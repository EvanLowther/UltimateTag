--!strict
-- Press jump while sprinting at a low obstacle (Config.Vault heights) to hop over it without
-- losing speed. The body follows an arc that clears the top, then you keep running.
local Players = game:GetService("Players")
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

type Plan = {
	dir: Vector3, -- flat direction of travel
	speed: number, -- sideways speed during the vault
	exitSpeed: number, -- sideways speed when you land (the speed you came in with)
	duration: number,
	peak: number, -- studs the body rises at the top of the arc
}

local animation: Animation? = nil

-- One second long, so playing it at speed 1 / duration fits any vault.
local function getAnimation(): Animation
	if not animation then
		local poses = Config.Vault.Poses :: { [string]: AnimationBuilder.Angles }
		animation = AnimationBuilder.make({
			{ time = 0, angles = poses.Vault },
			{ time = 0.7, angles = poses.Vault },
			{ time = 1, angles = {} },
		})
	end
	return animation :: Animation
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Looks for a vaultable obstacle ahead. Returns how to clear it, or nil.
local function findVault(character: Model, hum: Humanoid, root: BasePart): Plan?
	local settings = Config.Vault
	local velocity = flat(root.AssemblyLinearVelocity)
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

	-- 3. Thin enough to hop over. If the top carries on past MaxDepth, it's a platform.
	local farTop = Vector3.new(wall.Position.X, topY + 0.5, wall.Position.Z)
		+ dir * (settings.MaxDepth + 0.5)
	if workspace:Raycast(farTop, Vector3.new(0, -1, 0), params) then
		return nil
	end
	local backOrigin = Vector3.new(wall.Position.X, topY - 0.3, wall.Position.Z)
		+ dir * (settings.MaxDepth + 0.5)
	local back = workspace:Raycast(backOrigin, -dir * (settings.MaxDepth + 0.5), params)
	local depth = if back then flat(back.Position - wall.Position).Magnitude else settings.MaxDepth

	-- 4. Room for the body above it (no low ceiling).
	local tuckedHip = Crouch.standingHip(hum) * settings.HipHeightFactor
	local clearY = topY + settings.Clearance + root.Size.Y / 2 + tuckedHip
	local wallDistance = flat(wall.Position - root.Position).Magnitude
	local total = wallDistance + depth + settings.Landing
	local headOrigin = Vector3.new(root.Position.X, clearY + root.Size.Y, root.Position.Z)
	if workspace:Raycast(headOrigin, dir * total, params) then
		return nil
	end

	-- The arc: high enough to be above the top over the whole obstacle.
	local exitSpeed = math.max(velocity.Magnitude, hum.WalkSpeed)
	local duration = math.max(total / exitSpeed, settings.MinTime)
	local rise = math.max(clearY - root.Position.Y, 0.3)
	local peak = rise
	for _, distance in { wallDistance, wallDistance + depth } do
		local f = math.clamp(distance / total, 0.15, 0.85)
		peak = math.max(peak, rise / (4 * f * (1 - f)))
	end

	return {
		dir = dir,
		speed = total / duration,
		exitSpeed = exitSpeed,
		duration = duration,
		peak = math.min(peak, rise * 3),
	}
end

function Vault.start()
	local player = Players.LocalPlayer
	local trackHumanoid: Humanoid? = nil
	local track: AnimationTrack? = nil

	local function vault(hum: Humanoid, root: BasePart, plan: Plan)
		MoveState.busy = "Vault"
		hum.AutoRotate = false
		hum.Jump = false
		local drive, release = MoveState.drive(root, false)
		Crouch.set(hum, Config.Vault.HipHeightFactor, 0.08, 0)

		if trackHumanoid ~= hum or not track then
			track = AnimationBuilder.load(hum, getAnimation())
			trackHumanoid = hum
		end
		local activeTrack = track :: AnimationTrack
		activeTrack:Play(FADE)
		activeTrack:AdjustSpeed(1 / plan.duration)

		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if not hum.Parent or hum.Health <= 0 or elapsed >= plan.duration then
				connection:Disconnect()
				release()
				MoveState.busy = nil
				if hum.Parent then
					hum.AutoRotate = true
					Crouch.set(hum, 1, 0.15, 0)
					-- Land running at the speed you came in with.
					local v = root.AssemblyLinearVelocity
					local out = plan.dir * plan.exitSpeed
					root.AssemblyLinearVelocity = Vector3.new(out.X, math.min(v.Y, 0), out.Z)
				end
				return
			end
			-- Follow the arc: sideways at a steady speed, up then down.
			local f = elapsed / plan.duration
			local upSpeed = plan.peak * 4 * (1 - 2 * f) / plan.duration
			drive.VectorVelocity = plan.dir * plan.speed + Vector3.new(0, upSpeed, 0)
		end)
	end

	UserInputService.JumpRequest:Connect(function()
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if MoveState.busy or not character or not hum or not root or hum.Health <= 0 then
			return
		end
		if not Sprint.isSprinting() or hum.FloorMaterial == Enum.Material.Air then
			return
		end
		local plan = findVault(character, hum, root)
		if plan then
			vault(hum, root, plan)
		end
	end)
end

return Vault
