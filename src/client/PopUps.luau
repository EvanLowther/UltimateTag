--!strict
-- Pop-ups (the Playroom's jack-in-the-box): a launch pad that springs a toy open when someone
-- launches off it, at the same moment for everyone. The parts of one toy share a PopUp name and
-- each has a PopRole:
--   Lid:    the pad itself (it has LaunchVelocity). It turns PopAngle degrees round its hinge
--           line (PopHinge, a point on it, and PopHingeAxis) as the toy springs. The hinge is an
--           edge the lid shares with its box, so the lid stays joined to the box all the way.
--   Head:   rises PopRise studs out of the box (the clown).
--   Spring: stretches up from its base under the head.
-- The pad carries the timing: PopTime (seconds to spring open), PopCooldown (how long it stays
-- out; it launches nobody meanwhile), PopBack (the wind back down at the end of that) and PopAt,
-- the server time it last sprang, which server/PopUps sets when someone launches off it. The
-- player who launched sees it at once (trigger() sets PopAt on their screen first).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PopUps = {}

type Piece = { part: BasePart, base: CFrame, size: Vector3 }
type Toy = {
	pad: BasePart,
	lids: { Piece },
	heads: { Piece },
	springs: { Piece },
	resting: boolean,
}

local toys: { [string]: Toy } = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function number(part: BasePart, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

-- Is the pad's toy still out (sprung, not yet wound back down)?
function PopUps.sprung(pad: BasePart): boolean
	local popAt = pad:GetAttribute("PopAt")
	return type(popAt) == "number"
		and workspace:GetServerTimeNow() < popAt + number(pad, "PopCooldown", 2)
end

-- You just launched off the pad: spring it now on your screen and tell the server, which springs
-- it for everyone.
function PopUps.trigger(pad: BasePart)
	pad:SetAttribute("PopAt", workspace:GetServerTimeNow())
	Remotes.get("PopUp"):FireServer(pad)
end

local function scan(map: Instance)
	table.clear(toys)
	for _, item in map:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local name, role = item:GetAttribute("PopUp"), item:GetAttribute("PopRole")
		if type(name) ~= "string" then
			continue
		end
		local toy = toys[name]
		if not toy then
			toy = { pad = item, lids = {}, heads = {}, springs = {}, resting = true }
			toys[name] = toy
		end
		if typeof(item:GetAttribute("LaunchVelocity")) == "Vector3" then
			toy.pad = item
		end
		local piece: Piece = { part = item, base = item.CFrame, size = item.Size }
		if role == "Lid" then
			table.insert(toy.lids, piece)
		elseif role == "Head" then
			table.insert(toy.heads, piece)
		elseif role == "Spring" then
			table.insert(toy.springs, piece)
		end
	end
end

-- How far the toy is out (rise: the head, 1 = all the way) and open (the lid), `p` seconds
-- after it sprang.
local function amounts(pad: BasePart, p: number): (number, number)
	local C = Config.PopUps
	local popTime = number(pad, "PopTime", 0.12)
	local back = number(pad, "PopBack", 0.4)
	local cooldown = number(pad, "PopCooldown", 2)
	if p < popTime then
		return 1 - (1 - p / popTime) ^ 3, smooth(p / (popTime * C.LidLead))
	elseif p < cooldown - back then
		local q = p - popTime -- a bob on the spring as it settles
		return 1 + C.Wobble * math.sin(q * C.WobbleRate) * math.exp(-q * C.WobbleDamp), 1
	end
	-- Winding back down: the head sinks first, then the lid closes over it.
	local q = (p - (cooldown - back)) / back
	return 1 - smooth(q), 1 - smooth((q - C.LidCloseAt) / (1 - C.LidCloseAt))
end

local function place(toy: Toy, rise: number, open: number)
	local pad = toy.pad
	local riseStuds = number(pad, "PopRise", 6) * rise
	local hinge = pad:GetAttribute("PopHinge")
	local axis = pad:GetAttribute("PopHingeAxis")
	local turn = math.rad(number(pad, "PopAngle", -110)) * open
	for _, lid in toy.lids do
		if typeof(hinge) == "Vector3" and typeof(axis) == "Vector3" then
			-- Round the hinge line: a point on it stays put, so the lid never leaves the box.
			local pivot = CFrame.new(hinge)
			lid.part.CFrame = pivot
				* CFrame.fromAxisAngle(axis.Unit, turn)
				* pivot:Inverse()
				* lid.base
		end
	end
	for _, head in toy.heads do
		head.part.CFrame = head.base + Vector3.new(0, riseStuds, 0)
	end
	for _, spring in toy.springs do
		-- Its length runs along its own X (it stands upright): grow it from its base.
		local length = spring.size.X + riseStuds
		spring.part.Size = Vector3.new(length, spring.size.Y, spring.size.Z)
		spring.part.CFrame = spring.base + spring.base.RightVector * (length - spring.size.X) / 2
	end
end

function PopUps.start()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" then
			task.wait(0.5) -- let it finish replicating
			if child.Parent then
				scan(child)
			end
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "ActiveMap" then
			table.clear(toys)
		end
	end)
	local current = workspace:FindFirstChild("ActiveMap")
	if current then
		scan(current)
	end
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, toy in toys do
			if not toy.pad.Parent then
				continue
			end
			local popAt = toy.pad:GetAttribute("PopAt")
			local p = if type(popAt) == "number" then now - popAt else math.huge
			if p >= 0 and p < number(toy.pad, "PopCooldown", 2) then
				toy.resting = false
				place(toy, amounts(toy.pad, p))
			elseif not toy.resting then
				toy.resting = true
				place(toy, 0, 0)
			end
		end
	end)
end

return PopUps
