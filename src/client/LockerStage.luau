--!strict
-- The Locker's preview: a showcase stage built on this screen only, far from the maps and the
-- lobby (Config.Locker.Position), where a copy of your character shows the item picked in the
-- Locker while the camera looks at it. (Roblox's ViewportFrames can't draw trails, particles
-- or beams, so the preview is a real place in the world.)
--   Trails: the copy runs down a long runway with the trail off its hands and feet.
--   Tag effects: it tags a training dummy every few seconds with the effect.
--   Titles: the same, with the camera close on the title over its head.
--   Victories: it faces you and plays the victory.
-- While it's open your controls are off, the camera is scripted (FollowCam and Spectate step
-- aside, first person is suspended), and it closes by itself if a round needs you.
-- Framing: each scene has a camera pose (where it looks from and at) and a box that must stay
-- in view (Config.Locker.Frames). Every frame `frame` moves that pose, without turning the
-- camera, so the box is centred in the free space beside the menu window and plate
-- (Menu/LockerLayout, the Locker's layout on this screen) and backs the camera off until the
-- box fits that space. So the character is fully visible at any window size or aspect ratio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))
local GameState = require(Shared:WaitForChild("GameState"))
local TitleTag = require(Shared:WaitForChild("TitleTag"))
local AnimationBuilder = require(script.Parent.AnimationBuilder)
local CosmeticEffects = require(script.Parent.CosmeticEffects)
local LockerLayout = require(script.Parent.Menu.LockerLayout)
local Profile = require(script.Parent.Profile)
local SpeedTrails = require(script.Parent.SpeedTrails)
local TagSwing = require(script.Parent.TagSwing)
local ViewMode = require(script.Parent.ViewMode)

local LockerStage = {}

local STEP = "LockerStage"
local ROUND_PHASES = { Intro = true, Playing = true, Results = true }
local FACE_RUN = CFrame.Angles(0, -math.pi / 2, 0) -- facing +X, down the runway
local FACE_CAMERA = CFrame.Angles(0, math.pi, 0) -- facing +Z, toward the camera
local TAG_SPOT = Vector3.new(-70, 0, 0)
local DUMMY_GAP = 5.5
local WIN_SPOT = Vector3.new(-110, 0, -2)
local INK = Color3.fromRGB(17, 17, 17)

local stage: Model? = nil
local dummy: Model? = nil
local dummyHome = CFrame.new()
local copy: Model? = nil
local trails: SpeedTrails.Preview? = nil
local baseTrack: AnimationTrack? = nil
local runAnimation: Animation? = nil
local idleAnimation: Animation? = nil
local active = false
local scene = "run"
local selected: Catalog.Item? = nil
local rootHeight = 3
local runX = 0
local loopStart = 0
local lastT = -1
local hitTime = -math.huge
local lastCheck = 0
local saved: { fov: number }? = nil

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

