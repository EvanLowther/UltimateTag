--!strict
-- The Iridescent victories: they take over the whole screen. See docs/polish/victories.md for
-- the beats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticLook"))
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

---------------------------------------------------------------------------- Supernova

local SUPERNOVA: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.3,
		angles = { RightUpperArm = A(0, 0, 85), LeftUpperArm = A(0, 0, -85), Head = A(15) },
	},
	{ time = 2.2, angles = {} },
	{
		time = 2.35,
		angles = {
			RightUpperLeg = A(80),
			LeftUpperLeg = A(80),
			RightLowerLeg = A(-100),
			LeftLowerLeg = A(-100),
			RightUpperArm = A(60, 0, -30),
			LeftUpperArm = A(60, 0, 30),
			RightLowerArm = A(100),
			LeftLowerArm = A(100),
			UpperTorso = A(-20),
			Head = A(-30),
		},
		ease = "Out",
	},
	{ time = 2.6, angles = {} },
	{
		time = 2.72,
		angles = {
			RightUpperLeg = A(0, 0, 25),
			LeftUpperLeg = A(0, 0, -25),
			RightLowerLeg = A(0),
			LeftLowerLeg = A(0),
			RightUpperArm = A(0, 0, 130),
			LeftUpperArm = A(0, 0, -130),
			RightLowerArm = A(0),
			LeftLowerArm = A(0),
			UpperTorso = A(10),
			Head = A(30),
		},
		ease = "Out",
	},
}

-- The screen cracks like glass round `center` (pixels): wedge-shaped pieces of holo glass fan
-- out from it, drift apart a little, slide back together and fade.
local function crackScreen(center: Vector2)
	local screen = Kit.screen()
	local view = workspace.CurrentCamera.ViewportSize
	local reach = math.max(view.X, view.Y) * 1.6
	local count = 13
	type Shard = { holder: Frame, angle: number, scale: UIScale, fill: Frame }
	local shards: { Shard } = {}
	for i = 1, count do
		local angle = (i - 1) / count * 360 + Kit.rnd(-8, 8)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = UDim2.fromOffset(reach, reach)
		holder.Position = UDim2.fromOffset(center.X, center.Y)
		holder.Rotation = angle
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = holder
		-- A right triangle in the holder's lower right quarter, its point at the middle and its
		-- top edge along the crack line.
		local fill = Instance.new("Frame")
		fill.BorderSizePixel = 0
		fill.Position = UDim2.fromScale(0.5, 0.5)
		fill.Size = UDim2.fromScale(0.5, 0.5)
		fill.BackgroundColor3 = WHITE
		fill.BackgroundTransparency = 0.82
		local cut = Instance.new("UIGradient")
		cut.Rotation = 135
		cut.Color = CosmeticLook.holoSequence(i / count)
		cut.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.499, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		cut.Parent = fill
		fill.Parent = holder
		local edge = Instance.new("Frame")
		edge.BorderSizePixel = 0
		edge.AnchorPoint = Vector2.new(0, 0.5)
		edge.Position = UDim2.fromScale(0.5, 0.5)
		edge.Size = UDim2.new(0.5, 0, 0, 2)
		edge.BackgroundColor3 = WHITE
		edge.Parent = holder
		holder.Parent = screen
		table.insert(shards, { holder = holder, angle = angle, scale = scale, fill = fill })
	end
	local begun = Kit.now()
	Kit.every(function(t)
		local u = t - begun
		local grow = Kit.span(u, 0, 0.15, "Out")
		local apart = Kit.span(u, 0.1, 0.6, "Out") * (1 - Kit.span(u, 0.8, 1.8))
		local fade = Kit.span(u, 1.7, 2.3)
		for i, shard in shards do
			local bisector = math.rad(shard.angle + 22)
			local push = apart * 28 * (0.6 + (i % 3) * 0.3)
			shard.scale.Scale = 0.2 + 0.8 * grow
			shard.holder.Position = UDim2.fromOffset(
				center.X + math.cos(bisector) * push,
				center.Y + math.sin(bisector) * push
			)
			shard.holder.Rotation = shard.angle + apart * (if i % 2 == 0 then 3 else -3)
			shard.fill.BackgroundTransparency = 0.82 + 0.18 * fade
			for _, item in shard.holder:GetChildren() do
				if item:IsA("Frame") and item ~= shard.fill then
					item.BackgroundTransparency = fade
				end
			end
		end
		if u > 2.3 then
			for _, shard in shards do
				shard.holder:Destroy()
			end
			return true
		end
		return nil
	end)
