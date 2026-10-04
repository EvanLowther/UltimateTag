#!/usr/bin/env python3
"""The School map (grey-box), from the user's blueprint. Run from the repo root:
    python3 tools/school_layout.py
It rewrites `src/maps/School/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south (north is -Z), Y up. Main floor at Y 0, basement floor at Y -22.

MAIN FLOOR: a long rectangle (north-south longer). A classroom in the middle with a ring of
16-wide hallways around it (the main loop).
  - West hallway: lockers on the outer wall (wall-run surface); a floor grate near the south end
    is one basement opening.
  - North hallway: a puddle across the whole width: walk or run in and you slip and fall (Slip);
    slide across to get through.
  - East hallway: a tipped lunch table in the middle of the hall ramps up toward a hole in the
    floor. Off the ramp, steer to either wall and wall-run across (south to north only). Miss and you fall into
    the basement.
  - South hallway: plain, closed off.
  - Classroom: doors on the west (north end) and east (south end), rows of desks to vault.
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
    "light": (235, 235, 220), "light_warm": (240, 170, 100), "door": (150, 100, 60),
}

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def rot_x(deg):
    """Turns about X: a part's -Z end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


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
            "Material": "SmoothPlastic", "TopSurface": "Smooth", "BottomSurface": "Smooth",
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
        axis, `span` = (s0, s1) along it. Openings: (s0, s1, top) cut from the floor up to top."""
        s0, s1 = span
        cuts = sorted(openings)
        pos = s0
        pieces = []
        for o0, o1, top in cuts:
            if o0 > pos:
                pieces.append((pos, o0, y0, y1))
            if top < y1:
                pieces.append((o0, o1, top, y1))  # lintel
            pos = o1
        if pos < s1:
            pieces.append((pos, s1, y0, y1))
        for a, b, lo, hi in pieces:
            if axis == "X":
                self.block(group, name, a, b, lo, hi, fixed[0], fixed[1], color)
            else:
                self.block(group, name, fixed[0], fixed[1], lo, hi, a, b, color)

    def light(self, group, x, y, z, size=(8, 0.2, 1), warm=False, brightness=0.5, reach=22):
        self.part(group, "Light", size, (x, y, z), "light_warm" if warm else "light",
                  Material="Neon", CanCollide=False, CanQuery=False, CastShadow=False,
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
    m.block(g, "Ceiling", -IN_X - WALL, IN_X + WALL, HEIGHT, HEIGHT + 1, -IN_Z - WALL, IN_Z + WALL,
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
    m.wall(c, "Z", (-ROOM_X, -ROOM_X + WALL), (-ROOM_Z, ROOM_Z), 0, HEIGHT, "wall", [west_door])
    m.wall(c, "Z", (ROOM_X - WALL, ROOM_X), (-ROOM_Z, ROOM_Z), 0, HEIGHT, "wall", [east_door])
    m.wall(c, "X", (-ROOM_Z, -ROOM_Z + WALL), (-ROOM_X + WALL, ROOM_X - WALL), 0, HEIGHT, "wall")
    m.wall(c, "X", (ROOM_Z - WALL, ROOM_Z), (-ROOM_X + WALL, ROOM_X - WALL), 0, HEIGHT, "wall")
    m.block(c, "ClassFloor", -ROOM_X + WALL, ROOM_X - WALL, 0, 0.1, -ROOM_Z + WALL, ROOM_Z - WALL,
            "room_floor", CanCollide=False, CanQuery=False)
    for z0, z1, x in ((-34, -26, -ROOM_X), (26, 34, ROOM_X)):  # door frames
        for zz in (z0, z1):
            m.block(c, "DoorFrame", x - 1.2, x + 1.2, 0, DOOR_H, zz - 0.4, zz + 0.4, "door",
                    CanCollide=False, CanQuery=False)
    inner_x, inner_z = ROOM_X - WALL, ROOM_Z - WALL  # 26, 48
    m.block(c, "Chalkboard", -16, 16, 5, 12, -inner_z, -inner_z + 0.3, "board",
            CanCollide=False, CanQuery=False)
    m.block(c, "TeacherDesk", -6, 6, 0, 3.5, -40, -36, "desk")
    for zi, z in enumerate(range(-28, 42, 10)):
        for xi, x in enumerate(range(-18, 19, 9)):
            if (zi + xi) % 5 == 3:  # a few gaps so the rows aren't a perfect grid
                continue
            m.block(c, "Desk", x - 2, x + 2, 0, 2.6, z - 1.5, z + 1.5, "desk")
            m.block(c, "DeskTop", x - 2.2, x + 2.2, 2.6, 3, z - 1.7, z + 1.7, "desk_top")

    # Hallway features.
    h = "Hallways"
    # West: a long run of lockers on the outer wall.
    for i, z in enumerate(range(-48, 48, 3)):
        m.block(h, "Locker", -IN_X, -IN_X + 2, 0, 9, z, z + 3,
                "locker_a" if i % 2 == 0 else "locker_b")
    # North: a puddle across the whole hallway (slip).
    m.block(h, "Puddle", -14, 14, 0, 0.12, -IN_Z, -ROOM_Z, "puddle", Material="Glass",
            Transparency=0.4, Reflectance=0.1, attributes={"Slip": 1.6})
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
    # South: a couple of benches to vault (closed-off plain hallway otherwise).
    for x in (-12, 14):
        m.block(h, "Bench", x - 4, x + 4, 0, 2.4, IN_Z - 3, IN_Z - 1, "desk")

    # Lights.
    for z in range(-56, 57, 16):
        m.light("Lights", -36, HEIGHT - 0.2, z, size=(1, 0.2, 8))
        m.light("Lights", 36, HEIGHT - 0.2, z, size=(1, 0.2, 8))
    for x in (-18, 0, 18):
        m.light("Lights", x, HEIGHT - 0.2, -58)
        m.light("Lights", x, HEIGHT - 0.2, 58)
    for x in (-13, 13):
        for z in (-30, 0, 30):
            m.light("Lights", x, HEIGHT - 0.2, z, size=(8, 0.2, 1), reach=26)


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
           attributes={"LaunchVelocity": {"Vector3": [0, 105, -40]}})
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
        m.light(g, x, TUNNEL_TOP - 0.5, (sz0 + sz1) / 2, warm=True, brightness=0.45, reach=20)
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


def build():
    m = Map()
    main_floor(m)
    basement(m)
    # Spawns around the hallways and one in a classroom aisle (none next to the hole or grate).
    for x, z in ((-26, -58), (36, -58), (-36, -30), (-36, 6), (36, 32), (-16, 58), (16, 58),
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
