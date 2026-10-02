--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.5.0",

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
		HipHeightFactor = 0.25, -- character sinks to this fraction of its normal hip height
		CameraDip = 1.5, -- studs the camera drops during a slide
		BlendTime = 0.1, -- seconds to ease into and out of the crouch
		HeadClearance = 2.5, -- studs from the body center to the top of the head when standing
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
