--!strict
-- First or third person. In a live server the game is first person only. In Studio it starts as
-- Config.Camera.StartFirstPerson says and Config.Camera.ToggleKey (V) switches to the other view
-- and back for testing (if Config.Camera.AllowToggle is on).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ViewMode = {}

local studio = RunService:IsStudio()
local firstPerson = if studio then Config.Camera.StartFirstPerson else true
local suspended = false -- something else has the camera (the Locker's preview)

function ViewMode.isFirstPerson(): boolean
	return firstPerson and not suspended
end

local function apply()
	local player = Players.LocalPlayer
	if firstPerson and not suspended then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- Push the camera out, then let the player zoom freely again.
		player.CameraMinZoomDistance = Config.Camera.ThirdPersonDistance
		task.delay(0.1, function()
			player.CameraMinZoomDistance = 0.5
		end)
	end
end

-- Re-applies the camera mode (after something else, like spectating, changed it).
function ViewMode.apply()
	apply()
end

-- While something else owns the camera (the Locker's preview), report third person so the
-- first-person arms and body step aside; false puts things back.
function ViewMode.suspend(on: boolean)
	if suspended ~= on then
		suspended = on
		apply()
	end
end

function ViewMode.start()
	apply()
	if not studio or not Config.Camera.AllowToggle then
		return
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.Camera.ToggleKey then
			firstPerson = not firstPerson
			apply()
		end
	end)
end

return ViewMode
