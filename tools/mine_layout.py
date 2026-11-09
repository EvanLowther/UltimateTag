#!/usr/bin/env python3
"""The Desert Mine (6-12 players): an open sandstone mine in a canyon at midday, from the owner's
reference picture and the "Desert Mine Map" canvas. Run from the repo root:
    python3 tools/mine_layout.py
It rewrites `src/maps/DesertMine/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south, Y up. Three levels:
  PIT FLOOR (0): x -28..28, z -70..70, a safe floor with stepped stone ruins and two wall-run walls.
  LEDGES (24): x -60..-28 and 28..60, joined by two rope bridges over the pit.
  RIM (48): a full ring round the top.
Look: the Space Station's clean, simple style (see `simple_materials`): smooth plastic, plain colour
bands, a modest part count, no textured stone.
Gadgets: three two-way ziplines (press E at either end; client/Ziplines), a lift running 0, 24, 48
and back by itself (LiftStops; client/MapAmbience), five timed geysers that throw you up one level
(shared/Geysers). Also wooden stairs and one ladder. Solid shapes are simple; the rock faces, timber
and props over them are NO_HIT, and every prop stands on a surface or is tied to something.
"""
import math
import random
import sys

sys.path.insert(0, "tools")
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, matmul, rot_x, rot_y, rot_z  # noqa: E402

OUT = "src/maps/DesertMine"
ATTRIBUTES = {"DisplayName": "Desert Mine", "MinPlayers": 6, "MaxPlayers": 12, "InRotation": True,
              "Lighting": "Desert", "OutOfBounds": "BoundaryWall,RuinWall,Cart,MineCrane,ShedRoof"}

LEDGE, TOP = 24, 48
PX, LX, RX, RZ, PZ = 28, 60, 90, 100, 70  # pit, ledge and rim half-widths; rim and pit half-lengths
LIFT_X0, LIFT_X1, LIFT_Z0, LIFT_Z1 = 16.5, 27.5, 4, 16
GEYSER_UP = 112
GEYSERS = (  # vent (x, floor y, z), landing (x, y, z), phase
    ((-18, 0, -40), (-42, LEDGE, -40), 0), ((18, 0, 39), (42, LEDGE, 39), 2),
    ((-14, 0, 42), (-42, LEDGE, 62), 4),
    ((-45, LEDGE, -40), (-74, TOP, -40), 6), ((45, LEDGE, -18), (74, TOP, -18), 8),
)
LINES = (  # zipline ends and sag; cables are 10 over the ground they start from
    ((-63, TOP + 10, -46), (63, TOP + 10, -46), 8),
    ((-63, TOP + 10, 42), (44, LEDGE + 10, 42), 5),
    ((-24, TOP + 10, -73), (46, LEDGE + 10, 58), 6),
)
SPAWNS = ((-20, -34), (10, -8, 0), (-8, 8), (0, 62), (-44, -56, LEDGE), (-44, 34, LEDGE),
          (44, -48, LEDGE), (44, 12, LEDGE), (-75, -70, TOP), (75, -60, TOP), (-75, 62, TOP),
          (75, 82, TOP), (0, -86, TOP), (0, 86, TOP))

COLORS = {
    "sand": (226, 190, 132), "sandtop": (232, 200, 146), "plank": (150, 104, 62),
    "step": (162, 114, 70), "dark": (44, 34, 26), "vent": (84, 72, 60),
}
MATERIALS = {"sand": "Sand", "sandtop": "Sand", "plank": "WoodPlanks", "step": "WoodPlanks",
             "dark": "Slate", "vent": "Slate"}
STRATA = ((201, 142, 85), (214, 158, 100), (187, 124, 72), (222, 172, 116), (176, 112, 64),
          (208, 150, 92), (194, 134, 78))
WOOD = ((132, 90, 52), (118, 80, 46), (146, 100, 60), (108, 74, 44))
rng = random.Random(4077)


def jitter(color, amount=10):
    shift = rng.randint(-amount, amount)
    return tuple(max(0, min(255, c + shift)) for c in color)


