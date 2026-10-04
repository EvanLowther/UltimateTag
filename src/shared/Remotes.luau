--!strict
-- The game's RemoteEvents, in ReplicatedStorage.Remotes. The server creates them at startup
-- (Remotes.setup, from init.server.luau); clients get them with Remotes.get.
--   TagSwing:       client -> server. "I swung to tag." The server decides if it hit.
--   TagSwingPlayed: server -> clients. "This player swung." Every client plays the swipe on
--                   that character, so everyone sees it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local FOLDER = "Remotes"
local NAMES = { "TagSwing", "TagSwingPlayed" }

-- Server only: creates the folder and every RemoteEvent.
function Remotes.setup()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

-- Either side: the RemoteEvent called `name` (waits for the server to create it).
function Remotes.get(name: string): RemoteEvent
	return ReplicatedStorage:WaitForChild(FOLDER):WaitForChild(name) :: RemoteEvent
end

return Remotes
