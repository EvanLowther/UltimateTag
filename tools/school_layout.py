#!/usr/bin/env python3
"""The School (2-8 players): a two-floor school round a double-height atrium, designed on the
"School Map Rework" canvas (grey-box v1). Run from the repo root:
    python3 tools/school_layout.py
It rewrites `src/maps/School/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south (north is -Z), Y up. Inside 128 x 144. Ground floor at 0 (ceiling 16),
upper floor at 18 (ceiling 34), roof 34-37. The gym, the atrium and the library are double height.

Tag flow: two loops instead of one. The inner loop is the hall ring round the atrium, on both
floors; the outer loop runs through rooms that open into each other (gym, locker room, library,
stairwells, kitchen, band room, classrooms). Eleven ways between the floors, none of them one-way:
   1 the open grand stair up the middle of the atrium (run under its high end)
   2 the gym bleachers (vault row to row, or the aisle) up to the upper floor
   3 the north-west stairwell, 4 the south-east stairwell (switchbacks)
   5 the upper hall's floor, fallen into the cafeteria as a ramp (up, down, or under its low end)
   6 the science lab's floor, fallen into Room 101: drop, or climb the rubble and the cabinet
   7 the library shelf tops (9) up onto the mezzanine (18)
   8 the atrium's corner pillars: wall-climb two hops onto the balcony
   9 the balcony railing: vault it anywhere and drop 18 (landing roll)
  10 the gym springboard up onto the running track
  11 the running track's railing: vault off into the gym
Rooms: north the gym (bleachers, running track at 18, springboard); north-west and south-east the
stairwells; north-east the locker room (slippery showers) with the teachers' lounge above; west
Rooms 101 and 102 with the science lab and the computer lab above; east the library (shelf rows,
the mezzanine, a bridge from the balcony); south the cafeteria (lunch tables, a serving line
with a slide-under shutter and a vault-over counter), the kitchen (walk-in fridge, greasy floor)
and the band room, with the art room, the upper hall and the music room above.
"""
import math
import re
import sys

sys.path.insert(0, "tools")
from maplib import IDENTITY, NO_HIT, SMOKE, SPARK, Map, rot_x, rot_y, rot_z  # noqa: E402

OUT = "src/maps/School"
ATTRIBUTES = {"DisplayName": "School", "MinPlayers": 2, "MaxPlayers": 8, "InRotation": True,
              "Lighting": "Indoor"}

IN_X, IN_Z = 64, 72  # inside faces of the outer walls
WALL = 2
F1, F1_TOP, F2, F2_TOP, ROOF = 0, 16, 18, 34, 37  # floors, ceilings, roof top
DOOR, DOOR2 = F1 + 10, F2 + 10  # doorway tops on each floor

# Openings in the upper floor (x0, x1, z0, z1).
GYM = (-40, 40, -72, -32)
LIBRARY = (32, 64, -32, 32)
VOID = (-12, 12, -12, 12)  # the atrium, open up to the skylight
NW_STAIR = (-64, -40, -72, -40)
SE_STAIR = (40, 64, 40, 72)
LAB_HOLE = (-52, -44, -20, -12)  # the science lab floor, fallen into Room 101
COLLAPSE = (4, 36, 37, 43)  # the upper hall floor, fallen into the cafeteria

SPRINGBOARD = (0, -60)
LAUNCH = (0, 95, -12)  # clears the track railing and lands mid-track (tune in game)

COLORS = {
    "floor": (140, 146, 156), "wall": (178, 168, 146), "ceiling": (110, 112, 120),
    "room_floor": (135, 100, 70), "desk": (160, 110, 70), "board": (40, 80, 60),
    "locker_a": (60, 110, 200), "locker_b": (45, 90, 170), "table": (230, 120, 60),
    "puddle": (90, 170, 230), "concrete_dark": (80, 82, 88), "pad": (255, 140, 40),
    "grate": (60, 60, 64), "hazard": (250, 200, 40), "shelf": (120, 80, 50),
    "books_a": (190, 60, 60), "books_b": (60, 120, 190), "books_c": (220, 180, 60),
    "debris": (128, 128, 134), "rubble": (150, 145, 135), "chain": (90, 92, 98),
    "door": (150, 100, 60), "gym_floor": (214, 168, 106), "carpet_red": (150, 62, 62),
    "carpet_blue": (62, 84, 150), "lab_floor": (222, 226, 230), "cafe_floor": (214, 204, 176),
    "kitchen_floor": (176, 76, 64), "terrazzo": (200, 194, 182), "art_floor": (150, 152, 156),
    "bleacher": (176, 126, 74), "track": (196, 88, 62), "rail": (62, 68, 78),
    "pillar": (214, 204, 184), "stair": (152, 158, 168), "lab_bench": (44, 48, 58),
    "fridge": (205, 210, 215), "counter": (180, 186, 192), "mat": (52, 92, 204),
    "piano": (28, 28, 32), "planter": (128, 92, 70), "plant": (72, 150, 72),
    "vending": (205, 44, 44), "couch": (92, 124, 92), "comp_floor": (96, 108, 128),
    "glass": (185, 215, 235), "court_line": (245, 245, 245), "pad_wall": (40, 70, 160),
    "plate": (40, 40, 50), "light": (235, 235, 220),
}
MATERIALS = {
    "floor": "CeramicTiles", "wall": "Plaster", "ceiling": "Plaster", "room_floor": "WoodPlanks",
    "desk": "Wood", "board": "Slate", "locker_a": "Metal", "locker_b": "Metal",
    "concrete_dark": "Brick", "grate": "DiamondPlate", "shelf": "Wood", "debris": "Concrete",
    "rubble": "Slate", "chain": "Metal", "door": "Wood", "gym_floor": "WoodPlanks",
    "carpet_red": "Fabric", "carpet_blue": "Fabric", "lab_floor": "CeramicTiles",
    "cafe_floor": "CeramicTiles", "kitchen_floor": "CeramicTiles", "terrazzo": "Marble",
    "art_floor": "Concrete", "bleacher": "WoodPlanks", "rail": "Metal", "pillar": "Concrete",
    "stair": "Concrete", "lab_bench": "Slate", "fridge": "Metal", "counter": "Metal",
    "mat": "Fabric", "planter": "Brick", "plant": "Grass", "couch": "Fabric",
    "comp_floor": "Fabric", "pad_wall": "Fabric",
}

# ---- walls -----------------------------------------------------------------------------------
# Each wall runs along `axis` ("X" or "Z") on the line `line` (2 thick, centered on it) over
# `span`. f1 / f2 are its openings on each floor, with absolute heights: (s0, s1, top) a doorway,
# (s0, s1, top, bottom) a window. `floors` "12" builds both floors and the slab band between them.

