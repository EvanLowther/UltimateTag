--!strict
-- Menu, Quests tab: today's and this week's quests (server/Quests) with progress bars, rewards,
-- reset countdowns and a Claim button once finished.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Profile = require(script.Parent.Parent.Profile)
local Ui = require(script.Parent.Ui)

local QuestsTab = {}

local function definition(kind: string, id: string): { [string]: any }?
	for _, quest in Config.Quests[kind] do
		if quest.Id == id then
			return quest
		end
	end
	return nil
end

-- True when there's a finished quest waiting to be claimed (for the button's badge).
function QuestsTab.badge(profile: { [string]: any }): boolean
	for _, kind in { "Daily", "Weekly" } do
		for _, quest in profile.Quests[kind] do
			local def = definition(kind, quest.Id)
			if def and not quest.Claimed and quest.Progress >= def.Goal then
				return true
			end
		end
	end
	return false
end

function QuestsTab.build(page: Frame, api: { [string]: any }): () -> ()
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

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function row(kind: string, slot: number, quest: { [string]: any })
		local def = definition(kind, quest.Id)
		if not def then
			return
		end
		local done = quest.Progress >= def.Goal
		local frame = Ui.frame(scroll, Ui.Colors.Card, 12)
		frame.Size = UDim2.new(1, -10, 0, 64)
		frame.LayoutOrder = nextOrder()
		if done and not quest.Claimed then
			Ui.stroke(frame, Ui.Colors.Coin, 2.5)
		end
		local text = Ui.label(frame, def.Text, 19)
		text.Position = UDim2.fromOffset(14, 6)
		text.Size = UDim2.new(1, -170, 0, 24)
		text.TextXAlignment = Enum.TextXAlignment.Left
		local reward = Ui.label(
			frame,
			`<font color="#FFCD3C">{def.Coins} coins</font>   <font color="#5AC8FF">{def.XP} XP</font>`,
			14
		)
		reward.Position = UDim2.fromOffset(14, 30)
		reward.Size = UDim2.new(1, -170, 0, 16)
		reward.TextXAlignment = Enum.TextXAlignment.Left
		local bar = Ui.frame(frame, Ui.Colors.PanelLight, 6)
		bar.Position = UDim2.fromOffset(14, 48)
		bar.Size = UDim2.new(1, -170, 0, 10)
		local fill = Ui.frame(bar, if done then Ui.Colors.Good else Ui.Colors.XP, 6)
		fill.Size = UDim2.fromScale(math.clamp(quest.Progress / def.Goal, 0, 1), 1)
		local count = Ui.label(frame, `{quest.Progress} / {def.Goal}`, 15, Ui.Colors.Dim)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -140, 0, 6)
		count.Size = UDim2.fromOffset(80, 22)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local button = Ui.button(
			frame,
			if quest.Claimed then "Claimed" elseif done then "Claim!" else "In progress",
			if quest.Claimed
				then Ui.Colors.PanelLight
				elseif done then Ui.Colors.Good
				else Ui.Colors.PanelLight,
			function()
				if done and not quest.Claimed then
					api.send("ClaimQuest", kind, slot)
				end
			end
		)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -10, 0.5, 0)
		button.Size = UDim2.fromOffset(120, 40)
		button.TextSize = 17
	end

	local function heading(text: string, resets: string)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, -10, 0, 30)
		frame.LayoutOrder = nextOrder()
		frame.Parent = scroll
		local title = Ui.label(frame, text, 22, Ui.Colors.Text, Ui.BigFont)
		title.Size = UDim2.fromScale(0.5, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local timer = Ui.label(frame, resets, 15, Ui.Colors.Dim)
		timer.AnchorPoint = Vector2.new(1, 0)
		timer.Position = UDim2.fromScale(1, 0)
		timer.Size = UDim2.fromScale(0.5, 1)
		timer.TextXAlignment = Enum.TextXAlignment.Right
	end

	return function()
		local profile = Profile.get()
		if not profile then
			return
		end
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		order = 0
		heading("DAILY", `New quests in {DayClock.format(DayClock.secondsToNextDay())}`)
		for slot, quest in profile.Quests.Daily do
			row("Daily", slot, quest)
		end
		heading("WEEKLY", `New quests in {DayClock.format(DayClock.secondsToNextWeek())}`)
		for slot, quest in profile.Quests.Weekly do
			row("Weekly", slot, quest)
		end
	end
end

return QuestsTab
