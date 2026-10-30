--!strict
-- What the victories (client/Victories) are built from. One victory plays at a time, and
-- everything it makes (parts, particles, lights, screen effects, connections, changes to the
-- stage) is tracked, so `stop` clears it at once wherever it got to. Times are seconds since the
-- victory started. The victory's character is a posed copy whose root is anchored, so moving the
-- whole body (jumps, flips, spins) is done here by moving its pivot every frame, and the limbs by
-- keyframed poses (AnimationBuilder).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local AnimationBuilder = require(script.Parent.Parent.AnimationBuilder)

export type Context = {
	character: Model, -- the winner's copy (or the Locker's)
	root: BasePart,
	humanoid: Humanoid,
	item: Catalog.Item,
	colors: { Color3 }, -- the item's colors
	home: CFrame, -- the character's pivot when it started (facing the camera)
	ground: number, -- the y of what they stand on
	floor: number, -- the y of the stage floor
	block: BasePart?, -- the 1st place block under them (the win screen)
	blocks: { BasePart }, -- every podium block, 1st first
	others: { Model }, -- the 2nd and 3rd place copies (filled in as they arrive)
	stage: Instance?, -- the whole stage (hidden when a victory leaves it)
	hold: number, -- seconds before the victory lets go
	started: number,
}

-- A pose key: degrees per body part. `ease` shapes the move into this key ("In", "Out",
-- "InOut", "Linear"). Each key keeps the angles of the keys before it unless it changes them
-- (Vector3.zero puts a part back to standing).
export type Key = { time: number, angles: { [string]: Vector3 }, ease: string? }

type Shake = { strength: number, start: number, duration: number }

local Kit = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local session = 0
local current: Context? = nil
local tracked: { Instance } = {}
local connections: { RBXScriptConnection } = {}
local restores: { () -> () } = {}
local shakes: { Shake } = {}
local tiltOf: ((number) -> number)? = nil
local overlay: ScreenGui? = nil
local folder: Folder? = nil
local built: { [{ Key }]: Animation } = {}

local random = Random.new()
function Kit.rnd(a: number, b: number): number
	return a + random:NextNumber() * (b - a)
end

-- Eases: 0 -> 1 as t goes from a to b.
function Kit.span(t: number, a: number, b: number, style: string?): number
	local u = math.clamp((t - a) / math.max(b - a, 1e-6), 0, 1)
	if style == "In" then
		return u * u * u
	elseif style == "Out" then
		return 1 - (1 - u) ^ 3
	elseif style == "Linear" then
		return u
	elseif style == "Back" then
		local c = 1.7
		return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2
	end
	return u * u * (3 - 2 * u)
end

