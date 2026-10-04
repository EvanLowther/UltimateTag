--!strict
-- Every cosmetic in the game (data only; both sides read it).
--   kind:   "Trail" (speed trail colors), "TagEffect" (what tagging looks like), "Title" (text
--           over your head), "Victory" (your celebration when you win).
--   rarity: Common, Rare, Epic, Legendary (sold in the shop and found in crates) or Exclusive
--           (only earned: levels, login streak, achievements).
--   shop / crate: whether it can show up in the daily shop / come out of a crate.
--   look:   how it looks (read by client/CosmeticEffects, client/SpeedTrails, server/Titles).
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
}

export type Rarity = { color: Color3, price: number, weight: number, order: number }

Catalog.Rarities = {
	Common = { color = Color3.fromRGB(170, 180, 190), price = 150, weight = 60, order = 1 },
	Rare = { color = Color3.fromRGB(60, 150, 255), price = 400, weight = 28, order = 2 },
	Epic = { color = Color3.fromRGB(170, 80, 255), price = 900, weight = 10, order = 3 },
	Legendary = { color = Color3.fromRGB(255, 180, 40), price = 2000, weight = 2, order = 4 },
	Exclusive = { color = Color3.fromRGB(255, 80, 120), price = 0, weight = 0, order = 5 },
} :: { [string]: Rarity }

Catalog.Kinds = { "Trail", "TagEffect", "Title", "Victory" }
Catalog.KindNames =
	{ Trail = "Trails", TagEffect = "Tag Effects", Title = "Titles", Victory = "Victories" }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Item } = {}

local function add(
	id: string,
	kind: string,
	name: string,
	rarity: string,
	look: { [string]: any },
	note: string?
)
	local sellable = rarity ~= "Exclusive"
	table.insert(list, {
		id = id,
		kind = kind,
		name = name,
		rarity = rarity,
		shop = sellable,
		crate = sellable,
		look = look,
		note = note,
	})
end

-- Trails: Colors (one = solid, several = a gradient along the streak), Light (0-1 glow).
add("trail_white", "Trail", "Classic White", "Common", { Colors = { rgb(255, 255, 255) } })
add("trail_red", "Trail", "Cherry", "Common", { Colors = { rgb(255, 70, 70) } })
add("trail_blue", "Trail", "Sky", "Common", { Colors = { rgb(70, 150, 255) } })
add("trail_green", "Trail", "Lime", "Common", { Colors = { rgb(110, 230, 90) } })
add("trail_pink", "Trail", "Neon Pink", "Rare", { Colors = { rgb(255, 80, 200) }, Light = 0.6 })
add("trail_ice", "Trail", "Ice", "Rare", { Colors = { rgb(160, 240, 255), rgb(255, 255, 255) } })
add("trail_shadow", "Trail", "Shadow", "Rare", { Colors = { rgb(25, 20, 30), rgb(90, 40, 120) } })
add(
	"trail_gold",
	"Trail",
	"Gold Rush",
	"Epic",
	{ Colors = { rgb(255, 210, 60), rgb(255, 160, 30) }, Light = 0.5 }
)
add("trail_fire", "Trail", "Wildfire", "Epic", {
	Colors = { rgb(255, 240, 120), rgb(255, 140, 30), rgb(230, 40, 20) },
	Light = 1,
})
add("trail_rainbow", "Trail", "Rainbow", "Legendary", {
	Colors = {
		rgb(255, 60, 60),
		rgb(255, 170, 40),
		rgb(255, 240, 60),
		rgb(80, 230, 90),
		rgb(60, 150, 255),
		rgb(170, 80, 255),
	},
	Light = 0.4,
})
add("trail_galaxy", "Trail", "Galaxy", "Legendary", {
	Colors = { rgb(120, 60, 255), rgb(40, 120, 255), rgb(255, 90, 220) },
	Light = 1,
})
add(
	"trail_honor",
	"Trail",
	"Honor Roll",
	"Exclusive",
	{ Colors = { rgb(255, 220, 90) }, Light = 1 },
	"Reach level 10"
)
add("trail_perfect", "Trail", "Perfect Record", "Exclusive", {
	Colors = { rgb(255, 255, 255), rgb(120, 255, 200) },
	Light = 1,
}, "30-day login streak")
add("trail_prismatic", "Trail", "Prismatic", "Exclusive", {
	Colors = { rgb(255, 120, 200), rgb(120, 220, 255), rgb(200, 255, 140), rgb(255, 230, 120) },
	Light = 1,
}, "Reach level 50")

