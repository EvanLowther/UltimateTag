--!strict
-- First-person arms: the body's forearm (sleeve with stripe) and ball hand (BodyRig,
-- Config.Body), scaled by Config.Viewmodel.Scale and attached to the camera, posed for what you're
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
	local warned: { [string]: boolean } = {}
	-- A pose by name. A missing one falls back to Idle with a single warning, instead of
	-- erroring every frame.
	local function pose(name: string): Pose
		local found = poses[name]
		if found then
			return found
		end
		if not warned[name] then
			warned[name] = true
			warn(`[Viewmodel] Config.Viewmodel.Poses.{name} is missing, using Idle`)
		end
		return poses.Idle
	end
	local camera = workspace.CurrentCamera

	-- The body's forearm (a sleeve cylinder with its stripe) and ball hand, laid along the
	-- camera's forward axis (-Z) and scaled down.
	-- With the classic avatar (Config.Body.Enabled off) the arms are plain blocks in its arm color.
	local classic = not Config.Body.Enabled
	local sizes = Config.Body.Sizes
	local length = if classic then settings.ClassicArm.Z else sizes.LowerArm.Y * settings.Scale
	local thickness = if classic then settings.ClassicArm.X else sizes.LowerArm.X * settings.Scale
	local handSize = if classic then settings.ClassicHand else sizes.Hand.X * settings.Scale
	local armColor = if classic then Config.Avatar.ArmColor else BodyRig.colorOf("LowerArm")
	local handColor = if classic then Config.Avatar.ArmColor else BodyRig.colorOf("Hand")
	local function makePart(
		name: string,
		size: Vector3,
		partColor: Color3,
		shape: Enum.PartType?
	): Part
		local part = BodyRig.block(name, size, partColor, shape)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = camera
		return part
	end
	local function makeArm(side: string)
		local outward = if side == "Right" then 1 else -1
		return {
			sleeve = makePart(
				"Viewmodel" .. side,
				if classic
					then Vector3.new(thickness, thickness, length)
					else Vector3.new(length, thickness, thickness),
				armColor,
				if classic then nil else Enum.PartType.Cylinder
			),
			hand = makePart(
				"Viewmodel" .. side .. "Hand",
				Vector3.one * handSize,
				handColor,
				if classic then nil else Enum.PartType.Ball
			),
			stripe = if Config.Body.Stripes and not classic
				then makePart(
					"Viewmodel" .. side .. "Stripe",
					Vector3.new(0.04, 0.07, length * 0.92),
					Config.Body.Colors.Stripe
				)
				else nil,
			stripeOffset = CFrame.new(thickness / 2 * outward, 0, 0),
		}
	end
	local arms = { Right = makeArm("Right"), Left = makeArm("Left") }
	-- Cylinders lie along X; turn them to point forward. Classic blocks are already long along Z.
	local ALONG = if classic then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0)
	local handOffset = CFrame.new(0, 0, -(length / 2 + handSize * 0.35))
	local function allParts(): { BasePart }
		local list = {}
		for _, arm in arms do
			table.insert(list, arm.sleeve)
			table.insert(list, arm.hand)
			if arm.stripe then
				table.insert(list, arm.stripe)
			end
		end
		return list
	end
	-- Places one arm at `frame` (the middle of the forearm, pointing forward).
	local function place(arm: typeof(arms.Right), frame: CFrame)
		arm.sleeve.CFrame = frame * ALONG
		arm.hand.CFrame = frame * handOffset
		if arm.stripe then
			arm.stripe.CFrame = frame * arm.stripeOffset
		end
	end
	local rightPose, leftPose = sides(pose("Idle"))
	local lastBusy: string? = nil
	local busySince = 0

	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local parts = MoveState.parts()
		local show = ViewMode.isFirstPerson() and parts ~= nil
		local transparency = if show then 0 else 1
		for _, block in allParts() do
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
		if now - MoveState.tagTime < settings.TagJabTime then
			-- Tag swing: the right hand jabs forward; the left keeps its usual pose.
			local jabRight = sides(pose("TagJab"))
			local _, idleLeft =
				sides(pose(if MoveState.isGrounded(parts.humanoid) then "Idle" else "Air"))
			targetRight, targetLeft = jabRight, idleLeft
		elseif busy == "Mantle" then
			-- Hands reach up to the ledge, then push down on it as you climb.
			local mantle = Config.Mantle
			local progress = math.clamp((now - busySince) / (mantle.UpTime + mantle.OverTime), 0, 1)
			local grabRight, grabLeft = sides(pose("MantleGrab"))
			local pushRight, pushLeft = sides(pose("MantlePush"))
			targetRight, targetLeft =
				grabRight:Lerp(pushRight, progress), grabLeft:Lerp(pushLeft, progress)
		elseif busy == "Climb" then
			-- Hands reach up the wall one after the other.
			targetRight, targetLeft = sides(pose("Climb"))
			local reach = math.sin(now * settings.ClimbRate) * settings.ClimbSwing
			targetRight = CFrame.new(0, reach, 0) * targetRight
			targetLeft = CFrame.new(0, -reach, 0) * targetLeft
		elseif busy == "Hang" or busy == "Cling" then
			targetRight, targetLeft = sides(pose("Hang"))
		elseif busy == "WallRun" then
			-- The wall-side hand trails on the wall; the other is in the air pose.
			local handRight, handLeft = sides(pose("WallRunHand"))
			local airRight, airLeft = sides(pose("Air"))
			if MoveState.wallSide == "Right" then
				targetRight, targetLeft = handRight, airLeft
			else
				targetRight, targetLeft = airRight, handLeft
			end
		elseif busy == "Roll" then
			targetRight, targetLeft = sides(pose("Roll"))
		elseif busy == "Vault" then
			targetRight, targetLeft = sides(pose("Vault"))
		elseif busy == "Slide" then
			targetRight, targetLeft = sides(pose("Slide"))
		elseif busy == "Crouch" then
			targetRight, targetLeft = sides(pose("Crouch"))
		elseif not MoveState.isGrounded(parts.humanoid) then
			targetRight, targetLeft = sides(pose("Air"))
		else
			targetRight, targetLeft = sides(pose("Idle"))
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
		place(arms.Right, camera.CFrame * rightPose)
		place(arms.Left, camera.CFrame * leftPose)
	end)
end

return Viewmodel
