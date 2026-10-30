--!strict
-- Popups (Street sprint style), from the Reward remote (server/Progression, server/Shop) and the
-- Announce remote:
--   Earned:  "+15 COINS  +20 XP  ROUND SURVIVED" floating up beside your coins.
--   Grant:   a small card listing what a quest, streak, achievement or purchase gave you.
--   LevelUp: a cyan stripe across the screen, "LEVEL 5!", and what came with it.
--   Crate:   the crate opening: a reel of cards spins and stops on the best thing you got, then
--            lists the rest.
--   Announce (Unbox): a holo stripe for everyone when someone opens an Iridescent item.
-- Big popups take turns. They are built in the menu's scaled root frame (Ui.scale), so sizes
-- are virtual pixels; widths follow the screen (Ui.viewport) so nothing runs off a narrow one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Cursor = require(script.Parent.Parent.Cursor)
local ItemCard = require(script.Parent.ItemCard)
local Ui = require(script.Parent.Ui)

local Popups = {}

local gui: GuiObject
local floatAnchor: Frame
local queue: { () -> () } = {}
local showing = false

local TOP = 50 -- popups sit above the menu window
local CARD_WIDTH = 380 -- the reward card (narrower on a narrow screen)
local REEL_WIDTH = 600 -- the crate window (ditto)
local SHOWN_EXTRA = 5 -- other items named under the prize (the rest are counted)
local REASONS = {
	GamePlayed = "Game played",
	RoundSurvived = "Round survived",
	Tag = "Tag!",
	Win = "Victory!",
	PlayMinute = "Playing",
}

local function hex(color: Color3): string
	return color:ToHex()
end

-- "+15 COINS  +20 XP" in their colors.
local function amounts(coins: number?, xp: number?): string
	local parts = {}
	if coins and coins > 0 then
		table.insert(
			parts,
			`<font color="#{hex(Ui.Colors.Yellow)}">+{Ui.number(coins)} COINS</font>`
		)
	end
	if xp and xp > 0 then
		table.insert(parts, `<font color="#{hex(Ui.Colors.Cyan)}">+{Ui.number(xp)} XP</font>`)
	end
	return table.concat(parts, "   ")
end

local function itemLine(id: string, prefix: string?): string?
	local item = Catalog.get(id)
	if not item then
		return nil
	end
	local color = hex(Catalog.Rarities[item.rarity].color)
	return `{prefix or ""}<font color="#{color}">{Ui.upper(item.name)}</font> <font color="#{hex(
		Ui.Colors.Dim
	)}">{Ui.upper(Catalog.KindSingular[item.kind] or "")}</font>`
end

-- Puts something above everything else in the menu.
local function onTop(object: GuiObject)
	object.ZIndex = TOP
end

-- Text that floats up from beside your coins and fades.
local function float(text: string)
	local label = Ui.caps(floatAnchor, text, 18, Ui.Colors.Text)
	label.Size = UDim2.new(1, 0, 0, 26)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(label, 10, 18) -- long lines shrink instead of leaving the screen
	local stroke = Ui.stroke(label, 2)
	local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.fromOffset(0, -50), TextTransparency = 1 })
		:Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
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
	Cursor.hold("Popups", true) -- the mouse stays free while popups are up
	task.spawn(function()
		while #queue > 0 do
			table.remove(queue, 1)()
		end
		showing = false
		Cursor.hold("Popups", false)
	end)
end

-- Shrinks something away and destroys it.
local function dismiss(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		):Play()
	end
	task.wait(0.2)
	object:Destroy()
end

