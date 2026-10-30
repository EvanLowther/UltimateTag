--!strict
-- Every cosmetic in the game (data only; both sides read it).
--   kind:   "Trail" (speed trails), "TagEffect" (what tagging looks like), "Title" (text over
--           your head), "Victory" (your celebration when you win).
--   rarity: Common, Rare, Epic, Legendary, Iridescent (found in crates; all but Iridescent are
--           also sold in the daily shop) or Exclusive (only earned: levels, the login streak,
--           achievements, VIP).
--   shop / crate: whether it can show up in the daily shop / come out of a crate.
--   look:   how it looks (client/SpeedTrails, client/CosmeticEffects, shared/TitleTag).
-- What each rarity looks like (the tier rules):
--   Trails and titles: Common one solid color; Rare two colors or a simple pattern (stripes,
--   split, checker, camo); Epic a gradient; Legendary a gradient plus effects (particles, a
--   moving shine); Iridescent shifting holo colors plus something special (afterimages, a
--   framed title with its serial number). Tag effects follow the same pattern. Victories come
--   in Epic, Legendary and Iridescent only (the default "None" aside).
-- Prices come from the rarity unless an item sets its own.
local Catalog = {}

export type Item = {
	id: string,
	kind: string,
	name: string,
	rarity: string,
	price: number?,
	shop: boolean,
	crate: boolean,
	look: { [string]: any },
	note: string?, -- how to get an Exclusive
	blurb: string?, -- a one-line description (otherwise made from the look, Catalog.describe)
}

export type Rarity = { color: Color3, price: number, weight: number, order: number }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- weight: the chance (out of 100) a Mystery crate rolls this rarity. order: higher is rarer
-- (Exclusive sorts last). Iridescent's color is shown with a moving holo shimmer.
Catalog.Rarities = {
	Common = { color = rgb(170, 180, 190), price = 150, weight = 45, order = 1 },
	Rare = { color = rgb(60, 150, 255), price = 400, weight = 30, order = 2 },
	Epic = { color = rgb(170, 80, 255), price = 900, weight = 15, order = 3 },
	Legendary = { color = rgb(255, 180, 40), price = 2000, weight = 9.95, order = 4 },
	Iridescent = { color = rgb(255, 80, 120), price = 0, weight = 0.05, order = 5 },
	Exclusive = { color = rgb(33, 208, 122), price = 0, weight = 0, order = 0 },
} :: { [string]: Rarity }

-- The rarities a crate can roll, commonest first (also the order the odds are shown in).
Catalog.CrateOrder = { "Common", "Rare", "Epic", "Legendary", "Iridescent" }

Catalog.Kinds = { "Trail", "TagEffect", "Title", "Victory" }
Catalog.KindNames =
	{ Trail = "Trails", TagEffect = "Tags", Title = "Titles", Victory = "Victories" }
Catalog.KindSingular =
	{ Trail = "trail", TagEffect = "tag effect", Title = "title", Victory = "victory" }

local list: { Item } = {}

local function add(
	id: string,
	kind: string,
	name: string,
	rarity: string,
	look: { [string]: any },
	extra: { note: string?, blurb: string? }?
)
	local earned = rarity == "Exclusive"
	table.insert(list, {
		id = id,
		kind = kind,
		name = name,
		rarity = rarity,
		shop = not earned and rarity ~= "Iridescent", -- Iridescent: crates only
		crate = not earned,
		look = look,
		note = extra and extra.note,
		blurb = extra and extra.blurb,
	})
end

