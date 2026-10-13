--!strict
-- The game's UI kit, "Street sprint": flat black panels with cut corners, slanted bars and
-- buttons, hazard yellow, hot pink and cyan, Bangers headlines over Titillium Web labels. Every
-- menu, popup and HUD piece is built from these helpers (the dev panel keeps its own plain look).
--   Slants: Roblox can't skew a frame, so a slanted shape (Ui.slab) is three frames, a middle
--   and two end caps. Each cap is cut along its diagonal by a UIGradient with a hard
--   transparency step at 0.5: a gradient rotated r degrees has edges leaning r degrees from
--   vertical, and t = 0.5 always runs through the middle of the frame, so rotating it to
--   atan(cap width / height) cuts exactly corner to corner. Ui.paint recolors a slab.
--   Moving gradients (the Iridescent holo shimmer) are tagged for client/GradientFx.
--   Icons are drawn shapes (client/Icons), never emoji.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))
local Icons = require(script.Parent.Parent.Icons)

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(17, 17, 17), -- windows and bars
	Card = Color3.fromRGB(30, 30, 30), -- cards and rows
	Tab = Color3.fromRGB(38, 38, 38), -- idle tabs and chips
	Track = Color3.fromRGB(44, 44, 46), -- the empty part of bars
	Well = Color3.fromRGB(22, 22, 22), -- preview wells inside cards
	Text = Color3.fromRGB(255, 255, 255),
	Dim = Color3.fromRGB(138, 138, 138),
	Ink = Color3.fromRGB(17, 17, 17), -- dark text on bright fills
	Yellow = Color3.fromRGB(255, 214, 10),
	Pink = Color3.fromRGB(255, 46, 136),
	Cyan = Color3.fromRGB(25, 227, 255),
	Lime = Color3.fromRGB(124, 255, 79),
	Orange = Color3.fromRGB(255, 138, 31),
	Red = Color3.fromRGB(227, 36, 43),
	Blue = Color3.fromRGB(60, 150, 255),
	Purple = Color3.fromRGB(170, 80, 255),
	Gold = Color3.fromRGB(255, 180, 40),
	Coin = Color3.fromRGB(255, 214, 10),
	XP = Color3.fromRGB(25, 227, 255),
	PaidBack = Color3.fromRGB(22, 36, 15), -- a finished row's dark green
	DoneBack = Color3.fromRGB(42, 34, 16), -- a completed chain's dark gold
}

Ui.Display = Font.new("rbxasset://fonts/families/Bangers.json")
Ui.Bold = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold)
Ui.Heavy = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Heavy)

Ui.Slant = 8 -- default slant in pixels: how far a slab's top edge sits right of its bottom

local WHITE = Color3.new(1, 1, 1)

