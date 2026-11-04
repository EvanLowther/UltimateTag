--!strict
-- The player's sound settings (the menu's Settings page, client/Sounds): the SaveSettings remote
-- ({ Music, Sfx, Muted }) checked and kept in the profile's Settings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local Settings = {}

local function level(value: any, default: number): number
	local n = tonumber(value)
	if not n or n ~= n then
		return default
	end
	return math.clamp(math.floor(n * 100 + 0.5) / 100, 0, 1)
end

function Settings.start()
	local defaults = Config.Sounds.Defaults
	Remotes.get("SaveSettings").OnServerEvent:Connect(function(player, saved)
		if type(saved) ~= "table" then
			return
		end
		PlayerData.update(player, function(profile)
			profile.Settings = {
				Music = level(saved.Music, defaults.Music),
				Sfx = level(saved.Sfx, defaults.Sfx),
				Muted = saved.Muted == true,
			}
		end)
	end)
end

return Settings
