--!strict
-- Automatic vault, like the reference video: run into a low obstacle (Config.Vault heights)
-- while sprinting or moving fast and you hop it at full speed, no key and no pause. Works
-- mid-jump too. It's the only vault: Mantle leaves anything this low alone.
--   Thin obstacle: an arc over it, landing just past the far side.
--   Deep obstacle (a step or block): an arc up onto its top.
-- You keep your speed the whole way. Taller things are for Mantle and wall climbing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Crouch = require(script.Parent.Crouch)
local MoveState = require(script.Parent.MoveState)
local Sprint = require(script.Parent.Sprint)

local Vault = {}

local FADE = 0.05

type Plan = {
	dir: Vector3, -- flat direction of travel
	speed: number, -- sideways speed (kept the whole way)
	duration: number,
	rise: number, -- studs the body ends higher than it started (stepping up onto something)
	peak: number, -- extra studs of arc above the straight line from start to end
}

local animation: Animation? = nil

-- One second long: tucks into the vault pose, then eases back out. Played to fit each hop.
local function getAnimation(): Animation
	if not animation then
		local pose = (Config.Vault.Poses :: { [string]: AnimationBuilder.Angles }).Vault
		animation = AnimationBuilder.make({
			{ time = 0, angles = pose, ease = "Out" },
			{ time = 0.6, angles = pose },
			{ time = 1, angles = {} },
		}, true)
	end
	return animation :: Animation
end

-- Looks for something to hop ahead. Returns how to hop it, or nil.
local function findVault(character: Model, hum: Humanoid, root: BasePart): Plan?
	local settings = Config.Vault
	local velocity = MoveState.flat(root.AssemblyLinearVelocity)
	local heading = MoveState.flat(hum.MoveDirection)
	if heading.Magnitude < 0.1 or velocity.Magnitude < hum.WalkSpeed * 0.5 then
		return nil
	end
	local dir = heading.Unit
	local speed = math.max(velocity.Magnitude, hum.WalkSpeed)
	local feetY = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local reach = 1.5 + speed * settings.LookAhead

	-- 1. Something ahead at knee height with a steep face.
	local knee = Vector3.new(root.Position.X, feetY + settings.MinHeight * 0.7, root.Position.Z)
	local wall = workspace:Raycast(knee, dir * reach, params)
	if not wall or math.abs(wall.Normal.Y) > 0.5 then
		return nil
	end
	-- A slide gate (an invisible SlideBlocker under a low bar or slab) is for sliding, not
	-- vaulting: hopping onto it would put you inside whatever hangs above it.
	if wall.Instance:GetAttribute("SlideBlocker") then
		return nil
	end

	-- 2. Its top is between MinHeight and MaxHeight above your feet.
	local probe = Vector3.new(wall.Position.X, feetY + settings.MaxHeight + 0.5, wall.Position.Z)
		+ dir * 0.4
	local top = workspace:Raycast(probe, Vector3.new(0, -(settings.MaxHeight + 0.5), 0), params)
	if not top or top.Normal.Y < 0.7 or top.Instance:GetAttribute("SlideBlocker") then
		return nil
	end
	local topY = top.Position.Y
	local height = topY - feetY
	if height < settings.MinHeight or height > settings.MaxHeight then
		return nil
	end

	-- 3. Thin: hop over to the far side. Deep: step up onto the top.
	local wallDistance = MoveState.flat(wall.Position - root.Position).Magnitude
	local farTop = Vector3.new(wall.Position.X, topY + 0.5, wall.Position.Z)
		+ dir * (settings.MaxDepth + 0.5)
	local deep = workspace:Raycast(farTop, Vector3.new(0, -1, 0), params) ~= nil
	local distance, rise
	if deep then
		distance = wallDistance + settings.Landing
		rise = height -- end standing on top
	else
		local back = workspace:Raycast(
			Vector3.new(wall.Position.X, topY - 0.3, wall.Position.Z)
				+ dir * (settings.MaxDepth + 0.5),
			-dir * (settings.MaxDepth + 0.5),
			params
		)
		local depth = if back
			then MoveState.flat(back.Position - wall.Position).Magnitude
			else settings.MaxDepth
		distance = wallDistance + depth + settings.Landing
		rise = 0
	end

	-- 4. Room for the body above the top (no low ceiling over it).
	local tucked = Crouch.standingHip(hum) * settings.HipHeightFactor
	local clearY = topY + settings.Clearance + root.Size.Y / 2 + tucked
	if
		workspace:Raycast(
			Vector3.new(root.Position.X, clearY + root.Size.Y, root.Position.Z),
			dir * distance,
			params
		)
	then
		return nil
	end

	-- The arc: high enough to be above the top when passing over the obstacle.
	local duration = math.max(distance / speed, settings.MinTime)
	local f = math.clamp(wallDistance / distance, 0.15, 0.85)
	local lineAtWall = root.Position.Y + rise * f -- straight-line height at the wall
	local needed = math.max(clearY - lineAtWall, 0.3)
	local peak = needed / (4 * f * (1 - f))
	return {
		dir = dir,
		speed = distance / duration,
		duration = duration,
		rise = rise,
		peak = math.min(peak, needed * 3),
	}
end

function Vault.start()
	local settings = Config.Vault
	local trackHumanoid: Humanoid? = nil
	local track: AnimationTrack? = nil

	local function vault(hum: Humanoid, root: BasePart, plan: Plan)
		MoveState.busy = "Vault"
		MoveState.faceDirection = plan.dir
		local drive, release = MoveState.drive(root, false)
		Crouch.set(hum, settings.HipHeightFactor, 0.06, 0)
		if trackHumanoid ~= hum or not track then
			track = AnimationBuilder.load(hum, getAnimation())
			trackHumanoid = hum
		end
		local active = track :: AnimationTrack
		active:Play(FADE)
		active:AdjustSpeed(1 / plan.duration)

		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if not hum.Parent or hum.Health <= 0 or elapsed >= plan.duration then
				connection:Disconnect()
				release()
				MoveState.busy = nil
				MoveState.faceDirection = nil
				if hum.Parent then
					Crouch.set(hum, 1, 0.12, 0)
					-- Land running at the same speed.
					local v = root.AssemblyLinearVelocity
					local out = plan.dir * plan.speed
					root.AssemblyLinearVelocity = Vector3.new(out.X, math.min(v.Y, 0), out.Z)
				end
				return
			end
			-- Follow the arc: steady forward, up then down, ending `rise` higher.
			local f = elapsed / plan.duration
			local up = (plan.rise + plan.peak * 4 * (1 - 2 * f)) / plan.duration
			drive.VectorVelocity = plan.dir * plan.speed + Vector3.new(0, up, 0)
		end)
	end

	-- Automatic: checked every frame while running, and during a jump too (so pressing jump just
	-- before an obstacle still hops it). Not while falling fast.
	RunService.Heartbeat:Connect(function()
		if MoveState.busy then
			return
		end
		local parts = MoveState.parts()
		if not parts then
			return
		end
		local hum, root = parts.humanoid, parts.root
		if not MoveState.isGrounded(hum) and root.AssemblyLinearVelocity.Y < -15 then
			return
		end
		local fast = Sprint.isSprinting()
			or MoveState.flat(root.AssemblyLinearVelocity).Magnitude > hum.WalkSpeed
		if not fast then
			return
		end
		local plan = findVault(parts.character, hum, root)
		if plan then
			vault(hum, root, plan)
		end
	end)
end

return Vault
