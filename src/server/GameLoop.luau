--!strict
-- The game, start to finish:
--   Lobby -> Countdown -> rounds -> Victory -> Lobby again.
-- Each round: pick a map for the number of players still in (MapService), load it, place
-- everyone on its spawn points, let the game mode assign roles (Modes/HotPotato), freeze
-- everyone for the intro (Its a little longer), run the timer, then eliminate whoever the mode
-- says lost. Eliminated players go back to the lobby and spectate (client/Spectate). Rounds
-- continue until one player is left; they win.
-- With Config.Game.Mode = "Sandbox" this runs the free-play test mode instead (server/Sandbox).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local MapService = require(script.Parent.MapService)
local Participants = require(script.Parent.Participants)
local Roles = require(script.Parent.Roles)
local Sandbox = require(script.Parent.Sandbox)
local WinsStore = require(script.Parent.WinsStore)
local HotPotato = require(script.Parent.Modes.HotPotato)

local GameLoop = {}

local mode = HotPotato -- the active game mode (more modes can be added later)

local function minPlayers(): number
	return if RunService:IsStudio() then Config.Game.StudioMinPlayers else Config.Game.MinPlayers
end

-- Counts down `seconds` in `phase`. Stops early and returns false if `keepGoing` returns false.
local function countdown(
	phase: GameState.Phase,
	seconds: number,
	keepGoing: (() -> boolean)?
): boolean
	GameState.setPhase(phase)
	for timeLeft = seconds, 1, -1 do
		GameState.setTimeLeft(timeLeft)
		task.wait(1)
		if keepGoing and not keepGoing() then
			GameState.setTimeLeft(0)
			return false
		end
	end
	GameState.setTimeLeft(0)
	return true
end

local function names(players: { Player }): string
	local list = {}
	for _, player in players do
		table.insert(list, player.DisplayName)
	end
	return table.concat(list, ", ")
end

-- Respawns a player in the lobby (the only SpawnLocation in the game).
local function sendToLobby(player: Player)
	if player.Parent then
		player:LoadCharacter()
	end
end

-- Respawns each player on one of the map's spawn points (shuffled, reused if there are more
-- players than points).
local function placeOnMap(players: { Player }, map: Model)
	local points = MapService.spawnPoints(map)
	for i = #points, 2, -1 do
		local j = math.random(i)
		points[i], points[j] = points[j], points[i]
	end
	for i, player in players do
		local point = points[((i - 1) % math.max(#points, 1)) + 1]
		task.spawn(function()
			player:LoadCharacter()
			local character = player.Character
			if character and point then
				character:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
			end
		end)
	end
end

local function enoughToKeepPlaying(): boolean
	return #Participants.alive() >= 2
end

-- One round. Returns false if the game should stop (not enough players left).
local function playRound(round: number, lastMap: string?): string?
	local alive = Participants.alive()
	GameState.setRound(round)
	local mapName = MapService.choose(#alive, lastMap)
	if not mapName then
		warn("[GameLoop] no maps to play on")
		return nil
	end
	local map = MapService.load(mapName)
	placeOnMap(alive, map)
	task.wait(0.5) -- let the new characters load before roles are applied to them
	local modeStatus = mode.setup(alive)

	-- Intro: everyone frozen to look around; Its stay frozen a little longer (head start).
	local intro = Config.Game.IntroTime
	for _, player in alive do
		local extra = if Roles.get(player) == "It" then Config.Game.ItHeadStart else 0
		Roles.freeze(player, intro + extra)
	end
	GameState.setStatus(`Round {round}: {MapService.displayName(mapName)}. {modeStatus}`)
	countdown("Intro", intro, enoughToKeepPlaying)

	GameState.setStatus(modeStatus)
	countdown("Playing", Config.Game.RoundTime, enoughToKeepPlaying)

	-- Time's up: the mode decides who's out.
	alive = Participants.alive()
	local out = if #alive >= 2 then mode.finish(alive) else {}
	for _, player in out do
		Participants.eliminate(player)
		Roles.set(player, nil)
		sendToLobby(player)
	end
	GameState.setStatus(if #out > 0 then `Eliminated: {names(out)}` else "Nobody was eliminated")
	countdown("Results", Config.Game.ResultsTime)
	for _, player in Participants.alive() do
		Roles.set(player, nil)
	end
	MapService.unload()
	return mapName
end

local function playGame(players: { Player })
	Participants.startGame(players)
	local round = 0
	local lastMap: string? = nil
	while #Participants.alive() >= 2 do
		round += 1
		lastMap = playRound(round, lastMap)
		if not lastMap then
			break
		end
	end

	-- One player left (or nobody, if everyone else left).
	local alive = Participants.alive()
	local winner = alive[1]
	if winner then
		WinsStore.addWin(winner)
		GameState.setStatus(`{winner.DisplayName} wins!`)
		ReplicatedStorage:SetAttribute("Winner", winner.Name)
	else
		GameState.setStatus("Nobody won this time.")
	end
	countdown("Victory", Config.Game.VictoryTime)
	ReplicatedStorage:SetAttribute("Winner", nil)
	Roles.clearAll()
	MapService.unload()
	Participants.endGame()
	GameState.setRound(0)
	for _, player in alive do
		sendToLobby(player)
	end
end

local function runElimination()
	while true do
		local players = Players:GetPlayers()
		if #players < minPlayers() then
			GameState.setPhase("Lobby")
			GameState.setTimeLeft(0)
			GameState.setStatus(`Waiting for players ({#players}/{minPlayers()})`)
			task.wait(1)
		else
			GameState.setStatus("Game starting soon!")
			local ready = countdown("Countdown", Config.Game.LobbyCountdown, function()
				return #Players:GetPlayers() >= minPlayers()
			end)
			if ready then
				playGame(Players:GetPlayers())
			end
		end
	end
end

-- Sandbox: the test map, nothing ends. Players spawn on the test map instead of the lobby.
local function runSandbox()
	GameState.setPhase("Sandbox")
	MapService.load("TestGround")
	local lobbySpawn = workspace:FindFirstChild("Lobby")
	local spawn = lobbySpawn and lobbySpawn:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.Enabled = false
	end
	for _, player in Players:GetPlayers() do
		task.spawn(sendToLobby, player) -- respawns them on the test map's SpawnLocation
	end
	Sandbox.start()
end

function GameLoop.start()
	Participants.start()
	if Config.Game.Mode == "Sandbox" then
		runSandbox()
	else
		task.spawn(runElimination)
	end
end

return GameLoop
