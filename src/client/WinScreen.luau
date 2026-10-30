--!strict
-- The win screen. When a game ends the server sends GameOver (server/GameLoop): the podium (the
-- winner and the last players out, best first) and, for players who were in the game, their own
-- place, coins, XP, crates and new items for it (server/GameRewards). Every screen then builds a
-- small stage far from everything (like client/LockerStage, on this screen only), with copies of
-- the podium players' characters on 1st, 2nd and 3rd blocks, the winner playing their equipped
-- Victory (client/Victories), a scripted camera, name plates under the blocks, a headline,
-- and your own rewards card sliding in. Your controls, first person and the HUD and menu are off
-- while it plays; it ends after the server's Duration (long enough for the winner's victory,
-- Catalog.winScreenTime) or as soon as the
-- game phase leaves Victory (the dev panel skipping it, or switching modes).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(Shared:WaitForChild("GameState"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local ControlLock = require(script.Parent.ControlLock)
local LockerStage = require(script.Parent.LockerStage)
local MapLighting = require(script.Parent.MapLighting)
local SpeedTrails = require(script.Parent.SpeedTrails)
local Ui = require(script.Parent.Menu.Ui)
local Victories = require(script.Parent.Victories)
local ViewMode = require(script.Parent.ViewMode)

local WinScreen = {}

local STEP = "WinScreen"
local LOCK = "WinScreen"
local FACE_CAMERA = CFrame.Angles(0, math.pi, 0) -- facing +Z, toward the camera
local BLOCK_WIDTH = 9
local BLOCK_DEPTH = 8
local SPACING = 11 -- between block centers
local ORDINALS = { "1ST", "2ND", "3RD" }
local PLACE_COLORS = {
	Ui.Colors.Gold,
	Color3.fromRGB(205, 212, 224),
	Color3.fromRGB(205, 127, 50),
}
local INTRO_MOVE = 2.4 -- seconds the camera takes to push in
local WAIT_FOR_CHARACTER = 3 -- seconds to wait for a podium player's character to arrive

type Entry = { UserId: number, Name: string, DisplayName: string, Place: number, Won: boolean }
type Rewards = {
	Coins: number,
	XP: number,
	Crates: number,
	Items: { string },
	LevelFrom: number,
	LevelTo: number,
	Place: number,
	Of: number,
}
type Info = {
	Podium: { Entry },
	Duration: number,
	Rewards: Rewards?,
	Preview: boolean?, -- the dev panel's preview: not tied to the game phase, click to close
	PreviewVictory: string?, -- the Victory item to play instead of the winner's equipped one
}

local active = false
local session = 0 -- counts screens, so late work from an earlier one gives up
local stage: Model? = nil
local gui: ScreenGui? = nil
local hiddenGuis: { [ScreenGui]: boolean } = {}

local function ordinal(n: number): string
	return ORDINALS[n] or `{n}TH`
end

-- The x of a podium place on the stage: 1st in the middle, 2nd to its left, 3rd to its right.
local function blockX(place: number): number
	if place == 2 then
		return -SPACING
	elseif place == 3 then
		return SPACING
	end
	return 0
end

local function part(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A big place number on the front of a block (the face toward the camera, +Z).
local function number(block: Part, place: number, color: Color3)
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Back
	face.LightInfluence = 0.3
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 40
	local label = Ui.title(face, tostring(place), 200, color)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	face.Parent = block
end

-- The stage: a dark floor, a navy wall with neon slashes, and a block per podium place.
-- Returns it, the middle of each place's block top, and each place's block.
local function buildStage(places: { number }): (Model, { [number]: Vector3 }, { [number]: Part })
	local origin = Config.WinScreen.Position
	local heights = Config.WinScreen.StepHeights
	local model = Instance.new("Model")
	model.Name = "WinScreenStage"
	part(
		model,
		Vector3.new(120, 2, 60),
		CFrame.new(origin + Vector3.new(0, -1, 8)),
		Color3.fromRGB(38, 38, 44),
		Enum.Material.Asphalt
	)
	part(
		model,
		Vector3.new(120, 46, 2),
		CFrame.new(origin + Vector3.new(0, 22, -14)),
		Color3.fromRGB(24, 32, 50)
	)
	part(
		model,
		Vector3.new(120, 1, 0.3),
		CFrame.new(origin + Vector3.new(0, 0.5, -12.9)),
		Ui.Colors.Yellow,
		Enum.Material.Neon
	)
	local accents = { Ui.Colors.Pink, Ui.Colors.Cyan }
	for i = -2, 2 do
		part(
			model,
			Vector3.new(3, 52, 0.2),
			CFrame.new(origin + Vector3.new(i * 22, 22, -12.85))
				* CFrame.Angles(0, 0, math.rad(-24)),
			accents[i % 2 + 1],
			Enum.Material.Neon,
			0.45
		)
	end
	-- A soft key light from the camera's side, so the podium players are lit from the front.
	local key = part(
		model,
		Vector3.new(1, 1, 1),
		CFrame.lookAt(origin + Vector3.new(0, 18, 30), origin + Vector3.new(0, 6, 0)),
		Color3.new(1, 1, 1),
		nil,
		1
	)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 70
	spot.Range = 60
	spot.Brightness = 1.6
	spot.Color = Color3.fromRGB(255, 244, 232)
	spot.Parent = key
	local tops: { [number]: Vector3 } = {}
	local blocks: { [number]: Part } = {}
	for _, place in places do
		local height = heights[place] or heights[#heights]
		local color = PLACE_COLORS[place] or PLACE_COLORS[#PLACE_COLORS]
		local center = origin + Vector3.new(blockX(place), height / 2, 0)
		local block =
			part(model, Vector3.new(BLOCK_WIDTH, height, BLOCK_DEPTH), CFrame.new(center), color)
		block.Name = `Block{place}`
		blocks[place] = block
		number(block, place, Ui.Colors.Ink)
		tops[place] = origin + Vector3.new(blockX(place), height, 0)
		local lamp = part(
			model,
			Vector3.new(1, 1, 1),
			CFrame.new(origin + Vector3.new(blockX(place), height + 10, 8)),
			Color3.new(1, 1, 1),
			nil,
			1
		)
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = if place == 1 then 1.2 else 0.8
		light.Color = Color3.fromRGB(255, 244, 228)
		light.Parent = lamp
	end
	model.Parent = workspace
	return model, tops, blocks
end

-- Animation objects from a character's Animate script (it doesn't run on the copy).
local function animationFrom(character: Model, folder: string, name: string): Animation?
	local animate = character:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(folder)
	local animation = holder and holder:FindFirstChild(name)
	return if animation and animation:IsA("Animation") then animation else nil
end

-- A copy of a player's character to pose: no scripts, sounds or highlights, nothing that
-- collides, only its root anchored so it stays where it's put. Their title stays over the head.
-- Returns it, the height of its root over the ground, and its idle animation.
local function makeCopy(character: Model): (Model?, number, Animation?)
	local idle = animationFrom(character, "idle", "Animation1")
	local archivable = character.Archivable
	character.Archivable = true
	local ok, result = pcall(function()
		return character:Clone()
	end)
	character.Archivable = archivable
	if not ok or not result then
		return nil, 0, nil
	end
	local model = result :: Model
	for _, item in model:GetDescendants() do
		if
			item:IsA("BaseScript")
			or item:IsA("Sound")
			or item:IsA("ForceField")
			or item:IsA("Highlight")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.LocalTransparencyModifier = 0
		end
	end
	SpeedTrails.stripCopy(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, 0, nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	root.Anchored = true
	model.Name = "PodiumCopy"
	return model, humanoid.HipHeight + root.Size.Y / 2, idle
end

-- Waits for a player's lobby character (the server has just respawned everyone).
local function waitForCharacter(player: Player): Model?
	local waited = 0
	while waited < WAIT_FOR_CHARACTER do
		local character = player.Character
		if
			character
			and character:GetAttribute("Parked") ~= true
			and character:FindFirstChildOfClass("Humanoid")
			and character:FindFirstChild("HumanoidRootPart")
			and character:FindFirstChild("Head")
		then
			return character
		end
		waited += task.wait(0.1)
	end
	return nil
end

local function controlsOn(on: boolean)
	ControlLock.set(LOCK, on)
end

-- Hides the HUD, menu and other screens (by name), remembering what was on.
local function hideGuis()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for _, name in Config.WinScreen.HideGuis do
		local other = playerGui:FindFirstChild(name)
		if other and other:IsA("ScreenGui") then
			hiddenGuis[other] = other.Enabled
			other.Enabled = false
		end
	end
end

local function showGuis()
	for other, wasOn in hiddenGuis do
		if other.Parent then
			other.Enabled = wasOn
		end
	end
	table.clear(hiddenGuis)
end

-- A name plate under a block: the place in the block's color, then the name.
local function plate(parent: Instance, entry: Entry): Frame
	local color = PLACE_COLORS[entry.Place] or PLACE_COLORS[#PLACE_COLORS]
	local back = Ui.slab(parent, Ui.Colors.Panel, 8)
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Size = UDim2.fromOffset(230, 44)
	back.Visible = false
	local edge = Ui.slab(back, color, 8)
	edge.Size = UDim2.new(0, 64, 1, 0)
	edge.ZIndex = 2
	local place =
		Ui.title(edge, if entry.Won then "WIN" else ordinal(entry.Place), 26, Ui.Colors.Ink)
	place.Size = UDim2.fromScale(1, 1)
	place.ZIndex = 3
	local name = Ui.caps(back, entry.DisplayName, 17, Ui.Colors.Text)
	name.Position = UDim2.fromOffset(72, 0)
	name.Size = UDim2.new(1, -80, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 3
	return back
end

-- The headline across the top: "<NAME> WINS!", or "GAME OVER" when nobody won.
local function headline(parent: Instance, text: string)
	local holder = Ui.frame(parent)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 24)
	holder.Size = UDim2.fromOffset(0, 74)
	local shadow = Ui.slab(holder, Ui.Colors.Pink, 16)
	shadow.Position = UDim2.fromOffset(6, 6)
	shadow.Size = UDim2.fromScale(1, 1)
	local back = Ui.slab(holder, Ui.Colors.Yellow, 16)
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 2
	local label = Ui.title(back, Ui.upper(text), 52, Ui.Colors.Ink)
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.ZIndex = 3
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 36)
	pad.PaddingRight = UDim.new(0, 36)
	pad.Parent = label
	Ui.fitWidth(holder, label)
	Ui.popIn(holder, 0.4)
	return holder
end

local function line(parent: Instance, order: number): Frame
	local row = Ui.frame(parent)
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 28)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

local function word(parent: Instance, text: string, color: Color3, order: number): TextLabel
	local label = Ui.caps(parent, text, 17, color)
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	return label
end

-- Your rewards card: your place, then what you earned this game. Returns it (positioned just
-- below the screen; the caller slides it in).
local function rewardsCard(parent: Instance, rewards: Rewards): Frame
	local rows: { (Frame) -> () } = {}
	if rewards.Coins > 0 then
		table.insert(rows, function(row)
			local amount = Ui.coinAmount(row, rewards.Coins, 20, Ui.Colors.Yellow)
			amount.LayoutOrder = 1
			word(row, "COINS", Ui.Colors.Dim, 2)
		end)
	end
	if rewards.XP > 0 then
		table.insert(rows, function(row)
			word(row, `+{Ui.number(rewards.XP)} XP`, Ui.Colors.XP, 1)
		end)
	end
	if rewards.LevelTo > rewards.LevelFrom then
		table.insert(rows, function(row)
			word(row, `LEVEL UP!  {rewards.LevelFrom} TO {rewards.LevelTo}`, Ui.Colors.Lime, 1)
		end)
	end
	if rewards.Crates > 0 then
		table.insert(rows, function(row)
			word(
				row,
				`+{rewards.Crates} CRATE{if rewards.Crates == 1 then "" else "S"}`,
				Ui.Colors.Pink,
				1
			)
		end)
	end
	for _, id in rewards.Items do
		local item = Catalog.get(id)
		if item then
			table.insert(rows, function(row)
				word(row, "NEW", Ui.Colors.Dim, 1)
				word(row, Ui.upper(item.name), Ui.rarityColor(item.rarity), 2)
			end)
		end
	end
	if #rows == 0 then
		table.insert(rows, function(row)
			word(row, "NOTHING EARNED THIS GAME", Ui.Colors.Dim, 1)
		end)
	end

	local width = 360
	local height = 20 + 38 + #rows * 28 + 16
	local card = Ui.panel(parent, Ui.Colors.Panel, 14)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, height + 40) -- off the bottom
	card.Size = UDim2.fromOffset(width, height)
	local header = Ui.slab(card, Ui.Colors.Yellow, 8)
	header.Position = UDim2.fromOffset(14, 14)
	header.Size = UDim2.new(1, -28, 0, 34)
	header.ZIndex = 2
	local title = Ui.caps(header, "YOUR REWARDS", 16, Ui.Colors.Ink)
	title.Position = UDim2.fromOffset(18, 0)
	title.Size = UDim2.fromScale(0.55, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	local finish = Ui.caps(header, `{ordinal(rewards.Place)} OF {rewards.Of}`, 16, Ui.Colors.Ink)
	finish.AnchorPoint = Vector2.new(1, 0)
	finish.Position = UDim2.new(1, -18, 0, 0)
	finish.Size = UDim2.fromScale(0.4, 1)
	finish.TextXAlignment = Enum.TextXAlignment.Right
	finish.ZIndex = 3
	local list = Ui.frame(card)
	list.ZIndex = 2
	list.Position = UDim2.fromOffset(26, 58)
	list.Size = UDim2.new(1, -52, 1, -70)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i, build in rows do
		build(line(list, i))
	end
	return card
end

local function closeScreen()
	if not active then
		return
	end
	active = false
	session += 1
	RunService:UnbindFromRenderStep(STEP)
	Victories.stop()
	if gui then
		gui:Destroy()
		gui = nil
	end
	if stage then
		stage:Destroy()
		stage = nil
	end
	showGuis()
	MapLighting.override(nil)
	-- Fade back in from black on the lobby, so the jump (and its lighting settling) isn't seen.
	local back = Instance.new("ScreenGui")
	back.Name = "WinScreenReturn"
	back.IgnoreGuiInset = true
	back.DisplayOrder = 40
	local black = Ui.frame(back, Color3.new(0, 0, 0))
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundTransparency = 0
	back.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	task.delay(0.35, function()
		TweenService:Create(black, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end)
	task.delay(0.9, function()
		back:Destroy()
	end)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	ViewMode.suspend(false)
	controlsOn(false)
end

local function openScreen(info: Info)
	if active then
		closeScreen()
	end
	local podium = info.Podium
	if #podium == 0 then
		return
	end
	if LockerStage.isActive() then
		LockerStage.close()
	end
	active = true
	session += 1
	local mine = session
	local settings = Config.WinScreen
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera

	local places = {}
	for _, entry in podium do
		table.insert(places, entry.Place)
	end
	local model, tops, blocks = buildStage(places)
	local podiumBlocks: { BasePart } = {}
	for place = 1, 3 do
		if blocks[place] then
			table.insert(podiumBlocks, blocks[place])
		end
	end
	stage = model

	-- The camera aims at the middle of the blocks that are used.
	local minX, maxX = math.huge, -math.huge
	for _, place in places do
		minX = math.min(minX, blockX(place))
		maxX = math.max(maxX, blockX(place))
	end
	local middle = settings.Position + Vector3.new((minX + maxX) / 2, 0, 0)
	local halfWidth = (maxX - minX) / 2 + BLOCK_WIDTH / 2 + 3

	-- The screen.
	local screen = Instance.new("ScreenGui")
	screen.Name = "WinScreen"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 40
	screen.IgnoreGuiInset = true
	local winner: Entry? = nil
	for _, entry in podium do
		if entry.Won then
			winner = entry
		end
	end
	headline(screen, if winner then `{winner.DisplayName} wins!` else "Game over")
	local plates: { [number]: Frame } = {}
	for _, entry in podium do
		-- The winner's name is in the headline; a plate under the middle block would sit on
		-- your rewards card.
		if not entry.Won then
			plates[entry.Place] = plate(screen, entry)
		end
	end
	local card: Frame? = nil
	if info.Rewards then
		card = rewardsCard(screen, info.Rewards)
	end
	local cardShown = false
	local fade = Ui.frame(screen, Color3.new(0, 0, 0))
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 100
	if info.Preview then
		local hint = Ui.caps(screen, "PREVIEW  ·  CLICK ANYWHERE TO CLOSE", 14, Ui.Colors.Yellow)
		hint.AnchorPoint = Vector2.new(0, 1)
		hint.Position = UDim2.new(0, 16, 1, -12)
		hint.Size = UDim2.fromOffset(360, 20)
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.ZIndex = 101
		local close = Instance.new("TextButton")
		close.BackgroundTransparency = 1
		close.Text = ""
		close.Size = UDim2.fromScale(1, 1)
		close.ZIndex = 102
		close.Activated:Connect(closeScreen)
		close.Parent = screen
	end
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen

	hideGuis()
	MapLighting.override("Showcase")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = settings.FieldOfView
	ViewMode.suspend(true)
	controlsOn(true)

	-- The podium players' characters, as they arrive.
	local emoteAt = settings.EmoteDelay
	local winnerCopy: Model? = nil
	local winnerItem: Catalog.Item? = nil
	local others: { Model } = {} -- 2nd and 3rd, as they arrive
	for _, entry in podium do
		task.spawn(function()
			local owner = Players:GetPlayerByUserId(entry.UserId)
			local character = if owner then waitForCharacter(owner) else nil
			if not character or session ~= mine or not model.Parent then
				return
			end
			local copy, rootHeight, idle = makeCopy(character)
			local top = tops[entry.Place]
			if not copy or not top then
				return
			end
			copy:PivotTo(CFrame.new(top + Vector3.new(0, rootHeight, 0)) * FACE_CAMERA)
			copy.Parent = model
			local humanoid = copy:FindFirstChildOfClass("Humanoid")
			local animation = idle
			if not animation and player.Character then
				animation = animationFrom(player.Character, "idle", "Animation1")
			end
			if humanoid and animation then
				local track = AnimationBuilder.load(humanoid, animation)
				track.Looped = true
				track:Play(0)
			end
			if not entry.Won then
				table.insert(others, copy)
			end
			if entry.Won then
				winnerCopy = copy
				winnerItem = Catalog.get(
					info.PreviewVictory
						or (owner and owner:GetAttribute("EquippedVictory") :: string?)
				)
			end
		end)
	end

	local started = os.clock()
	local emoted = false
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 5, function()
		local t = os.clock() - started
		local shown = t - settings.WarmTime -- time since the fade in started
		if t > 0.5 and not info.Preview and GameState.getPhase() ~= "Victory" then
			closeScreen()
			return
		end
		if t >= info.Duration then
			closeScreen()
			return
		end

		-- The winner's victory, once their copy is there.
		if not emoted and shown >= emoteAt and winnerCopy and winnerItem then
			emoted = true
			Victories.play(winnerCopy, winnerItem, {
				hold = math.max(info.Duration - t - 1, 1),
				floor = settings.Position.Y,
				block = blocks[1],
				blocks = podiumBlocks,
				others = others,
				stage = model,
			})
		end

		-- The camera pushes in from far back, then holds; wide enough for the blocks on any
		-- screen shape.
		local view = camera.ViewportSize
		local aspect = if view.Y > 0 then view.X / view.Y else 16 / 9
		local halfAcross = math.atan(math.tan(math.rad(settings.FieldOfView) / 2) * aspect)
		local near = math.max(26, halfWidth / math.tan(halfAcross))
		local k = math.clamp(shown / INTRO_MOVE, 0, 1)
		local eased = 1 - (1 - k) ^ 3
		local distance = near + 20 * (1 - eased)
		local sway = math.sin(math.max(shown, 0) * 0.6) * 1.2
		local focus = middle + Vector3.new(0, 6, 0)
		camera.CFrame = Victories.camera(
			CFrame.lookAt(
				focus + Vector3.new(sway, 2.5 + 3 * (1 - eased), distance),
				focus + Vector3.new(0, -0.5, 0)
			)
		)

		-- Name plates under the blocks follow them on screen.
		for place, back in plates do
			local spot = settings.Position + Vector3.new(blockX(place), 0.2, BLOCK_DEPTH / 2 + 2)
			local point, onScreen = camera:WorldToViewportPoint(spot)
			back.Visible = onScreen and k > 0.6
			back.Position = UDim2.fromOffset(point.X, point.Y + 4)
		end

		-- Your rewards slide up after a moment.
		if card and not cardShown and shown >= settings.RewardsDelay then
			cardShown = true
			TweenService:Create(
				card,
				TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0.5, 0, 1, -24) }
			):Play()
		end

		-- Fade in from black, and out to black at the end.
		local fadeIn = 1 - math.clamp(shown / settings.FadeTime, 0, 1)
		local fadeOut = 1 - math.clamp((info.Duration - t) / settings.FadeTime, 0, 1)
		fade.BackgroundTransparency = 1 - math.max(fadeIn, fadeOut)
	end)
end

-- Dev panel: shows the win screen right now with `size` podium places (1 to 3), you on 1st and
-- the other players in the server (or copies of you) behind. `victoryId` picks the Victory
-- played (default: yours). A sample rewards card is shown. Click to close.
function WinScreen.preview(size: number?, victoryId: string?)
	local player = Players.LocalPlayer
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, other)
		end
	end
	local podium: { Entry } = {}
	for place = 1, math.clamp(size or Config.Game.PodiumSize, 1, 3) do
		local who = if place == 1 then player else (others[place - 1] or player)
		table.insert(podium, {
			UserId = who.UserId,
			Name = who.Name,
			DisplayName = who.DisplayName,
			Place = place,
			Won = place == 1,
		})
	end
	local item = Catalog.get(victoryId or player:GetAttribute("EquippedVictory") :: string?)
	openScreen({
		Podium = podium,
		Duration = Catalog.winScreenTime(
			item,
			Config.Game.VictoryTime,
			Config.WinScreen.WarmTime + Config.WinScreen.EmoteDelay,
			Config.WinScreen.EndHold
		),
		Preview = true,
		PreviewVictory = victoryId,
		Rewards = {
			Coins = 125,
			XP = 340,
			Crates = 1,
			Items = if Catalog.get("trail_honor") then { "trail_honor" } else {},
			LevelFrom = 4,
			LevelTo = 5,
			Place = 1,
			Of = 8,
		},
	})
end

function WinScreen.isActive(): boolean
	return active
end

-- The particle textures the victories use, loaded when the game starts.
local TEXTURES = {
	"rbxasset://textures/particles/sparkles_main.dds",
	"rbxasset://textures/particles/smoke_main.dds",
	"rbxasset://textures/particles/fire_main.dds",
}

function WinScreen.start()
	-- Load what the win screen and the lobby show ahead of time, so neither pops in the first
	-- time it's seen.
	task.spawn(function()
		local list: { any } = table.clone(TEXTURES)
		local lobby = workspace:FindFirstChild("Lobby")
		if lobby then
			table.insert(list, lobby)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
	Remotes.get("GameOver").OnClientEvent:Connect(function(info)
		if type(info) == "table" and type(info.Podium) == "table" then
			openScreen(info :: Info)
		end
	end)
end

return WinScreen
