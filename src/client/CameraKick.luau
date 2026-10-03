--!strict
-- Short camera jolts that make a move feel physical: a roll and a pitch that snap in fast and
-- settle back smoothly. Added on top of the normal camera each frame (the camera rebuilds its
-- own position every frame, so kicks never pile up). Used by the wall bounce.
local RunService = game:GetService("RunService")

local CameraKick = {}

local SNAP = 0.06 -- seconds for a kick to reach full strength before it settles

type Kick = { roll: number, pitch: number, start: number, duration: number }

local kicks: { Kick } = {}
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
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
	if #kicks == 0 then
		RunService:UnbindFromRenderStep("CameraKick")
		bound = false
	end
end

-- Rolls the camera by `roll` degrees (positive tips the view counterclockwise) and pitches it
-- by `pitch` degrees (positive looks up), settling back over `duration` seconds.
function CameraKick.kick(roll: number, pitch: number, duration: number)
	table.insert(
		kicks,
		{ roll = roll, pitch = pitch, start = os.clock(), duration = math.max(duration, SNAP * 2) }
	)
	if not bound then
		bound = true
		-- Right after the camera updates, before the first-person arms are placed.
		RunService:BindToRenderStep("CameraKick", Enum.RenderPriority.Camera.Value + 1, step)
	end
end

return CameraKick
