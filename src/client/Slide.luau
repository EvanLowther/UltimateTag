--!strict
-- Press Config.Slide.Key while sprinting on the ground to slide. You keep your momentum, then
-- it fades to walk speed. You can't stand up under a low ceiling, and jumping out keeps speed.
-- Sliding again within Config.Slide.DeadSlideTime is a "dead slide": no speed boost.
-- Holding the key as you land slides on touchdown, keeping the speed you landed with.
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

	local sliding = false
	local keyHeld = false
	local lastEnd = -math.huge
	local finish: ((jumped: boolean) -> ())? = nil
	local isBlocked: (() -> boolean)? = nil
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

	local function begin()
		local parts = MoveState.parts()
		if MoveState.busy or not parts then
			return
		end
		local character, hum, root = parts.character, parts.humanoid, parts.root
		if not Sprint.isSprinting() or not MoveState.isGrounded(hum) then
			return
		end
		local flat = MoveState.flat(root.AssemblyLinearVelocity)
		-- Just landed? Use the speed you landed with, before ground friction slowed you.
		local landed = MoveState.landVelocity
		if
			landed
			and os.clock() - MoveState.landTime < settings.LandingGrace
			and landed.Magnitude > flat.Magnitude
		then
			flat = landed
		end
		-- You have to be actually running to start a slide.
		if flat.Magnitude < hum.WalkSpeed * 0.5 then
			return
		end

		sliding = true
		MoveState.busy = "Slide"
		MoveState.landVelocity = nil
		local dir = flat.Unit
		-- Dead slide: sliding again too soon still slides, but without the speed boost.
		local dead = os.clock() - lastEnd < settings.DeadSlideTime
		local boost = if dead then 1 else settings.StartMultiplier
		local startSpeed = math.min(flat.Magnitude * boost, settings.MaxSpeed)
		local endSpeed = hum.WalkSpeed / Config.Sprint.Multiplier
		-- One pose per character, made while standing so it remembers the normal hip height.
		if poseCharacter ~= character or not pose then
			pose = SlidePose.attach(character, hum)
			poseCharacter = character
		end
		local activePose = pose :: SlidePose.Pose
		local standingHip = activePose.standingHip
		local slideHip = activePose.slideHip
		local elapsed = 0
		local airTime = 0
		local speed = startSpeed

		local drive, release = MoveState.drive(root, true)
		drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
		drive.Parent = root

		hum.AutoRotate = false
		activePose.play()
		setGroup(character, settings.SlidingGroup)

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = { character }
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.CollisionGroup = settings.SlidingGroup -- ignore the invisible stand blockers

		-- True if standing up now would put your head inside something.
		local function blockedAbove(): boolean
			local reach = (standingHip - slideHip) + settings.HeadClearance
			return workspace:Raycast(root.Position, Vector3.new(0, reach, 0), rayParams) ~= nil
		end

		local connection: RBXScriptConnection
		local function stop(jumped: boolean)
			connection:Disconnect()
			finish = nil
			isBlocked = nil
			sliding = false
			MoveState.busy = nil
			lastEnd = os.clock()
			release()
			activePose.stop()
			if hum.Parent then
				hum.AutoRotate = true
				setGroup(character, "Default")
				if jumped then
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
					hum.Jump = true
				end
			end
		end
		finish = stop
		isBlocked = blockedAbove

		connection = RunService.Heartbeat:Connect(function(dt)
			if not hum.Parent or not root.Parent or hum.Health <= 0 then
				stop(false)
				return
			end
			elapsed += dt
			local alpha = math.min(elapsed / settings.Duration, 1)
			speed = endSpeed + (startSpeed - endSpeed) * (1 - alpha) ^ 2

			-- Limited steering: your input only nudges the slide direction.
			local move = hum.MoveDirection
			if move.Magnitude > 0 then
				dir = (dir + move * settings.Steer * dt).Unit
			end
			drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)

			airTime = if MoveState.isGrounded(hum) then 0 else airTime + dt
			local v = root.AssemblyLinearVelocity
			local hitWall = elapsed > 0.15 and Vector3.new(v.X, 0, v.Z).Magnitude < speed * 0.3
			local timeUp = (alpha >= 1 or not keyHeld) and not blockedAbove()
			if airTime > 0.2 or hitWall or timeUp then
				stop(false)
			end
		end)
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
	-- Holding the slide key as you land starts the slide the moment you touch down.
	local wasGrounded = true
	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		local grounded = parts ~= nil and MoveState.isGrounded(parts.humanoid)
		if grounded and not wasGrounded and keyHeld and not sliding then
			begin()
		end
		wasGrounded = grounded
	end)
	UserInputService.JumpRequest:Connect(function()
		-- Jump out of a slide, unless a ceiling is in the way.
		if sliding and finish and isBlocked and not isBlocked() then
			finish(true)
		end
	end)
end

return Slide
