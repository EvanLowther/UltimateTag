--!strict
-- Reward popups (from the Reward remote, sent by server/Progression):
--   Earned:  "+15 coins  +20 XP  Round survived" floating up by the coin counter.
--   Grant:   a card listing what a quest, streak, achievement or prize gave you.
--   LevelUp: a big "LEVEL 5!" banner with what came with it.
--   Crate:   a crate opening: a reel of items spins and stops on what you got.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local ItemCard = require(script.Parent.ItemCard)
local Ui = require(script.Parent.Ui)

local Popups = {}

local gui: ScreenGui
local floatAnchor: Frame
local queue: { () -> () } = {} -- big popups wait their turn
local showing = false

local REASONS = {
	GamePlayed = "Game played",
	RoundSurvived = "Round survived",
	Tag = "Tag!",
	Win = "Victory!",
	PlayMinute = "Playing",
}

-- "+15 coins  +20 XP" with coloured parts.
local function amounts(coins: number?, xp: number?): string
	local parts = {}
	if coins and coins > 0 then
		table.insert(parts, `<font color="#FFCD3C">+{Ui.number(coins)} coins</font>`)
	end
	if xp and xp > 0 then
		table.insert(parts, `<font color="#5AC8FF">+{Ui.number(xp)} XP</font>`)
	end
	return table.concat(parts, "   ")
end

local function itemLines(ids: { string }?): { string }
	local lines = {}
	for _, id in ids or {} do
		local item = Catalog.get(id)
		if item then
			local color = Catalog.Rarities[item.rarity].color:ToHex()
			table.insert(lines, `<font color="#{color}">{item.name}</font> ({item.kind})`)
		end
	end
	return lines
end

-- Small text that floats up from under the coin counter and fades.
local function float(text: string)
	local label = Ui.label(floatAnchor, text, 20)
	Ui.outlined(label)
	label.Size = UDim2.new(1, 0, 0, 26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.fromOffset(0, 0)
	local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.fromOffset(0, 46), TextTransparency = 1 })
		:Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
	task.delay(2.3, function()
		label:Destroy()
	end)
end

-- Big popups one at a time.
local function enqueue(show: () -> ())
	table.insert(queue, show)
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		while #queue > 0 do
			table.remove(queue, 1)()
		end
		showing = false
	end)
end

-- A centered card: title, lines, held for `seconds`. Yields while it shows.
local function card(title: string, lines: { string }, color: Color3, seconds: number)
	local frame = Ui.frame(gui, Ui.Colors.Panel, 18)
	Ui.stroke(frame, color, 4)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.38)
	frame.Size = UDim2.fromOffset(380, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	Ui.padding(frame, 16)
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local heading = Ui.label(frame, title, 38, color, Ui.BigFont)
	heading.Size = UDim2.new(1, 0, 0, 44)
	Ui.outlined(heading, 3)
	for i, line in lines do
		local l = Ui.label(frame, line, 20)
		l.LayoutOrder = i
		l.Size = UDim2.new(1, 0, 0, 24)
		l.TextWrapped = true
	end
	Ui.popIn(frame)
	task.wait(seconds)
	local fade = TweenInfo.new(0.25)
	for _, child in frame:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, fade, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
	task.wait(0.3)
	frame:Destroy()
end

-- A crate opening: cards scroll past a marker and stop on the prize. Yields while it shows.
local function crateReel(prize: Catalog.Item, duplicate: boolean, refund: number)
	local width = ItemCard.Width + 10
	local count, stopAt = 26, 22
	local frame = Ui.frame(gui, Ui.Colors.Panel, 18)
	Ui.stroke(frame, Catalog.Rarities[prize.rarity].color, 4)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromOffset(560, ItemCard.Height + 90)
	local window = Instance.new("Frame")
	window.BackgroundTransparency = 1
	window.ClipsDescendants = true
	window.Position = UDim2.fromOffset(10, 14)
	window.Size = UDim2.new(1, -20, 0, ItemCard.Height + 6)
	window.Parent = frame
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(width * count, ItemCard.Height)
	strip.Position = UDim2.fromOffset(0, 3)
	strip.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	local pool = {}
	for _, item in Catalog.Items do
		if item.crate then
			table.insert(pool, item)
		end
	end
	for i = 1, count do
		local item = if i == stopAt then prize else pool[math.random(#pool)]
		local reelCard = ItemCard.make(strip, item)
		reelCard.LayoutOrder = i
	end
	local marker = Ui.frame(frame, Ui.Colors.Coin, 2)
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.new(0.5, 0, 0, 6)
	marker.Size = UDim2.fromOffset(4, ItemCard.Height + 22)
	marker.ZIndex = 5
	local result = Ui.label(frame, "", 24, Ui.Colors.Text, Ui.BigFont)
	result.Position = UDim2.new(0, 0, 1, -54)
	result.Size = UDim2.new(1, 0, 0, 44)
	Ui.outlined(result, 2)
	Ui.popIn(frame, 0.25)
	-- Scroll so the prize card ends centred under the marker.
	local windowWidth = 540
	local target = -((stopAt - 1) * width + ItemCard.Width / 2 - windowWidth / 2)
	local spin = TweenInfo.new(3.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(strip, spin, { Position = UDim2.fromOffset(target, 3) }):Play()
	task.wait(3.3)
	local color = Catalog.Rarities[prize.rarity].color:ToHex()
	result.Text = if duplicate
		then `Duplicate <font color="#{color}">{prize.name}</font>  +{Ui.number(refund)} coins`
		else `You got <font color="#{color}">{prize.name}</font>!`
	Ui.popIn(result, 0.3)
	task.wait(2)
	frame:Destroy()
end

function Popups.show(payload: { [string]: any })
	local kind = payload.Kind
	if kind == "Earned" then
		local reason = REASONS[payload.Reason] or payload.Reason or ""
		float(`{amounts(payload.Coins, payload.XP)}  <font color="#DDDDDD">{reason}</font>`)
	elseif kind == "LevelUp" then
		enqueue(function()
			local lines = { amounts(payload.Coins, nil) }
			if payload.Crates and payload.Crates > 0 then
				table.insert(lines, `<font color="#FF8C3C">+{payload.Crates} free crate</font>`)
			end
			for _, line in itemLines(payload.Items) do
				table.insert(lines, `Unlocked: {line}`)
			end
			card(`LEVEL {payload.Level}!`, lines, Ui.Colors.XP, 2.6)
		end)
	elseif kind == "Crate" then
		local prize = Catalog.get(payload.Item)
		if prize then
			enqueue(function()
				crateReel(prize :: Catalog.Item, payload.Duplicate == true, payload.Refund or 0)
			end)
		end
	elseif kind == "Grant" then
		enqueue(function()
			local lines = {}
			local money = amounts(payload.Coins, payload.XP)
			if money ~= "" then
				table.insert(lines, money)
			end
			if payload.Crates and payload.Crates > 0 then
				table.insert(lines, `<font color="#FF8C3C">+{payload.Crates} crate</font>`)
			end
			for _, line in itemLines(payload.Items) do
				table.insert(lines, `New: {line}`)
			end
			if #lines > 0 then
				card(payload.Reason or "Reward!", lines, Ui.Colors.Coin, 2.2)
			end
		end)
	end
end

function Popups.start(screen: ScreenGui, anchor: Frame)
	gui = screen
	floatAnchor = anchor
end

return Popups
