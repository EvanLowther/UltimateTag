--!strict
-- Menu, Rewards tab: the daily login streak (a 7-day calendar of rewards, today's highlighted,
-- with a Claim button; server/DailyStreak) and achievements (server/Achievements).
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
	if RewardsTab.canClaim(profile) then
		return true
	end
	return false
end

local function rewardText(reward: { [string]: any }): string
	local parts = {}
	if reward.Coins then
		table.insert(parts, `{reward.Coins} coins`)
	end
	if reward.Crates then
		table.insert(parts, `+{reward.Crates} crate`)
	end
	return table.concat(parts, "\n")
end

function RewardsTab.build(page: Frame, api: { [string]: any }): () -> ()
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- Streak section.
	local streakTitle = Ui.label(scroll, "", 22, Ui.Colors.Text, Ui.BigFont)
	streakTitle.Size = UDim2.new(1, -10, 0, 28)
	streakTitle.TextXAlignment = Enum.TextXAlignment.Left
	streakTitle.LayoutOrder = 1
	local days = Instance.new("Frame")
	days.BackgroundTransparency = 1
	days.Size = UDim2.new(1, -10, 0, 96)
	days.LayoutOrder = 2
	days.Parent = scroll
	local dayLayout = Instance.new("UIListLayout")
	dayLayout.FillDirection = Enum.FillDirection.Horizontal
	dayLayout.Padding = UDim.new(0, 6)
	dayLayout.Parent = days
	local claimRow = Instance.new("Frame")
	claimRow.BackgroundTransparency = 1
	claimRow.Size = UDim2.new(1, -10, 0, 46)
	claimRow.LayoutOrder = 3
	claimRow.Parent = scroll
	local claim = Ui.button(claimRow, "", Ui.Colors.Good, function()
		api.send("ClaimStreak")
	end)
	claim.Size = UDim2.fromOffset(240, 42)
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
		Ui.label(claimRow, `Streak extras: {table.concat(milestones, ",  ")}`, 14, Ui.Colors.Dim)
	milestoneLabel.Position = UDim2.fromOffset(252, 0)
	milestoneLabel.Size = UDim2.new(1, -252, 1, 0)
	milestoneLabel.TextXAlignment = Enum.TextXAlignment.Left
	milestoneLabel.TextWrapped = true

	-- Achievements section (filled by server/Achievements data in Config).
	local achievementsTitle = Ui.label(scroll, "ACHIEVEMENTS", 22, Ui.Colors.Text, Ui.BigFont)
	achievementsTitle.Size = UDim2.new(1, -10, 0, 28)
	achievementsTitle.TextXAlignment = Enum.TextXAlignment.Left
	achievementsTitle.LayoutOrder = 4
	local achievements = Instance.new("Frame")
	achievements.BackgroundTransparency = 1
	achievements.Size = UDim2.new(1, -10, 0, 0)
	achievements.AutomaticSize = Enum.AutomaticSize.Y
	achievements.LayoutOrder = 5
	achievements.Parent = scroll
	local achievementLayout = Instance.new("UIListLayout")
	achievementLayout.Padding = UDim.new(0, 6)
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
		claim.Text = if can
			then "Claim today's reward!"
			else `Next in {DayClock.format(DayClock.secondsToNextDay())}`
		claim.BackgroundColor3 = if can then Ui.Colors.Good else Ui.Colors.PanelLight

		for _, child in days:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		-- The 7-day cycle the next claim is in; today's box is highlighted.
		local cycleStart = ((count - 1) // 7) * 7
		for i = 1, 7 do
			local day = cycleStart + i
			local reward = Config.Streak.Rewards[i]
			local claimed = day < count or (day == count and not can)
			local isNext = day == count and can
			local box = Ui.frame(days, if isNext then Ui.Colors.Accent else Ui.Colors.Card, 10)
			box.Size = UDim2.fromOffset(76, 92)
			if i == 7 then
				Ui.stroke(box, Ui.Colors.Coin, 2.5)
			end
			local label = Ui.label(box, `Day {day}`, 16)
			label.Size = UDim2.new(1, 0, 0, 24)
			local rewardLabel = Ui.label(box, rewardText(reward), 13, Ui.Colors.Coin)
			rewardLabel.Position = UDim2.fromOffset(0, 26)
			rewardLabel.Size = UDim2.new(1, 0, 0, 36)
			rewardLabel.TextWrapped = true
			local status =
				Ui.label(box, if claimed then "✅" elseif isNext then "Today!" else "", 16)
			status.Position = UDim2.fromOffset(0, 64)
			status.Size = UDim2.new(1, 0, 0, 24)
		end

		-- Achievements.
		for _, child in achievements:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, achievement in Config.Achievements or {} do
			local done = profile.Achievements[achievement.Id] == true
			local value = if achievement.Stat == "Level"
				then profile.Level
				elseif achievement.Stat == "Streak" then profile.Streak.Count
				else profile.Stats[achievement.Stat] or 0
			local row =
				Ui.frame(achievements, if done then Ui.Colors.Card else Ui.Colors.PanelLight, 10)
			row.Size = UDim2.new(1, 0, 0, 44)
			row.LayoutOrder = if done then 1000 + i else i
			local name = Ui.label(row, `{if done then "🏆" else "🔒"}  {achievement.Text}`, 17)
			name.Position = UDim2.fromOffset(12, 0)
			name.Size = UDim2.fromScale(0.62, 1)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local item = achievement.Items and Catalog.get(achievement.Items[1])
			local rewardParts = {}
			if achievement.Coins then
				table.insert(rewardParts, `{achievement.Coins} coins`)
			end
			if item then
				table.insert(rewardParts, item.name)
			end
			local right = Ui.label(
				row,
				if done
					then "Done"
					else `{math.min(value, achievement.Goal)}/{achievement.Goal}  ·  {table.concat(
						rewardParts,
						", "
					)}`,
				14,
				if done then Ui.Colors.Good else Ui.Colors.Dim
			)
			right.AnchorPoint = Vector2.new(1, 0)
			right.Position = UDim2.new(1, -12, 0, 0)
			right.Size = UDim2.fromScale(0.38, 1)
			right.TextXAlignment = Enum.TextXAlignment.Right
			right.TextWrapped = true
		end
	end
end

return RewardsTab