local function kp(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end
local KEEP_HIGH = NumberSequence.new({ kp(0, 1), kp(0.49, 1), kp(0.51, 0), kp(1, 0) })
local KEEP_LOW = NumberSequence.new({ kp(0, 0), kp(0.49, 0), kp(0.51, 1), kp(1, 1) })

local function piece(parent: Instance, name: string, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.ZIndex = 0 -- under whatever goes on the shape
	f.Parent = parent
	return f
end

local function cut(frame: Frame, keep: NumberSequence, rotation: number): UIGradient
	local g = Instance.new("UIGradient")
	g.Transparency = keep
	g.Rotation = rotation
	g.Parent = frame
	return g
end

-- A slanted bar. Its top edge leans `slant` pixels right of its bottom (negative: left; 0: a
-- plain rectangle). Size and place it like a Frame; children go on top of it.
function Ui.slab(parent: Instance?, color: Color3, slant: number?): Frame
	local s = slant or Ui.Slant
	local slab = Instance.new("Frame")
	slab.Name = "Slab"
	slab.BackgroundTransparency = 1
	slab.BorderSizePixel = 0
	local w = math.abs(s)
	if w < 1 then
		local whole = piece(slab, "SlabMid", color)
		whole.Size = UDim2.fromScale(1, 1)
	else
		local left = piece(slab, "SlabLeft", color)
		left.Size = UDim2.new(0, w, 1, 0)
		local middle = piece(slab, "SlabMid", color)
		middle.Position = UDim2.fromOffset(w, 0)
		middle.Size = UDim2.new(1, -2 * w, 1, 0)
		local right = piece(slab, "SlabRight", color)
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.fromScale(1, 0)
		right.Size = UDim2.new(0, w, 1, 0)
		local leftCut = cut(left, KEEP_HIGH, 0)
		local rightCut = cut(right, KEEP_LOW, 0)
		local function fit()
			local height = slab.AbsoluteSize.Y
			if height > 0 then
				local scale = left.AbsoluteSize.X / w -- UIScale and friends scale both sides
				local angle = math.deg(math.atan(w * (if scale > 0 then scale else 1) / height))
				leftCut.Rotation = if s > 0 then angle else -angle
				rightCut.Rotation = leftCut.Rotation
			end
		end
		slab:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
	end
	slab.Parent = parent
	return slab
end

-- A panel with its top-right and bottom-left corners cut off (the menu windows).
function Ui.panel(parent: Instance?, color: Color3, corner: number?): Frame
	local c = corner or 16
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	local top = piece(panel, "SlabTop", color)
	top.Size = UDim2.new(1, -c, 0, c)
	local topRight = piece(panel, "SlabTopRight", color)
	topRight.AnchorPoint = Vector2.new(1, 0)
	topRight.Position = UDim2.fromScale(1, 0)
	topRight.Size = UDim2.fromOffset(c, c)
	cut(topRight, KEEP_LOW, -45)
	local middle = piece(panel, "SlabMid", color)
	middle.Position = UDim2.fromOffset(0, c)
	middle.Size = UDim2.new(1, 0, 1, -2 * c)
	local bottom = piece(panel, "SlabBottom", color)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, c, 1, 0)
	bottom.Size = UDim2.new(1, -c, 0, c)
	local bottomLeft = piece(panel, "SlabBottomLeft", color)
	bottomLeft.AnchorPoint = Vector2.new(0, 1)
	bottomLeft.Position = UDim2.fromScale(0, 1)
	bottomLeft.Size = UDim2.fromOffset(c, c)
	cut(bottomLeft, KEEP_HIGH, -45)
	panel.Parent = parent
	return panel
end

-- Recolors a slab or panel (or any frame).
function Ui.paint(object: GuiObject, color: Color3)
	local painted = false
	for _, child in object:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 4) == "Slab" then
			child.BackgroundColor3 = color
			painted = true
		end
	end
	if not painted then
		object.BackgroundColor3 = color
	end
end

-- Sets a slab's or panel's transparency.
function Ui.fade(object: GuiObject, transparency: number)
	for _, child in object:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 4) == "Slab" then
			child.BackgroundTransparency = transparency
		end
	end
end

