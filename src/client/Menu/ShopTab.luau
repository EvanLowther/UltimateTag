--!strict
-- Menu, Shop tab, in the game's chunky style: a wide banner card for the mystery crate (odds,
-- price or free crates), a divider, then today's offers (shared/ShopRotation: featured items
-- and one deal) as bright cards with price buttons, and a countdown to tomorrow's shop. Buying
-- and opening go through the server (server/Shop); results pop up through Menu/Popups.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))
local Profile = require(script.Parent.Parent.Profile)
local ItemCard = require(script.Parent.ItemCard)
local Ui = require(script.Parent.Ui)

local ShopTab = {}

function ShopTab.build(page: Frame, api: { [string]: any }): () -> ()
	local scroll = Ui.scroll(page, 12)

	-- The crate banner.
	local banner = Ui.card(scroll, Ui.Colors.Teal, 14)
	banner.Size = UDim2.new(1, -8, 0, 112)
	banner.LayoutOrder = 1
	local box = Instance.new("TextLabel")
	box.BackgroundTransparency = 1
	box.Text = "📦"
	box.TextScaled = true
	box.Position = UDim2.fromOffset(10, 8)
	box.Size = UDim2.fromOffset(96, 96)
	box.Rotation = -8
	box.Parent = banner
	local bannerTitle = Ui.text(banner, "MYSTERY CRATE", 28)
	bannerTitle.Position = UDim2.fromOffset(116, 10)
	bannerTitle.Size = UDim2.new(1, -250, 0, 32)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	local odds = {}
	for _, name in { "Common", "Rare", "Epic", "Legendary" } do
		local rarity = Catalog.Rarities[name]
		table.insert(odds, `<font color="#{rarity.color:ToHex()}">{name} {rarity.weight}%</font>`)
	end
	local oddsLabel = Ui.text(banner, table.concat(odds, "  "), 14, nil, Ui.Font)
	oddsLabel.Position = UDim2.fromOffset(116, 44)
	oddsLabel.Size = UDim2.new(1, -250, 0, 18)
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	local dupLabel = Ui.text(
		banner,
		`A random cosmetic! Duplicates pay back {math.floor(Config.Shop.DuplicateRefund * 100)}%`,
		13,
		nil,
		Ui.Font
	)
	dupLabel.Position = UDim2.fromOffset(116, 64)
	dupLabel.Size = UDim2.new(1, -250, 0, 18)
	dupLabel.TextXAlignment = Enum.TextXAlignment.Left
	local open = Ui.button(banner, "OPEN", Ui.Colors.Yellow, function()
		api.send("OpenCrate")
	end)
	open.AnchorPoint = Vector2.new(1, 0.5)
	open.Position = UDim2.new(1, -14, 0.5, 0)
	open.Size = UDim2.fromOffset(118, 64)
	local openPrice = Ui.pricePill(banner, Config.Shop.CratePrice)
	openPrice.AnchorPoint = Vector2.new(1, 1)
	openPrice.Position = UDim2.new(1, -30, 1, -4)
	openPrice.ZIndex = 3
	for _, child in openPrice:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 3
		end
	end

	local divider = Ui.divider(scroll)
	divider.LayoutOrder = 2

	-- Today's offers.
	local headerRow = Instance.new("Frame")
	headerRow.BackgroundTransparency = 1
	headerRow.Size = UDim2.new(1, -8, 0, 30)
	headerRow.LayoutOrder = 3
	headerRow.Parent = scroll
	local header = Ui.text(headerRow, "TODAY'S SHOP", 24, Ui.Colors.Coin)
	header.Size = UDim2.fromScale(0.5, 1)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local countdown = Ui.ink(headerRow, "", 16, Ui.Colors.InkDim)
	countdown.AnchorPoint = Vector2.new(1, 0)
	countdown.Position = UDim2.fromScale(1, 0)
	countdown.Size = UDim2.fromScale(0.5, 1)
	countdown.TextXAlignment = Enum.TextXAlignment.Right

	local offers = Instance.new("Frame")
	offers.BackgroundTransparency = 1
	offers.Size = UDim2.new(1, -8, 0, 0)
	offers.AutomaticSize = Enum.AutomaticSize.Y
	offers.LayoutOrder = 4
	offers.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(ItemCard.Width, ItemCard.Height)
	grid.CellPadding = UDim2.fromOffset(14, 14)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = offers

	local function tick()
		countdown.Text = `New items in {DayClock.format(DayClock.secondsToNextDay())}`
	end

	local shownDay = -1
	local function refresh()
		local profile = Profile.get()
		if not profile then
			return
		end
		tick()
		local free = profile.Crates > 0
		Ui.setText(open, if free then "FREE!" else "OPEN")
		open.BackgroundColor3 = if free then Ui.Colors.Green else Ui.Colors.Yellow
		local priceLabel = openPrice:FindFirstChild("Label") :: TextLabel?
		if priceLabel then
			priceLabel.Text = if free
				then `x{profile.Crates}`
				else Ui.number(Config.Shop.CratePrice)
		end

		shownDay = DayClock.day()
		for _, child in offers:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, offer in ShopRotation.today() do
			local item = Catalog.get(offer.id)
			if not item then
				continue
			end
			local card, bottom = ItemCard.make(offers, item)
			card.LayoutOrder = i
			if offer.deal then
				local badge = Ui.card(card, Ui.Colors.Red, 8)
				badge.Size = UDim2.fromOffset(58, 26)
				badge.Position = UDim2.fromOffset(-8, -8)
				badge.Rotation = -10
				badge.ZIndex = 5
				local text = Ui.text(badge, `-{math.floor(Config.Shop.DealDiscount * 100)}%`, 17)
				text.Size = UDim2.fromScale(1, 1)
				text.ZIndex = 5
			end
			local owned = profile.Owned[offer.id] == true
			local affordable = profile.Coins >= offer.price
			local buy = Ui.button(
				bottom,
				if owned then "OWNED" else "",
				if owned
					then Ui.Colors.Green
					elseif affordable then Ui.Colors.Yellow
					else Ui.Colors.Locked,
				function()
					if not owned then
						api.send("ShopBuy", offer.id)
					end
				end
			)
			buy.Size = UDim2.new(1, 0, 0, 40)
			if not owned then
				local pill = Ui.pricePill(buy, offer.price)
				pill.AnchorPoint = Vector2.new(0.5, 0.5)
				pill.Position = UDim2.fromScale(0.5, 0.5)
				pill.Size = UDim2.fromOffset(92, 28)
			end
		end
	end

	-- Keep the countdown ticking (and roll over to tomorrow's shop) while the tab is open.
	task.spawn(function()
		while true do
			task.wait(1)
			if page.Visible then
				if DayClock.day() ~= shownDay then
					refresh()
				else
					tick()
				end
			end
		end
	end)
	return refresh
end

return ShopTab
