--!strict
-- Chrysalis (Iridescent), built from its approved mockup (docs/polish/victories.md): the stage's
-- neon dies and nature overgrows it (moss, grass, ferns, vines, flowers growing in), silk spirals
-- up and wraps the winner into a pearly cocoon that beats like a heart and cracks, then bursts
-- into hundreds of morpho butterflies as huge blue-violet-teal wings unfold from the winner's
-- back. They rise on the wings, one butterfly lands on their raised hand while the rest fly at the
-- camera in waves and out of view, and it leaves last.
-- Places are worked out in "stage space": X to the right of the screen, Y up from what the winner
-- stands on, Z toward the camera (the mockup's own axes).
local Kit = require(script.Parent.Kit)

type Context = Kit.Context
type Key = Kit.Key

local Chrysalis = {}

local function A(x: number, y: number?, z: number?): Vector3
	return Vector3.new(x, y or 0, z or 0)
end
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WHITE = Color3.new(1, 1, 1)
local DEEP, ELECTRIC, VIOLET, TEAL =
	rgb(20, 70, 220), rgb(40, 140, 255), rgb(140, 80, 255), rgb(40, 220, 210)
local PEARL = rgb(244, 240, 250)
local MOSS = { rgb(44, 86, 31), rgb(60, 110, 40), rgb(72, 124, 45), rgb(86, 138, 52) }
local GRASS = { rgb(62, 128, 38), rgb(90, 160, 50), rgb(118, 186, 60) }
local LEAF = { rgb(50, 130, 45), rgb(72, 150, 50), rgb(120, 190, 60), rgb(40, 110, 40) }
local FLOWER = { rgb(245, 245, 238), rgb(255, 176, 206), rgb(200, 172, 255) }
local CENTRE = rgb(255, 214, 80)
-- The butterflies' colour sets (base to tip), as in the mockup.
local MORPHO = {
	{ DEEP, ELECTRIC, ELECTRIC, TEAL },
	{ DEEP, VIOLET, VIOLET, rgb(190, 140, 255) },
	{ DEEP, rgb(30, 150, 240), TEAL, rgb(120, 250, 230) },
	{ rgb(70, 50, 200), VIOLET, rgb(190, 120, 255), TEAL },
	{ DEEP, ELECTRIC, rgb(110, 190, 255), VIOLET },
	{ rgb(30, 40, 170), rgb(60, 110, 255), TEAL, TEAL },
	{ rgb(80, 40, 200), rgb(150, 90, 255), rgb(90, 170, 255), rgb(60, 230, 210) },
	{ DEEP, rgb(40, 120, 255), rgb(130, 90, 255), rgb(70, 220, 255) },
}

-- The timeline (seconds from the start).
local PULSES = { { 2.5, 0.5 }, { 2.9, 0.75 }, { 3.27, 1.0 } }
local WAVES = { 6.5, 6.95, 7.4, 7.85, 8.3 }
local BURST, UNFOLD, RING = 3.8, 3.9, 5.1
local LAST_GONE = 9.6 -- the last of the swarm is out of view
local LEAVE = LAST_GONE + 0.5 -- the butterfly on the hand leaves
local COCOON_H, COCOON_W = 6.6, 2.3 -- height and half width
local WING = 8.6 -- one wing's span (both about 17 across)
local WING_TALL = 0.64 -- its height to span

local span = Kit.span

local function rise(t: number): number
	return 5 * span(t, 5.1, 6.8)
end
-- The wings' beat: 1 is open, smaller is the downstroke.
local function flapOf(t: number): number
	if t < 4.8 then
		return 1
	elseif t < 5.55 then
		return 1 - 0.62 * math.sin(math.pi * (t - 4.8) / 0.75) ^ 2
	end
	return 1 - 0.42 * math.sin(math.pi * (t - 5.55)) ^ 2
end
-- How far the winner is off the block: the cocoon lifts, then they rise on the wings.
local function lift(t: number): number
	local l = 1.0 * span(t, 2.2, 2.75)
	if t > 2.75 and t < 3.45 then
		l += math.sin((t - 2.75) * 3.2) * 0.07
	end
	l += rise(t)
	if t > 4.8 then
		l += 0.32 * (1 - flapOf(t - 0.18)) * span(t, 4.8, 5.2)
	end
	return l
end
-- The cocoon's half width at height v (0 bottom, 1 top).
local function cocoonWidth(v: number): number
	if v <= 0 or v >= 1 then
		return 0
	end
	return COCOON_W * math.sin(math.pi * v) ^ 0.72 * (1 - 0.14 * (v - 0.55))
end
-- The light inside the cocoon: three heartbeats, brightest at the hush.
local function glowOf(t: number): number
	if t < 2.2 then
		return 0
	end
	local v = 0.1 * span(t, 2.2, 2.5)
	for _, pulse in PULSES do
		v += pulse[2] * (math.exp(-((t - pulse[1]) / 0.08) ^ 2) + 0.5 * math.exp(
			-((t - pulse[1] - 0.17) / 0.07) ^ 2
		))
	end
	if t >= 3.36 and t < BURST then
		v = math.max(v, 1.25 * span(t, 3.36, 3.5))
	elseif t >= BURST then
		v = 1.25 * (1 - span(t, BURST, 4.05))
	end
	return v
end

---------------------------------------------------------------------------- the winner's poses

local WINNER: { Key } = {
	{ time = 0, angles = {} },
	{ time = 0.15, angles = {} },
	{ time = 0.45, angles = { Head = A(-10, 35, 0) } },
	{ time = 0.75, angles = { Head = A(-8, -30, 0) } },
	{
		time = 1.0,
		angles = { Head = A(8), RightUpperArm = A(0, 0, 20), LeftUpperArm = A(0, 0, -20) },
	},
	{ time = 1.2, angles = {} },
	{
		-- Arms crossed over the chest as the cocoon wraps them.
		time = 1.6,
		angles = {
			RightUpperArm = A(60, 0, -30),
			RightLowerArm = A(100),
			LeftUpperArm = A(60, 0, 30),
			LeftLowerArm = A(100),
			Head = A(-12),
		},
	},
	{ time = BURST, angles = {} },
	{
		-- Thrown open as the wings unfold.
		time = 4.05,
		angles = {
			RightUpperArm = A(0, 0, 122),
			LeftUpperArm = A(0, 0, -122),
			RightLowerArm = A(0),
			LeftLowerArm = A(0),
			Head = A(25),
			RightUpperLeg = A(0, 0, 7),
			LeftUpperLeg = A(0, 0, -7),
			RightLowerLeg = A(-6),
			LeftLowerLeg = A(-6),
		},
		ease = "Out",
	},
	{ time = 5.1, angles = {} },
	{
		-- The right hand raised for the butterfly to land on, looking at it.
		time = 5.9,
		angles = {
			RightUpperArm = A(150, 0, 25),
			RightLowerArm = A(20),
			LeftUpperArm = A(0, 0, -112),
			Head = A(20, -25, 0),
		},
	},
	{ time = 6.3, angles = { Head = A(15, -30, 0) } },
	{ time = 7.3, angles = {} },
	{ time = 7.6, angles = { Head = A(15, 10, 0) } },
	{ time = 8.4, angles = {} },
	{ time = 8.7, angles = { Head = A(20, -25, 0) } },
	{ time = LEAVE, angles = {} },
	{ time = LEAVE + 0.6, angles = { Head = A(35, -15, 0) } },
	{
		time = LEAVE + 1.3,
		angles = { Head = A(25), RightUpperArm = A(0, 0, 120), RightLowerArm = A(0) },
	},
}

---------------------------------------------------------------------------- shapes

-- A stretched ball (an egg shape).
local function egg(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local part = Kit.block(size, cframe, color, material, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Something that grows over a stretch of the timeline: `step(u)` is called with 0 to 1.
type Grow = { at: number, dur: number, step: (number) -> (), done: boolean }

---------------------------------------------------------------------------- the butterflies (screen-facing)

type Butterfly = {
	gui: BillboardGui,
	point: Attachment,
	halves: { Frame },
	flake: Frame,
	wings: { GuiObject },
	origin: Vector3,
	out: Vector3,
	reach: number,
	time: number,
	phase: number,
	radius: number,
	spin: number,
	start: number,
	height: number,
	blend: number,
	squash: number,
	beat: number,
	beatPhase: number,
	lands: boolean,
	wave: number,
	waveTime: number,
	target: Vector3?,
	arc: number,
	shown: boolean,
}

local function oval(
	parent: Instance,
	size: Vector2,
	at: Vector2,
	anchor: Vector2,
	rotation: number,
	color: Color3,
	transparency: number?
): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.AnchorPoint = anchor
	frame.Position = UDim2.fromScale(at.X, at.Y)
	frame.Size = UDim2.fromScale(size.X, size.Y)
	frame.Rotation = rotation
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function morphoGradient(parent: Instance, colors: { Color3 }, rotation: number)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]),
		ColorSequenceKeypoint.new(0.4, colors[2]),
		ColorSequenceKeypoint.new(0.75, colors[3]),
		ColorSequenceKeypoint.new(1, colors[4]),
	})
	gradient.Parent = parent
