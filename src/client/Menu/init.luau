--!strict
-- The player menu, in the Street sprint style (Menu/Ui).
--   Left side: your coins, then a column of slanted buttons (Shop, Locker, Quests, Rewards,
--   Leaders), each with a colored edge and a pink count when something is waiting.
--   Bottom center: your level and a segmented XP bar.
--   The window: one window whose header takes the open page's color, icon and title. The Locker
--   docks to the left instead, over its 3D preview (Menu/LockerTab, client/LockerStage; where
--   everything goes on any screen is Menu/LockerLayout), and the buttons and level bar step
--   aside while it's open.
-- Everything is built in a scaled root frame (Ui.scale): layouts are in virtual pixels for a
-- 1280x720 screen. Pages get their body size (virtual) as the BodyW / BodyH attributes of their
-- page frame (Ui.bodySize) and are refreshed when it changes, so they can switch to a narrow
-- layout.
-- Pages are modules in this folder: build(page, api) -> refresh function, and optionally
-- badge(profile) -> number (the count on the button), info(profile) -> string (rich text on the
-- header's right), opened() / closed(), and docked = true. See PAGES.
-- Reward popups come in through the Reward remote and server-wide news through Announce
-- (Popups). The lobby's Avatar Shop prompt opens the Shop; when today's streak reward is
-- waiting, Rewards opens by itself shortly after joining.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cursor = require(script.Parent.Cursor)
local Icons = require(script.Parent.Icons)
local Profile = require(script.Parent.Profile)
local LeadersTab = require(script.LeadersTab)
local LockerLayout = require(script.LockerLayout)
local LockerTab = require(script.LockerTab)
local Popups = require(script.Popups)
local QuestsTab = require(script.QuestsTab)
local RewardsTab = require(script.RewardsTab)
local ShopTab = require(script.ShopTab)
local Ui = require(script.Ui)

local Menu = {}

type Page = { name: string, title: string?, icon: string, color: Color3, module: any }
local PAGES: { Page } = {
	{ name = "Shop", icon = "shop", color = Ui.Colors.Yellow, module = ShopTab },
	{ name = "Locker", icon = "locker", color = Ui.Colors.Cyan, module = LockerTab },
	{ name = "Quests", icon = "quests", color = Ui.Colors.Pink, module = QuestsTab },
	{ name = "Rewards", icon = "rewards", color = Ui.Colors.Lime, module = RewardsTab },
	{
		name = "Leaders",
		title = "Leaderboards",
		icon = "leaders",
		color = Ui.Colors.Orange,
		module = LeadersTab,
	},
}

local WINDOW_MAX = Vector2.new(820, 560)
local WINDOW_SHARE = Vector2.new(0.92, 0.78) -- of the screen, up to WINDOW_MAX
local BODY_INSET = Vector2.new(32, 78) -- the window's body: its size minus the frame and header

local openPage: ((string?) -> ())? = nil

-- Opens the menu on a page (the lobby's shop prompt, the Rewards greeting). nil closes it.
function Menu.open(name: string?)
	if openPage then
		openPage(name)
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
	local root = Ui.scale(gui)

	-- Left side: coins, then the page buttons.
	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.BackgroundTransparency = 1
	nav.AnchorPoint = Vector2.new(0, 0.5)
	nav.Position = UDim2.new(0, 14, 0.5, 0)
	nav.Size = UDim2.fromOffset(160, 0)
	nav.AutomaticSize = Enum.AutomaticSize.Y
	local column = Instance.new("UIListLayout")
	column.Padding = UDim.new(0, 6)
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.Parent = nav
	nav.Parent = root

	local money = Ui.slab(nav, Ui.Colors.Panel, 8)
	money.Name = "Money"
	money.LayoutOrder = 0
	money.Size = UDim2.fromOffset(150, 34)
	local coin = Ui.coin(money, 20)
	coin.Position = UDim2.fromOffset(16, 7)
	local coinText = Ui.caps(money, "0", 20, Ui.Colors.Yellow)
	coinText.Position = UDim2.fromOffset(44, 0)
	coinText.Size = UDim2.new(1, -52, 1, 0)
	coinText.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(coinText, 11, 20) -- seven-digit totals shrink instead of running out of the pill

	-- Bottom center: the level and XP bar.
	local levelBar = Instance.new("Frame")
	levelBar.Name = "Level"
	levelBar.BackgroundTransparency = 1
	levelBar.AnchorPoint = Vector2.new(0.5, 1)
	levelBar.Position = UDim2.new(0.5, 0, 1, -10)
	levelBar.Size = UDim2.fromOffset(380, 44)
	levelBar.Parent = root
	local levelPlate = Ui.slab(levelBar, Ui.Colors.Panel, 8)
	levelPlate.Position = UDim2.fromOffset(0, 6)
	levelPlate.Size = UDim2.fromOffset(78, 32)
	local levelText = Ui.title(levelPlate, "LV 1", 24, Ui.Colors.Yellow)
	levelText.Size = UDim2.fromScale(1, 1)
	local segments, setXP = Ui.segments(levelBar, 10, Ui.Colors.Cyan, 24, 14)
	segments.Position = UDim2.fromOffset(88, 8)
	local xpText = Ui.caps(levelBar, "0 / 100 XP", 12, Ui.Colors.Text)
	xpText.Position = UDim2.fromOffset(88, 24)
	xpText.Size = UDim2.fromOffset(280, 16)
	xpText.TextXAlignment = Enum.TextXAlignment.Left
	Ui.stroke(xpText, 1.5)

	-- Floating "+coins" text rises from beside the money.
	local floatAnchor = Instance.new("Frame")
	floatAnchor.BackgroundTransparency = 1
	floatAnchor.Position = UDim2.new(1, 12, 0, 2)
	floatAnchor.Size = UDim2.fromOffset(380, 30)
	floatAnchor.Parent = money
	Popups.start(root, floatAnchor)
	local function fitFloat(view: Vector2)
		-- Room from beside the coins to the screen's right edge.
		floatAnchor.Size = UDim2.fromOffset(math.clamp(view.X - 190, 160, 380), 30)
	end
	fitFloat(Ui.viewport())
	Ui.onViewport(fitFloat)

	-- The window.
	local window, body, close, header, title, info = Ui.window(root, "", Ui.Colors.Yellow, "")
	window.Visible = false
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = WINDOW_MAX
	sizeLimit.Parent = window
	local modal = Instance.new("TextButton") -- frees the mouse in first person while open
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Modal = true
	modal.Parent = window

	local pages: { [string]: Frame } = {}
	local refreshers: { [string]: () -> () } = {}
	local byName: { [string]: Page } = {}
	local buttons: { [string]: TextButton } = {}
	local badges: { [string]: TextLabel } = {}
	local current: string? = nil

	-- Tells every page how big its body is (virtual pixels) and refreshes the open one when that
	-- changed, so it can switch between wide and narrow layouts.
	local lastBody = Vector2.new(788, 482)
	local function sizePages(bodySize: Vector2)
		lastBody = bodySize
		local changed = false
		for _, page in pages do
			if
				page:GetAttribute("BodyW") ~= bodySize.X
				or page:GetAttribute("BodyH") ~= bodySize.Y
			then
				changed = true
				page:SetAttribute("BodyW", bodySize.X)
				page:SetAttribute("BodyH", bodySize.Y)
			end
		end
		local refresh = if current then refreshers[current] else nil
		if changed and refresh and window.Visible then
			refresh()
		end
	end

	local dockedNow = false
	local function place(docked: boolean)
		dockedNow = docked
		local view = Ui.viewport()
		local size: Vector2
		if docked then
			-- Sized in virtual pixels from the Locker's layout (side, column or bottom sheet).
			local layout = LockerLayout.compute(view).window
			window.AnchorPoint = Vector2.zero
			window.Position = UDim2.fromOffset(layout.x, layout.y)
			window.Size = UDim2.fromOffset(layout.w, layout.h)
			sizeLimit.MaxSize = Vector2.new(layout.w, layout.h)
			size = Vector2.new(layout.w, layout.h)
		else
			-- Centered a little low, clear of the HUD bar at the top.
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			window.Position = UDim2.new(0.5, 0, 0.5, 28)
			window.Size = UDim2.fromScale(WINDOW_SHARE.X, WINDOW_SHARE.Y)
			sizeLimit.MaxSize = WINDOW_MAX
			size = Vector2.new(
				math.min(WINDOW_MAX.X, view.X * WINDOW_SHARE.X),
				math.min(WINDOW_MAX.Y, view.Y * WINDOW_SHARE.Y)
			)
		end
		nav.Visible = not docked
		levelBar.Visible = not docked
		sizePages(size - BODY_INSET)
	end
	Ui.onViewport(function()
		place(dockedNow)
	end)

	local function paintButtons()
		for name, button in buttons do
			local page = byName[name]
			local open = name == current
			Ui.paint(
				button:FindFirstChild("Fill") :: Frame,
				if open then page.color else Ui.Colors.Panel
			)
			local label = button:FindFirstChild("Label") :: TextLabel
			label.TextColor3 = if open then Ui.Colors.Ink else Ui.Colors.Text
			local pageIcon = button:FindFirstChild("PageIcon")
			if pageIcon then
				if open then
					Icons.paint(pageIcon, Ui.Colors.Ink, Ui.Colors.Text)
				else
					Icons.paint(pageIcon, Ui.Colors.Text, page.color)
				end
			end
		end
	end

	local function refreshInfo()
		local page = current and byName[current]
		local profile = Profile.get()
		info.Text = if page
				and profile
				and page.module.info
			then Ui.upper(page.module.info(profile))
			else ""
	end

	local api = {
		gui = root,
		send = function(remoteName: string, ...: any)
			Remotes.get(remoteName):FireServer(...)
		end,
		open = function(name: string?)
			Menu.open(name)
		end,
	}

	local function show(name: string?)
		local previous = current
		if previous == name then
			return
		end
		if previous then
			local module = byName[previous].module
			if module.closed then
				module.closed()
			end
		end
		current = name
		window.Visible = name ~= nil
		Cursor.hold("Menu", name ~= nil) -- the mouse stays free while a page is open
		for pageName, page in pages do
			page.Visible = pageName == name
		end
		paintButtons()
		if not name then
			place(false)
			return
		end
		local page = byName[name]
		place(page.module.docked == true)
		title.Text = Ui.upper(page.title or page.name)
		Ui.windowIcon(header, page.icon)
		Ui.paint(header, page.color)
		refreshInfo()
		local refresh = refreshers[name]
		if refresh then
			refresh()
		end
		if page.module.opened then
			page.module.opened()
		end
		Ui.popIn(window, 0.22)
	end
	openPage = show
	close.Activated:Connect(function()
		show(nil)
	end)

	for i, page in PAGES do
		byName[page.name] = page
		local frame = Instance.new("Frame")
		frame.Name = page.name
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(1, 1)
		frame.Visible = false
		frame:SetAttribute("BodyW", lastBody.X)
		frame:SetAttribute("BodyH", lastBody.Y)
		frame.Parent = body
		pages[page.name] = frame
		refreshers[page.name] = page.module.build(frame, api)

		local button = Instance.new("TextButton")
		button.Name = page.name
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.Text = ""
		button.LayoutOrder = i
		button.Size = UDim2.fromOffset(150, Ui.hit(38))
		local fill = Ui.slab(button, Ui.Colors.Panel, 8)
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		local edge = Ui.slab(button, page.color, 8)
		edge.Name = "Edge"
		edge.Size = UDim2.new(0, 16, 1, 0)
		edge.ZIndex = 2
		local pageIcon = Ui.icon(button, page.icon, 22, Ui.Colors.Text, page.color)
		pageIcon.Name = "PageIcon"
		pageIcon.AnchorPoint = Vector2.new(0, 0.5)
		pageIcon.Position = UDim2.new(0, 23, 0.5, 0)
		pageIcon.ZIndex = 3
		local label = Ui.caps(button, page.name, 15, Ui.Colors.Text)
		label.Name = "Label"
		label.Position = UDim2.fromOffset(52, 0)
		label.Size = UDim2.new(1, -56, 1, 0)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 3
		badges[page.name] = Ui.badge(button)
		local scale = Instance.new("UIScale")
		scale.Parent = button
		button.MouseEnter:Connect(function()
			if current ~= page.name then
				Ui.paint(fill, Ui.Colors.Tab)
			end
			scale.Scale = 1.03
		end)
		button.MouseLeave:Connect(function()
			paintButtons()
			scale.Scale = 1
		end)
		button.Activated:Connect(function()
			show(if current == page.name then nil else page.name)
		end)
		button.Parent = nav
		buttons[page.name] = button
	end
	paintButtons()

	Profile.onChanged(function(profile)
		for name, badge in badges do
			local module = byName[name].module
			local count = if module.badge then module.badge(profile) else 0
			badge.Text = if count > 0 then tostring(count) else ""
		end
		if current and refreshers[current] then
			refreshers[current]()
		end
		refreshInfo()
	end)

	-- Coins (counting quickly to the new amount) and level.
	local shownCoins = 0
	Profile.onChanged(function(profile)
		if profile.Coins ~= shownCoins then
			local from = shownCoins
			shownCoins = profile.Coins
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
		levelText.Text = `LV {profile.Level}`
		local need = xpNeeded(profile.Level)
		xpText.Text = `{Ui.number(profile.XP)} / {Ui.number(need)} XP`
		setXP(profile.XP / need)
	end)

	Remotes.get("Reward").OnClientEvent:Connect(Popups.show)
	Remotes.get("Announce").OnClientEvent:Connect(Popups.announce)

	-- Today's streak reward waiting: open Rewards once, shortly after joining.
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
