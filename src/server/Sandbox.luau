--!strict
-- Free-play test mode: no rounds or timer. Everyone is a Runner and one player is always It.
-- If It leaves, someone else becomes It. Use this to try out mechanics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameState = require(Shared.GameState)
local Roles = require(script.Parent.Roles)

local Sandbox = {}

local connections: { RBXScriptConnection } = {}

local function ensureIt()
	if Roles.getIt() then
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local it = players[math.random(#players)]
	Roles.set(it, "It")
	GameState.setStatus(`{it.DisplayName} is It!`)
end

function Sandbox.start()
	GameState.setStatus("Sandbox: tag to pass It on")

	table.insert(
		connections,
		Players.PlayerAdded:Connect(function(player)
			Roles.set(player, "Runner")
			ensureIt()
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function()
			-- The leaving player is still listed until the next frame.
			task.defer(ensureIt)
		end)
	)
	for _, player in Players:GetPlayers() do
		Roles.set(player, "Runner")
	end
	ensureIt()
end

-- Stops keeping an It (when the dev panel switches modes).
function Sandbox.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return Sandbox
