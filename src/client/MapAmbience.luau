--!strict
-- Moving map parts and small living touches, from part attributes on the loaded map
-- (Workspace.ActiveMap). Motion is worked out from the server's clock
-- (workspace:GetServerTimeNow), so every player sees the same parts in the same place without
-- the server sending anything.
--   Flicker (true): a light that cuts out now and then (its Neon and any light in it).
--   Spin (number, degrees per second): turns the part around the world's up axis, around
--     SpinCenter (Vector3, world position; default its own position). Parts sharing a center
--     turn together (a gear and its teeth).
--   SpinCarry (true): standing on this spinning part turns you with it (rotating platforms).
--   Swing: SwingPivot (Vector3, world), SwingAxis (Vector3), SwingAmplitude (degrees),
--     SwingPeriod (seconds): swings back and forth around the pivot (a pendulum).
--     SwingLevel (true): the part follows the swing's arc but stays level (a hanging gondola
--     platform you can stand on).
--   Carry (true, or SpinCarry): standing on this moving part takes you with it (a spinning
--     platform turns you; a swinging one carries you along).
--   Knockback (number, studs/s): touching the part shoves you away from it.
local RunService = game:GetService("RunService")

local MoveState = require(script.Parent.MoveState)

local MapAmbience = {}

type Flicker = { part: BasePart, material: Enum.Material, lights: { Light }, nextAt: number }
type Mover = {
	part: BasePart,
	base: CFrame,
	spin: number?,
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
local KNOCK_COOLDOWN = 0.8
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

local function scan(map: Instance)
	table.clear(flickers)
	table.clear(movers)
	local now = os.clock()
	for _, item in map:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		if item:GetAttribute("Flicker") == true then
			local lights = {}
			for _, child in item:GetChildren() do
				if child:IsA("Light") then
					table.insert(lights, child)
				end
			end
			table.insert(flickers, {
				part = item,
				material = item.Material,
				lights = lights,
				nextAt = now + math.random() * 4,
			})
		end
		local spin = item:GetAttribute("Spin")
		local pivot = item:GetAttribute("SwingPivot")
		local knockback = item:GetAttribute("Knockback")
		if type(spin) == "number" or typeof(pivot) == "Vector3" or type(knockback) == "number" then
			local center = item:GetAttribute("SpinCenter")
			local axis = item:GetAttribute("SwingAxis")
			table.insert(movers, {
				part = item,
				base = item.CFrame,
				spin = if type(spin) == "number" then spin else nil,
				center = if typeof(center) == "Vector3" then center else item.Position,
				pivot = if typeof(pivot) == "Vector3" then pivot else nil,
				axis = if typeof(axis) == "Vector3" then axis.Unit else Vector3.xAxis,
				amplitude = (item:GetAttribute("SwingAmplitude") or 0) :: number,
				period = (item:GetAttribute("SwingPeriod") or 4) :: number,
				carry = item:GetAttribute("SpinCarry") == true
					or item:GetAttribute("Carry") == true,
				level = item:GetAttribute("SwingLevel") == true,
				knockback = if type(knockback) == "number" then knockback else nil,
			})
		end
	end
end

-- Where a moving part is at server time `t`.
local function placeAt(mover: Mover, t: number): CFrame
	local cframe = mover.base
	if mover.spin then
		local angle = math.rad((mover.spin * t) % 360)
		local c = mover.center
		cframe = CFrame.new(c) * CFrame.Angles(0, angle, 0) * CFrame.new(-c) * cframe
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

-- Is `point` inside the part's box, grown by `margin`?
local function touching(part: BasePart, point: Vector3, margin: number): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.new(margin, margin, margin)
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

function MapAmbience.start()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" then
			task.wait(0.5) -- let it finish replicating
			if child.Parent then
				scan(child)
			end
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "ActiveMap" then
			table.clear(flickers)
			table.clear(movers)
		end
	end)
	local current = workspace:FindFirstChild("ActiveMap")
	if current then
		scan(current)
	end

	local lastKnock = -math.huge

	RunService.Heartbeat:Connect(function()
		local t = workspace:GetServerTimeNow()
		local parts = MoveState.parts()
		local standingOn = if parts and #movers > 0 then floorPart(parts) else nil
		local carried = false
		for _, mover in movers do
			local part = mover.part
			if not part.Parent then
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
			-- Knocked back by a moving hazard.
			if mover.knockback and parts and os.clock() - lastKnock > KNOCK_COOLDOWN then
				if touching(part, parts.root.Position, 2) then
					lastKnock = os.clock()
					local away = parts.root.Position - part.Position
					away = Vector3.new(away.X, 0, away.Z)
					local push = if away.Magnitude > 0.1 then away.Unit else -part.CFrame.LookVector
					local velocity = push * mover.knockback
						+ Vector3.new(0, mover.knockback * 0.4, 0)
					parts.root.AssemblyLinearVelocity = velocity
					MoveState.airVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				end
			end
		end
		local now = os.clock()
		for _, flicker in flickers do
			if now >= flicker.nextAt and flicker.part.Parent then
				flicker.nextAt = now + 2 + math.random() * 6
				flick(flicker)
			end
		end
	end)
end

return MapAmbience
