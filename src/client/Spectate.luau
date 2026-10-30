--!strict
-- Spectating. While a game is being played (Intro, Playing, Results) and you're out of it
-- (eliminated, fell off the map, or joined late: the server parks your body and sets your
-- `Spectating` attribute, server/Spectators), the camera follows a player who is still in, in
-- third person. Your controls are off. Q / E, the left / right arrows or the on-screen
-- prev / next buttons switch between them. A Leave button takes you back to the lobby early
-- (you stay out of the game); players still in the game never see this bar.
-- The moment the game ends (the phase leaves Intro/Playing/Results) it all stops: the camera,
-- first person and controls come back for your new lobby character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared:WaitForChild("GameState"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ControlLock = require(script.Parent.ControlLock)
local LockerStage = require(script.Parent.LockerStage)
local Ui = require(script.Parent.Menu.Ui)
local ViewMode = require(script.Parent.ViewMode)

local Spectate = {}

local LOCK = "Spectate"
local GAME_PHASES = { Intro = true, Playing = true, Results = true }
local BAR_WIDTH = 340 -- the name bar
local BUTTON_WIDTH = 104
local RESTORE_TIMEOUT = 5 -- seconds to wait for the new lobby character before giving up
local NEXT_KEYS = {
	[Enum.KeyCode.E] = 1,
	[Enum.KeyCode.Right] = 1,
	[Enum.KeyCode.Q] = -1,
	[Enum.KeyCode.Left] = -1,
}

-- Everyone still in the game, in a stable order (so switching goes round the same way).
local function alivePlayers(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("InGame") and other:GetAttribute("Alive") then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

function Spectate.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local target: Player? = nil
	local spectating = false
	local restoreSince: number? = nil -- set after spectating ends, until the camera is given back
	local lockerWas = false -- the Locker's preview had the camera on the last frame
	local hint = if UserInputService.KeyboardEnabled then "  ·  Q / E TO SWITCH" else ""

	local gui = Instance.new("ScreenGui")
	gui.Name = "Spectate"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	-- A row above the level bar: prev button, a black slanted bar with a cyan edge, next button,
	-- Leave (Menu/Ui style). On a screen too narrow for all of it in one line it wraps: the bar
	-- on top, the three buttons under it.
	local row = Ui.frame(gui)
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -120)
	row.Size = UDim2.new(1, -24, 0, 40)
	row.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Wraps = true
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local function cycle(step: number)
		local list = alivePlayers()
		if #list == 0 then
			target = nil
			return
		end
		local index = if target then table.find(list, target) else nil
		if not index then
			target = list[1]
		else
			target = list[((index - 1 + step) % #list) + 1]
		end
	end

	local prev = Ui.button(row, "Prev", Ui.Colors.Cyan, function()
		cycle(-1)
	end, Ui.Colors.Ink, 8, "play")
	prev.LayoutOrder = 1
	prev.Size = UDim2.fromOffset(104, Ui.hit(36))
	local prevIcon = prev:FindFirstChild("Icon", true)
	if prevIcon and prevIcon:IsA("GuiObject") then
		prevIcon.Rotation = 180 -- the play triangle, pointing left
	end

	local bar = Ui.slab(row, Ui.Colors.Panel, 10)
	bar.LayoutOrder = 2
	bar.Size = UDim2.fromOffset(BAR_WIDTH, 36)
	local edge = Ui.slab(bar, Ui.Colors.Cyan, 10)
	edge.Size = UDim2.new(0, 18, 1, 0)
	edge.ZIndex = 2
	local label = Ui.caps(bar, "", 15, Ui.Colors.Text)
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 3
	Ui.pad(label, 14, 0)
	label.Position = UDim2.fromOffset(22, 0) -- (right of the cyan edge)
	label.Size = UDim2.new(1, -22, 1, 0)
	Ui.shrinkText(label, 11, 15) -- "SPECTATING <20-letter name>" shrinks, then is cut off

	local nextButton = Ui.button(row, "Next", Ui.Colors.Cyan, function()
		cycle(1)
	end, Ui.Colors.Ink, 8, "play")
	nextButton.LayoutOrder = 3
	nextButton.Size = UDim2.fromOffset(104, Ui.hit(36))

	-- Leave: back to the lobby now (only spectators see this bar, so only players who are out).
	local leave = Ui.button(row, "Leave", Ui.Colors.Pink, function()
		Remotes.get("LeaveGame"):FireServer()
	end, Ui.Colors.Ink, 8)
	leave.LayoutOrder = 4
	leave.Size = UDim2.fromOffset(104, Ui.hit(36))

	-- Fit the screen: one line (prev, bar, next, leave) when it fits, else the bar first.
	local function fitScreen()
		local width = gui.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local one = BUTTON_WIDTH * 3 + BAR_WIDTH + 30 <= width - 24
		prev.LayoutOrder = if one then 1 else 2
		bar.LayoutOrder = if one then 2 else 1
		nextButton.LayoutOrder = 3
		bar.Size = UDim2.fromOffset(math.min(BAR_WIDTH, width - 24), 36)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScreen)
	gui.Parent = player:WaitForChild("PlayerGui")
	fitScreen()

	local function shouldSpectate(): boolean
		return GAME_PHASES[GameState.getPhase()] == true
			and player:GetAttribute("Spectating") == true
	end

	local function begin()
		spectating = true
		restoreSince = nil
		gui.Enabled = true
		ViewMode.suspend(true) -- third person, and the first-person body steps aside
		ControlLock.set(LOCK, true)
	end

	-- Spectating is over: controls back at once; the camera and view mode once the new lobby
	-- character is here (the parked body is on its way out).
	local function stop()
		spectating = false
		target = nil
		gui.Enabled = false
		ControlLock.set(LOCK, false)
		restoreSince = os.clock()
	end

	local function restore()
		local since = restoreSince
		if not since then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local parked = character ~= nil and character:GetAttribute("Parked") == true
		if (humanoid and not parked) or os.clock() - since > RESTORE_TIMEOUT then
			if humanoid then
				camera.CameraSubject = humanoid
			end
			ViewMode.suspend(false)
			restoreSince = nil
		end
	end

	RunService.RenderStepped:Connect(function()
		if LockerStage.isActive() then
			lockerWas = true
			return -- the Locker's preview has the camera
		end
		if lockerWas then
			-- Closing the preview gave first person and the controls back: take them again.
			lockerWas = false
			if spectating then
				ViewMode.suspend(true)
				ControlLock.apply()
			end
		end
		if not shouldSpectate() then
			if spectating then
				stop()
			end
			restore()
			return
		end
		if not spectating then
			begin()
		end
		-- Keep watching someone who is still in (they may have been eliminated or left).
		if not target or not target.Parent or not target:GetAttribute("Alive") then
			cycle(1)
		end
		local character = target and target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
		label.Text = if target
			then `SPECTATING {Ui.upper(target.DisplayName)}{hint}`
			else "SPECTATING"
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not spectating then
			return
		end
		local step = NEXT_KEYS[input.KeyCode]
		if step then
			cycle(step)
		end
	end)
end

return Spectate
