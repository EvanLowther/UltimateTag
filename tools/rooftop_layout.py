#!/usr/bin/env python3
"""Rooftop Quad (grey-box): four skyscrapers in a 2x2 grid around a central canyon, neon night.

Run from the repo root:
    python3 tools/rooftop_layout.py
It rewrites `src/maps/RooftopQuad/` (generated: don't edit those files by hand), and Rojo syncs
the map into Studio by itself. Axes: X east, Z south, Y up, centered on the origin.

Sized for the moves: sprint about 30 studs/s, sprint jump about 16 studs on the flat and about
22 when dropping 12, wall run about 48 studs, Mantle Boost about 38, wall-climb hop 12, jump
reach for a mantle about 10 above your feet. The canyon is 20 wide, so a plain jump only crosses
going down a level; same-level and upward crossings need a move, a gadget or a bridge.

Buildings (roof heights): A north-west 100 (construction), B north-east 112 (helipad),
C south-east 96 (dishes), D south-west 84 (fans, launch pads).
Routes: A->B crane boom (walk) or I-beam (then mantle up 12); B->C billboard wall run (drop 16);
C<->D pipe bridge (slope); D->A launch pads; any roof -> a lower one by a jump.
Falling below KillHeight kills you; you respawn on a roof (server/MapRespawn).
"""
import json
import math
import os
import shutil

OUT = "src/maps/RooftopQuad"
HALF_BUILDING = 32  # buildings are 64 x 64
CANYON = 20  # gap between buildings
CENTER = HALF_BUILDING + CANYON / 2  # building centers at +/-42
EDGE = CENTER + HALF_BUILDING  # outer edges at +/-74
KILL_HEIGHT = 60

ROOF = {"A": 100, "B": 112, "C": 96, "D": 84}
SPOT = {"A": (-CENTER, -CENTER), "B": (CENTER, -CENTER), "C": (CENTER, CENTER),
        "D": (-CENTER, CENTER)}
NEON = {"A": (255, 140, 40), "B": (40, 220, 255), "C": (255, 60, 200), "D": (90, 110, 255)}
WINDOW_COLORS = [(255, 210, 120), (120, 220, 255), (255, 120, 220), (255, 240, 200)]

BODY = (44, 48, 64)
ROOF_TOP = (70, 74, 92)
STEEL = (150, 156, 170)
YELLOW = (255, 200, 40)
WOOD = (176, 128, 80)
UNIT = (120, 126, 140)
STREET = (24, 26, 34)

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def rot_z(deg):
    """Turns about Z: a part's +X end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def rot_x(deg):
    """Turns about X: a part's -Z end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


UPRIGHT = rot_z(90)  # a cylinder's length (X) pointing up


def r(v):
    return round(v, 3)


class Map:
    def __init__(self):
        self.groups = {}
        self.spawns = []
        self.names = {}

    def _unique(self, name):
        n = self.names.get(name, 0) + 1
        self.names[name] = n
        return name if n == 1 else f"{name}{n}"

    def part(self, group, name, size, pos, color, rows=IDENTITY, children=None, **props):
        attributes = props.pop("attributes", None)
        properties = {
            "Anchored": True,
            "Size": [r(v) for v in size],
            "Color": [r(c / 255) for c in color],
            "Material": "SmoothPlastic",
            "TopSurface": "Smooth",
            "BottomSurface": "Smooth",
            "CFrame": {"CFrame": {"position": [r(v) for v in pos],
                                  "orientation": [[r(v) for v in row] for row in rows]}},
        }
        properties.update(props)
        node = {"name": self._unique(name), "className": "Part", "properties": properties}
        if attributes:
            node["attributes"] = attributes
        if children:
            node["children"] = children
        self.groups.setdefault(group, []).append(node)
        return node

    def box(self, group, name, x, y0, z, sx, sy, sz, color, **props):
        """A block standing on y0 (its bottom), centered at x, z."""
        return self.part(group, name, (sx, sy, sz), (x, y0 + sy / 2, z), color, **props)

    def neon(self, group, name, size, pos, color, rows=IDENTITY):
        """Glowing trim: no collision, ignored by move raycasts."""
        return self.part(group, name, size, pos, color, rows, Material="Neon", CanCollide=False,
                         CanQuery=False, CanTouch=False, CastShadow=False)

    def cylinder(self, group, name, length, diameter, pos, color, rows=UPRIGHT, **props):
        return self.part(group, name, (length, diameter, diameter), pos, color, rows,
                         Shape="Cylinder", **props)

    def spawn(self, x, y, z):
        self.spawns.append((x, y, z))


