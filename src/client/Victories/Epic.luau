--!strict
-- The Epic victories (and Trophy Lift): one signature move with an effect in the item's colors,
-- staying on the podium. See docs/polish/victories.md for the beats.
local Kit = require(script.Parent.Kit)

type Context = Kit.Context
type Key = Kit.Key

local Epic = {}

local function A(x: number, y: number?, z: number?): Vector3
	return Vector3.new(x, y or 0, z or 0)
end

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 207, 58)
local DUST = Color3.fromRGB(196, 188, 172)

-- The three-point landing (Backflip, Meteor Touchdown): right knee down, left foot forward, a
-- right fist on the ground, the left arm out behind, head down.
Epic.HERO = {
	RightUpperLeg = A(-5),
	RightLowerLeg = A(-95),
	LeftUpperLeg = A(85),
	LeftLowerLeg = A(-85),
	UpperTorso = A(-30),
	RightUpperArm = A(30),
	RightLowerArm = A(10),
	LeftUpperArm = A(-55, 0, -35),
	LeftLowerArm = A(10),
	Head = A(-30),
}

-- How far the root drops for the hero landing (a knee on the ground).
function Epic.kneelDrop(context: Context): number
	return context.humanoid.HipHeight * 0.5 - 0.2
end

-- Where the character's feet are (under the root, on what they stand on).
local function feet(context: Context): Vector3
	local home = context.home.Position
	return Vector3.new(home.X, context.ground, home.Z)
end

-- Glowing cracks spreading from `center` over a flat surface, fading after `seconds`.
function Epic.cracks(center: Vector3, color: Color3, count: number, length: number, seconds: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + Kit.rnd(-0.3, 0.3)
		local a = center + Vector3.new(0, 0.05, 0)
		local bend = angle + Kit.rnd(-0.5, 0.5)
		local b = a + Vector3.new(math.cos(angle), 0, math.sin(angle)) * length * Kit.rnd(0.4, 0.6)
		local c = b + Vector3.new(math.cos(bend), 0, math.sin(bend)) * length * Kit.rnd(0.3, 0.5)
		for _, piece in { Kit.line(a, b, 0.14, color), Kit.line(b, c, 0.1, color) } do
			Kit.tween(
				piece,
				seconds,
				{ Transparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			Kit.expire(piece, seconds + 0.05)
		end
	end
end

---------------------------------------------------------------------------- Flex

local FLEX: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.25,
		angles = {
			RightUpperArm = A(0, 0, 90),
			RightLowerArm = A(0, 0, 100),
			LeftUpperArm = A(0, 0, -90),
			LeftLowerArm = A(0, 0, -100),
			UpperTorso = A(-8),
		},
	},
}

function Epic.Flex(context: Context)
	Kit.pose(context.character, FLEX, context.hold, true)
	local center = context.root.Position
	local colors = context.colors
	Kit.at(0.3, function()
		Kit.burst(center + A(0, 1), 60, Kit.sequence(colors), NumberRange.new(10, 18), 0.7, 10)
	end)
	Kit.at(0.65, function()
		Kit.burst(center + A(0, 3), 40, colors[2] or colors[1], NumberRange.new(6, 12), 0.5)
	end)
end

---------------------------------------------------------------------------- Backflip

local TUCK = {
	RightUpperLeg = A(120),
	LeftUpperLeg = A(120),
	RightLowerLeg = A(-135),
	LeftLowerLeg = A(-135),
	UpperTorso = A(-20),
	RightUpperArm = A(70),
	LeftUpperArm = A(70),
	RightLowerArm = A(70),
	LeftLowerArm = A(70),
	Head = A(-20),
}

local BACKFLIP: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.18,
		angles = {
			RightUpperLeg = A(55),
			LeftUpperLeg = A(55),
			RightLowerLeg = A(-90),
			LeftLowerLeg = A(-90),
			UpperTorso = A(-25),
			RightUpperArm = A(-45),
			LeftUpperArm = A(-45),
			Head = A(-10),
		},
	},
	{
		time = 0.3,
		angles = {
			RightUpperLeg = A(0),
			LeftUpperLeg = A(0),
			RightLowerLeg = A(0),
			LeftLowerLeg = A(0),
			UpperTorso = A(10),
			RightUpperArm = A(160),
			LeftUpperArm = A(160),
			Head = A(10),
		},
		ease = "Out",
	},
	{ time = 0.42, angles = TUCK },
	{ time = 0.8, angles = TUCK },
	{
		time = 0.93,
		angles = {
			RightUpperLeg = A(30),
			LeftUpperLeg = A(30),
			RightLowerLeg = A(-40),
			LeftLowerLeg = A(-40),
			UpperTorso = A(-10),
			RightUpperArm = A(60, 0, 40),
			LeftUpperArm = A(60, 0, -40),
			RightLowerArm = A(0),
			LeftLowerArm = A(0),
			Head = A(-10),
		},
	},
	{ time = 1.02, angles = Epic.HERO, ease = "Out" },
	{ time = 1.15, angles = { UpperTorso = A(-36), Head = A(-33) } },
	{ time = 1.4, angles = { UpperTorso = A(-30), Head = A(-30) } },
	{ time = 2.2, angles = {} },
	{ time = 2.9, angles = { UpperTorso = A(-24), Head = A(12) }, ease = "Out" },
}

-- A real backflip: dip, spring up about 6 studs, one full turn backwards with the knees
-- tucked, and a superhero landing.
function Epic.Backflip(context: Context)
	local character = context.character
	local kneel = Epic.kneelDrop(context)
	local spin = A(0, 0.2, 0) -- the turn is round the middle of the tucked body
	Kit.pose(character, BACKFLIP, context.hold)
	Kit.move(context, function(t)
		if t < 0.3 then
			local dip = if t < 0.18 then Kit.span(t, 0, 0.18) else 1 - Kit.span(t, 0.18, 0.3)
			return CFrame.new(0, -0.55 * dip, 0)
		elseif t < 0.95 then
			local u = (t - 0.625) / 0.325
			local turn = math.rad(360) * Kit.span(t, 0.33, 0.9)
			return CFrame.new(0, 6 * (1 - u * u), 0) * Kit.around(spin, CFrame.Angles(turn, 0, 0))
		end
		local squash = math.sin(math.clamp((t - 1.02) / 0.35, 0, 1) * math.pi) * 0.15
		return CFrame.new(0, -kneel * Kit.span(t, 0.95, 1.02, "Out") - squash, 0)
	end, function(t)
		return t >= 1.0 -- the landing rests on the block
	end)
	local trails = {}
	for _, name in { "RightFoot", "LeftFoot" } do
		local foot = Kit.part(character, name)
		if foot then
			local trail = Kit.trail(foot, A(0, 0.2), A(0, -0.2), Kit.sequence(context.colors), 0.3)
			trail.Enabled = false
			table.insert(trails, trail)
		end
	end
	Kit.at(0.3, function()
		for _, trail in trails do
			trail.Enabled = true
		end
	end)
	Kit.at(1.0, function()
		for _, trail in trails do
			trail.Enabled = false
		end
		local ground = feet(context)
		Kit.ring(ground + A(0, 0.1), DUST, 14, 0.6)
		Kit.ring(ground + A(0, 0.15), context.colors[1], 10, 0.45)
		Kit.dust(ground + A(0, 0.3), 14, 1.2)
		Epic.cracks(ground, context.colors[1], 6, 4, 1.4)
		Kit.shake(1.4, 0.35)
	end)
	Kit.tilt(function(t)
		return -1.6 * Kit.span(t, 1.0, 1.06) * (1 - Kit.span(t, 1.06, 1.5))
	end)
end

---------------------------------------------------------------------------- Confetti Storm

