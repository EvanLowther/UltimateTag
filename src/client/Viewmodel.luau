--!strict
-- First-person arms: the body's forearm and hand (BodyRig, Config.Body), scaled by
-- Config.Viewmodel.Scale and attached to the camera, posed for what you're
-- doing (idle, running swing, air, slide, crouch, vault plant, mantle grab and push). Only shown
-- in first person. Poses live in Config.Viewmodel.Poses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BodyRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BodyRig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local Sprint = require(script.Parent.Sprint)
local ViewMode = require(script.Parent.ViewMode)

local Viewmodel = {}

type ArmPose = { Position: Vector3, Rotation: Vector3 }
type Pose = { Right: ArmPose, Left: ArmPose? }

local function toCFrame(arm: ArmPose): CFrame
	local r = arm.Rotation
	return CFrame.new(arm.Position) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end

-- The left arm is the right arm reflected across the middle of the screen.
local function mirror(arm: ArmPose): ArmPose
	return {
		Position = Vector3.new(-arm.Position.X, arm.Position.Y, arm.Position.Z),
		Rotation = Vector3.new(arm.Rotation.X, -arm.Rotation.Y, -arm.Rotation.Z),
	}
end

local function sides(pose: Pose): (CFrame, CFrame)
	return toCFrame(pose.Right), toCFrame(pose.Left or mirror(pose.Right))
end

function Viewmodel.start()
	local settings = Config.Viewmodel
	if not settings.Enabled then
		return
	end
	local poses = settings.Poses :: { [string]: Pose }
	local camera = workspace.CurrentCamera

	-- The body's forearm and hand, laid along the camera's forward axis (-Z) and scaled down.
	local function swap(size: Vector3): Vector3
		return Vector3.new(size.X, size.Z, size.Y) * settings.Scale
	end
	local sizes = Config.Body.Sizes
	local armSize, handSize = swap(sizes.LowerArm), swap(sizes.Hand)
	local function makeBlock(name: string, size: Vector3, kind: string): Part
		local block = BodyRig.block(name, size, BodyRig.colorOf(kind))
		block.Anchored = true
		block.CanCollide = false
		block.CanQuery = false
		block.CanTouch = false
		block.CastShadow = false
		block.Parent = camera
		return block
	end
	local right, left =
		makeBlock("ViewmodelRight", armSize, "LowerArm"),
		makeBlock("ViewmodelLeft", armSize, "LowerArm")
	local rightHand, leftHand =
		makeBlock("ViewmodelRightHand", handSize, "Hand"),
		makeBlock("ViewmodelLeftHand", handSize, "Hand")
	-- The hand sits on the far (forward) end of the forearm.
	local handOffset = CFrame.new(0, 0, -(armSize.Z + handSize.Z) / 2)
	local rightPose, leftPose = sides(poses.Idle)
	local lastBusy: string? = nil
	local busySince = 0

	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local parts = MoveState.parts()
		local show = ViewMode.isFirstPerson() and parts ~= nil
		local transparency = if show then 0 else 1
		for _, block in { right, left, rightHand, leftHand } do
			block.Transparency = transparency
		end
		if not parts or not show then
			return
		end

		local busy = MoveState.busy
		local now = os.clock()
		if busy ~= lastBusy then
			lastBusy = busy
			busySince = now
		end

		local targetRight, targetLeft
		local sinceBounce = now - MoveState.bounceTime
		if sinceBounce < settings.WallPushTime then
			-- Wall bounce: the hand on the wall's side plants on it, the other stays in the air pose.
			local pushRight, pushLeft = sides(poses.WallPush)
			local airRight, airLeft = sides(poses.Air)
			if MoveState.bounceHand == "Right" then
				targetRight, targetLeft = pushRight, airLeft
			else
				targetRight, targetLeft = airRight, pushLeft
			end
		elseif busy == "Mantle" then
			-- Hands reach up to the ledge, then push down on it as you climb.
			local mantle = Config.Mantle
			local progress = math.clamp((now - busySince) / (mantle.UpTime + mantle.OverTime), 0, 1)
			local grabRight, grabLeft = sides(poses.MantleGrab)
			local pushRight, pushLeft = sides(poses.MantlePush)
			targetRight, targetLeft =
				grabRight:Lerp(pushRight, progress), grabLeft:Lerp(pushLeft, progress)
		elseif busy == "Vault" then
			targetRight, targetLeft = sides(poses.Vault)
		elseif busy == "Slide" then
			targetRight, targetLeft = sides(poses.Slide)
		elseif busy == "Crouch" then
			targetRight, targetLeft = sides(poses.Crouch)
		elseif not MoveState.isGrounded(parts.humanoid) then
			targetRight, targetLeft = sides(poses.Air)
		else
			targetRight, targetLeft = sides(poses.Idle)
			-- Swing the arms while running, harder when sprinting.
			local speed = MoveState.flat(parts.root.AssemblyLinearVelocity).Magnitude
			if speed > 1 then
				local amount = settings.BobAmount
					* (if Sprint.isSprinting() then settings.SprintBob else 1)
				local phase = now * settings.BobRate * (speed / Config.Speed.Runner)
				local swing = math.sin(phase) * amount
				targetRight = CFrame.new(0, swing, swing * 2) * targetRight
				targetLeft = CFrame.new(0, -swing, -swing * 2) * targetLeft
			end
		end

		local blend = 1 - math.exp(-settings.Smooth * dt)
		rightPose = rightPose:Lerp(targetRight, blend)
		leftPose = leftPose:Lerp(targetLeft, blend)
		right.CFrame = camera.CFrame * rightPose
		left.CFrame = camera.CFrame * leftPose
		rightHand.CFrame = right.CFrame * handOffset
		leftHand.CFrame = left.CFrame * handOffset
	end)
end

return Viewmodel
