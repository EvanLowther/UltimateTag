--!strict
-- Builds the game's character body: a smooth, rounded cartoon person (Crab Game style) made of
-- Roblox's round shapes. Limbs are cylinders with ball joints, the head and hands are balls,
-- and the face (eyes, pupils, mouth) and hair are small shapes welded on. The parts use the
-- standard R15 names and joints, so Roblox's animations and ours work on it. Sizes and colors
-- live in Config.Body, and joint positions are worked out from the sizes.
--
-- Cylinders lie along their X axis, so each limb is turned upright through its attachments:
-- every joint frame still uses the standard axes, so animation angles mean the same as on a
-- normal R15 character.
local Config = require(script.Parent.Config)

local BodyRig = {}

-- Which color each body part wears.
local COLORS: { [string]: string } = {
	Head = "Skin",
	UpperTorso = "Jacket",
	LowerTorso = "Pants",
	UpperArm = "Jacket",
	LowerArm = "Jacket",
	Hand = "Skin",
	UpperLeg = "Pants",
	LowerLeg = "Pants",
	Foot = "Shoes",
}

local LIMBS = { UpperArm = true, LowerArm = true, UpperLeg = true, LowerLeg = true }
local BALLS = { Head = true, Hand = true }
local SOLID = { HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true }

-- Turns a limb's local frame (cylinder along X) into the standard frame (length along Y).
local UPRIGHT = CFrame.Angles(0, 0, -math.pi / 2)

-- "LeftUpperArm" -> "UpperArm"
local function kindOf(name: string): string
	return (name:gsub("^Left", ""):gsub("^Right", ""))
end

local function sizeOf(name: string): Vector3
	return (Config.Body.Sizes :: { [string]: Vector3 })[kindOf(name)]
end

local function color(key: string): Color3
	return (Config.Body.Colors :: { [string]: Color3 })[key]
end

function BodyRig.colorOf(kind: string): Color3
	return color(COLORS[kind])
end

-- How far the hips sit off the ground (the R15 HipHeight).
function BodyRig.hipHeight(): number
	return sizeOf("UpperLeg").Y + sizeOf("LowerLeg").Y + sizeOf("Foot").Y
end

-- A frame inside part `name`, given in standard axes (Y along the limb).
local function frameIn(name: string, position: Vector3): CFrame
	if LIMBS[kindOf(name)] then
		return CFrame.new(UPRIGHT:VectorToWorldSpace(position)) * UPRIGHT
	end
	return CFrame.new(position)
end

