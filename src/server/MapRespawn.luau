--!strict
-- Falling off a map. A loaded map with a KillHeight attribute kills anyone who drops below that
-- world height (maps sit at the origin) while near it (Config.Game.KillRadius sideways, so the
-- lobby far away is never affected). Players
-- who die on the map during a round (or in Sandbox) come back on one of its spawn points instead
-- of in the lobby, keeping their role. Respawn delay: Config.Game.RespawnTime.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local MapService = require(script.Parent.MapService)
local Participants = require(script.Parent.Participants)

local MapRespawn = {}

local diedOnMap: { [Player]: boolean } = {}

-- Should this player come back on the map rather than in the lobby?
local function belongsOnMap(player: Player): boolean
	local phase = GameState.getPhase()
	if phase == "Sandbox" then
		return true
	end
	return Participants.isAlive(player)
		and (phase == "Intro" or phase == "Playing" or phase == "Results")
end

local function placeOnMap(character: Model)
	local map = MapService.active()
	if not map then
		return
	end
	local points = MapService.spawnPoints(map)
	if #points == 0 then
		return
	end
	local point = points[math.random(#points)]
	character:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		if diedOnMap[player] then
			diedOnMap[player] = nil
			if belongsOnMap(player) then
				character:WaitForChild("HumanoidRootPart", 5)
				placeOnMap(character)
			end
		end
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				if MapService.active() and belongsOnMap(player) then
					diedOnMap[player] = true
				end
			end)
		end
	end)
end

function MapRespawn.start()
	Players.RespawnTime = Config.Game.RespawnTime
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		diedOnMap[player] = nil
	end)

	-- Kill anyone who fell below the map's KillHeight.
	RunService.Heartbeat:Connect(function()
		local map = MapService.active()
		local killHeight = map and map:GetAttribute("KillHeight")
		if not map or type(killHeight) ~= "number" then
			return
		end
		local center = map:GetPivot().Position
		local radius = Config.Game.KillRadius
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 then
				continue
			end
			local position = root.Position
			local sideways = Vector2.new(position.X - center.X, position.Z - center.Z).Magnitude
			if position.Y < killHeight and sideways < radius then
				humanoid.Health = 0
			end
		end
	end)
end

return MapRespawn
