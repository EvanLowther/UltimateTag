--!strict
-- The game's UI style (every menu, popup and HUD piece uses it): chunky and bright, like a
-- classic simulator shop. White windows with a red header bar, thick dark outlines on
-- everything, bold white text with a dark outline, bright glossy cards, white price pills with a
-- coin, and buttons that bounce. Everything is built in code.
local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Colors = {
	Outline = Color3.fromRGB(28, 30, 48), -- the thick dark edge on everything
	Window = Color3.fromRGB(248, 248, 252), -- window bodies
	Header = Color3.fromRGB(236, 52, 62), -- window header bars
	Ink = Color3.fromRGB(44, 48, 70), -- dark text on white
	InkDim = Color3.fromRGB(120, 126, 150),
	Text = Color3.fromRGB(255, 255, 255),
	Pill = Color3.fromRGB(250, 250, 255),
	Track = Color3.fromRGB(70, 74, 96), -- empty part of bars
	Coin = Color3.fromRGB(255, 205, 50),
	XP = Color3.fromRGB(80, 190, 255),
	Good = Color3.fromRGB(80, 205, 80),
	Bad = Color3.fromRGB(236, 60, 70),
	Locked = Color3.fromRGB(150, 155, 175),
	-- Card colors.
	Teal = Color3.fromRGB(50, 215, 200),
	Purple = Color3.fromRGB(160, 100, 255),
	Blue = Color3.fromRGB(70, 155, 255),
	Orange = Color3.fromRGB(255, 150, 45),
	Yellow = Color3.fromRGB(255, 210, 45),
	Green = Color3.fromRGB(85, 205, 85),
	Pink = Color3.fromRGB(255, 105, 180),
	Red = Color3.fromRGB(240, 70, 80),
}

Ui.Font = Enum.Font.FredokaOne
Ui.BigFont = Enum.Font.LuckiestGuy
Ui.OutlineThickness = 3

function Ui.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

-- The thick dark border.
function Ui.outline(parent: Instance, thickness: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Color = color or Ui.Colors.Outline
	s.Thickness = thickness or Ui.OutlineThickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
end

function Ui.padding(parent: Instance, pixels: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, pixels)
	p.PaddingRight = UDim.new(0, pixels)
	p.PaddingTop = UDim.new(0, pixels)
	p.PaddingBottom = UDim.new(0, pixels)
	p.Parent = parent
end

-- A glossy shine: lighter at the top.
function Ui.gloss(parent: GuiObject)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))
	g.Rotation = 90
	g.Parent = parent
end

