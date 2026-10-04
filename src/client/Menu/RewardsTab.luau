--!strict
-- Menu, Rewards tab: the daily login streak (a 7-day row of reward cards, today's highlighted,
-- and a big Claim button; server/DailyStreak) and achievements (server/Achievements) as cards
-- with progress bars.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Profile = require(script.Parent.Parent.Profile)
local Ui = require(script.Parent.Ui)

local RewardsTab = {}

-- Can today's streak reward be claimed?
function RewardsTab.canClaim(profile: { [string]: any }): boolean
	return profile.Streak.LastDay ~= DayClock.day()
end

-- The streak number today's claim would give.
local function nextCount(profile: { [string]: any }): number
	local today = DayClock.day()
	if profile.Streak.LastDay == today then
		return profile.Streak.Count
	end
	return if profile.Streak.LastDay == today - 1 then profile.Streak.Count + 1 else 1
end

function RewardsTab.badge(profile: { [string]: any }): boolean
	return RewardsTab.canClaim(profile)
end

function RewardsTab.build(page: Frame, api: { [string]: any }): () -> ()
	local scroll = Ui.scroll(page, 10)

	local streakTitle = Ui.text(scroll, "", 26, Ui.Colors.Orange)
	streakTitle.Size = UDim2.new(1, -8, 0, 32)
	streakTitle.TextXAlignment = Enum.TextXAlignment.Left
	streakTitle.LayoutOrder = 1
	local days = Instance.new("Frame")
	days.BackgroundTransparency = 1
	days.Size = UDim2.new(1, -8, 0, 104)
	days.LayoutOrder = 2
	days.Parent = scroll
	local dayLayout = Instance.new("UIListLayout")
	dayLayout.FillDirection = Enum.FillDirection.Horizontal
	dayLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dayLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dayLayout.Padding = UDim.new(0, 8)
	dayLayout.Parent = days
	local claimRow = Instance.new("Frame")
	claimRow.BackgroundTransparency = 1
	claimRow.Size = UDim2.new(1, -8, 0, 56)
	claimRow.LayoutOrder = 3
	claimRow.Parent = scroll
	local claim = Ui.button(claimRow, "", Ui.Colors.Green, function()
		api.send("ClaimStreak")
	end)
	claim.Size = UDim2.fromOffset(260, 50)
	local milestones = {}
	for count, extra in Config.Streak.Milestones do
		for _, id in extra.Items or {} do
			local item = Catalog.get(id)
			if item then
				table.insert(milestones, `{count} days: {item.name}`)
			end
		end
	end
	local milestoneLabel =
		Ui.ink(claimRow, `Streak extras: {table.concat(milestones, ",  ")}`, 15, Ui.Colors.InkDim)
	milestoneLabel.Position = UDim2.fromOffset(274, 0)
	milestoneLabel.Size = UDim2.new(1, -274, 1, 0)
	milestoneLabel.TextXAlignment = Enum.TextXAlignment.Left
	milestoneLabel.TextWrapped = true

	local divider = Ui.divider(scroll)
	divider.LayoutOrder = 4
	local achievementsTitle = Ui.text(scroll, "ACHIEVEMENTS", 26, Ui.Colors.Yellow)
	achievementsTitle.Size = UDim2.new(1, -8, 0, 32)
	achievementsTitle.TextXAlignment = Enum.TextXAlignment.Left
	achievementsTitle.LayoutOrder = 5
	local achievements = Instance.new("Frame")
	achievements.BackgroundTransparency = 1
	achievements.Size = UDim2.new(1, -8, 0, 0)
	achievements.AutomaticSize = Enum.AutomaticSize.Y
	achievements.LayoutOrder = 6
	achievements.Parent = scroll
	local achievementLayout = Instance.new("UIListLayout")
	achievementLayout.Padding = UDim.new(0, 8)
	achievementLayout.SortOrder = Enum.SortOrder.LayoutOrder
	achievementLayout.Parent = achievements

	return function()
		local profile = Profile.get()
		if not profile then
			return
		end
		local can = RewardsTab.canClaim(profile)
		local count = nextCount(profile)
		streakTitle.Text = if can
			then `DAILY STREAK: DAY {count}`
			else `DAILY STREAK: {profile.Streak.Count} DAY{if profile.Streak.Count == 1
				then ""
				else "S"}`
		Ui.setText(
			claim,
			if can
				then "CLAIM!"
				else `NEXT IN {DayClock.format(DayClock.secondsToNextDay()):upper()}`
		)
		claim.BackgroundColor3 = if can then Ui.Colors.Green else Ui.Colors.Locked

		for _, child in days:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local cycleStart = ((count - 1) // 7) * 7
		for i = 1, 7 do
			local day = cycleStart + i
			local reward = Config.Streak.Rewards[i]
			local claimed = day < count or (day == count and not can)
			local isNext = day == count and can
			local color = if claimed
				then Ui.Colors.Locked
				elseif isNext then Ui.Colors.Orange
				elseif i == 7 then Ui.Colors.Yellow
				else Ui.Colors.Teal
			local box = Ui.card(days, color, 12)
			box.Size = UDim2.fromOffset(if i == 7 then 88 else 72, if isNext then 100 else 92)
			local label = Ui.text(box, `DAY {day}`, 15)
			label.Size = UDim2.new(1, 0, 0, 22)
			label.Position = UDim2.fromOffset(0, 4)
			local icon = Instance.new("TextLabel")
			icon.BackgroundTransparency = 1
			icon.Text = if claimed then "✅" elseif reward.Crates then "📦" else "🪙"
			icon.TextScaled = true
			icon.Position = UDim2.new(0.22, 0, 0, 26)
			icon.Size = UDim2.new(0.56, 0, 0, 30)
			icon.Parent = box
			local amount = Ui.text(
				box,
				if reward.Crates then `{reward.Coins}+📦` else tostring(reward.Coins),
				15
			)
			amount.Position = UDim2.new(0, 0, 1, -28)
			amount.Size = UDim2.new(1, 0, 0, 22)
		end

		for _, child in achievements:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, achievement in Config.Achievements do
			local done = profile.Achievements[achievement.Id] == true
			local value = if achievement.Stat == "Level"
				then profile.Level
				elseif achievement.Stat == "Streak" then profile.Streak.Count
				else profile.Stats[achievement.Stat] or 0
			local card =
				Ui.card(achievements, if done then Ui.Colors.Yellow else Ui.Colors.Locked, 12)
			card.Size = UDim2.new(1, 0, 0, 52)
			card.LayoutOrder = if done then 1000 + i else i
			local name =
				Ui.text(card, `{if done then "🏆" else "🔒"} {achievement.Text:upper()}`, 17)
			name.Position = UDim2.fromOffset(12, 0)
			name.Size = UDim2.fromScale(0.5, 1)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local item = achievement.Items and Catalog.get(achievement.Items[1])
			local reward = if item then item.name else `{achievement.Coins or 0}`
			local pill = Ui.pricePill(
				card,
				if item then nil else achievement.Coins,
				if item then reward else nil
			)
			pill.AnchorPoint = Vector2.new(1, 0.5)
			pill.Position = UDim2.new(1, -12, 0.5, 0)
			pill.Size = UDim2.fromOffset(if item then 124 else 84, 26)
			if not done then
				local bar, set = Ui.bar(card, Ui.Colors.Green)
				bar.AnchorPoint = Vector2.new(1, 0.5)
				bar.Position = UDim2.new(1, -150, 0.5, 0)
				bar.Size = UDim2.new(0.3, 0, 0, 16)
				set(value / achievement.Goal)
				local progress =
					Ui.text(bar, `{math.min(value, achievement.Goal)}/{achievement.Goal}`, 13)
				progress.Size = UDim2.fromScale(1, 1)
				progress.ZIndex = 3
			end
		end
	end
end

return RewardsTab
