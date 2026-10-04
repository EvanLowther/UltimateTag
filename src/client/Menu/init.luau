--!strict
-- The game's menu (for players, unlike the dev panel). On the left side of the screen: your
-- coins, your level with an XP bar, and buttons that open the menu window's tabs (Shop,
-- Inventory, Quests, Rewards). Reward popups come in through the Reward remote (Popups).
-- Tabs are modules in this folder with build(page, api) -> refresh function; see TABS.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profile = require(script.Parent.Profile)
local Popups = require(script.Popups)
local Ui = require(script.Ui)

local Menu = {}

-- name, button color, module (each module has build(page, api) returning a refresh function)
type Tab = { name: string, color: Color3, module: any }
local TABS: { Tab } = {}

local WINDOW_W, WINDOW_H = 620, 440

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

	-- Left side: coins, level, menu buttons.
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, 12, 0.45, 0)
	side.Size = UDim2.fromOffset(220, 0)
	side.AutomaticSize = Enum.AutomaticSize.Y
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = side
	side.Parent = gui

	local coinPill = Ui.frame(side, Ui.Colors.Panel, 20)
	coinPill.Size = UDim2.fromOffset(170, 40)
	coinPill.LayoutOrder = 1
	Ui.stroke(coinPill)
	local coin = Ui.coinIcon(coinPill, 28)
	coin.Position = UDim2.fromOffset(7, 6)
	local coinText = Ui.label(coinPill, "0", 24, Ui.Colors.Coin)
	coinText.Position = UDim2.fromOffset(42, 0)
	coinText.Size = UDim2.new(1, -50, 1, 0)
	coinText.TextXAlignment = Enum.TextXAlignment.Left

	local levelPill = Ui.frame(side, Ui.Colors.Panel, 20)
	levelPill.Size = UDim2.fromOffset(210, 40)
	levelPill.LayoutOrder = 2
	Ui.stroke(levelPill)
	local badge = Ui.frame(levelPill, Ui.Colors.XP, 20)
	badge.Size = UDim2.fromOffset(32, 32)
	badge.Position = UDim2.fromOffset(4, 4)
	local levelText = Ui.label(badge, "1", 20, Ui.Colors.Text, Ui.BigFont)
	levelText.Size = UDim2.fromScale(1, 1)
	Ui.outlined(levelText)
	local bar = Ui.frame(levelPill, Ui.Colors.PanelLight, 8)
	bar.Position = UDim2.fromOffset(44, 12)
	bar.Size = UDim2.new(1, -54, 0, 16)
	local fill = Ui.frame(bar, Ui.Colors.XP, 8)
	fill.Size = UDim2.fromScale(0, 1)
	local xpText = Ui.label(bar, "0 / 100", 13)
	xpText.Size = UDim2.fromScale(1, 1)
	xpText.ZIndex = 2
	Ui.outlined(xpText, 1.5)

	-- Floating "+coins" text appears just under the level bar.
	local floatAnchor = Instance.new("Frame")
	floatAnchor.BackgroundTransparency = 1
	floatAnchor.Size = UDim2.fromOffset(320, 30)
	floatAnchor.LayoutOrder = 3
	floatAnchor.Parent = side
	Popups.start(gui, floatAnchor)

	-- The menu window and its tab buttons (when there are tabs).
	local window = Ui.frame(gui, Ui.Colors.Panel, 18)
	window.Visible = false
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
	Ui.stroke(window, Color3.fromRGB(15, 18, 30), 3)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(WINDOW_W, WINDOW_H)
	sizeLimit.Parent = window
	local title = Ui.label(window, "", 32, Ui.Colors.Text, Ui.BigFont)
	title.Position = UDim2.fromOffset(20, 8)
	title.Size = UDim2.new(1, -80, 0, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Ui.outlined(title, 2)
	local modal = Instance.new("TextButton") -- frees the mouse in first person while open
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Modal = true
	modal.Parent = window

	local pages: { [string]: Frame } = {}
	local refreshers: { [string]: () -> () } = {}
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
			local refresh = refreshers[name]
			if refresh then
				refresh()
			end
			Ui.popIn(window, 0.25)
		end
	end
	openTab = show

	local close = Ui.button(window, "X", Ui.Colors.Bad, function()
		show(nil)
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(40, 40)

	for i, tab in TABS do
		local page = Instance.new("Frame")
		page.Name = tab.name
		page.BackgroundTransparency = 1
		page.Position = UDim2.fromOffset(16, 56)
		page.Size = UDim2.new(1, -32, 1, -72)
		page.Visible = false
		page.Parent = window
		pages[tab.name] = page
		refreshers[tab.name] = tab.module.build(page, api)

		local button = Ui.button(side, tab.name, tab.color, function()
			show(if current == tab.name then nil else tab.name)
		end)
		button.Size = UDim2.fromOffset(130, 42)
		button.LayoutOrder = 10 + i
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
		levelText.Text = tostring(profile.Level)
		local need = xpNeeded(profile.Level)
		xpText.Text = `{Ui.number(profile.XP)} / {Ui.number(need)} XP`
		TweenService:Create(
			fill,
			TweenInfo.new(0.4),
			{ Size = UDim2.fromScale(math.clamp(profile.XP / need, 0, 1), 1) }
		):Play()
	end)

	Remotes.get("Reward").OnClientEvent:Connect(Popups.show)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and current then
			show(nil)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Menu
