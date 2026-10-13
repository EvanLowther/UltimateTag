#!/usr/bin/env python3
"""The Metro, design v1 (design stage: not in the game yet). 2-6 players, one floor: an
underground station in the spirit of the Gang Beasts subway. Shown on the "Metro Map" design
canvas. Built with tools/maplib.py and checked with tools/mapcheck.py like the real map
generators, so it becomes tools/metro_layout.py once the design is settled. Run from the repo
root:
    python3 tools/designs/metro_v1.py                                   (checks only)
    python3 tools/designs/canvas_export.py metro_v1 build/metro.json   (for the canvas)

Axes: X east, Z south, Y up. One long island platform (160 x 24, top at 0) between two track
pits (floor at -4, 15 wide), under a ceiling at 18:
  Track A (north) is the BOARDING side: the train comes in from the east heading west, stops
    with its doors open for SCHEDULE["board"] seconds, chimes, closes them and leaves west.
  The ride: the train runs round the west loop (a balloon loop under the city, past an old
    closed station) and comes back on track B about 17 s after its doors closed. Whoever got
    on is shut in together and keeps playing on the moving train.
  Track B (south) is the EXIT side: the doors open and everyone inside is pushed to the nearest
    door and out onto the platform; nobody can get on. Then the train runs round the east loop,
    waits a random time out of sight and comes in on A again.
Being in a track pit or in front of the train when it comes in kills you (the nose carries an
invisible TrainNose box). The pits are only 4 deep, so you can always jump back out, and the
crawl space under each platform edge (3 high: crouch or slide into it) is the one safe spot.
Moves: wall-run (or slide-jump) the works gaps at the ends of the platform, slide under the
scaffold sheds and through the staff room, juke round the kiosk, benches and columns, and cut
through the train's doors while it's in.

The train is built where it rests (stopped on A, left doors open) from parts tagged with its
working-part attributes, which the game will animate on every client from the server clock
the way client/MapAmbience does now:
  TrainCar (1-3, front to back): the part rides with that car. Cars follow TRACK: each car's
    two bogies sit on the path, BOGIE either side of the car's middle.
  TrainGangway (1-2): the flexible passage between car n and n+1 (follows both ends).
  DoorSlide (studs along the car's forward axis, closed -> open): a door leaf, built open.
  ExitPush: floor arrows that light while the exit side pushes everyone out.
  NoEntry: the doorway volumes that shove anyone out during the exit stop (no boarding there).
  TrainNose: the kill box in front of the train.
  TrackWarning ("A"/"B"): platform-edge lights that flash before a train comes in on that track.
  DepartureBoard: shows the countdown to the next train.
"""
import math
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_y  # noqa: E402

OUT = "src/maps/Metro"
ATTRIBUTES = {"DisplayName": "The Metro", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "KillHeight": -25, "Lighting": "Indoor",
              "OutOfBounds": "Ceiling,CeilingTunnel,TunnelDivider,Works,Shed,StaffRoof,Kiosk,"
                             "RoofCar,RoofCrown,CabFloor"}

# Movement numbers the gaps are built round (Config + Roblox defaults; see mapcheck).
GRAVITY = 196.2
JUMP = 7.2  # jump height
SPRINT = 30  # sprint speed
SLIDE_JUMP = 37  # a slide into a jump
WALL_RUN = 30 * 1.6  # studs along a wall in one wall run
CROUCH_ROOM = 4.2  # slide gates: the gap under them (standing needs 5)

# ---- the station ------------------------------------------------------------------------------
PX = 80  # the platform runs x -80..80; the end walls stand at x = +-80
PZ = 12  # platform half width (z -12..12)
PIT = -4  # track pit floor (the platform is 4 above it: jump back out anywhere)
CEIL = 18  # ceiling over the platform and the tracks
CUT = 8.4  # the walls are built in two parts, split here (the canvas cuts them away above it)
OUTER = 27  # the track walls' faces (z = +-27)
RECESS = 10  # the platform's body stops here: a crawl space under each edge (10..12, 3 high)
SPINE = 4  # the middle row of features: z -4..4, lanes 8 wide either side
# Platform bands from the middle out (|z|): terrazzo, tactile strip, safety line, coping.
BANDS = ((0, 9.4, "floor"), (9.4, 10.0, "tactile"), (10.0, 10.6, "safety"),
         (10.6, PZ, "coping"))
# The works at each end: a hoarded block in the middle row, a gap in one lane (wall-run along
# the hoarding, or slide-jump it) and a low scaffold shed over the other (slide under it).
WORKS = (52, 74)  # |x| of the works blocks
NOTCH = (54, 72)  # |x| of the gaps: 18 long
SHED = (59, 67)  # |x| of the sheds
WORKS_TOP = 12
SHED_TOP = 8.6
KIOSK = (-38, -28)
STAFF = (28, 38)
STAFF_DOOR = (30, 36)
BENCHES = ((-18, -8), (8, 18))
COLUMNS = (-45, -23, 0, 23, 45)  # x of the columns down the middle (z = 0)
BOARDS = (-50, 5, 50)  # x of the departure boards hanging across the platform

# ---- the train ---------------------------------------------------------------------------------
TRACK_Z = 18.6  # |z| of the two track centrelines
CARS = 3
CAR_LEN = 32
CAR_W = 12
GAP = 2  # between car bodies (the gangway)
BOGIE = 11  # bogies this far either side of a car's middle
TRAIN_LEN = CARS * CAR_LEN + (CARS - 1) * GAP  # 100
DOORS = (-8, 8)  # door centres along each car (u, from the car's middle, + towards the nose)
DOOR_W = 4.5
LEAF = DOOR_W / 2
WINDOWS = ((-15.2, -12.8), (-3.2, 3.2), (12.8, 15.2))
DOOR_TOP = 7.6
ROOF = 8.6  # interior ceiling (the roof's underside)
WALL_T = 0.4
CAB = 12.5  # the leading and trailing cabs start this far from the car's middle
GANG_W = 4.5  # gangway opening between cars
GANG_SLICES = 4  # the gangway's bellows, in slices that bend between the two car ends
ISLAND = (-4, 4, -2, 2)  # the middle car's seat island with a glass screen (u0, u1, w0, w1)

# ---- the track ---------------------------------------------------------------------------------
LOOP_R = 150  # both turns and the bulb of each balloon loop: gentle, so the cars stay apart
LOOP_STRAIGHT = 16  # straight from the portal into each loop (the train swings as it turns)
MOUTH = PX + LOOP_STRAIGHT  # the tunnel mouths run x 80..96, the loops beyond
MOUTH_FLOOR = 86  # the pit floor stops here: past it the tunnel drops away (falling kills)
TUNNEL_HALF = 8  # tunnel walls this far either side of the track in the loops
TUNNEL_TOP = 12
TUNNEL_BOTTOM = -14
SCHEDULE = {  # seconds; runs are (acceleration, top speed, braking) in studs/s
    "waitMin": 3, "waitMax": 12, "warn": 4,
    "doorsOpen": 1.5, "board": 7, "doorsClose": 2, "departDelay": 0.5,
    "exitOpen": 1.2, "exitPush": 3.5, "exitClose": 1.5,
    "approach": (15, 70, 10), "ride": (15, 100, 15), "leave": (15, 100, 15),
}

COLORS = {
    "tile": (238, 234, 222), "band_a": (110, 205, 70), "band_b": (232, 64, 136),
    "floor": (196, 194, 188), "tactile": (150, 150, 146), "safety": (255, 214, 10),
    "coping": (214, 210, 200), "edge": (128, 128, 124), "ballast": (92, 86, 80),
    "sleeper": (96, 72, 52), "rail": (160, 164, 170), "power": (120, 108, 76),
    "ceiling": (66, 70, 78), "hoarding": (44, 48, 58), "hazard": (255, 214, 10),
    "ink": (24, 24, 28), "kiosk": (238, 130, 40), "staff": (70, 112, 160),
    "shutter": (150, 156, 164), "bench": (176, 122, 72), "steel": (110, 116, 126),
    "tunnel": (58, 60, 66), "abyss": (14, 14, 18), "lamp": (255, 244, 220),
    "warn": (255, 160, 30), "board": (20, 22, 28), "board_text": (255, 170, 40),
    "body": (188, 194, 202), "stripe": (255, 46, 136), "door": (255, 214, 10),
    "cab": (255, 214, 10), "roof": (122, 126, 134), "under": (52, 54, 60),
    "seat": (25, 180, 210), "pole": (255, 214, 10), "car_floor": (70, 76, 92),
    "glass": (150, 190, 215), "headlight": (255, 250, 232), "taillight": (255, 40, 40),
    "dest": (255, 138, 31), "push": (255, 46, 136), "board_go": (124, 255, 79),
    "old_tile": (196, 186, 150), "old_band": (120, 60, 50), "poster": (60, 150, 255),
}
MATERIALS = {
    "tile": "CeramicTiles", "band_a": "CeramicTiles", "band_b": "CeramicTiles",
    "floor": "Concrete", "tactile": "Pebble", "coping": "Concrete", "edge": "Concrete",
    "ballast": "Pebble", "sleeper": "WoodPlanks", "rail": "Metal", "power": "Metal",
    "ceiling": "Concrete", "hoarding": "WoodPlanks", "kiosk": "Metal", "staff": "Metal",
    "shutter": "DiamondPlate", "bench": "WoodPlanks", "steel": "Metal", "tunnel": "Concrete",
    "body": "Metal", "roof": "Metal", "under": "Metal", "seat": "Fabric", "pole": "Metal",
    "car_floor": "Rubber", "old_tile": "CeramicTiles", "old_band": "CeramicTiles",
}
DETAIL = dict(NO_HIT, CastShadow=False)


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


