--!strict
-- Menu, Rewards page:
--   The daily login streak (server/DailyStreak): a row of the 7 days, today's with a Claim
--   button (claimed by hand, once per UTC day; missing a day starts it over).
--   Your crates: the Mystery crate with how many you have, its odds (shared/Catalog), Open and
--   Open all (server/Shop; the reel plays in Menu/Popups), and beside them the last few things
--   you opened (the newest LAST_SHOWN, in a strip no taller than the Open button).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Profile = require(script.Parent.Parent.Profile)
local Ui = require(script.Parent.Ui)

local RewardsTab = {}

local LAST_SHOWN = 5 -- items in the "Last opened" strip (the newest)
local NARROW_BELOW = 560 -- pages narrower than this (virtual pixels) stack the crate and its odds
local DAY_HEIGHT = 100 -- a streak day's tile
local CRATE_HEIGHT = 236 -- the crate panel and the odds panel

-- Can today's streak reward be claimed?
function RewardsTab.canClaim(profile: { [string]: any }): boolean
	return profile.Streak.LastDay ~= DayClock.day()
end

-- The streak day today's claim would be (or the day already claimed today).
local function nextCount(profile: { [string]: any }): number
	local today = DayClock.day()
	if profile.Streak.LastDay == today then
		return profile.Streak.Count
	end
	return if profile.Streak.LastDay == today - 1 then profile.Streak.Count + 1 else 1
end

-- The count on the Rewards button: today's streak reward plus crates waiting.
function RewardsTab.badge(profile: { [string]: any }): number
	return (if RewardsTab.canClaim(profile) then 1 else 0) + profile.Crates
end

-- The header's right side: the streak.
function RewardsTab.info(profile: { [string]: any }): string
	local days = if RewardsTab.canClaim(profile)
		then (if profile.Streak.LastDay == DayClock.day() - 1 then profile.Streak.Count else 0)
		else profile.Streak.Count
	return `{days} day streak`
end

