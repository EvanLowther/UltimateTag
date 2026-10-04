--!strict
-- A card showing one cosmetic: a rarity-colored top, a preview (trail colors, title text, or an
-- icon for effects), its name and rarity, and an action button underneath (Equip, Buy...).
-- Used by the Inventory and Shop tabs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))
local Ui = require(script.Parent.Ui)

local ItemCard = {}

local ICONS = {
	Classic = "💥",
	Sparks = "✨",
	Hearts = "💖",
	Stars = "⭐",
	Confetti = "🎉",
	Shockwave = "🌀",
	Lightning = "⚡",
	Flex = "💪",
	Cheer = "🙌",
	Backflip = "🤸",
	CapToss = "🎓",
	Fireworks = "🎆",
	None = "➖",
}

ItemCard.Width, ItemCard.Height = 128, 168

-- The preview area for an item.
local function preview(parent: Frame, item: Catalog.Item)
	local look = item.look
	if item.kind == "Trail" then
		local swatch = Ui.frame(parent, Color3.new(1, 1, 1), 8)
		swatch.AnchorPoint = Vector2.new(0.5, 0.5)
		swatch.Position = UDim2.fromScale(0.5, 0.5)
		swatch.Size = UDim2.new(0.85, 0, 0, 16)
		local gradient = Instance.new("UIGradient")
		local colors = look.Colors :: { Color3 }
		if #colors == 1 then
			gradient.Color = ColorSequence.new(colors[1])
		else
			local points = {}
			for i, color in colors do
				table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
			end
			gradient.Color = ColorSequence.new(points)
		end
		gradient.Parent = swatch
	elseif item.kind == "Title" then
		local text = Ui.label(parent, look.Text, 20, look.Color, Ui.BigFont)
		text.Size = UDim2.fromScale(1, 1)
		text.TextScaled = true
		text.TextWrapped = true
		Ui.outlined(text, 1.5)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 24
		limit.Parent = text
	else
		local key = if item.kind == "Victory" and look.Effect == "Fireworks"
			then "Fireworks"
			elseif item.kind == "Victory" then look.Pose
			else look.Effect
		local icon = Ui.label(parent, ICONS[key] or "❔", 40)
		icon.Size = UDim2.fromScale(1, 1)
	end
end

-- Builds a card. `dim` greys it out (not owned). Returns the card and its bottom area (for
-- buttons).
function ItemCard.make(parent: Instance, item: Catalog.Item, dim: boolean?): (Frame, Frame)
	local rarity = Catalog.Rarities[item.rarity]
	local card = Ui.frame(parent, Ui.Colors.Card, 12)
	card.Size = UDim2.fromOffset(ItemCard.Width, ItemCard.Height)
	Ui.stroke(card, rarity.color, 2.5)

	local top = Ui.frame(card, rarity.color, 12)
	top.Size = UDim2.new(1, 0, 0, 70)
	local shade = Instance.new("UIGradient")
	shade.Transparency = NumberSequence.new(0.1, 0.55)
	shade.Rotation = 90
	shade.Parent = top
	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.Size = UDim2.new(1, -10, 1, -10)
	area.Position = UDim2.fromOffset(5, 5)
	area.Parent = top
	preview(area, item)

	local name = Ui.label(card, item.name, 16)
	name.Position = UDim2.fromOffset(4, 72)
	name.Size = UDim2.new(1, -8, 0, 20)
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 17
	nameLimit.Parent = name
	local rarityLabel = Ui.label(card, item.rarity, 13, rarity.color)
	rarityLabel.Position = UDim2.fromOffset(4, 92)
	rarityLabel.Size = UDim2.new(1, -8, 0, 16)

	local bottom = Instance.new("Frame")
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromOffset(6, 112)
	bottom.Size = UDim2.new(1, -12, 0, 50)
	bottom.Parent = card

	if dim then
		local veil = Ui.frame(card, Color3.new(0, 0, 0), 12)
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundTransparency = 0.45
		veil.ZIndex = 3
		bottom.ZIndex = 4
		for _, child in bottom:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 4
			end
		end
	end
	return card, bottom
end

return ItemCard