-- Trails. Pattern: Solid, Stripes, Split (two lanes side by side), Checker, Camo, Gradient or
-- Holo. Colors: the colors it uses. Light (0-1): glow. Effect: particles off the hands and feet
-- (Embers, Stars, Sparkles, Sparks, Snow) or Afterimages.
add(
	"trail_white",
	"Trail",
	"Classic White",
	"Common",
	{ Pattern = "Solid", Colors = { rgb(255, 255, 255) } }
)
add("trail_red", "Trail", "Cherry", "Common", { Pattern = "Solid", Colors = { rgb(255, 70, 70) } })
add("trail_blue", "Trail", "Sky", "Common", { Pattern = "Solid", Colors = { rgb(70, 150, 255) } })
add("trail_green", "Trail", "Lime", "Common", { Pattern = "Solid", Colors = { rgb(110, 230, 90) } })
add(
	"trail_yellow",
	"Trail",
	"Sunny",
	"Common",
	{ Pattern = "Solid", Colors = { rgb(255, 214, 60) } }
)
add(
	"trail_purple",
	"Trail",
	"Grape",
	"Common",
	{ Pattern = "Solid", Colors = { rgb(160, 90, 255) } }
)
add(
	"trail_pink",
	"Trail",
	"Bubblegum",
	"Rare",
	{ Pattern = "Stripes", Colors = { rgb(255, 110, 200), rgb(255, 255, 255) } }
)
add(
	"trail_candy",
	"Trail",
	"Candy Cane",
	"Rare",
	{ Pattern = "Stripes", Colors = { rgb(255, 60, 60), rgb(255, 255, 255) } }
)
add(
	"trail_bumble",
	"Trail",
	"Bumblebee",
	"Rare",
	{ Pattern = "Stripes", Colors = { rgb(255, 214, 10), rgb(25, 25, 25) } }
)
add(
	"trail_split",
	"Trail",
	"Split",
	"Rare",
	{ Pattern = "Split", Colors = { rgb(25, 227, 255), rgb(255, 46, 136) } }
)
add(
	"trail_checker",
	"Trail",
	"Checkers",
	"Rare",
	{ Pattern = "Checker", Colors = { rgb(255, 255, 255), rgb(25, 25, 25) } }
)
add("trail_camo", "Trail", "Jungle Camo", "Rare", {
	Pattern = "Camo",
	Colors = { rgb(85, 107, 47), rgb(143, 151, 121), rgb(47, 58, 29), rgb(107, 142, 35) },
})
add("trail_ice", "Trail", "Ice", "Epic", {
	Pattern = "Gradient",
	Colors = { rgb(160, 240, 255), rgb(255, 255, 255), rgb(90, 170, 255) },
})
add(
	"trail_shadow",
	"Trail",
	"Shadow",
	"Epic",
	{ Pattern = "Gradient", Colors = { rgb(25, 20, 30), rgb(90, 40, 120) } }
)
add(
	"trail_gold",
	"Trail",
	"Gold Rush",
	"Epic",
	{ Pattern = "Gradient", Colors = { rgb(255, 240, 140), rgb(255, 170, 30) } }
)
add("trail_sunset", "Trail", "Sunset", "Epic", {
	Pattern = "Gradient",
	Colors = { rgb(255, 210, 60), rgb(255, 90, 90), rgb(170, 80, 255) },
})
add("trail_toxic", "Trail", "Toxic", "Epic", {
	Pattern = "Gradient",
	Colors = { rgb(234, 255, 60), rgb(33, 208, 122), rgb(10, 110, 90) },
})
add("trail_fire", "Trail", "Wildfire", "Legendary", {
	Pattern = "Gradient",
	Colors = { rgb(255, 246, 160), rgb(255, 140, 30), rgb(230, 40, 20) },
	Light = 1,
	Effect = "Embers",
})
add("trail_galaxy", "Trail", "Galaxy", "Legendary", {
	Pattern = "Gradient",
	Colors = { rgb(120, 60, 255), rgb(40, 120, 255), rgb(255, 90, 220) },
	Light = 1,
	Effect = "Stars",
})
add("trail_thunder", "Trail", "Thunder", "Legendary", {
	Pattern = "Gradient",
	Colors = { rgb(255, 255, 255), rgb(25, 227, 255), rgb(40, 80, 255) },
	Light = 1,
	Effect = "Sparks",
})
add("trail_rainbow", "Trail", "Rainbow", "Legendary", {
	Pattern = "Gradient",
	Colors = {
		rgb(255, 60, 60),
		rgb(255, 170, 40),
		rgb(255, 240, 60),
		rgb(80, 230, 90),
		rgb(60, 150, 255),
		rgb(170, 80, 255),
	},
	Light = 0.5,
	Effect = "Sparkles",
})
add("trail_frost", "Trail", "Frostbite", "Legendary", {
	Pattern = "Gradient",
	Colors = { rgb(255, 255, 255), rgb(160, 240, 255), rgb(60, 150, 255) },
	Light = 0.7,
	Effect = "Snow",
})
add("trail_mirage", "Trail", "Mirage", "Iridescent", {
	Pattern = "Holo",
	Light = 1,
	Effect = "Afterimages",
}, { blurb = "Holo colors that shift as you run, plus afterimages of you" })
add(
	"trail_honor",
	"Trail",
	"Honor Roll",
	"Exclusive",
	{ Pattern = "Solid", Colors = { rgb(255, 220, 90) }, Light = 1 },
	{ note = "Reach level 10" }
)
add("trail_perfect", "Trail", "Perfect Record", "Exclusive", {
	Pattern = "Gradient",
	Colors = { rgb(255, 255, 255), rgb(120, 255, 200) },
	Light = 1,
}, { note = "30-day login streak" })
add("trail_prismatic", "Trail", "Prismatic", "Exclusive", {
	Pattern = "Gradient",
	Colors = { rgb(255, 120, 200), rgb(120, 220, 255), rgb(200, 255, 140), rgb(255, 230, 120) },
	Light = 1,
	Effect = "Sparkles",
}, { note = "Reach level 50" })

