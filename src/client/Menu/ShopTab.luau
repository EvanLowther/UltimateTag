--!strict
-- Menu, Shop page: two tabs.
--   Daily shop: today's offers (shared/ShopRotation: a big deal card and four featured items),
--   a countdown to tomorrow's shop, and the Mystery crate with its odds (bought crates are
--   opened in Rewards). Buying goes through the server (server/Shop). A price you can't pay is
--   greyed out and says how many coins are missing; owned items say so.
--   Coin shop: coin packs and game passes for Robux (Config.Monetization; server/Purchases).
--   Each one shows "Soon" until it has an ID.
-- Two layouts, by the page's width (Ui.bodySize): wide (the deal card beside the four offers,
-- packs in one row) and narrow, under WIDE_FROM (a phone held upright: the deal card above the
-- offers, packs in two columns, the crate's button below its text).
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

local ROBUX = "R$"
local WIDE_FROM = 680 -- pages at least this wide (virtual pixels) get the wide layout
local SCROLL_PAD = 12 -- the scroll list's padding on the right
local DEAL_WIDTH = 230 -- the wide layout's deal card
local DEAL_TALL_NARROW = 232 -- the narrow layout's deal card, plus its buy button
local HOUR = 3600

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
	left.Size = UDim2.new(0.4, -4, 1, 0)
	left.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(left, 11, 14)
	local right = Ui.caps(row, "", 12, Ui.Colors.Dim)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.new(0.6, -4, 1, 0)
	right.TextXAlignment = Enum.TextXAlignment.Right
	Ui.shrinkText(right, 11, 12)
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

local function buildDaily(page: Frame, api: { [string]: any }, owner: Frame): () -> ()
	local scroll = Ui.scroll(page, 10)
	local _, countdown = header(scroll, "Today's drop", 1)
	local cardHeight = ItemCard.SHOP_BODY + ItemCard.buyHeight()

	local offers = Ui.frame(scroll)
	offers.Name = "Offers"
	offers.LayoutOrder = 2
	offers.Size = UDim2.new(1, 0, 0, cardHeight * 2 + 10)
	local dealSlot = Ui.frame(offers)
	dealSlot.Size = UDim2.new(0, DEAL_WIDTH, 1, 0)
	local featured = Ui.frame(offers)
	featured.Position = UDim2.fromOffset(DEAL_WIDTH + 10, 0)
	featured.Size = UDim2.new(1, -(DEAL_WIDTH + 10), 1, 0)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -5, 0, cardHeight)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = featured
	local empty = Ui.caps(offers, "Nothing in the shop today", 14, Ui.Colors.Dim)
	empty.Size = UDim2.fromScale(1, 1)
	empty.Visible = false

	-- The Mystery crate.
	local crate = Ui.panel(scroll, Ui.Colors.Card, 10)
	crate.LayoutOrder = 3
	crate.Size = UDim2.new(1, 0, 0, 116)
	local crateStrip = Ui.frame(crate, Ui.Colors.Yellow)
	crateStrip.Size = UDim2.new(1, -10, 0, 4)
	local box = Ui.icon(crate, "crate", 64, Ui.Colors.Yellow, Ui.Colors.Ink)
	box.Position = UDim2.fromOffset(14, 22)
	local crateName = Ui.caps(crate, "Mystery crate", 16, Ui.Colors.Text)
	crateName.TextXAlignment = Enum.TextXAlignment.Left
	local crateNote = Ui.text(
		crate,
		"Any trail, tag effect, title or victory. Open it in Rewards.",
		13,
		Ui.Colors.Dim
	)
	crateNote.TextXAlignment = Enum.TextXAlignment.Left
	crateNote.TextWrapped = true
	crateNote.TextTruncate = Enum.TextTruncate.AtEnd
	crateNote.TextYAlignment = Enum.TextYAlignment.Top
	local bar = oddsBar(crate)
	local odds = Ui.caps(crate, ShopTab.oddsText(), 11, Ui.Colors.Dim)
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.TextYAlignment = Enum.TextYAlignment.Top
	odds.TextWrapped = true
	odds.TextTruncate = Enum.TextTruncate.AtEnd
	local buyCrate = Ui.button(crate, "", Ui.Colors.Yellow, function()
		api.send("BuyCrate")
	end)
	local crateButtonHeight = Ui.hit(38)
	local cratePrice, cratePriceLabel =
		Ui.coinAmount(buyCrate, Config.Shop.CratePrice, 16, Ui.Colors.Ink)
	cratePrice.AnchorPoint = Vector2.new(0.5, 0.5)
	cratePrice.Position = UDim2.fromScale(0.5, 0.5)
	for _, child in cratePrice:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 3
		end
	end
	local owned = Ui.caps(crate, "", 11, Ui.Colors.Lime)
	owned.TextWrapped = true
	owned.TextTruncate = Enum.TextTruncate.AtEnd

	-- Lays the page out for its width. `featuredCount`: how many full-price cards; `hasDeal`.
	local function arrange(featuredCount: number, hasDeal: boolean)
		local width = Ui.bodySize(owner).X - SCROLL_PAD
		local wide = width + SCROLL_PAD >= WIDE_FROM
		local rows = math.max(1, math.ceil(featuredCount / 2))
		local featuredHeight = rows * cardHeight + (rows - 1) * 10
		local dealWidth = if hasDeal then DEAL_WIDTH + 10 else 0
		if wide then
			local height = math.max(featuredHeight, if hasDeal then cardHeight * 2 + 10 else 0)
			offers.Size = UDim2.new(1, 0, 0, math.max(height, 60))
			dealSlot.Position = UDim2.fromOffset(0, 0)
			dealSlot.Size = UDim2.new(0, DEAL_WIDTH, 1, 0)
			featured.Position = UDim2.fromOffset(dealWidth, 0)
			featured.Size = UDim2.new(1, -dealWidth, 1, 0)
		else
			local dealHeight = if hasDeal then DEAL_TALL_NARROW + ItemCard.buyHeight() else 0
			local gap = if hasDeal and featuredCount > 0 then 10 else 0
			offers.Size = UDim2.new(1, 0, 0, math.max(dealHeight + gap + featuredHeight, 60))
			dealSlot.Position = UDim2.fromOffset(0, 0)
			dealSlot.Size = UDim2.new(1, 0, 0, dealHeight)
			featured.Position = UDim2.fromOffset(0, dealHeight + gap)
			featured.Size = UDim2.new(1, 0, 0, featuredHeight)
		end
		-- The crate: text beside the button (wide) or the button under the text (narrow).
		if wide then
			-- Text on the left, the button on the right with what you have / what's missing
			-- under it (two lines of its own, so a long line can't run into the odds).
			crate.Size = UDim2.new(1, 0, 0, math.max(116, crateButtonHeight + 76))
			crateName.Position = UDim2.fromOffset(90, 12)
			crateName.Size = UDim2.new(1, -330, 0, 22)
			crateNote.Position = UDim2.fromOffset(90, 36)
			crateNote.Size = UDim2.new(1, -330, 0, 32)
			bar.Position = UDim2.fromOffset(90, 74)
			bar.Size = UDim2.new(1, -340, 0, 8)
			odds.Position = UDim2.fromOffset(90, 86)
			odds.Size = UDim2.new(1, -330, 0, 28)
			buyCrate.AnchorPoint = Vector2.new(1, 0)
			buyCrate.Position = UDim2.new(1, -16, 0, 16)
			buyCrate.Size = UDim2.fromOffset(130, crateButtonHeight)
			owned.AnchorPoint = Vector2.new(1, 0)
			owned.Position = UDim2.new(1, -16, 0, 16 + crateButtonHeight + 6)
			owned.Size = UDim2.fromOffset(190, 30)
			owned.TextXAlignment = Enum.TextXAlignment.Center
			owned.TextYAlignment = Enum.TextYAlignment.Top
		else
			crate.Size = UDim2.new(1, 0, 0, 184 + crateButtonHeight)
			crateName.Position = UDim2.fromOffset(90, 12)
			crateName.Size = UDim2.new(1, -106, 0, 22)
			crateNote.Position = UDim2.fromOffset(90, 36)
			crateNote.Size = UDim2.new(1, -106, 0, 48)
			bar.Position = UDim2.fromOffset(14, 96)
			bar.Size = UDim2.new(1, -28, 0, 8)
			odds.Position = UDim2.fromOffset(14, 110)
			odds.Size = UDim2.new(1, -28, 0, 44)
			buyCrate.AnchorPoint = Vector2.new(0, 1)
			buyCrate.Position = UDim2.new(0, 14, 1, -12)
			buyCrate.Size = UDim2.new(1, -28, 0, crateButtonHeight)
			owned.AnchorPoint = Vector2.new(0, 1)
			owned.Position = UDim2.new(0, 14, 1, -(crateButtonHeight + 18))
			owned.Size = UDim2.new(1, -28, 0, 18)
			owned.TextXAlignment = Enum.TextXAlignment.Left
			owned.TextYAlignment = Enum.TextYAlignment.Center
		end
	end

	local function tick()
		local left = DayClock.secondsToNextDay()
		countdown.Text = Ui.upper(`New items in {DayClock.format(left)}`)
		-- Under an hour left: the text turns hot, so the last chance is noticed.
		countdown.TextColor3 = if left < HOUR then Ui.Colors.Pink else Ui.Colors.Dim
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
		cratePriceLabel.TextColor3 = if canBuyCrate then Ui.Colors.Ink else Ui.Colors.Dim
		local missing = Config.Shop.CratePrice - profile.Coins
		local haveText = if profile.Crates > 0 then `You have {profile.Crates}` else ""
		local needText = if canBuyCrate
			then ""
			else `<font color="#{Ui.Colors.Pink:ToHex()}">Need {Ui.number(missing)} more</font>`
		owned.Text = Ui.upper(
			if haveText ~= "" and needText ~= ""
				then `{haveText}  ·  {needText}`
				else haveText .. needText
		)

		shownDay = DayClock.day()
		Ui.clear(dealSlot)
		Ui.clear(featured)
		local order = 0
		local hasDeal = false
		local list = ShopRotation.today()
		for _, offer in list do
			local item = Catalog.get(offer.id)
			if not item then
				continue
			end
			if offer.deal then
				hasDeal = true
			else
				order += 1
			end
		end
		arrange(order, hasDeal)
		empty.Visible = order == 0 and not hasDeal
		order = 0
		for _, offer in list do
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
					true,
					profile.Coins
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
					buy,
					nil,
					profile.Coins
				)
				card.LayoutOrder = order
			end
		end
	end
	arrange(Config.Shop.Featured, true)

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

