--!strict
-- This player's own profile as the server last sent it (server/PlayerData through the
-- ProfileSync remote): coins, XP, level, owned and equipped cosmetics, quests, streak, stats.
-- Read only: changes always go through the server. Menus read it and listen with onChanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Profile = {}

local data: { [string]: any }? = nil
local override: { [string]: any }? = nil
local listeners: { (any) -> () } = {}

-- The latest profile, or nil until the first sync arrives.
function Profile.get(): { [string]: any }?
	return override or data
end

-- Shows `sample` instead of the real profile (nil: back to the real one) and tells every
-- listener: the UI auditor's worst-case content (client/DevPanel/UiAudit). Nothing is sent to
-- the server, and the next real sync is ignored while a sample is shown.
function Profile.setOverride(sample: { [string]: any }?)
	override = sample
	local shown = sample or data
	if shown then
		for _, callback in listeners do
			task.spawn(callback, shown)
		end
	end
end

-- Calls `callback(profile)` on every update (and now, if one has arrived already).
function Profile.onChanged(callback: (any) -> ())
	table.insert(listeners, callback)
	local shown = override or data
	if shown then
		task.spawn(callback, shown)
	end
end

function Profile.start()
	local remote = Remotes.get("ProfileSync")
	remote.OnClientEvent:Connect(function(profile)
		data = profile
		if override then
			return
		end
		for _, callback in listeners do
			task.spawn(callback, profile)
		end
	end)
	remote:FireServer() -- in case the first sync went out before this was listening
end

return Profile
