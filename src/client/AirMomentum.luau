--!strict
-- Keeps your speed in the air. Roblox's own air control drags you back to walk speed, which
-- would kill the momentum from wall runs and slides. While you're in the air and
-- no move is running, this owns your sideways velocity: you keep your speed, your movement keys
-- turn your path toward where you steer (Config.AirMomentum.TurnRate), and steering backwards
-- brakes. Below walk speed you get normal air control.
-- Falling builds speed (Config.Momentum): while you're moving and coming down below the height
-- you left the ground from, part of gravity's pull goes into your speed across (FallGain), so the
-- longer the drop, the faster you go. When you land lower than you took off, part of the speed
-- that drop gives (LandCarry; a slide on landing adds more, see client/Slide) is added too. A
-- jump that lands where it started gains nothing, so hopping on flat ground doesn't build speed.
-- The landing speed is remembered (MoveState.landVelocity) for GroundMomentum to carry and for a
-- slide right after landing. Launch pad flights don't gain speed, so they still land where the
-- map aimed them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

local AirMomentum = {}

function AirMomentum.start()
	local settings = Config.AirMomentum
	local momentum = Config.Momentum
	local groundedAt = -math.huge -- the last time you were on the ground
	local groundY = math.huge -- your height when you were last on the ground

	RunService.Heartbeat:Connect(function(dt)
		local parts = MoveState.parts()
		if not parts or MoveState.busy or MoveState.isGrounded(parts.humanoid) then
			-- Just landed: remember the speed you landed with, plus the landing boost.
			local air = MoveState.airVelocity
			local grounded = parts ~= nil and MoveState.isGrounded(parts.humanoid)
			if parts and air and grounded then
				local launched = MoveState.launchTime > groundedAt
				-- The speed the drop below your takeoff height is worth.
				local drop = math.max(groundY - parts.root.Position.Y, 0)
				local impact = if launched then 0 else math.sqrt(2 * workspace.Gravity * drop)
				local landed = air
				if air.Magnitude >= momentum.MinMoving then
					local speed = air.Magnitude + momentum.LandCarry * impact
					landed = air.Unit
						* math.min(speed, math.max(momentum.MaxGroundSpeed, air.Magnitude))
				end
				MoveState.landVelocity = landed
				MoveState.landImpact = impact
				MoveState.landTime = os.clock()
			end
			if grounded and parts then
				groundedAt = os.clock()
				groundY = parts.root.Position.Y
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
				current = MoveState.turnToward(current, wish, math.rad(settings.TurnRate) * dt)
			end
		end

		-- Coming down below where you took off, while moving: the fall feeds your speed (not on
		-- a launch pad's flight).
		local vertical = root.AssemblyLinearVelocity.Y
		local launched = MoveState.launchTime > groundedAt
		if
			vertical < 0
			and root.Position.Y < groundY
			and not launched
			and current.Magnitude >= momentum.MinMoving
			and current.Magnitude < momentum.MaxAirSpeed
		then
			local gained = current.Magnitude + momentum.FallGain * workspace.Gravity * dt
			current = current.Unit * math.min(gained, momentum.MaxAirSpeed)
		end

		MoveState.airVelocity = current
		root.AssemblyLinearVelocity = Vector3.new(current.X, vertical, current.Z)
	end)
end

return AirMomentum
