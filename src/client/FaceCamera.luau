--!strict
-- Which way your body faces.
--   Third person (the default, like the reference video): your body turns toward the way you
--   run, using Roblox's own smooth turning (Humanoid.AutoRotate).
--   First person: your body faces where you look.
--   During a move that sets MoveState.faceDirection (climb faces the wall, wall run faces
--   along it, vault faces the hop), the body turns smoothly to that instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local FaceCamera = {}

function FaceCamera.start()
	local camera = workspace.CurrentCamera
	local turnRate = Config.Camera.TurnRate
	-- After the camera updates, so the body matches this frame's view.
	RunService:BindToRenderStep("FaceCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local parts = MoveState.parts()
		if not parts then
			return
		end
		local hum, root = parts.humanoid, parts.root
		local direction = MoveState.faceDirection
		if not direction and ViewMode.isFirstPerson() then
			direction = camera.CFrame.LookVector
		end
		if not direction then
			hum.AutoRotate = true -- third person, no move: Roblox turns you toward your running
			return
		end
		hum.AutoRotate = false
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		-- Turn smoothly (instantly in first person, where the body is hidden anyway).
		local target = CFrame.lookAt(root.Position, root.Position + flat)
		local blend = if ViewMode.isFirstPerson() then 1 else 1 - math.exp(-turnRate * dt)
		root.CFrame = root.CFrame:Lerp(target, blend)
	end)
end

return FaceCamera
