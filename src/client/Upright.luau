--!strict
-- Keeps the local character from tripping over. Roblox's FallingDown and Ragdoll states kick in
-- when physics shoves the body hard (vaults and slides do), and make you topple. Both are off.
local Players = game:GetService("Players")

local Upright = {}

function Upright.start()
	local player = Players.LocalPlayer
	local function setup(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
end

return Upright