end

local function edge(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.Transparency = transparency or 0
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = parent
end

-- A small glowing butterfly that always faces the camera: two halves (fore and hind wing each)
-- that flap by narrowing, a dark body, and the pearl flake it starts as.
local function makeButterfly(
	size: number,
	colors: { Color3 },
	folder: Instance
): (BillboardGui, Attachment, { Frame }, Frame, { GuiObject })
	local point = Instance.new("Attachment")
	point.Parent = workspace.Terrain
	Kit.track(point)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size * 1.9, size * 1.5)
	gui.LightInfluence = 0
	gui.MaxDistance = 2000
	gui.Adornee = point
	gui.Enabled = false
	local halves = {}
	local wings: { GuiObject } = {}
	for _, side in { -1, 1 } do
		local half = Instance.new("Frame")
		half.BackgroundTransparency = 1
		half.AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5)
		half.Position = UDim2.fromScale(0.5, 0.5)
		half.Size = UDim2.fromScale(0.5, 1)
		half.Parent = gui
		local near = if side < 0 then 1 else 0 -- the body side of this half
		local fore = oval(
			half,
			Vector2.new(1.0, 0.56),
			Vector2.new(near, 0.5),
			Vector2.new(near, 1),
			-24 * side,
			WHITE
		)
		morphoGradient(fore, colors, if side < 0 then 180 else 0)
		edge(fore, rgb(8, 10, 32), 1.5)
		local hind = oval(
			half,
			Vector2.new(0.72, 0.46),
			Vector2.new(near, 0.5),
			Vector2.new(near, 0),
			28 * side,
			WHITE
		)
		morphoGradient(hind, colors, if side < 0 then 180 else 0)
		edge(hind, rgb(8, 10, 32), 1.5)
		oval(
			hind,
			Vector2.new(0.24, 0.3),
			Vector2.new(if side < 0 then 0.3 else 0.7, 0.6),
			Vector2.new(0.5, 0.5),
			0,
			rgb(14, 12, 40)
		)
		table.insert(halves, half)
		table.insert(wings, fore)
		table.insert(wings, hind)
	end
	local body = oval(
		gui,
		Vector2.new(0.06, 0.5),
		Vector2.new(0.5, 0.52),
		Vector2.new(0.5, 0.5),
		0,
		rgb(12, 12, 30)
	)
	table.insert(wings, body)
	local flake =
		oval(gui, Vector2.new(0.42, 0.3), Vector2.new(0.5, 0.5), Vector2.new(0.5, 0.5), 25, PEARL)
	edge(flake, rgb(215, 195, 255), 1, 0.3)
	gui.Parent = folder
	Kit.track(gui)
	return gui, point, halves, flake, wings
end

---------------------------------------------------------------------------- the big wings

-- One big wing painted on a panel facing the camera: the fore and hind wing as gradient ovals
-- with dark veins and margins, pale spots, an eyespot on the hind wing and a glowing edge.
-- `mirror` draws it for the left of the screen (the body on the panel's right edge).
type BigWing = { panel: Part, gradients: { UIGradient } }
local function makeWing(mirror: boolean): BigWing
	local panel = Kit.block(A(1, 1, 0.05), CFrame.new(), WHITE, nil, 1)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(500, 640)
	gui.LightInfluence = 0
	gui.Brightness = 1.15
	gui.Parent = panel
	local gradients = {}
	local function x(v: number): number
		return if mirror then 1 - v else v
	end
	local function turn(r: number): number
		return if mirror then -r else r
	end
	-- (fore: from the body up and out to the apex; hind: down and out.)
	local parts = {
		{ size = Vector2.new(1.18, 0.36), at = Vector2.new(0.53, 0.25), rot = -25, hind = false },
		{ size = Vector2.new(0.76, 0.4), at = Vector2.new(0.42, 0.74), rot = 55, hind = true },
	}
	for _, wing in parts do
		-- The glowing edge, just outside the wing.
		local glow = oval(
			gui,
			wing.size + Vector2.new(0.03, 0.03),
			Vector2.new(x(wing.at.X), wing.at.Y),
			Vector2.new(0.5, 0.5),
			turn(wing.rot),
			WHITE,
			1
		)
		edge(glow, rgb(140, 220, 255), 5, 0.25)
		local shape = oval(
			gui,
			wing.size,
			Vector2.new(x(wing.at.X), wing.at.Y),
			Vector2.new(0.5, 0.5),
			turn(wing.rot),
			WHITE
		)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = if mirror then 180 else 0
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(12, 30, 120)),
			ColorSequenceKeypoint.new(0.18, DEEP),
			ColorSequenceKeypoint.new(0.45, ELECTRIC),
			ColorSequenceKeypoint.new(0.76, VIOLET),
			ColorSequenceKeypoint.new(1, TEAL),
		})
		gradient.Parent = shape
		table.insert(gradients, gradient)
		edge(shape, rgb(6, 8, 28), 7)
		-- Veins fanning out from the body end.
		local from = if mirror then 0.95 else 0.05
		for k = 0, 5 do
			local angle = (k - 2.5) * (if wing.hind then 9 else 7)
			local vein = Instance.new("Frame")
			vein.BorderSizePixel = 0
			vein.BackgroundColor3 = rgb(8, 12, 44)
			vein.BackgroundTransparency = 0.3
			vein.AnchorPoint = Vector2.new(if mirror then 1 else 0, 0.5)
			vein.Position = UDim2.fromScale(from, 0.5)
			vein.Size = UDim2.new(0.82 - math.abs(k - 2.5) * 0.08, 0, 0, 3)
			vein.Rotation = turn(angle)
			vein.Parent = shape
		end
		-- Pale spots along the outer margin.
		for k = 1, 4 do
			local u = 0.62 + k * 0.08
			oval(
				shape,
				Vector2.new(0.035, 0.09),
				Vector2.new(if mirror then 1 - u else u, if k % 2 == 0 then 0.18 else 0.82),
				Vector2.new(0.5, 0.5),
				0,
				rgb(225, 240, 255),
				0.15
			)
		end
		-- The dark apex, and on the hind wing the eyespot.
		if not wing.hind then
			oval(
				shape,
				Vector2.new(0.22, 0.6),
				Vector2.new(if mirror then 0.1 else 0.9, 0.5),
				Vector2.new(0.5, 0.5),
				0,
				rgb(6, 8, 30),
				0.35
			)
		else
			local eyeAt = Vector2.new(if mirror then 0.32 else 0.68, 0.55)
			oval(
				shape,
				Vector2.new(0.26, 0.5),
				eyeAt,
				Vector2.new(0.5, 0.5),
				0,
				rgb(10, 10, 32),
				0.05
			)
			oval(shape, Vector2.new(0.2, 0.39), eyeAt, Vector2.new(0.5, 0.5), 0, rgb(80, 230, 190))
			oval(shape, Vector2.new(0.14, 0.27), eyeAt, Vector2.new(0.5, 0.5), 0, rgb(22, 16, 58))
			oval(shape, Vector2.new(0.075, 0.15), eyeAt, Vector2.new(0.5, 0.5), 0, VIOLET)
			oval(
				shape,
				Vector2.new(0.035, 0.07),
				eyeAt + Vector2.new(0.02, -0.04),
				Vector2.new(0.5, 0.5),
				0,
				rgb(235, 242, 255)
			)
		end
	end
	return { panel = panel, gradients = gradients }
