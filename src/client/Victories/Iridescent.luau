--!strict
-- The Iridescent victories: they take over the whole screen. Rift is here; Chrysalis has its own
-- module (Victories/Chrysalis). See docs/polish/victories.md for the beats.
local Kit = require(script.Parent.Kit)

type Context = Kit.Context
type Key = Kit.Key

local Iridescent = {}

local function A(x: number, y: number?, z: number?): Vector3
	return Vector3.new(x, y or 0, z or 0)
end

local WHITE = Color3.new(1, 1, 1)

-- A part's CFrame turned to face the camera (a Cylinder's flat side, which is its X axis).
local function facingCamera(position: Vector3): CFrame
	return CFrame.lookAt(position, workspace.CurrentCamera.CFrame.Position)
		* CFrame.Angles(0, math.pi / 2, 0)
end

---------------------------------------------------------------------------- Rift

local PINK = Color3.fromRGB(255, 64, 150)
local ROSE = Color3.fromRGB(255, 140, 200)
local PALE = Color3.fromRGB(255, 215, 235)
local SPACE = Color3.fromRGB(5, 7, 18)
local DEEP = Color3.fromRGB(200, 30, 120)
-- The burst's pink-reds (the reference: a whole view of pink-red points of light).
local CORAL = Color3.fromRGB(255, 96, 128)
local BLUSH = Color3.fromRGB(255, 160, 178)
local RED = Color3.fromRGB(220, 44, 82)

local FLOAT = {
	RightUpperArm = A(30, 0, 50),
	RightLowerArm = A(30),
	LeftUpperArm = A(20, 0, -45),
	LeftLowerArm = A(35),
	RightUpperLeg = A(20, 0, 10),
	RightLowerLeg = A(-30),
	LeftUpperLeg = A(-10, 0, -8),
	LeftLowerLeg = A(-20),
	UpperTorso = A(5),
	Head = A(10),
}

local RIFT: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.35,
		angles = { RightUpperArm = A(160, 0, 15), RightLowerArm = A(10), Head = A(15) },
	},
	{
		time = 0.55,
		angles = { RightUpperArm = A(40, 0, -45), UpperTorso = A(0, -15, 0) },
		ease = "In",
	},
	{ time = 1.0, angles = {} },
	{
		-- Pulled in: arms and legs flung out.
		time = 1.3,
		angles = {
			RightUpperArm = A(120, 0, 60),
			LeftUpperArm = A(120, 0, -60),
			RightLowerArm = A(0),
			UpperTorso = A(15),
			RightUpperLeg = A(-20),
			LeftUpperLeg = A(-20),
			Head = A(10),
		},
	},
	{ time = 2.0, angles = {} },
	{ time = 2.4, angles = FLOAT, ease = "Out" },
	{ time = 4.0, angles = {} },
	{
		time = 4.6,
		angles = { RightUpperArm = A(10, 0, 70), LeftUpperArm = A(10, 0, -70), Head = A(20) },
	},
}