local UP_R = A(165, 0, 15)
local UP_L = A(165, 0, -15)
local CHEER: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.12,
		angles = { RightUpperArm = UP_R, LeftUpperArm = UP_L, Head = A(15) },
		ease = "Out",
	},
}
for i = 1, 9 do
	local low = i % 2 == 1
	table.insert(CHEER, {
		time = 0.12 + i * 0.32,
		angles = {
			RightUpperArm = if low then A(145, 0, 22) else UP_R,
			LeftUpperArm = if low then A(145, 0, -22) else UP_L,
		},
	})
end
for _, key in
	{
		{
			time = 3.5,
			angles = {
				RightUpperArm = A(50, 0, -35),
				RightLowerArm = A(110),
				LeftUpperArm = A(0),
				Head = A(-15, 30, 0),
			},
		},
		{ time = 3.65, angles = { RightLowerArm = A(85) } },
		{ time = 3.8, angles = { RightLowerArm = A(110) } },
		{ time = 3.95, angles = { RightLowerArm = A(85) } },
		{
			time = 4.4,
			angles = {
				RightUpperArm = UP_R,
				RightLowerArm = A(0),
				LeftUpperArm = UP_L,
				Head = A(15),
			},
			ease = "Out",
		},
	} :: { Key }
do
	table.insert(CHEER, key)
end

type Piece = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	turn: CFrame,
	spin: Vector3,
	phase: number,
	on: BasePart?, -- the body part it landed on
	rest: CFrame?, -- where it lies (relative to `on`, or in the world)
}

-- What a falling piece at `position` lands on: the highest top under it (blocks, heads and
-- shoulders), or the floor. Returns its height and the body part if it's one.
local function landing(context: Context, position: Vector3): (number, BasePart?)
	local best, on = context.floor, nil
	local function check(part: BasePart, body: boolean)
		local here = part.CFrame:PointToObjectSpace(position)
		local size = part.Size
		if math.abs(here.X) <= size.X / 2 and math.abs(here.Z) <= size.Z / 2 then
			local top = part.Position.Y + size.Y / 2
			if top > best and position.Y >= top - 0.6 then
				best = top
				on = if body then part else nil
			end
		end
	end
	for _, block in context.blocks do
		check(block, false)
	end
	for _, model in { context.character, table.unpack(context.others) } do
		for _, name in { "Head", "UpperTorso" } do
			local part = Kit.part(model, name)
			if part then
				check(part, true)
			end
		end
	end
	return best, on
end

-- Confetti cannons from both hands, then a storm that buries the stage: pieces land and stay on
-- the floor, the blocks, heads and shoulders, and some flutter across the screen.
function Epic.ConfettiStorm(context: Context)
	Kit.pose(context.character, CHEER, context.hold)
	Kit.react(context, "LookUp", 0.5)
	local colors = context.colors
	local pieces: { Piece } = {}
	local MAX = 260
	local function piece(position: Vector3, velocity: Vector3)
		if #pieces >= MAX then
			return
		end
		local part = Kit.block(
			Vector3.new(0.42, 0.05, 0.3),
			CFrame.new(position),
			Kit.gradient(colors, Kit.rnd(0, 1))
		)
		table.insert(pieces, {
			part = part,
			position = position,
			velocity = velocity,
			turn = CFrame.Angles(Kit.rnd(0, 6), Kit.rnd(0, 6), Kit.rnd(0, 6)),
			spin = A(Kit.rnd(-6, 6), Kit.rnd(-6, 6), Kit.rnd(-6, 6)),
			phase = Kit.rnd(0, 6),
		})
	end
	Kit.at(0.12, function()
		for _, name in { "RightHand", "LeftHand" } do
			local at = Kit.at3(context, name)
			Kit.burst(at, 30, Kit.sequence(colors), NumberRange.new(12, 20), 0.35, 6, 1)
			for _ = 1, 22 do
				piece(at, A(Kit.rnd(-5, 5), Kit.rnd(16, 26), Kit.rnd(-5, 5)))
			end
		end
	end)
	local home = context.home
	local spawnUntil = context.hold - 0.6
	local carry = 0
	-- Screen confetti: some pieces drift down the screen, a few stick for a moment.
	local screen = Kit.screen()
	type Flake = { frame: Frame, y: number, speed: number, stick: number, stuckAt: number? }
	local flakes: { Flake } = {}
	Kit.every(function(t, dt)
		if t > 0.5 and t < spawnUntil then
			carry += dt * 45
			while carry >= 1 do
				carry -= 1
				local spot = (home * CFrame.new(Kit.rnd(-18, 18), 0, Kit.rnd(-8, 10))).Position
				piece(
					Vector3.new(spot.X, context.ground + Kit.rnd(20, 24), spot.Z),
					A(Kit.rnd(-0.5, 0.5), Kit.rnd(-7, -5), Kit.rnd(-0.5, 0.5))
				)
			end
			if math.random() < dt * 4 then
				local frame = Instance.new("Frame")
				frame.BorderSizePixel = 0
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
				frame.Size = UDim2.fromOffset(Kit.rnd(14, 24), Kit.rnd(9, 14))
				frame.Rotation = Kit.rnd(0, 360)
				frame.BackgroundColor3 = Kit.gradient(colors, Kit.rnd(0, 1))
				frame.Position = UDim2.fromScale(Kit.rnd(0.05, 0.95), -0.05)
				frame.Parent = screen
				table.insert(flakes, {
					frame = frame,
					y = -0.05,
					speed = Kit.rnd(0.12, 0.25),
					stick = if math.random() < 0.35 then Kit.rnd(0.6, 1.1) else 0,
				})
			end
		end
		for i = #flakes, 1, -1 do
			local flake = flakes[i]
			if flake.stick > 0 and not flake.stuckAt and flake.y > Kit.rnd(0.2, 0.6) then
				flake.stuckAt = t
			end
			local stuck = flake.stuckAt ~= nil and t - (flake.stuckAt :: number) < flake.stick
			flake.y += dt * (if stuck
				then 0
				elseif flake.stuckAt then flake.speed * 0.4
				else flake.speed)
			if not stuck and not flake.stuckAt then
				flake.frame.Rotation += dt * 120
			end
			flake.frame.Position = UDim2.fromScale(flake.frame.Position.X.Scale, flake.y)
			if flake.y > 1.1 then
				flake.frame:Destroy()
				table.remove(flakes, i)
			end
		end
		-- The pieces: fall and flutter, then lie where they land (riding a head or shoulder).
		local parts = table.create(#pieces)
		local frames = table.create(#pieces)
		for _, p in pieces do
			if p.rest then
				local frame = if p.on then p.on.CFrame * p.rest else p.rest
				table.insert(parts, p.part)
				table.insert(frames, frame)
				continue
			end
			p.velocity = Vector3.new(
				p.velocity.X * (1 - dt),
				math.max(p.velocity.Y - 30 * dt, -7),
				p.velocity.Z * (1 - dt)
			)
			p.position += (p.velocity + A(
				math.sin(t * 4 + p.phase) * 2.2,
				0,
				math.cos(t * 3 + p.phase) * 1.2
			)) * dt
			p.turn *= CFrame.Angles(p.spin.X * dt, p.spin.Y * dt, p.spin.Z * dt)
			if p.velocity.Y < 0 then
				local top, on = landing(context, p.position)
				if p.position.Y <= top then
					local lie = CFrame.new(p.position.X, top + 0.03, p.position.Z)
						* CFrame.Angles(0, Kit.rnd(0, 6), 0)
					p.on = on
					p.rest = if on then on.CFrame:ToObjectSpace(lie) else lie
				end
			end
			table.insert(parts, p.part)
			table.insert(frames, CFrame.new(p.position) * p.turn)
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		return nil
	end)
end

---------------------------------------------------------------------------- Breakdance

local WINDMILL = {
	RightUpperLeg = A(0, 0, 45),
	LeftUpperLeg = A(0, 0, -45),
	RightLowerLeg = A(0),
	LeftLowerLeg = A(0),
	RightUpperArm = A(0, 0, 80),
	RightLowerArm = A(0),
	LeftUpperArm = A(70),
	LeftLowerArm = A(110),
	UpperTorso = A(0),
	Head = A(10),
}

local BREAKDANCE: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.2,
		angles = {
			RightUpperLeg = A(60),
			LeftUpperLeg = A(60),
			RightLowerLeg = A(-90),
			LeftLowerLeg = A(-90),
			UpperTorso = A(-35),
			RightUpperArm = A(40),
			LeftUpperArm = A(40),
		},
	},
	{ time = 0.4, angles = WINDMILL },
	{ time = 2.58, angles = WINDMILL },
	{
		-- The freeze: propped on the left hand, the right leg sticking straight out, the left
		-- tucked, the right arm thrown up.
		time = 2.7,
		angles = {
			LeftUpperArm = A(0, 0, -60),
			LeftLowerArm = A(0),
			RightUpperArm = A(0, 0, 130),
			RightLowerArm = A(0),
			RightUpperLeg = A(10, 0, 55),
			RightLowerLeg = A(0),
			LeftUpperLeg = A(75),
			LeftLowerLeg = A(-100),
			Head = A(0, 0, -20),
		},
		ease = "Out",
	},
	{ time = 3.0, angles = { Head = A(-12, 0, -20) } },
	{ time = 3.15, angles = { Head = A(0, 0, -20) } },
	{ time = 3.45, angles = { Head = A(-12, 0, -20) } },
	{ time = 3.6, angles = { Head = A(0, 0, -20) } },
}

