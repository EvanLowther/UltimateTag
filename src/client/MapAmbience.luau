--!strict
-- Moving map parts and small living touches, from part attributes on the loaded map
-- (Workspace.ActiveMap) and the lobby (Workspace.Lobby), including parts that stream in later. Motion is worked out from the server's clock
-- (workspace:GetServerTimeNow), so every player sees the same parts in the same place without
-- the server sending anything.
--   Flicker (true): a light that cuts out now and then (its Neon and any light in it).
--   Spin (number, degrees per second): turns the part around the world's up axis (or SpinAxis,
--     a Vector3 direction: a fan on a wall), around SpinCenter (Vector3, world position; default
--     its own position). Parts sharing a center turn together (a gear and its teeth).
--   SpinCarry (true): standing on this spinning part turns you with it (rotating platforms).
--   Swing: SwingPivot (Vector3, world), SwingAxis (Vector3), SwingAmplitude (degrees),
--     SwingPeriod (seconds): swings back and forth around the pivot (a pendulum).
--     SwingLevel (true): the part follows the swing's arc but stays level (a hanging gondola
--     platform you can stand on).
--   Carry (true, or SpinCarry): standing on this moving part takes you with it (a spinning
--     platform turns you; a swinging one carries you along).
--   Knockback (number, studs/s): the part hits you when it touches you, like a bat on a ball
--     (Config.MapHits): a spinning one pushes you the way it's sweeping, harder the faster that
--     bit of it is moving and the faster you're running into it (at least Knockback), and pops
--     you up, more the harder the hit and more again if you're in the air (time a jump as it
--     comes and it throws you higher). Anything else shoves you straight away from it. The hit
--     uses client/Knockback's flight, so your keys and momentum can't cancel it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Knockback = require(script.Parent.Knockback)
local MoveState = require(script.Parent.MoveState)

local MapAmbience = {}

type Flicker = {
	root: Instance,
	part: BasePart,
	material: Enum.Material,
	lights: { Light },
	nextAt: number,
}
type Mover = {
	root: Instance,
	part: BasePart,
	base: CFrame,
	spin: number?,
	spinAxis: Vector3,
	center: Vector3,
	pivot: Vector3?,
	axis: Vector3?,
	amplitude: number,
	period: number,
	carry: boolean,
	level: boolean,
	knockback: number?,
}

local flickers: { Flicker } = {}
local movers: { Mover } = {}
local watching: { [Instance]: RBXScriptConnection } = {}
local FLOOR_RAY = 4.5

local function setLit(flicker: Flicker, lit: boolean)
	flicker.part.Material = if lit then flicker.material else Enum.Material.SmoothPlastic
	for _, light in flicker.lights do
		light.Enabled = lit
	end
end

-- A short burst of cutting out and back on.
local function flick(flicker: Flicker)
	task.spawn(function()
		for _ = 1, math.random(2, 4) do
			setLit(flicker, false)
			task.wait(math.random() * 0.08 + 0.03)
			setLit(flicker, true)
			task.wait(math.random() * 0.15 + 0.04)
		end
	end)
end

-- Picks up a part's ambience attributes (under `root`: the loaded map or the lobby).
local function consider(item: Instance, root: Instance)
	if not item:IsA("BasePart") then
		return
	end
	if item:GetAttribute("Flicker") == true then
		local lights = {}
		for _, child in item:GetChildren() do
			if child:IsA("Light") then
				table.insert(lights, child)
			end
		end
		table.insert(flickers, {
			root = root,
			part = item,
			material = item.Material,
			lights = lights,
			nextAt = os.clock() + math.random() * 4,
		})
	end
	local spin = item:GetAttribute("Spin")
	local pivot = item:GetAttribute("SwingPivot")
	local knockback = item:GetAttribute("Knockback")
	if type(spin) == "number" or typeof(pivot) == "Vector3" or type(knockback) == "number" then
		local center = item:GetAttribute("SpinCenter")
		local spinAxis = item:GetAttribute("SpinAxis")
		local axis = item:GetAttribute("SwingAxis")
		table.insert(movers, {
			root = root,
			part = item,
			base = item.CFrame,
			spin = if type(spin) == "number" then spin else nil,
			spinAxis = if typeof(spinAxis) == "Vector3" then spinAxis.Unit else Vector3.yAxis,
			center = if typeof(center) == "Vector3" then center else item.Position,
			pivot = if typeof(pivot) == "Vector3" then pivot else nil,
			axis = if typeof(axis) == "Vector3" then axis.Unit else Vector3.xAxis,
			amplitude = (item:GetAttribute("SwingAmplitude") or 0) :: number,
			period = (item:GetAttribute("SwingPeriod") or 4) :: number,
			carry = item:GetAttribute("SpinCarry") == true or item:GetAttribute("Carry") == true,
			level = item:GetAttribute("SwingLevel") == true,
			knockback = if type(knockback) == "number" then knockback else nil,
		})
	end
end

-- Starts animating a place: what's in it now, and whatever streams in later.
local function track(root: Instance)
	if watching[root] then
		return
	end
	for _, item in root:GetDescendants() do
		consider(item, root)
	end
	watching[root] = root.DescendantAdded:Connect(function(item)
		task.defer(consider, item, root) -- once its children (lights) are in too
	end)
end

local function untrack(root: Instance)
	local connection = watching[root]
	if connection then
		connection:Disconnect()
		watching[root] = nil
	end
	for i = #flickers, 1, -1 do
		if flickers[i].root == root then
			table.remove(flickers, i)
		end
	end
	for i = #movers, 1, -1 do
		if movers[i].root == root then
			table.remove(movers, i)
		end
	end
