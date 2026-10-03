--!strict
-- The slide animation. Builds two keyframed animations from Config.Slide.Poses and plays them
-- through the character's Animator, the same way Roblox plays the run animation:
--   Slide:   drop (frame 2) -> slide pose (frames 3 to 5), then holds until the slide ends.
--   Recover: slide pose -> lunge (frame 6) -> crouch (frame 7) -> standing (frame 8).
--   Crouch:  the low crouch while holding the slide key without sprinting: an idle pose, and a
--            looping crouch walk while you move. The crouch height is worked out from the
--            character's leg lengths and the pose's knee angles, so the feet sit on the floor.
-- Also sinks the hips (so you fit under low bars) and dips the camera, through Crouch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local Crouch = require(script.Parent.Crouch)

export type Pose = {
	play: () -> (), -- start the slide
	stop: () -> (), -- slide -> recover -> standing
	crouch: () -> (), -- into the crouch (from standing or straight from a slide)
	crouchMove: (speed: number) -> (), -- each frame while crouched: walk cycle when moving
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
local crouchWalkAnimation: Animation? = nil

-- Builds both animations once and reuses them for every character.
local function animations(): (Animation, Animation, Animation, Animation)
	if
		not slideAnimation
		or not recoverAnimation
		or not crouchAnimation
		or not crouchWalkAnimation
	then
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
			{ time = 0, angles = poses.CrouchIdle },
			{ time = 0.1, angles = poses.CrouchIdle, name = HOLD_MARKER },
			{ time = 0.2, angles = poses.CrouchIdle },
		})
		-- Step, mirrored step, back to the first step: one full stride, looping.
		local step = poses.CrouchStep
		crouchWalkAnimation = AnimationBuilder.make({
			{ time = 0, angles = step },
			{ time = settings.CrouchStepTime, angles = AnimationBuilder.mirror(step) },
			{ time = settings.CrouchStepTime * 2, angles = step },
		}, false, true)
	end
	return slideAnimation :: Animation,
		recoverAnimation :: Animation,
		crouchAnimation :: Animation,
		crouchWalkAnimation :: Animation
end

-- How much lower the hips sit in the crouch pose than standing: the thigh and shin each lose
-- height as they bend (length x (1 - cos(angle from straight down))).
local function crouchDrop(character: Model, pose: AnimationBuilder.Angles): number
	local thigh = character:FindFirstChild("RightUpperLeg")
	local shin = character:FindFirstChild("RightLowerLeg")
	if not thigh or not shin or not thigh:IsA("BasePart") or not shin:IsA("BasePart") then
		return 1.2
	end
	local hip = math.rad(pose.RightUpperLeg.X)
	local knee = math.rad(pose.RightLowerLeg.X)
	return thigh.Size.Y * (1 - math.cos(hip)) + shin.Size.Y * (1 - math.cos(hip + knee))
end

function SlidePose.attach(character: Model, humanoid: Humanoid): Pose
	local settings = Config.Slide
	local slide, recover, crouch, crouchWalk = animations()
	local slideTrack = AnimationBuilder.load(humanoid, slide)
	local recoverTrack = AnimationBuilder.load(humanoid, recover)
	local crouchTrack = AnimationBuilder.load(humanoid, crouch)
	local walkTrack = AnimationBuilder.load(humanoid, crouchWalk)

	-- Freeze on the slide and crouch poses until they end.
	for _, track in { slideTrack, crouchTrack } do
		track.KeyframeReached:Connect(function(name)
			if name == HOLD_MARKER then
				track:AdjustSpeed(0)
			end
		end)
	end

	local standingHip = Crouch.standingHip(humanoid)
	local poses = settings.Poses :: { [string]: AnimationBuilder.Angles }
	local crouchHip = math.max(standingHip - crouchDrop(character, poses.CrouchIdle), 0.2)

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
				crouchHip / standingHip,
				settings.DropTime,
				settings.CameraDip * 0.6
			)
		end,
		crouchMove = function(speed: number)
			-- Moving: the walk cycle replaces the idle crouch. Stopped: back to the idle crouch.
			if speed > 0.5 then
				if not walkTrack.IsPlaying then
					crouchTrack:Stop(0.15)
					walkTrack:Play(0.15)
				end
				-- A steady step pace, only a little faster or slower with your speed.
				walkTrack:AdjustSpeed(math.clamp(speed / settings.CrouchSpeed, 0.7, 1.2))
			elseif walkTrack.IsPlaying then
				walkTrack:Stop(0.15)
				crouchTrack:Play(0.15)
			end
		end,
		stand = function()
			crouchTrack:Stop(settings.RiseTime)
			walkTrack:Stop(settings.RiseTime)
			Crouch.set(humanoid, 1, settings.RiseTime, 0)
		end,
		standingHip = standingHip,
		slideHip = standingHip * settings.HipHeightFactor,
		crouchHip = crouchHip,
	}
end

return SlidePose
