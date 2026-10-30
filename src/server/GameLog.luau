--!strict
-- The debug log for the game flow (Config.Game.DebugLog, on in Studio by default): one line per
-- event, tagged with the round, phase and time left, so a playtest's output shows what happened
-- and in what order (roles at the start, every tag, swings that missed, who went out and why).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)

local GameLog = {}

function GameLog.enabled(): boolean
	return Config.Game.DebugLog == true
end

function GameLog.say(text: string)
	if Config.Game.DebugLog then
		print(
			`[Game R{GameState.getRound()} {GameState.getPhase()} {GameState.getTimeLeft()}s] {text}`
		)
	end
end

-- "Ann (It), Bo (Runner)": names with their roles, or "-" for an empty list.
function GameLog.describe(players: { Player }): string
	if #players == 0 then
		return "-"
	end
	local list = {}
	for _, player in players do
		local role = player:GetAttribute("Role")
		table.insert(list, `{player.Name} ({role or "no role"})`)
	end
	return table.concat(list, ", ")
end

-- Everyone in the server with their game state: "Ann [in game, alive, It]".
function GameLog.everyone(): string
	local list = {}
	for _, player in Players:GetPlayers() do
		local state = if player:GetAttribute("InGame")
			then (if player:GetAttribute("Alive") then "alive" else "out")
			else "not in game"
		local role = player:GetAttribute("Role")
		table.insert(list, `{player.Name} [{state}{if role then ", " .. role else ""}]`)
	end
	return table.concat(list, ", ")
end

return GameLog
