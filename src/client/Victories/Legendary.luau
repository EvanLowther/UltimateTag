--!strict
-- The Legendary victories: they change the scene (the podium, the sky, big props) with camera
-- moments. See docs/polish/victories.md for the beats.
local Epic = require(script.Parent.Epic)
local Kit = require(script.Parent.Kit)

type Context = Kit.Context
type Key = Kit.Key

local Legendary = {}

local function A(x: number, y: number?, z: number?): Vector3
	return Vector3.new(x, y or 0, z or 0)
end

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 207, 58)
local ROCK = Color3.fromRGB(92, 80, 68)
local DUST = Color3.fromRGB(196, 188, 172)

local function rootHeight(context: Context): number
	return context.humanoid.HipHeight + context.root.Size.Y / 2
end

local function feet(context: Context): Vector3
	local home = context.home.Position
	return Vector3.new(home.X, context.ground, home.Z)
end

-- Chunks thrown from `position` that tumble and fall to the floor.
local function rubble(
	context: Context,
	position: Vector3,
	count: number,
	speed: number,
	color: Color3?,
	size: number?
)
	for _ = 1, count do
		local s = (size or 0.5) * Kit.rnd(0.6, 1.3)
		local chunk =
			Kit.block(A(s, s * 0.8, s), CFrame.new(position), color or ROCK, Enum.Material.Slate)
		local velocity = A(Kit.rnd(-1, 1) * speed, Kit.rnd(0.4, 1) * speed, Kit.rnd(-1, 1) * speed)
		local turn = A(Kit.rnd(-8, 8), Kit.rnd(-8, 8), Kit.rnd(-8, 8))
		local begun = Kit.now()
		Kit.every(function(t)
			local u = t - begun
			local at = position + velocity * u + A(0, -30 * u * u, 0)
			chunk.CFrame = CFrame.new(at) * CFrame.Angles(turn.X * u, turn.Y * u, turn.Z * u)
			if at.Y < context.floor - 1 or u > 2 then
				chunk:Destroy()
				return true
			end
			return nil
		end)
	end
end

-- Glowing cracks on the floor reaching out from `center` to `radius`, each piece lighting up as
-- something spreading at `speed` studs/s reaches it.
local function floorCracks(
	context: Context,
	center: Vector3,
	count: number,
	radius: number,
	color: Color3,
	speed: number
)
	local y = context.floor + 0.06
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + Kit.rnd(-0.2, 0.2)
		local from = Vector3.new(center.X, y, center.Z)
		local distance = 0
		while distance < radius do
			local step = Kit.rnd(2.5, 4.5)
			angle += Kit.rnd(-0.45, 0.45)
			local to = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * step
			local width = 0.2 * (1 - distance / radius) + 0.06
			local a, b = from, to
			Kit.at(Kit.now() + distance / speed, function()
				Kit.line(a, b, width, color)
			end)
			from = to
			distance += step
		end
	end
end

---------------------------------------------------------------------------- Podium Rise

local PODIUM: { Key } = {
	{ time = 0, angles = {} },
	{ time = 0.8, angles = {} },
	{
		time = 1.0,
		angles = {
			RightUpperLeg = A(45),
			LeftUpperLeg = A(45),
			RightLowerLeg = A(-80),
			LeftLowerLeg = A(-80),
			UpperTorso = A(-15),
			RightUpperArm = A(0, 0, 70),
			LeftUpperArm = A(0, 0, -70),
		},
	},
	{ time = 1.8, angles = {} },
	{
		time = 2.1,
		angles = {
			RightUpperLeg = A(0),
			LeftUpperLeg = A(0),
			RightLowerLeg = A(0),
			LeftLowerLeg = A(0),
			UpperTorso = A(5),
			RightUpperArm = A(170, 0, 10),
			RightLowerArm = A(15),
			LeftUpperArm = A(0, 0, -10),
			Head = A(20),
		},
		ease = "Out",
	},
	{ time = 3.2, angles = {} },
	{
		time = 3.6,
		angles = {
			RightUpperArm = A(0, 0, 125),
			RightLowerArm = A(0),
			LeftUpperArm = A(0, 0, -125),
			Head = A(15),
		},
	},
}

