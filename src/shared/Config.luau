--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.12.0",

	Tag = {
		Range = 5, -- studs between two characters that counts as a tag
		FreezeTime = 2, -- seconds the newly tagged player is frozen (also stops instant tag-backs)
	},

	Sprint = {
		Key = Enum.KeyCode.LeftShift, -- hold to sprint
		Multiplier = 1.6, -- sprint speed = current walk speed x this
		FovBoost = 8, -- degrees of extra field of view while sprinting (0 turns it off)
		FovTime = 0.2, -- seconds to ease the field of view in and out
	},

	Slide = {
		Key = Enum.KeyCode.C, -- sprinting (or moving fast in the air): slide. Otherwise: crouch.
		StartMultiplier = 1.25, -- slide starts at your current speed x this
		Duration = 0.9, -- seconds for the slide to fade back to walk speed
		DeadSlideTime = 1.75, -- sliding again within this many seconds gives no speed boost
		LandingGrace = 0.3, -- seconds after landing that a slide still gets your air speed
		MaxSpeed = 60, -- a slide never starts faster than this
		CrouchSpeed = 8, -- walk speed while crouched
		CrouchHipFactor = 0.35, -- crouched hips sit at this fraction of normal height (fits under slide bars)
		Steer = 2, -- how much you can turn while sliding (higher = more control)
		HipHeightFactor = 0.3, -- hips sink to this fraction of their normal height
		CameraDip = 1.5, -- studs the camera drops during a slide
		DropTime = 0.15, -- seconds from the drop pose into the full slide pose
		RiseTime = 0.3, -- seconds for the hips and camera to come back up
		HeadClearance = 2.5, -- studs from the body center to the top of the head when standing
		BlockerGroup = "SlideBlocker", -- collision group for invisible parts only sliders can pass
		SlidingGroup = "Sliding", -- collision group the character uses while sliding

		-- Slide animation, built from the reference frames. Each pose is degrees of rotation per
		-- body part (X = tip forward/back, Y = twist, Z = sideways), relative to standing.
		-- Positive X on LowerTorso leans the body back. Positive X on an upper leg or upper arm
		-- swings it forward. Negative X on a lower leg bends the knee.
		Poses = {
			Drop = { -- frame 2: dropping into the slide
				LowerTorso = Vector3.new(20, 0, 0),
				UpperTorso = Vector3.new(-10, 0, 0),
				RightUpperLeg = Vector3.new(45, 0, 0),
				RightLowerLeg = Vector3.new(-30, 0, 0),
				LeftUpperLeg = Vector3.new(-5, 0, 0),
				LeftLowerLeg = Vector3.new(-60, 0, 0),
				RightUpperArm = Vector3.new(50, 0, 10),
				LeftUpperArm = Vector3.new(-30, 0, -10),
			},
			Slide = { -- frames 3 to 5: leaning back, lead leg out front, arm up
				LowerTorso = Vector3.new(55, 0, 0),
				UpperTorso = Vector3.new(-15, 0, 0),
				Head = Vector3.new(-30, 0, 0),
				RightUpperLeg = Vector3.new(38, 0, 0),
				RightLowerLeg = Vector3.new(-5, 0, 0),
				LeftUpperLeg = Vector3.new(70, 0, -10),
				LeftLowerLeg = Vector3.new(-100, 0, 0),
				RightUpperArm = Vector3.new(120, 0, 15),
				RightLowerArm = Vector3.new(-30, 0, 0),
				LeftUpperArm = Vector3.new(-45, 0, -40),
				LeftLowerArm = Vector3.new(-15, 0, 0),
			},
			Lunge = { -- frame 6: pushing back up, one leg forward
				LowerTorso = Vector3.new(-10, 0, 0),
				UpperTorso = Vector3.new(-10, 0, 0),
				RightUpperLeg = Vector3.new(60, 0, 0),
				RightLowerLeg = Vector3.new(-70, 0, 0),
				LeftUpperLeg = Vector3.new(-30, 0, 0),
				LeftLowerLeg = Vector3.new(-40, 0, 0),
				RightUpperArm = Vector3.new(40, 0, 0),
				LeftUpperArm = Vector3.new(-30, 0, 0),
			},
			CrouchWalk = { -- holding C without sprinting: low crouch to get under things
				LowerTorso = Vector3.new(-15, 0, 0),
				UpperTorso = Vector3.new(-10, 0, 0),
				Head = Vector3.new(20, 0, 0),
				RightUpperLeg = Vector3.new(75, 0, 0),
				RightLowerLeg = Vector3.new(-120, 0, 0),
				LeftUpperLeg = Vector3.new(75, 0, 0),
				LeftLowerLeg = Vector3.new(-120, 0, 0),
				RightUpperArm = Vector3.new(25, 0, 10),
				LeftUpperArm = Vector3.new(25, 0, -10),
			},
			Crouch = { -- frame 7: rising through a crouch
				LowerTorso = Vector3.new(-10, 0, 0),
				UpperTorso = Vector3.new(-10, 0, 0),
				RightUpperLeg = Vector3.new(50, 0, 0),
				RightLowerLeg = Vector3.new(-80, 0, 0),
				LeftUpperLeg = Vector3.new(50, 0, 0),
				LeftLowerLeg = Vector3.new(-80, 0, 0),
				RightUpperArm = Vector3.new(20, 0, 10),
				LeftUpperArm = Vector3.new(20, 0, -10),
			},
		},
		RecoverLungeTime = 0.1, -- seconds into the recovery when the lunge pose is reached
		RecoverCrouchTime = 0.2, -- ... the crouch pose
		RecoverStandTime = 0.3, -- ... standing (frame 8)
	},

	AirStrafe = {
		-- In the air, your movement keys (camera-relative) bend your path without losing speed.
		TurnRate = 140, -- degrees per second your air path can turn toward where you steer
		BrakeRate = 20, -- studs/s per second you slow down when steering backwards
		AirControl = 40, -- studs/s per second you can speed up while slower than walk speed
		WallStop = 0.5, -- if a wall cuts your speed below this fraction, carry the slower speed
	},

	WallBounce = {
		-- Touch a wall in the air and press jump right away to push off it.
		Reach = 2, -- studs from your body that counts as touching a wall
		Window = 0.2, -- seconds after touching a wall that a jump still bounces
		OutSpeed = 26, -- studs/s pushed away from the wall
		UpSpeed = 38, -- studs/s upward
		KeepAlong = 0.8, -- fraction of your speed along the wall that you keep
		Cooldown = 0.25, -- seconds between bounces
	},

	Vault = {
		-- Press jump while sprinting at a low obstacle: hands on the top, then launched up and out.
		MinHeight = 1.5, -- studs above your feet: lower than this, just run or jump
		MaxHeight = 4.2, -- studs above your feet: taller than this, mantle instead
		MaxDepth = 4, -- obstacles thicker than this are platforms, not vaults
		Reach = 5, -- how far ahead (studs) an obstacle can be when you press jump
		Clearance = 0.3, -- extra studs the body clears the top by
		PlantTime = 0.15, -- longest it takes to get your hands onto the top before the launch
		LaunchForward = 50, -- studs/s forward at launch (about 25 to 30 studs of flight)
		LaunchUp = 50, -- studs/s upward at launch (equal to forward = about a 45 degree arc)
		MaxLaunchSpeed = 60, -- coming in faster than LaunchForward launches faster, up to this
		HipHeightFactor = 0.4, -- legs tuck up to this fraction of normal hip height
		Poses = {
			Vault = { -- hands down on the top, legs tucked up
				LowerTorso = Vector3.new(-20, 0, 0),
				Head = Vector3.new(15, 0, 0),
				RightUpperArm = Vector3.new(70, 0, 10),
				LeftUpperArm = Vector3.new(70, 0, -10),
				RightUpperLeg = Vector3.new(80, 0, 0),
				RightLowerLeg = Vector3.new(-100, 0, 0),
				LeftUpperLeg = Vector3.new(80, 0, 0),
				LeftLowerLeg = Vector3.new(-100, 0, 0),
			},
		},
	},

	Mantle = {
		-- Jump at a ledge and you grab it and pull yourself up automatically. You stop at the top.
		Reach = 2.5, -- how far ahead (studs) the ledge face can be
		MinAbove = 1.6, -- ledge top must be at least this far above your feet
		MaxAbove = 3.5, -- and at most this far above the middle of your body (hands up)
		Forward = 1.5, -- studs past the edge where you end up standing
		UpTime = 0.35, -- seconds to pull up
		OverTime = 0.2, -- seconds to climb over the edge
		Cooldown = 0.4, -- seconds before you can mantle again
		MaxRiseSpeed = 8, -- only grab once your jump has nearly peaked (rising slower than this)
		-- Mantle Boost: press jump inside this window (seconds after the climb starts) to launch
		-- up and over. Too early and you just climb. An on-screen indicator shows the timing.
		BoostWindowStart = 0.22,
		BoostWindowEnd = 0.4,
		BoostForward = 68, -- studs/s forward at the boost (about 38 studs of flight)
		BoostUp = 55, -- studs/s upward at the boost
		Poses = {
			Hang = { -- arms up holding the edge
				RightUpperArm = Vector3.new(170, 0, 10),
				LeftUpperArm = Vector3.new(170, 0, -10),
				RightUpperLeg = Vector3.new(10, 0, 0),
				RightLowerLeg = Vector3.new(-20, 0, 0),
				LeftUpperLeg = Vector3.new(10, 0, 0),
				LeftLowerLeg = Vector3.new(-20, 0, 0),
			},
			PullUp = { -- pushing down on the edge, one knee up onto it
				LowerTorso = Vector3.new(-25, 0, 0),
				RightUpperArm = Vector3.new(30, 0, 15),
				RightLowerArm = Vector3.new(-90, 0, 0),
				LeftUpperArm = Vector3.new(30, 0, -15),
				LeftLowerArm = Vector3.new(-90, 0, 0),
				RightUpperLeg = Vector3.new(80, 0, 0),
				RightLowerLeg = Vector3.new(-100, 0, 0),
			},
		},
	},

	Avatar = {
		UseOwnAvatar = false, -- false = everyone is the classic block avatar (easier to see animations)
		-- Classic 2012 colors, used when UseOwnAvatar is false.
		HeadColor = Color3.fromRGB(245, 205, 48), -- Bright yellow
		TorsoColor = Color3.fromRGB(13, 105, 172), -- Bright blue
		ArmColor = Color3.fromRGB(245, 205, 48), -- Bright yellow
		LegColor = Color3.fromRGB(164, 189, 71), -- Br. yellowish green
	},

	Speed = {
		Runner = 16,
		It = 18, -- a little faster so It can catch people
	},

	Colors = {
		It = Color3.fromRGB(255, 60, 60),
		Runner = Color3.fromRGB(75, 151, 75),
		HudBackground = Color3.fromRGB(20, 20, 20),
		Text = Color3.fromRGB(255, 255, 255),
		BoostReady = Color3.fromRGB(40, 210, 210), -- mantle boost window open (cyan)
		BoostMissed = Color3.fromRGB(120, 120, 120), -- mantle boost missed
	},

	Ui = {
		Font = Enum.Font.SourceSansBold,
	},
}

return Config
