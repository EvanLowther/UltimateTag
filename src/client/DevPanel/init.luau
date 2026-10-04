--!strict
-- The developer panel: a window with Game, Maps, Movement, Debug and Progress tabs, opened and closed with
-- Config.DevPanel.Key (the ` key). Only built for developers (DevAccess: everyone in Studio,
-- listed UserIds in live servers); the server checks every command again (server/DevCommands).
-- The window can be dragged by its title bar, and frees the mouse in first person while open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DevAccess = require(Shared:WaitForChild("DevAccess"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DebugTab = require(script.DebugTab)
local DebugTools = require(script.DebugTools)
local GameTab = require(script.GameTab)
local MapsTab = require(script.MapsTab)
local MovementTab = require(script.MovementTab)
local ProgressTab = require(script.ProgressTab)
local Widgets = require(script.Widgets)

local DevPanel = {}

local WIDTH, HEIGHT = 360, 500
local TITLE_HEIGHT, TAB_HEIGHT = 30, 30
local TABS = { "Game", "Maps", "Movement", "Debug", "Progress" }

local function page(parent: Instance, name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Visible = false
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(0, TITLE_HEIGHT + TAB_HEIGHT + 6)
	frame.Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + TAB_HEIGHT + 6))
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollBarThickness = 6
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = frame
	frame.Parent = parent
	return frame
end

function DevPanel.start()
	local player = Players.LocalPlayer
	if not DevAccess.isDeveloper(player) then
		return
	end
	local remote = Remotes.get("DevCommand")
	local function send(command: string, ...: any)
		remote:FireServer(command, ...)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Visible = false
	window.BackgroundColor3 = Widgets.Colors.Window
	window.BackgroundTransparency = 0.05
	window.Position = UDim2.new(1, -WIDTH - 12, 0.5, -HEIGHT / 2)
	window.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 8)
	windowCorner.Parent = window
	window.Parent = gui

	-- While the window is open, a modal button frees the mouse (first person locks it).
	local modal = Instance.new("TextButton")
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Modal = true
	modal.Parent = window

	-- Title bar (drag to move).
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundColor3 = Widgets.Colors.Bar
	title.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
	title.Text = `  Dev Panel   v{Config.Version}   ({Config.DevPanel.Key.Name} to close)`
	title.TextXAlignment = Enum.TextXAlignment.Left
	Widgets.text(title, 15)
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 8)
	titleCorner.Parent = title
	title.Parent = window

	local dragStart: Vector3? = nil
	local startPosition = window.Position
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = input.Position
			startPosition = window.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			window.Position = startPosition + UDim2.fromOffset(delta.X, delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = nil
		end
	end)

	-- Tabs.
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(8, TITLE_HEIGHT + 4)
	tabBar.Size = UDim2.new(1, -16, 0, TAB_HEIGHT)
	tabBar.Parent = window
	local tabRow = Widgets.row(tabBar, TAB_HEIGHT)

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local refreshMaps: () -> () = function() end
	local function show(name: string)
		for tab, frame in pages do
			frame.Visible = tab == name
			Widgets.select(tabButtons[tab], tab == name)
		end
		if name == "Maps" then
			refreshMaps()
		end
	end
	for _, name in TABS do
		pages[name] = page(window, name)
		tabButtons[name] = Widgets.button(tabRow, name, function()
			show(name)
		end)
	end

	GameTab.build(pages.Game, send)
	refreshMaps = MapsTab.build(pages.Maps, send)
	MovementTab.build(pages.Movement, send)
	DebugTab.build(pages.Debug, gui, send)
	ProgressTab.build(pages.Progress, send)
	DebugTools.start()
	show("Game")

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.DevPanel.Key then
			window.Visible = not window.Visible
			if window.Visible and pages.Maps.Visible then
				refreshMaps()
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	print(`[DevPanel] press {Config.DevPanel.Key.Name} to open the dev panel`)
end

return DevPanel
