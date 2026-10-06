--!strict
-- Menu, Shop page: two tabs.
--   Daily shop: today's offers (shared/ShopRotation: a big deal card and four featured items),
--   a countdown to tomorrow's shop, and the Mystery crate with its odds (bought crates are
--   opened in Rewards). Buying goes through the server (server/Shop).
--   Coin shop: coin packs and game passes for Robux (Config.Monetization; server/Purchases).
--   Each one shows "Soon" until it has an ID.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
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

local CARD_HEIGHT = 150
local ROBUX = "R$"

-- The header's right side: your coins.
function ShopTab.info(profile: { [string]: any }): string
	return `{Ui.number(profile.Coins)} coins`
end

-- The crate odds as a row of colored segments, widths by chance.
local function oddsBar(parent: Instance): Frame
	local bar = Ui.frame(parent)
	bar.Name = "Odds"
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar
	for i, name in Catalog.CrateOrder do
		local rarity = Catalog.Rarities[name]
		local part = Ui.frame(bar, rarity.color)
		part.LayoutOrder = i
		part.Size = if name == "Iridescent"
			then UDim2.new(0, 5, 1, 0)
			else UDim2.new(rarity.weight / 100, -1, 1, 0)
		if name == "Iridescent" then
			part.BackgroundColor3 = Color3.new(1, 1, 1)
			Ui.holo(part)
		end
	end
	return bar
end

-- "45% common · 30% rare · ..." in the rarities' colors.
function ShopTab.oddsText(): string
	local parts = {}
	for _, name in Catalog.CrateOrder do
		local rarity = Catalog.Rarities[name]
		table.insert(parts, `<font color="#{rarity.color:ToHex()}">{rarity.weight}% {name}</font>`)
	end
	return table.concat(parts, "  ·  ")
end

local function header(parent: Instance, text: string, order: number): (Frame, TextLabel)
	local row = Ui.frame(parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 22)
	local left = Ui.caps(row, text, 14, Ui.Colors.Text)
	left.Size = UDim2.fromScale(0.5, 1)
	left.TextXAlignment = Enum.TextXAlignment.Left
	local right = Ui.caps(row, "", 12, Ui.Colors.Dim)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.fromScale(0.5, 1)
	right.TextXAlignment = Enum.TextXAlignment.Right
	return row, right
end

-- Robux prices from Roblox (cached), falling back to the configured numbers.
local prices: { [string]: number } = {}
local function priceOf(id: number?, infoType: Enum.InfoType, fallback: number): number
	if not id then
		return fallback
	end
	local key = `{infoType.Name}{id}`
	if prices[key] then
		return prices[key]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	prices[key] = if ok and info and info.PriceInRobux then info.PriceInRobux else fallback
	return prices[key]
end

