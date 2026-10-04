--!strict
-- Speed trails, like the parkour reference: streaks off the hands and feet while a player is
-- moving fast or (for you) doing a move (Config.SpeedTrails). Drawn for every player, each in
-- the trail they have equipped (their EquippedTrail attribute, a Trail item in shared/Catalog:
-- one color or a gradient, optionally glowing). In first person your own hands don't trail, so
-- streaks don't smear across your view.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local SpeedTrails = {}

local LIMBS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

type Rig = { player: Player, character: Model, root: BasePart?, trails: { [string]: Trail } }

local rigs: { [Model]: Rig } = {}

-- A ColorSequence from one color (solid) or several (an even gradient).
local function sequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

-- Paints a rig's trails in its player's equipped trail.
local function applyLook(rig: Rig)
	local item = Catalog.get(rig.player:GetAttribute("EquippedTrail") :: string?)
		or Catalog.get(Config.Progression.DefaultEquipped.Trail)
	if not item then
		return
	end
	local look = item.look
	local light = (look.Light or 0) :: number
	for _, trail in rig.trails do
		trail.Color = sequence(look.Colors)
		trail.LightEmission = light
		trail.LightInfluence = 1 - light
	end
end

local function setup(player: Player, character: Model)
	local settings = Config.SpeedTrails
	local rig: Rig = { player = player, character = character, root = nil, trails = {} }
	rigs[character] = rig
	for _, name in LIMBS do
		local limb = character:WaitForChild(name, 5)
		if not limb or not limb:IsA("BasePart") then
			continue
		end
		-- A trail is drawn between two attachments; these sit at the ends of the hand or foot.
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, settings.Width / 2, 0)
		top.Parent = limb
		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -settings.Width / 2, 0)
		bottom.Parent = limb
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = settings.Lifetime
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.FaceCamera = true
		trail.MinLength = 0.05
		trail.Enabled = false
		trail.Parent = limb
		rig.trails[name] = trail
	end
	rig.root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	applyLook(rig)
	character.AncestryChanged:Connect(function()
		if not character.Parent then
			rigs[character] = nil
		end
	end)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		setup(player, character)
	end)
	if player.Character then
		task.spawn(setup, player, player.Character)
	end
	player:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
		for _, rig in rigs do
			if rig.player == player then
				applyLook(rig)
			end
		end
	end)
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
		for _, rig in rigs do
			local on = false
			local mine = rig.player == localPlayer
			if mine then
				local parts = MoveState.parts()
				if parts then
					on = parts.root.AssemblyLinearVelocity.Magnitude >= settings.MinSpeed
						or (MoveState.busy ~= nil and moves[MoveState.busy] == true)
				end
			elseif rig.root and rig.root.Parent then
				on = rig.root.AssemblyLinearVelocity.Magnitude >= settings.MinSpeed
			end
			for name, trail in rig.trails do
				local isHand = name == "LeftHand" or name == "RightHand"
				trail.Enabled = on and not (mine and firstPerson and isHand)
			end
		end
	end)
end

return SpeedTrails
