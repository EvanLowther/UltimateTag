#!/usr/bin/env python3
"""Layout for the Tag Island Port map (grey-box v2, 250 x 250).

Edit the layout in `build()`, then run from the repo root:
    python3 tools/port_layout.py            # check + print the top-down view + write the map
    python3 tools/port_layout.py --no-write # just check and print

It writes the map as Rojo files in `src/maps/TagIslandPort/` (generated: don't edit them by hand),
so with Rojo connected the map updates in Studio by itself. Axes: X east, Z south, Y up; the map is
centered on the origin, ground top at Y = 0. Sizes are in studs and follow the plan's scale rules.
"""
import json
import math
import os
import shutil
import sys

HALF = 125  # the map is 250 x 250
U = 8.0  # one container's height
CW = 7.0  # container width
LIFT = 4.2  # slide-gap underside height (same as the test map's slide bar)

COLORS = {
    "red": (232, 70, 66),
    "orange": (255, 150, 45),
    "yellow": (255, 205, 60),
    "teal": (40, 190, 190),
    "blue": (62, 120, 230),
    "white": (240, 240, 232),
    "green": (80, 190, 110),
}
GROUND = (222, 204, 160)
WOOD = (196, 150, 96)
METAL = (150, 158, 170)


class Layout:
    def __init__(self):
        self.parts = []  # dicts for the Luau builder
        self.boxes = []  # (name, x0, x1, y0, y1, z0, z1, solid) for checks
        self.spawns = []
        self.count = {}

    def _name(self, prefix):
        self.count[prefix] = self.count.get(prefix, 0) + 1
        return f"{prefix}_{self.count[prefix]:02d}"

    def add(self, name, group, x, y, z, sx, sy, sz, color, **extra):
        part = {
            "Name": name, "Group": group, "X": x, "Y": y, "Z": z,
            "SX": sx, "SY": sy, "SZ": sz, "Color": color,
        }
        part.update(extra)
        self.parts.append(part)
        solid = part.get("Collide", True)
        self.boxes.append((name, x - sx / 2, x + sx / 2, y - sy / 2, y + sy / 2,
                           z - sz / 2, z + sz / 2, solid, part.get("Checked", True)))

    # A stack of containers. `levels` lists (color, kind) from the bottom; kind "Closed" is a solid
    # box, "Tunnel" is open at both ends (walk through it). `lift` raises the whole stack on end
    # crates with an invisible stand-blocker underneath (slide under it).
    def stack(self, x, z, dir, length, levels, lift=0.0):
        name = self._name("Stack")
        sx, sz = (length, CW) if dir == "X" else (CW, length)
        for i, level in enumerate(levels):
            color, kind = level if isinstance(level, tuple) else (level, "Closed")
            y0 = lift + i * U
            if kind == "Closed":
                self.add(f"{name}_L{i + 1}", "Containers", x, y0 + U / 2, z, sx, U, sz,
                         COLORS[color])
            else:  # Tunnel: two walls and a roof
                t = 0.4
                if dir == "X":
                    for s in (-1, 1):
                        self.add(f"{name}_L{i + 1}_Wall{'AB'[s > 0]}", "Containers", x,
                                 y0 + (U - t) / 2, z + s * (CW - t) / 2, length, U - t, t,
                                 COLORS[color])
                    self.add(f"{name}_L{i + 1}_Roof", "Containers", x, y0 + U - t / 2, z,
                             length, t, CW, COLORS[color])
                else:
                    for s in (-1, 1):
                        self.add(f"{name}_L{i + 1}_Wall{'AB'[s > 0]}", "Containers",
                                 x + s * (CW - t) / 2, y0 + (U - t) / 2, z, t, U - t, length,
                                 COLORS[color])
                    self.add(f"{name}_L{i + 1}_Roof", "Containers", x, y0 + U - t / 2, z,
                             CW, t, length, COLORS[color])
        if lift > 0:
            # End crates (not under the container's width: the sides stay open to slide through).
            if dir == "X":
                for s in (-1, 1):
                    self.add(f"{name}_Support{'AB'[s > 0]}", "Containers", x + s * (length / 2 - 1.5),
                             lift / 2, z, 3, lift, CW, WOOD)
                self.add(f"{name}_StandBlocker", "Blockers", x, lift / 2, z, length - 6, lift, CW,
                         (255, 255, 255), Collide=True, Invisible=True, SlideBlocker=True)
            else:
                for s in (-1, 1):
                    self.add(f"{name}_Support{'AB'[s > 0]}", "Containers", x,
                             lift / 2, z + s * (length / 2 - 1.5), CW, lift, 3, WOOD)
                self.add(f"{name}_StandBlocker", "Blockers", x, lift / 2, z, CW, lift, length - 6,
                         (255, 255, 255), Collide=True, Invisible=True, SlideBlocker=True)

    def crate(self, x, z, size=(4, 3.5, 4), color=WOOD):
        self.add(self._name("Crate"), "Props", x, size[1] / 2, z, size[0], size[1], size[2], color)

    def sandbags(self, x, z, dir="X"):
        sx, sz = (6, 2) if dir == "X" else (2, 6)
        self.add(self._name("Sandbags"), "Props", x, 1.25, z, sx, 2.5, sz, (206, 186, 140))

    def barrel(self, x, z, color="red"):
        self.add(self._name("Barrel"), "Props", x, 1.75, z, 3, 3.5, 3, COLORS[color],
                 Shape="Cylinder", Upright=True)

    def pole(self, x, z):
        self.add(self._name("LightPole"), "Props", x, 15, z, 1, 30, 1, METAL, Shape="Cylinder",
                 Upright=True)
        self.add(self._name("LightHead"), "Props", x, 30.5, z, 4, 1, 2, (255, 240, 170),
                 Glow=True, Collide=False, Checked=False)

    # Crane gantry: two legs and a top beam running along Z (decoration plus a climbable leg).
    def gantry(self, x, z0, z1, height=26.0):
        name = self._name("Gantry")
        for i, z in enumerate((z0, z1)):
            self.add(f"{name}_Leg{i + 1}", "Gantry", x, height / 2, z, 3, height, 3, COLORS["yellow"])
        mid = (z0 + z1) / 2
        self.add(f"{name}_Beam", "Gantry", x, height + 1.5, mid, 3, 3, abs(z1 - z0) + 3,
                 COLORS["yellow"])

    def spawn(self, x, z):
        self.spawns.append((x, z))


