--!strict
-- Hold Config.Sprint.Key to run faster. Runs on the client so it responds instantly.
-- Also the one place that sets the camera's field of view: Config.Camera.FieldOfView in third
-- person, Config.FirstPerson.FieldOfViewAcross (degrees across, turned into Roblox's top-to-bottom
-- angle for your screen's shape) in first person, plus Config.Sprint.FovBoost while sprinting,
-- eased every frame. Leaves the camera alone while the Locker's preview has it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local Sprint = {}

local sprinting = false

function Sprint.isSprinting(): boolean
	return sprinting
end

-- The walk speed you should have right now: your role's speed (Config.Speed), times the sprint
-- bonus while sprinting. Moves that change your speed (like crouch) put this back when done.
function Sprint.targetSpeed(): number
	local role = Players.LocalPlayer:GetAttribute("Role")
	local base = if role == "It" then Config.Speed.It else Config.Speed.Runner
	return if sprinting then base * Config.Sprint.Multiplier else base
end

-- The top-to-bottom angle that shows `across` degrees left to right on a screen this shape.
local function verticalFov(across: number, aspect: number): number
	return math.deg(2 * math.atan(math.tan(math.rad(across) / 2) / aspect))
end

function Sprint.start()
	local player = Players.LocalPlayer
	local baseSpeed = 0

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if camera.CameraType == Enum.CameraType.Scriptable then
			return -- the Locker's preview sets its own
		end
		local fov = Config.Camera.FieldOfView
		if ViewMode.isFirstPerson() then
			local view = camera.ViewportSize
			local aspect = if view.Y > 0 then view.X / view.Y else 16 / 9
			fov = verticalFov(Config.FirstPerson.FieldOfViewAcross, aspect)
		end
		if sprinting then
			fov += Config.Sprint.FovBoost
		end
		fov = math.clamp(fov, 1, 120) -- Roblox's limits
		-- Ease about 99% of the way there in FovTime.
		local rate = 1 - math.exp(-4.6 * dt / math.max(Config.Sprint.FovTime, 0.01))
		camera.FieldOfView += (fov - camera.FieldOfView) * rate
	end)

	local function humanoid(): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function stop()
		if not sprinting then
			return
		end
		sprinting = false
		local hum = humanoid()
		if hum and hum.WalkSpeed > 0 then
			hum.WalkSpeed = baseSpeed
		end
	end

	local function begin()
		local hum = humanoid()
		-- Frozen players (WalkSpeed 0) can't sprint, and neither can crouched ones.
		if sprinting or not hum or hum.WalkSpeed <= 0 or MoveState.busy == "Crouch" then
			return
		end
		sprinting = true
		baseSpeed = hum.WalkSpeed
		hum.WalkSpeed = baseSpeed * Config.Sprint.Multiplier
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.Sprint.Key then
			begin()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Config.Sprint.Key then
			stop()
		end
	end)
	-- A new character starts at its normal speed.
	player.CharacterAdded:Connect(function()
		sprinting = false
	end)
end

return Sprint
