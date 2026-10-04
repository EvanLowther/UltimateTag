--!strict
-- Jump at a ledge (Config.Mantle reach) and you grab it and pull yourself up automatically.
-- Only grabs near the top of a jump or while falling, and only while you're moving toward the
-- ledge, so normal jumps are untouched.
-- You stop at the top. No sprint needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Crouch = require(script.Parent.Crouch)
local MoveState = require(script.Parent.MoveState)

local Mantle = {}

-- Set by Mantle.start(). Starts a climb-up toward a direction; false if there's no ledge.
Mantle.climbToward = function(_toward: Vector3): boolean
	return false
end

local FADE = 0.05 -- seconds to cross-fade into the mantle animation

local animation: Animation? = nil

-- One second long, so playing it at speed 1 / duration fits the mantle time.
local function getAnimation(): Animation
	if not animation then
		local settings = Config.Mantle
		local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
		local split = settings.UpTime / (settings.UpTime + settings.OverTime)
		animation = AnimationBuilder.make({
			{ time = 0, angles = poses.Hang },
			{ time = split, angles = poses.PullUp },
			{ time = 1, angles = {} },
		})
	end
	return animation :: Animation
end

-- Looks for a ledge in front you can grab. Returns where your body should end up (or nil),
-- and the flat direction you were heading. `toward` overrides the direction (used when another
-- move, like a wall climb, hands over to a climb-up).
local function findLedge(
	character: Model,
	hum: Humanoid,
	root: BasePart,
	toward: Vector3?
): (Vector3?, Vector3)
	local settings = Config.Mantle
	-- Look the way you're steering. No input means you're not jumping at anything.
	local move = toward or hum.MoveDirection
	local dir = Vector3.new(move.X, 0, move.Z)
	if dir.Magnitude < 0.1 then
		return nil, dir
	end
	dir = dir.Unit
	local feetY = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- 1. A steep face in front, at least MinAbove up from your feet.
	local origin = Vector3.new(root.Position.X, feetY + settings.MinAbove, root.Position.Z)
	local wall = workspace:Raycast(origin, dir * settings.Reach, params)
	if not wall or math.abs(wall.Normal.Y) > 0.5 then
		return nil, dir
	end

	-- 2. Its top is within reach of your hands, and flat enough to stand on.
	local highest = root.Position.Y + settings.MaxAbove
	local lowest = feetY + settings.MinAbove
	local overTop = Vector3.new(wall.Position.X, highest, wall.Position.Z) + dir * 0.6
	local top = workspace:Raycast(overTop, Vector3.new(0, lowest - highest, 0), params)
	if not top or top.Normal.Y < 0.7 then
		return nil, dir
	end
	-- Low obstacles (vault height from the floor in front of them) belong to the auto vault,
	-- not Mantle: otherwise jumping at one turns into a slow pull-up.
	local base = Vector3.new(wall.Position.X, top.Position.Y, wall.Position.Z) - dir * 0.6
	local floor = workspace:Raycast(base, Vector3.new(0, -60, 0), params)
	if floor and top.Position.Y - floor.Position.Y <= Config.Vault.MaxHeight then
		return nil, dir
	end

	-- 3. Somewhere to stand past the edge, with headroom.
	local standPoint = Vector3.new(wall.Position.X, top.Position.Y, wall.Position.Z)
		+ dir * settings.Forward
	if
		not workspace:Raycast(standPoint + Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0), params)
	then
		return nil, dir
	end
	local bodyHeight = Crouch.standingHip(hum) + root.Size.Y
	if
		workspace:Raycast(
			standPoint + Vector3.new(0, 0.1, 0),
			Vector3.new(0, bodyHeight + 2, 0),
			params
		)
	then
		return nil, dir
	end

	return standPoint + Vector3.new(0, Crouch.standingHip(hum) + root.Size.Y / 2, 0), dir
end

function Mantle.start()
	local settings = Config.Mantle
	local lastEnd = -math.huge
	local trackHumanoid: Humanoid? = nil
	local track: AnimationTrack? = nil

	local function mantle(hum: Humanoid, root: BasePart, goal: Vector3)
		MoveState.busy = "Mantle"
		local drive, release = MoveState.drive(root, false)

		if trackHumanoid ~= hum or not track then
			track = AnimationBuilder.load(hum, getAnimation())
			trackHumanoid = hum
		end
		local activeTrack = track :: AnimationTrack
		activeTrack:Play(FADE)
		activeTrack:AdjustSpeed(1 / (settings.UpTime + settings.OverTime))

		-- Two steps: straight up the wall until level with the goal, then forward over the edge.
		local upTarget = Vector3.new(root.Position.X, goal.Y + 0.2, root.Position.Z)
		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			local total = settings.UpTime + settings.OverTime
			if not hum.Parent or hum.Health <= 0 or elapsed >= total then
				connection:Disconnect()
				release()
				MoveState.busy = nil
				lastEnd = os.clock()
				if hum.Parent then
					-- You stop at the top.
					root.AssemblyLinearVelocity = Vector3.zero
				end
				return
			end
			local target, timeLeft
			if elapsed < settings.UpTime then
				target, timeLeft = upTarget, settings.UpTime - elapsed
			else
				target, timeLeft = goal, total - elapsed
			end
			drive.VectorVelocity = (target - root.Position) / math.max(timeLeft, dt)
		end)
	end

	RunService.Heartbeat:Connect(function()
		if MoveState.busy or os.clock() - lastEnd < settings.Cooldown then
			return
		end
		local parts = MoveState.parts()
		if not parts or MoveState.isGrounded(parts.humanoid) then
			return
		end
		local hum, root = parts.humanoid, parts.root
		-- Wait until the jump has nearly peaked, so a normal jump onto or over something still
		-- works, and tapping jump never mantles.
		if root.AssemblyLinearVelocity.Y > settings.MaxRiseSpeed then
			return
		end
		local goal = findLedge(parts.character, hum, root)
		if goal then
			mantle(hum, root, goal)
		end
	end)

	-- Lets another move (a wall climb or ledge hang) start a climb-up toward `toward`.
	-- Returns false if there's no ledge to climb onto there.
	Mantle.climbToward = function(toward: Vector3): boolean
		local parts = MoveState.parts()
		if not parts or MoveState.busy then
			return false
		end
		local goal = findLedge(parts.character, parts.humanoid, parts.root, toward)
		if not goal then
			return false
		end
		mantle(parts.humanoid, parts.root, goal)
		return true
	end
end

return Mantle
