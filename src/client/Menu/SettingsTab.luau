--!strict
-- Menu, Settings page: the sound. A Music slider (the lobby's music and the quiet round music),
-- a Sound effects slider (the game, the maps' ambience, victories), a UI slider (the menus'
-- clicks, buys, claims, the crate reel, level ups) and a Mute all button. Changes apply at once and are saved in your profile (client/Sounds,
-- server/Settings).
local UserInputService = game:GetService("UserInputService")

local Sounds = require(script.Parent.Parent.Sounds)
local Ui = require(script.Parent.Ui)

local SettingsTab = {}

local ROW = 56 -- each slider row's height
local BAR = 16 -- the slider bar's height
local VALUE_W = 72 -- the percentage on the right
local SLANT = 6
local NARROW_BELOW = 460 -- under this the label sits over its bar

type Slider = { row: Frame, label: TextLabel, value: TextLabel, track: Frame, fill: Frame }

local function slider(parent: Instance, text: string, field: string): Slider
	local row = Ui.frame(parent)
	local label = Ui.caps(row, text, 16, Ui.Colors.Text)
	label.TextXAlignment = Enum.TextXAlignment.Left
	Ui.shrinkText(label, 11, 16)
	local value = Ui.title(row, "", 26, Ui.Colors.Purple)
	value.AnchorPoint = Vector2.new(1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	local track = Ui.slab(row, Ui.Colors.Track, SLANT)
	local fill = Ui.slab(track, Ui.Colors.Purple, SLANT)
	fill.Name = "Fill"
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(SLANT * 2 + 2, 0)
	limit.Parent = fill

	-- Click or drag anywhere along the bar (a taller invisible strip over it, easy to hit).
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit:SetAttribute("Silent", true) -- no generic click; it plays its own on release
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AnchorPoint = Vector2.new(0, 0.5)
	hit.Position = UDim2.fromScale(0, 0.5)
	hit.Size = UDim2.new(1, 0, 0, Ui.hit(36))
	hit.ZIndex = 6
	hit.Parent = track
	local dragging = false
	local function setFrom(x: number)
		local width = track.AbsoluteSize.X
		if width > 0 then
			Sounds.set(field, (x - track.AbsolutePosition.X) / width)
		end
	end
	hit.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFrom(input.Position.X)
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
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragging = false
			if field == "Ui" then
				Sounds.play("ui_click") -- hear the new level
			elseif field == "Sfx" then
				Sounds.play("swing")
			end
		end
	end)
	return { row = row, label = label, value = value, track = track, fill = fill }
end

function SettingsTab.build(page: Frame, _api: { [string]: any }): () -> ()
	local heading = Ui.title(page, "Sound", 30, Ui.Colors.Purple)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	local music = slider(page, "Music", "Music")
	local sfx = slider(page, "Sound effects", "Sfx")
	local ui = slider(page, "UI", "Ui")
	local mute = Ui.button(page, "Mute all sound", Ui.Colors.Pink, function()
		Sounds.set("Muted", not Sounds.settings().Muted)
	end, Ui.Colors.Text)
	local note = Ui.caps(
		page,
		"Music plays in the lobby and on maps without their own sounds. UI is the menus: clicks, buying, claiming, crates and level ups. Sound effects are everything else: the game, the maps and the victories.",
		13,
		Ui.Colors.Dim
	)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.TextWrapped = true

	local function show(settings: Sounds.Settings)
		for _, pair in { { music, settings.Music }, { sfx, settings.Sfx }, { ui, settings.Ui } } do
			local s, level = pair[1] :: Slider, pair[2] :: number
			s.fill.Size = UDim2.fromScale(level, 1)
			s.fill.Visible = level > 0.005
			s.value.Text = `{math.floor(level * 100 + 0.5)}%`
			Ui.paint(s.fill, if settings.Muted then Ui.Colors.Dim else Ui.Colors.Purple)
			s.value.TextColor3 = if settings.Muted then Ui.Colors.Dim else Ui.Colors.Purple
		end
		Ui.setText(mute, if settings.Muted then "Turn sound on" else "Mute all sound")
		Ui.setColor(
			mute,
			if settings.Muted then Ui.Colors.Lime else Ui.Colors.Pink,
			if settings.Muted then Ui.Colors.Ink else Ui.Colors.Text
		)
	end
	Sounds.onSettings(show)

	local function layout()
		local width = Ui.bodySize(page).X
		local narrow = width < NARROW_BELOW
		local labelWidth = if narrow then 0 else math.min(200, width * 0.32)
		heading.Size = UDim2.new(1, 0, 0, 36)
		local y = 46
		for _, s in { music, sfx, ui } do
			local height = if narrow then ROW + 20 else ROW
			s.row.Position = UDim2.fromOffset(0, y)
			s.row.Size = UDim2.new(1, 0, 0, height)
			local barTop = if narrow then 24 else (ROW - BAR) / 2
			s.label.Position = UDim2.fromOffset(0, 0)
			s.label.Size = if narrow
				then UDim2.new(1, -VALUE_W, 0, 22)
				else UDim2.new(0, labelWidth - 12, 1, 0)
			s.value.Position = UDim2.fromScale(1, 0)
			s.value.Size = UDim2.fromOffset(VALUE_W, if narrow then 22 else ROW)
			s.track.Position = UDim2.fromOffset(labelWidth, barTop)
			s.track.Size = UDim2.new(1, -labelWidth - (if narrow then 0 else VALUE_W + 8), 0, BAR)
			y += height + 10
		end
		mute.Position = UDim2.fromOffset(0, y + 6)
		mute.Size = UDim2.fromOffset(220, Ui.hit(40))
		note.Position = UDim2.fromOffset(0, y + 6 + Ui.hit(40) + 16)
		note.Size = UDim2.new(1, 0, 0, 80)
		show(Sounds.settings())
	end
	layout()
	return layout
end

return SettingsTab
