--!strict
-- First person: keeps your hands in view. Each frame, after the animations have posed your body,
-- the upper arms swing forward (Config.FirstPerson.ArmLift) and in toward the middle, and the
-- shoulders move in. The lift is measured against the torso's lean and capped just above level,
-- so a slide's raised arm comes forward into view instead of going over your head, and running
-- arms pump at the bottom of the screen. During a wall run the wall-side arm reaches out and
-- drags its hand along the wall (WallHand). Only on your screen: joint changes made on your
-- client aren't sent to anyone, so other players see your normal animations.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local FirstPersonArms = {}

local DOWN = Vector3.new(0, -1, 0)

local function angles(degrees: Vector3, sign: number): CFrame
	-- sign -1 mirrors a pose written for the right side onto the left (Y and Z flip)
	return CFrame.Angles(
		math.rad(degrees.X),
		math.rad(degrees.Y * sign),
		math.rad(degrees.Z * sign)
	)
end

-- Where a joint puts its part relative to the part it hangs from, animation included.
local function offset(motor: Motor6D): CFrame
	return motor.C0 * motor.Transform * motor.C1:Inverse()
end

function FirstPersonArms.start()
	local settings = Config.FirstPerson
	local character: Model? = nil
	local motors: { [string]: Motor6D } = {} -- by the name of the part each one moves
	-- The animation's own Transform for each joint we changed this frame, put back before the
	-- animations run again (so a joint no animation touches doesn't keep turning further).
	local saved: { [Motor6D]: CFrame } = {}
	local wallBlend = 0
	local wallSide = "Right"

	local function findMotors(model: Model)
		character = model
		table.clear(motors)
		for _, motor in model:GetDescendants() do
			if motor:IsA("Motor6D") and motor.Part1 then
				motors[motor.Part1.Name] = motor
			end
		end
	end

	RunService.PreAnimation:Connect(function()
		for motor, transform in saved do
			motor.Transform = transform
		end
		table.clear(saved)
	end)

	RunService.PreSimulation:Connect(function(dt)
		local parts = MoveState.parts()
		if not parts or not ViewMode.isFirstPerson() then
			wallBlend = 0
			return
		end
		if parts.character ~= character or not motors.UpperTorso then
			findMotors(parts.character)
		end
		local root, waist = motors.LowerTorso, motors.UpperTorso
		if not root or not waist then
			return
		end

		local wallRunning = MoveState.busy == "WallRun"
		if wallRunning then
			wallSide = MoveState.wallSide
		end
		local target = if wallRunning then 1 else 0
		wallBlend += (target - wallBlend) * (1 - math.exp(-settings.WallHandBlend * dt))

		-- The upper torso in the root part's space: the lean of a slide, crouch or wall run.
		local torso = offset(root) * offset(waist)
		for _, side in { "Right", "Left" } do
			local shoulder = motors[side .. "UpperArm"]
			if not shoulder then
				continue
			end
			local sign = if side == "Right" then 1 else -1
			local base = shoulder.Transform
			saved[shoulder] = base

			-- How far forward of straight down the animation points this arm, seen from the side.
			local arm = torso * shoulder.C0 * base * shoulder.C1:Inverse()
			local down = arm:VectorToWorldSpace(DOWN)
			local pitch = math.deg(math.atan2(-down.Z, -down.Y))
			local lifted =
				math.clamp(pitch + settings.ArmLift, settings.MinArmAngle, settings.MaxArmAngle)

			-- Shoulders in: the arm's center moves toward the middle of the chest.
			local width = shoulder.C0.Position.X - shoulder.C1.Position.X
			local inward = CFrame.new(-width * (1 - settings.ShoulderWidth), 0, 0)
			local pose = inward
				* CFrame.Angles(math.rad(lifted - pitch), 0, math.rad(-settings.ArmTuck * sign))
				* base

			if wallBlend > 0.001 and side == wallSide then
				-- The wall-side hand on the wall (WallHand is written for a wall on the right).
				local hand = settings.WallHand
				pose = pose:Lerp(inward * angles(hand.UpperArm, sign), wallBlend)
				for name, degrees in { LowerArm = hand.LowerArm, Hand = hand.Hand } do
					local joint = motors[side .. name]
					if joint then
						saved[joint] = joint.Transform
						joint.Transform = joint.Transform:Lerp(angles(degrees, sign), wallBlend)
					end
				end
			end
			shoulder.Transform = pose
		end
	end)
end

return FirstPersonArms
