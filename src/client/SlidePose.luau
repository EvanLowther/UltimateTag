--!strict
-- The slide animation. Builds two keyframed animations from Config.Slide.Poses and plays them
-- through the character's Animator, the same way Roblox plays the run animation:
--   Slide:   drop (frame 2) -> slide pose (frames 3 to 5), then holds until the slide ends.
--   Recover: slide pose -> lunge (frame 6) -> crouch (frame 7) -> standing (frame 8).
--   Crouch:  the low crouch while holding the slide key without sprinting.
-- Also sinks the hips (so you fit under low bars) and dips the camera, through Crouch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Crouch = require(script.Parent.Crouch)

export type Pose = {
	play: () -> (), -- start the slide
	stop: () -> (), -- slide -> recover -> standing
	crouch: () -> (), -- into the crouch (from standing or straight from a slide)
	stand: () -> (), -- crouch -> standing
	standingHip: number,
	slideHip: number,
	crouchHip: number,
}

local SlidePose = {}

local HOLD_MARKER = "Hold" -- keyframe name where the slide animation freezes
local FADE = 0.05 -- seconds to cross-fade between animations

local slideAnimation: Animation? = nil
local recoverAnimation: Animation? = nil
local crouchAnimation: Animation? = nil

-- Builds both animations once and reuses them for every character.
local function animations(): (Animation, Animation, Animation)
	if not slideAnimation or not recoverAnimation or not crouchAnimation then
		local settings = Config.Slide
		local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
		slideAnimation = AnimationBuilder.make({
			{ time = 0, angles = poses.Drop },
			{ time = settings.DropTime, angles = poses.Slide, name = HOLD_MARKER },
			{ time = settings.DropTime + 0.1, angles = poses.Slide },
		})
		recoverAnimation = AnimationBuilder.make({
			{ time = 0, angles = poses.Slide },
			{ time = settings.RecoverLungeTime, angles = poses.Lunge },
			{ time = settings.RecoverCrouchTime, angles = poses.Crouch },
			{ time = settings.RecoverStandTime, angles = {} },
		})
		crouchAnimation = AnimationBuilder.make({
			{ time = 0, angles = poses.CrouchWalk },
			{ time = 0.1, angles = poses.CrouchWalk, name = HOLD_MARKER },
			{ time = 0.2, angles = poses.CrouchWalk },
		})
	end
	return slideAnimation :: Animation, recoverAnimation :: Animation, crouchAnimation :: Animation
end

function SlidePose.attach(_character: Model, humanoid: Humanoid): Pose
	local settings = Config.Slide
	local slide, recover, crouch = animations()
	local slideTrack = AnimationBuilder.load(humanoid, slide)
	local recoverTrack = AnimationBuilder.load(humanoid, recover)
	local crouchTrack = AnimationBuilder.load(humanoid, crouch)

	-- Freeze on the slide and crouch poses until they end.
	for _, track in { slideTrack, crouchTrack } do
		track.KeyframeReached:Connect(function(name)
			if name == HOLD_MARKER then
				track:AdjustSpeed(0)
			end
		end)
	end

	local standingHip = Crouch.standingHip(humanoid)

	return {
		play = function()
			recoverTrack:Stop(FADE)
			slideTrack:Play(FADE)
			slideTrack:AdjustSpeed(1)
			Crouch.set(humanoid, settings.HipHeightFactor, settings.DropTime, settings.CameraDip)
		end,
		stop = function()
			slideTrack:Stop(FADE)
			recoverTrack:Play(FADE)
			Crouch.set(humanoid, 1, settings.RiseTime, 0)
		end,
		crouch = function()
			slideTrack:Stop(settings.DropTime)
			recoverTrack:Stop(FADE)
			crouchTrack:Play(settings.DropTime)
			crouchTrack:AdjustSpeed(1)
			Crouch.set(
				humanoid,
				settings.CrouchHipFactor,
				settings.DropTime,
				settings.CameraDip * 0.6
			)
		end,
		stand = function()
			crouchTrack:Stop(settings.RiseTime)
			Crouch.set(humanoid, 1, settings.RiseTime, 0)
		end,
		standingHip = standingHip,
		slideHip = standingHip * settings.HipHeightFactor,
		crouchHip = standingHip * settings.CrouchHipFactor,
	}
end

return SlidePose