def block(L, cx, cz, items, rot=False):
    """Places a block's items, given as offsets from the block center (cx, cz). With `rot` the
    block is turned 90 degrees (offsets and directions swapped), so one pattern can be reused."""
    for item in items:
        kind, dx, dz = item[0], item[1], item[2]
        if rot:
            dx, dz = dz, dx
        x, z = cx + dx, cz + dz
        if kind == "S":
            direction = item[3]
            if rot:
                direction = "Z" if direction == "X" else "X"
            L.stack(x, z, direction, item[4], item[5], item[6] if len(item) > 6 else 0.0)
        elif kind == "C":
            L.crate(x, z)
        elif kind == "Q":
            direction = item[3] if len(item) > 3 else "X"
            if rot:
                direction = "Z" if direction == "X" else "X"
            L.sandbags(x, z, direction)
        elif kind == "B":
            L.barrel(x, z, item[3] if len(item) > 3 else "red")
        elif kind == "P":
            L.pole(x, z)
        elif kind == "G":
            z0, z1 = item[3], item[4]
            if rot:
                raise ValueError("gantry blocks can't be rotated")
            L.gantry(x, cz + z0, cz + z1)


# Block patterns: offsets inside a 58 x 58 block. Rows 7 wide with 8-stud gaps are wall-run
# corridors (and 8-stud roof jumps); 1-2-3 stacks next to each other are roof staircases.
RED_WALL = [  # three long rows of tall stacks
    ("S", -10, -19, "X", 36, ["red", "blue", "orange"]),
    ("S", 21, -19, "X", 18, ["teal"]),
    ("S", -10, -4, "X", 36, ["teal", "red"]),
    ("S", 21, -4, "X", 18, ["yellow", "white"]),
    ("S", 5, 11, "X", 36, ["orange", "blue", "white"]),
    ("C", -22, 11),
    ("S", -18, 25, "X", 18, ["green"]),
    ("Q", 12, 25, "X"),
]
YARD = [  # scattered low boxes with room to weave
    ("S", -16, -16, "Z", 18, ["white"]),
    ("S", 8, -20, "X", 18, ["blue", "orange"]),
    ("S", 19, 4, "Z", 18, ["red"]),
    ("S", -12, 10, "X", 18, ["yellow", "teal"]),
    ("S", 6, 23, "X", 18, ["green"]),
    ("C", -1, -5),
    ("B", -23, 23, "orange"),
    ("Q", -25, -2, "Z"),
    ("B", 25, -12),
]
TUNNELS = [  # walk-through containers, a slide-under one, tight lanes
    ("S", -14, -16, "X", 18, [("red", "Tunnel")]),
    ("S", 12, -16, "X", 18, [("blue", "Tunnel"), "orange"]),
    ("S", -14, 0, "X", 18, ["teal", "white"]),
    ("S", 13, 2, "X", 18, ["yellow"], 4.2),
    ("S", -3, 17, "Z", 18, ["red", "blue"]),
    ("S", 20, 20, "Z", 18, [("orange", "Tunnel")]),
    ("C", -20, 16),
    ("B", 8, 24, "yellow"),
]
TOWER = [  # a 3-high tower with a 1-2-3 roof staircase
    ("S", 0, 0, "X", 18, ["red", "blue", "yellow"]),
    ("S", 0, -12, "X", 18, ["white", "teal"]),
    ("S", 0, -24, "X", 18, ["orange"]),
    ("S", 0, 12, "X", 18, ["green"]),
    ("S", -21, 3, "Z", 18, ["blue", "red"]),
    ("S", 21, -5, "Z", 18, ["yellow"]),
    ("C", -20, -20),
    ("Q", 20, 18, "X"),
    ("B", -16, 22, "teal"),
]
CRANE = [  # a crane gantry over a container yard
    ("G", 0, 0, -26, 26),
    ("S", -11, -12, "Z", 18, ["red", "blue"]),
    ("S", 11, -13, "Z", 18, ["white", "yellow", "red"]),
    ("S", -11, 14, "Z", 18, ["orange"]),
    ("S", 11, 12, "Z", 18, ["teal"]),
    ("C", -22, 0),
    ("B", 22, 1, "blue"),
    ("Q", 0, 5, "Z"),
]
PLAZA = [  # the center: low roofs around a slide-under container
    ("S", -17, -18, "X", 18, ["blue"]),
    ("S", 17, -18, "X", 18, ["teal"]),
    ("S", -17, 18, "X", 18, ["red"]),
    ("S", 17, 18, "X", 18, ["yellow", "white"]),
    ("S", 0, 0, "X", 18, ["green"], 4.2),
    ("C", 0, -11),
    ("Q", -14, 6, "Z"),
    ("B", 14, -8),
    ("B", -3, 10, "orange"),
]