def norm(v):
    length = math.sqrt(sum(c * c for c in v))
    return [c / length for c in v]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def beam(m, group, name, p0, p1, w, h, color, material="Wood", **props):
    """A timber or rope from p0 to p1 (local Z along it), NO_HIT unless props say otherwise."""
    # A hair of random offset and size, so no two timbers ever share a surface.
    nudge = (rng.uniform(-0.11, 0.11), rng.uniform(-0.05, 0.05), rng.uniform(-0.11, 0.11))
    p0 = [a + n for a, n in zip(p0, nudge)]
    p1 = [a + n for a, n in zip(p1, nudge)]
    w += rng.uniform(0, 0.07)
    h += rng.uniform(0, 0.07)
    d = [b - a for a, b in zip(p0, p1)]
    length = math.sqrt(sum(c * c for c in d))
    z = norm(d)
    x = norm(cross([0, 1, 0] if abs(z[1]) < 0.98 else [1, 0, 0], z))
    y = cross(z, x)
    # A slight, unique twist round its length: rough-cut, and no two faces are ever parallel.
    twist = math.radians(rng.uniform(0.4, 2.2) * rng.choice((-1, 1)))
    c, s = math.cos(twist), math.sin(twist)
    x, y = ([c * a + s * b for a, b in zip(x, y)], [c * b - s * a for a, b in zip(x, y)])
    rows = [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
    extra = dict(NO_HIT)
    extra.update(props)
    return m.part(group, name, (w, h, length), [(a + b) / 2 for a, b in zip(p0, p1)], color, rows,
                  Material=material, **extra)


def timber(m, group, p0, p1, w=0.7):
    beam(m, group, "Timber", p0, p1, w, w, jitter(rng.choice(WOOD), 5))


def rock_rows(amount):
    return matmul(rot_y(rng.uniform(-amount, amount)),
                  matmul(rot_x(rng.uniform(-amount, amount)), rot_z(rng.uniform(-amount, amount))))


def clad(m, axis, fixed, out, a0, a1, y0, y1, proud=(0.2, 0.7), lean=1.2, group="RockFaces"):
    """Layered rock on a vertical face: bands of chunky slabs, each tilted a little. `axis` is the
    way the face runs ("x" or "z"), `fixed` the face's other coordinate, `out` the side it faces."""
    y, layer = y0, rng.randint(0, 6)
    while y < y1 - 0.6:
        h = min(rng.uniform(6.5, 10.5), y1 - y)
        band = STRATA[layer % len(STRATA)]
        a = a0
        while a < a1 - 0.6:
            w = min(rng.uniform(26, 50), a1 - a)
            depth, thick = rng.uniform(*proud), 2.4
            centre, normal = a + w / 2, fixed + out * (depth - thick / 2)
            size = (w + 0.5, h + rng.uniform(0.1, 0.7), thick)
            pos = (centre, y + h / 2, normal) if axis == "x" else (normal, y + h / 2, centre)
            rows = rock_rows(lean) if axis == "x" else matmul(rot_y(90), rock_rows(lean))
            m.part(group, "RockFace", size, pos, jitter(band, 4), rows, Material="SmoothPlastic", **NO_HIT)
            a += w
        y += h
        layer += 1


def build_ground(m):
    block = m.block
    block("Ground", "PitFloor", -PX, PX, -2, 0, -PZ, PZ, "sand")
    for s, name in ((-1, "West"), (1, "East")):
        a, b = sorted((s * PX, s * LX))
        block("Ground", f"Ledge{name}", a, b, -1, LEDGE, -PZ, PZ, "sandtop")
        a, b = sorted((s * LX, s * RX))
        block("Ground", f"Rim{name}", a, b, -1.5, TOP, -RZ, RZ, "sandtop")
    block("Ground", "RimNorth", -LX, LX, -1.2, TOP, -RZ, -PZ, "sandtop")
    block("Ground", "RimSouth", -LX, LX, -1.3, TOP, PZ, RZ, "sandtop")
    # Keep everyone in: invisible walls round the rim (the cliffs behind are scenery).
    wall = dict(Transparency=1, CastShadow=False)
    block("Ground", "BoundaryWall", -RX - 2, -RX, 0, 130, -RZ - 2, RZ + 2, "sand", **wall)
    block("Ground", "BoundaryWall", RX, RX + 2, 0, 130, -RZ - 2, RZ + 2, "sand", **wall)
    block("Ground", "BoundaryWall", -RX, RX, 0, 130, -RZ - 2, -RZ, "sand", **wall)
    block("Ground", "BoundaryWall", -RX, RX, 0, 130, RZ, RZ + 2, "sand", **wall)


def build_rock_faces(m):
    for s in (-1, 1):
        clad(m, "z", s * PX, -s, -PZ, PZ, 0, LEDGE - 0.25)
        clad(m, "z", s * LX, -s, -PZ, PZ, LEDGE, TOP - 0.25)
    for s in (-1, 1):
        clad(m, "x", s * PZ, -s, -PX, PX, 0, LEDGE)
        for a0, a1 in ((-LX, -PX), (PX, LX)):
            clad(m, "x", s * PZ, -s, a0, a1, LEDGE, TOP - 0.25)
        clad(m, "x", s * PZ, -s, -PX, PX, LEDGE, TOP - 0.25)
    # Big fallen slabs and boulders against the foot of the walls (on the floor, sunk in a little).
    for _ in range(12):
        s, level = rng.choice((-1, 1)), rng.random() < 0.55
        y, x = (0, PX - 1.2) if level else (LEDGE, LX - 1.2)
        z = rng.uniform(-PZ + 3, PZ - 3)
        if abs(z - 10) < 12 and s > 0 and level:
            continue
        w, h = rng.uniform(1.6, 3.6), rng.uniform(1.0, 2.8)
        m.part("RockFaces", "Boulder", (w, h, rng.uniform(1.8, 4.2)),
               (s * x, y + h * 0.32, z), jitter(rng.choice(STRATA), 8), rock_rows(16),
               Material="Sandstone", **NO_HIT)


def build_cliffs(m):
    """The canyon behind the rim: big stepped mesas of tilted rock, out of reach."""
    def mesa(x, z, big):
        y, w, d = -2.0, big * rng.uniform(1.0, 1.4), big * rng.uniform(0.8, 1.2)
        for i in range(rng.randint(2, 3)):
            h = rng.uniform(30, 46)
            color = jitter(STRATA[(i * 2 + rng.randint(0, 2)) % len(STRATA)], 5)
            m.part("Cliffs", "Mesa", (w, h + 4, d), (x + rng.uniform(-4, 4), y + h / 2, z + rng.uniform(-4, 4)), color,
                   rock_rows(2), Material="SmoothPlastic", **NO_HIT)
            y += h
            w, d = w * rng.uniform(0.66, 0.84), d * rng.uniform(0.66, 0.84)

    for x in range(-300, 301, 86):
        mesa(x + rng.uniform(-10, 10), -RZ - 44 - rng.uniform(0, 26), 76)
        mesa(x + rng.uniform(-10, 10), RZ + 44 + rng.uniform(0, 26), 76)
    for z in range(-180, 181, 86):
        mesa(-RX - 44 - rng.uniform(0, 26), z + rng.uniform(-10, 10), 76)
        mesa(RX + 44 + rng.uniform(0, 26), z + rng.uniform(-10, 10), 76)
    m.block("Cliffs", "FarSand", -700, 700, -6, -2.5, -700, 700, (214, 176, 122), Material="Sand",
            **NO_HIT)


def stairs(m, x0, x1, z_from, z_to, y0, y1, open_x):
    """A flight rising along Z, each step one plank thick, on timber stringers and posts."""
    steps = round(y1 - y0)
    run, rise = (z_to - z_from) / steps, (y1 - y0) / steps
    for i in range(steps):
        a, b = sorted((z_from + run * i, z_from + run * (i + 1)))
        top = y0 + rise * (i + 1)
        m.block("Stairs", "Step", x0, x1, top - 0.45, top, a, b, jitter(COLORS["step"], 9),
                Material="WoodPlanks")
    def at(i):
        return z_from + run * i, y0 + rise * i
    for x in (x0 + 0.5, x1 - 0.5):
        (z0, ya), (z1, yb) = at(0), at(steps)
        beam(m, "Stairs", "Stringer", (x, ya - 0.85, z0), (x, yb - 0.85, z1), 0.6, 1.0, WOOD[1])
    for i in range(5, steps, 8):
        z, y = at(i)
        for x in (x0 + 0.5, x1 - 0.5):
            timber(m, "Stairs", (x, y0, z), (x, y - 0.9, z), 0.6)
    # The handrail along the open side.
    last = None
    for i in range(0, steps + 1, 8):
        z, y = at(i)
        top = (open_x, y + 3.3, z)
        timber(m, "Stairs", (open_x, y - 0.8, z), top, 0.34)
        if last:
            timber(m, "Stairs", last, top, 0.26)
        last = top


def build_stairs(m):
    stairs(m, -PX, -19, 8, 44, 0, LEDGE, -19.3)
    stairs(m, 19, PX, -28, -64, 0, LEDGE, 19.3)
    stairs(m, -LX, -51, 24, -12, LEDGE, TOP, -51.3)
    stairs(m, 51, LX, 40, 4, LEDGE, TOP, 51.3)
    # The one ladder: a timber-framed ladder on the north wall, from the west ledge to the rim.
    m.ladder("Stairs", -43, -PZ, (0, 1), LEDGE, TOP, width=4, color=(112, 78, 46), name="MineLadder")
    for x in (-46.2, -39.8):
        timber(m, "Stairs", (x, LEDGE, -PZ + 0.7), (x, TOP + 1.2, -PZ + 0.7), 0.5)


def rope_bridge(m, z):
    w = 4.2
    half = PX
    m.block("Bridges", "BridgeDeck", -half, half, LEDGE - 0.6, LEDGE - 0.02, z - w, z + w, "plank",
            Transparency=1, CastShadow=False)
    x = -half + 1.15
    while x < half - 0.4:
        depth = 2.1
        m.part("Bridges", "Plank", (depth, 0.3, 2 * w + rng.uniform(-0.5, 0.5)),
               (x, LEDGE - 0.08 + rng.uniform(-0.03, 0.03), z + rng.uniform(-0.25, 0.25)),
               jitter(rng.choice(WOOD), 10), rot_y(rng.uniform(-1.6, 1.6)), Material="WoodPlanks", **NO_HIT)
        x += 2.4
    for side in (-1, 1):
        zs = z + side * (w - 0.3)
        # Two under-ropes carry the planks; top ropes sag from post to post.
        beam(m, "Bridges", "Rope", (-half - 1.5, LEDGE - 0.35, zs), (half + 1.5, LEDGE - 0.35, zs), 0.26, 0.26,
             (92, 72, 48), "Fabric")
        prev = None
        for i in range(9):
            t = i / 8
            xr = -half + 2 * half * t
            y = LEDGE + 4.4 - 1.7 * 4 * t * (1 - t)
            p = (xr, y, zs)
            if prev:
                beam(m, "Bridges", "Rope", prev, p, 0.2, 0.2, (96, 76, 52), "Fabric")
            if 0 < i < 8:
                beam(m, "Bridges", "Rope", p, (xr, LEDGE - 0.55, zs), 0.1, 0.1, (110, 90, 60), "Fabric")
            prev = p
        for sx in (-1, 1):
            post_x = sx * (half + 1.8)
            timber(m, "Bridges", (post_x, LEDGE, zs), (post_x, LEDGE + 5.4, zs), 0.8)
            beam(m, "Bridges", "Rope", (sx * half, LEDGE + 4.4, zs), (post_x, LEDGE + 5, zs), 0.22, 0.22,
                 (92, 72, 48), "Fabric")
            # A guy rope down to a stake in the ground.
            stake = (sx * (half + 7), LEDGE + 0.8, zs)
            beam(m, "Bridges", "Rope", (post_x, LEDGE + 5, zs), stake, 0.2, 0.2, (92, 72, 48), "Fabric")
            timber(m, "Bridges", (stake[0], LEDGE, zs), stake, 0.42)


def ruin(m, x0, x1, z0, z1, tiers, base=0):
    y = base
    for t in range(tiers):
        color = (220, 186, 138)
        m.block("Ruins", "Ruin", x0, x1, y, y + 4, z0, z1, color, Material="Sandstone")
        m.block("Ruins", "RuinCap", x0 - 0.18, x1 + 0.18, y + 3.3, y + 3.75, z0 - 0.18, z1 + 0.18, (202, 166, 118), **NO_HIT)
        y += 4
        if t < tiers - 1:
            # The next tier sits back on one side, leaving steps to climb.
            x0 += 2.4
            z0 += 2.0
            x1 -= rng.choice((0, 1.2))
    # Loose blocks fallen round the foot.
    for _ in range(2):
        a = rng.uniform(0, math.tau)
        cx, cz = (x0 + x1) / 2 + math.cos(a) * (x1 - x0) * 0.9, (z0 + z1) / 2 + math.sin(a) * (z1 - z0) * 0.9
        size = rng.uniform(0.9, 1.9)
        m.part("Ruins", "LooseStone", (size * 1.4, size, size), (cx, base + size * 0.42, cz),
               jitter((214, 178, 130), 10), rock_rows(22), Material="Sandstone", **NO_HIT)


def build_ruins(m):
    ruin(m, -14, -2, -62, -48, 2)
    ruin(m, 2, 14, -60, -46, 3)
    ruin(m, -21, -9, -22, -10, 2)
    ruin(m, -3, 9, 18, 34, 1)
    ruin(m, -23, -12, 52, 64, 2)
    ruin(m, 6, 20, 48, 60, 2)
    for x0 in (-2, 11):
        m.block("Ruins", "RuinWall", x0, x0 + 3, 0, 16, -30, 2, (214, 178, 130), Material="Sandstone")
        for y in (5, 10.5):
            m.block("Ruins", "RuinCap", x0 - 0.15, x0 + 3.15, y, y + 0.5, -30.15, 2.15, (198, 162, 116), **NO_HIT)


def build_lift(m):
    x0, x1, z0, z1 = LIFT_X0, LIFT_X1, LIFT_Z0, LIFT_Z1
    # The tower: posts on the pit floor against the east ledge, braced on the north and south.
    top = TOP + 8
    px0, px1 = x0 - 0.6, x1 + 0.3
    for x in (px0, px1):
        for z in (z0 - 0.6, z1 + 0.6):
            m.block("Lift", "TowerPost", x - 0.45, x + 0.45, 0, top, z - 0.45, z + 0.45, rng.choice(WOOD), Material="Wood")
    for z in (z0 - 0.6, z1 + 0.6):
        y = 0
        while y < top - 8:
            timber(m, "Lift", (px0, y + 0.4, z), (px1, y + 16, z), 0.42)
            timber(m, "Lift", (px0, y + 16, z), (px1, y + 16, z), 0.5)
            y += 16
    # The head: beams across the top and a winding drum, with cables down to the car.
    for z in (z0 - 0.6, z1 + 0.6):
        timber(m, "Lift", (px0, top, z), (px1, top, z), 0.9)
    timber(m, "Lift", (px0, top, z0 - 0.6), (px0, top, z1 + 0.6), 0.9)
    timber(m, "Lift", (px1, top, z0 - 0.6), (px1, top, z1 + 0.6), 0.9)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.cylinder("Lift", "Drum", z1 - z0 - 1, 2.6, (cx, top + 1.6, cz), (86, 88, 92), rot_y(90), Material="Metal", **NO_HIT)
    for z in (z0 + 1, z1 - 1):
        beam(m, "Lift", "LiftCable", (cx, top + 0.4, z), (cx, 9.55, z), 0.16, 0.16, (40, 40, 44), "Metal")
    # The car (moves on every screen, server clock; the floor carries you).
    motion = {"LiftStops": f"0,{LEDGE},{TOP}", "LiftMove": 3, "LiftWait": 4}
    floor_attrs = dict(motion)
    floor_attrs["Carry"] = True
    m.block("Lift", "LiftFloor", x0, x1, -0.45, 0.15, z0, z1, "plank", attributes=floor_attrs)
    def moving(name, a0, a1, b0, b1, c0, c1, color, material="Wood"):
        m.block("Lift", name, a0, a1, b0, b1, c0, c1, color, Material=material, attributes=motion, **NO_HIT)
    for z, zz in ((z0 + 0.1, z0 + 0.45), (z1 - 0.45, z1 - 0.1)):
        for x in (x0 + 0.08, x0 + 5.3, x1 - 0.48):
            moving("LiftPost", x, x + 0.4, 0.15, 3.6, z, zz, WOOD[0])
        moving("LiftRail", x0, x1, 3.6, 3.95, z - 0.07, zz + 0.07, WOOD[2])
        moving("LiftRail", x0, x1, 1.9, 2.15, z - 0.12, zz + 0.12, WOOD[1])
    for z, zz in ((z0 + 0.15, z0 + 0.4), (z1 - 0.4, z1 - 0.15)):
        moving("LiftMast", cx - 0.3, cx + 0.3, 3.95, 9.2, z, zz, (70, 72, 76), "Metal")
    moving("LiftBar", cx - 0.3, cx + 0.3, 9.2, 9.7, z0 + 0.15, z1 - 0.15, (70, 72, 76), "Metal")
    # The walkway from the tower's top across to the rim, on posts down to the ledge.
    x_a = LIFT_X1 + 0.4
    m.block("Lift", "WalkwayDeck", x_a, LX, TOP - 0.6, TOP - 0.02, 6, 14, "plank", Transparency=1, CastShadow=False)
    x = x_a + 1.1
    while x < LX - 0.2:
        m.part("Lift", "Plank", (2.1, 0.3, 8 + rng.uniform(-0.2, 0.2)), (x, TOP - 0.08, 10), jitter(rng.choice(WOOD), 9),
               Material="WoodPlanks", **NO_HIT)
        x += 2.35
    for x in (36, 45, 54):
        for z in (6.4, 13.6):
            m.block("Lift", "WalkPost", x - 0.4, x + 0.4, LEDGE, TOP - 0.6, z - 0.4, z + 0.4, rng.choice(WOOD), Material="Wood")
    for z in (6.2, 13.8):
        timber(m, "Lift", (x_a, TOP + 3.3, z), (LX, TOP + 3.3, z), 0.3)
        for x in range(30, 60, 14):
            timber(m, "Lift", (x, TOP - 0.4, z), (x, TOP + 3.3, z), 0.28)
    for z in (6.4, 13.6):
        timber(m, "Lift", (36, TOP - 1, z), (54, TOP - 1, z), 0.55)
        timber(m, "Lift", (LIFT_X1 + 0.3, TOP - 1, z), (36, TOP - 1, z), 0.55)


def build_ziplines(m):
    for index, (a, b, sag) in enumerate(LINES):
        prev = None
        for i in range(15):
            t = i / 14
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t),
                 a[2] + (b[2] - a[2]) * t)
            if prev:
                beam(m, "Ziplines", "Cable", prev, p, 0.2, 0.2, (40, 38, 36), "Metal")
            prev = p
        for here, there in ((a, b), (b, a)):
            gantry(m, index, here, there, sag)