end

-- Rises in a swirl of holo crystal shards, curls in at the peak, then explodes: a chromatic
-- shockwave, the screen cracks like glass, and prism rays turn behind them.
function Iridescent.Supernova(context: Context)
	local character = context.character
	local root = context.root
	local count = 26
	type Shard = { part: WedgePart, phase: number, height: number, out: number }
	local shards: { Shard } = {}
	for i = 1, count do
		local size = Kit.rnd(0.6, 1.2)
		local shard = Kit.wedge(
			A(0.15, size * 1.6, size),
			root.CFrame,
			CosmeticLook.holoColor(i / count),
			Enum.Material.Glass
		)
		shard.Transparency = 0.2
		shard.Reflectance = 0.2
		table.insert(shards, {
			part = shard,
			phase = i / count * math.pi * 2,
			height = Kit.rnd(-1.5, 3),
			out = Kit.rnd(0.9, 1.2),
		})
	end
	Kit.pose(character, SUPERNOVA, context.hold)
	Kit.move(context, function(t)
		local bob = if t > 2.7 then math.sin((t - 2.7) * 1.6) * 0.3 else 0
		return CFrame.new(0, 8 * Kit.span(t, 0, 2.0, "Out") + bob, 0)
	end)
	Kit.lookAt(function(t)
		return context.root.Position, 0.8 * Kit.span(t, 0.3, 2.0)
	end)
	Kit.react(context, "LookUp", 0.6)
	Kit.react(context, "Shield", 2.6)
	local angle = 0
	Kit.every(function(t, dt)
		local speed = if t < 2.2
			then 1.4 + 5.1 * Kit.span(t, 0, 2.2, "In")
			elseif t < 2.6 then 0
			else 0.6
		angle += speed * dt
		local center = root.Position + A(0, 0.6, 0)
		local radius = if t < 2.2
			then 6 - 3.7 * Kit.span(t, 0, 2.2)
			elseif t < 2.6 then 2.3
			else 2.3 + 34 * Kit.span(t, 2.6, 3.2, "Out")
		local fade = if t < 2.6 then 0 else Kit.span(t, 2.7, 3.2)
		local parts = table.create(count)
		local frames = table.create(count)
		for i, shard in shards do
			local a = shard.phase + angle
			local r = radius * shard.out
			local hidden = fade
			if t > 3.2 and i <= 12 then
				r = 5 * shard.out
				hidden = 1 - Kit.span(t, 3.2, 3.8)
			end
			shard.part.Transparency = 0.2 + 0.8 * hidden
			shard.part.Color = CosmeticLook.holoColor(t * 0.25 + i * 0.04)
			table.insert(parts, shard.part)
			table.insert(
				frames,
				CFrame.new(center + A(math.cos(a) * r, shard.height, math.sin(a) * r))
					* CFrame.Angles(a * 2, a, i)
			)
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		return nil
	end)
	Kit.at(2.6, function()
		local center = root.Position + A(0, 0.6, 0)
		Kit.flash(WHITE, 0.9, 0.35)
		Kit.shake(3, 0.7)
		for i, color in
			{
				Color3.fromRGB(255, 70, 100),
				Color3.fromRGB(70, 255, 150),
				Color3.fromRGB(80, 130, 255),
			}
		do
			Kit.at(2.6 + (i - 1) * 0.06, function()
				Kit.ring(center, color, 70, 0.9, facingCamera(center).Rotation)
			end)
		end
		Kit.burst(center, 70, CosmeticLook.holoSequence(0), NumberRange.new(16, 30), 0.6)
		-- The colour split: three quick tints.
		for i, color in
			{
				Color3.fromRGB(255, 60, 90),
				Color3.fromRGB(60, 255, 150),
				Color3.fromRGB(70, 120, 255),
			}
		do
			Kit.at(2.6 + (i - 1) * 0.066, function()
				Kit.flash(color, 0.3, 0.12)
			end)
		end
		crackScreen(Kit.onScreen(center))
	end)
	-- Prism rays and colour trails while they float at the peak.
	local rays = Kit.prop()
	for i = 1, 8 do
		Kit.add(
			rays,
			Kit.block(A(0.35, 24, 0.1), CFrame.new(), WHITE, Enum.Material.Neon, 1),
			CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 12, 0)
		)
	end
	local trails = {}
	for _, name in { "RightHand", "LeftHand", "RightFoot", "LeftFoot" } do
		local part = Kit.part(character, name)
		if part then
			local trail =
				Kit.trail(part, A(0, 0.25), A(0, -0.25), CosmeticLook.holoSequence(0), 0.5)
			trail.Enabled = false
			table.insert(trails, trail)
		end
	end
	Kit.every(function(t)
		if t < 3.0 then
			return nil
		end
		local show = Kit.span(t, 3.0, 3.6)
		local center = root.Position + A(0, 0.6, 0)
		local camera = workspace.CurrentCamera.CFrame.Position
		local behind = (center - camera).Unit * 1.5
		rays.place(CFrame.lookAt(center + behind, camera) * CFrame.Angles(0, 0, t * 0.25))
		for i, part in rays.parts do
			part.Transparency = 1 - 0.45 * show
			part.Color = CosmeticLook.holoColor(i / 8 + t * 0.1)
		end
		for _, trail in trails do
			trail.Enabled = true
			trail.Color = CosmeticLook.holoSequence(t * 0.3)
		end
		return nil
	end)
