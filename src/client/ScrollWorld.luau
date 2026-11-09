--!strict
-- Canyon Express on your screen (shared/ScrollLine). The trains stand still so moving on them is
-- as solid as the ground; instead the map's `Scroll<n>` folders slide past, bending away ahead of and
-- behind the trains so the line winds out of sight, `TrackB<n>` follows Train B's gap, `TrainB` drifts and carries whoever stands on it, and each
-- obstacle is one of the `Obstacle_<Kind>_<n>` folders brought down the line. A part with
-- `ObstacleHit` knocks you back if your body is in it (duck under a beam: only your standing height
-- reaches it). Lamps with `WarnLamp` flash while an obstacle is close.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ScrollLine = require(Shared:WaitForChild("ScrollLine"))
local Knockback = require(script.Parent.Knockback)
local MoveState = require(script.Parent.MoveState)

local ScrollWorld = {}

type Group = { parts: { BasePart }, base: { CFrame }, frames: { CFrame } }
type Hit = { part: BasePart, size: Vector3 }
type Pool = { group: Group, hits: { Hit }, at: number, shown: boolean }

local chunks: { [number]: Group } = {}
local tracks: { [number]: Group } = {}
local trainB: Group? = nil
local trainParts: { [BasePart]: boolean } = {}
local pools: { [string]: { [number]: Pool } } = {}
local lamps: { BasePart } = {}
local chunkCount = 0
local map: Instance? = nil
local dirtyAt: number? = nil
local added: RBXScriptConnection? = nil
local lastDrift = Vector3.zero
local lastHit = -math.huge

-- Where each part was built (remembered the first time it's seen: the map arrives in batches and
-- is scanned again as it does, and by then the earlier parts have already been moved).
local builtAt: { [BasePart]: CFrame } = {}

local function collect(root: Instance): Group
	local group: Group = { parts = {}, base = {}, frames = {} }
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			local built = builtAt[item] or item.CFrame
			builtAt[item] = built
			table.insert(group.parts, item)
			table.insert(group.base, built)
			table.insert(group.frames, built)
		end
	end
	return group
end

local function scan(target: Instance)
	table.clear(chunks)
	table.clear(tracks)
	table.clear(pools)
	table.clear(lamps)
	table.clear(trainParts)
	trainB, chunkCount = nil, 0
	lastDrift = Vector3.zero
	for _, child in target:GetChildren() do
		local name = child.Name
		local chunk = string.match(name, "^Scroll(%d+)$")
		local track = string.match(name, "^TrackB(%d+)$")
		local kind, pool = string.match(name, "^Obstacle_(%a+)_(%d+)$")
		if chunk then
			chunks[tonumber(chunk) :: number] = collect(child)
			chunkCount = math.max(chunkCount, (tonumber(chunk) :: number) + 1)
		elseif track then
			tracks[tonumber(track) :: number] = collect(child)
		elseif name == "TrainB" then
			local group = collect(child)
			trainB = group
			for _, part in group.parts do
				trainParts[part] = true
			end
		elseif kind and pool then
			local group = collect(child)
			local hits: { Hit } = {}
			for _, part in group.parts do
				if part:GetAttribute("ObstacleHit") == true then
					table.insert(hits, { part = part, size = part.Size })
				end
			end
			pools[kind] = pools[kind] or {}
			pools[kind][tonumber(pool) :: number] =
				{ group = group, hits = hits, at = 0, shown = false }
		end
	end
	for _, item in target:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("WarnLamp") == true then
			table.insert(lamps, item)
		end
	end
end

