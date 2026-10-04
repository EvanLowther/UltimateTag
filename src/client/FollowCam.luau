--!strict
-- The third-person camera: a follow cam that never goes through walls.
--   Roblox's camera still handles input (mouse, touch, gamepad, zoom). With Config.Camera.Follow
--   it's in Follow mode, so it swings round behind you as you run.
--   Every frame, right after Roblox places the camera, this sweeps a sphere
--   (Config.Camera.CollisionRadius) from the focus point out to the camera. If anything solid
--   is in the way, the camera moves in to just in front of it at once, and eases back out when
--   the way is clear (ZoomOutRate), so walls and ceilings never come between you and it. The
--   focus point is kept under ceilings too, and your own character fades when the camera is
--   pushed right up to it. First person is left alone (FirstPersonBody handles that).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ViewMode = require(script.Parent.ViewMode)

local FollowCam = {}

local MIN_DISTANCE = 0.5 -- closest the camera is pushed to the focus point

-- Fades a character out as the camera gets within `fadeDistance` of the focus.
local function setFade(character: Instance, amount: number)
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = amount
		end
	end
end

function FollowCam.start()
	local player = Players.LocalPlayer
	local settings = Config.Camera
	if settings.Follow then
		-- Also set on StarterPlayer in default.project.json; this covers a changed Config.
		pcall(function()
			player.DevComputerCameraMode = Enum.DevComputerCameraMovementMode.Follow
			player.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.Follow
		end)
	end

	local camera = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- only solid things block the camera
	local shown = math.huge -- the distance used last frame (eases back out after a wall)
	local faded: Instance? = nil -- the character we faded, to restore it

	local function unfade()
		if faded then
			setFade(faded, 0)
			faded = nil
		end
	end

	-- After Roblox's camera (Camera priority); the camera kick only turns it in place after this.
	RunService:BindToRenderStep("FollowCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local subject = camera.CameraSubject
		local humanoid = if subject and subject:IsA("Humanoid") then subject else nil
		local root = humanoid and humanoid.RootPart
		if ViewMode.isFirstPerson() or not humanoid or not root then
			shown = math.huge
			unfade()
			return
		end

		-- Characters never block the camera.
		local ignore = {}
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		params.FilterDescendantsInstances = ignore
		local radius = settings.CollisionRadius

		-- Keep the focus point below a low ceiling (it sits above the body).
		local focus = camera.Focus.Position
		local rise = focus - root.Position
		if rise.Magnitude > 0.01 then
			local ceiling = workspace:Spherecast(root.Position, radius, rise, params)
			if ceiling then
				focus = root.Position + rise.Unit * math.max(ceiling.Distance - 0.05, 0)
			end
		end

		local offset = camera.CFrame.Position - focus
		local wanted = offset.Magnitude
		if wanted < MIN_DISTANCE then
			shown = wanted
			return
		end
		local direction = offset.Unit
		local blocked = workspace:Spherecast(focus, radius, direction * wanted, params)
		local allowed = if blocked then math.max(blocked.Distance, MIN_DISTANCE) else wanted
		shown = if allowed < shown
			then allowed
			else math.min(allowed, shown + settings.ZoomOutRate * dt)

		-- Same view direction, moved in along the line to the focus.
		camera.CFrame = camera.CFrame.Rotation + (focus + direction * shown)

		-- Your own character fades out when the camera is pushed right up against it.
		local character = humanoid.Parent
		if character == player.Character and shown < settings.FadeDistance then
			local amount = 1 - (shown - MIN_DISTANCE) / (settings.FadeDistance - MIN_DISTANCE)
			setFade(character :: Instance, math.clamp(amount, 0, 1))
			faded = character
		else
			unfade()
		end
	end)
end

return FollowCam
