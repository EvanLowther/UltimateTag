--!strict
-- Top-of-screen HUD:
--   Panel:  the status line, and under it the timer, round and players left.
--   Banner: YOU ARE IT! / RUN! during a round, ELIMINATED once you're out, YOU WIN! or
--           "<name> wins!" at the end.
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

-- The second line of the panel: what the timer means in this phase, plus round info.
local function infoLine(): string
	local phase = GameState.getPhase()
	local time = formatTime(GameState.getTimeLeft())
	local round = GameState.getRound()
	local left = `{GameState.getAliveCount()} left`
	if phase == "Countdown" then
		return `Starting in {time}`
	elseif phase == "Intro" then
		return `Round {round} starts in {time}  ·  {left}`
	elseif phase == "Playing" then
		return `Round {round}  ·  {time}  ·  {left}`
	elseif phase == "Results" then
		return `Round {round} over  ·  {left}`
	end
	return ""
end

function Hud.start()
	local player = Players.LocalPlayer
	local colors = Config.Colors

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(480, 62)
	panel.BackgroundColor3 = colors.HudBackground
	panel.BackgroundTransparency = 0.4
	Instance.new("UICorner").Parent = panel
	panel.Parent = gui

	local status = makeLabel(panel, "Status", 22)
	status.Size = UDim2.new(1, -16, 0, 30)
	status.Position = UDim2.fromOffset(8, 2)
	status.TextWrapped = true

	local info = makeLabel(panel, "Info", 20)
	info.Size = UDim2.new(1, -16, 0, 24)
	info.Position = UDim2.fromOffset(8, 34)
	info.TextColor3 = colors.Text

	local banner = makeLabel(gui, "Banner", 32)
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 78)
	banner.Size = UDim2.fromOffset(300, 44)
	banner.BackgroundTransparency = 0.2
	Instance.new("UICorner").Parent = banner

	local function showBanner(text: string, color: Color3)
		banner.Visible = true
		banner.Text = text
		banner.BackgroundColor3 = color
	end

	local function refresh()
		status.Text = GameState.getStatus()
		info.Text = infoLine()
		info.Visible = info.Text ~= ""
		panel.Size = UDim2.fromOffset(480, if info.Visible then 62 else 36)

		local phase = GameState.getPhase()
		local role = player:GetAttribute("Role")
		local winner = ReplicatedStorage:GetAttribute("Winner")
		local eliminated = player:GetAttribute("InGame") == true
			and player:GetAttribute("Alive") == false
		if phase == "Victory" and winner then
			if winner == player.Name then
				showBanner("YOU WIN!", colors.Winner)
			else
				showBanner(`{winner} wins!`, colors.HudBackground)
			end
		elseif eliminated then
			showBanner("ELIMINATED", colors.Eliminated)
		elseif role == "It" then
			showBanner("YOU ARE IT!", colors.It)
		elseif role == "Runner" then
			showBanner("RUN!", colors.Runner)
		else
			banner.Visible = false
		end
	end

	GameState.onChanged(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("Winner"):Connect(refresh)
	for _, name in { "Role", "InGame", "Alive" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
