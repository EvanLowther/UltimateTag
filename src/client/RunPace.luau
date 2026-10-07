--!strict
-- Keeps Roblox's walk and run animations at a sensible pace. Roblox's Animate script sets their
-- speed from your movement speed, but only on certain events, so a fast moment (a launch, a
-- boost landing) can leave the run animation stuck playing several times too fast. Every frame
-- this sets the pace from your actual ground speed instead, clamped to Config.RunPace limits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

local RunPace = {}

-- The Animation names inside Roblox's Animate script for walking and running.
local LOCOMOTION = { WalkAnim = true, RunAnim = true }

function RunPace.start()
	local settings = Config.RunPace
	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		if not parts then
			return
		end
		local animator = parts.humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end
		local speed = MoveState.flat(parts.root.AssemblyLinearVelocity).Magnitude
		local pace = math.clamp(speed / settings.NormalSpeed, settings.MinPace, settings.MaxPace)
		for _, track in animator:GetPlayingAnimationTracks() do
			local animation = track.Animation
			if animation and LOCOMOTION[animation.Name] then
				track:AdjustSpeed(pace)
			end
		end
	end)
end

return RunPace