def gantry(m, index, here, there, sag):
    x, y, z = here
    ground = y - 10
    dx, dz = there[0] - x, there[2] - z
    length = math.hypot(dx, dz)
    fx, fz = dx / length, dz / length      # towards the far end
    sx, sz = -fz, fx                       # across the line
    def at(along, across, height):
        return (x + fx * along + sx * across, height, z + fz * along + sz * across)
    width = 4.6
    for s in (-1, 1):
        timber(m, "Ziplines", at(-1.2, s * width, ground), at(0, s * width, y + 1.2), 1.0)
        timber(m, "Ziplines", at(-4.5, s * width, ground), at(0, s * width, y - 1.5), 0.6)
    timber(m, "Ziplines", at(0, -width - 0.6, y + 0.9), at(0, width + 0.6, y + 0.9), 0.9)
    # The wheel the cable runs over, and its bracket.
    wheel_rows = rot_y(math.degrees(math.atan2(-fz, fx)) + 90)
    m.cylinder("Ziplines", "Wheel", 0.5, 2.4, (x, y + 0.12, z), (72, 68, 62), matmul(wheel_rows, rot_y(90)),
               Material="Metal", **NO_HIT)
    timber(m, "Ziplines", (x, y + 0.5, z), (x, y + 0.9, z), 0.5)
    # Back-stay: the cable runs on over the wheel to a stake and rocks behind the gantry.
    stake = at(-9, 0, ground + 0.8)
    beam(m, "Ziplines", "Cable", here, stake, 0.2, 0.2, (40, 38, 36), "Metal")
    timber(m, "Ziplines", (stake[0], ground, stake[2]), stake, 0.6)
    for k in range(2):
        size = rng.uniform(1.0, 1.9)
        m.part("Ziplines", "StakeRock", (size * 1.3, size, size),
               (stake[0] + rng.uniform(-1.4, 1.4), ground + size * 0.34, stake[2] + rng.uniform(-1.4, 1.4)),
               jitter(rng.choice(STRATA), 8), rock_rows(20), Material="Sandstone", **NO_HIT)
    # The grab point: press E on the ground under the wheel.
    prompt = {"name": "Prompt", "className": "ProximityPrompt", "properties": {
        "ActionText": "Grab zipline", "ObjectText": "Zipline", "KeyboardKeyCode": "E",
        "MaxActivationDistance": 13, "RequiresLineOfSight": False, "HoldDuration": 0}}
    attrs = {"ZipFrom": {"Vector3": list(here)}, "ZipTo": {"Vector3": list(there)}, "ZipSag": sag, "ZipLine": index + 1}
    m.part("Ziplines", "ZipGrab", (2, 2, 2), (x, ground + 2.4, z), (200, 200, 200), Transparency=1, CastShadow=False,
           attributes=attrs, children=[prompt], **NO_HIT)


