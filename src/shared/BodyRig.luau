--!strict
-- Builds the game's character body: a slim R15 rig with realistic proportions, made of plain
-- smooth blocks (low-poly style, no clothing details). The parts use the standard R15 names,
-- so Roblox's animations and ours work on it. Joint positions are worked out from the sizes in
-- Config.Body, so changing a size keeps the joints in the right place.
-- The server makes it everyone's character; the client's first-person arms copy its forearm
-- and hand.
local Config = require(script.Parent.Config)

local BodyRig = {}

-- Which color each part wears.
local COLORS: { [string]: string } = {
	Head = "Skin",
	UpperTorso = "Shirt",
	LowerTorso = "Pants",
	UpperArm = "Shirt",
	LowerArm = "Shirt",
	Hand = "Skin",
	UpperLeg = "Pants",
	LowerLeg = "Pants",
	Foot = "Boots",
}

-- Parts that collide (limbs don't, like a normal R15 character).
local SOLID = { HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true }

-- The size of a part by its R15 name ("LeftUpperArm" uses the "UpperArm" size).
local function sizeOf(name: string): Vector3
	local sizes = Config.Body.Sizes :: { [string]: Vector3 }
	return sizes[(name:gsub("^Left", ""):gsub("^Right", ""))]
end

function BodyRig.colorOf(kind: string): Color3
	return (Config.Body.Colors :: { [string]: Color3 })[COLORS[kind]]
end

-- How far the hips sit off the ground (the R15 HipHeight).
function BodyRig.hipHeight(): number
	return sizeOf("UpperLeg").Y + sizeOf("LowerLeg").Y + sizeOf("Foot").Y
end

-- One block of the body. Used for the character and the first-person arms.
function BodyRig.block(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Attachment pairs that become Motor6D joints: { joint, part0, offset0, part1, offset1 }.
local function joints(): { { any } }
	local root, lowerTorso, upperTorso =
		Vector3.new(2, 2, 1), sizeOf("LowerTorso"), sizeOf("UpperTorso")
	local head, upperArm, lowerArm = sizeOf("Head"), sizeOf("UpperArm"), sizeOf("LowerArm")
	local hand, upperLeg, lowerLeg, foot =
		sizeOf("Hand"), sizeOf("UpperLeg"), sizeOf("LowerLeg"), sizeOf("Foot")
	local list = {
		{
			"Root",
			"HumanoidRootPart",
			Vector3.new(0, -root.Y / 2 + lowerTorso.Y / 2, 0),
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
			Vector3.new(0, -head.Y / 2, 0),
		},
	}
	for _, side in { "Right", "Left" } do
		local x = if side == "Right" then 1 else -1
		local shoulderX = (upperTorso.X / 2 + upperArm.X / 2) * x
		local shoulderDrop = upperArm.X / 2 -- the joint sits a little below the top of the arm
		local hipX = (lowerTorso.X / 2 - upperLeg.X / 2) * x
		local list2 = {
			{
				side .. "Shoulder",
				"UpperTorso",
				Vector3.new(shoulderX, upperTorso.Y / 2 - shoulderDrop, 0),
				side .. "UpperArm",
				Vector3.new(0, upperArm.Y / 2 - shoulderDrop, 0),
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
				Vector3.new(0, hand.Y / 2, 0),
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
			-- The boot sticks out forward from the ankle (forward is -Z).
			{
				side .. "Ankle",
				side .. "LowerLeg",
				Vector3.new(0, -lowerLeg.Y / 2, 0),
				side .. "Foot",
				Vector3.new(0, foot.Y / 2, (foot.Z - lowerLeg.Z) / 2),
			},
		}
		for _, joint in list2 do
			table.insert(list, joint)
		end
	end
	return list
end

-- Builds the full character model: parts, attachments, Motor6D joints and the Humanoid.
function BodyRig.build(): Model
	local model = Instance.new("Model")
	model.Name = "Body"

	local root = BodyRig.block("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	model.PrimaryPart = root

	local partNames = { "Head", "UpperTorso", "LowerTorso" }
	for _, side in { "Right", "Left" } do
		for _, kind in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
			table.insert(partNames, side .. kind)
		end
	end
	for _, name in partNames do
		local kind = (name:gsub("^Left", ""):gsub("^Right", ""))
		local part = BodyRig.block(name, sizeOf(name), BodyRig.colorOf(kind))
		part.CanCollide = SOLID[name] == true
		part.CFrame = root.CFrame
		part.Parent = model
	end

	for _, joint in joints() do
		local attachmentName = joint[1] .. "RigAttachment"
		for i = 0, 1 do
			local attachment = Instance.new("Attachment")
			attachment.Name = attachmentName
			attachment.Position = joint[3 + i * 2]
			attachment.Parent = model:FindFirstChild(joint[2 + i * 2])
		end
	end

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
