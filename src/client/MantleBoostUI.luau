--!strict
-- The Mantle Boost timing indicator (Apex style). While you climb, brackets close in on a center
-- ring and a marker drops toward it. They meet when the boost window opens: the ring turns
-- cyan, and pressing jump then boosts you (a check appears). Too early greys it out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MantleBoostUI = {}

local RING = 56 -- center ring size in pixels
local BRACKETS_START = 150 -- bracket ring size when the climb starts
local BRACKETS_END = 76 -- bracket ring size when the window opens
local MARKER_DROP = 70 -- pixels above center the marker starts
local SUCCESS_TIME = 0.4 -- seconds the check stays up after a boost

local gui: ScreenGui? = nil
local ring: UIStroke? = nil
local brackets: Frame? = nil
local bracketStroke: UIStroke? = nil
local marker: Frame? = nil
local check: TextLabel? = nil
local connection: RBXScriptConnection? = nil
local missed = false -- pressed too early this climb

local function stroke(parent: Instance, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = Config.Colors.Text
	s.Parent = parent
	return s
end

local function circle(parent: Instance, size: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- Builds the indicator once and keeps it hidden until a climb starts.
local function build()
	if gui then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "MantleBoost"
	screen.ResetOnSpawn = false
	screen.Enabled = false

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.45)
	holder.Size = UDim2.fromOffset(BRACKETS_START, BRACKETS_START + MARKER_DROP)
	holder.BackgroundTransparency = 1
	holder.Parent = screen

	ring = stroke(circle(holder, RING), 4)

	-- The brackets: a ring with its top and bottom faded out, so only "(" and ")" show.
	local outer = circle(holder, BRACKETS_START)
	local outerStroke = stroke(outer, 4)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(0.36, 1),
		NumberSequenceKeypoint.new(0.64, 1),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = outerStroke
	brackets, bracketStroke = outer, outerStroke

	local drop = Instance.new("Frame")
	drop.AnchorPoint = Vector2.new(0.5, 0.5)
	drop.Size = UDim2.fromOffset(12, 12)
	drop.BackgroundColor3 = Config.Colors.Text
	drop.BorderSizePixel = 0
	stroke(drop, 2).Color = Config.Colors.HudBackground
	drop.Parent = holder
	marker = drop

	local tick = Instance.new("TextLabel")
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position = UDim2.new(0.5, 0, 0.5, RING / 2 + 6)
	tick.Size = UDim2.fromOffset(40, 40)
	tick.BackgroundTransparency = 1
	tick.Text = "✓"
	tick.TextSize = 40
	tick.Font = Config.Ui.Font
	tick.TextColor3 = Config.Colors.Text
	tick.TextStrokeTransparency = 0.3
	tick.Visible = false
	tick.Parent = holder
	check = tick

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
end

local function setColor(color: Color3)
	(ring :: UIStroke).Color = color;
	(bracketStroke :: UIStroke).Color = color;
	(marker :: Frame).BackgroundColor3 = color
end

local function stopAnimating()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

local function hide()
	stopAnimating()
	if gui then
		gui.Enabled = false
	end
end

-- Starts the indicator. The window is in seconds from now.
function MantleBoostUI.begin(windowStart: number, windowEnd: number)
	build()
	stopAnimating()
	local colors = Config.Colors
	setColor(colors.Text);
	(check :: TextLabel).Visible = false
	(gui :: ScreenGui).Enabled = true

	local start = os.clock()
	missed = false
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local p = math.clamp(t / windowStart, 0, 1)
		local size = BRACKETS_START + (BRACKETS_END - BRACKETS_START) * p;
		(brackets :: Frame).Size = UDim2.fromOffset(size, size);
		(marker :: Frame).Position = UDim2.new(0.5, 0, 0.5, -MARKER_DROP * (1 - p))
		if missed then
			return
		end
		if t >= windowStart and t <= windowEnd then
			setColor(colors.BoostReady)
		elseif t > windowEnd then
			setColor(colors.BoostMissed)
		end
	end)
end

-- Pressed too early: grey it out for the rest of the climb.
function MantleBoostUI.miss()
	if gui then
		missed = true
		setColor(Config.Colors.BoostMissed)
	end
end

-- Boost landed: show the check, then hide.
function MantleBoostUI.success()
	if not gui then
		return
	end
	stopAnimating()
	setColor(Config.Colors.BoostReady);
	(check :: TextLabel).Visible = true
	task.delay(SUCCESS_TIME, function()
		if not connection then
			hide()
		end
	end)
end

-- Climb finished without a boost.
function MantleBoostUI.hide()
	hide()
end

return MantleBoostUI
