--!strict
-- First person, while you're It: a faint red tint over the screen that gets darker toward the
-- edges (your red highlight is hidden on your own screen in first person, so this is the
-- reminder). Built from a faint wash plus four edge gradients; the corners, where two edges
-- overlap, come out darkest, like a vignette. Fades in and out (Config.FirstPerson.ItTint).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local Ui = require(script.Parent.Menu.Ui)
local ViewMode = require(script.Parent.ViewMode)

local ItTint = {}

function ItTint.start()
	local settings = Config.FirstPerson.ItTint
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "ItTint"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the HUD and menus
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Visible = false
	group.Parent = gui

	local wash = Ui.frame(group, settings.Color)
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundTransparency = settings.Wash

	-- Darkest at the edge, easing out to nothing `reach` of the way in.
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, settings.Edge),
		NumberSequenceKeypoint.new(0.35, settings.Edge + (1 - settings.Edge) * 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	local function edge(size: UDim2, anchor: Vector2, rotation: number)
		local band = Ui.frame(group, settings.Color)
		band.AnchorPoint = anchor
		band.Position = UDim2.fromScale(anchor.X, anchor.Y)
		band.Size = size
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = fade
		gradient.Rotation = rotation
		gradient.Parent = band
	end
	local reach, side = settings.Reach, settings.Reach * settings.SideReach
	edge(UDim2.fromScale(1, reach), Vector2.new(0, 0), 90) -- top, fading down
	edge(UDim2.fromScale(1, reach), Vector2.new(0, 1), -90) -- bottom, fading up
	edge(UDim2.fromScale(side, 1), Vector2.new(0, 0), 0) -- left, fading right
	edge(UDim2.fromScale(side, 1), Vector2.new(1, 0), 180) -- right, fading left

	local shown = 0
	RunService.RenderStepped:Connect(function(dt)
		local on = ViewMode.isFirstPerson()
			and player:GetAttribute("Role") == "It"
			and MoveState.parts() ~= nil
		local step = dt / math.max(settings.FadeTime, 0.01)
		shown = math.clamp(shown + (if on then step else -step), 0, 1)
		group.Visible = shown > 0
		group.GroupTransparency = 1 - shown
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return ItTint
