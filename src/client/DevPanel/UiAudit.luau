--!strict
-- The UI auditor (dev panel, Debug tab). It looks at every visible piece of text on screen and
-- prints, one line per problem, what is wrong with it, so layouts can be checked at any window
-- size without looking at each screen:
--   FIT      the text is bigger than its own label (spills out, or a wrapped text is taller than
--            its box), also when the label is set to shrink and is already at its smallest.
--   CUT      the label cuts the text off ("..." or lost lines); says how much is lost.
--   PAD      the text is closer than Config.Ui.MinPadding (sideways) / MinPaddingY (above and
--            below) to the edge of the box it sits on, or sticks out past it. The box is the
--            nearest thing behind the text with a visible fill: a Frame with a background, a
--            Ui.slab / Ui.panel (several pieces, slanted ends and cut corners are followed), a
--            filled child that covers its parent (a button's Fill), or a bordered frame.
--   SMALL    the text is drawn smaller than Config.Ui.MinTextSize on screen (after every UIScale),
--            or MinTouchTextSize when the touch rule is on.
--   OVERLAP  two texts on the same box draw over each other.
--   OFFSCREEN the text is partly or wholly off the screen.
-- Everything is measured in real pixels at the current window size. Run it, resize the window,
-- run it again. `scan()` checks what is on screen now; `sweep()` opens every menu page (with
-- both a broke and a rich fake profile) and tab, then the popups, banners, toast, spectate bar,
-- results card and win screen with the longest realistic content, scanning each. The dev panel's
-- own window and the auditor's overlay are never checked. Never touches the server.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Hud = require(script.Parent.Parent.Hud)
local LeadersTab = require(script.Parent.Parent.Menu.LeadersTab)
local Menu = require(script.Parent.Parent.Menu)
local Notify = require(script.Parent.Parent.Notify)
local Popups = require(script.Parent.Parent.Menu.Popups)
local Profile = require(script.Parent.Parent.Profile)
local RoundResults = require(script.Parent.Parent.RoundResults)
local Ui = require(script.Parent.Parent.Menu.Ui)
local WinScreen = require(script.Parent.Parent.WinScreen)

local UiAudit = {}

local TAG = "[UiAudit]"
local OVERLAY = "UiAuditOverlay"
local PROBE = "UiAuditProbe"
local SKIP_GUIS: { [string]: boolean } = { DevPanel = true, [OVERLAY] = true, [PROBE] = true }
local MAX_LINES = 400 -- problems printed per scan (the summary still counts them all)
local MAX_OUTLINES = 250
local LONG_NAME = "WWWWWWWWWWWWWWWWWWWW" -- 20 of the widest capital
local RED = Color3.fromRGB(255, 40, 40)

type Rect = { x1: number, y1: number, x2: number, y2: number }
type Problem = {
	kind: string,
	path: string,
	text: string,
	detail: string,
	rect: Rect, -- in its gui's absolute coordinates
	gui: ScreenGui,
}
type Calibration = {
	absScaled: boolean, -- AbsoluteSize includes UIScale (real pixels)
	boundsScaled: boolean, -- TextBounds includes UIScale
	lineRatio: { [string]: number }, -- TextBounds.Y / TextSize per font
	fix: { normal: Vector2, ignore: Vector2 }, -- add to AbsolutePosition for screen coordinates
}
type Box = {
	inst: GuiObject,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	leftAt: (number) -> number,
	rightAt: (number) -> number,
}
type Item = { label: GuiObject, gui: ScreenGui, rect: Rect, text: string, box: Instance? }

local options = {
	outline = false,
	touchRule = UserInputService.TouchEnabled,
}
local running = false
local calibration: Calibration? = nil

function UiAudit.setOutline(on: boolean)
	options.outline = on
	if not on then
		UiAudit.clearOutlines()
	end
end

function UiAudit.setTouchRule(on: boolean)
	options.touchRule = on
end

function UiAudit.touchRuleDefault(): boolean
	return options.touchRule
end

function UiAudit.isRunning(): boolean
	return running
end

local function playerGui(): PlayerGui?
	return Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

-- Outlines --------------------------------------------------------------------------------

function UiAudit.clearOutlines()
	local gui = playerGui()
	local overlay = gui and gui:FindFirstChild(OVERLAY)
	if overlay then
		overlay:Destroy()
	end
end

local function drawOutlines(problems: { Problem }, cal: Calibration)
	local gui = playerGui()
	if not gui then
		return
	end
	local overlay = gui:FindFirstChild(OVERLAY) :: ScreenGui?
	if not overlay then
		local made = Instance.new("ScreenGui")
		made.Name = OVERLAY
		made.ResetOnSpawn = false
		made.IgnoreGuiInset = true
		made.DisplayOrder = 2000
		made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		made.Parent = gui
		overlay = made
	end
	local shown = #(overlay :: ScreenGui):GetChildren()
	for _, problem in problems do
		if shown >= MAX_OUTLINES then
			break
		end
		shown += 1
		local shift = if problem.gui.IgnoreGuiInset then cal.fix.ignore else cal.fix.normal
		local frame = Instance.new("Frame")
		frame.Name = problem.kind
		frame.BackgroundTransparency = 1
		frame.Active = false
		frame.Position =
			UDim2.fromOffset(problem.rect.x1 + shift.X - 2, problem.rect.y1 + shift.Y - 2)
		frame.Size = UDim2.fromOffset(
			math.max(4, problem.rect.x2 - problem.rect.x1 + 4),
			math.max(4, problem.rect.y2 - problem.rect.y1 + 4)
		)
		local stroke = Instance.new("UIStroke")
		stroke.Color = RED
		stroke.Thickness = 2
		stroke.Parent = frame
		local tag = Instance.new("TextLabel")
		tag.BackgroundColor3 = RED
		tag.BackgroundTransparency = 0
		tag.AnchorPoint = Vector2.new(0, 1)
		tag.Position = UDim2.fromScale(0, 0)
		tag.Size = UDim2.fromOffset(0, 12)
		tag.AutomaticSize = Enum.AutomaticSize.X
		tag.Font = Enum.Font.SourceSansBold
		tag.TextSize = 11
		tag.TextColor3 = Color3.new(1, 1, 1)
		tag.Text = problem.kind
		tag.Parent = frame
		frame.Parent = overlay
	end
end

-- Calibration -----------------------------------------------------------------------------
-- A few throwaway labels tell, on this machine, how Roblox reports sizes under a UIScale and
-- how tall a line of each font is, so the numbers below are right without guessing.

local function fontKey(font: Font): string
	return `{font.Family}/{font.Weight.Name}`
end

local function calibrate(): Calibration
	local gui = playerGui()
	local cal: Calibration = {
		absScaled = true,
		boundsScaled = false,
		lineRatio = {},
		fix = { normal = Vector2.zero, ignore = Vector2.zero },
	}
	if not gui then
		return cal
	end
	local probe = Instance.new("ScreenGui")
	probe.Name = PROBE
	probe.ResetOnSpawn = false
	probe.DisplayOrder = -100
	local ignore = Instance.new("ScreenGui")
	ignore.Name = PROBE
	ignore.ResetOnSpawn = false
	ignore.IgnoreGuiInset = true
	ignore.DisplayOrder = -100

	local function sample(parent: Instance, scale: number, font: Font, y: number): TextLabel
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(0, y)
		holder.Size = UDim2.fromOffset(300, 40)
		local us = Instance.new("UIScale")
		us.Scale = scale
		us.Parent = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, 0)
		label.Size = UDim2.fromOffset(300, 40)
		label.FontFace = font
		label.TextSize = 20
		label.TextWrapped = false
		label.Text = "Hello Audit"
		label.Parent = holder
		holder.Parent = parent
		return label
	end
	local plain = sample(probe, 1, Ui.Bold, 0)
	local doubled = sample(probe, 2, Ui.Bold, 50)
	local heavy = sample(probe, 1, Ui.Heavy, 140)
	local display = sample(probe, 1, Ui.Display, 190)
	local corner = Instance.new("Frame")
	corner.Size = UDim2.fromOffset(10, 10)
	corner.Parent = probe
	local corner2 = Instance.new("Frame")
	corner2.Size = UDim2.fromOffset(10, 10)
	corner2.Parent = ignore
	probe.Parent = gui
	ignore.Parent = gui
	local waited = 0
	repeat
		waited += RunService.Heartbeat:Wait()
	until (plain.TextBounds.X > 0 and doubled.TextBounds.X > 0 and display.TextBounds.X > 0)
		or waited > 1.5
	RunService.Heartbeat:Wait()
	cal.absScaled = doubled.AbsoluteSize.X > plain.AbsoluteSize.X * 1.5
	cal.boundsScaled = doubled.TextBounds.X > plain.TextBounds.X * 1.5
	for _, pair in { { Ui.Bold, plain }, { Ui.Heavy, heavy }, { Ui.Display, display } } do
		local font, label = pair[1] :: Font, pair[2] :: TextLabel
		if label.TextBounds.Y > 0 then
			cal.lineRatio[fontKey(font)] = label.TextBounds.Y / 20
		end
	end
	local insetTopLeft = GuiService:GetGuiInset()
	cal.fix = {
		normal = insetTopLeft - corner.AbsolutePosition,
		ignore = Vector2.zero - corner2.AbsolutePosition,
	}
	probe:Destroy()
	ignore:Destroy()
	return cal