-- A plain frame (no slant).
function Ui.frame(parent: Instance?, color: Color3?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or Ui.Colors.Card
	if not color then
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end

-- Text (no background), bold Titillium unless `font` says otherwise. Rich text allowed.
function Ui.text(
	parent: Instance?,
	text: string,
	size: number?,
	color: Color3?,
	font: Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or Ui.Bold
	l.TextSize = size or 16
	l.TextColor3 = color or Ui.Colors.Text
	l.RichText = true
	l.Text = text
	l.Parent = parent
	return l
end

local function upperPlain(text: string): string
	return (string.gsub(text, "[a-z]", string.upper))
end

-- Upper-cases the ASCII letters in `text` and nothing else: emoji, accented letters (Roblox's
-- string.upper mangles their bytes) and rich text tags stay as written.
function Ui.upper(text: string): string
	local out = {}
	local i = 1
	while i <= #text do
		local open = string.find(text, "<", i, true)
		if not open then
			table.insert(out, upperPlain(string.sub(text, i)))
			break
		end
		table.insert(out, upperPlain(string.sub(text, i, open - 1)))
		local close = string.find(text, ">", open, true) or #text
		table.insert(out, string.sub(text, open, close))
		i = close + 1
	end
	return table.concat(out)
end

-- Upper-case heavy text (labels, tags, buttons).
function Ui.caps(parent: Instance?, text: string, size: number?, color: Color3?): TextLabel
	local label = Ui.text(parent, "", size or 14, color, Ui.Heavy)
	label.Text = Ui.upper(text)
	return label
end

-- Keeps `frame` as wide as `content` (an auto-sized label inside it) plus `extra` pixels. A
-- frame can't size itself to its children (AutomaticSize) while it also holds children sized
-- by Scale, like a slab's pieces: those stretch it to fill its parent instead.
function Ui.fitWidth(frame: GuiObject, content: GuiObject, extra: number?)
	local function fit()
		local size = frame.Size
		frame.Size = UDim2.new(
			0,
			math.ceil(content.AbsoluteSize.X) + (extra or 0),
			size.Y.Scale,
			size.Y.Offset
		)
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
end

-- A headline in Bangers.
function Ui.title(parent: Instance?, text: string, size: number?, color: Color3?): TextLabel
	return Ui.text(parent, text, size or 30, color, Ui.Display)
end

-- A dark outline round text (for text straight over the game world).
function Ui.stroke(label: TextLabel, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Ui.Colors.Ink
	s.Thickness = thickness or 2
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	return s
end

-- An icon (client/Icons), `size` pixels square: white with a dark accent unless colors are
-- given.
function Ui.icon(
	parent: Instance?,
	name: string,
	size: number,
	color: Color3?,
	accent: Color3?
): Frame
	return Icons.draw(parent, name, size, color, accent)
end

-- An icon centered in its parent.
function Ui.centerIcon(
	parent: Instance?,
	name: string,
	size: number,
	color: Color3?,
	accent: Color3?
): Frame
	local icon = Icons.draw(parent, name, size, color, accent)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	return icon
end

-- An icon followed by caps text, side by side (auto width, centered vertically). Returns the
-- row and its label.
function Ui.iconText(
	parent: Instance?,
	icon: string,
	text: string,
	size: number,
	color: Color3,
	iconColor: Color3?,
	accent: Color3?
): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Name = "IconText"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(0, size + 6)
	row.AutomaticSize = Enum.AutomaticSize.X
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, math.max(4, math.floor(size / 3)))
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local mark = Icons.draw(row, icon, size + 2, iconColor or color, accent)
	mark.LayoutOrder = 1
	local label = Ui.caps(row, text, size, color)
	label.Name = "Label"
	label.LayoutOrder = 2
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	row.Parent = parent
	return row, label
end

-- Makes an object's fill or text shimmer in the Iridescent holo colors (client/GradientFx).
function Ui.holo(object: GuiObject, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = CosmeticLook.holoSequence(0)
	g.Rotation = rotation or 0
	g.Parent = object
	CollectionService:AddTag(g, "HoloGradient")
	return g
end

-- A rarity's color.
function Ui.rarityColor(rarity: string): Color3
	local r = Catalog.Rarities[rarity]
	return if r then r.color else Ui.Colors.Dim
end

-- A rarity's name in its color (Iridescent shimmers).
function Ui.rarity(parent: Instance?, rarity: string, size: number?): TextLabel
	local label = Ui.caps(parent, rarity, size or 12, Ui.rarityColor(rarity))
	if rarity == "Iridescent" then
		label.TextColor3 = WHITE
		Ui.holo(label)
	end
	return label
end

-- A strip in a rarity's color (Iridescent shimmers), across the top of cards and tiles.
function Ui.rarityStrip(parent: Instance, rarity: string, height: number?): Frame
	local strip = Ui.frame(parent, Ui.rarityColor(rarity))
	strip.Name = "RarityStrip"
	strip.Size = UDim2.new(1, 0, 0, height or 4)
	strip.ZIndex = 2
	if rarity == "Iridescent" then
		strip.BackgroundColor3 = WHITE
		Ui.holo(strip)
	end
	return strip
end

-- A slanted button: a colored slab with a label; it brightens under the mouse and bounces when
-- pressed. The label is dark (for bright fills) unless `textColor` says otherwise.
function Ui.button(
	parent: Instance?,
	text: string,
	color: Color3,
	onClick: () -> (),
	textColor: Color3?,
	slant: number?,
	icon: string?
): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Text = ""
	b:SetAttribute("Color", color)
	local fill = Ui.slab(b, color, slant)
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	if icon then
		-- An icon before the text, the pair centered on the button.
		local row, label = Ui.iconText(b, icon, text, 15, textColor or Ui.Colors.Ink)
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.5)
		row.ZIndex = 2
		label.ZIndex = 2
	else
		local label = Ui.caps(b, text, 15, textColor or Ui.Colors.Ink)
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.ZIndex = 2
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local quick = TweenInfo.new(0.08)
	b.MouseEnter:Connect(function()
		local base = b:GetAttribute("Color") :: Color3
		Ui.paint(fill, base:Lerp(WHITE, 0.18))
		TweenService:Create(scale, quick, { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		Ui.paint(fill, b:GetAttribute("Color") :: Color3)
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	b.Parent = parent
	return b
end

-- Changes a Ui.button's text.
function Ui.setText(button: GuiObject, text: string)
	local label = button:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = Ui.upper(text)
	end
end

-- Changes a Ui.button's color (and its text color).
function Ui.setColor(button: GuiObject, color: Color3, textColor: Color3?)
	button:SetAttribute("Color", color)
	local fill = button:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		Ui.paint(fill, color)
	end
	local label = button:FindFirstChild("Label", true)
	if textColor and label and label:IsA("TextLabel") then
		label.TextColor3 = textColor
		local icon = button:FindFirstChild("Icon", true)
		if icon then
			Icons.paint(icon, textColor)
		end
	end
end

-- Changes a Ui.button's text size.
function Ui.setTextSize(button: GuiObject, size: number)
	local label = button:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.TextSize = size
	end
end

-- A row of slanted tabs. Clicking one calls `onSelect(name)`. Returns the row, a function that
-- shows a tab as selected, and one that sets a tab's badge count (nil or 0 hides it).
function Ui.tabs(
	parent: Instance?,
	names: { string },
	color: Color3,
	onSelect: (string) -> (),
	height: number?,
	textSize: number?
): (Frame, (string) -> (), (string, number?) -> ())
	local row = Instance.new("Frame")
	row.Name = "Tabs"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(0, height or 30)
	row.AutomaticSize = Enum.AutomaticSize.X
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local tabs: { [string]: TextButton } = {}
	local labels: { [string]: TextLabel } = {}
	local badges: { [string]: number } = {}
	local current: string? = nil

	local function draw(name: string)
		local label = labels[name]
		local count = badges[name]
		local selected = name == current
		local text = Ui.upper(name)
		if count and count > 0 then
			text ..= `  <font color="#{if selected then "111111" else Ui.Colors.Lime:ToHex()}">{count}</font>`
		end
		label.Text = text
		label.TextColor3 = if selected then Ui.Colors.Ink else Ui.Colors.Dim
		Ui.paint(
			tabs[name]:FindFirstChild("Fill") :: Frame,
			if selected then color else Ui.Colors.Tab
		)
	end

	local function select(name: string)
		current = name
		for other in tabs do
			draw(other)
		end
	end

	for i, name in names do
		local tab = Instance.new("TextButton")
		tab.Name = name
		tab.AutoButtonColor = false
		tab.BackgroundTransparency = 1
		tab.Text = ""
		tab.LayoutOrder = i
		tab.Size = UDim2.fromScale(0, 1)
		local fill = Ui.slab(tab, Ui.Colors.Tab, 7)
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		local label = Ui.caps(tab, name, textSize or 13, Ui.Colors.Dim)
		label.Size = UDim2.fromScale(0, 1)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.ZIndex = 2
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = label
		Ui.fitWidth(tab, label)
		tab.Activated:Connect(function()
			-- The row shows the click itself, so a tab is always lit for what's on screen (and
			-- every other tab stays clickable) even if `onSelect` doesn't call `select`.
			if current ~= name then
				select(name)
				onSelect(name)
			end
		end)
		tab.Parent = row
		tabs[name] = tab
		labels[name] = label
		draw(name)
	end
	row.Parent = parent

	local function badge(name: string, count: number?)
		if tabs[name] then
			badges[name] = count or 0
			draw(name)
		end
	end
	return row, select, badge
end

-- Puts icon `name` in a window header (dark on the bright bar, white details).
function Ui.windowIcon(header: Frame, name: string)
	local holder = header:FindFirstChild("IconHolder")
	if holder then
		Ui.clear(holder)
		Icons.draw(holder, name, 32, Ui.Colors.Ink, WHITE)
	end
end

-- The menu window: a black panel with cut corners, a slanted header bar in `color` (an icon,
-- the title in Bangers, and an info text on the right), and a pink close button. Returns the
-- window, its body (under the header), the close button, the header, the title and the info.
function Ui.window(
	parent: Instance?,
	title: string,
	color: Color3,
	icon: string?
): (Frame, Frame, TextButton, Frame, TextLabel, TextLabel)
	local window = Ui.panel(parent, Ui.Colors.Panel, 18)
	window.Name = "Window"
	local header = Ui.slab(window, color, 12)
	header.Name = "Header"
	header.Position = UDim2.fromOffset(0, 0)
	header.Size = UDim2.new(1, -60, 0, 52)
	local iconHolder = Ui.frame(header)
	iconHolder.Name = "IconHolder"
	iconHolder.Position = UDim2.fromOffset(14, 10)
	iconHolder.Size = UDim2.fromOffset(32, 32)
	iconHolder.ZIndex = 2
	if icon then
		Ui.windowIcon(header, icon)
	end
	local titleLabel = Ui.title(header, title, 36, Ui.Colors.Ink)
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(52, 2)
	titleLabel.Size = UDim2.new(0.6, -52, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 2
	local info = Ui.caps(header, "", 15, Ui.Colors.Ink)
	info.Name = "Info"
	info.AnchorPoint = Vector2.new(1, 0)
	info.Position = UDim2.new(1, -22, 0, 0)
	info.Size = UDim2.fromScale(0.4, 1)
	info.TextXAlignment = Enum.TextXAlignment.Right
	info.ZIndex = 2
	local close = Ui.button(window, "X", Ui.Colors.Pink, function() end, Ui.Colors.Text, 0)
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -22, 0, 8)
	close.Size = UDim2.fromOffset(36, 36)
	Ui.setTextSize(close, 22)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 62)
	body.Size = UDim2.new(1, -32, 1, -78)
	body.Parent = window
	return window, body, close, header, titleLabel, info
end

-- A slanted progress bar: a dark track and a colored fill. Returns the bar and a setter (0-1).
function Ui.bar(parent: Instance?, color: Color3, slant: number?): (Frame, (number) -> ())
	local s = slant or 4
	local track = Ui.slab(parent, Ui.Colors.Track, s)
	track.Name = "Bar"
	track.ClipsDescendants = true
	local fill = Ui.slab(track, color, s)
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(math.abs(s) * 2 + 2, 0)
	limit.Parent = fill
	return track,
		function(fraction: number)
			local f = math.clamp(fraction, 0, 1)
			fill.Visible = f > 0
			TweenService:Create(fill, TweenInfo.new(0.35), { Size = UDim2.fromScale(f, 1) }):Play()
		end
end

-- A row of `count` slanted segments that fill up like a bar (the XP bar). Returns the row and a
-- setter (0-1).
function Ui.segments(
	parent: Instance?,
	count: number,
	color: Color3,
	width: number?,
	height: number?
): (Frame, (number) -> ())
	local row = Instance.new("Frame")
	row.Name = "Segments"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(count * ((width or 20) + 4), height or 14)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local segments = {}
	for i = 1, count do
		local seg = Ui.slab(row, Ui.Colors.Track, 5)
		seg.LayoutOrder = i
		seg.Size = UDim2.fromOffset(width or 20, height or 14)
		segments[i] = seg
	end
	row.Parent = parent
	return row,
		function(fraction: number)
			local filled = math.floor(math.clamp(fraction, 0, 1) * count + 0.0001)
			for i, seg in segments do
				Ui.paint(seg, if i <= filled then color else Ui.Colors.Track)
			end
		end
end

-- A gold coin, `size` pixels.
function Ui.coin(parent: Instance?, size: number): Frame
	local coin = Ui.frame(parent, Ui.Colors.Coin)
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(size, size)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = coin
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(170, 120, 0)
	ring.Thickness = math.max(1, size / 12)
	ring.Parent = coin
	local c = Ui.text(coin, "C", math.floor(size * 0.7), Color3.fromRGB(150, 100, 0), Ui.Heavy)
	c.Size = UDim2.fromScale(1, 1)
	return coin
end

-- A coin and an amount side by side (auto width). Returns the holder and the amount label.
function Ui.coinAmount(
	parent: Instance?,
	amount: number,
	size: number?,
	color: Color3?
): (Frame, TextLabel)
	local h = size or 16
	local holder = Instance.new("Frame")
	holder.Name = "CoinAmount"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(0, h + 4)
	holder.AutomaticSize = Enum.AutomaticSize.X
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	local coin = Ui.coin(holder, h)
	coin.LayoutOrder = 1
	local label = Ui.caps(holder, Ui.number(amount), h + 2, color or Ui.Colors.Yellow)
	label.LayoutOrder = 2
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	holder.Parent = parent
	return holder, label
end

-- A vertical scrolling list.
function Ui.scroll(parent: Instance?, padding: number?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Ui.Colors.Dim
	scroll.ScrollBarImageTransparency = 0.3
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = scroll
	return scroll
end

-- A horizontal row (auto sizing), children in LayoutOrder.
function Ui.row(parent: Instance?, gap: number?, height: number?): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height or 24)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	row.Parent = parent
	return row
end

-- A pink count badge pinned to an object's top-right corner. Returns its label (Text "" hides
-- it).
function Ui.badge(parent: GuiObject): TextLabel
	local badge = Ui.caps(parent, "", 12, Ui.Colors.Text)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, 6, 0, 2)
	badge.Size = UDim2.fromOffset(0, 18)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.BackgroundColor3 = Ui.Colors.Pink
	badge.BackgroundTransparency = 0
	badge.ZIndex = 5
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = badge
	badge.Visible = false
	badge:GetPropertyChangedSignal("Text"):Connect(function()
		badge.Visible = badge.Text ~= ""
	end)
	return badge
end

-- A gentle looping grow-and-shrink (a Claim button calling for attention).
function Ui.pulse(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		local new = Instance.new("UIScale")
		new.Parent = object
		scale = new
	end
	TweenService:Create(
		scale :: UIScale,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.07 }
	):Play()
end

-- Pops something in: grows from small with a little overshoot.
function Ui.popIn(object: GuiObject, seconds: number?)
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		local new = Instance.new("UIScale")
		new.Parent = object
		scale = new
	end
	local s = scale :: UIScale
	s.Scale = 0.5
	TweenService:Create(
		s,
		TweenInfo.new(seconds or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- Padding on all four sides (or left/right and top/bottom).
function Ui.padding(parent: Instance, x: number, y: number?)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y or x)
	p.PaddingBottom = UDim.new(0, y or x)
	p.Parent = parent
end

-- Removes every GuiObject child (to rebuild a list).
function Ui.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A number with thousands separators: 12500 -> "12,500".
function Ui.number(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""):gsub("^%-,", "-"))
end

-- "1:24" from seconds.
function Ui.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Ui