def build_geysers(m):
    for (x, y, z), (tx, ty, tz), phase in GEYSERS:
        rise = ty - y
        flight = (GEYSER_UP + math.sqrt(GEYSER_UP ** 2 - 2 * mapcheck.GRAVITY * rise)) / mapcheck.GRAVITY
        velocity = [round((tx - x) / flight, 2), GEYSER_UP, round((tz - z) / flight, 2)]
        steam = m.particles("Steam", 150, (0.5, 1.0), (62, 84), [(0, 4), (0.5, 9), (1, 15)], [(0, 0.12), (0.7, 0.45), (1, 1)],
                            (250, 250, 250), spread=(5, 5))
        steam["properties"]["Enabled"] = False
        rumble = m.particles("Rumble", 26, (0.5, 0.9), (6, 12), [(0, 1.6), (1, 4.6)], [(0, 0.45), (1, 1)],
                             (232, 206, 170), spread=(28, 28))
        rumble["properties"]["Enabled"] = False
        m.cylinder("Geysers", "GeyserVent", 0.8, 6.6, (x, y + 0.0, z), "vent", children=[steam, rumble],
                   attributes={"LaunchVelocity": {"Vector3": velocity}, "GeyserPeriod": 10, "GeyserBlow": 3,
                               "GeyserRumble": 2, "GeyserPhase": phase})
        # The vent's throat, mineral stains and the ring of broken rock round it.
        m.cylinder("Geysers", "VentThroat", 0.12, 3.2, (x, y + 0.46, z), (30, 26, 22), **NO_HIT)
        m.cylinder("Geysers", "Stain", 0.06, 13, (x, y + 0.05, z), (228, 214, 186), Material="Limestone", **NO_HIT)
        for k in range(7):
            a = k / 7 * math.tau + rng.uniform(-0.12, 0.12)
            rad = rng.uniform(3.7, 5)
            w, h = rng.uniform(1.0, 2.3), rng.uniform(0.9, 2.3)
            m.part("Geysers", "VentRock", (w, h, rng.uniform(1.1, 2.1)),
                   (x + math.cos(a) * rad, y + h * 0.36, z + math.sin(a) * rad),
                   jitter((122, 100, 78), 14), rock_rows(24), Material="Slate", **NO_HIT)


