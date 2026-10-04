--!strict
-- This player's own profile as the server last sent it (server/PlayerData through the
-- ProfileSync remote): coins, XP, level, owned and equipped cosmetics, quests, streak, stats.
-- Read only: changes always go through the server. Menus read it and listen with onChanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Profile = {}

local data: { [string]: any }? = nil
local listeners: { (any) -> () } = {}

-- The latest profile, or nil until the first sync arrives.
function Profile.get(): { [string]: any }?
	return data
end

-- Calls `callback(profile)` on every update (and now, if one has arrived already).
function Profile.onChanged(callback: (any) -> ())
	table.insert(listeners, callback)
	if data then
		task.spawn(callback, data)
	end
end

function Profile.start()
	local remote = Remotes.get("ProfileSync")
	remote.OnClientEvent:Connect(function(profile)
		data = profile
		for _, callback in listeners do
			task.spawn(callback, profile)
		end
	end)
	remote:FireServer() -- in case the first sync went out before this was listening
end

return Profile