-- Tag effects: Effect picks the burst (client/CosmeticEffects); Colors tint it.
add(
	"tag_classic",
	"TagEffect",
	"Classic",
	"Common",
	{ Effect = "Classic", Colors = { rgb(255, 80, 80) } }
)
add("tag_pop", "TagEffect", "Pop", "Common", { Effect = "Pop", Colors = { rgb(255, 255, 255) } })
add(
	"tag_sparks",
	"TagEffect",
	"Sparks",
	"Common",
	{ Effect = "Sparks", Colors = { rgb(255, 200, 80) } }
)
add(
	"tag_hearts",
	"TagEffect",
	"Hearts",
	"Rare",
	{ Effect = "Hearts", Colors = { rgb(255, 90, 150), rgb(255, 255, 255) } }
)
add(
	"tag_stars",
	"TagEffect",
	"Stars",
	"Rare",
	{ Effect = "Stars", Colors = { rgb(255, 240, 120), rgb(255, 255, 255) } }
)
add(
	"tag_pow",
	"TagEffect",
	"Pow",
	"Rare",
	{ Effect = "Pow", Colors = { rgb(255, 214, 10), rgb(227, 36, 43) } }
)
add("tag_confetti", "TagEffect", "Confetti", "Epic", {
	Effect = "Confetti",
	Colors = { rgb(255, 210, 60), rgb(255, 90, 90), rgb(170, 80, 255) },
})
add(
	"tag_shockwave",
	"TagEffect",
	"Shockwave",
	"Epic",
	{ Effect = "Shockwave", Colors = { rgb(25, 227, 255), rgb(170, 80, 255) } }
)
add(
	"tag_lightning",
	"TagEffect",
	"Thunderstrike",
	"Legendary",
	{ Effect = "Lightning", Colors = { rgb(255, 255, 255), rgb(150, 220, 255) } }
)
add("tag_meteor", "TagEffect", "Meteor", "Legendary", {
	Effect = "Meteor",
	Colors = { rgb(255, 240, 140), rgb(255, 120, 30), rgb(200, 40, 20) },
})
add("tag_shatter", "TagEffect", "Shatter", "Iridescent", { Effect = "Shatter" })

