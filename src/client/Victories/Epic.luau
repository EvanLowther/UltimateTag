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

-- The body around the right arm (the arms themselves reach for the sword and sheath).
local KATANA: { Key } = {
	{ time = 0, angles = {} },
	{
		time = 0.25,
		angles = {
			UpperTorso = A(0, 18, 0),
			Head = A(-12),
			RightUpperLeg = A(0, 0, 8),
			LeftUpperLeg = A(0, 0, -8),
		},
	},
	{ time = 0.6, angles = { UpperTorso = A(0, -8, 0), Head = A(0) } },
	{ time = 1.6, angles = { UpperTorso = A(0) } },
	{ time = 2.0, angles = { UpperTorso = A(0, -25, 0), Head = A(5) } },
	{ time = 2.32, angles = { UpperTorso = A(0, 30, 0) }, ease = "In" },
	{ time = 2.6, angles = { UpperTorso = A(0, 20, 0) } },
	{ time = 3.05, angles = { UpperTorso = A(0, 15, 0), Head = A(-10) } },
	{ time = 3.7, angles = { UpperTorso = A(0), Head = A(-14) } },
}

-- Falling to the floor like a ragdoll: arms flung, then limp.
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
local BLADE = 3.6
local GRIP = 0.5 -- the hilt's middle, behind the guard (the sword's origin)

