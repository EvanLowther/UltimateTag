--!strict
-- Camera feel layered on top of the normal camera each frame (the camera rebuilds its own
-- position every frame, so nothing piles up):
--   kick(): a short jolt, a roll and a pitch that snap in fast and settle back (wall bounce).
--   lean(): a held roll that eases toward a target and stays there (wall running).
local RunService = game:GetService("RunService")

local CameraKick = {}

local SNAP = 0.06 -- seconds for a kick to reach full strength before it settles
local LEAN_RATE = 60 -- degrees per second a lean eases toward its target

type Kick = { roll: number, pitch: number, start: number, duration: number }

local kicks: { Kick } = {}
local lean, leanTarget = 0, 0
local lastStep = os.clock()
local bound = false -- whether the per-frame step is running

-- How strong a kick is right now: 0 -> 1 fast, then eases back to 0.
local function strength(kick: Kick, now: number): number
	local t = now - kick.start
	if t < SNAP then
		return t / SNAP
	end
	local settle = math.clamp((t - SNAP) / (kick.duration - SNAP), 0, 1)
	return (1 - settle) ^ 2
end

local function step()
	local now = os.clock()
	local dt = now - lastStep
	lastStep = now
	local roll, pitch = 0, 0
	for i = #kicks, 1, -1 do
		local kick = kicks[i]
		if now - kick.start >= kick.duration then
			table.remove(kicks, i)
		else
			local s = strength(kick, now)
			roll += kick.roll * s
			pitch += kick.pitch * s
		end
	end
	local change = math.clamp(leanTarget - lean, -LEAN_RATE * dt, LEAN_RATE * dt)
	lean += change
	roll += lean

	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
	if #kicks == 0 and lean == 0 and leanTarget == 0 then
		RunService:UnbindFromRenderStep("CameraKick")
		bound = false
	end
end

local function ensureBound()
	if not bound then
		bound = true
		lastStep = os.clock()
		-- Right after the camera updates, before the first-person arms are placed.
		RunService:BindToRenderStep("CameraKick", Enum.RenderPriority.Camera.Value + 1, step)
	end
end

-- Rolls the camera by `roll` degrees (positive tips the view counterclockwise) and pitches it
-- by `pitch` degrees (positive looks up), settling back over `duration` seconds.
function CameraKick.kick(roll: number, pitch: number, duration: number)
	table.insert(
		kicks,
		{ roll = roll, pitch = pitch, start = os.clock(), duration = math.max(duration, SNAP * 2) }
	)
	ensureBound()
end

-- Eases the camera into a held roll of `roll` degrees (0 to level out again).
function CameraKick.lean(roll: number)
	leanTarget = roll
	ensureBound()
end

return CameraKick
