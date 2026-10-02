--!strict
-- Builds keyframed animations in code and loads them on a character's Animator.
-- A pose is degrees of rotation per R15 body part, relative to standing (see Config.Slide.Poses
-- for which way each axis turns). Animations are registered on this client only, so other
-- players don't see them yet.
local AnimationClipProvider = game:GetService("AnimationClipProvider")

export type Angles = { [string]: Vector3 }
export type Key = { time: number, angles: Angles, name: string? }

type Tree = { [string]: Tree }

local AnimationBuilder = {}

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

-- Turns a list of keys into a registered animation. A key with a name fires KeyframeReached.
function AnimationBuilder.make(keys: { Key }): Animation
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

function AnimationBuilder.load(humanoid: Humanoid, animation: Animation): AnimationTrack
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return (animator :: Animator):LoadAnimation(animation)
end

return AnimationBuilder