-- The 1st place block erupts out of the ground, lifting the winner into a gold spotlight.
function Legendary.PodiumRise(context: Context)
	local base = feet(context)
	local block = context.block
	local rise = 8
	local grows = block ~= nil
	if not block then
		-- The Locker has no podium: a block comes up out of the floor under them.
		block =
			Kit.block(A(7, 5, 7), CFrame.new(base - A(0, 2.55, 0)), Color3.fromRGB(255, 214, 10))
		rise = 5
	end
	local podium = block :: BasePart
	local startSize, startFrame = podium.Size, podium.CFrame
	if grows then
		Kit.onStop(function()
			podium.Size = startSize
			podium.CFrame = startFrame
		end)
	end
	local function lifted(t: number): number
		return rise * Kit.span(t, 0.8, 1.8, "Back")
	end
	Kit.every(function(t)
		local r = lifted(t)
		local jitter = if t < 0.85
			then A(Kit.rnd(-0.06, 0.06), 0, Kit.rnd(-0.06, 0.06))
			else Vector3.zero
		if grows then
			podium.Size = startSize + A(0, r, 0)
			podium.CFrame = startFrame + A(0, r / 2, 0) + jitter
		else
			podium.CFrame = startFrame + A(0, r, 0) + jitter
		end
		return t > 1.9
	end)
	Kit.pose(context.character, PODIUM, context.hold)
	Kit.move(context, function(t)
		local crouch = Kit.span(t, 0.8, 1.0) * (1 - Kit.span(t, 1.8, 2.1))
		return CFrame.new(0, lifted(t) - 0.6 * crouch, 0)
	end)
	Kit.react(context, "LookUp", 0.9)
	Kit.tilt(function(t)
		return 9 * Kit.span(t, 0.8, 2.0)
	end)
	-- The rumble.
	Kit.shake(0.8, 0.9)
	local half = podium.Size.X / 2
	local floorY = context.floor
	for i = 0, 6 do
		Kit.at(i * 0.12, function()
			local side = if i % 2 == 0 then 1 else -1
			Kit.dust(
				Vector3.new(base.X + side * half, floorY + 0.3, base.Z + Kit.rnd(-3, 3)),
				3,
				0.8
			)
		end)
	end
	Kit.at(0.5, function()
		floorCracks(context, base, 10, 10, GOLD, 25)
	end)
	Kit.at(0.8, function()
		Kit.dust(Vector3.new(base.X, floorY + 0.4, base.Z), 30, 2.4)
		rubble(context, Vector3.new(base.X, floorY + 0.5, base.Z), 18, 14)
		Kit.shake(1.6, 1.1)
	end)
	for i = 0, 7 do
		Kit.at(0.95 + i * 0.11, function()
			local top = podium.Position.Y + podium.Size.Y / 2
			rubble(
				context,
				Vector3.new(base.X + Kit.rnd(-half, half), top, base.Z + Kit.rnd(-3, 3)),
				1,
				3,
				ROCK,
				0.45
			)
		end)
	end
	-- The spotlight.
	Kit.at(2.0, function()
		Kit.flash(Color3.fromRGB(255, 226, 138), 0.5, 0.5)
		Kit.shake(1.2, 0.35)
		local top = podium.Position.Y + podium.Size.Y / 2
		local lamp = Kit.block(A(5, 1, 5), CFrame.new(base.X, top + 26, base.Z), WHITE, nil, 1)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 30
		light.Brightness = 10
		light.Range = 40
		light.Color = Color3.fromRGB(255, 226, 150)
		light.Parent = lamp
		local beam = Instance.new("Beam")
		beam.Attachment0 = Kit.attach(lamp, A(0, 0, 0))
		local floorSpot = Kit.block(A(1, 1, 1), CFrame.new(base.X, top, base.Z), WHITE, nil, 1)
		beam.Attachment1 = Kit.attach(floorSpot, A(0, 0, 0))
		beam.Width0 = 3
		beam.Width1 = 9
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110))
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 0.55),
		})
		beam.Parent = lamp
		Kit.track(beam)
		Kit.emitter(lamp, {
			Shape = Enum.ParticleEmitterShape.Box,
			Color = ColorSequence.new(GOLD),
			Size = NumberSequence.new(0.18),
			Lifetime = NumberRange.new(4, 5),
			Speed = NumberRange.new(2, 3),
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 30,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end)
end

---------------------------------------------------------------------------- Thunderstorm

local STORM: { Key } = {
	{ time = 0, angles = {} },
	{ time = 1.35, angles = {} },
	{
		time = 1.55,
		angles = {
			RightUpperArm = A(-20, 0, 110),
			LeftUpperArm = A(-20, 0, -110),
			RightLowerArm = A(15),
			LeftLowerArm = A(15),
			UpperTorso = A(18),
			Head = A(30),
			RightUpperLeg = A(15),
			LeftUpperLeg = A(15),
			RightLowerLeg = A(-30),
			LeftLowerLeg = A(-30),
		},
		ease = "Out",
	},
}

-- The sky goes dark, warning bolts hit the floor, then the big bolt hits the winner, who hovers
-- crackling with electricity.
function Legendary.Thunderstorm(context: Context)
	local character = context.character
	local home = context.home
	local base = feet(context)
	local bolt = context.colors[1] or Color3.fromRGB(160, 216, 255)
	local tint = Kit.lighting("ColorCorrectionEffect", {})
	Kit.tween(tint, 0.6, {
		TintColor = Color3.fromRGB(150, 170, 225),
		Brightness = -0.18,
		Contrast = 0.15,
		Saturation = -0.2,
	})
	local sky = Kit.block(
		A(140, 80, 0.4),
		home * CFrame.new(0, 20, 12.4),
		Color3.fromRGB(10, 14, 30),
		nil,
		1
	)
	Kit.tween(sky, 0.6, { Transparency = 0.2 })
	local clouds = {}
	for i = 1, 8 do
		local size = Kit.rnd(10, 16)
		local cloud = Kit.block(
			A(size, size * 0.5, size * 0.6),
			home * CFrame.new(-28 + i * 7, Kit.rnd(11, 16), 10),
			Color3.fromRGB(46, 52, 72),
			nil,
			1,
			Enum.PartType.Ball
		)
		Kit.tween(cloud, 0.8, { Transparency = 0.15 })
		table.insert(clouds, { part = cloud, start = cloud.CFrame, speed = Kit.rnd(0.3, 0.8) })
	end
	Kit.at(3.0, function()
		Kit.tween(tint, 0.8, { TintColor = Color3.fromRGB(205, 215, 240), Brightness = -0.08 })
		Kit.tween(sky, 0.8, { Transparency = 0.55 })
	end)

	local function strike(spot: Vector3)
		Kit.bolt(spot + A(0, 44, 0), spot, WHITE, 0.45, 0.3, 2.5)
		Kit.burst(spot + A(0, 0.3), 25, bolt, NumberRange.new(8, 16), 0.4, 20)
		Kit.ring(spot + A(0, 0.1), bolt, 8, 0.35)
		Kit.flash(Color3.fromRGB(220, 240, 255), 0.3, 0.25)
		Kit.shake(1.2, 0.3)
	end
	Kit.at(0.6, function()
		strike(
			Vector3.new(
				(home * CFrame.new(-7, 0, -2)).X,
				context.floor,
				(home * CFrame.new(-7, 0, -2)).Z
			)
		)
	end)
	Kit.at(1.0, function()
		strike(
			Vector3.new(
				(home * CFrame.new(8, 0, 1)).X,
				context.floor,
				(home * CFrame.new(8, 0, 1)).Z
			)
		)
	end)
	Kit.at(1.4, function()
		local head = Kit.at3(context, "Head")
		Kit.bolt(head + A(0, 46, 0), head + A(0, 0.8, 0), WHITE, 0.8, 0.36, 2)
		Kit.flash(WHITE, 0.92, 0.45)
		Kit.shake(3, 0.6)
		Kit.burst(head, 50, Kit.sequence({ WHITE, bolt }), NumberRange.new(10, 20), 0.5, 10)
	end)
	Kit.react(context, "Shield", 1.4)
	Kit.pose(character, STORM, context.hold)
	Kit.move(context, function(t)
		local lift = 2 * Kit.span(t, 1.4, 1.55, "Out")
		local bob = if t > 1.55 then math.sin((t - 1.55) * 2.2) * 0.25 else 0
		return CFrame.new(0, lift + bob, 0)
	end)
	-- Sparks and arcs while they hover; the block's edges glow.
	local torso = Kit.part(character, "UpperTorso")
	local sparks: ParticleEmitter? = nil
	if torso then
		sparks = Kit.emitter(Kit.attach(torso, Vector3.zero), {
			Color = ColorSequence.new(WHITE, bolt),
			Size = NumberSequence.new(0.2, 0),
			Lifetime = NumberRange.new(0.4, 0.7),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = A(0, -30, 0),
			Rate = 0,
		})
	end
	local glow: SelectionBox? = nil
	Kit.at(1.4, function()
		if sparks then
			sparks.Rate = 35
		end
		if context.block then
			local box = Instance.new("SelectionBox")
			box.Adornee = context.block
			box.LineThickness = 0.12
			box.Color3 = bolt
			box.Parent = Kit.folder()
			glow = box
		end
	end)
	local limbs = { "RightHand", "LeftHand", "RightFoot", "LeftFoot", "Head", "UpperTorso" }
	local nextArc = 1.55
	Kit.every(function(t)
		for _, cloud in clouds do
			cloud.part.CFrame = cloud.start * CFrame.new(math.sin(t * cloud.speed) * 2, 0, 0)
		end
		if glow then
			glow.Transparency = 0.2 + 0.3 * math.abs(math.sin(t * 9))
		end
		if t > nextArc then
			nextArc = t + Kit.rnd(0.06, 0.16)
			local a = Kit.at3(context, limbs[math.random(#limbs)])
			local b = if math.random() < 0.35
				then Vector3.new(base.X + Kit.rnd(-3, 3), context.ground, base.Z + Kit.rnd(-3, 3))
				else Kit.at3(context, limbs[math.random(#limbs)])
			if (a - b).Magnitude > 0.5 then
				Kit.bolt(a, b, Color3.fromRGB(190, 230, 255), 0.08, 0.12, 0.6)
			end
		end
		return nil
	end)
end

---------------------------------------------------------------------------- Throne

local THRONE: { Key } = {
	{ time = 0, angles = {} },
	{ time = 1.0, angles = { Head = A(0, 70, 0), UpperTorso = A(0, 20, 0) } },
	{ time = 1.3, angles = { Head = A(0), UpperTorso = A(0) } },
	{
		time = 1.5,
		angles = {
			RightUpperArm = A(40),
			LeftUpperArm = A(40),
			RightUpperLeg = A(40),
			LeftUpperLeg = A(40),
		},
	},
	{
		-- Lounging: legs crossed, chin on the left fist, the right arm draped over the side.
		time = 1.85,
		angles = {
			RightUpperLeg = A(100, 0, -18),
			RightLowerLeg = A(-55),
			LeftUpperLeg = A(90),
			LeftLowerLeg = A(-90),
			LowerTorso = A(12),
			UpperTorso = A(0, 0, -6),
			LeftUpperArm = A(25, 0, -10),
			LeftLowerArm = A(125),
			RightUpperArm = A(-10, 0, 35),
			RightLowerArm = A(15),
			Head = A(-8, 0, 8),
		},
		ease = "Out",
	},
}

-- A gold throne crashes down behind the winner, who falls back into it and lounges under a
-- floating crown.
function Legendary.Throne(context: Context)
	local character = context.character
	local home = context.home
	local hip = context.humanoid.HipHeight
	local seat = hip * 0.55 -- seat height (about knee height)
	local back = 1.3 -- how far back they sit
	local sitDrop = seat + 0.5 - hip
	local velvet = context.colors[1] or Color3.fromRGB(106, 43, 191)
	local gem = context.colors[2] or Color3.fromRGB(255, 62, 138)
	local spot = home * CFrame.new(0, -rootHeight(context), back + 0.3) -- under the seat's middle

	local throne = Kit.prop()
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		Kit.add(
			throne,
			Kit.block(size, CFrame.new(), color, material or Enum.Material.Metal),
			offset
		)
	end
	local legH = seat - 0.55
	for _, x in { -2.3, 2.3 } do
		for _, z in { -1, 1 } do
			piece(A(0.55, legH, 0.55), CFrame.new(x, legH / 2, z), GOLD)
		end
	end
	piece(A(5.2, 0.55, 2.6), CFrame.new(0, seat - 0.27, 0), GOLD)
	piece(A(4.4, 0.3, 2.2), CFrame.new(0, seat + 0.12, -0.1), velvet, Enum.Material.Fabric)
	piece(A(5.6, 7, 0.5), CFrame.new(0, seat + 3.5, 1.35), GOLD)
	piece(A(4.3, 5.6, 0.1), CFrame.new(0, seat + 3.3, 1.07), velvet, Enum.Material.Fabric)
	for _, x in { -2.95, 2.95 } do
		piece(A(0.7, 0.9, 2.6), CFrame.new(x, seat + 0.45, 0), GOLD)
	end
	piece(
		A(1.2, 1.2, 0.45),
		CFrame.new(0, seat + 7.1, 1.35) * CFrame.Angles(0, 0, math.rad(45)),
		GOLD
	)
	for _, x in { -2.1, 2.1 } do
		piece(
			A(0.8, 0.8, 0.45),
			CFrame.new(x, seat + 6.8, 1.35) * CFrame.Angles(0, 0, math.rad(45)),
			GOLD
		)
	end
	Kit.add(
		throne,
		Kit.block(A(0.6, 0.6, 0.6), CFrame.new(), gem, Enum.Material.Neon, 0, Enum.PartType.Ball),
		CFrame.new(0, seat + 6.1, 1.02)
	)
	local shadow = Kit.block(
		A(0.1, 1, 1),
		spot * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.new(0, 0, 0),
		nil,
		0.5,
		Enum.PartType.Cylinder
	)
	Kit.every(function(t)
		throne.place(spot + A(0, 30 * (1 - Kit.span(t, 0, 0.6, "In")), 0))
		local grow = Kit.span(t, 0, 0.6) * 6
		shadow.Size = A(0.1, grow + 0.1, grow + 0.1)
		if t > 0.65 then
			shadow:Destroy()
			return true
		end
		return nil
	end)
	Kit.at(0.6, function()
		local floor = spot.Position
		Kit.dust(floor + A(0, 0.3), 30, 2)
		Kit.ring(floor + A(0, 0.1), DUST, 18, 0.5)
		rubble(context, floor + A(0, 0.5), 10, 9, GOLD, 0.35)
		Kit.shake(2.5, 0.5)
	end)
	Kit.react(context, "Stagger", 0.6)
	Kit.pose(character, THRONE, context.hold)
	Kit.move(context, function(t)
		local u = Kit.span(t, 1.3, 1.85)
		return CFrame.new(0, sitDrop * u, back * u)
			* CFrame.Angles(math.rad(18) * math.sin(math.pi * u), 0, 0)
	end)
	-- The crown.
	local crown = Kit.prop()
	Kit.add(
		crown,
		Kit.block(
			A(0.45, 1.5, 1.5),
			CFrame.new(),
			GOLD,
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder
		),
		CFrame.Angles(0, 0, math.rad(90))
	)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		Kit.add(
			crown,
			Kit.block(A(0.28, 0.6, 0.28), CFrame.new(), GOLD, Enum.Material.Metal),
			CFrame.new(math.cos(a) * 0.62, 0.45, math.sin(a) * 0.62)
				* CFrame.Angles(0, -a, math.rad(10))
		)
		Kit.add(
			crown,
			Kit.block(
				A(0.2, 0.2, 0.2),
				CFrame.new(),
				if i % 2 == 0 then gem else velvet,
				Enum.Material.Neon,
				0,
				Enum.PartType.Ball
			),
			CFrame.new(math.cos(a) * 0.76, 0.05, math.sin(a) * 0.76)
		)
	end
	for _, part in crown.parts do
		part.Transparency = 1
	end
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 8
	glow.Brightness = 0
	glow.Parent = crown.parts[1]
	Kit.at(2.0, function()
		Kit.burst(
			Kit.at3(context, "Head") + A(0, 1.8, 0),
			30,
			Kit.sequence({ GOLD, WHITE }),
			NumberRange.new(4, 8),
			0.35
		)
		glow.Brightness = 2
	end)
	Kit.every(function(t)
		if t < 2.0 then
			return nil
		end
		local show = Kit.span(t, 2.0, 2.3)
		for _, part in crown.parts do
			part.Transparency = 1 - show
		end
		local head = Kit.part(character, "Head")
		if head then
			local height = 1.8 - 0.65 * Kit.span(t, 2.0, 2.7, "Out") + math.sin(t * 2.4) * 0.08
			crown.place(CFrame.new(head.Position + A(0, height, 0)) * CFrame.Angles(0, t * 1.2, 0))
		end
		return nil
	end)
end

---------------------------------------------------------------------------- Meteor Touchdown

local STAND_FISTS = {
	RightUpperLeg = A(0),
	LeftUpperLeg = A(0),
	RightLowerLeg = A(0),
	LeftLowerLeg = A(0),
	UpperTorso = A(0),
	RightUpperArm = A(0, 0, 14),
	LeftUpperArm = A(0, 0, -14),
	RightLowerArm = A(25),
	LeftLowerArm = A(25),
	Head = A(10),
}

local METEOR: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.35,
		angles = {
			RightUpperLeg = A(60),
			LeftUpperLeg = A(60),
			RightLowerLeg = A(-100),
			LeftLowerLeg = A(-100),
			UpperTorso = A(-25),
			RightUpperArm = A(-40),
			LeftUpperArm = A(-40),
		},
	},
	{
		time = 0.5,
		angles = {
			RightUpperLeg = A(0),
			LeftUpperLeg = A(0),
			RightLowerLeg = A(0),
			LeftLowerLeg = A(0),
			UpperTorso = A(0),
			RightUpperArm = A(170),
			LeftUpperArm = A(170),
			Head = A(20),
		},
		ease = "Out",
	},
	{ time = 1.25, angles = {} },
	{
		-- Diving fist first.
		time = 1.4,
		angles = {
			RightUpperArm = A(0),
			LeftUpperArm = A(-60, 0, -40),
			RightUpperLeg = A(-20),
			LeftUpperLeg = A(-20),
			RightLowerLeg = A(-70),
			LeftLowerLeg = A(-70),
			Head = A(-30),
		},
	},
	{ time = 1.8, angles = {} },
	{ time = 1.84, angles = Epic.HERO, ease = "Out" },
	{ time = 2.4, angles = {} },
	{ time = 2.95, angles = STAND_FISTS, ease = "Out" },
}

-- Launches out of sight, comes back down as a meteor and slams into the podium: the shockwave
-- cracks the floor round the podium, breaks bits off every block and leaves a smoking crater.
function Legendary.MeteorTouchdown(context: Context)
	local character = context.character
	local root = context.root
	local colors = context.colors
	local hot = colors[1] or Color3.fromRGB(255, 180, 60)
	local deep = colors[2] or Color3.fromRGB(255, 74, 28)
	local fire = Kit.sequence({ Color3.fromRGB(255, 240, 180), hot, deep })
	local kneel = Epic.kneelDrop(context)
	local base = feet(context)

	Kit.pose(character, METEOR, context.hold)
	Kit.move(context, function(t)
		if t < 0.4 then
			local dip = if t < 0.35 then Kit.span(t, 0, 0.35) else 1 - Kit.span(t, 0.35, 0.4)
			return CFrame.new(0, -0.6 * dip, 0)
		elseif t < 1.3 then
			return CFrame.new(0, 45 * Kit.span(t, 0.4, 0.75, "In"), 0)
		elseif t < 1.8 then
			return CFrame.new(0, 40 - (40 + kneel) * Kit.span(t, 1.3, 1.8, "In"), 0)
		elseif t < 2.4 then
			return CFrame.new(0, -kneel, 0)
		end
		return CFrame.new(0, -kneel * (1 - Kit.span(t, 2.4, 2.95, "Out")), 0)
	end)
	Kit.tilt(function(t)
		return 6 * Kit.span(t, 0.4, 0.9) * (1 - Kit.span(t, 1.1, 1.6))
			- 1.8 * Kit.span(t, 1.8, 1.86) * (1 - Kit.span(t, 1.86, 2.3))
	end)
	-- Charging embers, then fire on the way up and down.
	local embers = Kit.emitter(Kit.attach(root, A(0, -rootHeight(context) + 0.3, 0)), {
		Color = fire,
		Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = A(0, 4, 0),
		Rate = 40,
	})
	local flames = Kit.emitter(Kit.attach(root, Vector3.zero), {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = fire,
		Size = NumberSequence.new(3, 0.5),
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		Transparency = NumberSequence.new(0.2, 1),
		Rate = 0,
	})
	local trail = Kit.trail(root, A(1, 0, 0), A(-1, 0, 0), fire, 0.45)
	trail.Enabled = false
	local ball = Kit.block(A(5, 5, 5), root.CFrame, hot, Enum.Material.Neon, 1, Enum.PartType.Ball)
	Kit.at(0.4, function()
		embers.Rate = 0
		flames.Rate = 120
		trail.Enabled = true
		Kit.ring(base + A(0, 0.1), hot, 10, 0.4)
		Kit.burst(base + A(0, 0.5), 30, fire, NumberRange.new(8, 14), 0.5)
		Kit.shake(1.2, 0.3)
	end)
	Kit.at(0.9, function()
		flames.Rate = 0
		trail.Enabled = false
	end)
	Kit.at(1.3, function()
		flames.Rate = 160
		trail.Enabled = true
	end)
	Kit.every(function(t)
		local on = t > 1.3 and t < 1.82
		ball.Transparency = if on then 0.45 + 0.4 * Kit.span(t, 1.7, 1.82) else 1
		ball.CFrame = root.CFrame * CFrame.new(0, -0.5, 0)
		return t > 1.9
	end)
	Kit.react(context, "Stagger", 1.85)
	Kit.at(1.8, function()
		flames.Rate = 0
		trail.Enabled = false
		Kit.flash(Color3.fromRGB(255, 208, 160), 0.85, 0.6)
		Kit.shake(4, 0.9)
		local top = base + A(0, 0.1, 0)
		Kit.ring(top, hot, 20, 0.6)
		Kit.burst(top + A(0, 1), 70, fire, NumberRange.new(14, 26), 0.6, 12)
		Kit.dust(top + A(0, 0.4), 24, 2)
		-- The shockwave runs out across the floor.
		local floorCenter = Vector3.new(base.X, context.floor + 0.1, base.Z)
		Kit.ring(floorCenter, deep, 60, 1.1)
		Kit.ring(floorCenter + A(0, 0.05, 0), hot, 44, 0.8)
		local scorch = Kit.block(
			A(0.1, 2, 2),
			CFrame.new(floorCenter) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(28, 20, 16),
			nil,
			0.25,
			Enum.PartType.Cylinder
		)
		Kit.tween(scorch, 0.9, { Size = A(0.1, 36, 36) })
		floorCracks(context, floorCenter, 14, 26, deep, 40)
		-- The crater on the winner's block, and its edges breaking off.
		local crater = Kit.block(
			A(0.12, 5, 5),
			CFrame.new(base + A(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(30, 20, 14),
			nil,
			0,
			Enum.PartType.Cylinder
		)
		crater.Material = Enum.Material.Slate
		Epic.cracks(base, deep, 7, 5, 99)
		-- Every block in reach: bits fly off its top corners, cracks glow on its front, it jolts.
		for i, block in context.blocks do
			local flat = Vector3.new(block.Position.X, base.Y, block.Position.Z)
			local distance = (flat - base).Magnitude
			Kit.at(Kit.now() + distance / 40, function()
				local size = block.Size
				local frame = block.CFrame
				for _, corner in { -1, 1 } do
					rubble(
						context,
						(frame * CFrame.new(corner * size.X / 2, size.Y / 2, size.Z / 2)).Position,
						4,
						8,
						block.Color,
						0.6
					)
				end
				local front = frame * CFrame.new(0, 0, size.Z / 2 + 0.04)
				local x = Kit.rnd(-size.X / 4, size.X / 4)
				local a = (front * CFrame.new(x, size.Y / 2, 0)).Position
				local b = (front * CFrame.new(x + Kit.rnd(-1.2, 1.2), size.Y / 2 - size.Y * 0.4, 0)).Position
				local c = (
					front * CFrame.new(x + Kit.rnd(-1.5, 1.5), size.Y / 2 - size.Y * 0.75, 0)
				).Position
				Kit.line(a, b, 0.14, deep)
				Kit.line(b, c, 0.1, deep)
				local charred = block.Color
				local burnt =
					charred:Lerp(Color3.fromRGB(60, 40, 30), if i == 1 then 0.55 else 0.25)
				block.Color = burnt
				Kit.onStop(function()
					block.Color = charred
				end)
				if i > 1 then
					local start = block.CFrame
					local begun = Kit.now()
					Kit.onStop(function()
						block.CFrame = start
					end)
					Kit.every(function(t)
						local u = t - begun
						block.CFrame = start
							+ A(0, math.sin(math.clamp(u / 0.3, 0, 1) * math.pi) * 0.4, 0)
						return u > 0.3
					end)
				end
			end)
		end
		-- Smoke and embers rising from the crater.
		local smokeSpot = Kit.block(A(4, 0.2, 4), CFrame.new(base + A(0, 0.2, 0)), WHITE, nil, 1)
		Kit.emitter(smokeSpot, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Shape = Enum.ParticleEmitterShape.Box,
			Color = ColorSequence.new(Color3.fromRGB(70, 66, 64)),
			LightEmission = 0,
			Size = NumberSequence.new(1.5, 4),
			Transparency = NumberSequence.new(0.4, 1),
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 10,
		})
		Kit.emitter(smokeSpot, {
			Shape = Enum.ParticleEmitterShape.Box,
			Color = fire,
			Size = NumberSequence.new(0.22, 0),
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(2, 4),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 18,
		})
	end)
end

return Legendary
