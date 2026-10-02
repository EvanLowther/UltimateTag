--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.3.0",

	Tag = {
		Range = 5, -- studs between two characters that counts as a tag
		FreezeTime = 2, -- seconds the newly tagged player is frozen (also stops instant tag-backs)
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
