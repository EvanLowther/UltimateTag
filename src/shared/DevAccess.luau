--!strict
-- Who may use the developer panel: everyone in a Studio playtest, and in live servers only the
-- UserIds in Config.DevPanel.UserIds. The client uses it to decide whether to build the panel;
-- the server checks it on every DevCommand, so the panel can't be faked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DevAccess = {}

function DevAccess.isDeveloper(player: Player): boolean
	local settings = Config.DevPanel
	if not settings.Enabled then
		return false
	end
	return RunService:IsStudio() or table.find(settings.UserIds, player.UserId) ~= nil
end

return DevAccess