end

-- Geometry --------------------------------------------------------------------------------

local function scaleOf(obj: Instance): number
	local k = 1
	local node: Instance? = obj
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") then
			local us = node:FindFirstChildOfClass("UIScale")
			if us then
				k *= us.Scale
			end
		end
		node = node.Parent
	end
	return k
end

local function rectOf(obj: GuiObject): Rect
	local p, s = obj.AbsolutePosition, obj.AbsoluteSize
	return { x1 = p.X, y1 = p.Y, x2 = p.X + s.X, y2 = p.Y + s.Y }
end

local function intersect(a: Rect, b: Rect): Rect?
	local r = {
		x1 = math.max(a.x1, b.x1),
		y1 = math.max(a.y1, b.y1),
		x2 = math.min(a.x2, b.x2),
		y2 = math.min(a.y2, b.y2),
	}
	if r.x2 > r.x1 and r.y2 > r.y1 then
		return r
	end
	return nil
end

local function pathOf(obj: Instance): string
	local name = obj:GetFullName()
	local prefix = `{Players.LocalPlayer.Name}.PlayerGui.`
	local at = string.find(name, prefix, 1, true)
	if at then
		name = string.sub(name, at + #prefix)
	end
	return name
end

-- Whether it and everything above it is shown; returns its ScreenGui.
local function shownIn(obj: GuiObject): ScreenGui?
	local node: Instance? = obj
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return nil
		end
		if node:IsA("CanvasGroup") and node.GroupTransparency >= 0.99 then
			return nil
		end
		if node:IsA("ScreenGui") then
			return if node.Enabled then node else nil
		end
		node = node.Parent
	end
	return nil
end

-- The clip rectangles above an object (scroll lists and clipping frames).
local function clippedAway(obj: GuiObject, rect: Rect): boolean
	local node: Instance? = obj.Parent
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and (node.ClipsDescendants or node:IsA("ScrollingFrame")) then
			if not intersect(rect, rectOf(node)) then
				return true
			end
		end
		node = node.Parent
	end
	return false
end

-- Boxes -----------------------------------------------------------------------------------

local function fillVisible(obj: GuiObject): boolean
	return obj.BackgroundTransparency < 0.9
end

local function slabParts(obj: GuiObject): { [string]: Frame }
	local parts: { [string]: Frame } = {}
	for _, child in obj:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 4) == "Slab" then
			parts[child.Name] = child
		end
	end
	return parts
