--!strict
-- Forces every player onto an R15 body (the slide pose needs R15 joints). A blank R15 rig
-- becomes StarterPlayer.StarterCharacter, then each character is dressed in the player's
-- own avatar. Test players with no real account (Studio's Local Server) keep the blank look.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Avatar = {}

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

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		dress(player, character)
	end)
end

function Avatar.start()
	local rig = Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
	rig.Name = "StarterCharacter"
	rig.Parent = StarterPlayer

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		-- Anyone who spawned before the rig existed gets respawned on it.
		if player.Character then
			player:LoadCharacter()
		end
	end
end

return Avatar