-- One smooth part. Used for the character and the first-person arms.
function BodyRig.block(name: string, size: Vector3, partColor: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = partColor
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- The real part for a body part name, shaped for its kind.
local function bodyPart(name: string): Part
	local kind = kindOf(name)
	local size = sizeOf(name)
	if LIMBS[kind] then
		return BodyRig.block(
			name,
			Vector3.new(size.Y, size.X, size.X),
			BodyRig.colorOf(kind),
			Enum.PartType.Cylinder
		)
	elseif BALLS[kind] then
		return BodyRig.block(name, Vector3.one * size.X, BodyRig.colorOf(kind), Enum.PartType.Ball)
	end
	return BodyRig.block(name, size, BodyRig.colorOf(kind))
end

-- A decoration (face, hair, stripes, joint balls) welded onto a body part. Doesn't collide,
-- weigh anything or get hit by raycasts.
local function decorate(
	body: BasePart,
	name: string,
	size: Vector3,
	colorKey: string,
	position: Vector3,
	shape: Enum.PartType?
)
	local part = BodyRig.block(name, size, color(colorKey), shape)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = body.CFrame * frameIn(body.Name, position)
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = part
	weld.C0 = frameIn(body.Name, position)
	weld.Parent = part
	part.Parent = body
end

-- Attachment pairs that become Motor6D joints: { joint, part0, offset0, part1, offset1 }.
local function joints(): { { any } }
	local lowerTorso, upperTorso, head = sizeOf("LowerTorso"), sizeOf("UpperTorso"), sizeOf("Head")
	local upperArm, lowerArm, hand = sizeOf("UpperArm"), sizeOf("LowerArm"), sizeOf("Hand")
	local upperLeg, lowerLeg, foot = sizeOf("UpperLeg"), sizeOf("LowerLeg"), sizeOf("Foot")
	local list = {
		{
			"Root",
			"HumanoidRootPart",
			Vector3.new(0, -1 + lowerTorso.Y / 2, 0),
			"LowerTorso",
			Vector3.zero,
		},
		{
			"Waist",
			"LowerTorso",
			Vector3.new(0, lowerTorso.Y / 2, 0),
			"UpperTorso",
			Vector3.new(0, -upperTorso.Y / 2, 0),
		},
		{
			"Neck",
			"UpperTorso",
			Vector3.new(0, upperTorso.Y / 2, 0),
			"Head",
			Vector3.new(0, -head.X / 2 - 0.1, 0),
		},
	}
	for _, side in { "Right", "Left" } do
		local x = if side == "Right" then 1 else -1
		local shoulderX = (upperTorso.X / 2 + upperArm.X / 2) * x
		local inset = upperArm.X / 2 -- the shoulder sits a little below the top of the arm
		local hipX = (lowerTorso.X / 2 - upperLeg.X / 2) * x
		for _, joint in
			{
				{
					side .. "Shoulder",
					"UpperTorso",
					Vector3.new(shoulderX, upperTorso.Y / 2 - inset, 0),
					side .. "UpperArm",
					Vector3.new(0, upperArm.Y / 2 - inset, 0),
				},
				{
					side .. "Elbow",
					side .. "UpperArm",
					Vector3.new(0, -upperArm.Y / 2, 0),
					side .. "LowerArm",
					Vector3.new(0, lowerArm.Y / 2, 0),
				},
				{
					side .. "Wrist",
					side .. "LowerArm",
					Vector3.new(0, -lowerArm.Y / 2, 0),
					side .. "Hand",
					Vector3.new(0, hand.X / 2, 0),
				},
				{
					side .. "Hip",
					"LowerTorso",
					Vector3.new(hipX, -lowerTorso.Y / 2, 0),
					side .. "UpperLeg",
					Vector3.new(0, upperLeg.Y / 2, 0),
				},
				{
					side .. "Knee",
					side .. "UpperLeg",
					Vector3.new(0, -upperLeg.Y / 2, 0),
					side .. "LowerLeg",
					Vector3.new(0, lowerLeg.Y / 2, 0),
				},
				-- The shoe sticks out forward from the ankle (forward is -Z).
				{
					side .. "Ankle",
					side .. "LowerLeg",
					Vector3.new(0, -lowerLeg.Y / 2, 0),
					side .. "Foot",
					Vector3.new(0, foot.Y / 2, (foot.Z - lowerLeg.X) / 2),
				},
			}
		do
			table.insert(list, joint)
		end
	end
	return list
end

-- Face, hair, stripes and joint balls.
local function addDetails(model: Model)
	local function part(name: string): BasePart
		return model:FindFirstChild(name) :: BasePart
	end
	local head = sizeOf("Head").X / 2 -- head radius
	local headPart = part("Head")
	for _, x in { -0.19, 0.19 } do
		decorate(
			headPart,
			"Eye",
			Vector3.one * 0.26,
			"Eye",
			Vector3.new(x, 0.08, -head * 0.82),
			Enum.PartType.Ball
		)
		decorate(
			headPart,
			"Pupil",
			Vector3.one * 0.12,
			"Pupil",
			Vector3.new(x, 0.08, -head * 0.82 - 0.1),
			Enum.PartType.Ball
		)
	end
	decorate(
		headPart,
		"Mouth",
		Vector3.new(0.26, 0.05, 0.05),
		"Mouth",
		Vector3.new(0, -0.22, -head * 0.9)
	)
	decorate(
		headPart,
		"Hair",
		Vector3.one * head * 1.96,
		"Hair",
		Vector3.new(0, head * 0.4, head * 0.24),
		Enum.PartType.Ball
	)
	decorate(headPart, "Neck", Vector3.new(0.3, 0.36, 0.36), "Skin", Vector3.new(0, -head, 0))

	local upperTorso = sizeOf("UpperTorso")
	for _, side in { "Right", "Left" } do
		local x = if side == "Right" then 1 else -1
		local upperArm, lowerArm = sizeOf("UpperArm"), sizeOf("LowerArm")
		local upperLeg, lowerLeg = sizeOf("UpperLeg"), sizeOf("LowerLeg")
		-- Ball joints so bends look smooth.
		decorate(
			part("UpperTorso"),
			"Shoulder",
			Vector3.one * upperArm.X * 1.08,
			"Jacket",
			Vector3.new(
				(upperTorso.X / 2 + upperArm.X / 2) * x,
				upperTorso.Y / 2 - upperArm.X / 2,
				0
			),
			Enum.PartType.Ball
		)
		decorate(
			part(side .. "UpperArm"),
			"Elbow",
			Vector3.one * lowerArm.X * 1.05,
			"Jacket",
			Vector3.new(0, -upperArm.Y / 2, 0),
			Enum.PartType.Ball
		)
		decorate(
			part(side .. "UpperLeg"),
			"Knee",
			Vector3.one * lowerLeg.X * 1.05,
			"Pants",
			Vector3.new(0, -upperLeg.Y / 2, 0),
			Enum.PartType.Ball
		)
		-- Shoe sole.
		local foot = sizeOf("Foot")
		decorate(
			part(side .. "Foot"),
			"Sole",
			Vector3.new(foot.X * 1.02, 0.08, foot.Z * 1.02),
			"Sole",
			Vector3.new(0, -foot.Y / 2 + 0.03, 0)
		)
		-- Tracksuit side stripes on the outside of each limb.
		if Config.Body.Stripes then
			for _, limb in
				{
					{ "UpperArm", upperArm },
					{ "LowerArm", lowerArm },
					{ "UpperLeg", upperLeg },
					{ "LowerLeg", lowerLeg },
				}
			do
				local kind, size = limb[1] :: string, limb[2] :: Vector3
				decorate(
					part(side .. kind),
					"Stripe",
					Vector3.new(0.05, size.Y * 0.92, 0.1),
					"Stripe",
					Vector3.new(size.X / 2 * x, 0, 0)
				)
			end
		end
	end
	-- Zipper down the front of the jacket.
	decorate(
		part("UpperTorso"),
		"Zipper",
		Vector3.new(0.05, upperTorso.Y * 0.9, 0.02),
		"Stripe",
		Vector3.new(0, 0, -upperTorso.Z / 2)
	)
end

-- Builds the full character model: parts, details, attachments, Motor6D joints and Humanoid.
function BodyRig.build(): Model
	local model = Instance.new("Model")
	model.Name = "Body"

	local root = BodyRig.block("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root

	local names = { "Head", "UpperTorso", "LowerTorso" }
	for _, side in { "Right", "Left" } do
		for _, kind in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
			table.insert(names, side .. kind)
		end
	end
	for _, name in names do
		local part = bodyPart(name)
		part.CanCollide = SOLID[name] == true
		part.CFrame = root.CFrame
		part.Parent = model
	end

	for _, joint in joints() do
		for i = 0, 1 do
			local attachment = Instance.new("Attachment")
			attachment.Name = joint[1] .. "RigAttachment"
			attachment.CFrame = frameIn(joint[2 + i * 2], joint[3 + i * 2])
			attachment.Parent = model:FindFirstChild(joint[2 + i * 2])
		end
	end
	addDetails(model)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = BodyRig.hipHeight()
	humanoid.AutomaticScalingEnabled = false
	Instance.new("Animator").Parent = humanoid
	humanoid.Parent = model
	humanoid:BuildRigFromAttachments()
	return model
end

return BodyRig
