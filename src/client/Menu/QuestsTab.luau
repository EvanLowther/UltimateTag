--!strict
-- Menu, Quests page: two tabs.
--   Daily: today's quests and, under them, this week's (server/Quests), each with its progress
--   and reward. Progress tracks itself; a finished quest gets a Claim button (no "Go" buttons).
--   Achievements: Config.Achievements grouped into tiered chains (Config.AchievementGroups:
--   "Winner" is win 1, 10, 50...). Each chain shows its next tier, the progress, the reward,
--   and a Claim button once that tier is reached (server/Achievements). Chips filter by
--   category.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Profile = require(script.Parent.Parent.Profile)
local Ui = require(script.Parent.Ui)

local QuestsTab = {}

-- The icon (client/Icons) for each kind of quest.
local EVENT_ICONS = {
	Win = "trophy",
	Tag = "burst",
	GamePlayed = "gamepad",
	RoundSurvived = "shield",
	WallRun = "wall",
	Slide = "speed",
	Vault = "vault",
	Climb = "ladder",
	PlayMinute = "clock",
}
local CATEGORIES = { "All", "Wins", "Tags", "Moves", "Levels", "Streaks" }

type Chain = { group: { [string]: any }, tiers: { { [string]: any } } }

local chains: { Chain } = {}
for _, group in Config.AchievementGroups do
	local tiers = {}
	for _, achievement in Config.Achievements do
		if achievement.Stat == group.Stat then
			table.insert(tiers, achievement)
		end
	end
	table.sort(tiers, function(a, b)
		return a.Goal < b.Goal
	end)
	if #tiers > 0 then
		table.insert(chains, { group = group, tiers = tiers })
	end
end

local function definition(kind: string, id: string): { [string]: any }?
	for _, quest in Config.Quests[kind] do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

local function statValue(profile: { [string]: any }, stat: string): number
	if stat == "Level" then
		return profile.Level
	elseif stat == "Streak" then
		return profile.Streak.Count
	end
	return profile.Stats[stat] or 0
end

-- Finished quests not yet claimed.
local function claimableQuests(profile: { [string]: any }): number
	local count = 0
	for _, kind in { "Daily", "Weekly" } do
		for _, quest in profile.Quests[kind] do
			local def = definition(kind, quest.Id)
			if def and not quest.Claimed and quest.Progress >= def.Goal then
				count += 1
			end
		end
	end
	return count
end

-- Reached achievements not yet claimed.
local function readyAchievements(profile: { [string]: any }): number
	local count = 0
	for _, achievement in Config.Achievements do
		if
			not profile.Achievements[achievement.Id]
			and statValue(profile, achievement.Stat) >= achievement.Goal
		then
			count += 1
		end
	end
	return count
end

-- The count on the Quests button: everything waiting to be claimed.
function QuestsTab.badge(profile: { [string]: any }): number
	return claimableQuests(profile) + readyAchievements(profile)
end

-- What a reward bundle is, as short rich text.
local function rewardText(coins: number?, xp: number?, items: { string }?): string
	local parts = {}
	if coins and coins > 0 then
		table.insert(
			parts,
			`<font color="#{Ui.Colors.Yellow:ToHex()}">{Ui.number(coins)} coins</font>`
		)
	end
	if xp and xp > 0 then
		table.insert(parts, `<font color="#{Ui.Colors.Cyan:ToHex()}">{Ui.number(xp)} XP</font>`)
	end
	for _, id in items or {} do
		local item = Catalog.get(id)
		if item then
			local color = Catalog.Rarities[item.rarity].color:ToHex()
			table.insert(
				parts,
				`<font color="#{color}">{item.name} {Catalog.KindSingular[item.kind]}</font>`
			)
		end
	end
	return table.concat(parts, "<br/>")
end

