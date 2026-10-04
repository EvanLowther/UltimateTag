--!strict
-- Dev panel, Debug tab: switches for the debug tools (DebugTools): movement readout, fly,
-- teleport key (spawn points are on the Maps tab).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local DebugTools = require(script.Parent.DebugTools)
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
end

return DebugTab