-- Titles: Text over your head. Style: Solid, TwoTone (top and bottom halves), Gradient, Shine
-- (a moving shine and sparkles) or Holo (shifting holo colors in a frame, with the item's
-- serial number). Colors: the colors it uses.
add(
	"title_rookie",
	"Title",
	"Rookie",
	"Common",
	{ Text = "Rookie", Style = "Solid", Colors = { rgb(220, 220, 220) } }
)
add(
	"title_slippery",
	"Title",
	"Slippery",
	"Common",
	{ Text = "Slippery", Style = "Solid", Colors = { rgb(120, 200, 255) } }
)
add(
	"title_runner",
	"Title",
	"Runner",
	"Common",
	{ Text = "Runner", Style = "Solid", Colors = { rgb(255, 214, 60) } }
)
add(
	"title_speedster",
	"Title",
	"Speedster",
	"Rare",
	{ Text = "Speedster", Style = "TwoTone", Colors = { rgb(124, 243, 255), rgb(60, 150, 255) } }
)
add(
	"title_classclown",
	"Title",
	"Class Clown",
	"Rare",
	{ Text = "Class Clown", Style = "TwoTone", Colors = { rgb(255, 214, 60), rgb(255, 120, 40) } }
)
add(
	"title_speeddemon",
	"Title",
	"Speed Demon",
	"Rare",
	{ Text = "Speed Demon", Style = "TwoTone", Colors = { rgb(255, 120, 90), rgb(200, 30, 40) } }
)
add(
	"title_wallrunner",
	"Title",
	"Wall Runner",
	"Epic",
	{ Text = "Wall Runner", Style = "Gradient", Colors = { rgb(255, 122, 217), rgb(155, 91, 255) } }
)
add(
	"title_freerunner",
	"Title",
	"Free Runner",
	"Epic",
	{ Text = "Free Runner", Style = "Gradient", Colors = { rgb(25, 227, 255), rgb(124, 255, 79) } }
)
add(
	"title_untouchable",
	"Title",
	"Untouchable",
	"Legendary",
	{ Text = "Untouchable", Style = "Shine", Colors = { rgb(255, 180, 40), rgb(255, 230, 110) } }
)
add(
	"title_tagmaster",
	"Title",
	"Tag Master",
	"Legendary",
	{ Text = "Tag Master", Style = "Shine", Colors = { rgb(255, 90, 60), rgb(255, 200, 60) } }
)
add("title_phantom", "Title", "Phantom", "Iridescent", { Text = "Phantom", Style = "Holo" })
add(
	"title_hallmonitor",
	"Title",
	"Hall Monitor",
	"Exclusive",
	{ Text = "Hall Monitor", Style = "Solid", Colors = { rgb(255, 230, 120) } },
	{ note = "Reach level 5" }
)
add(
	"title_valedictorian",
	"Title",
	"Valedictorian",
	"Exclusive",
	{ Text = "Valedictorian", Style = "Shine", Colors = { rgb(255, 200, 60), rgb(255, 240, 150) } },
	{ note = "Reach level 30" }
)
add(
	"title_attendance",
	"Title",
	"Perfect Attendance",
	"Exclusive",
	{ Text = "Perfect Attendance", Style = "Solid", Colors = { rgb(120, 255, 180) } },
	{ note = "14-day login streak" }
)
add(
	"title_champion",
	"Title",
	"Champion",
	"Exclusive",
	{ Text = "Champion", Style = "Shine", Colors = { rgb(255, 190, 40), rgb(255, 235, 140) } },
	{ note = "Win 100 games" }
)
add(
	"title_legend",
	"Title",
	"Legend",
	"Exclusive",
	{ Text = "Legend", Style = "Shine", Colors = { rgb(255, 120, 60), rgb(255, 210, 80) } },
	{ note = "Win 500 games" }
)
add(
	"title_hunter",
	"Title",
	"Hunter",
	"Exclusive",
	{ Text = "Hunter", Style = "Solid", Colors = { rgb(255, 90, 90) } },
	{ note = "Tag 1,000 players" }
)
add(
	"title_survivor",
	"Title",
	"Survivor",
	"Exclusive",
	{ Text = "Survivor", Style = "Solid", Colors = { rgb(120, 230, 120) } },
	{ note = "Survive 500 rounds" }
)
add(
	"title_parkour",
	"Title",
	"Parkour Pro",
	"Exclusive",
	{ Text = "Parkour Pro", Style = "Solid", Colors = { rgb(100, 200, 255) } },
	{ note = "Wall run 1,000 times" }
)
add(
	"title_vip",
	"Title",
	"VIP",
	"Exclusive",
	{ Text = "VIP", Style = "Shine", Colors = { rgb(255, 200, 60), rgb(255, 240, 150) } },
	{ note = "VIP gamepass" }
)
add(
	"title_veteran",
	"Title",
	"Veteran",
	"Exclusive",
	{ Text = "Veteran", Style = "Solid", Colors = { rgb(200, 200, 255) } },
	{ note = "Play 100 games" }
)

