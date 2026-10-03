--!strict
-- Speed trails, like the parkour reference: thin white streaks off the hands and feet while
-- you're moving fast or doing a move (Config.SpeedTrails). In first person only the feet trail,
-- so hand streaks don't smear across your view. Only you see them for now.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local SpeedTrails = {}

local LIMBS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

function SpeedTrails.start()
	local settings = Config.SpeedTrails
	if not settings.Enabled then
		return
	end
	local player = Players.LocalPlayer
	local trails: { [string]: Trail } = {}

	local function setup(character: Model)
		table.clear(trails)
		for _, name in LIMBS do
			local limb = character:WaitForChild(name, 5)
			if not limb or not limb:IsA("BasePart") then
				continue
			end
			-- A trail is drawn between two attachments; these sit at the ends of the hand or foot.
			local top = Instance.new("Attachment")
			top.Name = "TrailTop"
			top.Position = Vector3.new(0, settings.Width / 2, 0)
			top.Parent = limb
			local bottom = Instance.new("Attachment")
			bottom.Name = "TrailBottom"
			bottom.Position = Vector3.new(0, -settings.Width / 2, 0)
			bottom.Parent = limb
			local trail = Instance.new("Trail")
			trail.Attachment0 = top
			trail.Attachment1 = bottom
			trail.Lifetime = settings.Lifetime
			trail.Color = ColorSequence.new(settings.Color)
			trail.Transparency = NumberSequence.new(0.35, 1)
			trail.FaceCamera = true
			trail.MinLength = 0.05
			trail.Enabled = false
			trail.Parent = limb
			trails[name] = trail
		end
	end
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end

	local moves: { [string]: boolean } = {}
	for _, name in settings.Moves do
		moves[name] = true
	end

	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		local on = false
		if parts then
			local speed = parts.root.AssemblyLinearVelocity.Magnitude
			on = speed >= settings.MinSpeed
				or (MoveState.busy ~= nil and moves[MoveState.busy] == true)
		end
		local firstPerson = ViewMode.isFirstPerson()
		for name, trail in trails do
			local isHand = name == "LeftHand" or name == "RightHand"
			trail.Enabled = on and not (firstPerson and isHand)
		end
	end)
end

return SpeedTrails
