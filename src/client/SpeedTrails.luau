--!strict
-- Speed trails, like the parkour reference: streaks off the hands and feet while a player is
-- moving fast or (for you) doing a move (Config.SpeedTrails). Drawn for every player, each in
-- the trail they have equipped (their EquippedTrail attribute, a Trail item in shared/Catalog):
--   Solid and Gradient: one streak per hand and foot, colored along its length.
--   Stripes and Camo: hard-edged bands along it. Split and Checker: two half-width lanes.
--   Light: glow. Effect: particles off the hands and feet while it's on (Embers, Stars,
--   Sparkles, Sparks, Snow).
--   Holo (Iridescent): colors that flow every frame. Afterimages: see-through copies of the
--   body peel off behind you in shifting holo colors.
-- In first person your own hands don't trail, so streaks don't smear across your view.
-- SpeedTrails.preview gives the Locker's preview character the same trails, always on.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local CosmeticLook = require(Shared:WaitForChild("CosmeticLook"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local SpeedTrails = {}

local LIMBS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" }
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local ATTACHMENTS = { TrailTop = true, TrailMid = true, TrailBottom = true }

type Limb = {
	part: BasePart,
	top: Attachment,
	middle: Attachment,
	bottom: Attachment,
	trails: { Trail },
	emitter: ParticleEmitter?,
}
type Rig = {
	player: Player?,
	character: Model,
	root: BasePart?,
	limbs: { [string]: Limb },
	holo: boolean,
	afterimages: boolean,
	forced: boolean, -- the Locker preview: always on
	on: boolean,
	lastGhost: number,
}

export type Preview = {
	set: (Catalog.Item?) -> (),
	clear: () -> (),
	destroy: () -> (),
}

local rigs: { [Model]: Rig } = {}
local ghosts: Folder? = nil

local function kp(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end

-- Particle settings for each trail effect.
local function makeEmitter(effect: string, colors: { Color3 }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.Rate = Config.SpeedTrails.EffectRate
	e.Enabled = false
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	if effect == "Embers" then
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 40, 20)),
		})
		e.Size = NumberSequence.new({ kp(0, 0.28), kp(1, 0) })
		e.Speed = NumberRange.new(0.5, 2)
		e.Acceleration = Vector3.new(0, 7, 0)
		e.Lifetime = NumberRange.new(0.4, 0.8)
	elseif effect == "Sparks" then
		e.Color = ColorSequence.new(Color3.new(1, 1, 1), colors[2] or Color3.fromRGB(25, 227, 255))
		e.Size = NumberSequence.new({ kp(0, 0.22), kp(1, 0) })
		e.Speed = NumberRange.new(6, 11)
		e.Drag = 8
		e.Lifetime = NumberRange.new(0.12, 0.25)
		e.Rate = Config.SpeedTrails.EffectRate * 1.5
	elseif effect == "Snow" then
		e.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 240, 255))
		e.Size = NumberSequence.new({ kp(0, 0.2), kp(1, 0.12) })
		e.Speed = NumberRange.new(0.3, 1)
		e.Acceleration = Vector3.new(0, -5, 0)
		e.Lifetime = NumberRange.new(0.7, 1.1)
		e.LightEmission = 0.4
	else -- Stars, Sparkles
		e.Color = if effect == "Stars"
			then ColorSequence.new(
				Color3.new(1, 1, 1),
				colors[2] or colors[1] or Color3.new(1, 1, 1)
			)
			else ColorSequence.new(Color3.new(1, 1, 1))
		e.Size = NumberSequence.new({
			kp(0, 0),
			kp(0.3, if effect == "Stars" then 0.4 else 0.25),
			kp(1, 0),
		})
		e.Speed = NumberRange.new(0.3, 1.2)
		e.Lifetime = NumberRange.new(0.4, 0.7)
	end
	return e
end

-- Removes a rig's trails and particles (keeps the attachments).
local function strip(rig: Rig)
	for _, limb in rig.limbs do
		for _, trail in limb.trails do
			trail:Destroy()
		end
		table.clear(limb.trails)
		if limb.emitter then
			limb.emitter:Destroy()
			limb.emitter = nil
		end
	end
