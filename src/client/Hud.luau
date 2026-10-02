--!strict
-- Top-of-screen HUD: round status, timer, and a banner showing your role.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(Shared:WaitForChild("GameState"))

local Hud = {}

local function makeLabel(parent: Instance, name: string, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Config.Ui.Font
	label.TextSize = textSize
	label.TextColor3 = Config.Colors.Text
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Hud.start()
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(440, 64)
	panel.BackgroundColor3 = Config.Colors.HudBackground
	panel.BackgroundTransparency = 0.4
	Instance.new("UICorner").Parent = panel
	panel.Parent = gui

	local status = makeLabel(panel, "Status", 24)
	status.Size = UDim2.new(1, -16, 0, 32)
	status.Position = UDim2.fromOffset(8, 4)
	status.TextWrapped = true

	local timer = makeLabel(panel, "Timer", 22)
	timer.Size = UDim2.new(1, 0, 0, 24)
	timer.Position = UDim2.fromOffset(0, 36)

	local banner = makeLabel(gui, "RoleBanner", 32)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 80)
	banner.Size = UDim2.fromOffset(260, 44)
	banner.BackgroundTransparency = 0.2
	Instance.new("UICorner").Parent = banner

	local function refresh()
		local phase = GameState.getPhase()
		status.Text = GameState.getStatus()
		if phase == "Intermission" then
			timer.Text = `Next round in {formatTime(GameState.getTimeLeft())}`
		elseif phase == "Playing" then
			timer.Text = `Time left: {formatTime(GameState.getTimeLeft())}`
		else
			timer.Text = ""
		end

		local role = player:GetAttribute("Role")
		banner.Visible = role ~= nil and phase == "Playing"
		if role == "It" then
			banner.Text = "YOU ARE IT!"
			banner.BackgroundColor3 = Config.Colors.It
		else
			banner.Text = "RUN!"
			banner.BackgroundColor3 = Config.Colors.Runner
		end
	end

	GameState.onChanged(refresh)
	player:GetAttributeChangedSignal("Role"):Connect(refresh)
	refresh()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