def text_gui(face, text, color, background):
    """A SurfaceGui with one big glowing label (billboard and sign text)."""
    return {
        "name": f"Sign{face}", "className": "SurfaceGui",
        "properties": {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": 25,
                       "LightInfluence": 0, "Brightness": 2.5},
        "children": [{
            "name": "Text", "className": "TextLabel",
            "properties": {"Size": {"UDim2": [[1, 0], [1, 0]]}, "BackgroundColor3": [r(c / 255) for c in background],
                           "BackgroundTransparency": 0.15, "Text": text, "TextScaled": True,
                           "RichText": True, "Font": "Arcade",
                           "TextColor3": [r(c / 255) for c in color]},
        }],
    }


# ---- buildings -----------------------------------------------------------------------------------

def building(m, key):
    cx, cz = SPOT[key]
    top = ROOF[key]
    g = f"Building{key}"
    m.box(g, "Body", cx, 0, cz, 2 * HALF_BUILDING, top - 1, 2 * HALF_BUILDING, BODY)
    m.box(g, "Roof", cx, top - 1, cz, 2 * HALF_BUILDING, 1, 2 * HALF_BUILDING, ROOF_TOP)

    # Window bands on all four faces, and neon trim around the roof edge.
    length = 2 * HALF_BUILDING - 8
    for i, y in enumerate(range(10, int(top) - 6, 12)):
        color = WINDOW_COLORS[(i + "ABCD".index(key)) % len(WINDOW_COLORS)]
        for sx, sz, dx, dz in ((length, 0.4, 0, -1), (length, 0.4, 0, 1), (0.4, length, -1, 0),
                               (0.4, length, 1, 0)):
            m.neon(g, "Windows", (sx, 2.4, sz),
                   (cx + dx * (HALF_BUILDING + 0.2), y, cz + dz * (HALF_BUILDING + 0.2)), color)
    edge = 2 * HALF_BUILDING + 1
    for sx, sz, dx, dz in ((edge, 0.6, 0, -1), (edge, 0.6, 0, 1), (0.6, edge, -1, 0),
                           (0.6, edge, 1, 0)):
        m.neon(g, "EdgeTrim", (sx, 0.6, sz),
               (cx + dx * (HALF_BUILDING + 0.3), top - 0.3, cz + dz * (HALF_BUILDING + 0.3)),
               NEON[key])

    # Outer edges: a parapet too tall to vault (5.5) plus an invisible wall, so you can't fall
    # off the outside. The canyon sides stay open.
    outer_x = -1 if cx < 0 else 1
    outer_z = -1 if cz < 0 else 1
    wall = 120
    m.box(g, "Parapet", cx + outer_x * (HALF_BUILDING - 1), top, cz, 2, 5.5, 2 * HALF_BUILDING,
          ROOF_TOP)
    m.box(g, "Parapet", cx, top, cz + outer_z * (HALF_BUILDING - 1), 2 * HALF_BUILDING, 5.5, 2,
          ROOF_TOP)
    m.box(g, "EdgeWall", cx + outer_x * (HALF_BUILDING + 1), top, cz, 2, wall,
          2 * HALF_BUILDING + 4, (255, 255, 255), Transparency=1, CastShadow=False)
    m.box(g, "EdgeWall", cx, top, cz + outer_z * (HALF_BUILDING + 1), 2 * HALF_BUILDING + 4, wall,
          2, (255, 255, 255), Transparency=1, CastShadow=False)


