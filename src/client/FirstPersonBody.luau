--!strict
-- First person: you see your own body. Roblox hides your whole character when the camera is
-- zoomed in; this draws your arms and legs again as copies only you see, slimmer than the real
-- limbs (Config.FirstPerson.ArmThickness and LegThickness, so they read as hands and legs at
-- the edge of the view instead of walls of plastic). The copies follow the real limbs every
-- frame, so every animation (run, jump, slide, crouch, wall run, tag swipe) shows exactly as it
-- does in third person; FirstPersonArms moves the arms so the hands stay in view. The head,
-- torso and accessories stay hidden, and your own highlight (the red "It" glow) is turned off on
-- your screen only, so it doesn't tint your view.
-- The camera also follows your head as the animations move it, so a slide, crouch or wall run
-- moves your view naturally, and it sits a little ahead of the chest (Config.Camera.BodyForward)
-- so you never look out from inside your body.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MoveState = require(script.Parent.MoveState)
local ViewMode = require(script.Parent.ViewMode)

local FirstPersonBody = {}

local ARMS =
	{ "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand" }
local LEGS =
	{ "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" }

-- One drawn copy: of a limb (offset nil), or of a detail welded onto it (knee ball, stripe, sole).
type Copy = {
	source: BasePart,
	part: BasePart,
	limb: BasePart,
	offset: CFrame?,
	arm: boolean,
}

-- The size of `part` thinned by `k` across its length. Limbs run along Y, except cylinders
-- (along X); balls shrink evenly.
local function thinned(part: BasePart, size: Vector3, k: number): Vector3
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Cylinder then
			return Vector3.new(size.X, size.Y * k, size.Z * k)
		elseif part.Shape == Enum.PartType.Ball then
			return size * k
		end
	end
	return Vector3.new(size.X * k, size.Y, size.Z * k)
end

-- A local, anchored copy of `source` that looks the same but takes no part in physics.
local function copyOf(source: BasePart, parent: Instance): BasePart
	local archivable = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = archivable
	for _, child in copy:GetChildren() do
		if
			not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance"))
		then
			child:Destroy()
		end
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.CastShadow = false
	copy.Massless = true
	copy.LocalTransparencyModifier = 0
	copy.Parent = parent
	return copy
end

function FirstPersonBody.start()
	local player = Players.LocalPlayer
	local settings = Config.Camera
	local folder = Instance.new("Folder")
	folder.Name = "FirstPersonBody"
	local copies: { Copy } = {}
	local hidden: { BasePart } = {} -- every real part we hide in first person
	local built: Model? = nil
	local restHead: Vector3? = nil -- where the head sits relative to the root when standing still
	local offset = Vector3.zero
	local wasFirstPerson = ViewMode.isFirstPerson()

	local function build(character: Model)
		folder:ClearAllChildren()
		table.clear(copies)
		table.clear(hidden)
		built = character
		restHead = nil
		local limbs: { [string]: boolean } = {}
		for _, name in ARMS do
			limbs[name] = true
		end
		for _, name in LEGS do
			limbs[name] = false
		end
		for name, arm in limbs do
			local limb = character:FindFirstChild(name)
			if not limb or not limb:IsA("BasePart") then
				continue
			end
			table.insert(
				copies,
				{ source = limb, part = copyOf(limb, folder), limb = limb, arm = arm }
			)
			for _, detail in limb:GetDescendants() do
				if detail:IsA("BasePart") then
					table.insert(copies, {
						source = detail,
						part = copyOf(detail, folder),
						limb = limb,
						offset = limb.CFrame:ToObjectSpace(detail.CFrame),
						arm = arm,
					})
				end
			end
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				table.insert(hidden, part)
			end
		end
	end

	local function setup(character: Model)
		for _, name in LEGS do
			character:WaitForChild(name)
		end
		for _, name in ARMS do
			character:WaitForChild(name)
		end
		if player.Character == character then
			build(character)
		end
	end
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end

	-- Before the camera updates: move the camera with the head.
	RunService:BindToRenderStep(
		"FirstPersonHead",
		Enum.RenderPriority.Camera.Value - 1,
		function(dt)
			local parts = MoveState.parts()
			local firstPerson = ViewMode.isFirstPerson()
			if not firstPerson then
				if wasFirstPerson and parts then
					parts.humanoid.CameraOffset = Vector3.zero
				end
				wasFirstPerson = false
				return
			end
			wasFirstPerson = true
			if not parts then
				return
			end
			local head = parts.character:FindFirstChild("Head")
			if not head or not head:IsA("BasePart") then
				return
			end
			local headLocal = parts.root.CFrame:PointToObjectSpace(head.Position)
			-- Learn the resting head position the first time you're standing still on the ground.
			if not restHead then
				local still = MoveState.flat(parts.root.AssemblyLinearVelocity).Magnitude < 0.5
				if MoveState.busy or not still or not MoveState.isGrounded(parts.humanoid) then
					return
				end
				restHead = headLocal
			end
			local target = (headLocal - (restHead :: Vector3))
				+ Vector3.new(0, 0, -settings.BodyForward)
			offset = offset:Lerp(target, 1 - math.exp(-settings.HeadFollow * dt))
			parts.humanoid.CameraOffset = offset
		end
	)

	-- After the camera updates (it hides the whole character in first person): draw the limbs.
	local showing = false
	RunService:BindToRenderStep("FirstPersonBody", Enum.RenderPriority.Camera.Value + 1, function()
		local firstPerson = ViewMode.isFirstPerson()
		local character = player.Character
		local highlight = character and character:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.Enabled = not firstPerson
		end
		local show = firstPerson
			and character ~= nil
			and character == built
			and MoveState.parts() ~= nil
		if show ~= showing then
			showing = show
			folder.Parent = if show then workspace.CurrentCamera else nil
			if not show then
				-- Back to third person: let the camera decide what's see-through again.
				for _, part in hidden do
					part.LocalTransparencyModifier = 0
				end
			end
		end
		if not show then
			return
		end
		for _, part in hidden do
			part.LocalTransparencyModifier = 1
		end
		local look = Config.FirstPerson
		for _, copy in copies do
			local k = if copy.arm then look.ArmThickness else look.LegThickness
			local part, source = copy.part, copy.source
			local size = thinned(source, source.Size, k)
			if part.Size ~= size then
				part.Size = size
			end
			if copy.offset then
				-- Details sit where they're welded, pulled in with the thinner limb.
				local at = copy.offset.Position
				part.CFrame = copy.limb.CFrame
					* CFrame.new(at.X * k, at.Y, at.Z * k)
					* copy.offset.Rotation
			else
				part.CFrame = source.CFrame
			end
			part.Color = source.Color
			part.Transparency = source.Transparency
		end
	end)
end

return FirstPersonBody