def shrub(m, x, y, z):
    r = rng.uniform(1.1, 2.0)
    for _ in range(rng.randint(2, 3)):
        rr = r * rng.uniform(0.55, 1.0)
        p = (x + rng.uniform(-r, r) * 0.8, y + rr * 0.55, z + rng.uniform(-r, r) * 0.8)
        m.part("Clutter", "Shrub", (rr * 2, rr * 1.3, rr * 2), p, jitter((122, 132, 74), 16), Shape="Ball", Material="Grass", **NO_HIT)


def clear(x, z, level):
    """Is (x, z) free of stairs, gadgets and ruins on this level, for scattering small things?"""
    if level == 0:
        boxes = ((-24, -1, -63, -45), (1, 15, -61, -45), (-22, -8, -23, -9), (-4, 10, 17, 35), (-24, -11, 51, 65),
                 (5, 21, 47, 61), (-3, 15, -31, 3), (-29, -18, 7, 45), (18, 29, -65, -27), (15, 29, 3, 18))
    elif level == 1:
        boxes = ((-61, -50, -13, 25), (50, 61, 3, 41), (-48, -38, -71, -62))
    else:
        boxes = ()
    if any(a <= x <= b and c <= z <= d for a, b, c, d in boxes):
        return False
    for (vx, vy, vz), _, _ in GEYSERS:
        if abs(vy - (0, LEDGE, TOP)[level]) < 1 and math.hypot(x - vx, z - vz) < 9:
            return False
    return True


