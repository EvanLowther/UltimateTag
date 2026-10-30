--!strict
-- Builds keyframed animations in code and loads them on a character's Animator.
-- A pose is degrees of rotation per R15 body part, relative to standing (see Config.Slide.Poses
-- for which way each axis turns). Animations are registered on this client only, so other
-- players don't see them yet.
local AnimationClipProvider = game:GetService("AnimationClipProvider")

export type Angles = { [string]: Vector3 }
-- `ease` shapes the motion from this key to the next: "Out" slows into the next pose (absorbing),
-- "In" speeds up into it (exploding), "InOut" (the default) does both, all cubic; "Linear" moves
-- at a steady pace.
export type Key = { time: number, angles: Angles, name: string?, ease: string? }

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

-- `only`: if given, just these parts are animated (weight 1); every other part has weight 0,
-- so whatever animation is playing underneath (running, falling) still moves it.
local EASE: { [string]: Enum.PoseEasingDirection } = {
	In = Enum.PoseEasingDirection.In,
	Out = Enum.PoseEasingDirection.Out,
	InOut = Enum.PoseEasingDirection.InOut,
}

local function addPoses(
	parent: Instance,
	tree: Tree,
	angles: Angles,
	only: { [string]: boolean }?,
	ease: Enum.PoseEasingDirection? -- nil: linear
)
	for name, children in tree do
		local degrees = angles[name] or Vector3.zero
		local pose = Instance.new("Pose")
		pose.Name = name
		pose.CFrame = CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
		pose.EasingStyle = if ease == nil
			then Enum.PoseEasingStyle.Linear
			else Enum.PoseEasingStyle.Cubic
		pose.EasingDirection = ease or Enum.PoseEasingDirection.In
		if only and not only[name] then
			pose.Weight = 0
		end
		pose.Parent = parent
		addPoses(pose, children, angles, only, ease)
	end
end

-- The same pose for the other side of the body: Left and Right parts swap, and sideways
-- rotations (Y and Z) flip.
function AnimationBuilder.mirror(angles: Angles): Angles
	local mirrored: Angles = {}
	for name, degrees in angles do
		local other = if name:sub(1, 4) == "Left"
			then "Right" .. name:sub(5)
			elseif name:sub(1, 5) == "Right" then "Left" .. name:sub(6)
			else name
		mirrored[other] = Vector3.new(degrees.X, -degrees.Y, -degrees.Z)
	end
	return mirrored
end

-- Turns a list of keys into a registered animation. A key with a name fires KeyframeReached.
-- With `partial`, only the parts named in the keys are animated; the rest keep whatever
-- animation is playing underneath. With `looped`, it repeats until stopped (make the last key
-- match the first so the loop is seamless).
function AnimationBuilder.make(keys: { Key }, partial: boolean?, looped: boolean?): Animation
	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = looped == true
	sequence.Priority = Enum.AnimationPriority.Action4
	local only: { [string]: boolean }? = nil
	if partial then
		local used = {}
		for _, key in keys do
			for name in key.angles do
				used[name] = true
			end
		end
		only = used
	end
	for _, key in keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.time
		keyframe.Name = key.name or "Keyframe"
		local ease = if key.ease == "Linear" then nil else EASE[key.ease or "InOut"]
		addPoses(keyframe, R15, key.angles, only, ease)
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
