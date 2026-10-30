--!strict
-- The HUD at the top of the screen, in the Street sprint style (Menu/Ui):
--   The bar: a slanted black bar with a pink tag for the phase (LOBBY, STARTING, ROUND 2...),
--   the timer in big yellow numbers and how many players are left, a yellow underline and a
--   pink shadow. The status line sits under it.
--   Banners: YOU'RE IT!, RUN!, ELIMINATED, YOU WIN! and "<NAME> WINS!" sweep across the screen
--   as a tilted stripe when they change, then stay as a small tag under the bar (except
--   YOU'RE IT!, which only sweeps: in first person the red ItTint shows you're It). ELIMINATED
--   sweeps while your body is still visible; once you are spectating no banners show.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameState = require(Shared:WaitForChild("GameState"))
local Ui = require(script.Parent.Menu.Ui)

local Hud = {}

local STRIPE_TIME = 2.2 -- seconds a banner's stripe stays before shrinking to the tag

type Banner = { text: string, color: Color3, ink: Color3, sweepOnly: boolean? }

local function phaseTag(): string
	local phase = GameState.getPhase()
	local round = GameState.getRound()
	if phase == "Countdown" then
		return "Starting"
	elseif phase == "Intro" or phase == "Playing" then
		return `Round {round}`
	elseif phase == "Results" then
		return "Results"
	elseif phase == "Victory" then
		return "Victory"
	elseif phase == "Sandbox" then
		return "Sandbox"
	end
	return "Lobby"
end

