--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.5.3",

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
		DropTime = 0.15, -- seconds to blend from running into the slide pose
		RiseTime = 0.3, -- seconds to blend from the slide pose back to standing
		HeadClearance = 2.5, -- studs from the body center to the top of the head when standing
		BlockerGroup = "SlideBlocker", -- collision group for invisible parts only sliders can pass
		SlidingGroup = "Sliding", -- collision group the character uses while sliding

		-- Slide pose: degrees of rotation (X = tip forward/back, Y = twist, Z = sideways) for
		-- each R15 joint. Positive X on Root leans the body back. Positive X on a hip or
		-- shoulder swings that limb forward. Negative X on a knee bends it.
		Pose = {
			Root = Vector3.new(55, 0, 0), -- lean the whole body back
			Waist = Vector3.new(-15, 0, 0), -- curl the chest forward a little
			Neck = Vector3.new(-30, 0, 0), -- keep looking ahead
			RightHip = Vector3.new(38, 0, 0), -- lead leg straight out in front
			RightKnee = Vector3.new(-5, 0, 0),
			LeftHip = Vector3.new(70, 0, -10), -- back leg bent with the knee up
			LeftKnee = Vector3.new(-100, 0, 0),
			RightShoulder = Vector3.new(120, 0, 15), -- right arm raised for balance
			RightElbow = Vector3.new(-30, 0, 0),
			LeftShoulder = Vector3.new(-45, 0, -40), -- left hand reaching back to the ground
			LeftElbow = Vector3.new(-15, 0, 0),
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
	},

	Ui = {
		Font = Enum.Font.SourceSansBold,
	},
}

return Config