end

---------------------------------------------------------------------------- the victory

function Chrysalis.play(context: Context)
	local character = context.character
	local home = context.home
	local root = context.root
	local rootHeight = context.humanoid.HipHeight + root.Size.Y / 2
	local floorY = context.floor - context.ground -- the stage floor, in stage space (0 or below)
	local onPodium = #context.blocks > 0
	local look = home.LookVector -- toward the camera
	local random = Random.new(20261030)
	local function rnd(a: number, b: number): number
		return a + random:NextNumber() * (b - a)
	end
	-- Stage space to the world, and back.
	local function at(x: number, y: number, z: number): Vector3
		return (home * CFrame.new(-x, y - rootHeight, -z)).Position
	end
	local function stage(point: Vector3): Vector3
		local here = home:PointToObjectSpace(point)
		return A(-here.X, here.Y + rootHeight, -here.Z)
	end
	local facing = home.Rotation -- a flat thing turned to the camera
	local folder = Kit.folder()

	Kit.pose(character, WINNER, context.hold)
	Kit.move(context, function(t)
		return CFrame.new(0, lift(t), 0)
	end)
	-- The camera drifts in, pushes in on the cocoon, backs off for the burst and rises with them.
	Kit.dolly(function(t)
		local forward = 3 * span(t, 0, 1.7) + 5 * span(t, 2.2, BURST) - 5.5 * span(t, BURST, 5.0)
		return A(0, 1.5 * span(t, 2.2, BURST) + rise(t) * 0.86, -forward)
	end)
	Kit.lookAt(function(t)
		return root.Position + A(0, 0.5, 0), 0.35 * span(t, 4.8, 6.0)
	end)
	Kit.react(context, "LookAround", 0.3)
	Kit.react(context, "Shield", 3.82)
	Kit.react(context, "LookUp", 5.3)

	-- 0.0: the neon dies (a flicker, then out) and the lamps go warm and low.
	local neon: { { part: BasePart, color: Color3 } } = {}
	local lamps: { { light: Light, brightness: number, color: Color3 } } = {}
	if context.stage then
		for _, item in context.stage:GetDescendants() do
			if item:IsDescendantOf(character) then
				continue
			end
			if item:IsA("BasePart") and item.Material == Enum.Material.Neon then
				table.insert(neon, { part = item, color = item.Color })
			elseif item:IsA("Light") then
				table.insert(
					lamps,
					{ light = item, brightness = item.Brightness, color = item.Color }
				)
			end
		end
	end
	Kit.onStop(function()
		for _, n in neon do
			n.part.Color = n.color
		end
		for _, l in lamps do
			l.light.Brightness = l.brightness
			l.light.Color = l.color
		end
	end)
	local function neonLevel(t: number): number
		if t < 0.12 then
			return 1
		elseif t < 0.17 then
			return 0.15
		elseif t < 0.22 then
			return 0.9
		end
		return 1 - span(t, 0.22, 0.32, "Linear")
	end
	local dead, warm = rgb(42, 34, 56), rgb(255, 196, 120)
	Kit.every(function(t)
		local n = neonLevel(t)
		for _, item in neon do
			item.part.Color = item.color:Lerp(dead, 1 - n)
		end
		for _, item in lamps do
			item.light.Brightness = item.brightness * (0.55 + 0.45 * n)
			item.light.Color = item.color:Lerp(warm, 1 - n)
		end
		return t > 0.4
	end)
	local quiet = table.clone(context)
	quiet.stage = nil
	Kit.darken(quiet, 0.3, 0.4)

	---------------------------------------------------------------- the overgrowth
	local grows: { Grow } = {}
	local function grow(from: number, dur: number, step: (number) -> ())
		table.insert(grows, { at = from, dur = dur, step = step, done = false })
	end
	local function startOf(position: Vector3): number
		local here = stage(position)
		return 0.12
			+ math.sqrt(here.X ^ 2 + ((here.Y - floorY) * 0.6) ^ 2 + here.Z ^ 2) * 0.05
			+ rnd(0, 0.25)
	end
	local function insideBlock(point: Vector3, pad: number): boolean
		for _, block in context.blocks do
			local here = block.CFrame:PointToObjectSpace(point)
			if
				math.abs(here.X) < block.Size.X / 2 + pad
				and math.abs(here.Z) < block.Size.Z / 2 + pad
			then
				return true
			end
		end
		return false
	end
	-- A floor spot (stage space x, z) clear of the blocks, or nil.
	local function floorAt(x: number, z: number): Vector3?
		local point = at(x, floorY, z)
		if insideBlock(point, 0.3) then
			return nil
		end
		return point
	end

	-- Moss: patches of soft discs spreading out on the floor, the block tops and fronts.
	local function mossPatch(center: Vector3, normal: Vector3, radius: number, starts: number)
		local count = math.random(5, 8)
		local across = if math.abs(normal.Y) > 0.5 then home.RightVector else Vector3.yAxis
		local side = normal:Cross(across).Unit
		for i = 1, count do
			local a, d = rnd(0, math.pi * 2), math.sqrt(random:NextNumber()) * radius
			local spot = center
				+ (across * math.cos(a) + side * math.sin(a)) * d
				+ normal * (0.04 + i * 0.004)
			local size = rnd(0.5, 1.1) * radius + 0.2
			-- (A disc's flat sides are its X ends: turn X onto the surface's normal.)
			local upHint = if math.abs(normal.Y) > 0.5 then look else Vector3.yAxis
			local disc = Kit.block(
				A(0.06, 0.05, 0.05),
				CFrame.lookAt(spot, spot + normal, upHint) * CFrame.Angles(0, math.rad(90), 0),
				MOSS[math.random(#MOSS)],
				Enum.Material.Grass,
				1,
				Enum.PartType.Cylinder
			)
			local base = disc.CFrame
			grow(starts + (d / radius) * 0.5, rnd(0.7, 1.3), function(u)
				local k = 1 - (1 - u) ^ 3
				disc.Transparency = 0
				disc.Size = A(0.06, math.max(size * k, 0.05), math.max(size * k, 0.05))
				disc.CFrame = base
			end)
		end
	end
	-- Grass: tufts of blades rising.
	local function tuft(base: Vector3, low: number, high: number, starts: number, blades: number?)
		for _ = 1, blades or math.random(4, 6) do
			local height = rnd(low, high)
			local bend = CFrame.Angles(rnd(-0.35, 0.35), rnd(0, 6), rnd(-0.35, 0.35))
			local foot = CFrame.new(
				base + home.RightVector * rnd(-0.38, 0.38) + look * rnd(-0.2, 0.2)
			) * bend
			local blade = Kit.block(A(0.1, 0.02, 0.04), foot, GRASS[math.random(#GRASS)], nil, 1)
			grow(starts + rnd(0, 0.3), 0.7, function(u)
				local h = height * (1 - (1 - u) ^ 3)
				blade.Transparency = 0
				blade.Size = A(0.1, math.max(h, 0.02), 0.04)
				blade.CFrame = foot * CFrame.new(0, h / 2, 0)
			end)
		end
	end
	-- Flowers: a stem rises and the bud opens petal by petal.
	local function flower(base: Vector3, stem: number, size: number, starts: number, dur: number?)
		local color = FLOWER[math.random(#FLOWER)]
		local count = if random:NextNumber() < 0.7 then 5 else 6
		local turn = rnd(0, math.pi * 2)
		local stalk = Kit.block(A(0.07, 0.02, 0.07), CFrame.new(base), rgb(70, 140, 50), nil, 1)
		local petals = {}
		for _ = 1, count do
			table.insert(petals, egg(A(0.3, 0.05, 0.17) * size, CFrame.new(base), color, nil, 1))
		end
		local heart = egg(A(0.12, 0.12, 0.12) * size, CFrame.new(base), CENTRE, nil, 1)
		grow(starts, dur or rnd(0.7, 1.1), function(u)
			local h = stem * span(u, 0, 0.5, "Out")
			stalk.Transparency = 0
			stalk.Size = A(0.07, math.max(h, 0.02), 0.07)
			stalk.CFrame = CFrame.new(base + A(0, h / 2, 0))
			local top = base + A(0, h, 0)
			local open = span(u, 0.45, 1, "Out")
			if u > 0.4 then
				heart.Transparency = 0
				heart.CFrame = CFrame.new(top)
				for i, petal in petals do
					petal.Transparency = 0
					local pitch = math.rad(78 - 66 * open)
					petal.CFrame = CFrame.new(top)
						* CFrame.Angles(0, turn + i * math.pi * 2 / count, 0)
						* CFrame.Angles(0, 0, pitch)
						* CFrame.new(0.15 * size, 0, 0)
				end
			end
		end)
	end
	-- Ferns: fronds unrolling from tight curls.
	local function fern(base: Vector3, length: number, starts: number)
		for k = 0, 4 do
			local yaw = rnd(0, math.pi * 2)
			local lean = (k - 2) * 0.12
			local pieces = {}
			for _ = 1, 4 do
				table.insert(
					pieces,
					egg(
						A(0.12, 0.05, 0.5) * (length / 1.8),
						CFrame.new(base),
						LEAF[math.random(#LEAF)],
						nil,
						1
					)
				)
			end
			grow(starts + math.abs(k - 2) * 0.12, rnd(1.0, 1.5), function(u)
				-- Starts nearly upright, arching out; the part not yet unrolled is a tight curl.
				local frame = CFrame.new(base)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(math.pi / 2 - 0.35 + lean, 0, 0)
				local step = length / #pieces
				for i, piece in pieces do
					piece.Transparency = 0
					local curl = if i / #pieces < u then -0.22 else -0.9
					frame *= CFrame.Angles(curl, 0, 0)
					piece.CFrame = frame * CFrame.new(0, 0, -step / 2)
					frame *= CFrame.new(0, 0, -step)
				end
			end)
		end
	end
	-- Vines: a stem climbing a wall (in the plane facing the camera) with leaves unfurling.
	local function vine(
		from: Vector3,
		length: number,
		starts: number,
		dur: number,
		top: number,
		left: number?,
		right: number?
	)
		local points = { from }
		local angle = math.pi / 2 + rnd(-0.35, 0.35)
		local wob, phase = rnd(0.6, 1.4), rnd(0, 6)
		local up, across = Vector3.yAxis, -home.RightVector -- (screen right)
		local x, y, s = 0, 0, 0
		local fromStage = stage(from)
		while s < length do
			angle += rnd(-0.16, 0.16) + (math.pi / 2 - angle) * 0.07 + math.sin(s * wob + phase) * 0.05
			if fromStage.Y + y > top - 0.6 then
				angle += if angle > math.pi / 2 then 0.25 else -0.25
			end
			if left and fromStage.X + x < left + 0.3 then
				angle -= 0.25
			end
			if right and fromStage.X + x > right - 0.3 then
				angle += 0.25
			end
			x += math.cos(angle) * 0.8
			y += math.sin(angle) * 0.8
			s += 0.8
			table.insert(points, from + across * x + up * y)
		end
		local stems = {}
		for i = 1, #points - 1 do
			table.insert(
				stems,
				Kit.block(A(0.12, 0.12, 0.05), CFrame.new(points[i]), rgb(56, 104, 36), nil, 1)
			)
		end
		local leaves = {}
		local side = 1
		for i = 2, #points - 1, 2 do
			local leaf = egg(
				A(0.6, 0.38, 0.05) * rnd(0.7, 1.2),
				CFrame.new(points[i]),
				LEAF[math.random(#LEAF)],
				nil,
				1
			)
			table.insert(leaves, { part = leaf, index = i, side = side, size = leaf.Size })
			side = -side
		end
		grow(starts, dur, function(u)
			local reached = u * #stems
			for i, stem in stems do
				local f = math.clamp(reached - (i - 1), 0, 1)
				if f > 0 then
					local a, b = points[i], points[i + 1]
					local tip = a:Lerp(b, f)
					stem.Transparency = 0
					stem.Size = A(0.12, 0.12, math.max((tip - a).Magnitude, 0.05))
					stem.CFrame = CFrame.lookAt((a + tip) / 2, tip)
				end
			end
			for _, leaf in leaves do
				local f = math.clamp((reached - leaf.index) / 2, 0, 1)
				if f > 0 then
					local p = points[leaf.index]
					leaf.part.Transparency = 0
					leaf.part.Size = leaf.size * (0.2 + 0.8 * f)
					leaf.part.CFrame = CFrame.new(p)
						* facing
						* CFrame.Angles(0, 0, leaf.side * (0.7 + 0.6 * (1 - f)))
						* CFrame.new(-leaf.side * leaf.part.Size.X * 0.45, 0, 0)
				end
			end
		end)
	end

	-- Lay it all out.
	local winnerFloor = at(0, floorY, 0)
	for _ = 1, 30 do
		local spot = floorAt(rnd(-22, 22), rnd(-10, 12))
		if spot then
			mossPatch(spot, Vector3.yAxis, rnd(0.9, 2.2), startOf(spot) * 0.8)
		end
	end
	for _ = 1, 26 do
		local spot = floorAt(rnd(-18, 18), rnd(4.3, 10.5))
		if spot then
			tuft(spot, 0.45, 1.2, startOf(spot) + 0.1)
		end
	end
	for _ = 1, 10 do
		local spot =
			floorAt((if random:NextNumber() < 0.5 then -1 else 1) * rnd(16, 28), rnd(-10, 4))
		if spot then
			tuft(spot, 0.6, 1.4, startOf(spot) + 0.1)
		end
	end
	for _ = 1, 14 do
		local spot = floorAt(rnd(-18, 18), rnd(4.4, 7))
		if spot then
			flower(spot, rnd(0.45, 1.1), rnd(0.9, 1.2), startOf(spot) + 0.5)
		end
	end
	for _, spot in
		{
			A(-5.4, 0, 4.7),
			A(5.4, 0, 4.6),
			A(-17, 0, 4.4),
			A(17, 0, 4.5),
			A(-21, 0, -3),
			A(21, 0, -2.5),
		}
	do
		local base = floorAt(spot.X, spot.Z)
		if base then
			fern(base, rnd(1.6, 2.4), startOf(base) + 0.2)
		end
	end
	-- The occasional new flower right through.
	for i = 0, 9 do
		local spot = floorAt(rnd(-18, 18), rnd(4.3, 7.5))
		if spot then
			flower(
				spot,
				rnd(0.45, 1.1),
				rnd(0.9, 1.15),
				2.6 + i * 0.8 + rnd(-0.2, 0.2),
				rnd(0.9, 1.4)
			)
		end
	end
	if onPodium then
		-- The backdrop wall (behind them) gets vines climbing it.
		local wallZ = -12.9
		for k = 0, 11 do
			local x = -28 + k * 5.1 + rnd(-1, 1)
			local from = at(x, floorY, wallZ)
			vine(
				from,
				rnd(8, 16),
				0.25 + math.abs(x) * 0.025 + rnd(0, 0.3),
				rnd(2.2, 3.6),
				floorY + 24
			)
		end
		for _, block in context.blocks do
			local first = block == context.block
			local starts = if first then 0.05 else 0.35
			local size = block.Size
			local frontCenter = block.Position + look * (size.Z / 2)
			local topCenter = block.Position + A(0, size.Y / 2, 0)
			-- Moss up the front and over the top, grass and flowers along the top's edge.
			for _ = 1, 7 do
				local spot = frontCenter
					+ home.RightVector * rnd(-size.X / 2 + 0.6, size.X / 2 - 0.6)
					+ A(0, rnd(-size.Y / 2 + 0.3, -size.Y / 2 + 1.6), 0)
				mossPatch(spot, look, rnd(0.6, 1.3), starts + rnd(0, 0.35))
			end
			for _ = 1, 3 do
				local spot = frontCenter
					+ home.RightVector * rnd(-size.X / 2 + 0.5, size.X / 2 - 0.5)
					+ A(0, size.Y / 2 - rnd(0.2, 0.6), 0)
				mossPatch(spot, look, rnd(0.45, 0.8), starts + rnd(0.6, 1.0))
			end
			for _ = 1, 6 do
				local spot = topCenter
					+ home.RightVector * rnd(-size.X / 2 + 0.5, size.X / 2 - 0.5)
					+ look * rnd(1.5, size.Z / 2 - 0.4)
				mossPatch(spot, Vector3.yAxis, rnd(0.5, 1.1), starts + rnd(0.15, 0.7))
			end
			for _ = 1, 5 do
				local spot = topCenter
					+ home.RightVector * rnd(-size.X / 2 + 0.6, size.X / 2 - 0.6)
					+ look * rnd(2.8, size.Z / 2 - 0.2)
				tuft(spot, 0.22, 0.5, starts + rnd(0, 0.6), math.random(3, 5))
			end
			for _ = 1, if first then 4 else 2 do
				local side = if random:NextNumber() < 0.5 then -1 else 1
				local spot = topCenter
					+ home.RightVector * side * rnd(1.4, size.X / 2 - 0.6)
					+ look * rnd(1, size.Z / 2 - 0.5)
				flower(spot, rnd(0.25, 0.45), rnd(0.6, 0.8), starts + 0.5 + rnd(0, 0.6))
			end
			-- Vines up the front.
			local frontStage = stage(frontCenter)
			for _, dx in { -size.X / 2 + rnd(0.5, 1.4), size.X / 2 - rnd(0.5, 1.4), rnd(-2, 2) } do
				local from = frontCenter
					+ home.RightVector * -dx
					- A(0, size.Y / 2, 0)
					+ look * 0.05
				vine(
					from,
					size.Y * rnd(0.7, 1.1),
					starts + rnd(0, 0.3),
					rnd(1.3, 2.0),
					frontStage.Y + size.Y / 2 - 0.1,
					frontStage.X - size.X / 2,
					frontStage.X + size.X / 2
				)
			end
		end
	end
	-- Run the growing.
	Kit.every(function(t)
		for _, item in grows do
			if not item.done and t >= item.at then
				local u = math.clamp((t - item.at) / item.dur, 0, 1)
				item.step(u)
				item.done = u >= 1
			end
		end
		return nil
	end)
	-- Pollen and soft light drifting, and leaves falling.
	local air = Kit.block(A(56, 20, 26), CFrame.new(at(0, floorY + 10, 0)) * facing, WHITE, nil, 1)
	local motes = Kit.emitter(air, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Color = ColorSequence.new(rgb(255, 222, 140), rgb(210, 255, 170)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.16, 0.06),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(0.3, 0.8),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 0,
	})
	Kit.at(0.4, function()
		motes.Rate = 30
	end)
	type Falling = {
		part: BasePart,
		x: number,
		z: number,
		period: number,
		offset: number,
		sway: number,
		spin: number,
		start: number,
	}
	local falling: { Falling } = {}
	for _ = 1, 10 do
		table.insert(falling, {
			part = egg(A(0.45, 0.05, 0.28), CFrame.new(), LEAF[math.random(#LEAF)], nil, 1),
			x = rnd(-22, 22),
			z = rnd(-8, 9),
			period = rnd(4.2, 6.2),
			offset = rnd(0, 6),
			sway = rnd(1, 2.4),
			spin = rnd(2, 4),
			start = 0.9 + rnd(0, 1.5),
		})
	end
	Kit.every(function(t)
		local still = if t > 3.45 and t < BURST then 3.45 elseif t >= BURST then t - 0.35 else t
		for _, leaf in falling do
			if t < leaf.start then
				continue
			end
			local k = ((still - leaf.start) / leaf.period + leaf.offset) % 1
			local y = floorY + 20 * (1 - k)
			leaf.part.Transparency = 0
			leaf.part.CFrame = CFrame.new(
				at(leaf.x + math.sin(still * 1.3 + leaf.offset) * leaf.sway, y, leaf.z)
			) * CFrame.Angles(
				math.sin(still * leaf.spin) * 0.8,
				still * 0.7,
				math.cos(still * leaf.spin) * 0.6
			)
		end
		return nil
	end)

	---------------------------------------------------------------- the silk and the cocoon
	local function hipY(t: number): number
		return 2 + lift(t)
	end
	type Thread = {
		pieces: { BasePart },
		phase: number,
		start: number,
		turns: number,
		top: number,
		dir: number,
	}
	local threads: { Thread } = {}
	for j = 0, 8 do
		local pieces = {}
		for _ = 1, 16 do
			table.insert(
				pieces,
				Kit.block(A(0.06, 0.06, 0.1), CFrame.new(), PEARL, Enum.Material.Neon, 1)
			)
		end
		table.insert(threads, {
			pieces = pieces,
			phase = j / 9 * math.pi * 2 + rnd(-0.2, 0.2),
			start = 0.6 + j * 0.045,
			turns = rnd(1.4, 1.9),
			top = rnd(1.5, 3.5),
			dir = if j % 3 == 0 then -1 else 1,
		})
	end
	-- The cocoon builds up in bands from the feet, then a smooth pearly shell with a sliding
	-- sheen, and a glow inside it for the heartbeat.
	local BANDS = 12
	local bands: { BasePart } = {}
	for _ = 1, BANDS do
		table.insert(
			bands,
			egg(A(0.1, 0.1, 0.1), CFrame.new(), PEARL, Enum.Material.SmoothPlastic, 1)
		)
	end
	local shell = egg(
		A(COCOON_W * 2, COCOON_H, COCOON_W * 1.75),
		CFrame.new(),
		PEARL,
		Enum.Material.SmoothPlastic,
		1
	)
	shell.Reflectance = 0.15
	local sheen = egg(
		A(COCOON_W * 2 + 0.12, COCOON_H + 0.12, COCOON_W * 1.75 + 0.12),
		CFrame.new(),
		rgb(215, 195, 255),
		Enum.Material.ForceField,
		1
	)
	local inner = egg(
		A(COCOON_W * 2 + 0.25, COCOON_H + 0.2, COCOON_W * 1.75 + 0.25),
		CFrame.new(),
		rgb(110, 90, 255),
		Enum.Material.Neon,
		1
	)
	local strands: { BasePart } = {}
	for _ = 1, 3 do
		table.insert(
			strands,
			Kit.block(A(0.04, 0.04, 12), CFrame.new(), PEARL, Enum.Material.Neon, 1)
		)
	end
	local heartLight = Instance.new("PointLight")
	heartLight.Color = rgb(130, 110, 255)
	heartLight.Range = 14
	heartLight.Brightness = 0
	heartLight.Parent = shell
	-- Cracks across the front of the shell, spreading in steps; each piece is a short glowing
	-- line laid on its surface.
	type Crack = { pieces: { BasePart }, points: { Vector2 }, at: number, grow: number }
	local cracks: { Crack } = {}
	local function addCracks(
		count: number,
		from: number,
		to: number,
		steps: number,
		low: number,
		high: number
	)
		for _ = 1, count do
			local u, v, a = rnd(-0.8, 0.8), rnd(low, high), rnd(0, math.pi * 2)
			local points = { Vector2.new(u, v) }
			for _ = 1, steps + math.random(0, 2) do
				a += rnd(-0.55, 0.55)
				u = math.clamp(u + math.cos(a) * 0.13, -0.95, 0.95)
				v = math.clamp(v + math.sin(a) * 0.05, 0.04, 0.96)
				table.insert(points, Vector2.new(u, v))
			end
			local pieces = {}
			for _ = 1, #points - 1 do
				table.insert(
					pieces,
					Kit.block(
						A(0.05, 0.05, 0.1),
						CFrame.new(),
						rgb(175, 165, 255),
						Enum.Material.Neon,
						1
					)
				)
			end
			table.insert(
				cracks,
				{ pieces = pieces, points = points, at = rnd(from, to), grow = rnd(0.12, 0.3) }
			)
		end
	end
	addCracks(3, 2.47, 2.55, 2, 0.35, 0.7)
	addCracks(5, 2.88, 2.96, 3, 0.2, 0.85)
	addCracks(6, 3.25, 3.33, 4, 0.1, 0.9)
	addCracks(16, 3.4, 3.62, 5, 0.04, 0.96)
	local function onShell(t: number, u: number, v: number): Vector3
		local width = cocoonWidth(v)
		local x = u * width * 0.95
		local depth = math.sqrt(math.max(width * width - x * x, 0)) * 0.875
		return at(x, hipY(t) - 2.5 + v * COCOON_H, depth + 0.05)
	end
	-- Hide the winner inside it once it's closed, and bring them back at the burst.
	Kit.at(2.1, function()
		Kit.fade(character, 1)
	end)
	Kit.every(function(t)
		if t < 0.6 then
			return nil
		end
		local bottom = hipY(t) - 2.5
		local wrap = span(t, 1.2, 2.2)
		-- Silk threads spiralling up, then drawing in to the cocoon.
		for _, thread in threads do
			local climb = span(t, thread.start, thread.start + 0.6, "Out")
			local fade = span(t, 2.1, 2.3)
			for i, piece in thread.pieces do
				local s0, s1 = (i - 1) / #thread.pieces, i / #thread.pieces
				local function spot(s: number): Vector3
					local height = s * (thread.top + 2) * climb
					local v = math.clamp((height + 0.5) / COCOON_H, 0.02, 0.98)
					local radius = 2.6 + (cocoonWidth(v) + 0.06 - 2.6) * wrap
					local angle = thread.phase
						+ thread.dir * thread.turns * math.pi * 2 * s
						+ t * 1.4
					return at(
						math.cos(angle) * radius,
						bottom + 0.5 + height,
						math.sin(angle) * radius * 0.85
					)
				end
				local a, b = spot(s0), spot(s1)
				piece.Transparency = if climb > 0 then 0.25 + 0.75 * fade else 1
				piece.Size = A(0.06, 0.06, math.max((b - a).Magnitude, 0.02))
				piece.CFrame = CFrame.lookAt((a + b) / 2, b)
			end
		end
		-- The bands, built up from the feet.
		local closed = span(t, 2.0, 2.15)
		for i, band in bands do
			local v = (i - 0.5) / BANDS
			local grown = span(t, 1.25 + (i - 1) * 0.07, 1.25 + (i - 1) * 0.07 + 0.25, "Out")
			if t >= BURST then
				band.Transparency = 1
			elseif grown > 0 then
				local width = cocoonWidth(v) * 2 * (0.3 + 0.7 * grown) + 0.08
				band.Transparency = closed
				band.Size = A(width, COCOON_H / BANDS * 1.7, width * 0.87)
				band.CFrame = CFrame.new(at(0, bottom + v * COCOON_H, 0))
					* facing
					* CFrame.Angles(0, t * 0.6 + i, 0)
			end
		end
		local center = CFrame.new(at(0, bottom + COCOON_H / 2, 0)) * facing
		local glow = glowOf(t)
		local whole = if t >= BURST then 1 else 1 - closed
		shell.Transparency = whole
		shell.CFrame = center
		shell.Color = PEARL:Lerp(rgb(200, 190, 255), math.min(glow, 1) * 0.5)
		sheen.Transparency = if t >= BURST then 1 else 1 - closed * 0.6
		sheen.CFrame = center * CFrame.Angles(0, t * 0.5, 0)
		inner.Transparency = if t >= BURST then 1 else 1 - math.min(glow, 1.25) * 0.4
		inner.CFrame = center
		heartLight.Brightness = if t >= BURST then 0 else glow * 3
		-- Hanging on a few strands of silk once it lifts.
		local hang = span(t, 2.2, 2.4)
		for i, strand in strands do
			local top = at((i - 2) * 0.5, bottom + COCOON_H + 6, 0)
			local foot = at((i - 2) * 0.4, bottom + COCOON_H - 0.2, 0)
			strand.Transparency = if t >= BURST or hang <= 0 then 1 else 1 - 0.65 * hang
			strand.CFrame = CFrame.lookAt((top + foot) / 2, foot)
		end
		-- The cracks.
		for _, crack in cracks do
			local grown = math.clamp((t - crack.at) / crack.grow, 0, 1)
			local reach = grown * (#crack.points - 1)
			for i, piece in crack.pieces do
				local f = math.clamp(reach - (i - 1), 0, 1)
				if t >= BURST or f <= 0 then
					piece.Transparency = 1
				else
					local p0, p1 = crack.points[i], crack.points[i + 1]
					local q = p0:Lerp(p1, f)
					local a, b = onShell(t, p0.X, p0.Y), onShell(t, q.X, q.Y)
					piece.Transparency = 0
					piece.Size = A(0.05, 0.05, math.max((b - a).Magnitude, 0.02))
					piece.CFrame = CFrame.lookAt((a + b) / 2, b)
				end
			end
		end
		return t > BURST + 0.1
	end)
	Kit.at(3.4, function()
		Kit.shake(0.6, 0.3)
	end)

	---------------------------------------------------------------- the burst and the wings
	Kit.at(BURST, function()
		Kit.flash(rgb(150, 150, 255), 0.35, 0.5)
		Kit.shake(1.6, 0.4)
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = 0
			end
		end
	end)
	local wings = { right = makeWing(false), left = makeWing(true) }
	local dust: { ParticleEmitter } = {}
	for _, wing in { wings.right, wings.left } do
		table.insert(
			dust,
			Kit.emitter(wing.panel, {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Shape = Enum.ParticleEmitterShape.Box,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rgb(70, 150, 255)),
					ColorSequenceKeypoint.new(0.5, rgb(60, 230, 215)),
					ColorSequenceKeypoint.new(1, rgb(155, 105, 255)),
				}),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.2, 0.18, 0.06),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new(0.2, 1),
				Lifetime = NumberRange.new(1.4, 2.2),
				Speed = NumberRange.new(0.3, 0.8),
				Acceleration = A(0, -0.8, 0),
				EmissionDirection = Enum.NormalId.Bottom,
				Rate = 0,
			})
		)
	end
	Kit.at(4.05, function()
		for _, emitter in dust do
			emitter.Rate = 30
		end
	end)
	local wingGlow = egg(A(1, 1, 0.05), CFrame.new(), rgb(80, 110, 255), Enum.Material.Neon, 1)
	local hidden = CFrame.new(at(0, -200, 0))
	Kit.every(function(t)
		if t < 3.88 then
			wings.right.panel.CFrame = hidden
			wings.left.panel.CFrame = hidden
			wingGlow.CFrame = hidden
			return nil
		end
		local u = span(t, UNFOLD, 4.95)
		local open = 1 - (1 - u) ^ 3
		local wide = 0.1 + 0.9 * u
		local tall = 0.4 + 0.6 * u ^ 0.7
		local f = flapOf(t)
		local turn = -1.15 + 1.15 * open + 0.2 * (1 - f)
		wide *= f
		local sx, sy = math.max(WING * wide, 0.1), math.max(WING * WING_TALL * tall, 0.1)
		-- Hinged at the upper back, just behind the body.
		local anchor = CFrame.new(at(0, hipY(t) + 2 - 0.55, -0.7)) * facing
		wings.right.panel.Size = A(sx, sy * 2, 0.05)
		wings.left.panel.Size = A(sx, sy * 2, 0.05)
		-- (Screen right is the anchor's -X; a turn up on screen is a turn about -Z for that wing.)
		wings.right.panel.CFrame = anchor * CFrame.Angles(0, 0, -turn) * CFrame.new(-sx / 2, 0, 0)
		wings.left.panel.CFrame = anchor * CFrame.Angles(0, 0, turn) * CFrame.new(sx / 2, 0, 0)
		local slide = 0.08 * math.sin(t * 0.9)
		for _, wing in { wings.right, wings.left } do
			for _, gradient in wing.gradients do
				gradient.Offset = Vector2.new(slide, 0)
			end
		end
		wingGlow.Transparency = 1 - 0.18 * span(t, 3.88, 4.2)
		wingGlow.Size = A(math.max(18 * wide, 1), 12 * tall, 0.05)
		wingGlow.CFrame = anchor * CFrame.new(0, 0, 0.4)
		return nil
	end)
	-- 4.8: the first flap sends a ring of light out across the stage.
	Kit.at(RING, function()
		local center = at(0, hipY(RING) + 1, 0)
		Kit.ring(
			center,
			rgb(140, 200, 255),
			46,
			1.2,
			(CFrame.lookAt(center, workspace.CurrentCamera.CFrame.Position) * CFrame.Angles(
				0,
				math.pi / 2,
				0
			)).Rotation
		)
		Kit.ring(winnerFloor + A(0, 0.12, 0), rgb(120, 220, 230), 40, 1.1)
	end)

	---------------------------------------------------------------- the butterflies
	local butterflies: { Butterfly } = {}
	local COUNT = 180
	local burstBottom = hipY(BURST) - 2.5
	for i = 1, COUNT do
		local v, a = rnd(0.06, 0.94), rnd(0, math.pi * 2)
		local width = cocoonWidth(v)
		local origin =
			A(math.cos(a) * width, burstBottom + v * COCOON_H, math.sin(a) * width * 0.85)
		local out = A(math.cos(a) * rnd(0.6, 1.2), rnd(-0.55, 0.95), rnd(-0.45, 1.0)).Unit
		local roams = random:NextNumber() < 0.28
		local lands = i == 1
		local size = if lands then 1.05 else rnd(0.5, 0.95)
		local gui, point, halves, flake, parts =
			makeButterfly(size, MORPHO[if lands then 3 else math.random(#MORPHO)], folder)
		local wave = WAVES[(i - 1) % #WAVES + 1] + rnd(0, 0.28)
		table.insert(butterflies, {
			gui = gui,
			point = point,
			halves = halves,
			flake = flake,
			wings = parts,
			origin = origin,
			out = out,
			reach = rnd(5, 19),
			time = rnd(0.8, 1.5),
			phase = rnd(0, math.pi * 2),
			radius = if roams then rnd(13, 21) else rnd(6.5, 12.5),
			spin = (if roams then rnd(0.35, 0.6) else rnd(0.7, 1.3))
				* (if random:NextNumber() < 0.85 then 1 else -1)
				* (if roams then 1 else 0.87),
			start = rnd(0, math.pi * 2),
			height = if roams then rnd(-6, 11) else rnd(-4.5, 7.5),
			blend = rnd(0, 0.5),
			squash = if roams then 0.55 else 0.8,
			beat = rnd(5.2, 7.8),
			beatPhase = rnd(0, math.pi * 2),
			lands = lands,
			wave = wave,
			waveTime = math.min(rnd(0.75, 1.0), LAST_GONE - wave),
			target = nil,
			arc = rnd(-1.5, 2.5),
			shown = false,
		})
	end
	-- Where a butterfly is (stage space) while it bursts out, then circles the winner.
	local function burstOut(b: Butterfly, t: number): Vector3
		local u = math.clamp((t - BURST) / b.time, 0, 1)
		local e = 1 - (1 - u) ^ 3
		return b.origin
			+ b.out * b.reach * e
			+ A(math.sin(t * 1.3 + b.phase) * 0.6 * e, math.cos(t * 1.1 + b.phase) * 0.5 * e, 0)
	end
	local function circling(b: Butterfly, t: number): Vector3
		local tt = math.max(0, t - 4.75)
		local r = b.radius * (1 + 0.55 * math.exp(-tt * 1.4))
		local th = b.start + b.spin * tt
		return A(
			r * math.cos(th),
			hipY(t) + 1 + b.height + 0.6 * math.sin(2 * th + b.phase),
			math.clamp(r * math.sin(th) * b.squash, -11, 18)
		)
	end
	local function flying(b: Butterfly, t: number): Vector3
		local a = burstOut(b, t)
		local s = 4.75 + b.blend
		if t <= s then
			return a
		end
		return a:Lerp(circling(b, t), span(t, s, s + 1.3))
	end
	-- Where the landing butterfly sits: just above the raised right hand.
	local function onHand(): Vector3
		local hand = Kit.part(character, "RightHand")
		return stage((if hand then hand.Position else root.Position) + A(0, 0.62, 0)) + A(0, 0, 0.3)
	end
	local function placeOf(b: Butterfly, t: number): Vector3?
		if t < BURST then
			return nil
		end
		if b.lands then
			if t < 5.75 then
				return flying(b, t)
			elseif t < 6.35 then
				local s, h = flying(b, 5.75), onHand()
				local u = span(t, 5.75, 6.35)
				local c = (s + h) / 2 + A(1.5, math.max(s.Y, h.Y) - (s.Y + h.Y) / 2 + 2.5, 0)
				return s * (1 - u) ^ 2 + c * 2 * u * (1 - u) + h * u * u
			elseif t < LEAVE then
				return onHand()
			end
			local u = (t - LEAVE) / 1.5
			if u >= 1 then
				return nil
			end
			return onHand() + A(7 * u ^ 1.4 + math.sin(u * 9) * 0.3, 6 * u ^ 1.2, 16 * u * u)
		end
		if t >= b.wave then
			local u = (t - b.wave) / b.waveTime
			if u >= 1 then
				return nil
			end
			if not b.target then
				-- Out past the camera, somewhere round the edge of the view.
				local camera = stage(workspace.CurrentCamera.CFrame.Position)
				local angle, off = rnd(0, math.pi * 2), rnd(3, 7)
				b.target = camera + A(math.cos(angle) * off * 1.3, math.sin(angle) * off * 0.8, 3)
			end
			local s = flying(b, b.wave)
			local e = u ^ 1.7
			return s:Lerp(b.target :: Vector3, e) + A(0, math.sin(u * math.pi) * b.arc, 0)
		end
		return flying(b, t)
	end
	-- How open a butterfly's wings are (1 open, smaller closing up).
	local function beat(b: Butterfly, t: number): number
		if b.lands and t >= 6.35 and t < LEAVE then
			return 0.3 + 0.7 * (0.5 + 0.5 * math.cos(math.pi * 2 * (t - 6.35) / 1.9))
		end
		return 0.16 + 0.84 * (0.5 + 0.5 * math.cos(math.pi * 2 * b.beat * t + b.beatPhase))
	end
	Kit.every(function(t)
		if t < BURST then
			return nil
		end
		local view = workspace.CurrentCamera.CFrame
		-- The winner's body on screen (kept clear of butterflies in front of them).
		local body = view:PointToObjectSpace(root.Position + A(0, 0.2, 0))
		local bodyDepth = -body.Z
		for _, b in butterflies do
			local place = placeOf(b, t)
			if not place then
				b.gui.Enabled = false
				continue
			end
			local world = at(place.X, place.Y, place.Z)
			if not b.lands then
				local here = view:PointToObjectSpace(world)
				local depth = -here.Z
				if depth > 0.5 and depth < bodyDepth + 1.5 then
					local px, py = here.X / depth, here.Y / depth
					local bx, by = body.X / bodyDepth, body.Y / bodyDepth
					local halfW, halfH = 2.2 / bodyDepth, 3.4 / bodyDepth
					if math.abs(px - bx) < halfW and math.abs(py - by) < halfH then
						local push = (halfW - math.abs(px - bx))
							* depth
							* (if px >= bx then 1 else -1)
						world += view.RightVector * push
					end
				end
			end
			b.point.WorldPosition = world
			b.gui.Enabled = true
			-- A pearl flake for a moment, then the butterfly.
			local morph = span(t, BURST + 0.05, BURST + 0.3)
			b.flake.BackgroundTransparency = morph
			for _, part in b.wings do
				part.Visible = morph > 0.05
			end
			local open = beat(b, t) * morph
			for _, half in b.halves do
				half.Size = UDim2.fromScale(0.5 * math.max(open, 0.05), 1)
			end
		end
		return nil
	end)
	-- Petals drifting down near the end.
	Kit.at(6.6, function()
		local sky =
			Kit.block(A(44, 1, 20), CFrame.new(at(0, floorY + 20, 2)) * facing, WHITE, nil, 1)
		Kit.emitter(sky, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Shape = Enum.ParticleEmitterShape.Box,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, FLOWER[1]),
				ColorSequenceKeypoint.new(0.5, FLOWER[2]),
				ColorSequenceKeypoint.new(1, FLOWER[3]),
			}),
			LightEmission = 0.3,
			Size = NumberSequence.new(0.22),
			Transparency = NumberSequence.new(0.1, 0.6),
			Lifetime = NumberRange.new(6, 8),
			Speed = NumberRange.new(1, 1.8),
			RotSpeed = NumberRange.new(-120, 120),
			Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 3,
		})
	end)
end

return Chrysalis
