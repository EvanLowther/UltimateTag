--!strict
-- The game's menu (for players, unlike the dev panel), in the game's chunky style (Menu/Ui).
-- Left side: your coins in a green pill above a grid of icon buttons opening the menu window's
-- tabs (Shop, Inventory, Quests, Rewards). Bottom center: your level with an XP bar.
-- Reward popups come in through the Reward remote (Popups).
-- Tabs are modules in this folder with build(page, api) -> refresh function, and optionally
-- badge(profile) -> boolean (a red "!" on the button: something to claim); see TABS.
-- When today's login streak reward is waiting, the Rewards tab opens by itself on joining.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profile = require(script.Parent.Profile)
local InventoryTab = require(script.InventoryTab)
local Popups = require(script.Popups)
local QuestsTab = require(script.QuestsTab)
local RewardsTab = require(script.RewardsTab)
local ShopTab = require(script.ShopTab)
local Ui = require(script.Ui)

local Menu = {}

-- name, icon, color (button and window header), module (build(page, api) -> refresh function)
type Tab = { name: string, icon: string, color: Color3, module: any }
local TABS: { Tab } = {
	{ name = "Shop", icon = "🛒", color = Ui.Colors.Red, module = ShopTab },
	{ name = "Inventory", icon = "🎒", color = Ui.Colors.Purple, module = InventoryTab },
	{ name = "Quests", icon = "📜", color = Ui.Colors.Blue, module = QuestsTab },
	{ name = "Rewards", icon = "🎁", color = Ui.Colors.Orange, module = RewardsTab },
}

local WINDOW_W, WINDOW_H = 640, 460

local openTab: ((string?) -> ())? = nil

-- Opens the menu window on a tab (used by the lobby shop prompt). nil closes it.
function Menu.open(name: string?)
	if openTab then
		openTab(name)
	end
end

local function xpNeeded(level: number): number
	local settings = Config.Progression
	return settings.LevelBase + settings.LevelStep * (level - 1)
end