-- Victories (client/Victories): Victory names the celebration, Length is how many seconds it
-- plays (the win screen grows to fit it, Catalog.winScreenTime), Colors tint its effects.
add("victory_none", "Victory", "None", "Common", { Victory = "None", Length = 0 }, {
	blurb = "No celebration",
})
add("victory_flex", "Victory", "Flex", "Epic", {
	Victory = "Flex",
	Length = 3.5,
	Colors = { rgb(255, 214, 60), rgb(255, 90, 90) },
}, { blurb = "A big flex and a gradient sparkle burst" })
add("victory_backflip", "Victory", "Backflip", "Epic", {
	Victory = "Backflip",
	Length = 5,
	Colors = { rgb(34, 211, 238), rgb(170, 80, 255) },
}, { blurb = "A tucked backflip into a superhero landing" })
add("victory_confetti", "Victory", "Confetti Storm", "Epic", {
	Victory = "ConfettiStorm",
	Length = 6,
	Colors = { rgb(255, 210, 60), rgb(255, 90, 90), rgb(170, 80, 255), rgb(34, 211, 238) },
}, { blurb = "Confetti cannons, then a storm that buries the podium" })
add("victory_breakdance", "Victory", "Breakdance", "Epic", {
	Victory = "Breakdance",
	Length = 5.5,
	Colors = { rgb(255, 62, 138), rgb(255, 214, 10) },
}, { blurb = "A windmill into a one-hand freeze" })
add("victory_katana", "Victory", "Katana", "Epic", {
	Victory = "Katana",
	Length = 5.5,
	Colors = { rgb(255, 143, 194), rgb(255, 255, 255) },
}, { blurb = "Draw, spin, one clean cut, and the other blocks fall apart" })
add("victory_trophy", "Victory", "Trophy Lift", "Epic", {
	Victory = "TrophyLift",
	Length = 5.5,
	Colors = { rgb(255, 62, 138), rgb(34, 211, 238) },
}, { blurb = "A gold trophy lifted high" })
add("victory_podium", "Victory", "Podium Rise", "Legendary", {
	Victory = "PodiumRise",
	Length = 8.3,
	Colors = { rgb(255, 207, 58), rgb(255, 241, 184) },
}, { blurb = "Your block erupts from the ground into a gold spotlight" })
add("victory_thunderstorm", "Victory", "Thunderstorm", "Legendary", {
	Victory = "Thunderstorm",
	Length = 8,
	Colors = { rgb(160, 216, 255), rgb(255, 255, 255) },
}, { blurb = "The sky darkens and lightning lifts you, crackling" })
add("victory_throne", "Victory", "Throne", "Legendary", {
	Victory = "Throne",
	Length = 8,
	Colors = { rgb(106, 43, 191), rgb(255, 62, 138) },
}, { blurb = "A throne crashes down, you lounge under a floating crown" })
add("victory_meteor", "Victory", "Meteor Touchdown", "Legendary", {
	Victory = "MeteorTouchdown",
	Length = 8,
	Colors = { rgb(255, 180, 60), rgb(255, 74, 28) },
}, { blurb = "Launch out of sight and slam back down, cracking the whole podium" })
add("victory_supernova", "Victory", "Supernova", "Iridescent", {
	Victory = "Supernova",
	Length = 9,
}, { blurb = "Rise in holo shards and explode: the screen cracks like glass" })
add("victory_rift", "Victory", "Rift", "Iridescent", {
	Victory = "Rift",
	Length = 9.5,
	Colors = { rgb(255, 64, 150), rgb(255, 215, 235) },
}, { blurb = "Tear open space, float in it, and a supernova erupts behind you" })

-- Items that were replaced: anyone who owned (or wore) the old one gets the new one
-- (server/PlayerData, when a profile loads).
Catalog.Renamed = {
	victory_cheer = "victory_confetti",
	victory_fireworks = "victory_podium",
	victory_hologram = "victory_supernova",
	victory_graduation = "victory_trophy",
} :: { [string]: string }

