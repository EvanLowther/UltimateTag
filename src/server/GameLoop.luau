--!strict
-- The game, start to finish:
--   Lobby -> Countdown -> rounds -> Victory -> Lobby again.
-- Lobby countdown: 20 s when the 2nd player is waiting, +10 s for each player who joins (never
-- above 40 s), no extensions and at most 15 s left once 10 players are waiting (shared/RoundPlan).
-- Each round: everyone is placed on the round's map (picked for the players still in, and loaded
-- during the previous Results), the game mode makes as many Its as the round's elimination
-- target (shared/RoundPlan: a game takes at most Config.Game.MaxRounds rounds), everyone is
-- frozen for the 5 s intro (the big role banner shows for 3 s of it), then the round timer runs
-- (2:00 with 7 or more players left, 1:30 with fewer). Tags freeze nobody. The round ends the
-- moment the target number of players are out (falling off the Rooftop District, the Metro's
-- train, AFK, leaving) or when the timer runs out, when the Its that are left are eliminated.
-- If every It is out mid-round a new one is picked from the Runners. Out of the game means
-- camera only: after a short ELIMINATED moment the body is parked out of sight and the player
-- spectates (server/Spectators, client/Spectate). Results (about 5 s) show who went out and how
-- while the next map loads behind a full-screen cover (client/RoundResults).
-- Rounds continue until one player is left; they win. When the game ends everyone is respawned
-- in the lobby and the win screen plays (client/WinScreen, the GameOver remote).
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
local RoundPlan = require(Shared.RoundPlan)
local Afk = require(script.Parent.Afk)
local GameLog = require(script.Parent.GameLog)
local GameRewards = require(script.Parent.GameRewards)
local MapRespawn = require(script.Parent.MapRespawn)
local MapService = require(script.Parent.MapService)
local Participants = require(script.Parent.Participants)
local Progression = require(script.Parent.Progression)
local Roles = require(script.Parent.Roles)
local RoundStats = require(script.Parent.RoundStats)
local Sandbox = require(script.Parent.Sandbox)
local Spectators = require(script.Parent.Spectators)
local WinsStore = require(script.Parent.WinsStore)
local HotPotato = require(script.Parent.Modes.HotPotato)

local GameLoop = {}

export type Mode = "Elimination" | "Sandbox"

local mode = HotPotato -- the active game mode (more modes can be added later)

local loopThread: thread? = nil -- the running Elimination loop (nil in Sandbox)
local prepThread: thread? = nil -- the next map being loaded during Results
local counting = false -- a phase timer is running
local remaining = 0 -- seconds left on it
local skipping = false -- end the current timer now (dev panel)
local forceStart = false -- start a game now, without the lobby countdown (dev panel)
local joinsSinceStart = 0 -- players who joined since the lobby countdown last looked

-- Who went out this round and why, for the results card.
type Out = { UserId: number, Name: string, DisplayName: string, Reason: string }
local roundOut: { Out } = {}
-- The round being played: how many are to go out, and how many players it started with.
local activeRound: { Target: number, StartAlive: number }? = nil

local function minPlayers(): number
	return if RunService:IsStudio() then Config.Game.StudioMinPlayers else Config.Game.MinPlayers
end

-- Counts down `seconds` in `phase`, checking `keepGoing` ten times a second. Stops early and
-- returns false if `keepGoing` returns false. A dev panel skip ends it early but counts as
-- finished.
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
		local waited = 0
		while waited < 1 and not skipping and finished do
			waited += task.wait(0.1)
			if keepGoing and not keepGoing() then
				finished = false
			end
		end
		if not finished then
			break
		end
		remaining -= 1
	end
	counting = false
	skipping = false
	GameState.setTimeLeft(0)
	return finished
end

-- Respawns a player in the lobby (its spawn ring has the only SpawnLocations in the game).
local function sendToLobby(player: Player)
	if player.Parent then
		pcall(player.LoadCharacter, player)
	end
end

