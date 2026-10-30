--!strict
-- Dev panel, Game tab: what the server is doing (mode, phase, timer, round, players left) and
-- controls for it: switch mode, start now, skip the timer, set the time left and round length,
-- pick your own role, freeze, respawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(Shared:WaitForChild("GameState"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local WinScreen = require(script.Parent.Parent.WinScreen)
local Widgets = require(script.Parent.Widgets)

local GameTab = {}

function GameTab.build(page: Instance, send: (string, ...any) -> ())
	local player = Players.LocalPlayer

	Widgets.section(page, "Status")
	local status = Widgets.label(page, "")

	Widgets.section(page, "Mode")
	local modes = Widgets.row(page)
	local modeButtons = {
		Elimination = Widgets.button(modes, "Elimination", function()
			send("SetMode", "Elimination")
		end),
		Sandbox = Widgets.button(modes, "Sandbox", function()
			send("SetMode", "Sandbox")
		end),
	}
	Widgets.label(page, "Sandbox: free play on TestGround. Elimination: lobby and rounds.")

	Widgets.section(page, "Flow")
	local flow = Widgets.row(page)
	Widgets.button(flow, "Start game now", function()
		send("StartNow")
	end)
	Widgets.button(flow, "Skip timer", function()
		send("Skip")
	end)

	Widgets.label(page, "Time left on the running timer (s), then Enter")
	Widgets.numberBox(page, 10, function(seconds)
		send("SetTimeLeft", seconds)
	end)
	Widgets.label(
		page,
		"Round length (s) for every round, from the next round (normally by players left)"
	)
	Widgets.numberBox(page, 120, function(seconds)
		send("SetRoundTime", seconds)
	end)

	Widgets.section(page, "Win screen")
	Widgets.label(page, "Shows the win screen to you now. Click anywhere to close it.")
	local victories: { Catalog.Item } = {}
	for _, item in Catalog.Items do
		if item.kind == "Victory" and item.id ~= "victory_none" then
			table.insert(victories, item)
		end
	end
	local picked = 0 -- 0: your equipped Victory, otherwise an index into `victories`
	local shows = Widgets.row(page)
	for _, size in { 3, 2, 1 } do
		Widgets.button(shows, `Show ({size})`, function()
			WinScreen.preview(size, if picked == 0 then nil else victories[picked].id)
		end)
	end
	local victoryButton: TextButton
	victoryButton = Widgets.button(page, "Victory: your equipped", function()
		picked = (picked + 1) % (#victories + 1)
		victoryButton.Text = if picked == 0
			then "Victory: your equipped"
			else `Victory: {victories[picked].name}`
	end)

	Widgets.section(page, "Me")
	local roles = Widgets.row(page)
	local roleButtons = {
		It = Widgets.button(roles, "It", function()
			send("SetRole", "It")
		end),
		Runner = Widgets.button(roles, "Runner", function()
			send("SetRole", "Runner")
		end),
		None = Widgets.button(roles, "No role", function()
			send("SetRole", "None")
		end),
	}
	local freeze = Widgets.row(page)
	local freezeBox = Widgets.numberBox(freeze, 5, function(seconds)
		send("Freeze", seconds)
	end)
	freezeBox.PlaceholderText = "seconds"
	Widgets.button(freeze, "Freeze", function()
		send("Freeze", tonumber(freezeBox.Text) or 5)
	end)
	Widgets.button(freeze, "Unfreeze", function()
		send("Unfreeze")
	end)
	Widgets.button(page, "Respawn", function()
		send("Respawn")
	end)

	local function refresh()
		local mode = GameState.getMode()
		for name, button in modeButtons do
			Widgets.select(button, name == mode)
		end
		local role = player:GetAttribute("Role") or "None"
		for name, button in roleButtons do
			Widgets.select(button, name == role, Config.Colors.It)
		end
		status.Text = table.concat({
			`Mode <b>{mode}</b>   Phase <b>{GameState.getPhase()}</b>`,
			`Time left <b>{GameState.getTimeLeft()}</b>   Round <b>{GameState.getRound()}</b>   Alive <b>{GameState.getAliveCount()}</b>`,
			GameState.getStatus(),
		}, "\n")
	end
	GameState.onChanged(refresh)
	player:GetAttributeChangedSignal("Role"):Connect(refresh)
	refresh()
end

return GameTab
