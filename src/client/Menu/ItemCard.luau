--!strict
-- How a cosmetic is shown in the menus: a preview of what it looks like (a trail swatch in its
-- pattern, the title in its style, an icon for tag effects and victories) and the cards built
-- round it:
--   shop:  a Daily shop card (rarity strip, preview, rarity and kind, name, price button).
--   tile:  a small clickable Locker tile (preview, name, a lock if not owned, ON if equipped).
--   reel:  a card for the crate opening reel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))
local Icons = require(script.Parent.Parent.Icons)
local Ui = require(script.Parent.Ui)

local ItemCard = {}

local WHITE = Color3.new(1, 1, 1)

local TAG_ICONS = {
	Classic = "burst",
	Pop = "ring",
	Sparks = "sparks",
	Hearts = "heart",
	Stars = "sparkle",
	Confetti = "confetti",
	Shockwave = "shockwave",
	Lightning = "bolt",
	Meteor = "meteor",
	Shatter = "shards",
}
local VICTORY_ICONS = {
	None = "dash",
	Flex = "figureFlex",
	Cheer = "figureCheer",
	Backflip = "figureFlip",
	CapToss = "figureCap",
}

-- The icon (client/Icons) for a tag effect or victory.
function ItemCard.icon(item: Catalog.Item): string
	local look = item.look
	if item.kind == "TagEffect" then
		return TAG_ICONS[look.Effect] or "burst"
	elseif item.kind == "Victory" then
		if look.Effect == "Fireworks" then
			return "fireworks"
		elseif look.Effect == "Hologram" then
			return "hologram"
		end
		return VICTORY_ICONS[look.Pose] or "figureCheer"
	end
	return "sparkle"
end

-- An item's icon colors: its look's first color (white if none) and second. Without a second
-- the accent is gold on a white icon and white on a colored one, never dark: the preview wells
-- are nearly black, so a dark accent would vanish (Sparks' spokes, Backflip's arrow).
local function iconColors(item: Catalog.Item): (Color3, Color3)
	local colors = (item.look.Colors or {}) :: { Color3 }
	local main = colors[1] or WHITE
	local accent = colors[2] or if main == WHITE then Ui.Colors.Gold else WHITE
	if item.look.Effect == "Fireworks" then
		return WHITE, Ui.Colors.Gold
	elseif item.look.Effect == "Lightning" then
		return WHITE, Ui.Colors.Cyan
	end
	return main, accent
end