def build():
    L = Layout()
    ground = 4.0
    L.add("Ground", "Ground", 0, -ground / 2, 0, 2 * HALF, ground, 2 * HALF, GROUND, Checked=False)

    # Nine blocks; centers are offset so the avenues between them (22-28 wide) don't line up into
    # one big grid, and every block plays differently.
    block(L, -84, -84, RED_WALL)  # NW "Red Wall"
    block(L, 0, -86, TUNNELS)  # N "Tarp Alley"
    block(L, 85, -82, TOWER)  # NE tower
    block(L, -86, 0, YARD)  # W low yard
    block(L, 0, 2, PLAZA)  # center "Blue Deck"
    block(L, 86, -2, RED_WALL, rot=True)  # E rows, turned
    block(L, -82, 86, TOWER, rot=True)  # SW tower, turned
    block(L, 2, 85, YARD, rot=True)  # S yard, turned
    block(L, 84, 84, CRANE)  # SE "Crane Corner"

    # The avenues: vault props to hop while sprinting, and two slide-under containers across
    # the middle of an avenue (go under, or around through a block).
    L.stack(-43, -44, "Z", 18, ["white"], LIFT)
    L.stack(44, 42, "X", 18, ["red"], LIFT)
    for x, z in ((-43, 20), (43, -40), (-20, -43), (24, 43), (-62, 44), (62, -44)):
        L.crate(x, z)
    for x, z, d in ((-43, -12, "Z"), (43, 18, "Z"), (10, -43, "X"), (-28, 44, "X")):
        L.sandbags(x, z, d)
    for x, z, c in ((44, -14, "blue"), (-44, 50, "orange"), (-6, 44, "yellow"), (58, 47, "teal")):
        L.barrel(x, z, c)

    # Light poles along the avenues and the edge lane.
    for x, z in ((-43, -60), (43, -66), (-43, 66), (43, 62), (-64, -43), (66, 43), (-118, 0),
                 (118, 20), (0, -118), (-10, 118)):
        L.pole(x, z)

    # Eight spawns around the edge lane, far apart.
    for x, z in ((-118, -40), (-40, -118), (42, -118), (118, -42), (118, 44), (40, 118),
                 (-42, 118), (-118, 42)):
        L.spawn(x, z)
    return L


