--!strict
-- Carry and fade: when you end up on the ground faster than you can run (landing from a fall, a
-- slide ending fast, being knocked back by a hit), you keep that speed along the ground and it
-- fades back to your walk speed (Config.Momentum.GroundDecay) instead of Roblox snapping you to
-- it the moment you touch down. Your keys turn it (GroundTurnRate); steering backwards brakes
-- harder. Frozen players (walk speed 0) skid to a stop.
-- It only starts from hand-offs (the landing speed AirMomentum records, MoveState.groundVelocity
-- from a slide or a knockback), never from how fast you happen to be moving on the ground, so
-- trains and moving platforms can't set it off. It lets go when another move starts, when you
-- leave the ground (handing the speed to AirMomentum, so a jump keeps it), when a wall stops
-- you, or once you're back at walk speed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)

local GroundMomentum = {}

function GroundMomentum.start()
	local settings = Config.Momentum
	local carried: Vector3? = nil
	local drive: LinearVelocity? = nil
	local release: (() -> ())? = nil
	local driven: BasePart? = nil
	local usedLanding = -math.huge -- the landing (MoveState.landTime) already picked up

	local function stop()
		if release then
			release()
		end
		carried, drive, release, driven = nil, nil, nil, nil
	end

	RunService.Heartbeat:Connect(function(dt)
		local parts = MoveState.parts()
		if not parts or MoveState.busy then
			stop()
			return
		end
		local hum, root = parts.humanoid, parts.root
		local grounded = MoveState.isGrounded(hum)

		-- Hand-offs: a move that ended fast, or a landing.
		local handoff = MoveState.groundVelocity
		MoveState.groundVelocity = nil
		if not handoff and grounded and MoveState.landTime ~= usedLanding then
			usedLanding = MoveState.landTime
			handoff = MoveState.landVelocity
		end
		if handoff and grounded then
			local flat = MoveState.flat(handoff)
			if flat.Magnitude > hum.WalkSpeed + 1 then
				carried = flat.Unit * math.min(flat.Magnitude, settings.MaxGroundSpeed)
			end
		end
		local current = carried
		if not current then
			return
		end
		if not grounded then
			-- Jumped or ran off an edge: the air carries it on.
			MoveState.airVelocity = current
			stop()
			return
		end
		-- A wall stopped you.
		local actual = MoveState.flat(root.AssemblyLinearVelocity)
		if
			driven == root
			and actual.Magnitude < current.Magnitude * Config.AirMomentum.WallStop
		then
			stop()
			return
		end

		-- Steer, then fade.
		local fade = settings.GroundDecay * dt
		local wish = MoveState.flat(hum.MoveDirection)
		if wish.Magnitude > 0.1 then
			wish = wish.Unit
			if current.Unit:Dot(wish) < -0.5 then
				fade *= 2 -- steering backwards brakes
			else
				current =
					MoveState.turnToward(current, wish, math.rad(settings.GroundTurnRate) * dt)
			end
		end
		local speed = current.Magnitude - fade
		if speed <= hum.WalkSpeed + 0.5 then
			stop() -- back to normal running
			return
		end
		current = current.Unit * speed
		carried = current

		if driven ~= root then
			stop()
			carried = current
			local newDrive, newRelease = MoveState.drive(root, true)
			drive, release, driven = newDrive, newRelease, root
		end
		local active = drive :: LinearVelocity
		active.PlaneVelocity = Vector2.new(current.X, current.Z)
	end)
end

return GroundMomentum
