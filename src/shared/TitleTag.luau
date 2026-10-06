--!strict
-- The title over a character's head: a BillboardGui with the player's level and their equipped
-- title, styled by its look (shared/Catalog, shared/CosmeticLook): Solid, TwoTone, Gradient,
-- Shine (a moving shine and sparkles) or Holo (holo colors on a framed plate, with the item's
-- serial number). The server builds one for every player (server/Cosmetics); the Locker builds
-- one on its preview character. Moving gradients are animated on each client (client/GradientFx).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))

local TitleTag = {}

TitleTag.Name = "TitleTag"

local SPARKLES = "TitleSparkles"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DISPLAY = Font.new("rbxasset://fonts/families/Bangers.json")
local HEAVY = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Heavy)
local INK = Color3.fromRGB(17, 17, 17)
local CYAN = Color3.fromRGB(25, 227, 255)
local HEIGHT = 3 -- studs above the head

local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

local function label(parent: Instance, name: string, font: Font, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = ""
	l.Parent = parent
	return l
end

local function build(head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = TitleTag.Name
	gui.Size = UDim2.fromOffset(300, 78)
	gui.StudsOffset = Vector3.new(0, HEIGHT, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90

	local level = label(gui, "Level", HEAVY, 15)
	level.Position = UDim2.fromOffset(0, 0)
	level.Size = UDim2.new(1, 0, 0, 18)
	level.TextColor3 = CYAN
	outline(level, 2)

	-- The plate holds the title; Holo titles fill it in and frame it.
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.new(0.5, 0, 0, 20)
	plate.Size = UDim2.fromOffset(0, 38)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.BackgroundColor3 = INK
	plate.BackgroundTransparency = 1
	plate.BorderSizePixel = 0
	plate.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = plate
	local frame = Instance.new("UIStroke")
	frame.Name = "Frame"
	frame.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	frame.Thickness = 3
	frame.Color = Color3.new(1, 1, 1)
	frame.Enabled = false
	frame.Parent = plate
	local frameGradient = Instance.new("UIGradient")
	frameGradient.Color = CosmeticLook.holoSequence(0)
	frameGradient.Parent = frame
	CollectionService:AddTag(frameGradient, "HoloGradient")

	local title = label(plate, "Title", DISPLAY, 32)
	title.Size = UDim2.fromScale(0, 1)
	title.AutomaticSize = Enum.AutomaticSize.X
	outline(title, 2.5)

	local serial = label(gui, "Serial", HEAVY, 13)
	serial.AnchorPoint = Vector2.new(0.5, 0)
	serial.Position = UDim2.new(0.5, 0, 0, 60)
	serial.Size = UDim2.new(1, 0, 0, 16)
	serial.TextColor3 = CosmeticLook.Holo[2]
	outline(serial, 2)

	gui.Parent = head
	return gui
end

-- Sparkles round a Legendary or Iridescent title (nil colors: none).
local function setSparkles(head: BasePart, colors: ColorSequence?)
	local old = head:FindFirstChild(SPARKLES)
	if old then
		old:Destroy()
	end
	if not colors then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = SPARKLES
	attachment.Position = Vector3.new(0, HEIGHT + 0.3, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = colors
	emitter.LightEmission = 1
	emitter.Rate = 5
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(1, 2.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Drag = 3
	emitter.Parent = attachment
	attachment.Parent = head
end

-- Puts (or updates) the title over `head`: `item` is the equipped Title (nil: level only),
-- `serial` its serial number (Iridescent).
function TitleTag.apply(head: BasePart, item: Catalog.Item?, level: number, serial: number?)
	local gui = (head:FindFirstChild(TitleTag.Name) :: BillboardGui?) or build(head)
	local levelLabel = gui:FindFirstChild("Level") :: TextLabel
	local plate = gui:FindFirstChild("Plate") :: Frame
	local title = plate:FindFirstChild("Title") :: TextLabel
	local frame = plate:FindFirstChild("Frame") :: UIStroke
	local serialLabel = gui:FindFirstChild("Serial") :: TextLabel

	levelLabel.Text = `LV {level}`
	local old = title:FindFirstChildOfClass("UIGradient")
	if old then
		old:Destroy()
	end
	local look = if item then item.look else {}
	title.Text = if item then (look.Text or item.name) else ""
	local sequence, rotation, animation = CosmeticLook.titleGradient(look)
	if sequence then
		title.TextColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Color = sequence
		gradient.Rotation = rotation
		gradient.Parent = title
		if animation then
			CollectionService:AddTag(gradient, animation)
		end
	else
		title.TextColor3 = CosmeticLook.mainColor(look)
	end

	local holo = look.Style == "Holo"
	plate.BackgroundTransparency = if holo then 0.25 else 1
	frame.Enabled = holo
	serialLabel.Text = if holo and serial then `NO. {serial}` else ""
	gui.MaxDistance = if item and item.rarity == "Iridescent"
		then 160
		elseif item and item.rarity == "Legendary" then 120
		else 90

	if look.Style == "Shine" then
		setSparkles(head, CosmeticLook.sequence(look.Colors or {}))
	elseif holo then
		setSparkles(head, CosmeticLook.holoSequence(0))
	else
		setSparkles(head, nil)
	end
end

return TitleTag
