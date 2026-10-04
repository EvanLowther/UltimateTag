--!strict
-- Menu, Shop tab: today's offers (shared/ShopRotation: a few featured cosmetics and one deal),
-- a countdown to tomorrow's shop, and the mystery crate with its odds. Buying and opening go
-- through the server (server/Shop); results pop up through client/Menu/Popups.
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
	local header = Ui.label(page, "TODAY'S SHOP", 22, Ui.Colors.Coin, Ui.BigFont)
	header.Size = UDim2.new(0.5, 0, 0, 28)
	header.TextXAlignment = Enum.TextXAlignment.Left
	local countdown = Ui.label(page, "", 16, Ui.Colors.Dim)
	countdown.AnchorPoint = Vector2.new(1, 0)
	countdown.Position = UDim2.fromScale(1, 0)
	countdown.Size = UDim2.new(0.5, 0, 0, 28)
	countdown.TextXAlignment = Enum.TextXAlignment.Right

	local offers = Instance.new("ScrollingFrame")
	offers.BackgroundTransparency = 1
	offers.BorderSizePixel = 0
	offers.Position = UDim2.fromOffset(0, 32)
	offers.Size = UDim2.new(1, 0, 0, ItemCard.Height + 16)
	offers.CanvasSize = UDim2.new()
	offers.AutomaticCanvasSize = Enum.AutomaticSize.X
	offers.ScrollingDirection = Enum.ScrollingDirection.X
	offers.ScrollBarThickness = 5
	offers.Parent = page
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 10)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = offers
	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingTop = UDim.new(0, 4)
	rowPad.PaddingLeft = UDim.new(0, 4)
	rowPad.Parent = offers

	-- The crate panel.
	local crate = Ui.frame(page, Ui.Colors.PanelLight, 14)
	crate.Position = UDim2.fromOffset(0, ItemCard.Height + 56)
	crate.Size = UDim2.new(1, 0, 1, -(ItemCard.Height + 56))
	Ui.stroke(crate, Ui.Colors.Accent, 2)
	local icon = Ui.label(crate, "📦", 64)
	icon.Position = UDim2.fromOffset(10, 0)
	icon.Size = UDim2.new(0, 90, 1, 0)
	local crateTitle = Ui.label(crate, "MYSTERY CRATE", 22, Ui.Colors.Text, Ui.BigFont)
	crateTitle.Position = UDim2.fromOffset(104, 8)
	crateTitle.Size = UDim2.fromOffset(240, 26)
	crateTitle.TextXAlignment = Enum.TextXAlignment.Left
	local odds = {}
	for _, name in { "Common", "Rare", "Epic", "Legendary" } do
		local rarity = Catalog.Rarities[name]
		table.insert(odds, `<font color="#{rarity.color:ToHex()}">{name} {rarity.weight}%</font>`)
	end
	local oddsLabel = Ui.label(crate, table.concat(odds, "   "), 15)
	oddsLabel.Position = UDim2.fromOffset(104, 36)
	oddsLabel.Size = UDim2.new(1, -114, 0, 20)
	oddsLabel.TextXAlignment = Enum.TextXAlignment.Left
	local dupLabel = Ui.label(
		crate,
		`Duplicates pay back {math.floor(Config.Shop.DuplicateRefund * 100)}% in coins`,
		13,
		Ui.Colors.Dim
	)
	dupLabel.Position = UDim2.fromOffset(104, 56)
	dupLabel.Size = UDim2.new(1, -114, 0, 18)
	dupLabel.TextXAlignment = Enum.TextXAlignment.Left
	local open = Ui.button(crate, "", Ui.Colors.Accent, function()
		api.send("OpenCrate")
	end)
	open.Position = UDim2.fromOffset(104, 80)
	open.Size = UDim2.fromOffset(220, 40)

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
		if profile.Crates > 0 then
			open.Text = `Open free crate ({profile.Crates})`
			open.BackgroundColor3 = Ui.Colors.Good
		else
			open.Text = `Open for {Ui.number(Config.Shop.CratePrice)} coins`
			open.BackgroundColor3 = if profile.Coins >= Config.Shop.CratePrice
				then Ui.Colors.Accent
				else Ui.Colors.PanelLight
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
				local badge = Ui.frame(card, Ui.Colors.Bad, 8)
				badge.Size = UDim2.fromOffset(56, 22)
				badge.Position = UDim2.fromOffset(-4, -6)
				badge.ZIndex = 5
				local text = Ui.label(badge, `-{math.floor(Config.Shop.DealDiscount * 100)}%`, 15)
				text.Size = UDim2.fromScale(1, 1)
				text.ZIndex = 5
			end
			local owned = profile.Owned[offer.id] == true
			local affordable = profile.Coins >= offer.price
			local buy = Ui.button(
				bottom,
				if owned then "Owned" else Ui.number(offer.price),
				if owned
					then Ui.Colors.Good
					elseif affordable then Ui.Colors.Coin
					else Ui.Colors.PanelLight,
				function()
					if not owned then
						api.send("ShopBuy", offer.id)
					end
				end
			)
			buy.Size = UDim2.new(1, 0, 0, 36)
			buy.TextColor3 = if owned or not affordable
				then Ui.Colors.Text
				else Color3.fromRGB(70, 45, 10)
			if not owned then
				local coin = Ui.coinIcon(buy, 20)
				coin.Position = UDim2.fromOffset(8, 8)
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
