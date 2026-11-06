--!strict
-- Sliding doors on a map (the Space Station; client/Doors slides them). A door's parts share a
-- `Door` name and carry `DoorSlide` (Vector3: how far that part moves when the door is open) and
-- `DoorCenter` (Vector3: the middle of the doorway). A door opens while anyone (a player or a
-- bot) is within Config.Doors.Range of its middle, on either side, and closes CloseDelay seconds
-- after the last one has gone. The server only sets each part's `DoorOpen` attribute and turns
-- the solid parts' collision off while it's open, so everyone walks through; the parts never
-- move here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Contestant = require(Shared.Contestant)

local Doors = {}

type Door = {
	parts: { BasePart },
	solid: { BasePart },
	center: Vector3,
	open: boolean,
	lastNear: number,
}

local doors: { Door } = {}
local scanned: Instance? = nil

local function scan(map: Instance?)
	table.clear(doors)
	scanned = map
	if not map then
		return
	end
	local byName: { [string]: Door } = {}
	for _, item in map:GetDescendants() do
		if not item:IsA("BasePart") or typeof(item:GetAttribute("DoorSlide")) ~= "Vector3" then
			continue
		end
		local name, center = item:GetAttribute("Door"), item:GetAttribute("DoorCenter")
		if type(name) ~= "string" or typeof(center) ~= "Vector3" then
			continue
		end
		local door = byName[name]
		if not door then
			door = { parts = {}, solid = {}, center = center, open = false, lastNear = -math.huge }
			byName[name] = door
			table.insert(doors, door)
		end
		table.insert(door.parts, item)
		if item.CanCollide then
			table.insert(door.solid, item)
		end
		item:SetAttribute("DoorOpen", false)
	end
end

local function anyoneNear(center: Vector3, range: number): boolean
	for _, contestant in Contestant.all() do
		local character = Contestant.character(contestant)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - center).Magnitude <= range then
			return true
		end
	end
	return false
end

local function setOpen(door: Door, open: boolean)
	door.open = open
	for _, part in door.parts do
		part:SetAttribute("DoorOpen", open)
	end
	for _, part in door.solid do
		part.CanCollide = not open
	end
end

function Doors.start()
	local settings = Config.Doors
	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited < settings.CheckEvery then
			return
		end
		waited = 0
		local map = workspace:FindFirstChild("ActiveMap")
		if map ~= scanned then
			scan(map)
		end
		local now = os.clock()
		for _, door in doors do
			if anyoneNear(door.center, settings.Range) then
				door.lastNear = now
				if not door.open then
					setOpen(door, true)
				end
			elseif door.open and now - door.lastNear >= settings.CloseDelay then
				setOpen(door, false)
			end
		end
	end)
end

return Doors
