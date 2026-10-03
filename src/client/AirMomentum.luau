--!strict
-- Keeps your speed in the air. Roblox's own air control drags you back to walk speed, which
-- would kill the momentum from wall runs, swings, slides and vaults. While you're in the air and
-- no move is running, this owns your sideways velocity: you keep your speed, your movement keys
-- turn your path toward where you steer (Config.AirMomentum.TurnRate), and steering backwards
-- brakes. Below walk speed you get normal air control. It also remembers the speed you land
-- with, so a slide right after landing can keep it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

local AirMomentum = {}

-- Turns `v` toward the unit direction `target` by at most `maxAngle` radians, keeping its length.
local function turnToward(v: Vector3, target: Vector3, maxAngle: number): Vector3
	local speed = v.Magnitude
	local from = v.Unit
	local angle = math.acos(math.clamp(from:Dot(target), -1, 1))
	if angle <= maxAngle then
		return target * speed
	end
	local axis = from:Cross(target)
	if axis.Magnitude < 1e-4 then
		return v
	end
	return CFrame.fromAxisAngle(axis.Unit, maxAngle):VectorToWorldSpace(from) * speed
end

function AirMomentum.start()
	local settings = Config.AirMomentum

	RunService.Heartbeat:Connect(function(dt)
		local parts = MoveState.parts()
		if not parts or MoveState.busy or MoveState.isGrounded(parts.humanoid) then
			-- Just landed: remember the speed you landed with.
			if parts and MoveState.airVelocity and MoveState.isGrounded(parts.humanoid) then
				MoveState.landVelocity = MoveState.airVelocity
				MoveState.landTime = os.clock()
			end
			MoveState.airVelocity = nil
			return
		end
		local hum, root = parts.humanoid, parts.root
		local actual = MoveState.flat(root.AssemblyLinearVelocity)

		-- Start from your takeoff speed. If a wall stopped you, carry the slower speed instead.
		local current = MoveState.airVelocity or actual
		if actual.Magnitude < current.Magnitude * settings.WallStop then
			current = actual
		end

		local wish = MoveState.flat(hum.MoveDirection)
		local walk = hum.WalkSpeed
		if wish.Magnitude > 0.1 then
			wish = wish.Unit
			if current.Magnitude < walk then
				-- Slower than walking: normal air control toward where you steer.
				local change = wish * walk - current
				local step = settings.AirControl * dt
				current = if change.Magnitude <= step
					then wish * walk
					else current + change.Unit * step
			elseif current.Unit:Dot(wish) < -0.5 then
				-- Steering backwards: brake.
				current = current.Unit * math.max(current.Magnitude - settings.BrakeRate * dt, 0)
			else
				-- Steering sideways or forwards: turn without losing speed.
				current = turnToward(current, wish, math.rad(settings.TurnRate) * dt)
			end
		end

		MoveState.airVelocity = current
		root.AssemblyLinearVelocity =
			Vector3.new(current.X, root.AssemblyLinearVelocity.Y, current.Z)
	end)
end

return AirMomentum
