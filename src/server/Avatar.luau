--!strict
-- Forces every player onto an R15 body (the slide pose needs R15 joints). A blank R15 rig
-- becomes StarterPlayer.StarterCharacter, then each character is dressed in the player's
-- own avatar. Test players with no real account (Studio's Local Server) keep the blank look.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

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
	dress(player, character)
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
	local rig = Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
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