end

-- Where a moving part is at server time `t`.
local function placeAt(mover: Mover, t: number): CFrame
	local cframe = mover.base
	if mover.spin then
		local angle = math.rad((mover.spin * t) % 360)
		local c = mover.center
		cframe = CFrame.new(c)
			* CFrame.fromAxisAngle(mover.spinAxis, angle)
			* CFrame.new(-c)
			* cframe
	end
	if mover.pivot and mover.axis then
		local angle = math.rad(mover.amplitude) * math.sin(2 * math.pi * t / mover.period)
		local p = mover.pivot
		local swung = CFrame.new(p)
			* CFrame.fromAxisAngle(mover.axis, angle)
			* CFrame.new(-p)
			* cframe
		-- A level part keeps its orientation and only follows the arc.
		cframe = if mover.level then cframe.Rotation + swung.Position else swung
	end
	return cframe
end

-- The part under your feet, if any.
local function floorPart(parts: MoveState.Parts): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parts.character }
	local hit = workspace:Raycast(parts.root.Position, Vector3.new(0, -FLOOR_RAY, 0), params)
	return if hit then hit.Instance :: BasePart else nil
end

-- Does your body (root to about 3 below and 2 above it, `reach` round it) overlap the part?
local function touching(part: BasePart, at: CFrame, root: Vector3, reach: number): boolean
	local p = at:PointToObjectSpace(root)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X + reach
		and math.abs(p.Z) <= half.Z + reach
		and p.Y < half.Y + 3
		and p.Y > -half.Y - 2
end

-- The hit: how hard and which way a hazard knocks you (see Knockback at the top).
local function hit(mover: Mover, at: CFrame, parts: MoveState.Parts): boolean
	local C = Config.MapHits
	local root = parts.root
	local mine = MoveState.flat(root.AssemblyLinearVelocity)
	local sweep = Vector3.zero -- how fast the bit of it touching you is moving
	if mover.spin then
		local r = root.Position - mover.center
		sweep = Vector3.new(r.Z, 0, -r.X) * math.rad(mover.spin)
	end
	local push: Vector3
	local closing: number
	if sweep.Magnitude > C.MinSweep then
		local n = sweep.Unit
		closing = sweep.Magnitude - mine:Dot(n) -- how fast it's catching you up
		if closing <= 0 then
			return false -- you're outrunning it
		end
		local out = (sweep.Magnitude + C.Restitution * closing) * C.Strength
		local along = mine - n * mine:Dot(n)
		push = n * math.clamp(out, mover.knockback or 0, C.Max) + along * C.KeepAlong
	else
		local away = MoveState.flat(root.Position - at.Position)
		local direction = if away.Magnitude > 0.1 then away.Unit else -at.LookVector
		closing = math.max(-mine:Dot(direction), 0)
		push = direction * math.clamp(closing * C.Strength, mover.knockback or 0, C.Max)
	end
	local pop = C.Pop + C.PopPerSpeed * closing
	if not MoveState.isGrounded(parts.humanoid) then
		pop *= C.AirBonus -- caught mid-jump: thrown higher
	end
	return Knockback.apply(push, pop, C.AirAcross)
end

function MapAmbience.start()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" or child.Name == "Lobby" then
			track(child)
		end
	end)
	workspace.ChildRemoved:Connect(untrack)
	for _, name in { "ActiveMap", "Lobby" } do
		local place = workspace:FindFirstChild(name)
		if place then
			track(place)
		end
	end

	local lastKnock = -math.huge

	RunService.Heartbeat:Connect(function(dt: number)
		local t = workspace:GetServerTimeNow()
		local parts = MoveState.parts()
		local standingOn = if parts and #movers > 0 then floorPart(parts) else nil
		local carried = false
		for i = #movers, 1, -1 do
			local mover = movers[i]
			local part = mover.part
			if not part.Parent then
				table.remove(movers, i) -- streamed out or gone (it's picked up again if it comes back)
				continue
			end
			local before = part.CFrame
			local after = placeAt(mover, t)
			if mover.spin or mover.pivot then
				part.CFrame = after
			end
			-- Ride along on a moving platform you're standing on (once per frame): a spinning one
			-- turns you with it, a swinging one carries you without tilting you.
			if mover.carry and not carried and parts and standingOn == part then
				carried = true
				local root = parts.root
				if mover.spin then
					root.CFrame = (after * before:Inverse()) * root.CFrame
				else
					local moved = after:PointToWorldSpace(before:PointToObjectSpace(root.Position))
					root.CFrame += moved - root.Position
				end
			end
			-- Hit by a moving hazard (the reach grows by how far it swept this frame, so a fast
			-- one can't pass through you between frames).
			if mover.knockback and parts and os.clock() - lastKnock > Config.MapHits.Cooldown then
				local swept = if mover.spin
					then math.abs(math.rad(mover.spin)) * MoveState.flat(
						parts.root.Position - mover.center
					).Magnitude * dt
					else 0
				if touching(part, after, parts.root.Position, Config.MapHits.Reach + swept) then
					if hit(mover, after, parts) then
						lastKnock = os.clock()
					end
				end
			end
		end
		local now = os.clock()
		for i = #flickers, 1, -1 do
			local flicker = flickers[i]
			if not flicker.part.Parent then
				table.remove(flickers, i)
			elseif now >= flicker.nextAt then
				flicker.nextAt = now + 2 + math.random() * 6
				flick(flicker)
			end
		end
	end)
end

return MapAmbience