-- Respawns these players in the lobby and waits (up to 5 s) until they have all loaded.
local function respawnInLobby(players: { Player })
	local pending = 0
	for _, player in players do
		pending += 1
		task.spawn(function()
			sendToLobby(player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 5 do
		waited += task.wait(0.1)
	end
end

-- The lobby's SpawnLocations (the spawn ring) are turned off in Sandbox so players spawn on the
-- test map.
local function setLobbySpawn(enabled: boolean)
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	for _, spawn in lobby:GetDescendants() do
		if spawn:IsA("SpawnLocation") then
			spawn.Enabled = enabled
		end
	end
end

-- Respawns each player on one of the map's spawn points (shuffled, reused if there are more
-- players than points) and waits (up to 5 s) until they have all loaded.
local function placeOnMap(players: { Player }, map: Model)
	local points = MapService.spawnPoints(map)
	for i = #points, 2, -1 do
		local j = math.random(i)
		points[i], points[j] = points[j], points[i]
	end
	local pending = 0
	for i, player in players do
		local point = points[((i - 1) % math.max(#points, 1)) + 1]
		pending += 1
		task.spawn(function()
			pcall(player.LoadCharacter, player)
			local character = player.Character
			if character and point then
				character:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
			end
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 5 do
		waited += task.wait(0.1)
	end
end

-- Has the round reached its end? Fewer than 2 players are left, or as many are out as the
-- target (players who left, fell, were hit by the train, went AFK or were eliminated all count).
local function roundIsOver(): boolean
	local round = activeRound
	if not round then
		return true
	end
	local alive = #Participants.alive()
	return alive < 2 or round.StartAlive - alive >= round.Target
end

-- If every It is out, makes a random Runner the new It.
local function ensureIt()
	local runners = {}
	for _, player in Participants.alive() do
		local role = Roles.get(player)
		if role == "It" then
			return
		elseif role == "Runner" then
			table.insert(runners, player)
		end
	end
	if #runners == 0 then
		return
	end
	local chosen = runners[math.random(#runners)]
	Roles.set(chosen, "It")
	GameLog.say(`no It left, {chosen.Name} is the new It (random Runner of {#runners})`)
	GameState.setStatus(`{chosen.DisplayName} is the new It!`)
end

-- Out mid-round (the Playing phase): fell off a FallEliminates map or hit by the Metro's train
-- (`body` false: they died and are respawning, the respawn is parked), or AFK (`body` true:
-- they are still standing there, so the ELIMINATED moment plays). They are camera only from now
-- on (server/Spectators). The round's end check (`roundIsOver`) sees the drop in players.
local function outMidRound(player: Player, reason: string, body: boolean)
	if GameState.getPhase() ~= "Playing" or not Participants.isAlive(player) then
		return
	end
	Participants.eliminate(player)
	Roles.set(player, nil)
	Progression.record(player, "GameLost")
	table.insert(roundOut, {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Reason = reason,
	})
	if body then
		Spectators.eliminated(player)
	else
		Spectators.fellOut(player)
	end
	local round = activeRound
	GameLog.say(
		`{player.Name} out mid-round: {reason}; {if round
			then round.StartAlive - #Participants.alive()
			else "?"} of {if round then round.Target else "?"} out`
	)
	Remotes.get("Notify"):FireAllClients(
		if reason == "Train"
			then `{player.DisplayName} was hit by the train and is out!`
			elseif reason == "Afk" then `{player.DisplayName} was away and is out!`
			else `{player.DisplayName} fell and is out!`
	)
	ensureIt()
end

local function fellOut(player: Player)
	local character = player.Character
	local hitByTrain = character ~= nil and character:GetAttribute("HitByTrain") == true
	outMidRound(player, if hitByTrain then "Train" else "Fell", false)
end

local function wentAfk(player: Player)
	outMidRound(player, "Afk", true)
end

-- Picks the next round's map for the players still in, clears their roles and freezes them
-- (they stay frozen through the rest of Results into the intro), loads the map and places them
-- on it. Returns the map's name (nil if there is none or fewer than 2 players are left).
local function loadRound(lastMap: string?): string?
	local alive = Participants.alive()
	if #alive < 2 then
		return nil
	end
	local mapName = MapService.choose(#alive, lastMap)
	if not mapName then
		warn("[GameLoop] no maps to play on")
		return nil
	end
	for _, player in alive do
		Roles.set(player, nil)
		Roles.freeze(player, Config.Game.ResultsTime + Config.Game.IntroTime + 20)
	end
	local map = MapService.load(mapName)
	placeOnMap(alive, map)
	task.wait(0.5) -- let the new characters settle before roles are applied to them
	GameLog.say(`loaded {mapName} for {#alive} players`)
	return mapName
end

-- Tells everyone about the round that just ended (the results card, client/RoundResults).
local function sendResults(round: number, hasNext: boolean)
	local left = #Participants.alive()
	for _, player in Players:GetPlayers() do
		local stats = RoundStats.get(player)
		local fate = "Watching"
		local reason: string? = nil
		if Participants.isAlive(player) then
			fate = "Safe"
		else
			for _, out in roundOut do
				if out.UserId == player.UserId then
					fate = "Out"
					reason = out.Reason
				end
			end
		end
		Remotes.get("RoundResults"):FireClient(player, {
			Round = round,
			Left = left,
			Out = roundOut,
			Next = hasNext,
			Duration = Config.Game.ResultsTime,
			CoverAt = Config.Game.ResultsCoverAt,
			Mine = {
				Fate = fate,
				Reason = reason,
				Tags = stats.Tags,
				Tagged = stats.Tagged,
				ItSeconds = math.floor(stats.ItSeconds + 0.5),
			},
		})
	end
end

-- One round on the already loaded `mapName`. Returns the name of the next round's map, which is
-- loaded behind the results card, or nil if the game is over (fewer than 2 players are left).
local function playRound(round: number, mapName: string): string?
	local alive = Participants.alive()
	GameState.setRound(round)
	Progression.newRound()
	table.clear(roundOut)
	RoundStats.reset(alive)
	local target = RoundPlan.eliminateTarget(#alive, round, Config.Game.MaxRounds)
	local startAlive = #alive
	activeRound = { Target = target, StartAlive = startAlive }
	local modeStatus = mode.setup(alive, target)
	GameLog.say(
		`round {round} on {mapName} starts: {startAlive} players, {target} to go out; roles: {GameLog.describe(
			alive
		)}`
	)

	-- Intro: everyone frozen to look around (the Its too: no head start).
	local intro = Config.Game.IntroTime
	for _, player in alive do
		Roles.freeze(player, intro)
	end
	GameState.setStatus(`Round {round}: {MapService.displayName(mapName)}. {modeStatus}`)
	local introDone = countdown("Intro", intro, function()
		ensureIt()
		return not roundIsOver()
	end)

	-- The round timer.
	if introDone and not roundIsOver() then
		GameState.setStatus(modeStatus)
		local seconds = if Config.Game.RoundTimeOverride > 0
			then Config.Game.RoundTimeOverride
			else RoundPlan.roundTime(#Participants.alive(), Config.Game.RoundTimes)
		RoundStats.begin()
		Afk.begin(Participants.alive())
		GameLog.say(`round timer: {seconds}s`)
		countdown("Playing", seconds, function()
			ensureIt()
			return not roundIsOver()
		end)
		Afk.stop()
	end
	RoundStats.finish()

	-- Time's up (or the target was reached early): the mode decides who else is out, up to what
	-- is left of the target.
	alive = Participants.alive()
	local quota = target - (startAlive - #alive)
	GameLog.say(
		`round over, roles: {GameLog.describe(alive)}; {startAlive - #alive} of {target} already out, {math.max(
			quota,
			0
		)} to go`
	)
	local out = if #alive >= 2 and quota > 0
		then mode.finish(alive, math.min(quota, #alive - 1))
		else {}
	for _, player in out do
		Participants.eliminate(player)
		Roles.set(player, nil)
		Spectators.eliminated(player) -- the ELIMINATED moment, then parked out of sight
		Progression.record(player, "GameLost")
		table.insert(roundOut, {
			UserId = player.UserId,
			Name = player.Name,
			DisplayName = player.DisplayName,
			Reason = "It",
		})
		GameLog.say(`{player.Name} eliminated: still It when time ran out ({mode.Name})`)
	end
	activeRound = nil
	if #roundOut > 0 then
		for _, player in Participants.alive() do
			Progression.record(player, "RoundSurvived")
		end
		Progression.checkTopFive(Participants.alive())
	end

	-- Results: the card shows who went out; once the ELIMINATED moment is over it covers the
	-- world while the next map is loaded and everyone is placed on it.
	local hasNext = #Participants.alive() >= 2
	local outNames = {}
	for _, entry in roundOut do
		table.insert(outNames, entry.DisplayName)
	end
	GameState.setStatus(
		if #outNames > 0 then `Out: {table.concat(outNames, ", ")}` else "Nobody was eliminated"
	)
	local nextName: string? = nil
	local prep = "idle" -- "idle", "running" or "done"
	local function prepare()
		prep = "running"
		nextName = loadRound(mapName)
		prep = "done"
	end
	GameState.setPhase("Results") -- (so clients know the phase when the card arrives)
	sendResults(round, hasNext)
	local resultsStart = os.clock()
	countdown("Results", Config.Game.ResultsTime, function()
		if
			hasNext
			and prep == "idle"
			and os.clock() - resultsStart >= Config.Game.ResultsCoverAt
		then
			prepThread = task.spawn(prepare)
		end
		return true
	end)
	if hasNext then
		if prep == "idle" then
			prepare() -- the card was skipped before the cover: load now
		end
		local waited = 0
		while prep ~= "done" and waited < Config.Game.ResultsLoadWait do
			waited += task.wait(0.1)
		end
		prepThread = nil
	else
		for _, player in Participants.alive() do
			Roles.set(player, nil)
		end
	end
	return nextName
end

local function playGame(players: { Player })
	Participants.startGame(players)
	GameRewards.begin(players)
	Progression.newGame(#players)
	for _, player in players do
		Progression.record(player, "GamePlayed")
	end
	local round = 0
	local mapName = loadRound(nil)
	while mapName do
		round += 1
		mapName = playRound(round, mapName)
	end

	-- One player left (or nobody, if everyone else left or fell).
	local winner = if round > 0 then Participants.alive()[1] else nil
	if winner then
		WinsStore.addWin(winner)
		Progression.record(winner, "Win")
		GameState.setStatus(`{winner.DisplayName} wins!`)
		ReplicatedStorage:SetAttribute("Winner", winner.Name)
	else
		GameState.setStatus("Nobody won this time.")
	end
	GameLog.say(`game over, winner: {if winner then winner.Name else "nobody"}`)

	-- What the win screen shows: the podium, and each player's own place and winnings.
	local podium = Participants.podium(Config.Game.PodiumSize)
	local screens: { [Player]: { [string]: any } } = {}
	for _, player in Players:GetPlayers() do
		local info: { [string]: any } = {
			Podium = podium,
			Duration = Config.Game.VictoryTime,
		}
		local earned = GameRewards.earned(player)
		local place, of = Participants.placeOf(player)
		if earned and place then
			info.Rewards = {
				Coins = earned.Coins,
				XP = earned.XP,
				Crates = earned.Crates,
				Items = earned.Items,
				LevelFrom = earned.LevelFrom,
				LevelTo = earned.LevelTo,
				Place = place,
				Of = of,
			}
		end
		screens[player] = info
	end

	-- The game is over: spectating ends at once (Victory is not a spectating phase), everyone is
	-- respawned in the lobby, the map goes, and the win screen plays on every screen.
	GameState.setPhase("Victory")
	Spectators.releaseAll()
	Roles.clearAll()
	Participants.endGame()
	GameRewards.clear()
	respawnInLobby(Players:GetPlayers())
	MapService.unload()
	if #podium > 0 then
		for player, info in screens do
			if player.Parent then
				Remotes.get("GameOver"):FireClient(player, info)
			end
		end
	end
	countdown("Victory", Config.Game.VictoryTime)
	ReplicatedStorage:SetAttribute("Winner", nil)
	GameState.setRound(0)
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
			joinsSinceStart = 0
			local bigLobbyCut = false -- the big lobby's cut is made once (the dev panel can then set more)
			local ready = countdown(
				"Countdown",
				RoundPlan.initialCountdown(#players, Config.Game),
				function()
					local count = #Players:GetPlayers()
					if count < minPlayers() then
						return false
					end
					local joins = joinsSinceStart
					joinsSinceStart = 0
					local big = count >= Config.Game.BigLobby
					if joins > 0 or (big and not bigLobbyCut) then
						local adjusted =
							RoundPlan.countdownAfter(remaining, joins, count, Config.Game)
						if adjusted ~= remaining then
							GameLog.say(
								`lobby countdown {remaining}s -> {adjusted}s ({joins} joined, {count} waiting)`
							)
							remaining = adjusted
							GameState.setTimeLeft(remaining)
						end
					end
					bigLobbyCut = big
					return true
				end
			)
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
	if prepThread then
		task.cancel(prepThread)
		prepThread = nil
	end
	Afk.stop()
	RoundStats.finish()
	activeRound = nil
	table.clear(roundOut)
	counting, skipping, forceStart = false, false, false
	ReplicatedStorage:SetAttribute("Winner", nil)
	Spectators.releaseAll()
	GameRewards.clear()
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
	Afk.onAfk(wentAfk)
	Players.PlayerAdded:Connect(function()
		joinsSinceStart += 1
	end)
	run(if Config.Game.Mode == "Sandbox" then "Sandbox" else "Elimination")
end

return GameLoop
