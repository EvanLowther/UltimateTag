--!strict
-- The Arctic Icebreaker on your screen (shared/ShipRoll). The ship stays perfectly still, so moving
-- on it stays solid; instead its `Sea` folder and your camera roll round it, and you're pushed
-- downhill as if the deck had really tipped (stopped by anything solid, so you can get behind
-- cover). The `Loose<n>` containers slide across the deck: you can ride them, and one sliding into
-- you knocks you back. Parts with `ShipWarnLamp` flash before a big tip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ShipRoll = require(Shared:WaitForChild("ShipRoll"))
local Knockback = require(script.Parent.Knockback)
local MoveState = require(script.Parent.MoveState)

local ShipWorld = {}

type Group = { parts: { BasePart }, base: { CFrame }, frames: { CFrame } }
type Loose = { group: Group, solid: BasePart?, size: Vector3, builtX: number, x: number }

local map: Instance? = nil
local dirtyAt: number? = nil
local added: RBXScriptConnection? = nil
local sea: Group? = nil
local loose: { [number]: Loose } = {}
local looseParts: { [BasePart]: Loose } = {}
local lamps: { BasePart } = {}
local active = false
local cameraRoll = 0
local lastHit = -math.huge

local function collect(root: Instance): Group
	local group: Group = { parts = {}, base = {}, frames = {} }
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(group.parts, item)
			table.insert(group.base, item.CFrame)
			table.insert(group.frames, item.CFrame)
		end
	end
	return group
end

local function scan(target: Instance)
	sea = nil
	table.clear(loose)
	table.clear(looseParts)
	table.clear(lamps)
	for _, child in target:GetChildren() do
		local n = string.match(child.Name, "^Loose(%d+)$")
		if child.Name == "Sea" then
			sea = collect(child)
		elseif n then
			local group = collect(child)
			local entry: Loose =
				{ group = group, solid = nil, size = Vector3.zero, builtX = 0, x = 0 }
			for _, part in group.parts do
				looseParts[part] = entry
				if part.CanCollide then
					entry.solid = part
					entry.size = part.Size
					entry.builtX = part.Position.X
				end
			end
			loose[tonumber(n) :: number] = entry
		end
	end
	for _, item in target:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("ShipWarnLamp") == true then
			table.insert(lamps, item)
		end
	end
end

-- Pushes you along X unless something solid is right there.
local function push(parts: MoveState.Parts, dx: number)
	local root = parts.root
	local direction = Vector3.new(if dx > 0 then 1 else -1, 0, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parts.character }
	for _, height in { -2.4, -0.5, 1.5 } do
		local from = root.Position + Vector3.new(0, height, 0)
		if
			workspace:Raycast(from, direction * (math.abs(dx) + Config.ShipRoll.PushClear), params)
		then
			return
		end
	end
	root.CFrame += Vector3.new(dx, 0, 0)
end

local function step(dt: number)
	local current = workspace:FindFirstChild("ActiveMap")
	if current ~= map then
		if added then
			added:Disconnect()
			added = nil
		end
		map = current
		active = false
		dirtyAt = nil
		sea = nil
		if map and map:GetAttribute("ShipRoll") == true then
			dirtyAt = os.clock()
			added = map.DescendantAdded:Connect(function()
				dirtyAt = os.clock()
			end)
		end
	end
	if not map then
		return
	end
	if dirtyAt and os.clock() - dirtyAt > 0.4 then
		dirtyAt = nil
		scan(map)
		active = true
	end
	if not active then
		return
	end
	local s = Config.ShipRoll
	-- Nobody near the ship (waiting in the lobby, say): no need to move any of it.
	if workspace.CurrentCamera.CFrame.Position.Magnitude > s.CameraRange then
		return
	end
	local t = workspace:GetServerTimeNow()
	local roll, warn = ShipRoll.at(t)
	if sea then
		local pivot = CFrame.new(0, s.PivotY, 0)
		local turn = pivot * CFrame.Angles(0, 0, -roll) * pivot:Inverse()
		for i, base in sea.base do
			sea.frames[i] = turn * base
		end
		workspace:BulkMoveTo(sea.parts, sea.frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	local parts = MoveState.parts()
	local floor: BasePart? = nil
	if parts then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { parts.character }
		local hit = workspace:Raycast(parts.root.Position, Vector3.new(0, -4.5, 0), params)
		floor = if hit then hit.Instance :: BasePart else nil
	end
	for index, entry in loose do
		local x, speed = ShipRoll.container(t, index)
		local delta = x - entry.builtX
		for i, base in entry.group.base do
			entry.group.frames[i] = base + Vector3.new(delta, 0, 0)
		end
		workspace:BulkMoveTo(
			entry.group.parts,
			entry.group.frames,
			Enum.BulkMoveMode.FireCFrameChanged
		)
		if parts then
			local moved = x - entry.x
			if floor and looseParts[floor] == entry then
				parts.root.CFrame += Vector3.new(moved, 0, 0) -- riding it
			elseif
				entry.solid
				and math.abs(speed) > s.HitSpeed
				and os.clock() - lastHit > s.HitCooldown
			then
				local p = parts.root.Position
				local c = entry.solid.Position
				local half = entry.size / 2
				if
					math.abs(p.X - c.X) < half.X + 1.5
					and math.abs(p.Z - c.Z) < half.Z + 1.2
					and p.Y < c.Y + half.Y
					and p.Y > c.Y - half.Y - 3
				then
					local sign = if speed > 0 then 1 else -1
					if Knockback.apply(Vector3.new(sign * s.HitPush, 0, 0), s.HitPop, 1) then
						lastHit = os.clock()
					end
				end
			end
		end
		entry.x = x
	end
	-- Pushed downhill (a roll lifts +X, so you go towards -X); a gentle sway does nothing.
	if parts and not parts.root.Anchored and math.abs(roll) > math.rad(s.PushFrom) then
		local amount = math.sin(roll) / math.sin(math.rad(s.MaxRoll))
		push(parts, -amount * s.PushSpeed * dt)
	end
	local on = warn and math.floor(os.clock() * 4) % 2 == 0
	for _, lamp in lamps do
		lamp.Color = if on then s.WarnOn else s.WarnOff
	end
end

function ShipWorld.start()
	RunService.PreSimulation:Connect(step)
	-- The camera rolls with the ship, so the deck looks tipped against a level horizon. Roblox's
	-- camera reads its own last look, so the roll comes off just before it runs and goes back on
	-- right after.
	local function apply(angle: number)
		local camera = workspace.CurrentCamera
		local c = camera.CFrame
		camera.CFrame = CFrame.new(c.Position) * CFrame.Angles(0, 0, angle) * c.Rotation
	end
	RunService:BindToRenderStep("ShipRollOff", Enum.RenderPriority.Camera.Value - 1, function()
		if cameraRoll ~= 0 then
			apply(cameraRoll)
			cameraRoll = 0
		end
	end)
	RunService:BindToRenderStep("ShipRollOn", Enum.RenderPriority.Camera.Value + 4, function()
		if active and map and map.Parent then
			local camera = workspace.CurrentCamera
			if camera.CFrame.Position.Magnitude < Config.ShipRoll.CameraRange then
				local roll = ShipRoll.at(workspace:GetServerTimeNow())
				apply(-roll)
				cameraRoll = roll
			end
		end
	end)
end

return ShipWorld
