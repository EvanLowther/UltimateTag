--!strict
-- Launch vault: press jump while sprinting at a low obstacle (Config.Vault heights). You plant
-- your hands on the top for a split second, then get thrown up and out in the direction you're
-- running, about 25 to 30 studs. From there it's normal physics plus air strafing, and holding
-- slide as you land keeps the speed going. Mantle has the same launch near the top of a climb.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Crouch = require(script.Parent.Crouch)
local MoveState = require(script.Parent.MoveState)
local Sprint = require(script.Parent.Sprint)

local Vault = {}

local FADE = 0.05 -- seconds to cross-fade into the vault animation
local HOLD = 0.4 -- the animation holds the vault pose for this part of its 1 second

type Plan = {
	dir: Vector3, -- flat direction of travel
	entrySpeed: number, -- sideways speed you came in with
	plantPoint: Vector3, -- where your body is when your hands are on the top
	plantTime: number, -- seconds to get there
}

local animation: Animation? = nil

-- One second long: holds the vault pose, then eases back to standing in the air.
local function getAnimation(): Animation
	if not animation then
		local poses = Config.Vault.Poses :: { [string]: AnimationBuilder.Angles }
		animation = AnimationBuilder.make({
			{ time = 0, angles = poses.Vault },
			{ time = HOLD, angles = poses.Vault },
			{ time = 1, angles = {} },
		})
	end
	return animation :: Animation
end

-- Looks for a vaultable obstacle ahead. Returns how to launch off it, or nil.
local function findVault(character: Model, hum: Humanoid, root: BasePart): Plan?
	local settings = Config.Vault
	local velocity = MoveState.flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude < 1 then
		return nil
	end
	local dir = velocity.Unit
	local feetY = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- 1. Something ahead at knee height, with a steep face (not a ramp).
	local kneeOrigin =
		Vector3.new(root.Position.X, feetY + settings.MinHeight * 0.6, root.Position.Z)
	local wall = workspace:Raycast(kneeOrigin, dir * settings.Reach, params)
	if not wall or math.abs(wall.Normal.Y) > 0.5 then
		return nil
	end

	-- 2. Its top is between MinHeight and MaxHeight above your feet.
	local probeY = feetY + settings.MaxHeight + 0.5
	local overTop = Vector3.new(wall.Position.X, probeY, wall.Position.Z) + dir * 0.5
	local top = workspace:Raycast(overTop, Vector3.new(0, -(settings.MaxHeight + 0.5), 0), params)
	if not top then
		return nil
	end
	local topY = top.Position.Y
	local height = topY - feetY
	if height < settings.MinHeight or height > settings.MaxHeight then
		return nil
	end

	-- 3. Thin enough to vault. If the top carries on past MaxDepth, it's a platform.
	local farTop = Vector3.new(wall.Position.X, topY + 0.5, wall.Position.Z)
		+ dir * (settings.MaxDepth + 0.5)
	if workspace:Raycast(farTop, Vector3.new(0, -1, 0), params) then
		return nil
	end

	-- 4. Where your body goes when your hands are on the top, with room above it.
	local tuckedHip = Crouch.standingHip(hum) * settings.HipHeightFactor
	local plantY = topY + settings.Clearance + root.Size.Y / 2 + tuckedHip
	local plantPoint = Vector3.new(wall.Position.X, plantY, wall.Position.Z) + dir * 0.5
	if workspace:Raycast(plantPoint, Vector3.new(0, root.Size.Y + 2, 0), params) then
		return nil
	end

	local entrySpeed = math.max(velocity.Magnitude, hum.WalkSpeed)
	local distance = (plantPoint - root.Position).Magnitude
	return {
		dir = dir,
		entrySpeed = entrySpeed,
		plantPoint = plantPoint,
		plantTime = math.clamp(distance / entrySpeed, 0.06, settings.PlantTime),
	}
end

function Vault.start()
	local settings = Config.Vault
	local trackHumanoid: Humanoid? = nil
	local track: AnimationTrack? = nil

	local function vault(hum: Humanoid, root: BasePart, plan: Plan)
		MoveState.busy = "Vault"
		hum.Jump = false
		local drive, release = MoveState.drive(root, false)
		Crouch.set(hum, settings.HipHeightFactor, 0.08, 0)

		if trackHumanoid ~= hum or not track then
			track = AnimationBuilder.load(hum, getAnimation())
			trackHumanoid = hum
		end
		local activeTrack = track :: AnimationTrack
		activeTrack:Play(FADE)
		-- Hold the vault pose through the plant, then ease out over the start of the flight.
		activeTrack:AdjustSpeed(HOLD / plan.plantTime)

		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if not hum.Parent or hum.Health <= 0 then
				connection:Disconnect()
				release()
				MoveState.busy = nil
				return
			end
			local timeLeft = plan.plantTime - elapsed
			if timeLeft > 0 then
				-- Plant: move your body onto the near edge of the top.
				drive.VectorVelocity = (plan.plantPoint - root.Position) / math.max(timeLeft, dt)
				return
			end

			-- Launch: up and out the way you were running.
			connection:Disconnect()
			release()
			MoveState.busy = nil
			Crouch.set(hum, 1, 0.3, 0)
			local forward =
				math.clamp(plan.entrySpeed, settings.LaunchForward, settings.MaxLaunchSpeed)
			MoveState.launch(root, plan.dir, forward, settings.LaunchUp)
		end)
	end

	UserInputService.JumpRequest:Connect(function()
		local parts = MoveState.parts()
		if MoveState.busy or not parts then
			return
		end
		local hum, root = parts.humanoid, parts.root
		if not Sprint.isSprinting() or not MoveState.isGrounded(hum) then
			return
		end
		local plan = findVault(parts.character, hum, root)
		if plan then
			vault(hum, root, plan)
		end
	end)
end

return Vault
