--!strict
-- Forces every player onto an R15 body (the slide pose needs R15 joints). A plain R15 block
-- rig becomes StarterPlayer.StarterCharacter. If Config.Avatar.UseOwnAvatar is on, each
-- character is then dressed in the player's own avatar. Otherwise everyone stays the classic
-- block avatar, which makes animations easy to see.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)

local Avatar = {}

local MAX_RESPAWNS = 3 -- stop trying after this many, so a failure can't loop forever
local respawns: { [Player]: number } = {}

local function dress(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if not character.Parent then
		character.AncestryChanged:Wait()
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	if ok and description and humanoid.Parent then
		humanoid:ApplyDescription(description)
	end
end

-- Respawns a character that isn't R15 (for example one that loaded before the rig was ready).
local function check(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		local tries = (respawns[player] or 0) + 1
		respawns[player] = tries
		if tries <= MAX_RESPAWNS then
			task.defer(player.LoadCharacter, player)
		else
			warn(`[Avatar] {player.Name} is still not R15 after {MAX_RESPAWNS} respawns`)
		end
		return
	end
	if Config.Avatar.UseOwnAvatar then
		dress(player, character)
	end
end

-- The classic block look: no clothes or accessories, blocky proportions, 2012 colors.
local function classicDescription(): HumanoidDescription
	local colors = Config.Avatar
	local description = Instance.new("HumanoidDescription")
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeadColor = colors.HeadColor
	description.TorsoColor = colors.TorsoColor
	description.LeftArmColor = colors.ArmColor
	description.RightArmColor = colors.ArmColor
	description.LeftLegColor = colors.LegColor
	description.RightLegColor = colors.LegColor
	return description
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		check(player, character)
	end)
	if player.Character then
		task.spawn(check, player, player.Character)
	end
end

function Avatar.start()
	local rig =
		Players:CreateHumanoidModelFromDescription(classicDescription(), Enum.HumanoidRigType.R15)
	rig.Name = "StarterCharacter"
	rig.Parent = StarterPlayer

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		respawns[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Avatar
