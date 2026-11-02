--!strict
-- A character's joints, whichever kind it has: Motor6Ds, or the AnimationConstraints that
-- Roblox's Avatar Joint Upgrade puts in their place (rolling out to every game since 2026, in
-- Studio and live servers alike). Both have a Transform that the Animator writes every frame and
-- code can change in PreSimulation; an AnimationConstraint's Attachment0 and Attachment1 (and the
-- parts they're on) stand in for a Motor6D's C0 and C1 (Part0 and Part1), with the same math:
-- Part1 = Part0 * C0 * Transform * C1:Inverse().
local Joints = {}

export type Joint = any -- a Motor6D or an AnimationConstraint

local function isConstraint(joint: Instance): boolean
	return joint:IsA("AnimationConstraint")
end

-- The part a joint hangs from, and the part it moves.
function Joints.part0(joint: Joint): BasePart?
	if isConstraint(joint) then
		local attachment = joint.Attachment0
		local part = attachment and attachment.Parent
		return if part and part:IsA("BasePart") then part else nil
	end
	return joint.Part0
end

function Joints.part1(joint: Joint): BasePart?
	if isConstraint(joint) then
		local attachment = joint.Attachment1
		local part = attachment and attachment.Parent
		return if part and part:IsA("BasePart") then part else nil
	end
	return joint.Part1
end

-- The joint's frame on each part (a Motor6D's C0 and C1).
function Joints.c0(joint: Joint): CFrame
	if isConstraint(joint) then
		local attachment = joint.Attachment0
		return if attachment then attachment.CFrame else CFrame.identity
	end
	return joint.C0
end

function Joints.c1(joint: Joint): CFrame
	if isConstraint(joint) then
		local attachment = joint.Attachment1
		return if attachment then attachment.CFrame else CFrame.identity
	end
	return joint.C1
end

-- Where a joint puts its part relative to the part it hangs from, animation included.
function Joints.offset(joint: Joint): CFrame
	return Joints.c0(joint) * joint.Transform * Joints.c1(joint):Inverse()
end

-- The joint that moves each body part, by the part's name. Where a part has both kinds (a rig
-- caught mid-upgrade), the AnimationConstraint wins: it's the one the Animator drives.
function Joints.find(model: Instance): { [string]: Joint }
	local joints: { [string]: Joint } = {}
	for _, descendant in model:GetDescendants() do
		local constraint = isConstraint(descendant)
		if constraint or descendant:IsA("Motor6D") then
			local part = Joints.part1(descendant)
			if part and Joints.part0(descendant) then
				local had = joints[part.Name]
				if not had or (constraint and not isConstraint(had)) then
					joints[part.Name] = descendant
				end
			end
		end
	end
	return joints
end

-- The same, kept per model and found again when a joint is added or one goes away (the joint
-- upgrade can swap a rig's joints after it spawns).
local cache: { [Instance]: { [string]: Joint } } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function Joints.of(model: Instance): { [string]: Joint }
	local joints = cache[model]
	if joints then
		for _, joint in joints do
			if not joint.Parent then
				joints = nil
				break
			end
		end
	end
	if not joints then
		joints = Joints.find(model)
		cache[model] = joints
		if not watched[model] then
			watched[model] = true
			model.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("Motor6D") or isConstraint(descendant) then
					cache[model] = nil
				end
			end)
		end
	end
	return joints :: { [string]: Joint }
end

return Joints