# ---- the track: straights and arcs, measured along their length --------------------------------

class Track:
    """A path in the XZ plane, from straights and arcs, measured by distance s along it.
    Headings are degrees: 0 = +X (east), 90 = +Z (south)."""

    def __init__(self, x, z, heading):
        self.x, self.z, self.h = x, z, heading
        self.segs = []
        self.length = 0.0

    def straight(self, d):
        self.segs.append(("L", self.length, d, self.x, self.z, self.h))
        a = math.radians(self.h)
        self.x += d * math.cos(a)
        self.z += d * math.sin(a)
        self.length += d

    def arc(self, radius, turn):
        """Turn by `turn` degrees (positive: the heading angle grows) on a circle."""
        a = math.radians(self.h)
        side = 1 if turn > 0 else -1
        cx = self.x - side * radius * math.sin(a)
        cz = self.z + side * radius * math.cos(a)
        d = radius * math.radians(abs(turn))
        self.segs.append(("A", self.length, d, cx, cz, self.h, radius, side))
        self.h += turn
        b = math.radians(self.h)
        self.x = cx + side * radius * math.sin(b)
        self.z = cz - side * radius * math.cos(b)
        self.length += d

    def at(self, s):
        """(x, z, heading) at distance s."""
        s %= self.length
        seg = self.segs[-1]
        for candidate in self.segs:
            if s <= candidate[1] + candidate[2] + 1e-9:
                seg = candidate
                break
        t = s - seg[1]
        if seg[0] == "L":
            _, _, _, x, z, h = seg
            a = math.radians(h)
            return x + t * math.cos(a), z + t * math.sin(a), h
        _, _, _, cx, cz, h0, radius, side = seg
        h = h0 + side * math.degrees(t / radius)
        b = math.radians(h)
        return cx + side * radius * math.sin(b), cz - side * radius * math.cos(b), h

    def export(self):
        return [[seg[0]] + [round(v, 4) for v in seg[1:]] for seg in self.segs]


def build_track():
    """The dogbone: A (west through the station), the west loop, B (east through the
    station), the east loop, back to A. s = 0 is the east portal on track A."""
    c, r = TRACK_Z, LOOP_R
    theta = math.degrees(math.acos((c + r) / (2 * r)))
    t = Track(PX, -c, 180)
    loop = {}
    t.straight(2 * PX)
    for name in ("west", "east"):
        start = t.length
        t.straight(LOOP_STRAIGHT)
        t.arc(r, theta)
        t.arc(r, -(180 + 2 * theta))
        t.arc(r, theta)
        t.straight(LOOP_STRAIGHT)
        loop[name] = (start, t.length)
        if name == "west":
            t.straight(2 * PX)
    return t, loop


TRACK, LOOPS = build_track()
STOP_A = PX - (-TRAIN_LEN / 2)  # the nose's distance along the track when stopped at A (130)
STOP_B = LOOPS["west"][1] + PX + TRAIN_LEN / 2  # stopped at B, nose at x = +50
# The train waits (out of sight) at the start of the east loop's last turn.
WAIT = LOOPS["east"][1] - LOOP_STRAIGHT - LOOP_R * math.radians(
    math.degrees(math.acos((TRACK_Z + LOOP_R) / (2 * LOOP_R))))
PORTAL_A = 0.0  # where the nose enters the station on A (the east portal)
PORTAL_B = LOOPS["west"][1]  # ... and on B (the west portal)


def car_middle(nose, car):
    """Distance along the track of a car's middle when the nose is at `nose`."""
    return nose - CAR_LEN / 2 - car * (CAR_LEN + GAP)


def car_frame(nose, car):
    """(x, z, heading) of a car: the middle of its two bogies, facing from the rear one to the
    front one."""
    s = car_middle(nose, car)
    fx, fz, _ = TRACK.at(s + BOGIE)
    rx, rz, _ = TRACK.at(s - BOGIE)
    return (fx + rx) / 2, (fz + rz) / 2, math.degrees(math.atan2(fz - rz, fx - rx))


# ---- runs and the schedule ----------------------------------------------------------------------

def run_time(distance, accel, top, brake):
    """Seconds to cover `distance` from a stop to a stop."""
    up, down = top * top / (2 * accel), top * top / (2 * brake)
    if up + down <= distance:
        return top / accel + (distance - up - down) / top + top / brake
    peak = math.sqrt(distance / (1 / (2 * accel) + 1 / (2 * brake)))
    return peak / accel + peak / brake


def run_until(distance, accel, top, brake, covered):
    """Seconds from the start of a run until `covered` studs are behind it."""
    up, down = top * top / (2 * accel), top * top / (2 * brake)
    if up + down > distance:
        peak = math.sqrt(distance / (1 / (2 * accel) + 1 / (2 * brake)))
        up, down, top = peak * peak / (2 * accel), peak * peak / (2 * brake), peak
    if covered <= up:
        return math.sqrt(2 * covered / accel)
    if covered <= distance - down:
        return top / accel + (covered - up) / top
    left = distance - covered
    return run_time(distance, accel, top, brake) - math.sqrt(2 * left / brake)


def ride_numbers():
    """The ride: doors closed -> stopped on the exit side, and the speeds coming in."""
    ride = STOP_B - STOP_A
    approach = (STOP_A + TRACK.length - WAIT) % TRACK.length
    leave = (WAIT - STOP_B) % TRACK.length
    return {
        "ride": ride, "rideTime": run_time(ride, *SCHEDULE["ride"]) + SCHEDULE["departDelay"],
        "loopTime": run_until(ride, *SCHEDULE["ride"], PORTAL_B - STOP_A)
        - run_until(ride, *SCHEDULE["ride"], 2 * PX - STOP_A),
        "approach": approach, "approachTime": run_time(approach, *SCHEDULE["approach"]),
        "leave": leave, "leaveTime": run_time(leave, *SCHEDULE["leave"]),
    }


# ---- building helpers ----------------------------------------------------------------------------

def car_x(car):
    """x of a car's middle where the train rests (stopped on A, heading west)."""
    return -TRAIN_LEN / 2 + CAR_LEN / 2 + car * (CAR_LEN + GAP)


class Car:
    """Builds one car where the train rests. Car-local u runs forward (west, -X), w to the
    left (south, +Z: the side that faces the platform at both stops), v up."""

    def __init__(self, m, index):
        self.m, self.index = m, index
        self.cx = car_x(index)
        self.cz = -TRACK_Z

    def box(self, name, u0, u1, v0, v1, w0, w1, color, attrs=None, **props):
        attributes = {"TrainCar": self.index + 1}
        attributes.update(attrs or {})
        return self.m.block("Train", name, self.cx - u1, self.cx - u0, v0, v1, self.cz + w0,
                            self.cz + w1, color, attributes=attributes, **props)

    def turned(self, name, u, v, w, size, yaw, color, attrs=None, **props):
        """A part turned `yaw` degrees about the vertical (in the car's frame)."""
        attributes = {"TrainCar": self.index + 1}
        attributes.update(attrs or {})
        # Car frame -> world: u is -X, w is +Z, so a turn in the car is the same turn in the world.
        return self.m.part("Train", name, size, (self.cx - u, v, self.cz + w), color,
                           rot_y(yaw), attributes=attributes, **props)