end

-- The box a Ui.slab / Ui.panel makes of `obj` (or any plain filled frame), or nil.
local function boxOf(obj: GuiObject): Box?
	local r = rectOf(obj)
	local function plain(): Box
		return {
			inst = obj,
			x1 = r.x1,
			y1 = r.y1,
			x2 = r.x2,
			y2 = r.y2,
			leftAt = function(_y: number)
				return r.x1
			end,
			rightAt = function(_y: number)
				return r.x2
			end,
		}
	end
	local parts = slabParts(obj)
	if parts.SlabMid then
		if parts.SlabMid.BackgroundTransparency >= 0.9 then
			return nil
		end
		local height = math.max(r.y2 - r.y1, 1)
		if parts.SlabLeft and parts.SlabRight then
			-- A slanted bar: the top edge leans right of the bottom (or left, for a negative slant).
			local w = parts.SlabLeft.AbsoluteSize.X
			local cut = parts.SlabLeft:FindFirstChildOfClass("UIGradient")
			local lean = if cut and cut.Rotation < 0 then -1 else 1
			local box = plain()
			box.leftAt = function(y: number)
				local f = math.clamp((y - r.y1) / height, 0, 1)
				return r.x1 + w * (if lean > 0 then 1 - f else f)
			end
			box.rightAt = function(y: number)
				local f = math.clamp((y - r.y1) / height, 0, 1)
				return r.x2 - w * (if lean > 0 then f else 1 - f)
			end
			return box
		elseif parts.SlabTopRight and parts.SlabBottomLeft then
			-- A panel: the top-right and bottom-left corners are cut off.
			local c = parts.SlabTopRight.AbsoluteSize.X
			local box = plain()
			box.rightAt = function(y: number)
				return r.x2 - math.max(0, c - (y - r.y1))
			end
			box.leftAt = function(y: number)
				return r.x1 + math.max(0, c - (r.y2 - y))
			end
			return box
		end
		return plain()
	end
	if
		(obj:IsA("Frame") or obj:IsA("ImageLabel") or obj:IsA("ScrollingFrame"))
		and fillVisible(obj)
		and not obj:IsA("CanvasGroup")
	then
		return plain()
	end
	if obj:IsA("Frame") or obj:IsA("ImageLabel") then
		local stroke = obj:FindFirstChildOfClass("UIStroke")
		if stroke and stroke.Enabled and stroke.Thickness > 0 and stroke.Transparency < 0.9 then
			return plain()
		end
	end
	-- A filled child that covers the object is its background (a button's Fill, a tile's back).
	local size = obj.AbsoluteSize
	local best: Box? = nil
	local bestZ = -math.huge
	for _, child in obj:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			local cs = child.AbsoluteSize
			if
				cs.X >= size.X * 0.97
				and cs.Y >= size.Y * 0.97
				and size.X > 0
				and (slabParts(child).SlabMid ~= nil or fillVisible(child))
				and child.ZIndex >= bestZ -- (the one on top: a shadow sits under its bar)
			then
				local inner = boxOf(child)
				if inner then
					best = inner
					bestZ = child.ZIndex
				end
			end
		end
	end
	return best
end

