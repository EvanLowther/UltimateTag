#!/usr/bin/env python3
"""The School map (grey-box), from the user's blueprint. Run from the repo root:
    python3 tools/school_layout.py
It rewrites `src/maps/School/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south (north is -Z), Y up. Main floor at Y 0, basement floor at Y -22.

MAIN FLOOR: a long rectangle (north-south longer). A classroom in the middle with a ring of
16-wide hallways around it (the main loop).
  - West hallway: lockers on the outer wall (wall-run surface); a floor grate near the south end
    is one basement opening.
  - North hallway: a puddle across the whole width: run or slide in and you slip, skid on with
    your momentum, and get up (Slip).
  - East hallway: a tipped lunch table in the middle of the hall ramps up toward a hole in the
    floor. Off the ramp, steer to either wall and wall-run across (south to north only). Miss and you fall into
    the basement.
  - South hallway: a collapsed ceiling: slide under the low slab (or squeeze past by the wall),
    or mantle on and run up to a section hanging at 10, then drop off; rubble to vault.
  - Classroom: doors on the west (north end) and east (south end). Two rows of tall bookshelves
    cross it (wall-run faces, a high route on top), each with a vault gap (a fallen shelf) and a
    gap under the duct; a support column in the middle; an HVAC duct catwalk at 11 (climb a riser).
BASEMENT: exactly two openings.
  - East chamber under the hole: a steam updraft pad launches you back up through the hole,
    landing north of it.
  - An L-shaped tunnel: south from the chamber, then west under the south hallway.
  - Pipe room at the west end: an incline (the pipe slide) up north to a platform under the
    grate; climb the shaft (one 12-stud hop) and over onto the west hallway. From the top, drop
    in the grate, land, and slide down the pipe into the tunnel.
"""
import json
import math
import os
import shutil

OUT = "src/maps/School"

# Main floor
IN_X, IN_Z = 44, 66  # inside faces of the outer walls (building is 88 x 132 inside)
HALL = 16  # hallway width
ROOM_X, ROOM_Z = IN_X - HALL, IN_Z - HALL  # classroom outer faces (28, 50)
WALL = 2
HEIGHT = 18  # floor to ceiling
DOOR_W, DOOR_H = 8, 10

# Openings in the main floor
HOLE = (28, 44, -30, -4)  # x0, x1, z0, z1 (east hallway)
GRATE = (-39, -33, 24, 30)  # west hallway, near the south end

# Basement
B_FLOOR = -22
SLAB = -2  # bottom of the main floor slab
TUNNEL_TOP = -12
CHAMBER = (24, 46, -40, 2)  # x0, x1, z0, z1 (under the hole)
TUNNEL_EAST = (34, 44, 2, 46)  # leg running south from the chamber
TUNNEL_SOUTH = (-42, 44, 46, 56)  # leg running west under the south hallway
PIPE_ROOM = (-42, -30, 24, 46)  # incline up north to the grate
PLATFORM_Y = -12  # top of the incline / bottom of the grate shaft
PIPE_TOP_Z = 30  # where the incline reaches the platform

COLORS = {
    "floor": (140, 146, 156), "wall": (178, 168, 146), "trim": (80, 115, 165),
    "ceiling": (110, 112, 120), "room_floor": (135, 100, 70), "desk": (160, 110, 70),
    "desk_top": (205, 170, 120), "board": (40, 80, 60), "locker_a": (60, 110, 200),
    "locker_b": (45, 90, 170), "table": (230, 120, 60), "puddle": (90, 170, 230),
    "concrete": (110, 112, 118), "concrete_dark": (80, 82, 88), "pipe": (180, 70, 50),
    "pad": (255, 140, 40), "grate": (60, 60, 64), "hazard": (250, 200, 40),
    "light": (235, 235, 220), "light_warm": (240, 170, 100),
    "column": (150, 140, 120), "duct": (165, 172, 182), "duct_dark": (120, 126, 136),
    "shelf": (120, 80, 50), "books_a": (190, 60, 60), "books_b": (60, 120, 190),
    "books_c": (220, 180, 60), "debris": (128, 128, 134), "rubble": (150, 145, 135),
    "hole": (25, 25, 30), "chain": (90, 92, 98), "door": (150, 100, 60),
}

