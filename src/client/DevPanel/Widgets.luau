--!strict
-- Small UI building blocks for the dev panel: section headers, labels, buttons, rows of
-- buttons, toggles, number boxes and sliders. Each one stacks into its parent's list in the
-- order it's made. Dev-only, so the look is plain and dark.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Widgets = {}

Widgets.Colors = {
	Window = Color3.fromRGB(24, 26, 32),
	Bar = Color3.fromRGB(36, 39, 48),
	Item = Color3.fromRGB(46, 50, 62),
	ItemHover = Color3.fromRGB(60, 65, 80),
	Accent = Color3.fromRGB(70, 150, 255),
	On = Color3.fromRGB(60, 180, 100),
	Changed = Color3.fromRGB(255, 190, 70),
	Text = Color3.fromRGB(235, 238, 245),
	Dim = Color3.fromRGB(150, 156, 170),
}

local ROW = 28 -- height of a normal line
local order = 0

local function nextOrder(): number
	order += 1
	return order
end

-- The next position in a list, for items made outside these helpers.
Widgets.nextOrder = nextOrder

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 5)
	c.Parent = parent
end

function Widgets.text(instance: TextLabel | TextButton | TextBox, size: number?)
	instance.Font = Config.Ui.Font
	instance.TextSize = size or 15
	instance.TextColor3 = Widgets.Colors.Text
end

-- A vertical list that grows with its contents.
function Widgets.list(parent: Instance, padding: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = nextOrder()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or 4)
	layout.Parent = frame
	frame.Parent = parent
	return frame
end

function Widgets.section(parent: Instance, title: string): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = string.upper(title)
	label.LayoutOrder = nextOrder()
	Widgets.text(label, 13)
	label.TextColor3 = Widgets.Colors.Accent
	label.Parent = parent
	return label
end

function Widgets.label(parent: Instance, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.RichText = true
	label.Text = text
	label.LayoutOrder = nextOrder()
	Widgets.text(label, 14)
	label.TextColor3 = Widgets.Colors.Dim
	label.Parent = parent
	return label
end

-- A horizontal row; buttons added to it share its width equally.
function Widgets.row(parent: Instance, height: number?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height or ROW)
	frame.LayoutOrder = nextOrder()
	local gap = 4
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = frame
	-- Share the width equally between the items.
	local function relayout()
		local items = {}
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(items, child)
			end
		end
		local n = #items
		for _, item in items do
			item.Size = UDim2.new(1 / n, -gap * (n - 1) / n, 1, 0)
		end
	end
	frame.ChildAdded:Connect(relayout)
	frame.ChildRemoved:Connect(relayout)
	frame.Parent = parent
	return frame
end

function Widgets.button(parent: Instance, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = Widgets.Colors.Item
	button.Size = UDim2.new(1, 0, 0, ROW)
	button.Text = text
	button.LayoutOrder = nextOrder()
	Widgets.text(button)
	corner(button)
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Selected") ~= true then
			button.BackgroundColor3 = Widgets.Colors.ItemHover
		end
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("Selected") ~= true then
			button.BackgroundColor3 = Widgets.Colors.Item
		end
	end)
	button.Activated:Connect(onClick)
	button.Parent = parent
	return button
end

-- Marks a button as the selected choice (a mode, a role, the loaded map).
function Widgets.select(button: TextButton, selected: boolean, color: Color3?)
	button:SetAttribute("Selected", selected)
	button.BackgroundColor3 = if selected
		then color or Widgets.Colors.Accent
		else Widgets.Colors.Item
end

-- An on/off switch. Returns a function to set it from code (without calling onChange).
function Widgets.toggle(
	parent: Instance,
	text: string,
	initial: boolean,
	onChange: (boolean) -> ()
): (boolean) -> ()
	local on = initial
	local button: TextButton
	local function show()
		button.Text = `{text}: {if on then "ON" else "OFF"}`
		Widgets.select(button, on, Widgets.Colors.On)
	end
	button = Widgets.button(parent, text, function()
		on = not on
		show()
		onChange(on)
	end)
	button.TextXAlignment = Enum.TextXAlignment.Left
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.Parent = button
	show()
	return function(value: boolean)
		on = value
		show()
	end
end

-- A text box for a number. Calls onCommit with the number when Enter is pressed.
function Widgets.numberBox(parent: Instance, initial: number, onCommit: (number) -> ()): TextBox
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Widgets.Colors.Bar
	box.Size = UDim2.new(1, 0, 0, ROW)
	box.ClearTextOnFocus = false
	box.Text = tostring(initial)
	box.LayoutOrder = nextOrder()
	Widgets.text(box)
	corner(box)
	box.FocusLost:Connect(function(enterPressed)
		local value = tonumber(box.Text)
		if enterPressed and value then
			onCommit(value)
		end
	end)
	box.Parent = parent
	return box
end

local function decimals(step: number): number
	local text = string.format("%g", step)
	local dot = string.find(text, ".", 1, true)
	return if dot then #text - dot else 0
end

-- Rounds `value` to the slider's step and shows it with the step's decimals.
function Widgets.formatStep(value: number, step: number): string
	return string.format(`%.{decimals(step)}f`, value)
end

export type Slider = {
	set: (number) -> (), -- move the slider from code (without calling onChange)
	setChanged: (boolean) -> (), -- highlight the name (value differs from the default)
}

-- A named slider with a value box. Calls onChange with values snapped to `step`.
function Widgets.slider(
	parent: Instance,
	name: string,
	min: number,
	max: number,
	step: number,
	value: number,
	onChange: (number) -> ()
): Slider
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.LayoutOrder = nextOrder()

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -70, 0, 18)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name
	Widgets.text(label, 14)
	label.Parent = frame

	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Widgets.Colors.Bar
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.fromScale(1, 0)
	box.Size = UDim2.fromOffset(64, 20)
	box.ClearTextOnFocus = false
	Widgets.text(box, 14)
	corner(box, 4)
	box.Parent = frame

	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = Widgets.Colors.Bar
	track.Position = UDim2.fromOffset(0, 26)
	track.Size = UDim2.new(1, 0, 0, 8)
	corner(track, 4)
	track.Parent = frame

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Widgets.Colors.Accent
	fill.BorderSizePixel = 0
	corner(fill, 4)
	fill.Parent = track

	local current = value
	local function show()
		local t = if max > min then math.clamp((current - min) / (max - min), 0, 1) else 0
		fill.Size = UDim2.fromScale(t, 1)
		box.Text = Widgets.formatStep(current, step)
	end
	local function commit(raw: number)
		local snapped = math.clamp(math.round(raw / step) * step, min, max)
		snapped = tonumber(Widgets.formatStep(snapped, step)) or snapped -- drop float noise
		if snapped ~= current then
			current = snapped
			onChange(current)
		end
		show()
	end

	local dragging = false
	local function dragTo(x: number)
		local t = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		commit(min + t * (max - min))
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	box.FocusLost:Connect(function()
		local typed = tonumber(box.Text)
		if typed then
			commit(typed)
		else
			show()
		end
	end)

	show()
	frame.Parent = parent
	return {
		set = function(newValue: number)
			current = newValue
			show()
		end,
		setChanged = function(changed: boolean)
			label.TextColor3 = if changed then Widgets.Colors.Changed else Widgets.Colors.Text
			label.Text = if changed then `{name} *` else name
		end,
	}
end

return Widgets