-- Tag effects: Effect picks the burst (client/CosmeticEffects), Color tints it.
add(
	"tag_classic",
	"TagEffect",
	"Classic",
	"Common",
	{ Effect = "Classic", Color = rgb(255, 80, 80) }
)
add("tag_sparks", "TagEffect", "Sparks", "Common", { Effect = "Sparks", Color = rgb(255, 200, 80) })
add("tag_hearts", "TagEffect", "Hearts", "Rare", { Effect = "Hearts", Color = rgb(255, 90, 150) })
add("tag_stars", "TagEffect", "Stars", "Rare", { Effect = "Stars", Color = rgb(255, 240, 120) })
add(
	"tag_confetti",
	"TagEffect",
	"Confetti",
	"Epic",
	{ Effect = "Confetti", Color = rgb(255, 255, 255) }
)
add(
	"tag_shockwave",
	"TagEffect",
	"Shockwave",
	"Epic",
	{ Effect = "Shockwave", Color = rgb(80, 200, 255) }
)
add(
	"tag_lightning",
	"TagEffect",
	"Lightning",
	"Legendary",
	{ Effect = "Lightning", Color = rgb(150, 220, 255) }
)

-- Titles: Text over your head, Color, Glow (shine).
add("title_rookie", "Title", "Rookie", "Common", { Text = "Rookie", Color = rgb(220, 220, 220) })
add(
	"title_wallrunner",
	"Title",
	"Wall Runner",
	"Common",
	{ Text = "Wall Runner", Color = rgb(140, 220, 255) }
)
add(
	"title_slippery",
	"Title",
	"Slippery",
	"Common",
	{ Text = "Slippery", Color = rgb(120, 200, 255) }
)
add(
	"title_classclown",
	"Title",
	"Class Clown",
	"Rare",
	{ Text = "Class Clown", Color = rgb(255, 170, 60) }
)
add(
	"title_speeddemon",
	"Title",
	"Speed Demon",
	"Rare",
	{ Text = "Speed Demon", Color = rgb(255, 80, 60) }
)
add(
	"title_untouchable",
	"Title",
	"Untouchable",
	"Epic",
	{ Text = "Untouchable", Color = rgb(190, 110, 255), Glow = true }
)
add(
	"title_tagmaster",
	"Title",
	"Tag Master",
	"Legendary",
	{ Text = "Tag Master", Color = rgb(255, 200, 60), Glow = true }
)
add(
	"title_hallmonitor",
	"Title",
	"Hall Monitor",
	"Exclusive",
	{ Text = "Hall Monitor", Color = rgb(255, 230, 120) },
	"Reach level 5"
)
add("title_valedictorian", "Title", "Valedictorian", "Exclusive", {
	Text = "Valedictorian",
	Color = rgb(255, 215, 80),
	Glow = true,
}, "Reach level 30")
add("title_attendance", "Title", "Perfect Attendance", "Exclusive", {
	Text = "Perfect Attendance",
	Color = rgb(120, 255, 180),
}, "14-day login streak")
add(
	"title_champion",
	"Title",
	"Champion",
	"Exclusive",
	{ Text = "Champion", Color = rgb(255, 200, 60), Glow = true },
	"Win 100 games"
)
add(
	"title_legend",
	"Title",
	"Legend",
	"Exclusive",
	{ Text = "Legend", Color = rgb(255, 120, 60), Glow = true },
	"Win 500 games"
)
add(
	"title_hunter",
	"Title",
	"Hunter",
	"Exclusive",
	{ Text = "Hunter", Color = rgb(255, 90, 90) },
	"Tag 1,000 players"
)
add(
	"title_survivor",
	"Title",
	"Survivor",
	"Exclusive",
	{ Text = "Survivor", Color = rgb(120, 230, 120) },
	"Survive 500 rounds"
)
add(
	"title_parkour",
	"Title",
	"Parkour Pro",
	"Exclusive",
	{ Text = "Parkour Pro", Color = rgb(100, 200, 255) },
	"Wall run 1,000 times"
)
add(
	"title_vip",
	"Title",
	"VIP",
	"Exclusive",
	{ Text = "VIP", Color = rgb(255, 215, 80), Glow = true },
	"VIP gamepass"
)
add(
	"title_veteran",
	"Title",
	"Veteran",
	"Exclusive",
	{ Text = "Veteran", Color = rgb(200, 200, 255) },
	"Play 100 games"
)

-- Victories: Pose (an animation, client/CosmeticEffects) and Effect (a burst around you).
add("victory_none", "Victory", "None", "Common", { Pose = "None", Effect = "None" })
add("victory_flex", "Victory", "Flex", "Common", { Pose = "Flex", Effect = "None" })
add("victory_cheer", "Victory", "Cheer", "Rare", { Pose = "Cheer", Effect = "Confetti" })
add("victory_fireworks", "Victory", "Fireworks", "Epic", { Pose = "Cheer", Effect = "Fireworks" })
add("victory_backflip", "Victory", "Backflip", "Legendary", { Pose = "Backflip", Effect = "Stars" })
add("victory_graduation", "Victory", "Graduation", "Exclusive", {
	Pose = "CapToss",
	Effect = "Confetti",
}, "Reach level 20")

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

-- What an item costs in the shop.
function Catalog.price(item: Item): number
	return item.price or Catalog.Rarities[item.rarity].price
end

return Catalog