def ac_unit(m, g, x, y, z, sx=6, sz=6):
    """Chest-height AC box (4 tall: you vault or step onto it)."""
    m.box(g, "ACUnit", x, y, z, sx, 4, sz, UNIT)
    m.cylinder(g, "ACFan", 0.4, min(sx, sz) - 1.5, (x, y + 4.2, z), (60, 64, 76),
               CanCollide=False, CanQuery=False)


def solar_slide(m, g, x, z, along, top, toward, length=24, width=10, angle=12):
    """An angled solar panel row whose low end sits at a canyon edge: running down it and jumping
    gives a SpeedBoost. `along` "X" or "Z"; `toward` -1/+1 is the direction of the low end."""
    rise = math.sin(math.radians(angle)) * length / 2
    run = math.cos(math.radians(angle)) * length / 2
    if along == "X":
        rows = rot_z(angle * -toward)
        pos = (x - toward * run, top + rise + 0.2, z)
        size = (length, 0.6, width)
    else:
        rows = rot_x(angle * toward)
        pos = (x, top + rise + 0.2, z - toward * run)
        size = (width, 0.6, length)
    m.part(g, "SolarSlide", size, pos, (40, 60, 140), rows,
           attributes={"SpeedBoost": 44})


def build():
    m = Map()
    for key in "ABCD":
        building(m, key)

    # ---- A: construction site (north-west, roof 100) ----
    g, top = "BuildingA", ROOF["A"]
    deck_x, deck_z, deck = -29, -46, 22
    m.box(g, "SteelDeck", deck_x, top + 11, deck_z, deck, 1, deck, STEEL)  # walk level 112
    for dx in (-1, 1):
        for dz in (-1, 1):
            m.box(g, "Column", deck_x + dx * (deck / 2 - 0.75), top, deck_z + dz * (deck / 2 - 0.75),
                  1.5, 24, 1.5, YELLOW)
    for dz in (-1, 1):  # open frame above the deck
        m.box(g, "TopBeam", deck_x, top + 23, deck_z + dz * (deck / 2 - 0.75), deck, 1.5, 1.5,
              YELLOW)
    m.box(g, "WoodPlatform", -46, top + 5, -46, 8, 1, 8, WOOD)  # 6 up: mantle, then 6 to the deck
    m.box(g, "WoodPost", -46, top, -46, 2, 5, 2, WOOD)
    # Crane: a climbable tower, the boom walkway east to B's roof at 112, a counter-jib.
    m.box(g, "CraneTower", deck_x, top, -61, 4, 40, 4, YELLOW)
    m.box(g, "CraneBoom", (deck_x + deck / 2 + 12) / 2, top + 10.5, deck_z,
          12 - (deck_x + deck / 2), 1.5, 3, YELLOW)  # deck edge to 2 studs onto B's roof
    m.box(g, "CraneJib", deck_x - 6, top + 38, -61, 30, 2, 2, YELLOW)
    m.box(g, "CraneWeight", deck_x - 18, top + 33, -61, 6, 5, 4, (90, 90, 100))
    # I-beam at roof level to B's wall (then mantle up 12 onto B).
    m.box(g, "IBeam", 0, top - 1, -24, 22, 1, 2, STEEL)
    solar_slide(m, g, -58, -10, "Z", top, 1)  # toward D (drop 16 across the canyon)
    ac_unit(m, g, -60, top, -30)
    m.box(g, "Crates", -20, top, -22, 4, 3.5, 4, WOOD)
    m.spawn(-62, top, -62)
    m.spawn(-34, top, -22)

    # ---- B: helipad and solar roof (north-east, roof 112) ----
    g, top = "BuildingB", ROOF["B"]
    m.cylinder(g, "Helipad", 1, 26, (52, top + 0.5, -52), (60, 64, 80))
    m.neon(g, "HelipadRing", (0.2, 27, 27), (52, top + 0.6, -52), YELLOW, UPRIGHT)
    for size, pos in (((1.6, 0.2, 10), (48, top + 1.05, -52)), ((1.6, 0.2, 10), (56, top + 1.05, -52)),
                      ((8, 0.2, 1.6), (52, top + 1.05, -52))):
        m.neon(g, "HelipadH", size, pos, YELLOW)
    solar_slide(m, g, 10, -28, "X", top, -1)  # toward A (drop 12)
    ac_unit(m, g, 66, top, -24)
    ac_unit(m, g, 24, top, -62, 8, 5)
    m.neon(g, "BillboardLane", (2, 0.2, 18), (39, top + 0.1, -19), NEON["B"])  # run here, then off
    m.spawn(66, top, -64)
    m.spawn(60, top, -24)

    # ---- Billboard between B and C: wall-run along it, B (112) down to C (96) ----
    board_x = 42
    m.part("Billboard", "Board", (2, 22, 30), (board_x, ROOF["C"] + 11, 3), (30, 30, 50),
           children=[text_gui("Left", "BILLBOARD RUN<br/>WALL-RUN REQUIRED", (255, 80, 220),
                              (20, 10, 40)),
                     text_gui("Right", "BILLBOARD RUN<br/>WALL-RUN REQUIRED", (80, 230, 255),
                              (10, 20, 40))])
    for z in (-6, 12):
        m.neon("Billboard", "Frame", (2.4, 0.6, 30), (board_x, ROOF["C"] + (22 if z < 0 else 0.3), 3),
               (255, 60, 200))
    m.box("Billboard", "Support", board_x, ROOF["C"], 16, 2, 22, 2, STEEL)

    # ---- C: dishes and AC (south-east, roof 96) ----
    g, top = "BuildingC", ROOF["C"]
    for x, z in ((62, 30), (62, 46), (52, 62)):
        m.box(g, "DishPost", x, top, z, 1.2, 5, 1.2, STEEL)
        m.cylinder(g, "Dish", 0.8, 8, (x, top + 6.5, z), (210, 214, 224), rot_z(60),
                   CanCollide=False, CanQuery=False)
    ac_unit(m, g, 28, top, 60)
    ac_unit(m, g, 66, top, 64, 5, 8)
    m.box(g, "Crates", 30, top, 30, 4, 3.5, 4, WOOD)
    m.spawn(64, top, 22)
    m.spawn(26, top, 46)

    # ---- Pipe bridge C (96) <-> D (84): three pipes and a walk plate, sloped ----
    run, rise = 28, ROOF["C"] - ROOF["D"]
    slope = math.degrees(math.atan2(rise, run))
    length = math.hypot(run, rise)
    mid_y = (ROOF["C"] + ROOF["D"]) / 2
    for dz, color in ((-3, (255, 70, 70)), (0, (60, 200, 90)), (3, (60, 120, 255))):
        m.cylinder("Pipes", "Pipe", length, 2.6, (0, mid_y - 1.6, 42 + dz), color, rot_z(slope))
    m.part("Pipes", "WalkPlate", (length, 0.5, 9), (0, mid_y + 0.25, 42), (110, 116, 130),
           rot_z(slope))

    # ---- D: fans and launch pads (south-west, roof 84) ----
    g, top = "BuildingD", ROOF["D"]
    for x in (-60, -44):
        m.box(g, "ExhaustFan", x, top, 58, 10, 4, 10, UNIT)
        m.neon(g, "FanGlow", (0.3, 8, 8), (x, top + 4.2, 58), NEON["D"], UPRIGHT)
    # Pads throw you north over the canyon onto A (16 higher): about 34 studs, peak about 23 up.
    for x in (-56, -30):
        m.part(g, "LaunchPad", (8, 1, 8), (x, top + 0.5, 16), (255, 120, 40),
               Material="Neon", attributes={"LaunchVelocity": {"Vector3": [0, 95, -45]}})
        m.neon(g, "PadArrow", (2, 0.2, 6), (x, top + 1.1, 16), (255, 255, 255))
    ac_unit(m, g, -24, top, 44)
    m.box(g, "Crates", -66, top, 30, 4, 3.5, 4, WOOD)
    m.spawn(-64, top, 64)
    m.spawn(-22, top, 62)

    # ---- City around and below (scenery) ----
    m.box("City", "Street", 0, -1, 0, 900, 1, 900, STREET, CanQuery=False)
    for dx in (-1, 1):
        m.neon("City", "StreetLine", (0.8, 0.1, 900), (dx * CANYON / 4, 0.06, 0), YELLOW)
        m.neon("City", "StreetLine", (900, 0.1, 0.8), (0, 0.06, dx * CANYON / 4), YELLOW)
    import random
    rng = random.Random(7)
    for i in range(44):
        angle = i / 44 * 2 * math.pi + rng.uniform(-0.05, 0.05)
        dist = rng.uniform(140, 330)
        x, z = math.cos(angle) * dist, math.sin(angle) * dist
        w, h = rng.uniform(24, 46), rng.uniform(70, 230)
        m.box("City", "Tower", x, 0, z, w, h, w, (30, 32, 46), CanCollide=False, CanQuery=False,
              CastShadow=False)
        trim = [NEON["A"], NEON["B"], NEON["C"], NEON["D"]][i % 4]
        m.neon("City", "TowerTrim", (w + 0.6, 0.8, w + 0.6), (x, h - 2, z), trim)
        for k in range(rng.randint(1, 3)):
            y = rng.uniform(15, h - 10)
            m.neon("City", "TowerWindows", (w + 0.4, 1.6, w + 0.4), (x, y, z),
                   WINDOW_COLORS[(i + k) % len(WINDOW_COLORS)])
    return m