-- One row: an accent edge, an icon, a title and line under it, a progress bar with a count,
-- and something on the right (a reward, a Claim button, or a done mark). Returns the row and
-- the frame for the right side.
local function row(
	parent: Instance,
	order: number,
	accent: Color3,
	back: Color3,
	icon: string,
	titleText: string,
	line: string?,
	progress: number,
	countText: string
): (Frame, Frame)
	local r = Ui.slab(parent, back, 6)
	r.LayoutOrder = order
	r.Size = UDim2.new(1, -6, 0, if line then 64 else 56)
	local edge = Ui.slab(r, accent, 6)
	edge.Size = UDim2.new(0, 12, 1, 0)
	edge.ZIndex = 1
	local box = Ui.frame(r, Ui.Colors.Panel)
	box.Position = UDim2.fromOffset(18, 9)
	box.Size = UDim2.fromOffset(38, 38)
	Ui.centerIcon(box, icon, 28, accent, Ui.Colors.Text)
	local title = Ui.caps(r, titleText, 14, Ui.Colors.Text)
	title.Position = UDim2.fromOffset(66, 6)
	title.Size = UDim2.new(1, -66 - 220, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local barY = 30
	if line then
		local sub = Ui.text(r, line, 12, Ui.Colors.Dim)
		sub.Position = UDim2.fromOffset(66, 24)
		sub.Size = UDim2.new(1, -66 - 220, 0, 16)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		barY = 42
	end
	local bar, set = Ui.bar(r, accent, 4)
	bar.Position = UDim2.fromOffset(66, barY)
	bar.Size = UDim2.new(1, -66 - 220, 0, 12)
	set(progress)
	local count = Ui.caps(r, countText, 13, Ui.Colors.Text)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -150, 0, 0)
	count.Size = UDim2.new(0, 64, 1, 0)
	local right = Ui.frame(r)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, -12, 0, 0)
	right.Size = UDim2.new(0, 132, 1, 0)
	return r, right
end

local function claimButton(parent: Frame, onClick: () -> ())
	local claim = Ui.button(parent, "Claim", Ui.Colors.Lime, onClick, Ui.Colors.Ink, 7)
	claim.AnchorPoint = Vector2.new(1, 0.5)
	claim.Position = UDim2.fromScale(1, 0.5)
	claim.Size = UDim2.fromOffset(104, 34)
	Ui.setTextSize(claim, 16)
	Ui.pulse(claim)
end

-- A done mark on the right of a row: an icon and a word.
local function rightMark(parent: Frame, icon: string, text: string, color: Color3)
	local mark = Ui.iconText(parent, icon, text, 12, color)
	mark.AnchorPoint = Vector2.new(1, 0.5)
	mark.Position = UDim2.fromScale(1, 0.5)
end

local function rightText(parent: Frame, text: string, color: Color3?)
	local label = Ui.caps(parent, text, 12, color or Ui.Colors.Text)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextWrapped = true
end

local function heading(parent: Instance, order: number, text: string, timer: string)
	local frame = Ui.frame(parent)
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -6, 0, 22)
	local left = Ui.caps(frame, text, 14, Ui.Colors.Text)
	left.Size = UDim2.fromScale(0.5, 1)
	left.TextXAlignment = Enum.TextXAlignment.Left
	local right = Ui.caps(frame, timer, 12, Ui.Colors.Dim)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.fromScale(0.5, 1)
	right.TextXAlignment = Enum.TextXAlignment.Right
end

