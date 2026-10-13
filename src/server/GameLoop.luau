--!strict
-- The game, start to finish:
--   Lobby -> Countdown -> rounds -> Victory -> Lobby again.
-- Each round: pick a map for the number of players still in (MapService), load it, place
-- everyone on its spawn points, let the game mode assign roles (Modes/HotPotato), freeze
-- everyone for the intro (Its a little longer), run the timer, then eliminate whoever the mode
-- says lost. Eliminated players go back to the lobby and spectate (client/Spectate). On a map
-- with FallEliminates, falling off during the round puts you out at once (server/MapRespawn).
-- Rounds continue until one player is left; they win.
-- With Config.Game.Mode = "Sandbox" this runs the free-play test mode instead (server/Sandbox).
-- The dev panel (server/DevCommands) can switch modes, skip the current timer, change the time
-- left and start a game early.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local MapRespawn = require(script.Parent.MapRespawn)
local MapService = require(script.Parent.MapService)
local Participants = require(script.Parent.Participants)
local Progression = require(script.Parent.Progression)
local Roles = require(script.Parent.Roles)
local Sandbox = require(script.Parent.Sandbox)
local WinsStore = require(script.Parent.WinsStore)
local HotPotato = require(script.Parent.Modes.HotPotato)

local GameLoop = {}

export type Mode = "Elimination" | "Sandbox"

local mode = HotPotato -- the active game mode (more modes can be added later)

local loopThread: thread? = nil -- the running Elimination loop (nil in Sandbox)
local counting = false -- a phase timer is running
local remaining = 0 -- seconds left on it
local skipping = false -- end the current timer now (dev panel)
local forceStart = false -- start a game now, without the lobby countdown (dev panel)
local fellThisRound: { Player } = {} -- out this round by falling off (FallEliminates maps)

local function minPlayers(): number
	return if RunService:IsStudio() then Config.Game.StudioMinPlayers else Config.Game.MinPlayers
end

-- Counts down `seconds` in `phase`. Stops early and returns false if `keepGoing` returns false.
-- A dev panel skip ends it early but counts as finished.
local function countdown(
	phase: GameState.Phase,
	seconds: number,
	keepGoing: (() -> boolean)?
): boolean
	GameState.setPhase(phase)
	remaining = seconds
	skipping = false
	counting = true
	local finished = true
	while remaining > 0 and not skipping do
		GameState.setTimeLeft(remaining)
		task.wait(1)
		remaining -= 1
		if keepGoing and not keepGoing() then
			finished = false
			break
		end
	end
	counting = false
	skipping = false
	GameState.setTimeLeft(0)
	return finished
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

-- The lobby's SpawnLocation is turned off in Sandbox so players spawn on the test map.
local function setLobbySpawn(enabled: boolean)
	local lobby = workspace:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.Enabled = enabled
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

local function roundGoesOn(): boolean
	return enoughToKeepPlaying() and mode.canContinue(Participants.alive())
end

-- Out mid-round: fell off a map with FallEliminates (server/MapRespawn). They come back in the
-- lobby on their own (the lobby has the only SpawnLocation) and spectate.
local function fellOut(player: Player)
	if GameState.getPhase() ~= "Playing" or not Participants.isAlive(player) then
		return
	end
	Participants.eliminate(player)
	Roles.set(player, nil)
	Progression.record(player, "GameLost")
	table.insert(fellThisRound, player)
	Remotes.get("Notify"):FireAllClients(`{player.DisplayName} fell and is out!`)
end

