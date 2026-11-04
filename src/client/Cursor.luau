--!strict
-- The mouse in first person. First person locks the mouse to the screen centre (so it can't wander
-- off the game window onto another monitor), and while it's locked the arrow is hidden and a
-- small hollow aim ring sits at the centre instead (Config.Cursor.Crosshair; red while you're It
-- and a Runner is in reach, client/TagSwing). The mouse is freed
-- (a Modal button, the trick Roblox uses to unlock it) only when:
--   - you hold Config.Cursor.Key (Left Alt), for as long as you hold it;
--   - something holds it: the menu window while it's open (Cursor.hold). So clicking a side
--     button keeps the mouse free until you close the page, even if you let go of Alt;
--   - you're in the lobby waiting (phase Lobby or Countdown), if Config.Cursor.FreeInLobby (off).
-- While the mouse is free, the first-person camera turns with the right mouse button held
-- (Roblox's usual free-mouse look). A free mouse can still leave a windowed game; only the lock
-- keeps it in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(Shared:WaitForChild("GameState"))
local Ui = require(script.Parent.Menu.Ui)
local ViewMode = require(script.Parent.ViewMode)

local Cursor = {}

local holds: { [string]: boolean } = {}
local keyHeld = false
local mainRing: UIStroke? = nil -- the aim ring's white stroke
local hot = false

-- Something (a window) needs the mouse while `on`.
function Cursor.hold(name: string, on: boolean)
	holds[name] = if on then true else nil
end

-- Turns the aim ring Config.Tag.AimHotColor while `on` (client/TagSwing: you're It and a Runner
-- is in reach).
function Cursor.setHot(on: boolean)
	if on == hot then
		return
	end
	hot = on
	if mainRing then
		mainRing.Color = if on then Config.Tag.AimHotColor else Config.Cursor.Crosshair.Color
	end
end

-- Is the mouse free right now?
function Cursor.isFree(): boolean
	if keyHeld or next(holds) ~= nil then
		return true
	end
	if Config.Cursor.FreeInLobby then
		local phase = GameState.getPhase()
		return phase == "Lobby" or phase == "Countdown"
	end
	return false
end

-- A ring of `thickness` round a hole `size` across, centred on its parent.
local function ring(parent: Instance, size: number, thickness: number, color: Color3, fade: number)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke") -- drawn just outside the frame
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.Transparency = fade
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

-- The aim ring: white, with a thin dark edge just inside and just outside it.
local function crosshair(player: Player): ScreenGui
	local look = Config.Cursor.Crosshair
	local gui = Instance.new("ScreenGui")
	gui.Name = "Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the centre of the whole screen, where the locked mouse is
	gui.DisplayOrder = 5
	gui.Enabled = false
	local edge = look.EdgeThickness
	ring(gui, look.Size - 2 * edge, edge, look.Edge, look.EdgeTransparency)
	local main = ring(gui, look.Size, look.Thickness, look.Color, 0)
	mainRing = main:FindFirstChildOfClass("UIStroke")
	ring(gui, look.Size + 2 * look.Thickness, edge, look.Edge, look.EdgeTransparency)
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function Cursor.start()
	local player = Players.LocalPlayer
	local settings = Config.Cursor

	local gui = Instance.new("ScreenGui")
	gui.Name = "Cursor"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10
	local modal = Instance.new("TextButton")
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Size = UDim2.fromOffset(0, 0)
	modal.Modal = false
	modal.Parent = gui

	-- A quiet reminder while the mouse is locked in first person.
	local hint = Ui.caps(gui, `HOLD {settings.KeyName} FOR MOUSE`, 12, Ui.Colors.Dim)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 16, 1, -14)
	hint.Size = UDim2.fromOffset(220, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local aim = crosshair(player)

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == settings.Key then
			keyHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == settings.Key then
			keyHeld = false
		end
	end)
	-- Alt-tabbing away would leave the key "held".
	UserInputService.WindowFocusReleased:Connect(function()
		keyHeld = false
	end)

	local iconHidden = false
	RunService.Heartbeat:Connect(function()
		local free = Cursor.isFree()
		if modal.Modal ~= free then
			modal.Modal = free
		end
		local locked = not free and ViewMode.isFirstPerson()
		aim.Enabled = locked
		hint.Visible = locked and not UserInputService.TouchEnabled
		-- The arrow hides while the ring stands in for it, and comes back the moment it's free
		-- (or anything else has the camera: spectating, the win screen, the Locker).
		if iconHidden ~= locked then
			iconHidden = locked
			UserInputService.MouseIconEnabled = not locked
		end
	end)
end

return Cursor