-- Default items (what a new player has equipped) never appear in the shop or crates.
for _, item in list do
	if
		item.id == "trail_white"
		or item.id == "tag_classic"
		or item.id == "title_rookie"
		or item.id == "victory_none"
	then
		item.shop = false
		item.crate = false
	end
end

local byId: { [string]: Item } = {}
for _, item in list do
	byId[item.id] = item
end

Catalog.Items = list

function Catalog.get(id: string?): Item?
	return if id then byId[id] else nil
end

-- How long the win screen shows when `item` is the winner's victory: at least `minimum`, or long
-- enough for the victory to start after `delay` and finish `tail` seconds before the end.
function Catalog.winScreenTime(item: Item?, minimum: number, delay: number, tail: number): number
	local length = if item then tonumber(item.look.Length) or 0 else 0
	return math.max(minimum, delay + length + tail)
end

-- What an item costs in the shop.
function Catalog.price(item: Item): number
	return item.price or Catalog.Rarities[item.rarity].price
end

-- Every crate item of a rarity.
function Catalog.cratePool(rarity: string): { Item }
	local pool = {}
	for _, item in list do
		if item.crate and item.rarity == rarity then
			table.insert(pool, item)
		end
	end
	return pool
end

local rolls = Random.new()

-- A Mystery crate roll: a rarity by the crate odds (Rarities weights), then an item of it.
function Catalog.roll(rng: Random?): Item?
	local random = rng or rolls
	local total = 0
	for _, name in Catalog.CrateOrder do
		total += Catalog.Rarities[name].weight
	end
	local pick = random:NextNumber() * total
	local chosen = Catalog.CrateOrder[1]
	for _, name in Catalog.CrateOrder do
		pick -= Catalog.Rarities[name].weight
		if pick <= 0 then
			chosen = name
			break
		end
	end
	local pool = Catalog.cratePool(chosen)
	if #pool == 0 then
		pool = Catalog.cratePool(Catalog.CrateOrder[1])
	end
	return if #pool > 0 then pool[random:NextInteger(1, #pool)] else nil
end

local TRAIL_TEXT = {
	Solid = "One solid color",
	Stripes = "Two-color stripes",
	Split = "Two colors side by side",
	Checker = "A two-color checker pattern",
	Camo = "A camo pattern",
	Gradient = "A smooth gradient",
	Holo = "Holo colors that shift as you run",
}
local TRAIL_EFFECT_TEXT = {
	Embers = " with rising embers",
	Stars = " with twinkling stars",
	Sparkles = " with sparkles",
	Sparks = " with crackling sparks",
	Snow = " with falling snow",
	Afterimages = ", plus afterimages of you",
}
local TAG_TEXT = {
	Classic = "A burst in one color",
	Pop = "A one-color ring",
	Sparks = "One-color sparks",
	Hearts = "Two-color hearts",
	Stars = "Two-color stars",
	Pow = "A two-color comic burst",
	Confetti = "A gradient confetti burst",
	Shockwave = "Gradient shockwave rings",
	Lightning = "A lightning strike, sparks and a shake",
	Meteor = "A meteor strike with embers",
	Shatter = "They burst into holo shards, and nearby screens flash",
}
local TITLE_TEXT = {
	Solid = "One solid color",
	TwoTone = "Two-color text",
	Gradient = "Gradient text",
	Shine = "A moving shine and sparkles",
	Holo = "Holo text in a frame, with its serial number",
}

-- A one-line description of what an item looks like (for the Locker and the shop).
function Catalog.describe(item: Item): string
	if item.blurb then
		return item.blurb
	end
	local look = item.look
	if item.kind == "Trail" then
		return (TRAIL_TEXT[look.Pattern] or "A trail") .. (TRAIL_EFFECT_TEXT[look.Effect] or "")
	elseif item.kind == "TagEffect" then
		return TAG_TEXT[look.Effect] or "A tag effect"
	elseif item.kind == "Title" then
		return TITLE_TEXT[look.Style] or "A title"
	end
	return "A victory celebration"
end

return Catalog