def scatter(m, count, x0, x1, z0, z1, y, level):
    for _ in range(count):
        x, z = rng.uniform(x0, x1), rng.uniform(z0, z1)
        if not clear(x, z, level):
            continue
        kind = rng.random()
        if kind < 0.45:
            shrub(m, x, y, z)
        else:
            size = rng.uniform(0.8, 1.9)
            m.part("Clutter", "Pebble", (size * 1.4, size, size * 1.1), (x, y + size * 0.3, z), jitter(rng.choice(STRATA), 6),
                   rock_rows(24), Material="SmoothPlastic", **NO_HIT)


def crate(m, x, y, z, s):
    m.block("Props", "Crate", x - s, x + s, y, y + 2 * s, z - s, z + s, jitter((150, 108, 66), 10), Material="WoodPlanks")


def barrel(m, x, y, z):
    m.cylinder("Props", "Barrel", 3.2, 2.2, (x, y + 1.6, z), (128, 86, 50), Material="Wood")
    for h in (0.7, 2.5):
        m.cylinder("Props", "Hoop", 0.2, 2.34, (x, y + h, z), (66, 62, 58), Material="Metal", **NO_HIT)


def mine_portal(m, wall_x, out, z):
    """A boarded-up mine tunnel in a pit wall: a timber frame round a dark mouth."""
    half, h = 6.0, 11
    x = wall_x + out * 0.95
    m.block("Props", "TunnelDark", min(x, x + out * 0.1), max(x, x + out * 0.1), 0, h - 0.4, z - half, z + half, "dark", **NO_HIT)
    fx = x + out * 0.75
    for s in (-1, 1):
        timber(m, "Props", (fx, 0, z + s * half), (fx, h, z + s * half), 1.3)
    timber(m, "Props", (fx, h, z - half - 1.2), (fx, h, z + half + 1.2), 1.4)
    for k in range(5):
        y = 1.6 + k * 2.0
        beam(m, "Props", "Board", (fx - out * 0.35, y, z - half + 0.2), (fx - out * 0.35, y + rng.uniform(-0.7, 0.7), z + half - 0.2),
             0.2, 1.2, jitter(rng.choice(WOOD), 12), "WoodPlanks")


