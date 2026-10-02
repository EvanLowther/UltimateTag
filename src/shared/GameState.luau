--!strict
-- Round state shared by server and client, stored as attributes on ReplicatedStorage.
-- Only the server calls the set functions. Clients read them and listen for changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Phase = "Waiting" | "Intermission" | "Playing" | "RoundOver"

local GameState = {}

function GameState.getPhase(): Phase
	return (ReplicatedStorage:GetAttribute("Phase") or "Waiting") :: Phase
end

function GameState.getTimeLeft(): number
	return (ReplicatedStorage:GetAttribute("TimeLeft") or 0) :: number
end

function GameState.getStatus(): string
	return (ReplicatedStorage:GetAttribute("Status") or "") :: string
end

function GameState.setPhase(phase: Phase)
	ReplicatedStorage:SetAttribute("Phase", phase)
end

function GameState.setTimeLeft(seconds: number)
	ReplicatedStorage:SetAttribute("TimeLeft", seconds)
end

function GameState.setStatus(text: string)
	ReplicatedStorage:SetAttribute("Status", text)
end

-- Calls `callback` whenever the phase, timer or status changes.
function GameState.onChanged(callback: () -> ()): RBXScriptConnection
	return ReplicatedStorage.AttributeChanged:Connect(function(name)
		if name == "Phase" or name == "TimeLeft" or name == "Status" then
			callback()
		end
	end)
end

return GameState
