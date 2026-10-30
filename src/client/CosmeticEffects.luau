--!strict
-- Cosmetic effects everyone sees (each client plays them locally), from shared/Catalog looks.
-- Shapes in the air (hearts, stars, the Pow burst) are drawn icons (client/Icons), not emoji.
--   Tag effects: when a tag lands (TagHit remote), the tagger's equipped TagEffect plays on the
--   tagged player. Common: one color (Classic burst, Pop ring, Sparks). Rare: two colors and
--   simple shapes (Hearts, Stars, a Pow comic burst). Epic: gradients (Confetti, Shockwave
--   rings). Legendary: big effects (Lightning strike, Meteor; both shake nearby cameras).
--   Iridescent: Shatter, the tagged player bursts into holo shards that snap back together,
--   and nearby screens flash.
-- playTag also works on any model, for the Locker's preview (client/LockerStage). Victories are
-- in client/Victories.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CameraKick = require(script.Parent.CameraKick)
local Icons = require(script.Parent.Icons)

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

-- Fades a drawn icon (and any text in it) out over `seconds`.
local function fadeOut(root: Instance, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, item in root:GetDescendants() do
		if item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1 }):Play()
		elseif item:IsA("Frame") and item.BackgroundTransparency < 1 then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
end

-- Drawn icons (client/Icons) floating up and out from `position`, taking turns through
-- `icons` ({ name, color, accent } each).
local function floaters(position: Vector3, icons: { { any } }, count: number)
	for i = 1, count do
		local spec = icons[(i - 1) % #icons + 1]
		local attachment = Instance.new("Attachment")
		attachment.Parent = workspace.Terrain
		attachment.WorldPosition = position
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(1.5, 1.5)
		gui.LightInfluence = 0
		gui.Adornee = attachment
		local icon = Icons.draw(gui, spec[1], 64, spec[2], spec[3])
		icon.Size = UDim2.fromScale(1, 1)
		icon.Rotation = rnd(-20, 20)
		gui.Parent = attachment
		local drift = Vector3.new(rnd(-3, 3), rnd(4, 7), rnd(-3, 3))
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(attachment, info, { WorldPosition = position + drift }):Play()
		fadeOut(icon, 1.1)
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
	-- Square, because an icon's shapes are sized against both sides: in a wide billboard the
	-- burst's turned spikes would stretch unevenly.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7, 7)
	gui.LightInfluence = 0
	gui.Adornee = attachment
	-- The comic burst behind the text (client/Icons).
	local star = Icons.draw(
		gui,
		"burst",
		96,
		colors[1] or Color3.fromRGB(255, 214, 10),
		colors[2] or Color3.fromRGB(227, 36, 43)
	)
	star.Size = UDim2.fromScale(1, 1)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 0.4)
	text.Position = UDim2.fromScale(0, 0.3)
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
		fadeOut(gui, 0.25)
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
	Hearts = function(_, position, colors)
		floaters(position, {
			{ "heart", colors[1] or Color3.fromRGB(255, 90, 150) },
			{ "heart", colors[2] or Color3.new(1, 1, 1) },
		}, 8)
	end,
	Stars = function(_, position, colors)
		floaters(position, {
			{ "sparkle", colors[1] or Color3.fromRGB(255, 240, 120), Color3.new(1, 1, 1) },
			{
				"sparkle",
				colors[2] or Color3.new(1, 1, 1),
				colors[1] or Color3.fromRGB(255, 240, 120),
			},
		}, 8)
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
	effectsFolder()
end

return CosmeticEffects
