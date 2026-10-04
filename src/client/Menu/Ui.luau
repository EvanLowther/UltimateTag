--!strict
-- UI building blocks for the game's menus (client/Menu): bright, rounded, chunky, with a
-- little bounce on buttons. Everything is built in code.
local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(30, 34, 52),
	PanelLight = Color3.fromRGB(46, 52, 78),
	Card = Color3.fromRGB(56, 62, 92),
	Text = Color3.fromRGB(255, 255, 255),
	Dim = Color3.fromRGB(175, 182, 210),
	Coin = Color3.fromRGB(255, 205, 60),
	XP = Color3.fromRGB(90, 200, 255),
	Good = Color3.fromRGB(80, 210, 110),
	Bad = Color3.fromRGB(240, 80, 80),
	Accent = Color3.fromRGB(255, 120, 60),
}

Ui.Font = Enum.Font.FredokaOne
Ui.BigFont = Enum.Font.LuckiestGuy

function Ui.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function Ui.stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(15, 18, 30)
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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

function Ui.frame(parent: Instance, color: Color3?, radius: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or Ui.Colors.Panel
	f.BorderSizePixel = 0
	Ui.corner(f, radius)
	f.Parent = parent
	return f
end

function Ui.label(
	parent: Instance,
	text: string,
	size: number?,
	color: Color3?,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font or Ui.Font
	l.TextSize = size or 18
	l.TextColor3 = color or Ui.Colors.Text
	l.RichText = true
	l.Parent = parent
	return l
end

-- Text with a dark outline, for text over the game view.
function Ui.outlined(label: TextLabel, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = Color3.fromRGB(20, 20, 30)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
end

-- A button that bounces when pressed.
function Ui.button(parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Ui.Font
	b.TextSize = 20
	b.TextColor3 = Ui.Colors.Text
	b.RichText = true
	Ui.corner(b, 10)
	Ui.stroke(b)
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
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	b.Parent = parent
	return b
end

-- A gold coin (a circle with a C), `size` pixels.
function Ui.coinIcon(parent: Instance, size: number): Frame
	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(size, size)
	coin.BackgroundColor3 = Ui.Colors.Coin
	Ui.corner(coin, size)
	Ui.stroke(coin, Color3.fromRGB(170, 120, 20), 2)
	local c = Ui.label(coin, "C", math.floor(size * 0.65), Color3.fromRGB(170, 110, 20), Ui.BigFont)
	c.Size = UDim2.fromScale(1, 1)
	coin.Parent = parent
	return coin
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