-- Slices open a tear in space, gets pulled into it, and floats in deep space: a pink shooting
-- star streaks past and a supernova erupts behind them in wisps of plasma and drifting light.
function Iridescent.Rift(context: Context)
	local character = context.character
	local home = context.home
	local hand = Kit.part(character, "RightHand")
	local riftAt = home * CFrame.new(-4.5, 0.6, 2.5)
	local facing = CFrame.new(riftAt.Position) * home.Rotation
	-- The shooting star's long path from far right to the left; it bursts at its end (STRIKE),
	-- high behind them on the left.
	local starFrom = (home * CFrame.new(120, 36, 70)).Position
	local starBend = (home * CFrame.new(50, 48, 70)).Position
	local starTo = (home * CFrame.new(-14, 20, 70)).Position
	local function along(u: number): Vector3
		return starFrom:Lerp(starBend, u):Lerp(starBend:Lerp(starTo, u), u)
	end
	local STAR_START, STAR_TIME, BURST_AT = 2.4, 1.4, 1
	local STRIKE = STAR_START + STAR_TIME * BURST_AT
	local NOVA = CFrame.new(along(BURST_AT))
	-- The blast's shockwave pushes them away from it: forward toward the camera, a little down
	-- and to the right of the screen (their left, -X), into the emptier space.
	local PUSH = A(-3, -1.6, -4.5)
	local HOVER = A(0, 2.5, 0)
	local function pushed(t: number): Vector3
		return PUSH * Kit.span(t, STRIKE, STRIKE + 2.4, "Out")
	end

	-- Energy gathering in the raised hand.
	local energy = Kit.block(A(0.25, 0.25, 2.4), CFrame.new(), PINK, Enum.Material.Neon, 1)
	-- The tear: two jagged glowing edges with darkness and stars between them.
	local points = 11
	local jag = {}
	for i = 1, points do
		jag[i] = Kit.rnd(0.7, 1.3)
	end
	local edges: { BasePart } = {}
	for _ = 1, (points - 1) * 2 do
		table.insert(
			edges,
			Kit.block(A(0.18, 0.18, 0.1), CFrame.new(), PINK, Enum.Material.Neon, 1)
		)
	end
	local fills: { BasePart } = {}
	for _ = 1, points do
		table.insert(
			fills,
			Kit.block(A(0.1, 0.1, 0.08), CFrame.new(), SPACE, Enum.Material.Neon, 1)
		)
	end
	local core = Kit.block(A(1, 5, 0.3), facing * CFrame.new(0, 0, -0.1), WHITE, nil, 1)
	local riftStars = Kit.emitter(core, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Shape = Enum.ParticleEmitterShape.Box,
		Color = ColorSequence.new(WHITE, ROSE),
		Size = NumberSequence.new(0.12, 0),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(0.2, 0.6),
		Rate = 0,
		ZOffset = 1,
	})
	local function riftSize(t: number): (number, number)
		local h = 6.5 * Kit.span(t, 0.55, 0.85, "Out") * (1 - Kit.span(t, 1.95, 2.08, "In"))
		local w = 0.6 + 2.2 * Kit.span(t, 1.0, 1.4)
		return w, h
	end
	Kit.every(function(t)
		if hand then
			local on = Kit.span(t, 0.1, 0.35) * (1 - Kit.span(t, 0.55, 0.7))
			energy.Transparency = 1 - on
			energy.CFrame = hand.CFrame
				* CFrame.Angles(math.rad(-90), 0, 0)
				* CFrame.new(0, 0, -1.4)
		end
		local w, h = riftSize(t)
		local open = h > 0.05
		riftStars.Rate = if open then 40 else 0
		local function edge(i: number, side: number): Vector3
			local u = (i - 1) / (points - 1)
			local x = side
				* math.sin(math.pi * u)
				* w
				/ 2
				* jag[if side > 0 then i else points + 1 - i]
			return (facing * CFrame.new(x, -h / 2 + h * u, 0)).Position
		end
		local n = 0
		for _, side in { -1, 1 } do
			for i = 1, points - 1 do
				n += 1
				local part = edges[n]
				local a, b = edge(i, side), edge(i + 1, side)
				part.Transparency = if open then 0 else 1
				part.Size = A(0.18, 0.18, math.max((b - a).Magnitude, 0.05))
				part.CFrame = CFrame.lookAt((a + b) / 2, b)
			end
		end
		for i, fill in fills do
			local u = (i - 0.5) / points
			local across = math.sin(math.pi * u) * w * 0.9
			fill.Transparency = if open then 0 else 1
			fill.Size = A(math.max(across, 0.05), math.max(h / points * 1.05, 0.05), 0.08)
			fill.CFrame = facing * CFrame.new(0, -h / 2 + h * u, 0.05)
		end
		core.Size = A(math.max(w * 0.5, 0.1), math.max(h * 0.8, 0.1), 0.3)
		return t > 2.2
	end)
	Kit.at(0.55, function()
		Kit.flash(ROSE, 0.35, 0.3)
		Kit.shake(1, 0.3)
	end)
	-- The pull: motes stream into the tear, and the winner is dragged in, tumbling, and gone.
	Kit.react(context, "Shield", 1.0)
	local pullTo = CFrame.new(-4.5, 0.6, 2.5)
	Kit.every(function(t)
		if t < 1.0 then
			return nil
		end
		if t < 1.9 and math.random() < 0.6 then
			local from = riftAt.Position + A(Kit.rnd(-10, 10), Kit.rnd(-4, 6), Kit.rnd(-8, 4))
			local mote = Kit.block(
				A(0.16, 0.16, 0.9),
				CFrame.lookAt(from, riftAt.Position),
				if math.random() < 0.5 then PINK else PALE,
				Enum.Material.Neon
			)
			local begun = t
			Kit.every(function(now)
				local u = Kit.span(now, begun, begun + 0.5, "In")
				local at = from:Lerp(riftAt.Position, u)
				mote.CFrame = CFrame.lookAt(at, riftAt.Position)
				if u >= 1 then
					mote:Destroy()
					return true
				end
				return nil
			end)
		end
		local hidden = Kit.span(t, 1.6, 1.95)
		local back = Kit.span(t, 2.1, 2.4)
		local transparency = if t < 2.05 then hidden else 1 - back
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = transparency
			end
		end
		return t > 2.45
	end)
	Kit.onStop(function()
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = 0
			end
		end
	end)
	Kit.pose(character, RIFT, context.hold)
	Kit.move(context, function(t)
		if t < 2.05 then
			local u = Kit.span(t, 1.0, 1.95, "In")
			return CFrame.new():Lerp(pullTo, u)
				* CFrame.Angles(math.rad(40) * u, math.pi * 3 * u, math.rad(25) * u)
		end
		-- Floating in space, drifting and turning slowly; the blast shoves them and knocks them
		-- back a little, then they settle.
		local kick = Kit.span(t, STRIKE, STRIKE + 0.45, "Out")
			* (1 - Kit.span(t, STRIKE + 0.45, STRIKE + 3))
		return CFrame.new(HOVER + pushed(t) + A(0, math.sin(t * 0.9) * 0.3, 0))
			* CFrame.Angles(
				math.rad(10 * math.sin(t * 0.5) - 14 * kick),
				math.rad(20 * math.sin(t * 0.3)),
				math.rad(14 * math.sin(t * 0.4) + 12 * kick)
			)
	end)
	Kit.tilt(function(t)
		return 3 * Kit.span(t, 2.1, 2.6)
	end)

	-- Deep space: the stage goes, dark blue-black and stars all round.
	local spaceBloom: BloomEffect? = nil
	-- A huge green planet fills the view behind them (the reference clip's): swirling toxic-green
	-- bands, a rusty storm, darker toward its night side, a glowing lime rim across the top. It's
	-- painted on one flat disc turned to the camera (so far off it reads as a ball), so nothing
	-- sticks out of it.
	type Planet = { gui: SurfaceGui, haze: Frame, flow: Frame }
	local planet: Planet? = nil
	local function makePlanet(): Planet
		local camera = workspace.CurrentCamera.CFrame.Position
		local spot = (home * CFrame.new(-60, -360, 400)).Position
		local board = Kit.block(A(1000, 1000, 1), CFrame.lookAt(spot, camera), WHITE, nil, 1)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(1024, 1024)
		gui.LightInfluence = 0
		gui.Brightness = 1.2
		gui.Parent = board
		local function circle(
			parent: Instance,
			size: Vector2,
			at: Vector2,
			color: Color3,
			transparency: number,
			rotation: number?
		): Frame
			local frame = Instance.new("Frame")
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Size = UDim2.fromScale(size.X, size.Y)
			frame.Position = UDim2.fromScale(at.X, at.Y)
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = transparency
			frame.BorderSizePixel = 0
			frame.Rotation = rotation or 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = frame
			frame.Parent = parent
			return frame
		end
		local function gradient(
			parent: Instance,
			rotation: number,
			color: ColorSequence?,
			transparency: NumberSequence?
		)
			local g = Instance.new("UIGradient")
			g.Rotation = rotation
			if color then
				g.Color = color
			end
			if transparency then
				g.Transparency = transparency
			end
			g.Parent = parent
		end
		local function stroke(
			parent: Instance,
			thickness: number,
			transparency: number,
			rotation: number
		)
			local line = Instance.new("UIStroke")
			line.Color = Color3.fromRGB(184, 255, 72)
			line.Thickness = thickness
			line.Transparency = transparency
			line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			line.Parent = parent
			-- Bright along the top (the lit edge), gone toward the bottom.
			gradient(
				line,
				rotation,
				nil,
				NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.45, 0.5),
					NumberSequenceKeypoint.new(0.7, 1),
					NumberSequenceKeypoint.new(1, 1),
				})
			)
		end
		local DISC = 0.9 -- of the canvas (room round it for the glow)
		local middle = Vector2.new(0.5, 0.5)
		-- The atmosphere's glow just outside the rim.
		local halo =
			circle(gui, Vector2.new(DISC + 0.02, DISC + 0.02), middle, Color3.new(0, 0, 0), 1)
		stroke(halo, 22, 0.55, 100)
		-- The ground colour: lit lime-green top right, dark green to black bottom left.
		local base = circle(gui, Vector2.new(DISC, DISC), middle, WHITE, 0)
		gradient(
			base,
			125,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 206, 48)),
				ColorSequenceKeypoint.new(0.35, Color3.fromRGB(52, 136, 34)),
				ColorSequenceKeypoint.new(0.7, Color3.fromRGB(18, 62, 18)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 14, 6)),
			})
		)
		-- Swirling cloud bands, drawn as many thin streaks along curves (kept inside the disc).
		local flow = Instance.new("Frame")
		flow.BackgroundTransparency = 1
		flow.AnchorPoint = Vector2.new(0.5, 0.5)
		flow.Position = UDim2.fromScale(0.5, 0.5)
		flow.Size = UDim2.fromScale(1, 1)
		flow.Parent = gui
		local reach = DISC / 2 - 0.02
		local function streak(
			at: Vector2,
			length: number,
			width: number,
			angle: number,
			color: Color3,
			transparency: number
		)
			if (at - middle).Magnitude + length / 2 > reach then
				return
			end
			circle(flow, Vector2.new(length, width), at, color, transparency, math.deg(angle))
		end
		local greens = {
			Color3.fromRGB(150, 226, 66),
			Color3.fromRGB(96, 176, 46),
			Color3.fromRGB(34, 92, 26),
			Color3.fromRGB(16, 52, 16),
		}
		-- Long bands curving round the planet.
		for band = 1, 22 do
			local radius = Kit.rnd(0.06, reach - 0.02)
			local start = Kit.rnd(0, math.pi * 2)
			local sweep = Kit.rnd(0.6, 1.6)
			local color = greens[math.random(#greens)]
			local width = Kit.rnd(0.008, 0.03)
			for k = 0, 14 do
				local a = start + sweep * k / 14
				local wobble = 0.012 * math.sin(k * 0.9 + band)
				local at = middle + Vector2.new(math.cos(a), math.sin(a)) * (radius + wobble)
				streak(at, radius * sweep / 10, width, a + math.pi / 2, color, Kit.rnd(0.35, 0.6))
			end
		end
		-- Eddies: tight curls winding inward.
		for _ = 1, 16 do
			local center = middle + Vector2.new(Kit.rnd(-0.3, 0.3), Kit.rnd(-0.3, 0.3))
			local radius = Kit.rnd(0.03, 0.08)
			local start = Kit.rnd(0, math.pi * 2)
			local color = greens[math.random(#greens)]
			for k = 0, 16 do
				local a = start + k * 0.45
				local r = radius * (1 - k / 22)
				local at = center + Vector2.new(math.cos(a), math.sin(a)) * r
				streak(at, r * 0.7, 0.01, a + math.pi / 2, color, 0.45)
			end
		end
		-- The rusty storm on the right, with darker cores and its own curls.
		local rustAt = Vector2.new(0.66, 0.5)
		circle(flow, Vector2.new(0.34, 0.28), rustAt, Color3.fromRGB(146, 70, 26), 0.35, -20)
		circle(
			flow,
			Vector2.new(0.22, 0.17),
			rustAt + Vector2.new(0.02, 0.02),
			Color3.fromRGB(118, 44, 20),
			0.3,
			-10
		)
		circle(
			flow,
			Vector2.new(0.12, 0.09),
			rustAt + Vector2.new(-0.03, 0.04),
			Color3.fromRGB(82, 30, 16),
			0.3,
			15
		)
		for _ = 1, 10 do
			local center = rustAt + Vector2.new(Kit.rnd(-0.12, 0.12), Kit.rnd(-0.1, 0.1))
			local radius = Kit.rnd(0.025, 0.06)
			local start = Kit.rnd(0, math.pi * 2)
			local color = if math.random() < 0.5
				then Color3.fromRGB(196, 108, 40)
				else Color3.fromRGB(96, 34, 16)
			for k = 0, 14 do
				local a = start + k * 0.5
				local r = radius * (1 - k / 20)
				streak(
					center + Vector2.new(math.cos(a), math.sin(a)) * r,
					r * 0.7,
					0.009,
					a + math.pi / 2,
					color,
					0.4
				)
			end
		end
		-- The night side: darker toward the bottom left.
		local shade = circle(gui, Vector2.new(DISC, DISC), middle, Color3.new(0, 0, 0), 0)
		gradient(
			shade,
			125,
			nil,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.75),
				NumberSequenceKeypoint.new(0.8, 0.25),
				NumberSequenceKeypoint.new(1, 0.05),
			})
		)
		-- The lit rim.
		local rim = circle(gui, Vector2.new(DISC, DISC), middle, Color3.new(0, 0, 0), 1)
		stroke(rim, 6, 0, 100)
		-- A red haze laid over it when the supernova bursts.
		local haze = circle(
			gui,
			Vector2.new(DISC + 0.03, DISC + 0.03),
			middle,
			Color3.fromRGB(58, 10, 24),
			1
		)
		return { gui = gui, haze = haze, flow = flow }
	end
	Kit.every(function(t)
		if planet then
			-- The clouds drift slowly.
			planet.flow.Rotation = 1.5 * math.sin(t * 0.15)
		end
		return nil
	end)
	Kit.at(1.95, function()
		Kit.flash(PALE, 0.9, 0.45)
		Kit.shake(1.5, 0.35)
		if context.stage then
			Kit.hide(context.stage, character)
		end
		Kit.block(
			A(2000, 1500, 1),
			CFrame.lookAt((home * CFrame.new(0, 0, 1000)).Position, home.Position),
			SPACE,
			Enum.Material.Neon
		)
		Kit.block(
			A(2000, 1, 2000),
			CFrame.new(home.Position - A(0, 800, 0)),
			SPACE,
			Enum.Material.Neon
		)
		planet = makePlanet()
		Kit.lighting(
			"ColorCorrectionEffect",
			{ TintColor = Color3.fromRGB(205, 210, 255), Contrast = 0.12, Saturation = 0.1 }
		)
		spaceBloom =
			Kit.lighting("BloomEffect", { Intensity = 0.5, Size = 30, Threshold = 1.1 }) :: BloomEffect
		local field = Kit.block(A(180, 110, 60), home * CFrame.new(0, 10, 40), WHITE, nil, 1)
		local stars = Kit.emitter(field, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 210, 255)),
			Size = NumberSequence.new(0.22),
			Lifetime = NumberRange.new(60),
			Speed = NumberRange.new(0),
			Rate = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.3, 0.6),
				NumberSequenceKeypoint.new(0.6, 0.05),
				NumberSequenceKeypoint.new(1, 0.4),
			}),
		})
		stars:Emit(500)
	end)

	-- Floating in space they stay the focus: a soft outline (seen through the particles) and a
	-- light in front of them.
	Kit.at(2.2, function()
		local outline = Instance.new("Highlight")
		outline.Adornee = character
		outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		outline.FillTransparency = 1
		outline.OutlineColor = PALE
		outline.OutlineTransparency = 1
		outline.Parent = Kit.folder()
		Kit.track(outline)
		Kit.tween(outline, 0.5, { OutlineTransparency = 0.35 })
		local key = Kit.block(A(1, 1, 1), home * CFrame.new(0, 3.5, -4), WHITE, nil, 1)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 236, 246)
		light.Range = 12
		light.Brightness = 2.2
		light.Parent = key
		Kit.every(function()
			key.CFrame = home.Rotation + (home * (HOVER + pushed(Kit.now()) + A(0, 1, -4)))
			return nil
		end)
	end)

	-- A pink shooting star with a bright pointed head arcs across the sky behind them; partway
	-- across, high behind them, it bursts: the supernova grows from that spot (STRIKE).
	Kit.at(STAR_START, function()
		local star = Kit.prop()
		-- The head: a hot point leading a stretched glow, pointing the way it flies (-Z).
		Kit.add(
			star,
			Kit.block(
				A(0.7, 0.7, 0.7),
				CFrame.new(),
				Color3.fromRGB(255, 205, 232),
				Enum.Material.Neon,
				0,
				Enum.PartType.Ball
			),
			CFrame.new()
		)
		local tip = Kit.block(A(0.55, 0.55, 2.6), CFrame.new(), ROSE, Enum.Material.Neon, 0.15)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = tip
		Kit.add(star, tip, CFrame.new(0, 0, 1.0))
		local halo = Kit.block(
			A(2.6, 2.6, 2.6),
			CFrame.new(),
			PINK,
			Enum.Material.Neon,
			0.7,
			Enum.PartType.Ball
		)
		Kit.add(star, halo, CFrame.new())
		local head = star.parts[1]
		local light = Instance.new("PointLight")
		light.Color = PINK
		light.Range = 30
		light.Brightness = 3
		light.Parent = head
		local trail =
			Kit.trail(head, A(0, 0.45, 0), A(0, -0.45, 0), ColorSequence.new(ROSE, PINK), 1.2)
		trail.WidthScale = NumberSequence.new(1.6, 0)
		trail.Transparency = NumberSequence.new(0, 1)
		local sparkles = Kit.emitter(head, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(ROSE, PINK),
			Size = NumberSequence.new(0.3, 0),
			Lifetime = NumberRange.new(0.6, 1.4),
			Speed = NumberRange.new(0.5, 3),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = A(0, -3, 0),
			Rate = 500,
		})
		Kit.every(function(t)
			local u = (t - STAR_START) / STAR_TIME
			if u >= BURST_AT then
				star.place(CFrame.new(NOVA.Position - A(0, 500, 0)))
				light.Enabled = false
				sparkles.Enabled = false
				return true
			end
			local at = along(u)
			local ahead = along(math.min(u + 0.02, 1))
			star.place(
				CFrame.lookAt(at, if (ahead - at).Magnitude > 1e-3 then ahead else at + A(0, -1, 0))
			)
			return nil
		end)
	end)

	-- The supernova erupts behind them: a blinding flash and shockwaves, plasma flaring out in
	-- wisps, a glowing pink nebula, streaks of light, and drifting points of light all round them.
	Kit.at(STRIKE, function()
		local nova = NOVA.Position
		Kit.flash(CORAL, 0.6, 0.9)
		if planet then
			Kit.tween(planet.haze, 1.2, { BackgroundTransparency = 0.2 })
			Kit.tween(planet.gui, 1.2, { Brightness = 0.6 })
		end
		Kit.shake(2.8, 0.9)
		local toCamera = facingCamera(nova).Rotation
		for i, size in { 160, 120, 90 } do
			Kit.at(STRIKE + (i - 1) * 0.12, function()
				Kit.ring(nova, if i == 2 then ROSE else PINK, size, 1.6, toCamera)
			end)
		end
		-- The core: a bright heart in layered glow.
		local blast = Kit.block(
			A(2, 2, 2),
			CFrame.new(nova),
			ROSE,
			Enum.Material.Neon,
			0.2,
			Enum.PartType.Ball
		)
		Kit.tween(blast, 0.5, { Size = A(22, 22, 22), Transparency = 0.8 })
		Kit.at(STRIKE + 0.5, function()
			Kit.tween(blast, 1.4, { Size = A(8, 8, 8), Transparency = 0.6, Color = PINK })
		end)
		local heart = Kit.block(
			A(3, 3, 3),
			CFrame.new(nova),
			ROSE,
			Enum.Material.Neon,
			0.35,
			Enum.PartType.Ball
		)
		local corona = Kit.block(
			A(14, 14, 14),
			CFrame.new(nova),
			PINK,
			Enum.Material.Neon,
			0.9,
			Enum.PartType.Ball
		)
		local origin = Kit.block(A(1, 1, 1), CFrame.new(nova), WHITE, nil, 1)
		local center = Kit.attach(origin, Vector3.zero)
		-- Plasma wisps flaring out (soft, smoky ribbons that sway).
		type Flare = { beam: Beam, tip: Attachment, toward: Vector3, length: number, phase: number }
		local flares: { Flare } = {}
		for i = 1, 34 do
			local angle = i / 34 * math.pi * 2 + Kit.rnd(-0.12, 0.12)
			local toward = (home.Rotation * Vector3.new(
				math.cos(angle),
				math.sin(angle),
				Kit.rnd(-0.5, 0.3)
			)).Unit
			local tip = Kit.attach(origin, Vector3.zero)
			local beam = Instance.new("Beam")
			beam.Attachment0 = center
			beam.Attachment1 = tip
			beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.TextureSpeed = Kit.rnd(0.2, 0.6)
			beam.Width0 = Kit.rnd(4, 10)
			beam.Width1 = Kit.rnd(0.5, 2)
			beam.Segments = 30
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, ROSE),
				ColorSequenceKeypoint.new(0.5, PINK),
				ColorSequenceKeypoint.new(1, DEEP),
			})
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Parent = origin
			Kit.track(beam)
			table.insert(flares, {
				beam = beam,
				tip = tip,
				toward = toward,
				length = Kit.rnd(28, 70),
				phase = Kit.rnd(0, 6),
			})
		end
		-- A faint nebula behind (soft, so the winner stands out against it).
		Kit.emitter(origin, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(ROSE, PINK),
			Size = NumberSequence.new(12, 26),
			Transparency = NumberSequence.new(0.78, 1),
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(3, 7),
			SpreadAngle = Vector2.new(180, 180),
			RotSpeed = NumberRange.new(-15, 15),
			Rotation = NumberRange.new(0, 360),
			Drag = 0.5,
			Rate = 8,
		}):Emit(18)
		-- The explosion: thousands of small points of light blast out of it, slow down and hang,
		-- spaced out, filling the whole screen in pink (soft dots, like out-of-focus lights, and
		-- sharper glints among them). Small and partly see-through, so the winner shows through.
		local function grownIn(size: number, spread: number): NumberSequence
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.06, size, spread),
				NumberSequenceKeypoint.new(0.85, size, spread),
				NumberSequenceKeypoint.new(1, 0),
			})
		end
		local twinkle = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.4, 0.35, 0.25),
			NumberSequenceKeypoint.new(0.8, 0.3, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		local palette = ColorSequence.new({
			ColorSequenceKeypoint.new(0, BLUSH),
			ColorSequenceKeypoint.new(0.5, CORAL),
			ColorSequenceKeypoint.new(1, RED),
		})
		local soft = Kit.emitter(origin, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = palette,
			Size = grownIn(0.26, 0.14),
			Transparency = twinkle,
			Lifetime = NumberRange.new(5, 7),
			Speed = NumberRange.new(10, 60),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1.1,
			Rate = 0,
		})
		soft:Emit(4000)
		local glints = Kit.emitter(origin, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			LightEmission = 1,
			Color = palette,
			Size = grownIn(0.16, 0.08),
			Transparency = twinkle,
			Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(12, 60),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1.1,
			Rate = 0,
		})
		glints:Emit(2000)
		-- More keep pouring out, so the screen stays full.
		Kit.at(STRIKE + 0.4, function()
			soft.Rate = 400
			glints.Rate = 180
		end)
		-- The whole view fills: points of light of every size (tiny sharp ones, soft discs, and big
		-- blurry ones close to the camera, the depth of field turning them into soft discs) fly
		-- out from the burst in a growing wave to their places all across the screen, then drift.
		local camera = workspace.CurrentCamera
		local view = camera.CFrame
		local tanHalf = math.tan(math.rad(camera.FieldOfView) / 2)
		local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
		type Glow = { part: BasePart, to: Vector3, arrive: number, phase: number, base: number }
		local glows: { Glow } = {}
		-- Where the winner is on screen (as seen from the camera), with room round them, so
		-- nothing in front of them covers their face or body.
		-- (Both where they are now and where the blast pushes them to.)
		type Spot = { x: number, y: number, w: number, h: number, depth: number }
		local function spotOf(position: Vector3): Spot
			local here = view:PointToObjectSpace(position + A(0, 0.6, 0))
			local depth = -here.Z
			return {
				x = here.X / depth,
				y = here.Y / depth,
				w = 2.8 / depth,
				h = 4.2 / depth,
				depth = depth,
			}
		end
		local spots = { spotOf(context.root.Position), spotOf(home * (HOVER + PUSH)) }
		local final = spots[2]
		local bodyX, bodyY, bodyW, bodyH = final.x, final.y, final.w, final.h
		local function covers(x: number, y: number, depth: number, size: number): boolean
			for _, spot in spots do
				local pad = size / depth
				if
					depth <= spot.depth + 3
					and math.abs(x / depth - spot.x) < spot.w + pad
					and math.abs(y / depth - spot.y) < spot.h + pad
				then
					return true
				end
			end
			return false
		end
		for i = 1, 520 do
			local close = i <= 40
			local depth = if close then Kit.rnd(6, 18) else Kit.rnd(14, 95)
			local size = if close
				then Kit.rnd(1.6, 4)
				elseif math.random() < 0.25 then Kit.rnd(0.6, 1.4)
				else Kit.rnd(0.12, 0.5)
			local high = depth * tanHalf * 1.05
			local wide = high * aspect
			local x, y = Kit.rnd(-wide, wide), Kit.rnd(-high, high)
			for _ = 1, 30 do
				if not covers(x, y, depth, size) then
					break
				end
				x, y = Kit.rnd(-wide, wide), Kit.rnd(-high, high)
			end
			local to = (view * CFrame.new(x, y, -depth)).Position
			local roll = math.random()
			local color = if roll < 0.2 then RED elseif roll < 0.7 then CORAL else BLUSH
			local part = Kit.block(
				A(size, size, size),
				CFrame.new(nova),
				color,
				Enum.Material.Neon,
				1,
				Enum.PartType.Ball
			)
			table.insert(glows, {
				part = part,
				to = to,
				arrive = (to - nova).Magnitude / 85 + 0.3,
				phase = Kit.rnd(0, 6),
				base = if close then Kit.rnd(0.45, 0.7) else Kit.rnd(0.15, 0.55),
			})
		end
		-- And once the wave reaches the camera, tiny points keep appearing all through the view
		-- round them (four boxes: left of, right of, above and below where they are on screen).
		local drifts: { ParticleEmitter } = {}
		local mid = 24 -- the boxes' middle depth from the camera
		local high, wide = mid * tanHalf * 1.1, mid * tanHalf * 1.1 * aspect
		local left, right = (bodyX - bodyW) * mid - 0.6, (bodyX + bodyW) * mid + 0.6
		local bottom, top = (bodyY - bodyH) * mid - 0.6, (bodyY + bodyH) * mid + 0.6
		local function fillBox(x0: number, x1: number, y0: number, y1: number)
			if x1 - x0 < 0.5 or y1 - y0 < 0.5 then
				return
			end
			local box = Kit.block(
				A(x1 - x0, y1 - y0, 32),
				view * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -mid),
				WHITE,
				nil,
				1
			)
			table.insert(
				fills,
				Kit.emitter(box, {
					Texture = "rbxasset://textures/particles/smoke_main.dds",
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
					Color = palette,
					Size = grownIn(0.2, 0.12),
					Transparency = twinkle,
					Lifetime = NumberRange.new(3, 5),
					Speed = NumberRange.new(0.3, 1.5),
					SpreadAngle = Vector2.new(180, 180),
					Rate = 0,
				})
			)
		end
		fillBox(-wide, left, -high, high)
		fillBox(right, wide, -high, high)
		fillBox(left, right, top, high)
		fillBox(left, right, -high, bottom)
		Kit.at(STRIKE + 0.8, function()
			for _, fill in drifts do
				fill.Rate = 120
			end
		end)
		local burstAt = Kit.now()
		Kit.every(function(t)
			local u = t - burstAt
			local parts = table.create(#glows)
			local frames = table.create(#glows)
			for _, glow in glows do
				local k = Kit.span(u, 0, glow.arrive, "Out")
				local drift = A(math.sin(t * 0.4 + glow.phase), math.cos(t * 0.3 + glow.phase), 0)
					* 0.5
					* k
				table.insert(parts, glow.part)
				table.insert(frames, CFrame.new(nova:Lerp(glow.to, k) + drift))
				local shown = Kit.span(u, 0, 0.15)
				glow.part.Transparency = 1
					- shown * (1 - glow.base - 0.15 * math.sin(t * 2 + glow.phase))
			end
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			return nil
		end)
		-- Everything takes on the burst's pink-red as the wave spreads.
		local tint = Kit.lighting("ColorCorrectionEffect", {})
		Kit.tween(
			tint,
			1.4,
			{ TintColor = Color3.fromRGB(255, 172, 186), Saturation = 0.25, Contrast = 0.06 }
		)
		local focus = Kit.lighting("DepthOfFieldEffect", {
			FocusDistance = (view.Position - context.root.Position).Magnitude,
			InFocusRadius = 7,
			NearIntensity = 0.8,
			FarIntensity = 0.5,
		}) :: DepthOfFieldEffect
		Kit.every(function()
			focus.FocusDistance = (workspace.CurrentCamera.CFrame.Position - context.root.Position).Magnitude
			return nil
		end)
		if spaceBloom then
			Kit.tween(spaceBloom, 0.4, { Intensity = 0.7 })
		end
		local begun = Kit.now()
		Kit.every(function(t)
			local u = t - begun
			local grow = Kit.span(u, 0, 0.7, "Out")
			for _, flare in flares do
				local sway = math.sin(t * 0.8 + flare.phase)
				flare.tip.Position = flare.toward * flare.length * grow
				flare.beam.CurveSize0 = 10 * sway
				flare.beam.CurveSize1 = -14 * math.cos(t * 0.6 + flare.phase)
			end
			heart.Transparency = 0.35 + 0.2 * math.abs(math.sin(t * 2))
			corona.Size = A(14, 14, 14) * (1 + 0.08 * math.sin(t * 3))
			return nil
		end)
	end)
end

return Iridescent
