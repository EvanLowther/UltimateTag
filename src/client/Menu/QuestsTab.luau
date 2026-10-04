--!strict
-- Menu, Quests tab: today's and this week's quests (server/Quests) as bright cards with a
-- progress bar, the reward, reset countdowns and a Claim button once finished.
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
	local scroll = Ui.scroll(page, 10)
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
		local color = if quest.Claimed
			then Ui.Colors.Locked
			elseif kind == "Daily" then Ui.Colors.Blue
			else Ui.Colors.Purple
		local card = Ui.card(scroll, color, 14)
		card.Size = UDim2.new(1, -8, 0, 78)
		card.LayoutOrder = nextOrder()
		local text = Ui.text(card, def.Text:upper(), 20)
		text.Position = UDim2.fromOffset(14, 8)
		text.Size = UDim2.new(1, -170, 0, 24)
		text.TextXAlignment = Enum.TextXAlignment.Left
		local coins = Ui.pricePill(card, def.Coins)
		coins.Position = UDim2.fromOffset(14, 36)
		local xp = Ui.pricePill(card, nil, `{def.XP} XP`)
		xp.Position = UDim2.fromOffset(104, 36)
		xp.Size = UDim2.fromOffset(74, 26)
		local bar, set = Ui.bar(card, if done then Ui.Colors.Green else Ui.Colors.Yellow)
		bar.Position = UDim2.fromOffset(190, 40)
		bar.Size = UDim2.new(1, -360, 0, 18)
		set(quest.Progress / def.Goal)
		local count = Ui.text(bar, `{quest.Progress}/{def.Goal}`, 14)
		count.Size = UDim2.fromScale(1, 1)
		count.ZIndex = 3
		local button = Ui.button(
			card,
			if quest.Claimed then "CLAIMED" elseif done then "CLAIM!" else "GO!",
			if quest.Claimed
				then Ui.Colors.Locked
				elseif done then Ui.Colors.Green
				else Ui.Colors.Orange,
			function()
				if done and not quest.Claimed then
					api.send("ClaimQuest", kind, slot)
				end
			end
		)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.5, 0)
		button.Size = UDim2.fromOffset(130, 50)
		Ui.setTextSize(button, 20)
	end

	local function heading(text: string, color: Color3, resets: string)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, -8, 0, 32)
		frame.LayoutOrder = nextOrder()
		frame.Parent = scroll
		local title = Ui.text(frame, text, 26, color)
		title.Size = UDim2.fromScale(0.5, 1)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local timer = Ui.ink(frame, resets, 16, Ui.Colors.InkDim)
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
		heading(
			"DAILY",
			Ui.Colors.Blue,
			`New quests in {DayClock.format(DayClock.secondsToNextDay())}`
		)
		for slot, quest in profile.Quests.Daily do
			row("Daily", slot, quest)
		end
		local divider = Ui.divider(scroll)
		divider.LayoutOrder = nextOrder()
		heading(
			"WEEKLY",
			Ui.Colors.Purple,
			`New quests in {DayClock.format(DayClock.secondsToNextWeek())}`
		)
		for slot, quest in profile.Quests.Weekly do
			row("Weekly", slot, quest)
		end
	end
end

return QuestsTab
