--!strict
-- The mouse in first person. First person locks the mouse to the screen centre, so the side
-- menu buttons can't be clicked. The mouse is freed (a Modal button, the trick Roblox uses to
-- unlock it) when:
--   - you hold Config.Cursor.Key (Left Alt), for as long as you hold it;
--   - you're in the lobby waiting (phase Lobby or Countdown), if Config.Cursor.FreeInLobby;
--   - something holds it: the menu window while it's open, and popups while any are showing
--     (Cursor.hold). So clicking a side panel keeps the mouse free until you close it and no
--     popup is left, even if you let go of Alt.
-- In a round it's locked again as soon as none of those apply. While the mouse is free, the
-- first-person camera turns with the right mouse button held (Roblox's usual free-mouse look).
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

-- Something (a window, popups) needs the mouse while `on`.
function Cursor.hold(name: string, on: boolean)
	holds[name] = if on then true else nil
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

	RunService.Heartbeat:Connect(function()
		local free = Cursor.isFree()
		if modal.Modal ~= free then
			modal.Modal = free
		end
		hint.Visible = not free and ViewMode.isFirstPerson() and not UserInputService.TouchEnabled
	end)
end

return Cursor