OUTER_WALLS = [
    {"axis": "Z", "fixed": (-IN_X - WALL, -IN_X), "span": (-IN_Z - WALL, IN_Z + WALL),
     "f1": [(a, b, 12, 4) for a, b in ((-28, -20), (-12, -4), (4, 12), (20, 28), (44, 52),
                                       (58, 66))],
     "f2": [(a, b, 30, 22) for a, b in ((-28, -20), (-12, -4), (4, 12), (20, 28), (44, 52),
                                        (58, 66))]},
    {"axis": "Z", "fixed": (IN_X, IN_X + WALL), "span": (-IN_Z - WALL, IN_Z + WALL),
     "f1": [(-26, -18, 13, 3), (-6, 6, 13, 3), (18, 26, 13, 3)],
     "f2": [(-26, -18, 31, 21), (18, 26, 31, 21)]},
    {"axis": "X", "fixed": (-IN_Z - WALL, -IN_Z), "span": (-IN_X, IN_X),
     "f2": [(-30, -18, 31, 23), (-6, 6, 31, 23), (18, 30, 31, 23)]},
    {"axis": "X", "fixed": (IN_Z, IN_Z + WALL), "span": (-IN_X, IN_X),
     "f2": [(-30, -18, 31, 25), (-6, 6, 31, 25), (18, 30, 31, 25), (-58, -46, 30, 22)]},
]

INSIDE_WALLS = {
    # Along X at Z -32: the gym and the stairwell / locker room against the halls,
    # Room 101 / science lab and the library.
    "north": {"axis": "X", "line": -32, "span": (-IN_X, IN_X),
              "f1": [(-60, -52, DOOR), (-32, -24, DOOR), (24, 32, DOOR), (40, 46, DOOR)],
              "f2": [(-60, -52, DOOR2), (-16, 16, DOOR2), (56, 62, DOOR2)]},
    # Along X at Z 32: the halls and the library against the south wing.
    "south": {"axis": "X", "line": 32, "span": (-IN_X, IN_X),
              "f1": [(-60, -52, DOOR), (-30, -22, DOOR), (-10, 10, 12), (22, 30, DOOR),
                     (40, 46, DOOR)],
              "f2": [(-60, -52, DOOR2), (-16, 16, DOOR2), (56, 62, DOOR2)]},
    # Along Z at X -32: the west wing against the halls.
    "west": {"axis": "Z", "line": -32, "span": (-32, 32),
             "f1": [(-16, -8, DOOR), (8, 16, DOOR)],
             "f2": [(-16, -8, DOOR2), (8, 16, DOOR2), (-28, -20, 30, 22), (20, 28, 30, 22)]},
    # Along Z at X 32: the library against the halls (the bridge comes in at 18).
    "east": {"axis": "Z", "line": 32, "span": (-32, 32),
             "f1": [(-10, -4, DOOR), (4, 10, DOOR), (-28, -20, 12, 4), (20, 28, 12, 4)],
             "f2": [(-4, 4, DOOR2), (-28, -10, 31, 21), (10, 28, 31, 21)]},
    "classrooms": {"axis": "X", "line": 0, "span": (-IN_X, -32),
                   "f1": [(-56, -50, DOOR)], "f2": [(-56, -50, DOOR2)]},
    "gym_west": {"axis": "Z", "line": -40, "span": (-IN_Z, -32),
                 "f1": [(-38, -33, DOOR)], "f2": [(-38, -33, DOOR2)]},
    "gym_east": {"axis": "Z", "line": 40, "span": (-IN_Z, -32),
                 "f1": [(-60, -52, DOOR)], "f2": [(-60, -52, DOOR2)]},
    "band": {"axis": "Z", "line": -40, "span": (32, IN_Z),
             "f1": [(40, 48, DOOR), (62, 68, DOOR)], "f2": [(34, 42, DOOR2), (56, 64, DOOR2)]},
    "stairs_se": {"axis": "Z", "line": 40, "span": (32, IN_Z),
                  "f1": [(33, 39, DOOR), (63, 69, 7)], "f2": [(33, 39, DOOR2)]},
    # The serving line between the cafeteria and the kitchen (ground floor only).
    "serving": {"axis": "X", "line": 56, "span": (-40, 40), "floors": "1",
                "f1": [(-36, -30, DOOR), (-22, -4, 12), (4, 22, 12), (30, 36, DOOR)],
                "gated": [(-22, -4), (4, 22)]},  # the shutter and the counter, on purpose
    # The upper hall against the music room (upper floor only).
    "music": {"axis": "X", "line": 44, "span": (-40, 40), "floors": "2",
              "f2": [(-30, -22, DOOR2), (-8, 0, DOOR2)]},
}
ARCHES = [(-14, -6, 12), (6, 14, 12)]  # two a side in the atrium's ground-floor walls
for _axis, _line in (("X", -20), ("X", 20), ("Z", -20), ("Z", 20)):
    INSIDE_WALLS[f"atrium{_axis}{_line}"] = {"axis": _axis, "line": _line, "span": (-20, 20),
                                             "floors": "1", "f1": ARCHES, "color": "pillar"}

DOORS = []  # (axis, line, s0, s1, floor y) of every doorway, for the checks


def walls(m, spec, group="Walls"):
    axis, floors = spec["axis"], spec.get("floors", "12")
    fixed = spec.get("fixed") or (spec["line"] - 1, spec["line"] + 1)
    color = spec.get("color", "wall")
    bottom = F1 if "line" in spec else -2  # outer walls reach down past the ground slab
    if "1" in floors:
        m.wall(group, axis, fixed, spec["span"], bottom, F1_TOP, color, spec.get("f1", ()))
    if floors == "12":
        m.wall(group, axis, fixed, spec["span"], F1_TOP, F2, color)
    if "2" in floors:
        m.wall(group, axis, fixed, spec["span"], F2, F2_TOP, color, spec.get("f2", ()))
    for key, floor_y in (("f1", F1), ("f2", F2)):
        for opening in spec.get(key, ()):
            if len(opening) == 3 and tuple(opening[:2]) not in spec.get("gated", ()):
                DOORS.append((axis, (fixed[0] + fixed[1]) / 2, opening[0], opening[1], floor_y))


# ---- helpers ---------------------------------------------------------------------------------

def ramp_z(m, g, name, x0, x1, za, ya, zb, yb, color="stair", thick=1.0, **props):
    """A slab whose top runs straight from (za, ya) to (zb, yb) along Z (stairs, ramps)."""
    dz, dy = zb - za, yb - ya
    ang = math.degrees(math.atan(dy / -dz))
    a = math.radians(ang)
    normal = (0, math.cos(a), math.sin(a))
    mid = ((x0 + x1) / 2, (ya + yb) / 2, (za + zb) / 2)
    pos = tuple(mid[i] - 0.5 * thick * normal[i] for i in range(3))
    return m.part(g, name, (x1 - x0, thick, math.hypot(dz, dy)), pos, color, rot_x(ang), **props)


