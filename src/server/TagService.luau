--!strict
-- Tagging. It left-clicks to swing (client/TagSwing sends a TagSwing remote); the server checks
-- the swing is allowed (the sender is It, not frozen, off cooldown), tells every client to play
-- the swipe, and tags the nearest Runner within Config.Tag.Range. Misses still swing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local Remotes = require(Shared.Remotes)
local Leaderstats = require(script.Parent.Leaderstats)
local Roles = require(script.Parent.Roles)

local TagService = {}

local lastSwing: { [Player]: number } = {}

-- Returns the player's root part only if their character is alive.
local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tag(tagger: Player, tagged: Player)
	Roles.set(tagger, "Runner")
	Roles.set(tagged, "It")
	Roles.freeze(tagged, Config.Tag.FreezeTime)
	Leaderstats.add(tagger, "Tags", 1)
	GameState.setStatus(`{tagger.DisplayName} tagged {tagged.DisplayName}!`)
end

-- The nearest Runner within reach of `itRoot`, if any.
local function nearestRunner(it: Player, itRoot: BasePart): Player?
	local best: Player? = nil
	local bestDistance = Config.Tag.Range
	for _, other in Players:GetPlayers() do
		if other ~= it and Roles.get(other) == "Runner" then
			local root = aliveRoot(other)
			local distance = root and (root.Position - itRoot.Position).Magnitude
			if distance and distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

local function onSwing(player: Player)
	-- Only It can swing, not while frozen, and not faster than the cooldown allows.
	if Roles.get(player) ~= "It" or Roles.isFrozen(player) then
		return
	end
	local now = os.clock()
	if now - (lastSwing[player] or -math.huge) < Config.Tag.Cooldown then
		return
	end
	lastSwing[player] = now
	local root = aliveRoot(player)
	if not root then
		return
	end
	Remotes.get("TagSwingPlayed"):FireAllClients(player)
	local target = nearestRunner(player, root)
	if target then
		tag(player, target)
	end
end

function TagService.start()
	Remotes.get("TagSwing").OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return TagService