def side_wall(car, side, doors_open):
    """One side of a car (side +1: the left, platform side): wall pieces round the door
    openings and windows, glass, sills, the livery stripe, and the doors."""
    w0, w1 = (CAR_W / 2 - WALL_T, CAR_W / 2) if side > 0 else (-CAR_W / 2, -CAR_W / 2 + WALL_T)
    face = w1 if side > 0 else w0  # the outer face
    out = 1 if side > 0 else -1
    half = CAR_LEN / 2
    doors = [(d - LEAF, d + LEAF) for d in DOORS] if side > 0 else []
    openings = sorted([(a, b, "door") for a, b in doors] + [(a, b, "window") for a, b in WINDOWS])
    pos = -half
    stripe_spans = []
    for a, b, kind in openings:
        if a > pos:
            car.box("CarWall", pos, a, 0, ROOF, w0, w1, "body")
            stripe_spans.append((pos, a))
        if kind == "door":
            car.box("CarWall", a, b, DOOR_TOP, ROOF, w0, w1, "body")
        else:
            car.box("CarWall", a, b, 0, 3.2, w0, w1, "body")
            car.box("CarWall", a, b, 7.2, ROOF, w0, w1, "body")
            car.box("Window", a, b, 3.2, 7.2, w0, w1, "glass", Material="Glass", Transparency=0.55,
                    CastShadow=False)
            stripe_spans.append((a, b))
            for f0, f1 in ((w0 - 0.2, w0), (w1, w1 + 0.2)):
                car.box("WindowFrame", a, b, 2.9, 3.3, f0, f1, "ink", Material="Metal", **DETAIL)
        pos = b
    if pos < half:
        car.box("CarWall", pos, half, 0, ROOF, w0, w1, "body")
        stripe_spans.append((pos, half))
    if side < 0:  # the painted-on doors carry their own stripe
        for d in DOORS:
            stripe_spans = [piece for a, b in stripe_spans
                            for piece in ((a, min(b, d - LEAF)), (max(a, d + LEAF), b))
                            if piece[1] - piece[0] > 1e-6]
    for a, b in stripe_spans:  # the livery stripe, on the wall's outer face below the windows
        lo, hi = (face + 0.05, face + 0.09) if out > 0 else (face - 0.09, face - 0.05)
        car.box("Stripe", a, b, 2.0, 2.8, lo, hi, "stripe", Material="SmoothPlastic", **DETAIL)
    if side > 0:
        for d in DOORS:
            door_leaves(car, d, doors_open)
    else:
        for d in DOORS:  # the right side never opens: closed doors painted on
            car.box("DoorPanel", d - LEAF, d + LEAF, 0.1, DOOR_TOP, face - 0.12, face - 0.05,
                    "door", **DETAIL)
            car.box("DoorPanelGlass", d - LEAF + 0.4, d + LEAF - 0.4, 3.4, 6.8, face - 0.17,
                    face - 0.13, "ink", **DETAIL)
            car.box("DoorPanelStripe", d - LEAF, d + LEAF, 2.0, 2.8, face - 0.17, face - 0.13,
                    "stripe", **DETAIL)


def door_leaves(car, d, open_):
    """The two leaves of a left-side door, outside the wall. Built open (slid apart along the
    car into the solid pockets beside the doorway); DoorSlide says how far they moved."""
    lo, hi = CAR_W / 2 + 0.1, CAR_W / 2 + 0.3
    for direction in (1, -1):
        closed0 = d if direction > 0 else d - LEAF
        shift = LEAF * direction if open_ else 0.0
        a, b = closed0 + shift, closed0 + LEAF + shift
        attrs = {"DoorSlide": round(LEAF * direction, 3)}
        car.box("DoorLeaf", a, b, 0, DOOR_TOP + 0.1, lo, hi, "door", attrs)
        car.box("DoorGlass", a + 0.35, b - 0.35, 3.4, 6.8, hi + 0.05, hi + 0.09, "ink", attrs,
                **DETAIL)
        car.box("DoorStripe", a, b, 2.0, 2.8, hi + 0.05, hi + 0.09, "stripe", attrs, **DETAIL)


def end_wall(car, end, kind):
    """A car end (end +1: the front). kind: "gangway" (an opening to the next car), "cab" (the
    driver's end of the train)."""
    half = CAR_LEN / 2
    u0, u1 = (half - WALL_T, half) if end > 0 else (-half, -half + WALL_T)
    inner = CAR_W / 2 - WALL_T
    if kind == "gangway":
        car.box("CarEnd", u0, u1, 0, ROOF, -inner, -GANG_W / 2, "body")
        car.box("CarEnd", u0, u1, 0, ROOF, GANG_W / 2, inner, "body")
        car.box("CarEnd", u0, u1, DOOR_TOP, ROOF, -GANG_W / 2, GANG_W / 2, "body")
        return
    # The cab: a yellow nose with a big windscreen, lights and the destination sign, and a
    # bulkhead between it and the passengers.
    car.box("CabFront", u0, u1, 0, 4.2, -inner, inner, "cab")
    car.box("CabFront", u0, u1, 7.6, ROOF, -inner, inner, "cab")
    car.box("CabFront", u0, u1, 4.2, 7.6, -inner, -4.6, "cab")
    car.box("CabFront", u0, u1, 4.2, 7.6, 4.6, inner, "cab")
    car.box("Window", u0, u1, 4.2, 7.6, -4.6, 4.6, "glass", Material="Glass", Transparency=0.45,
            CastShadow=False)
    face = u1 if end > 0 else u0
    lo, hi = (face + 0.05, face + 0.12) if end > 0 else (face - 0.12, face - 0.05)
    car.box("WindowFrame", lo, hi, 3.9, 4.2, -4.8, 4.8, "ink", **DETAIL)
    car.box("WindowFrame", lo, hi, 7.6, 7.85, -4.8, 4.8, "ink", **DETAIL)
    lamp = "headlight" if end > 0 else "taillight"
    for w in (-3.8, 3.8):
        car.box("Headlight" if end > 0 else "Taillight", lo, hi, 1.6, 2.5, w - 0.8, w + 0.8, lamp,
                Material="Neon", **DETAIL)
    car.box("DestinationSign", lo, hi, 7.95, 8.45, -2.6, 2.6, "dest", Material="Neon", **DETAIL)
    b0, b1 = (u1, u1 + 0.6) if end > 0 else (u0 - 0.6, u0)
    car.box("Bumper", b0, b1, -0.6, 0.6, -5, 5, "ink", **DETAIL)
    k0, k1 = (CAB - WALL_T, CAB) if end > 0 else (-CAB, -CAB + WALL_T)
    car.box("Bulkhead", k0, k1, 0, ROOF, -inner, inner, "body")
    p = k0 - 0.12 if end > 0 else k1 + 0.05
    car.box("CabDoor", p, p + 0.07, 0.1, 7.2, -1.4, 1.4, "door", **DETAIL)
    c0, c1 = (13.4, 14.8) if end > 0 else (-14.8, -13.4)
    car.box("CabConsole", c0, c1, 0, 3.2, -4.2, 4.2, "ink", **DETAIL)
    if end > 0:  # the kill box in front of the train
        car.box("TrainNose", u1, u1 + 3, PIT, 10, -CAR_W / 2 - 0.4, CAR_W / 2 + 0.4, "push",
                {"TrainNose": True}, Transparency=1, CanCollide=False, CanQuery=False,
                CanTouch=True, CastShadow=False)


def car_inside(car, cab_front, cab_rear):
    """Seats, poles, grab rails, lights, adverts, and the exit arrows and doorway volumes."""
    half = CAR_LEN / 2
    inner = CAR_W / 2 - WALL_T
    lo = -CAB if cab_rear else -half + WALL_T
    hi = CAB if cab_front else half - WALL_T
    middle_car = car.index == 1
    # Longitudinal seats along both walls between the doors (the middle car has its island
    # there instead) and at the gangway ends.
    spans = [] if middle_car else [(-5.2, 5.2)]
    if not cab_front:
        spans.append((10.8, hi - 0.2))
    if not cab_rear:
        spans.append((lo + 0.2, -10.8))
    for a, b in spans:
        for side in (1, -1):
            w0, w1 = (inner - 2.0, inner) if side > 0 else (-inner, -inner + 2.0)
            car.box("Seat", a, b, 0, 1.6, w0, w1, "seat")
            b0, b1 = (inner - 0.4, inner) if side > 0 else (-inner, -inner + 0.4)
            car.box("SeatBack", a, b, 1.6, 2.8, b0, b1, "seat")
    if middle_car:  # the island: seats facing out either side of a glass screen
        u0, u1, w0, w1 = ISLAND
        car.box("Seat", u0, u1, 0, 1.6, w0, -0.3, "seat")
        car.box("Seat", u0, u1, 0, 1.6, 0.3, w1, "seat")
        car.box("Screen", u0, u1, 0, 6.5, -0.3, 0.3, "glass", Material="Glass", Transparency=0.35,
                CastShadow=False)
        for u in (u0 - 0.3, u1 + 0.3):
            car.m.cylinder("Train", "Pole", ROOF, 0.35, (car.cx - u, ROOF / 2, car.cz), "pole",
                           attributes={"TrainCar": car.index + 1})
    for d in DOORS:  # a pole in the middle of each door area
        car.m.cylinder("Train", "Pole", ROOF, 0.35, (car.cx - d, ROOF / 2, car.cz), "pole",
                       attributes={"TrainCar": car.index + 1})
    for w in (-3.0, 3.0):  # grab rails and ceiling lights
        car.box("GrabRail", lo + 0.5, hi - 0.5, 7.4, 7.55, w - 0.08, w + 0.08, "pole", **DETAIL)
        car.box("CarLight", lo + 0.6, hi - 0.6, 8.45, 8.55, w - 0.35, w + 0.35, "lamp",
                Material="Neon", **DETAIL)
    for a, b in WINDOWS:  # adverts above the windows inside
        a, b = max(a, lo + 0.2), min(b, hi - 0.2)
        if b - a < 1:
            continue
        for side in (1, -1):
            w0, w1 = (inner - 0.1, inner - 0.05) if side > 0 else (-inner + 0.05, -inner + 0.1)
            car.box("Advert", a, b, 7.5, 8.35, w0, w1, "poster", **DETAIL)
    # Exit arrows: chevrons on the floor pointing to the nearest door, and out of it.
    for d in DOORS:
        for step, toward in ((3.5, -1), (6.5, -1), (-3.5, 1), (-6.5, 1)):
            u = d + step
            if not lo + 1 < u < hi - 1:
                continue
            chevron(car, u, 2.8, 90 if toward > 0 else -90)
        chevron(car, d, 4.6, 0)
        car.box("NoEntry", d - LEAF, d + LEAF, 0, DOOR_TOP, inner - 0.6, CAR_W / 2 + 1.2, "push",
                {"NoEntry": True}, Transparency=1, CanCollide=False, CanQuery=False, CanTouch=True,
                CastShadow=False)


