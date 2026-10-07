--!strict
-- Wall running, automatic like the parkour reference: jump alongside a wall while sprinting (or
-- moving fast) and you run along it, rising a little then sinking, with the camera leaning away
-- from the wall, following the wall as it curves (round towers). Ends when the wall does or time
-- runs out. Jump during a wall run to drop off it early, keeping your speed (no kick off the
-- wall). Heading straight into a wall does nothing (there's no wall climb).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local CameraKick = require(script.Parent.CameraKick)
local MoveState = require(script.Parent.MoveState)
local Sprint = require(script.Parent.Sprint)

local WallRun = {}

type Parts = MoveState.Parts

-- Animations, built on first use: "RunLeft", "RunRight".
local animations: { [string]: Animation } = {}

local function getAnimation(name: string): Animation
	local cached = animations[name]
	if cached then
		return cached
	end
	local settings = Config.WallRun
	local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
	local stepTime = settings.StepTime
	local function steps(
		a: AnimationBuilder.Angles,
		b: AnimationBuilder.Angles
	): { AnimationBuilder.Key }
		return {
			{ time = 0, angles = a },
			{ time = stepTime, angles = b },
			{ time = stepTime * 2, angles = a },
		}
	end
	local keys
	if name == "RunLeft" then
		keys = steps(poses.RunA, poses.RunB)
	else
		keys = steps(AnimationBuilder.mirror(poses.RunA), AnimationBuilder.mirror(poses.RunB))
	end
	local animation = AnimationBuilder.make(keys, true, true)
	animations[name] = animation
	return animation
end

function WallRun.start()
	local settings = Config.WallRun
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local lastWallNormal: Vector3? = nil
	local lastWallTime = -math.huge
	local tracks: { [string]: AnimationTrack } = {}
	local trackHumanoid: Humanoid? = nil
	local onJump: (() -> ())? = nil -- set while a wall run is running

	local function play(hum: Humanoid, name: string): AnimationTrack
		if trackHumanoid ~= hum then
			table.clear(tracks)
			trackHumanoid = hum
		end
		local track = tracks[name]
		if not track then
			track = AnimationBuilder.load(hum, getAnimation(name))
			tracks[name] = track
		end
		local active = track :: AnimationTrack
		active:Play(0.1)
		return active
	end

	-- Casts from the body toward the wall (along -normal). Returns the hit, if the wall is there.
	local function wallAt(parts: Parts, normal: Vector3, ahead: Vector3?): RaycastResult?
		params.FilterDescendantsInstances = { parts.character }
		local origin = parts.root.Position + (ahead or Vector3.zero)
		local hit = workspace:Raycast(
			origin,
			-normal * (parts.root.Size.X / 2 + settings.Reach + 0.5),
			params
		)
		if hit and math.abs(hit.Normal.Y) < 0.3 then
			return hit
		end
		return nil
	end

	-- Leaves the wall: stops the move, and remembers the wall so it isn't grabbed again at once.
	local function leave(normal: Vector3, release: () -> (), track: AnimationTrack)
		release()
		track:Stop(0.15)
		MoveState.busy = nil
		MoveState.faceDirection = nil
		onJump = nil
		lastWallNormal = normal
		lastWallTime = os.clock()
		CameraKick.lean(0)
	end

	local function wallRun(parts: Parts, normal: Vector3, along: Vector3, speed: number)
		MoveState.busy = "WallRun"
		MoveState.faceDirection = along
		-- Which side of the body the wall is on, with the body facing along the wall.
		local right = along:Cross(Vector3.yAxis)
		local side = if (-normal):Dot(right) < 0 then "Left" else "Right"
		MoveState.wallSide = side
		local drive, release = MoveState.drive(parts.root, false)
		local track = play(parts.humanoid, "Run" .. side)
		-- Lean the view away from the wall.
		local wallOnLeft = workspace.CurrentCamera.CFrame.RightVector:Dot(normal) > 0
		CameraKick.lean(if wallOnLeft then -settings.LeanRoll else settings.LeanRoll)
		local elapsed = 0
		local connection: RBXScriptConnection

		local function finish()
			connection:Disconnect()
			leave(normal, release, track)
			MoveState.airVelocity = along * speed -- keep the run's speed into the air
		end
		onJump = function()
			finish() -- drop off the wall early, keeping the run's speed
		end

		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			local hum = parts.humanoid
			if not hum.Parent or hum.Health <= 0 then
				finish()
				return
			end
			-- Follow the wall's surface: on a curved wall (a round tower) the wall turns as you
			-- run, so turn the run with it, keeping parallel to the surface beside you.
			local beside = wallAt(parts, normal)
			if beside then
				local surface = Vector3.new(beside.Normal.X, 0, beside.Normal.Z)
				if surface.Magnitude > 0.5 then
					normal = surface.Unit
					local flat = along - normal * along:Dot(normal)
					if flat.Magnitude > 0.1 then
						along = flat.Unit
						MoveState.faceDirection = along
					end
				end
			end
			local wallEnds = not wallAt(parts, normal, along * 1.5)
			local steerAway = hum.MoveDirection:Dot(normal) > 0.5
			if
				elapsed >= settings.RunTime
				or wallEnds
				or steerAway
				or MoveState.isGrounded(hum)
			then
				finish()
				return
			end
			-- Along the wall, rising a little at first and sinking by the end, held RunGap
			-- studs from the wall so the tilted body's feet run on it.
			local f = elapsed / settings.RunTime
			local vertical = settings.RunLift + (-settings.RunSink - settings.RunLift) * f
			if
				vertical > 0
				and MoveState.headroom(parts, settings.CeilingStop + vertical * dt)
					<= settings.CeilingStop + vertical * dt
			then
				vertical = 0 -- don't rise into a ceiling
			end
			local gap = if beside then beside.Distance else settings.RunGap
			local inward = math.clamp((gap - settings.RunGap) * 12, -6, 20)
			drive.VectorVelocity = along * speed + Vector3.new(0, vertical, 0) - normal * inward
		end)
	end

	-- Looks for a wall to run on.
	RunService.Heartbeat:Connect(function()
		if MoveState.busy then
			return
		end
		local parts = MoveState.parts()
		if not parts or MoveState.isGrounded(parts.humanoid) then
			return
		end
		local hum, root = parts.humanoid, parts.root
		local flat = MoveState.flat(root.AssemblyLinearVelocity)
		local fast = Sprint.isSprinting() or flat.Magnitude >= settings.MinEntrySpeed
		if not fast then
			return
		end
		local heading = MoveState.flat(hum.MoveDirection)
		if heading.Magnitude < 0.1 then
			heading = flat
		end
		if heading.Magnitude < 0.1 then
			return
		end
		heading = heading.Unit

		-- Look ahead, to both sides and both diagonals, and take the nearest wall. (A wall run
		-- starts with the wall beside you, which a single ray straight ahead would miss.)
		params.FilterDescendantsInstances = { parts.character }
		local reach = root.Size.X / 2 + settings.Reach
		local side = heading:Cross(Vector3.yAxis)
		local hit: RaycastResult? = nil
		for _, direction in { heading, side, -side, (heading + side).Unit, (heading - side).Unit } do
			local result = workspace:Raycast(root.Position, direction * reach, params)
			if
				result
				and math.abs(result.Normal.Y) < 0.3
				and (not hit or result.Distance < hit.Distance)
			then
				hit = result
			end
		end
		if not hit then
			return
		end
		local normal = MoveState.flat(hit.Normal).Unit
		-- Don't grab the wall you just left.
		if
			lastWallNormal
			and os.clock() - lastWallTime < settings.Cooldown
			and normal:Dot(lastWallNormal) > 0.9
		then
			return
		end
		if os.clock() - MoveState.launchTime < 0.15 then
			return
		end

		local facing = heading:Dot(-normal)
		if facing < math.cos(math.rad(settings.HeadOnAngle)) and facing > -0.3 then
			-- Beside it or glancing into it (not moving away): run along it.
			local along = heading - normal * heading:Dot(normal)
			if along.Magnitude > 0.2 then
				wallRun(parts, normal, along.Unit, math.max(flat.Magnitude, settings.RunSpeed))
			end
		end
	end)

	-- A fresh jump press during a wall run.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not onJump then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			(onJump :: () -> ())()
		end
	end)
end

return WallRun