end

local function newTrail(
	limb: Limb,
	a0: Attachment,
	a1: Attachment,
	color: ColorSequence,
	light: number
): Trail
	local settings = Config.SpeedTrails
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = settings.Lifetime
	trail.Color = color
	trail.Transparency = NumberSequence.new({ kp(0, 0.25), kp(1, 1) })
	trail.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0.35) })
	trail.FaceCamera = true
	trail.MinLength = 0.05
	trail.LightEmission = light
	trail.LightInfluence = 1 - light
	trail.Enabled = false
	trail.Parent = limb.part
	table.insert(limb.trails, trail)
	return trail
end

-- Builds a rig's trails in a trail item's look.
local function applyLook(rig: Rig, item: Catalog.Item?)
	strip(rig)
	local chosen = item or Catalog.get(Config.Progression.DefaultEquipped.Trail)
	if not chosen then
		return
	end
	local look = chosen.look
	local light = math.clamp((look.Light or 0) :: number, 0, 1)
	local lanes = CosmeticLook.trailLanes(look)
	rig.holo = lanes == nil
	rig.afterimages = look.Effect == "Afterimages"
	local colors = (look.Colors or {}) :: { Color3 }
	for _, limb in rig.limbs do
		if not lanes then
			newTrail(limb, limb.top, limb.bottom, CosmeticLook.holoSequence(0), light)
		elseif #lanes == 1 then
			newTrail(limb, limb.top, limb.bottom, lanes[1], light)
		else
			newTrail(limb, limb.top, limb.middle, lanes[1], light)
			newTrail(limb, limb.middle, limb.bottom, lanes[2], light)
		end
		if look.Effect and look.Effect ~= "Afterimages" then
			local emitter = makeEmitter(look.Effect, colors)
			emitter.Parent = limb.middle
			limb.emitter = emitter
		end
	end
	rig.on = false
end

local function attach(part: BasePart, name: string, y: number): Attachment
	local existing = part:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = Vector3.new(0, y, 0)
	a.Parent = part
	return a
end

local function setup(player: Player?, character: Model, forced: boolean): Rig
	local width = Config.SpeedTrails.Width
	local rig: Rig = {
		player = player,
		character = character,
		root = nil,
		limbs = {},
		holo = false,
		afterimages = false,
		forced = forced,
		on = false,
		lastGhost = 0,
	}
	for _, name in LIMBS do
		local part = if forced
			then character:FindFirstChild(name)
			else character:WaitForChild(name, 5)
		if not part or not part:IsA("BasePart") then
			continue
		end
		-- A trail is drawn between two attachments at the ends of the hand or foot.
		rig.limbs[name] = {
			part = part,
			top = attach(part, "TrailTop", width / 2),
			middle = attach(part, "TrailMid", 0),
			bottom = attach(part, "TrailBottom", -width / 2),
			trails = {},
			emitter = nil,
		}
	end
	rig.root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	rigs[character] = rig
	return rig
end

local function itemFor(player: Player): Catalog.Item?
	return Catalog.get(player:GetAttribute("EquippedTrail") :: string?)
end

local function watch(player: Player)
	local function add(character: Model)
		local rig = setup(player, character, false)
		applyLook(rig, itemFor(player))
		character.AncestryChanged:Connect(function()
			if not character.Parent then
				rigs[character] = nil
			end
		end)
	end
	player.CharacterAdded:Connect(add)
	if player.Character then
		task.spawn(add, player.Character)
	end
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
		for _, rig in rigs do
			if rig.player == player then
				applyLook(rig, itemFor(player))
			end
		end
	end)
end

-- Turns a rig's trails on or off (your own hands stay off in first person).
local function setOn(rig: Rig, on: boolean, handsHidden: boolean)
	for name, limb in rig.limbs do
		local isHand = name == "LeftHand" or name == "RightHand"
		local show = on and not (handsHidden and isHand)
		for _, trail in limb.trails do
			trail.Enabled = show
		end
		if limb.emitter then
			limb.emitter.Enabled = show
		end
	end
	rig.on = on