function Hud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- The bar.
	local bar = Ui.frame(gui)
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 10)
	bar.Size = UDim2.fromOffset(0, 50)
	local shadow = Ui.slab(bar, Ui.Colors.Pink, 14)
	shadow.Position = UDim2.fromOffset(5, 5)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 0
	local back = Ui.slab(bar, Ui.Colors.Panel, 14)
	back.Size = UDim2.fromScale(1, 1)
	local underline = Ui.slab(bar, Ui.Colors.Yellow, 1)
	underline.AnchorPoint = Vector2.new(0, 1)
	underline.Position = UDim2.fromScale(0, 1)
	underline.Size = UDim2.new(1, -13, 0, 4)
	underline.ZIndex = 2
	local content = Ui.frame(bar)
	content.Size = UDim2.new(0, 0, 1, -4)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.ZIndex = 3
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 0)
	pad.PaddingRight = UDim.new(0, 22)
	pad.Parent = content
	local tag = Ui.slab(content, Ui.Colors.Pink, 14)
	tag.LayoutOrder = 1
	tag.Size = UDim2.fromScale(0, 1)
	local tagText = Ui.caps(tag, "", 14, Ui.Colors.Text)
	tagText.Size = UDim2.fromScale(0, 1)
	tagText.AutomaticSize = Enum.AutomaticSize.X
	tagText.ZIndex = 2
	local tagPad = Instance.new("UIPadding")
	tagPad.PaddingLeft = UDim.new(0, 20)
	tagPad.PaddingRight = UDim.new(0, 14)
	tagPad.Parent = tagText
	Ui.fitWidth(tag, tagText)
	local timer = Ui.title(content, "", 38, Ui.Colors.Yellow)
	timer.LayoutOrder = 2
	timer.Size = UDim2.fromScale(0, 1)
	timer.AutomaticSize = Enum.AutomaticSize.X
	local left = Ui.caps(content, "", 14, Ui.Colors.Text)
	left.LayoutOrder = 3
	left.Size = UDim2.fromScale(0, 1)
	left.AutomaticSize = Enum.AutomaticSize.X
	Ui.fitWidth(bar, content)

	local status = Ui.caps(gui, "", 14, Ui.Colors.Text)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 68)
	status.Size = UDim2.fromOffset(560, 20)
	status.TextWrapped = true
	Ui.stroke(status, 2)

	-- The small tag that stays under the bar while a banner lasts.
	local roleTag = Ui.slab(gui, Ui.Colors.Yellow, 8)
	roleTag.AnchorPoint = Vector2.new(0.5, 0)
	roleTag.Position = UDim2.new(0.5, 0, 0, 92)
	roleTag.Size = UDim2.fromOffset(0, 26)
	roleTag.Visible = false
	local roleText = Ui.caps(roleTag, "", 14, Ui.Colors.Ink)
	roleText.Size = UDim2.fromScale(0, 1)
	roleText.AutomaticSize = Enum.AutomaticSize.X
	local rolePad = Instance.new("UIPadding")
	rolePad.PaddingLeft = UDim.new(0, 18)
	rolePad.PaddingRight = UDim.new(0, 18)
	rolePad.Parent = roleText
	Ui.fitWidth(roleTag, roleText)

	-- A stripe across the screen for a new banner.
	local function sweep(banner: Banner)
		local band = Ui.frame(gui, banner.color)
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.3)
		band.Size = UDim2.new(1.3, 0, 0, 84)
		band.Rotation = -3
		band.ZIndex = 20
		for _, edge in { 0, 1 } do
			local line = Ui.frame(band, Ui.Colors.Ink)
			line.AnchorPoint = Vector2.new(0, edge)
			line.Position = UDim2.fromScale(0, edge)
			line.Size = UDim2.new(1, 0, 0, 5)
		end
		local echo = Ui.title(band, banner.text, 60, Ui.Colors.Pink)
		echo.Position = UDim2.fromOffset(4, 4)
		echo.Size = UDim2.fromScale(1, 1)
		local label = Ui.title(band, banner.text, 60, banner.ink)
		label.Size = UDim2.fromScale(1, 1)
		Ui.popIn(band, 0.25)
		task.delay(STRIPE_TIME, function()
			local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(band, info, { Position = UDim2.fromScale(1.6, 0.3) }):Play()
			task.delay(0.3, band.Destroy, band)
		end)
	end

	local shown: string? = nil
	local function showBanner(banner: Banner?)
		local text = if banner then banner.text else nil
		if text == shown then
			return
		end
		shown = text
		roleTag.Visible = banner ~= nil and not banner.sweepOnly
		if banner then
			roleText.Text = Ui.upper(banner.text)
			roleText.TextColor3 = banner.ink
			Ui.paint(roleTag, banner.color)
			sweep(banner)
		end
	end

	local function refresh()
		local phase = GameState.getPhase()
		tagText.Text = Ui.upper(phaseTag())
		local timed = phase == "Countdown" or phase == "Intro" or phase == "Playing"
		timer.Visible = timed
		timer.Text = Ui.clock(GameState.getTimeLeft())
		local inGame = phase == "Intro" or phase == "Playing" or phase == "Results"
		left.Visible = inGame
		left.Text = `{GameState.getAliveCount()} LEFT`
		status.Text = Ui.upper(GameState.getStatus())

		-- Spectators see the game, not role banners.
		local spectating = player:GetAttribute("Spectating") == true
		local role = if spectating then nil else player:GetAttribute("Role")
		local winner = ReplicatedStorage:GetAttribute("Winner")
		local eliminated = not spectating
			and player:GetAttribute("InGame") == true
			and player:GetAttribute("Alive") == false
		if phase == "Victory" and winner then
			showBanner(if winner == player.Name
				then { text = "You win!", color = Ui.Colors.Gold, ink = Ui.Colors.Ink }
				else {
					text = `{winner} wins!`,
					color = Ui.Colors.Text,
					ink = Ui.Colors.Ink,
				})
		elseif eliminated then
			showBanner({ text = "Eliminated", color = Ui.Colors.Panel, ink = Ui.Colors.Red })
		elseif role == "It" then
			showBanner({
				text = "You're it!",
				color = Ui.Colors.Yellow,
				ink = Ui.Colors.Ink,
				sweepOnly = true,
			})
		elseif role == "Runner" then
			showBanner({ text = "Run!", color = Ui.Colors.Cyan, ink = Ui.Colors.Ink })
		else
			showBanner(nil)
		end
	end

	GameState.onChanged(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("Winner"):Connect(refresh)
	for _, name in { "Role", "InGame", "Alive", "Spectating" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