function Ui.frame(parent: Instance, color: Color3?, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or Ui.Colors.Window
	f.BorderSizePixel = 0
	Ui.corner(f, radius)
	f.Parent = parent
	return f
end

-- A bright card: colored, outlined, glossy.
function Ui.card(parent: Instance, color: Color3, radius: number?): Frame
	local f = Ui.frame(parent, color, radius or 12)
	Ui.outline(f)
	Ui.gloss(f)
	return f
end

-- Bold white text with a dark outline (the main text style).
function Ui.text(
	parent: Instance,
	text: string,
	size: number?,
	color: Color3?,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font or Ui.BigFont
	l.TextSize = size or 20
	l.TextColor3 = color or Ui.Colors.Text
	l.RichText = true
	local s = Instance.new("UIStroke")
	s.Thickness = math.max(1.5, (size or 20) / 9)
	s.Color = Ui.Colors.Outline
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
	l.Parent = parent
	return l
end

-- Plain dark text (on white backgrounds).
function Ui.ink(parent: Instance, text: string, size: number?, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Ui.Font
	l.TextSize = size or 18
	l.TextColor3 = color or Ui.Colors.Ink
	l.RichText = true
	l.Parent = parent
	return l
end

-- Kept for older callers: same as Ui.ink.
Ui.label = Ui.ink

-- A button that bounces: colored, outlined, glossy, with outlined white text.
function Ui.button(parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Text = ""
	Ui.corner(b, 10)
	Ui.outline(b)
	Ui.gloss(b)
	local label = Ui.text(b, text, 20)
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = false
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local quick = TweenInfo.new(0.08)
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
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
function Ui.setText(button: TextButton, text: string)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Sets a Ui.button's text size.
function Ui.setTextSize(button: TextButton, size: number)
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextSize = size
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = math.max(1.5, size / 9)
		end
	end
end

-- A square icon button (the left-side menu): a big emoji, a small name underneath.
function Ui.iconButton(
	parent: Instance,
	icon: string,
	name: string,
	color: Color3,
	onClick: () -> ()
): TextButton
	local b = Ui.button(parent, "", color, onClick)
	b.Size = UDim2.fromOffset(68, 68)
	local emoji = Instance.new("TextLabel")
	emoji.BackgroundTransparency = 1
	emoji.Text = icon
	emoji.TextScaled = true
	emoji.Position = UDim2.fromScale(0.15, 0.06)
	emoji.Size = UDim2.fromScale(0.7, 0.62)
	emoji.Parent = b
	local label = Ui.text(b, name, 13)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -3)
	label.Size = UDim2.new(1, 0, 0, 16)
	return b
end

-- A gold coin (a circle with a C), `size` pixels.
function Ui.coinIcon(parent: Instance, size: number): Frame
	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(size, size)
	coin.BackgroundColor3 = Ui.Colors.Coin
	Ui.corner(coin, size)
	Ui.outline(coin, 2, Color3.fromRGB(150, 100, 15))
	local c = Ui.text(coin, "C", math.floor(size * 0.62), Color3.fromRGB(255, 240, 170))
	c.Size = UDim2.fromScale(1, 1)
	coin.Parent = parent
	return coin
end

-- A white price pill with a coin and a number (dark text).
function Ui.pricePill(parent: Instance, amount: number?, text: string?): Frame
	local pill = Ui.frame(parent, Ui.Colors.Pill, 20)
	Ui.outline(pill, 2.5)
	pill.Size = UDim2.fromOffset(84, 26)
	local label = Ui.ink(pill, text or Ui.number(amount or 0), 17)
	label.Name = "Label"
	if amount then
		local coin = Ui.coinIcon(pill, 18)
		coin.Position = UDim2.fromOffset(5, 4)
		label.Position = UDim2.fromOffset(24, 0)
		label.Size = UDim2.new(1, -28, 1, 0)
	else
		label.Size = UDim2.fromScale(1, 1)
	end
	return pill
end

-- A dark divider line with round ends.
function Ui.divider(parent: Instance): Frame
	local line = Ui.frame(parent, Ui.Colors.Outline, 3)
	line.Size = UDim2.new(1, -16, 0, 4)
	return line
end

-- A progress bar: dark outlined track, colored fill. Returns the bar and a setter (0-1).
function Ui.bar(parent: Instance, color: Color3): (Frame, (number) -> ())
	local bar = Ui.frame(parent, Ui.Colors.Track, 8)
	Ui.outline(bar, 2.5)
	local fill = Ui.frame(bar, color, 8)
	Ui.gloss(fill)
	fill.Size = UDim2.fromScale(0, 1)
	return bar,
		function(fraction: number)
			TweenService:Create(
				fill,
				TweenInfo.new(0.35),
				{ Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }
			):Play()
		end
end

-- A window: white body, thick outline, colored header bar with a title and a red X.
-- Returns the window, its content area (below the header), and the close button.
function Ui.window(
	parent: Instance,
	title: string,
	headerColor: Color3?
): (Frame, Frame, TextButton, TextLabel)
	local window = Ui.frame(parent, Ui.Colors.Window, 16)
	Ui.outline(window, 4)
	local header = Ui.frame(window, headerColor or Ui.Colors.Header, 16)
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 52)
	-- Square off the header's bottom corners with a strip under it.
	local strip = Instance.new("Frame")
	strip.BorderSizePixel = 0
	strip.BackgroundColor3 = headerColor or Ui.Colors.Header
	strip.Position = UDim2.new(0, 0, 1, -16)
	strip.Size = UDim2.new(1, 0, 0, 16)
	strip.Parent = header
	local edge = Ui.frame(window, Ui.Colors.Outline, 0)
	edge.Position = UDim2.fromOffset(0, 52)
	edge.Size = UDim2.new(1, 0, 0, 4)
	local titleLabel = Ui.text(header, title, 32)
	titleLabel.Position = UDim2.fromOffset(18, 0)
	titleLabel.Size = UDim2.new(1, -80, 1, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 2
	-- The close button: a bold X on a dark red square (callers connect close.Activated).
	local close = Ui.button(header, "X", Color3.fromRGB(190, 30, 42), function() end)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(40, 40)
	close.ZIndex = 2
	Ui.setTextSize(close, 26)
	local closeLabel = close:FindFirstChild("Label")
	if closeLabel and closeLabel:IsA("TextLabel") then
		closeLabel.ZIndex = 2
	end
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(14, 66)
	body.Size = UDim2.new(1, -28, 1, -80)
	body.Parent = window
	return window, body, close, titleLabel
end

-- A vertical scrolling list with a dark rounded scrollbar.
function Ui.scroll(parent: Instance, padding: number?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Ui.Colors.Outline
	scroll.ScrollBarImageTransparency = 0
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = scroll
	return scroll
end

-- Bounces something in: grows from small with a little overshoot.
function Ui.popIn(object: GuiObject, seconds: number?)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = object
	TweenService:Create(
		scale,
		TweenInfo.new(seconds or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- A number with thousands separators: 12500 -> "12,500".
function Ui.number(n: number): string
	local text = tostring(math.floor(n))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

return Ui