def chevron(car, u, w, heading):
    """A floor arrow (two bars in a V) pointing `heading` degrees in the car's frame: 0 = out of
    the left side (+w), 90 = forward (+u), -90 = back."""
    a = math.radians(heading)
    tip_u, tip_w = math.sin(a) * 0.5, math.cos(a) * 0.5
    for arm in (-1, 1):
        yaw = heading + arm * 135  # each bar runs back from the tip at 45 degrees
        b = math.radians(yaw)
        mu, mw = u + tip_u + math.sin(b) * 0.55, w + tip_w + math.cos(b) * 0.55
        # Part X runs along the bar; turning the part by `yaw` points it that way (u is -X).
        car.turned("ExitArrow", mu, 0.08 + 0.06 * (arm > 0), mw, (1.3, 0.06, 0.32), 90 - yaw,
                   "push", {"ExitPush": True}, Material="Neon", **DETAIL)


def build_car(m, index):
    car = Car(m, index)
    half = CAR_LEN / 2
    cab_front, cab_rear = index == 0, index == CARS - 1
    f0 = -CAB if cab_rear else -half
    f1 = CAB if cab_front else half
    car.box("CarFloor", f0, f1, -0.5, 0, -CAR_W / 2, CAR_W / 2, "car_floor")
    if cab_front:
        car.box("CabFloor", CAB, half, -0.5, 0, -CAR_W / 2, CAR_W / 2, "car_floor")
    if cab_rear:
        car.box("CabFloor", -half, -CAB, -0.5, 0, -CAR_W / 2, CAR_W / 2, "car_floor")
    car.box("Underframe", -14, 14, -2.0, -0.5, -5.2, 5.2, "under")
    for u in (-BOGIE, BOGIE):
        car.box("Bogie", u - 2.6, u + 2.6, -3.2, -2.0, -4.4, 4.4, "under")
        for du in (-1.6, 1.6):
            for w in (-3.6, 3.6):
                car.m.cylinder("Train", "Wheel", 0.4, 1.6, (car.cx - u - du, -2.5, car.cz + w),
                               "steel", [[0, 1, 0], [0, 0, 1], [1, 0, 0]],
                               attributes={"TrainCar": index + 1}, **DETAIL)
    side_wall(car, 1, True)
    side_wall(car, -1, False)
    end_wall(car, 1, "cab" if cab_front else "gangway")
    end_wall(car, -1, "cab" if cab_rear else "gangway")
    car.box("RoofCar", -half, half, ROOF, ROOF + 0.8, -CAR_W / 2, CAR_W / 2, "roof")
    car.box("RoofCrown", -half + 1, half - 1, ROOF + 0.8, ROOF + 1.2, -4.5, 4.5, "roof")
    for u in (-8, 8):
        car.box("RoofUnit", u - 3, u + 3, ROOF + 1.25, ROOF + 2.0, -3, 3, "under", **DETAIL)
    car_inside(car, cab_front, cab_rear)


def build_gangway(m, index):
    """The flexible passage between car `index` and the next: bellows in slices across the gap
    (floor plate, two side walls, roof each), so on a curve it bends smoothly from one car end to
    the other. GangwaySlice says where a slice sits: 0 at the front car's end, 1 at the next's.
    Every other slice stands a little proud, like the folds of real bellows."""
    x0 = car_x(index) + CAR_LEN / 2  # the front car's back end (the train rests heading west)
    cz = -TRACK_Z
    step = GAP / GANG_SLICES
    for k in range(GANG_SLICES):
        a, b = x0 + k * step, x0 + (k + 1) * step
        attrs = {"TrainGangway": index + 1, "GangwaySlice": round((k + 0.5) / GANG_SLICES, 4)}
        fold = 0.12 * (k % 2)
        color = "ink" if k % 2 else "under"
        m.block("Train", "GangwayFloor", a, b, -0.5, 0, cz - GANG_W / 2, cz + GANG_W / 2,
                "car_floor", attributes=attrs)
        for w0, w1 in ((-GANG_W / 2 - 0.4 - fold, -GANG_W / 2),
                       (GANG_W / 2, GANG_W / 2 + 0.4 + fold)):
            m.block("Train", "Bellows", a, b, 0, DOOR_TOP + 0.4 + fold, cz + w0, cz + w1, color,
                    attributes=attrs)
        m.block("Train", "Bellows", a, b, DOOR_TOP, DOOR_TOP + 0.4 + fold, cz - GANG_W / 2,
                cz + GANG_W / 2, color, attributes=attrs)


# ---- the station ---------------------------------------------------------------------------------

def notch_holes():
    """The two works gaps: (x0, x1, z0, z1). West in the boarding lane, east in the exit lane."""
    return [(-NOTCH[1], -NOTCH[0], -PZ, -SPINE), (NOTCH[0], NOTCH[1], SPINE, PZ)]


def platform(m):
    g = "Platform"
    m.block(g, "TrackBed", -PX, PX, PIT - 2, PIT, -OUTER, OUTER, "ballast")
    holes = notch_holes()
    core = [(x0, x1, max(z0, -RECESS), min(z1, RECESS)) for x0, x1, z0, z1 in holes]
    m.slab(g, "PlatformBody", (-PX, PX, -RECESS, RECESS), PIT, -1, core, "edge")
    for a, b, color in BANDS:
        for sign in (-1, 1):
            z0, z1 = (a, b) if sign > 0 else (-b, -a)
            if a == 0:
                z0, z1 = (0, b) if sign > 0 else (-b, 0)
            band_holes = [(x0, x1, max(z0, hz0), min(z1, hz1)) for x0, x1, hz0, hz1 in holes
                          if hz0 < z1 and hz1 > z0]
            m.slab(g, "PlatformTop" if color == "floor" else color.capitalize(),
                   (-PX, PX, z0, z1), -1, 0, band_holes, color)
    # Hazard stripes round the works gaps (on the floor, 0.06 high).
    for x0, x1, z0, z1 in holes:
        for x in (x0, x1):
            a, b = (x - 0.8, x) if x == x0 else (x, x + 0.8)
            m.block("Details", "HazardEdge", a, b, 0, 0.06, z0, z1, "hazard", **DETAIL)
    # Door zones painted on the platform: green "board here" on A, pink "exit only" on B.
    for x in door_xs():
        m.block("Details", "BoardHere", x - LEAF, x + LEAF, 0, 0.06, -9.2, -7.4, "band_a", **DETAIL)
        m.block("Details", "ExitOnly", x - LEAF, x + LEAF, 0, 0.06, 7.4, 9.2, "band_b", **DETAIL)
    # Warning lights along both edges (on the coping), flashing before a train comes in.
    for sign, track in ((-1, "A"), (1, "B")):
        x = -PX + 3
        while x < PX - 2:
            gap = any(h[0] - 1 <= x <= h[1] + 1 and (h[2] < 0) == (sign < 0) for h in holes)
            if not gap:
                m.block("Details", "EdgeLight", x - 0.6, x + 0.6, 0, 0.06, sign * 11.0 - 0.3,
                        sign * 11.0 + 0.3, "warn", Material="Neon",
                        attributes={"TrackWarning": track}, **DETAIL)
            x += 5