def build_props(m):
    # Mine tunnels with an ore track leading out, and a cart on it.
    mine_portal(m, -PX, 1, -36)
    mine_portal(m, PX, -1, 42)
    for x in (-3.2, 3.2):
        pass
    rail_x = (PX - 10)
    for a, b in ((-PX + 1.8, -24), ):
        for z in (-37.6, -34.4):
            m.block("Props", "OreRail", a, b, 0.14, 0.4, z - 0.14, z + 0.14, (84, 80, 76), Material="Metal", **NO_HIT)
        x = a
        while x < b:
            m.block("Props", "Sleeper", x, x + 0.9, 0.03, 0.14, -38.6, -33.4, jitter(WOOD[0], 8), Material="Wood", **NO_HIT)
            x += 2
    for a, b in ((24, PX - 1.8), ):
        for z in (40.4, 43.6):
            m.block("Props", "OreRail", a, b, 0.14, 0.4, z - 0.14, z + 0.14, (84, 80, 76), Material="Metal", **NO_HIT)
        x = a
        while x < b:
            m.block("Props", "Sleeper", x, x + 0.9, 0.03, 0.14, 39.4, 44.6, jitter(WOOD[0], 8), Material="Wood", **NO_HIT)
            x += 2
    # Stacks on the ledges and rim, against the back walls so they're out of the running lanes.
    for x, z in ((-56, 40), (-56, 46), (-52.2, 43)):
        crate(m, x, LEDGE, z, 1.6)
    crate(m, -56, LEDGE + 3.2, 40, 1.3)
    for x, z in ((56, -50), (56, -44)):
        crate(m, x, LEDGE, z, 1.8)
    for x, y, z in ((-55, LEDGE, 54), (-52, LEDGE, 56), (55, LEDGE, -56), (-82, TOP, -20), (-80, TOP, -16), (82, TOP, 30), (30, 0, -66) ,(-24, 0, -66)):
        barrel(m, x, y, z)
    for x, z in ((-82, -30), (82, 20), (82, 26), (-6, 90), (-1, 90)):
        crate(m, x, TOP, z, 1.8)
    # A site hut on the south rim, with an awning and tools.
    h0, h1, z0, z1 = 22, 40, 78, 92
    m.block("Props", "Hut", h0, h1, TOP, TOP + 9, z0, z1, (156, 112, 70), Material="WoodPlanks")
    m.block("Props", "ShedRoof", h0 - 1.2, h1 + 1.2, TOP + 9, TOP + 9.6, z0 - 1.2, z1 + 1.2, (94, 92, 88), Material="CorrodedMetal")
    m.block("Props", "HutDoor", 29, 33, TOP + 0.02, TOP + 7, z0 - 0.08, z0 - 0.02, (88, 60, 36), Material="Wood", **NO_HIT)
    for x in (-1, 12):
        pass
    # An old wooden crane on the north rim's edge, like the picture's winch towers.
    x, z = 24, -76
    for ox in (-4, 4):
        m.block("Props", "MineCrane", x + ox - 0.5, x + ox + 0.5, TOP, TOP + 16, z - 0.5, z + 0.5, WOOD[0], Material="Wood")
        timber(m, "Props", (x + ox, TOP, z - 5), (x + ox, TOP + 14, z), 0.7)
        timber(m, "Props", (x + ox, TOP + 8, z - 3), (x + ox, TOP + 8, z), 0.4)
    timber(m, "Props", (x - 4.5, TOP + 16, z), (x + 4.5, TOP + 16, z), 0.9)
    m.cylinder("Props", "Winch", 8, 2.0, (x, TOP + 15, z), (92, 88, 82), rot_y(0), Material="Metal", **NO_HIT)
    timber(m, "Props", (x, TOP + 15, z), (x, TOP + 13, z + 7.9), 0.7)
    beam(m, "Props", "Rope", (x, TOP + 13, z + 7.9), (x, LEDGE + 1.6, z + 7.9), 0.16, 0.16, (92, 72, 48), "Fabric")
    m.block("Props", "Bucket", x - 1.2, x + 1.2, LEDGE, LEDGE + 2.0, z + 6.7, z + 9.1, (88, 84, 78), Material="CorrodedMetal", **NO_HIT)
    # Timber shoring against the walls: props and braces standing on the ledges and the floor.
    for s in (-1, 1):
        for z in range(-48, 49, 48):
            if abs(z) < 3:
                continue
            for x, y0, y1 in ((s * (PX - 0.8), 0, LEDGE - 2), (s * (LX - 0.8), LEDGE, TOP - 2)):
                if s > 0 and y0 == 0 and 1 < z < 20:
                    continue
                if (s < 0 and y0 == 0 and 7 < z < 46) or (s > 0 and y0 == 0 and -66 < z < -26):
                    continue
                if (s < 0 and y0 == LEDGE and -14 < z < 26) or (s > 0 and y0 == LEDGE and 2 < z < 42):
                    continue
                timber(m, "Props", (x, y0, z - 4), (x, y1, z - 4), 0.8)
                timber(m, "Props", (x, y0, z + 4), (x, y1, z + 4), 0.8)
                timber(m, "Props", (x, y1, z - 4.8), (x, y1, z + 4.8), 0.9)


