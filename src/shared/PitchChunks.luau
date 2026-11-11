--!strict
-- Tag Stadium's lifting pitch chunks (tools/stadium_layout.py), worked out from the server's clock
-- and the map's ChunkSeed (set by server/StadiumWorld when it loads), so the server and every
-- player agree without sending anything. Every Config.Stadium.Cycle seconds a new random set of
-- `Up` of the `Slots` chunks is up; a chunk changing this cycle flashes for `Warn` seconds, then
-- rises or sinks over `Move` seconds.
--
-- A chunk part carries ChunkSlot and ChunkMode: Rise (straight up by ChunkHeight), Tilt (a ramp
-- turned about ChunkHinge/ChunkAxis until its far end is ChunkHeight up, ChunkLength from the
-- hinge) or Piston (the strut under a ramp, PistonAt of the way along it, ChunkDir the way from
-- the hinge). Parts are built lowered; `frame` says where one is when its chunk is `f` up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PitchChunks = {}

export type Piece = {
	part: BasePart,
	base: CFrame,
	slot: number,
	mode: string,
	height: number,
	length: number,
	hinge: Vector3,
	axis: Vector3,
	dir: number,
	at: number,
}

local SLAB = 1.2 -- a ramp's thickness (its hinge runs along its top edge)

local picks: { [string]: { [number]: boolean } } = {}
local cached = 0

-- The chunks up during cycle number `cycle`.
function PitchChunks.pick(cycle: number, seed: number): { [number]: boolean }
	local key = `{seed}:{cycle}`
	local hit = picks[key]
	if hit then
		return hit
	end
	if cached > 64 then
		table.clear(picks)
		cached = 0
	end
	local s = Config.Stadium
	local rng = Random.new((seed * 7919 + cycle) % 2147483647)
	local order = {}
	for i = 1, s.Slots do
		order[i] = i
	end
	for i = s.Slots, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local up = {}
	for i = 1, s.Up do
		up[order[i]] = true
	end
	picks[key] = up
	cached += 1
	return up
end

-- How far up each chunk is at server time `t` (0 down, 1 up), and whether it's flashing or moving.
function PitchChunks.at(t: number, seed: number): ({ number }, { boolean })
	local s = Config.Stadium
	local cycle = math.floor(t / s.Cycle)
	local into = t - cycle * s.Cycle
	local now, before = PitchChunks.pick(cycle, seed), PitchChunks.pick(cycle - 1, seed)
	local m = math.clamp((into - s.Warn) / s.Move, 0, 1)
	local eased = m * m * (3 - 2 * m)
	local up, changing = {}, {}
	for slot = 1, s.Slots do
		local isUp, wasUp = now[slot] == true, before[slot] == true
		if isUp then
			up[slot] = if wasUp then 1 else eased
		else
			up[slot] = if wasUp then 1 - eased else 0
		end
		changing[slot] = isUp ~= wasUp and into < s.Warn + s.Move
	end
	return up, changing
end

-- A chunk part's piece, from its attributes (nil if it isn't one).
function PitchChunks.piece(part: BasePart): Piece?
	local slot = part:GetAttribute("ChunkSlot")
	local mode = part:GetAttribute("ChunkMode")
	if type(slot) ~= "number" or type(mode) ~= "string" then
		return nil
	end
	local hinge = part:GetAttribute("ChunkHinge")
	local axis = part:GetAttribute("ChunkAxis")
	return {
		part = part,
		base = part.CFrame,
		slot = slot,
		mode = mode,
		height = (part:GetAttribute("ChunkHeight") or 0) :: number,
		length = (part:GetAttribute("ChunkLength") or 1) :: number,
		hinge = if typeof(hinge) == "Vector3" then hinge else Vector3.zero,
		axis = if typeof(axis) == "Vector3" then axis else Vector3.zAxis,
		dir = (part:GetAttribute("ChunkDir") or 1) :: number,
		at = (part:GetAttribute("PistonAt") or 0) :: number,
	}
end

-- Where a piece is when its chunk is `f` up.
function PitchChunks.frame(piece: Piece, f: number): CFrame
	if piece.mode == "Rise" then
		return piece.base + Vector3.new(0, f * piece.height, 0)
	end
	local angle = math.atan2(f * piece.height, piece.length)
	if piece.mode == "Tilt" then
		local turn = CFrame.new(piece.hinge)
			* CFrame.fromAxisAngle(piece.axis, angle)
			* CFrame.new(-piece.hinge)
		return turn * piece.base
	end
	-- Piston: its top stays under the ramp's underside, PistonAt of the way along it.
	local d = piece.at * piece.length
	local cos, sin = math.cos(angle), math.sin(angle)
	local along = d * cos + SLAB * sin - d
	local up = d * sin - SLAB * cos + SLAB
	return piece.base + Vector3.new(piece.dir * along, up, 0)
end

-- If `position` is under (or inside) a piece, the nearest spot just out past its edge (same
-- height); otherwise nil. For whoever is under a sinking chunk.
function PitchChunks.outFrom(part: BasePart, position: Vector3, margin: number): Vector3?
	local here = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	if math.abs(here.X) > half.X + 1 or math.abs(here.Z) > half.Z + 1 then
		return nil
	end
	if here.Y > half.Y + 1 or here.Y < -half.Y - 5 then
		return nil -- on top of it, or well under the pitch
	end
	local gapX, gapZ = half.X - math.abs(here.X), half.Z - math.abs(here.Z)
	local out = if gapX < gapZ
		then Vector3.new((if here.X >= 0 then 1 else -1) * (half.X + margin), here.Y, here.Z)
		else Vector3.new(here.X, here.Y, (if here.Z >= 0 then 1 else -1) * (half.Z + margin))
	local world = part.CFrame:PointToWorldSpace(out)
	return Vector3.new(world.X, position.Y, world.Z)
end

return PitchChunks
