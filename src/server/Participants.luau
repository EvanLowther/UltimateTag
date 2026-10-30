--!strict
-- Who is in the current game, as player attributes clients can read:
--   InGame  true for everyone who started this game
--   Alive   true while they're still in it (false once eliminated)
-- Players who join mid-game have neither, so they spectate until the next game.
-- Keeps GameState's AliveCount up to date.
-- Also records the order players went out in (`eliminate`), for the win screen's podium.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.GameState)
local GameLog = require(script.Parent.GameLog)

local Participants = {}

-- Someone who went out of the game. `Order` counts up with every elimination in the game, so a
-- later one always has the higher number (Round alone can't tell two from the same round apart).
type Placement = { UserId: number, Name: string, DisplayName: string, Round: number, Order: number }

-- One podium entry: `Place` 1 is the winner (`Won` is true only for someone still in the game
-- when it ended).
export type Podium = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Place: number,
	Won: boolean,
}

local placements: { Placement } = {}
local gameId = 0 -- counts games, so delayed work can tell it belongs to an earlier one

local function refreshCount()
	GameState.setAliveCount(#Participants.alive())
end

-- Starts a game with these players, all alive.
function Participants.startGame(players: { Player })
	gameId += 1
	table.clear(placements)
	for _, player in Players:GetPlayers() do
		local playing = table.find(players, player) ~= nil
		player:SetAttribute("InGame", if playing then true else nil)
		player:SetAttribute("Alive", if playing then true else nil)
		player:SetAttribute("LeftEarly", nil)
	end
	refreshCount()
	GameLog.say(`game {gameId} starts: {GameLog.everyone()}`)
end

-- Which game this is (increases with every game). Delayed work keeps the number it started in
-- and gives up if it has changed.
function Participants.gameId(): number
	return gameId
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

-- Puts a player out of the game and remembers when (once: a second call changes nothing).
function Participants.eliminate(player: Player)
	for _, placement in placements do
		if placement.UserId == player.UserId then
			return
		end
	end
	player:SetAttribute("Alive", false)
	table.insert(placements, {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Round = GameState.getRound(),
		Order = #placements + 1,
	})
	refreshCount()
	GameLog.say(
		`{player.Name} is out (round {GameState.getRound()}, number {#placements} out); alive now: {#Participants.alive()}`
	)
end

-- The best `limit` players for the win screen, best first: whoever is still in the game (the
-- winner, Won = true), then the players who went out last. Going out later ranks higher, also
-- within the same round (two players out in one round: the one out second is better). Only
-- players still in the server are listed (the win screen needs their characters), so a podium
-- player who left is replaced by the next best, and a game with 2 or 3 players has a shorter
-- podium. Call it before `endGame`.
function Participants.podium(limit: number): { Podium }
	local list: { Podium } = {}
	local function add(player: Player, won: boolean)
		if #list < limit then
			table.insert(list, {
				UserId = player.UserId,
				Name = player.Name,
				DisplayName = player.DisplayName,
				Place = #list + 1,
				Won = won,
			})
		end
	end
	for i, player in Participants.alive() do
		add(player, i == 1)
	end
	for i = #placements, 1, -1 do
		local player = Players:GetPlayerByUserId(placements[i].UserId)
		if player and player.Parent and not Participants.isAlive(player) then
			add(player, false)
		end
	end
	return list
end

-- This player's finishing place among the players who are still here and started the game
-- (1 = still in at the end), and how many that is. nil if they weren't in the game. Call it
-- before `endGame`.
function Participants.placeOf(player: Player): (number?, number)
	local aliveCount = #Participants.alive()
	local present = 0 -- eliminated players still in the server
	local outAfter = 0 -- of those, the ones who went out after this player
	local mine: number? = nil
	for i, placement in placements do
		if placement.UserId == player.UserId then
			mine = i
		end
	end
	for i, placement in placements do
		local other = Players:GetPlayerByUserId(placement.UserId)
		if other and other.Parent then
			present += 1
			if mine and i > mine then
				outAfter += 1
			end
		end
	end
	if Participants.isAlive(player) then
		return 1, aliveCount + present
	end
	if not mine then
		return nil, 0
	end
	return aliveCount + outAfter + 1, aliveCount + present
end

-- Clears the game from everyone (back to the lobby).
function Participants.endGame()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("InGame", nil)
		player:SetAttribute("Alive", nil)
		player:SetAttribute("LeftEarly", nil)
	end
	refreshCount()
	GameLog.say("game over, everyone is out of the game state")
end

function Participants.start()
	Players.PlayerRemoving:Connect(function(player)
		if player:GetAttribute("InGame") then
			GameLog.say(
				`{player.Name} left ({if player:GetAttribute("Alive")
					then "alive"
					else "already out"})`
			)
		end
		task.defer(refreshCount) -- the leaver is still listed until the next frame
	end)
end

return Participants