# ---- checks --------------------------------------------------------------------------------------

def overlap(a, b):
    eps = 0.01
    return (a[1] < b[2] - eps and b[1] < a[2] - eps and a[3] < b[4] - eps and b[3] < a[4] - eps
            and a[5] < b[6] - eps and b[5] < a[6] - eps)


def check(L):
    problems = []
    solid = [b for b in L.boxes if b[7] and b[8] and b[0] != "Ground"]
    for i, a in enumerate(solid):
        for b in solid[i + 1:]:
            if overlap(a, b):
                problems.append(f"overlap: {a[0]} and {b[0]}")
    for b in solid:
        if b[1] < -HALF or b[2] > HALF or b[5] < -HALF or b[6] > HALF:
            problems.append(f"out of bounds: {b[0]}")
    # Ground-level gaps between footprints (lanes): flag any narrower than 3 studs.
    foot = [b for b in solid if b[3] <= 0.01 and not b[0].startswith(("LightPole", "Stack_"))
            or (b[3] <= 0.01 and b[0].startswith("Stack_") and "StandBlocker" not in b[0])]
    seen = set()
    for i, a in enumerate(foot):
        for b in foot[i + 1:]:
            gx = max(a[1] - b[2], b[1] - a[2])
            gz = max(a[5] - b[6], b[5] - a[6])
            if gx < 0 and gz < 0:
                continue
            gap = max(gx, gz) if (gx < 0 or gz < 0) else math.hypot(gx, gz)
            key = ("_".join(a[0].split("_")[:2]), "_".join(b[0].split("_")[:2]))
            if gap < 3.0 and key[0] != key[1] and key not in seen and gap > -0.01:
                seen.add(key)
                problems.append(f"narrow lane {gap:.1f}: {key[0]} / {key[1]}")
    # Spawns: clear of everything, 25+ apart.
    for i, (x, z) in enumerate(L.spawns):
        for b in solid:
            if b[3] < 3 and b[1] - 1.5 < x < b[2] + 1.5 and b[5] - 1.5 < z < b[6] + 1.5:
                problems.append(f"spawn {i + 1} ({x}, {z}) is inside or touching {b[0]}")
        for j in range(i):
            d = math.hypot(x - L.spawns[j][0], z - L.spawns[j][1])
            if d < 25:
                problems.append(f"spawns {j + 1} and {i + 1} only {d:.0f} apart")
    return problems


