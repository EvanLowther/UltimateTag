--!strict
-- Dev panel, Debug tab: switches for the debug tools (DebugTools): movement readout, fly,
-- teleport key (spawn points are on the Maps tab), and the UI auditor (UiAudit).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DebugTools = require(script.Parent.DebugTools)
local UiAudit = require(script.Parent.UiAudit)
local Widgets = require(script.Parent.Widgets)

local DebugTab = {}

function DebugTab.build(page: Instance, gui: ScreenGui, send: (string, ...any) -> ())
	Widgets.section(page, "Tools")
	Widgets.toggle(page, "Movement readout", false, function(on)
		DebugTools.setReadout(on, gui)
	end)
	local setFly = Widgets.toggle(page, "Fly + noclip", false, DebugTools.setFly)
	DebugTools.onFlyEnded(function()
		setFly(false)
	end)
	Widgets.label(page, "Fly: WASD, E up, Q down, hold Shift to go faster.")
	Widgets.toggle(
		page,
		`Teleport key ({Config.DevPanel.TeleportKey.Name})`,
		false,
		DebugTools.setTeleport
	)
	Widgets.label(page, "Press the key to jump to where the mouse points.")
	Widgets.button(page, "Respawn", function()
		send("Respawn")
	end)

	Widgets.section(page, "UI audit")
	Widgets.label(
		page,
		"Checks every visible text for: not fitting, cut off, too close to its box edge, too small, overlapping, off screen. Results go to the Output window (one line per problem, then SUMMARY). Resize the window and run it again."
	)
	Widgets.button(page, "Scan the UI now", UiAudit.scan)
	Widgets.button(page, "Open every window with worst-case content, then scan", UiAudit.sweep)
	Widgets.label(
		page,
		"The second button opens the Shop, Locker, Quests, Rewards and Leaders (every tab, with a broke and a rich fake profile), then popups, banner, toast, spectate bar, results card and win screen with 20-letter names and 7-digit numbers. Takes about a minute; don't click meanwhile."
	)
	Widgets.toggle(page, "Outline problems in red", false, UiAudit.setOutline)
	Widgets.toggle(
		page,
		"Touch text rule (14 px)",
		UiAudit.touchRuleDefault(),
		UiAudit.setTouchRule
	)
	Widgets.button(page, "Clear outlines", UiAudit.clearOutlines)
end

return DebugTab