end

---------------------------------------------------------------------------- Rift

local PINK = Color3.fromRGB(255, 64, 150)
local ROSE = Color3.fromRGB(255, 140, 200)
local PALE = Color3.fromRGB(255, 215, 235)
local SPACE = Color3.fromRGB(5, 7, 18)

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
		-- Floating in space, drifting and turning slowly.
		return CFrame.new(0, 2.5 + math.sin(t * 0.9) * 0.3, 0)
			* CFrame.Angles(
				math.rad(10 * math.sin(t * 0.5)),
				math.rad(20 * math.sin(t * 0.3)),
				math.rad(14 * math.sin(t * 0.4))
			)
	end)
	Kit.tilt(function(t)
		return 3 * Kit.span(t, 2.1, 2.6)
	end)

	-- Deep space: the stage goes, dark blue-black and stars all round.
	Kit.at(1.95, function()
		Kit.flash(PALE, 0.9, 0.45)
		Kit.shake(1.5, 0.35)
		if context.stage then
			Kit.hide(context.stage, character)
		end
		Kit.block(
			A(500, 360, 1),
			CFrame.lookAt((home * CFrame.new(0, 0, 80)).Position, home.Position),
			SPACE,
			Enum.Material.Neon
		)
		Kit.block(
			A(500, 1, 500),
			CFrame.new(home.Position - A(0, 60, 0)),
			SPACE,
			Enum.Material.Neon
		)
		Kit.lighting(
			"ColorCorrectionEffect",
			{ TintColor = Color3.fromRGB(205, 210, 255), Contrast = 0.12, Saturation = 0.1 }
		)
		Kit.lighting("BloomEffect", { Intensity = 0.9, Size = 36, Threshold = 0.9 })
		local field = Kit.block(A(180, 110, 60), home * CFrame.new(0, 10, 40), WHITE, nil, 1)
		local stars = Kit.emitter(field, {
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

	-- A pink shooting star arcing across the sky, shedding sparkles.
	Kit.at(2.7, function()
		local from = (home * CFrame.new(28, 14, 45)).Position
		local bend = (home * CFrame.new(2, 26, 45)).Position
		local to = (home * CFrame.new(-34, -2, 45)).Position
		local star = Kit.block(
			A(1, 1, 1),
			CFrame.new(from),
			WHITE,
			Enum.Material.Neon,
			0,
			Enum.PartType.Ball
		)
		local halo = Kit.block(
			A(3.2, 3.2, 3.2),
			CFrame.new(from),
			PINK,
			Enum.Material.Neon,
			0.65,
			Enum.PartType.Ball
		)
		local light = Instance.new("PointLight")
		light.Color = PINK
		light.Range = 30
		light.Brightness = 4
		light.Parent = star
		local trail =
			Kit.trail(star, A(0, 0.5, 0), A(0, -0.5, 0), ColorSequence.new(PALE, PINK), 1.3)
		trail.WidthScale = NumberSequence.new(1.6, 0)
		trail.Transparency = NumberSequence.new(0, 1)
		local glowTrail =
			Kit.trail(star, A(0, 1.4, 0), A(0, -1.4, 0), ColorSequence.new(ROSE, PINK), 0.6)
		glowTrail.Transparency = NumberSequence.new(0.6, 1)
		Kit.emitter(star, {
			Color = ColorSequence.new(WHITE, PINK),
			Size = NumberSequence.new(0.35, 0),
			Lifetime = NumberRange.new(0.6, 1.4),
			Speed = NumberRange.new(0.5, 3),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = A(0, -3, 0),
			Rate = 500,
		})
		Kit.emitter(star, {
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = NumberSequence.new(2),
			Color = ColorSequence.new(PALE),
			Size = NumberSequence.new(0.18, 0),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 150,
		})
		local begun = Kit.now()
		Kit.every(function(t)
			local u = Kit.span(t, begun, begun + 1.0, "Linear")
			local a = from:Lerp(bend, u)
			local b = bend:Lerp(to, u)
			local at = a:Lerp(b, u)
			star.CFrame = CFrame.new(at)
			halo.CFrame = CFrame.new(at)
			if u >= 1 then
				star.Transparency = 1
				halo.Transparency = 1
				light.Enabled = false
				for _, item in star:GetChildren() do
					if item:IsA("ParticleEmitter") then
						item.Enabled = false
					end
				end
				return true
			end
			return nil
		end)
	end)

	-- The supernova erupts behind them: a blinding flash and shockwaves, plasma flaring out in
	-- wisps, a glowing pink nebula, streaks of light, and drifting points of light all round them.
	Kit.at(3.9, function()
		local nova = (home * CFrame.new(4, 7, 48)).Position
		Kit.flash(ROSE, 0.9, 0.8)
		Kit.shake(2.8, 0.9)
		local toCamera = facingCamera(nova).Rotation
		for i, size in { 160, 120, 90 } do
			Kit.at(3.9 + (i - 1) * 0.12, function()
				Kit.ring(nova, if i == 2 then PALE else PINK, size, 1.6, toCamera)
			end)
		end
		-- The core: a bright heart in layered glow.
		local blast =
			Kit.block(A(2, 2, 2), CFrame.new(nova), PALE, Enum.Material.Neon, 0, Enum.PartType.Ball)
		Kit.tween(blast, 0.5, { Size = A(34, 34, 34), Transparency = 0.6 })
		Kit.at(4.4, function()
			Kit.tween(blast, 1.4, { Size = A(11, 11, 11), Transparency = 0.35, Color = PINK })
		end)
		local heart = Kit.block(
			A(5, 5, 5),
			CFrame.new(nova),
			WHITE,
			Enum.Material.Neon,
			0.1,
			Enum.PartType.Ball
		)
		local corona = Kit.block(
			A(18, 18, 18),
			CFrame.new(nova),
			PINK,
			Enum.Material.Neon,
			0.85,
			Enum.PartType.Ball
		)
		-- A long lens streak across the sky through it.
		local streak = Kit.block(
			A(220, 0.5, 0.1),
			CFrame.new(nova) * toCamera * CFrame.Angles(0, math.pi / 2, 0),
			PALE,
			Enum.Material.Neon,
			0.2
		)
		Kit.tween(streak, 2.5, { Transparency = 0.75, Size = A(160, 0.25, 0.1) })
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
				ColorSequenceKeypoint.new(0, PALE),
				ColorSequenceKeypoint.new(0.4, ROSE),
				ColorSequenceKeypoint.new(1, PINK),
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
		-- The nebula: big soft glowing clouds billowing out.
		Kit.emitter(origin, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(ROSE, PINK),
			Size = NumberSequence.new(14, 34),
			Transparency = NumberSequence.new(0.55, 1),
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(3, 8),
			SpreadAngle = Vector2.new(180, 180),
			RotSpeed = NumberRange.new(-15, 15),
			Rotation = NumberRange.new(0, 360),
			Drag = 0.5,
			Rate = 18,
		}):Emit(30)
		-- Streaks of light shooting out of it.
		local streaks = Kit.emitter(origin, {
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Squash = NumberSequence.new(2.5),
			Color = ColorSequence.new(WHITE, PINK),
			Size = NumberSequence.new(0.6, 0.1),
			Lifetime = NumberRange.new(1, 2.2),
			Speed = NumberRange.new(35, 80),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1.2,
			Rate = 90,
		})
		streaks:Emit(500)
		-- Glitter filling the space round the winner.
		local around = Kit.block(A(70, 34, 60), home * CFrame.new(0, 4, 12), WHITE, nil, 1)
		Kit.emitter(around, {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(PALE, PINK),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Lifetime = NumberRange.new(2, 4),
			Speed = NumberRange.new(0.2, 1),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 260,
		})
		-- Soft out-of-focus blobs of light drifting.
		Kit.emitter(around, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Color = ColorSequence.new(ROSE, PINK),
			Size = NumberSequence.new(1.2, 3),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 45,
		})
		-- Points of light thrown out of the blast and drifting round the winner.
		type Mote = { part: BasePart, to: Vector3, phase: number, base: number }
		local motes: { Mote } = {}
		for _ = 1, 240 do
			local size = Kit.rnd(0.15, 1.9)
			local part = Kit.block(
				A(size, size, size),
				CFrame.new(nova),
				PINK:Lerp(PALE, Kit.rnd(0, 0.85)),
				Enum.Material.Neon,
				0.3,
				Enum.PartType.Ball
			)
			local to = (home * CFrame.new(Kit.rnd(-30, 30), Kit.rnd(-10, 20), Kit.rnd(-14, 44))).Position
			table.insert(
				motes,
				{ part = part, to = to, phase = Kit.rnd(0, 6), base = Kit.rnd(0.15, 0.7) }
			)
		end
		local camera = workspace.CurrentCamera
		Kit.lighting("DepthOfFieldEffect", {
			FocusDistance = (camera.CFrame.Position - context.root.Position).Magnitude,
			InFocusRadius = 6,
			NearIntensity = 0.75,
			FarIntensity = 0.5,
		})
		Kit.lighting("BloomEffect", { Intensity = 1.2, Size = 40, Threshold = 0.85 })
		Kit.emitter(Kit.attach(context.root, Vector3.zero), {
			Color = ColorSequence.new(PALE, PINK),
			Size = NumberSequence.new(0.2, 0),
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 40,
		})
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
			heart.Transparency = 0.1 + 0.2 * math.abs(math.sin(t * 2))
			corona.Size = A(18, 18, 18) * (1 + 0.08 * math.sin(t * 3))
			local spread = Kit.span(u, 0, 1.6, "Out")
			local parts = table.create(#motes)
			local frames = table.create(#motes)
			for _, mote in motes do
				local drift = A(math.sin(t * 0.4 + mote.phase), math.cos(t * 0.3 + mote.phase), 0)
					* 0.8
				table.insert(parts, mote.part)
				table.insert(frames, CFrame.new(nova:Lerp(mote.to, spread) + drift))
				mote.part.Transparency = mote.base + 0.25 * math.sin(t * 2 + mote.phase)
			end
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
			return nil
		end)
	end)
end

return Iridescent