def top_view(L):
    cols = 50
    cell = 2 * HALF / cols  # studs per character
    grid = [["." for _ in range(cols)] for _ in range(cols)]
    for b in L.boxes:
        if b[0] == "Ground" or not b[7]:
            continue
        top = b[4]
        ch = ":" if top <= 4.6 else "1" if top <= 8.1 else "2" if top <= 16.1 else "3" if top <= 24.1 else "G"
        if b[0].startswith("LightPole"):
            ch = "P"
        for r in range(cols):
            for c in range(cols):
                x, z = -HALF + cell * (c + 0.5), -HALF + cell * (r + 0.5)
                if b[1] <= x <= b[2] and b[5] <= z <= b[6]:
                    cur = grid[r][c]
                    order = ".:1PSG23"
                    if cur == "." or order.index(ch) > order.index(cur) if ch in order and cur in order else True:
                        grid[r][c] = ch
    for x, z in L.spawns:
        grid[int((z + HALF) // cell)][int((x + HALF) // cell)] = "@"
    return "\n".join("".join(row) for row in grid)


# ---- Rojo output ---------------------------------------------------------------------------------

MAP_DIR = "src/maps/TagIslandPort"
IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
UPRIGHT = [[0, -1, 0], [1, 0, 0], [0, 0, 1]]  # turns a cylinder's length (X) to point up
WALL_HEIGHT = 60
OCEAN = (40, 170, 210)


def rnd(v):
    return round(v, 3)


def color(rgb):
    return [rnd(c / 255) for c in rgb]


def cframe(x, y, z, rows=IDENTITY):
    return {"CFrame": {"position": [rnd(x), rnd(y), rnd(z)],
                       "orientation": [[rnd(v) for v in row] for row in rows]}}


def facing_center(x, z):
    """Rotation rows for a part at (x, z) looking at the map center (like CFrame.lookAt)."""
    fx, fz = -x, -z
    length = math.hypot(fx, fz) or 1.0
    fx, fz = fx / length, fz / length
    zx, zz = -fx, -fz  # ZVector points backwards
    xx, xz = zz, -zx  # XVector = up x ZVector
    return [[xx, 0, zx], [0, 1, 0], [xz, 0, zz]]


def rojo_part(name, size, pos, rgb, rows=IDENTITY, **props):
    base = {
        "Anchored": True,
        "Size": [rnd(v) for v in size],
        "Color": color(rgb),
        "Material": "SmoothPlastic",
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
        "CFrame": cframe(*pos, rows=rows),
    }
    attributes = props.pop("attributes", None)
    base.update(props)
    node = {"name": name, "className": "Part", "properties": base}
    if attributes:
        node["attributes"] = attributes
    return node


def to_rojo(p):
    props = {}
    size = (p["SX"], p["SY"], p["SZ"])
    rows = IDENTITY
    if p.get("Shape") == "Cylinder":
        props["Shape"] = "Cylinder"
        if p.get("Upright"):
            size = (p["SY"], p["SX"], p["SZ"])
            rows = UPRIGHT
    if p.get("Collide") is False:
        props["CanCollide"] = False
    if p.get("Invisible"):
        props["Transparency"] = 1
        props["CastShadow"] = False
    if p.get("Glow"):
        props["Material"] = "Neon"
        props["CastShadow"] = False
    if p.get("SlideBlocker"):
        props["attributes"] = {"SlideBlocker": True}
    return rojo_part(p["Name"], size, (p["X"], p["Y"], p["Z"]), p["Color"], rows, **props)


def write_rojo(L, out_dir=MAP_DIR):
    """Writes the map as Rojo files (one folder per group), so Rojo syncs it into
    ServerStorage.Maps.TagIslandPort by itself. The folder is generated: it's replaced each run."""
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)

    def dump(name, data):
        with open(os.path.join(out_dir, name), "w") as f:
            json.dump(data, f, indent=1)
            f.write("\n")

    dump("init.meta.json", {
        "className": "Model",
        "attributes": {"DisplayName": "Tag Island Port", "MinPlayers": 2, "MaxPlayers": 8,
                       "InRotation": True},
    })
    groups = {}
    for p in L.parts:
        groups.setdefault(p["Group"], []).append(to_rojo(p))
    for group, children in groups.items():
        dump(f"{group}.model.json", {"className": "Folder", "children": children})

    walls = []
    for i, (sx, sz, x, z) in enumerate((
            (2, 2 * HALF + 4, HALF + 1, 0), (2, 2 * HALF + 4, -HALF - 1, 0),
            (2 * HALF + 4, 2, 0, HALF + 1), (2 * HALF + 4, 2, 0, -HALF - 1))):
        walls.append(rojo_part(f"Wall{i + 1}", (sx, WALL_HEIGHT, sz), (x, WALL_HEIGHT / 2, z),
                               (255, 255, 255), Transparency=1, CastShadow=False))
    walls.append(rojo_part("Ocean", (1000, 1, 1000), (0, -3, 0), OCEAN, Transparency=0.15,
                           Reflectance=0.05, CanCollide=False, CanQuery=False, CanTouch=False,
                           CastShadow=False))
    dump("Boundary.model.json", {"className": "Folder", "children": walls})

    spawns = [rojo_part(f"Spawn{i + 1}", (2, 1, 2), (x, 0.5, z), (255, 255, 255),
                        facing_center(x, z), Transparency=1, CanCollide=False, CanQuery=False,
                        CanTouch=False, CastShadow=False)
              for i, (x, z) in enumerate(L.spawns)]
    dump("Spawns.model.json", {"className": "Folder", "children": spawns})


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(top_view(layout))
    print()
    print(f"{len(layout.parts)} parts, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    if "--no-write" not in sys.argv:
        write_rojo(layout)
        print(f"wrote {MAP_DIR}/ (Rojo syncs it into ServerStorage.Maps)")
    sys.exit(1 if issues else 0)
