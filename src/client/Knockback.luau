--!strict
-- Getting hit by a swing (a tag or a shove) knocks you back. server/TagService works out the
-- push from how fast the swinger was moving at you and sends it here (TagKnockback); your client
-- owns your character's physics, so it applies it and everyone sees it. In the air the push is
-- Config.Knockback.AirMultiplier times as strong and pops you up higher (AirPop). A hit ends a
-- slide or crouch; ladders, wall runs, launch pads and train pushes aren't interrupted.
-- While you fly back, MoveState.busy is "Knockback" and a flat drive holds the push (so your keys
-- and Roblox's air control can't cancel it; a wall stops it). When you land, GroundMomentum
-- carries it on and fades it, so you skid back (to a stop, if you were tagged and frozen).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local MoveState = require(script.Parent.MoveState)
local Slide = require(script.Parent.Slide)

local Knockback = {}

-- Moves a hit interrupts (anything else keeps control).
local INTERRUPTS = { Slide = true, Crouch = true, Knockback = true }
local MIN_FLIGHT = 0.1 -- seconds before a landing counts (the pop has to lift you first)

function Knockback.start()
	local settings = Config.Knockback
	local flight: RBXScriptConnection? = nil
	local release: (() -> ())? = nil

	-- Ends the current knockback, if any.
	local function finish()
		if flight then
			flight:Disconnect()
			flight = nil
		end
		if release then
			release()
			release = nil
		end
		if MoveState.busy == "Knockback" then
			MoveState.busy = nil
		end
	end

	Remotes.get("TagKnockback").OnClientEvent:Connect(function(push: Vector3)
		if typeof(push) ~= "Vector3" then
			return
		end
		local parts = MoveState.parts()
		if not parts then
			return
		end
		local busy = MoveState.busy
		if busy and not INTERRUPTS[busy] then
			return
		end
		local hum, root = parts.humanoid, parts.root
		local airborne = not MoveState.isGrounded(hum)
		if busy == "Slide" or busy == "Crouch" then
			Slide.cancel()
		end
		finish() -- a hit while already flying back replaces that one

		local across = MoveState.flat(push) * (if airborne then settings.AirMultiplier else 1)
		local pop = if airborne then settings.AirPop else settings.Pop
		MoveState.busy = "Knockback"
		MoveState.airVelocity = nil
		MoveState.faceDirection = nil
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local rising = math.max(root.AssemblyLinearVelocity.Y, 0)
		root.AssemblyLinearVelocity = across + Vector3.new(0, rising + pop, 0)
		local drive, remove = MoveState.drive(root, true)
		drive.PlaneVelocity = Vector2.new(across.X, across.Z)
		release = remove

		local started = os.clock()
		flight = RunService.Heartbeat:Connect(function()
			if not hum.Parent or hum.Health <= 0 then
				finish()
				return
			end
			local elapsed = os.clock() - started
			-- A wall stops the push.
			local actual = MoveState.flat(root.AssemblyLinearVelocity)
			if
				elapsed > 0.05
				and actual.Magnitude < across.Magnitude * Config.AirMomentum.WallStop
			then
				across = actual
				drive.PlaneVelocity = Vector2.new(across.X, across.Z)
			end
			if elapsed >= MIN_FLIGHT and MoveState.isGrounded(hum) then
				local carried = across
				finish()
				MoveState.groundVelocity = carried -- skid on and fade (GroundMomentum)
				MoveState.groundSkid = true -- whatever keys they hold
			end
		end)
	end)
end

return Knockback