def door_xs():
    return sorted(car_x(c) - d for c in range(CARS) for d in DOORS)


def track_bed(m, x0, x1, cz):
    """Sleepers, running rails and the power rail along the straight track through the station
    and the tunnel mouths (sleepers only where there's a floor under them)."""
    g = "Track"
    x = -MOUTH_FLOOR + 1.2
    while x < MOUTH_FLOOR - 0.4:
        m.block(g, "Sleeper", x - 0.4, x + 0.4, PIT, PIT + 0.3, cz - 4.5, cz + 4.5, "sleeper",
                **DETAIL)
        x += 2.5
    for w in (-3.6, 3.6):
        m.block(g, "Rail", x0, x1, PIT + 0.3, PIT + 0.7, cz + w - 0.2, cz + w + 0.2, "rail",
                **DETAIL)
    side = -1 if cz < 0 else 1  # the power rail on the outer side
    m.block(g, "PowerRail", -MOUTH_FLOOR, MOUTH_FLOOR, PIT, PIT + 0.5, cz + side * 5.6 - 0.25,
            cz + side * 5.6 + 0.25, "power", **DETAIL)


def walls(m):
    g = "Walls"
    for sign in (-1, 1):
        z0, z1 = (OUTER, OUTER + 1) if sign > 0 else (-OUTER - 1, -OUTER)
        m.block(g, "TrackWall", -PX - 1, PX + 1, PIT - 2, CUT, z0, z1, "tile")
        m.block(g, "TrackWallUpper", -PX - 1, PX + 1, CUT, CEIL + 1, z0, z1, "tile")
        # End walls, with the tunnel portals over the pits.
        x0, x1 = (PX, PX + 1) if sign > 0 else (-PX - 1, -PX)
        m.block(g, "EndWall", x0, x1, PIT - 2, CUT, -PZ, PZ, "tile")
        m.block(g, "EndWallUpper", x0, x1, CUT, CEIL, -PZ, PZ, "tile")
        for zs in (1, -1):
            a, b = (PZ, OUTER) if zs > 0 else (-OUTER, -PZ)
            m.block(g, "EndWallUpper", x0, x1, TUNNEL_TOP, CEIL, a, b, "tile")
    m.block(g, "Ceiling", -PX - 1, PX + 1, CEIL, CEIL + 1, -OUTER, OUTER, "ceiling")
    d = "Details"
    for sign, band, label in ((-1, "band_a", "A"), (1, "band_b", "B")):
        face = sign * OUTER
        off = (face - 0.1, face - 0.05) if sign > 0 else (face + 0.05, face + 0.1)
        # The coloured band: lime on the boarding side, pink on the exit side.
        m.block(d, "TileBand", -PX, PX, 8.5, 10, off[0], off[1], band, **DETAIL)
        # Name plates over the band and adverts below it.
        for x in (-60, -20, 20, 60):
            m.block(d, "NamePlate", x - 9, x + 9, 10.4, 12.6, off[0] - 0.04 * sign, off[1] - 0.04
                    * sign, "ink", **DETAIL,
                    children=[m.surface_text("Front" if sign > 0 else "Back", "TAG STREET",
                                             (255, 255, 255), pps=10)])
        for i, x in enumerate((-70, -40, 0, 40, 70)):
            color = ((60, 150, 255), (255, 138, 31), (124, 255, 79), (25, 227, 255),
                     (255, 46, 136))[(i + (sign > 0)) % 5]
            m.block(d, "Poster", x - 6, x + 6, 1.5, 7, off[0] - 0.04 * sign, off[1] - 0.04 * sign,
                    color, **DETAIL)
        # Cable trays near the top.
        m.block(d, "CableTray", -PX, PX, 15.5, 16, *sorted((face - 0.09 * sign, face - 0.6 * sign)),
                "steel", **DETAIL)
    # End walls: the closed way out on each, a station map.
    for sign in (-1, 1):
        face = sign * PX
        off = (face - 0.1, face - 0.05) if sign > 0 else (face + 0.05, face + 0.1)
        m.block(d, "ClosedGate", off[0], off[1], 0, 8, -5, 5, "shutter", **DETAIL)
        m.block(d, "WayOutSign", off[0] - 0.04 * sign, off[1] - 0.04 * sign, 9.6, 11.4, -5, 5,
                "ink", **DETAIL, children=[m.surface_text("Right" if sign < 0 else "Left",
                                                         "NO EXIT", (255, 214, 10), pps=10)])
        m.block(d, "StationMap", off[0], off[1], 3, 8, 7, 11, (240, 240, 236), **DETAIL)
    # Lights: strips under the ceiling over both lanes and both tracks.
    for z in (-8, 8, -TRACK_Z, TRACK_Z):
        for x in range(-72, 73, 16):
            m.light("Lights", (x, CEIL - 0.3, z), size=(10, 0.4, 0.8), color=COLORS["lamp"],
                    brightness=0.6, reach=22)


def tunnel_mouths(m):
    """Past each end wall: 6 studs of pit floor, then the tunnel drops away (falling kills).
    The mouths are wider than the pits on the inside (the train swings in as it turns into the
    loop)."""
    g = "Tunnels"
    inner = TRACK_Z - TUNNEL_HALF
    for sx in (-1, 1):
        x0, x1 = (PX + 1, MOUTH) if sx > 0 else (-MOUTH, -PX - 1)
        f0, f1 = (PX, MOUTH_FLOOR) if sx > 0 else (-MOUTH_FLOOR, -PX)
        m.block(g, "TunnelDivider", x0, x1, TUNNEL_BOTTOM, TUNNEL_TOP + 1, -inner, inner, "tunnel")
        for sz in (-1, 1):
            a, b = (PZ, OUTER) if sz > 0 else (-OUTER, -PZ)
            ia, ib = (inner, PZ) if sz > 0 else (-PZ, -inner)
            m.block(g, "MouthFloor", f0, f1, PIT - 2, PIT, a, b, "ballast")
            m.block(g, "MouthFloor", x0 if sx > 0 else f0, f1 if sx > 0 else x1, PIT - 2, PIT, ia,
                    ib, "ballast")
            m.block(g, "CeilingTunnel", x0, x1, TUNNEL_TOP, TUNNEL_TOP + 1, min(a, ia),
                    max(b, ib), "tunnel")
            w0, w1 = (OUTER, OUTER + 1) if sz > 0 else (-OUTER - 1, -OUTER)
            m.block(g, "TunnelWall", x0, x1, TUNNEL_BOTTOM, TUNNEL_TOP + 1, w0, w1, "tunnel")
            edge = f1 if sx > 0 else f0
            e0, e1 = (edge + 0.05, edge + 0.1) if sx > 0 else (edge - 0.1, edge - 0.05)
            m.block("Details", "DropEdge", e0, e1, PIT - 2, PIT, min(a, ia), max(b, ib), "hazard",
                    **DETAIL)
            # Signal by the portal.
            sz_side = OUTER - 0.6 if sz > 0 else -OUTER + 0.6
            m.block("Details", "Signal", x0 + 1 if sx > 0 else x1 - 1.6,
                    x0 + 1.6 if sx > 0 else x1 - 1, 4, 6.4, sz_side - 0.3, sz_side + 0.3, "ink",
                    **DETAIL)


def track_offset(s, off):
    """The point `off` studs to the right of the track at distance s."""
    x, z, h = TRACK.at(s)
    a = math.radians(h)
    return x - math.sin(a) * off, z + math.cos(a) * off


def chord(s0, s1, off=0.0):
    """A straight piece following the track from s0 to s1, `off` to its right: (middle x, z,
    length, yaw); pieces along one offset meet end to end."""
    ax, az = track_offset(s0, off)
    bx, bz = track_offset(s1, off)
    return (ax + bx) / 2, (az + bz) / 2, math.hypot(bx - ax, bz - az), \
        math.degrees(math.atan2(bz - az, bx - ax))


