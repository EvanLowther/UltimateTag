--!strict
-- The slide key (Config.Slide.Key) does three things:
--   Slide:     sprinting on the ground. You keep your momentum (plus a boost), then it fades to
--              walk speed. Sliding again within DeadSlideTime is a "dead slide": no boost.
--   Air slide: moving fast in the air (or sprinting). Keeps your air speed with no boost, and
--              the slow-down only starts once you land, so you slide out of the landing.
--   Crouch:    anything else. A low crouch at CrouchSpeed to get under things.
-- Holding the key when a slide runs out turns it into a crouch. You can't stand up under a low
-- ceiling, and jumping out of a slide keeps its speed. Holding the key as you land slides (or
-- crouches) on touchdown, keeping the speed you landed with.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local SlidePose = require(script.Parent.SlidePose)
local Sprint = require(script.Parent.Sprint)

local Slide = {}

function Slide.start()
	local settings = Config.Slide

	local keyHeld = false
	local lastEnd = -math.huge
	local finish: ((jumped: boolean) -> ())? = nil -- ends the current slide or crouch
	local isBlocked: (() -> boolean)? = nil -- true if standing up would hit a ceiling
	local pose: SlidePose.Pose? = nil
	local poseCharacter: Model? = nil

	-- Moves every part of the character into a collision group.
	local function setGroup(character: Model, group: string)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = group
			end
		end
	end

	-- One pose per character, made while standing so it remembers the normal hip height.
	local function getPose(character: Model, hum: Humanoid): SlidePose.Pose
		if poseCharacter ~= character or not pose then
			pose = SlidePose.attach(character, hum)
			poseCharacter = character
		end
		return pose :: SlidePose.Pose
	end

	-- Builds the "would standing up hit a ceiling?" check for a body lowered to `loweredHip`.
	local function ceilingCheck(
		parts: MoveState.Parts,
		standingHip: number,
		loweredHip: number
	): () -> boolean
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { parts.character }
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.CollisionGroup = settings.SlidingGroup -- ignore the invisible stand blockers
		local reach = (standingHip - loweredHip) + settings.HeadClearance
		return function()
			return workspace:Raycast(parts.root.Position, Vector3.new(0, reach, 0), params) ~= nil
		end
	end

	local function crouch(parts: MoveState.Parts)
		local character, hum = parts.character, parts.humanoid
		local activePose = getPose(character, hum)
		MoveState.busy = "Crouch"
		activePose.crouch()
		-- Crouching cuts you straight to crouch speed (no gliding in carrying your old speed).
		local root = parts.root
		local flat = MoveState.flat(root.AssemblyLinearVelocity)
		if flat.Magnitude > settings.CrouchSpeed then
			local capped = flat.Unit * settings.CrouchSpeed
			root.AssemblyLinearVelocity =
				Vector3.new(capped.X, root.AssemblyLinearVelocity.Y, capped.Z)
		end
		setGroup(character, settings.SlidingGroup)
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		local blockedAbove = ceilingCheck(parts, activePose.standingHip, activePose.crouchHip)

		local connection: RBXScriptConnection
		local function stop(jumped: boolean)
			connection:Disconnect()
			finish = nil
			isBlocked = nil
			MoveState.busy = nil
			activePose.stand()
			if hum.Parent then
				setGroup(character, "Default")
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				-- Back to the speed you should have now (frozen players stay frozen).
				if hum.WalkSpeed > 0 then
					hum.WalkSpeed = Sprint.targetSpeed()
				end
				if jumped then
					hum.Jump = true
				end
			end
		end
		finish = stop
		isBlocked = blockedAbove

		connection = RunService.Heartbeat:Connect(function()
			if not hum.Parent or hum.Health <= 0 then
				stop(false)
				return
			end
			-- Frozen (tagged) players keep their 0 speed.
			if hum.WalkSpeed > 0 then
				hum.WalkSpeed = settings.CrouchSpeed
			end
			activePose.crouchMove(MoveState.flat(parts.root.AssemblyLinearVelocity).Magnitude)
			if not keyHeld and not blockedAbove() then
				stop(false)
			end
		end)
	end

	local function slide(parts: MoveState.Parts, flat: Vector3, airborne: boolean)
		local character, hum, root = parts.character, parts.humanoid, parts.root
		local activePose = getPose(character, hum)
		MoveState.busy = "Slide"
		MoveState.landVelocity = nil

		local dir = flat.Unit
		-- No boost for a dead slide (too soon after the last one) or an air slide.
		local dead = os.clock() - lastEnd < settings.DeadSlideTime
		local boost = if dead or airborne then 1 else settings.StartMultiplier
		local startSpeed = math.min(flat.Magnitude * boost, settings.MaxSpeed)
		local endSpeed = hum.WalkSpeed
			/ (if Sprint.isSprinting() then Config.Sprint.Multiplier else 1)
		local elapsed = 0 -- only counts while on the ground, so air slides keep their speed
		local speed = startSpeed

		local drive, release = MoveState.drive(root, true)
		drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
		MoveState.faceDirection = dir
		activePose.play()
		setGroup(character, settings.SlidingGroup)
		local blockedAbove = ceilingCheck(parts, activePose.standingHip, activePose.slideHip)

		local connection: RBXScriptConnection
		local function stop(jumped: boolean, intoCrouch: boolean)
			connection:Disconnect()
			finish = nil
			isBlocked = nil
			MoveState.busy = nil
			MoveState.faceDirection = nil
			lastEnd = os.clock()
			release()
			if not hum.Parent then
				return
			end
			if intoCrouch then
				crouch(parts)
				return
			end
			activePose.stop()
			setGroup(character, "Default")
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
			if jumped then
				hum.Jump = true
			end
		end
		finish = function(jumped: boolean)
			stop(jumped, false)
		end
		isBlocked = blockedAbove

		connection = RunService.Heartbeat:Connect(function(dt)
			if not hum.Parent or not root.Parent or hum.Health <= 0 then
				stop(false, false)
				return
			end
			local grounded = MoveState.isGrounded(hum)
			if grounded then
				elapsed += dt
			end
			local alpha = math.min(elapsed / settings.Duration, 1)
			speed = endSpeed + (startSpeed - endSpeed) * (1 - alpha) ^ 2

			-- Steering: your keys nudge the slide direction.
			local move = hum.MoveDirection
			if move.Magnitude > 0 then
				dir = (dir + move * settings.Steer * dt).Unit
			end
			drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
			MoveState.faceDirection = dir -- feet first: the body points along the slide

			local v = root.AssemblyLinearVelocity
			local hitWall = elapsed > 0.15 and Vector3.new(v.X, 0, v.Z).Magnitude < speed * 0.3
			local blocked = blockedAbove()
			if hitWall then
				stop(false, grounded and (keyHeld or blocked))
			elseif alpha >= 1 then
				-- Slide ran out: crouch if you're holding the key or stuck under something.
				stop(false, keyHeld or blocked)
			elseif not keyHeld and not blocked then
				stop(false, false)
			end
		end)
	end

	local function begin()
		local parts = MoveState.parts()
		if MoveState.busy or not parts then
			return
		end
		local hum, root = parts.humanoid, parts.root
		local grounded = MoveState.isGrounded(hum)
		local flat = MoveState.flat(root.AssemblyLinearVelocity)
		local fast = false -- moving faster than you can walk without sprinting

		if grounded then
			-- Just landed? Use the speed you landed with, before ground friction slowed you.
			local landed = MoveState.landVelocity
			if
				landed
				and os.clock() - MoveState.landTime < settings.LandingGrace
				and landed.Magnitude > flat.Magnitude
			then
				flat = landed
				fast = flat.Magnitude > hum.WalkSpeed
			end
		else
			-- In the air, AirMomentum holds the speed you're actually carrying.
			local air = MoveState.airVelocity
			if air and air.Magnitude > flat.Magnitude then
				flat = air
			end
			fast = flat.Magnitude > hum.WalkSpeed
		end

		local moving = flat.Magnitude >= hum.WalkSpeed * 0.5
		if moving and (Sprint.isSprinting() or fast) then
			slide(parts, flat, not grounded)
		elseif grounded then
			crouch(parts)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == settings.Key then
			keyHeld = true
			begin()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == settings.Key then
			keyHeld = false
		end
	end)
	-- Holding the key as you land slides (or crouches) the moment you touch down.
	local wasGrounded = true
	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		local grounded = parts ~= nil and MoveState.isGrounded(parts.humanoid)
		if grounded and not wasGrounded and keyHeld and not MoveState.busy then
			begin()
		end
		wasGrounded = grounded
	end)
	UserInputService.JumpRequest:Connect(function()
		-- Jump out of a slide or crouch, unless a ceiling is in the way.
		if finish and isBlocked and not isBlocked() then
			finish(true)
		end
	end)
end

return Slide