-- A small card: a header bar in `color` with the title, the lines under it. Yields while shown.
local function card(title: string, lines: { string }, color: Color3, seconds: number)
	local panel = Ui.panel(gui, Ui.Colors.Panel, 12)
	onTop(panel)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 110)
	panel.Size = UDim2.fromOffset(math.min(CARD_WIDTH, Ui.viewport().X - 24), 58 + #lines * 26)
	local header = Ui.slab(panel, color, 10)
	header.Size = UDim2.new(1, -20, 0, 40)
	local titleLabel = Ui.title(header, title, 28, Ui.Colors.Ink)
	titleLabel.Size = UDim2.fromScale(1, 1)
	Ui.pad(titleLabel, 18, 2) -- (clear of the header's slanted ends)
	Ui.shrinkText(titleLabel, 14, 28)
	for i, line in lines do
		local l = Ui.caps(panel, line, 15, Ui.Colors.Text)
		l.Position = UDim2.fromOffset(16, 44 + (i - 1) * 26)
		l.Size = UDim2.new(1, -32, 0, 24)
		Ui.shrinkText(l, 11, 15) -- one line each; a long item name gets smaller
	end
	Ui.popIn(panel)
	task.wait(seconds)
	dismiss(panel)
end

-- A stripe right across the screen with big text, tilted a little. Yields while shown.
local function stripe(
	text: string,
	color: Color3,
	textColor: Color3,
	seconds: number,
	holo: boolean?
)
	local band = Ui.frame(gui, color)
	onTop(band)
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.32)
	band.Size = UDim2.new(1.3, 0, 0, 74)
	band.Rotation = -3
	if holo then
		band.BackgroundColor3 = Color3.new(1, 1, 1)
		Ui.holo(band)
	end
	for _, edge in { 0, 1 } do
		local line = Ui.frame(band, Ui.Colors.Ink)
		line.AnchorPoint = Vector2.new(0, edge)
		line.Position = UDim2.fromScale(0, edge)
		line.Size = UDim2.new(1, 0, 0, 5)
	end
	-- The band is 1.3 screens wide, so the text keeps to the middle 0.72 of it (the visible
	-- part is 1 / 1.3 = 0.77) and shrinks if it's long.
	local shadow = Ui.title(band, text, 52, Ui.Colors.Pink)
	shadow.AnchorPoint = Vector2.new(0.5, 0)
	shadow.Position = UDim2.new(0.5, 4, 0, 4)
	shadow.Size = UDim2.new(0.72, 0, 1, -8)
	Ui.shrinkText(shadow, 14, 52)
	local label = Ui.title(band, text, 52, textColor)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Size = UDim2.new(0.72, 0, 1, -8)
	Ui.shrinkText(label, 14, 52)
	local scale = Instance.new("UIScale")
	scale.Parent = band
	Ui.popIn(band, 0.25)
	task.wait(seconds)
	dismiss(band)
end

-- The crate opening: a reel spins past a marker and stops on the best item, then the rest are
-- listed. Yields while it shows.
local function crateReel(results: { { [string]: any } })
	local best: Catalog.Item? = nil
	local bestResult: { [string]: any }? = nil
	for _, result in results do
		local item = Catalog.get(result.Item)
		if
			item
			and (
				not best
				or Catalog.Rarities[item.rarity].order > Catalog.Rarities[best.rarity].order
			)
		then
			best = item
			bestResult = result
		end
	end
	if not best or not bestResult then
		return
	end
	local prize = best :: Catalog.Item
	local width, height = 128, 170
	local count, stopAt = 26, 22
	local window, body, close = Ui.window(gui, "Mystery crate", Ui.Colors.Yellow, "crate")
	onTop(window)
	close.Visible = false
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.45)
	local windowWidth = math.min(REEL_WIDTH, Ui.viewport().X - 24)
	window.Size = UDim2.fromOffset(windowWidth, height + 196)
	local view = Ui.frame(body)
	view.ClipsDescendants = true
	view.Size = UDim2.new(1, 0, 0, height + 10)
	local strip = Ui.frame(view)
	strip.Size = UDim2.fromOffset((width + 10) * count, height)
	strip.Position = UDim2.fromOffset(0, 5)
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
		local reelCard = ItemCard.reel(strip, item, width, height)
		reelCard.LayoutOrder = i
	end
	local marker = Ui.frame(body, Ui.Colors.Yellow)
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Position = UDim2.new(0.5, 0, 0, -4)
	marker.Size = UDim2.fromOffset(5, height + 18)
	marker.ZIndex = 5
	local result = Ui.caps(body, "", 20, Ui.Colors.Text)
	result.Position = UDim2.fromOffset(0, height + 16)
	result.Size = UDim2.new(1, 0, 0, 32)
	Ui.shrinkText(result, 11, 20) -- a long name and serial number shrink to the window
	local rest = Ui.caps(body, "", 12, Ui.Colors.Dim)
	rest.Position = UDim2.fromOffset(0, height + 52)
	rest.Size = UDim2.new(1, 0, 0, 56)
	rest.TextWrapped = true
	rest.TextTruncate = Enum.TextTruncate.AtEnd
	rest.TextYAlignment = Enum.TextYAlignment.Top
	Ui.popIn(window, 0.25)

	-- Scroll so the prize card ends up centred under the marker.
	local viewWidth = windowWidth - 32 -- the window's body (Ui.window: 16 each side)
	local target = -((stopAt - 1) * (width + 10) + width / 2 - viewWidth / 2)
	local spin = TweenInfo.new(3.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(strip, spin, { Position = UDim2.fromOffset(target, 5) }):Play()
	task.wait(3.3)
	local color = hex(Catalog.Rarities[prize.rarity].color)
	local label = `<font color="#{color}">{Ui.upper(prize.name)}</font>`
	result.Text = if bestResult.Duplicate
		then `{label} <font color="#{hex(Ui.Colors.Dim)}">(DUPLICATE)</font>`
		elseif bestResult.Serial then `YOU GOT {label} NO. {bestResult.Serial}!`
		else `YOU GOT {label}!`
	Ui.popIn(result, 0.3)
	if #results > 1 then
		local others = {}
		local more = 0
		for _, other in results do
			if other ~= bestResult then
				local line = itemLine(other.Item)
				if line and #others < SHOWN_EXTRA then
					table.insert(others, line .. (if other.Duplicate then " (DUP)" else ""))
				elseif line then
					more += 1
				end
			end
		end
		rest.Text = "ALSO: "
			.. table.concat(others, "  ·  ")
			.. (if more > 0 then `  ·  +{more} MORE` else "")
	end
	task.wait(if #results > 1 then 3 else 2)
	dismiss(window)
end

function Popups.show(payload: { [string]: any })
	local kind = payload.Kind
	if kind == "Earned" then
		local reason = REASONS[payload.Reason] or payload.Reason or ""
		float(
			`{amounts(payload.Coins, payload.XP)}  <font color="#DDDDDD">{Ui.upper(reason)}</font>`
		)
	elseif kind == "LevelUp" then
		enqueue(function()
			stripe(`LEVEL {payload.Level}!`, Ui.Colors.Cyan, Ui.Colors.Ink, 1.6)
			local lines = { amounts(payload.Coins, nil) }
			if payload.Crates and payload.Crates > 0 then
				table.insert(
					lines,
					`<font color="#{hex(Ui.Colors.Lime)}">+{payload.Crates} FREE CRATE</font>`
				)
			end
			for _, id in payload.Items or {} do
				local line = itemLine(id, "UNLOCKED: ")
				if line then
					table.insert(lines, line)
				end
			end
			card("Level up!", lines, Ui.Colors.Cyan, 2.2)
		end)
	elseif kind == "Crate" then
		local results = payload.Items
		if type(results) == "table" and #results > 0 then
			enqueue(function()
				crateReel(results)
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
				table.insert(
					lines,
					`<font color="#{hex(Ui.Colors.Lime)}">+{payload.Crates} CRATE</font>`
				)
			end
			for _, id in payload.Items or {} do
				local line = itemLine(id, "NEW: ")
				if line then
					table.insert(lines, line)
				end
			end
			if #lines > 0 then
				card(payload.Reason or "Reward!", lines, Ui.Colors.Lime, 2.2)
			end
		end)
	end
end

-- Server-wide news (the Announce remote): an Iridescent unboxing.
function Popups.announce(payload: { [string]: any })
	if type(payload) ~= "table" or payload.Kind ~= "Unbox" then
		return
	end
	local item = Catalog.get(payload.Item)
	if not item then
		return
	end
	enqueue(function()
		local serial = if payload.Serial then ` NO. {payload.Serial}` else ""
		stripe(
			`{Ui.upper(payload.Name or "Someone")} UNBOXED {Ui.upper(item.name)}{serial}!`,
			Ui.Colors.Pink,
			Ui.Colors.Ink,
			3.5,
			true
		)
	end)
end

function Popups.start(screen: GuiObject, anchor: Frame)
	gui = screen
	floatAnchor = anchor
end

return Popups
