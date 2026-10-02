--!strict
-- Status text shared by server and client, stored as an attribute on ReplicatedStorage.
-- Only the server calls setStatus. Clients read it and listen for changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = {}

function GameState.getStatus(): string
	return (ReplicatedStorage:GetAttribute("Status") or "") :: string
end

function GameState.setStatus(text: string)
	ReplicatedStorage:SetAttribute("Status", text)
end

-- Calls `callback` whenever the status changes.
function GameState.onChanged(callback: () -> ()): RBXScriptConnection
	return ReplicatedStorage:GetAttributeChangedSignal("Status"):Connect(callback)
end

return GameState