def loop_tunnels(m):
    """The loops: walls and roof along the track (decoration: only the riders, shut in the
    train, ever see them), lamps, the old closed station on the west loop, and a dark floor far
    below so nothing shows the sky."""
    g = "Tunnels"
    ghost = ghost_span()
    for name, (start, end) in LOOPS.items():
        s = start + LOOP_STRAIGHT
        stop = end - LOOP_STRAIGHT
        count = max(1, round((stop - s) / 10))
        step = (stop - s) / count
        for i in range(count):
            a, b = s + i * step, s + (i + 1) * step
            for side in (-1, 1):
                if name == "west" and side == ghost["side"] and \
                        ghost["s0"] <= (a + b) / 2 <= ghost["s1"]:
                    continue  # the old station is here instead of the wall
                x, z, length, yaw = chord(a, b, side * (TUNNEL_HALF + 0.5))
                m.part(g, "TunnelWall", (length, TUNNEL_TOP - TUNNEL_BOTTOM, 1),
                       (x, (TUNNEL_TOP + TUNNEL_BOTTOM) / 2, z), "tunnel", rot_y(-yaw), **DETAIL)
                if i % 3 == 1:
                    x, z, _, yaw = chord(a, b, side * (TUNNEL_HALF - 0.11))
                    m.part(g, "TunnelLamp", (1.2, 0.5, 0.12), (x, 7, z), "lamp", rot_y(-yaw),
                           Material="Neon", **DETAIL)
            x, z, length, yaw = chord(a, b)
            # Neighbouring roof pieces overlap on the inside of the turn, so they alternate
            # heights (and both clear the mouths' roofs).
            lift = 0.06 * (1 + i % 2)
            m.part(g, "CeilingTunnel", (length + 1.6, 1, 2 * TUNNEL_HALF + 2),
                   (x, TUNNEL_TOP + 0.5 + lift, z), "tunnel", rot_y(-yaw), **DETAIL)
            for w in (-3.6, 3.6):  # rails (no sleepers: they'd only show from the train)
                x, z, length, yaw = chord(a, b, w)
                m.part(g, "Rail", (length, 0.4, 0.4), (x, PIT + 0.5, z), "rail", rot_y(-yaw),
                       **DETAIL)
    old_station(m, ghost)
    xs, zs = [], []
    k = 0.0
    while k < TRACK.length:
        x, z, _ = TRACK.at(k)
        xs.append(x)
        zs.append(z)
        k += 5
    pad = TUNNEL_HALF + 20
    m.block(g, "Abyss", min(xs) - pad, max(xs) + pad, -42, -40, min(zs) - pad, max(zs) + pad,
            "abyss", **DETAIL)


def ghost_span():
    """Where the old closed station sits: the outside of the west loop's far end."""
    start, _ = LOOPS["west"]
    theta = math.acos((TRACK_Z + LOOP_R) / (2 * LOOP_R))
    bulb0 = start + LOOP_STRAIGHT + LOOP_R * theta
    bulb_len = LOOP_R * (math.pi + 2 * theta)
    mid = bulb0 + bulb_len / 2
    return {"s0": mid - 16, "s1": mid + 16, "mid": mid, "side": 1}


def old_station(m, ghost):
    """A short lit platform on the outside of the west loop, closed for decades: riders flash
    past it. Decoration only."""
    g = "Tunnels"
    x, z, h = TRACK.at(ghost["mid"])
    a = math.radians(h)
    nx, nz = -math.sin(a), math.cos(a)  # to the train's right
    side = ghost["side"]
    tx, tz = math.cos(a), math.sin(a)
    rows = rot_y(-h)

    def at(along, out, y, size, color, name, **props):
        px = x + tx * along + nx * side * out
        pz = z + tz * along + nz * side * out
        return m.part(g, name, size, (px, y, pz), color, rows, **props)

    at(0, 10.6, -0.5, (34, 1, 5.2), "old_tile", "OldPlatform", **DETAIL)
    at(0, 13.7, 5.5, (34, 13, 1), "old_tile", "OldWall", **DETAIL)
    at(0, 13.1, 7.6, (34, 1.4, 0.1), "old_band", "OldBand", **DETAIL)
    at(0, 13.1, 10, (14, 1.8, 0.1), "ink", "OldNameplate", **DETAIL,
       children=[m.surface_text("Front", "OLD TAG STREET", (230, 220, 190), pps=10)])
    for along in (-11, 0, 11):
        at(along, 12.2, 0.6, (5, 1.2, 1.4), "bench", "OldBench", **DETAIL)
    for along in (-12, 4):
        lamp = at(along, 12.6, 11.4, (4, 0.4, 0.6), "lamp", "OldLamp", Material="Neon",
                  attributes={"Flicker": True}, **DETAIL)
        lamp["children"] = [{"name": "Glow", "className": "PointLight", "properties": {
            "Brightness": 0.5, "Range": 18, "Color": m.rgb("lamp"), "Shadows": False}}]


# ---- the middle row and the works ----------------------------------------------------------------

