--!strict
-- A map's train (the Metro): where it is on its track and what it's doing at any moment. The
-- map has a TrainLine module (its track, cars, timetable and hit zones, generated with the map)
-- and two attributes the server sets when the map loads: TrainEpoch (the server time its
-- timetable starts) and TrainSeed (picks the random waits). Everything here is worked out from
-- those and the server clock, the same way on the server (server/Trains) and every client
-- (client/Trains), so nothing about the train is ever sent. Ported from the Metro design canvas.
--
-- The track is lines and arcs laid end to end, measured by s (studs along it). The train is
-- placed by its nose's s: each car sits between its two bogies on the track. Train coordinates:
-- u studs back from the nose, w studs to the train's left (the platform side at both stops).
-- One trip round the timetable: wait out of sight, come in on A (boarding), board, ride the
-- loop, stop on B (exit only: everyone is pushed out), leave round the other loop.
local TrainLine = {}

export type Spec = any
export type Frame = { x: number, z: number, h: number } -- h: heading, radians from +X towards +Z
export type Phase = {
	name: string,
	start: number,
	dur: number,
	s: number?,
	from: number?,
	dist: number?,
	run: { number }?,
	doors: string?,
}
export type Cycle = {
	k: number,
	start: number,
	finish: number,
	phases: { Phase },
	byName: { [string]: Phase },
	warnA: { number },
	warnB: { number },
	next: Cycle?,
}
export type State = {
	t: number,
	cycle: Cycle,
	phase: Phase,
	into: number, -- seconds into the phase
	s: number, -- the nose's place on the track
	speed: number,
	open: number, -- doors: 0 shut, 1 open
	push: boolean, -- everyone aboard is being pushed out (exit stop)
	gate: boolean, -- no getting on (the exit stop)
	warnA: boolean, -- the train is about to come through the station on track A
	warnB: boolean,
}
export type Timetable = {
	spec: Spec,
	seed: number,
	epoch: number,
	cycle: Cycle,
	at: (self: Timetable, t: number) -> State,
}

-- ---- the track --------------------------------------------------------------------------------

