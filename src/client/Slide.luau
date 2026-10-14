--!strict
-- The slide key (Config.Slide.Key) does three things:
--   Slide:     sprinting on the ground. You keep your momentum (plus a boost), then it fades to
--              walk speed. Sliding again within DeadSlideTime is a "dead slide": no boost.
--   Air slide: moving fast in the air (or sprinting). Keeps your air speed with no boost, and
--              the slow-down only starts once you land, so you slide out of the landing.
--   Crouch:    anything else. A low crouch at CrouchSpeed to get under things.
-- Holding the key when a slide runs out turns it into a crouch. You can't stand up under a low
-- ceiling. Holding the key as you land slides (or crouches) on touchdown, keeping the speed you
-- landed with plus more of the drop (Config.Momentum.LandSlideCarry).
-- Slopes: sliding downhill speeds you up (SlopeAccel) and the slide doesn't fade until you're off
-- the slope; uphill slows you. Jumping out of a slide keeps its speed and goes higher the faster
-- you were going (JumpLift). A slide that ends on the ground faster than you can run hands its
-- speed to GroundMomentum, which carries it and fades it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local SlidePose = require(script.Parent.SlidePose)
local Sprint = require(script.Parent.Sprint)

local Slide = {}

-- Ends the current slide or crouch now (keeping a slide's speed), if one is running. Set up by
-- Slide.start; used by things that interrupt a slide, like slipping on a wet floor.
function Slide.cancel() end

-- Jumps out of the current slide (with its speed and lift), if one is running. Returns true if
-- it did. Used by CoyoteJump for a slide that just went off an edge.
function Slide.jump(): boolean
	return false
end

-- The speed a normal jump leaves the ground with (0 while frozen).
local function jumpSpeed(hum: Humanoid): number
	if hum.UseJumpPower then
		return hum.JumpPower
	end
	return math.sqrt(2 * workspace.Gravity * math.max(hum.JumpHeight, 0))
end

function Slide.start()
	local settings = Config.Slide

	local keyHeld = false
	local lastEnd = -math.huge
	local finish: ((jumped: boolean) -> ())? = nil -- ends the current slide or crouch
	local isBlocked: (() -> boolean)? = nil -- true if standing up would hit a ceiling
	local pose: SlidePose.Pose? = nil
	local poseCharacter: Model? = nil

	Slide.cancel = function()
		if finish then
			finish(false)
		end
	end
	Slide.jump = function()
		if finish and MoveState.busy == "Slide" then
			finish(true)
			return true
		end
		return false
	end

	-- The ground under the slide: how much it slopes downhill along `dir` (sine of the slope
	-- toward dir: positive downhill, negative uphill, 0 on the flat or in the air).
	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.RespectCanCollide = true
	local function downhill(parts: MoveState.Parts, dir: Vector3): number
		floorParams.FilterDescendantsInstances = { parts.character }
		local hit = workspace:Raycast(parts.root.Position, Vector3.new(0, -6, 0), floorParams)
		if not hit then
			return 0
		end
		return MoveState.flat(hit.Normal):Dot(dir)
	end

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
		local age = 0 -- how long the slide has run
		local slopeSpeed = 0 -- speed slopes have added (less on the way uphill)
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
			local across = Vector3.new(dir.X * speed, 0, dir.Z * speed)
			local up = if jumped then jumpSpeed(hum) else 0
			if up > 0 then
				-- Out of the slide with its speed, higher the faster you were going.
				local sprint = endSpeed * Config.Sprint.Multiplier
				local lift =
					math.min(math.max(speed - sprint, 0) * settings.JumpLift, settings.JumpLiftMax)
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
				root.AssemblyLinearVelocity = across + Vector3.new(0, up + lift, 0)
				MoveState.airVelocity = across
				return
			end
			root.AssemblyLinearVelocity = across + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			if MoveState.isGrounded(hum) and speed > hum.WalkSpeed + 1 then
				MoveState.groundVelocity = across -- GroundMomentum carries it and fades it
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
			age += dt
			-- Slopes: downhill adds speed and holds off the fade; uphill takes speed away. On the
			-- flat, what a slope gave you fades.
			local slope = if grounded then downhill(parts, dir) else 0
			if math.abs(slope) > 0.03 then
				slopeSpeed += workspace.Gravity * settings.SlopeAccel * slope * dt
			elseif grounded then
				local fade = settings.SlopeFade * dt
				slopeSpeed = if slopeSpeed > 0
					then math.max(slopeSpeed - fade, 0)
					else math.min(slopeSpeed + fade, 0)
			end
			if grounded and slope <= 0.03 then
				elapsed += dt
			end
			local alpha = math.min(elapsed / settings.Duration, 1)
			local curve = endSpeed + (startSpeed - endSpeed) * (1 - alpha) ^ 2
			slopeSpeed = math.min(slopeSpeed, settings.MaxSpeed - curve)
			speed = math.clamp(curve + slopeSpeed, 0, settings.MaxSpeed)

			-- Steering: the slide turns toward your keys, relative to where you look (W follows
			-- your view, A/D curve it). Holding back doesn't spin it round.
			local move = MoveState.flat(hum.MoveDirection)
			if move.Magnitude > 0.1 and move.Unit:Dot(dir) > -0.5 then
				local turned =
					MoveState.turnToward(dir, move.Unit, math.rad(settings.TurnRate) * dt)
				if turned.Magnitude > 0.01 then
					dir = turned.Unit
				end
			end
			drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
			MoveState.faceDirection = dir -- feet first: the body points along the slide

			local v = root.AssemblyLinearVelocity
			local hitWall = age > 0.15 and Vector3.new(v.X, 0, v.Z).Magnitude < speed * 0.3
			local blocked = blockedAbove()
			if hitWall or speed < 2 then -- a wall, or an uphill slope that stopped you
				stop(false, grounded and (keyHeld or blocked))
			elseif alpha >= 1 and slopeSpeed <= 0.5 then
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
			-- Just landed? Use the speed you landed with, before ground friction slowed you,
			-- plus the extra a slide gets from the drop.
			local landed = MoveState.landVelocity
			if
				landed
				and os.clock() - MoveState.landTime < settings.LandingGrace
				and landed.Magnitude > flat.Magnitude
			then
				local momentum = Config.Momentum
				local extra = (momentum.LandSlideCarry - momentum.LandCarry) * MoveState.landImpact
				flat = landed + landed.Unit * math.max(extra, 0)
			end
			-- Faster than you can walk (carried momentum) counts as sprinting.
			fast = flat.Magnitude > hum.WalkSpeed + 1
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
		-- Jump out of a slide or crouch, unless a ceiling is in the way. Only on the ground: a
		-- slide that went off an edge jumps through CoyoteJump (in time) or not at all.
		local parts = MoveState.parts()
		if
			finish
			and isBlocked
			and not isBlocked()
			and parts
			and MoveState.isGrounded(parts.humanoid)
		then
			finish(true)
		end
	end)
end

return Slide