local function buildCoins(page: Frame, owner: Frame): () -> ()
	local settings = Config.Monetization
	local player = Players.LocalPlayer
	local scroll = Ui.scroll(page, 10)
	header(scroll, "Coin packs", 1)
	local packHeight = 176 + Ui.hit(30)

	local packs = Ui.frame(scroll)
	packs.LayoutOrder = 2
	packs.Size = UDim2.new(1, 0, 0, packHeight)
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
		strip.Size = UDim2.new(1, -10, 0, if pack.Tag then 22 else 4)
		if pack.Tag then
			local tag = Ui.caps(
				strip,
				pack.Tag,
				11,
				if pack.Tag == "Best value" then Ui.Colors.Ink else Ui.Colors.Text
			)
			tag.Size = UDim2.fromScale(1, 1)
			Ui.pad(tag, 12, 0)
		end
		local well = Ui.frame(card, Ui.Colors.Well)
		well.Position = UDim2.fromOffset(8, 28)
		well.Size = UDim2.new(1, -16, 0, 60)
		Ui.centerIcon(well, pack.Icon or "coin", 50, Ui.Colors.Cyan, Ui.Colors.Text)
		local amount = Ui.title(card, Ui.number(pack.Coins), 28, Ui.Colors.Yellow)
		amount.Position = UDim2.fromOffset(0, 94)
		amount.Size = UDim2.new(1, 0, 0, 34)
		Ui.pad(amount, 12, 0)
		Ui.shrinkText(amount, 16, 28)
		local bonus = Ui.caps(
			card,
			if (pack.Bonus or 0) > 0 then `+{pack.Bonus}% bonus` else "",
			11,
			Ui.Colors.Lime
		)
		bonus.Position = UDim2.fromOffset(0, 128)
		bonus.Size = UDim2.new(1, 0, 0, 18)
		Ui.pad(bonus, 12, 0)
		Ui.shrinkText(bonus, 11, 11)
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
		buy.Size = UDim2.new(1, -24, 0, Ui.hit(30))
		if pack.Id then
			priceLabels[i] = buy
		end
	end

	header(scroll, "Game passes", 3)
	local passHeight = 88
	local passes = Ui.frame(scroll)
	passes.LayoutOrder = 4
	passes.Size = UDim2.new(1, 0, 0, passHeight)
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
		icon.Position = UDim2.fromOffset(14, 22)
		local name = Ui.caps(card, pass.name, 16, Ui.Colors.Text)
		name.Position = UDim2.fromOffset(68, 14)
		name.Size = UDim2.new(1, -184, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Left
		Ui.shrinkText(name, 11, 16)
		local text = Ui.text(card, pass.text, 13, Ui.Colors.Dim)
		text.Position = UDim2.fromOffset(68, 36)
		text.Size = UDim2.new(1, -184, 0, 44)
		text.TextTruncate = Enum.TextTruncate.AtEnd
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
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
		buy.Size = UDim2.fromOffset(110, Ui.hit(32))
		passButtons[pass] = buy
	end

	-- Packs in one row (wide) or two columns (narrow); passes side by side or one under the other.
	local function arrange()
		local wide = Ui.bodySize(owner).X >= WIDE_FROM
		local count = #settings.CoinPacks
		if wide then
			grid.CellSize = UDim2.new(1 / count, -8, 1, 0)
			packs.Size = UDim2.new(1, 0, 0, packHeight)
			passGrid.CellSize = UDim2.new(0.5, -5, 1, 0)
			passes.Size = UDim2.new(1, 0, 0, passHeight)
		else
			local rows = math.ceil(count / 2)
			grid.CellSize = UDim2.new(0.5, -5, 0, packHeight)
			grid.CellPadding = UDim2.fromOffset(10, 10)
			packs.Size = UDim2.new(1, 0, 0, rows * packHeight + (rows - 1) * 10)
			passGrid.CellSize = UDim2.new(1, 0, 0, passHeight)
			passGrid.CellPadding = UDim2.fromOffset(0, 10)
			passes.Size = UDim2.new(1, 0, 0, #passList * passHeight + (#passList - 1) * 10)
		end
	end
	arrange()

	local function refresh()
		arrange()
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
	local top = Ui.hit(30) + 12 -- under the tabs
	local daily = Ui.frame(page)
	daily.Name = "Daily"
	daily.Position = UDim2.fromOffset(0, top)
	daily.Size = UDim2.new(1, 0, 1, -top)
	local coins = Ui.frame(page)
	coins.Name = "Coins"
	coins.Position = daily.Position
	coins.Size = daily.Size
	coins.Visible = false
	local refreshDaily = buildDaily(daily, api, page)
	local refreshCoins = buildCoins(coins, page)

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