-- A windmill: rolls round over the shoulders and back with the legs in a wide V, four turns,
-- faster and faster, then snaps into a one-hand freeze with a leg out. The body's lowest point
-- is kept on the block the whole time, so it never sinks in or floats.
function Epic.Breakdance(context: Context)
	local character = context.character
	local rootHeight = context.humanoid.HipHeight + context.root.Size.Y / 2
	local shoulder = A(0, 1.4, 0.45) -- upper back: what the windmill turns on
	local turns = math.pi * 2 * 4
	local function windmill(phi: number): CFrame
		return CFrame.new(0, -rootHeight + 0.55, 0)
			* CFrame.Angles(0, phi, 0)
			* CFrame.Angles(math.rad(80), 0, 0)
			* CFrame.Angles(0, phi, 0)
			* CFrame.new(-shoulder)
	end
	local crouch = CFrame.new(0, -0.8, 0)
	local freeze = CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.rad(60))
	Kit.pose(character, BREAKDANCE, context.hold)
	Kit.move(context, function(t)
		if t < 0.2 then
			return CFrame.new():Lerp(crouch, Kit.span(t, 0, 0.2))
		elseif t < 0.4 then
			return crouch:Lerp(windmill(0), Kit.span(t, 0.2, 0.4))
		elseif t < 2.6 then
			return windmill(turns * Kit.span(t, 0.4, 2.6, "Linear") ^ 1.5)
		end
		return windmill(turns):Lerp(freeze, Kit.span(t, 2.6, 2.72, "Out"))
	end, function()
		return true -- always touching the podium
	end)
	local trails = {}
	for _, name in { "RightFoot", "LeftFoot" } do
		local foot = Kit.part(character, name)
		if foot then
			local trail =
				Kit.trail(foot, A(0, 0.25), A(0, -0.25), Kit.sequence(context.colors), 0.35)
			trail.Enabled = false
			table.insert(trails, trail)
		end
	end
	Kit.at(0.4, function()
		for _, trail in trails do
			trail.Enabled = true
		end
	end)
	local ground = feet(context)
	for i = 0, 11 do
		Kit.at(0.45 + i * 0.18, function()
			Kit.dust(ground + A(Kit.rnd(-1.5, 1.5), 0.2, Kit.rnd(-1.5, 1.5)), 4, 0.8)
		end)
	end
	Kit.at(2.66, function()
		for _, trail in trails do
			trail.Enabled = false
		end
		Kit.ring(ground + A(0, 0.1), context.colors[1], 18, 0.55)
		Kit.ring(ground + A(0, 0.15), context.colors[2] or context.colors[1], 12, 0.5)
		Kit.burst(ground + A(0, 1), 40, Kit.sequence(context.colors), NumberRange.new(10, 18), 0.45)
		Kit.shake(1.2, 0.3)
	end)
end

---------------------------------------------------------------------------- Katana

-- The body round the arms (the arms themselves reach for the sword and sheath): a wide stance,
-- the torso twisting into each cut.
local KATANA: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.25,
		angles = {
			UpperTorso = A(0, 18, 0),
			Head = A(-12),
			RightUpperLeg = A(0, 0, 10),
			LeftUpperLeg = A(0, 0, -10),
		},
	},
	{ time = 0.6, angles = { UpperTorso = A(0, -8, 0), Head = A(8) } },
	{ time = 1.3, angles = { UpperTorso = A(0) } },
	{ time = 1.45, angles = { UpperTorso = A(0, -22, 0) } }, -- the apple: wind up right
	{ time = 1.62, angles = { UpperTorso = A(-8, 25, 0) }, ease = "In" },
	{ time = 1.85, angles = { UpperTorso = A(0, 30, 0) } }, -- the banana: wind up left
	{ time = 2.05, angles = { UpperTorso = A(0, -28, 0) }, ease = "In" },
	{ time = 2.35, angles = { UpperTorso = A(12, 0, 0), Head = A(15) } }, -- the watermelon: raise
	{ time = 2.55, angles = { UpperTorso = A(-22, 0, 0), Head = A(-5) }, ease = "In" },
	{ time = 2.85, angles = { UpperTorso = A(0, -25, 0), Head = A(8) } }, -- the bomb: wind up
	{ time = 3.12, angles = { UpperTorso = A(0, 30, 0) }, ease = "In" },
	{ time = 3.4, angles = { UpperTorso = A(0, 20, 0) } },
	{ time = 3.9, angles = { UpperTorso = A(0, 15, 0), Head = A(-10) } },
	{ time = 4.5, angles = { UpperTorso = A(0), Head = A(-14) } },
}

-- Thrown by a blast and landing like a ragdoll: arms flung, then limp.
local SLUMP: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.2,
		angles = {
			RightUpperArm = A(60, 0, 80),
			LeftUpperArm = A(60, 0, -80),
			RightUpperLeg = A(20),
			Head = A(-15),
		},
		ease = "Out",
	},
	{
		time = 0.75,
		angles = {
			RightUpperArm = A(10, 0, 100),
			LeftUpperArm = A(-10, 0, -70),
			RightLowerArm = A(20),
			LeftLowerArm = A(40),
			RightUpperLeg = A(35, 0, 10),
			RightLowerLeg = A(-50),
			LeftUpperLeg = A(10, 0, -5),
			LeftLowerLeg = A(-15),
			Head = A(-10, 0, 25),
		},
	},
}

