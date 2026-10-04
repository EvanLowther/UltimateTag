--!strict
-- Who is in the current game, as player attributes clients can read:
--   InGame  true for everyone who started this game
--   Alive   true while they're still in it (false once eliminated)
-- Players who join mid-game have neither, so they spectate until the next game.
-- Keeps GameState's AliveCount up to date.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.GameState)

local Participants = {}

local function refreshCount()
	GameState.setAliveCount(#Participants.alive())
end

-- Starts a game with these players, all alive.
function Participants.startGame(players: { Player })
	for _, player in Players:GetPlayers() do
		local playing = table.find(players, player) ~= nil
		player:SetAttribute("InGame", if playing then true else nil)
		player:SetAttribute("Alive", if playing then true else nil)
	end
	refreshCount()
end

-- Everyone still in the game (leavers drop out on their own).
function Participants.alive(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InGame") and player:GetAttribute("Alive") then
			table.insert(list, player)
		end
	end
	return list
end

function Participants.isAlive(player: Player): boolean
	return player:GetAttribute("InGame") == true and player:GetAttribute("Alive") == true
end

function Participants.eliminate(player: Player)
	player:SetAttribute("Alive", false)
	refreshCount()
end

-- Clears the game from everyone (back to the lobby).
function Participants.endGame()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("InGame", nil)
		player:SetAttribute("Alive", nil)
	end
	refreshCount()
end

function Participants.start()
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshCount) -- the leaver is still listed until the next frame
	end)
end

return Participants
