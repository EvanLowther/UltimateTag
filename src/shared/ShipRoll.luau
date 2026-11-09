--!strict
-- The Arctic Icebreaker's motion, worked out from the server clock so every screen agrees and
-- nothing is sent: a gentle sway, jolts now and then, and a big tip every so often, with a warning
-- first. Positive roll lifts the +X side. The loose containers slide to the low side on each tip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ShipRoll = {}

local function hash(slot: number, salt: number): number
	local n = (slot * 7919 + salt * 104729) % 2147483647
	for _ = 1, 3 do
		n = (n * 16807) % 2147483647
	end
	return n / 2147483647
end

local function tipStart(slot: number): number
	local s = Config.ShipRoll
	return slot * s.TipEvery + hash(slot, 1) * s.TipJitter
end

local function tipDirection(slot: number): number
	return if hash(slot, 2) < 0.5 then -1 else 1
end

local function ease(k: number): number
	return k * k * (3 - 2 * k)
end

-- The ship's roll in radians at time `t`, and whether the warning is on.
function ShipRoll.at(t: number): (number, boolean)
	local s = Config.ShipRoll
	local big, warn = 0, false
	local slot = math.floor(t / s.TipEvery)
	for i = slot - 1, slot do
		local p = t - tipStart(i)
		if p >= 0 and p < s.Warn + s.Rise + s.Hold + s.Fall then
			local amount = 0
			if p < s.Warn then
				warn = true
			elseif p < s.Warn + s.Rise then
				amount = ease((p - s.Warn) / s.Rise)
			elseif p < s.Warn + s.Rise + s.Hold then
				amount = 1
			else
				amount = 1 - ease((p - s.Warn - s.Rise - s.Hold) / s.Fall)
			end
			big = amount * tipDirection(i)
		end
	end
	local jolt = 0
	local joltSlot = math.floor(t / s.JoltEvery)
	for i = joltSlot - 1, joltSlot do
		local start = i * s.JoltEvery + hash(i, 3) * s.JoltEvery * 0.5
		if t >= start then
			local sign = if hash(i, 4) < 0.5 then -1 else 1
			jolt += sign * s.Jolt * (0.6 + 0.4 * hash(i, 5)) * math.exp(-(t - start) * s.JoltDecay)
		end
	end
	local calm = 1 - math.abs(big)
	local roll = (s.Sway * math.sin(t * s.SwayRate) + jolt) * calm + big * s.MaxRoll
	return math.rad(roll), warn
end

-- Loose container `index` (1 and 2 share the first lane, 3 and 4 the second; odd is the one
-- nearer -X): how far along X it is at time `t`, and its speed.
function ShipRoll.container(t: number, index: number): (number, number)
	local s = Config.ShipRoll
	local slot = math.floor(t / s.TipEvery)
	if t < tipStart(slot) + s.Warn + s.SlideStart then
		slot -= 1 -- the latest tip whose slide has begun
	end
	local function rest(i: number): number
		local low = -tipDirection(i) -- the side that dips
		local odd = index % 2 == 1
		if low < 0 then
			return if odd then -s.Lane else -s.Lane + s.Pair
		end
		return if odd then s.Lane - s.Pair else s.Lane
	end
	local from, to = rest(slot - 1), rest(slot)
	local k = math.clamp((t - tipStart(slot) - s.Warn - s.SlideStart) / s.SlideTime, 0, 1)
	local x = from + (to - from) * k * k
	local speed = if k < 1 then (to - from) * 2 * k / s.SlideTime else 0
	return x, speed
end

return ShipRoll