end

local function ghostFolder(): Folder
	if not ghosts or not ghosts.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "Afterimages"
		folder.Parent = workspace
		ghosts = folder
	end
	return ghosts :: Folder
end

-- A see-through copy of the body where it is now, fading out.
local function afterimage(rig: Rig, phase: number)
	local folder = ghostFolder()
	local fade = TweenInfo.new(Config.SpeedTrails.AfterimageLife, Enum.EasingStyle.Quad)
	local index = 0
	for _, part in rig.character:GetChildren() do
		if
			not part:IsA("BasePart")
			or part.Name == "HumanoidRootPart"
			or part.Transparency >= 1
		then
			continue
		end
		index += 1
		local ghost = Instance.new("Part")
		ghost.Size = part.Size
		ghost.CFrame = part.CFrame
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.CanQuery = false
		ghost.CanTouch = false
		ghost.CastShadow = false
		ghost.Material = Enum.Material.ForceField
		ghost.Color = CosmeticLook.holoColor(phase + index * 0.04)
		ghost.Parent = folder
		TweenService:Create(ghost, fade, { Transparency = 1 }):Play()
		Debris:AddItem(ghost, Config.SpeedTrails.AfterimageLife + 0.05)
	end
end

-- Trails on a model that isn't a player's character (the Locker's preview), always on.
function SpeedTrails.preview(character: Model): Preview
	local rig = setup(nil, character, true)
	return {
		set = function(item: Catalog.Item?)
			applyLook(rig, item)
			setOn(rig, true, false)
		end,
		clear = function()
			for _, limb in rig.limbs do
				for _, trail in limb.trails do
					trail:Clear()
				end
			end
		end,
		destroy = function()
			strip(rig)
			rigs[character] = nil
			for _, limb in rig.limbs do
				for _, a in { limb.top, limb.middle, limb.bottom } do
					a:Destroy()
				end
			end
		end,
	}
end

-- Takes the trail parts off a copied character (the Locker copies yours, trails and all).
function SpeedTrails.stripCopy(character: Model)
	for _, item in character:GetDescendants() do
		local trailPart = item:IsA("Trail") or item:IsA("ParticleEmitter")
		if trailPart or (item:IsA("Attachment") and ATTACHMENTS[item.Name]) then
			item:Destroy()
		end
	end
end

function SpeedTrails.start()
	local settings = Config.SpeedTrails
	if not settings.Enabled then
		return
	end
	local localPlayer = Players.LocalPlayer
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local moves: { [string]: boolean } = {}
	for _, name in settings.Moves do
		moves[name] = true
	end

	RunService.Heartbeat:Connect(function()
		local firstPerson = ViewMode.isFirstPerson()
		local now = os.clock()
		local phase = (now / settings.HoloCycle) % 1
		local holo: ColorSequence? = nil
		for _, rig in rigs do
			local on = rig.forced
			local mine = rig.player == localPlayer
			if not on then
				if mine then
					local parts = MoveState.parts()
					if parts then
						on = parts.root.AssemblyLinearVelocity.Magnitude >= settings.MinSpeed
							or (MoveState.busy ~= nil and moves[MoveState.busy] == true)
					end
				elseif rig.root and rig.root.Parent then
					on = rig.root.AssemblyLinearVelocity.Magnitude >= settings.MinSpeed
				end
			end
			if on ~= rig.on or not rig.forced then
				setOn(rig, on, mine and firstPerson)
			end
			if rig.holo and on then
				holo = holo or CosmeticLook.holoSequence(phase)
				for _, limb in rig.limbs do
					for _, trail in limb.trails do
						trail.Color = holo :: ColorSequence
					end
				end
			end
			if rig.afterimages and on and now - rig.lastGhost >= settings.AfterimageEvery then
				rig.lastGhost = now
				if not (mine and firstPerson) then
					afterimage(rig, phase)
				end
			end
		end
	end)
end

return SpeedTrails