def ramp_x(m, g, name, z0, z1, xa, ya, xb, yb, color="stair", thick=1.0, **props):
    """A slab whose top runs straight from (xa, ya) to (xb, yb) along X."""
    dx, dy = xb - xa, yb - ya
    ang = math.degrees(math.atan(dy / dx))
    a = math.radians(ang)
    normal = (-math.sin(a), math.cos(a), 0)
    mid = ((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2)
    pos = tuple(mid[i] - 0.5 * thick * normal[i] for i in range(3))
    return m.part(g, name, (math.hypot(dx, dy), thick, z1 - z0), pos, color, rot_z(ang), **props)


def rail(m, g, x0, x1, z0, z1, y=F2, glass=False):
    """A railing 3.2 high: solid, low enough to vault over and drop."""
    if glass:
        m.block(g, "Railing", x0, x1, y, y + 3.2, z0, z1, "glass", Material="Glass",
                Transparency=0.55, CastShadow=False)
        m.block(g, "RailCap", x0, x1, y + 3.2, y + 3.4, z0, z1, "rail", **NO_HIT)
    else:
        m.block(g, "Railing", x0, x1, y, y + 3.2, z0, z1, "rail")


def slip_puddle(m, g, x, z, y, size=9, slip=1.6):
    """A roundish puddle (three overlapping discs): run or slide in and you slip (Slip)."""
    wet = {"Material": "Glass", "Transparency": 0.35, "Reflectance": 0.15, "CanCollide": False,
           "attributes": {"Slip": slip}}
    for dx, dz, k in ((0, 0, 1), (size * 0.35, size * 0.17, 0.6), (-size * 0.37, -size * 0.13, 0.5)):
        m.cylinder(g, "Puddle", 0.12, size * k, (x + dx, y + 0.06, z + dz), "puddle", **wet)


def desk(m, g, x, z, y=F1):
    m.block(g, "Desk", x - 1.5, x + 1.5, y, y + 2.6, z - 1.1, z + 1.1, "desk")


SHELF_HEIGHT = 9
SHELF_DEPTH = 2.5


def bookshelf_row(m, g, x0, x1, z, k):
    """Standing bookshelves from x0 to x1: the solid case (a wall-run face, a high route on top)
    with coloured book spines on both faces (decoration)."""
    books = ("books_a", "books_b", "books_c")
    m.block(g, "Bookshelf", x0, x1, 0, SHELF_HEIGHT, z - SHELF_DEPTH / 2, z + SHELF_DEPTH / 2,
            "shelf")
    for side in (-1, 1):
        face = z + side * (SHELF_DEPTH / 2 + 0.05)
        for level, y in enumerate((1.2, 3.6, 6.0)):
            x = x0 + 0.6
            i = level + k
            while x < x1 - 1.2:
                width = min(1.5 + (i * 7 % 5) * 0.6, x1 - 0.6 - x)
                height = 1.4 + (i * 3 % 4) * 0.15
                m.block(g, "Books", x, x + width, y, y + height, face - 0.05, face + 0.05,
                        books[i % 3], **NO_HIT)
                x += width + 0.3
                i += 1


# Wall faces for decoration: (axis the face is on, its coordinate, which way it faces).
FACE_NAMES = {("x", 1): "Right", ("x", -1): "Left", ("z", 1): "Back", ("z", -1): "Front"}
HALL_W = ("x", -31, 1)  # west wing wall, hall side (both floors)
HALL_E = ("x", 31, -1)  # library wall, hall side
HALL_N = ("z", -31, 1)  # gym wall, hall side (also Room 101's north wall further west)
HALL_S = ("z", 31, -1)  # cafeteria wall, hall side (also Room 102's south wall further west)
ATRIUM_W = ("x", -21, -1)  # atrium walls, hall side
ATRIUM_E = ("x", 21, 1)
ATRIUM_S_IN = ("z", 19, -1)  # atrium south wall, atrium side
GYM_N = ("z", -IN_Z, 1)
GYM_E_IN = ("x", 39, -1)
CAFE_N_IN = ("z", 33, 1)
KITCHEN_SERVE = ("z", 57, 1)
UPPER_HALL_S = ("z", 43, -1)
UPPER_HALL_ART = ("x", -39, 1)
TRACK_E = ("x", 39, -1)
ART_W = ("x", -IN_X, 1)
LIB_E = ("x", IN_X, -1)
MEZZ_EDGE = ("x", 54, -1)


def on_wall(m, g, name, face, along, y, w, h, color, depth=0.12, out=0.0, text=None,
            text_color=(255, 255, 255), font="FredokaOne", glow=False, **props):
    """A flat box on a wall face (no collision), centered `along` the wall at height y, with
    optional text on its front."""
    axis, coord, facing = face
    c = coord + facing * (out + depth / 2 + 0.02)
    children = [m.surface_text(FACE_NAMES[(axis, facing)], text, text_color, font=font,
                               glow=glow)] if text else None
    extra = dict(NO_HIT)
    extra.update(props)
    if axis == "x":
        m.part(g, name, (depth, h, w), (c, y, along), color, children=children, **extra)
    else:
        m.part(g, name, (w, h, depth), (along, y, c), color, children=children, **extra)


def lockers(m, g, face, s0, s1, openings=(), y=F1):
    """Locker doors flat on a wall (decoration: the wall stays a clean wall-run face), skipping
    the wall's doorways and windows."""
    skip = [(o[0] - 0.5, o[1] + 0.5) for o in openings]
    s, i = s0, 0
    while s + 3 <= s1:
        if not any(a < s + 3 and s < b for a, b in skip):
            on_wall(m, g, "Locker", face, s + 1.5, y + 4.5, 2.8, 9,
                    "locker_a" if i % 2 == 0 else "locker_b", depth=0.3)
            on_wall(m, g, "LockerVent", face, s + 1.5, y + 7.8, 1.6, 0.5, (30, 35, 45),
                    depth=0.05, out=0.3)
            on_wall(m, g, "LockerHandle", face, s + 2.3, y + 4.6, 0.25, 1, (200, 200, 205),
                    depth=0.12, out=0.3, Material="Metal")
            i += 1
        s += 3


def poster(m, g, face, along, y, w, h, background, text, text_color=(255, 255, 255)):
    on_wall(m, g, "Poster", face, along, y, w, h, background, text=text, text_color=text_color)


def plate(m, g, face, along, y, text, w=None):
    """A room sign over a door."""
    on_wall(m, g, "RoomSign", face, along, y, w or max(2.4, 0.75 * len(text)), 1.4, "plate",
            text=text, text_color=(240, 220, 120))


def clock(m, g, face, along, y):
    axis, coord, facing = face
    rows = IDENTITY if axis == "x" else rot_y(90)
    c = coord + facing * 0.15
    pos = (c, y, along) if axis == "x" else (along, y, c)
    m.part(g, "Clock", (0.25, 2.6, 2.6), pos, (245, 245, 245), rows, Shape="Cylinder", **NO_HIT)
    on_wall(m, g, "HourHand", face, along + 0.25, y + 0.1, 0.7, 0.15, (20, 20, 20), depth=0.05,
            out=0.3)
    on_wall(m, g, "MinuteHand", face, along - 0.05, y + 0.5, 0.12, 1.0, (20, 20, 20), depth=0.05,
            out=0.32)


def bulletin_board(m, g, face, along, y, w, h):
    on_wall(m, g, "BulletinFrame", face, along, y, w + 0.6, h + 0.6, "door", depth=0.1)
    on_wall(m, g, "BulletinBoard", face, along, y, w, h, (185, 140, 90), out=0.1,
            Material="Fabric")
    notes = ((255, 250, 210), (200, 230, 255), (255, 210, 220), (210, 255, 210), (255, 255, 255))
    for i, (fx, fy, nw, nh) in enumerate(((-0.32, 0.2, 1.4, 1.8), (-0.05, -0.15, 1.6, 1.2),
                                          (0.22, 0.22, 1.2, 1.5), (0.33, -0.2, 1.3, 1.4),
                                          (-0.3, -0.25, 1.1, 1.0))):
        on_wall(m, g, "Note", face, along + fx * w, y + fy * h, nw, nh, notes[i], depth=0.03,
                out=0.23)


def exit_sign(m, g, x, y, z, along_x=True):
    """A glowing EXIT sign hanging from the ceiling at y (its top), readable from both sides."""
    rows = IDENTITY if along_x else rot_y(90)
    m.part(g, "ExitSign", (3, 1.1, 0.3), (x, y - 1.6, z), (30, 30, 30), rows,
           children=[m.surface_text("Front", "EXIT", (255, 60, 60), font="Arcade", glow=True),
                     m.surface_text("Back", "EXIT", (255, 60, 60), font="Arcade", glow=True)],
           **NO_HIT)


def light(m, x, y, z, along_x=True, flicker=False, reach=24, brightness=0.6, warm=False):
    color = (255, 205, 150) if warm else COLORS["light"]
    m.light("Lights", (x, y - 0.1, z), size=(8, 0.2, 1) if along_x else (1, 0.2, 8), color=color,
            brightness=brightness, reach=reach, flicker=flicker)


# ---- the building ----------------------------------------------------------------------------

def shell(m):
    g = "Building"
    m.block(g, "Ground", -IN_X - WALL, IN_X + WALL, -2, 0, -IN_Z - WALL, IN_Z + WALL, "floor")
    m.slab(g, "UpperFloor", (-IN_X, IN_X, -IN_Z, IN_Z), F1_TOP, F2,
           [GYM, LIBRARY, VOID, NW_STAIR, SE_STAIR, LAB_HOLE, COLLAPSE], "floor")
    m.slab("Roof", "Roof", (-IN_X - WALL, IN_X + WALL, -IN_Z - WALL, IN_Z + WALL), F2_TOP, ROOF,
           [VOID], "ceiling")
    m.block("Roof", "Skylight", -12, 12, ROOF - 1, ROOF - 0.6, -12, 12, "glass", Material="Glass",
            Transparency=0.5, CastShadow=False)
    for spec in OUTER_WALLS:
        walls(m, spec)
    for spec in INSIDE_WALLS.values():
        walls(m, spec)

    # Floor finishes, so each room reads at a glance.
    f = "Finishes"
    for rect, y, color, holes in (
        (GYM, F1, "gym_floor", ()), ((40, 64, -72, -32), F1, "lab_floor", ()),
        ((-64, -32, -32, 32), F1, "room_floor", ()), ((-20, 20, -20, 20), F1, "terrazzo", ()),
        (LIBRARY, F1, "carpet_red", ()), ((-64, -40, 32, 72), F1, "carpet_blue", ()),
        ((-40, 40, 32, 56), F1, "cafe_floor", ()), ((-40, 40, 56, 72), F1, "kitchen_floor", ()),
        ((40, 64, -72, -32), F2, "carpet_blue", ()), ((-64, -32, -32, 0), F2, "lab_floor",
                                                      (LAB_HOLE,)),
        ((-64, -32, 0, 32), F2, "comp_floor", ()), ((-64, -40, 32, 72), F2, "art_floor", ()),
        ((-40, 40, 44, 72), F2, "room_floor", ()), ((54, 64, -32, 32), F2, "carpet_red", ()),
    ):
        m.slab(f, "FloorFinish", rect, y, y + 0.06, list(holes), color, **NO_HIT)


def atrium(m):
    """The middle of the school: double height under a skylight, an open stair up the middle to
    the balcony, corner pillars to wall-climb, a vault-over glass railing all round."""
    g = "Atrium"
    # The grand stair: open underneath, so you can run under its high end and duck under the
    # middle. Step edges painted on (decoration).
    ramp_z(m, g, "GrandStair", -5, 5, 16, 0, -12, F2, thick=1.2)
    ang = math.degrees(math.atan(F2 / 28))
    a = math.radians(ang)
    for k in range(1, 12):
        t = k / 12
        z, y = 16 - 28 * t, F2 * t
        m.part(g, "StepEdge", (10, 0.06, 0.5), (0, y + 0.04 * math.cos(a), z + 0.04 * math.sin(a)),
               "rail", rot_x(ang), **NO_HIT)
    for x in (-5.3, 5.3):
        ramp_z(m, g, "StairRail", x - 0.15, x + 0.15, 16, 3, -12, F2 + 3, color="rail", thick=0.3,
               **NO_HIT)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 12, sz * 12
            m.block(g, "Pillar", x - 1.5, x + 1.5, F1, F2, z - 1.5, z + 1.5, "pillar")
    # Balcony railing round the void, open where the stair arrives.
    for x0, x1, z0, z1 in ((-10.5, -5, -12.3, -11.7), (5, 10.5, -12.3, -11.7),
                           (-10.5, 10.5, 11.7, 12.3), (-12.3, -11.7, -10.5, 10.5),
                           (11.7, 12.3, -10.5, 10.5)):
        rail(m, g, x0, x1, z0, z1, glass=True)
    # Planters and benches on the atrium floor (vault them).
    for x in (-15, 15):
        m.block(g, "Planter", x - 2.5, x + 2.5, F1, 3, 1.5, 6.5, "planter")
        m.block(g, "Plant", x - 2, x + 2, 3, 3.6, 2, 6, "plant", **NO_HIT)
        m.block(g, "Bench", x - 1, x + 1, F1, 1.8, -9, -3, "desk")
    # The TIGERS banner over the void, the trophy case behind the stair.
    m.block(g, "Banner", -6, 6, 24, 30, -0.05, 0.05, (130, 30, 40), **NO_HIT,
            children=[m.surface_text("Front", "TIGERS", (250, 200, 60)),
                      m.surface_text("Back", "TIGERS", (250, 200, 60))])
    for x in (-5.5, 5.5):
        m.block(g, "BannerRod", x - 0.05, x + 0.05, 30, F2_TOP, -0.05, 0.05, "chain", **NO_HIT)
    on_wall(m, g, "TrophyCase", ATRIUM_S_IN, 0, 3.5, 12, 7, "door", depth=0.8)
    on_wall(m, g, "TrophyGlass", ATRIUM_S_IN, 0, 3.8, 11.4, 6, "glass", depth=0.1, out=0.8,
            Material="Glass", Transparency=0.6)
    for i, x in enumerate((-4, -1.5, 1.5, 4)):
        height = 1.2 + (i % 2) * 0.6
        m.cylinder(g, "Trophy", height, 0.7, (x, 1.5 + height / 2, 18.4), (240, 190, 50),
                   Material="Metal", Reflectance=0.3, **NO_HIT)


def gym(m):
    """North: double-height gym. Bleachers climb to the upper floor, a running track rings it at
    18, a springboard throws you onto the track, mats and a ball cart to vault."""
    g = "Gym"
    # Bleachers: six 3-high rows (vault from row to row), the aisle ramp up the middle.
    for i in range(6):
        top = 3 * (i + 1)
        front = -33 - 2.5 * (6 - i)
        for x0, x1 in ((-24, -3), (3, 24)):
            m.block(g, "Bleacher", x0, x1, F1, top, front, -33, "bleacher")
    ramp_z(m, g, "BleacherAisle", -3, 3, -52, 0, -33, F2)
    # The running track at 18 round the north, west and east walls, joined to the bleacher top.
    for x0, x1, z0, z1 in ((-40, 40, -72, -66), (-40, -34, -66, -33), (34, 40, -66, -33),
                           (-34, -24, -35.5, -33), (24, 34, -35.5, -33)):
        m.block(g, "Track", x0, x1, F1_TOP, F2, z0, z1, "track")
    for x0, x1, z0, z1 in ((-34, 34, -66.3, -65.7), (-34.3, -33.7, -65.7, -35.5),
                           (33.7, 34.3, -65.7, -35.5)):
        rail(m, g, x0, x1, z0, z1)
    # The springboard.
    sx, sz = SPRINGBOARD
    m.part(g, "Springboard", (6, 1, 6), (sx, 0.5, sz), "pad", Material="Neon",
           attributes={"LaunchVelocity": {"Vector3": list(LAUNCH)}})
    for x0, x1, z0, z1 in ((sx - 4, sx + 4, sz - 4, sz - 3.4), (sx - 4, sx + 4, sz + 3.4, sz + 4),
                           (sx - 4, sx - 3.4, sz - 3.4, sz + 3.4),
                           (sx + 3.4, sx + 4, sz - 3.4, sz + 3.4)):
        m.block(g, "HazardStripe", x0, x1, 0.06, 0.12, z0, z1, "hazard", **NO_HIT)
    # Things to vault, hoops, court lines, wall pads.
    m.block(g, "GymMats", -16, -10, F1, 3, -64, -60, "mat")
    m.block(g, "BallCart", 10, 14, F1, 3.2, -64, -61, "grate")
    for x, z in ((11, -62.5), (12.5, -61.8), (13, -63.2)):
        m.part(g, "Ball", (1.4, 1.4, 1.4), (x, 3.9, z), (230, 110, 40), Shape="Ball", **NO_HIT)
    for side in (-1, 1):
        x = side * 33.4
        m.block(g, "Backboard", x - 0.15, x + 0.15, 10, 13.5, -55, -49, (245, 245, 245),
                **NO_HIT)
        m.cylinder(g, "Hoop", 0.2, 1.8, (x - side * 1.1, 10.2, -52), (230, 90, 30), rot_z(90),
                   **NO_HIT)
    for x0, x1, z0, z1 in ((-36, 36, -64.2, -63.9), (-36, 36, -49.9, -49.6),
                           (-0.15, 0.15, -64, -50)):
        m.block(g, "CourtLine", x0, x1, 0.06, 0.1, z0, z1, "court_line", **NO_HIT)
    door_w = INSIDE_WALLS["gym_west"]["f1"]
    door_e = INSIDE_WALLS["gym_east"]["f1"]
    for z in range(-70, -36, 4):
        if not any(a - 0.5 < z + 3.6 and z < b + 0.5 for a, b, _ in door_w):
            m.block(g, "WallPad", -39, -38.7, 1, 7, z, z + 3.6, "pad_wall", **NO_HIT)
        if not any(a - 0.5 < z + 3.6 and z < b + 0.5 for a, b, _ in door_e):
            m.block(g, "WallPad", 38.7, 39, 1, 7, z, z + 3.6, "pad_wall", **NO_HIT)


def stairwells(m):
    """Switchback stairs in the north-west and south-east corners: a flight up to a landing at 9,
    then back the other way up to the upper floor."""
    g = "Stairs"
    ramp_z(m, g, "Stairs", -64, -52, -40, 0, -60, 9)
    m.block(g, "Landing", -64, -40, 8, 9, -72, -60, "stair")
    ramp_z(m, g, "Stairs", -52, -40, -60, 9, -40, F2)
    ramp_z(m, g, "Stairs", 52, 64, 40, 0, 60, 9)
    m.block(g, "Landing", 40, 64, 8, 9, 60, 72, "stair")
    ramp_z(m, g, "Stairs", 40, 52, 60, 9, 40, F2)


def west_wing(m):
    """Rooms 101 and 102 below, the science lab and the computer lab above. The lab's floor has
    fallen into 101: drop through, or climb the rubble (4) and the fallen cabinet (10) and pull
    up onto the lab floor."""
    g = "WestWing"
    for x, z in ((-60, -22), (-60, -14), (-60, -6), (-38, -26), (-38, -3), (-46, -27)):
        desk(m, g, x, z)
    for x in (-56, -48, -40):
        for z in (8, 16, 24):
            desk(m, g, x, z)
    on_wall(m, g, "Chalkboard", HALL_N, -43, 8, 14, 6, "board", depth=0.2,
            text="TODAY: TAG<br/>Rule #1: don't get caught", text_color=(240, 240, 230),
            font="PermanentMarker")
    on_wall(m, g, "Chalkboard", HALL_S, -43, 8, 14, 6, "board", depth=0.2,
            text="POP QUIZ:<br/>Who's It?", text_color=(240, 240, 230), font="PermanentMarker")
    # The fall: a lab cabinet came down under the hole's south edge, with rubble next to it.
    m.block(g, "FallenCabinet", -51, -47, F1, 10, -14.5, -12, "lab_bench")
    m.block(g, "Rubble", -52, -46.5, F1, 4, -11, -6.5, "rubble")
    m.block(g, "Rubble", -45, -42, F1, 2.2, -16, -13, "rubble")
    m.part(g, "FloorChunk", (7, 1, 6), (-48, 1.2, -17.5), "debris", rot_z(14), **NO_HIT)
    # Upper floor: lab benches round the hole, the fume hood, computer desks.
    for z in (-24, -7):
        for x0, x1 in ((-61, -51), (-45, -37)):
            m.block(g, "LabBench", x0, x1, F2, F2 + 3.4, z - 1.5, z + 1.5, "lab_bench")
    hx0, hx1, hz0, hz1 = LAB_HOLE
    for x0, x1, z0, z1 in ((hx0 - 1, hx1 + 1, hz0 - 1, hz0), (hx0 - 1, hx1 + 1, hz1, hz1 + 1),
                           (hx0 - 1, hx0, hz0, hz1), (hx1, hx1 + 1, hz0, hz1)):
        m.block(g, "HazardEdge", x0, x1, F2, F2 + 0.08, z0, z1, "hazard", **NO_HIT)
    m.block(g, "FumeHood", -50, -42, F2, F2 + 9, -31, -28, "counter")
    for z in (8, 16, 24):
        for x0, x1 in ((-61, -51), (-45, -38)):
            m.block(g, "ComputerDesk", x0, x1, F2, F2 + 3, z - 1.2, z + 1.2, "desk")
            for x in range(x0 + 1, x1 - 1, 3):
                m.block(g, "Monitor", x, x + 1.6, F2 + 3, F2 + 4.2, z - 0.2, z + 0.1,
                        (30, 30, 36), **NO_HIT)
    m.block(g, "ServerRack", -63.5, -60.5, F2, F2 + 10, 28, 31, (30, 34, 40))
    for i, (x, z) in enumerate(((-56, -18), (-44, -24), (-36, -10), (-52, 12), (-44, 28))):
        m.part(g, "Paper", (1.3, 0.04, 1.7), (x, 0.13, z), (250, 250, 245),
               rot_y(i * 37 % 90 - 45), **NO_HIT)


def east_wing(m):
    """The library (double height): shelf rows to wall-run and run along the tops, a mezzanine
    at 18 on the east wall, a bridge across from the balcony. North of it the locker room, with
    the teachers' lounge above."""
    g = "Library"
    for k, z in enumerate((-24, -14, 14, 24)):
        bookshelf_row(m, g, 34, 40, z, k)
        bookshelf_row(m, g, 46, 53, z, k + 1)  # ends 1 short of the mezzanine: climb from here
    for x0, x1 in ((34, 39), (47, 52)):
        m.block(g, "ReadingTable", x0, x1, F1, 2.8, -1.5, 1.5, "desk")
    m.block(g, "FrontDesk", 34, 38, F1, 3.5, -31, -27, "door")
    m.block(g, "Mezzanine", 54, IN_X, F1_TOP, F2, -32, 32, "floor")
    m.block(g, "Bridge", 32, 54, F1_TOP, F2, -4, 4, "floor")
    rail(m, g, 33, 54, -4.3, -3.7)
    rail(m, g, 33, 54, 3.7, 4.3)
    for z in (-24, -10, 10, 24):
        m.block(g, "MezzColumn", 54, 55.5, F1, F1_TOP, z - 0.75, z + 0.75, "pillar")
    for z0, z1 in ((-32, -4), (4, 32)):
        m.block(g, "HazardEdge", 54, 54.6, F2, F2 + 0.08, z0, z1, "hazard", **NO_HIT)
    for y in (F1, F2):  # bookshelves on the east wall, clear of the windows (decoration)
        for z0, z1 in ((-16, -8), (8, 16)):
            m.block(g, "WallShelf", 63, 63.9, y, y + 8, z0, z1, "shelf", **NO_HIT)
    m.part(g, "GlobeStand", (0.8, 0.8, 0.8), (37, 9.4, -24), (60, 50, 40), **NO_HIT)
    m.part(g, "Globe", (2, 2, 2), (37, 10.8, -24), (70, 130, 200), Shape="Ball", **NO_HIT)

    g = "Lockers"
    for x0 in (47, 55):
        m.block(g, "LockerIsland", x0, x0 + 2.5, F1, 9, -56, -38, "locker_a")
    m.block(g, "Bench", 51, 53, F1, 1.6, -54, -40, "desk")
    for x in (50, 56, 62):
        m.block(g, "ShowerWall", x - 0.2, x + 0.2, F1, 7, -72, -66, "lab_floor")
    slip_puddle(m, g, 54, -63, F1, size=8)
    m.block(g, "Couch", 44, 52, F2, F2 + 3, -50, -47, "couch")
    m.block(g, "CoffeeTable", 45, 51, F2, F2 + 2, -44, -42, "desk")
    m.block(g, "Vending", 60.5, 63.8, F2, F2 + 8, -44, -40, "vending")
    m.block(g, "Kitchenette", 42, 60, F2, F2 + 3.5, -71.5, -69, "counter")


def south_wing(m):
    """Cafeteria, kitchen and band room below; art room, upper hall and music room above. The
    upper hall's floor has fallen into the cafeteria as a ramp you can run up or down."""
    g = "Cafeteria"
    for x in (-32, -22, -12):
        m.block(g, "LunchTable", x - 2, x + 2, F1, 2.6, 39, 51, "table")
    for x in (14, 26):
        m.block(g, "LunchTable", x - 2, x + 2, F1, 2.6, 46, 52, "table")
    # The serving line: a half-down shutter (slide under it) and an open counter (vault it).
    m.block(g, "Shutter", -22, -4, 4.2, 12, 55.4, 56.6, "grate")
    m.block(g, "StandBlocker", -22, -4, F1, 4.2, 55.4, 56.6, (255, 255, 255), Transparency=1,
            CastShadow=False, attributes={"SlideBlocker": True})
    m.block(g, "ServingCounter", 4, 22, F1, 3, 55, 57, "counter")
    m.block(g, "Vending", -39.8, -37, F1, 8, 50, 54, "vending")
    # The collapse: hinged at the hole's west edge, resting on the floor short of the east
    # end (clear of the stairwell door).
    cx0, cx1, cz0, cz1 = COLLAPSE
    ramp_x(m, g, "CollapsedFloor", cz0 + 0.5, cz1 - 0.5, cx0, F2, cx1 - 2, 0, color="debris",
           thick=1.5)
    for x, z, size in ((38, 45.5, (2.5, 2, 2.5)), (31, 45.5, (3, 2.4, 2)), (20, 45, (2, 1.6, 2))):
        m.block(g, "Rubble", x - size[0] / 2, x + size[0] / 2, F1, size[1], z - size[2] / 2,
                z + size[2] / 2, "rubble")
    m.block(g, "CollapseEdge", cx0, cx1, F2, F2 + 0.08, cz0 - 0.6, cz0, "hazard", **NO_HIT)

    g = "Kitchen"
    for x0, x1 in ((-30, -14), (-6, 10)):
        m.block(g, "KitchenIsland", x0, x1, F1, 3.5, 62, 65, "counter")
    m.block(g, "WalkInFridge", 22, 36, F1, 10, 60, 71, "fridge")
    m.block(g, "Stove", -38, -22, F1, 3.5, 69.5, IN_Z, (70, 72, 78))
    slip_puddle(m, g, 0, 68.5, F1, size=5, slip=1.2)

    g = "BandArt"
    for x0, x1, h in ((-64, -58, 4.5), (-58, -54, 3), (-54, -50, 1.5)):
        m.block(g, "Riser", x0, x1, F1, h, 40, 68, "carpet_blue")
    m.block(g, "Piano", -48, -43, F1, 3.5, 50, 56, "piano")
    m.cylinder(g, "BassDrum", 1.5, 3, (-61, 6, 54), (220, 220, 220), rot_y(90), **NO_HIT)
    for z in (40, 56):
        m.block(g, "PaintTable", -60, -46, F2, F2 + 3, z, z + 5, "desk")
    m.block(g, "Kiln", -62, -58, F2, F2 + 6, 66, 70, "concrete_dark")
    for i, (x, z) in enumerate(((-50, 50), (-56, 63), (-47, 36))):
        m.cylinder(g, "PaintSplat", 0.05, 3 + i, (x, F2 + 0.08, z),
                   ((220, 60, 60), (60, 120, 220), (240, 200, 50))[i], **NO_HIT)
    for i in range(4):  # the music room's tiers, stepping up to the south wall
        m.block(g, "MusicTier", -34, 34, F2, F2 + 1.5 * (i + 1), 58 + 3.5 * i, IN_Z, "room_floor")
    m.block(g, "GrandPiano", 10, 16, F2, F2 + 3.5, 49, 54, "piano")


def upper_ring(m):
    """The balcony ring's extras: a leak puddle with its bucket, benches."""
    g = "UpperRing"
    slip_puddle(m, g, 24, -22, F2, size=7, slip=1.4)
    m.block(g, "Bucket", 29, 31, F2, F2 + 2.4, -26, -24, "hazard")
    for x in (-24, 24):
        m.block(g, "Bench", x - 3, x + 3, F2, F2 + 1.8, 22, 24, "desk")


def lights(m):
    # The hall ring, both floors.
    for y in (F1_TOP, F2_TOP):
        for x in (-26, 26):
            for z in (-24, -8, 8, 24):
                light(m, x, y, z, along_x=False)
        for z in (-26, 26):
            for x in (-8, 8):
                light(m, x, y, z)
    for x, z in ((-16, 0), (16, 0), (0, -16), (0, 16)):  # under the balcony
        light(m, x, F1_TOP, z, along_x=x == 0)
    for x in (-24, 0, 24):  # gym
        for z in (-60, -44):
            light(m, x, F2_TOP, z, brightness=0.7, reach=34)
    for x, z in ((-56, -24), (-40, -24), (-58, -8), (-40, -6), (-48, 8), (-48, 24)):  # 101, 102
        light(m, x, F1_TOP, z)
    for x, z, flick in ((-58, -16, True), (-38, -18, False), (-48, 8, False), (-48, 24, False)):
        light(m, x, F2_TOP, z, flicker=flick)  # labs
    for x in (-30, -10, 10, 30):  # cafeteria
        light(m, x, F1_TOP, 44)
    for x in (-24, 0, 24):  # kitchen
        light(m, x, F1_TOP, 64)
    for z in (44, 60):  # band, art
        light(m, -52, F1_TOP, z)
        light(m, -52, F2_TOP, z)
    for x in (-24, 0, 24):  # music
        light(m, x, F2_TOP, 58)
    for x, flick in ((-28, False), (-8, False), (20, True)):  # upper hall, flickering over the hole
        light(m, x, F2_TOP, 38, flicker=flick)
    for z in (-18, 0, 18):  # library, under and over the mezzanine
        light(m, 42, F2_TOP, z, warm=True, reach=30)
    for z in (-16, 16):
        light(m, 59, F1_TOP, z, along_x=False, warm=True)
        light(m, 59, F2_TOP, z, along_x=False, warm=True)
    for z in (-62, -46):  # locker room, lounge
        light(m, 52, F1_TOP, z)
        light(m, 52, F2_TOP, z, warm=True)
    for x, z in ((-52, -36), (-52, -56), (52, 36), (52, 56)):  # stairwells
        light(m, x, F1_TOP if abs(z) < 40 else F2_TOP, z)


def details(m):
    """Decoration that makes the school feel lived in (no collision, no effect on the routes)."""
    g = "Details"
    hall = INSIDE_WALLS
    # Lockers along the halls (both floors) and the upper hall, skipping doors and windows.
    lockers(m, g, HALL_W, -30, 30, hall["west"]["f1"])
    lockers(m, g, HALL_W, -30, 30, hall["west"]["f2"], y=F2)
    lockers(m, g, HALL_E, -30, 30, hall["east"]["f1"])
    lockers(m, g, ATRIUM_W, -19, 19, ARCHES)
    lockers(m, g, ATRIUM_E, -19, 19, ARCHES)
    lockers(m, g, UPPER_HALL_S, -38, 38, hall["music"]["f2"], y=F2)

    # Posters (school notices) and bulletin boards.
    for args in (
        (HALL_W, -24, 12.5, 7, 3.5, (220, 60, 60), "NO RUNNING<br/>IN THE HALLS"),
        (HALL_W, 24, 12.5, 5, 3.5, (230, 90, 150), "SPIRIT<br/>WEEK"),
        (HALL_E, -15, 12.5, 5, 3.5, (90, 180, 110), "READ MORE<br/>BOOKS"),
        (HALL_E, 15, 12.5, 5, 3.5, (200, 70, 70), "BOOK<br/>FAIR"),
        (HALL_N, 0, 7.5, 10, 5, (250, 190, 40), "GO TIGERS!", (60, 30, 10)),
        (HALL_S, -16, 7, 5, 6, (240, 140, 60), "LUNCH MENU<br/>PIZZA DAY"),
        (HALL_S, 16, 7, 5, 4, (120, 90, 200), "STAY IN<br/>SCHOOL"),
        (HALL_W, 0, 30.5, 6, 3.5, (40, 120, 200), "SCIENCE FAIR<br/>FRIDAY!"),
        (HALL_S, -24, 24, 5, 5, (60, 170, 200), "ART CLUB<br/>ROOM 204"),
        (HALL_S, 24, 24, 4, 4, (240, 200, 70), "PROM<br/>TICKETS", (60, 30, 10)),
        (UPPER_HALL_S, -15, 30.5, 5, 3.5, (200, 70, 70), "BAND<br/>CONCERT"),
        (UPPER_HALL_S, 22, 30.5, 6, 3.5, (70, 90, 160), "MATH TEAM<br/>TRYOUTS"),
        (GYM_N, 0, 11, 16, 4.5, (130, 30, 40), "GO TIGERS!", (250, 200, 60)),
        (KITCHEN_SERVE, 26, 8, 5, 4, (60, 140, 140), "WASH<br/>YOUR HANDS"),
        (ART_W, 55, 25, 5, 4, (230, 90, 150), "ART<br/>CLUB"),
        (CAFE_N_IN, 16, 8, 5, 4, (250, 190, 40), "TACO<br/>TUESDAY", (60, 30, 10)),
    ):
        poster(m, g, *args)
    on_wall(m, g, "QuietSign", MEZZ_EDGE, -14, 17, 8, 1.6, "plate", text="QUIET PLEASE",
            text_color=(240, 220, 120))
    bulletin_board(m, g, HALL_N, -14, 7.5, 10, 5)
    bulletin_board(m, g, HALL_S, -38, 24, 8, 4)  # upper floor, in the computer lab
    # Room signs over the doors.
    for face, along, y, text in (
        (HALL_W, -12, 11.2, "101"), (HALL_W, 12, 11.2, "102"),
        (HALL_E, -7, 11.2, "LIBRARY"), (HALL_E, 7, 11.2, "LIBRARY"),
        (HALL_N, -28, 11.2, "GYM"), (HALL_N, 28, 11.2, "GYM"), (HALL_S, 0, 13.2, "CAFETERIA"),
        (HALL_W, -12, 29.2, "SCIENCE LAB"), (HALL_W, 12, 29.2, "COMPUTER LAB"),
        (HALL_E, 0, 29.2, "LIBRARY"), (HALL_N, 0, 29.2, "GYM"),
        (UPPER_HALL_S, -26, 29.2, "MUSIC"), (UPPER_HALL_S, -4, 29.2, "MUSIC"),
        (UPPER_HALL_ART, 38, 29.2, "ART"), (TRACK_E, -56, 29.2, "TEACHERS ONLY"),
    ):
        plate(m, g, face, along, y, text)
    # Exit signs by the stairwell doors, clocks, fire alarms.
    for x, y, z, along_x in ((-56, F1_TOP, -30, True), (-56, F2_TOP, -30, True),
                             (37, F1_TOP, 36, False), (37, F2_TOP, 36, False),
                             (43, F1_TOP, 30, True), (-37, F1_TOP, -35.5, False)):
        exit_sign(m, g, x, y, z, along_x)
    for face, along, y in ((GYM_N, 24, 11), (CAFE_N_IN, -16, 12), (HALL_N, -56, 13),
                           (HALL_S, -56, 13), (HALL_E, -7, F2 + 7)):
        clock(m, g, face, along, y)
    for face, along, y in ((HALL_N, 20, 5.2), (HALL_S, 20, 5.2), (HALL_N, 22, F2 + 5.2)):
        on_wall(m, g, "FireAlarm", face, along, y, 0.8, 1.2, (210, 40, 40), depth=0.3)
    # Ceiling fans in the cafeteria (spinning).
    for x in (-20, 0):
        m.cylinder(g, "FanMotor", 0.8, 1.4, (x, F1_TOP - 1, 47), (60, 60, 64), **NO_HIT)
        m.block(g, "FanRod", x - 0.08, x + 0.08, F1_TOP - 0.6, F1_TOP, 46.92, 47.08, "chain",
                **NO_HIT)
        for angle in (0, 90):
            m.part(g, "FanBlade", (7, 0.12, 0.9), (x, F1_TOP - 1.3, 47), (150, 110, 70),
                   rot_y(angle), Material="Wood", attributes={"Spin": 220}, **NO_HIT)
    # Dust falling from the two collapses, a live wire sparking over the cafeteria.
    dust = {"rate": 5, "life": (3, 5), "speed": (1, 3), "size": ((0, 0.3), (1, 0.8)),
            "transparency": ((0, 0.6), (1, 1)), "color": (200, 195, 185), "texture": SMOKE,
            "direction": "Bottom", "spread": (30, 30)}
    cx0, cx1, cz0, cz1 = COLLAPSE
    hx0, hx1, hz0, hz1 = LAB_HOLE
    for name, x0, x1, z0, z1 in (("CollapseDust", cx0, cx1, cz0 - 0.4, cz0),
                                 ("LabDust", hx0, hx1, hz0 - 0.4, hz0)):
        m.block(g, name, x0, x1, F1_TOP - 0.1, F1_TOP, z0, z1, (255, 255, 255), Transparency=1,
                CastShadow=False, children=[m.particles("Dust", **dust)], **NO_HIT)
    m.cylinder(g, "Wire", 4, 0.15, (24, F1_TOP - 2, cz0 + 0.3), (30, 30, 30), **NO_HIT)
    m.block(g, "WireEnd", 23.8, 24.2, F1_TOP - 4.2, F1_TOP - 3.8, cz0 + 0.1, cz0 + 0.5,
            (255, 160, 60), Material="Neon", **NO_HIT,
            children=[m.particles("Sparks", rate=10, life=(0.2, 0.45), speed=(6, 14),
                                  size=((0, 0.15), (1, 0.05)), transparency=((0, 0), (1, 1)),
                                  color=(255, 200, 90), texture=SPARK, direction="Bottom",
                                  spread=(60, 60), accel=(0, -60, 0), light=1)])
    # Baseboards along the halls, broken at the doorways.
    for face, spec in ((HALL_N, hall["north"]), (HALL_S, hall["south"]), (HALL_W, hall["west"]),
                       (HALL_E, hall["east"])):
        s = -32
        for o0, o1 in sorted((o[0], o[1]) for o in spec["f1"] if len(o) == 3) + [(32, 32)]:
            a, b = max(s, -32), min(o0, 32)
            if b - a > 0.5:
                on_wall(m, g, "Baseboard", face, (a + b) / 2, 0.3, b - a, 0.6, (60, 55, 50),
                        depth=0.15)
            s = max(s, o1)


SPAWNS = (  # x, z, floor
    (-18, -56, F1), (18, -56, F1), (-26, 0, F1), (26, 0, F1), (0, 26, F1), (-60, 4, F1),
    (43, 20, F1), (-17, 46, F1), (-58, -16, F2), (-34, 38, F2), (0, -24, F2), (56, -38, F2),
)


def build():
    DOORS.clear()
    m = Map(colors=COLORS, materials=MATERIALS)
    shell(m)
    atrium(m)
    gym(m)
    stairwells(m)
    west_wing(m)
    east_wing(m)
    south_wing(m)
    upper_ring(m)
    lights(m)
    details(m)
    for x, z, y in SPAWNS:
        m.spawn(x, z, y)
    return m


# ---- checks ----------------------------------------------------------------------------------

def solids(m):
    """World-space bounds of every part that blocks players."""
    boxes = []
    for nodes in m.groups.values():
        for node in nodes:
            p = node["properties"]
            gate = (node.get("attributes") or {}).get("SlideBlocker")
            if p.get("CanCollide") is False or (p.get("Transparency", 0) >= 1 and not gate):
                continue
            cf = p["CFrame"]["CFrame"]
            rows, (x, y, z), size = cf["orientation"], cf["position"], p["Size"]
            half = [sum(abs(rows[i][j]) * size[j] / 2 for j in range(3)) for i in range(3)]
            name = re.sub(r"\d+$", "", node["name"])
            boxes.append((name, (x - half[0], x + half[0]), (y - half[1], y + half[1]),
                          (z - half[2], z + half[2])))
    return boxes


def overlaps(box, xs, ys, zs):
    _, bx, by, bz = box
    return all(a[0] < b[1] and b[0] < a[1] for a, b in ((bx, xs), (by, ys), (bz, zs)))


def check(m):
    problems = []
    boxes = solids(m)
    if len(m.spawns) < ATTRIBUTES["MaxPlayers"]:
        problems.append(f"only {len(m.spawns)} spawns for {ATTRIBUTES['MaxPlayers']} players")
    for i, (x, y, z) in enumerate(m.spawns):
        for j in range(i):
            if math.dist((x, y, z), m.spawns[j]) < 25:
                problems.append(f"spawns {j + 1} and {i + 1} are under 25 studs apart")
        body = ((x - 1, x + 1), (y + 0.3, y + 5), (z - 1, z + 1))
        hits = [b[0] for b in boxes if overlaps(b, *body)]
        if hits:
            problems.append(f"spawn {i + 1} is inside {', '.join(sorted(set(hits)))}")
        under = ((x - 0.5, x + 0.5), (y - 0.5, y - 0.01), (z - 0.5, z + 0.5))
        if not any(overlaps(b, *under) for b in boxes):
            problems.append(f"spawn {i + 1} has no floor under it")
    # Every doorway: nothing solid in the way for 3 studs either side of the wall.
    for axis, line, s0, s1, floor_y in DOORS:
        along, across, ys = (s0 + 1, s1 - 1), (line - 4, line + 4), (floor_y + 0.5, floor_y + 5)
        xs, zs = (along, across) if axis == "X" else (across, along)
        hits = [b[0] for b in boxes if overlaps(b, xs, ys, zs) and b[0] != "Wall"]
        if hits:
            problems.append(f"door on {axis}={line} at {s0}..{s1} (floor {floor_y}) is blocked "
                            f"by {', '.join(sorted(set(hits)))}")
    return problems


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns, "
          f"{len(DOORS)} doorways")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
