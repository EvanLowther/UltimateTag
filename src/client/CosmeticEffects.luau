--!strict
-- Cosmetic effects everyone sees (each client plays them locally), from shared/Catalog looks:
--   Tag effects: when a tag lands (TagHit remote), the tagger's equipped TagEffect plays on the
--   tagged player. Common: one color (Classic burst, Pop ring, Sparks). Rare: two colors and
--   simple shapes (Hearts, Stars, a Pow comic burst). Epic: gradients (Confetti, Shockwave
--   rings). Legendary: big effects (Lightning strike, Meteor; both shake nearby cameras).
--   Iridescent: Shatter, the tagged player bursts into holo shards that snap back together,
--   and nearby screens flash.
--   Victories: when a game is won (Victory remote), the winner plays their equipped Victory: a
--   pose (Flex, Cheer, Backflip, CapToss) and an effect (Sparkle, Confetti, Fireworks with a
--   spotlight, Stars, or Hologram: a giant holo statue of them rises behind them).
-- playTag and playVictory also work on any model, for the Locker's preview (client/LockerStage).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local CameraKick = require(script.Parent.CameraKick)

local CosmeticEffects = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local BANGERS = Font.new("rbxasset://fonts/families/Bangers.json")
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(200, 100, 255),
	Color3.fromRGB(255, 255, 255),
}
local SHAKE_RANGE = 35 -- studs: Lightning and Meteor shake cameras this close
local FLASH_RANGE = 45 -- studs: Shatter flashes screens this close

local random = Random.new()
local function rnd(a: number, b: number): number
	return a + random:NextNumber() * (b - a)
end

local function rootOf(model: Model?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function effectsFolder(): Folder
	local folder = workspace:FindFirstChild("CosmeticEffects")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local new = Instance.new("Folder")
	new.Name = "CosmeticEffects"
	new.Parent = workspace
	return new
end

local function loosePart(shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- How far this screen's camera is from `position`.
local function cameraDistance(position: Vector3): number
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude
end

-- A one-off particle burst at `position`.
local function burst(
	position: Vector3,
	count: number,
	color: Color3 | ColorSequence,
	speed: NumberRange,
	size: number,
	gravity: number?
)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = speed
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -(gravity or 0), 0)
	emitter.Drag = 2
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, 1.5)
end

