--!strict
-- Map gadgets, driven by attributes on map parts (so any map can use them):
--   LaunchVelocity (Vector3): standing on the part throws you with that velocity (a launch pad).
--   SpeedBoost (number):      jumping or running off the part sends you at least this fast in
--                             the direction you're moving (solar panel slides before a gap).
--   Slip (number):            moving onto the part knocks you onto your back for that many
--                             seconds (a wet floor). Sliding across it is safe (a move is busy).
-- Runs on the client like the other moves; the flight keeps its speed through AirMomentum.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

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

-- Feet out from under you: fall onto your back, lie there, get up.
local function slip(parts: MoveState.Parts, seconds: number, onDone: () -> ())
	local settings = Config.Gadgets
	local hum, root = parts.humanoid, parts.root
	MoveState.busy = "Slip"
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	hum:ChangeState(Enum.HumanoidStateType.FallingDown)
	-- Tip backwards (feet forward) and keep a little forward slide.
	root.AssemblyAngularVelocity = root.CFrame.RightVector * settings.SlipSpin
	root.AssemblyLinearVelocity += Vector3.new(0, 8, 0)
	task.delay(seconds, function()
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
			if
				typeof(velocity) == "Vector3"
				and now - lastLaunch > settings.LaunchCooldown
				and not MoveState.busy -- a move in progress keeps control (slides, flying)
			then
				lastLaunch = now
				boostSpeed = nil
				launch(parts, velocity)
				wasGrounded = false
				return
			end
			local slipTime = floor and floor:GetAttribute("Slip")
			if
				type(slipTime) == "number"
				and not MoveState.busy
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
