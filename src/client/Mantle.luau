--!strict
-- Jump at a ledge (Config.Mantle reach) and you grab it and pull yourself up automatically.
-- Only grabs near the top of a jump or while falling, and only while you're moving toward the
-- ledge, so normal jumps are untouched.
-- Slower than a vault: you stop at the top, which is the price for the extra height.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Crouch = require(script.Parent.Crouch)
local MoveState = require(script.Parent.MoveState)

local Mantle = {}

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

-- Looks for a ledge in front you can grab. Returns where your body should end up, or nil.
local function findLedge(character: Model, hum: Humanoid, root: BasePart): Vector3?
	local settings = Config.Mantle
	-- Look the way you're steering. No input means you're not jumping at anything.
	local move = hum.MoveDirection
	local dir = Vector3.new(move.X, 0, move.Z)
	if dir.Magnitude < 0.1 then
		return nil
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
		return nil
	end

	-- 2. Its top is within reach of your hands, and flat enough to stand on.
	local highest = root.Position.Y + settings.MaxAbove
	local lowest = feetY + settings.MinAbove
	local overTop = Vector3.new(wall.Position.X, highest, wall.Position.Z) + dir * 0.6
	local top = workspace:Raycast(overTop, Vector3.new(0, lowest - highest, 0), params)
	if not top or top.Normal.Y < 0.7 then
		return nil
	end

	-- 3. Somewhere to stand past the edge, with headroom.
	local standPoint = Vector3.new(wall.Position.X, top.Position.Y, wall.Position.Z)
		+ dir * settings.Forward
	if
		not workspace:Raycast(standPoint + Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0), params)
	then
		return nil
	end
	local bodyHeight = Crouch.standingHip(hum) + root.Size.Y
	if
		workspace:Raycast(
			standPoint + Vector3.new(0, 0.1, 0),
			Vector3.new(0, bodyHeight + 2, 0),
			params
		)
	then
		return nil
	end

	return standPoint + Vector3.new(0, Crouch.standingHip(hum) + root.Size.Y / 2, 0)
end

function Mantle.start()
	local player = Players.LocalPlayer
	local settings = Config.Mantle
	local lastEnd = -math.huge
	local trackHumanoid: Humanoid? = nil
	local track: AnimationTrack? = nil

	local function mantle(hum: Humanoid, root: BasePart, goal: Vector3)
		MoveState.busy = "Mantle"
		hum.AutoRotate = false
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
					hum.AutoRotate = true
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
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not hum or not root or hum.Health <= 0 then
			return
		end
		if hum.FloorMaterial ~= Enum.Material.Air then
			return
		end
		-- Wait until the jump has nearly peaked, so a normal jump onto or over something still
		-- works, and tapping jump never mantles.
		if root.AssemblyLinearVelocity.Y > settings.MaxRiseSpeed then
			return
		end
		local goal = findLedge(character, hum, root)
		if goal then
			mantle(hum, root, goal)
		end
	end)
end

return Mantle
