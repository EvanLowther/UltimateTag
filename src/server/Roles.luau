--!strict
-- Who is It and who is a Runner. Stored as the "Role" attribute on each Player so clients can read it.
-- Also applies each role's speed and look to the character, again after every respawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)

export type Role = "It" | "Runner"

local HIGHLIGHT_NAME = "ItHighlight"

local Roles = {}

local frozenUntil: { [Player]: number } = {}

function Roles.get(player: Player): Role?
	return player:GetAttribute("Role") :: Role?
end

-- The first It found (the sandbox only ever has one).
function Roles.getIt(): Player?
	for _, player in Players:GetPlayers() do
		if Roles.get(player) == "It" then
			return player
		end
	end
	return nil
end

-- Every player who is It right now (a game round can have several).
function Roles.getIts(): { Player }
	local its = {}
	for _, player in Players:GetPlayers() do
		if Roles.get(player) == "It" then
			table.insert(its, player)
		end
	end
	return its
end

function Roles.isFrozen(player: Player): boolean
	local untilTime = frozenUntil[player]
	return untilTime ~= nil and os.clock() < untilTime
end

-- Pushes the player's current role and frozen state onto their character.
local function apply(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local role = Roles.get(player)
	local frozen = Roles.isFrozen(player)

	humanoid.WalkSpeed = if frozen
		then 0
		elseif role == "It" then Config.Speed.It
		else Config.Speed.Runner
	humanoid.JumpPower = if frozen then 0 else StarterPlayer.CharacterJumpPower
	humanoid.JumpHeight = if frozen then 0 else StarterPlayer.CharacterJumpHeight

	local highlight = character:FindFirstChild(HIGHLIGHT_NAME)
	if role == "It" and not highlight then
		local new = Instance.new("Highlight")
		new.Name = HIGHLIGHT_NAME
		new.FillColor = Config.Colors.It
		new.FillTransparency = 0.5
		new.OutlineColor = Config.Colors.Text
		new.Parent = character
	elseif role ~= "It" and highlight then
		highlight:Destroy()
	end
end

function Roles.set(player: Player, role: Role?)
	player:SetAttribute("Role", role)
	apply(player)
end

-- Freezes the player in place for `seconds`. Frozen players can't move, jump, or tag.
function Roles.freeze(player: Player, seconds: number)
	local untilTime = os.clock() + seconds
	frozenUntil[player] = untilTime
	apply(player)
	task.delay(seconds, function()
		if frozenUntil[player] == untilTime then
			frozenUntil[player] = nil
			apply(player)
		end
	end)
end

function Roles.unfreeze(player: Player)
	frozenUntil[player] = nil
	apply(player)
end

-- Re-applies everyone's role (after Config.Speed changes, from the dev panel).
function Roles.refreshAll()
	for _, player in Players:GetPlayers() do
		apply(player)
	end
end

function Roles.clearAll()
	for _, player in Players:GetPlayers() do
		frozenUntil[player] = nil
		Roles.set(player, nil)
	end
end

function Roles.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			apply(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		frozenUntil[player] = nil
	end)
end

return Roles
