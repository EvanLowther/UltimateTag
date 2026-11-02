--!strict
-- Builds keyframed animations in code and loads them on a character's Animator.
-- A pose is degrees of rotation per R15 body part, relative to standing (see Config.Slide.Poses
-- for which way each axis turns). Animations are on this client only, so other players don't
-- see them yet.
-- Roblox only lets a script register an animation it built in code (RegisterAnimationClip) inside
-- Studio, so in a published game that call throws. Then (or with Config.Animation.ForceSoftware)
-- the same keys are played by a small software animator that turns the body's Motor6D joints
-- itself every frame, behind the same track calls (Play, Stop, AdjustSpeed, IsPlaying, Looped,
-- KeyframeReached, Destroy). Animations that are real Roblox assets (the Animate script's idle
-- and run) always go through the Animator.
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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

-- One key of a clip played by the software animator: a rotation per body part.
type SoftKey = { time: number, name: string?, ease: string, poses: { [string]: CFrame } }
type Clip = { keys: { SoftKey }, length: number, looped: boolean }

local clips: { [Animation]: Clip } = setmetatable({}, { __mode = "k" }) :: any
local nativeWorks = true -- false once RegisterAnimationClip has thrown (it only works in Studio)

local PARTS: { string } = {}
local function collectParts(tree: Tree)
	for name, children in tree do
		if name ~= "HumanoidRootPart" then
			table.insert(PARTS, name)
		end
		collectParts(children)
	end
end
collectParts(R15)

local function ease(kind: string, a: number): number
	if kind == "Linear" then
		return a
	elseif kind == "In" then
		return a * a * a
	elseif kind == "Out" then
		return 1 - (1 - a) ^ 3
	end
	return if a < 0.5 then 4 * a * a * a else 1 - (-2 * a + 2) ^ 3 / 2
end

local function rotation(degrees: Vector3): CFrame
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

