--!strict
-- Character settings the moves need:
--   Roblox's FallingDown and Ragdoll states kick in when physics shoves the body hard (vaults
--   and slides do) and make you topple. Both are off.
--   AutomaticScalingEnabled is off: with it on, Roblox's Animate script treats a lowered hip
--   height (crouch, slide, vault) as short legs and speeds the run animation up, and keeps
--   that speed after you stand until your running speed changes.
local Players = game:GetService("Players")

local Upright = {}

function Upright.start()
	local player = Players.LocalPlayer
	local function setup(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid.AutomaticScalingEnabled = false
	end
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
end

return Upright
