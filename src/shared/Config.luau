--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.27.0",

	Game = {
		-- How the server runs. "Elimination": lobby -> rounds on maps -> last player wins.
		-- "Sandbox": free play on the test map, one It, nothing ends (for testing movement).
		Mode = "Elimination",
		MinPlayers = 2, -- players needed in the lobby to start a game
		StudioMinPlayers = 2, -- the same when testing in Studio (use Test > Clients and Servers)
		LobbyCountdown = 15, -- seconds from having enough players to the game starting
		IntroTime = 5, -- seconds on a new map before the round timer starts
		ItHeadStart = 3, -- seconds the Its are frozen at the start of a round
		RoundTime = 60, -- seconds per round
		ResultsTime = 5, -- seconds to show who was eliminated
		VictoryTime = 8, -- seconds to show the winner before going back to the lobby
		EliminateFraction = 0.45, -- share of the players still in who start a round as It (and lose it)
	},

	Lobby = {
		-- The lobby island is imported once into Studio and set up with tools/SetupLobby (see
		-- AGENTS.md). It then lives in the place file; these settings drive its working parts.
		Position = Vector3.new(2000, 0, 0), -- where the setup tool puts the island's center (water level)
		LeaderboardRows = 8, -- names on the lobby leaderboard
		LeaderboardRefresh = 45, -- seconds between leaderboard updates
		WheelCooldownHours = 24, -- the reward wheel: one spin per player per this many hours
		WheelSpinTime = 4.5, -- seconds a spin takes
		WheelTurns = 4, -- full turns before it settles
		-- One prize per wheel segment, in segment order: red, orange, yellow, green, cyan, blue,
		-- purple, pink. Placeholders until coins and trails exist.
		WheelPrizes = {
			"10 Coins",
			"25 Coins",
			"50 Coins",
			"100 Coins",
			"Speed Trail (1 day)",
			"5 Coins",
			"VIP Trial (1 day)",
			"Mystery Box",
		},
		ShopMessage = "The Avatar Shop opens soon!",
	},

	Tag = {
		-- It left-clicks to swing; a swing tags the nearest Runner within Range.
		Range = 7, -- studs between the two characters' centers that a swing reaches
		Cooldown = 0.45, -- seconds between swings
		FreezeTime = 2, -- seconds the newly tagged player is frozen (also stops instant tag-backs)
		SwingTime = 0.35, -- seconds the swipe animation lasts
		-- The swipe: wind the right arm back, then reach forward. Only these parts move; the
		-- rest keep running.
		Poses = {
			WindUp = {
				UpperTorso = Vector3.new(0, -20, 0),
				RightUpperArm = Vector3.new(60, 0, 35),
				RightLowerArm = Vector3.new(-70, 0, 0),
			},
			Reach = {
				UpperTorso = Vector3.new(0, 18, 0),
				RightUpperArm = Vector3.new(92, 0, 5),
				RightLowerArm = Vector3.new(-5, 0, 0),
			},
		},
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
		CrouchStepTime = 0.3, -- seconds per crouch-walk step at CrouchSpeed (faster when moving faster)
		Steer = 2, -- how much your movement keys turn a slide (higher = more control)
		HipHeightFactor = 0.3, -- hips sink to this fraction of their normal height
		CameraDip = 1.5, -- studs the camera drops during a slide
		DropTime = 0.1, -- seconds from the drop pose into the full slide pose
		RiseTime = 0.24, -- seconds for the hips and camera to come back up
		HeadClearance = 2.5, -- studs from the body center to the top of the head when standing
		BlockerGroup = "SlideBlocker", -- collision group for invisible parts only sliders can pass
		SlidingGroup = "Sliding", -- collision group the character uses while sliding

		-- Slide animation, built from the reference frames. Each pose is degrees of rotation per
		-- body part (X = tip forward/back, Y = twist, Z = sideways), relative to standing.
		-- Positive X on LowerTorso leans the body back. Positive X on an upper leg or upper arm
		-- swings it forward. Negative X on a lower leg bends the knee.
		Poses = {
			-- Slide, like the reference video: feet first with both legs out straight, body leaned
			-- well back (about 60 degrees), head tipped forward to look ahead, one arm up by the
			-- head and the other trailing low behind.
			Drop = { -- dropping into it
				LowerTorso = Vector3.new(30, 0, 0),
				Head = Vector3.new(-20, 0, 0),
				RightUpperLeg = Vector3.new(30, 0, 0),
				RightLowerLeg = Vector3.new(-25, 0, 0),
				LeftUpperLeg = Vector3.new(20, 0, 0),
				LeftLowerLeg = Vector3.new(-40, 0, 0),
				RightUpperArm = Vector3.new(90, 0, 20),
				RightLowerArm = Vector3.new(-30, 0, 0),
				LeftUpperArm = Vector3.new(-20, 0, -20),
			},
			Slide = { -- the held slide
				LowerTorso = Vector3.new(62, 0, 0),
				UpperTorso = Vector3.new(-8, 0, 0),
				Head = Vector3.new(-40, 0, 0),
				RightUpperLeg = Vector3.new(5, 0, 0),
				RightLowerLeg = Vector3.new(0, 0, 0),
				LeftUpperLeg = Vector3.new(15, 0, -5),
				LeftLowerLeg = Vector3.new(-30, 0, 0),
				RightUpperArm = Vector3.new(150, 0, 25),
				RightLowerArm = Vector3.new(-20, 0, 0),
				LeftUpperArm = Vector3.new(-50, 0, -30),
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
			-- Crouching (C without sprinting). The lean is in the chest (UpperTorso), not the hips,
			-- so the legs stay where the knee angles put them; the crouch height is worked out
			-- from these leg angles so the feet sit exactly on the floor.
			CrouchIdle = {
				UpperTorso = Vector3.new(-25, 0, 0),
				Head = Vector3.new(20, 0, 0),
				RightUpperLeg = Vector3.new(80, 0, 0),
				RightLowerLeg = Vector3.new(-130, 0, 0),
				LeftUpperLeg = Vector3.new(80, 0, 0),
				LeftLowerLeg = Vector3.new(-130, 0, 0),
				RightUpperArm = Vector3.new(25, 0, 10),
				RightLowerArm = Vector3.new(-40, 0, 0),
				LeftUpperArm = Vector3.new(25, 0, -10),
				LeftLowerArm = Vector3.new(-40, 0, 0),
			},
			-- One step of the crouch walk (right leg forward); the other step is its mirror.
			-- Each leg's height matches the idle pose's, so the feet stay on the floor.
			CrouchStep = {
				UpperTorso = Vector3.new(-25, 0, 0),
				Head = Vector3.new(20, 0, 0),
				RightUpperLeg = Vector3.new(95, 0, 0),
				RightLowerLeg = Vector3.new(-125, 0, 0),
				LeftUpperLeg = Vector3.new(65, 0, 0),
				LeftLowerLeg = Vector3.new(-130, 0, 0),
				RightUpperArm = Vector3.new(5, 0, 10),
				RightLowerArm = Vector3.new(-40, 0, 0),
				LeftUpperArm = Vector3.new(45, 0, -10),
				LeftLowerArm = Vector3.new(-40, 0, 0),
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
		RecoverLungeTime = 0.08, -- seconds into the recovery when the lunge pose is reached
		RecoverCrouchTime = 0.16, -- ... the crouch pose
		RecoverStandTime = 0.24, -- ... standing
	},

	RunPace = {
		-- Roblox's walk and run animations play at (ground speed / NormalSpeed), kept between
		-- MinPace and MaxPace, so no move can leave them stuck playing too fast.
		NormalSpeed = 18, -- studs/s at which the animations play at normal speed
		MinPace = 0.6,
		MaxPace = 1.45,
	},

	AirMomentum = {
		-- In the air, you keep your speed (Roblox's own air control would drag you back to walk
		-- speed and kill the momentum from wall runs, slides and vaults). Your keys steer it.
		TurnRate = 160, -- degrees per second your air path can turn toward where you steer
		BrakeRate = 25, -- studs/s per second you slow down when steering backwards
		AirControl = 45, -- studs/s per second you can speed up while slower than walk speed
		WallStop = 0.5, -- if a wall cuts your speed below this fraction, carry the slower speed
	},

	WallRun = {
		-- Jump at a wall while sprinting (or moving fast). Heading straight at it: you hop up it
		-- and cling, jump to hop higher, hang at the top and climb over. Running alongside it: you run along it.
		-- Jump during either to kick off the wall.
		Reach = 2.2, -- studs from your body (ahead, beside or diagonally) that counts as touching a wall
		ClimbAngle = 35, -- heading within this many degrees of straight at the wall = climb;
		-- anything else (beside or glancing) = wall run, unless you're moving away from the wall
		MinEntrySpeed = 18, -- studs/s sideways you need to start one (sprinting always counts)
		Cooldown = 0.4, -- seconds before you can grab the same wall again
		HopSpeed = 75, -- studs/s up the wall at the start of each hop (slows to 0 over HopTime)
		HopTime = 0.32, -- seconds per hop. Height per hop = HopSpeed x HopTime / 2 (about 12 studs,
		-- measured from the reference video: each hop is roughly 2.5 body heights)
		MaxHops = 3, -- hops up one wall: the first one plus jumps while clinging
		ClingTime = 1.1, -- seconds you can hold on to the wall face between hops
		ClingSlide = 1.5, -- studs/s you slide down while clinging
		ClingGap = 1.2, -- studs from your body's center to the wall while climbing or clinging
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
		RunGap = 1.3, -- studs from your body's center to the wall during a wall run (feet on the wall)
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
			-- Wall run, wall on the LEFT (mirrored for the right). The whole body tilts away from
			-- the wall (LowerTorso roll) so the feet run on it; the head tilts back toward level.
			-- Both arms pump like a sprint; the wall-side arm stays close to the body.
			RunA = { -- right leg forward
				LowerTorso = Vector3.new(5, 0, -28),
				Head = Vector3.new(0, 0, 14),
				LeftUpperArm = Vector3.new(-25, 0, -12),
				LeftLowerArm = Vector3.new(-30, 0, 0),
				RightUpperArm = Vector3.new(45, 0, 12),
				RightLowerArm = Vector3.new(-60, 0, 0),
				RightUpperLeg = Vector3.new(65, 0, 0),
				RightLowerLeg = Vector3.new(-50, 0, 0),
				LeftUpperLeg = Vector3.new(-25, 0, 0),
				LeftLowerLeg = Vector3.new(-75, 0, 0),
			},
			RunB = { -- left leg forward
				LowerTorso = Vector3.new(5, 0, -28),
				Head = Vector3.new(0, 0, 14),
				LeftUpperArm = Vector3.new(45, 0, -12),
				LeftLowerArm = Vector3.new(-60, 0, 0),
				RightUpperArm = Vector3.new(-25, 0, 12),
				RightLowerArm = Vector3.new(-30, 0, 0),
				LeftUpperLeg = Vector3.new(65, 0, 0),
				LeftLowerLeg = Vector3.new(-50, 0, 0),
				RightUpperLeg = Vector3.new(-25, 0, 0),
				RightLowerLeg = Vector3.new(-75, 0, 0),
			},
		},
		StepTime = 0.14, -- seconds per climbing or running step in the animations
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
		Moves = { "Slide", "Vault", "Climb", "WallRun", "Roll" }, -- always show during these
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
		TagJabTime = 0.2, -- seconds the first-person arm stays jabbed out after a tag swing
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
			-- Hanging at the top of a wall or clinging to it: both hands up gripping.
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
			-- Tag swing: the right hand jabs forward into the middle of the view.
			TagJab = {
				Right = {
					Position = Vector3.new(0.3, -0.35, -1.6),
					Rotation = Vector3.new(5, 15, 0),
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
		Winner = Color3.fromRGB(230, 180, 30), -- YOU WIN! banner (gold)
		Eliminated = Color3.fromRGB(90, 90, 96), -- ELIMINATED banner (gray)
		BoostReady = Color3.fromRGB(40, 210, 210), -- mantle boost window open (cyan)
		BoostMissed = Color3.fromRGB(120, 120, 120), -- mantle boost missed
	},

	Ui = {
		Font = Enum.Font.SourceSansBold,
	},
}

return Config
