--!strict
-- Canyon Express: everything that "moves" on the map, worked out from the server clock so every
-- screen agrees and nothing is sent. The world (not the trains) moves: `distance` is how far it has
-- slid past; Train A never moves; Train B drifts (`trainB`); obstacles come down the line in an
-- order that looks random but is the same everywhere (`obstacles`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ScrollLine = {}

export type Obstacle = { kind: string, pool: number, x: number }

function ScrollLine.distance(t: number): number
	return t * Config.ScrollWorld.Speed
end

-- Train B's offset from where it's built (built at the middle gap, no drift).
function ScrollLine.trainB(t: number): Vector3
	local s = Config.ScrollWorld
	return Vector3.new(
		s.DriftX * math.sin(t * s.DriftRate),
		0,
		s.GapSwing * math.sin(t * s.GapRate + 0.6)
	)
end

-- A number from 0 to 1 that depends only on (slot, salt).
local function hash(slot: number, salt: number): number
	local n = (slot * 7919 + salt * 104729) % 2147483647
	for _ = 1, 3 do
		n = (n * 16807) % 2147483647
	end
	return n / 2147483647
end

local function kindOf(slot: number): string
	local roll, s = hash(slot, 1), Config.ScrollWorld
	for _, entry in s.Kinds do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Kind
		end
	end
	return s.Kinds[1].Kind
end

-- Every obstacle on the line at time `t`: its kind, which of that kind's pieces shows it, and
-- where its middle is along the track (x).
function ScrollLine.obstacles(t: number): { Obstacle }
	local s = Config.ScrollWorld
	local duration = (s.StartX - s.EndX) / s.Speed
	local out: { Obstacle } = {}
	local used: { [string]: number } = {}
	local first = math.floor((t - duration) / s.Every) - 1
	for slot = first, math.floor(t / s.Every) do
		local start = slot * s.Every + hash(slot, 2) * s.Jitter
		local age = t - start
		if age >= 0 and age < duration then
			local kind = kindOf(slot)
			local pool = (used[kind] or 0) + 1
			used[kind] = pool
			table.insert(out, { kind = kind, pool = pool, x = s.StartX - s.Speed * age })
		end
	end
	return out
end

return ScrollLine
