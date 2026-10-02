--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.6.0",

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
		Key = Enum.KeyCode.C, -- press while sprinting on the ground
		StartMultiplier = 1.25, -- slide starts at your current speed x this
		Duration = 0.9, -- seconds for the slide to fade back to walk speed
		Cooldown = 1, -- seconds before you can slide again
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
	},

	Ui = {
		Font = Enum.Font.SourceSansBold,
	},
}

return Config
