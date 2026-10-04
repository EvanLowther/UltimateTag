--!strict
-- The game's RemoteEvents, in ReplicatedStorage.Remotes. The server creates them at startup
-- (Remotes.setup, from init.server.luau); clients get them with Remotes.get.
--   TagSwing:       client -> server. "I swung to tag." The server decides if it hit.
--   TagSwingPlayed: server -> clients. "This player swung." Every client plays the swipe on
--                   that character, so everyone sees it.
--   Notify:         server -> one client. A short message to show on screen.
--   DevCommand:     both ways, developers only (server/DevCommands checks). Client -> server:
--                   a dev panel command and its arguments. Server -> client: replies (the map list).
--   ProfileSync:    server -> one client: their saved profile (server/PlayerData). Client ->
--                   server (no arguments): "send it again".
--   Reward:         server -> one client: something was earned (a table: Kind = "Coins",
--                   "LevelUp", "Items"...), for the popups in client/Menu.
--   MoveDone:       client -> server: a move started ("WallRun", "Slide", "Vault", "Climb"), for
--                   stats and quests. Only counted during a live round, and throttled.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local FOLDER = "Remotes"
local NAMES = {
	"TagSwing",
	"TagSwingPlayed",
	"Notify",
	"DevCommand",
	"ProfileSync",
	"Reward",
	"MoveDone",
}

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
