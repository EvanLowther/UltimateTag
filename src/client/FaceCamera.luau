--!strict
-- Your body always faces where you're looking (left and right only), like Apex: in first and
-- third person, standing, running and during every move. Roblox's own turning
-- (Humanoid.AutoRotate) is switched off for good, and this sets the facing every frame.
-- Movement keys already follow the camera, so moving and looking always line up.
local RunService = game:GetService("RunService")

local MoveState = require(script.Parent.MoveState)

local FaceCamera = {}

function FaceCamera.start()
	local camera = workspace.CurrentCamera
	-- After the camera updates, so the body matches this frame's view.
	RunService:BindToRenderStep("FaceCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local parts = MoveState.parts()
		if not parts then
			return
		end
		parts.humanoid.AutoRotate = false
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		local root = parts.root
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end)
end

return FaceCamera