function QuestsTab.build(page: Frame, api: { [string]: any }): () -> ()
	local daily = Ui.frame(page)
	daily.Position = UDim2.fromOffset(0, 42)
	daily.Size = UDim2.new(1, 0, 1, -42)
	local dailyList = Ui.scroll(daily, 8)

	local achievements = Ui.frame(page)
	achievements.Position = daily.Position
	achievements.Size = daily.Size
	achievements.Visible = false
	local category = "All"
	local refresh: () -> ()
	local chipRow, selectChip = Ui.tabs(achievements, CATEGORIES, Ui.Colors.Text, function(name)
		category = name
		refresh()
	end, 24, 11)
	chipRow.Position = UDim2.fromOffset(0, 0)
	selectChip(category)
	local chainHolder = Ui.frame(achievements)
	chainHolder.Position = UDim2.fromOffset(0, 34)
	chainHolder.Size = UDim2.new(1, 0, 1, -34)
	local chainList = Ui.scroll(chainHolder, 8)

	local current = "Daily"
	local selectTab: (string) -> ()
	local setBadge: (string, number?) -> ()
	local _, select, badge = Ui.tabs(
		page,
		{ "Daily", "Achievements" },
		Ui.Colors.Pink,
		function(name)
			current = name
			daily.Visible = name == "Daily"
			achievements.Visible = name == "Achievements"
			selectTab(name)
			refresh()
		end
	)
	selectTab = select
	setBadge = badge
	selectTab(current)

	local function questRows(profile: { [string]: any }, kind: string, start: number): number
		local order = start
		for slot, quest in profile.Quests[kind] do
			local def = definition(kind, quest.Id)
			if not def then
				continue
			end
			order += 1
			local done = quest.Progress >= def.Goal
			local claimed = quest.Claimed == true
			local accent = if claimed
				then Ui.Colors.Dim
				elseif done then Ui.Colors.Lime
				elseif kind == "Weekly" then Ui.Colors.Gold
				else Ui.Colors.Pink
			local r, right = row(
				dailyList,
				order,
				accent,
				if done and not claimed then Ui.Colors.PaidBack else Ui.Colors.Card,
				if done then "check" else EVENT_ICONS[def.Event] or "quests",
				def.Text,
				nil,
				quest.Progress / def.Goal,
				`{math.min(quest.Progress, def.Goal)}/{def.Goal}`
			)
			if claimed then
				r.Name = "Claimed"
				Ui.fade(r, 0.5)
				rightMark(right, "check", "Claimed", Ui.Colors.Dim)
			elseif done then
				claimButton(right, function()
					api.send("ClaimQuest", kind, slot)
				end)
			else
				rightText(right, rewardText(def.Coins, def.XP))
			end
		end
		return order
	end

	local function refreshDaily(profile: { [string]: any })
		Ui.clear(dailyList)
		heading(
			dailyList,
			1,
			"Today",
			Ui.upper(`New quests in {DayClock.format(DayClock.secondsToNextDay())}`)
		)
		local order = questRows(profile, "Daily", 1)
		heading(
			dailyList,
			order + 1,
			"This week",
			Ui.upper(`Resets in {DayClock.format(DayClock.secondsToNextWeek())}`)
		)
		order = questRows(profile, "Weekly", order + 1)
		local noteRow = Ui.frame(dailyList)
		noteRow.LayoutOrder = order + 1
		noteRow.Size = UDim2.new(1, -6, 0, 24)
		local note = Ui.iconText(
			noteRow,
			"bolt",
			"Progress tracks on its own. Claim each reward here when it's done.",
			11,
			Ui.Colors.Dim
		)
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.Position = UDim2.fromScale(0.5, 0.5)
	end

	local function refreshChains(profile: { [string]: any })
		Ui.clear(chainList)
		for i, chain in chains do
			local group = chain.group
			if category ~= "All" and group.Category ~= category then
				continue
			end
			local value = statValue(profile, group.Stat)
			local nextIndex: number? = nil
			for t, tier in chain.tiers do
				if not profile.Achievements[tier.Id] then
					nextIndex = t
					break
				end
			end
			local full = nextIndex == nil
			local tier = if nextIndex then chain.tiers[nextIndex] else chain.tiers[#chain.tiers]
			local can = not full and value >= tier.Goal
			local previous = if nextIndex and nextIndex > 1
				then chain.tiers[nextIndex - 1].Goal
				else 0
			local progress = if full or can
				then 1
				else (value - previous) / math.max(tier.Goal - previous, 1)
			local line = if full
				then "All tiers done"
				elseif can then `Tier {nextIndex} done: claim it!`
				else `Tier {nextIndex}: {tier.Text}`
			local accent = if full
				then Ui.Colors.Gold
				elseif can then Ui.Colors.Lime
				else Ui.Colors.Pink
			-- The tier pips after the name: gold claimed, lime ready, grey to come.
			local pips = {}
			for t, other in chain.tiers do
				local color = if profile.Achievements[other.Id]
					then Ui.Colors.Gold
					elseif t == nextIndex and can then Ui.Colors.Lime
					else Ui.Colors.Track
				table.insert(pips, `<font color="#{color:ToHex()}">■</font>`)
			end
			local _, right = row(
				chainList,
				i,
				accent,
				if full
					then Ui.Colors.DoneBack
					elseif can then Ui.Colors.PaidBack
					else Ui.Colors.Card,
				group.Icon,
				`{Ui.upper(group.Name)}   {table.concat(pips, " ")}`,
				line,
				progress,
				if full then Ui.number(value) else `{Ui.number(value)}/{Ui.number(tier.Goal)}`
			)
			if full then
				rightMark(right, "check", "Complete", Ui.Colors.Gold)
			elseif can then
				claimButton(right, function()
					api.send("ClaimAchievement", tier.Id)
				end)
			else
				rightText(right, rewardText(tier.Coins, nil, tier.Items))
			end
		end
	end

	refresh = function()
		local profile = Profile.get()
		if not profile then
			return
		end
		setBadge("Daily", claimableQuests(profile))
		setBadge("Achievements", readyAchievements(profile))
		if current == "Daily" then
			refreshDaily(profile)
		else
			refreshChains(profile)
		end
	end
	return refresh
end

return QuestsTab