-- A trail swatch: a tilted bar painted in the trail's pattern, glowing for Legendary and up.
local function swatch(parent: GuiObject, look: { [string]: any }, width: number, height: number)
	local holder = Ui.frame(parent)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(width, height)
	holder.Rotation = -6
	local lanes = CosmeticLook.trailLanes(look)
	if not lanes then
		local bar = Ui.frame(holder, WHITE)
		bar.Size = UDim2.fromScale(1, 1)
		Ui.holo(bar)
	else
		for i, sequence in lanes do
			local bar = Ui.frame(holder, WHITE)
			bar.Position = UDim2.fromScale(0, (i - 1) / #lanes)
			bar.Size = UDim2.fromScale(1, 1 / #lanes)
			local gradient = Instance.new("UIGradient")
			gradient.Color = sequence
			gradient.Parent = bar
		end
	end
	local glow = Instance.new("UIStroke")
	if look.Effect or (look.Light or 0) >= 1 then
		glow.Color = if lanes then CosmeticLook.mainColor(look) else CosmeticLook.Holo[2]
		glow.Thickness = 2
		glow.Transparency = 0.35
	else
		-- A faint edge, so dark colors still show on the dark card.
		glow.Color = Color3.fromRGB(90, 90, 96)
		glow.Thickness = 1
	end
	glow.Parent = holder
	if look.Effect then
		local sparkle = Ui.icon(parent, "sparkle", math.max(12, height + 6), WHITE, Ui.Colors.Gold)
		sparkle.AnchorPoint = Vector2.new(0, 0.5)
		sparkle.Position = UDim2.new(0.5, width / 2 + 4, 0.5, 0)
		if look.Pattern == "Holo" then
			Icons.holo(sparkle)
		end
	end
end

-- A title in its style (solid, two-tone, gradient, shining, holo).
local function titleText(parent: GuiObject, item: Catalog.Item, size: number)
	local look = item.look
	local label = Ui.title(parent, look.Text or item.name, size, WHITE)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
	local sequence, rotation, animation = CosmeticLook.titleGradient(look)
	if sequence then
		local gradient = Instance.new("UIGradient")
		gradient.Color = sequence
		gradient.Rotation = rotation
		gradient.Parent = label
		if animation then
			game:GetService("CollectionService"):AddTag(gradient, animation)
		end
	else
		label.TextColor3 = CosmeticLook.mainColor(look)
	end
	Ui.stroke(label, 1.5)
end

-- Draws an item's preview inside `parent` (sized to fit). `scale`: 1 normal, bigger for the
-- Locker's info and the reel.
function ItemCard.preview(parent: GuiObject, item: Catalog.Item, scale: number?)
	local s = scale or 1
	if item.kind == "Trail" then
		swatch(parent, item.look, math.floor(58 * s), math.floor(10 * s))
	elseif item.kind == "Title" then
		local inner = Ui.frame(parent)
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.new(1, -8, 0, math.floor(24 * s))
		titleText(inner, item, math.floor(20 * s))
	elseif item.kind == "TagEffect" and item.look.Effect == "Pow" then
		-- The comic burst with TAG! across it, as it pops up in the game.
		local main, accent = iconColors(item)
		Ui.centerIcon(parent, "burst", math.floor(40 * s), main, accent)
		local tag = Ui.title(parent, "TAG!", math.floor(15 * s), main)
		tag.AnchorPoint = Vector2.new(0.5, 0.5)
		tag.Position = UDim2.fromScale(0.5, 0.5)
		tag.Size = UDim2.fromOffset(math.floor(48 * s), math.floor(20 * s))
		tag.Rotation = -8
		Ui.stroke(tag, 2, accent)
	else
		local main, accent = iconColors(item)
		local icon = Ui.centerIcon(parent, ItemCard.icon(item), math.floor(32 * s), main, accent)
		if item.rarity == "Iridescent" then
			Icons.holo(icon)
		end
	end
end

-- "EPIC TRAIL": the rarity in its color and the kind in grey, side by side.
function ItemCard.rarityLine(parent: Instance, item: Catalog.Item, size: number?): Frame
	local line = Ui.row(parent, 4, (size or 12) + 4)
	local rarity = Ui.rarity(line, item.rarity, size or 12)
	rarity.Size = UDim2.fromScale(0, 1)
	rarity.AutomaticSize = Enum.AutomaticSize.X
	rarity.LayoutOrder = 1
	local kind = Ui.caps(line, Catalog.KindSingular[item.kind] or "", size or 12, Ui.Colors.Dim)
	kind.Size = UDim2.fromScale(0, 1)
	kind.AutomaticSize = Enum.AutomaticSize.X
	kind.LayoutOrder = 2
	return line
end

-- A Daily shop card. `oldPrice` (a deal) adds a ribbon and the old price struck out. `tall`
-- makes the big deal card. Returns the card.
function ItemCard.shop(
	parent: Instance,
	item: Catalog.Item,
	price: number,
	oldPrice: number?,
	owned: boolean,
	canAfford: boolean,
	onBuy: () -> (),
	tall: boolean?
): Frame
	local card = Ui.panel(parent, Ui.Colors.Card, 10)
	card.Name = item.id
	local strip = Ui.rarityStrip(card, item.rarity, 4)
	strip.Size = UDim2.new(1, -10, 0, 4)
	local wellHeight = if tall then 120 else 54
	local well = Ui.frame(card, Ui.Colors.Well)
	well.Name = "Well"
	well.Position = UDim2.fromOffset(8, 12)
	well.Size = UDim2.new(1, -16, 0, wellHeight)
	ItemCard.preview(well, item, if tall then 1.6 else 1)
	local y = 12 + wellHeight + 6
	local line = ItemCard.rarityLine(card, item, 12)
	line.Position = UDim2.fromOffset(8, y)
	line.Size = UDim2.new(1, -16, 0, 16)
	local name = if tall
		then Ui.title(card, item.name, 30, Ui.Colors.Text)
		else Ui.caps(card, item.name, 15, Ui.Colors.Text)
	name.Position = UDim2.fromOffset(8, y + 16)
	name.Size = UDim2.new(1, -16, 0, if tall then 32 else 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local buy = Ui.button(
		card,
		if owned then "Owned" else "",
		if owned then Ui.Colors.Tab elseif canAfford then Ui.Colors.Yellow else Ui.Colors.Track,
		function()
			if not owned then
				onBuy()
			end
		end,
		if owned then Ui.Colors.Dim else Ui.Colors.Ink,
		7,
		if owned then "check" else nil
	)
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = UDim2.new(0, 8, 1, -10)
	buy.Size = UDim2.fromOffset(if tall then 130 else 110, 30)
	if not owned then
		local amount =
			Ui.coinAmount(buy, price, 15, if canAfford then Ui.Colors.Ink else Ui.Colors.Dim)
		amount.AnchorPoint = Vector2.new(0.5, 0.5)
		amount.Position = UDim2.fromScale(0.5, 0.5)
		amount.ZIndex = 2
		for _, child in amount:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 3
			end
		end
	end
	if oldPrice then
		local ribbon = Ui.slab(card, Ui.Colors.Pink, 6)
		ribbon.Position = UDim2.fromOffset(10, 16)
		ribbon.Size = UDim2.fromOffset(104, 22)
		ribbon.ZIndex = 3
		local text = Ui.caps(ribbon, `Deal -{math.floor((1 - price / oldPrice) * 100 + 0.5)}%`, 13)
		text.Size = UDim2.fromScale(1, 1)
		text.ZIndex = 4
		local was = Ui.caps(card, `<s>{Ui.number(oldPrice)}</s>`, 13, Ui.Colors.Dim)
		was.AnchorPoint = Vector2.new(0, 1)
		was.Position = UDim2.new(0, 148, 1, -14)
		was.Size = UDim2.fromOffset(80, 20)
		was.TextXAlignment = Enum.TextXAlignment.Left
	end
	return card
end

-- A Locker tile. Returns the clickable tile.
function ItemCard.tile(
	parent: Instance,
	item: Catalog.Item,
	owned: boolean,
	equipped: boolean,
	selected: boolean,
	onClick: () -> ()
): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = item.id
	tile.AutoButtonColor = false
	tile.BackgroundTransparency = 1
	tile.Text = ""
	local back = Ui.panel(tile, if selected then Color3.fromRGB(23, 58, 66) else Ui.Colors.Card, 8)
	back.Size = UDim2.fromScale(1, 1)
	local strip = Ui.rarityStrip(tile, item.rarity, 4)
	strip.Size = UDim2.new(1, -8, 0, 4)
	local well = Ui.frame(tile)
	well.Position = UDim2.fromOffset(4, 8)
	well.Size = UDim2.new(1, -8, 1, -28)
	well.ZIndex = 2
	ItemCard.preview(well, item, 0.85)
	-- Titles already show their name in the preview: the line under says the rarity instead.
	local label = if item.kind == "Title" then item.rarity else item.name
	local name = Ui.caps(tile, label, 11, Ui.Colors.Text)
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -4)
	name.Size = UDim2.new(1, -6, 0, 14)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 2
	if item.kind == "Title" and owned then
		name.TextColor3 = Ui.rarityColor(item.rarity)
	end
	if not owned then
		name.TextColor3 = Ui.Colors.Dim
		local veil = Ui.frame(tile, Ui.Colors.Card)
		veil.Position = well.Position
		veil.Size = well.Size
		veil.BackgroundTransparency = 0.45
		veil.ZIndex = 3
		local lock = Ui.icon(tile, "lock", 13, Ui.Colors.Dim, Ui.Colors.Card)
		lock.Position = UDim2.fromOffset(6, 10)
		lock.ZIndex = 4
	end
	if equipped then
		local on = Ui.caps(tile, "On", 11, Ui.Colors.Ink)
		on.AnchorPoint = Vector2.new(1, 0)
		on.Position = UDim2.new(1, 0, 0, 4)
		on.Size = UDim2.fromOffset(24, 14)
		on.BackgroundColor3 = Ui.Colors.Cyan
		on.BackgroundTransparency = 0
		on.ZIndex = 4
	end
	tile.Activated:Connect(onClick)
	tile.Parent = parent
	return tile
end

-- A card for the crate opening reel.
function ItemCard.reel(parent: Instance, item: Catalog.Item, width: number, height: number): Frame
	local card = Ui.panel(parent, Ui.Colors.Card, 10)
	card.Name = item.id
	card.Size = UDim2.fromOffset(width, height)
	local strip = Ui.rarityStrip(card, item.rarity, 5)
	strip.Size = UDim2.new(1, -10, 0, 5)
	local well = Ui.frame(card, Ui.Colors.Well)
	well.Position = UDim2.fromOffset(8, 14)
	well.Size = UDim2.new(1, -16, 0, height - 70)
	ItemCard.preview(well, item, 1.2)
	local rarity = Ui.rarity(card, item.rarity, 12)
	rarity.Position = UDim2.new(0, 8, 1, -52)
	rarity.Size = UDim2.new(1, -16, 0, 16)
	local name = Ui.caps(card, item.name, 14, Ui.Colors.Text)
	name.Position = UDim2.new(0, 8, 1, -34)
	name.Size = UDim2.new(1, -16, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	return card
end

return ItemCard
