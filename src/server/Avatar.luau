--!strict
-- Gives every player the game's body as StarterPlayer.StarterCharacter. Normally that's the
-- BodyRig (Config.Body). With Config.Body.Enabled off it's a classic R15 block rig instead, and
-- if Config.Avatar.UseOwnAvatar is on, those are dressed in the player's own avatar.
-- Any character that spawns without R15 joints is respawned (the moves need them).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local BodyRig = require(ReplicatedStorage.Shared.BodyRig)
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
	if Config.Avatar.UseOwnAvatar and not Config.Body.Enabled then
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
	local classic =
		Players:CreateHumanoidModelFromDescription(classicDescription(), Enum.HumanoidRigType.R15)
	local rig = classic
	if Config.Body.Enabled then
		rig = BodyRig.build()
		-- Borrow Roblox's standard Animate script (run, jump, fall animations) from the classic rig.
		local animate = classic:FindFirstChild("Animate")
		if animate then
			animate.Parent = rig
		end
		classic:Destroy()
	end
	rig.Name = "StarterCharacter"
	-- Stops Roblox's Animate script from speeding up the run animation whenever a move lowers
	-- the hips (it reads hip height as leg length while this is on). See client/Upright.
	local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
	if rigHumanoid then
		rigHumanoid.AutomaticScalingEnabled = false
	end
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
