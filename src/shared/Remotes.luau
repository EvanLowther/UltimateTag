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
--   MoveDone:       client -> server: a move started ("WallRun", "Slide"), for
--                   stats and quests. Only counted during a live round, and throttled.
--   Equip:          client -> server: equip an owned cosmetic (its id).
--   TagHit:         server -> clients: (tagger, tagged) a tag landed: play the tagger's effect.
--   TagKnockback:   server -> the player hit by a swing (tag or shove): (push) their flat push
--                   velocity; client/Knockback applies it (they own their character's physics).
--   GameOver:       server -> clients: the game ended; (info) a table for client/WinScreen:
--                   Podium = { { UserId, Name, DisplayName, Place, Won } } best first (the winner
--                   has Won = true; none if nobody won), Duration (seconds the screen lasts),
--                   and for players who were in the game Rewards = { Coins, XP, Crates, Items,
--                   LevelFrom, LevelTo, Place, Of } (their own, from server/GameRewards).
--   ShopBuy:        client -> server: buy today's shop item (its id).
--   BuyCrate:       client -> server: buy a crate (it goes into your crates).
--   OpenCrate:      client -> server: (count) open that many of your crates (1 if left out).
--   ClaimStreak:    client -> server: claim today's login streak reward.
--   ClaimQuest:     client -> server: ("Daily" | "Weekly", slot) claim a finished quest.
--   ClaimAchievement: client -> server: (achievement id) claim a reached achievement's reward.
--   Announce:       server -> clients: something everyone sees (a table: Kind = "Unbox" when
--                   someone opens an Iridescent item, with Name, Item and Serial).
--   PopUp:          client -> server: (pad) "I launched off this pop-up's pad": server/PopUps
--                   springs it for everyone if it's ready.
--   Leaderboard:    client -> server (no arguments): "send me the boards". Server -> client:
--                   the cached boards and this player's ranks (server/Leaderboards).
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
	"Equip",
	"TagHit",
	"TagKnockback",
	"GameOver",
	"ShopBuy",
	"BuyCrate",
	"OpenCrate",
	"ClaimStreak",
	"ClaimQuest",
	"ClaimAchievement",
	"Announce",
	"Leaderboard",
	"PopUp",
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