-- A hand's turn for gripping a hilt that runs along `blade` (out of the hand's front, -Z), the
-- forearm coming in toward `forearm` (the hand's top, +Y).
local function gripTurn(blade: Vector3, forearm: Vector3): CFrame
	local back = -blade.Unit
	local right = forearm:Cross(back)
	right = if right.Magnitude < 1e-3 then Vector3.xAxis else right.Unit
	return CFrame.fromMatrix(Vector3.zero, right, back:Cross(right), back)
end

-- The sheath on the left hip: its mouth, and the way into it (back and down), in the lower
-- torso's space. -Z of this frame points into the sheath.
local MOUTH = A(-1.15, 0.15, -0.55)
local SHEATH = CFrame.lookAt(MOUTH, MOUTH + A(0, -0.45, 0.89))
local BLADE = 4.4 -- guard to tip
local GRIP = 0.5 -- the hilt's middle, behind the guard (the sword's origin)
local FLIGHT = 0.8 -- seconds a fruit flies before the blade meets it
local GRAVITY = 30

-- An egg shape (a stretched ball) in `prop`.
local function egg(
	prop: Kit.Prop,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): BasePart
	local part = Kit.block(size, CFrame.new(), color, material, transparency)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return Kit.add(prop, part, offset)
end

local function stick(
	prop: Kit.Prop,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return Kit.add(prop, Kit.block(size, CFrame.new(), color, material), offset)
end

-- Half of a round fruit, cut face up (+Y) at its origin: a rounded skin below and a flat face
-- of `faces` (outer first: rind, flesh...) on top.
local function dome(diameter: number, skin: Color3, faces: { Color3 }): Kit.Prop
	local half = Kit.prop()
	local rim = diameter * 0.22
	Kit.add(
		half,
		Kit.block(A(rim, diameter, diameter), CFrame.new(), skin, nil, 0, Enum.PartType.Cylinder),
		CFrame.new(0, -rim / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	egg(half, A(diameter, diameter * 0.58, diameter), CFrame.new(0, -rim, 0), skin)
	for i, color in faces do
		local width = diameter * (0.93 - (i - 1) * 0.12)
		egg(half, A(width, 0.05, width), CFrame.new(0, diameter * 0.075 + i * 0.025, 0), color)
	end
	return half
end

type Fruit = {
	whole: Kit.Prop,
	halves: { Kit.Prop },
	across: boolean, -- halves split along the fruit's own X (a banana) rather than the cut
	juice: { Color3 },
	face: number, -- how high the top of a half's face is (for the seeds)
	spark: BasePart?, -- a bomb's fuse
}

local function apple(): Fruit
	local whole = Kit.prop()
	local red = Color3.fromRGB(190, 24, 36)
	egg(whole, A(1.4, 1.3, 1.4), CFrame.new(), red)
	egg(whole, A(1.0, 0.95, 1.0), CFrame.new(0.24, 0.1, -0.3), Color3.fromRGB(222, 70, 42))
	egg(whole, A(0.5, 0.2, 0.5), CFrame.new(0, 0.6, 0), Color3.fromRGB(120, 16, 24))
	stick(
		whole,
		A(0.08, 0.42, 0.08),
		CFrame.new(0.03, 0.78, 0) * CFrame.Angles(0, 0, math.rad(-10)),
		Color3.fromRGB(92, 62, 34)
	)
	egg(
		whole,
		A(0.48, 0.05, 0.22),
		CFrame.new(0.24, 0.84, 0) * CFrame.Angles(0, 0.4, math.rad(28)),
		Color3.fromRGB(70, 150, 50)
	)
	egg(whole, A(0.34, 0.16, 0.22), CFrame.new(-0.32, 0.36, -0.52), WHITE, nil, 0.45)
	local flesh, core, seed =
		Color3.fromRGB(246, 234, 196), Color3.fromRGB(230, 206, 150), Color3.fromRGB(70, 40, 20)
	local halves = {}
	for _ = 1, 2 do
		local half = dome(1.4, red, { red, flesh })
		egg(half, A(0.5, 0.05, 0.62), CFrame.new(0, 0.2, 0), core)
		for _, x in { -0.11, 0.11 } do
			egg(half, A(0.12, 0.06, 0.2), CFrame.new(x, 0.23, 0), seed)
		end
		table.insert(halves, half)
	end
	return { whole = whole, halves = halves, across = false, juice = { flesh, WHITE }, face = 0.2 }
end

local function watermelon(): Fruit
	local whole = Kit.prop()
	local skin, stripe = Color3.fromRGB(96, 164, 62), Color3.fromRGB(30, 86, 36)
	egg(whole, A(2.7, 2.0, 2.0), CFrame.new(), skin)
	for k = 0, 5 do
		egg(whole, A(2.72, 2.02, 0.3), CFrame.Angles(k * math.pi / 6, 0, 0), stripe)
	end
	stick(whole, A(0.18, 0.16, 0.16), CFrame.new(1.38, 0, 0), Color3.fromRGB(110, 90, 50))
	egg(whole, A(0.8, 0.3, 0.5), CFrame.new(-0.4, 0.6, -0.75), WHITE, nil, 0.6)
	local halves = {}
	for _ = 1, 2 do
		local half =
			dome(2.0, stripe, { Color3.fromRGB(226, 242, 204), Color3.fromRGB(232, 46, 60) })
		for k = 1, 9 do
			local a = k / 9 * math.pi * 2
			egg(
				half,
				A(0.1, 0.05, 0.17),
				CFrame.new(math.cos(a) * 0.5, 0.28, math.sin(a) * 0.5) * CFrame.Angles(0, -a, 0),
				Color3.fromRGB(20, 16, 14)
			)
		end
		table.insert(halves, half)
	end
	return {
		whole = whole,
		halves = halves,
		across = false,
		juice = { Color3.fromRGB(235, 40, 55), Color3.fromRGB(255, 130, 130) },
		face = 0.25,
	}
end

local function banana(): Fruit
	local yellow, end_ = Color3.fromRGB(250, 214, 60), Color3.fromRGB(210, 176, 40)
	local function segments(prop: Kit.Prop, from: number, to: number)
		for a = from, to, 20 do
			local r = math.rad(a)
			local tip = math.abs(a) >= 50
			egg(
				prop,
				if tip then A(0.52, 0.32, 0.32) else A(0.64, 0.42, 0.42),
				CFrame.new(1.5 * math.sin(r), 1.5 * math.cos(r) - 1.5, 0) * CFrame.Angles(0, 0, -r),
				if tip then end_ else yellow
			)
		end
	end
	local function stem(prop: Kit.Prop)
		local r = math.rad(64)
		stick(
			prop,
			A(0.36, 0.13, 0.13),
			CFrame.new(1.5 * math.sin(r), 1.5 * math.cos(r) - 1.5, 0) * CFrame.Angles(0, 0, -r),
			Color3.fromRGB(110, 92, 40)
		)
	end
	local function nub(prop: Kit.Prop)
		local r = math.rad(-62)
		egg(
			prop,
			A(0.16, 0.16, 0.16),
			CFrame.new(1.5 * math.sin(r), 1.5 * math.cos(r) - 1.5, 0),
			Color3.fromRGB(60, 44, 24)
		)
	end
	local whole = Kit.prop()
	segments(whole, -50, 50)
	stem(whole)
	nub(whole)
	local flesh = Color3.fromRGB(250, 240, 200)
	local left, right = Kit.prop(), Kit.prop()
	segments(left, -50, -10)
	nub(left)
	egg(left, A(0.05, 0.38, 0.38), CFrame.new(-0.18, -0.01, 0), flesh)
	segments(right, 10, 50)
	stem(right)
	egg(right, A(0.05, 0.38, 0.38), CFrame.new(0.18, -0.01, 0), flesh)
	return {
		whole = whole,
		halves = { left, right },
		across = true,
		juice = { flesh, Color3.fromRGB(255, 236, 150) },
		face = 0,
	}
end

local function bomb(): Fruit
	local whole = Kit.prop()
	local black = Color3.fromRGB(26, 26, 32)
	local body = egg(whole, A(1.7, 1.7, 1.7), CFrame.new(), black)
	body.Reflectance = 0.15
	egg(whole, A(0.5, 0.28, 0.3), CFrame.new(-0.42, 0.45, -0.62), WHITE, nil, 0.35)
	Kit.add(
		whole,
		Kit.block(
			A(0.3, 0.75, 0.75),
			CFrame.new(),
			Color3.fromRGB(70, 70, 78),
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	stick(
		whole,
		A(0.09, 0.45, 0.09),
		CFrame.new(0.06, 1.25, 0) * CFrame.Angles(0, 0, math.rad(-15)),
		Color3.fromRGB(140, 110, 70)
	)
	stick(
		whole,
		A(0.09, 0.35, 0.09),
		CFrame.new(0.22, 1.55, 0) * CFrame.Angles(0, 0, math.rad(-45)),
		Color3.fromRGB(140, 110, 70)
	)
	local spark = Kit.add(
		whole,
		Kit.block(
			A(0.26, 0.26, 0.26),
			CFrame.new(),
			Color3.fromRGB(255, 170, 60),
			Enum.Material.Neon,
			0,
			Enum.PartType.Ball
		),
		CFrame.new(0.36, 1.7, 0)
	)
	local halves = {}
	for _ = 1, 2 do
		table.insert(
			halves,
			dome(1.7, black, { Color3.fromRGB(46, 46, 52), Color3.fromRGB(70, 66, 60) })
		)
	end
	return {
		whole = whole,
		halves = halves,
		across = false,
		juice = { Color3.fromRGB(255, 190, 90), WHITE },
		face = 0.2,
		spark = spark,
	}
end

-- A turn whose up (+Y) is `up`.
local function upward(up: Vector3): CFrame
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 1e-3 then
		right = up:Cross(Vector3.xAxis)
	end
	return CFrame.fromMatrix(Vector3.zero, right.Unit, up.Unit)
end

-- A block knocked over by a blast: it hops, tips over outward onto its side and slides; whoever
-- stood on it is thrown off and lands on the floor like a ragdoll. `out` is +1 or -1 (world X).
local function topple(context: Context, block: BasePart, out: number, rider: Model?)
	local size, base = block.Size, block.CFrame
	local edge = (base * CFrame.new(out * size.X / 2, -size.Y / 2, 0)).Position
	Kit.onStop(function()
		block.CFrame = base
	end)
	for _, corner in { -1, 1 } do
		Kit.rubble(
			context,
			(base * CFrame.new(corner * size.X / 2, size.Y / 2, size.Z / 2)).Position,
			4,
			9,
			block.Color,
			0.5,
			true
		)
	end
	local begun = Kit.now()
	local landed = false
	Kit.every(function(t)
		local u = t - begun
		local fall = Kit.span(u, 0, 0.75, "In")
		local hop = math.sin(math.clamp(u / 0.3, 0, 1) * math.pi) * 0.7
		local slide = A(out * 1.8 * Kit.span(u, 0, 1.0, "Out"), hop, 0)
		block.CFrame = CFrame.new(edge + slide)
			* CFrame.Angles(0, 0, -out * math.rad(90) * fall)
			* CFrame.new(-edge)
			* base
		if u >= 0.75 and not landed then
			landed = true
			Kit.dust(Vector3.new(edge.X + out * size.Y / 2, context.floor + 0.3, edge.Z), 18, 1.6)
			Kit.shake(1.4, 0.3)
		end
		return u > 1.05
	end)
	if not rider then
		return
	end
	local start = rider:GetPivot()
	Kit.onStop(function()
		if rider.Parent then
			rider:PivotTo(start)
		end
	end)
	Kit.pose(rider, SLUMP, context.hold)
	local velocity = A(out * 9, 13, Kit.rnd(-1, 1))
	local spin = Kit.rnd(-1, 1)
	Kit.every(function(t)
		local u = t - begun
		local position = start.Position + velocity * math.min(u, 1.2) + A(0, -18 * u * u, 0)
		local frame = CFrame.new(position)
			* CFrame.Angles(0, spin * u, -out * math.rad(100) * Kit.span(u, 0, 0.7))
			* start.Rotation
		rider:PivotTo(frame)
		local low = Kit.lowest(rider)
		if low < context.floor then
			rider:PivotTo(frame + A(0, context.floor - low, 0))
		end
		return u > 1.6
	end)
end

-- Fruit Ninja with a katana: draws it from the hip, spins it, then slices an apple, a banana
-- and a watermelon tossed up into the air, one cut each, with juice flying. The last thing up
-- is a bomb: the wide cut that hangs in the air splits it, it blows up in front of the podium,
-- knocking 2nd and 3rd's blocks over and throwing them to the floor. Then the blade slides home
-- and the hanging cut scatters into petals.
function Epic.Katana(context: Context)
	local character = context.character
	local lower = Kit.part(character, "LowerTorso")
	if not lower then
		return
	end
	local home = context.home
	local colors = context.colors
	local steel = Color3.fromRGB(226, 232, 240)
	local ink = Color3.fromRGB(26, 22, 30)

	local sheath = Kit.prop()
	Kit.add(
		sheath,
		Kit.block(A(0.3, 0.36, BLADE + 0.2), CFrame.new(), ink),
		CFrame.new(0, 0, -(BLADE + 0.2) / 2)
	)
	Kit.add(
		sheath,
		Kit.block(A(0.38, 0.44, 0.25), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, -0.12)
	)
	Kit.add(
		sheath,
		Kit.block(A(0.34, 0.4, 0.2), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, -BLADE - 0.1)
	)
	-- A long, thin blade with a bright edge and a pointed tip.
	local sword = Kit.prop()
	local length = BLADE - 0.55
	local blade = Kit.add(
		sword,
		Kit.block(A(0.06, 0.26, length), CFrame.new(), steel, Enum.Material.Metal),
		CFrame.new(0, 0, -length / 2 - 0.05)
	)
	blade.Reflectance = 0.4
	Kit.add(
		sword,
		Kit.block(
			A(0.03, 0.04, length),
			CFrame.new(),
			Color3.fromRGB(240, 248, 255),
			Enum.Material.Neon,
			0.3
		),
		CFrame.new(0, -0.13, -length / 2 - 0.05)
	)
	local tip = Kit.wedge(A(0.06, 0.26, 0.55), CFrame.new(), steel, Enum.Material.Metal)
	tip.Reflectance = 0.4
	Kit.add(sword, tip, CFrame.new(0, 0, -length - 0.05 - 0.275))
	Kit.add(
		sword,
		Kit.block(A(0.12, 0.32, 0.2), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, -0.1)
	)
	Kit.add(
		sword,
		Kit.block(
			A(0.12, 0.6, 0.6),
			CFrame.new(),
			GOLD,
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder
		),
		CFrame.Angles(0, math.pi / 2, 0)
	)
	Kit.add(
		sword,
		Kit.block(A(0.22, 0.24, 1.0), CFrame.new(), Color3.fromRGB(70, 20, 34)),
		CFrame.new(0, 0, 0.55)
	)
	for k = 0, 3 do
		Kit.add(
			sword,
			Kit.block(A(0.24, 0.26, 0.06), CFrame.new(), ink),
			CFrame.new(0, 0, 0.18 + k * 0.24)
				* CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 30 else -30))
		)
	end
	Kit.add(
		sword,
		Kit.block(A(0.26, 0.28, 0.12), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, 1.1)
	)
	local trail = Kit.trail(
		blade,
		A(0, 0, -length / 2),
		A(0, 0, length / 2 - 0.3),
		Kit.sequence(colors),
		0.18
	)
	trail.Enabled = false

	-- The sword's path, in the character's space (+X its right, -Z toward the camera).
	local function at(position: Vector3, toward: Vector3): CFrame
		return home * CFrame.lookAt(position, position + toward)
	end
	local READY = at(A(1.3, 0.5, -1.4), A(0.15, 0.9, -0.6))
	local HIGH_RIGHT = at(A(1.6, 2.3, -0.8), A(0.5, 0.8, 0.2))
	local ACROSS = at(A(0.6, 1.2, -1.6), A(0.1, 0.1, -1))
	local LOW_LEFT = at(A(-0.6, -0.1, -1.6), A(-0.6, -0.6, -0.5))
	local OVERHEAD = at(A(0.6, 2.6, -0.4), A(0, 0.5, 1))
	local UPRIGHT = at(A(0.5, 2.4, -1.1), A(0, 1, -0.1))
	local DOWN = at(A(0.4, 0.1, -1.7), A(0, -0.7, -0.7))
	local LOW = at(A(-1.0, 0.1, -1.4), A(-0.6, -0.5, -0.7))
	local center, radius = A(0.8, 0.9, 0), 1.8
	local function arc(angle: number): CFrame
		local x, z = math.sin(angle), -math.cos(angle)
		return at(center + A(x, 0, z) * radius, A(x, -0.08, z))
	end
	local swingFrom, swingTo = math.rad(-50), math.rad(65) -- the banana, left to right
	local cutFrom, cutTo = math.rad(60), math.rad(-45) -- the bomb, right to left
	local function sheathed(slide: number): CFrame
		return (lower :: BasePart).CFrame * SHEATH * CFrame.new(0, 0, slide)
	end
	local function spun(spin: number): CFrame
		return READY * CFrame.new(0, 0, GRIP) * CFrame.Angles(spin, 0, 0) * CFrame.new(0, 0, -GRIP)
	end
	local function swordAt(t: number): CFrame
		if t < 0.3 then
			return sheathed(0)
		elseif t < 0.5 then
			return sheathed(BLADE * Kit.span(t, 0.3, 0.5, "In"))
		elseif t < 0.75 then
			return sheathed(BLADE):Lerp(READY, Kit.span(t, 0.5, 0.75))
		elseif t < 1.3 then
			return spun(-math.pi * 4 * Kit.span(t, 0.75, 1.3))
		elseif t < 1.45 then
			return READY:Lerp(HIGH_RIGHT, Kit.span(t, 1.3, 1.45))
		elseif t < 1.535 then
			return HIGH_RIGHT:Lerp(ACROSS, Kit.span(t, 1.45, 1.535, "In"))
		elseif t < 1.62 then
			return ACROSS:Lerp(LOW_LEFT, Kit.span(t, 1.535, 1.62, "Out"))
		elseif t < 1.85 then
			return LOW_LEFT:Lerp(arc(swingFrom), Kit.span(t, 1.62, 1.85))
		elseif t < 2.05 then
			return arc(swingFrom + (swingTo - swingFrom) * Kit.span(t, 1.85, 2.05))
		elseif t < 2.35 then
			return arc(swingTo):Lerp(OVERHEAD, Kit.span(t, 2.05, 2.35))
		elseif t < 2.45 then
			return OVERHEAD:Lerp(UPRIGHT, Kit.span(t, 2.35, 2.45, "In"))
		elseif t < 2.55 then
			return UPRIGHT:Lerp(DOWN, Kit.span(t, 2.45, 2.55, "Out"))
		elseif t < 2.85 then
			return DOWN:Lerp(arc(cutFrom), Kit.span(t, 2.55, 2.85))
		elseif t < 3.12 then
			return arc(cutFrom + (cutTo - cutFrom) * Kit.span(t, 2.85, 3.12))
		elseif t < 3.4 then
			return arc(cutTo):Lerp(LOW, Kit.span(t, 3.12, 3.4, "Out"))
		elseif t < 3.9 then
			return LOW:Lerp(sheathed(BLADE), Kit.span(t, 3.4, 3.9))
		end
		return sheathed(BLADE * (1 - Kit.span(t, 3.9, 4.3, "Out")))
	end

	local arcParts: { BasePart } = {}
	local lastTip: Vector3? = nil
	Kit.pose(character, KATANA, context.hold)
	Kit.every(function(t)
		local show = Kit.span(t, 0, 0.25)
		for _, part in sheath.parts do
			part.Transparency = 1 - show
		end
		for i, part in sword.parts do
			part.Transparency = if i == 2 then 1 - 0.7 * show else 1 - show
		end
		sheath.place((lower :: BasePart).CFrame * SHEATH)
		local frame = swordAt(t)
		-- The right hand grips the hilt, turned with the blade; the sword then sits exactly in it
		-- (even at full stretch).
		local grip = (frame * CFrame.new(0, 0, GRIP)).Position
		local edge = frame.LookVector -- the way the blade points
		local function forearm(side: string): Vector3
			local upper = Kit.part(character, side .. "UpperArm")
			return if upper then upper.Position - grip else Vector3.yAxis
		end
		local held = Kit.reach(
			character,
			"Right",
			grip,
			(home * CFrame.new(2.6, -1.2, 1)).Position,
			Kit.span(t, 0.05, 0.3),
			gripTurn(edge, forearm("Right"))
		)
		if held and t > 0.3 then
			frame += held - grip
		end
		-- The left hand steadies the sheath, lets go for the spin and the quick cuts, then joins
		-- the right on the hilt for the two-handed chop and the big cut, and goes back to the
		-- sheath to take the blade home.
		local sheathHold = (sheathed(0) * CFrame.new(0, 0, -0.7)).Position
		local pommel = (frame * CFrame.new(0, 0, GRIP + 0.42)).Position
		local twoHands = Kit.span(t, 2.05, 2.25) * (1 - Kit.span(t, 3.15, 3.35))
		local free = Kit.span(t, 0.7, 0.8) * (1 - Kit.span(t, 2.05, 2.25))
		Kit.reach(
			character,
			"Left",
			sheathHold:Lerp(pommel, twoHands),
			(home * CFrame.new(-2.6, -1.2, 0.6)).Position,
			Kit.span(t, 0.1, 0.35) * (1 - free),
			if twoHands > 0.5 then gripTurn(edge, forearm("Left")) else nil
		)
		sword.place(frame)
		trail.Enabled = t > 0.45 and t < 3.4
		-- The big cut leaves its arc hanging in the air.
		local point = (frame * CFrame.new(0, 0, -BLADE)).Position
		if t >= 2.85 and t <= 3.14 then
			if lastTip then
				table.insert(
					arcParts,
					Kit.line(lastTip, point, 0.22, Kit.gradient(colors, #arcParts / 16), 0.1)
				)
			end
			lastTip = point
		end
		return nil
	end)
	Kit.at(0.5, function()
		Kit.burst((blade :: BasePart).Position, 14, WHITE, NumberRange.new(4, 8), 0.35)
	end)

	-- The fruit: each one tossed up from below the stage so the blade meets it mid-cut.
	local floorBelow = context.floor - home.Position.Y - 1.2
	local throws = {
		{ make = apple, hit = 1.535, from = A(2.6, floorBelow, -5) },
		{ make = banana, hit = 1.95, from = A(-3, floorBelow, -5.5) },
		{ make = watermelon, hit = 2.5, from = A(0.6, floorBelow, -6) },
		{ make = bomb, hit = 2.985, from = A(-1.6, floorBelow, -5) },
	}
	for _, throw in throws do
		local fruit = throw.make()
		local cutFrame = swordAt(throw.hit)
		local hitAt = (cutFrame * CFrame.new(0, 0, -BLADE * 0.66)).Position
		local from = (home * throw.from)
		local launch = (hitAt - from) / FLIGHT + A(0, GRAVITY / 2 * FLIGHT, 0)
		local tumble = A(Kit.rnd(-4, 4), Kit.rnd(-4, 4), Kit.rnd(-4, 4))
		local normal = cutFrame.RightVector -- the blade's flat: the halves fly apart along it
		local hidden = CFrame.new(from - A(0, 60, 0))
		local wholeAt = CFrame.new(from)
		local cut = false
		local resting = { false, false }
		local rests: { CFrame } = {}
		local isBomb = fruit.spark ~= nil
		for _, half in fruit.halves do
			half.place(hidden)
		end
		if fruit.spark then
			Kit.emitter(fruit.spark, {
				Color = ColorSequence.new(
					Color3.fromRGB(255, 230, 140),
					Color3.fromRGB(255, 120, 40)
				),
				Size = NumberSequence.new(0.18, 0),
				Lifetime = NumberRange.new(0.2, 0.45),
				Speed = NumberRange.new(3, 7),
				SpreadAngle = Vector2.new(180, 180),
				Rate = 70,
			})
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 160, 60)
			glow.Range = 6
			glow.Parent = fruit.spark
		end
		Kit.every(function(t)
			local u = t - (throw.hit - FLIGHT)
			if u < 0 then
				fruit.whole.place(CFrame.new(from))
				return nil
			end
			if t < throw.hit then
				wholeAt = CFrame.new(from + launch * u + A(0, -GRAVITY / 2 * u * u, 0))
					* CFrame.Angles(tumble.X * u, tumble.Y * u, tumble.Z * u)
				fruit.whole.place(wholeAt)
				return nil
			end
			if not cut then
				cut = true
				fruit.whole.place(hidden)
				Kit.burst(
					hitAt,
					if isBomb then 25 else 50,
					Kit.sequence(fruit.juice),
					NumberRange.new(6, 15),
					0.35,
					30,
					0.9
				)
				local streak = Kit.line(
					hitAt - cutFrame.LookVector * 1.8,
					hitAt + cutFrame.LookVector * 1.8,
					0.12,
					WHITE
				)
				Kit.tween(streak, 0.25, { Transparency = 1 })
				Kit.shake(0.5, 0.15)
			end
			-- The halves fly apart, tumbling, and lie where they land (a bomb's drift apart
			-- slowly until it goes off).
			local w = t - throw.hit
			local velocity = launch + A(0, -GRAVITY * FLIGHT, 0)
			local apart = if isBomb then 1.5 else 5
			for i, half in fruit.halves do
				if isBomb and t >= 3.4 then
					half.place(hidden)
					continue
				end
				if resting[i] then
					half.place(rests[i])
					continue
				end
				local side = if i == 1 then 1 else -1
				local away = if fruit.across then wholeAt.RightVector * -side else normal * side
				local position = hitAt
					+ away * (0.15 + apart * w)
					+ (velocity * 0.35 + A(0, 4, 0)) * w
					+ A(0, -GRAVITY / 2 * 1.15 * w * w, 0)
				local turn = if fruit.across
					then wholeAt.Rotation * CFrame.Angles(0, 0, side * w * 3)
					else upward(-away) * CFrame.Angles(w * 2.5 * side, 0, 0)
				local frame = CFrame.new(position) * turn
				if position.Y <= context.floor + 0.45 then
					frame = CFrame.new(position.X, context.floor + 0.45, position.Z) * turn
					resting[i] = true
					rests[i] = frame
				end
				half.place(frame)
			end
			return (resting[1] and resting[2]) or (isBomb and t >= 3.4)
		end)
		if isBomb then
			-- The bomb goes off between its halves, in front of the podium.
			Kit.at(3.4, function()
				local w = 3.4 - throw.hit
				local velocity = (launch + A(0, -GRAVITY * FLIGHT, 0)) * 0.35 + A(0, 4, 0)
				local blast = hitAt + velocity * w + A(0, -GRAVITY / 2 * 1.15 * w * w, 0)
				Kit.flash(Color3.fromRGB(255, 222, 170), 0.95, 0.7)
				Kit.shake(4.5, 1)
				local fireball = Kit.block(
					A(1, 1, 1),
					CFrame.new(blast),
					Color3.fromRGB(255, 150, 40),
					Enum.Material.Neon,
					0,
					Enum.PartType.Ball
				)
				Kit.tween(fireball, 0.35, { Size = A(16, 16, 16), Transparency = 0.6 })
				Kit.at(3.75, function()
					Kit.tween(
						fireball,
						0.6,
						{ Transparency = 1, Color = Color3.fromRGB(80, 40, 20) }
					)
				end)
				local core = Kit.block(
					A(0.5, 0.5, 0.5),
					CFrame.new(blast),
					WHITE,
					Enum.Material.Neon,
					0,
					Enum.PartType.Ball
				)
				Kit.tween(core, 0.25, { Size = A(9, 9, 9), Transparency = 1 })
				Kit.burst(
					blast,
					120,
					Kit.sequence({
						Color3.fromRGB(255, 240, 180),
						Color3.fromRGB(255, 140, 40),
						Color3.fromRGB(200, 50, 20),
					}),
					NumberRange.new(18, 36),
					0.7,
					10,
					1.1
				)
				Kit.dust(blast, 30, 3, Color3.fromRGB(70, 64, 60))
				Kit.ring(
					Vector3.new(blast.X, context.floor + 0.1, blast.Z),
					Color3.fromRGB(255, 140, 40),
					40,
					0.8
				)
				Kit.rubble(context, blast, 14, 16, Color3.fromRGB(40, 36, 34), 0.4, true)
				local smoke = Kit.block(A(4, 4, 4), CFrame.new(blast), WHITE, nil, 1)
				local puffs = Kit.emitter(smoke, {
					Texture = "rbxasset://textures/particles/smoke_main.dds",
					Shape = Enum.ParticleEmitterShape.Box,
					Color = ColorSequence.new(Color3.fromRGB(60, 56, 54)),
					LightEmission = 0,
					Size = NumberSequence.new(3, 8),
					Transparency = NumberSequence.new(0.35, 1),
					Lifetime = NumberRange.new(2, 3),
					Speed = NumberRange.new(2, 5),
					SpreadAngle = Vector2.new(180, 180),
					Acceleration = A(0, 3, 0),
					Rate = 30,
				})
				Kit.at(4.6, function()
					puffs.Rate = 0
				end)
				-- 2nd and 3rd go over.
				for i = 2, #context.blocks do
					local block = context.blocks[i]
					local out = if block.Position.X > home.Position.X then 1 else -1
					local rider: Model? = nil
					for _, other in context.others do
						local spot = block.CFrame:PointToObjectSpace(other:GetPivot().Position)
						if
							math.abs(spot.X) <= block.Size.X / 2
							and math.abs(spot.Z) <= block.Size.Z / 2
						then
							rider = other
						end
					end
					Kit.at(3.42 + (i - 2) * 0.05, function()
						topple(context, block, out, rider)
					end)
				end
			end)
		end
	end

	Kit.at(4.3, function()
		local mouth = ((lower :: BasePart).CFrame * SHEATH).Position
		Kit.burst(mouth, 16, WHITE, NumberRange.new(4, 9), 0.3)
		Kit.shake(0.8, 0.25)
		-- The hanging cut scatters into petals.
		for i, piece in arcParts do
			for _ = 1, 2 do
				local petal =
					Kit.block(A(0.3, 0.04, 0.24), piece.CFrame, Kit.gradient(colors, i / #arcParts))
				local drift = A(Kit.rnd(-3, 3), Kit.rnd(-4, -2), Kit.rnd(-2, 2))
				local begun = Kit.now()
				local start = piece.Position
				local turn = A(Kit.rnd(-5, 5), Kit.rnd(-5, 5), Kit.rnd(-5, 5))
				Kit.every(function(t)
					local u = t - begun
					petal.CFrame = CFrame.new(
						start + drift * u + A(math.sin(u * 4 + i) * 0.6, 0, 0)
					) * CFrame.Angles(turn.X * u, turn.Y * u, turn.Z * u)
					petal.Transparency = Kit.span(u, 1.4, 2.2)
					return u > 2.2
				end)
			end
			piece:Destroy()
		end
		table.clear(arcParts)
		local streak = Kit.line(
			(home * CFrame.new(-40, 1.5, 12.4)).Position,
			(home * CFrame.new(40, 1.5, 12.4)).Position,
			0.16,
			WHITE
		)
		Kit.tween(streak, 0.7, { Transparency = 1 })
	end)
end

---------------------------------------------------------------------------- Trophy Lift

local TROPHY: { Key } = {
	{ time = 0, angles = {} },
	{ time = 0.3, angles = { UpperTorso = A(-6, 10, 0), Head = A(-15, 15, 0) } },
	{ time = 0.85, angles = { UpperTorso = A(-4), Head = A(-22) } },
	{ time = 1.2, angles = {} },
	{ time = 1.6, angles = { UpperTorso = A(6), Head = A(28) }, ease = "Out" },
}

-- Pulls a gold trophy out of a pocket (it grows as it comes out), holds it in both hands,
-- admires it and lifts it high over the head.
function Epic.TrophyLift(context: Context)
	local character = context.character
	local home = context.home
	local colors = context.colors
	local head = Kit.part(character, "Head")
	local wood = Color3.fromRGB(92, 58, 34)
	local cup = Kit.prop()
	-- Built up from the base's bottom middle (where the hands hold it).
	Kit.add(cup, Kit.block(A(1.3, 0.45, 1.3), CFrame.new(), wood), CFrame.new(0, 0.22, 0))
	Kit.add(
		cup,
		Kit.block(
			A(0.7, 0.32, 0.32),
			CFrame.new(),
			GOLD,
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2)
	)
	Kit.add(
		cup,
		Kit.block(A(1.5, 1.5, 1.5), CFrame.new(), GOLD, Enum.Material.Metal, 0, Enum.PartType.Ball),
		CFrame.new(0, 1.75, 0)
	)
	Kit.add(
		cup,
		Kit.block(
			A(0.9, 1.6, 1.6),
			CFrame.new(),
			GOLD,
			Enum.Material.Metal,
			0,
			Enum.PartType.Cylinder
		),
		CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	)
	for _, side in { -1, 1 } do
		Kit.add(
			cup,
			Kit.block(A(0.5, 0.16, 0.16), CFrame.new(), GOLD, Enum.Material.Metal),
			CFrame.new(side * 0.95, 2.45, 0)
		)
		Kit.add(
			cup,
			Kit.block(A(0.16, 0.7, 0.16), CFrame.new(), GOLD, Enum.Material.Metal),
			CFrame.new(side * 1.15, 2.15, 0)
		)
		Kit.add(
			cup,
			Kit.block(A(0.5, 0.16, 0.16), CFrame.new(), GOLD, Enum.Material.Metal),
			CFrame.new(side * 0.95, 1.85, 0)
		)
		Kit.add(
			cup,
			Kit.block(
				A(0.14, 1.1, 0.06),
				CFrame.new(),
				colors[if side < 0 then 1 else 2] or colors[1]
			),
			CFrame.new(side * 1.25, 1.35, 0.1) * CFrame.Angles(0, 0, math.rad(side * 8))
		)
	end
	for _, part in cup.parts do
		part.Transparency = 1
	end
	local glint = Kit.block(A(0.25, 1.9, 0.1), CFrame.new(), WHITE, Enum.Material.Neon, 1)

	-- Where the trophy's base goes (the character's space): out of the right pocket, in front of
	-- the chest, then over the head (clear of it).
	local headTop = if head then home:PointToObjectSpace(head.Position).Y + head.Size.Y / 2 else 2.8
	local POCKET = A(0.95, -0.7, -0.5)
	local CHEST = A(0, 0.35, -1.25)
	local OVER = A(0, math.max(headTop + 0.15, 2.6), -0.75)
	local HOLD = 0.45 -- each hand under the base's side
	local function baseAt(t: number): Vector3
		if t < 0.8 then
			return POCKET:Lerp(CHEST + A(0.45, 0, 0), Kit.span(t, 0.35, 0.8))
		elseif t < 1.05 then
			return (CHEST + A(0.45, 0, 0)):Lerp(CHEST, Kit.span(t, 0.8, 1.05))
		elseif t < 2.2 then
			return CHEST:Lerp(OVER, Kit.span(t, 1.2, 1.6, "Out"))
		end
		local pump = math.abs(math.sin((t - 2.2) / 0.8 * math.pi * 2)) * (1 - Kit.span(t, 2.9, 3.0))
		return OVER - A(0, 0.4 * pump, 0)
	end
	local function scaleAt(t: number): number
		return 0.12 + 0.88 * Kit.span(t, 0.38, 0.8, "Out")
	end
	local facing = home.Rotation
	Kit.pose(character, TROPHY, context.hold)
	Kit.every(function(t)
		local scale = scaleAt(t)
		local spot = home * baseAt(t)
		local right = spot + facing * A(HOLD * scale, 0, 0)
		local left = spot - facing * A(HOLD * scale, 0, 0)
		local rightPole = (home * CFrame.new(2.6, 0, 1)).Position
		local leftPole = (home * CFrame.new(-2.6, 0, 1)).Position
		-- Into the pocket first, then holding the trophy.
		local pocket = (home * POCKET)
		-- Holding the base from its sides: palms in, fingers up.
		local across = facing.RightVector
		local holding =
			CFrame.fromMatrix(Vector3.zero, across, -Vector3.yAxis, across:Cross(-Vector3.yAxis))
		local rightHand = Kit.reach(
			character,
			"Right",
			if t < 0.35 then pocket else right,
			rightPole,
			Kit.span(t, 0, 0.3),
			if t < 0.35 then nil else holding
		)
		local leftHand =
			Kit.reach(character, "Left", left, leftPole, Kit.span(t, 0.75, 1.0), holding)
		-- The trophy sits in the hands (even at full stretch).
		local base = spot
		if t >= 1.0 and rightHand and leftHand then
			base = (rightHand + leftHand) / 2
		elseif rightHand and t >= 0.35 then
			base = rightHand - facing * A(HOLD * scale, 0, 0)
		end
		local frame = CFrame.new(base) * facing
		cup.place(frame, scale)
		local hidden = if t < 0.38 then 1 else 0
		for _, part in cup.parts do
			part.Transparency = hidden
		end
		local sweep = Kit.span(t, 1.65, 2.0, "Linear")
		glint.Transparency = if sweep > 0 and sweep < 1 then 0.15 else 1
		glint.CFrame = frame
			* CFrame.new(-1.0 + sweep * 2.0, 2.0, -0.85)
			* CFrame.Angles(0, 0, math.rad(-25))
		return nil
	end)
	Kit.at(0.4, function()
		Kit.burst((home * POCKET) + A(0, 0.3, 0), 22, GOLD, NumberRange.new(3, 7), 0.35)
	end)
	Kit.at(1.7, function()
		Kit.burst(
			(home * OVER) + A(0, 2, 0),
			70,
			Kit.sequence({ GOLD, Color3.fromRGB(255, 243, 176) }),
			NumberRange.new(8, 16),
			0.5,
			4,
			1
		)
		Kit.shake(0.6, 0.25)
	end)
end

return Epic
