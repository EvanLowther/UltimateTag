--!strict
-- First or third person. The game is first person; Config.Camera.ToggleKey (V) switches to
-- third person and back for testing, if Config.Camera.AllowToggle is on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ViewMode = {}

local firstPerson = Config.Camera.StartFirstPerson

function ViewMode.isFirstPerson(): boolean
	return firstPerson
end

local function apply()
	local player = Players.LocalPlayer
	if firstPerson then
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

function ViewMode.start()
	apply()
	if not Config.Camera.AllowToggle then
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
