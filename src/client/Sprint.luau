--!strict
-- Hold Config.Sprint.Key to run faster. Runs on the client so it responds instantly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

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

function Sprint.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local baseFov = camera.FieldOfView

	local baseSpeed = 0

	local function easeFov(target: number)
		local info = TweenInfo.new(Config.Sprint.FovTime, Enum.EasingStyle.Quad)
		TweenService:Create(camera, info, { FieldOfView = target }):Play()
	end

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
		easeFov(baseFov)
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
		easeFov(baseFov + Config.Sprint.FovBoost)
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
		easeFov(baseFov)
	end)
end

return Sprint
