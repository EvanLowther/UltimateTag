--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.21.1",

	Tag = {
		Range = 5, -- studs between two characters that counts as a tag
		FreezeTime = 2, -- seconds the newly tagged player is frozen (also stops instant tag-backs)
	},

	Sprint = {
		Key = Enum.KeyCode.LeftShift, -- hold to sprint
		Multiplier = 1.7, -- sprint speed = current walk speed x this (about 30 studs/s)
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
		Steer = 2, -- how much your movement keys turn a slide (higher = more control)
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

	AirMomentum = {
		-- In the air, you keep your speed (Roblox's own air control would drag you back to walk
		-- speed and kill the momentum from wall runs, swings and slides). Your keys steer it.
		TurnRate = 160, -- degrees per second your air path can turn toward where you steer
		BrakeRate = 25, -- studs/s per second you slow down when steering backwards
		AirControl = 45, -- studs/s per second you can speed up while slower than walk speed
		WallStop = 0.5, -- if a wall cuts your speed below this fraction, carry the slower speed
	},

	WallRun = {
		-- Jump at a wall while sprinting (or moving fast). Heading straight at it: you run up it
		-- (climb), hang at the top and climb over. Running alongside it: you run along it.
		-- Jump during either to kick off the wall.
		Reach = 2.2, -- studs from your body (ahead, beside or diagonally) that counts as touching a wall
		ClimbAngle = 35, -- heading within this many degrees of straight at the wall = climb;
		-- anything else (beside or glancing) = wall run, unless you're moving away from the wall
		MinEntrySpeed = 18, -- studs/s sideways you need to start one (sprinting always counts)
		Cooldown = 0.4, -- seconds before you can grab the same wall again
		ClimbSpeed = 30, -- studs/s up the wall at the start of a climb (slows to 0 over ClimbTime)
		ClimbTime = 0.8,
		HangTime = 4, -- seconds you can hang at the top before dropping
		HangMin = 0.15, -- seconds you hang before a held forward key climbs you over
		RunSpeed = 30, -- slowest wall run (studs/s); faster entries keep their speed
		RunTime = 1.6, -- longest wall run in seconds
		RunLift = 8, -- studs/s upward at the start of a wall run
		RunSink = 6, -- studs/s downward by the end of a wall run
		JumpOut = 28, -- kicking off the wall: studs/s away from it
		JumpUp = 40, -- kicking off the wall: studs/s up
		KeepAlong = 0.9, -- kicking off a wall run: fraction of your run speed you keep
		LeanRoll = 12, -- degrees the camera leans away from the wall while wall running
		-- Third-person poses. Wall-run poses are written for a wall on your LEFT (mirrored for the right).
		Poses = {
			ClimbA = { -- right hand reaching up, left knee up
				RightUpperArm = Vector3.new(170, 0, 10),
				RightLowerArm = Vector3.new(-10, 0, 0),
				LeftUpperArm = Vector3.new(110, 0, -10),
				LeftLowerArm = Vector3.new(-60, 0, 0),
				LeftUpperLeg = Vector3.new(70, 0, 0),
				LeftLowerLeg = Vector3.new(-80, 0, 0),
				RightUpperLeg = Vector3.new(5, 0, 0),
				RightLowerLeg = Vector3.new(-20, 0, 0),
			},
			ClimbB = { -- the mirror step: left hand up, right knee up
				LeftUpperArm = Vector3.new(170, 0, -10),
				LeftLowerArm = Vector3.new(-10, 0, 0),
				RightUpperArm = Vector3.new(110, 0, 10),
				RightLowerArm = Vector3.new(-60, 0, 0),
				RightUpperLeg = Vector3.new(70, 0, 0),
				RightLowerLeg = Vector3.new(-80, 0, 0),
				LeftUpperLeg = Vector3.new(5, 0, 0),
				LeftLowerLeg = Vector3.new(-20, 0, 0),
			},
			Hang = { -- both hands on the ledge, legs hanging
				RightUpperArm = Vector3.new(175, 0, 12),
				RightLowerArm = Vector3.new(-10, 0, 0),
				LeftUpperArm = Vector3.new(175, 0, -12),
				LeftLowerArm = Vector3.new(-10, 0, 0),
				RightUpperLeg = Vector3.new(10, 0, 0),
				RightLowerLeg = Vector3.new(-15, 0, 0),
				LeftUpperLeg = Vector3.new(-5, 0, 0),
				LeftLowerLeg = Vector3.new(-25, 0, 0),
			},
			RunA = { -- wall on the left: left hand trails on the wall, body leans away
				UpperTorso = Vector3.new(0, 0, -12),
				LeftUpperArm = Vector3.new(15, 0, -70),
				LeftLowerArm = Vector3.new(-20, 0, 0),
				RightUpperArm = Vector3.new(-30, 0, 20),
				RightLowerArm = Vector3.new(-40, 0, 0),
				RightUpperLeg = Vector3.new(60, 0, 0),
				RightLowerLeg = Vector3.new(-40, 0, 0),
				LeftUpperLeg = Vector3.new(-30, 0, 0),
				LeftLowerLeg = Vector3.new(-70, 0, 0),
			},
			RunB = {
				UpperTorso = Vector3.new(0, 0, -12),
				LeftUpperArm = Vector3.new(15, 0, -70),
				LeftLowerArm = Vector3.new(-20, 0, 0),
				RightUpperArm = Vector3.new(40, 0, 20),
				RightLowerArm = Vector3.new(-40, 0, 0),
				LeftUpperLeg = Vector3.new(60, 0, 0),
				LeftLowerLeg = Vector3.new(-40, 0, 0),
				RightUpperLeg = Vector3.new(-30, 0, 0),
				RightLowerLeg = Vector3.new(-70, 0, 0),
			},
		},
		StepTime = 0.14, -- seconds per climbing or running step in the animations
	},

	BarSwing = {
		-- Jump up to a bar (any part with the "SwingBar" attribute, a cylinder lying along its X
		-- axis) to grab it. You swing like a pendulum; hold forward to pump higher, press jump to
		-- let go with the swing's momentum, press the slide key to drop.
		GrabReach = 2.2, -- studs from the bar to anywhere between just below your chest and your raised hands
		HandHeight = 2.3, -- studs above your body center where your hands are, reaching up
		Radius = 2.6, -- hanging: your body center sits this far below the bar
		PumpAccel = 3, -- swing speed (radians/s per second) added while holding forward
		Damping = 0.12, -- fraction of swing speed lost per second
		MaxAngle = 100, -- degrees: the swing never goes higher than this either way
		ReleaseBoost = 1.15, -- letting go: your swing speed x this
		ReleaseUp = 14, -- letting go: extra studs/s upward
		Cooldown = 0.5, -- seconds before you can grab the same bar again
		Poses = {
			Hang = { -- both hands on the bar, legs together
				RightUpperArm = Vector3.new(178, 0, 6),
				RightLowerArm = Vector3.new(0, 0, 0),
				LeftUpperArm = Vector3.new(178, 0, -6),
				LeftLowerArm = Vector3.new(0, 0, 0),
				RightUpperLeg = Vector3.new(15, 0, 0),
				RightLowerLeg = Vector3.new(-20, 0, 0),
				LeftUpperLeg = Vector3.new(15, 0, 0),
				LeftLowerLeg = Vector3.new(-20, 0, 0),
			},
		},
	},

	LandingRoll = {
		-- Land from a big drop while moving and you roll forward, keeping your speed, instead
		-- of a hard landing. Holding the slide key as you land slides instead.
		MinFallSpeed = 55, -- studs/s downward at landing that counts as a big drop (about 8 studs)
		MinMoveSpeed = 6, -- studs/s sideways you need to be moving to roll
		Time = 0.5, -- seconds the roll takes
		KeepSpeed = 0.95, -- fraction of your landing speed kept through the roll
		MinSpeed = 18, -- a roll always carries you at least this fast
		CameraDip = -22, -- first person: degrees the view tips down during the roll
		Poses = {
			Tuck = { -- curled up: knees to chest, arms wrapped forward
				UpperTorso = Vector3.new(-30, 0, 0),
				Head = Vector3.new(-25, 0, 0),
				RightUpperArm = Vector3.new(70, 0, 10),
				RightLowerArm = Vector3.new(-90, 0, 0),
				LeftUpperArm = Vector3.new(70, 0, -10),
				LeftLowerArm = Vector3.new(-90, 0, 0),
				RightUpperLeg = Vector3.new(100, 0, 0),
				RightLowerLeg = Vector3.new(-130, 0, 0),
				LeftUpperLeg = Vector3.new(100, 0, 0),
				LeftLowerLeg = Vector3.new(-130, 0, 0),
			},
		},
	},

	SpeedTrails = {
		-- Thin white streaks off the hands and feet while you're fast or doing a move.
		Enabled = true,
		MinSpeed = 30, -- studs/s: faster than this always shows trails
		Lifetime = 0.22, -- seconds a streak lasts
		Width = 0.18, -- studs
		Color = Color3.fromRGB(255, 255, 255),
		Moves = { "Slide", "Vault", "Climb", "WallRun", "BarSwing", "Roll" }, -- always show during these
	},

	Vault = {
		-- Automatic, like the reference video: run into a low obstacle while sprinting and you hop
		-- over it at full speed (thin obstacles) or step up onto it (deep ones). No key, no pause.
		MinHeight = 1.2, -- studs above your feet: lower than this, you just run over it
		MaxHeight = 4.5, -- studs above your feet: taller than this is a climb or mantle
		MaxDepth = 4, -- obstacles thinner than this are hopped over; deeper ones are stepped onto
		LookAhead = 0.12, -- seconds ahead (at your speed) to spot an obstacle, plus 1.5 studs
		Clearance = 0.4, -- extra studs the body clears the top by
		MinTime = 0.18, -- shortest a hop can take, in seconds
		Landing = 2, -- studs past the far side (or onto the top) where the hop lands
		HipHeightFactor = 0.5, -- legs tuck up to this fraction of normal hip height
		Poses = {
			Vault = { -- one hand planting on the top, legs tucked to the side
				LowerTorso = Vector3.new(-15, 0, 10),
				RightUpperArm = Vector3.new(60, 0, 15),
				RightLowerArm = Vector3.new(-10, 0, 0),
				LeftUpperArm = Vector3.new(20, 0, -40),
				RightUpperLeg = Vector3.new(70, 0, -25),
				RightLowerLeg = Vector3.new(-90, 0, 0),
				LeftUpperLeg = Vector3.new(60, 0, -20),
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
		UpTime = 0.25, -- seconds to pull up
		OverTime = 0.15, -- seconds to climb over the edge
		Cooldown = 0.25, -- seconds before you can mantle again
		MaxRiseSpeed = 8, -- only grab once your jump has nearly peaked (rising slower than this)
		-- Mantle Boost: press jump inside this window (seconds after the climb starts) to launch
		-- up and over. Too early and you just climb. An on-screen indicator shows the timing.
		BoostWindowStart = 0.14,
		BoostWindowEnd = 0.3,
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

	Camera = {
		StartFirstPerson = false, -- third person like the reference video (V toggles first person)
		AllowToggle = true, -- testing: ToggleKey switches to third person and back
		ToggleKey = Enum.KeyCode.V,
		TurnRate = 18, -- third person: how quickly your body turns to face a move's direction
		ThirdPersonDistance = 12, -- studs the camera pulls back when switching to third person
		BodyForward = 0.4, -- first person: studs the camera sits ahead of the body
		HeadFollow = 14, -- first person: how quickly the camera follows your head (higher = tighter)
	},

	Viewmodel = {
		-- First-person arms attached to the camera. Poses are camera space: Position in studs
		-- (X right, Y up, -Z forward) of the arm's middle, Rotation in degrees (positive X tips
		-- the arm up, positive Y turns it left, Z rolls it). Left mirrors Right unless given.
		Enabled = true,
		Scale = 0.7, -- arms are the body's forearm and hand (Config.Body), scaled by this
		ClassicArm = Vector3.new(0.26, 0.26, 1.3), -- classic avatar: forearm block (long along Z)
		ClassicHand = 0.32, -- classic avatar: hand block
		Smooth = 16, -- how quickly arms move to a new pose (higher = snappier)
		BobAmount = 0.04, -- studs of arm swing while running
		SprintBob = 2, -- swing multiplier while sprinting
		BobRate = 9, -- swing speed at walk speed
		ClimbSwing = 0.35, -- studs the climbing hands move up and down
		ClimbRate = 17, -- how fast the climbing hands alternate
		Poses = {
			Idle = {
				Right = {
					Position = Vector3.new(0.62, -0.72, -1.15),
					Rotation = Vector3.new(10, 10, 0),
				},
			},
			Air = {
				Right = {
					Position = Vector3.new(0.72, -0.55, -1.15),
					Rotation = Vector3.new(25, 6, -15),
				},
			},
			Crouch = {
				Right = {
					Position = Vector3.new(0.55, -0.7, -1.1),
					Rotation = Vector3.new(4, 12, 0),
				},
			},
			Slide = { -- right arm up for balance, left hand trailing low (like the slide reference)
				Right = {
					Position = Vector3.new(0.7, 0.05, -1.25),
					Rotation = Vector3.new(65, 10, -10),
				},
				Left = {
					Position = Vector3.new(-0.78, -0.8, -0.95),
					Rotation = Vector3.new(-20, -20, 20),
				},
			},
			Vault = {
				Right = {
					Position = Vector3.new(0.45, -0.62, -1.35),
					Rotation = Vector3.new(-40, 6, 0),
				},
			},
			MantleGrab = {
				Right = {
					Position = Vector3.new(0.48, 0.25, -1.35),
					Rotation = Vector3.new(35, 6, 0),
				},
			},
			-- Wall climb: hands reach up the wall one after the other (ClimbSwing studs apart).
			Climb = {
				Right = {
					Position = Vector3.new(0.45, 0.2, -1.15),
					Rotation = Vector3.new(70, 6, 0),
				},
			},
			-- Hanging at the top of a wall or on a bar: both hands up gripping.
			Hang = {
				Right = {
					Position = Vector3.new(0.4, 0.55, -1.05),
					Rotation = Vector3.new(80, 8, 0),
				},
			},
			-- Wall run: the wall-side hand trails on the wall (written for a wall on the right).
			WallRunHand = {
				Right = {
					Position = Vector3.new(0.9, -0.3, -1),
					Rotation = Vector3.new(5, -60, -15),
				},
			},
			-- Landing roll: arms tucked in.
			Roll = {
				Right = {
					Position = Vector3.new(0.35, -0.8, -0.95),
					Rotation = Vector3.new(30, 25, 0),
				},
			},
			MantlePush = {
				Right = {
					Position = Vector3.new(0.48, -0.72, -1.15),
					Rotation = Vector3.new(-50, 6, 0),
				},
			},
		},
	},

	Body = {
		-- The game's character: a smooth, rounded cartoon person (Crab Game style) built from
		-- Roblox's round shapes: cylinder limbs, ball joints, ball head and hands, a face made of
		-- shapes. Everyone uses it, and the first-person arms copy its forearm and hand.
		-- A custom mesh can replace it later; the R15 joints stay the same.
		Enabled = false, -- true = this rounded body; false = the classic 2012 block avatar (Config.Avatar)
		Sizes = { -- studs. Limbs: X = thickness, Y = length. Head and Hand are balls (X used).
			Head = Vector3.new(1, 1, 1),
			UpperTorso = Vector3.new(1.4, 1.35, 0.78),
			LowerTorso = Vector3.new(1.25, 0.55, 0.72),
			UpperArm = Vector3.new(0.44, 1.1, 0.44),
			LowerArm = Vector3.new(0.4, 1, 0.4),
			Hand = Vector3.new(0.42, 0.42, 0.42),
			UpperLeg = Vector3.new(0.6, 1.2, 0.6),
			LowerLeg = Vector3.new(0.52, 1.2, 0.52),
			Foot = Vector3.new(0.52, 0.32, 1),
		},
		Colors = {
			Skin = Color3.fromRGB(232, 190, 150),
			Jacket = Color3.fromRGB(232, 108, 44), -- tracksuit top
			Pants = Color3.fromRGB(52, 56, 66), -- joggers
			Stripe = Color3.fromRGB(245, 245, 245), -- side stripes on sleeves and legs
			Shoes = Color3.fromRGB(240, 240, 240),
			Sole = Color3.fromRGB(120, 120, 128),
			Hair = Color3.fromRGB(86, 58, 38),
			Eye = Color3.fromRGB(250, 250, 250),
			Pupil = Color3.fromRGB(20, 20, 20),
			Mouth = Color3.fromRGB(90, 40, 35),
		},
		Stripes = true, -- white side stripes on the tracksuit
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
		Runner = 18,
		It = 20, -- a little faster so It can catch people
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