def spine(m):
    g = "Platform"
    d = "Details"
    # The works: hoarded blocks (wall-run along them over the gap), with the slide sheds.
    for sign in (-1, 1):
        x0, x1 = (WORKS[0], WORKS[1]) if sign > 0 else (-WORKS[1], -WORKS[0])
        m.block(g, "Works", x0, x1, 0, WORKS_TOP, -SPINE, SPINE, "hoarding")
        for zs in (-1, 1):
            face = zs * SPINE
            off = (face + 0.05, face + 0.1) if zs > 0 else (face - 0.1, face - 0.05)
            m.block(d, "HoardingStripe", x0, x1, 0.4, 1.2, off[0], off[1], "hazard", **DETAIL)
            m.block(d, "WorksSign", (x0 + x1) / 2 - 6, (x0 + x1) / 2 + 6, 6, 9, off[0], off[1],
                    "hazard", **DETAIL,
                    children=[m.surface_text("Back" if zs < 0 else "Front", "ENGINEERING WORKS",
                                             COLORS["ink"], pps=10)])
        for x in (x0 + 2, x1 - 2):  # scaffold poles poking out of the top, a crane arm
            m.block(d, "ScaffoldPole", x - 0.2, x + 0.2, WORKS_TOP, CEIL, -0.2, 0.2, "steel",
                    **DETAIL)
        m.block(d, "ScaffoldBar", x0 + 2, x1 - 2, 15, 15.3, -0.14, 0.14, "steel", **DETAIL)
        # The shed over the other lane: a slide gate 4.2 high, too tall to jump onto.
        s0, s1 = (SHED[0], SHED[1]) if sign > 0 else (-SHED[1], -SHED[0])
        z0, z1 = (-PZ, -SPINE) if sign > 0 else (SPINE, PZ)
        m.block(g, "Shed", s0, s1, CROUCH_ROOM, SHED_TOP, z0, z1, "hoarding")
        m.block(g, "StandBlocker", s0, s1, 0, CROUCH_ROOM, z0, z1, (255, 255, 255),
                Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
        for x in (s0 + 0.5, s1 - 0.5):
            for z in (z0 + 0.5, z1 - 0.5):
                m.block(g, "ShedPost", x - 0.3, x + 0.3, 0, CROUCH_ROOM, z - 0.3, z + 0.3, "steel")
        for x, face in ((s0, -1), (s1, 1)):
            a, b = (x - 0.1, x - 0.05) if face < 0 else (x + 0.05, x + 0.1)
            m.block(d, "LowSign", a, b, CROUCH_ROOM + 0.2, CROUCH_ROOM + 1.4, z0 + 1, z1 - 1,
                    "hazard", **DETAIL)
        # Cones round the gap.
        n0, n1, nz0, nz1 = notch_holes()[0 if sign < 0 else 1]
        for x in (n0 - 1.6, n1 + 1.6):
            for z in ((nz0 + nz1) / 2 - 2.5, (nz0 + nz1) / 2 + 2.5):
                m.cylinder(d, "Cone", 1.6, 0.9, (x, 0.8, z), "kiosk", **DETAIL)

    # The kiosk: a juke block (coffee and papers), awnings both sides.
    x0, x1 = KIOSK
    m.block(g, "Kiosk", x0, x1, 0, 8, -SPINE, SPINE, "kiosk")
    for zs in (-1, 1):
        a, b = (SPINE, SPINE + 1.6) if zs > 0 else (-SPINE - 1.6, -SPINE)
        m.block(d, "Awning", x0 - 0.5, x1 + 0.5, 7.2, 7.5, a, b, "stripe", **DETAIL)
        face = zs * SPINE
        off = (face + 0.05, face + 0.1) if zs > 0 else (face - 0.1, face - 0.05)
        m.block(d, "Counter", x0 + 1, x1 - 1, 3.2, 3.5, off[0], off[1], "ink", **DETAIL)
    m.block(d, "KioskSign", x0 + 1, x1 - 1, 8.05, 9.6, -1, 1, "ink", **DETAIL,
            children=[m.surface_text(f, "COFFEE · NEWS", (255, 214, 10), pps=10)
                      for f in ("Front", "Back")])
    m.block(g, "VendingMachine", x0 - 1.5, x0, 0, 6.5, -1.6, 1.6, "stripe")
    m.block(g, "VendingMachine", x1, x1 + 1.5, 0, 6.5, -1.6, 1.6, (25, 160, 200))

    # The staff room: shutters half down on both long sides (slide through), lockers inside.
    x0, x1 = STAFF
    a, b = STAFF_DOOR
    for zs in (-1, 1):
        z0, z1 = (SPINE - WALL_T, SPINE) if zs > 0 else (-SPINE, -SPINE + WALL_T)
        m.block(g, "StaffWall", x0, a, 0, 8.4, z0, z1, "staff")
        m.block(g, "StaffWall", b, x1, 0, 8.4, z0, z1, "staff")
        m.block(g, "Shutter", a, b, CROUCH_ROOM, 8.4, z0, z1, "shutter")
        m.block(g, "StandBlocker", a, b, 0, CROUCH_ROOM, z0, z1, (255, 255, 255),
                Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
        face = z1 if zs > 0 else z0
        off = (face + 0.05, face + 0.1) if zs > 0 else (face - 0.1, face - 0.05)
        m.block(d, "StaffSign", a, b, 8.6, 9.8, off[0], off[1], "ink", **DETAIL,
                children=[m.surface_text("Back" if zs < 0 else "Front", "STAFF ONLY",
                                         (255, 255, 255), pps=10)])
    for x, xa, xb in ((x0, x0, x0 + WALL_T), (x1, x1 - WALL_T, x1)):
        m.block(g, "StaffWall", xa, xb, 0, 8.4, -SPINE + WALL_T, SPINE - WALL_T, "staff")
    m.block(g, "StaffRoof", x0, x1, 8.4, 9, -SPINE, SPINE, "staff")
    for xa, xb in ((x0 + WALL_T, x0 + WALL_T + 1), (x1 - WALL_T - 1, x1 - WALL_T)):
        m.block(g, "Locker", xa, xb, 0, 6, -2.4, 2.4, "steel")

    # Bench islands: two benches back to back (hurdle them, juke round them), a bin each end.
    for x0, x1 in BENCHES:
        m.block(g, "Bench", x0, x1, 0, 1.6, -1.6, -0.2, "bench")
        m.block(g, "Bench", x0, x1, 0, 1.6, 0.2, 1.6, "bench")
        m.block(g, "BenchBack", x0, x1, 0, 3.0, -0.2, 0.2, "steel")
        for x in (x0 - 1, x1 + 1):
            m.cylinder(g, "Bin", 2.6, 1.2, (x, 1.3, 0), "steel")

    # Columns down the middle (tiled), each with a coloured band.
    for x in COLUMNS:
        m.block(g, "Column", x - 0.8, x + 0.8, 0, CEIL, -0.8, 0.8, "tile")
        for (a, b), (c, e) in (((x - 0.85, x + 0.85), (-0.85, -0.8)), ((x - 0.85, x + 0.85),
                                                                       (0.8, 0.85))):
            m.block(d, "ColumnBand", a, b, 2.5, 3.5, c, e, "band_a" if c < 0 else "band_b",
                    **DETAIL)

    # Departure boards (the game shows the countdown) and lane signs, hanging.
    for x in BOARDS:
        m.block(d, "DepartureBoard", x - 0.3, x + 0.3, 10, 12, -6, 6, "board", **DETAIL,
                attributes={"DepartureBoard": True},
                children=[m.surface_text(f, "NEXT TRAIN", COLORS["board_text"], pps=10, glow=True)
                          for f in ("Right", "Left")])
        for z in (-5, 5):
            m.block(d, "Hanger", x - 0.1, x + 0.1, 12, CEIL, z - 0.1, z + 0.1, "steel", **DETAIL)
    for x in (-64, -32, 32, 64):
        for zs, color, text in ((-1, "band_a", "1  BOARDING"), (1, "band_b", "2  EXIT ONLY")):
            z = zs * 8
            m.block(d, "LaneSign", x - 0.2, x + 0.2, 12.2, 13.6, z - 3, z + 3, color, **DETAIL,
                    children=[m.surface_text(f, text, COLORS["ink"], pps=10)
                              for f in ("Right", "Left")])
            m.block(d, "Hanger", x - 0.08, x + 0.08, 13.6, CEIL, z - 0.08, z + 0.08, "steel",
                    **DETAIL)


SPAWNS = ((-77, -1), (77, 1), (-46, 8), (46, -8), (-23, -8), (23, 8), (-4, 7), (4, -7))


def build():
    m = Map(COLORS, MATERIALS)
    platform(m)
    walls(m)
    for cz in (-TRACK_Z, TRACK_Z):
        track_bed(m, -MOUTH, MOUTH, cz)
    tunnel_mouths(m)
    loop_tunnels(m)
    spine(m)
    for car in range(CARS):
        build_car(m, car)
    for gap in range(CARS - 1):
        build_gangway(m, gap)
    for x, z in SPAWNS:
        m.spawn(x, z)
    return m


# ---- the design canvas ---------------------------------------------------------------------------

def _label(text, x, y, z, kind="zone"):
    return {"t": text, "x": x, "y": y, "z": z, "f": 1, "k": kind}


def _marker(n, title, text, x, y, z):
    return {"n": n, "t": title, "d": text, "x": x, "y": y, "z": z, "f": 1}


def _canvas():
    numbers = ride_numbers()
    ghost = ghost_span()
    west_far = TRACK.at(ghost["mid"])
    gx, gz = track_offset(ghost["mid"], ghost["side"] * 11)  # the old platform
    east_mid = TRACK.at((LOOPS["east"][0] + LOOPS["east"][1]) / 2)
    return {
        "label": "Design v1",
        "labels": [
            _label("Platform", 0, 4, 0), _label("Track A · boarding", -62, 2, -TRACK_Z),
            _label("Track B · exit only", 62, 2, TRACK_Z),
            _label("West loop: the ride", west_far[0] + LOOP_R, 16, west_far[1]),
            _label("East loop", east_mid[0] - LOOP_R, 16, east_mid[1]),
            _label("Old Tag Street (closed)", gx, 15, gz, "feature"),
            _label("Kiosk", sum(KIOSK) / 2, 10.5, 0, "feature"),
            _label("Staff room", sum(STAFF) / 2, 11, 0, "feature"),
            _label("Works", -63, 14, 0, "feature"), _label("Works", 63, 14, 0, "feature"),
            _label("Benches", -13, 4.5, 0, "feature"), _label("Benches", 13, 4.5, 0, "feature"),
        ],
        "markers": [
            _marker(1, "Boarding side (track A)", "The train comes in from the east tunnel "
                    "heading west and stops along the green side with its doors open for 7 "
                    "seconds. Get on, or don't: the doors chime and close over 2 seconds, so you "
                    "can still squeeze through (or get shut out) at the last moment.", -8, 9, -14),
            _marker(2, "The ride", f"The west loop itself takes about "
                    f"{numbers['loopTime']:.0f} seconds (about {numbers['rideTime']:.0f} from the "
                    "doors closing to stopping on the exit side): a long, gentle loop under the "
                    "city, past the old closed station. Whoever got on is shut in together. If It "
                    "got on too, it's a chase through three cars; if not, it's a breather.",
                    west_far[0] + 40, 12, west_far[1]),
            _marker(3, "Exit side (track B)", "The same train comes back on the other side of the "
                    "platform heading east. The doors open and everyone inside is pushed to the "
                    "nearest door and out onto the platform (the pink arrows). Nobody can get on "
                    "here.", 8, 9, 14),
            _marker(4, "Track pits", "4 deep: drop in to cut along the platform and jump back out "
                    "anywhere. But if the train comes in while you're down there, or you're in "
                    "front of it, you're dead. The edge lights flash 4 seconds before, and the "
                    "boards count down.", 66, -1, -TRACK_Z),
            _marker(5, "Under the edge", "A crawl space runs under each platform edge, 3 high. "
                    "Crouch or slide into it and the train misses you.", -66, -2, 11),
            _marker(6, "West works gap", "An 18-stud gap in the green lane: too far to jump at a "
                    "sprint. Wall-run along the hoarding or slide-jump it. Miss, and you're in the "
                    "pit.", -63, 6, -8),
            _marker(7, "West shed", "A scaffold shed over the pink lane, 4.2 high: slide or crouch "
                    "under it, or go round the end of the works.", -63, 10, 8),
            _marker(8, "East works gap", "The same in the pink lane at the other end: wall-run or "
                    "slide-jump it.", 63, 6, 8),
            _marker(9, "East shed", "And a shed over the green lane: slide under.", 63, 10, -8),
            _marker(10, "Staff room", "Shutters half down on both sides: slide in one side and out "
                    "the other to cut across the platform.", sum(STAFF) / 2, 10.5, 0),
            _marker(11, "Kiosk and benches", "The middle of the platform: run rings round the "
                    "kiosk and the columns, hurdle the benches.", -13, 5, 0),
            _marker(12, "Through the train", "While the train is in with its doors open it's a "
                    "second lane: in one door, along the cars, out another.", 26, 11, -TRACK_Z),
            _marker(13, "Middle car", "Seats either side of a glass screen down the middle of the "
                    "middle car: the one loop you can run on the moving train.", 0, 11, -TRACK_Z),
            _marker(14, "Tunnel drop", "Past the ends of the platform the tunnel floor gives way. "
                    "Falling in kills you.", 88, -3, -TRACK_Z),
        ],
        "views": {
            "Overview": [70, 165, 150, 0, -2, 0], "Whole loop": [0, 1180, 500, 0, -10, 0],
            "Platform": [-34, 7, 9, 30, 3, -4], "Boarding side": [-30, 14, -6, 20, 2, -TRACK_Z],
            "Exit side": [30, 14, 6, -20, 2, TRACK_Z], "West works": [-40, 22, -34, -63, 2, -6],
            "East works": [40, 22, 34, 63, 2, 6],
            "Old station": [gx + 34, 40, gz - 26, gx + 3, 0, gz],
        },
        "figure": [-4, 0, 7],
        "roof_names": ["Ceiling", "CeilingTunnel"],
        "roof_extra": ["Light", "CeilingTunnel",
                       "TrackWallUpper", "EndWallUpper", "TileBand", "NamePlate", "CableTray",
                       "WayOutSign"],
        "tunnel_groups": ["Tunnels"],
    }


def train_canvas():
    """What the canvas needs to run the train like the game will."""
    numbers = ride_numbers()
    rest = []
    for car in range(CARS):
        x, z, h = car_frame(STOP_A, car)
        rest.append([round(x, 3), round(z, 3), round(h, 3)])
    doors = [round(CAR_LEN / 2 + c * (CAR_LEN + GAP) - d, 3) for c in range(CARS) for d in DOORS]
    return {
        "segs": TRACK.export(), "length": round(TRACK.length, 4),
        "stops": {"A": STOP_A, "B": round(STOP_B, 4), "W": round(WAIT, 4),
                  "portalA": PORTAL_A, "portalB": round(PORTAL_B, 4)},
        "cars": CARS, "carLen": CAR_LEN, "gap": GAP, "bogie": BOGIE, "width": CAR_W,
        "floorY": 0, "rest": rest, "restNose": STOP_A, "doors": doors,
        "schedule": {k: (list(v) if isinstance(v, tuple) else v) for k, v in SCHEDULE.items()},
        "numbers": {k: round(v, 2) for k, v in numbers.items()},
        "pits": {"A": [-MOUTH_FLOOR, MOUTH_FLOOR, -OUTER, -PZ, PIT],
                 "B": [-MOUTH_FLOOR, MOUTH_FLOOR, PZ, OUTER, PIT]},
        "lanes": {"A": -8, "B": 8}, "edge": PZ, "trackZ": TRACK_Z,
        "crossings": [-77, -45, -23, 0, 23, 45, 77],
        "island": list(ISLAND), "boards": [[x, 11, 0] for x in BOARDS],
    }


CANVAS = _canvas()
TRAIN = train_canvas()


# ---- checks --------------------------------------------------------------------------------------

def jump_reach(drop, speed=SPRINT):
    """How far a running jump carries you before your feet fall `drop` below takeoff."""
    up = math.sqrt(2 * GRAVITY * JUMP)
    t = (up + math.sqrt(up * up + 2 * GRAVITY * drop)) / GRAVITY
    return speed * t


def train_clearance():
    """Smallest gap between the train's corners (and the middles of its sides, which cut in on
    a curve) and the walls: the platform edge and track wall in the station and tunnel mouths,
    the tunnel walls round the loops."""
    worst = math.inf
    half_w = CAR_W / 2
    s = 0.0
    while s < TRACK.length:
        for car in range(CARS):
            x, z, h = car_frame(s, car)
            middle = car_middle(s, car)
            a = math.radians(h)
            for du in (-CAR_LEN / 2, 0, CAR_LEN / 2):
                for dw in (-half_w, half_w):
                    px = x + du * math.cos(a) + dw * math.sin(a)
                    pz = z + du * math.sin(a) - dw * math.cos(a)
                    worst = min(worst, wall_gap(px, pz, middle))
        s += 2.0
    return worst


def car_end_gap():
    """Smallest gap between neighbouring cars' facing corners round the track: on a turn the
    inside corners close up, and too sharp a turn makes the cars clip into each other."""
    worst = math.inf
    half_l, half_w = CAR_LEN / 2, CAR_W / 2
    s = 0.0
    while s < TRACK.length:
        frames = [car_frame(s, c) for c in range(CARS)]
        for c in range(CARS - 1):
            ax, az, ah = frames[c]
            bx, bz, bh = frames[c + 1]
            a, b = math.radians(ah), math.radians(bh)
            fx, fz = math.cos(a), math.sin(a)
            for dw in (-half_w, half_w):
                rx = ax - half_l * fx + dw * math.sin(a)
                rz = az - half_l * fz - dw * math.cos(a)
                qx = bx + half_l * math.cos(b) + dw * math.sin(b)
                qz = bz + half_l * math.sin(b) - dw * math.cos(b)
                worst = min(worst, (rx - qx) * fx + (rz - qz) * fz)
        s += 2.0
    return worst


def wall_gap(px, pz, near):
    """How far a point of the train is inside its walls. `near`: the car's place on the track
    (the nearest stretch of track is looked for round it)."""
    if abs(px) <= PX:
        az = abs(pz)
        return min(az - PZ, OUTER - az)
    if abs(px) <= MOUTH:
        az = abs(pz)
        return min(az - (TRACK_Z - TUNNEL_HALF), OUTER - az)
    best = math.inf
    s = near - 24
    while s <= near + 24:
        x, z, _ = TRACK.at(s)
        best = min(best, math.hypot(px - x, pz - z))
        s += 0.5
    return TUNNEL_HALF - best


def check(m):
    problems = []
    numbers = ride_numbers()
    if not 15 <= numbers["rideTime"] <= 20:
        problems.append(f"the ride takes {numbers['rideTime']:.1f} s (want 15-20)")
    if not 10 <= numbers["loopTime"] <= 15:
        problems.append(f"the loop takes {numbers['loopTime']:.1f} s (want 10-15)")
    ends = car_end_gap()
    if ends < 0.4:
        problems.append(f"neighbouring cars come within {ends:.2f} of each other on the turns")
    gap = NOTCH[1] - NOTCH[0]
    if gap <= jump_reach(0) + 0.5:
        problems.append(f"a sprinting jump ({jump_reach(0):.1f}) clears the {gap} works gap")
    if gap >= jump_reach(0, SLIDE_JUMP):
        problems.append(f"a slide jump ({jump_reach(0, SLIDE_JUMP):.1f}) can't clear the gap")
    if WORKS[1] - WORKS[0] < gap + 4 or gap > WALL_RUN:
        problems.append("the works hoarding is too short for the wall run")
    if -PIT > mapcheck.JUMP_UP - 1:
        problems.append("the pits are too deep to jump out of")
    if SHED_TOP <= mapcheck.JUMP_UP or CROUCH_ROOM < mapcheck.CROUCH:
        problems.append("the sheds can be jumped onto, or slid under only by luck")
    clearance = train_clearance()
    if clearance < 0.3:
        problems.append(f"the train comes within {clearance:.2f} of a wall")
    a_doors = door_xs()
    b_doors = sorted(-x for x in a_doors)
    if any(abs(a - b) > 1e-6 for a, b in zip(a_doors, b_doors)):
        problems.append("the doors don't line up on both sides")
    if len(m.spawns) < ATTRIBUTES["MaxPlayers"]:
        problems.append("not enough spawns")
    # Wall runs along the works hoardings over the gaps, both ways.
    runs = [((-NOTCH[1] - 3, 0, -SPINE - 1.5), (-NOTCH[0] + 3, 0, -SPINE - 1.5), True),
            ((NOTCH[0] - 3, 0, SPINE + 1.5), (NOTCH[1] + 3, 0, SPINE + 1.5), True)]
    return problems + mapcheck.check_map(m, ATTRIBUTES, routes=runs)


if __name__ == "__main__":
    layout = build()
    numbers = ride_numbers()
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    print(f"track {TRACK.length:.1f} long; ride {numbers['ride']:.0f} studs in "
          f"{numbers['rideTime']:.1f} s (the loop {numbers['loopTime']:.1f} s); approach "
          f"{numbers['approachTime']:.1f} s; leave {numbers['leaveTime']:.1f} s; wall clearance "
          f"{train_clearance():.2f}; car ends {car_end_gap():.2f} apart at the closest")
    end = TRACK.at(TRACK.length - 1e-9)
    print(f"track closes at ({end[0]:.3f}, {end[1]:.3f}) heading {end[2] % 360:.1f}")
    issues = check(layout)
    for line in issues:
        print("PROBLEM:", line)
    if "--write" in sys.argv:
        os.chdir(REPO)
        layout.write(OUT, ATTRIBUTES)
        print(f"wrote {OUT}/")
    raise SystemExit(1 if issues else 0)