-- A SurfaceGui showing `text` (Bangers) on one face of a part.
local function sign(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	transparency: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.FontFace = Font.new("rbxasset://fonts/families/Bangers.json")
	label.TextScaled = true
	label.TextColor3 = color
	label.TextTransparency = transparency
	label.Parent = gui
	gui.Parent = target
end

-- A red and white target on one face of the dummy.
local function target(body: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local red = Color3.fromRGB(227, 36, 43)
	local rings = {
		{ size = 0.62, color = red },
		{ size = 0.4, color = Color3.new(1, 1, 1) },
		{ size = 0.18, color = red },
	}
	for i, ring in rings do
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.42)
		circle.Size = UDim2.fromScale(ring.size, ring.size)
		circle.SizeConstraint = Enum.SizeConstraint.RelativeXX
		circle.BackgroundColor3 = ring.color
		circle.BorderSizePixel = 0
		circle.ZIndex = i
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = circle
		circle.Parent = gui
	end
	gui.Parent = body
end

local function buildDummy(parent: Instance, home: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Dummy"
	local tan = Color3.fromRGB(236, 214, 168)
	part(
		model,
		Vector3.new(3.4, 0.4, 3.4),
		home * CFrame.new(0, 0.2, 0),
		Color3.fromRGB(46, 46, 51)
	)
	part(
		model,
		Vector3.new(0.4, 2.2, 0.4),
		home * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(90, 90, 98)
	)
	local body = part(
		model,
		Vector3.new(2, 2.8, 1.3),
		home * CFrame.new(0, 4, 0),
		tan,
		Enum.Material.SmoothPlastic
	)
	body.Name = "Body"
	for _, y in { 3.3, 4.8 } do
		part(
			model,
			Vector3.new(2.06, 0.18, 1.36),
			home * CFrame.new(0, y, 0),
			Color3.fromRGB(168, 146, 95)
		)
	end
	local head = part(
		model,
		Vector3.new(1.4, 1.4, 1.4),
		home * CFrame.new(0, 6.1, 0),
		tan,
		Enum.Material.SmoothPlastic
	)
	sign(head, Enum.NormalId.Left, "x  x", INK, 0)
	local eyes = (head:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui):FindFirstChildOfClass(
		"TextLabel"
	)
	if eyes then
		eyes.AnchorPoint = Vector2.new(0.5, 0.5)
		eyes.Position = UDim2.fromScale(0.5, 0.42)
		eyes.Size = UDim2.fromScale(0.8, 0.4)
	end
	target(body, Enum.NormalId.Left)
	target(body, Enum.NormalId.Front)
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

-- The stage: a long dark runway, a navy back wall with neon slashes and a hazard band, big
-- faint "TAG" letters, lane marks, and the training dummy.
local function buildStage(): Model
	local settings = Config.Locker
	local origin = settings.Position
	local model = Instance.new("Model")
	model.Name = "LockerStage"
	local startX = -140
	local length = settings.RunLength + 200
	local centerX = startX + length / 2
	part(
		model,
		Vector3.new(length, 2, 70),
		CFrame.new(origin + Vector3.new(centerX, -1, 6)),
		Color3.fromRGB(38, 38, 44),
		Enum.Material.Asphalt
	)
	part(
		model,
		Vector3.new(length, 46, 2),
		CFrame.new(origin + Vector3.new(centerX, 22, -19)),
		Color3.fromRGB(24, 32, 50)
	)
	-- The hazard band along the bottom of the wall: sections of yellow and black stripes.
	local section = 40
	for i = 0, math.ceil(length / section) - 1 do
		local band = part(
			model,
			Vector3.new(section, 1.2, 0.3),
			CFrame.new(origin + Vector3.new(startX + i * section + section / 2, 0.6, -17.9)),
			Color3.new(1, 1, 1)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- toward the camera (+Z)
		gui.LightInfluence = 0.3
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		local stripes = Instance.new("UIGradient")
		local widths = {}
		for s = 1, 10 do
			widths[s] = 0.1
		end
		stripes.Color = CosmeticLook.bands({ Color3.fromRGB(255, 214, 10), INK }, widths)
		stripes.Parent = fill
		fill.Parent = gui
		gui.Parent = band
	end
	-- Neon slashes and big faint letters on the wall.
	local accents = { Color3.fromRGB(255, 46, 136), Color3.fromRGB(25, 227, 255) }
	for i = 0, math.floor(length / 60) do
		local x = startX + 20 + i * 60
		part(
			model,
			Vector3.new(3, 52, 0.2),
			CFrame.new(origin + Vector3.new(x, 22, -17.85)) * CFrame.Angles(0, 0, math.rad(-24)),
			accents[i % 2 + 1],
			Enum.Material.Neon,
			0.55
		)
		if i % 2 == 0 then
			local board = part(
				model,
				Vector3.new(30, 14, 0.2),
				CFrame.new(origin + Vector3.new(x + 30, 20, -17.8)),
				Color3.new(1, 1, 1),
				nil,
				1
			)
			sign(board, Enum.NormalId.Back, "TAG", Color3.new(1, 1, 1), 0.9)
		end
	end
	-- Lane marks on the floor.
	for i = 0, math.floor(length / 16) do
		for _, z in { 6, 15 } do
			part(
				model,
				Vector3.new(8, 0.06, 0.6),
				CFrame.new(origin + Vector3.new(startX + i * 16, 0.03, z)),
				Color3.fromRGB(70, 70, 80)
			)
		end
	end
	dummyHome = CFrame.lookAt(
		origin + TAG_SPOT + Vector3.new(DUMMY_GAP, 0, 0),
		origin + TAG_SPOT + Vector3.new(DUMMY_GAP - 1, 0, 0)
	)
	dummy = buildDummy(model, dummyHome)
	-- Soft fill lights on the tag and victory spots (the wall can shade them).
	for _, spot in { TAG_SPOT + Vector3.new(DUMMY_GAP / 2, 0, 0), WIN_SPOT } do
		local lamp = part(
			model,
			Vector3.new(1, 1, 1),
			CFrame.new(origin + spot + Vector3.new(0, 10, 9)),
			Color3.new(1, 1, 1),
			nil,
			1
		)
		local light = Instance.new("PointLight")
		light.Range = 32
		light.Brightness = 1.4
		light.Color = Color3.fromRGB(255, 244, 228)
		light.Parent = lamp
	end
	return model
end

-- Animation objects from your character's Animate script (it doesn't run on the copy).
local function animationFrom(character: Model, folder: string, name: string): Animation?
	local animate = character:FindFirstChild("Animate")
	local holder = animate and animate:FindFirstChild(folder)
	local animation = holder and holder:FindFirstChild(name)
	return if animation and animation:IsA("Animation") then animation else nil
end

-- A copy of your character to pose: no scripts, no title or trails of its own, nothing that
-- collides, its root anchored so it only moves where it's put.
local function makeCopy(): Model?
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return nil
	end
	runAnimation = animationFrom(character, "run", "RunAnim")
	idleAnimation = animationFrom(character, "idle", "Animation1")
	character.Archivable = true
	local ok, result = pcall(function()
		return character:Clone()
	end)
	character.Archivable = false
	if not ok or not result then
		return nil
	end
	local model = result :: Model
	for _, item in model:GetDescendants() do
		if
			item:IsA("BaseScript")
			or item:IsA("Sound")
			or item:IsA("BillboardGui")
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
	local copyHumanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not copyHumanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	copyHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	copyHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	copyHumanoid.BreakJointsOnDeath = false
	root.Anchored = true
	rootHeight = copyHumanoid.HipHeight + root.Size.Y / 2
	model.Name = "LockerCopy"
	return model
end

local function playBase(animation: Animation?, speed: number)
	if baseTrack then
		baseTrack:Stop(0.15)
		baseTrack = nil
	end
	local humanoid = copy and copy:FindFirstChildOfClass("Humanoid")
	if humanoid and animation then
		local track = AnimationBuilder.load(humanoid, animation)
		track.Looped = true
		track:Play(0.15)
		track:AdjustSpeed(speed)
		baseTrack = track
	end
end

local function equipped(kind: string): Catalog.Item?
	local profile = Profile.get()
	return if profile then Catalog.get(profile.Equipped[kind]) else nil
end

-- The title over the copy's head: the selected title in the Titles scene, otherwise yours.
local function showTitle()
	local head = copy and copy:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local profile = Profile.get()
	local title = if scene == "title" then selected else equipped("Title")
	local serial = if profile and title then profile.Serials[title.id] else nil
	TitleTag.apply(head, title, if profile then profile.Level else 1, serial)
end

local function place(position: Vector3, facing: CFrame)
	local origin = Config.Locker.Position
	if copy then
		copy:PivotTo(CFrame.new(origin + position + Vector3.new(0, rootHeight, 0)) * facing)
	end
end

-- Whether the preview can open now (not while you're playing in a round).
function LockerStage.available(): boolean
	local player = Players.LocalPlayer
	if
		ROUND_PHASES[GameState.getPhase()]
		and player:GetAttribute("InGame")
		and player:GetAttribute("Alive")
	then
		return false
	end
	if player:GetAttribute("Spectating") then
		return false -- spectators have no body to show
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function LockerStage.isActive(): boolean
	return active
end

-- Shows an item (nil: your equipped trail) in the scene that suits its kind.
function LockerStage.show(item: Catalog.Item?)
	selected = item
	if not active or not copy then
		return
	end
	local kind = if item then item.kind else "Trail"
	scene = if kind == "Trail"
		then "run"
		elseif kind == "TagEffect" then "tag"
		elseif kind == "Title" then "title"
		else "victory"
	loopStart = os.clock()
	lastT = -1
	hitTime = -math.huge
	runX = 0
	if trails then
		trails.set(if scene == "run" then item else nil)
		trails.clear()
	end
	if dummy then
		dummy:PivotTo(dummyHome)
	end
	if scene == "run" then
		place(Vector3.new(runX, 0, 0), FACE_RUN)
		playBase(runAnimation, 1.4)
	elseif scene == "victory" then
		place(WIN_SPOT, FACE_CAMERA)
		playBase(idleAnimation, 1)
	else
		place(TAG_SPOT, FACE_RUN)
		playBase(idleAnimation, 1)
	end
	showTitle()
end

-- A camera that looks the same way as the one at `position` looking at `lookAt`, moved
-- sideways, up or down and back as needed so the box around `center` (`bounds` studs wide and
-- high, facing the camera) sits in the middle of the free space on screen, fully inside it.
-- With the camera's vertical field of view f and a viewport `v` pixels high, one stud at
-- distance d is v / (2 d tan(f / 2)) pixels. Moving the camera along its right or up vector
-- moves `center` on screen without changing its distance, so: first push the camera back until
-- the box fits the free rectangle, then shift it so the box's centre lands at the rectangle's
-- centre (as a share of half the screen: half the screen is halfH studs high at distance d).
local function frame(
	camera: Camera,
	position: Vector3,
	lookAt: Vector3,
	center: Vector3,
	bounds: Vector2
): CFrame
	local free = LockerLayout.freeReal()
	local view = camera.ViewportSize
	local look = (lookAt - position).Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look)
	local halfTan = math.tan(math.rad(camera.FieldOfView) / 2)
	local depth = (center - position):Dot(look)
	local needed = math.max(bounds.X / free.w, bounds.Y / free.h) * view.Y / (2 * halfTan)
	if depth < needed then
		position -= look * (needed - depth)
		depth = needed
	end
	local offset = center - position
	local halfHeight = depth * halfTan
	local halfWidth = halfHeight * view.X / view.Y
	local wantX = ((free.x + free.w / 2) - view.X / 2) / (view.X / 2) -- -1 left .. 1 right
	local wantY = (view.Y / 2 - (free.y + free.h / 2)) / (view.Y / 2) -- -1 bottom .. 1 top
	position += right * (offset:Dot(right) - wantX * halfWidth)
	position += up * (offset:Dot(up) - wantY * halfHeight)
	return CFrame.lookAt(position, position + look)
end

local function step(dt: number)
	local now = os.clock()
	if now - lastCheck > 0.5 then
		lastCheck = now
		if not LockerStage.available() then
			LockerStage.close()
			return
		end
	end
	if not copy then
		return
	end
	local settings = Config.Locker
	local origin = settings.Position
	local camera = workspace.CurrentCamera
	local t = now - loopStart

	if scene == "run" then
		runX += settings.RunSpeed * dt
		if runX > settings.RunLength then
			runX = 0
			if trails then
				trails.clear()
			end
		end
		place(Vector3.new(runX, 0, 0), FACE_RUN)
		local spot = origin + Vector3.new(runX, rootHeight, 0)
		camera.CFrame = frame(
			camera,
			spot + Vector3.new(3, 3, 17),
			spot + Vector3.new(3, 0.5, 0),
			spot + Vector3.new(-1.5, -0.25, 0), -- the runner and a little of the trail behind
			settings.Frames.run
		)
	elseif scene == "tag" or scene == "title" then
		local cycle = t % settings.TagLoop
		if cycle < lastT then
			lastT = -1
		end
		local humanoid = copy:FindFirstChildOfClass("Humanoid")
		if lastT < 0.5 and cycle >= 0.5 and humanoid then
			TagSwing.swipe(humanoid)
		end
		if lastT < 0.62 and cycle >= 0.62 and dummy then
			CosmeticEffects.playTag(
				if scene == "tag" then selected else equipped("TagEffect"),
				dummy
			)
			hitTime = now
		end
		lastT = cycle
		-- The dummy rocks back from the hit.
		if dummy then
			local k = (now - hitTime) / 0.6
			local angle = if k < 1 then 16 * math.sin(math.pi * k) * (1 - k * 0.4) else 0
			local base = dummyHome.Position
			dummy:PivotTo(
				CFrame.new(base)
					* CFrame.Angles(0, 0, math.rad(-angle))
					* CFrame.new(-base)
					* dummyHome
			)
		end
		local spot = origin + TAG_SPOT + Vector3.new(0, rootHeight, 0)
		if scene == "title" then
			local head = spot + Vector3.new(0, 2.6, 0)
			camera.CFrame = frame(
				camera,
				head + Vector3.new(2.5, 1.2, 13),
				head + Vector3.new(1.2, 1.4, 0),
				head + Vector3.new(0, 0.4, 0), -- the head and the title over it
				settings.Frames.title
			)
		else
			local middle = spot + Vector3.new(DUMMY_GAP / 2, 0, 0)
			camera.CFrame = frame(
				camera,
				middle + Vector3.new(0, 3, 15),
				middle + Vector3.new(0, 0.5, 0),
				middle + Vector3.new(0, 0.5, 0), -- you and the dummy
				settings.Frames.tag
			)
		end
	else
		local cycle = t % settings.VictoryLoop
		if cycle < lastT then
			lastT = -1
		end
		if lastT < 0.3 and cycle >= 0.3 and selected then
			CosmeticEffects.playVictory(copy, selected, settings.VictoryLoop - 1.2)
		end
		lastT = cycle
		local spot = origin + WIN_SPOT + Vector3.new(0, rootHeight, 0)
		local hologram = selected ~= nil and selected.look.Effect == "Hologram"
		camera.CFrame = if hologram
			then frame(
				camera,
				spot + Vector3.new(0, 7, 30),
				spot + Vector3.new(0, 6, -6),
				spot + Vector3.new(0, 6, -6), -- the giant statue
				settings.Frames.hologram
			)
			else frame(
				camera,
				spot + Vector3.new(0, 2.5, 15),
				spot + Vector3.new(0, 1.5, 0),
				spot + Vector3.new(0, 0.5, 0), -- you, arms up
				settings.Frames.victory
			)
	end
end

local function controls(): any
	local ok, module = pcall(function()
		return require(
			Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
		) :: any
	end)
	if ok and module then
		return module:GetControls()
	end
	return nil
end

-- Opens the preview (false if it can't open now).
function LockerStage.open(): boolean
	if active then
		return true
	end
	if not LockerStage.available() then
		return false
	end
	local built = stage or buildStage()
	stage = built
	built.Parent = workspace
	local model = makeCopy()
	if not model then
		built.Parent = nil
		return false
	end
	copy = model
	model.Parent = built
	trails = SpeedTrails.preview(model)
	local camera = workspace.CurrentCamera
	saved = { fov = camera.FieldOfView }
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Locker.FieldOfView
	ViewMode.suspend(true)
	local playerControls = controls()
	if playerControls then
		playerControls:Disable()
	end
	active = true
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 5, step)
	LockerStage.show(selected)
	return true
end

-- Closes the preview and gives the camera and controls back.
function LockerStage.close()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(STEP)
	if baseTrack then
		baseTrack:Stop(0)
		baseTrack = nil
	end
	if trails then
		trails.destroy()
		trails = nil
	end
	if copy then
		copy:Destroy()
		copy = nil
	end
	if stage then
		stage.Parent = nil
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if saved then
		camera.FieldOfView = saved.fov
		saved = nil
	end
	ViewMode.suspend(false)
	local playerControls = controls()
	if playerControls then
		playerControls:Enable()
	end
end

return LockerStage