local function buildDaily(page: Frame, api: { [string]: any }): () -> ()
	local scroll = Ui.scroll(page, 10)
	local _, countdown = header(scroll, "Today's drop", 1)

	local offers = Ui.frame(scroll)
	offers.Name = "Offers"
	offers.LayoutOrder = 2
	offers.Size = UDim2.new(1, 0, 0, CARD_HEIGHT * 2 + 10)
	local dealSlot = Ui.frame(offers)
	dealSlot.Size = UDim2.new(0, 230, 1, 0)
	local featured = Ui.frame(offers)
	featured.Position = UDim2.fromOffset(240, 0)
	featured.Size = UDim2.new(1, -240, 1, 0)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -5, 0, CARD_HEIGHT)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = featured

	-- The Mystery crate.
	local crate = Ui.panel(scroll, Ui.Colors.Card, 10)
	crate.LayoutOrder = 3
	crate.Size = UDim2.new(1, 0, 0, 104)
	local crateStrip = Ui.frame(crate, Ui.Colors.Yellow)
	crateStrip.Size = UDim2.new(1, -10, 0, 4)
	local box = Ui.icon(crate, "crate", 64, Ui.Colors.Yellow, Ui.Colors.Ink)
	box.Position = UDim2.fromOffset(14, 22)
	local crateName = Ui.caps(crate, "Mystery crate", 16, Ui.Colors.Text)
	crateName.Position = UDim2.fromOffset(90, 12)
	crateName.Size = UDim2.new(1, -250, 0, 20)
	crateName.TextXAlignment = Enum.TextXAlignment.Left
	local crateNote = Ui.text(
		crate,
		"Any trail, tag effect, title or victory. Open it in Rewards.",
		13,
		Ui.Colors.Dim
	)
	crateNote.Position = UDim2.fromOffset(90, 32)
	crateNote.Size = UDim2.new(1, -250, 0, 18)
	crateNote.TextXAlignment = Enum.TextXAlignment.Left
	local bar = oddsBar(crate)
	bar.Position = UDim2.fromOffset(90, 56)
	bar.Size = UDim2.new(1, -260, 0, 8)
	local odds = Ui.caps(crate, ShopTab.oddsText(), 11, Ui.Colors.Dim)
	odds.Position = UDim2.fromOffset(90, 68)
	odds.Size = UDim2.new(1, -250, 0, 28)
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.TextWrapped = true
	local buyCrate = Ui.button(crate, "", Ui.Colors.Yellow, function()
		api.send("BuyCrate")
	end)
	buyCrate.AnchorPoint = Vector2.new(1, 0.5)
	buyCrate.Position = UDim2.new(1, -16, 0.5, -8)
	buyCrate.Size = UDim2.fromOffset(130, 38)
	local cratePrice = Ui.coinAmount(buyCrate, Config.Shop.CratePrice, 16, Ui.Colors.Ink)
	cratePrice.AnchorPoint = Vector2.new(0.5, 0.5)
	cratePrice.Position = UDim2.fromScale(0.5, 0.5)
	for _, child in cratePrice:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 3
		end
	end
	local owned = Ui.caps(crate, "", 11, Ui.Colors.Lime)
	owned.AnchorPoint = Vector2.new(1, 0)
	owned.Position = UDim2.new(1, -16, 0.5, 16)
	owned.Size = UDim2.fromOffset(160, 16)
	owned.TextXAlignment = Enum.TextXAlignment.Center

	local function tick()
		countdown.Text = Ui.upper(`New items in {DayClock.format(DayClock.secondsToNextDay())}`)
	end

	local shownDay = -1
	local function refresh()
		local profile = Profile.get()
		if not profile then
			return
		end
		tick()
		local canBuyCrate = profile.Coins >= Config.Shop.CratePrice
		Ui.setColor(buyCrate, if canBuyCrate then Ui.Colors.Yellow else Ui.Colors.Track)
		owned.Text = if profile.Crates > 0 then Ui.upper(`You have {profile.Crates}`) else ""

		shownDay = DayClock.day()
		Ui.clear(dealSlot)
		Ui.clear(featured)
		local order = 0
		for _, offer in ShopRotation.today() do
			local item = Catalog.get(offer.id)
			if not item then
				continue
			end
			local has = profile.Owned[offer.id] == true
			local function buy()
				api.send("ShopBuy", offer.id)
			end
			if offer.deal then
				local card = ItemCard.shop(
					dealSlot,
					item,
					offer.price,
					Catalog.price(item),
					has,
					profile.Coins >= offer.price,
					buy,
					true
				)
				card.Size = UDim2.fromScale(1, 1)
			else
				order += 1
				local card = ItemCard.shop(
					featured,
					item,
					offer.price,
					nil,
					has,
					profile.Coins >= offer.price,
					buy
				)
				card.LayoutOrder = order
			end
		end
	end

	-- Keep the countdown ticking (and roll over to tomorrow's shop) while it's open.
	task.spawn(function()
		while true do
			task.wait(1)
			if page.Visible and page.Parent and (page.Parent :: GuiObject).Visible then
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

local function buildCoins(page: Frame): () -> ()
	local settings = Config.Monetization
	local player = Players.LocalPlayer
	local scroll = Ui.scroll(page, 10)
	header(scroll, "Coin packs", 1)

	local packs = Ui.frame(scroll)
	packs.LayoutOrder = 2
	packs.Size = UDim2.new(1, 0, 0, 196)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / #settings.CoinPacks, -8, 1, 0)
	grid.CellPadding = UDim2.fromOffset(10, 0)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = packs

	local priceLabels: { [number]: TextButton } = {}
	for i, pack in settings.CoinPacks do
		local card = Ui.panel(packs, Ui.Colors.Card, 10)
		card.LayoutOrder = i
		local tagColor = if pack.Tag == "Best value" then Ui.Colors.Cyan else Ui.Colors.Pink
		local strip = Ui.frame(card, if pack.Tag then tagColor else Ui.Colors.Yellow)
		strip.Size = UDim2.new(1, -10, 0, if pack.Tag then 18 else 4)
		if pack.Tag then
			local tag = Ui.caps(
				strip,
				pack.Tag,
				11,
				if pack.Tag == "Best value" then Ui.Colors.Ink else Ui.Colors.Text
			)
			tag.Size = UDim2.fromScale(1, 1)
		end
		local well = Ui.frame(card, Ui.Colors.Well)
		well.Position = UDim2.fromOffset(8, 24)
		well.Size = UDim2.new(1, -16, 0, 60)
		Ui.centerIcon(well, pack.Icon or "coin", 50, Ui.Colors.Cyan, Ui.Colors.Text)
		local amount = Ui.title(card, Ui.number(pack.Coins), 28, Ui.Colors.Yellow)
		amount.Position = UDim2.fromOffset(0, 90)
		amount.Size = UDim2.new(1, 0, 0, 30)
		local bonus = Ui.caps(
			card,
			if (pack.Bonus or 0) > 0 then `+{pack.Bonus}% bonus` else "",
			11,
			Ui.Colors.Lime
		)
		bonus.Position = UDim2.fromOffset(0, 120)
		bonus.Size = UDim2.new(1, 0, 0, 16)
		local buy = Ui.button(
			card,
			if pack.Id then `{ROBUX} {pack.Robux}` else "Soon",
			if pack.Id then Ui.Colors.Lime else Ui.Colors.Track,
			function()
				if pack.Id then
					MarketplaceService:PromptProductPurchase(player, pack.Id)
				end
			end,
			if pack.Id then Ui.Colors.Ink else Ui.Colors.Dim,
			6
		)
		buy.AnchorPoint = Vector2.new(0.5, 1)
		buy.Position = UDim2.new(0.5, 0, 1, -10)
		buy.Size = UDim2.new(1, -24, 0, 30)
		if pack.Id then
			priceLabels[i] = buy
		end
	end

	header(scroll, "Game passes", 3)
	local passes = Ui.frame(scroll)
	passes.LayoutOrder = 4
	passes.Size = UDim2.new(1, 0, 0, 78)
	local passGrid = Instance.new("UIGridLayout")
	passGrid.CellSize = UDim2.new(0.5, -5, 1, 0)
	passGrid.CellPadding = UDim2.fromOffset(10, 0)
	passGrid.Parent = passes

	type Pass = {
		name: string,
		icon: string,
		text: string,
		id: number?,
		robux: number,
		attribute: string,
		color: Color3,
	}
	local passList: { Pass } = {
		{
			name = "VIP",
			icon = "crown",
			text = `+{math.floor(settings.VipXPBonus * 100)}% XP, the VIP title`,
			id = settings.VipPass,
			robux = settings.PassRobux.Vip,
			attribute = "VIP",
			color = Ui.Colors.Gold,
		},
		{
			name = "2x coins",
			icon = "coin2x",
			text = "Double coins from every game",
			id = settings.DoubleCoinsPass,
			robux = settings.PassRobux.DoubleCoins,
			attribute = "DoubleCoins",
			color = Ui.Colors.Yellow,
		},
	}
	local passButtons: { [Pass]: TextButton } = {}
	for _, pass in passList do
		local card = Ui.panel(passes, Ui.Colors.Card, 10)
		local strip = Ui.frame(card, pass.color)
		strip.Size = UDim2.new(1, -10, 0, 4)
		local icon = Ui.icon(card, pass.icon, 44, Ui.Colors.Gold, Ui.Colors.Ink)
		icon.Position = UDim2.fromOffset(14, 18)
		local name = Ui.caps(card, pass.name, 16, Ui.Colors.Text)
		name.Position = UDim2.fromOffset(68, 14)
		name.Size = UDim2.new(1, -200, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local text = Ui.text(card, pass.text, 13, Ui.Colors.Dim)
		text.Position = UDim2.fromOffset(68, 36)
		text.Size = UDim2.new(1, -200, 0, 30)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		local buy = Ui.button(
			card,
			if pass.id then `{ROBUX} {pass.robux}` else "Soon",
			if pass.id then Ui.Colors.Lime else Ui.Colors.Track,
			function()
				if pass.id and not player:GetAttribute(pass.attribute) then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end
			end,
			if pass.id then Ui.Colors.Ink else Ui.Colors.Dim,
			6
		)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -14, 0.5, 2)
		buy.Size = UDim2.fromOffset(110, 32)
		passButtons[pass] = buy
	end

	local function refresh()
		for pass, button in passButtons do
			if player:GetAttribute(pass.attribute) then
				Ui.setText(button, "Owned")
				Ui.setColor(button, Ui.Colors.Tab, Ui.Colors.Dim)
			end
		end
	end

	-- Real prices from Roblox, once.
	task.spawn(function()
		for i, button in priceLabels do
			local pack = settings.CoinPacks[i]
			Ui.setText(button, `{ROBUX} {priceOf(pack.Id, Enum.InfoType.Product, pack.Robux)}`)
		end
		for pass, button in passButtons do
			if pass.id and not player:GetAttribute(pass.attribute) then
				Ui.setText(button, `{ROBUX} {priceOf(pass.id, Enum.InfoType.GamePass, pass.robux)}`)
			end
		end
	end)
	for _, name in { "VIP", "DoubleCoins" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	return refresh
end

function ShopTab.build(page: Frame, api: { [string]: any }): () -> ()
	local daily = Ui.frame(page)
	daily.Name = "Daily"
	daily.Position = UDim2.fromOffset(0, 42)
	daily.Size = UDim2.new(1, 0, 1, -42)
	local coins = Ui.frame(page)
	coins.Name = "Coins"
	coins.Position = daily.Position
	coins.Size = daily.Size
	coins.Visible = false
	local refreshDaily = buildDaily(daily, api)
	local refreshCoins = buildCoins(coins)

	local current = "Daily shop"
	local selectTab: (string) -> ()
	local _, select = Ui.tabs(page, { "Daily shop", "Coin shop" }, Ui.Colors.Yellow, function(name)
		current = name
		daily.Visible = name == "Daily shop"
		coins.Visible = name == "Coin shop"
		if name == "Daily shop" then
			refreshDaily()
		else
			refreshCoins()
		end
		selectTab(name)
	end)
	selectTab = select
	selectTab(current)

	return function()
		if current == "Daily shop" then
			refreshDaily()
		else
			refreshCoins()
		end
	end
end

return ShopTab