-- Little paper squares flying out from `position`, in `colors`.
local function confetti(position: Vector3, count: number, power: number, colors: { Color3 }?)
	local palette = colors or CONFETTI_COLORS
	local folder = effectsFolder()
	for i = 1, count do
		local piece = Instance.new("Part")
		piece.Size = Vector3.new(0.35, 0.05, 0.25)
		local a = palette[(i - 1) % #palette + 1]
		local b = palette[i % #palette + 1]
		piece.Color = a:Lerp(b, random:NextNumber()) -- in between the look's colors (a gradient)
		piece.Material = Enum.Material.SmoothPlastic
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Massless = true
		piece.CFrame = CFrame.new(position) * CFrame.Angles(rnd(0, 6), rnd(0, 6), rnd(0, 6))
		piece.AssemblyLinearVelocity =
			Vector3.new(rnd(-0.5, 0.5) * power, power * rnd(0.6, 1.2), rnd(-0.5, 0.5) * power)
		piece.AssemblyAngularVelocity = Vector3.new(rnd(0, 10), rnd(0, 10), 0)
		piece.Parent = folder
		Debris:AddItem(piece, 2.5)
	end
end

-- Emoji floating up and out from `position`, taking turns through `symbols`.
local function emojis(position: Vector3, symbols: { string }, count: number)
	for i = 1, count do
		local attachment = Instance.new("Attachment")
		attachment.Parent = workspace.Terrain
		attachment.WorldPosition = position
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(1.6, 1.6)
		gui.LightInfluence = 0
		gui.Adornee = attachment
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = symbols[(i - 1) % #symbols + 1]
		label.TextScaled = true
		label.Parent = gui
		gui.Parent = attachment
		local drift = Vector3.new(rnd(-3, 3), rnd(4, 7), rnd(-3, 3))
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(attachment, info, { WorldPosition = position + drift }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		Debris:AddItem(attachment, 1.2)
	end
end

-- A flat glowing disc that spreads out from `position` and fades.
local function ring(position: Vector3, color: Color3, size: number, seconds: number)
	local disc = loosePart(Enum.PartType.Cylinder)
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Size = Vector3.new(0.2, 2, 2)
	disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	disc.Transparency = 0.1
	disc.Parent = effectsFolder()
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(disc, info, { Size = Vector3.new(0.2, size, size), Transparency = 1 })
		:Play()
	Debris:AddItem(disc, seconds + 0.05)
end

-- Shakes this screen's camera if it's close to `position`.
local function shakeNear(position: Vector3, strength: number)
	if cameraDistance(position) < SHAKE_RANGE then
		CameraKick.kick(rnd(-1, 1) * strength, strength * 0.6, 0.35)
	end
end

-- A zigzag bolt from the sky down to `position`, flashing twice.
local function lightning(position: Vector3, color: Color3)
	local points = { position + Vector3.new(0, 40, 0) }
	for i = 1, 5 do
		local t = i / 6
		table.insert(points, position + Vector3.new(rnd(-3, 3), 40 * (1 - t), rnd(-3, 3)))
	end
	table.insert(points, position)
	local segments = {}
	local folder = effectsFolder()
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = loosePart()
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(0.35, 0.35, (b - a).Magnitude)
		segment.CFrame = CFrame.lookAt((a + b) / 2, b)
		segment.Parent = folder
		table.insert(segments, segment)
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 6
	light.Range = 30
	light.Parent = segments[#segments]
	task.spawn(function()
		for _, visible in { false, true, false } do
			task.wait(0.06)
			for _, segment in segments do
				segment.Transparency = if visible then 0 else 1
			end
		end
		for _, segment in segments do
			segment:Destroy()
		end
	end)
	burst(position, 30, color, NumberRange.new(10, 20), 0.6, 40)
	shakeNear(position, 3)
end

-- A comic "TAG!" burst that pops up and fades.
local function pow(position: Vector3, colors: { Color3 })
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position + Vector3.new(0, 1, 0)
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 4)
	gui.LightInfluence = 0
	gui.Adornee = attachment
	local star = Instance.new("TextLabel")
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromScale(1, 1)
	star.Text = "💥"
	star.TextScaled = true
	star.Parent = gui
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 0.7)
	text.Position = UDim2.fromScale(0, 0.15)
	text.Text = "TAG!"
	text.FontFace = BANGERS
	text.TextScaled = true
	text.TextColor3 = colors[1] or Color3.fromRGB(255, 214, 10)
	text.Rotation = -8
	local outline = Instance.new("UIStroke")
	outline.Color = colors[2] or Color3.fromRGB(227, 36, 43)
	outline.Thickness = 4
	outline.Parent = text
	text.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = gui
	gui.Parent = attachment
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(0.5, function()
		local fade = TweenInfo.new(0.25)
		TweenService:Create(text, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(star, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(outline, fade, { Transparency = 1 }):Play()
	end)
	Debris:AddItem(attachment, 0.85)
end

-- A fireball dropping out of the sky onto `position`, then exploding into embers.
local function meteor(position: Vector3, colors: { Color3 })
	local hot = colors[2] or Color3.fromRGB(255, 120, 30)
	local ball = loosePart(Enum.PartType.Ball)
	ball.Material = Enum.Material.Neon
	ball.Color = hot
	ball.Size = Vector3.new(2.4, 2.4, 2.4)
	local from = position + Vector3.new(rnd(-12, 12), 42, rnd(-12, 12))
	ball.CFrame = CFrame.new(from)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = ball
	local tail = Instance.new("Trail")
	tail.Attachment0 = a0
	tail.Attachment1 = a1
	tail.Lifetime = 0.25
	tail.FaceCamera = true
	tail.LightEmission = 1
	tail.Color = CosmeticLook.sequence(colors)
	tail.Transparency = NumberSequence.new(0, 1)
	tail.Parent = ball
	ball.Parent = effectsFolder()
	local fall = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(ball, fall, { CFrame = CFrame.new(position) }):Play()
	task.delay(0.35, function()
		ball:Destroy()
		burst(position, 50, CosmeticLook.sequence(colors), NumberRange.new(14, 26), 0.8, 30)
		burst(position, 25, colors[1] or hot, NumberRange.new(4, 9), 0.4, -12) -- embers rising
		ring(position - Vector3.new(0, 2.5, 0), hot, 20, 0.5)
		shakeNear(position, 4)
	end)
end

-- Tints this screen for a moment (Shatter's flash).
local function flash()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "ShatterFlash"
	tint.TintColor = CosmeticLook.Holo[2]
	tint.Brightness = 0.15
	tint.Saturation = 0.5
	tint.Parent = Lighting
	TweenService:Create(
		tint,
		TweenInfo.new(0.45),
		{ TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 }
	):Play()
	Debris:AddItem(tint, 0.5)
end

-- The model bursts into holo shards that fly out, hang, and snap back together.
local function shatter(model: Model, center: Vector3)
	local parts: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 1 then
			table.insert(parts, item)
		end
	end
	for _, part in parts do
		part.LocalTransparencyModifier = 1
	end
	-- Surface art (the dummy's target and eyes) ignores LocalTransparencyModifier: hide it too.
	local hidden: { SurfaceGui } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("SurfaceGui") and item.Enabled then
			item.Enabled = false
			table.insert(hidden, item)
		end
	end
	local folder = effectsFolder()
	type Shard = { part: BasePart, home: CFrame, away: CFrame }
	local shards: { Shard } = {}
	for i, part in parts do
		local count = if part.Size.Magnitude > 2.5 then 3 else 1
		for _ = 1, count do
			local shard = Instance.new("WedgePart")
			shard.Anchored = true
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CastShadow = false
			shard.Material = Enum.Material.Neon
			shard.Transparency = 0.15
			shard.Color = CosmeticLook.holoColor(i * 0.07 + rnd(0, 0.1))
			shard.Size = Vector3.new(rnd(0.3, 0.6), rnd(0.6, 1.3), rnd(0.6, 1.3))
			local offset = Vector3.new(
				rnd(-0.4, 0.4) * part.Size.X,
				rnd(-0.4, 0.4) * part.Size.Y,
				rnd(-0.4, 0.4) * part.Size.Z
			)
			local spin = CFrame.Angles(rnd(-3, 3), rnd(-3, 3), rnd(-3, 3))
			local home = part.CFrame * CFrame.new(offset)
			local direction = home.Position - center
			if direction.Magnitude < 0.01 then
				direction = Vector3.new(0, 1, 0)
			end
			local away = CFrame.new(
				home.Position + direction.Unit * rnd(4, 8) + Vector3.new(0, rnd(1, 4), 0)
			) * home.Rotation * spin
			shard.CFrame = home
			shard.Parent = folder
			table.insert(shards, { part = shard, home = home, away = away })
		end
	end
	local out = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, shard in shards do
		TweenService:Create(shard.part, out, { CFrame = shard.away }):Play()
	end
	task.delay(0.6, function()
		local back = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, shard in shards do
			TweenService:Create(shard.part, back, { CFrame = shard.home }):Play()
		end
	end)
	task.delay(0.97, function()
		for _, shard in shards do
			shard.part:Destroy()
		end
		for _, part in parts do
			if part.Parent then
				part.LocalTransparencyModifier = 0
			end
		end
		for _, gui in hidden do
			gui.Enabled = true
		end
	end)
	burst(center, 30, CosmeticLook.holoSequence(0), NumberRange.new(10, 18), 0.5)
	ring(center - Vector3.new(0, 2.5, 0), CosmeticLook.Holo[4], 18, 0.5)
	if cameraDistance(center) < FLASH_RANGE then
		flash()
	end
end

local TAG_EFFECTS: { [string]: (Model, Vector3, { Color3 }) -> () } = {
	Classic = function(_, position, colors)
		burst(position, 25, colors[1], NumberRange.new(8, 14), 0.6)
	end,
	Pop = function(_, position, colors)
		ring(position, colors[1], 12, 0.3)
		burst(position, 14, colors[1], NumberRange.new(10, 16), 0.4)
	end,
	Sparks = function(_, position, colors)
		burst(position, 45, colors[1], NumberRange.new(14, 24), 0.4, 50)
	end,
	Hearts = function(_, position)
		emojis(position, { "💖", "🤍" }, 8)
	end,
	Stars = function(_, position)
		emojis(position, { "⭐", "✨" }, 8)
	end,
	Pow = function(_, position, colors)
		pow(position, colors)
		burst(position, 16, colors[2] or colors[1], NumberRange.new(10, 18), 0.4)
	end,
	Confetti = function(_, position, colors)
		confetti(position, 34, 24, colors)
	end,
	Shockwave = function(_, position, colors)
		ring(position - Vector3.new(0, 2.5, 0), colors[1], 18, 0.45)
		task.delay(0.1, ring, position, colors[2] or colors[1], 16, 0.45)
		burst(position, 30, CosmeticLook.sequence(colors), NumberRange.new(12, 20), 0.5)
	end,
	Lightning = function(_, position, colors)
		lightning(position, colors[2] or colors[1])
	end,
	Meteor = function(_, position, colors)
		meteor(position, colors)
	end,
	Shatter = function(model, position)
		shatter(model, position)
	end,
}

-- Plays a tag effect on `target` (a character, or the Locker's dummy).
function CosmeticEffects.playTag(item: Catalog.Item?, target: Model)
	local root = rootOf(target)
	local chosen = item or Catalog.get(Config.Progression.DefaultEquipped.TagEffect)
	if not root or not chosen then
		return
	end
	local look = chosen.look
	local play = TAG_EFFECTS[look.Effect]
	if play then
		play(target, root.Position, (look.Colors or { Color3.new(1, 1, 1) }) :: { Color3 })
	end
end

-- Victory poses (degrees per body part, like the move poses in Config).
local POSES: { [string]: { AnimationBuilder.Key } } = {
	Flex = {
		{ time = 0, angles = {} },
		{
			time = 0.25,
			angles = {
				RightUpperArm = Vector3.new(0, 0, 90),
				RightLowerArm = Vector3.new(0, 0, 100),
				LeftUpperArm = Vector3.new(0, 0, -90),
				LeftLowerArm = Vector3.new(0, 0, -100),
				UpperTorso = Vector3.new(-8, 0, 0),
			},
		},
		{
			time = 2.5,
			angles = {
				RightUpperArm = Vector3.new(0, 0, 90),
				RightLowerArm = Vector3.new(0, 0, 100),
				LeftUpperArm = Vector3.new(0, 0, -90),
				LeftLowerArm = Vector3.new(0, 0, -100),
				UpperTorso = Vector3.new(-8, 0, 0),
			},
		},
	},
	Cheer = {
		{ time = 0, angles = {} },
		{
			time = 0.2,
			angles = {
				RightUpperArm = Vector3.new(170, 0, 15),
				LeftUpperArm = Vector3.new(170, 0, -15),
			},
		},
		{
			time = 0.45,
			angles = {
				RightUpperArm = Vector3.new(140, 0, 25),
				LeftUpperArm = Vector3.new(140, 0, -25),
			},
		},
		{
			time = 0.7,
			angles = {
				RightUpperArm = Vector3.new(170, 0, 15),
				LeftUpperArm = Vector3.new(170, 0, -15),
			},
		},
		{
			time = 0.95,
			angles = {
				RightUpperArm = Vector3.new(140, 0, 25),
				LeftUpperArm = Vector3.new(140, 0, -25),
			},
		},
		{
			time = 1.2,
			angles = {
				RightUpperArm = Vector3.new(170, 0, 15),
				LeftUpperArm = Vector3.new(170, 0, -15),
			},
		},
	},
	Backflip = {
		{ time = 0, angles = {} },
		{
			time = 0.2,
			angles = {
				LowerTorso = Vector3.new(-40, 0, 0),
				RightUpperLeg = Vector3.new(90, 0, 0),
				LeftUpperLeg = Vector3.new(90, 0, 0),
				RightLowerLeg = Vector3.new(-110, 0, 0),
				LeftLowerLeg = Vector3.new(-110, 0, 0),
			},
			ease = "In",
		},
		{
			time = 0.5,
			angles = {
				LowerTorso = Vector3.new(-200, 0, 0),
				RightUpperLeg = Vector3.new(100, 0, 0),
				LeftUpperLeg = Vector3.new(100, 0, 0),
				RightLowerLeg = Vector3.new(-120, 0, 0),
				LeftLowerLeg = Vector3.new(-120, 0, 0),
			},
		},
		{ time = 0.8, angles = { LowerTorso = Vector3.new(-360, 0, 0) }, ease = "Out" },
		{
			time = 1.2,
			angles = {
				RightUpperArm = Vector3.new(170, 0, 15),
				LeftUpperArm = Vector3.new(170, 0, -15),
			},
		},
	},
	CapToss = {
		{ time = 0, angles = { RightUpperArm = Vector3.new(30, 0, 0) } },
		{ time = 0.3, angles = { RightUpperArm = Vector3.new(175, 0, 10) }, ease = "In" },
		{
			time = 0.6,
			angles = {
				RightUpperArm = Vector3.new(170, 0, 15),
				LeftUpperArm = Vector3.new(170, 0, -15),
			},
		},
		{
			time = 2,
			angles = {
				RightUpperArm = Vector3.new(160, 0, 20),
				LeftUpperArm = Vector3.new(160, 0, -20),
			},
		},
	},
}

local animations: { [string]: Animation } = {}

local function playPose(character: Model, pose: string, hold: number)
	local keys = POSES[pose]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not keys or not humanoid then
		return
	end
	local animation = animations[pose]
	if not animation then
		animation = AnimationBuilder.make(keys, true)
		animations[pose] = animation
	end
	local track = AnimationBuilder.load(humanoid, animation)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(0.1)
	task.delay(hold, function()
		track:Stop(0.3)
	end)
end

-- A graduation cap thrown up from the head, tumbling back down.
local function capToss(root: BasePart)
	local cap = Instance.new("Part")
	cap.Size = Vector3.new(2, 0.2, 2)
	cap.Color = Color3.fromRGB(25, 25, 30)
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.CFrame = root.CFrame + Vector3.new(0, 3.5, 0)
	cap.AssemblyLinearVelocity = Vector3.new(0, 55, 0)
	cap.AssemblyAngularVelocity = Vector3.new(8, 4, 0)
	local tassel = Instance.new("Part")
	tassel.Size = Vector3.new(0.15, 0.8, 0.15)
	tassel.Color = Color3.fromRGB(255, 200, 60)
	tassel.CanCollide = false
	tassel.Massless = true
	tassel.CFrame = cap.CFrame * CFrame.new(0.9, -0.4, 0.9)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = cap
	weld.Part1 = tassel
	weld.Parent = cap
	tassel.Parent = cap
	cap.Parent = effectsFolder()
	Debris:AddItem(cap, 3)
end

-- Fireworks bursting overhead.
local function fireworks(root: BasePart)
	task.spawn(function()
		for i = 1, 4 do
			local spot = root.Position + Vector3.new(rnd(-8, 8), rnd(16, 24), rnd(-8, 8))
			burst(
				spot,
				70,
				CONFETTI_COLORS[(i % #CONFETTI_COLORS) + 1],
				NumberRange.new(18, 28),
				0.9,
				15
			)
			task.wait(0.45)
		end
	end)
end

-- A spotlight shining down on the winner, and a glow round their feet.
local function spotlight(root: BasePart, hold: number)
	local lamp = loosePart()
	lamp.Transparency = 1
	lamp.Size = Vector3.new(1, 1, 1)
	lamp.CFrame = CFrame.new(root.Position + Vector3.new(0, 22, 0))
		* CFrame.Angles(-math.pi / 2, 0, 0)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 40
	light.Brightness = 8
	light.Range = 40
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = lamp
	lamp.Parent = effectsFolder()
	local glow = loosePart(Enum.PartType.Cylinder)
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(255, 240, 200)
	glow.Transparency = 0.75
	glow.Size = Vector3.new(0.1, 10, 10)
	glow.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	glow.Parent = effectsFolder()
	Debris:AddItem(lamp, hold)
	Debris:AddItem(glow, hold)
end

-- A giant holo statue of the character (as posed a moment after it starts) rising behind them.
local function hologram(character: Model, hold: number)
	local root = rootOf(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	task.delay(0.45, function()
		if not root.Parent then
			return
		end
		local scale = 3
		local ground = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
		local behind = (root.CFrame * CFrame.new(0, 0, 10)).Position
		local base = CFrame.new(behind.X, ground + (root.Position.Y - ground) * scale, behind.Z)
			* root.CFrame.Rotation
		local statue = Instance.new("Model")
		statue.Name = "Hologram"
		type Piece = { part: BasePart, rel: CFrame }
		local pieces: { Piece } = {}
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") and part ~= root and part.Transparency < 1 then
				local rel = root.CFrame:ToObjectSpace(part.CFrame)
				local copy = loosePart()
				copy.Size = part.Size * scale
				copy.Material = Enum.Material.ForceField
				copy.Parent = statue
				table.insert(pieces, { part = copy, rel = rel })
			end
		end
		statue.Parent = effectsFolder()
		local drop = (root.Position.Y - ground) * scale * 2 + 4
		local start = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			local rise = 1 - (1 - math.clamp(t / 1.1, 0, 1)) ^ 2
			local fade = if t > hold - 0.8 then math.clamp((t - (hold - 0.8)) / 0.8, 0, 1) else 0
			local lift = CFrame.new(0, (1 - rise) * -drop, 0)
			for i, piece in pieces do
				piece.part.CFrame = lift
					* base
					* CFrame.new(piece.rel.Position * scale)
					* piece.rel.Rotation
				piece.part.Color = CosmeticLook.holoColor(t * 0.35 + i * 0.03)
				piece.part.Transparency = fade
			end
			if t >= hold then
				connection:Disconnect()
				statue:Destroy()
			end
		end)
		for i = 1, 4 do
			task.delay(i * 0.5, function()
				if statue.Parent then
					burst(
						base.Position + Vector3.new(rnd(-6, 6), rnd(-4, 8), rnd(-3, 3)),
						12,
						CosmeticLook.holoSequence(i * 0.2),
						NumberRange.new(2, 5),
						0.6
					)
				end
			end)
		end
	end)
end

-- Plays a victory on `character` (the winner, or the Locker's preview). `hold`: seconds before
-- the pose lets go.
function CosmeticEffects.playVictory(character: Model, item: Catalog.Item?, hold: number?)
	local root = rootOf(character)
	if not root or not item then
		return
	end
	local seconds = hold or (Config.Game.VictoryTime - 1)
	local look = item.look
	local colors = (look.Colors or CONFETTI_COLORS) :: { Color3 }
	playPose(character, look.Pose, seconds)
	if look.Pose == "CapToss" then
		task.delay(0.3, capToss, root)
	end
	local effect = look.Effect
	if effect == "Confetti" then
		confetti(root.Position + Vector3.new(0, 3, 0), 60, 30, colors)
	elseif effect == "Sparkle" then
		burst(
			root.Position + Vector3.new(0, 1, 0),
			60,
			CosmeticLook.sequence(colors),
			NumberRange.new(10, 18),
			0.7,
			10
		)
		task.delay(
			0.35,
			burst,
			root.Position + Vector3.new(0, 3, 0),
			40,
			colors[2] or colors[1],
			NumberRange.new(6, 12),
			0.5
		)
	elseif effect == "Fireworks" then
		fireworks(root)
		spotlight(root, seconds)
	elseif effect == "Stars" then
		emojis(root.Position + Vector3.new(0, 2, 0), { "⭐", "🌟" }, 12)
		burst(
			root.Position + Vector3.new(0, 2, 0),
			40,
			Color3.fromRGB(255, 240, 150),
			NumberRange.new(8, 14),
			0.5
		)
	elseif effect == "Hologram" then
		hologram(character, seconds + 0.5)
	end
end

function CosmeticEffects.start()
	Remotes.get("TagHit").OnClientEvent:Connect(function(tagger, tagged)
		if typeof(tagger) == "Instance" and typeof(tagged) == "Instance" then
			local item =
				Catalog.get((tagger :: Player):GetAttribute("EquippedTagEffect") :: string?)
			local character = (tagged :: Player).Character
			if character then
				CosmeticEffects.playTag(item, character)
			end
		end
	end)
	Remotes.get("Victory").OnClientEvent:Connect(function(winner)
		if typeof(winner) == "Instance" and winner:IsA("Player") then
			-- The winner's new lobby character may still be arriving.
			local waited = 0
			while not rootOf(winner.Character) and waited < 3 do
				waited += task.wait(0.1)
			end
			local character = winner.Character
			if character then
				CosmeticEffects.playVictory(
					character,
					Catalog.get(winner:GetAttribute("EquippedVictory") :: string?)
				)
			end
		end
	end)
	effectsFolder()
end

return CosmeticEffects