function TrainLine.trackAt(spec: Spec, s: number): (number, number)
	s = s % spec.length
	local segs = spec.segs
	local seg = segs[#segs]
	for _, g in segs do
		if s <= g.s0 + g.len + 1e-9 then
			seg = g
			break
		end
	end
	local t = s - seg.s0
	if seg.kind == "L" then
		local a = math.rad(seg.heading)
		return seg.x + t * math.cos(a), seg.z + t * math.sin(a)
	end
	local b = math.rad(seg.heading + seg.side * math.deg(t / seg.radius))
	return seg.cx + seg.side * seg.radius * math.sin(b),
		seg.cz - seg.side * seg.radius * math.cos(b)
end

-- Car c (1 = the front car) with the nose at s: the middle of its two bogies, facing from the
-- rear one to the front one.
function TrainLine.carFrame(spec: Spec, nose: number, c: number): Frame
	local mid = nose - spec.carLen / 2 - (c - 1) * (spec.carLen + spec.gap)
	local fx, fz = TrainLine.trackAt(spec, mid + spec.bogie)
	local rx, rz = TrainLine.trackAt(spec, mid - spec.bogie)
	return { x = (fx + rx) / 2, z = (fz + rz) / 2, h = math.atan2(fz - rz, fx - rx) }
end

function TrainLine.frames(spec: Spec, nose: number): { Frame }
	local out = {}
	for c = 1, spec.cars do
		out[c] = TrainLine.carFrame(spec, nose, c)
	end
	return out
end

-- A slice of the gangway between car g and the next: t of the way from the back of car g to the
-- front of car g + 1, turned that far between their headings, so the bellows bend.
function TrainLine.gangSlice(spec: Spec, a: Frame, b: Frame, t: number): Frame
	local half = spec.carLen / 2
	local rx, rz = a.x - math.cos(a.h) * half, a.z - math.sin(a.h) * half
	local fx, fz = b.x + math.cos(b.h) * half, b.z + math.sin(b.h) * half
	local dh = b.h - a.h
	dh = math.atan2(math.sin(dh), math.cos(dh))
	return { x = rx + (fx - rx) * t, z = rz + (fz - rz) * t, h = a.h + dh * t }
end

-- A frame as a CFrame at floor level: its X axis along the heading.
function TrainLine.frameCFrame(frame: Frame): CFrame
	return CFrame.new(frame.x, 0, frame.z) * CFrame.Angles(0, -frame.h, 0)
end

-- A point of the train (u back from the nose, w to the left) in the world: x, z.
function TrainLine.trainPoint(spec: Spec, frames: { Frame }, u: number, w: number): (number, number)
	local pitch = spec.carLen + spec.gap
	local c = math.clamp(math.floor(u / pitch), 0, spec.cars - 1)
	local f = frames[c + 1]
	local forward = spec.carLen / 2 + c * pitch - u
	return f.x + forward * math.cos(f.h) + w * math.sin(f.h),
		f.z + forward * math.sin(f.h) - w * math.cos(f.h)
end

-- Where a world point is on the train: the car it's over (or nil), its u and w. `margin` grows
-- each car's box; `nose` lets the front of the first car reach further (in front of the train).
function TrainLine.locate(
	spec: Spec,
	frames: { Frame },
	x: number,
	z: number,
	margin: number,
	nose: number?
): (number?, number, number)
	local pitch = spec.carLen + spec.gap
	local half, side = spec.carLen / 2 + spec.gap / 2, spec.width / 2 + margin
	for c, f in frames do
		local dx, dz = x - f.x, z - f.z
		local forward = dx * math.cos(f.h) + dz * math.sin(f.h)
		local w = dx * math.sin(f.h) - dz * math.cos(f.h)
		local ahead = if c == 1 and nose then spec.carLen / 2 + nose else half
		if forward <= ahead and forward >= -half and math.abs(w) <= side then
			return c, spec.carLen / 2 + (c - 1) * pitch - forward, w
		end
	end
	return nil, 0, 0
end

-- The door nearest u (its u).
function TrainLine.nearestDoor(spec: Spec, u: number): number
	local best = spec.doors[1]
	for _, d in spec.doors do
		if math.abs(d - u) < math.abs(best - u) then
			best = d
		end
	end
	return best
end

-- ---- runs between stops: speed up, run, slow down ---------------------------------------------
-- A run is { acceleration, top speed, deceleration }.

type Shape = {
	a: number,
	d: number,
	top: number,
	up: number,
	down: number,
	t1: number,
	t2: number,
	t3: number,
	dist: number,
}

local function shape(dist: number, run: { number }): Shape
	local a, d = run[1], run[3]
	local top = run[2]
	local up, down = top * top / (2 * a), top * top / (2 * d)
	if up + down > dist then
		top = math.sqrt(dist / (1 / (2 * a) + 1 / (2 * d)))
		up, down = top * top / (2 * a), top * top / (2 * d)
	end
	local t1 = top / a
	local t2 = t1 + (dist - up - down) / top
	return {
		a = a,
		d = d,
		top = top,
		up = up,
		down = down,
		t1 = t1,
		t2 = t2,
		t3 = t2 + top / d,
		dist = dist,
	}
end

local function runTime(dist: number, run: { number }): number
	return shape(dist, run).t3
end

-- Distance covered and speed `t` seconds into a run.
local function runAt(t: number, dist: number, run: { number }): (number, number)
	local k = shape(dist, run)
	if t <= 0 then
		return 0, 0
	elseif t < k.t1 then
		return 0.5 * k.a * t * t, k.a * t
	elseif t < k.t2 then
		return k.up + k.top * (t - k.t1), k.top
	elseif t < k.t3 then
		local u = t - k.t2
		return k.up + k.top * (k.t2 - k.t1) + k.top * u - 0.5 * k.d * u * u, k.top - k.d * u
	end
	return dist, 0
end

-- Seconds into a run until it has covered `covered`.
local function runUntil(covered: number, dist: number, run: { number }): number
	local k = shape(dist, run)
	if covered <= k.up then
		return math.sqrt(2 * covered / k.a)
	elseif covered <= dist - k.down then
		return k.t1 + (covered - k.up) / k.top
	end
	return k.t3 - math.sqrt(2 * math.max(0, dist - covered) / k.d)
end

-- ---- the timetable ----------------------------------------------------------------------------

local function makeCycle(spec: Spec, seed: number, k: number, start: number): Cycle
	local S, L = spec.schedule, spec.length
	local sA, sB, sW = spec.stops.A, spec.stops.B, spec.stops.W
	local approach, ride, leave = (sA - sW) % L, (sB - sA) % L, (sW - sB) % L
	local wait = S.firstWait
	if k > 0 then
		wait = S.waitMin + (S.waitMax - S.waitMin) * Random.new(seed * 4096 + k):NextNumber()
	end
	local list: { { any } } = {
		{ "wait", wait, { s = sW } },
		{
			"approach",
			runTime(approach, S.approach),
			{ from = sW, dist = approach, run = S.approach },
		},
		{ "doorsOpen", S.doorsOpen, { s = sA, doors = "open" } },
		{ "board", S.board, { s = sA, doors = "full" } },
		{ "doorsClose", S.doorsClose, { s = sA, doors = "close" } },
		{ "depart", S.departDelay, { s = sA } },
		{ "ride", runTime(ride, S.ride), { from = sA, dist = ride, run = S.ride } },
		{ "exitOpen", S.exitOpen, { s = sB, doors = "open" } },
		{ "exitPush", S.exitPush, { s = sB, doors = "full" } },
		{ "exitClose", S.exitClose, { s = sB, doors = "close" } },
		{ "leave", runTime(leave, S.leave), { from = sB, dist = leave, run = S.leave } },
	}
	local t = start
	local phases: { Phase } = {}
	local byName: { [string]: Phase } = {}
	for _, item in list do
		local info = item[3]
		local phase: Phase = {
			name = item[1],
			start = t,
			dur = item[2],
			s = info.s,
			from = info.from,
			dist = info.dist,
			run = info.run,
			doors = info.doors,
		}
		t += phase.dur
		table.insert(phases, phase)
		byName[phase.name] = phase
	end
	-- The edge lights flash from S.warn seconds before the nose comes into the station until the
	-- train stops.
	local inApproach = byName.approach
	local inRide = byName.ride
	local tA = inApproach.start + runUntil((spec.stops.portalA - sW) % L, approach, S.approach)
	local tB = inRide.start + runUntil((spec.stops.portalB - sA) % L, ride, S.ride)
	return {
		k = k,
		start = start,
		finish = t,
		phases = phases,
		byName = byName,
		warnA = { tA - S.warn, inApproach.start + inApproach.dur },
		warnB = { tB - S.warn, inRide.start + inRide.dur },
	}
end

local function nextCycle(timetable: Timetable, cycle: Cycle): Cycle
	if not cycle.next then
		cycle.next = makeCycle(timetable.spec, timetable.seed, cycle.k + 1, cycle.finish)
	end
	return cycle.next :: Cycle
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- The train at server time t.
local function at(timetable: Timetable, t: number): State
	if t < timetable.cycle.start then
		timetable.cycle = makeCycle(timetable.spec, timetable.seed, 0, timetable.epoch)
	end
	while t >= timetable.cycle.finish do
		timetable.cycle = nextCycle(timetable, timetable.cycle)
	end
	local cycle = timetable.cycle
	local phase = cycle.phases[#cycle.phases]
	for _, p in cycle.phases do
		if t < p.start + p.dur then
			phase = p
			break
		end
	end
	local into = math.max(0, t - phase.start)
	local s, speed = phase.s or 0, 0
	if phase.dist and phase.from and phase.run then
		local covered
		covered, speed = runAt(into, phase.dist, phase.run)
		s = phase.from + covered
	end
	local open = 0
	if phase.doors == "open" then
		open = smooth(into / phase.dur)
	elseif phase.doors == "full" then
		open = 1
	elseif phase.doors == "close" then
		open = 1 - smooth(into / phase.dur)
	end
	return {
		t = t,
		cycle = cycle,
		phase = phase,
		into = into,
		s = s % timetable.spec.length,
		speed = speed,
		open = open,
		push = phase.name == "exitPush",
		gate = string.sub(phase.name, 1, 4) == "exit",
		warnA = t >= cycle.warnA[1] and t < cycle.warnA[2],
		warnB = t >= cycle.warnB[1] and t < cycle.warnB[2],
	}
end

-- A timetable for the map's train: `epoch` and `seed` from its TrainEpoch and TrainSeed.
function TrainLine.timetable(spec: Spec, seed: number, epoch: number): Timetable
	return {
		spec = spec,
		seed = seed,
		epoch = epoch,
		cycle = makeCycle(spec, seed, 0, epoch),
		at = at,
	}
end

-- When the train next stops on the boarding side (server time), for the departure boards.
function TrainLine.nextArrival(timetable: Timetable, state: State): number
	local here = state.cycle.byName.approach
	if state.t < here.start + here.dur then
		return here.start + here.dur
	end
	local after = nextCycle(timetable, state.cycle).byName.approach
	return after.start + after.dur
end

-- What the departure boards say.
function TrainLine.boardText(timetable: Timetable, state: State): string
	local function clock(seconds: number): string
		local n = math.max(0, math.ceil(seconds - 0.05))
		return string.format("%d:%02d", n // 60, n % 60)
	end
	local name = state.phase.name
	local P = state.cycle.byName
	if name == "approach" then
		return "STAND CLEAR"
	elseif name == "doorsOpen" then
		return "BOARDING"
	elseif name == "board" then
		return "DOORS CLOSE " .. clock(P.doorsClose.start - state.t)
	elseif name == "doorsClose" then
		return "DOORS CLOSING"
	elseif name == "exitOpen" or name == "exitPush" then
		return "EXIT ONLY"
	end
	return "NEXT TRAIN " .. clock(TrainLine.nextArrival(timetable, state) - state.t)
end

return TrainLine