def simple_materials(m):
    """The owner's look (matching the Space Station): smooth colours, only real metal and glass
    keep their material."""
    for group in m.groups.values():
        stack = list(group)
        while stack:
            node = stack.pop()
            props = node.get("properties", {})
            if "Material" in props and props["Material"] not in ("Metal", "Glass", "DiamondPlate"):
                props["Material"] = "SmoothPlastic"
            stack.extend(node.get("children", ()))


def build():
    m = Map(colors=COLORS, materials=MATERIALS)
    build_ground(m)
    build_rock_faces(m)
    build_cliffs(m)
    build_stairs(m)
    rope_bridge(m, -35)
    rope_bridge(m, 30)
    build_ruins(m)
    build_lift(m)
    build_ziplines(m)
    build_geysers(m)
    scatter(m, 20, -27, 27, -69, 69, 0, 0)
    scatter(m, 12, -59, -29, -69, 69, LEDGE, 1)
    scatter(m, 12, 29, 59, -69, 69, LEDGE, 1)
    for x0, x1, z0, z1 in ((-89, -61, -99, 99), (61, 89, -99, 99), (-59, 59, -99, -72), (-59, 59, 72, 99)):
        scatter(m, 10, x0, x1, z0, z1, TOP, 2)
    build_props(m)
    for spawn in SPAWNS:
        m.spawn(spawn[0], spawn[1], spawn[2] if len(spawn) > 2 else 0)
    simple_materials(m)
    return m


def check(m):
    problems = mapcheck.check_map(m, ATTRIBUTES)
    nodes = [n for group in m.groups.values() for n in group]
    reach = mapcheck.Reach(mapcheck.parts_from_nodes(nodes), [(x, y + 0.5, z) for x, y, z in m.spawns])
    reach.build()
    for (x, y, z), (tx, ty, tz), _ in GEYSERS:
        rise = ty - y
        flight = (GEYSER_UP + math.sqrt(GEYSER_UP ** 2 - 2 * mapcheck.GRAVITY * rise)) / mapcheck.GRAVITY
        landing = reach.fly(x, y + 0.4 + mapcheck.ROOT, z, (tx - x) / flight, GEYSER_UP, (tz - z) / flight)
        where = reach.nodes[landing][:3] if landing is not None else None
        print(f"geyser at {(x, y, z)}: lands at {where} (x, z, y)")
        if where is None or abs(where[2] - ty) > 0.6:
            problems.append(f"geyser at {(x, y, z)} doesn't land on {ty} ({where})")
    return problems


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
