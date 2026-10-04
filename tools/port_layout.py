#!/usr/bin/env python3
"""Layout for the Tag Island Port map (grey-box v1).

Edit the layout in `build()`, then run from the repo root:
    python3 tools/port_layout.py            # check + print the top-down view + write PortData
    python3 tools/port_layout.py --no-write # just check and print
    stylua src                              # format the generated file afterwards

It writes `src/tools/PortData.luau`, which `ServerStorage.Tools.BuildPortGreybox` turns into the
map `ServerStorage.Maps.TagIslandPort` in Studio. Axes: X east, Z south, Y up; the map is
centered on the origin, ground top at Y = 0. Sizes are in studs and follow the plan's scale rules.
"""
import math
import sys

HALF = 50  # the map is 100 x 100
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


def build():
    L = Layout()
    ground = 4.0
    L.add("Ground", "Ground", 0, -ground / 2, 0, 2 * HALF, ground, 2 * HALF, GROUND, Checked=False)

    # NW "Red Wall": dense 3-high stacks with 7-8 wide wall-run lanes.
    L.stack(-37, -40, "X", 18, ["red", "blue", "orange"])
    L.stack(-15, -40, "X", 18, ["orange", "teal"])
    L.stack(-41, -22, "Z", 18, ["yellow", "red", "white"])
    L.stack(-24, -26, "X", 18, ["teal", "red"])
    L.stack(-24, -10, "X", 18, ["blue"])

    # Center "Blue Deck": a low one-high yard of roofs, a slide-under container, vault props.
    L.stack(-2, -15, "X", 18, ["blue"])
    L.stack(20, -15, "X", 18, ["teal"])
    L.stack(1, 4, "Z", 18, ["red"])
    L.stack(-18, 6, "X", 18, ["white", "orange"])
    L.stack(14, 2, "Z", 18, ["green"], lift=LIFT)
    L.crate(-9, -6)
    L.sandbags(-6, -27)
    L.barrel(-8, 16)
    L.crate(26, 10)

    # NE "Tarp Alley": narrow lanes and a walk-through tunnel container.
    L.stack(22, -41, "X", 18, ["teal", "yellow"])
    L.stack(41, -38, "Z", 18, ["orange", "blue", "white"])
    L.stack(24, -28, "X", 18, [("red", "Tunnel")])
    L.stack(41, -16, "Z", 18, ["teal", "white"])
    L.stack(30, 0, "X", 18, ["yellow"])
    L.sandbags(6, -30)
    L.barrel(7, -45)

    # SE "Crane Corner": the gantry, tall stacks, a roof circuit.
    L.stack(40, 16, "Z", 18, ["red", "blue", "orange"])
    L.stack(40, 38, "Z", 18, ["white", "teal"])
    L.stack(23, 20, "X", 18, ["yellow", "red"])
    L.gantry(26, 30, 44)
    L.crate(14, 30)
    L.barrel(17, 37)

    # SW "Low Yard": scattered low boxes, barrels, wide lanes.
    L.stack(-37, 26, "X", 18, ["white"])
    L.stack(-20, 32, "Z", 18, ["blue", "orange"])
    L.stack(-36, 40, "X", 18, ["red"])
    L.stack(-4, 24, "X", 18, ["teal", "white"])
    L.crate(-33, 15)
    L.crate(-10, 42)
    L.sandbags(-24, 16)
    L.barrel(-4, 33)
    L.barrel(3, 40, "orange")

    # Light poles on the perimeter lane (decoration).
    for x, z in ((-47, -20), (47, 0), (10, 47), (-47, 30), (14, -47)):
        L.pole(x, z)

    # Eight spawns on the ground lanes, spread out.
    for x, z in ((-47, -47), (0, -47), (34, -47), (47, -12), (47, 20), (0, 47), (-48, 40),
                 (-48, 10)):
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
    cols = HALF  # one character = 2 studs
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
                x, z = -HALF + 2 * c + 1, -HALF + 2 * r + 1
                if b[1] <= x <= b[2] and b[5] <= z <= b[6]:
                    cur = grid[r][c]
                    order = ".:1PSG23"
                    if cur == "." or order.index(ch) > order.index(cur) if ch in order and cur in order else True:
                        grid[r][c] = ch
    for x, z in L.spawns:
        grid[int((z + HALF) // 2)][int((x + HALF) // 2)] = "@"
    return "\n".join("".join(row) for row in grid)


# ---- Luau output ---------------------------------------------------------------------------------

def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def write_luau(L, path):
    out = ["--!strict",
           "-- GENERATED by tools/port_layout.py. Don't edit by hand: change the script and run it again.",
           "-- Read by ServerStorage.Tools.BuildPortGreybox to build ServerStorage.Maps.TagIslandPort.",
           "local PortData = {}", "",
           'PortData.MapName = "TagIslandPort"',
           'PortData.DisplayName = "Tag Island Port"',
           "PortData.MinPlayers = 2", "PortData.MaxPlayers = 8", f"PortData.Half = {HALF}", "",
           "PortData.Parts = {"]
    for p in L.parts:
        fields = [f'Name = "{p["Name"]}"', f'Group = "{p["Group"]}"',
                  f'Position = Vector3.new({num(p["X"])}, {num(p["Y"])}, {num(p["Z"])})',
                  f'Size = Vector3.new({num(p["SX"])}, {num(p["SY"])}, {num(p["SZ"])})',
                  f'Color = Color3.fromRGB({p["Color"][0]}, {p["Color"][1]}, {p["Color"][2]})']
        if p.get("Shape"):
            fields.append(f'Shape = "{p["Shape"]}"')
        if p.get("Upright"):
            fields.append("Upright = true")
        if p.get("Invisible"):
            fields.append("Invisible = true")
        if p.get("SlideBlocker"):
            fields.append("SlideBlocker = true")
        if p.get("Glow"):
            fields.append("Glow = true")
        if p.get("Collide") is False:
            fields.append("Collide = false")
        out.append("\t{ " + ", ".join(fields) + " },")
    out += ["}", "", "PortData.Spawns = {"]
    for x, z in L.spawns:
        out.append(f"\tVector3.new({num(x)}, 0.5, {num(z)}),")
    out += ["}", "", "return PortData", ""]
    with open(path, "w") as f:
        f.write("\n".join(out))


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(top_view(layout))
    print()
    print(f"{len(layout.parts)} parts, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    if "--no-write" not in sys.argv:
        write_luau(layout, "src/tools/PortData.luau")
        print("wrote src/tools/PortData.luau")
    sys.exit(1 if issues else 0)
