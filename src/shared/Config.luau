--!strict
-- Every tunable number and name lives here. Change values here, not in the scripts.
local Config = {
	GameName = "Ultimate Tag",
	Version = "0.2.0",

	Round = {
		IntermissionTime = 15, -- seconds between rounds
		RoundTime = 120, -- seconds per round
		EndTime = 5, -- seconds the results stay on screen
		MinPlayers = 2, -- players needed to start a round
		StudioMinPlayers = 1, -- lets you test alone in Studio
		ItHeadStart = 3, -- seconds It is frozen at the start so runners can scatter
		SpawnRadius = 40, -- runners spawn at random spots within this many studs of the center
	},

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
