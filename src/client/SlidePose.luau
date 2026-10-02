--!strict
-- The slide pose: leans the body back and kicks the legs out front by rotating the R15
-- joints, blended smoothly over the normal animations. Also sinks the hips and dips the
-- camera on the same blend. Angles live in Config.Slide.Pose.
-- Runs on the client only, so other players don't see the pose yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Pose = {
	play: () -> (),
	stop: () -> (),
	standingHip: number,
	slideHip: number,
}

local SlidePose = {}

local function toCFrame(degrees: Vector3): CFrame
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

function SlidePose.attach(character: Model, humanoid: Humanoid): Pose
	local settings = Config.Slide
	local pose = settings.Pose :: { [string]: Vector3 }

	local joints: { { motor: Motor6D, target: CFrame } } = {}
	for _, item in character:GetDescendants() do
		if item:IsA("Motor6D") and pose[item.Name] then
			table.insert(joints, { motor = item, target = toCFrame(pose[item.Name]) })
		end
	end

	local standingHip = humanoid.HipHeight
	local slideHip = standingHip * settings.HipHeightFactor
	local weight = 0 -- 0 = normal animations, 1 = full slide pose
	local goal = 0
	local connection: RBXScriptConnection? = nil

	-- Runs after the Animator each frame, so the pose blends on top of the run animation.
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

		for _, joint in joints do
			joint.motor.Transform = joint.motor.Transform:Lerp(joint.target, w)
		end
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
			blendTo(1)
		end,
		stop = function()
			blendTo(0)
		end,
		standingHip = standingHip,
		slideHip = slideHip,
	}
end

return SlidePose