-- One round. Returns false if the game should stop (not enough players left).
local function playRound(round: number, lastMap: string?): string?
	local alive = Participants.alive()
	GameState.setRound(round)
	Progression.newRound()
	table.clear(fellThisRound)
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
	countdown("Playing", Config.Game.RoundTime, roundGoesOn)

	-- Time's up: the mode decides who's out.
	alive = Participants.alive()
	local out = if #alive >= 2 then mode.finish(alive) else {}
	for _, player in out do
		Participants.eliminate(player)
		Roles.set(player, nil)
		sendToLobby(player)
		Progression.record(player, "GameLost")
	end
	if #out > 0 or #fellThisRound > 0 then
		for _, player in Participants.alive() do
			Progression.record(player, "RoundSurvived")
		end
		Progression.checkTopFive(Participants.alive())
	end
	local results = {}
	if #out > 0 then
		table.insert(results, `Eliminated: {names(out)}`)
	end
	if #fellThisRound > 0 then
		table.insert(results, `Fell off: {names(fellThisRound)}`)
	end
	GameState.setStatus(
		if #results > 0 then table.concat(results, ". ") else "Nobody was eliminated"
	)
	countdown("Results", Config.Game.ResultsTime)
	for _, player in Participants.alive() do
		Roles.set(player, nil)
	end
	MapService.unload()
	return mapName
end

local function playGame(players: { Player })
	Participants.startGame(players)
	Progression.newGame(#players)
	for _, player in players do
		Progression.record(player, "GamePlayed")
	end
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
		Progression.record(winner, "Win")
		GameState.setStatus(`{winner.DisplayName} wins!`)
		ReplicatedStorage:SetAttribute("Winner", winner.Name)
		-- Celebrate in the lobby, where everyone else already is (the last map is gone), with the
		-- winner's equipped victory (client/CosmeticEffects).
		sendToLobby(winner)
		task.wait(0.8)
		Remotes.get("Victory"):FireAllClients(winner)
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
		if player ~= winner then
			sendToLobby(player)
		end
	end
end

local function runElimination()
	while true do
		local players = Players:GetPlayers()
		if forceStart then
			forceStart = false
			playGame(players)
		elseif #players < minPlayers() then
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
	setLobbySpawn(false)
	for _, player in Players:GetPlayers() do
		task.spawn(sendToLobby, player) -- respawns them on the test map's SpawnLocation
	end
	Sandbox.start()
end

-- Stops whatever is running and clears all game state (roles, map, participants).
local function stopAll()
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
	Sandbox.stop()
	counting, skipping, forceStart = false, false, false
	ReplicatedStorage:SetAttribute("Winner", nil)
	Roles.clearAll()
	MapService.unload()
	Participants.endGame()
	GameState.setRound(0)
	GameState.setTimeLeft(0)
	setLobbySpawn(true)
end

local function run(newMode: Mode)
	Config.Game.Mode = newMode
	GameState.setMode(newMode)
	if newMode == "Sandbox" then
		runSandbox()
	else
		loopThread = task.spawn(runElimination)
	end
end

-- Dev panel: switch between Elimination and Sandbox right now. Everyone respawns.
function GameLoop.setMode(newMode: Mode)
	stopAll()
	run(newMode)
	if newMode == "Elimination" then
		for _, player in Players:GetPlayers() do
			task.spawn(sendToLobby, player)
		end
	end
end

-- Dev panel: ends the running timer now (lobby countdown, intro, round, results or victory).
-- Returns false if no timer is running.
function GameLoop.skip(): boolean
	if not counting then
		return false
	end
	skipping = true
	return true
end

-- Dev panel: sets the seconds left on the running timer. Returns false if none is running.
function GameLoop.setTimeLeft(seconds: number): boolean
	if not counting then
		return false
	end
	remaining = math.max(1, math.floor(seconds))
	GameState.setTimeLeft(remaining)
	return true
end

-- Dev panel: starts a game now with everyone, skipping the lobby countdown (needs 2 players).
-- Returns a reason if it can't.
function GameLoop.startNow(): string?
	if Config.Game.Mode ~= "Elimination" then
		return "Switch to Elimination first"
	end
	local phase = GameState.getPhase()
	if phase ~= "Lobby" and phase ~= "Countdown" then
		return "A game is already running"
	end
	if #Players:GetPlayers() < 2 then
		return "A game needs 2 players (Test > Clients and Servers)"
	end
	if phase == "Countdown" then
		skipping = true
	else
		forceStart = true
	end
	return nil
end

function GameLoop.start()
	Participants.start()
	MapRespawn.onFellOut(fellOut)
	run(if Config.Game.Mode == "Sandbox" then "Sandbox" else "Elimination")
end

return GameLoop