local function softClip(keys: { Key }, only: { [string]: boolean }?, looped: boolean): Clip
	local soft: { SoftKey } = {}
	for _, key in keys do
		local poses: { [string]: CFrame } = {}
		for _, name in PARTS do
			if not only or only[name] then
				poses[name] = rotation(key.angles[name] or Vector3.zero)
			end
		end
		table.insert(soft, {
			time = key.time,
			name = key.name,
			ease = key.ease or "InOut",
			poses = poses,
		})
	end
	return { keys = soft, length = soft[#soft].time, looped = looped }
end

-- Turns a list of keys into a registered animation. A key with a name fires KeyframeReached.
-- With `partial`, only the parts named in the keys are animated; the rest keep whatever
-- animation is playing underneath. With `looped`, it repeats until stopped (make the last key
-- match the first so the loop is seamless).
function AnimationBuilder.make(keys: { Key }, partial: boolean?, looped: boolean?): Animation
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
	local animation = Instance.new("Animation")
	if nativeWorks and not Config.Animation.ForceSoftware then
		local sequence = Instance.new("KeyframeSequence")
		sequence.Loop = looped == true
		sequence.Priority = Enum.AnimationPriority.Action4
		for _, key in keys do
			local keyframe = Instance.new("Keyframe")
			keyframe.Time = key.time
			keyframe.Name = key.name or "Keyframe"
			local easing = if key.ease == "Linear" then nil else EASE[key.ease or "InOut"]
			addPoses(keyframe, R15, key.angles, only, easing)
			keyframe.Parent = sequence
		end
		local ok, id = pcall(function()
			return AnimationClipProvider:RegisterAnimationClip(sequence)
		end)
		if ok then
			animation.AnimationId = id
			return animation
		end
		nativeWorks = false
	end
	clips[animation] = softClip(keys, only, looped == true)
	return animation
end

-- The software animator -----------------------------------------------------------------------

type Track = {
	[string]: any,
}

local playing: { Track } = {} -- tracks that are on or fading out, in the order they started
local savedBase: { [Motor6D]: CFrame } = {} -- what the Animator wrote, put back before it runs
local preAnimation: RBXScriptConnection? = nil
local preSimulation: RBXScriptConnection? = nil

local function sample(clip: Clip, time: number, name: string): CFrame?
	local keys = clip.keys
	local last = keys[#keys]
	if time >= last.time then
		return last.poses[name]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if time < b.time then
			local from, to = a.poses[name], b.poses[name]
			if not from or not to then
				return nil
			end
			local span = b.time - a.time
			local alpha = if span > 0 then math.clamp((time - a.time) / span, 0, 1) else 1
			return from:Lerp(to, ease(a.ease, alpha))
		end
	end
	return last.poses[name]
end

local function fireKeys(track: Track, from: number, to: number)
	local clip: Clip = track.clip
	for _, key in clip.keys do
		if key.name and key.name ~= "Keyframe" and key.time > from and key.time <= to then
			for _, callback in track.listeners do
				callback(key.name)
			end
		end
	end
end

local function restore()
	for joint, base in savedBase do
		if joint.Parent then
			joint.Transform = base
		end
	end
	table.clear(savedBase)
end

local function stepTracks(dt: number)
	for i = #playing, 1, -1 do
		local track = playing[i]
		local humanoid: Humanoid = track.humanoid
		if track.destroyed or not humanoid.Parent then
			table.remove(playing, i)
			continue
		end
		local clip: Clip = track.clip
		local before = track.time
		local after = before + dt * track.speed
		if track.speed > 0 then
			fireKeys(track, before, math.min(after, clip.length))
		end
		if after >= clip.length and clip.length > 0 then
			if track.Looped then
				after %= clip.length
				fireKeys(track, -1, after)
			else
				after = clip.length
				if track.IsPlaying then
					track.IsPlaying = false -- finished: fades out
					track.target = 0
					track.fade = 0.1
				end
			end
		end
		track.time = after
		-- Fade in or out.
		local target: number = track.target
		if track.weight ~= target then
			local fade: number = track.fade
			local step = if fade > 0 then dt / fade else 1
			track.weight = if track.weight < target
				then math.min(track.weight + step, target)
				else math.max(track.weight - step, target)
		end
		if track.weight <= 0 and target == 0 then
			table.remove(playing, i)
		end
	end
	for _, track in playing do
		local clip: Clip = track.clip
		local weight: number = track.weight
		if weight > 0 then
			for name, joint in track.joints :: { [string]: Motor6D } do
				local pose = sample(clip, track.time, name)
				if pose and joint.Parent then
					if savedBase[joint] == nil then
						savedBase[joint] = joint.Transform
					end
					joint.Transform = joint.Transform:Lerp(pose, weight)
				end
			end
		end
	end
	if #playing == 0 and preSimulation then
		if preAnimation then
			preAnimation:Disconnect()
			preAnimation = nil
		end
		preSimulation:Disconnect()
		preSimulation = nil
		restore()
	end
end

local function register(track: Track)
	if not table.find(playing, track) then
		table.insert(playing, track)
	end
	if not preSimulation then
		-- Put back what the Animator wrote last frame before it runs again; turn the joints after.
		preAnimation = RunService.PreAnimation:Connect(restore)
		preSimulation = RunService.PreSimulation:Connect(stepTracks)
	end
end

-- The joint that moves each body part (the Motor6D whose Part1 it is).
local function findJoints(character: Instance): { [string]: Motor6D }
	local wanted: { [string]: boolean } = {}
	for _, name in PARTS do
		wanted[name] = true
	end
	local joints: { [string]: Motor6D } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local part = descendant.Part1
			if part and wanted[part.Name] and not joints[part.Name] then
				joints[part.Name] = descendant
			end
		end
	end
	return joints
end

local function softTrack(humanoid: Humanoid, clip: Clip): AnimationTrack
	local track: Track = {
		clip = clip,
		humanoid = humanoid,
		joints = nil,
		listeners = {},
		time = 0,
		speed = 1,
		weight = 0,
		target = 0,
		fade = 0.1,
		destroyed = false,
		IsPlaying = false,
		Looped = clip.looped,
		Priority = Enum.AnimationPriority.Action4,
		Length = clip.length,
	}
	track.KeyframeReached = {
		Connect = function(_, callback: (string) -> ())
			table.insert(track.listeners, callback)
			return {
				Disconnect = function()
					local at = table.find(track.listeners, callback)
					if at then
						table.remove(track.listeners, at)
					end
				end,
			}
		end,
	}
	function track.Play(self: Track, fade: number?)
		if not self.joints then
			self.joints = findJoints(humanoid.Parent or humanoid)
		end
		if not self.IsPlaying then
			self.IsPlaying = true
			self.time = 0
		end
		self.target = 1
		self.fade = fade or 0.1
		if self.fade <= 0 then
			self.weight = 1
		end
		register(self)
	end
	function track.Stop(self: Track, fade: number?)
		self.IsPlaying = false
		self.target = 0
		self.fade = fade or 0.1
		if self.fade <= 0 then
			self.weight = 0
		end
	end
	function track.AdjustSpeed(self: Track, speed: number?)
		self.speed = speed or 1
	end
	function track.Destroy(self: Track)
		self.destroyed = true
		self.IsPlaying = false
		self.weight = 0
		self.target = 0
		table.clear(self.listeners)
	end
	return track :: any
end

function AnimationBuilder.load(humanoid: Humanoid, animation: Animation): AnimationTrack
	local clip = clips[animation]
	if clip then
		return softTrack(humanoid, clip)
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return (animator :: Animator):LoadAnimation(animation)
end

return AnimationBuilder
