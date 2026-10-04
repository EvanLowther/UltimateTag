--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.37.1",

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
		RespawnTime = 3, -- seconds before someone who died (fell off a map) comes back
		-- Falling off: a map with a KillHeight attribute kills anyone who drops below that world
		-- height within this many studs of it sideways. They respawn on the map (server/MapRespawn).
		KillRadius = 400,
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
		-- One prize per wheel segment, in segment order (red, orange, yellow, green, cyan, blue,
		-- purple, pink). Weight: how likely it is (the jackpot is rare). Paid by Progression.grant.
		WheelPrizes = {
			{ Label = "50 Coins", Coins = 50, Weight = 20 },
			{ Label = "100 Coins", Coins = 100, Weight = 16 },
			{ Label = "150 XP", XP = 150, Weight = 16 },
			{ Label = "200 Coins", Coins = 200, Weight = 12 },
			{ Label = "300 XP", XP = 300, Weight = 12 },
			{ Label = "A free crate", Crates = 1, Weight = 10 },
			{ Label = "400 Coins", Coins = 400, Weight = 9 },
			{ Label = "1,000 Coins!", Coins = 1000, Weight = 5 },
		} :: { { [string]: any } },
		ShopMessage = "The Avatar Shop opens soon!", -- (unused now: the prompt opens the Shop)
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
		-- Jump during a wall run to drop off it early (no kick off the wall).
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
		LeanRoll = 12, -- degrees the camera leans away from the wall while wall running
		RunGap = 1.3, -- studs from your body's center to the wall during a wall run (feet on the wall)
		CeilingStop = 0.4, -- studs below a ceiling where climb hops and wall-run lift stop
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
		-- Colors come from each player's equipped trail (shared/Catalog).
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
		-- Third-person follow cam (client/FollowCam).
		Follow = true, -- Roblox's Follow mode: the camera swings round behind you as you run
		CollisionRadius = 0.6, -- studs: the camera keeps this far from walls and ceilings
		ZoomOutRate = 10, -- studs/s the camera eases back out once a wall stops blocking it
		FadeDistance = 3, -- your character fades when the camera is pushed closer than this
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

	-- Saved player profiles (server/PlayerData).
	Data = {
		AutosaveSeconds = 60,
		LockStale = 180, -- seconds after which another server's session lock is ignored (it crashed)
		LoadAttempts = 6, -- tries to load a locked or failing profile before giving up
		RetryDelay = 4, -- seconds between tries
	},

	-- Progression: coins, XP, levels, cosmetics (server/Progression and friends).
	Progression = {
		-- What a brand new player has equipped (and owns). Never sold or found in crates.
		DefaultEquipped = {
			Trail = "trail_white",
			TagEffect = "tag_classic",
			Title = "title_rookie",
			Victory = "victory_none",
		},
		-- What each event gives (Progression.record). Stat: the profile stat it counts toward.
		-- Movement events (WallRun, Slide, Vault, Climb) only count during a live round.
		Events = {
			GamePlayed = { Stat = "GamesPlayed", Coins = 10, XP = 25 },
			RoundSurvived = { Stat = "RoundsSurvived", XP = 20 }, -- XP only, no coins
			TopFive = { Coins = 15 }, -- still in when a big game gets down to its last few (below)
			Tag = { Stat = "Tags", Coins = 1, XP = 5, PerRound = 10 }, -- rewards for at most PerRound tags a round
			-- A win scales with how many players started the game (WinScale below): Coins/XP is
			-- the most (a full game), MinCoins/MinXP the least (2 players). Wins stat: WinsStore.
			Win = { Coins = 100, XP = 150, MinCoins = 20, MinXP = 30 },
			GameLost = {}, -- ends your win streak
			PlayMinute = { Stat = "PlayMinutes", Coins = 1, XP = 2 }, -- each minute in a live game
			WallRun = { Stat = "WallRuns" },
			Slide = { Stat = "Slides" },
			Vault = { Stat = "Vaults" },
			Climb = { Stat = "Climbs" },
			StreakDay = {}, -- a login streak claim (for achievements)
		},
		FirstWinMultiplier = 2, -- the day's first win pays this many times the coins
		-- Win rewards grow in a straight line from 2 players (Min) to WinFullAt players (full),
		-- counting everyone who started the game (not who's left in the last round).
		WinFullAt = 30,
		-- Top 5 bonus: in a game that started with TopFiveMinPlayers or more, everyone still in
		-- once TopFiveCount or fewer are left gets the TopFive event's coins, once per game.
		TopFiveMinPlayers = 20,
		TopFiveCount = 5,
		StreakBonus = 25, -- extra coins per win in a row after the first, scaled like the win
		-- (2nd win in a row +25 in a full game, 3rd +50...)
		StreakBonusCap = 5, -- ...up to this many steps
		FriendXPBonus = 0.1, -- +10% XP while a friend is in the server
		MoveCooldown = 0.4, -- seconds: movement events of one kind count at most this often
		-- Levels: XP needed for the next level = LevelBase + LevelStep x (level - 1).
		LevelBase = 100,
		LevelStep = 50,
		LevelCoins = 25, -- coins on every level up, plus LevelCoinsStep x the new level
		LevelCoinsStep = 5,
		CrateEvery = 5, -- a free crate every this many levels
		-- Extra rewards at certain levels (cosmetics only you can earn).
		LevelRewards = {
			[5] = { Items = { "title_hallmonitor" } },
			[10] = { Items = { "trail_honor" } },
			[20] = { Items = { "victory_graduation" } },
			[30] = { Items = { "title_valedictorian" } },
			[50] = { Items = { "trail_prismatic" } },
		} :: { [number]: { [string]: any } },
	},

	-- The daily login streak (server/DailyStreak): claim once per UTC day; days in a row grow the
	-- streak, a missed day starts it over. Rewards repeat every 7 days.
	Streak = {
		Rewards = {
			{ Coins = 25 },
			{ Coins = 50 },
			{ Coins = 75 },
			{ Coins = 100 },
			{ Coins = 150 },
			{ Coins = 200 },
			{ Coins = 300, Crates = 1 },
		} :: { { [string]: any } },
		-- Extra one-time rewards for long streaks.
		Milestones = {
			[14] = { Items = { "title_attendance" } },
			[30] = { Items = { "trail_perfect" } },
		} :: { [number]: { [string]: any } },
	},

	-- Quests (server/Quests): Count daily and weekly quests per player, picked from these pools
	-- (the same ones all day / week). Event: what counts (Progression.record events), Goal: how
	-- many. Daily ones reset at 00:00 UTC, weekly ones on Monday.
	Quests = {
		Count = 3,
		Daily = {
			{
				Id = "d_games",
				Text = "Play 3 games",
				Event = "GamePlayed",
				Goal = 3,
				Coins = 75,
				XP = 60,
			},
			{
				Id = "d_survive",
				Text = "Survive 5 rounds",
				Event = "RoundSurvived",
				Goal = 5,
				Coins = 100,
				XP = 80,
			},
			{ Id = "d_tags", Text = "Tag 5 players", Event = "Tag", Goal = 5, Coins = 75, XP = 60 },
			{
				Id = "d_wallrun",
				Text = "Wall run 15 times",
				Event = "WallRun",
				Goal = 15,
				Coins = 60,
				XP = 50,
			},
			{
				Id = "d_slide",
				Text = "Slide 25 times",
				Event = "Slide",
				Goal = 25,
				Coins = 60,
				XP = 50,
			},
			{
				Id = "d_vault",
				Text = "Vault 20 times",
				Event = "Vault",
				Goal = 20,
				Coins = 60,
				XP = 50,
			},
			{
				Id = "d_climb",
				Text = "Climb 10 walls",
				Event = "Climb",
				Goal = 10,
				Coins = 60,
				XP = 50,
			},
			{ Id = "d_win", Text = "Win a game", Event = "Win", Goal = 1, Coins = 150, XP = 120 },
			{
				Id = "d_minutes",
				Text = "Play for 15 minutes",
				Event = "PlayMinute",
				Goal = 15,
				Coins = 75,
				XP = 60,
			},
		} :: { { [string]: any } },
		Weekly = {
			{ Id = "w_wins", Text = "Win 5 games", Event = "Win", Goal = 5, Coins = 600, XP = 500 },
			{
				Id = "w_survive",
				Text = "Survive 40 rounds",
				Event = "RoundSurvived",
				Goal = 40,
				Coins = 450,
				XP = 400,
			},
			{
				Id = "w_tags",
				Text = "Tag 50 players",
				Event = "Tag",
				Goal = 50,
				Coins = 450,
				XP = 400,
			},
			{
				Id = "w_wallrun",
				Text = "Wall run 150 times",
				Event = "WallRun",
				Goal = 150,
				Coins = 350,
				XP = 300,
			},
			{
				Id = "w_games",
				Text = "Play 25 games",
				Event = "GamePlayed",
				Goal = 25,
				Coins = 400,
				XP = 350,
			},
			{
				Id = "w_slide",
				Text = "Slide 200 times",
				Event = "Slide",
				Goal = 200,
				Coins = 350,
				XP = 300,
			},
		} :: { { [string]: any } },
	},

	-- Achievements (server/Achievements): reach Goal in Stat (a profile stat, or "Level" or
	-- "Streak") for a one-time reward. BadgeId: a Roblox badge to award too (nil = none yet).
	Achievements = {
		{ Id = "win_1", Text = "First victory", Stat = "Wins", Goal = 1, Coins = 100 },
		{ Id = "win_10", Text = "Win 10 games", Stat = "Wins", Goal = 10, Coins = 300 },
		{ Id = "win_50", Text = "Win 50 games", Stat = "Wins", Goal = 50, Coins = 1000 },
		{
			Id = "win_100",
			Text = "Win 100 games",
			Stat = "Wins",
			Goal = 100,
			Items = { "title_champion" },
		},
		{
			Id = "win_500",
			Text = "Win 500 games",
			Stat = "Wins",
			Goal = 500,
			Items = { "title_legend" },
		},
		{ Id = "tag_10", Text = "Tag 10 players", Stat = "Tags", Goal = 10, Coins = 100 },
		{ Id = "tag_100", Text = "Tag 100 players", Stat = "Tags", Goal = 100, Coins = 400 },
		{
			Id = "tag_1000",
			Text = "Tag 1,000 players",
			Stat = "Tags",
			Goal = 1000,
			Items = { "title_hunter" },
		},
		{
			Id = "survive_50",
			Text = "Survive 50 rounds",
			Stat = "RoundsSurvived",
			Goal = 50,
			Coins = 300,
		},
		{
			Id = "survive_500",
			Text = "Survive 500 rounds",
			Stat = "RoundsSurvived",
			Goal = 500,
			Items = { "title_survivor" },
		},
		{
			Id = "wallrun_100",
			Text = "Wall run 100 times",
			Stat = "WallRuns",
			Goal = 100,
			Coins = 200,
		},
		{
			Id = "wallrun_1000",
			Text = "Wall run 1,000 times",
			Stat = "WallRuns",
			Goal = 1000,
			Items = { "title_parkour" },
		},
		{ Id = "games_10", Text = "Play 10 games", Stat = "GamesPlayed", Goal = 10, Coins = 150 },
		{
			Id = "games_100",
			Text = "Play 100 games",
			Stat = "GamesPlayed",
			Goal = 100,
			Items = { "title_veteran" },
		},
		{ Id = "level_10", Text = "Reach level 10", Stat = "Level", Goal = 10, Coins = 500 },
		{ Id = "level_25", Text = "Reach level 25", Stat = "Level", Goal = 25, Coins = 1500 },
		{ Id = "level_50", Text = "Reach level 50", Stat = "Level", Goal = 50, Coins = 5000 },
		{ Id = "streak_7", Text = "7-day login streak", Stat = "Streak", Goal = 7, Coins = 300 },
		{
			Id = "streak_30",
			Text = "30-day login streak",
			Stat = "Streak",
			Goal = 30,
			Coins = 2000,
		},
	} :: { { [string]: any } },

	-- Robux purchases (server/Purchases): all off until these have IDs from the Roblox website.
	Monetization = {
		VipPass = nil :: number?, -- gamepass id: +VipXPBonus XP and the VIP title
		DoubleCoinsPass = nil :: number?, -- gamepass id: double coins from games
		CoinPacks = {} :: { [number]: number }, -- developer product id -> coins
		VipXPBonus = 0.25,
	},

	-- The daily shop and crates (server/Shop, shared/ShopRotation).
	Shop = {
		Featured = 4, -- items at full price each day, plus one deal
		DealDiscount = 0.3, -- the deal is this much off
		RarityWeights = { Common = 50, Rare = 30, Epic = 15, Legendary = 5 }, -- how often each shows up
		CratePrice = 300,
		-- Bought crates go to your Inventory. Opening one rolls a rarity by Catalog.Rarities
		-- weights (odds shown in the shop), then an item. Duplicates are possible.
	},

	Avatar = {
		UseOwnAvatar = false, -- false = everyone is the classic block avatar (easier to see animations)
		UseOwnColors = true, -- the block avatar wears each player's own Roblox body colors
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
	},

	Ui = {
		Font = Enum.Font.SourceSansBold,
	},

	-- Map gadgets (client/MapGadgets), set up by attributes on map parts:
	--   LaunchVelocity (Vector3): stepping on the part throws you with that velocity (studs/s).
	--   SpeedBoost (number): jumping or running off the part sends you at least this fast.
	--   Slip (number): moving onto the part (running or sliding) makes you slip: you fall onto
	--                  your back and skid on with your momentum, slowing to a stop, and get up
	--                  after that many seconds (a wet floor).
	Gadgets = {
		LaunchCooldown = 0.8, -- seconds before the same player can be launched again
		LaunchDriveTime = 0.08, -- seconds the launch velocity is forced (beats ground friction)
		BoostWindow = 0.3, -- seconds after leaving a SpeedBoost part that the boost still applies
		SlipMinSpeed = 4, -- studs/s you must be moving to slip
		SlipSpin = 7, -- how hard the slip tips you backwards (radians/s)
		SlipCarry = 0.85, -- the skid starts at this fraction of your speed
		SlipSkidTime = 0.9, -- seconds the skid takes to slow to a stop
		SlipCooldown = 1.5, -- seconds after getting up before you can slip again
	},

	-- Per-map lighting (client/MapLighting): a map with a Lighting attribute (a preset name here)
	-- switches your lighting to that preset while your camera is within Radius studs of it.
	-- Other places use the normal lighting from default.project.json.
	MapLighting = {
		Radius = 500,
		FadeTime = 1.2, -- seconds to blend between lightings
		Presets = {
			-- Inside buildings (the School): the outdoor sun settings and bloom wash an enclosed,
			-- lamp-lit space out to white, so turn exposure, bloom and ambient down.
			Indoor = {
				Lighting = {
					Brightness = 1,
					Ambient = Color3.fromRGB(70, 70, 78),
					OutdoorAmbient = Color3.fromRGB(80, 80, 88),
					ExposureCompensation = -0.45,
					EnvironmentDiffuseScale = 0.15,
					EnvironmentSpecularScale = 0.15,
				},
				Atmosphere = { Density = 0, Haze = 0, Glare = 0 },
				Bloom = { Intensity = 0.12, Size = 16, Threshold = 2.2 },
				ColorCorrection = {
					Saturation = 0.12,
					Contrast = 0.12,
					Brightness = -0.02,
					TintColor = Color3.fromRGB(255, 250, 240),
				},
			},
			Night = {
				Lighting = {
					ClockTime = 0.4,
					Brightness = 1.2,
					Ambient = Color3.fromRGB(60, 55, 95),
					OutdoorAmbient = Color3.fromRGB(80, 70, 130),
					ExposureCompensation = 0.35,
					EnvironmentDiffuseScale = 0.3,
					EnvironmentSpecularScale = 0.6,
				},
				Atmosphere = {
					Density = 0.36,
					Offset = 0.05,
					Color = Color3.fromRGB(70, 50, 120),
					Decay = Color3.fromRGB(40, 25, 80),
					Glare = 0,
					Haze = 1.6,
				},
				Bloom = { Intensity = 1.1, Size = 30, Threshold = 0.95 },
				ColorCorrection = {
					Saturation = 0.35,
					Contrast = 0.12,
					Brightness = 0.02,
					TintColor = Color3.fromRGB(235, 225, 255),
				},
			},
		},
	},

	-- The developer panel (client/DevPanel, server/DevCommands): game flow, maps, movement tuning
	-- and debug tools in one window. Always available in Studio playtests; in live servers only
	-- for the UserIds listed here. Players never see it.
	DevPanel = {
		Enabled = true,
		Key = Enum.KeyCode.Backquote, -- opens and closes the panel (the ` key)
		UserIds = {} :: { number }, -- extra people allowed in live servers (Studio always is)
		TeleportKey = Enum.KeyCode.T, -- with "Teleport key" on: jump to where the mouse points
		FlySpeed = 60, -- studs/s while flying (WASD, E up, Q down)
		FlyBoost = 3, -- hold Shift while flying to go this many times faster
		-- The Movement tab's sliders: { Section, Key, Min, Max, Step }. Changes apply at once
		-- (on your client, and on the server for values it uses) and last until the playtest ends;
		-- "Copy changes" lists them for pasting into this file.
		Tunables = {
			{ "Speed", "Runner", 8, 40, 1 },
			{ "Speed", "It", 8, 40, 1 },
			{ "Sprint", "Multiplier", 1, 3, 0.05 },
			{ "Slide", "StartMultiplier", 1, 2.5, 0.05 },
			{ "Slide", "Duration", 0.2, 3, 0.05 },
			{ "Slide", "MaxSpeed", 20, 120, 1 },
			{ "Slide", "Steer", 0, 8, 0.1 },
			{ "Slide", "DeadSlideTime", 0, 5, 0.05 },
			{ "Slide", "CrouchSpeed", 2, 20, 0.5 },
			{ "AirMomentum", "TurnRate", 0, 720, 5 },
			{ "AirMomentum", "BrakeRate", 0, 100, 1 },
			{ "AirMomentum", "AirControl", 0, 150, 1 },
			{ "WallRun", "MinEntrySpeed", 0, 40, 1 },
			{ "WallRun", "HopSpeed", 20, 150, 1 },
			{ "WallRun", "HopTime", 0.1, 1, 0.01 },
			{ "WallRun", "MaxHops", 1, 6, 1 },
			{ "WallRun", "ClingTime", 0.2, 4, 0.05 },
			{ "WallRun", "RunSpeed", 10, 60, 1 },
			{ "WallRun", "RunTime", 0.3, 4, 0.05 },
			{ "WallRun", "RunLift", 0, 30, 0.5 },
			{ "Vault", "MinHeight", 0.2, 4, 0.1 },
			{ "Vault", "MaxHeight", 2, 8, 0.1 },
			{ "Vault", "MaxDepth", 1, 10, 0.1 },
			{ "Mantle", "Reach", 1, 5, 0.1 },
			{ "Mantle", "UpTime", 0.05, 1, 0.01 },
			{ "LandingRoll", "MinFallSpeed", 20, 120, 1 },
			{ "LandingRoll", "KeepSpeed", 0.5, 1.2, 0.01 },
			{ "Tag", "Range", 2, 20, 0.5 },
			{ "Tag", "Cooldown", 0, 2, 0.05 },
		} :: { { any } },
	},
}

return Config
