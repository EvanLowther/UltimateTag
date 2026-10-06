--!strict
-- Left click (or the gamepad right trigger) while you're It swings to tag. Your swipe plays
-- straight away, the first-person arm jabs, and the server is asked to tag (server/TagService
-- decides if it hit). When anyone swings, the server tells every client, and each one plays
-- the swipe on that player's character, so everyone sees it (the swipe is built in code, so
-- it has to be played on each screen).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local MoveState = require(script.Parent.MoveState)

local TagSwing = {}

local animation: Animation? = nil

-- Wind up, reach forward, hold the reach; the track is faded out after SwingTime.
local function getAnimation(): Animation
	if not animation then
		local settings = Config.Tag
		local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
		animation = AnimationBuilder.make({
			{ time = 0, angles = poses.WindUp, ease = "In" },
			{ time = settings.SwingTime * 0.3, angles = poses.Reach, ease = "Out" },
			{ time = settings.SwingTime + 1, angles = poses.Reach },
		}, true)
	end
	return animation :: Animation
end

-- Plays the swipe on a humanoid (on this screen): any player's, or the Locker's preview.
function TagSwing.swipe(humanoid: Humanoid)
	local track = AnimationBuilder.load(humanoid, getAnimation())
	track:Play(0.04)
	task.delay(Config.Tag.SwingTime, function()
		track:Stop(0.15)
		task.delay(0.3, track.Destroy, track) -- after the fade-out finishes
	end)
end

-- Plays the swipe on any player's character.
local function playSwipe(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	TagSwing.swipe(humanoid)
end

function TagSwing.start()
	local player = Players.LocalPlayer
	local settings = Config.Tag
	local swingRemote = Remotes.get("TagSwing")
	local lastSwing = -math.huge

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.ButtonR2
		if not click or player:GetAttribute("Role") ~= "It" then
			return
		end
		local now = os.clock()
		if now - lastSwing < settings.Cooldown then
			return
		end
		lastSwing = now
		MoveState.tagTime = now
		playSwipe(player) -- right away, no waiting for the server
		swingRemote:FireServer()
	end)

	-- Other players' swings (ours already played).
	Remotes.get("TagSwingPlayed").OnClientEvent:Connect(function(swinger: Player)
		if swinger ~= player then
			playSwipe(swinger)
		end
	end)
end

return TagSwing
