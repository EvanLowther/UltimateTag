--!strict
-- A card showing one cosmetic, in the game's chunky style: a bright glossy card in its rarity's
-- color with a thick outline, a big preview (trail colors, title text, or an icon for effects),
-- its name in outlined white text, its rarity, and an area underneath for a price pill or a
-- button (Equip, Buy...). Used by the Inventory and Shop tabs and the crate reel.
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

ItemCard.Width, ItemCard.Height = 128, 172

-- The preview area for an item.
local function preview(parent: Frame, item: Catalog.Item)
	local look = item.look
	if item.kind == "Trail" then
		local swatch = Ui.frame(parent, Color3.new(1, 1, 1), 9)
		Ui.outline(swatch, 2.5)
		swatch.AnchorPoint = Vector2.new(0.5, 0.5)
		swatch.Position = UDim2.fromScale(0.5, 0.5)
		swatch.Size = UDim2.new(0.86, 0, 0, 20)
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
		local text = Ui.text(parent, look.Text, 22, look.Color)
		text.Size = UDim2.fromScale(1, 1)
		text.TextScaled = true
		text.TextWrapped = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 24
		limit.Parent = text
	else
		local key = if item.kind == "Victory" and look.Effect == "Fireworks"
			then "Fireworks"
			elseif item.kind == "Victory" then look.Pose
			else look.Effect
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Text = ICONS[key] or "❔"
		icon.TextScaled = true
		icon.Size = UDim2.fromScale(1, 1)
		icon.Parent = parent
	end
end

-- Builds a card. `dim` greys it out (not owned). Returns the card and its bottom area (for a
-- pill or buttons).
function ItemCard.make(parent: Instance, item: Catalog.Item, dim: boolean?): (Frame, Frame)
	local rarity = Catalog.Rarities[item.rarity]
	local card = Ui.card(parent, rarity.color, 14)
	card.Size = UDim2.fromOffset(ItemCard.Width, ItemCard.Height)

	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.Position = UDim2.fromOffset(8, 6)
	area.Size = UDim2.new(1, -16, 0, 62)
	area.Parent = card
	preview(area, item)

	local name = Ui.text(card, item.name:upper(), 16)
	name.Position = UDim2.fromOffset(4, 70)
	name.Size = UDim2.new(1, -8, 0, 22)
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 17
	nameLimit.Parent = name
	local rarityLabel = Ui.text(card, item.rarity, 12, Color3.fromRGB(255, 255, 255), Ui.Font)
	rarityLabel.Position = UDim2.fromOffset(4, 92)
	rarityLabel.Size = UDim2.new(1, -8, 0, 16)

	local bottom = Instance.new("Frame")
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromOffset(8, 114)
	bottom.Size = UDim2.new(1, -16, 0, 50)
	bottom.Parent = card

	if dim then
		local veil = Ui.frame(card, Color3.fromRGB(30, 32, 45), 14)
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundTransparency = 0.5
		veil.ZIndex = 3
		bottom.ZIndex = 4
	end
	return card, bottom
end

return ItemCard
