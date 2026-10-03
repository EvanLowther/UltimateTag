--!strict
-- Lets you see your own body in first person. Roblox hides the whole character when the camera
-- is zoomed in; this shows the torso and legs again (the head stays hidden, and the arms are
-- replaced by the Viewmodel arms). The camera also follows your head as the animations move it,
-- so a slide, crouch or climb moves your view naturally, and it sits a little ahead of the
-- chest (Config.Camera.BodyForward) so you never look out from inside your body.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local FirstPersonBody = {}

local VISIBLE = {
	LowerTorso = true,
	UpperTorso = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

function FirstPersonBody.start()
	local player = Players.LocalPlayer
	local settings = Config.Camera
	local visibleParts: { BasePart } = {}
	local restHead: Vector3? = nil -- where the head sits relative to the root when standing still
	local offset = Vector3.zero
	local wasFirstPerson = ViewMode.isFirstPerson()

	local function setup(character: Model)
		table.clear(visibleParts)
		restHead = nil
		for _, name in { "LowerTorso", "UpperTorso", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } do
			character:WaitForChild(name)
		end
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") and VISIBLE[part.Name] then
				table.insert(visibleParts, part)
			end
		end
	end
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end

	-- Before the camera updates: move the camera with the head.
	RunService:BindToRenderStep(
		"FirstPersonHead",
		Enum.RenderPriority.Camera.Value - 1,
		function(dt)
			local parts = MoveState.parts()
			local firstPerson = ViewMode.isFirstPerson()
			if not firstPerson then
				if wasFirstPerson and parts then
					parts.humanoid.CameraOffset = Vector3.zero
				end
				wasFirstPerson = false
				return
			end
			wasFirstPerson = true
			if not parts then
				return
			end
			local head = parts.character:FindFirstChild("Head")
			if not head or not head:IsA("BasePart") then
				return
			end
			local headLocal = parts.root.CFrame:PointToObjectSpace(head.Position)
			-- Learn the resting head position the first time you're standing still on the ground.
			if not restHead then
				local still = MoveState.flat(parts.root.AssemblyLinearVelocity).Magnitude < 0.5
				if MoveState.busy or not still or not MoveState.isGrounded(parts.humanoid) then
					return
				end
				restHead = headLocal
			end
			local target = (headLocal - (restHead :: Vector3))
				+ Vector3.new(0, 0, -settings.BodyForward)
			offset = offset:Lerp(target, 1 - math.exp(-settings.HeadFollow * dt))
			parts.humanoid.CameraOffset = offset
		end
	)

	-- After the camera updates (it hides the whole character in first person): show the body.
	RunService:BindToRenderStep("FirstPersonBody", Enum.RenderPriority.Camera.Value + 1, function()
		if not ViewMode.isFirstPerson() then
			return
		end
		for _, part in visibleParts do
			part.LocalTransparencyModifier = 0
		end
	end)
end

return FirstPersonBody
