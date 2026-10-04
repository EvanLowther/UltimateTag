--!strict
-- The map catalog and loading. Maps live in ServerStorage.Maps (from src/maps); each is a Model
-- with attributes:
--   DisplayName  shown to players
--   MinPlayers / MaxPlayers  the player counts it suits (its size tier)
--   InRotation  false keeps it out of games (TestGround, the movement test map)
-- and a "Spawns" folder of invisible parts where players are placed.
-- One map is loaded at a time, as Workspace.ActiveMap.
local ServerStorage = game:GetService("ServerStorage")

local MapService = {}

local ACTIVE = "ActiveMap"

local nextMap: string? = nil -- set from the dev panel: used for the next round, once

local function maps(): { Model }
	local list = {}
	for _, item in ServerStorage:WaitForChild("Maps"):GetChildren() do
		if item:IsA("Model") then
			table.insert(list, item)
		end
	end
	return list
end

local function range(map: Model): (number, number)
	return (map:GetAttribute("MinPlayers") or 0) :: number,
		(map:GetAttribute("MaxPlayers") or 0) :: number
end

-- Picks a map for `playerCount` players: a random one whose size range fits, avoiding
-- `lastMap` when there's another choice. If none fits, the one whose range is closest.
function MapService.choose(playerCount: number, lastMap: string?): string?
	if nextMap then
		local forced = nextMap
		nextMap = nil
		return forced
	end
	local fits, others = {}, {}
	for _, map in maps() do
		if map:GetAttribute("InRotation") == false then
			continue
		end
		local low, high = range(map)
		if playerCount >= low and playerCount <= high then
			table.insert(fits, map.Name)
		else
			table.insert(others, map)
		end
	end
	if #fits > 1 and lastMap then
		local index = table.find(fits, lastMap)
		if index then
			table.remove(fits, index)
		end
	end
	if #fits > 0 then
		return fits[math.random(#fits)]
	end
	-- Nothing fits: the closest size tier.
	local best: Model? = nil
	local bestGap = math.huge
	for _, map in others do
		local low, high = range(map)
		local gap = if playerCount < low then low - playerCount else playerCount - high
		if gap < bestGap then
			best, bestGap = map, gap
		end
	end
	return if best then best.Name else nil
end

-- Makes the next round use `name` (or clears that with nil). Dev panel only.
function MapService.setNext(name: string?)
	nextMap = name
end

function MapService.getNext(): string?
	return nextMap
end

function MapService.exists(name: string): boolean
	local map = ServerStorage:WaitForChild("Maps"):FindFirstChild(name)
	return map ~= nil and map:IsA("Model")
end

export type MapInfo = {
	Name: string,
	DisplayName: string,
	MinPlayers: number,
	MaxPlayers: number,
	InRotation: boolean,
	Spawns: number,
}

-- Every map in the catalog, sorted by size tier (for the dev panel's map list).
function MapService.catalog(): { MapInfo }
	local list: { MapInfo } = {}
	for _, map in maps() do
		local low, high = range(map)
		table.insert(list, {
			Name = map.Name,
			DisplayName = (map:GetAttribute("DisplayName") or map.Name) :: string,
			MinPlayers = low,
			MaxPlayers = high,
			InRotation = map:GetAttribute("InRotation") ~= false,
			Spawns = #MapService.spawnPoints(map),
		})
	end
	table.sort(list, function(a, b)
		if a.MinPlayers ~= b.MinPlayers then
			return a.MinPlayers < b.MinPlayers
		end
		return a.Name < b.Name
	end)
	return list
end

-- The loaded map (Workspace.ActiveMap), if any.
function MapService.active(): Model?
	local current = workspace:FindFirstChild(ACTIVE)
	return if current and current:IsA("Model") then current else nil
end

-- The display name of a map in the catalog.
function MapService.displayName(name: string): string
	local map = ServerStorage:WaitForChild("Maps"):FindFirstChild(name)
	return if map then (map:GetAttribute("DisplayName") or name) :: string else name
end

-- Loads `name` as Workspace.ActiveMap (unloading any map already there) and returns it.
function MapService.load(name: string): Model
	MapService.unload()
	local template = ServerStorage:WaitForChild("Maps"):FindFirstChild(name)
	assert(template and template:IsA("Model"), `[MapService] no map called {name}`)
	local map = template:Clone()
	map.Name = ACTIVE
	map:SetAttribute("MapName", name)
	map.Parent = workspace
	return map
end

function MapService.unload()
	local current = workspace:FindFirstChild(ACTIVE)
	if current then
		current:Destroy()
	end
end

-- The spawn point parts of a loaded map.
function MapService.spawnPoints(map: Model): { BasePart }
	local points = {}
	local folder = map:FindFirstChild("Spawns")
	if folder then
		for _, item in folder:GetChildren() do
			if item:IsA("BasePart") then
				table.insert(points, item)
			end
		end
	end
	return points
end

return MapService
