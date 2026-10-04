--!strict
-- Game state shared by server and client, stored as attributes on ReplicatedStorage.
-- Only the server calls the set functions. Clients read them and listen for changes.
--   Phase:      where the game is (see the Phase type).
--   TimeLeft:   seconds left in the current phase (0 when there's no timer).
--   Round:      round number in the current game (0 in the lobby).
--   AliveCount: players still in the game.
--   Status:     a line of text for the HUD.
--   Mode:       how the server runs: "Elimination" or "Sandbox" (Config.Game.Mode, switchable
--               from the dev panel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Phase =
	"Sandbox" -- free play for testing movement (Config.Game.Mode = "Sandbox")
	| "Lobby" -- waiting for enough players
	| "Countdown" -- enough players, the game starts soon
	| "Intro" -- a round's map is loaded and players are placed; Its have a head start
	| "Playing" -- the round timer is running
	| "Results" -- the round is over, eliminations are shown
	| "Victory" -- the game is over, the winner is shown

local GameState = {}

local FIELDS =
	{ Phase = true, TimeLeft = true, Round = true, AliveCount = true, Status = true, Mode = true }

function GameState.getPhase(): Phase
	return (ReplicatedStorage:GetAttribute("Phase") or "Lobby") :: Phase
end

function GameState.getTimeLeft(): number
	return (ReplicatedStorage:GetAttribute("TimeLeft") or 0) :: number
end

function GameState.getRound(): number
	return (ReplicatedStorage:GetAttribute("Round") or 0) :: number
end

function GameState.getAliveCount(): number
	return (ReplicatedStorage:GetAttribute("AliveCount") or 0) :: number
end

function GameState.getStatus(): string
	return (ReplicatedStorage:GetAttribute("Status") or "") :: string
end

function GameState.getMode(): string
	return (ReplicatedStorage:GetAttribute("Mode") or "Elimination") :: string
end

function GameState.setMode(mode: string)
	ReplicatedStorage:SetAttribute("Mode", mode)
end

function GameState.setPhase(phase: Phase)
	ReplicatedStorage:SetAttribute("Phase", phase)
end

function GameState.setTimeLeft(seconds: number)
	ReplicatedStorage:SetAttribute("TimeLeft", seconds)
end

function GameState.setRound(round: number)
	ReplicatedStorage:SetAttribute("Round", round)
end

function GameState.setAliveCount(count: number)
	ReplicatedStorage:SetAttribute("AliveCount", count)
end

function GameState.setStatus(text: string)
	ReplicatedStorage:SetAttribute("Status", text)
end

-- Calls `callback` whenever any of the fields above changes.
function GameState.onChanged(callback: () -> ()): RBXScriptConnection
	return ReplicatedStorage.AttributeChanged:Connect(function(name)
		if FIELDS[name] then
			callback()
		end
	end)
end

return GameState
