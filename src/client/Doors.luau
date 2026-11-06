--!strict
-- Slides the sliding doors on this screen (server/Doors decides when they open and turns their
-- collision off): each part with `DoorSlide` moves that far from where it was built while its
-- `DoorOpen` attribute is true, easing over Config.Doors.SlideTime, and slides back when it
-- closes, with an air hiss as it opens and a thunk as it shuts (3D at the doorway). Parts that
-- stream in later are picked up too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sounds = require(script.Parent.Sounds)

local Doors = {}

type Leaf = { part: BasePart, base: CFrame, slide: Vector3, amount: number }

local leaves: { Leaf } = {}
local heard: { [string]: boolean } = {} -- each door's state when its sound last played
local watching: RBXScriptConnection? = nil

local function add(item: Instance)
	if not item:IsA("BasePart") then
		return
	end
	local slide = item:GetAttribute("DoorSlide")
	if typeof(slide) == "Vector3" then
		table.insert(leaves, { part = item, base = item.CFrame, slide = slide, amount = 0 })
	end
end

local function watch(map: Instance)
	table.clear(leaves)
	if watching then
		watching:Disconnect()
	end
	table.clear(heard)
	for _, item in map:GetDescendants() do
		add(item)
	end
	watching = map.DescendantAdded:Connect(add)
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

function Doors.start()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "ActiveMap" then
			watch(child)
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "ActiveMap" then
			table.clear(leaves)
		end
	end)
	local current = workspace:FindFirstChild("ActiveMap")
	if current then
		watch(current)
	end
	RunService.Heartbeat:Connect(function(dt)
		local step = dt / Config.Doors.SlideTime
		for i = #leaves, 1, -1 do
			local leaf = leaves[i]
			if not leaf.part.Parent then
				table.remove(leaves, i)
				continue
			end
			local open = leaf.part:GetAttribute("DoorOpen") == true
			local name, center =
				leaf.part:GetAttribute("Door"), leaf.part:GetAttribute("DoorCenter")
			if type(name) == "string" and typeof(center) == "Vector3" then
				if heard[name] == nil then
					heard[name] = open -- (no sound for the state it was in when it loaded)
				elseif heard[name] ~= open then
					heard[name] = open
					Sounds.at(if open then "door_open" else "door_close", center)
				end
			end
			local target = if open then 1 else 0
			if leaf.amount ~= target then
				leaf.amount = if target > leaf.amount
					then math.min(target, leaf.amount + step)
					else math.max(target, leaf.amount - step)
				leaf.part.CFrame = leaf.base + leaf.slide * smooth(leaf.amount)
			end
		end
	end)
end

return Doors
