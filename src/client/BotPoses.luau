--!strict
-- Bots slide on the server (server/BotBrain lowers them and sets their character's BotMove
-- attribute to "Slide"); this plays the slide pose on them on each screen, built from the same
-- keys as the player's slide (Config.Slide.Poses: the drop into the held slide). Their running,
-- jumping and climbing come from the server's Animator like any animation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Contestant = require(Shared:WaitForChild("Contestant"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)

local BotPoses = {}

local slideAnimation: Animation? = nil

local function getSlide(): Animation
	if not slideAnimation then
		local settings = Config.Slide
		local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
		slideAnimation = AnimationBuilder.make({
			{ time = 0, angles = poses.Drop },
			{ time = settings.DropTime, angles = poses.Slide },
			{ time = settings.DropTime + 30, angles = poses.Slide },
		})
	end
	return slideAnimation :: Animation
end

local function watchCharacter(character: Model)
	local track: AnimationTrack? = nil
	local function update()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local sliding = character:GetAttribute("BotMove") == "Slide"
		if sliding and humanoid then
			if not track then
				track = AnimationBuilder.load(humanoid, getSlide())
			end
			local active = track :: AnimationTrack
			if not active.IsPlaying then
				active:Play(0.05)
			end
		elseif track and track.IsPlaying then
			track:Stop(0.15)
		end
	end
	character:GetAttributeChangedSignal("BotMove"):Connect(update)
	update()
end

local function watchBot(bot: Instance)
	if not bot:IsA("ObjectValue") then
		return
	end
	local function changed()
		local character = bot.Value
		if character and character:IsA("Model") then
			watchCharacter(character)
		end
	end
	bot:GetPropertyChangedSignal("Value"):Connect(changed)
	changed()
end

function BotPoses.start()
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(Contestant.FolderName)
		folder.ChildAdded:Connect(watchBot)
		for _, bot in folder:GetChildren() do
			watchBot(bot)
		end
	end)
end

return BotPoses
