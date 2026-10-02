--!strict
-- The slide animation. Builds two keyframed animations from Config.Slide.Poses and plays them
-- through the character's Animator, the same way Roblox plays the run animation:
--   Slide:   drop (frame 2) -> slide pose (frames 3 to 5), then holds until the slide ends.
--   Recover: slide pose -> lunge (frame 6) -> crouch (frame 7) -> standing (frame 8).
-- Also sinks the hips (so you fit under low bars) and dips the camera on a smooth blend.
-- The animations are registered on this client only, so other players don't see them yet.
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Pose = {
	play: () -> (),
	stop: () -> (),
	standingHip: number,
	slideHip: number,
}

type Angles = { [string]: Vector3 }
type Tree = { [string]: Tree }

local SlidePose = {}

local HOLD_MARKER = "Hold" -- keyframe name where the slide animation freezes
local FADE = 0.05 -- seconds to cross-fade between animations

-- R15 body parts, nested the way their joints connect.
local R15: Tree = {
	HumanoidRootPart = {
		LowerTorso = {
			UpperTorso = {
				Head = {},
				RightUpperArm = { RightLowerArm = { RightHand = {} } },
				LeftUpperArm = { LeftLowerArm = { LeftHand = {} } },
			},
			RightUpperLeg = { RightLowerLeg = { RightFoot = {} } },
			LeftUpperLeg = { LeftLowerLeg = { LeftFoot = {} } },
		},
	},
}

local function addPoses(parent: Instance, tree: Tree, angles: Angles)
	for name, children in tree do
		local degrees = angles[name] or Vector3.zero
		local pose = Instance.new("Pose")
		pose.Name = name
		pose.CFrame = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
		pose.EasingStyle = Enum.PoseEasingStyle.Cubic
		pose.EasingDirection = Enum.PoseEasingDirection.InOut
		pose.Parent = parent
		addPoses(pose, children, angles)
	end
end

-- Turns a list of { time, pose, name? } into a registered animation the Animator can play.
local function makeAnimation(keys: { { time: number, angles: Angles, name: string? } }): Animation
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action4
	for _, key in keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.time
		keyframe.Name = key.name or "Keyframe"
		addPoses(keyframe, R15, key.angles)
		keyframe.Parent = sequence
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = AnimationClipProvider:RegisterAnimationClip(sequence)
	return animation
end

local slideAnimation: Animation? = nil
local recoverAnimation: Animation? = nil

-- Builds both animations once and reuses them for every character.
local function animations(): (Animation, Animation)
	if not slideAnimation or not recoverAnimation then
		local settings = Config.Slide
		local poses = settings.Poses :: { [string]: Angles }
		slideAnimation = makeAnimation({
			{ time = 0, angles = poses.Drop },
			{ time = settings.DropTime, angles = poses.Slide, name = HOLD_MARKER },
			{ time = settings.DropTime + 0.1, angles = poses.Slide },
		})
		recoverAnimation = makeAnimation({
			{ time = 0, angles = poses.Slide },
			{ time = settings.RecoverLungeTime, angles = poses.Lunge },
			{ time = settings.RecoverCrouchTime, angles = poses.Crouch },
			{ time = settings.RecoverStandTime, angles = {} },
		})
	end
	return slideAnimation :: Animation, recoverAnimation :: Animation
end

function SlidePose.attach(_character: Model, humanoid: Humanoid): Pose
	local settings = Config.Slide
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local slide, recover = animations()
	local slideTrack = (animator :: Animator):LoadAnimation(slide)
	local recoverTrack = (animator :: Animator):LoadAnimation(recover)

	-- Freeze on the slide pose until the slide ends.
	slideTrack.KeyframeReached:Connect(function(name)
		if name == HOLD_MARKER then
			slideTrack:AdjustSpeed(0)
		end
	end)

	local standingHip = humanoid.HipHeight
	local slideHip = standingHip * settings.HipHeightFactor
	local weight = 0 -- 0 = standing height, 1 = full slide height
	local goal = 0
	local connection: RBXScriptConnection? = nil

	-- Eases the hips and camera between standing and sliding height.
	local function step(dt: number)
		if not humanoid.Parent then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			return
		end
		if goal > weight then
			weight = math.min(weight + dt / settings.DropTime, 1)
		else
			weight = math.max(weight - dt / settings.RiseTime, 0)
		end
		local w = weight * weight * (3 - 2 * weight) -- smoothstep, so it eases in and out
		humanoid.HipHeight = standingHip + (slideHip - standingHip) * w
		humanoid.CameraOffset = Vector3.new(0, -settings.CameraDip * w, 0)

		if weight == 0 and goal == 0 and connection then
			connection:Disconnect()
			connection = nil
		end
	end

	local function blendTo(newGoal: number)
		goal = newGoal
		if not connection then
			connection = RunService.PreSimulation:Connect(step)
		end
	end

	return {
		play = function()
			recoverTrack:Stop(FADE)
			slideTrack:Play(FADE)
			slideTrack:AdjustSpeed(1)
			blendTo(1)
		end,
		stop = function()
			slideTrack:Stop(FADE)
			recoverTrack:Play(FADE)
			blendTo(0)
		end,
		standingHip = standingHip,
		slideHip = slideHip,
	}
end

return SlidePose
