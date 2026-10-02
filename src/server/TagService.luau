--!strict
-- Detects tags: It tags any Runner who gets within Config.Tag.Range.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local GameState = require(Shared.GameState)
local Leaderstats = require(script.Parent.Leaderstats)
local Roles = require(script.Parent.Roles)

local TagService = {}

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

local function step()
	local it = Roles.getIt()
	if not it or Roles.isFrozen(it) then
		return
	end
	local itRoot = aliveRoot(it)
	if not itRoot then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= it and Roles.get(other) == "Runner" then
			local root = aliveRoot(other)
			if root and (root.Position - itRoot.Position).Magnitude <= Config.Tag.Range then
				tag(it, other)
				return
			end
		end
	end
end

function TagService.start()
	RunService.Heartbeat:Connect(step)
end

return TagService