function Menu.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Left side: your coins in a green pill, and under it a two-column grid of icon buttons.
	local leftColumn = Instance.new("Frame")
	leftColumn.BackgroundTransparency = 1
	leftColumn.AnchorPoint = Vector2.new(0, 0.5)
	leftColumn.Position = UDim2.new(0, 14, 0.45, 0)
	leftColumn.Size = UDim2.fromOffset(150, 0)
	leftColumn.AutomaticSize = Enum.AutomaticSize.Y
	local column = Instance.new("UIListLayout")
	column.Padding = UDim.new(0, 10)
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.Parent = leftColumn
	leftColumn.Parent = gui

	local money = Ui.card(leftColumn, Ui.Colors.Green, 16)
	money.Size = UDim2.fromOffset(146, 34)
	money.LayoutOrder = 1
	local coin = Ui.coinIcon(money, 24)
	coin.Position = UDim2.fromOffset(6, 5)
	local coinText = Ui.text(money, "0", 22)
	coinText.Position = UDim2.fromOffset(34, 0)
	coinText.Size = UDim2.new(1, -40, 1, 0)

	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Size = UDim2.fromOffset(150, 0)
	side.AutomaticSize = Enum.AutomaticSize.Y
	side.LayoutOrder = 2
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(68, 68)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = side
	side.Parent = leftColumn

	-- Bottom center: the level bar.
	local bottom = Instance.new("Frame")
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -8)
	bottom.Size = UDim2.fromOffset(460, 44)
	bottom.Parent = gui

	local levelText = Ui.text(bottom, "Lvl. 1", 20)
	levelText.AnchorPoint = Vector2.new(0, 1)
	levelText.Position = UDim2.new(0, 4, 1, -20)
	levelText.Size = UDim2.fromOffset(120, 22)
	levelText.TextXAlignment = Enum.TextXAlignment.Left
	local xpText = Ui.text(bottom, "0/100", 18)
	xpText.AnchorPoint = Vector2.new(1, 1)
	xpText.Position = UDim2.new(1, -4, 1, -20)
	xpText.Size = UDim2.fromOffset(140, 22)
	xpText.TextXAlignment = Enum.TextXAlignment.Right
	local bar, setXP = Ui.bar(bottom, Ui.Colors.XP)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -2)
	bar.Size = UDim2.new(1, 0, 0, 16)

	-- Floating "+coins" text rises from beside the money pill.
	local floatAnchor = Instance.new("Frame")
	floatAnchor.BackgroundTransparency = 1
	floatAnchor.Position = UDim2.new(1, 12, 0, 2)
	floatAnchor.Size = UDim2.fromOffset(380, 30)
	floatAnchor.Parent = money
	Popups.start(gui, floatAnchor)

	-- The menu window: one window whose header takes the open tab's name and color.
	local window, body, close, title = Ui.window(gui, "", Ui.Colors.Header)
	window.Visible = false
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.48)
	window.Size = UDim2.fromScale(0.9, 0.78)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(WINDOW_W, WINDOW_H)
	sizeLimit.Parent = window
	local header = window:FindFirstChild("Header") :: Frame
	local modal = Instance.new("TextButton") -- frees the mouse in first person while open
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Modal = true
	modal.Parent = window

	local pages: { [string]: Frame } = {}
	local refreshers: { [string]: () -> () } = {}
	local colors: { [string]: Color3 } = {}
	local current: string? = nil

	local api = {
		send = function(remoteName: string, ...: any)
			Remotes.get(remoteName):FireServer(...)
		end,
	}

	local function show(name: string?)
		current = name
		window.Visible = name ~= nil
		for tab, page in pages do
			page.Visible = tab == name
		end
		if name then
			title.Text = name:upper()
			local color = colors[name] or Ui.Colors.Header
			header.BackgroundColor3 = color
			for _, child in header:GetChildren() do
				if child:IsA("Frame") then
					child.BackgroundColor3 = color
				end
			end
			local refresh = refreshers[name]
			if refresh then
				refresh()
			end
			Ui.popIn(window, 0.25)
		end
	end
	openTab = show
	close.Activated:Connect(function()
		show(nil)
	end)

	for i, tab in TABS do
		local page = Instance.new("Frame")
		page.Name = tab.name
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = false
		page.Parent = body
		pages[tab.name] = page
		colors[tab.name] = tab.color
		refreshers[tab.name] = tab.module.build(page, api)

		local button = Ui.iconButton(side, tab.icon, tab.name, tab.color, function()
			show(if current == tab.name then nil else tab.name)
		end)
		button.LayoutOrder = i
		if tab.module.badge then
			local dot = Ui.frame(button, Ui.Colors.Bad, 12)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(1, -4, 0, 4)
			dot.Size = UDim2.fromOffset(24, 24)
			dot.ZIndex = 3
			dot.Visible = false
			Ui.outline(dot, 2.5)
			local mark = Ui.text(dot, "!", 18)
			mark.Size = UDim2.fromScale(1, 1)
			mark.ZIndex = 3
			Profile.onChanged(function(profile)
				dot.Visible = tab.module.badge(profile)
			end)
		end
	end
	Profile.onChanged(function()
		if current and refreshers[current] then
			refreshers[current]()
		end
	end)

	-- Coins and level from the profile.
	local shownCoins = 0
	Profile.onChanged(function(profile)
		if profile.Coins ~= shownCoins then
			local from = shownCoins
			shownCoins = profile.Coins
			-- Count up (or down) quickly.
			task.spawn(function()
				local steps = 12
				for i = 1, steps do
					if shownCoins ~= profile.Coins then
						return
					end
					coinText.Text = Ui.number(from + (profile.Coins - from) * i / steps)
					task.wait(0.03)
				end
			end)
		end
		levelText.Text = `Lvl. {profile.Level}`
		local need = xpNeeded(profile.Level)
		xpText.Text = `{Ui.number(profile.XP)}/{Ui.number(need)}`
		setXP(profile.XP / need)
	end)

	Remotes.get("Reward").OnClientEvent:Connect(Popups.show)

	-- Today's streak reward waiting: open the Rewards tab once, shortly after joining.
	local greeted = false
	Profile.onChanged(function(profile)
		if not greeted then
			greeted = true
			if RewardsTab.canClaim(profile) then
				task.delay(2, function()
					if not current then
						show("Rewards")
					end
				end)
			end
		end
	end)

	-- The lobby's Avatar Shop prompt opens the Shop.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if CollectionService:HasTag(prompt, "AvatarShopPrompt") then
			show("Shop")
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and current then
			show(nil)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Menu
