--!strict
-- The round loop: Waiting -> Intermission -> Playing -> RoundOver -> repeat.
-- Whoever is It when the timer runs out loses. Every Runner gets a Win.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local Leaderstats = require(script.Parent.Leaderstats)
local Roles = require(script.Parent.Roles)

local RoundService = {}

local function minPlayers(): number
	return if RunService:IsStudio() then Config.Round.StudioMinPlayers else Config.Round.MinPlayers
end

local function enoughPlayers(): boolean
	return #Players:GetPlayers() >= minPlayers()
end

-- Counts down `seconds` in `phase`. Stops early and returns false if `keepGoing` returns false.
local function countdown(phase: GameState.Phase, seconds: number, keepGoing: () -> boolean): boolean
	GameState.setPhase(phase)
	for timeLeft = seconds, 1, -1 do
		GameState.setTimeLeft(timeLeft)
		task.wait(1)
		if not keepGoing() then
			return false
		end
	end
	GameState.setTimeLeft(0)
	return true
end

-- Respawns the player at a random spot near the center of the map.
local function spawnScattered(player: Player)
	player:LoadCharacter()
	local character = player.Character
	if character then
		local angle = math.random() * 2 * math.pi
		local distance = math.random() * Config.Round.SpawnRadius
		character:PivotTo(CFrame.new(math.cos(angle) * distance, 4, math.sin(angle) * distance))
	end
end

local function pickIt(): Player?
	local runners = {}
	for _, player in Players:GetPlayers() do
		if Roles.get(player) == "Runner" then
			table.insert(runners, player)
		end
	end
	if #runners == 0 then
		return nil
	end
	local it = runners[math.random(#runners)]
	Roles.set(it, "It")
	return it
end

local function playRound()
	for _, player in Players:GetPlayers() do
		Roles.set(player, "Runner")
		task.spawn(spawnScattered, player)
	end
	local it = pickIt()
	if it then
		Roles.freeze(it, Config.Round.ItHeadStart)
		GameState.setStatus(`{it.DisplayName} is It! Run!`)
	end

	local finished = countdown("Playing", Config.Round.RoundTime, function()
		-- If It left the game, hand the role to someone else.
		if not Roles.getIt() then
			local newIt = pickIt()
			if newIt then
				GameState.setStatus(`It left! {newIt.DisplayName} is now It!`)
			end
		end
		return enoughPlayers()
	end)

	if finished then
		local loser = Roles.getIt()
		for _, player in Players:GetPlayers() do
			if Roles.get(player) == "Runner" then
				Leaderstats.add(player, "Wins", 1)
			end
		end
		GameState.setStatus(
			if loser
				then `{loser.DisplayName} was It at the buzzer! Everyone else wins!`
				else "Round over!"
		)
	else
		GameState.setStatus("Not enough players. Round cancelled.")
	end
	GameState.setPhase("RoundOver")
	task.wait(Config.Round.EndTime)
	Roles.clearAll()
end

function RoundService.start()
	-- People who join mid-round can be tagged right away.
	Players.PlayerAdded:Connect(function(player)
		if GameState.getPhase() == "Playing" then
			Roles.set(player, "Runner")
		end
	end)

	task.spawn(function()
		while true do
			if not enoughPlayers() then
				GameState.setPhase("Waiting")
				GameState.setStatus(`Waiting for players ({#Players:GetPlayers()}/{minPlayers()})`)
				task.wait(1)
			else
				GameState.setStatus("Get ready! Next round starting soon.")
				if countdown("Intermission", Config.Round.IntermissionTime, enoughPlayers) then
					playRound()
				end
			end
		end
	end)
end

return RoundService
