--!strict
-- Cosmetic effects everyone sees (each client plays them locally):
--   Tag effects: when a tag lands (TagHit remote), the tagger's equipped TagEffect bursts at the
--   tagged player (Classic, Sparks, Hearts, Stars, Confetti, Shockwave, Lightning).
--   Victories: when a game is won (Victory remote), the winner plays their equipped Victory: a
--   pose (Flex, Cheer, Backflip, CapToss) and an effect (Confetti, Fireworks, Stars).
-- Item looks come from shared/Catalog.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)

local CosmeticEffects = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(200, 100, 255),
	Color3.fromRGB(255, 255, 255),
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A one-off particle burst at `position`.
local function burst(
	position: Vector3,
	count: number,
	color: Color3,
	speed: NumberRange,
	size: number,
	gravity: number?
)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.Color = ColorSequence.new(color)
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

-- Little paper squares flying out from `position`.
local function confetti(position: Vector3, count: number, power: number)
	for _ = 1, count do
		local piece = Instance.new("Part")
		piece.Size = Vector3.new(0.35, 0.05, 0.25)
		piece.Color = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.Material = Enum.Material.SmoothPlastic
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Massless = true
		piece.CFrame = CFrame.new(position)
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		piece.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * power,
			power * (0.6 + math.random() * 0.6),
			(math.random() - 0.5) * power
		)
		piece.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, 0)
		piece.Parent = workspace
		Debris:AddItem(piece, 2.5)
	end
end

-- Emoji floating up and out from `position` (hearts, stars).
local function emojis(position: Vector3, symbol: string, count: number)
	for _ = 1, count do
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
		label.Text = symbol
		label.TextScaled = true
		label.Parent = gui
		gui.Parent = attachment
		local drift =
			Vector3.new((math.random() - 0.5) * 6, 4 + math.random() * 3, (math.random() - 0.5) * 6)
		local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(attachment, info, { WorldPosition = position + drift }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		Debris:AddItem(attachment, 1.2)
	end
end

-- A flat glowing ring that spreads out from `position`.
local function shockwave(position: Vector3, color: Color3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.1
	ring.Parent = workspace
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.2, 18, 18), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)
end

-- A zigzag bolt from the sky down to `position`, flashing twice.
local function lightning(position: Vector3, color: Color3)
	local points = { position + Vector3.new(0, 40, 0) }
	for i = 1, 5 do
		local t = i / 6
		table.insert(
			points,
			position
				+ Vector3.new((math.random() - 0.5) * 6, 40 * (1 - t), (math.random() - 0.5) * 6)
		)
	end
	table.insert(points, position)
	local segments = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = color
		segment.Size = Vector3.new(0.35, 0.35, (b - a).Magnitude)
		segment.CFrame = CFrame.lookAt((a + b) / 2, b)
		segment.Parent = workspace
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
end

local TAG_EFFECTS: { [string]: (Vector3, Color3) -> () } = {
	Classic = function(position, color)
		burst(position, 25, color, NumberRange.new(8, 14), 0.6)
	end,
	Sparks = function(position, color)
		burst(position, 45, color, NumberRange.new(14, 24), 0.4, 50)
	end,
	Hearts = function(position)
		emojis(position, "💖", 7)
	end,
	Stars = function(position)
		emojis(position, "⭐", 7)
	end,
	Confetti = function(position)
		confetti(position, 30, 22)
	end,
	Shockwave = function(position, color)
		shockwave(position - Vector3.new(0, 2.5, 0), color)
		shockwave(position, color)
	end,
	Lightning = lightning,
}

local function playTagEffect(tagger: Player, tagged: Player)
	local root = rootOf(tagged)
	local item = Catalog.get(tagger:GetAttribute("EquippedTagEffect") :: string?)
		or Catalog.get(Config.Progression.DefaultEquipped.TagEffect)
	if not root or not item then
		return
	end
	local play = TAG_EFFECTS[item.look.Effect]
	if play then
		play(root.Position, item.look.Color)
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

local function playPose(character: Model, pose: string)
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
	task.delay(Config.Game.VictoryTime - 1, function()
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
	cap.Parent = workspace
	Debris:AddItem(cap, 3)
end

local VICTORY_EFFECTS: { [string]: (BasePart) -> () } = {
	Confetti = function(root)
		confetti(root.Position + Vector3.new(0, 3, 0), 60, 30)
	end,
	Stars = function(root)
		emojis(root.Position + Vector3.new(0, 2, 0), "⭐", 12)
	end,
	Fireworks = function(root)
		task.spawn(function()
			for i = 1, 4 do
				local spot = root.Position
					+ Vector3.new(
						(math.random() - 0.5) * 16,
						16 + math.random() * 8,
						(math.random() - 0.5) * 16
					)
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
	end,
}

local function playVictory(winner: Player)
	local character = winner.Character
	local root = rootOf(winner)
	local item = Catalog.get(winner:GetAttribute("EquippedVictory") :: string?)
	if not character or not root or not item then
		return
	end
	playPose(character, item.look.Pose)
	if item.look.Pose == "CapToss" then
		task.delay(0.3, capToss, root)
	end
	local effect = VICTORY_EFFECTS[item.look.Effect]
	if effect then
		effect(root)
	end
end

function CosmeticEffects.start()
	Remotes.get("TagHit").OnClientEvent:Connect(function(tagger, tagged)
		if typeof(tagger) == "Instance" and typeof(tagged) == "Instance" then
			playTagEffect(tagger :: Player, tagged :: Player)
		end
	end)
	Remotes.get("Victory").OnClientEvent:Connect(function(winner)
		if typeof(winner) == "Instance" and winner:IsA("Player") then
			-- The winner's new lobby character may still be arriving.
			local waited = 0
			while not rootOf(winner) and waited < 3 do
				waited += task.wait(0.1)
			end
			playVictory(winner)
		end
	end)
end

-- For the inventory: show an effect on your own character to preview it.
function CosmeticEffects.preview(id: string)
	local item = Catalog.get(id)
	local player = game:GetService("Players").LocalPlayer
	local root = rootOf(player)
	if not item or not root then
		return
	end
	if item.kind == "TagEffect" then
		local play = TAG_EFFECTS[item.look.Effect]
		if play then
			play(root.Position + root.CFrame.LookVector * 4, item.look.Color)
		end
	elseif item.kind == "Victory" and player.Character then
		playPose(player.Character, item.look.Pose)
		local effect = VICTORY_EFFECTS[item.look.Effect]
		if effect then
			effect(root)
		end
		if item.look.Pose == "CapToss" then
			task.delay(0.3, capToss, root)
		end
	end
end

return CosmeticEffects