function RewardsTab.build(page: Frame, api: { [string]: any }): () -> ()
	local scroll = Ui.scroll(page, 10)

	-- The streak.
	local streakHead = Ui.frame(scroll)
	streakHead.LayoutOrder = 1
	streakHead.Size = UDim2.new(1, -6, 0, 32)
	local flame = Ui.icon(streakHead, "flame", 28, Ui.Colors.Orange, Ui.Colors.Yellow)
	flame.Position = UDim2.fromOffset(0, 2)
	local streakTitle = Ui.caps(streakHead, "", 19, Ui.Colors.Text)
	streakTitle.Position = UDim2.fromOffset(36, 0)
	streakTitle.Size = UDim2.new(0.6, -40, 1, 0)
	streakTitle.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(streakTitle, 15, 19)
	local streakNote = Ui.caps(streakHead, "", 15, Ui.Colors.Dim)
	streakNote.AnchorPoint = Vector2.new(1, 0)
	streakNote.Position = UDim2.fromScale(1, 0)
	streakNote.Size = UDim2.new(0.4, -4, 1, 0)
	streakNote.TextXAlignment = Enum.TextXAlignment.Right
	Ui.shrinkText(streakNote, 15, 15)
	local days = Ui.frame(scroll)
	days.LayoutOrder = 2
	days.Size = UDim2.new(1, -6, 0, DAY_HEIGHT)
	local dayGrid = Instance.new("UIGridLayout")
	dayGrid.CellSize = UDim2.new(1 / 7, -6, 1, 0)
	dayGrid.CellPadding = UDim2.fromOffset(6, 6)
	dayGrid.SortOrder = Enum.SortOrder.LayoutOrder
	dayGrid.Parent = days

	-- The crates.
	local crateHead = Ui.caps(scroll, "Your crates", 19, Ui.Colors.Text)
	crateHead.LayoutOrder = 3
	crateHead.Size = UDim2.new(1, -6, 0, 30)
	crateHead.TextXAlignment = Enum.TextXAlignment.Left
	local crateRow = Ui.frame(scroll)
	crateRow.LayoutOrder = 4
	crateRow.Size = UDim2.new(1, -6, 0, CRATE_HEIGHT)
	local function narrow(): boolean
		return Ui.bodySize(page).X < NARROW_BELOW
	end

	local crate = Ui.panel(crateRow, Ui.Colors.Card, 10)
	crate.Size = UDim2.new(0, 250, 1, 0)
	local crateStrip = Ui.frame(crate, Ui.Colors.Yellow)
	crateStrip.Size = UDim2.new(1, -10, 0, 4)
	local box = Ui.icon(crate, "crate", 92, Ui.Colors.Yellow, Ui.Colors.Ink)
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 40)
	local crateName = Ui.title(crate, "Mystery crate", 32, Ui.Colors.Text)
	crateName.Position = UDim2.fromOffset(0, 140)
	crateName.Size = UDim2.new(1, 0, 0, 38)
	Ui.pad(crateName, 12, 0)
	Ui.shrinkText(crateName, 18, 32)
	local crateStatus = Ui.caps(crate, "", 16, Ui.Colors.Text)
	crateStatus.Position = UDim2.fromOffset(0, 182)
	crateStatus.Size = UDim2.new(1, 0, 0, 44)
	crateStatus.TextWrapped = true
	Ui.pad(crateStatus, 12, 0)
	local crateCount = Ui.caps(crate, "", 20, Ui.Colors.Lime)
	crateCount.AnchorPoint = Vector2.new(1, 0)
	crateCount.Position = UDim2.new(1, -14, 0, 10)
	crateCount.Size = UDim2.fromOffset(160, 30)
	Ui.shrinkText(crateCount, 15, 20)
	crateCount.TextXAlignment = Enum.TextXAlignment.Right

	local odds = Ui.panel(crateRow, Ui.Colors.Card, 10)
	odds.Position = UDim2.fromOffset(262, 0)
	odds.Size = UDim2.new(1, -262, 1, 0)
	local oddsTitle = Ui.caps(odds, "Mystery crate odds", 16, Ui.Colors.Text)
	oddsTitle.Position = UDim2.fromOffset(14, 10)
	oddsTitle.Size = UDim2.new(1, -28, 0, 26)
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	for i, name in Catalog.CrateOrder do
		local rarity = Catalog.Rarities[name]
		local y = 44 + (i - 1) * 28
		local label = Ui.rarity(odds, name, 15)
		label.Position = UDim2.fromOffset(14, y)
		label.Size = UDim2.fromOffset(124, 24)
		label.TextXAlignment = Enum.TextXAlignment.Left
		Ui.shrinkText(label, 15, 15)
		local bar, set = Ui.bar(odds, rarity.color, 4)
		bar.Position = UDim2.fromOffset(144, y + 6)
		bar.Size = UDim2.new(1, -144 - 104, 0, 12)
		set(math.max(rarity.weight / 50, 0.03)) -- scaled so Common (45%) nearly fills it
		if name == "Iridescent" then
			-- Its sliver shimmers (the middle piece; the slanted ends keep their cut).
			local fill = bar:FindFirstChild("Fill") :: Frame
			local middle = fill:FindFirstChild("SlabMid")
			if middle and middle:IsA("Frame") then
				middle.BackgroundColor3 = Color3.new(1, 1, 1)
				Ui.holo(middle)
			end
		end
		local percent = Ui.caps(odds, `{rarity.weight}%`, 15, Ui.Colors.Text)
		percent.AnchorPoint = Vector2.new(1, 0)
		percent.Position = UDim2.new(1, -14, 0, y)
		percent.Size = UDim2.fromOffset(84, 24)
		percent.TextXAlignment = Enum.TextXAlignment.Right
	end
	local oddsNote = Ui.text(
		odds,
		"Any trail, tag effect, title or victory. Iridescent is about 1 in 2,000. Duplicates can happen.",
		14,
		Ui.Colors.Dim
	)
	oddsNote.Position = UDim2.new(0, 14, 1, -50)
	oddsNote.Size = UDim2.new(1, -28, 0, 44)
	oddsNote.TextXAlignment = Enum.TextXAlignment.Left
	oddsNote.TextYAlignment = Enum.TextYAlignment.Top
	oddsNote.TextWrapped = true
	oddsNote.TextTruncate = Enum.TextTruncate.AtEnd

	-- Open and Open all, and right beside them the last things you opened: a strip no taller
	-- than the Open button, the newest LAST_SHOWN (it scrolls sideways if they don't all fit).
	local BUTTON_HEIGHT = Ui.hit(46)
	local buttons = Ui.frame(scroll)
	buttons.LayoutOrder = 5
	buttons.Size = UDim2.new(1, -6, 0, BUTTON_HEIGHT)
	local open = Ui.button(buttons, "Open", Ui.Colors.Lime, function()
		api.send("OpenCrate", 1)
	end)
	open.Size = UDim2.fromOffset(150, BUTTON_HEIGHT)
	Ui.setTextSize(open, 22)
	local openAll = Ui.button(buttons, "Open all", Ui.Colors.Tab, function()
		local profile = Profile.get()
		if profile and profile.Crates > 1 then
			api.send("OpenCrate", math.min(profile.Crates, Config.Shop.OpenAllMax))
		end
	end, Ui.Colors.Text)
	openAll.Position = UDim2.fromOffset(162, 0)
	openAll.Size = UDim2.fromOffset(170, BUTTON_HEIGHT)
	Ui.setTextSize(openAll, 18)

	local last = Instance.new("ScrollingFrame")
	last.Name = "LastOpened"
	last.BackgroundTransparency = 1
	last.BorderSizePixel = 0
	last.ScrollingDirection = Enum.ScrollingDirection.X
	last.AutomaticCanvasSize = Enum.AutomaticSize.X
	last.CanvasSize = UDim2.new()
	last.ScrollBarThickness = 4
	last.ScrollBarImageColor3 = Ui.Colors.Dim
	last.ElasticBehavior = Enum.ElasticBehavior.Never
	last.Parent = buttons
	local lastLayout = Instance.new("UIListLayout")
	lastLayout.FillDirection = Enum.FillDirection.Horizontal
	lastLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	lastLayout.Padding = UDim.new(0, 6)
	lastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lastLayout.Parent = last

	-- Wide: the strip fills the rest of the buttons' row (after Open all, or after Open when
	-- Open all is hidden). Narrow: under the buttons, as tall as them. Wide: the crate and its
	-- odds side by side; narrow: stacked.
	local function arrange()
		local after = if openAll.Visible then 344 else 162
		if narrow() then
			crateRow.Size = UDim2.new(1, -6, 0, CRATE_HEIGHT * 2 + 10)
			crate.Size = UDim2.new(1, 0, 0, CRATE_HEIGHT)
			odds.Position = UDim2.fromOffset(0, CRATE_HEIGHT + 10)
			odds.Size = UDim2.new(1, 0, 0, CRATE_HEIGHT)
			buttons.Size = UDim2.new(1, -6, 0, BUTTON_HEIGHT * 2 + 8)
			last.Position = UDim2.fromOffset(0, BUTTON_HEIGHT + 8)
			last.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
		else
			crateRow.Size = UDim2.new(1, -6, 0, CRATE_HEIGHT)
			crate.Size = UDim2.new(0, 250, 1, 0)
			odds.Position = UDim2.fromOffset(262, 0)
			odds.Size = UDim2.new(1, -262, 1, 0)
			buttons.Size = UDim2.new(1, -6, 0, BUTTON_HEIGHT)
			last.Position = UDim2.fromOffset(after, 0)
			last.Size = UDim2.new(1, -after, 0, BUTTON_HEIGHT)
		end
	end

	-- What you opened this session, newest first.
	local opened: { { id: string, duplicate: boolean } } = {}
	local function drawLast()
		for _, child in last:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local chipHeight = BUTTON_HEIGHT - 8 -- (room for the sideways scroll bar)
		local title = Ui.caps(last, "Last opened", 14, Ui.Colors.Dim)
		title.LayoutOrder = 0
		title.Size = UDim2.fromOffset(0, chipHeight)
		title.AutomaticSize = Enum.AutomaticSize.X
		if #opened == 0 then
			local none = Ui.caps(last, "Nothing yet", 14, Ui.Colors.Dim)
			none.LayoutOrder = 1
			none.Size = UDim2.fromOffset(0, chipHeight)
			none.AutomaticSize = Enum.AutomaticSize.X
		end
		for i, entry in opened do
			local item = Catalog.get(entry.id)
			if not item or i > LAST_SHOWN then
				continue
			end
			local chip = Ui.frame(last, Ui.Colors.Card)
			chip.LayoutOrder = i
			chip.Size = UDim2.fromOffset(0, chipHeight)
			chip.AutomaticSize = Enum.AutomaticSize.X
			local edge = Ui.frame(chip, Ui.rarityColor(item.rarity))
			edge.Size = UDim2.new(0, 4, 1, 0)
			if item.rarity == "Iridescent" then
				edge.BackgroundColor3 = Color3.new(1, 1, 1)
				Ui.holo(edge)
			end
			local text = Ui.upper(item.name)
				.. (
					if entry.duplicate
						then ` <font color="#{Ui.Colors.Dim:ToHex()}">DUP</font>`
						else ""
				)
			local name = Ui.caps(chip, text, 15, Ui.Colors.Text)
			name.Position = UDim2.fromOffset(12, 0)
			name.Size = UDim2.fromScale(0, 1)
			name.AutomaticSize = Enum.AutomaticSize.X
			local pad = Instance.new("UIPadding")
			pad.PaddingRight = UDim.new(0, 12)
			pad.Parent = chip
		end
	end
	Remotes.get("Reward").OnClientEvent:Connect(function(payload)
		if
			type(payload) == "table"
			and payload.Kind == "Crate"
			and type(payload.Items) == "table"
		then
			for _, result in payload.Items do
				table.insert(opened, 1, { id = result.Item, duplicate = result.Duplicate == true })
			end
			while #opened > LAST_SHOWN do
				table.remove(opened)
			end
			drawLast()
		end
	end)
	drawLast()

	return function()
		local profile = Profile.get()
		if not profile then
			return
		end
		local can = RewardsTab.canClaim(profile)
		local count = nextCount(profile)
		streakTitle.Text = if can
			then `LOGIN STREAK: DAY {count}`
			else `LOGIN STREAK: {profile.Streak.Count} DAY{if profile.Streak.Count == 1
				then ""
				else "S"}`
		streakNote.Text = if can
			then "RESETS IF YOU MISS A DAY"
			else Ui.upper(`Next in {DayClock.format(DayClock.secondsToNextDay())}`)

		arrange()
		local columns = if narrow() then 4 else 7
		local rowCount = math.ceil(7 / columns)
		-- Exactly `columns` a row (a pixel spare so rounding never pushes the last day onto a
		-- line of its own).
		dayGrid.FillDirectionMaxCells = columns
		dayGrid.CellSize = UDim2.new(1 / columns, -6 * (columns - 1) / columns - 1, 0, DAY_HEIGHT)
		days.Size = UDim2.new(1, -6, 0, rowCount * DAY_HEIGHT + (rowCount - 1) * 6)
		Ui.clear(days)
		local cycleStart = ((count - 1) // 7) * 7
		for i = 1, 7 do
			local day = cycleStart + i
			local reward = Config.Streak.Rewards[i]
			local claimed = day < count or (day == count and not can)
			local isNext = day == count and can
			local tile = Instance.new("TextButton")
			tile.AutoButtonColor = false
			tile.BackgroundTransparency = 1
			tile.Text = ""
			tile.LayoutOrder = i
			local back = Ui.slab(tile, if isNext then Ui.Colors.Lime else Ui.Colors.Card, 8)
			back.Size = UDim2.fromScale(1, 1)
			local underline = Ui.slab(
				tile,
				if claimed or isNext
					then Ui.Colors.Lime
					elseif i == 7 then Ui.Colors.Yellow
					else Ui.Colors.Tab,
				2
			)
			underline.AnchorPoint = Vector2.new(0, 1)
			underline.Position = UDim2.fromScale(0, 1)
			underline.Size = UDim2.new(1, -8, 0, 4)
			-- Which day, then exactly what it gives: the coins (a coin, the amount, the word
			-- COINS) and any crate. Claimed days keep showing what they gave, with a check.
			local ink = if isNext
				then Ui.Colors.Ink
				elseif claimed then Ui.Colors.Lime
				else Ui.Colors.Dim
			local top = Ui.caps(
				tile,
				if isNext
					then "Claim today"
					elseif day == count and claimed then "Today"
					else `Day {day}`,
				14,
				ink
			)
			top.Position = UDim2.fromOffset(0, 8)
			top.Size = UDim2.new(1, 0, 0, 24)
			Ui.pad(top, 10, 0)
			Ui.shrinkText(top, 15, 14)
			top.ZIndex = 2
			local amountColor = if isNext
				then Ui.Colors.Ink
				elseif claimed then Ui.Colors.Lime
				else Ui.Colors.Yellow
			local amount = Ui.coinAmount(tile, reward.Coins, if isNext then 20 else 18, amountColor)
			amount.AnchorPoint = Vector2.new(0.5, 0)
			amount.Position = UDim2.new(0.5, 0, 0, 34)
			amount.ZIndex = 2
			for _, item in amount:GetDescendants() do
				if item:IsA("GuiObject") then
					item.ZIndex = 2
				end
			end
			local what = Ui.caps(
				tile,
				if reward.Crates
					then `+{reward.Crates} crate{if reward.Crates == 1 then "" else "s"}` -- (the coins show above)
					else "Coins",
				14,
				if isNext then Ui.Colors.Ink else Ui.Colors.Text
			)
			what.Position = UDim2.fromOffset(0, 66)
			what.Size = UDim2.new(1, 0, 0, 24)
			Ui.pad(what, 8, 0)
			Ui.shrinkText(what, 15, 14)
			what.ZIndex = 2
			if claimed then
				local check = Ui.icon(tile, "check", 20, Ui.Colors.Lime)
				check.AnchorPoint = Vector2.new(1, 0)
				check.Position = UDim2.new(1, -10, 0, 5)
				check.ZIndex = 3
			end
			if isNext then
				tile.Activated:Connect(function()
					api.send("ClaimStreak")
				end)
				Ui.pulse(tile)
			end
			tile.Parent = days
		end

		crateCount.Text = `{profile.Crates} CRATE{if profile.Crates == 1 then "" else "S"}`
		crateStatus.Text = if profile.Crates > 0
			then "READY TO OPEN"
			else "NONE LEFT: BUY ONE IN THE SHOP"
		Ui.setColor(open, if profile.Crates > 0 then Ui.Colors.Lime else Ui.Colors.Track)
		Ui.setText(openAll, `Open all ({math.min(profile.Crates, Config.Shop.OpenAllMax)})`)
		openAll.Visible = profile.Crates > 1
		arrange()
	end
end

return RewardsTab