-- Cuts a podium block in two along a slant: the top half slides down the cut, tips off and
-- falls to the floor, and whoever stood on it falls with it and flops onto the floor. `high` is
-- +1 if the cut is higher on the block's +X side (the top slides toward -X).
local function slice(context: Context, block: BasePart, high: number, rider: Model?)
	local size = block.Size
	local w, h, d = size.X, size.Y, size.Z
	local hi, lo = h * 0.66, h * 0.34
	local base = block.CFrame
	local floor = context.floor
	local front = d / 2 + 0.04
	local glow = Kit.line(
		(base * CFrame.new(high * w / 2, hi - h / 2, front)).Position,
		(base * CFrame.new(-high * w / 2, lo - h / 2, front)).Position,
		0.14,
		WHITE
	)
	Kit.tween(glow, 0.5, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	block.LocalTransparencyModifier = 1
	local guis = {}
	for _, item in block:GetChildren() do
		if item:IsA("SurfaceGui") and item.Enabled then
			item.Enabled = false
			table.insert(guis, item)
		end
	end
	Kit.onStop(function()
		block.LocalTransparencyModifier = 0
		for _, gui in guis do
			gui.Enabled = true
		end
	end)
	local band = hi - lo
	local middle = lo + band / 2 - h / 2
	local up, down = A(0, 1, 0), A(0, -1, 0)
	local toHigh, toLow = A(high, 0, 0), A(-high, 0, 0)
	-- The lower half stays: a box and a wedge rising to the high side.
	Kit.block(A(w, lo, d), base * CFrame.new(0, -h / 2 + lo / 2, 0), block.Color, block.Material)
	Kit.wedge(
		A(d, band, w),
		base * CFrame.fromMatrix(A(0, middle, 0), up:Cross(toHigh), up, toHigh),
		block.Color,
		block.Material
	)
	-- The upper half: an upside-down wedge and the box on top.
	local top = Kit.prop()
	local topCenter = A(0, (middle + h / 2) / 2, 0)
	Kit.add(
		top,
		Kit.block(A(w, h - hi, d), base, block.Color, block.Material),
		CFrame.new(0, -h / 2 + hi + (h - hi) / 2, 0)
	)
	Kit.add(
		top,
		Kit.wedge(A(d, band, w), base, block.Color, block.Material),
		CFrame.fromMatrix(A(0, middle, 0), down:Cross(toLow), down, toLow)
	)
	top.place(base)
	local slope = base:VectorToWorldSpace(A(-high * w, lo - hi, 0).Unit)
	local outward = base:VectorToWorldSpace(toLow)
	local begun = Kit.now()
	local landed = false
	-- Where the top half is `u` seconds after the cut.
	local function topAt(u: number): CFrame
		local slid = slope * 1.6 * Kit.span(u, 0.1, 0.45, "In")
		local fall = math.max(u - 0.45, 0)
		local tip = math.rad(40) * Kit.span(u, 0.45, 0.95) * -high
		return (base + slid + outward * 2.2 * fall + A(0, -22 * fall * fall, 0))
			* Kit.around(topCenter, CFrame.Angles(0, 0, tip))
	end
	Kit.every(function(t)
		if landed then
			return true
		end
		local u = t - begun
		local frame = topAt(u)
		top.place(frame)
		local low = Kit.lowestOf(top.parts)
		if low < floor then
			top.place(frame + A(0, floor - low, 0))
			landed = u > 0.5
			if landed then
				Kit.dust(Vector3.new(frame.X, floor + 0.3, frame.Z), 14, 1.4)
				Kit.shake(0.8, 0.25)
			end
		end
		return nil
	end)
	if not rider then
		return
	end
	-- The rider rides the slide, then falls off sideways and lies on the floor.
	local start = rider:GetPivot()
	Kit.onStop(function()
		if rider.Parent then
			rider:PivotTo(start)
		end
	end)
	local lean = if outward:Dot(-start.RightVector) > 0 then 1 else -1
	Kit.pose(rider, SLUMP, context.hold - begun)
	Kit.every(function(t)
		local u = t - begun
		local slid = slope * 1.6 * Kit.span(u, 0.1, 0.45, "In")
		local fall = math.max(u - 0.35, 0)
		local turn = math.rad(90) * Kit.span(u, 0.35, 0.95, "In") * lean
		local position = start.Position
			+ slid
			+ outward * 3 * math.min(fall, 0.6)
			+ A(0, -26 * fall * fall, 0)
		local frame = CFrame.new(position) * start.Rotation * CFrame.Angles(0, 0, turn)
		rider:PivotTo(frame)
		local low = Kit.lowest(rider)
		if low < floor then
			rider:PivotTo(frame + A(0, floor - low, 0))
		end
		return u > 1.2
	end)
end

-- Draws a katana from a sheath on the hip, spins it, makes one wide cut that hangs in the air,
-- and slides it cleanly home: the sword follows one smooth path and the arms reach for it. On
-- the click the cut scatters into petals and the 2nd and 3rd blocks are sliced: their tops slide
-- off and fall, and the players on them flop onto the floor.
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
	Kit.add(sheath, Kit.block(A(0.32, 0.36, 3.8), CFrame.new(), ink), CFrame.new(0, 0, -1.9))
	Kit.add(
		sheath,
		Kit.block(A(0.4, 0.44, 0.25), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, -0.12)
	)
	Kit.add(
		sheath,
		Kit.block(A(0.36, 0.4, 0.2), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, -3.75)
	)
	local sword = Kit.prop()
	local blade = Kit.add(
		sword,
		Kit.block(A(0.08, 0.3, BLADE), CFrame.new(), steel, Enum.Material.Metal),
		CFrame.new(0, 0, -BLADE / 2)
	)
	blade.Reflectance = 0.35
	Kit.add(
		sword,
		Kit.block(
			A(0.12, 0.55, 0.55),
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
		Kit.block(A(0.22, 0.22, 1.0), CFrame.new(), Color3.fromRGB(70, 20, 34)),
		CFrame.new(0, 0, 0.55)
	)
	Kit.add(
		sword,
		Kit.block(A(0.26, 0.26, 0.12), CFrame.new(), GOLD, Enum.Material.Metal),
		CFrame.new(0, 0, 1.08)
	)
	local trail =
		Kit.trail(blade, A(0, 0, -BLADE / 2), A(0, 0, BLADE / 2 - 0.3), Kit.sequence(colors), 0.18)
	trail.Enabled = false

	-- The sword's path, in the character's space (+X its right, -Z toward the camera).
	local function at(position: Vector3, toward: Vector3): CFrame
		return home * CFrame.lookAt(position, position + toward)
	end
	local READY = at(A(1.3, 0.5, -1.4), A(0.15, 0.9, -0.6))
	local OVERHEAD = at(A(0.9, 2.5, -0.3), A(-0.2, 0.5, 1))
	local LOW = at(A(-1.0, 0.1, -1.4), A(-0.6, -0.5, -0.7))
	local center, radius = A(0.8, 0.9, 0), 1.8
	local function arc(angle: number): CFrame
		local x, z = math.sin(angle), -math.cos(angle)
		return at(center + A(x, 0, z) * radius, A(x, -0.08, z))
	end
	local cutFrom, cutTo = math.rad(60), math.rad(-45)
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
		elseif t < 0.8 then
			return sheathed(BLADE):Lerp(READY, Kit.span(t, 0.5, 0.8))
		elseif t < 1.6 then
			return spun(-math.pi * 4 * Kit.span(t, 0.8, 1.6))
		elseif t < 2.0 then
			return READY:Lerp(OVERHEAD, Kit.span(t, 1.6, 2.0))
		elseif t < 2.08 then
			return OVERHEAD:Lerp(arc(cutFrom), Kit.span(t, 2.0, 2.08, "In"))
		elseif t < 2.32 then
			return arc(cutFrom + (cutTo - cutFrom) * Kit.span(t, 2.08, 2.32))
		elseif t < 2.6 then
			return arc(cutTo):Lerp(LOW, Kit.span(t, 2.32, 2.6, "Out"))
		elseif t < 3.05 then
			return LOW:Lerp(sheathed(BLADE), Kit.span(t, 2.6, 3.05))
		end
		return sheathed(BLADE * (1 - Kit.span(t, 3.05, 3.45, "Out")))
	end

	local arcParts: { BasePart } = {}
	local lastTip: Vector3? = nil
	Kit.pose(character, KATANA, context.hold)
	Kit.every(function(t)
		local show = Kit.span(t, 0, 0.25)
		for _, part in sheath.parts do
			part.Transparency = 1 - show
		end
		for _, part in sword.parts do
			part.Transparency = 1 - show
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
		-- The left hand steadies the sheath, lets go for the spin, then joins the right on the
		-- hilt for the overhead and the cut (a two-handed strike), and goes back to the sheath to
		-- take the blade home.
		local sheathHold = (sheathed(0) * CFrame.new(0, 0, -0.7)).Position
		local pommel = (frame * CFrame.new(0, 0, GRIP + 0.42)).Position
		local twoHands = Kit.span(t, 1.6, 1.85) * (1 - Kit.span(t, 2.6, 2.85))
		local free = Kit.span(t, 0.75, 0.85) * (1 - Kit.span(t, 1.6, 1.85))
		Kit.reach(
			character,
			"Left",
			sheathHold:Lerp(pommel, twoHands),
			(home * CFrame.new(-2.6, -1.2, 0.6)).Position,
			Kit.span(t, 0.1, 0.35) * (1 - free),
			if twoHands > 0.5 then gripTurn(edge, forearm("Left")) else nil
		)
		sword.place(frame)
		trail.Enabled = t > 0.45 and t < 2.9
		-- The wide cut leaves its arc hanging in the air.
		local tip = (frame * CFrame.new(0, 0, -BLADE)).Position
		if t >= 2.08 and t <= 2.34 then
			if lastTip then
				table.insert(
					arcParts,
					Kit.line(lastTip, tip, 0.22, Kit.gradient(colors, #arcParts / 14), 0.1)
				)
			end
			lastTip = tip
		end
		return nil
	end)
	Kit.at(0.5, function()
		Kit.burst((sword.parts[1] :: BasePart).Position, 14, WHITE, NumberRange.new(4, 8), 0.35)
	end)
	Kit.at(3.45, function()
		local mouth = ((lower :: BasePart).CFrame * SHEATH).Position
		Kit.burst(mouth, 16, WHITE, NumberRange.new(4, 9), 0.3)
		Kit.shake(0.8, 0.25)
		-- The arc scatters into petals.
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
		-- A thin bright line across the backdrop.
		local streak = Kit.line(
			(home * CFrame.new(-40, 1.5, 12.4)).Position,
			(home * CFrame.new(40, 1.5, 12.4)).Position,
			0.16,
			WHITE
		)
		Kit.tween(streak, 0.7, { Transparency = 1 })
		-- The competition is cut down: 2nd and 3rd's blocks split and fall.
		for i = 2, #context.blocks do
			local block = context.blocks[i]
			local side = if block.Position.X > home.Position.X then 1 else -1
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
			-- High on the side toward the winner, so the top slides away from them.
			Kit.at(3.5 + (i - 2) * 0.12, function()
				slice(context, block, -side, rider)
			end)
		end
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