-- A color along `colors` (0 the first, 1 the last).
function Kit.gradient(colors: { Color3 }, u: number): Color3
	if #colors == 1 then
		return colors[1]
	end
	local x = math.clamp(u, 0, 1) * (#colors - 1)
	local i = math.min(#colors - 1, math.floor(x))
	return colors[i + 1]:Lerp(colors[i + 2], x - i)
end

function Kit.sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

---------------------------------------------------------------------------- the session

function Kit.begin(context: Context)
	Kit.stop()
	session += 1
	current = context
end

-- Clears everything the playing victory made and puts the stage back.
function Kit.stop()
	session += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for i = #restores, 1, -1 do
		pcall(restores[i])
	end
	table.clear(restores)
	for _, item in tracked do
		item:Destroy()
	end
	table.clear(tracked)
	table.clear(shakes)
	tiltOf = nil
	overlay = nil
	folder = nil
	current = nil
end

function Kit.context(): Context?
	return current
end

function Kit.now(): number
	return if current then os.clock() - current.started else 0
end

function Kit.track<T>(item: T): T
	table.insert(tracked, item :: any)
	return item
end

function Kit.onStop(restore: () -> ())
	table.insert(restores, restore)
end

-- Runs `callback` `at` seconds into the victory (if it's still playing).
function Kit.at(at: number, callback: () -> ())
	local mine = session
	local delay = at - Kit.now()
	task.delay(math.max(delay, 0), function()
		if mine == session then
			callback()
		end
	end)
end

-- Runs `callback(t, dt)` every frame after the animations (so body parts are where they're
-- drawn this frame) until it returns true or the victory stops.
function Kit.every(callback: (number, number) -> boolean?)
	local connection: RBXScriptConnection
	connection = RunService.PreSimulation:Connect(function(dt)
		if callback(Kit.now(), dt) == true then
			connection:Disconnect()
		end
	end)
	table.insert(connections, connection)
end

---------------------------------------------------------------------------- the body

-- Moves the whole character every frame: `offset(t)` is relative to where it started (in its
-- own space: -Z is toward the camera, +Z behind it). Put back when the victory stops.
function Kit.move(context: Context, offset: (number) -> CFrame)
	local character = context.character
	Kit.onStop(function()
		if character.Parent then
			character:PivotTo(context.home)
		end
	end)
	Kit.every(function(t)
		character:PivotTo(context.home * offset(t))
		return nil
	end)
end

-- A turn of `angles` round the point `point` (in the character's space).
function Kit.around(point: Vector3, angles: CFrame): CFrame
	return CFrame.new(point) * angles * CFrame.new(-point)
end

-- Fills in each key's angles from the keys before it, and moves each key's `ease` onto the key
-- before it (AnimationBuilder eases from a key to the next).
local function chain(keys: { Key }): { AnimationBuilder.Key }
	local out: { AnimationBuilder.Key } = {}
	local angles: { [string]: Vector3 } = {}
	for i, key in keys do
		angles = table.clone(angles)
		for name, value in key.angles do
			angles[name] = value
		end
		out[i] = { time = key.time, angles = angles }
		if i > 1 and key.ease then
			out[i - 1].ease = key.ease
		end
	end
	-- Hold the last pose until stopped.
	local last = out[#out]
	table.insert(out, { time = last.time + 120, angles = last.angles })
	return out
end

-- Plays `keys` on `model` (whole body unless `partial`), holding the last pose until `hold`.
function Kit.pose(model: Model, keys: { Key }, hold: number, partial: boolean?): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animation = built[keys]
	if not animation then
		animation = AnimationBuilder.make(chain(keys), partial)
		built[keys] = animation
	end
	local track = AnimationBuilder.load(humanoid, animation)
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(0.12)
	local mine = session
	Kit.onStop(function()
		track:Stop(0.25)
	end)
	task.delay(hold, function()
		if mine == session then
			track:Stop(0.3)
		end
	end)
	return track
end

function Kit.part(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Where a body part is (or the root's if it's missing).
function Kit.at3(context: Context, name: string): Vector3
	local part = Kit.part(context.character, name)
	return if part then part.Position else context.root.Position
end

-- Fades every part of `model` to `transparency` (local only; put back when stopped).
function Kit.fade(model: Instance, transparency: number)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = transparency
		end
	end
	Kit.onStop(function()
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = 0
			end
		end
	end)
end

-- Hides `root` and everything in it except `keep` (local only; put back when stopped).
function Kit.hide(root: Instance, keep: Instance?)
	local hidden: { BasePart } = {}
	local guis: { LayerCollector } = {}
	for _, item in root:GetDescendants() do
		if keep and (item == keep or item:IsDescendantOf(keep)) then
			continue
		end
		if item:IsA("BasePart") and item.LocalTransparencyModifier < 1 then
			item.LocalTransparencyModifier = 1
			table.insert(hidden, item)
		elseif (item:IsA("SurfaceGui") or item:IsA("BillboardGui")) and item.Enabled then
			item.Enabled = false
			table.insert(guis, item)
		elseif item:IsA("Light") and item.Enabled then
			item.Enabled = false
			Kit.onStop(function()
				item.Enabled = true
			end)
		end
	end
	Kit.onStop(function()
		for _, part in hidden do
			part.LocalTransparencyModifier = 0
		end
		for _, gui in guis do
			gui.Enabled = true
		end
	end)
end

---------------------------------------------------------------------------- reactions

-- 2nd and 3rd place react: "LookUp" (heads up), "Shield" (an arm over the eyes), "Flail" (arms
-- thrown out) or "Stagger" (Flail, pushed back away from the winner, then back).
local REACTIONS: { [string]: { Key } } = {
	LookUp = {
		{ time = 0, angles = {} },
		{
			time = 0.4,
			angles = { Head = Vector3.new(32, 0, 0), UpperTorso = Vector3.new(8, 0, 0) },
		},
	},
	Shield = {
		{ time = 0, angles = {} },
		{
			time = 0.15,
			angles = {
				RightUpperArm = Vector3.new(115, 0, -25),
				RightLowerArm = Vector3.new(85, 0, 0),
				Head = Vector3.new(-18, 0, 0),
				UpperTorso = Vector3.new(-10, 0, 0),
			},
			ease = "Out",
		},
		{ time = 1.8, angles = {} },
		{
			time = 2.3,
			angles = {
				RightUpperArm = Vector3.zero,
				RightLowerArm = Vector3.zero,
				Head = Vector3.new(10, 0, 0),
				UpperTorso = Vector3.zero,
			},
		},
	},
	Flail = {
		{ time = 0, angles = {} },
		{
			time = 0.15,
			angles = {
				RightUpperArm = Vector3.new(40, 0, 70),
				LeftUpperArm = Vector3.new(40, 0, -70),
				UpperTorso = Vector3.new(14, 0, 0),
				Head = Vector3.new(-10, 0, 0),
			},
			ease = "Out",
		},
		{ time = 0.9, angles = {} },
		{
			time = 1.4,
			angles = {
				RightUpperArm = Vector3.zero,
				LeftUpperArm = Vector3.zero,
				UpperTorso = Vector3.zero,
				Head = Vector3.zero,
			},
		},
	},
}

function Kit.react(context: Context, kind: string, at: number)
	Kit.at(at, function()
		local keys = REACTIONS[if kind == "Stagger" then "Flail" else kind]
		for _, other in context.others do
			if not other.Parent then
				continue
			end
			Kit.pose(other, keys, context.hold - at, true)
			if kind == "Stagger" then
				local start = other:GetPivot()
				local away = start.Position - context.home.Position
				away = Vector3.new(away.X, 0, away.Z)
				local push = if away.Magnitude > 0.1 then away.Unit * 1.2 else Vector3.zero
				local begun = Kit.now()
				Kit.onStop(function()
					if other.Parent then
						other:PivotTo(start)
					end
				end)
				Kit.every(function(t)
					local u = t - begun
					local k = if u < 0.2
						then Kit.span(u, 0, 0.2, "Out")
						else 1 - Kit.span(u, 0.5, 1.3)
					other:PivotTo(
						start
							+ push * k
							+ Vector3.new(0, math.sin(math.min(u, 0.4) / 0.4 * math.pi) * 0.4, 0)
					)
					return u > 1.3
				end)
			end
		end
	end)
end

---------------------------------------------------------------------------- the world

function Kit.folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local new = Instance.new("Folder")
	new.Name = "Victory"
	new.Parent = workspace
	folder = Kit.track(new)
	return new
end

-- An anchored part that touches nothing and casts no shadow.
function Kit.block(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Parent = Kit.folder()
	return part
end

function Kit.wedge(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = Kit.folder()
	return part
end

-- A neon line from `a` to `b`.
function Kit.line(a: Vector3, b: Vector3, width: number, color: Color3, transparency: number?): Part
	local length = (b - a).Magnitude
	return Kit.block(
		Vector3.new(width, width, math.max(length, 0.05)),
		CFrame.lookAt((a + b) / 2, b),
		color,
		Enum.Material.Neon,
		transparency
	)
end

function Kit.tween(
	item: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService:Create(
		item,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		goal
	):Play()
end

-- Destroys `item` after `seconds` (if the victory hasn't already cleared it).
function Kit.expire(item: Instance, seconds: number)
	task.delay(seconds, function()
		item:Destroy()
	end)
end

-- A group of parts placed together: `place(cframe)` puts each at its spot relative to it.
export type Prop = { parts: { BasePart }, offsets: { CFrame }, place: (CFrame) -> () }

function Kit.prop(): Prop
	local prop = { parts = {}, offsets = {} } :: any
	function prop.place(cframe: CFrame)
		local frames = table.create(#prop.parts)
		for i, offset in prop.offsets do
			frames[i] = cframe * offset
		end
		workspace:BulkMoveTo(prop.parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	return prop :: Prop
end

function Kit.add(prop: Prop, part: BasePart, offset: CFrame): BasePart
	table.insert(prop.parts, part)
	table.insert(prop.offsets, offset)
	return part
end

---------------------------------------------------------------------------- particles

local function attachmentAt(position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	return Kit.track(attachment)
end

-- A one-off burst of glowing sparks at `position`.
function Kit.burst(
	position: Vector3,
	count: number,
	color: Color3 | ColorSequence,
	speed: NumberRange,
	size: number,
	gravity: number?,
	life: number?
)
	local attachment = attachmentAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	local lifetime = life or 0.8
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = speed
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -(gravity or 0), 0)
	emitter.Drag = 2
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(count)
	Kit.expire(attachment, lifetime + 0.5)
end

-- Dust or smoke: soft gray puffs.
function Kit.dust(position: Vector3, count: number, spread: number, color: Color3?)
	local attachment = attachmentAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(190, 182, 168))
	emitter.Size = NumberSequence.new(spread * 0.4, spread)
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(spread * 1.5, spread * 4)
	emitter.SpreadAngle = Vector2.new(180, 30)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Drag = 3
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(count)
	Kit.expire(attachment, 2)
end

-- An emitter that keeps going (on `parent`, an attachment or part) until removed.
function Kit.emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.LightEmission = 1
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return Kit.track(emitter)
end

function Kit.attach(part: BasePart, offset: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Position = offset
	attachment.Parent = part
	return Kit.track(attachment)
end

-- A trail between two points on `part`.
function Kit.trail(
	part: BasePart,
	a: Vector3,
	b: Vector3,
	color: ColorSequence,
	lifetime: number
): Trail
	local trail = Instance.new("Trail")
	trail.Attachment0 = Kit.attach(part, a)
	trail.Attachment1 = Kit.attach(part, b)
	trail.Color = color
	trail.Lifetime = lifetime
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = part
	return Kit.track(trail)
end

-- A flat glowing ring spreading out from `position` and fading. `facing`: its turn (flat on
-- the ground by default).
function Kit.ring(position: Vector3, color: Color3, size: number, seconds: number, facing: CFrame?)
	local disc = Kit.block(
		Vector3.new(0.2, 2, 2),
		CFrame.new(position) * (facing or CFrame.Angles(0, 0, math.rad(90))),
		color,
		Enum.Material.Neon,
		0.1,
		Enum.PartType.Cylinder
	)
	Kit.tween(disc, seconds, { Size = Vector3.new(0.2, size, size), Transparency = 1 })
	Kit.expire(disc, seconds + 0.05)
end

-- A zigzag bolt from `a` to `b` that flickers and goes.
function Kit.bolt(
	a: Vector3,
	b: Vector3,
	color: Color3,
	width: number,
	seconds: number,
	jitter: number?
)
	local points = { a }
	local count = math.max(3, math.floor((b - a).Magnitude / 4))
	local j = jitter or 1.5
	for i = 1, count - 1 do
		table.insert(
			points,
			a:Lerp(b, i / count) + Vector3.new(Kit.rnd(-j, j), Kit.rnd(-j, j) * 0.4, Kit.rnd(-j, j))
		)
	end
	table.insert(points, b)
	local segments = {}
	for i = 1, #points - 1 do
		table.insert(segments, Kit.line(points[i], points[i + 1], width, color))
	end
	local mine = session
	task.spawn(function()
		for _, visible in { false, true, false, true } do
			task.wait(seconds / 5)
			if mine ~= session then
				return
			end
			for _, segment in segments do
				segment.Transparency = if visible then 0 else 1
			end
		end
		task.wait(seconds / 5)
		for _, segment in segments do
			segment:Destroy()
		end
	end)
end

-- Adds a lighting effect (ColorCorrection, Bloom, DepthOfField...) for this screen.
function Kit.lighting(className: string, props: { [string]: any }): PostEffect
	local effect = Instance.new(className) :: any
	for key, value in props do
		effect[key] = value
	end
	effect.Name = "Victory" .. className
	effect.Parent = Lighting
	return Kit.track(effect)
end

---------------------------------------------------------------------------- the camera and screen

-- Shakes the camera `strength` degrees, settling over `seconds`.
function Kit.shake(strength: number, seconds: number)
	table.insert(shakes, { strength = strength, start = os.clock(), duration = seconds })
end

-- The camera tips up by `tilt(t)` degrees (down if negative) while the victory plays.
function Kit.tilt(tilt: (number) -> number)
	tiltOf = tilt
end

-- The win screen's or Locker's camera with the victory's shakes and tilt laid on.
function Kit.camera(cframe: CFrame): CFrame
	if not current then
		return cframe
	end
	local now = os.clock()
	local pitch = if tiltOf then tiltOf(Kit.now()) else 0
	local roll, yaw = 0, 0
	for i = #shakes, 1, -1 do
		local shake = shakes[i]
		local u = (now - shake.start) / shake.duration
		if u >= 1 then
			table.remove(shakes, i)
		else
			local s = shake.strength * (1 - u) ^ 2
			pitch += math.noise(now * 18, 1.3) * s
			yaw += math.noise(now * 18, 7.1) * s
			roll += math.noise(now * 18, 3.7) * s * 0.6
		end
	end
	return cframe * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
end

-- A full-screen layer for screen effects, under the menus and the win screen's text.
function Kit.screen(): ScreenGui
	if overlay and overlay.Parent then
		return overlay
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VictoryScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlay = Kit.track(gui)
	return gui
end

-- The whole screen flashes `color` and fades over `seconds`.
function Kit.flash(color: Color3, strength: number, seconds: number)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - strength
	frame.Parent = Kit.screen()
	Kit.tween(frame, seconds, { BackgroundTransparency = 1 })
	Kit.expire(frame, seconds + 0.05)
end

-- A world point's place on the screen (pixels).
function Kit.onScreen(position: Vector3): Vector2
	local point = workspace.CurrentCamera:WorldToViewportPoint(position)
	return Vector2.new(point.X, point.Y)
end

return Kit