# Real materials for the named colours (the rest stay smooth plastic).
MATERIALS = {
    "floor": "CeramicTiles", "wall": "Plaster", "ceiling": "Plaster", "room_floor": "WoodPlanks",
    "shelf": "Wood", "door": "Wood", "desk": "Wood", "locker_a": "Metal", "locker_b": "Metal",
    "duct": "Metal", "duct_dark": "Metal", "grate": "DiamondPlate", "board": "Slate",
    "concrete": "Concrete", "concrete_dark": "Brick", "pipe": "Metal", "column": "Concrete",
    "debris": "Concrete", "rubble": "Slate", "chain": "Metal", "cork": "Fabric",
}

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def rot_x(deg):
    """Turns about X: a part's -Z end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_z(deg):
    """Turns about Z: a part's +X end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def rot_y(deg):
    """Turns about Y (a part lying at an angle on the floor)."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def r(v):
    return round(v, 3)


def rgb(c):
    return [r(v / 255) for v in c]


class Map:
    def __init__(self):
        self.groups = {}
        self.spawns = []
        self.counts = {}

    def _name(self, name):
        n = self.counts.get(name, 0) + 1
        self.counts[name] = n
        return name if n == 1 else f"{name}{n}"

    def part(self, group, name, size, pos, color, rows=IDENTITY, children=None, **props):
        attributes = props.pop("attributes", None)
        properties = {
            "Anchored": True, "Size": [r(v) for v in size], "Color": rgb(COLORS.get(color, color)
                                                                      if isinstance(color, str) else color),
            "Material": MATERIALS.get(color, "SmoothPlastic") if isinstance(color, str)
            else "SmoothPlastic",
            "TopSurface": "Smooth", "BottomSurface": "Smooth",
            "CFrame": {"CFrame": {"position": [r(v) for v in pos],
                                  "orientation": [[r(v) for v in row] for row in rows]}},
        }
        properties.update(props)
        node = {"name": self._name(name), "className": "Part", "properties": properties}
        if attributes:
            node["attributes"] = attributes
        if children:
            node["children"] = children
        self.groups.setdefault(group, []).append(node)
        return node

    def block(self, group, name, x0, x1, y0, y1, z0, z1, color, **props):
        """An axis-aligned block from its bounds."""
        return self.part(group, name, (x1 - x0, y1 - y0, z1 - z0),
                         ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, **props)

    def cylinder(self, group, name, length, diameter, pos, color, rows=None, **props):
        """A cylinder; by default standing upright (its length is vertical)."""
        return self.part(group, name, (length, diameter, diameter), pos, color,
                         rows if rows is not None else rot_z(90), Shape="Cylinder", **props)

    def slab(self, group, name, rect, y0, y1, holes, color, **props):
        """A slab over rect (x0, x1, z0, z1) with rectangular holes cut out (grid split)."""
        x0, x1, z0, z1 = rect
        xs = sorted({x0, x1, *[v for h in holes for v in h[:2] if x0 < v < x1]})
        zs = sorted({z0, z1, *[v for h in holes for v in h[2:] if z0 < v < z1]})
        for i in range(len(zs) - 1):
            row = []
            for j in range(len(xs) - 1):
                cx, cz = (xs[j] + xs[j + 1]) / 2, (zs[i] + zs[i + 1]) / 2
                inside = any(h[0] <= cx <= h[1] and h[2] <= cz <= h[3] for h in holes)
                row.append(None if inside else (xs[j], xs[j + 1]))
            # Merge neighbouring solid cells in the row.
            run = None
            for cell in row + [None]:
                if cell and run:
                    run = (run[0], cell[1])
                elif cell:
                    run = cell
                else:
                    if run:
                        self.block(group, name, run[0], run[1], y0, y1, zs[i], zs[i + 1], color,
                                   **props)
                    run = None

    def wall(self, group, axis, fixed, span, y0, y1, color, openings=(), name="Wall"):
        """A wall along `axis` ("X" or "Z"). `fixed` = (a0, a1) its thickness range on the other
        axis, `span` = (s0, s1) along it. Openings: (s0, s1, top) is a doorway from the floor up
        to top; (s0, s1, top, bottom) is a window: glass (solid, see-through) from bottom to top,
        flush with the wall so wall runs along it still work."""
        s0, s1 = span
        cuts = sorted(openings)
        pos = s0
        pieces = []
        panes = []
        for opening in cuts:
            o0, o1, top = opening[:3]
            bottom = opening[3] if len(opening) > 3 else None
            if o0 > pos:
                pieces.append((pos, o0, y0, y1))
            if top < y1:
                pieces.append((o0, o1, top, y1))  # lintel
            if bottom is not None:
                pieces.append((o0, o1, y0, bottom))  # sill
                panes.append((o0, o1, bottom, top))
            pos = o1
        if pos < s1:
            pieces.append((pos, s1, y0, y1))
        glass = {"Material": "Glass", "Transparency": 0.6, "CastShadow": False}
        for a, b, lo, hi in pieces:
            if axis == "X":
                self.block(group, name, a, b, lo, hi, fixed[0], fixed[1], color)
            else:
                self.block(group, name, fixed[0], fixed[1], lo, hi, a, b, color)
        for a, b, lo, hi in panes:
            if axis == "X":
                self.block(group, "Window", a, b, lo, hi, fixed[0], fixed[1], (185, 215, 235),
                           **glass)
                self.block(group, "WindowFrame", a, b, lo - 0.3, lo, fixed[0] - 0.2, fixed[1] + 0.2,
                           "door", CanCollide=False, CanQuery=False)
            else:
                self.block(group, "Window", fixed[0], fixed[1], lo, hi, a, b, (185, 215, 235),
                           **glass)
                self.block(group, "WindowFrame", fixed[0] - 0.2, fixed[1] + 0.2, lo - 0.3, lo, a, b,
                           "door", CanCollide=False, CanQuery=False)

    def light(self, group, x, y, z, size=(8, 0.2, 1), warm=False, brightness=0.5, reach=22,
              flicker=False):
        extra = {"attributes": {"Flicker": True}} if flicker else {}
        self.part(group, "Light", size, (x, y, z), "light_warm" if warm else "light",
                  Material="Neon", CanCollide=False, CanQuery=False, CastShadow=False, **extra,
                  children=[{"name": "Glow", "className": "PointLight",
                             "properties": {"Brightness": brightness, "Range": reach,
                                            "Color": rgb(COLORS["light_warm" if warm else "light"]),
                                            "Shadows": False}}])

    def spawn(self, x, z, y=0.0):
        self.spawns.append((x, y, z))


def main_floor(m):
    g = "Building"
    # Floor slab with the hole and the grate cut out; ceiling.
    m.slab(g, "Floor", (-IN_X, IN_X, -IN_Z, IN_Z), SLAB, 0, [HOLE, GRATE], "floor")
    # Thick, so nothing gets pushed through it.
    m.block(g, "Ceiling", -IN_X - WALL, IN_X + WALL, HEIGHT, HEIGHT + 4, -IN_Z - WALL, IN_Z + WALL,
            "ceiling")
    # Outer walls.
    m.wall(g, "Z", (IN_X, IN_X + WALL), (-IN_Z - WALL, IN_Z + WALL), SLAB, HEIGHT, "wall")
    m.wall(g, "Z", (-IN_X - WALL, -IN_X), (-IN_Z - WALL, IN_Z + WALL), SLAB, HEIGHT, "wall")
    m.wall(g, "X", (-IN_Z - WALL, -IN_Z), (-IN_X, IN_X), SLAB, HEIGHT, "wall")
    m.wall(g, "X", (IN_Z, IN_Z + WALL), (-IN_X, IN_X), SLAB, HEIGHT, "wall")
    # Wainscot trim stripe along the hallway walls (decoration).
    for x0, x1, z0, z1 in ((IN_X - 0.2, IN_X, -IN_Z, IN_Z), (-IN_X, -IN_X + 0.2, -IN_Z, IN_Z),
                           (-IN_X, IN_X, -IN_Z, -IN_Z + 0.2), (-IN_X, IN_X, IN_Z - 0.2, IN_Z)):
        m.block(g, "Trim", x0, x1, 3.5, 4.5, z0, z1, "trim", CanCollide=False, CanQuery=False)

    # Classroom walls with two doors: west (north end) and east (south end).
    c = "Classroom"
    west_door = (-34, -26, DOOR_H)
    east_door = (26, 34, DOOR_H)
    # Windows between the classroom and the hallways (glass from 4 to 11), clear of the doors
    # and of where the bookshelf rows meet the walls.
    west_windows = [(-46, -38, 11, 4), (-14, -4, 11, 4), (4, 14, 11, 4), (24, 40, 11, 4)]
    east_windows = [(-44, -36, 11, 4), (-14, -4, 11, 4), (4, 14, 11, 4), (38, 46, 11, 4)]
    south_windows = [(-22, -10, 11, 4), (10, 20, 11, 4)]
    m.wall(c, "Z", (-ROOM_X, -ROOM_X + WALL), (-ROOM_Z, ROOM_Z), 0, HEIGHT, "wall",
           [west_door, *west_windows])
    m.wall(c, "Z", (ROOM_X - WALL, ROOM_X), (-ROOM_Z, ROOM_Z), 0, HEIGHT, "wall",
           [east_door, *east_windows])
    m.wall(c, "X", (-ROOM_Z, -ROOM_Z + WALL), (-ROOM_X + WALL, ROOM_X - WALL), 0, HEIGHT, "wall")
    m.wall(c, "X", (ROOM_Z - WALL, ROOM_Z), (-ROOM_X + WALL, ROOM_X - WALL), 0, HEIGHT, "wall",
           south_windows)
    m.block(c, "ClassFloor", -ROOM_X + WALL, ROOM_X - WALL, 0, 0.1, -ROOM_Z + WALL, ROOM_Z - WALL,
            "room_floor", CanCollide=False, CanQuery=False)
    for z0, z1, x in ((-34, -26, -ROOM_X), (26, 34, ROOM_X)):  # door frames
        for zz in (z0, z1):
            m.block(c, "DoorFrame", x - 1.2, x + 1.2, 0, DOOR_H, zz - 0.4, zz + 0.4, "door",
                    CanCollide=False, CanQuery=False)
    inner_x, inner_z = ROOM_X - WALL, ROOM_Z - WALL  # 26, 48
    m.block(c, "Chalkboard", -16, 16, 5, 12, -inner_z, -inner_z + 0.3, "board",
            CanCollide=False, CanQuery=False,
            children=[surface_text("Back", "TODAY: TAG<br/>Rule #1: don't get caught",
                                   (240, 240, 230), None, font="PermanentMarker", pps=20)])
    m.block(c, "ChalkTray", -16, 16, 4.7, 5, -inner_z, -inner_z + 0.6, "door",
            CanCollide=False, CanQuery=False)
    classroom_obstacles(m, c, inner_x, inner_z)

    # Hallway features.
    h = "Hallways"
    # West: a long run of lockers on the outer wall.
    for i, z in enumerate(range(-48, 48, 3)):
        m.block(h, "Locker", -IN_X, -IN_X + 2, 0, 9, z, z + 3,
                "locker_a" if i % 2 == 0 else "locker_b")
    # North: a round puddle (slip) that leaves room to go round it, and the janitor's bucket.
    puddle(m, h, -4, -58)
    # East: the tipped lunch table in the middle of the hallway, rising north to the hole's south
    # edge (4 high). Off the end, steer toward either wall to wall-run across.
    hx0, hx1, hz0, hz1 = HOLE
    table_x = (ROOM_X + IN_X) / 2
    length, rise = 12, 4
    angle = math.degrees(math.atan2(rise, length))
    slope_len = math.hypot(length, rise)
    m.part(h, "LunchTable", (7, 0.6, slope_len), (table_x, rise / 2 + 0.1, hz1 + length / 2),
           "table", rot_x(angle))
    for dz in (3, 9):  # legs sticking out (decoration)
        m.block(h, "TableLeg", table_x - 3, table_x + 3, 0, 0.6, hz1 + dz - 0.3, hz1 + dz + 0.3,
                "grate", CanCollide=False, CanQuery=False)
    # Hazard stripes around the hole and the grate, a grate grid (decoration).
    for x0, x1, z0, z1 in ((hx0, hx1, hz0 - 1, hz0), (hx0, hx1, hz1, hz1 + 1)):
        m.block(h, "HazardEdge", x0, x1, 0, 0.08, z0, z1, "hazard", CanCollide=False,
                CanQuery=False)
    gx0, gx1, gz0, gz1 = GRATE
    for x in (gx0 + 1.5, (gx0 + gx1) / 2, gx1 - 1.5):
        m.block(h, "GrateBar", x - 0.2, x + 0.2, -0.3, 0, gz0, gz1, "grate", CanCollide=False,
                CanQuery=False)
    m.block(h, "GrateFrame", gx0 - 0.5, gx1 + 0.5, 0, 0.08, gz0 - 0.5, gz0, "hazard",
            CanCollide=False, CanQuery=False)
    m.block(h, "GrateFrame", gx0 - 0.5, gx1 + 0.5, 0, 0.08, gz1, gz1 + 0.5, "hazard",
            CanCollide=False, CanQuery=False)
    # South: a collapsed ceiling section.
    ceiling_collapse(m, "Collapse")

    # Lights.
    for z in range(-56, 57, 16):
        m.light("Lights", -36, HEIGHT - 0.2, z, size=(1, 0.2, 8))
        m.light("Lights", 36, HEIGHT - 0.2, z, size=(1, 0.2, 8), flicker=(z == -24))
    for x in (-18, 0, 18):
        m.light("Lights", x, HEIGHT - 0.2, -58)
        m.light("Lights", x, HEIGHT - 0.2, 58, flicker=(x == 0))
    for x in (-13, 13):
        for z in (-30, 0, 30):
            m.light("Lights", x, HEIGHT - 0.2, z, size=(8, 0.2, 1), reach=26)


def ceiling_collapse(m, g):
    """The middle of the south hallway, where the ceiling came down:
      - a slab hanging at 4.2 high across most of the hall: slide or crouch under it (an
        invisible SlideBlocker stops standing players, like the test map's slide bar), or squeeze
        through the 3-wide gap left along the outer wall;
      - mantle onto it (top 5.2), run up a broken panel to a section hanging on chains at 10,
        and drop off the far end (landing roll);
      - rubble at vault height on the west approach."""
    z0, z1 = ROOM_Z, IN_Z - 3  # 50 to 63: leaves a 3-wide gap by the outer wall
    gap_y = 4.2
    # The low slab and the blocker under it.
    m.block(g, "FallenSlab", -6, 6, gap_y, gap_y + 1, z0, z1, "debris")
    m.block(g, "StandBlocker", -6, 6, 0, gap_y, z0, z1, (255, 255, 255), Transparency=1,
            CastShadow=False, attributes={"SlideBlocker": True})
    # The broken panel rising east from the slab's top to the hanging section.
    low = (6, gap_y + 1)
    high_x, high_top = 16, 10
    run, rise = high_x - low[0], high_top - low[1]
    angle = math.degrees(math.atan2(rise, run))
    length = math.hypot(run, rise)
    a = math.radians(angle)
    cx = (low[0] + high_x) / 2 + 0.5 * math.sin(a)
    cy = (low[1] + high_top) / 2 - 0.5 * math.cos(a)
    m.part(g, "BrokenPanel", (length, 1, z1 - z0 - 2), (cx, cy, (z0 + z1) / 2), "debris", rot_z(angle))
    # The hanging section at 10, on chains, with a drop off the east end.
    m.block(g, "HangingSection", high_x, 24, high_top - 1, high_top, z0 + 1, z1 - 1, "debris")
    for x in (high_x + 1, 23):
        for z in (z0 + 2, z1 - 2):
            m.block(g, "Chain", x - 0.15, x + 0.15, high_top, HEIGHT, z - 0.15, z + 0.15, "chain",
                    CanCollide=False, CanQuery=False)
    for x in (-5, 5):  # chains holding up the low slab
        for z in (z0 + 2, z1 - 2):
            m.block(g, "Chain", x - 0.15, x + 0.15, gap_y + 1, HEIGHT, z - 0.15, z + 0.15, "chain",
                    CanCollide=False, CanQuery=False)
    # The break in the ceiling above (dark), and loose tiles hanging from it.
    m.block(g, "CeilingBreak", -8, 26, HEIGHT - 0.05, HEIGHT, z0, IN_Z - 1, "hole",
            CanCollide=False, CanQuery=False, CastShadow=False,
            children=[particles("Dust", rate=6, life=(3, 5), speed=(1, 3),
                                size=((0, 0.3), (1, 0.8)), transparency=((0, 0.6), (1, 1)),
                                color=(200, 195, 185), texture=SMOKE, direction="Bottom",
                                spread=(30, 30))])
    # A live wire hanging from the break, sparking.
    m.cylinder(g, "Wire", 5, 0.15, (13, HEIGHT - 2.5, 57), (30, 30, 30), CanCollide=False,
               CanQuery=False)
    m.block(g, "WireEnd", 12.8, 13.2, HEIGHT - 5.2, HEIGHT - 4.8, 56.8, 57.2, (255, 160, 60),
            Material="Neon", CanCollide=False, CanQuery=False,
            children=[particles("Sparks", rate=10, life=(0.2, 0.45), speed=(6, 14),
                                size=((0, 0.15), (1, 0.05)), transparency=((0, 0), (1, 1)),
                                color=(255, 200, 90), texture=SPARK, direction="Bottom",
                                spread=(60, 60), accel=(0, -60, 0), light=1)])
    for x, z, ang in ((-3, 58, 25), (10, 54, -30), (20, 60, 20)):
        m.part(g, "LooseTile", (4, 0.3, 4), (x, HEIGHT - 2, z), "ceiling", rot_z(ang),
               CanCollide=False, CanQuery=False)
    # Rubble on the west approach: vault-height chunks with room between them.
    for x, z, size in ((-11, 53, (3, 2.6, 3)), (-15, 59, (4, 3.2, 3)), (-20, 54, (3, 2.4, 2.5)),
                       (-10, 61, (2.5, 2, 2.5))):
        m.block(g, "Rubble", x - size[0] / 2, x + size[0] / 2, 0, size[1], z - size[2] / 2,
                z + size[2] / 2, "rubble")


def puddle(m, g, x, z):
    """A roundish puddle (three overlapping discs) with Slip, about 11 across in the 16-wide
    hallway, and a yellow mop bucket with a mop and a wet-floor sign next to it."""
    wet = {"Material": "Glass", "Transparency": 0.35, "Reflectance": 0.15, "CanCollide": False,
           "attributes": {"Slip": 1.6}}
    for dx, dz, size in ((0, 0, 9), (3.2, 1.5, 5.5), (-3.4, -1.2, 4.5)):
        m.cylinder(g, "Puddle", 0.12, size, (x + dx, 0.06, z + dz), "puddle", **wet)
    # Mop bucket (vault-sized, it's in the way if you hug the wall).
    bx, bz = x + 9, z - 4
    m.cylinder(g, "MopBucket", 2.4, 2.6, (bx, 1.2, bz), "hazard")
    m.cylinder(g, "BucketWater", 0.1, 2.2, (bx, 2.42, bz), (110, 130, 120), CanCollide=False,
               CanQuery=False)
    m.block(g, "Wringer", bx - 1.4, bx - 0.2, 2.4, 3.4, bz - 0.9, bz + 0.9, "grate",
            CanCollide=False, CanQuery=False)
    for dx, dz in ((-1.1, -1.1), (1.1, -1.1), (-1.1, 1.1), (1.1, 1.1)):  # casters
        m.cylinder(g, "Caster", 0.4, 0.5, (bx + dx, 0.2, bz + dz), "grate", rot_z(0),
                   CanCollide=False, CanQuery=False)
    # The mop leaning out of the bucket.
    m.cylinder(g, "MopHandle", 7, 0.25, (bx + 0.6, 4.6, bz + 0.3), (200, 170, 120),
               rot_z(75), CanCollide=False, CanQuery=False)
    m.block(g, "MopHead", bx - 0.4, bx + 1.0, 1.4, 2.6, bz - 0.4, bz + 1.0, (220, 215, 200),
            CanCollide=False, CanQuery=False)
    # Wet floor sign: an A-frame, yellow.
    sx, sz = x - 7, z + 2
    for tilt in (14, -14):
        m.part(g, "WetFloorSign", (0.2, 3.2, 2), (sx + (0.4 if tilt > 0 else -0.4), 1.55, sz),
               "hazard", rot_z(tilt), CanCollide=False, CanQuery=False)
    m.block(g, "SignStripe", sx - 0.1, sx + 0.1, 1.2, 1.8, sz - 1.05, sz + 1.05, (30, 30, 30),
            CanCollide=False, CanQuery=False)


DUCT_X = 9  # the catwalk runs north-south east of the column
DUCT_TOP = 11  # walk on top: out of reach of a tag from the floor, 7 below the ceiling (room
# to stand, and the mantle's headroom check passes)
DUCT_W = 6
DUCT_Z = 42  # catwalk from -DUCT_Z to DUCT_Z, with a riser down to the floor at each end


def classroom_obstacles(m, g, inner_x, inner_z):
    """The classroom's obstacles: a support column in the middle (go around), an HVAC duct
    catwalk at 12 high (climb a riser at either end, drop off anywhere), fallen bookshelves lying
    across the diagonal between the two doors (sprint to vault them, walk and you stall)."""
    # Center support column, floor to ceiling.
    m.block(g, "SupportColumn", -3, 3, 0, HEIGHT, -3, 3, "column")
    m.block(g, "ColumnBand", -3.2, 3.2, 3, 3.6, -3.2, 3.2, "trim", CanCollide=False, CanQuery=False)

    # Duct catwalk: a 3-tall box hung from the ceiling, its top is the walkway.
    x0, x1 = DUCT_X - DUCT_W / 2, DUCT_X + DUCT_W / 2
    m.block(g, "Duct", x0, x1, DUCT_TOP - 3, DUCT_TOP, -DUCT_Z + 4, DUCT_Z - 4, "duct")
    for z in range(-DUCT_Z + 8, DUCT_Z - 3, 8):  # seams and hanger rods (decoration)
        m.block(g, "DuctSeam", x0 - 0.15, x1 + 0.15, DUCT_TOP - 3.1, DUCT_TOP + 0.05, z - 0.3,
                z + 0.3, "duct_dark", CanCollide=False, CanQuery=False)
    for z in range(-DUCT_Z + 10, DUCT_Z - 5, 16):
        for x in (x0 + 0.5, x1 - 0.5):
            m.block(g, "Hanger", x - 0.15, x + 0.15, DUCT_TOP, HEIGHT, z - 0.15, z + 0.15,
                    "duct_dark", CanCollide=False, CanQuery=False)
    # Risers: the duct turns down to the floor at each end; climb one (one 12-stud hop) and
    # pull up onto the catwalk.
    for z0, z1 in ((-DUCT_Z, -DUCT_Z + 4), (DUCT_Z - 4, DUCT_Z)):
        m.block(g, "DuctRiser", x0, x1, 0, DUCT_TOP, z0, z1, "duct")
        m.block(g, "RiserGrille", x0 - 0.1, x1 + 0.1, 3, 6, z0 - 0.1, z1 + 0.1, "duct_dark",
                CanCollide=False, CanQuery=False)

    # Two rows of tall bookshelves cross the room (east-west), splitting it into three zones.
    # Their long faces are wall-run walls; their tops (9) are a mantle-up high route. Each row has
    # two gaps: one where a shelf has fallen into it (vault it) and one under the duct. Getting
    # from one door to the other means picking a gap in each row.
    rows = (
        # row z, standing segments (x0, x1), vault gaps (x0, x1, fallen shelf height)
        (-18, ((-inner_x, -17), (-11, DUCT_X - DUCT_W / 2 - 1), (DUCT_X + DUCT_W / 2 + 1, inner_x)),
         ((-17, -11, 3.2),)),
        (18, ((-inner_x, -21), (-15, DUCT_X - DUCT_W / 2 - 1), (DUCT_X + DUCT_W / 2 + 1, inner_x)),
         ((-21, -15, 3.2), (DUCT_X - DUCT_W / 2 - 1, DUCT_X + DUCT_W / 2 + 1, 2.2))),
    )
    books = ("books_a", "books_b", "books_c")
    for z, segments, gaps in rows:
        for k, (x0, x1) in enumerate(segments):
            bookshelf_row(m, g, x0, x1, z, books, k)
        for x0, x1, height in gaps:
            # A shelf fallen across the gap (low enough to vault; the one under the duct is
            # lower still so the vault clears the duct).
            m.block(g, "FallenShelf", x0 + 0.3, x1 - 0.3, 0, height, z - 1.5, z + 1.5, "shelf")
            m.block(g, "SpilledBooks", x0 + 1, x1 - 1, height, height + 0.4, z - 1, z + 1,
                    books[int(abs(x0)) % 3], CanCollide=False, CanQuery=False)
            for i, dx in enumerate((-2.2, 0.8, 2.6)):  # books on the floor beside it
                m.part(g, "Book", (1.2, 0.3, 0.9), ((x0 + x1) / 2 + dx, 0.15, z + 2.6 + i * 0.4),
                       books[i], rot_y(25 * i - 20), CanCollide=False, CanQuery=False)


SHELF_HEIGHT = 9
SHELF_DEPTH = 2.5


def bookshelf_row(m, g, x0, x1, z, books, k):
    """Standing bookshelves from x0 to x1: a solid back and frame (the wall-run face), shelves of
    coloured book spines on both faces (decoration)."""
    m.block(g, "Bookshelf", x0, x1, 0, SHELF_HEIGHT, z - SHELF_DEPTH / 2, z + SHELF_DEPTH / 2,
            "shelf")
    for side in (-1, 1):
        face = z + side * (SHELF_DEPTH / 2 + 0.05)
        for level, y in enumerate((1.2, 3.6, 6.0)):
            # Book spines: a few coloured runs per shelf level, with small gaps.
            x = x0 + 0.6
            i = level + k
            while x < x1 - 1.2:
                width = min(1.5 + (i * 7 % 5) * 0.6, x1 - 0.6 - x)
                height = 1.4 + (i * 3 % 4) * 0.15
                m.block(g, "Books", x, x + width, y, y + height, face - 0.05, face + 0.05,
                        books[i % 3], CanCollide=False, CanQuery=False)
                x += width + 0.3
                i += 1


def basement(m):
    g = "Basement"
    rooms = [CHAMBER, TUNNEL_EAST, TUNNEL_SOUTH, PIPE_ROOM]
    for x0, x1, z0, z1 in rooms:
        m.block(g, "BasementFloor", x0 - WALL, x1 + WALL, B_FLOOR - 2, B_FLOOR, z0 - WALL,
                z1 + WALL, "concrete")

    # Chamber (tall: up to the slab) with an opening south into the tunnel.
    cx0, cx1, cz0, cz1 = CHAMBER
    tx0, tx1, _, _ = TUNNEL_EAST
    m.wall(g, "Z", (cx0 - WALL, cx0), (cz0 - WALL, cz1 + WALL), B_FLOOR, SLAB, "concrete_dark")
    m.wall(g, "Z", (cx1, cx1 + WALL), (cz0 - WALL, cz1 + WALL), B_FLOOR, SLAB, "concrete_dark")
    m.wall(g, "X", (cz0 - WALL, cz0), (cx0, cx1), B_FLOOR, SLAB, "concrete_dark")
    m.wall(g, "X", (cz1, cz1 + WALL), (cx0, cx1), B_FLOOR, SLAB, "concrete_dark",
           [(tx0, tx1, TUNNEL_TOP)])
    # Steam updraft pad under the hole: up through it, landing north of the hole.
    pad_x, pad_z = 36, -12
    m.part(g, "UpdraftPad", (8, 1, 8), (pad_x, B_FLOOR + 0.5, pad_z), "pad", Material="Neon",
           attributes={"LaunchVelocity": {"Vector3": [0, 105, -40]}},
           children=[particles("Steam", rate=28, life=(1.4, 2.2), speed=(10, 18),
                               size=((0, 1.2), (0.5, 3), (1, 4.5)),
                               transparency=((0, 0.5), (0.6, 0.75), (1, 1)),
                               color=(235, 235, 240), texture=SMOKE, spread=(12, 12))])
    m.block(g, "PadRing", pad_x - 5, pad_x + 5, B_FLOOR, B_FLOOR + 0.6, pad_z - 5, pad_z + 5,
            "grate")
    m.light(g, 30, SLAB - 0.5, -30, warm=True, brightness=0.6)
    m.light(g, 40, SLAB - 0.5, -2, warm=True, brightness=0.6)

    # East tunnel leg (south from the chamber).
    ex0, ex1, ez0, ez1 = TUNNEL_EAST
    sx0, sx1, sz0, sz1 = TUNNEL_SOUTH
    m.wall(g, "Z", (ex0 - WALL, ex0), (ez0, sz0), B_FLOOR, TUNNEL_TOP, "concrete_dark")
    m.wall(g, "Z", (ex1, ex1 + WALL), (ez0, sz1 + WALL), B_FLOOR, TUNNEL_TOP, "concrete_dark")
    m.block(g, "TunnelCeiling", ex0 - WALL, ex1 + WALL, TUNNEL_TOP, TUNNEL_TOP + 1, ez0 + WALL,
            sz0, "concrete")
    # South tunnel leg (west to the pipe room).
    px0, px1, pz0, pz1 = PIPE_ROOM
    m.wall(g, "X", (sz0 - WALL, sz0), (px1, ex0 - WALL), B_FLOOR, TUNNEL_TOP, "concrete_dark")
    m.wall(g, "X", (sz1, sz1 + WALL), (sx0 - WALL, ex1 + WALL), B_FLOOR, TUNNEL_TOP,
           "concrete_dark")
    m.wall(g, "Z", (sx0 - WALL, sx0), (sz0, sz1 + WALL), B_FLOOR, TUNNEL_TOP, "concrete_dark")
    m.block(g, "TunnelCeiling", px1, ex1 + WALL, TUNNEL_TOP, TUNNEL_TOP + 1, sz0 - WALL,
            sz1 + WALL, "concrete")
    for x in (-10, 20):
        m.light(g, x, TUNNEL_TOP - 0.5, (sz0 + sz1) / 2, warm=True, brightness=0.45, reach=20,
                flicker=(x == -10))
    m.light(g, (ex0 + ex1) / 2, TUNNEL_TOP - 0.5, 24, warm=True, brightness=0.45, reach=20)
    # Pipes along the tunnel wall (decoration).
    m.block(g, "Pipe", sx0, ex0 - WALL, TUNNEL_TOP - 2.5, TUNNEL_TOP - 1, sz1 - 1.5, sz1, "pipe",
            CanCollide=False, CanQuery=False)

    # Pipe room: tall (up to the slab), the incline up north to the platform under the grate.
    m.wall(g, "Z", (px0 - WALL, px0), (pz0 - WALL, sz0), B_FLOOR, SLAB, "concrete_dark")
    m.wall(g, "Z", (px1, px1 + WALL), (pz0 - WALL, sz0 - WALL), B_FLOOR, SLAB, "concrete_dark")
    m.wall(g, "X", (pz0 - WALL, pz0), (px0, px1), B_FLOOR, SLAB, "concrete_dark")
    m.block(g, "PipeRoomCap", sx0 - WALL, px1 + WALL, TUNNEL_TOP, SLAB, sz0 - WALL, sz0,
            "concrete_dark")  # closes the gap above the tunnel mouth
    rise = PLATFORM_Y - B_FLOOR
    run = sz0 - PIPE_TOP_Z
    angle = math.degrees(math.atan2(rise, run))
    m.part(g, "PipeSlide", (px1 - px0, 1, math.hypot(run, rise)),
           ((px0 + px1) / 2, (PLATFORM_Y + B_FLOOR) / 2 - 0.5, (PIPE_TOP_Z + sz0) / 2), "pipe",
           rot_x(angle))
    m.block(g, "GratePlatform", px0, px1, PLATFORM_Y - 1, PLATFORM_Y, pz0, PIPE_TOP_Z, "concrete")
    m.block(g, "PlatformFill", px0, px1, B_FLOOR, PLATFORM_Y - 1, pz0, PIPE_TOP_Z, "concrete_dark")
    m.light(g, (px0 + px1) / 2, SLAB - 0.5, 38, warm=True, brightness=0.45, reach=20)


# ---- Detail: decoration that makes the school feel lived in (no effect on the routes) ----------

SMOKE = "rbxasset://textures/particles/smoke_main.dds"
SPARK = "rbxasset://textures/particles/sparkles_main.dds"
NO_HIT = {"CanCollide": False, "CanQuery": False, "CanTouch": False}


def number_sequence(points):
    return {"NumberSequence": {"keypoints": [{"time": t, "value": v, "envelope": 0}
                                             for t, v in points]}}


def particles(name, rate, life, speed, size, transparency, color, texture, direction="Top",
              spread=(10, 10), accel=(0, 0, 0), light=0):
    """A ParticleEmitter child (steam, dust, sparks, drips)."""
    return {"name": name, "className": "ParticleEmitter", "properties": {
        "Rate": rate, "Lifetime": {"NumberRange": list(life)}, "Speed": {"NumberRange": list(speed)},
        "Size": number_sequence(size), "Transparency": number_sequence(transparency),
        "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": rgb(color)},
                                                  {"time": 1, "color": rgb(color)}]}},
        "Texture": texture, "EmissionDirection": direction,
        "SpreadAngle": {"Vector2": list(spread)}, "Acceleration": list(accel),
        "LightEmission": light, "Drag": 0.5,
    }}


def surface_text(face, text, color, background, font="FredokaOne", pps=30, glow=False):
    """A SurfaceGui with one label filling the face (posters, signs, the chalkboard). `glow`
    makes it shine on its own (exit signs) instead of being lit like paper."""
    label = {"Size": {"UDim2": [[0.92, 0], [0.88, 0]]}, "Position": {"UDim2": [[0.04, 0], [0.06, 0]]},
             "BackgroundTransparency": 1, "Text": text, "TextScaled": True, "RichText": True,
             "Font": font, "TextColor3": rgb(color)}
    gui = {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": pps}
    if glow:
        gui["LightInfluence"] = 0
        gui["Brightness"] = 2
    return {"name": f"Text{face}", "className": "SurfaceGui", "properties": gui,
            "children": [{"name": "Label", "className": "TextLabel", "properties": label}]}


# Wall faces: (axis the face is on, its coordinate, which way it faces).
WALLS = {
    "EO": ("x", IN_X, -1), "WO": ("x", -IN_X, 1), "NO": ("z", -IN_Z, 1), "SO": ("z", IN_Z, -1),
    "EI": ("x", ROOM_X, 1), "WI": ("x", -ROOM_X, -1), "NI": ("z", -ROOM_Z, -1),
    "SI": ("z", ROOM_Z, 1),
    "CE": ("x", ROOM_X - WALL, -1), "CW": ("x", -ROOM_X + WALL, 1),
    "CN": ("z", -ROOM_Z + WALL, 1), "CS": ("z", ROOM_Z - WALL, -1),
}
FACE = {("x", 1): "Right", ("x", -1): "Left", ("z", 1): "Back", ("z", -1): "Front"}


def on_wall(m, g, name, wall, along, y, w, h, color, depth=0.12, out=0.0, children=None,
            **props):
    """A flat box on a wall face, centered `along` the wall at height y. `out` pushes it further
    from the wall (for things that stick out). Returns the facing name for text."""
    axis, coord, facing = WALLS[wall]
    center = coord + facing * (out + depth / 2 + 0.02)
    extra = dict(NO_HIT)
    extra.update(props)
    if axis == "x":
        m.part(g, name, (depth, h, w), (center, y, along), color, children=children, **extra)
    else:
        m.part(g, name, (w, h, depth), (along, y, center), color, children=children, **extra)
    return FACE[(axis, facing)]


def poster(m, g, wall, along, y, w, h, background, text, text_color=(255, 255, 255)):
    face = FACE[(WALLS[wall][0], WALLS[wall][2])]
    on_wall(m, g, "Poster", wall, along, y, w, h, background,
            children=[surface_text(face, text, text_color, background)])


def bulletin_board(m, g, wall, along, y, w, h):
    on_wall(m, g, "BulletinFrame", wall, along, y, w + 0.6, h + 0.6, "door", depth=0.1)
    on_wall(m, g, "BulletinBoard", wall, along, y, w, h, (185, 140, 90), depth=0.12, out=0.1,
            Material="Fabric")
    notes = ((255, 250, 210), (200, 230, 255), (255, 210, 220), (210, 255, 210), (255, 255, 255))
    spots = ((-0.32, 0.2, 1.4, 1.8), (-0.05, -0.15, 1.6, 1.2), (0.22, 0.22, 1.2, 1.5),
             (0.33, -0.2, 1.3, 1.4), (-0.3, -0.25, 1.1, 1.0))
    for i, (fx, fy, nw, nh) in enumerate(spots):
        on_wall(m, g, "Note", wall, along + fx * w, y + fy * h, nw, nh, notes[i], depth=0.03,
                out=0.23)


def clock(m, g, wall, along, y):
    axis = WALLS[wall][0]
    rows = IDENTITY if axis == "x" else rot_y(90)
    _, coord, facing = WALLS[wall]
    c = coord + facing * 0.15
    pos = (c, y, along) if axis == "x" else (along, y, c)
    m.part(g, "Clock", (0.25, 2.6, 2.6), pos, (245, 245, 245), rows, Shape="Cylinder",
           children=None, **NO_HIT)
    on_wall(m, g, "ClockRim", wall, along, y, 2.8, 0.2, (40, 40, 40), depth=0.2, out=0.0)
    on_wall(m, g, "HourHand", wall, along + 0.25, y + 0.1, 0.7, 0.15, (20, 20, 20), depth=0.05,
            out=0.3)
    on_wall(m, g, "MinuteHand", wall, along - 0.05, y + 0.5, 0.12, 1.0, (20, 20, 20), depth=0.05,
            out=0.32)


def hallway_details(m):
    g = "Details"
    # Posters (the hallway ones are school notices).
    for args in (
        ("EO", 46, 7, 5, 7, (40, 120, 200), "SCIENCE<br/>FAIR<br/>FRIDAY!"),
        ("EO", -48, 7, 6, 4, (220, 60, 60), "NO RUNNING<br/>IN THE HALLS"),
        ("NO", 26, 8, 8, 4, (250, 190, 40), "GO TIGERS!", (60, 30, 10)),
        ("NO", -30, 7, 5, 6, (90, 180, 110), "READ<br/>MORE<br/>BOOKS"),
        ("SO", -34, 7, 5, 6, (240, 140, 60), "LUNCH MENU<br/>PIZZA DAY"),
        ("SO", 34, 7, 6, 4, (120, 90, 200), "STAY IN<br/>SCHOOL"),
        ("WO", -58, 7, 5, 6, (60, 170, 200), "ART CLUB<br/>ROOM 104"),
        ("WO", 58, 7, 5, 6, (230, 90, 150), "SPIRIT<br/>WEEK"),
        ("WI", -20, 8, 4, 5, (70, 90, 160), "MATH TEAM<br/>TRYOUTS"),
        ("EI", 20, 8, 5, 5, (200, 70, 70), "BOOK<br/>FAIR"),
        ("NI", -10, 8, 6, 4, (60, 140, 140), "CLASS PHOTOS<br/>TUESDAY"),
        ("SI", 24, 6, 4, 4, (240, 200, 70), "PROM<br/>TICKETS", (60, 30, 10)),
    ):
        poster(m, g, *args)
    # Bulletin boards, clocks.
    bulletin_board(m, g, "NI", 18, 7.5, 10, 5)
    bulletin_board(m, g, "EO", 20, 7.5, 10, 5)
    bulletin_board(m, g, "SO", 12, 7.5, 10, 5)
    clock(m, g, "NO", 0, 13)
    clock(m, g, "SO", -14, 13)
    clock(m, g, "EI", -40, 13)
    # Room plates by the classroom doors.
    for wall, along in (("WI", -38), ("EI", 37)):
        poster(m, g, wall, along, 8, 2.2, 1.2, (40, 40, 50), "101", (240, 220, 120))

    # Exit signs hanging at the corners.
    for x, z in ((36, -58), (-36, -58), (36, 58), (-36, 58)):
        m.part(g, "ExitSign", (3, 1.1, 0.3), (x, HEIGHT - 1.6, z), (30, 30, 30),
               children=[surface_text("Front", "EXIT", (255, 60, 60), None, font="Arcade",
                                      glow=True),
                         surface_text("Back", "EXIT", (255, 60, 60), None, font="Arcade",
                                      glow=True)],
               **NO_HIT)
        for dx in (-1.2, 1.2):
            m.block(g, "SignRod", x + dx - 0.05, x + dx + 0.05, HEIGHT - 1.05, HEIGHT, z - 0.05,
                    z + 0.05, "chain", **NO_HIT)
    # Fire alarms and an extinguisher cabinet.
    for wall, along in (("EO", 12), ("WO", -54), ("SO", -40), ("NO", 40)):
        on_wall(m, g, "FireAlarm", wall, along, 5.2, 0.8, 1.2, (210, 40, 40), depth=0.3)
    on_wall(m, g, "ExtinguisherCase", "NO", -40, 5, 2, 3.2, (235, 235, 235), depth=0.6)
    _, coord, facing = WALLS["NO"]
    m.cylinder(g, "Extinguisher", 2.2, 0.8, (-40, 4.8, coord + facing * 0.7), (200, 30, 30),
               **NO_HIT)
    # Water fountain on the classroom's east wall (hallway side).
    on_wall(m, g, "WaterFountain", "EI", 44, 3.2, 3, 1.2, (190, 195, 205), depth=1.4,
            Material="Metal")
    on_wall(m, g, "FountainBowl", "EI", 44, 3.9, 2.2, 0.15, (140, 150, 160), depth=1.2)
    # Trophy case on the classroom's north wall (hallway side; that wall has no windows).
    trophy_x = -23.5
    on_wall(m, g, "TrophyCase", "NI", trophy_x, 6, 7, 6, "door", depth=1.2)
    on_wall(m, g, "TrophyGlass", "NI", trophy_x, 6, 6.4, 5.4, (190, 220, 240), depth=0.1, out=1.2,
            Material="Glass", Transparency=0.6)
    _, coord, facing = WALLS["NI"]
    for i, dx in enumerate((-2.2, -0.7, 0.8, 2.3)):
        height = 1.2 + (i % 2) * 0.6
        m.cylinder(g, "Trophy", height, 0.7,
                   (trophy_x + dx, 4.4 + height / 2, coord + facing * 0.6), (240, 190, 50),
                   Material="Metal", Reflectance=0.3, **NO_HIT)
        m.cylinder(g, "TrophyBase", 0.4, 1, (trophy_x + dx, 4.25, coord + facing * 0.6),
                   (60, 40, 30), **NO_HIT)
    # School banner hanging over the north hallway.
    m.part(g, "Banner", (10, 3, 0.1), (-14, 15, -58), (130, 30, 40),
           children=[surface_text("Front", "TIGERS", (250, 200, 60), (130, 30, 40)),
                     surface_text("Back", "TIGERS", (250, 200, 60), (130, 30, 40))], **NO_HIT)
    for dx in (-4.5, 4.5):
        m.block(g, "BannerRod", -14 + dx - 0.05, -14 + dx + 0.05, 16.5, HEIGHT, -58.05, -57.95,
                "chain", **NO_HIT)
    # Trash cans in the corners (solid: vault them or go round).
    for x, z in ((41, -63), (-41, -63), (41, 63), (-41, 63)):
        m.cylinder(g, "TrashCan", 3.2, 2.4, (x, 1.6, z), (110, 115, 120), Material="Metal")
        m.cylinder(g, "TrashLid", 0.2, 2.6, (x, 3.3, z), (80, 85, 90), **NO_HIT)

    # Locker details: vents, handles and the seams between lockers.
    face = -IN_X + 2
    for i, z in enumerate(range(-48, 48, 3)):
        for y in (7.6, 8.0):
            m.block(g, "LockerVent", face, face + 0.05, y, y + 0.12, z + 0.6, z + 2.4, (30, 35, 45),
                    **NO_HIT)
        m.block(g, "LockerHandle", face, face + 0.15, 4.2, 5.2, z + 2.3, z + 2.55, (200, 200, 205),
                Material="Metal", **NO_HIT)
        m.block(g, "LockerSeam", face, face + 0.04, 0, 9, z - 0.05, z + 0.05, (25, 30, 40),
                **NO_HIT)
        if i % 5 == 2:  # a few name tags
            m.block(g, "NameTag", face, face + 0.04, 6.6, 7.1, z + 0.8, z + 2.2, (250, 250, 240),
                    **NO_HIT)

    # Baseboards along the hallway walls, and the ceiling tile grid.
    base = (60, 55, 50)
    for wall, s0, s1 in (("EO", -IN_Z, IN_Z), ("NO", -IN_X, IN_X), ("SO", -IN_X, IN_X),
                         ("WO", -IN_Z, -48), ("WO", 48, IN_Z), ("NI", -ROOM_X, ROOM_X),
                         ("SI", -ROOM_X, ROOM_X), ("EI", -ROOM_Z, 26), ("EI", 34, ROOM_Z),
                         ("WI", -ROOM_Z, -34), ("WI", -26, ROOM_Z)):
        on_wall(m, g, "Baseboard", wall, (s0 + s1) / 2, 0.3, s1 - s0, 0.6, base, depth=0.15)
    grid = (95, 97, 104)
    for x in range(-42, 43, 6):  # north and south hallways
        for z0, z1 in ((-IN_Z, -ROOM_Z), (ROOM_Z, IN_Z)):
            m.block(g, "CeilingGrid", x - 0.08, x + 0.08, HEIGHT - 0.04, HEIGHT, z0, z1, grid,
                    **NO_HIT)
    for z in range(-48, 49, 6):  # east and west hallways
        for x0, x1 in ((-IN_X, -ROOM_X), (ROOM_X, IN_X)):
            m.block(g, "CeilingGrid", x0, x1, HEIGHT - 0.04, HEIGHT, z - 0.08, z + 0.08, grid,
                    **NO_HIT)


def classroom_details(m):
    g = "ClassroomDetails"
    inner_x, inner_z = ROOM_X - WALL, ROOM_Z - WALL
    # Alphabet strip over the board, a clock, a world map, a flag.
    poster(m, g, "CN", 0, 13.2, 32, 1.4, (250, 250, 245),
           "Aa  Bb  Cc  Dd  Ee  Ff  Gg  Hh  Ii  Jj  Kk  Ll  Mm", (40, 60, 140))
    clock(m, g, "CN", 21, 14)
    on_wall(m, g, "WorldMap", "CE", -28, 11.5, 8, 5, (90, 160, 210), depth=0.08)
    for dx, dy, w, h in ((-2.2, 0.8, 2.4, 1.6), (0.4, 0.3, 1.6, 2.6), (2.6, 0.9, 2, 1.4),
                         (2.9, -1.3, 1.4, 1)):
        on_wall(m, g, "Continent", "CE", -28 + dx, 11.5 + dy, w, h, (110, 180, 90), depth=0.03,
                out=0.08)
    _, coord, facing = WALLS["CN"]
    m.cylinder(g, "FlagPole", 6, 0.2, (-21, 12, coord + facing * 0.8), (200, 190, 150),
               rot_z(70), **NO_HIT)
    for i, color in enumerate(((200, 40, 50), (245, 245, 245), (200, 40, 50))):
        m.part(g, "Flag", (3.2, 0.6, 0.05), (-19.6, 14.4 - i * 0.6, coord + facing * 0.9), color,
               **NO_HIT)
    # Papers scattered on the floor.
    for i, (x, z) in enumerate(((-20, -40), (-6, -30), (14, -36), (20, -8), (-18, 6), (-2, 12),
                                (16, 30), (-12, 34), (2, 42), (22, 40), (-22, -2), (8, -26))):
        m.part(g, "Paper", (1.3, 0.04, 1.7), (x, 0.13, z), (250, 250, 245), rot_y(i * 37 % 90 - 45),
               **NO_HIT)
    # A globe on top of a bookshelf.
    m.part(g, "GlobeStand", (0.8, 0.8, 0.8), (-23, 9.4, -18), (60, 50, 40), **NO_HIT)
    m.part(g, "Globe", (2, 2, 2), (-23, 10.8, -18), (70, 130, 200), Shape="Ball", **NO_HIT)
    # Ceiling fans (spinning).
    for z in (-34, 34):
        m.cylinder(g, "FanMotor", 0.8, 1.4, (-14, HEIGHT - 1, z), (60, 60, 64), **NO_HIT)
        m.block(g, "FanRod", -14.08, -13.92, HEIGHT - 0.6, HEIGHT, z - 0.08, z + 0.08, "chain",
                **NO_HIT)
        for angle in (0, 90):
            m.part(g, "FanBlade", (7, 0.12, 0.9), (-14, HEIGHT - 1.3, z), (150, 110, 70),
                   rot_y(angle), Material="Wood", attributes={"Spin": 220}, **NO_HIT)
    # Ceiling grid over the classroom.
    for x in range(-24, 25, 8):
        m.block(g, "CeilingGrid", x - 0.08, x + 0.08, HEIGHT - 0.04, HEIGHT, -inner_z, inner_z,
                (95, 97, 104), **NO_HIT)


def basement_details(m):
    g = "BasementDetails"
    cx0, cx1, cz0, cz1 = CHAMBER
    # Boiler in the chamber's north-east corner (solid; clear of the hole above).
    m.cylinder(g, "Boiler", 14, 7, (41.5, B_FLOOR + 7, -35), (140, 60, 45), Material="Metal")
    m.cylinder(g, "BoilerBand", 0.6, 7.3, (41.5, B_FLOOR + 3, -35), (60, 60, 64), **NO_HIT)
    m.cylinder(g, "BoilerBand", 0.6, 7.3, (41.5, B_FLOOR + 11, -35), (60, 60, 64), **NO_HIT)
    m.cylinder(g, "BoilerPipe", 6, 1.2, (41.5, B_FLOOR + 17, -35), "pipe", **NO_HIT)
    m.part(g, "Gauge", (0.2, 1.2, 1.2), (37.9, B_FLOOR + 8, -35), (240, 240, 235),
           Shape="Cylinder", **NO_HIT)
    # Crates in the north-west corner (solid).
    m.block(g, "Crate", cx0 + 0.5, cx0 + 4.5, B_FLOOR, B_FLOOR + 4, cz0 + 0.5, cz0 + 4.5, "desk")
    m.block(g, "Crate", cx0 + 1, cx0 + 4, B_FLOOR + 4, B_FLOOR + 7, cz0 + 1, cz0 + 4, "desk")
    m.block(g, "Crate", cx0 + 5, cx0 + 8, B_FLOOR, B_FLOOR + 3, cz0 + 0.5, cz0 + 3.5, "desk")
    # Hazard stripes round the updraft pad.
    for x0, x1, z0, z1 in ((30, 42, -18.5, -17.5), (30, 42, -6.5, -5.5), (29.5, 30.5, -18, -6),
                           (41.5, 42.5, -18, -6)):
        m.block(g, "HazardStripe", x0, x1, B_FLOOR, B_FLOOR + 0.62, z0, z1, "hazard", **NO_HIT)
    # Pipes along the walls and tunnels, with valve wheels.
    runs = (
        ((cx0 + 0.6, -6, cz0), (cx0 + 0.6, -6, cz1), 1.2, (70, 110, 70)),
        ((cx0 + 0.6, -8, cz0), (cx0 + 0.6, -8, cz1), 0.8, "pipe"),
        ((43.4, -13.6, 4), (43.4, -13.6, 46), 1.0, (70, 90, 140)),
        ((-30, -13.6, 46.7), (32, -13.6, 46.7), 0.9, (70, 110, 70)),
        ((-41.3, B_FLOOR, 40), (-41.3, -2, 40), 1.2, "pipe"),
    )
    for (ax, ay, az), (bx, by, bz), dia, color in runs:
        length = math.dist((ax, ay, az), (bx, by, bz))
        mid = ((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2)
        if ax != bx:
            rows = IDENTITY  # along X
        elif az != bz:
            rows = rot_y(90)  # along Z
        else:
            rows = rot_z(90)  # vertical
        m.cylinder(g, "Pipe", length, dia, mid, color, rows, Material="Metal", **NO_HIT)
    for x, y, z, rows in ((cx0 + 1.4, -6, -20, IDENTITY), (42.6, -13.6, 24, IDENTITY),
                          (0, -13.6, 47.6, rot_y(90))):
        m.part(g, "Valve", (0.25, 1.6, 1.6), (x, y, z), (200, 40, 40), rows, Shape="Cylinder",
               **NO_HIT)
    # Water dripping in the pipe room, and a puddle under it (just a puddle: no slip).
    m.block(g, "Drip", -36.2, -35.8, -2.4, -2.1, 40.8, 41.2, (90, 110, 130), **NO_HIT,
            children=[particles("Drips", rate=3, life=(0.6, 0.8), speed=(2, 4),
                                size=((0, 0.12), (1, 0.12)), transparency=((0, 0.2), (1, 0.4)),
                                color=(160, 200, 230), texture=SPARK, direction="Bottom",
                                spread=(0, 0), accel=(0, -60, 0))])


def build():
    m = Map()
    main_floor(m)
    basement(m)
    hallway_details(m)
    classroom_details(m)
    basement_details(m)
    # Spawns around the hallways and one in a classroom aisle (none next to the hole or grate).
    for x, z in ((-26, -58), (36, -58), (-36, -30), (-36, 6), (36, 32), (-30, 58), (34, 58),
                 (4.5, 7)):
        m.spawn(x, z)
    return m


def check(m):
    problems = []
    for i, (x, _, z) in enumerate(m.spawns):
        for j in range(i):
            px, _, pz = m.spawns[j]
            if math.hypot(x - px, z - pz) < 25:
                problems.append(f"spawns {j + 1} and {i + 1} are under 25 studs apart")
        for name, (x0, x1, z0, z1) in (("hole", HOLE), ("grate", GRATE)):
            if x0 - 3 <= x <= x1 + 3 and z0 - 3 <= z <= z1 + 3:
                problems.append(f"spawn {i + 1} is next to the {name}")
    return problems


def write(m):
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)

    def dump(name, data):
        with open(os.path.join(OUT, name), "w") as f:
            json.dump(data, f, indent=1)
            f.write("\n")

    dump("init.meta.json", {"className": "Model", "attributes": {
        "DisplayName": "School", "MinPlayers": 2, "MaxPlayers": 8, "InRotation": True,
        "Lighting": "Indoor"}})
    for group, children in m.groups.items():
        dump(f"{group}.model.json", {"className": "Folder", "children": children})
    spawns = []
    for i, (x, y, z) in enumerate(m.spawns):
        spawns.append({"name": f"Spawn{i + 1}", "className": "Part", "properties": {
            "Anchored": True, "CanCollide": False, "CanQuery": False, "CanTouch": False,
            "CastShadow": False, "Transparency": 1, "Size": [2, 1, 2],
            "CFrame": {"CFrame": {"position": [r(x), r(y + 0.5), r(z)],
                                  "orientation": IDENTITY}}}})
    dump("Spawns.model.json", {"className": "Folder", "children": spawns})


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    count = sum(len(v) for v in layout.groups.values())
    print(f"{count} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    write(layout)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