def check(m):
    problems = []
    for i, (x, y, z) in enumerate(m.spawns):
        for j in range(i):
            px, _, pz = m.spawns[j]
            if math.hypot(x - px, z - pz) < 25:
                problems.append(f"spawns {j + 1} and {i + 1} are under 25 studs apart")
        if not (abs(x) <= EDGE - 3 and abs(z) <= EDGE - 3 and abs(x) >= CANYON / 2 + 3
                and abs(z) >= CANYON / 2 + 3):
            problems.append(f"spawn {i + 1} is too close to an edge")
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
        "DisplayName": "Rooftop Quad", "MinPlayers": 2, "MaxPlayers": 8, "InRotation": True,
        "KillHeight": KILL_HEIGHT, "Lighting": "Night"}})
    for group, children in m.groups.items():
        dump(f"{group}.model.json", {"className": "Folder", "children": children})
    spawns = []
    for i, (x, y, z) in enumerate(m.spawns):
        fx, fz = -x, -z
        n = math.hypot(fx, fz) or 1
        fx, fz = fx / n, fz / n
        zx, zz = -fx, -fz  # a spawn faces the middle (like CFrame.lookAt)
        rows = [[zz, 0, zx], [0, 1, 0], [-zx, 0, zz]]
        spawns.append({"name": f"Spawn{i + 1}", "className": "Part", "properties": {
            "Anchored": True, "CanCollide": False, "CanQuery": False, "CanTouch": False,
            "CastShadow": False, "Transparency": 1, "Size": [2, 1, 2],
            "CFrame": {"CFrame": {"position": [r(x), r(y + 0.5), r(z)],
                                  "orientation": [[r(v) for v in row] for row in rows]}}}})
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