-- The nearest box behind a label: its own fill, else the first filled thing above it that the
-- label's middle lies inside.
local function boxFor(label: GuiObject, textRect: Rect): Box?
	if label:IsA("GuiObject") and fillVisible(label) then
		local r = rectOf(label)
		return {
			inst = label,
			x1 = r.x1,
			y1 = r.y1,
			x2 = r.x2,
			y2 = r.y2,
			leftAt = function(_y: number)
				return r.x1
			end,
			rightAt = function(_y: number)
				return r.x2
			end,
		}
	end
	local cx, cy = (textRect.x1 + textRect.x2) / 2, (textRect.y1 + textRect.y2) / 2
	local node: Instance? = label.Parent
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") then
			local box = boxOf(node)
			if box then
				if cx >= box.x1 and cx <= box.x2 and cy >= box.y1 and cy <= box.y2 then
					return box
				end
				return nil -- the label sits outside the nearest box (a float, a hanging badge)
			end
		end
		node = node.Parent
	end
	return nil
end

-- Text ------------------------------------------------------------------------------------

local function naturalBounds(label: TextLabel, size: number, width: number): Vector2?
	local ok, result = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Font = label.FontFace
		params.Size = size
		params.Width = width
		local rich = false
		if label.RichText then
			rich = pcall(function()
				(params :: any).RichText = true
			end)
		end
		params.Text = if label.RichText and not rich then label.ContentText else label.Text
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok then
		return result :: Vector2
	end
	return nil
end

local function num(n: number): string
	return string.format("%.0f", n)
end

local function describe(label: GuiObject): string
	local text = (label :: any).ContentText :: string
	text = string.gsub(text, "[\n\r]+", " ")
	if #text > 44 then
		text = string.sub(text, 1, 41) .. "..."
	end
	return text
end