local function move(group: Group, delta: Vector3)
	for i, base in group.base do
		group.frames[i] = base + delta
	end
	workspace:BulkMoveTo(group.parts, group.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Places a group built round `origin` along the track at `place` (a point and turn on the bend).
local function moveTo(group: Group, origin: number, place: CFrame)
	local inverse = CFrame.new(-origin, 0, 0)
	for i, base in group.base do
		group.frames[i] = place * inverse * base
	end
	workspace:BulkMoveTo(group.parts, group.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function hitCheck(parts: MoveState.Parts, pool: Pool): boolean
	local root = parts.root.Position
	local head = parts.character:FindFirstChild("Head") :: BasePart?
	local top = if head then head.Position.Y + head.Size.Y / 2 else root.Y + 2.5
	local bottom = root.Y - 3
	local s = Config.ScrollWorld
	for _, hit in pool.hits do
		local c = hit.part.CFrame.Position
		local half = hit.size / 2
		if
			math.abs(root.X - c.X) <= half.X + s.HitReach
			and math.abs(root.Z - c.Z) <= half.Z + 1
			and top > c.Y - half.Y
			and bottom < c.Y + half.Y
		then
			return Knockback.apply(Vector3.new(-s.HitPush, 0, 0), s.HitPop, 1)
		end
	end
	return false
end

local frame = 0

local function step()
	local current = workspace:FindFirstChild("ActiveMap")
	if current ~= map then
		if added then
			added:Disconnect()
			added = nil
		end
		map = current
		table.clear(chunks)
		table.clear(tracks)
		table.clear(pools)
		table.clear(builtAt)
		chunkCount = 0
		if map and map:GetAttribute("ScrollWorld") == true then
			dirtyAt = os.clock()
			added = map.DescendantAdded:Connect(function()
				dirtyAt = os.clock()
			end)
		else
			dirtyAt = nil
		end
	end
	if not map then
		return
	end
	if dirtyAt and os.clock() - dirtyAt > 0.4 then
		dirtyAt = nil
		scan(map)
	end
	if chunkCount == 0 then
		return
	end
	frame += 1
	local s = Config.ScrollWorld
	local t = workspace:GetServerTimeNow()
	local slid = ScrollLine.distance(t)
	local total = chunkCount * s.ChunkLength
	local drift = ScrollLine.trainB(t)
	for index, group in chunks do
		local built = (index + 0.5) * s.ChunkLength
		local x = (built - slid) % total - total / 2 -- centred on the trains
		-- (the far stretches, out in the haze, only need a move every few frames)
		if math.abs(x) > s.FarFrom and frame % 3 ~= 0 then
			continue
		end
		local place = ScrollLine.warp(x, slid)
		moveTo(group, built, place)
		local track = tracks[index]
		if track then
			moveTo(track, built, place * CFrame.new(0, 0, drift.Z))
		end
	end
	local parts = MoveState.parts()
	if trainB then
		move(trainB, drift)
		-- Ride along on Train B.
		if parts then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { parts.character }
			local hit = workspace:Raycast(parts.root.Position, Vector3.new(0, -4.5, 0), params)
			if hit and trainParts[hit.Instance :: BasePart] then
				parts.root.CFrame += drift - lastDrift
			end
		end
		lastDrift = drift
	end
	-- Obstacles: bring each one in use to its place, send the rest back where they're built.
	local active = ScrollLine.obstacles(t)
	local inUse: { [Pool]: boolean } = {}
	local soon = false
	for _, obstacle in active do
		local kindPools = pools[obstacle.kind]
		local pool = kindPools and kindPools[obstacle.pool]
		if pool then
			inUse[pool] = true
			-- (each piece is built round a multiple of ParkStep along the line)
			local built = math.round(pool.group.base[1].Position.X / s.ParkStep) * s.ParkStep
			local side = if string.sub(obstacle.kind, -1) == "B" then drift.Z else 0
			moveTo(pool.group, built, ScrollLine.warp(obstacle.x, slid) * CFrame.new(0, 0, side))
			pool.shown = true
			if obstacle.x > s.TrainFront and obstacle.x < s.TrainFront + s.Speed * s.WarnTime then
				soon = true
			end
			if parts and os.clock() - lastHit > s.HitCooldown and hitCheck(parts, pool) then
				lastHit = os.clock()
			end
		end
	end
	for _, kindPools in pools do
		for _, pool in kindPools do
			if pool.shown and not inUse[pool] then
				pool.shown = false
				move(pool.group, Vector3.zero)
			end
		end
	end
	local on = soon and math.floor(os.clock() * 4) % 2 == 0
	for _, lamp in lamps do
		lamp.Color = if on then s.WarnOn else s.WarnOff
	end
end

function ScrollWorld.start()
	RunService.PreSimulation:Connect(step)
end

return ScrollWorld
