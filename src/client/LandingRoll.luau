--!strict
-- Landing roll, like the parkour reference: land from a big drop (Config.LandingRoll) while
-- moving and you tuck and roll forward, keeping your speed instead of a hard landing. In third
-- person the body does a full forward roll; in first person the view dips forward instead of
-- spinning. Holding the slide key as you land slides instead (Slide handles that).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local CameraKick = require(script.Parent.CameraKick)
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local LandingRoll = {}

local animation: Animation? = nil

-- A forward roll: the whole body turns a full circle around the waist while tucked.
-- Keys every quarter turn so the rotation always goes the forward way round.
local function getAnimation(): Animation
	if not animation then
		local settings = Config.LandingRoll
		local tuck = (settings.Poses :: { [string]: AnimationBuilder.Angles }).Tuck
		local keys: { AnimationBuilder.Key } = {}
		for i = 0, 4 do
			local angles: AnimationBuilder.Angles = table.clone(tuck)
			angles.LowerTorso = Vector3.new(-90 * i, 0, 0)
			table.insert(keys, { time = settings.Time * i / 4, angles = angles, ease = "In" })
		end
		animation = AnimationBuilder.make(keys)
	end
	return animation :: Animation
end

function LandingRoll.start()
	local settings = Config.LandingRoll
	local wasGrounded = true
	local fallSpeed = 0 -- fastest downward speed during this time in the air
	local airFlat = Vector3.zero -- sideways velocity just before landing
	local track: AnimationTrack? = nil
	local trackHumanoid: Humanoid? = nil

	local function roll(parts: MoveState.Parts, flat: Vector3)
		MoveState.busy = "Roll"
		local hum, root = parts.humanoid, parts.root
		local dir = flat.Unit
		local speed = math.max(flat.Magnitude * settings.KeepSpeed, settings.MinSpeed)
		local drive, release = MoveState.drive(root, true)
		drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)

		if trackHumanoid ~= hum or not track then
			track = AnimationBuilder.load(hum, getAnimation())
			trackHumanoid = hum
		end
		local active = track :: AnimationTrack
		active:Play(0.05)
		if ViewMode.isFirstPerson() then
			CameraKick.kick(0, settings.CameraDip, settings.Time)
		end

		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if not hum.Parent or hum.Health <= 0 or elapsed >= settings.Time then
				connection:Disconnect()
				release()
				active:Stop(0.1)
				MoveState.busy = nil
				-- Come out of the roll still moving.
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
				return
			end
			-- Steer a little with the camera direction you're holding toward.
			local move = MoveState.flat(hum.MoveDirection)
			if move.Magnitude > 0.1 then
				dir = (dir + move.Unit * 2 * dt).Unit
			end
			drive.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
		end)
	end

	RunService.Heartbeat:Connect(function()
		local parts = MoveState.parts()
		if not parts then
			return
		end
		local grounded = MoveState.isGrounded(parts.humanoid)
		local velocity = parts.root.AssemblyLinearVelocity
		if not grounded then
			if wasGrounded then
				fallSpeed = 0
			end
			fallSpeed = math.max(fallSpeed, -velocity.Y)
			airFlat = MoveState.airVelocity or MoveState.flat(velocity)
		elseif not wasGrounded then
			-- Just landed.
			local holdingSlide = UserInputService:IsKeyDown(Config.Slide.Key)
			if
				not MoveState.busy
				and not holdingSlide
				and fallSpeed >= settings.MinFallSpeed
				and airFlat.Magnitude >= settings.MinMoveSpeed
			then
				roll(parts, airFlat)
			end
		end
		wasGrounded = grounded
	end)
end

return LandingRoll