-- Checks one label; adds problems and returns its Item for the overlap check.
local function inspect(
	label: GuiObject,
	gui: ScreenGui,
	cal: Calibration,
	touchRule: boolean,
	screen: Rect,
	problems: { Problem }
): Item?
	local text = describe(label)
	local l = label :: any
	if l.ContentText == "" or l.TextTransparency >= 0.99 then
		return nil
	end
	local abs = label.AbsoluteSize
	if abs.X <= 0 or abs.Y <= 0 then
		return nil
	end
	local k = scaleOf(label)
	local localSize = if cal.absScaled then abs / k else abs
	local boundsLocal = if cal.boundsScaled then l.TextBounds / k else l.TextBounds :: Vector2
	if boundsLocal.X <= 0 or boundsLocal.Y <= 0 then
		return nil
	end
	local pad = label:FindFirstChildOfClass("UIPadding")
	local padL, padR, padT, padB = 0, 0, 0, 0
	if pad then
		padL = pad.PaddingLeft.Scale * localSize.X + pad.PaddingLeft.Offset
		padR = pad.PaddingRight.Scale * localSize.X + pad.PaddingRight.Offset
		padT = pad.PaddingTop.Scale * localSize.Y + pad.PaddingTop.Offset
		padB = pad.PaddingBottom.Scale * localSize.Y + pad.PaddingBottom.Offset
	end
	local areaW, areaH = localSize.X - padL - padR, localSize.Y - padT - padB
	local pos = label.AbsolutePosition

	-- Where the text is actually drawn (real pixels, in the gui's coordinates).
	local bw, bh = boundsLocal.X * k, boundsLocal.Y * k
	local ax, ay = pos.X + padL * k, pos.Y + padT * k
	local aw, ah = areaW * k, areaH * k
	local xa, ya = l.TextXAlignment, l.TextYAlignment
	local tx = if xa == Enum.TextXAlignment.Left
		then ax
		elseif xa == Enum.TextXAlignment.Center then ax + (aw - bw) / 2
		else ax + aw - bw
	local ty = if ya == Enum.TextYAlignment.Top
		then ay
		elseif ya == Enum.TextYAlignment.Center then ay + (ah - bh) / 2
		else ay + ah - bh
	local rect: Rect = { x1 = tx, y1 = ty, x2 = tx + bw, y2 = ty + bh }
	local labelRect = rectOf(label)
	if clippedAway(label, rect) then
		return nil
	end
	local path = pathOf(label)
	local function report(kind: string, detail: string, at: Rect?)
		table.insert(problems, {
			kind = kind,
			path = path,
			text = text,
			detail = detail,
			rect = at or rect,
			gui = gui,
		})
	end

	-- FIT / CUT ---------------------------------------------------------------------------
	local auto = label.AutomaticSize
	local autoX = auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY
	local autoY = auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY
	local ratio = cal.lineRatio[fontKey(l.FontFace)] or 1.2
	local scaled = l.TextScaled == true
	local drawn = if scaled then boundsLocal.Y / ratio else l.TextSize :: number
	local overX = if autoX then 0 else boundsLocal.X - areaW
	local overY = if autoY then 0 else boundsLocal.Y - areaH
	if overX > 0.75 or overY > 0.75 then
		report(
			"FIT",
			`text {num(bw)}x{num(bh)} px in a box {num(aw)}x{num(ah)} px`
				.. (if overX > 0.75 then `, {num(overX * k)} px too wide` else "")
				.. (if overY > 0.75 then `, {num(overY * k)} px too tall` else "")
				.. (if scaled then " (already at its smallest size)" else ""),
			labelRect
		)
	elseif l.TextTruncate ~= Enum.TextTruncate.None then
		local wrapped = l.TextWrapped == true
		local full =
			naturalBounds(l, math.max(drawn, 1), if wrapped then math.max(areaW, 1) else 100000)
		if full then
			-- (a shrink-to-fit label's size is only estimated from its height, so allow a few
			-- percent before calling it cut)
			local slack = if scaled then 0.06 else 0
			local lostX = if wrapped or autoX then 0 else full.X - areaW * (1 + slack)
			local lostY = if wrapped and not autoY then full.Y - areaH * (1 + slack) else 0
			if lostX > 1.5 or lostY > 1.5 then
				local lost = if lostX > 1.5 then lostX / full.X else lostY / full.Y
				report(
					"CUT",
					`natural text {num(full.X * k)}x{num(full.Y * k)} px, box {num(aw)}x{num(ah)} px: about {num(
						lost * 100
					)}% is cut off ("...")`,
					labelRect
				)
			end
		end
	elseif scaled and l.TextWrapped ~= true then
		local fits = true
		pcall(function()
			fits = l.TextFits
		end)
		if not fits then
			report("FIT", "label says its text does not fit even at its smallest size", labelRect)
		end
	end

	-- SMALL -------------------------------------------------------------------------------
	local px = drawn * k
	local least = if touchRule then Config.Ui.MinTouchTextSize else Config.Ui.MinTextSize
	if px < least - 0.05 then
		report(
			"SMALL",
			`drawn about {string.format("%.1f", px)} px high on screen (text size {string.format(
				"%.1f",
				drawn
			)} x UI scale {string.format("%.2f", k)}); least {least}{if touchRule
				then " (touch rule)"
				else ""}`
		)
	end

	-- PAD ---------------------------------------------------------------------------------
	local box = boxFor(label, rect)
	if box then
		local left = rect.x1 - math.max(box.leftAt(rect.y1), box.leftAt(rect.y2))
		local right = math.min(box.rightAt(rect.y1), box.rightAt(rect.y2)) - rect.x2
		local top = rect.y1 - box.y1
		local bottom = box.y2 - rect.y2
		local sides = {}
		local minX, minY = Config.Ui.MinPadding, Config.Ui.MinPaddingY
		if left < minX - 0.05 then
			table.insert(sides, `left {num(left)}`)
		end
		if right < minX - 0.05 then
			table.insert(sides, `right {num(right)}`)
		end
		if top < minY - 0.05 then
			table.insert(sides, `top {num(top)}`)
		end
		if bottom < minY - 0.05 then
			table.insert(sides, `bottom {num(bottom)}`)
		end
		if #sides > 0 and not (overX > 0.75 or overY > 0.75) then
			report(
				"PAD",
				`room to the box edge: {table.concat(sides, ", ")} px (least {minX} sideways, {minY} above/below; box {pathOf(
					box.inst
				)} {num(box.x2 - box.x1)}x{num(box.y2 - box.y1)})`
			)
		elseif #sides > 0 then
			-- (already reported as not fitting)
			local negative = left < 0 or right < 0 or top < 0 or bottom < 0
			if negative then
				report(
					"PAD",
					`sticks out of its box: {table.concat(sides, ", ")} px (box {pathOf(box.inst)})`
				)
			end
		end
	end

	-- OFFSCREEN ---------------------------------------------------------------------------
	local shift = if gui.IgnoreGuiInset then cal.fix.ignore else cal.fix.normal
	local sx1, sy1, sx2, sy2 =
		rect.x1 + shift.X, rect.y1 + shift.Y, rect.x2 + shift.X, rect.y2 + shift.Y
	local outside = {}
	if sx1 < screen.x1 - 1.5 then
		table.insert(outside, `left {num(screen.x1 - sx1)}`)
	end
	if sy1 < screen.y1 - 1.5 then
		table.insert(outside, `top {num(screen.y1 - sy1)}`)
	end
	if sx2 > screen.x2 + 1.5 then
		table.insert(outside, `right {num(sx2 - screen.x2)}`)
	end
	if sy2 > screen.y2 + 1.5 then
		table.insert(outside, `bottom {num(sy2 - screen.y2)}`)
	end
	if #outside > 0 then
		report("OFFSCREEN", `past the screen edge by {table.concat(outside, ", ")} px`)
	end

	return {
		label = label,
		gui = gui,
		rect = rect,
		text = text,
		box = if box then box.inst else gui,
	}
end

-- Scanning --------------------------------------------------------------------------------

type Counts = { [string]: number }

-- Scans every visible text on screen. `context` is printed in front of each line. `seen`
-- remembers problems already printed in this run. Returns the problems found.
local function scanNow(
	context: string,
	seen: { [string]: boolean },
	cal: Calibration
): ({ Problem }, number)
	local gui = playerGui()
	local found: { Problem } = {}
	if not gui then
		return found, 0
	end
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local screen: Rect = { x1 = 0, y1 = 0, x2 = view.X, y2 = view.Y }
	local items: { Item } = {}
	for _, root in gui:GetChildren() do
		if root:IsA("ScreenGui") and root.Enabled and not SKIP_GUIS[root.Name] then
			for _, obj in root:GetDescendants() do
				if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
					if shownIn(obj) then
						local ok, item = pcall(function()
							return inspect(obj, root, cal, options.touchRule, screen, found)
						end)
						if ok and item then
							table.insert(items, item)
						elseif not ok then
							warn(TAG, "could not check", obj:GetFullName(), item)
						end
					end
				end
			end
		end
	end

	-- OVERLAP: two texts on the same box drawing over each other.
	local groups: { [Instance]: { Item } } = {}
	for _, item in items do
		local key = item.box or item.gui
		groups[key] = groups[key] or {}
		table.insert(groups[key], item)
	end
	for _, group in groups do
		for i = 1, #group do
			for j = i + 1, #group do
				local a, b = group[i], group[j]
				if a.text ~= b.text or a.label.Parent ~= b.label.Parent then
					local both = intersect(a.rect, b.rect)
					if both and both.x2 - both.x1 > 1.5 and both.y2 - both.y1 > 1.5 then
						table.insert(found, {
							kind = "OVERLAP",
							path = pathOf(a.label),
							text = a.text,
							detail = `draws over "{b.text}" ({pathOf(b.label)}) by {num(
								both.x2 - both.x1
							)}x{num(both.y2 - both.y1)} px`,
							rect = both,
							gui = a.gui,
						})
					end
				end
			end
		end
	end

	-- Print what's new.
	local fresh: { Problem } = {}
	for _, problem in found do
		local key = `{problem.kind}|{problem.path}|{problem.text}|{problem.detail}`
		if not seen[key] then
			seen[key] = true
			table.insert(fresh, problem)
		end
	end
	for i, problem in fresh do
		if i > MAX_LINES then
			print(TAG, `... {#fresh - MAX_LINES} more not printed`)
			break
		end
		print(TAG, `{problem.kind} {context}{problem.path} "{problem.text}": {problem.detail}`)
	end
	if options.outline then
		drawOutlines(fresh, cal)
	end
	return fresh, #items
end

local function header(cal: Calibration): string
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.zero
	return `screen {num(view.X)}x{num(view.Y)}, menu UI scale {string.format("%.2f", Ui.factor())}, touch={tostring(
		UserInputService.TouchEnabled
	)}, touch rule {if options.touchRule then "ON" else "off"}` .. ` | rules: pad {Config.Ui.MinPadding} px sideways / {Config.Ui.MinPaddingY} above+below, text least {if options.touchRule
		then Config.Ui.MinTouchTextSize
		else Config.Ui.MinTextSize} px` .. ` | calibration: AbsoluteSize scaled={tostring(
		cal.absScaled
	)}, TextBounds scaled={tostring(cal.boundsScaled)}, line height Bold {string.format(
		"%.2f",
		cal.lineRatio[fontKey(Ui.Bold)] or 0
	)} Heavy {string.format("%.2f", cal.lineRatio[fontKey(Ui.Heavy)] or 0)} Display {string.format(
		"%.2f",
		cal.lineRatio[fontKey(Ui.Display)] or 0
	)}`
end

local function summary(all: { Problem }, scanned: number, label: string)
	local counts: Counts = {}
	for _, problem in all do
		counts[problem.kind] = (counts[problem.kind] or 0) + 1
	end
	local parts = {}
	for _, kind in { "FIT", "CUT", "PAD", "SMALL", "OVERLAP", "OFFSCREEN" } do
		table.insert(parts, `{kind} {counts[kind] or 0}`)
	end
	print(
		TAG,
		`SUMMARY {label}: {#all} problems ({table.concat(parts, ", ")}), {scanned} texts checked`
	)
end

local function getCalibration(): Calibration
	if not calibration then
		calibration = calibrate()
	end
	return calibration :: Calibration
end

-- Scans what is on screen now.
function UiAudit.scan()
	if running then
		print(TAG, "already running")
		return
	end
	running = true
	task.spawn(function()
		local ok, err = pcall(function()
			calibration = calibrate() -- (fresh each time: the window may have been resized)
			local cal = getCalibration()
			if options.outline then
				UiAudit.clearOutlines()
			end
			print(TAG, "SCAN", header(cal))
			local problems, scanned = scanNow("", {}, cal)
			summary(problems, scanned or 0, "scan")
		end)
		if not ok then
			warn(TAG, "scan failed:", err)
		end
		running = false
	end)
end

-- Worst-case content -----------------------------------------------------------------------

local function longest(kind: string): Catalog.Item?
	local best: Catalog.Item? = nil
	for _, item in Catalog.Items do
		if item.kind == kind and (not best or #item.name > #best.name) then
			best = item
		end
	end
	return best
end

-- A fake profile: "broke" owns the defaults and has nothing; "rich" owns everything, has
-- seven-digit totals, the longest equipped names, finished quests and a day-7 streak claim.
local function fakeProfile(rich: boolean): { [string]: any }
	local owned: { [string]: boolean } = {}
	local equipped: { [string]: string } = {}
	local serials: { [string]: number } = {}
	for _, item in Catalog.Items do
		if rich or Config.Progression.DefaultEquipped[item.kind] == item.id then
			owned[item.id] = true
		end
		if item.rarity == "Iridescent" then
			serials[item.id] = 12345
		end
	end
	for _, kind in { "Trail", "TagEffect", "Title", "Victory" } do
		local pick = if rich then longest(kind) else nil
		equipped[kind] = if pick then pick.id else Config.Progression.DefaultEquipped[kind]
	end
	local function quests(list: any, slots: number): { any }
		local made = {}
		for i = 1, slots do
			local def = list and list[i]
			if def then
				made[i] = {
					Id = def.Id,
					Progress = if rich
						then (if i == 1
							then def.Goal
							elseif i == 2 then math.max(def.Goal - 1, 0)
							else def.Goal)
						else 0,
					Claimed = rich and i == 3,
				}
			end
		end
		return made
	end
	local achievements: { [string]: boolean } = {}
	if rich then
		for i, achievement in Config.Achievements do
			if i % 2 == 0 then
				achievements[achievement.Id] = true
			end
		end
	end
	local day = DayClock.day()
	return {
		Coins = if rich then 9999999 else 0,
		XP = if rich then 9999 else 0,
		Level = if rich then 100 else 1,
		Stats = {
			Wins = if rich then 1234567 else 0,
			Tags = if rich then 9876543 else 0,
			RoundsSurvived = if rich then 456789 else 0,
			GamesPlayed = if rich then 2345678 else 0,
			PlayMinutes = if rich then 99999 else 0,
			WallRuns = if rich then 1234567 else 0,
			Slides = if rich then 7654321 else 0,
			WinStreak = if rich then 99 else 0,
			BestWinStreak = if rich then 123 else 0,
		},
		Owned = owned,
		Equipped = equipped,
		Streak = {
			Count = if rich then 36 else 0,
			LastDay = if rich then day - 1 else -1,
		},
		Quests = {
			Day = day,
			Daily = quests((Config.Quests :: any).Daily, 3),
			Week = DayClock.week(),
			Weekly = quests((Config.Quests :: any).Weekly, 3),
		},
		Achievements = achievements,
		Wheel = { LastSpin = 0 },
		Crates = if rich then 99 else 0,
		Serials = serials,
		Weekly = { Week = DayClock.week(), Wins = 0, Tags = 0, WallRuns = 0 },
		FirstWinDay = -1,
	}
end

local function leadersPayload(): { [string]: any }
	local boards: { [string]: any } = {}
	local mine: { [string]: any } = {}
	for _, def in Config.Leaderboards.Boards do
		for _, period in { "All", "Week" } do
			local key = `{def.Id}:{period}`
			local entries = {}
			for i = 1, Config.Leaderboards.ShowCount do
				table.insert(entries, {
					Name = LONG_NAME,
					UserId = Players.LocalPlayer.UserId,
					Value = 9999999 - i,
				})
			end
			boards[key] = entries
			mine[key] = { Rank = nil, Value = 1234567 }
		end
	end
	return { Source = "server", Boards = boards, Me = mine }
end

local function longNames(count: number): { string }
	local items: { string } = {}
	for _, item in Catalog.Items do
		table.insert(items, item.id)
	end
	table.sort(items, function(a, b)
		local ia, ib = Catalog.get(a), Catalog.get(b)
		return #(if ia then ia.name else "") > #(if ib then ib.name else "")
	end)
	local out = {}
	for i = 1, math.min(count, #items) do
		out[i] = items[i]
	end
	return out
end

-- Opens every tab of every tab row in a page, scanning each state.
local function eachTab(page: Instance, visit: (string) -> ())
	local rows: { Instance } = {}
	for _, d in page:GetDescendants() do
		if d.Name == "Tabs" and d:IsA("Frame") then
			table.insert(rows, d)
		end
	end
	local function showing(row: Instance): boolean
		return row:IsA("GuiObject") and shownIn(row) ~= nil and row.AbsoluteSize.X > 0
	end
	-- The page's own tab row first, then the rows inside whichever tab it opened.
	local mainRow = nil
	for _, row in rows do
		if row.Parent == page then
			mainRow = row
		end
	end
	if not mainRow then
		visit("")
		return
	end
	local mainNames = Ui.tabNames(mainRow)
	for _, tab in mainNames do
		Ui.pick(mainRow, tab)
		task.wait(0.4)
		visit(`{tab}`)
		for _, row in rows do
			if row ~= mainRow and showing(row) then
				for _, inner in Ui.tabNames(row) do
					Ui.pick(row, inner)
					task.wait(0.35)
					visit(`{tab}/{inner}`)
				end
			end
		end
	end
	Ui.pick(mainRow, mainNames[1])
end

-- Opens every menu page (broke, then rich) and the popups and other screens with worst-case
-- content, scanning each. Takes about a minute and puts the camera and menu back afterwards.
function UiAudit.sweep()
	if running then
		print(TAG, "already running")
		return
	end
	running = true
	task.spawn(function()
		local seen: { [string]: boolean } = {}
		local all: { Problem } = {}
		local scanned = 0
		local player = Players.LocalPlayer
		local gui = playerGui()
		local ok, err = pcall(function()
			calibration = calibrate()
			local cal = getCalibration()
			if options.outline then
				UiAudit.clearOutlines()
			end
			print(TAG, "SWEEP", header(cal))
			local function look(context: string)
				local found, count = scanNow(`[{context}] `, seen, cal)
				for _, problem in found do
					table.insert(all, problem)
				end
				scanned += count or 0
			end

			-- Menu pages with a broke and a rich fake profile.
			for _, rich in { false, true } do
				local who = if rich then "rich" else "broke"
				Profile.setOverride(fakeProfile(rich))
				task.wait(0.3)
				for _, name in { "Shop", "Locker", "Quests", "Rewards", "Leaders" } do
					Menu.open(name)
					task.wait(0.6)
					-- (Menu > Root > Window > Body > the page; the nav button has the same name)
					local menu = gui and gui:FindFirstChild("Menu")
					local root = menu and menu:FindFirstChild("Root")
					local window = root and root:FindFirstChild("Window")
					local body = window and window:FindFirstChild("Body")
					local pageFrame = body and body:FindFirstChild(name)
					local function visit(tab: string)
						if name == "Leaders" then
							LeadersTab.sample(leadersPayload())
							task.wait(0.15)
						end
						look(`{name} {who}{if tab ~= "" then " " .. tab else ""}`)
					end
					if pageFrame then
						eachTab(pageFrame, visit)
					else
						visit("")
					end
				end
				Menu.open(nil)
				task.wait(0.4)
				look(`menu closed {who}`)
			end

			-- Popups, one at a time.
			local items = longNames(6)
			Profile.setOverride(fakeProfile(true))
			Popups.show({ Kind = "Earned", Coins = 9999999, XP = 999999, Reason = "RoundSurvived" })
			task.wait(0.5)
			look("popup earned")
			Popups.show({
				Kind = "LevelUp",
				Level = 100,
				Coins = 99999,
				Crates = 99,
				Items = items,
			})
			task.wait(1.0)
			look("popup level-up stripe")
			task.wait(1.5)
			look("popup level-up card")
			task.wait(3.2)
			Popups.show({
				Kind = "Grant",
				Reason = "Wall run 1,000 times claimed!",
				Coins = 99999,
				XP = 99999,
				Crates = 99,
				Items = items,
			})
			task.wait(0.9)
			look("popup grant card")
			task.wait(2.2)
			local results = {}
			for i, id in longNames(10) do
				table.insert(
					results,
					{ Item = id, Duplicate = i % 3 == 0, Serial = if i == 1 then 12345 else nil }
				)
			end
			Popups.show({ Kind = "Crate", Items = results })
			task.wait(4.3)
			look("popup crate reel")
			task.wait(3.5)
			Popups.announce({
				Kind = "Unbox",
				Name = LONG_NAME,
				Item = items[1],
				Serial = 12345,
			})
			task.wait(1.0)
			look("popup unbox stripe")
			task.wait(3.5)

			-- Toast, banner, spectate bar.
			Notify.show(`{LONG_NAME} fell and is out! {LONG_NAME} was hit by the train!`)
			task.wait(0.3)
			look("toast")
			Hud.preview(`{LONG_NAME} wins!`, 3)
			task.wait(0.8)
			look("hud banner")
			task.wait(2.6)
			local spectate = gui and gui:FindFirstChild("Spectate")
			if spectate and spectate:IsA("ScreenGui") then
				local wasOn = spectate.Enabled
				spectate.Enabled = true
				for _, d in spectate:GetDescendants() do
					if d:IsA("TextLabel") and d.Text == "" then
						d.Text = `SPECTATING {LONG_NAME}  ·  Q / E TO SWITCH`
					end
				end
				task.wait(0.4)
				look("spectate bar")
				spectate.Enabled = wasOn
			end

			-- The results card and the win screen.
			local out = {}
			for i = 1, 12 do
				table.insert(out, {
					UserId = player.UserId,
					Name = LONG_NAME,
					DisplayName = LONG_NAME,
					Reason = ({ "It", "Fell", "Train", "Afk" })[i % 4 + 1],
				})
			end
			RoundResults.preview({
				Round = 12,
				Left = 100,
				Out = out,
				Next = true,
				Duration = 4,
				CoverAt = 99,
				Mine = {
					Fate = "Out",
					Reason = "Train",
					Tags = 99999,
					Tagged = 0,
					ItSeconds = 3599,
				},
			})
			task.wait(1.0)
			look("results card")
			RoundResults.hide()
			task.wait(0.6)
			local podium = {}
			for place = 1, 3 do
				table.insert(podium, {
					UserId = player.UserId,
					Name = LONG_NAME,
					DisplayName = LONG_NAME,
					Place = place,
					Won = place == 1,
				})
			end
			WinScreen.sample({
				Podium = podium,
				Duration = 12,
				Rewards = {
					Coins = 9999999,
					XP = 999999,
					Crates = 99,
					Items = items,
					LevelFrom = 99,
					LevelTo = 100,
					Place = 30,
					Of = 30,
				},
			})
			task.wait(Config.WinScreen.RewardsDelay + 1.4)
			look("win screen")
			WinScreen.close()
			task.wait(0.5)
		end)
		if not ok then
			warn(TAG, "sweep stopped early:", err)
		end
		Profile.setOverride(nil)
		Menu.open(nil)
		summary(all, scanned, "sweep")
		print(
			TAG,
			"Not covered: the Locker's 3D preview and info plate (shown if you are in the lobby), the lobby boards and world titles."
		)
		running = false
	end)
end

return UiAudit
