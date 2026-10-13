--!strict
-- Map gadgets, driven by attributes on map parts (so any map can use them):
--   LaunchVelocity (Vector3): standing on the part throws you with that velocity (a launch pad).
--                             Sliding or crouching onto it works too (the slide ends first).
--   LaunchAnyDirection (true): the pad throws you the way you're moving instead (the same up
--                             speed and the same speed across as LaunchVelocity; standing
--                             still, the way you face).
--   SpeedBoost (number):      jumping or running off the part sends you at least this fast in
--                             the direction you're moving (solar panel slides before a gap).
--   Slip (number):            moving onto the part (running or sliding) makes you slip: you
--                             fall onto your back and skid on with your momentum, slowing to a
--                             stop, then get up after that many seconds (a wet floor).
-- Runs on the client like the other moves; the flight keeps its speed through AirMomentum.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local Slide = require(script.Parent.Slide)

local MapGadgets = {}

local FLOOR_RAY = 4.5 -- studs below the root part to look for the floor

-- The part you're standing on, if any.
local function floorPart(parts: MoveState.Parts): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { parts.character }
	local hit = workspace:Raycast(parts.root.Position, Vector3.new(0, -FLOOR_RAY, 0), params)
	return if hit then hit.Instance :: BasePart else nil
end

-- An any-direction pad's throw: LaunchVelocity's up speed, and its speed across turned the way
-- you're moving (or facing, if you're barely moving).
local function aimed(parts: MoveState.Parts, velocity: Vector3): Vector3
	local moving = MoveState.flat(parts.root.AssemblyLinearVelocity)
	local direction = if moving.Magnitude >= Config.Gadgets.LaunchAimSpeed
		then moving.Unit
		elseif parts.humanoid.MoveDirection.Magnitude > 0.1 then MoveState.flat(
			parts.humanoid.MoveDirection
		).Unit
		else MoveState.flat(parts.root.CFrame.LookVector).Unit
	local across = direction * MoveState.flat(velocity).Magnitude
	return Vector3.new(across.X, velocity.Y, across.Z)
end

local function launch(parts: MoveState.Parts, velocity: Vector3)
	local settings = Config.Gadgets
	local root, hum = parts.root, parts.humanoid
	MoveState.busy = "Launch"
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	local drive, remove = MoveState.drive(root, false)
	drive.VectorVelocity = velocity
	root.AssemblyLinearVelocity = velocity
	local flat = MoveState.flat(velocity)
	if flat.Magnitude > 0.1 then
		MoveState.faceDirection = flat.Unit
	end
	task.delay(settings.LaunchDriveTime, function()
		remove()
		MoveState.airVelocity = flat
		MoveState.launchTime = os.clock()
		MoveState.faceDirection = nil
		if MoveState.busy == "Launch" then
			MoveState.busy = nil
		end
	end)
end

-- Feet out from under you: fall onto your back and skid on with your momentum (slowing to a
-- stop over SlipSkidTime), lie there, get up after `seconds`.
local function slip(parts: MoveState.Parts, seconds: number, onDone: () -> ())
	local settings = Config.Gadgets
	local hum, root = parts.humanoid, parts.root
	if MoveState.busy == "Slide" or MoveState.busy == "Crouch" then
		Slide.cancel() -- ends the slide and keeps its speed
	end
	local momentum = MoveState.flat(root.AssemblyLinearVelocity) * settings.SlipCarry
	MoveState.busy = "Slip"
	MoveState.airVelocity = nil
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	hum:ChangeState(Enum.HumanoidStateType.FallingDown)
	-- Tip backwards (feet forward), a little hop so the body leaves the floor cleanly.
	root.AssemblyAngularVelocity = root.CFrame.RightVector * settings.SlipSpin
	root.AssemblyLinearVelocity = momentum + Vector3.new(0, 8, 0)

	-- The skid: a flat drive that eases your momentum down to zero.
	local drive, release = MoveState.drive(root, true)
	local elapsed = 0
	local skid: RBXScriptConnection
	skid = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local left = math.max(1 - elapsed / settings.SlipSkidTime, 0)
		local v = momentum * left * left
		drive.PlaneVelocity = Vector2.new(v.X, v.Z)
		if left <= 0 or not hum.Parent then
			skid:Disconnect()
			release()
		end
	end)

	task.delay(seconds, function()
		if skid.Connected then
			skid:Disconnect()
			release()
		end
		if hum.Parent and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		end
		if MoveState.busy == "Slip" then
			MoveState.busy = nil
		end
		onDone()
	end)
end

function MapGadgets.start()
	local settings = Config.Gadgets
	local lastLaunch = -math.huge
	local boostSpeed: number? = nil -- SpeedBoost of the last part you stood on
	local boostLeft = -math.huge -- when you left it
	local wasGrounded = true
	local slipReady = 0 -- os.clock() after which you can slip again

	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		if not parts then
			boostSpeed = nil
			return
		end
		local hum, root = parts.humanoid, parts.root
		local grounded = MoveState.isGrounded(hum)
		local now = os.clock()

		if grounded then
			local floor = floorPart(parts)
			local velocity = floor and floor:GetAttribute("LaunchVelocity")
			local busy = MoveState.busy
			if
				floor
				and typeof(velocity) == "Vector3"
				and now - lastLaunch > settings.LaunchCooldown
				-- Slides and crouches launch too; other moves (wall runs, flying) keep control.
				and (not busy or busy == "Slide" or busy == "Crouch")
			then
				lastLaunch = now
				boostSpeed = nil
				-- Aim before the slide ends, so a slide throws you the way it was going.
				local throw = if floor:GetAttribute("LaunchAnyDirection") == true
					then aimed(parts, velocity)
					else velocity
				if busy then
					Slide.cancel() -- ends the slide or crouch: hips up, normal collisions
				end
				launch(parts, throw)
				wasGrounded = false
				return
			end
			local slipTime = floor and floor:GetAttribute("Slip")
			if
				type(slipTime) == "number"
				and (not busy or busy == "Slide" or busy == "Crouch") -- sliding slips too
				and now >= slipReady
				and MoveState.flat(root.AssemblyLinearVelocity).Magnitude
					>= settings.SlipMinSpeed
			then
				slipReady = math.huge -- until you're back up
				slip(parts, slipTime, function()
					slipReady = os.clock() + settings.SlipCooldown
				end)
				return
			end
			local boost = floor and floor:GetAttribute("SpeedBoost")
			boostSpeed = if type(boost) == "number" then boost else nil
		elseif wasGrounded and boostSpeed then
			boostLeft = now -- just left a boost surface
		end

		-- In the air shortly after leaving a boost surface: make sure you're at least that fast.
		if
			not grounded
			and boostSpeed
			and not MoveState.busy
			and now - boostLeft <= settings.BoostWindow
		then
			local flat = MoveState.flat(root.AssemblyLinearVelocity)
			if flat.Magnitude < boostSpeed then
				local direction = if flat.Magnitude > 1
					then flat.Unit
					else MoveState.flat(root.CFrame.LookVector).Unit
				local boosted = direction * boostSpeed
				root.AssemblyLinearVelocity =
					Vector3.new(boosted.X, root.AssemblyLinearVelocity.Y, boosted.Z)
				MoveState.airVelocity = boosted
			end
			boostSpeed = nil -- once per jump
		end
		wasGrounded = grounded
	end)
end

return MapGadgets
