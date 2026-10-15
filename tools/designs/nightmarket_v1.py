#!/usr/bin/env python3
"""The Night Market lobby, design v1 (design stage: not in the game yet). The main lobby: a rainy,
neon-lit night market where up to 30 players wait between games. Shown on the "Night Market Lobby"
design canvas (the 3D model, built up in five passes). Built with tools/maplib.py and checked with
tools/mapcheck.py like the maps. Run from the repo root:
    python3 tools/designs/nightmarket_v1.py                                        (checks only)
    python3 tools/designs/canvas_export.py nightmarket_v1 build/nightmarket.json   (for the canvas)

The layout (X east, Z south: north is -Z; the ground is at 0):
  central plaza    (0, 0), radius 40: the lantern pole in the middle with a ring of benches,
                   16 spawn spots on a ring of radius 30, all facing north to the boards
  leaderboard wall a tall facade at z = -70 facing the plaza, three boards side by side with their
                   bottoms at 8 (GLOBAL LEADERS, THIS SESSION, RICHEST PLAYERS) over a promenade
  Market Street    the shop: x 40 to 100, 36 wide, an arch at x = 42, six shop stalls and two food
                   stalls along both sides, the middle clear to run down
  food court       at the street's east end: communal tables, a second lantern pole, three food
                   stalls, a canopy of lanterns and string lights
  noodle bar       in the west (x -115 to -50): IT'S NOODLES! (a long counter with stools), the
                   lounge (plastic stools, low tables, sofas), RUN-NING NOODLES
  Training Alley   in the south: a fenced 120 x 56 course: six stations on one one-way lap from
                   the gate back to the gate (slide, gap jumps, wall run, launch pad, ladder, tag
                   dummies), guide fences between the lanes
Tall dark buildings (40-90) all round, never walkable. Every part carries the pass it was added in
(1 blockout, 2 structures, 3 signs, 4 lighting and atmosphere, 5 dressing): the canvas shows each.
Only the ground, buildings, stall counters, fences, walls, the arch's pillars, the two lantern poles
and the training course are solid; everything else is decoration (no collision, no raycasts).
"""
import math
import os
import sys
from contextlib import contextmanager

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, SMOKE, Map, rot_y  # noqa: E402

ATTRIBUTES = {"DisplayName": "Night Market", "MinPlayers": 1, "MaxPlayers": 30,
              "InRotation": False, "OutOfBounds": "Building,Tower,RoofBox,OuterGround"}

GRAVITY = 196.2
JUMP = 7.2
SPRINT = 30
WALK = 16
WALL_RUN = 30 * 1.6  # about how far a wall run carries you
LAUNCH_DRIVE = 0.08
EYE = 5.0  # a player's eyes
HANG_MIN = 9.0  # nothing hangs lower than this over a walkway
CLEAR_RUN = 12.0  # every way through is at least this wide
PART_BUDGET = 5000

# ---- the layout ------------------------------------------------------------------------------------
PLAZA_R = 40
PLAZA_TOP = 0.3
SPAWN_R = 30
SPAWNS = 16
FACADE_Z = -70  # the leaderboard building's front
PROMENADE = (-66, 66, -70, -40)  # x0, x1, z0, z1
PLAZA_SQ = (-50, 40, -40, 48.4)
STREET = (40, 100, -18, 18)
ARCH_X = 42
FOOD = (100, 148, -36, 36)
LOUNGE = (-115, -50, -30, 30)
ALLEY = (-59.6, 59.6, 48.4, 103.6)  # the fence lines
GATE = (-13, 13)  # the gate's opening in the alley's north fence (split in two: in and out)
GATE_Z = 44  # where the gate opens from the plaza
FENCE_H = 10
# The boards: centers along the facade, the frame (outer half width, bottom, top).
BOARDS = (("GLOBAL", -38), ("SESSION", 0), ("RICHEST", 38))
BOARD_HALF = 16
BOARD_BOTTOM = 8.0
BOARD_TOP = 31.6

# Training Alley (inside the fence: x -59.4..59.4, z 48.6..103.4). One way round, from the gate:
#   1 SLIDE      in through the gate's west half, west along the start lane: a 40-long sprint
#                lane, the slide bar, then south through the crate tunnel
#   2 GAP JUMP   east along the south lane: three platforms 4 high, gaps of 6 then 11
#   3 WALL RUN   off the last platform along the 48-long wall, land on the mats
#   4 LAUNCH PAD north up the east side: the pad throws you onto the platform 16 high, 25 away;
#                down its slide ramp into the launch pen
#   5 LADDER     south into the infield, up the block to its ledge (14 high), down its slide ramp
#   6 TAG DUMMY  three padded dummies in a ring, then out through the gate's east half
# Guide fences (6 high: too high to jump) keep it one way: they split the gate, close the start
# lane and the south lane off from the infield, and part the launch pen from the finish lane; the
# ladder block and its ramp close the infield in two, so the only way on is up the ladder.
IN_X = (-59.4, 59.4)
IN_Z = (48.6, 103.4)
GUIDE_H = 6.0
GUIDES = (  # (x0, z0, x1, z1): straight along X or Z, corners shared
    (0.0, 48.4, 0.0, 64.2),        # splits the gate: in on the west half, out on the east
    (-45.4, 64.2, -42.4, 64.2),    # the start lane's south side, from the tunnel's corner...
    (-42.4, 64.2, 0.0, 64.2),      # ...to the gate's divider
    (-42.4, 64.2, -42.4, 88.0),    # the infield's west side, beside the west column
    (-42.4, 88.0, 43.8, 88.0),     # the south lane's north side
    (43.8, 62.0, 43.8, 88.0),      # the east corridor's west side
    (12.6, 48.4, 12.6, 76.2),      # the launch pen from the finish lane
)
SPRINT_LANE = (-4.0, -44.0)  # x: start, end (40 long, heading west)
BAR = (-45.5, -44.5, 49.3, 63.3, 4.2)  # x0, x1, z0, z1, underside: 14 wide
BAR_POST = 0.6
TUNNEL = (-57.4, -45.4, 66.0, 78.0, 4.2)  # inner x0, x1, z0, z1, inner height (12 wide, 12 long)
TUNNEL_WALL = 2.0
S_LANE = (88.2, 101.6)  # z: the south lane, between the guide fence and the wall's face
GAP_PLATFORMS = ((-43.0, -35.0), (-29.0, -21.0), (-10.0, -2.0))  # x0, x1: gaps of 6, then 11
GAP_Z = (88.4, 102.6)
GAP_H = 4.0
RUN_WALL = (-2.0, 46.0, 101.6, 103.2, 16.0)  # x0, x1, z0, z1, top: 48 long
RUN_MATS = (46.0, 58.6, 88.4, 101.4, 0.8)
LAUNCH_PAD = (49.0, 55.0, 77.0, 83.0, 0.4)  # 6 x 6
LAUNCH_PLATFORM = (44.0, 58.8, 48.8, 62.0, 16.0)
LAUNCH_TARGET = (50.8, 55.0)
LAUNCH_RAMP = (25.0, 49.0, 61.0)  # x of its foot, z0, z1 (it rises east to the platform)
LADDER_BLOCK = (12.8, 18.8, 76.6, 87.6, 14.0)  # x0, x1, z0, z1, top: 6 deep, ladder on its east face
LADDER_RAMP_FOOT = -9.2  # x where its slide ramp meets the floor
DUMMY_RING = (-30.0, 71.5, 6.0)  # x, z, radius
DUMMY_R = 3.5

# ---- colours and materials ----------------------------------------------------------------------------
COLORS = {
    "sky": (11, 16, 48), "asphalt": (24, 26, 36), "wet": (42, 47, 69), "stone": (34, 38, 56),
    "stone_light": (48, 53, 77), "pavers": (40, 42, 56), "concrete": (58, 61, 72),
    "concrete_dark": (44, 46, 56), "tiles": (47, 52, 70), "deck": (92, 61, 38),
    "brick": (92, 48, 42), "brick_dark": (64, 36, 34), "bldg": (32, 34, 46), "bldg2": (38, 42, 58),
    "bldg3": (28, 30, 40), "bldg4": (46, 40, 52), "metal": (43, 46, 54), "metal_light": (138, 143, 153),
    "steel": (90, 96, 108), "black": (10, 11, 16), "ink": (14, 16, 26), "plate": (13, 16, 32),
    "wood": (122, 82, 50), "wood_dark": (74, 48, 32), "crate": (150, 104, 58), "cardboard": (160, 124, 82),
    "white": (244, 246, 251), "cream": (243, 227, 195), "amber": (255, 179, 71), "red": (224, 49, 43),
    "yellow": (255, 212, 0), "pink": (255, 46, 147), "cyan": (25, 227, 255), "lime": (157, 255, 46),
    "orange": (255, 140, 40), "gold": (255, 201, 74), "silver": (207, 214, 223), "bronze": (200, 131, 74),
    "violet": (185, 140, 255), "mat_blue": (47, 111, 214), "mat_red": (214, 66, 59), "pad": (201, 164, 107), "hazard": (255, 212, 0),
    "chalk": (31, 42, 36), "glass": (40, 52, 80), "lit": (255, 207, 122), "lit_cyan": (127, 240, 255),
}
MATERIALS = {
    "asphalt": "Asphalt", "wet": "Asphalt", "stone": "Slate", "stone_light": "Slate",
    "pavers": "Pavement", "concrete": "Concrete", "concrete_dark": "Concrete", "tiles": "CeramicTiles",
    "deck": "WoodPlanks", "brick": "Brick", "brick_dark": "Brick", "bldg": "Concrete",
    "bldg2": "Plaster", "bldg3": "Concrete", "bldg4": "Brick", "metal": "Metal",
    "metal_light": "Metal", "steel": "Metal", "wood": "WoodPlanks", "wood_dark": "WoodPlanks",
    "crate": "WoodPlanks", "cardboard": "Cardboard", "mat_blue": "Rubber", "mat_red": "Rubber",
    "pad": "Fabric", "chalk": "Slate", "glass": "Glass",
}
NEON = {"Material": "Neon", "CastShadow": False}
DETAIL = dict(NO_HIT, CastShadow=False)


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def hexrgb(color):
    """A colour as (r, g, b): a palette name, a hex string or already a tuple."""
    if isinstance(color, str):
        if color in COLORS:
            return COLORS[color]
        return tuple(int(color.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    return color


# ---- the builder: maplib plus passes, frames, text and lights ------------------------------------------

def norm(a):
    length = math.sqrt(sum(c * c for c in a)) or 1.0
    return tuple(c / length for c in a)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def heading(dx, dz):
    """Rows for a part whose Front (-Z, where its SurfaceGui sits) faces (dx, dz)."""
    dx, _, dz = norm((dx, 0, dz))
    return [[-dz, 0, -dx], [0, 1, 0], [dx, 0, -dz]]


def axis_rows(a):
    """Rows for a part whose length (local X: a cylinder's axis) runs along `a`."""
    ax = norm(a)
    helper = (0, 1, 0) if abs(ax[1]) < 0.9 else (1, 0, 0)
    z = norm(cross(ax, helper))
    y = cross(z, ax)
    return [[ax[0], y[0], z[0]], [ax[1], y[1], z[1]], [ax[2], y[2], z[2]]]


class Frame:
    """A local frame on a face: u runs to the viewer's right, v up, w out towards the viewer."""

    def __init__(self, x, y, z, dx, dz):
        self.o = (x, y, z)
        self.W = norm((dx, 0, dz))
        self.R = (self.W[2], 0, -self.W[0])
        self.rows = heading(dx, dz)

    def at(self, u, v, w):
        o, R, W = self.o, self.R, self.W
        return (o[0] + u * R[0] + w * W[0], o[1] + v, o[2] + u * R[2] + w * W[2])


class Builder:
    def __init__(self):
        self.m = Map(colors=COLORS, materials=MATERIALS)
        self.m.passes = {}  # id(node) -> pass (canvas_export reads it)
        self.pass_ = 1
        self.hanging = []  # (node, label): hangs over walkways, so its bottom must be >= HANG_MIN
        self.solid_names = set()

    @contextmanager
    def stage(self, n):
        before = self.pass_
        self.pass_ = n
        yield
        self.pass_ = before

    def _keep(self, node, hang):
        self.m.passes[id(node)] = self.pass_
        if hang:
            self.hanging.append(node)
        return node

    # Every part goes through here: solid ones collide, the rest are decoration.
    def part(self, group, name, size, pos, color, rows=None, solid=False, hang=False, **props):
        if not solid:
            for key, value in DETAIL.items():
                props.setdefault(key, value)
        node = self.m.part(group, name, size, pos, color, rows or [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
                           **props)
        return self._keep(node, hang)

    def box(self, group, name, x0, x1, y0, y1, z0, z1, color, **kw):
        return self.part(group, name, (x1 - x0, y1 - y0, z1 - z0),
                         ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, **kw)

    def cyl(self, group, name, length, diameter, pos, color, rows=None, **kw):
        """A cylinder, upright unless `rows` say otherwise."""
        rows = rows or [[0, -1, 0], [1, 0, 0], [0, 0, 1]]
        return self.part(group, name, (length, diameter, diameter), pos, color, rows,
                         Shape="Cylinder", **kw)

    def ball(self, group, name, d, pos, color, **kw):
        return self.part(group, name, (d, d, d), pos, color, Shape="Ball", **kw)

    def tube(self, group, name, p0, p1, d, color, **kw):
        """A cylinder from point p0 to p1."""
        a = tuple(p1[i] - p0[i] for i in range(3))
        length = math.sqrt(sum(c * c for c in a))
        mid = tuple((p0[i] + p1[i]) / 2 for i in range(3))
        return self.part(group, name, (length, d, d), mid, color, axis_rows(a), Shape="Cylinder",
                         **kw)

    def wedge(self, group, name, size, pos, color, rows=None, **kw):
        node = self.part(group, name, size, pos, color, rows, **kw)
        node["className"] = "WedgePart"
        return node

    def ramp_x(self, group, name, z0, z1, x_low, x_high, y_top, color, **kw):
        """A solid wedge ramp along X: floor (0) at x_low up to y_top at x_high."""
        length = abs(x_high - x_low)
        sign = 1 if x_high > x_low else -1
        # A wedge rises toward its local +Z: turn local +Z to point along +X (or -X).
        rows = rot_y(90 * sign)
        return self.wedge(group, name, (z1 - z0, y_top, length),
                          ((x_low + x_high) / 2, y_top / 2, (z0 + z1) / 2), color, rows, **kw)

    # -- frames --
    def fbox(self, F, group, name, u0, u1, v0, v1, w0, w1, color, **kw):
        return self.part(group, name, (u1 - u0, v1 - v0, w1 - w0),
                         F.at((u0 + u1) / 2, (v0 + v1) / 2, (w0 + w1) / 2), color, F.rows, **kw)

    def fdisc(self, F, group, name, u, v, w0, w1, d, color, **kw):
        return self.tube(group, name, F.at(u, v, w0), F.at(u, v, w1), d, color, **kw)

    def ftube(self, F, group, name, a, b, w, d, color, **kw):
        return self.tube(group, name, F.at(a[0], a[1], w), F.at(b[0], b[1], w), d, color, **kw)

    def ftext(self, F, group, name, u0, u1, v0, v1, w, text, color, font="TitilliumWeb",
              weight="Bold", align="Center", glow=False, stroke=None, flicker=False):
        """Text on an invisible carrier whose front sits at w (a SurfaceGui label, the way the
        game shows sign text)."""
        node = self.fbox(F, group, name, u0, u1, v0, v1, w - 0.05, w, (255, 255, 255),
                         Transparency=1)
        node["children"] = [text_gui("Front", text, color, font, weight, align, glow, stroke)]
        if flicker:
            node.setdefault("attributes", {})["Flicker"] = True
        return node

    # -- light --
    def lamp(self, group, name, size, pos, color, brightness=1.0, reach=20, kind="Lantern",
             shape="Ball", solid=False, hang=False, flicker=False, spot=None, rows=None, light=True,
             **kw):
        """A glowing part with a light in it (`kind` names the light for the canvas legend);
        `light=False` makes one that only glows."""
        children = []
        if light:
            props_l = {"Brightness": brightness, "Range": reach, "Color": self.m.rgb(color),
                       "Shadows": False}
            if spot:
                props_l.update({"Face": spot[0], "Angle": spot[1]})
            children = [{"name": kind, "className": "SpotLight" if spot else "PointLight",
                         "properties": props_l}]
        props = dict(NEON, **kw)
        if shape == "Ball":
            props["Shape"] = "Ball"
        elif shape == "Cylinder":
            props["Shape"] = "Cylinder"
        node = self.part(group, name, size, pos, color, rows, solid=solid, hang=hang,
                         children=children, **props)
        if flicker:
            node.setdefault("attributes", {})["Flicker"] = True
        return node

    def emitter(self, group, name, pos, size, kind="Steam", rate=6, color=(220, 226, 240),
                spread=(12, 12), speed=(2, 4), life=(1.6, 2.6), grow=(1.2, 4.0)):
        """An invisible part that puffs particles (steam, mist): the canvas animates them."""
        node = self.part(group, name, size, pos, (255, 255, 255), Transparency=1)
        node["children"] = [self.m.particles(kind, rate, life, speed, [(0, grow[0]), (1, grow[1])],
                                             [(0, 0.55), (1, 1)], color, SMOKE, "Top", spread)]
        return node

    def ladder(self, group, x, z, facing, y0, y1, width=4):
        before = len(self.m.groups.get(group, []))
        self.m.ladder(group, x, z, facing, y0, y1, width)
        for node in self.m.groups[group][before:]:
            self.m.passes[id(node)] = self.pass_

    def count(self):
        return self.m.count()


def text_gui(face, text, color, font="TitilliumWeb", weight="Bold", align="Center", glow=False,
             stroke=None):
    rgb = [round(c / 255, 3) for c in hexrgb(color)]
    label = {"Size": {"UDim2": [[1, 0], [1, 0]]}, "BackgroundTransparency": 1, "Text": text,
             "TextScaled": True, "TextColor3": rgb, "TextXAlignment": align,
             "FontFace": {"Font": {"family": f"rbxasset://fonts/families/{font}.json",
                                   "weight": weight, "style": "Normal"}}}
    if stroke is not None:
        label["TextStrokeColor3"] = [round(c / 255, 3) for c in hexrgb(stroke)]
        label["TextStrokeTransparency"] = 0
    gui = {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": 40,
           "LightInfluence": 0 if glow else 1, "Brightness": 2.5 if glow else 1}
    return {"name": f"Text{face}", "className": "SurfaceGui", "properties": gui,
            "children": [{"name": "Label", "className": "TextLabel", "properties": label}]}


# ---- the ground --------------------------------------------------------------------------------------

GROUND = (-210, 240, -170, 200)
INNER = (-115, 148, -70, 104)  # the asphalt under the lobby (the rest is under buildings)
ALLEY_FLOOR = (-60, 60, 48, 104)


def walkable(x, z):
    """On the lobby's floor (not under a building)."""
    if math.hypot(x, z) <= PLAZA_R:
        return True
    for x0, x1, z0, z1 in (PROMENADE, PLAZA_SQ, STREET, FOOD, LOUNGE, ALLEY):
        if x0 <= x <= x1 and z0 <= z <= z1:
            return True
    return False


def ground(b):
    g = "Ground"
    x0, x1, z0, z1 = GROUND
    ax0, ax1, az0, az1 = ALLEY_FLOOR
    ix0, ix1, iz0, iz1 = INNER
    with b.stage(1):
        # Asphalt under the lobby, the alley's concrete cut out of it, and the ground beyond the
        # buildings (never reached: OutOfBounds). Pieces meet edge to edge.
        for a in ((ix0, ix1, iz0, az0), (ix0, ax0, az0, iz1), (ax1, ix1, az0, iz1)):
            b.box(g, "Asphalt", a[0], a[1], -1, 0, a[2], a[3], "asphalt", solid=True)
        for a in ((x0, x1, z0, iz0), (x0, x1, iz1, z1), (x0, ix0, iz0, iz1), (ix1, x1, iz0, iz1)):
            b.box(g, "OuterGround", a[0], a[1], -1, 0, a[2], a[3], "asphalt", solid=True)
        b.box(g, "AlleyFloor", ax0, ax1, -1, 0, az0, az1, "concrete", solid=True)
        b.cyl(g, "PlazaFloor", PLAZA_TOP, 2 * PLAZA_R, (0, PLAZA_TOP / 2, 0), "stone", solid=True)
        b.box(g, "Promenade", PROMENADE[0], PROMENADE[1], 0, 0.15, PROMENADE[2], PROMENADE[3],
              "pavers", solid=True)
        b.box(g, "FoodCourtFloor", FOOD[0], FOOD[1], 0, 0.15, FOOD[2], FOOD[3], "tiles", solid=True)
        b.box(g, "Deck", -111, LOUNGE[1], 0, 0.4, LOUNGE[2], LOUNGE[3], "deck", solid=True)


def inside_building(x, z, pad=0.0):
    """Within a building's footprint (or `pad` of it)."""
    return any(x0 - pad < x < x1 + pad and z0 - pad < z < z1 + pad
               for _, x0, x1, z0, z1, _, _ in BUILDINGS)


def floor_at(x, z):
    """The floor's height at (x, z)."""
    if math.hypot(x, z) <= PLAZA_R:
        return PLAZA_TOP
    if PROMENADE[0] <= x <= PROMENADE[1] and PROMENADE[2] <= z <= PROMENADE[3]:
        return 0.15
    if FOOD[0] <= x <= FOOD[1] and FOOD[2] <= z <= FOOD[3]:
        return 0.15
    if -111 <= x <= LOUNGE[1] and LOUNGE[2] <= z <= LOUNGE[3]:
        return 0.4
    return 0.0


# ---- the buildings (never walkable) ------------------------------------------------------------------

# name, x0, x1, z0, z1, height, body colour. They close the lobby in on every side.
BUILDINGS = (
    ("N1", -66, 66, -100, -70, 76, "bldg"), ("NE1", 66, 100, -100, -40, 58, "bldg2"),
    ("MN1", 40, 66, -40, -18, 46, "brick"), ("MN2", 66, 100, -40, -18, 52, "bldg3"),
    ("FN", 100, 148, -100, -36, 64, "bldg"), ("FE", 148, 182, -36, 36, 70, "bldg4"),
    ("FS", 100, 148, 36, 80, 48, "brick_dark"), ("MS2", 66, 100, 18, 48, 44, "bldg2"),
    ("MS1", 40, 66, 18, 48, 40, "brick"), ("SE1", 60, 100, 48, 130, 56, "bldg3"),
    ("S2", 0, 60, 104, 130, 62, "bldg"), ("S1", -60, 0, 104, 130, 50, "brick_dark"),
    ("SW1", -120, -60, 48, 130, 54, "bldg4"), ("SW2", -120, -50, 30, 48, 42, "brick"),
    ("W1", -150, -115, -30, 30, 46, "bldg3"), ("NW2", -120, -66, -100, -30, 60, "bldg2"),
    ("NW3", -66, -50, -40, -30, 34, "brick_dark"),
    # Behind the front row, so the skyline has no holes.
    ("SE2", 100, 182, 80, 130, 44, "bldg"), ("FE2", 148, 182, 36, 80, 52, "bldg3"),
    ("FNE", 148, 182, -100, -36, 58, "bldg2"), ("NW4", -150, -120, -100, -30, 50, "bldg"),
    ("SW3", -150, -120, 30, 130, 46, "bldg3"),
)
# Far towers for the skyline (lit windows on the side facing the lobby).
TOWERS = (
    ("T1", -50, -10, -150, -120, 90), ("T2", 30, 70, -142, -112, 84),
    ("T3", 120, 160, -146, -116, 88), ("T4", 200, 232, -64, -24, 86),
    ("T5", 200, 232, 56, 96, 80), ("T6", 120, 160, 150, 186, 82), ("T7", -44, -4, 150, 186, 78),
    ("T8", -186, -152, 118, 158, 85), ("T9", -204, -172, -44, -4, 88),
    ("T10", -176, -142, -152, -120, 84), ("T11", 196, 228, 130, 166, 72),
    ("T12", -96, -60, 150, 184, 70),
)


def rand(*keys):
    """A repeatable pseudo-random number in [0, 1) from integer keys."""
    h = 2166136261
    for k in keys:
        h = ((h ^ (int(k) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h ^= h >> 15
    return (h & 0xFFFFFF) / float(0x1000000)


def faces(x0, x1, z0, z1):
    """Each face of a footprint: (frame along it, its length, the face's name)."""
    return ((Frame(x1, 0, z0, 0, -1), x1 - x0, "N", (x0, x1)),
            (Frame(x0, 0, z1, 0, 1), x1 - x0, "S", (x0, x1)),
            (Frame(x0, 0, z0, -1, 0), z1 - z0, "W", (z0, z1)),
            (Frame(x1, 0, z1, 1, 0), z1 - z0, "E", (z0, z1)))


AGAINST_FACES = ((40.5, 43.5, -18.0, -15.0), (40.5, 43.5, 15.0, 18.0))  # the arch's pillars


def open_runs(F, length, step=1.0, out=1.6):
    """Stretches along a face (u from 0 to length) that look out over the lobby's floor."""
    runs, start = [], None
    n = int(length / step)
    for i in range(n + 1):
        u = min(length, i * step)
        x, _, z = F.at(u, 0, out)
        ok = walkable(x, z) and not any(a <= x <= c and d <= z <= e for a, c, d, e in AGAINST_FACES)
        if ok and start is None:
            start = u
        if (not ok or i == n) and start is not None:
            end = u if ok else u - step
            if end - start >= 6:
                runs.append((start, end))
            start = None
    return runs


def buildings(b):
    g = "Buildings"
    with b.stage(1):
        for name, x0, x1, z0, z1, h, color in BUILDINGS:
            b.box(g, "Building", x0, x1, 0, h, z0, z1, color, solid=True)
        for name, x0, x1, z0, z1, h in TOWERS:
            b.box(g, "Tower", x0, x1, 0, h, z0, z1, "bldg3" if rand(x0, z0) < 0.5 else "bldg",
                  solid=True)
    with b.stage(2):
        for k, (name, x0, x1, z0, z1, h, color) in enumerate(BUILDINGS):
            for F, length, side, _ in faces(x0, x1, z0, z1):
                for u0, u1 in open_runs(F, length):
                    facade(b, F, u0, u1, h, k * 7 + "NSWE".index(side), name, side)
            cornice(b, x0, x1, z0, z1, h, color)
        for k, (name, x0, x1, z0, z1, h) in enumerate(TOWERS):
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            for F, length, side, _ in faces(x0, x1, z0, z1):
                if F.W[0] * -cx + F.W[2] * -cz > 0.35 * math.hypot(cx, cz):
                    tower_face(b, F, length, h, 100 + k * 7 + "NSWE".index(side))


def facade(b, F, u0, u1, h, seed, name, side):
    """Floors of windows (a dark glass band each, some windows lit) and a ledge per floor."""
    g = "Facades"
    first = 14 if name != "N1" else 38  # the board building's lower floors are behind the boards
    y = first
    floor = 0
    while y + 6 <= h - 4:
        b.fbox(F, g, "GlassBand", u0 + 1.5, u1 - 1.5, y, y + 4.6, 0.05, 0.15, "glass",
               Material="Glass", Transparency=0.15)
        b.fbox(F, g, "Ledge", u0 + 0.5, u1 - 0.5, y - 1.2, y - 0.8, 0, 0.45, "metal")
        n = int((u1 - u0 - 3) / 6)
        pad = (u1 - u0 - n * 6) / 2
        for i in range(n):
            r = rand(seed, floor, i)
            if r < 0.34 or (r > 0.97 and floor % 2 == 0):
                warm = r < 0.3
                a = u0 + pad + i * 6 + 1.2
                b.fbox(F, g, "LitWindow", a, a + 3.6, y + 0.5, y + 4.1, 0.15, 0.2,
                       "lit" if warm else "lit_cyan", Material="Neon",
                       Transparency=0.05 if warm else 0.2)
        y += 8
        floor += 1


def tower_face(b, F, length, h, seed):
    g = "Facades"
    y, floor = 10, 0
    while y + 6 <= h - 4:
        b.fbox(F, g, "GlassBand", 2, length - 2, y, y + 4.6, 0.05, 0.15, "glass",
               Material="Glass", Transparency=0.15)
        n = int((length - 3) / 6)
        for i in range(n):
            r = rand(seed, floor, i)
            if r < 0.2:
                a = 1.5 + i * 6 + 1.2
                b.fbox(F, g, "LitWindow", a, a + 3.6, y + 0.5, y + 4.1, 0.15, 0.2,
                       "lit" if r < 0.17 else "lit_cyan", Material="Neon",
                       Transparency=0.1)
        y += 8
        floor += 1


def cornice(b, x0, x1, z0, z1, h, color):
    """A parapet round the roof's edge."""
    g = "Facades"
    t, top = 0.8, h + 2.2
    b.box(g, "RoofBox", x0, x1, h, h + 0.6, z0, z1, "metal")
    for a in ((x0, x1, z0, z0 + t), (x0, x1, z1 - t, z1), (x0, x0 + t, z0 + t, z1 - t),
              (x1 - t, x1, z0 + t, z1 - t)):
        b.box(g, "RoofBox", a[0], a[1], h + 0.6, top, a[2], a[3], color)


# ---- shared pieces -------------------------------------------------------------------------------------

def rot_about(rows, axis, deg):
    """`rows` turned by `deg` about one of the part's own axes (0 X, 1 Y, 2 Z)."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    if axis == 0:
        r = [[1, 0, 0], [0, c, -s], [0, s, c]]
    elif axis == 1:
        r = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    else:
        r = [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    return [[sum(rows[i][k] * r[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def floor_rows(ux, uz):
    """Rows for a flat carrier whose Front faces up, its text reading with its top towards
    (ux, uz)."""
    ux, _, uz = norm((ux, 0, uz))
    return [[uz, ux, 0], [0, 0, -1], [-ux, uz, 0]]


def bench(b, F, g, length, color="wood"):
    """A bench: you sit on it looking out along F.W."""
    h = length / 2
    b.fbox(F, g, "BenchSeat", -h, h, 1.45, 1.8, -0.7, 0.8, color)
    b.fbox(F, g, "BenchBack", -h, h, 1.8, 3.6, -0.75, -0.45, color)
    for s in (-1, 1):
        b.fbox(F, g, "BenchLeg", s * (h - 0.6) - 0.2, s * (h - 0.6) + 0.2, 0, 1.45, -0.6, 0.6,
               "metal")


def burst(b, F, g, name, u, v, w, size, colors, turn=0.0):
    """A comic starburst: squares turned against each other, stacked towards the viewer."""
    for k, color in enumerate(colors):
        s = size * (1 - 0.16 * k)
        rows = rot_about(F.rows, 2, turn + k * 30 + 15 * (k % 2))
        b.part(g, name, (s, s, 0.06), F.at(u, v, w + 0.03 + k * 0.1), color, rows, **NEON)


def ftri(b, F, g, name, corner, a, c, w0, w1, color, **kw):
    """A flat right triangle on a frame's face (a WedgePart on its side): the right angle at
    `corner` (u, v), its legs running to `a` and `c`, from w0 out to w1."""
    p0, pa, pc = F.at(*corner, 0), F.at(*a, 0), F.at(*c, 0)
    la = math.dist(p0, pa)
    lc = math.dist(p0, pc)
    y = tuple((pa[i] - p0[i]) / la for i in range(3))  # the wedge's Y: towards a
    z = tuple(-(pc[i] - p0[i]) / lc for i in range(3))  # its Z: away from c
    x = cross(y, z)
    rows = [[x[i], y[i], z[i]] for i in range(3)]
    mid = F.at((a[0] + c[0]) / 2, (a[1] + c[1]) / 2, (w0 + w1) / 2)
    return b.wedge(g, name, (w1 - w0, la, lc), mid, color, rows, **kw)


def sparkle(b, F, g, name, u, v, w, size, color, points=4):
    """A pointed star: a diamond in the middle and two thin right triangles per point."""
    R, r = size / 2, size * 0.16
    for k in range(points):
        ang = math.radians(90 + k * 360 / points)
        d = (math.cos(ang), math.sin(ang))
        n = (-d[1], d[0])
        foot = (u + d[0] * r * 0.7, v + d[1] * r * 0.7)
        tip = (u + d[0] * R, v + d[1] * R)
        for side in (-1, 1):
            base = (foot[0] + n[0] * side * r * 0.7, foot[1] + n[1] * side * r * 0.7)
            ftri(b, F, g, name, foot, tip, base, w, w + 0.06, color, **NEON)
    b.fbox(F, g, name, u - r * 0.75, u + r * 0.75, v - r * 0.75, v + r * 0.75, w - 0.04, w + 0.01,
           color, **NEON)  # (just behind the points, so their faces never share a plane)


def heart(b, F, g, name, u, v, w, size, color):
    """Two discs over a diamond."""
    r = size * 0.3
    b.part(g, name, (size * 0.62, size * 0.62, 0.06), F.at(u, v - size * 0.12, w + 0.03), color,
           rot_about(F.rows, 2, 45), **NEON)
    for s in (-1, 1):
        b.fdisc(F, g, name, u + s * r * 0.95, v + size * 0.12, w + 0.11, w + 0.17, 2 * r, color,
                **NEON)


def coin(b, F, g, name, u, v, w, d):
    """A coin: a gold disc with a ring."""
    b.fdisc(F, g, name, u, v, w, w + 0.08, d, "gold", **NEON)
    b.fdisc(F, g, name, u, v, w + 0.08, w + 0.13, d * 0.72, (196, 140, 30), Material="Metal")
    b.fdisc(F, g, name, u, v, w + 0.13, w + 0.18, d * 0.5, "gold", **NEON)


def trophy(b, F, g, name, u, v, w, size, color, **kw):
    """A trophy from cylinders: cup, handles (rings), stem and base, standing at (u, v)."""
    s = size
    cup = F.at(u, v + s * 0.62, w)
    b.cyl(g, name, s * 0.5, s * 0.62, cup, color, **kw)
    b.cyl(g, name, s * 0.08, s * 0.7, F.at(u, v + s * 0.88, w), color, **kw)
    b.cyl(g, name, s * 0.24, s * 0.16, F.at(u, v + s * 0.25, w), color, **kw)
    b.fbox(F, g, name, u - s * 0.3, u + s * 0.3, v, v + s * 0.13, w - s * 0.22, w + s * 0.22,
           color, **kw)
    for side in (-1, 1):
        b.fdisc(F, g, name, u + side * s * 0.38, v + s * 0.66, w - 0.05, w + 0.05, s * 0.3, color,
                **kw)


# ---- the central plaza -----------------------------------------------------------------------------------

POLE = (0.0, 0.0, 44.0)  # x, z, top
POSTS_R = 37.5  # lamp posts round the plaza's edge (the pole's strands end on them)
POST_TOP = 15.0
LANTERN_COLORS = ("red", "yellow", "pink")


def spawn_points():
    step = 360 / SPAWNS
    return [(round(SPAWN_R * math.cos(math.radians(i * step + step / 2)), 2),
             round(SPAWN_R * math.sin(math.radians(i * step + step / 2)), 2)) for i in range(SPAWNS)]


def sag(p0, p1, t, depth):
    """A point along a hanging cable from p0 to p1 (it sags `depth` in the middle)."""
    return (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t - 4 * depth * t * (1 - t),
            p0[2] + (p1[2] - p0[2]) * t)


def string_lights(b, g, p0, p1, depth, bulbs, lanterns=(), colors=("amber",), segments=3,
                  cable="black", bulb=0.34):
    """A swag of string lights from p0 to p1: a sagging cable, bulbs along it, paper lanterns
    hanging under it."""
    pts = [sag(p0, p1, i / segments, depth) for i in range(segments + 1)]
    for a, c in zip(pts, pts[1:]):
        b.tube(g, "Cable", a, c, 0.08, cable, hang=True)
    for i in range(bulbs):
        t = (i + 0.5) / bulbs
        x, y, z = sag(p0, p1, t, depth)
        b.ball(g, "Bulb", bulb, (x, y - 0.22, z), colors[i % len(colors)], hang=True, **NEON)
    for k, t in enumerate(lanterns):
        x, y, z = sag(p0, p1, t, depth)
        b.ball(g, "PaperLantern", 1.5, (x, y - 0.95, z), LANTERN_COLORS[k % 3], hang=True, **NEON,
               Transparency=0.08)


def plaza(b):
    g = "Plaza"
    y0 = PLAZA_TOP
    px, pz, top = POLE
    with b.stage(1):
        b.cyl(g, "PolePlinth", 1.2, 7, (px, y0 + 0.6, pz), "stone_light", solid=True)
        b.cyl(g, "LanternPole", top - y0 - 1.2, 1.4, (px, (y0 + 1.2 + top) / 2, pz), "red",
              solid=True)
        for x, z in spawn_points():
            b.m.spawn(x, z, y0)
    with b.stage(2):
        # Rings in the paving: discs stacked a little apart (each one shows as a ring).
        for r, h, color in ((32, 0.05, "stone_light"), (28, 0.1, "stone"), (12, 0.15, "stone_light"),
                            (10.5, 0.2, "stone")):
            b.cyl(g, "PlazaRing", h, 2 * r, (px, y0 + h / 2, pz), color)
        for y in (6, 14, 22, 30, 38):
            b.cyl(g, "PoleBand", 0.5, 1.7, (px, y, pz), "gold", Material="Metal")
        b.cyl(g, "PoleCrown", 0.6, 4.4, (px, top + 0.3, pz), "gold", Material="Metal")
        b.ball(g, "PoleFinial", 1.5, (px, top + 1.35, pz), "gold", Material="Metal")
        for k in range(3):  # arms for the big lanterns
            y = 20 + k * 7
            for i in range(4):
                a = math.radians(i * 90 + k * 45)
                b.tube(g, "PoleArm", (px, y, pz), (px + 3.2 * math.cos(a), y, pz + 3.2 * math.sin(a)),
                       0.25, "black", hang=True)
        for i in range(8):
            a = math.radians(i * 45 + 22.5)
            F = Frame(px + 7.6 * math.cos(a), y0 + 0.2, pz + 7.6 * math.sin(a), math.cos(a),
                      math.sin(a))
            bench(b, F, g, 5.0)
        for i in range(16):
            a = math.radians(i * 22.5)
            x, z = POSTS_R * math.cos(a), POSTS_R * math.sin(a)
            b.cyl(g, "LampPost", POST_TOP - y0, 0.45, (x, (y0 + POST_TOP) / 2, z), "black")
            b.cyl(g, "LampPostFoot", 0.8, 1.1, (x, y0 + 0.4, z), "black")
            b.tube(g, "LampArm", (x, POST_TOP - 0.6, z),
                   (x - 1.6 * math.cos(a), POST_TOP - 0.6, z - 1.6 * math.sin(a)), 0.2, "black")
    with b.stage(3):
        for x, z in spawn_points():  # each spawn spot: a lime pad with a chevron pointing north
            b.cyl(g, "SpawnPad", 0.06, 3.2, (x, y0 + 0.08, z), "lime", **NEON, Transparency=0.55)
            for s in (-1, 1):
                b.part(g, "SpawnChevron", (1.5, 0.06, 0.36), (x + s * 0.5, y0 + 0.14 + 0.03 * (s + 1), z - 0.1),
                       "white", rot_y(s * 38), **NEON)
    with b.stage(4):
        for k in range(3):
            y = 20 + k * 7
            for i in range(4):
                a = math.radians(i * 90 + k * 45)
                x, z = px + 3.2 * math.cos(a), pz + 3.2 * math.sin(a)
                if i == 0:
                    b.lamp(g, "BigLantern", (2.6, 2.6, 2.6), (x, y - 1.5, z), LANTERN_COLORS[k],
                           1.4, 34, "Lantern", hang=True)
                else:
                    b.ball(g, "BigLantern", 2.6, (x, y - 1.5, z), LANTERN_COLORS[(k + i) % 3],
                           hang=True, **NEON, Transparency=0.05)
        crown = 3.6
        for i in range(12):  # strands from the crown out to every other lamp post (and between)
            a = math.radians(i * 30)
            p0 = (px + crown * math.cos(a), top - 0.6, pz + crown * math.sin(a))
            p1 = ((POSTS_R - 1.6) * math.cos(a), POST_TOP - 0.7, (POSTS_R - 1.6) * math.sin(a))
            string_lights(b, g, p0, p1, 1.6, 6, lanterns=(0.3, 0.55, 0.78),
                          colors=("amber", "amber", "pink", "amber", "cyan", "amber"))
        for i in range(16):  # swags between neighbouring posts round the edge
            a0, a1 = math.radians(i * 22.5), math.radians((i + 1) * 22.5)
            p0 = (POSTS_R * math.cos(a0), POST_TOP - 0.3, POSTS_R * math.sin(a0))
            p1 = (POSTS_R * math.cos(a1), POST_TOP - 0.3, POSTS_R * math.sin(a1))
            string_lights(b, g, p0, p1, 1.4, 4, segments=2, colors=("amber", "yellow"))
        for i in range(16):
            a = math.radians(i * 22.5)
            x, z = (POSTS_R - 1.6) * math.cos(a), (POSTS_R - 1.6) * math.sin(a)
            b.lamp(g, "PostLamp", (0.9, 0.9, 0.9), (x, POST_TOP - 1.2, z), "amber", 0.9, 18,
                   "Lantern")


# ---- the leaderboard wall and promenade ------------------------------------------------------------

BOARD_THEME = {"GLOBAL": "yellow", "SESSION": "cyan", "RICHEST": "pink"}
NAMES = ("SlideKing", "WallRunWendy", "NoodleNinja", "HotPotato99", "FreezeFrame", "LadderLarry",
         "CoyoteJump", "PopUpPete", "Sprinty", "TagMaster")
BOARD_ROWS = {
    "GLOBAL": [(n, v) for n, v in zip(NAMES, ("1,284", "1,151", "987", "860", "742", "655", "590",
                                                "512", "471", "433"))],
    "SESSION": [(n, v) for n, v in zip(
        ("TagMaster", "Sprinty", "HotPotato99", "SlideKing", "PopUpPete", "CoyoteJump",
         "NoodleNinja", "FreezeFrame", "WallRunWendy", "LadderLarry"),
        (("5", "41"), ("4", "37"), ("4", "29"), ("3", "33"), ("3", "22"), ("2", "19"), ("2", "15"),
         ("1", "12"), ("1", "9"), ("0", "6")))],
    "RICHEST": [(n, v) for n, v in zip(
        ("NoodleNinja", "PopUpPete", "SlideKing", "LadderLarry", "TagMaster", "WallRunWendy",
         "FreezeFrame", "Sprinty", "CoyoteJump", "HotPotato99"),
        ("98,450", "87,200", "74,910", "66,005", "58,320", "51,775", "47,060", "39,840",
         "33,120", "29,990"))],
}
BOARD_TEXT = {
    "GLOBAL": ("GLOBAL LEADERS", "ALL-TIME WINS", "UPDATES EVERY 45s"),
    "SESSION": ("THIS SESSION", "THIS SERVER, RIGHT NOW", "RESETS WHEN THIS SERVER CLOSES"),
    "RICHEST": ("RICHEST PLAYERS", "MOST COINS", "UPDATES EVERY 45s"),
}
# Rows on the plate: rank 1 is taller and glows, then nine more.
ROW1 = (23.75, 25.65)
BOARD_LAMPS = (-7, 7)  # odd, so they miss the RICHEST board's marquee bulbs
ROW_H = 1.5
MEDALS = ("gold", "silver", "bronze")


def row_bounds(i):
    if i == 0:
        return ROW1
    top = ROW1[0] - (i - 1) * ROW_H
    return (top - ROW_H, top)


def boards(b):
    g = "Boards"
    for kind, cx in BOARDS:
        F = Frame(cx, 0, FACADE_Z, 0, 1)
        theme = BOARD_THEME[kind]
        frame = "gold" if kind == "RICHEST" else "metal"
        H = BOARD_HALF
        with b.stage(1):
            fm = {"Material": "Metal"} if kind == "RICHEST" else {}
            b.fbox(F, g, "BoardFrame", -H, H, BOARD_TOP - 1, BOARD_TOP, 1.2, 2.4, frame, **fm)
            b.fbox(F, g, "BoardFrame", -H, H, BOARD_BOTTOM, BOARD_BOTTOM + 1, 1.2, 2.4, frame, **fm)
            for s in (-1, 1):
                b.fbox(F, g, "BoardFrame", min(s * H, s * (H - 1)), max(s * H, s * (H - 1)),
                       BOARD_BOTTOM + 1, BOARD_TOP - 1, 1.2, 2.4, frame, **fm)
            b.fbox(F, g, "BoardPlate", -(H - 1), H - 1, BOARD_BOTTOM + 1, BOARD_TOP - 1, 1.2, 2.0,
                   "plate", Material="Rubber")
        with b.stage(2):
            for u in (-11, 11):
                for v in (12, 27):
                    b.fbox(F, g, "BoardBracket", u - 0.4, u + 0.4, v - 0.4, v + 0.4, 0, 1.2, "steel",
                           Material="Metal")
                b.fbox(F, g, "CableAnchor", u * 0.85 - 0.5, u * 0.85 + 0.5, 39.5, 40.5, 0, 0.3,
                       "steel", Material="Metal")
                b.tube(g, "BoardCable", F.at(u * 1.25, BOARD_TOP, 1.8), F.at(u * 0.85, 39.6, 0.2),
                       0.14, "black")
            for u in (-H + 0.5, H - 0.5):
                for v in (BOARD_BOTTOM + 0.5, BOARD_TOP - 0.5):
                    b.fdisc(F, g, "Bolt", u, v, 2.4, 2.48, 0.42, "silver", Material="Metal")
            # Two lamps on arms over the top edge, shining down the board (not into your eyes).
            for u in BOARD_LAMPS:
                b.fbox(F, g, "LampArm", u - 0.15, u + 0.15, BOARD_TOP, BOARD_TOP + 0.3, 1.6, 6.2,
                       "black")
                b.fbox(F, g, "LampHead", u - 0.7, u + 0.7, BOARD_TOP - 0.7, BOARD_TOP, 5.0, 6.4,
                       "black")
        with b.stage(3):
            board_face(b, F, g, kind, theme)
        with b.stage(4):
            b.fbox(F, g, "Halo", -H - 1.8, H + 1.8, BOARD_BOTTOM - 1.6, BOARD_TOP + 1.6, 0.4, 0.6,
                   theme, **NEON, Transparency=0.72)
            b.fbox(F, g, "Wash", -H + 1, H - 1, 0.15, 0.15 + WASH_STALL, 3.5, 20, theme, **NEON,
                   Transparency=0.84)
            for u in BOARD_LAMPS:
                b.fbox(F, g, "LampLens", u - 0.6, u + 0.6, BOARD_TOP - 0.8, BOARD_TOP - 0.7, 5.1,
                       6.3, theme, **NEON)
            b.lamp(g, "BoardLight", (0.5, 0.5, 0.5), F.at(0, BOARD_TOP - 1.2, 5.7), theme, 0.9, 30,
                   "Neon", Transparency=1)


def board_face(b, F, g, kind, theme):
    H = BOARD_HALF - 1  # the plate's half width
    ink = "ink"
    # The neon header bar, its title in black like the game's window headers, icons either side.
    b.fbox(F, g, "HeaderBar", -H + 0.3, H - 0.3, 27.3, 30.3, 2.0, 2.25, theme, **NEON)
    title, subtitle, footer = BOARD_TEXT[kind]
    b.ftext(F, g, "BoardTitle", -10.6, 10.6, 27.5, 30.1, 2.3, title, ink, "Bangers", "Regular")
    for s in (-1, 1):
        if kind == "GLOBAL":
            trophy(b, F, g, "TrophyIcon", s * 12.6, 27.75, 2.62, 2.2, ink)
        elif kind == "RICHEST":
            coin(b, F, g, "CoinIcon", s * 12.6, 28.8, 2.27, 2.1)
        else:
            sparkle(b, F, g, "StarIcon", s * 12.6, 28.8, 2.32, 2.0, ink)
    if kind == "SESSION":
        b.ftext(F, g, "BoardSubtitle", -14, 2.5, 25.95, 27.05, 2.3, subtitle, "white",
                "TitilliumWeb", "Heavy", "Left", glow=True)
        b.ftext(F, g, "ColumnHead", 4.0, 8.6, 25.95, 27.05, 2.3, "WINS", theme, "TitilliumWeb",
                "Heavy", glow=True)
        b.ftext(F, g, "ColumnHead", 9.6, 14.2, 25.95, 27.05, 2.3, "TAGS", theme, "TitilliumWeb",
                "Heavy", glow=True)
    else:
        b.ftext(F, g, "BoardSubtitle", -14, 14, 25.95, 27.05, 2.3, subtitle, "white",
                "TitilliumWeb", "Heavy", glow=True)
    for i, (name, value) in enumerate(BOARD_ROWS[kind]):
        v0, v1 = row_bounds(i)
        mid = (v0 + v1) / 2
        half = 0.75 if i == 0 else 0.65
        if i == 0:
            b.fbox(F, g, "RowGlow", -H + 0.2, H - 0.2, v0, v1, 2.0, 2.05, "gold", **NEON,
                   Transparency=0.62)
            b.ftube(F, g, "RowLine", (-H + 0.4, v0 + 0.1), (H - 0.4, v0 + 0.1), 2.14, 0.12, theme,
                    **NEON)
        else:
            b.fbox(F, g, "RowStripe", -H + 0.2, H - 0.2, v0, v1, 2.0, 2.05,
                   (20, 24, 38) if i % 2 else (28, 34, 54))
        if i < 3:
            d = 1.62 if i == 0 else 1.3
            b.fdisc(F, g, "RankBadge", -13.3, mid, 2.05, 2.2, d, MEDALS[i], **NEON)
            b.ftext(F, g, "RankNumber", -13.3 - d / 2, -13.3 + d / 2, mid - d * 0.42, mid + d * 0.42,
                    2.25, str(i + 1), ink, "Bangers", "Regular")
        else:
            b.ftext(F, g, "RankNumber", -14.3, -12.3, mid - half, mid + half, 2.3, str(i + 1),
                    (200, 208, 226), "Bangers", "Regular", glow=True)
        b.ftext(F, g, "RowName", -11.9, 3.0, mid - half, mid + half, 2.3, name,
                "white" if i else "gold", "TitilliumWeb", "Bold", "Left", glow=True)
        if kind == "SESSION":
            wins, tags = value
            b.ftext(F, g, "RowValue", 4.0, 8.6, mid - half, mid + half, 2.3, wins, theme,
                    "TitilliumWeb", "Heavy", glow=True)
            b.ftext(F, g, "RowValue", 9.6, 14.2, mid - half, mid + half, 2.3, tags, "white",
                    "TitilliumWeb", "Heavy", glow=True)
        elif kind == "RICHEST":
            coin(b, F, g, "CoinIcon", 7.9, mid, 2.06, 1.0 if i else 1.2)
            b.ftext(F, g, "RowValue", 8.8, 14.3, mid - half, mid + half, 2.3, value, "gold",
                    "TitilliumWeb", "Heavy", "Left", glow=True)
        else:
            b.ftext(F, g, "RowValue", 3.5, 14.3, mid - half, mid + half, 2.3, value, theme,
                    "TitilliumWeb", "Heavy", "Right", glow=True)
    b.ftext(F, g, "BoardFooter", -14, 14, 9.3, 9.95, 2.3, footer, (141, 150, 173), "TitilliumWeb",
            "Bold")
    # The neon tube border, just inside the frame.
    t = 0.2
    for a, c in (((-H + 0.15, 30.45), (H - 0.15, 30.45)), ((-H + 0.15, 9.15), (H - 0.15, 9.15)),
                 ((-H + 0.15, 9.15), (-H + 0.15, 30.45)), ((H - 0.15, 9.15), (H - 0.15, 30.45))):
        b.ftube(F, g, "NeonTube", a, c, 2.2, t, theme, **NEON)
    corners = [(-BOARD_HALF + 0.5, BOARD_BOTTOM + 0.5), (BOARD_HALF - 0.5, BOARD_BOTTOM + 0.5),
               (-BOARD_HALF + 0.5, BOARD_TOP - 0.5), (BOARD_HALF - 0.5, BOARD_TOP - 0.5)]
    if kind == "RICHEST":
        # The fanciest frame: gold trim lines, corner diamonds and a ring of marquee bulbs.
        H2 = BOARD_HALF
        for a, c in (((-H2 + 0.5, BOARD_TOP - 0.5), (H2 - 0.5, BOARD_TOP - 0.5)),
                     ((-H2 + 0.5, BOARD_BOTTOM + 0.5), (H2 - 0.5, BOARD_BOTTOM + 0.5))):
            b.fbox(F, g, "GoldTrim", a[0] + 1.2, c[0] - 1.2, a[1] - 0.1, a[1] + 0.1, 2.4, 2.45,
                   (255, 226, 140), **NEON)
        for u in (-H2 + 0.5, H2 - 0.5):
            b.fbox(F, g, "GoldTrim", u - 0.1, u + 0.1, BOARD_BOTTOM + 1.2, BOARD_TOP - 1.2, 2.4, 2.45,
                   (255, 226, 140), **NEON)
        for u, v in corners:
            b.part(g, "CornerDiamond", (1.3, 1.3, 0.12), F.at(u, v, 2.52), "gold",
                   rot_about(F.rows, 2, 45), Material="Metal")
        n_top, n_side = 15, 10
        for i in range(n_top):
            u = -H2 + 2.0 + i * (2 * H2 - 4.0) / (n_top - 1)
            for v in (BOARD_TOP + 0.45, BOARD_BOTTOM - 0.45):
                b.ball(g, "MarqueeBulb", 0.5, F.at(u, v, 1.8), (255, 236, 190), **NEON)
        for i in range(n_side):
            v = BOARD_BOTTOM + 1.6 + i * (BOARD_TOP - BOARD_BOTTOM - 3.2) / (n_side - 1)
            for u in (-H2 - 0.45, H2 + 0.45):
                b.ball(g, "MarqueeBulb", 0.5, F.at(u, v, 1.8), (255, 236, 190), **NEON)
    else:
        for u, v in corners:
            b.ball(g, "MarqueeBulb", 0.55, F.at(u, v, 2.72), (255, 236, 190), **NEON)


def promenade(b):
    g = "Promenade"
    y0 = 0.15
    with b.stage(2):
        for x in (-50, -26, -8, 8, 26, 50):
            bench(b, Frame(x, y0, -50, 0, -1), g, 6.0)
        for x, color in ((-19, "pink"), (19, "cyan")):
            F = Frame(x, y0, FACADE_Z, 0, 1)
            b.fbox(F, g, "KioskCounter", -2.4, 2.4, 0, 3.2, 0, 2.6, "wood_dark", solid=True)
            b.fbox(F, g, "KioskTop", -2.6, 2.6, 3.2, 3.45, -0.05, 2.8, "wood")
            for u in (-2.2, 2.2):
                b.fbox(F, g, "KioskPost", u - 0.12, u + 0.12, 3.45, 6.4, 2.3, 2.54, "black")
            for k in range(4):
                b.fbox(F, g, "KioskRoof", -2.8 + k * 1.4, -1.4 + k * 1.4, 6.4, 6.6, 0.0, 3.0,
                       color if k % 2 == 0 else "cream", Material="Fabric")
    with b.stage(3):
        for x, word, color in ((-19, "FLOWERS", "pink"), (19, "SOUVENIRS", "cyan")):
            F = Frame(x, y0, FACADE_Z, 0, 1)
            b.ftext(F, g, "KioskSign", -2.4, 2.4, 1.5, 2.7, 2.65, word, color, "Bangers", "Regular",
                    glow=True)
    with b.stage(5):
        for x, color in ((-19, "pink"), (19, "cyan")):
            F = Frame(x, y0, FACADE_Z, 0, 1)
            if color == "pink":
                for k, u in enumerate((-1.6, -0.6, 0.4, 1.4)):
                    b.cyl(g, "FlowerPot", 0.7, 0.8, F.at(u, 3.8, 1.0), "wood_dark")
                    b.ball(g, "Flowers", 0.9, F.at(u, 4.6, 1.0), ("pink", "yellow", "red", "lime")[k])
            else:
                for k, u in enumerate((-1.5, 0, 1.5)):
                    b.ball(g, "SouvenirLantern", 1.0, F.at(u, 4.1, 1.2), LANTERN_COLORS[k], **NEON)


# ---- signs ------------------------------------------------------------------------------------------------

def hero_sign(b, F, g, name, u0, u1, v0, v1, w0, color, lines, frame="metal", plate="plate",
              mount=1.0, cables=True, wash=None, halo=None, stage_wash=4):
    """A hero sign, the full anatomy: brackets back to the wall, a dark backplate in a metal frame,
    a neon tube border, raised glowing lettering 0.3 off the plate, bolts, hanging cables, and (in
    the lighting pass) a soft halo behind and a coloured wash on the ground in front.
    `lines` = [(u0, u1, v0, v1, text, colour, font, stroke)], `w0` = the plate's back."""
    t = 0.4  # plate thickness
    pf = w0 + t  # the plate's front
    with b.stage(2):
        if mount > 0:
            for u in (u0 + 1.2, u1 - 1.2):
                for v in (v0 + 0.8, v1 - 0.8):
                    b.fbox(F, g, name + "Bracket", u - 0.3, u + 0.3, v - 0.3, v + 0.3, w0 - mount,
                           w0, "steel", Material="Metal")
        if cables:
            for u in (u0 + 1.5, u1 - 1.5):
                b.tube(g, name + "Cable", F.at(u, v1, w0 + 0.2),
                       F.at(u * 0.8, v1 + 4.5, w0 - mount + 0.1), 0.12, "black")
    with b.stage(3):
        b.fbox(F, g, name + "Plate", u0, u1, v0, v1, w0, pf, plate, Material="Rubber")
        f = 0.35
        for a in ((u0 - f, u1 + f, v1, v1 + f), (u0 - f, u1 + f, v0 - f, v0),
                  (u0 - f, u0, v0, v1), (u1, u1 + f, v0, v1)):
            b.fbox(F, g, name + "Frame", a[0], a[1], a[2], a[3], w0 - 0.05, pf + 0.2, frame,
                   Material="Metal")
        r = 0.16
        for a, c in (((u0 + 0.3, v1 - 0.3), (u1 - 0.3, v1 - 0.3)),
                     ((u0 + 0.3, v0 + 0.3), (u1 - 0.3, v0 + 0.3)),
                     ((u0 + 0.3, v0 + 0.3), (u0 + 0.3, v1 - 0.3)),
                     ((u1 - 0.3, v0 + 0.3), (u1 - 0.3, v1 - 0.3))):
            b.ftube(F, g, name + "Tube", a, c, pf + 0.12, 2 * r, color, **NEON)
        for u in (u0 - f / 2, u1 + f / 2):
            for v in (v0 - f / 2, v1 + f / 2):
                b.fdisc(F, g, "Bolt", u, v, pf + 0.2, pf + 0.28, 0.24, "silver", Material="Metal")
        for (a0, a1, c0, c1, text, tc, font, stroke) in lines:
            b.ftext(F, g, name + "Text", a0, a1, c0, c1, pf + 0.3, text, tc, font,
                    "Regular" if font == "Bangers" else "Heavy", glow=True, stroke=stroke)
    with b.stage(4):
        b.fbox(F, g, "Halo", u0 - 1.4, u1 + 1.4, v0 - 1.4, v1 + 1.4, w0 - 0.35, w0 - 0.15,
               halo or color, **NEON, Transparency=0.72)
        if wash:
            wu0, wu1, ww0, ww1, wy = wash
            b.fbox(F, g, "Wash", wu0, wu1, wy, wy + WASH_HERO, ww0, ww1, color, **NEON,
                   Transparency=0.84)


def glow_sign(b, F, g, name, u0, u1, v0, v1, w0, text, color, font="Bangers", text_color=None,
              plate="plate", rim=True, text_v=None):
    """A smaller lit sign: a plate with a neon rim just behind it and glowing text (over the
    whole plate, or between the heights `text_v`)."""
    b.fbox(F, g, name, u0, u1, v0, v1, w0, w0 + 0.3, plate, Material="Rubber")
    if rim:
        b.fbox(F, g, name + "Rim", u0 - 0.15, u1 + 0.15, v0 - 0.15, v1 + 0.15, w0 - 0.08, w0 - 0.02,
               color, **NEON)
    pad = min(0.2, (v1 - v0) * 0.1)
    tv0, tv1 = text_v or (v0 + pad, v1 - pad)
    b.ftext(F, g, name + "Text", u0 + 0.25, u1 - 0.25, tv0, tv1, w0 + 0.35, text,
            text_color or color, font, "Regular" if font == "Bangers" else "Heavy", glow=True)


# ---- Market Street: the arch and the stalls -------------------------------------------------------------

# key, side, x0, x1, kind, awning stripes, header, colour
STALLS = (
    ("deal", "N", 43.5, 61.5, "deal", ("yellow", "ink"), None, "yellow"),
    ("trails", "N", 61.5, 73.5, "trails", ("cyan", "cream"), "TRAILS", "cyan"),
    ("tags", "N", 73.5, 85.5, "tags", ("pink", "cream"), "TAG EFFECTS", "pink"),
    ("tea", "N", 85.5, 100.0, "tea", ("lime", "cream"), "BUBBLE TEA|SIP & SPRINT", "lime"),
    ("titles", "S", 43.5, 56.5, "titles", ("orange", "cream"), "TITLES", "orange"),
    ("victories", "S", 56.5, 69.5, "victories", ("gold", "ink"), "VICTORIES", "gold"),
    ("crate", "S", 69.5, 84.0, "crate", ("pink", "ink"), "MYSTERY CRATE", "pink"),
    ("sliders", "S", 84.0, 100.0, "sliders", ("red", "cream"), "SLIDERS|SLIDE RIGHT IN", "red"),
)
WASH_STALL = 0.15  # floor overlays: paint and puddles 0.05, puddle glows 0.1, these, then
WASH_HERO = 0.2  # the hero signs' washes, the wayfinding's 0.25
COUNTER_FRONT = 10.5  # |z| of the counters' fronts (the street's clear middle is 21 wide)
ARCH_SPLIT = 8.18  # where "NIGHT MARKE" ends and its flickering "T" begins (u on the sign):
#                    at 4 studs Bangers sets NIGHT MARKET 19.25 wide, centred, NIGHT MARKE 17.8 of it
COUNTER_TOP = 3.5
CHALK = {"deal": ("TODAY ONLY", "-50% ON ALL 4"), "trails": ("TRAILS", "FROM 150"),
         "tags": ("TAG FX", "FROM 150"), "tea": ("BOBA", "SIP & SPRINT"),
         "titles": ("TITLES", "FROM 150"), "victories": ("VICTORIES", "FROM 900"),
         "crate": ("1 CRATE", "250 COINS"), "sliders": ("SLIDERS", "SLIDE RIGHT IN")}


# Each food stall's menu: where it hangs along the stall (clear of the tall props), its lines.
MENUS = {"fries": (-4.2, (("CLASSIC", "3"), ("CHEESY", "5"), ("SPICY", "4"))),
         "freeze": (4.0, (("ICE POP", "2"), ("SHAVED ICE", "4"), ("RAINBOW", "5"))),
         "skewers": (-3.4, (("CHICKEN", "4"), ("BEEF", "5"), ("VEGGIE", "3"))),
         "tea": (-3.9, (("MILK TEA", "4"), ("TARO", "5"), ("MANGO", "5"))),
         "sliders": (-3.7, (("CLASSIC", "4"), ("DOUBLE", "6"), ("CHEESE", "5"))),
         "noodles": (2.4, (("RAMEN", "6"), ("UDON", "6"), ("SPICY", "7")))}
MENU_W = -0.7  # the menus hang over the counter (it runs from the wall to w = 0), not the walkway


def hanging_menu(b, F, g, D, back_top, front_top, color, u, items):
    """A lit menu on two chains from the awning: MENU on a neon strip, three items and prices."""
    w = MENU_W
    rise, run = back_top - front_top, D - 0.3 + 1.6
    w_mid, y_mid = (-D + 1.9) / 2, (back_top + front_top) / 2 + 0.08
    under = y_mid + (w_mid - w) * rise / run - 0.075 / math.cos(math.atan2(rise, run))
    pf = w + 0.06  # the plate's front
    b.fbox(F, g, "MenuPlate", u - 2.0, u + 2.0, 6.2, 8.9, w - 0.06, pf, "plate", Material="Rubber")
    b.fbox(F, g, "MenuHeader", u - 1.85, u + 1.85, 8.25, 8.75, pf, pf + 0.06, color, **NEON)
    b.ftext(F, g, "MenuTitle", u - 1.7, u + 1.7, 8.28, 8.72, pf + 0.11, "MENU", "ink", "Bangers",
            "Regular")
    for k, (item, price) in enumerate(items):
        v0 = 7.6 - k * 0.6
        b.ftext(F, g, "MenuItem", u - 1.8, u + 0.9, v0, v0 + 0.5, pf + 0.05, item, "white",
                "TitilliumWeb", "Heavy", "Left", glow=True)
        b.ftext(F, g, "MenuPrice", u + 0.9, u + 1.8, v0, v0 + 0.5, pf + 0.05, price, color,
                "TitilliumWeb", "Heavy", "Right", glow=True)
    for s in (-1, 1):
        b.tube(g, "MenuChain", F.at(u + s * 1.6, 8.9, w), F.at(u + s * 1.6, under + 0.03, w), 0.1,
               "steel")


def stall_frame(side, x0, x1):
    xc = (x0 + x1) / 2
    if side == "N":
        return Frame(xc, 0, -COUNTER_FRONT, 0, 1)
    return Frame(xc, 0, COUNTER_FRONT, 0, -1)


def local(center, rows, offset):
    """A point `offset` (in a part's own axes) from `center`."""
    return tuple(center[i] + sum(rows[i][k] * offset[k] for k in range(3)) for i in range(3))


def stall(b, F, L, D, key, stripes, header, color, group="Market", back_top=11.6, front_top=10.3,
          floor=0.0):
    """A stall against a wall, its front at F (facing the walkway): a solid counter from the wall
    out to its front (D deep), a back panel, posts and a striped awning whose front edge hangs over
    the walkway at 10.3, a header sign on the awning, an A-frame chalkboard, a light under the
    awning and a wash on the ground in front."""
    h = L / 2
    g = group
    with b.stage(1):
        b.fbox(F, g, "Counter", -h, h, 0, COUNTER_TOP, -D, 0, "wood_dark", solid=True)
    with b.stage(2):
        b.fbox(F, g, "CounterFront", -h + 0.3, h - 0.3, 0.4, 3.2, 0, 0.06,
               stripes[0] if stripes[0] not in ("ink", "cream") else "wood")
        b.fbox(F, g, "CounterLip", -h, h, COUNTER_TOP, COUNTER_TOP + 0.25, -1.4, 0.12, "wood")
        b.fbox(F, g, "BackPanel", -h, h, COUNTER_TOP, back_top, -D, -D + 0.3, "wood_dark")
        for s in (-1, 1):
            b.fbox(F, g, "StallPost", s * (h - 0.25) - 0.2, s * (h - 0.25) + 0.2,
                   COUNTER_TOP + 0.25, front_top + 0.1, -0.9, -0.5, "black")
        rise = back_top - front_top
        run = D - 0.3 + 1.6
        angle = math.degrees(math.atan2(rise, run))
        rows = rot_about(F.rows, 0, -angle)
        n = max(4, int(round(L / 3)))
        for k in range(n):
            a = -h + k * L / n
            mid = F.at(a + L / n / 2, (back_top + front_top) / 2 + 0.08, (-D + 0.3 + 1.6) / 2)
            b.part(g, "Awning", (L / n, 0.15, math.hypot(rise, run)), mid, stripes[k % 2], rows,
                   hang=True, Material="Fabric")
        b.fbox(F, g, "Valance", -h + 0.02, h - 0.02, 9.45, front_top - 0.02, 1.48, 1.68, stripes[0],
               hang=True, Material="Fabric")
        # The A-frame chalkboard at the stall's left end, its front board leaning back 11 degrees.
        cu = -h + 1.3
        for s in (1, -1):
            b.part(g, "ChalkFrame", (1.9 if s > 0 else 1.75, 3.2, 0.14),
                   F.at(cu, floor + 1.55, 1.25 + s * 0.3), "wood", rot_about(F.rows, 0, s * 11))
        board_rows = rot_about(F.rows, 0, 11)
        board = F.at(cu, floor + 1.62, 1.25 + 0.3 + 0.1)
        b.part(g, "Chalkboard", (1.6, 2.6, 0.06), board, "chalk", board_rows)
    with b.stage(3):
        if header:
            main, _, sub = header.partition("|")
            half = min(h - 0.4, 6.6)
            if sub:  # MAIN over a smaller white line
                glow_sign(b, F, g, "StallSign", -half, half, 10.4, 13.8, 1.45, main, color,
                          text_v=(11.5, 13.65))
                b.ftext(F, g, "StallSignSub", -half + 1.0, half - 1.0, 10.6, 11.45, 1.8, sub,
                        "white", "TitilliumWeb", "Heavy", glow=True)
            else:
                glow_sign(b, F, g, "StallSign", -half, half, 10.4, 12.6, 1.45, main, color)
        if key in MENUS:
            hanging_menu(b, F, g, D, back_top, front_top, color, *MENUS[key])
        top, bottom = CHALK.get(key, ("", ""))
        for line, dy, size, tc in ((top, 0.55, 0.62, "white"), (bottom, -0.4, 0.5, color)):
            if not line:
                continue
            node = b.part(g, "ChalkText", (1.5, size, 0.02),
                          local(board, board_rows, (0, dy, -0.08)), (255, 255, 255), board_rows,
                          Transparency=1)
            node["children"] = [text_gui("Front", line, tc, "TitilliumWeb", "Heavy")]
    with b.stage(4):
        b.ftube(F, g, "AwningLight", (-h + 0.5, front_top - 0.25), (h - 0.5, front_top - 0.25), 1.1,
                0.18, "amber", hang=True, **NEON)
        b.lamp(g, "StallLight", (0.4, 0.4, 0.4), F.at(0, 8.6, -1.5), "amber", 1.0, 16, "Stall",
               Transparency=1)
        b.fbox(F, g, "Wash", -h + 1, h - 1, floor, floor + WASH_STALL, 0.5, 5.5, color, **NEON,
               Transparency=0.86)


def arch(b):
    g = "Arch"
    x0, x1 = ARCH_X - 1.5, ARCH_X + 1.5
    with b.stage(1):
        for z0, z1 in ((-18, -15), (15, 18)):
            b.box(g, "ArchPillar", x0, x1, 0, 30, z0, z1, "brick_dark", solid=True)
        b.box(g, "ArchBeam", x0, x1, 28, 30, -15, 15, "metal")
        b.box(g, "ArchSign", ARCH_X - 0.3, ARCH_X + 0.3, 13, 27, -15, 15, "plate")
    with b.stage(2):
        for z0, z1 in ((-18, -15), (15, 18)):
            out = (max(z0 - 0.3, -18), min(z1 + 0.3, 18))  # not into the buildings either side
            b.box(g, "PillarCap", x0 - 0.3, x1 + 0.3, 30, 31, out[0], out[1], "metal")
            b.box(g, "PillarBase", x0 - 0.3, x1 + 0.3, 0, 1.2, out[0], out[1], "stone_light")
        for z in (-10, 10):
            b.tube(g, "ArchChain", (ARCH_X, 27, z), (ARCH_X, 28, z), 0.3, "steel")
            b.box(g, "ArchClamp", ARCH_X - 0.45, ARCH_X + 0.45, 27.05, 27.4, z - 0.5, z + 0.5,
                  "steel", Material="Metal")
    # The west face, towards the plaza: ULTIMATE TAG over NIGHT MARKET (the T flickers), a TAG!
    # burst at its corner. The east face reads it too, smaller, with the way back.
    W = Frame(ARCH_X, 0, 0, -1, 0)
    hero_sign(b, W, g, "Arch", -14.6, 14.6, 13.3, 26.7, 0.3, "pink", [
        (-13.6, 13.6, 20.3, 26.3, "ULTIMATE TAG", "yellow", "Bangers", "pink"),
    ], mount=0, cables=False, wash=(-12, 12, 0.8, 8.4, 0.36), halo="pink")
    pf = 0.7  # the west plate's front
    with b.stage(3):
        b.ftext(W, g, "ArchText", -10.6, ARCH_SPLIT, 15.2, 19.2, pf + 0.3, "NIGHT MARKE", "cyan",
                "Bangers", "Regular", "Right", glow=True)
        b.ftext(W, g, "ArchText", ARCH_SPLIT, 10.6, 15.2, 19.2, pf + 0.3, "T", "cyan", "Bangers",
                "Regular", "Left", glow=True, flicker=True)
        burst(b, W, g, "TagBurst", 12.6, 26.4, pf + 0.4, 5.0, ("pink", "yellow", "white"), turn=8)
        b.ftext(W, g, "BurstText", 10.9, 14.3, 25.4, 27.4, pf + 0.75, "TAG!", "ink", "Bangers",
                "Regular")
    E = Frame(ARCH_X, 0, 0, 1, 0)
    with b.stage(3):
        b.fbox(E, g, "ArchBackPlate", -14.6, 14.6, 13.3, 26.7, 0.3, 0.6, "plate")
        b.ftext(E, g, "ArchBackText", -12, 12, 20.5, 25.5, 0.9, "ULTIMATE TAG", "yellow",
                "Bangers", "Regular", glow=True, stroke="pink")
        b.ftext(E, g, "ArchBackText", -9, 9, 16.0, 18.6, 0.9, "BACK TO THE PLAZA", "cyan",
                "TitilliumWeb", "Heavy", glow=True)
        for a, c in (((-14.3, 26.4), (14.3, 26.4)), ((-14.3, 13.6), (14.3, 13.6)),
                     ((-14.3, 13.6), (-14.3, 26.4)), ((14.3, 13.6), (14.3, 26.4))):
            b.ftube(E, g, "ArchTube", a, c, 0.75, 0.26, "cyan", **NEON)
    with b.stage(4):
        b.lamp(g, "ArchLight", (0.5, 0.5, 0.5), (ARCH_X - 6, 16, 0), "pink", 1.4, 30, "Neon",
               Transparency=1)


def qmark(b, F, g, u, v, w, s, color):
    """A question mark from flat blocks (the Mystery crate's icon)."""
    for a in ((-0.5, 0.5, 0.75, 1.0), (0.25, 0.5, 0.2, 0.75), (-0.5, -0.25, 0.5, 0.75),
              (-0.12, 0.5, 0.0, 0.2), (-0.12, 0.12, -0.4, 0.0), (-0.13, 0.13, -0.85, -0.6)):
        b.fbox(F, g, "QuestionMark", u + a[0] * s, u + a[1] * s, v + a[2] * s, v + a[3] * s, w,
               w + 0.06, color, **NEON)


def limb(b, F, g, name, pivot, length, thick, angle, w, color, facing=-1):
    """A limb hanging from `pivot` (u, v), swung `angle` degrees towards the way the figure faces
    (facing -1: the viewer's left)."""
    a = math.radians(angle)
    du, dv = facing * math.sin(a), -math.cos(a)
    center = (pivot[0] + du * length / 2, pivot[1] + dv * length / 2)
    # The box's up axis points from the foot back to the pivot; local X is -u.
    phi = math.degrees(math.atan2(-du, -dv))
    b.part(g, name, (thick, length, thick), F.at(center[0], center[1], w), color,
           rot_about(F.rows, 2, -phi))
    return (pivot[0] + du * length, pivot[1] + dv * length)


def runner(b, F, g, u, v, w, color=(223, 227, 234)):
    """A mannequin mid-stride, side on to the viewer, running to the viewer's left. Returns where
    its hands and feet are."""
    hip = (u, v + 2.0)
    ends = [limb(b, F, g, "Mannequin", hip, 2.0, 0.85, 34, w + 0.3, color),
            limb(b, F, g, "Mannequin", hip, 2.0, 0.85, -38, w - 0.3, color)]
    b.part(g, "Mannequin", (1.0, 1.9, 1.9), F.at(u - 0.2, v + 2.95, w), color,
           rot_about(F.rows, 2, -12))
    b.part(g, "Mannequin", (1.05, 1.05, 1.05), F.at(u - 0.55, v + 4.45, w), color,
           rot_about(F.rows, 2, -12))
    shoulder = (u - 0.4, v + 3.7)
    ends += [limb(b, F, g, "Mannequin", shoulder, 1.8, 0.7, -42, w + 1.25, color),
             limb(b, F, g, "Mannequin", shoulder, 1.8, 0.7, 48, w - 1.25, color)]
    return ends


def deal_props(b, F, g):
    items = (("FLAME TRAIL", "450", "orange"), ("CONFETTI POP", "600", "pink"),
             ("COMET TRAIL", "900", "cyan"), ("POW TAG", "400", "yellow"))
    top = COUNTER_TOP
    for k, (name, price, color) in enumerate(items):
        u = -6.3 + k * 4.2
        with b.stage(2):
            b.cyl(g, "Pedestal", 1.2, 2.4, F.at(u, top + 0.6, -2.6), "plate")
            b.cyl(g, "PedestalRim", 0.2, 2.6, F.at(u, top + 1.3, -2.6), "gold", Material="Metal")
            base = top + 1.4
            if k == 0:
                for dx, ang, c, dw in ((-0.5, 18, "red", -0.1), (0.0, -8, "orange", 0.0),
                                       (0.5, 14, "yellow", 0.1)):
                    b.part(g, "FlameRibbon", (0.45, 2.6, 0.1), F.at(u + dx, base + 1.3, -2.6 + dw), c,
                           rot_about(F.rows, 2, ang), **NEON)
            elif k == 1:
                b.ball(g, "ConfettiBall", 1.3, F.at(u, base + 0.75, -2.6), "pink", **NEON)
                for j in range(6):
                    a = math.radians(j * 60 + 15)
                    b.part(g, "Confetti", (0.32, 0.32, 0.32),
                           F.at(u + 1.15 * math.cos(a), base + 0.75 + 1.15 * math.sin(a), -2.6),
                           ("yellow", "cyan", "lime", "white", "orange", "pink")[j],
                           rot_about(F.rows, 2, j * 25), **NEON)
            elif k == 2:
                b.ball(g, "Comet", 1.0, F.at(u - 0.7, base + 1.5, -2.6), "cyan", **NEON)
                for j, (ln, th) in enumerate(((1.0, 0.7), (1.0, 0.5), (0.9, 0.32))):
                    b.part(g, "CometTail", (ln, th, 0.1),
                           F.at(u - 0.05 + j * 0.92, base + 1.2 - j * 0.3, -2.6),
                           ("cyan", (150, 240, 255), "white")[j], rot_about(F.rows, 2, 18), **NEON)
            else:
                burst(b, F, g, "PowBurst", u, base + 1.3, -2.9, 2.2, ("yellow", "red", "white"))
        with b.stage(3):
            if k == 3:
                b.ftext(F, g, "PowText", u - 0.85, u + 0.85, base + 0.95, base + 1.65, -2.45,
                        "POW!", "ink", "Bangers", "Regular")
            b.fbox(F, g, "PricePlate", u - 1.85, u + 1.85, 1.85, 3.15, 0.06, 0.14, "plate")
            b.ftext(F, g, "PriceName", u - 1.7, u + 1.7, 2.55, 3.05, 0.19, name, "white",
                    "TitilliumWeb", "Heavy", glow=True)
            coin(b, F, g, "CoinIcon", u - 0.75, 2.2, 0.14, 0.46)
            b.ftext(F, g, "PriceValue", u - 0.4, u + 1.6, 1.95, 2.47, 0.19, price, "gold",
                    "TitilliumWeb", "Heavy", "Left", glow=True)
    # TODAY'S DEAL: a hero sign on two posts over the stall, ONLY TODAY and a countdown under it.
    with b.stage(2):
        for s in (-1, 1):
            b.fbox(F, g, "DealPost", s * 8.65 - 0.18, s * 8.65 + 0.18, top, 17.8, -6.75, -6.35,
                   "black")
            b.tube(g, "DealCable", F.at(s * 7.0, 17.35, -6.35), F.at(s * 7.6, 18.6, -7.45), 0.12,
                   "black")
            for v in (13.6, 16.6):  # clamps from the posts onto the sign's frame
                b.fbox(F, g, "DealClamp", min(s * 8.4, s * 8.95), max(s * 8.4, s * 8.95), v - 0.22,
                       v + 0.22, -6.82, -6.28, "steel", Material="Metal")
        # Its power cable, looping down the left post to a junction box.
        b.fbox(F, g, "JunctionBox", -9.45, -8.85, 9.0, 10.2, -6.95, -6.15, (60, 64, 72),
               Material="Metal")
        for a, c in (((-8.0, 12.9), (-8.75, 11.6)), ((-8.75, 11.6), (-9.15, 10.2))):
            b.tube(g, "PowerCable", F.at(a[0], a[1], -6.75), F.at(c[0], c[1], -6.75), 0.14,
                   "black")
    hero_sign(b, F, g, "Deal", -8.2, 8.2, 12.9, 17.3, -6.55, "yellow", [
        (-7.6, 7.6, 14.7, 17.1, "TODAY'S DEAL", "yellow", "Bangers", "pink"),
        (-7.6, -0.2, 13.25, 14.35, "ONLY TODAY", "white", "TitilliumWeb", None),
    ], mount=0, cables=False, wash=(-7.4, 7.4, 1.0, 7.0, 0.0))
    pf = -6.15
    with b.stage(3):
        b.fbox(F, g, "Countdown", 0.4, 7.6, 13.15, 14.5, pf, pf + 0.12, "ink")
        b.ftext(F, g, "CountdownText", 0.6, 7.4, 13.25, 14.4, pf + 0.17, "07:42:10",
                (255, 90, 54), "TitilliumWeb", "Heavy", glow=True)
        burst(b, F, g, "SaleBurst", 7.9, 7.6, 0.2, 2.8, ("pink", "yellow", "white"), turn=12)
        b.ftext(F, g, "SaleText", 6.85, 8.95, 7.05, 8.15, 0.55, "-50%", "ink", "Bangers",
                "Regular")


def trails_props(b, F, g):
    with b.stage(2):
        b.cyl(g, "Pedestal", 0.7, 3.4, F.at(-1.6, COUNTER_TOP + 0.35, -3.2), "plate")
        b.cyl(g, "PedestalRim", 0.15, 3.6, F.at(-1.6, COUNTER_TOP + 0.775, -3.2), "cyan",
              **NEON)
        ends = runner(b, F, g, -1.6, COUNTER_TOP + 0.85, -3.2)
        for k, ((eu, ev), color) in enumerate(zip(ends, ("pink", "cyan", "yellow", "lime"))):
            w = -3.2 + (0.6, -0.6, 1.5, -1.5)[k]
            u = eu
            for j in range(3):
                dv = 0.32 * math.sin(j * 2.1 + k)
                b.part(g, "TrailRibbon", (2.1, 0.42 - j * 0.08, 0.08),
                       F.at(u + 1.05, ev + dv, w), color, **NEON, Transparency=0.15 * j)
                u += 2.1


def tags_props(b, F, g):
    with b.stage(2):
        b.fbox(F, g, "EffectStand", -1.5, 1.5, COUNTER_TOP, COUNTER_TOP + 1.4, -4.2, -1.8, "plate")
        b.fbox(F, g, "EffectStandTrim", -1.5, 1.5, COUNTER_TOP + 1.4, COUNTER_TOP + 1.55, -4.2,
               -1.8, "pink", **NEON)
        burst(b, F, g, "PowBurst", -2.7, 7.4, -3.0, 2.8, ("yellow", "red", "white"), turn=5)
        sparkle(b, F, g, "Star", 2.5, 8.6, -3.0, 2.0, "yellow")
        sparkle(b, F, g, "Star", 4.1, 6.5, -3.2, 1.3, "cyan")
        heart(b, F, g, "Heart", -0.2, 9.0, -3.1, 1.3, "pink")
        heart(b, F, g, "Heart", 1.3, 6.3, -2.9, 0.9, "red")
    with b.stage(3):
        b.ftext(F, g, "PowText", -3.75, -1.65, 6.95, 7.85, -2.6, "POW!", "ink", "Bangers",
                "Regular")


def tea_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        for k, (u, tint) in enumerate(((-5.0, (170, 120, 210)), (-2.8, (255, 170, 70)),
                                        (-0.6, (130, 200, 110)), (1.6, (170, 110, 70)))):
            b.cyl(g, "TeaCup", 1.7, 1.0, F.at(u, top + 0.85, -2.6), tint, Material="Glass",
                  Transparency=0.3)
            b.cyl(g, "TeaLid", 0.12, 1.06, F.at(u, top + 1.76, -2.6), "white")
            b.tube(g, "Straw", F.at(u + 0.15, top + 1.2, -2.6), F.at(u + 0.45, top + 2.9, -2.6), 0.16,
                   ("pink", "cyan", "lime", "yellow")[k], **NEON)
        b.cyl(g, "GiantCup", 3.8, 2.4, F.at(5.0, top + 1.9, -3.0), (255, 150, 190),
              Material="Glass", Transparency=0.35)
        b.cyl(g, "GiantLid", 0.3, 2.5, F.at(5.0, top + 3.95, -3.0), "white")
        b.tube(g, "GiantStraw", F.at(5.3, top + 3.0, -3.0), F.at(5.9, top + 6.1, -3.0), 0.36, "cyan",
               **NEON)
        for j in range(5):
            b.ball(g, "Boba", 0.42, F.at(4.3 + j * 0.35, top + 0.35, -3.0 + (j % 2) * 0.4),
                   (40, 24, 20))
    with b.stage(3):
        b.fbox(F, g, "MenuBoard", -6.2, 1.6, 6.0, 9.6, -7.2, -7.08, "chalk")
        for k, line in enumerate(("TARO", "MANGO", "MATCHA", "BROWN SUGAR")):
            b.ftext(F, g, "MenuText", -5.9, 1.3, 8.75 - k * 0.8, 9.35 - k * 0.8, -7.03, line,
                    ("white", "yellow", "lime", "pink")[k], "TitilliumWeb", "Heavy", "Left")


def titles_props(b, F, g):
    words = (("CHAMP", "gold"), ("SPEEDY", "cyan"), ("UNTAGGABLE", "pink"), ("TURBO", "orange"),
             ("GHOST", "white"), ("IT", "red"))
    for k, (word, color) in enumerate(words):
        u = (-4.15, 0, 4.15)[k % 3]
        v = 7.0 if k < 3 else 5.0
        with b.stage(2):
            b.fbox(F, g, "Nameplate", u - 1.95, u + 1.95, v, v + 1.4, -7.2, -7.05, "plate")
            b.fbox(F, g, "NameplateRim", u - 2.05, u + 2.05, v - 0.1, v + 1.5, -7.2, -7.12, color,
                   **NEON)
        with b.stage(3):
            b.ftext(F, g, "NameplateText", u - 1.8, u + 1.8, v + 0.15, v + 1.25, -7.0, word, color,
                    "Bangers", "Regular", glow=True)


def victories_props(b, F, g):
    with b.stage(2):
        for v in (5.3, 7.5):
            b.fbox(F, g, "TrophyShelf", -5.2, 5.2, v, v + 0.25, -7.2, -5.9, "wood")
        for (u, v, size, color) in ((-3.4, 5.55, 1.6, "gold"), (0, 5.55, 1.8, "silver"),
                                    (3.4, 5.55, 1.5, "bronze"), (-3.4, 7.75, 1.2, "silver"),
                                    (0, 7.75, 1.5, "gold"), (3.4, 7.75, 1.2, "gold")):
            trophy(b, F, g, "Trophy", u, v, -6.55, size, color, Material="Metal")
        for u, (c1, c2), medal in ((-3.6, ("red", "white"), "gold"),
                                   (0, ("mat_blue", "white"), "silver"),
                                   (3.6, ("lime", "ink"), "bronze")):
            for s, c in ((-1, c1), (1, c2)):
                b.part(g, "MedalRibbon", (0.42, 1.4, 0.06), F.at(u + s * 0.22, 9.75, -7.1 - 0.035 * s),
                       c, rot_about(F.rows, 2, -s * 16), Material="Fabric")
            b.fdisc(F, g, "Medal", u, 8.85, -7.0, -6.9, 0.95, medal, Material="Metal")


def crate_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        b.fbox(F, g, "ClawMachine", -5.6, -2.4, top, top + 2.6, -4.5, -1.3, "pink")
        b.fbox(F, g, "ClawGlass", -5.5, -2.5, top + 2.6, top + 5.4, -4.4, -1.4, (180, 230, 255),
               Material="Glass", Transparency=0.6)
        b.fbox(F, g, "ClawTop", -5.6, -2.4, top + 5.4, top + 6.0, -4.5, -1.3, "plate")
        b.fbox(F, g, "ClawTopTrim", -5.62, -2.38, top + 5.55, top + 5.85, -1.3, -1.25, "pink",
               **NEON)
        b.tube(g, "ClawCable", F.at(-4.0, top + 5.4, -2.9), F.at(-4.0, top + 4.4, -2.9), 0.12,
               "steel")
        for s in (-1, 0, 1):
            b.part(g, "Claw", (0.12, 0.7, 0.12), F.at(-4.0 + s * 0.25, top + 4.1, -2.9), "steel",
                   rot_about(F.rows, 2, s * 25), Material="Metal")
        for j, c in enumerate(("cyan", "yellow", "lime", "pink")):
            b.ball(g, "Prize", 0.75, F.at(-5.0 + j * 0.65, top + 3.0, -2.9 + (j % 2) * 0.6), c)
        for (u0, u1, v0, v1) in ((0.6, 3.0, top, top + 2.4), (3.2, 5.6, top, top + 2.4),
                                 (1.9, 4.3, top + 2.4, top + 4.8)):
            b.fbox(F, g, "Crate", u0, u1, v0, v1, -3.6, -1.2, "crate")
    with b.stage(3):
        qmark(b, F, g, 3.1, top + 3.55, -1.2, 1.5, "pink")
        qmark(b, F, g, 1.8, top + 1.15, -1.2, 1.1, "yellow")
        qmark(b, F, g, 4.4, top + 1.15, -1.2, 1.1, "cyan")
        b.ftext(F, g, "ClawText", -5.5, -2.5, top + 1.3, top + 2.2, -1.25, "WIN", "white",
                "Bangers", "Regular", glow=True)


def sliders_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        b.fbox(F, g, "Grill", -6.4, -1.0, top, top + 0.9, -5.5, -1.8, "metal")
        b.fbox(F, g, "GrillGlow", -6.2, -1.2, top + 0.9, top + 1.0, -5.3, -2.0, "orange", **NEON)
        for k in range(5):
            b.fbox(F, g, "GrillBar", -6.2, -1.2, top + 1.0, top + 1.08, -5.0 + k * 0.7,
                   -4.85 + k * 0.7, "black")
        for u in (-5.2, -3.7, -2.2):
            b.cyl(g, "Patty", 0.25, 1.0, F.at(u, top + 1.21, -3.6), (90, 50, 34))
        bu, base = 3.6, top
        for (h, d, c, y) in ((0.6, 2.6, (214, 156, 86), 0.3), (0.5, 2.8, (90, 50, 34), 0.85),
                             (0.18, 2.9, (90, 190, 70), 1.19)):
            b.cyl(g, "GiantBurger", h, d, F.at(bu, base + y, -3.4), c)
        b.part(g, "GiantBurger", (2.3, 0.1, 2.3), F.at(bu, base + 1.33, -3.4), "yellow",
               rot_about(F.rows, 1, 45))
        b.ball(g, "GiantBurger", 2.6, F.at(bu, base + 1.38, -3.4), (214, 156, 86))
    with b.stage(4):
        b.emitter(g, "GrillSmoke", F.at(-3.7, top + 1.6, -3.6), (3, 0.2, 2), "Smoke", rate=5,
                  color=(200, 200, 210))


KIND_PROPS = {"deal": deal_props, "trails": trails_props, "tags": tags_props, "tea": tea_props,
              "titles": titles_props, "victories": victories_props, "crate": crate_props,
              "sliders": sliders_props}


def market(b):
    g = "Market"
    arch(b)
    for key, side, x0, x1, kind, stripes, header, color in STALLS:
        F = stall_frame(side, x0, x1)
        stall(b, F, x1 - x0, 18 - COUNTER_FRONT, key, stripes, header, color)
        KIND_PROPS[kind](b, F, g)
    blade_signs(b, g)
    # THE SHOP: the hero sign on the facade over the first stalls.
    Fs = Frame(57, 0, STREET[2], 0, 1)
    hero_sign(b, Fs, g, "Shop", -10.5, 10.5, 19.2, 24.6, 1.0, "pink", [
        (-9.6, 9.6, 19.7, 24.1, "THE SHOP", "yellow", "Bangers", "pink"),
    ], wash=(-9, 9, 8.6, 17.5, 0.05))
    with b.stage(3):
        Fm = Frame(STREET[0], 0, -21.4, -1, 0)
        b.fbox(Fm, g, "StreetPlate", -3.0, 3.0, 9.4, 11.0, 0.05, 0.2, (24, 70, 120))
        b.fbox(Fm, g, "StreetPlateLine", -2.8, 2.8, 9.55, 10.85, 0.2, 0.25, "white")
        b.fbox(Fm, g, "StreetPlateInner", -2.65, 2.65, 9.7, 10.7, 0.25, 0.3, (24, 70, 120))
        b.ftext(Fm, g, "StreetName", -2.5, 2.5, 9.78, 10.62, 0.35, "MARKET ST", "white",
                "TitilliumWeb", "Heavy")
    with b.stage(4):
        for x in (50, 62, 74, 86, 98):
            string_lights(b, g, (x, 18.5, -17.6), (x, 18.5, 17.6), 3.5, 9, lanterns=(0.3, 0.5, 0.7),
                          colors=("amber", "pink", "amber", "cyan"))
        string_lights(b, g, (ARCH_X + 1.6, 23, 0), (FOOD[0] - 1, 21, 0), 2.5, 0,
                      lanterns=tuple((k + 0.5) / 10 for k in range(10)), segments=4)


# Blade signs on brackets from the facades, over the stalls, read down the street both ways:
# x (between the string lights at 50, 62, 74, 86 and 98), side, text, colour.
BLADES = ((67.5, "N", "TRAILS", "cyan"), (79.5, "N", "TAG FX", "pink"),
          (92.75, "N", "BUBBLE TEA", "lime"), (53.0, "S", "TITLES", "orange"),
          (66.0, "S", "VICTORIES", "gold"), (76.75, "S", "CRATES", "pink"),
          (92.0, "S", "SLIDERS", "red"))
BLADE_V = (14.4, 17.0)
BLADE_Z = (12.0, 17.4)  # |z|: from over the stalls' fronts to just off the facade (|z| = 18)


def blade_signs(b, g):
    v0, v1 = BLADE_V
    for x, side, text, color in BLADES:
        sg = -1 if side == "N" else 1
        z0, z1 = sorted((sg * BLADE_Z[0], sg * BLADE_Z[1]))
        zc = (z0 + z1) / 2
        with b.stage(2):
            for v in (v0 + 0.4, v1 - 0.4):
                b.box(g, "BladeArm", x - 0.1, x + 0.1, v - 0.1, v + 0.1,
                      *sorted((sg * (BLADE_Z[1] + 0.15), sg * 18.0)), "steel", Material="Metal")
        with b.stage(3):
            b.box(g, "BladeSign", x - 0.15, x + 0.15, v0, v1, z0, z1, "plate", Material="Rubber")
            b.box(g, "BladeRim", x - 0.08, x + 0.08, v0 - 0.15, v1 + 0.15, z0 - 0.15, z1 + 0.15,
                  color, **NEON)
            for dx in (-1, 1):
                Fb = Frame(x + dx * 0.15, 0, zc, dx, 0)
                b.ftext(Fb, g, "BladeText", -2.5, 2.5, v0 + 0.25, v1 - 0.25, 0.05, text, color,
                        "Bangers", "Regular", glow=True)


# ---- the food court ---------------------------------------------------------------------------------------

FC_POLE = (124.0, 0.0, 30.0)  # x, z, top
FOOD_STALLS = (  # key, wall, centre along it, length, awning stripes, header, colour
    ("fries", "N", 107.0, 14.0, ("yellow", "red"), "HOT POTATO FRIES", "yellow"),
    ("freeze", "N", 141.0, 14.0, ("cyan", "white"), "FREEZE POPS|SHAVED ICE", "cyan"),
    ("skewers", "S", 119.0, 14.0, ("orange", "ink"), "TAG-ALONG SKEWERS", "orange"),
)
FOOD_DEPTH = 5.5
CHALK.update({"fries": ("FRIES", "EXTRA SALTY"), "freeze": ("SHAVED ICE", "BRAIN FREEZE"),
              "skewers": ("SKEWERS", "STICK WITH IT"), "noodles": ("TO GO", "FAST NOODLES")})


def picnic_table(b, g, x0, x1, z, y0):
    """A long communal table with a bench along each side (along X, centred on z)."""
    b.box(g, "TableTop", x0, x1, y0 + 2.6, y0 + 2.9, z - 1.4, z + 1.4, "wood")
    for x in (x0 + 1.2, (x0 + x1) / 2, x1 - 1.2):
        b.box(g, "TableLeg", x - 0.25, x + 0.25, y0, y0 + 2.6, z - 0.25, z + 0.25, "metal")
        for s in (-1, 1):
            b.box(g, "BenchLeg", x - 0.2, x + 0.2, y0, y0 + 1.5, z + s * 2.6 - 0.2, z + s * 2.6 + 0.2,
                  "metal")
    for s in (-1, 1):
        b.box(g, "TableBench", x0, x1, y0 + 1.5, y0 + 1.75, z + s * 2.6 - 0.6, z + s * 2.6 + 0.6,
              "wood")


def lantern_pole(b, g, x, z, top, y0, plinth=5.0):
    with b.stage(1):
        b.cyl(g, "PolePlinth", 1.0, plinth, (x, y0 + 0.5, z), "stone_light", solid=True)
        b.cyl(g, "LanternPole", top - y0 - 1.0, 1.1, (x, (y0 + 1.0 + top) / 2, z), "red", solid=True)
    with b.stage(2):
        for y in range(6, int(top) - 2, 7):
            b.cyl(g, "PoleBand", 0.4, 1.35, (x, y, z), "gold", Material="Metal")
        b.cyl(g, "PoleCrown", 0.5, 3.4, (x, top + 0.25, z), "gold", Material="Metal")
        b.ball(g, "PoleFinial", 1.2, (x, top + 1.1, z), "gold", Material="Metal")


def food_court(b):
    g = "FoodCourt"
    y0 = 0.15
    px, pz, top = FC_POLE
    lantern_pole(b, g, px, pz, top, y0)
    for key, wall, c, L, stripes, header, color in FOOD_STALLS:
        F = Frame(c, 0, FOOD[2] + FOOD_DEPTH, 0, 1) if wall == "N" else \
            Frame(c, 0, FOOD[3] - FOOD_DEPTH, 0, -1)
        stall(b, F, L, FOOD_DEPTH, key, stripes, header, color, group=g, floor=y0)
        FOOD_PROPS[key](b, F, g)
    with b.stage(2):
        picnic_table(b, g, 110, 130, -17.5, y0)
        picnic_table(b, g, 110, 130, 17.5, y0)
        for x, z in ((141, -14), (141, 14)):
            b.cyl(g, "CafeTable", 0.2, 3.0, (x, y0 + 2.6, z), "white")
            b.cyl(g, "CafeTableLeg", 2.5, 0.35, (x, y0 + 1.25, z), "metal")
            for k in range(3):
                a = math.radians(k * 120 + 30)
                b.cyl(g, "PlasticStool", 1.6, 1.1, (x + 2.2 * math.cos(a), y0 + 0.8, z + 2.2 * math.sin(a)),
                      ("red", "mat_blue", "lime")[k], Material="Plastic")
    with b.stage(4):
        anchors = [(106, 21, -35.6), (124, 21, -35.6), (142, 21, -35.6), (106, 21, 35.6),
                   (124, 21, 35.6), (142, 21, 35.6), (147.6, 22, -16), (147.6, 22, 16),
                   (100.4, 21, -27), (100.4, 21, 27)]
        for k, (ax, ay, az) in enumerate(anchors):
            a = math.atan2(az - pz, ax - px)
            p0 = (px + 1.8 * math.cos(a), top - 0.4, pz + 1.8 * math.sin(a))
            string_lights(b, g, p0, (ax, ay, az), 2.2, 6, lanterns=(0.35, 0.65),
                          colors=("amber", "pink", "amber", "lime"))
        for i in range(4):
            a = math.radians(i * 90 + 45)
            b.lamp(g, "BigLantern", (2.2, 2.2, 2.2), (px + 2.6 * math.cos(a), top - 6, pz + 2.6 * math.sin(a)),
                   ("amber", "red", "amber", "yellow")[i], 0.8, 28, "Lantern", hang=True)
            b.tube(g, "PoleArm", (px, top - 4.2, pz), (px + 2.6 * math.cos(a), top - 4.2, pz + 2.6 * math.sin(a)),
                   0.2, "black", hang=True)


def fries_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        b.fbox(F, g, "Fryer", -6.2, -2.4, top, top + 1.0, -4.8, -1.8, "metal")
        b.fbox(F, g, "FryerOil", -6.0, -2.6, top + 1.0, top + 1.08, -4.6, -2.0, "amber", **NEON)
        for k, u in enumerate((-0.8, 0.6, 2.0)):
            b.cyl(g, "FryCone", 1.2, 0.95, F.at(u, top + 0.6, -2.0), "red")
            for j in range(4):
                b.part(g, "Fry", (0.16, 1.0, 0.16), F.at(u - 0.3 + j * 0.2, top + 1.45, -2.0 + (j % 2) * 0.2),
                       "yellow", rot_about(F.rows, 2, (j - 1.5) * 9))
        b.fbox(F, g, "GiantFryBox", 3.6, 6.0, top, top + 2.6, -3.4, -1.6, "red")
        for j in range(6):
            b.part(g, "GiantFry", (0.35, 2.2, 0.35),
                   F.at(3.9 + j * 0.38, top + 3.2 + (j % 3) * 0.25, -2.5 + (j % 3 - 1) * 0.45),
                   "yellow", rot_about(F.rows, 2, (j - 2.5) * 5))
    with b.stage(4):
        b.emitter(g, "FryerSteam", F.at(-4.3, top + 1.6, -3.3), (3, 0.2, 2), "Steam", rate=5)


def freeze_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        b.fbox(F, g, "IceShaver", -6.0, -4.0, top, top + 2.6, -4.2, -2.2, "white")
        b.ball(g, "IceDome", 2.0, F.at(-5.0, top + 3.0, -3.2), (200, 240, 255), Material="Glass",
               Transparency=0.4)
        for k, (u, c) in enumerate(((-2.4, "pink"), (-0.9, "cyan"), (0.6, "lime"), (2.1, "yellow"))):
            b.cyl(g, "IceCone", 1.0, 0.8, F.at(u, top + 0.5, -1.8), "white")
            b.ball(g, "ShavedIce", 1.25, F.at(u, top + 1.35, -1.8), c)
        b.fbox(F, g, "Freezer", 3.4, 6.4, top, top + 1.2, -4.6, -1.8, "white")
        b.fbox(F, g, "FreezerGlass", 3.55, 6.25, top + 1.2, top + 1.3, -4.45, -1.95, (190, 230, 255),
               Material="Glass", Transparency=0.4)
    with b.stage(4):
        b.emitter(g, "ColdMist", F.at(4.9, top + 1.4, -3.2), (3, 0.2, 2.5), "Mist", rate=4,
                  color=(220, 240, 255), speed=(0.5, 1.2), grow=(1.0, 3.0))


def skewers_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        b.fbox(F, g, "Grill", -6.2, -0.6, top, top + 0.9, -4.6, -1.6, "metal")
        b.fbox(F, g, "Coals", -6.0, -0.8, top + 0.9, top + 1.0, -4.4, -1.8, (255, 70, 30), **NEON)
        for k in range(5):
            u = -5.5 + k * 1.15
            b.tube(g, "Skewer", F.at(u, top + 1.25, -4.5), F.at(u, top + 1.25, -1.7), 0.08, "wood")
            for j in range(3):
                b.part(g, "SkewerBite", (0.45, 0.45, 0.45), F.at(u, top + 1.25, -3.9 + j * 0.85),
                       ((150, 70, 40), (230, 200, 60), (90, 160, 60))[j])
        for k, u in enumerate((1.4, 3.2, 5.0)):
            b.cyl(g, "SkewerCup", 1.4, 1.1, F.at(u, top + 0.7, -2.2), "orange")
            for j in range(3):
                b.part(g, "SkewerStick", (0.1, 2.4, 0.1), F.at(u - 0.25 + j * 0.25, top + 2.2, -2.2 + j * 0.12),
                       "wood", rot_about(F.rows, 2, (j - 1) * 12))
    with b.stage(4):
        b.emitter(g, "GrillSmoke", F.at(-3.4, top + 1.6, -3.1), (4, 0.2, 2), "Smoke", rate=5,
                  color=(190, 190, 200))


def noodles_props(b, F, g):
    top = COUNTER_TOP
    with b.stage(2):
        b.cyl(g, "NoodlePot", 1.8, 2.3, F.at(-3.8, top + 0.9, -2.8), "metal", Material="Metal")
        for k, u in enumerate((0.0, 1.6, 3.2, 4.8)):
            b.fbox(F, g, "TakeoutBox", u - 0.55, u + 0.55, top, top + 1.2, -2.2, -1.2, "white")
            b.fbox(F, g, "TakeoutTrim", u - 0.61, u + 0.61, top + 0.75, top + 0.95, -2.26, -1.14, "red")
    with b.stage(4):
        b.emitter(g, "PotSteam", F.at(-3.8, top + 2.0, -2.8), (2, 0.2, 2), "Steam", rate=6)


FOOD_PROPS = {"fries": fries_props, "freeze": freeze_props, "skewers": skewers_props,
              "noodles": noodles_props}


# ---- the noodle bar and lounge -------------------------------------------------------------------------

NOODLE = (-115.0, -111.0, -20.0, 20.0)  # the counter: x0, x1, z0, z1
LOUNGE_ISLANDS = ((-90.0, -12.0), (-90.0, 12.0), (-69.0, -10.0), (-69.0, 13.0))


def noodle_bar(b):
    g = "NoodleBar"
    F = Frame(NOODLE[1], 0, 0, 1, 0)  # its front, facing east; u runs north
    D = NOODLE[1] - NOODLE[0]
    deck = 0.4
    top = COUNTER_TOP
    with b.stage(1):
        b.fbox(F, g, "Counter", -20, 20, 0, top, -D, 0, "red", solid=True)
    with b.stage(2):
        b.fbox(F, g, "CounterFront", -19.7, 19.7, 0.6, 3.2, 0, 0.06, (150, 30, 30))
        b.fbox(F, g, "CounterLip", -20, 20, top, top + 0.25, -1.8, 0.15, "wood")
        b.fbox(F, g, "KitchenGlow", -19, 19, top + 0.1, 9.6, -D + 0.05, -D + 0.15, "amber", **NEON,
               Transparency=0.55)
        for v in (5.4, 7.6):
            b.fbox(F, g, "Shelf", -18.5, 18.5, v, v + 0.2, -D + 0.15, -D + 1.1, "wood_dark")
            for k in range(9):
                u = -16 + k * 4
                b.cyl(g, "Bowl", 0.45, 0.9, F.at(u, v + 0.425, -D + 0.62), ("white", "red")[k % 2])
        for u in (-12.0, -2.0, 8.0):
            b.cyl(g, "NoodlePot", 1.8, 2.2, F.at(u, top + 0.9 + 0.25, -2.4), "metal", Material="Metal")
        for u in (-16.0, -6.0, 4.0, 14.0):
            b.cyl(g, "NoodleBowl", 0.5, 1.15, F.at(u, top + 0.5, -0.8), "white")
            b.cyl(g, "Noodles", 0.08, 0.95, F.at(u, top + 0.79, -0.8), (250, 214, 120))
            for s in (-1, 1):
                b.tube(g, "Chopstick", F.at(u + s * 0.12, top + 0.75, -1.2), F.at(u + 0.7 + s * 0.12, top + 1.6, -0.3),
                       0.07, "wood")
        for k in range(13):
            u = -18 + k * 3
            b.cyl(g, "BarStool", 0.25, 1.4, F.at(u, 2.75, 1.5), "red")
            b.cyl(g, "BarStoolPost", 2.15, 0.25, F.at(u, deck + 1.075 + 0.05, 1.5), "metal")
            b.cyl(g, "BarStoolFoot", 0.12, 1.0, F.at(u, deck + 0.06, 1.5), "metal")
        # The awning over the counter and stools.
        back, front = 11.6, 10.6
        run = D + 3.0
        angle = math.degrees(math.atan2(back - front, run))
        rows = rot_about(F.rows, 0, -angle)
        for k in range(10):
            u = -21 + k * 4.2
            b.part(g, "Awning", (4.2, 0.15, math.hypot(back - front, run)),
                   F.at(u + 2.1, (back + front) / 2, (-D + 3.0) / 2), ("red", "cream")[k % 2], rows,
                   hang=True, Material="Fabric")
        b.fbox(F, g, "Valance", -21.1, 21.1, 9.8, front - 0.02, 2.88, 3.08, "red", hang=True,
               Material="Fabric")
    hero_sign(b, F, g, "Noodle", -11.5, 11.5, 12.8, 18.6, -D + 0.9, "red", [
        (-10.8, 6.4, 13.4, 18.0, "IT'S NOODLES!", "yellow", "Bangers", "red"),
    ], wash=(-10, 10, 4, 14, deck))
    with b.stage(3):
        w = -D + 0.9 + 0.4
        b.fdisc(F, g, "BowlIcon", 8.9, 15.2, w, w + 0.1, 3.4, "white", **NEON)
        b.fbox(F, g, "BowlIconCut", 6.9, 10.9, 15.2, 17.2, w + 0.1, w + 0.16, "plate")
        b.fbox(F, g, "BowlIconNoodles", 7.6, 10.2, 15.0, 15.25, w + 0.16, w + 0.22, "yellow", **NEON)
        for s in (-1, 1):
            b.part(g, "BowlIconStick", (0.18, 4.0, 0.08), F.at(9.4 + s * 0.4, 16.3, w + 0.26), "wood",
                   rot_about(F.rows, 2, -28 + s * 4), **NEON)
        b.fbox(F, g, "MenuStrip", -14, 14, 8.3, 9.4, -D + 1.15, -D + 1.3, "plate")
        for k, (word, color) in enumerate((("RAMEN", "yellow"), ("UDON", "white"), ("GYOZA", "pink"),
                                           ("SPICY IT", "red"))):
            u = -10.5 + k * 7
            b.ftext(F, g, "MenuText", u - 3, u + 3, 8.4, 9.3, -D + 1.35, word, color, "TitilliumWeb",
                    "Heavy", glow=True)
        Fo = Frame(NOODLE[0] + 0.0, 0, -25.0, 1, 0)
        glow_sign(b, Fo, g, "OpenSign", -3.4, 3.4, 4.4, 7.0, 0.3, "OPEN ALL NIGHT", "pink",
                  font="TitilliumWeb", plate="plate")
    with b.stage(4):
        for k in range(8):
            u = -17.5 + k * 5
            b.ball(g, "PaperLantern", 1.4, F.at(u, front - 0.9, 2.7), LANTERN_COLORS[k % 3], hang=True,
                   **NEON, Transparency=0.08)
        b.lamp(g, "KitchenLight", (0.4, 0.4, 0.4), F.at(0, 7.0, 0.8), "amber", 1.3, 26, "Stall",
               Transparency=1)
        for u in (-12.0, -2.0, 8.0):
            b.emitter(g, "PotSteam", F.at(u, top + 2.4, -2.4), (2, 0.2, 2), "Steam", rate=6)
        b.fbox(Frame(NOODLE[0], 0, -25.0, 1, 0), g, "Wash", -3, 3, deck, deck + WASH_STALL, 0.5, 5.0,
               "pink", **NEON, Transparency=0.86)


def lounge(b):
    g = "Lounge"
    deck = 0.4
    noodle_bar(b)
    F = Frame(-77.0, 0, LOUNGE[2] + FOOD_DEPTH, 0, 1)
    stall(b, F, 14.0, FOOD_DEPTH, "noodles", ("orange", "cream"), "RUN-NING NOODLES", "orange",
          group=g, floor=deck)
    noodles_props(b, F, g)
    with b.stage(2):
        for (x, z) in LOUNGE_ISLANDS:
            b.cyl(g, "LowTable", 0.22, 3.2, (x, deck + 1.6, z), "white", Material="Plastic")
            b.cyl(g, "LowTableLeg", 1.5, 0.5, (x, deck + 0.75, z), "metal")
            for k in range(4):
                a = math.radians(k * 90 + 45)
                b.cyl(g, "PlasticStool", 1.15, 1.2, (x + 2.5 * math.cos(a), deck + 0.575, z + 2.5 * math.sin(a)),
                      ("red", "mat_blue", "yellow", "lime")[k], Material="Plastic")
        for x0 in (-106.0, -66.0):
            Fs = Frame(x0 + 4, deck, LOUNGE[3] - 3.4, 0, -1)
            b.fbox(Fs, g, "Sofa", -4, 4, 0, 1.4, -0.0, 3.4, (40, 130, 140), Material="Fabric")
            b.fbox(Fs, g, "SofaBack", -4, 4, 1.4, 3.6, 0.0, 0.9, (34, 110, 120), Material="Fabric")
            for s in (-1, 1):
                b.fbox(Fs, g, "SofaArm", s * 4 - (0.8 if s > 0 else 0), s * 4 + (0.8 if s < 0 else 0),
                       1.4, 2.4, 0.9, 3.4, (34, 110, 120), Material="Fabric")
        for x in (-104.0, -60.0):
            bench(b, Frame(x, deck, LOUNGE[2] + 1.0, 0, 1), g, 6.0)
    with b.stage(4):
        for x in (-104.0, -92.0, -80.0, -68.0, -56.0):
            string_lights(b, g, (x, 19.5, LOUNGE[2] + 0.4), (x, 19.5, LOUNGE[3] - 0.4), 4.0, 10,
                          lanterns=(0.3, 0.5, 0.7), colors=("amber", "amber", "pink", "cyan"))
        for (x, z), color in (((-90.0, 0.0), "red"), ((-66.0, 0.0), "amber")):
            b.lamp(g, "LoungeLantern", (1.8, 1.8, 1.8), (x, 15.5, z), color, 0.9, 24, "Lantern",
                   hang=True)


# ---- Training Alley ----------------------------------------------------------------------------------------

def fence_line(b, g, a0, a1, fixed, axis, skip=None):
    """A chain-link fence along `axis` ("X" or "Z") from a0 to a1 at `fixed`: hazard-striped posts
    about every 10 studs, a see-through wire panel between each pair (solid: it's the fence) and a
    rail along the top. `skip` = (s0, s1) leaves a gap (the gate)."""
    pts = []
    spans = [(a0, a1)] if skip is None else [(a0, skip[0]), (skip[1], a1)]
    for s0, s1 in spans:
        n = max(1, round((s1 - s0) / 10))
        pts.append([s0 + (s1 - s0) * i / n for i in range(n + 1)])

    def put(name, s0, s1, t0, t1, y0, y1, color, **kw):
        if axis == "X":
            return b.box(g, name, s0, s1, y0, y1, fixed + t0, fixed + t1, color, **kw)
        return b.box(g, name, fixed + t0, fixed + t1, y0, y1, s0, s1, color, **kw)

    for row in pts:
        with b.stage(1):
            for s in row:
                if skip is not None and (abs(s - skip[0]) < 0.01 or abs(s - skip[1]) < 0.01):
                    continue  # the gate's own posts stand there
                if axis == "Z" and (abs(s - a0) < 0.01 or abs(s - a1) < 0.01):
                    continue  # the corners' posts come with the X lines
                put("FencePost", s - 0.2, s + 0.2, -0.2, 0.2, 0, FENCE_H, "hazard", solid=True,
                    attributes={"Look": "Hazard"})
        for s0, s1 in zip(row, row[1:]):
            e0 = s0 + (0.5 if skip is not None and abs(s0 - skip[1]) < 0.01 else 0.2)
            e1 = s1 - (0.5 if skip is not None and abs(s1 - skip[0]) < 0.01 else 0.2)
            with b.stage(1):
                put("FenceRail", e0, e1, -0.1, 0.1, FENCE_H - 0.4, FENCE_H - 0.2, "metal", solid=True)
            with b.stage(2):
                put("ChainLink", e0, e1, -0.05, 0.05, 0.05, FENCE_H - 0.4, (150, 156, 168), solid=True,
                    Transparency=0.35, attributes={"Look": "ChainLink"})


def guide_fence(b, g, x0, z0, x1, z1, posts):
    """A guide fence, GUIDE_H high (too high to jump): hazard posts about every 8 (one per corner
    where fences meet: `posts` remembers them), see-through panels and a top rail."""
    along_x = abs(z1 - z0) < 1e-6
    a0, a1 = (x0, x1) if along_x else (z0, z1)
    fixed = z0 if along_x else x0
    n = max(1, round((a1 - a0) / 8))
    pts = [a0 + (a1 - a0) * i / n for i in range(n + 1)]

    def put(name, s0, s1, t0, t1, y0, y1, color, **kw):
        if along_x:
            return b.box(g, name, s0, s1, y0, y1, fixed + t0, fixed + t1, color, **kw)
        return b.box(g, name, fixed + t0, fixed + t1, y0, y1, s0, s1, color, **kw)

    with b.stage(1):
        for a in pts:
            key = (round(a, 2), round(fixed, 2)) if along_x else (round(fixed, 2), round(a, 2))
            if key in posts:
                continue
            posts.add(key)
            put("GuidePost", a - 0.2, a + 0.2, -0.2, 0.2, 0, GUIDE_H, "hazard", solid=True,
                attributes={"Look": "Hazard"})
        for a, c in zip(pts, pts[1:]):
            put("GuideRail", a + 0.2, c - 0.2, -0.1, 0.1, GUIDE_H - 0.4, GUIDE_H - 0.2, "metal",
                solid=True)
    with b.stage(2):
        for a, c in zip(pts, pts[1:]):
            put("GuideLink", a + 0.2, c - 0.2, -0.05, 0.05, 0.05, GUIDE_H - 0.4, (150, 156, 168),
                solid=True, Transparency=0.35, attributes={"Look": "ChainLink"})


def station_group(n):
    return "Station%d" % n


def alley(b):
    g = "Alley"
    fx0, fx1, fz0, fz1 = ALLEY
    gx = GATE[1] + 0.5  # the gate posts' centres (x = +-8.5)
    fence_line(b, g, fx0, fx1, fz0, "X", skip=(-gx, gx))
    fence_line(b, g, fx0, fx1, fz1, "X")
    fence_line(b, g, fz0, fz1, fx0, "Z")
    fence_line(b, g, fz0, fz1, fx1, "Z")
    with b.stage(1):
        for s in (-1, 1):
            b.box(g, "GatePost", s * gx - 0.5, s * gx + 0.5, 0, 14, fz0 - 0.5, fz0 + 0.5, "hazard",
                  solid=True, attributes={"Look": "Hazard"})
        b.box(g, "GateBeam", -gx + 0.5, gx - 0.5, 12, 13.4, fz0 - 0.4, fz0 + 0.4, "metal", hang=True)
    with b.stage(2):
        for s in (-1, 1):  # the gate's leaves, swung open against the fence on the plaza side
            x0, x1 = sorted((s * (gx + 0.6), s * (gx + 8.2)))
            b.box(g, "GateLeaf", x0, x1, 0.3, 9.2, fz0 - 0.95, fz0 - 0.85, (150, 156, 168),
                  Transparency=0.35, attributes={"Look": "ChainLink"})
            b.box(g, "GateLeafFrame", x0, x1, 9.2, 9.45, fz0 - 1.0, fz0 - 0.8, "metal")
            b.box(g, "GateLeafFrame", x0, x1, 0.05, 0.3, fz0 - 1.0, fz0 - 0.8, "metal")
            for x in (x0, x1):
                b.box(g, "GateLeafFrame", x - 0.12, x + 0.12, 0.3, 9.2, fz0 - 1.0, fz0 - 0.8, "metal")
        for s in (-1, 1):
            b.box(g, "SignStrut", s * 7 - 0.3, s * 7 + 0.3, 13.4, 13.45, fz0 - 0.6, fz0 + 0.2, "steel",
                  hang=True, Material="Metal")
            # Stay cables from the sign's top back to the gate posts, a clamp at each end.
            b.tube(g, "SignStay", (s * 9.2, 18.6, fz0 - 0.1), (s * 8.5, 14.0, fz0 + 0.55), 0.12,
                   "black", hang=True)
            b.box(g, "StayClamp", s * 8.5 - 0.35, s * 8.5 + 0.35, 14.0, 14.3, fz0 + 0.2, fz0 + 0.62,
                  "steel", hang=True, Material="Metal")
    Fg = Frame(0, 0, fz0 - 0.4, 0, -1)
    hero_sign(b, Fg, g, "Training", -9.6, 9.6, 13.8, 19.0, 0.0, "lime", [
        (-8.9, 8.9, 15.5, 18.6, "TRAINING ALLEY", "lime", "Bangers", None),
        (-6.4, 6.4, 14.1, 15.2, "6 STATIONS, ONE LAP", "white", "TitilliumWeb", None),
    ], mount=0, cables=False, wash=(-7, 7, 1, 8, 0.36))
    stations(b)
    posts = set()
    for (x0, z0, x1, z1) in GUIDES:
        guide_fence(b, "AlleyGuides", x0, z0, x1, z1, posts)
    with b.stage(2):
        for (x, z), _ in FLOODS:
            b.cyl(g, "FloodPole", 22.6, 0.6, (x, 11.3, z), "black")
            b.box(g, "FloodBar", x - 1.6, x + 1.6, 21.6, 22.0, z - 0.2, z + 0.2, "black")
    with b.stage(4):
        for (x, z), target in FLOODS:
            for s in (-1, 1):
                p = (x + s * 1.1, FLOOD_Y, z)
                b.lamp(g, "Floodlight", (1.4, 0.9, 1.4), p, (225, 238, 255), 2.2, FLOOD_RANGE,
                       "Flood", shape="Block", rows=axis_rows(flood_aim(p, target)), light=s > 0,
                       spot=("Right", FLOOD_ANGLE))
        for (x, z, d) in ((34.0, 72.0, 4.0), (-15.5, 98.5, 3.0)):
            b.cyl(g, "Puddle", 0.05, d, (x, 0.025, z), (26, 34, 56), Material="Glass",
                  Transparency=0.3)
            b.cyl(g, "PuddleGlow", 0.1, d * 0.8, (x, 0.05, z), "lime", **NEON, Transparency=0.82)


FLOODS = (  # each pole (x, z) and where its beam points: every station is lit from the side you
    # see it from (the two on the north fence light the wall run and the wall-jump walls)
    ((-58.4, 49.6), (-38.0, 64.0)), ((58.4, 63.0), (40.0, 74.0)),
    ((-20.0, 48.9), (-22.0, 92.0)), ((20.0, 48.9), (24.0, 92.0)),
    ((-58.4, 76.0), (-32.0, 78.0)), ((-58.4, 102.4), (-34.0, 90.0)),
    ((58.4, 102.4), (34.0, 88.0)), ((0.0, 102.6), (0.0, 84.0)))
FLOOD_Y = 21.2
FLOOD_RANGE = 70
FLOOD_ANGLE = 48  # the cone, degrees across


def flood_aim(p, target):
    """A flood's beam, from its lamp at p down to target (x, z) on the ground."""
    return norm((target[0] - p[0], -p[1], target[1] - p[2]))


def floods_check():
    """No flood's cone reaches the plaza: every ray within its range comes down south of the
    alley's north fence (spill to the east, west and south only lights the buildings)."""
    problems = []
    half = math.radians(FLOOD_ANGLE / 2)
    for (x, z), target in FLOODS:
        p = (x + 1.1, FLOOD_Y, z)
        a = flood_aim(p, target)
        rows = axis_rows(a)
        side, up = (rows[0][2], rows[1][2], rows[2][2]), (rows[0][1], rows[1][1], rows[2][1])
        worst = None
        for i in range(72):
            t = math.radians(i * 5)
            for k in (0.25, 0.5, 0.75, 1.0):
                c, sn = math.cos(half * k), math.sin(half * k)
                d = tuple(a[j] * c + (side[j] * math.cos(t) + up[j] * math.sin(t)) * sn
                          for j in range(3))
                if d[1] >= -0.02 or FLOOD_Y / -d[1] > FLOOD_RANGE:
                    continue
                gz = p[2] + d[2] * FLOOD_Y / -d[1]
                worst = gz if worst is None else min(worst, gz)
        if worst is None or worst < ALLEY[2]:
            problems.append("the flood at (%g, %g) lights the plaza (down to z = %.1f)" % (
                x, z, worst if worst is not None else float("nan")))
    return problems


def stations(b):
    with b.stage(1):
        # 1 SLIDE: the bar (14 wide, underside 4.2) on striped posts, then the crate tunnel.
        g = station_group(1)
        x0, x1, z0, z1, under = BAR
        b.box(g, "SlideBar", x0, x1, under, under + 1.0, z0, z1, "hazard", solid=True,
              attributes={"Look": "Hazard"})
        for a, c in ((z0 - BAR_POST, z0), (z1, z1 + BAR_POST)):
            b.box(g, "BarPost", x0, x1, 0, under + 1.8, a, c, "black", solid=True)
        b.box(g, "StandBlocker", x0, x1, 0, under, z0, z1, (230, 60, 60), solid=True, Transparency=1,
              attributes={"SlideBlocker": True})
        ix0, ix1, iz0, iz1, ih = TUNNEL
        t = TUNNEL_WALL
        b.box(g, "TunnelWall", ix0 - t, ix0, 0, ih, iz0, iz1, "crate", solid=True)
        b.box(g, "TunnelWall", ix1, ix1 + t, 0, ih, iz0, iz1, "crate", solid=True)
        b.box(g, "TunnelRoof", ix0 - t, ix1 + t, ih, ih + 1.2, iz0, iz1, "crate", solid=True)
        for a, c in ((iz0, iz0 + 0.3), (iz1 - 0.3, iz1)):
            b.box(g, "StandBlocker", ix0, ix1, 0, ih, a, c, (230, 60, 60), solid=True,
                  Transparency=1, attributes={"SlideBlocker": True})
        # 2 GAP JUMP: three platforms 4 high across the south lane: gaps of 6, then 11.
        g = station_group(2)
        for x0, x1 in GAP_PLATFORMS:
            b.box(g, "GapPlatform", x0, x1, 0, GAP_H, GAP_Z[0], GAP_Z[1], "concrete", solid=True)
        # 3 WALL RUN: the flat 48-long wall from the last platform, the landing mats at its end.
        g = station_group(3)
        x0, x1, z0, z1, h = RUN_WALL
        b.box(g, "RunWall", x0, x1, 0, h, z0, z1, "brick", solid=True)
        x0, x1, z0, z1, h = RUN_MATS
        b.box(g, "LandingMat", x0, x1, 0, h, z0, z1, "mat_blue", solid=True)
        # 4 LAUNCH PAD: the pad throws you north onto the platform (16 high), its slide ramp down.
        g = station_group(4)
        x0, x1, z0, z1, h = LAUNCH_PLATFORM
        b.box(g, "LaunchPlatform", x0, x1, 0, h, z0, z1, "concrete", solid=True)
        b.ramp_x(g, "SlideRamp", LAUNCH_RAMP[1], LAUNCH_RAMP[2], LAUNCH_RAMP[0], x0, h,
                 "metal_light", solid=True)
        x0, x1, z0, z1, h = LAUNCH_PAD
        b.box(g, "LaunchPad", x0, x1, 0, h, z0, z1, "metal", solid=True,
              attributes={"LaunchVelocity": vec(*LAUNCH)})
        # 5 LADDER: up the brick block (14 high, 6 deep), its slide ramp down the other side.
        g = station_group(5)
        x0, x1, z0, z1, h = LADDER_BLOCK
        b.box(g, "LadderBlock", x0, x1, 0, h, z0, z1, "brick", solid=True)
        b.ramp_x(g, "SlideRamp", z0, z1, LADDER_RAMP_FOOT, x0, h, "metal_light", solid=True)
    with b.stage(2):
        g = station_group(5)
        b.ladder(g, LADDER_BLOCK[1], (LADDER_BLOCK[2] + LADDER_BLOCK[3]) / 2, (1, 0), 0,
                 LADDER_BLOCK[4], 4)
        g = station_group(4)
        x0, x1, z0, z1, h = LAUNCH_PLATFORM
        b.box(g, "LandingMat", x0 + 2, x1 - 1, h, h + MAT, z0 + 1, z1 - 1, "mat_blue", solid=True)
        for (a0, a1, c0, c1) in ((x1 - 0.2, x1, z0, z1), (x0 + 2, x1 - 0.2, z0, z0 + 0.2)):
            b.box(g, "SafetyNet", a0, a1, h + 0.05, h + 3.2, c0, c1, (40, 44, 52), solid=True,
                  Transparency=0.4, attributes={"Look": "ChainLink"})
        x0, x1, z0, z1, h = LAUNCH_PAD
        b.box(g, "PadRim", x0 - 0.3, x1 + 0.3, 0, 0.2, z0 - 0.3, z1 + 0.3, "black")
        for k in range(3):  # chevrons pointing the way you fly (north)
            chevron(b, g, (x0 + x1) / 2, z1 - 1.3 - k * 1.7, 0, -1, "lime", y=h)
        g = station_group(6)
        cx, cz, _ = DUMMY_RING
        for k in range(3):
            a = math.radians(90 + k * 120)
            x, z = cx + DUMMY_R * math.cos(a), cz + DUMMY_R * math.sin(a)
            b.cyl(g, "DummyBase", 0.6, 2.6, (x, 0.3, z), "black", solid=True)
            b.cyl(g, "DummyBody", 4.0, 1.7, (x, 2.6, z), "pad", solid=True, Material="Fabric")
            b.cyl(g, "DummyTarget", 0.5, 1.8, (x, 3.4, z), "red", Material="Fabric")
            b.ball(g, "DummyHead", 1.5, (x, 5.25, z), "pad", Material="Fabric")
            ang = math.degrees(math.atan2(cz - z, cx - x))
            b.part(g, "DummyArms", (0.6, 0.5, 3.0), (x, 3.9, z), "pad", rot_y(-ang),
                   Material="Fabric")
        course_paint(b)
        g = "AlleyCourse"
        for (x0, z0) in ((-58.0, 82.0), (-58.0, 84.8)):
            b.box(g, "Locker", x0 - 1.2, x0 + 0.6, 0, 6.0, z0, z0 + 2.8, (60, 90, 140), Material="Metal")
        bench(b, Frame(18.0, 0, 49.6, 0, 1), g, 6.0)


MAT = 0.4  # the landing mats on the launch platform


def course_paint(b):
    """Paint that makes the course read at night: hazard stripes along every edge you jump from
    or over, and a colour band along the wall you run on (0.05 thick: flat, never in the way)."""
    hz = {"Look": "Hazard"}
    g = station_group(2)
    for x0, x1 in GAP_PLATFORMS:
        for a, c in ((x0 + 0.05, x0 + 0.85), (x1 - 0.85, x1 - 0.05)):
            b.box(g, "EdgePaint", a, c, GAP_H, GAP_H + 0.05, GAP_Z[0] + 0.05, GAP_Z[1] - 0.05,
                  "hazard", attributes=hz)
    g = station_group(4)
    x0, x1, z0, z1, h = LAUNCH_PLATFORM
    b.box(g, "EdgePaint", x0 + 2.05, x1 - 1.05, h, h + 0.05, z1 - 0.95, z1 - 0.05, "hazard",
          attributes=hz)
    g = station_group(3)
    x0, x1, z0, z1, h = RUN_WALL
    for v0, v1 in ((6.4, 7.6), (12.4, 12.9)):
        b.box(g, "WallBand", x0 + 0.6, x1 - 0.6, v0, v1, z0 - 0.05, z0, "pink", **NEON)


def stations_info():
    """Each station: number, title, tip lines, its sign (centre, facing) and where it starts.
    Each sign faces you down the straight that leads to its station."""
    return [
        (1, "SLIDE", ("SPRINT (SHIFT),", "THEN PRESS C TO", "SLIDE UNDER"), (-7.2, 63.6), (0, -1),
         (-9.0, 56.0)),
        (2, "GAP JUMP", ("SPRINT AND JUMP", "AT THE VERY EDGE"), (-51.4, 103.0), (0, -1),
         (-51.4, 92.0)),
        (3, "WALL RUN", ("JUMP AT A WALL", "WHILE FAST. YOU", "RUN ALONG IT"), (58.9, 95.0),
         (-1, 0), (2.0, 95.0)),
        (4, "LAUNCH PAD", ("STEP ON IT",), (50.8, 62.4), (0, 1), (52.0, 86.0)),
        (5, "LADDER", ("WALK INTO IT", "AND CLIMB"), (28.0, 87.5), (0, -1), (28.0, 70.0)),
        (6, "TAG DUMMY", ("LEFT CLICK", "TO SWING"), (-30.0, 64.9), (0, 1), (-18.0, 70.0)),
    ]


# Text widths in em (measured in the browser): Titillium Web Heavy for tips, Bangers for titles.
TEXT_EM = {
    "SPRINT (SHIFT),": 7.027, "THEN PRESS C TO": 7.700, "SLIDE UNDER": 5.926,
    "JUMP AT A WALL": 7.317, "WHILE FAST. YOU": 7.628, "RUN ALONG IT": 6.281, "JUMP DURING A": 7.009,
    "WALL RUN TO": 6.056, "LAUNCH OFF": 5.557, "SPRINT AND JUMP": 8.146, "AT THE VERY EDGE": 8.167,
    "WALK INTO IT": 6.021, "AND CLIMB": 4.972, "STEP ON IT": 4.851, "LEFT CLICK": 4.749,
    "TO SWING": 4.484, "SLIDE": 1.714, "WALL RUN": 3.134, "WALL JUMP": 3.514, "GAP JUMP": 3.202,
    "LADDER": 2.402, "LAUNCH PAD": 3.893, "TAG DUMMY": 3.921,
}


def sign_half(title, tips):
    """Half the width of a station sign: the number panel (3), a gap, the text, a margin."""
    text = max(TEXT_EM[title] * TITLE_H, max(TEXT_EM[t] for t in tips) * TIP_H) + 0.3
    return (3.0 + 0.4 + text + 0.6) / 2


def fly(start, velocity, target_y, edge=None):
    """A launch from `start` with `velocity` (the game's drive time, then gravity): where your
    feet come down through target_y, and your height as you cross the platform's edge (`edge` =
    (axis index, value): (2, 62) is z = 62)."""
    x, y, z = start
    vx, vy, vz = velocity
    t, dt, over_edge = 0.0, 1 / 240, None
    while t < 4:
        if t >= LAUNCH_DRIVE:
            vy -= GRAVITY * dt
        x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
        t += dt
        if edge is not None and over_edge is None and \
                ((x, y, z)[edge[0]] - edge[1]) * velocity[edge[0]] >= 0:
            over_edge = y
        if vy < 0 and y <= target_y:
            return x, z, over_edge
    return None


def aim(start, target, top, edge):
    """The gentlest launch velocity that lands on `target` (x, z) at height `top`, crossing the
    platform's edge at least 1.5 above it."""
    dx, dz = target[0] - start[0], target[1] - start[2]
    dist = math.hypot(dx, dz)
    best = None
    for vy in range(30, 90):
        for k in range(40, 400):
            vh = k / 4
            v = (dx / dist * vh, vy, dz / dist * vh)
            hit = fly(start, v, top, edge)
            if not hit:
                continue
            x, z, over = hit
            if math.hypot(x - target[0], z - target[1]) < 0.6 and over and over > top + 1.5:
                if best is None or vh * vh + vy * vy < best[0]:
                    best = (vh * vh + vy * vy, tuple(round(c, 1) for c in v))
                break
    return best[1]


PAD_START = ((LAUNCH_PAD[0] + LAUNCH_PAD[1]) / 2, LAUNCH_PAD[4], (LAUNCH_PAD[2] + LAUNCH_PAD[3]) / 2)
PAD_EDGE = (2, LAUNCH_PLATFORM[3])  # you fly north over the platform's south edge
LAUNCH = aim(PAD_START, LAUNCH_TARGET, LAUNCH_PLATFORM[4] + 0.4, PAD_EDGE)


# ---- the station signs, floor paint and wayfinding -------------------------------------------------------

STATION_COLORS = ("yellow", "cyan", "pink", "lime", "orange", "violet")
SIGN_V = (2.8, 8.7)
TIP_H = 1.1  # tip text height (the brief: at least 0.9)
TITLE_H = 1.5


def pictogram(b, F, g, kind, u, v, w, color):
    """Each station's picture, from flat blocks, in about a 2.4 square centred on (u, v)."""
    step = [0]

    def nxt():
        step[0] += 1
        return w + 0.06 * (step[0] - 1)

    def blk(u0, u1, v0, v1, turn=0.0):
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        b.part(g, "Pictogram", (u1 - u0, v1 - v0, 0.05), F.at(cu, cv, nxt() + 0.025), color,
               rot_about(F.rows, 2, turn), **NEON)

    def head(cu, cv, d=0.5):
        a = nxt()
        b.fdisc(F, g, "Pictogram", cu, cv, a, a + 0.05, d, color, **NEON)

    if kind == "SLIDE":  # sliding under a bar
        blk(u - 1.2, u + 1.2, v + 0.75, v + 0.95)
        blk(u + 0.95, u + 1.15, v - 1.1, v + 0.95)
        blk(u - 0.9, u + 0.5, v - 0.75, v - 0.5, 20)
        head(u - 1.0, v - 0.25)
        blk(u - 1.2, u + 1.2, v - 1.15, v - 1.0)
    elif kind == "WALL RUN":  # running along a wall
        blk(u + 0.9, u + 1.15, v - 1.2, v + 1.2)
        blk(u - 0.3, u - 0.05, v - 0.7, v + 0.5, -18)
        head(u + 0.05, v + 0.85)
        for k in range(3):
            blk(u - 1.25, u - 0.65, v + 0.3 - k * 0.45, v + 0.42 - k * 0.45)
    elif kind == "GAP JUMP":  # two blocks and a jump arc
        blk(u - 1.2, u - 0.4, v - 1.2, v - 0.5)
        blk(u + 0.4, u + 1.2, v - 1.2, v - 0.5)
        blk(u - 0.8, u - 0.1, v + 0.15, v + 0.32, 38)
        blk(u + 0.1, u + 0.8, v + 0.15, v + 0.32, -38)
    elif kind == "LADDER":  # a ladder
        blk(u - 0.75, u - 0.55, v - 1.2, v + 1.2)
        blk(u + 0.55, u + 0.75, v - 1.2, v + 1.2)
        for k in range(4):
            blk(u - 0.55, u + 0.55, v - 0.95 + k * 0.62, v - 0.8 + k * 0.62)
    elif kind == "LAUNCH PAD":  # chevrons going up
        for k in range(3):
            vv = v - 0.8 + k * 0.75
            blk(u - 0.95, u + 0.05, vv, vv + 0.2, 32)
            blk(u - 0.05, u + 0.95, vv, vv + 0.2, -32)
    else:  # a dummy and a swipe
        blk(u - 0.95, u - 0.35, v - 1.2, v + 0.2)
        head(u - 0.65, v + 0.6, 0.6)
        for k, (du, dv, turn) in enumerate(((0.35, 0.75, -40), (0.75, 0.15, -90), (0.4, -0.45, -140))):
            blk(u + du - 0.35, u + du + 0.35, v + dv - 0.09, v + dv + 0.09, turn)


def station_signs(b):
    g = "AlleySigns"
    for (n, title, tips, (x, z), (dx, dz), _start) in stations_info():
        F = Frame(x, 0, z, dx, dz)
        color = STATION_COLORS[n - 1]
        h = sign_half(title, tips)
        v0, v1 = SIGN_V
        with b.stage(3):
            for u in (-h + 1.1, h - 1.1):
                b.fbox(F, g, "SignPost", u - 0.15, u + 0.15, 0, v0, -0.15, 0.15, "black")
            b.fbox(F, g, "StationSign", -h, h, v0, v1, -0.15, 0.15, "plate")
            b.fbox(F, g, "StationSignRim", -h - 0.15, h + 0.15, v0 - 0.15, v1 + 0.15, -0.23, -0.17,
                   color, **NEON)
            b.fbox(F, g, "NumberPanel", -h + 0.3, -h + 3.3, v0 + 0.3, v1 - 0.3, 0.15, 0.2, color,
                   **NEON)
            b.ftext(F, g, "StationNumber", -h + 0.4, -h + 3.2, v1 - 2.7, v1 - 0.4, 0.25, str(n), "ink",
                    "Bangers", "Regular")
            pictogram(b, F, g, title, -h + 1.8, v0 + 1.65, 0.2, "ink")
            b.ftext(F, g, "StationTitle", -h + 3.7, h - 0.3, v1 - 0.3 - TITLE_H, v1 - 0.3, 0.45, title,
                    color, "Bangers", "Regular", "Left", glow=True)
            top = v1 - 0.45 - TITLE_H
            for k, line in enumerate(tips):
                a = top - 0.1 - k * (TIP_H + 0.1)
                b.ftext(F, g, "StationTip", -h + 3.7, h - 0.3, a - TIP_H, a, 0.45, line, "white",
                        "TitilliumWeb", "Heavy", "Left", glow=True)
        with b.stage(4):
            b.fbox(F, g, "Wash", -h + 1, h - 1, 0, WASH_STALL, 0.6, 5.0, color, **NEON,
                   Transparency=0.86)


def floor_mark(b, g, name, x0, x1, z0, z1, color, y=0.0, h=0.05, **kw):
    return b.box(g, name, x0, x1, y, y + h, z0, z1, color, **kw)


def chevron(b, g, x, z, dx, dz, color, size=2.2, y=0.0):
    """A painted chevron on the floor pointing (dx, dz) (its second arm sits on the first where
    they cross)."""
    a = math.degrees(math.atan2(dz, dx))
    for s in (-1, 1):
        off = (-math.cos(math.radians(a)) * 0.45 + s * -math.sin(math.radians(a)) * 0.6,
               -math.sin(math.radians(a)) * 0.45 + s * math.cos(math.radians(a)) * 0.6)
        b.part(g, "Arrow", (size, 0.05, 0.5), (x + off[0], y + 0.025 + (0.05 if s > 0 else 0), z + off[1]),
               color, rot_y(-(a + s * 38)), **NEON, Transparency=0.15)


def floor_text(b, g, name, x, z, w, h, text, color, up=(0, -1), y=0.0, font="Bangers"):
    node = b.part(g, name, (w, h, 0.05), (x, y + 0.06, z), (255, 255, 255), floor_rows(*up),
                  Transparency=1)
    node["children"] = [text_gui("Front", text, color, font,
                                 "Regular" if font == "Bangers" else "Heavy")]
    return node


def alley_paint(b):
    g = "AlleyPaint"
    with b.stage(3):
        x0, x1 = SPRINT_LANE[1], SPRINT_LANE[0]
        z0, z1 = BAR[2], BAR[3]
        for z in (z0, z1):
            floor_mark(b, g, "LaneLine", x0, x1, z - 0.15, z + 0.15, "white")
        floor_mark(b, g, "StartLine", x1 - 0.3, x1 + 0.3, z0 + 0.15, z1 - 0.15, "white")
        floor_text(b, g, "FloorText", -26, 56, 14, 3.6, "SPRINT!", "white", up=(-1, 0))
        floor_text(b, g, "FloorText", -6.5, 51.4, 9, 2.0, "START", "lime", up=(0, 1),
                   font="TitilliumWeb")
        floor_text(b, g, "FloorText", 6.4, 51.4, 9, 2.0, "FINISH", "pink", up=(0, -1),
                   font="TitilliumWeb")
        for (x, z, dx, dz) in ((-6.5, 59.5, -1, 0), (-14, 56.5, -1, 0), (-38, 56.5, -1, 0),
                               (-51.4, 84, 0, 1), (-50, 95.5, 1, 0), (-32, 95, 1, 0),
                               (-15.5, 95, 1, 0), (10, 92, 1, 0), (30, 92, 1, 0), (52, 72, 0, -1),
                               (19, 60, 0, 1), (36, 66, 0, 1), (26, 82, -1, 0), (-14, 82, -1, 0),
                               (-24, 81, 0, -1), (-10, 70, 1, 0), (6, 70, 0, -1), (6, 57, 0, -1)):
            chevron(b, g, x, z, dx, dz, "yellow")
        for (n, title, tips, sign_xz, facing, (x, z)) in stations_info():
            b.cyl(g, "StationSpot", 0.05, 3.6, (x, 0.025, z), STATION_COLORS[n - 1], **NEON,
                  Transparency=0.45)
            floor_text(b, g, "SpotNumber", x, z, 2.4, 2.4, str(n), "ink", up=(0, -1), y=0.0)


WAYPOSTS = (  # (x, z), then blades: text, colour, the way it points
    ((22.0, 31.0), (("SHOP", "yellow", (1, 0)), ("LEADERS", "cyan", (0, -1)),
                    ("TRAINING", "lime", (-0.35, 1)))),
    ((-30.0, -24.0), (("LEADERS", "cyan", (0.4, -1)), ("SHOP", "yellow", (1, 0.05)),
                      ("TRAINING", "lime", (0.25, 1)))),
    ((-54.0, 22.0), (("PLAZA", "pink", (1, 0)), ("TRAINING", "lime", (0.45, 1)))),
    ((108.0, 26.0), (("PLAZA", "pink", (-1, -0.2)), ("LEADERS", "cyan", (-1, -0.6)))),
)


def wayfinding(b):
    g = "Wayfinding"
    for (x, z), blades in WAYPOSTS:
        y0 = floor_at(x, z)
        with b.stage(3):
            b.cyl(g, "SignPole", 15.2 - y0, 0.4, (x, (y0 + 15.2) / 2, z), "black")
            b.ball(g, "SignPoleCap", 0.7, (x, 15.3, z), "black")
            for k, (word, color, (dx, dz)) in enumerate(blades):
                d = norm((dx, 0, dz))
                v = 10.4 + k * 1.6
                for side in (1, -1):
                    nx, nz = -d[2] * side, d[0] * side
                    F = Frame(x, 0, z, nx, nz)
                    s = side  # along the blade: the arrow points to +u on one face, -u on the other
                    if side == 1:
                        b.fbox(F, g, "WayBlade", 0.4, 5.6, v - 0.6, v + 0.6, -0.1, 0.1, color,
                               hang=True, **NEON)
                        b.part(g, "WayArrow", (0.95, 0.95, 0.3), F.at(5.6, v, 0), color,
                               rot_about(F.rows, 2, 45), hang=True, **NEON)
                    u0, u1 = (0.7, 5.2) if s == 1 else (-5.2, -0.7)
                    b.ftext(F, g, "WayText", u0, u1, v - 0.5, v + 0.5, 0.15, word, "ink", "Bangers",
                            "Regular")
        with b.stage(4):
            b.cyl(g, "Wash", 0.25, 7.0, (x, y0 + 0.125, z), "white", **NEON, Transparency=0.9)


# ---- rooftops: water tanks, rooftop signs, fire escapes, antennas ---------------------------------------

def building(name):
    for row in BUILDINGS:
        if row[0] == name:
            return row
    raise KeyError(name)


def face_frame(name, side):
    """The frame on one face of a building (u along it from its left end as you face it)."""
    _, x0, x1, z0, z1, h, _ = building(name)
    for F, length, s, _span in faces(x0, x1, z0, z1):
        if s == side:
            return F, length, h
    raise KeyError(side)


WATER_TANKS = (("NE1", 84.0, -62.0), ("W1", -134.0, 4.0), ("SW1", -92.0, 74.0), ("FS", 126.0, 60.0),
               ("S1", -34.0, 118.0), ("MS2", 86.0, 34.0))
ROOF_SIGNS = (  # building, face, centre along it, width, text, colour
    ("N1", "S", 98.0, 26.0, "HOTEL SPRINT", "cyan"), ("MN1", "W", 11.0, 16.0, "KARAOKE", "pink"),
    ("FE", "W", 36.0, 24.0, "TAGTRONIC", "yellow"), ("S2", "N", 30.0, 24.0, "PIXEL CAFE", "orange"),
    ("NW2", "S", 30.0, 22.0, "ARCADE", "cyan"), ("SE1", "W", 30.0, 20.0, "LAUNDRY 24H", "lime"),
)
FIRE_ESCAPES = (("MS2", "N", 6.0), ("SW1", "E", 40.0), ("FS", "N", 34.0), ("NW2", "S", 18.0),
                ("NE1", "W", 46.0), ("S2", "N", 6.0))


def rooftops(b):
    g = "Rooftops"
    with b.stage(2):
        for name, x, z in WATER_TANKS:
            y = building(name)[5] + 0.6
            for dx, dz in ((-2.4, -2.4), (2.4, -2.4), (-2.4, 2.4), (2.4, 2.4)):
                b.cyl(g, "TankLeg", 4.0, 0.5, (x + dx, y + 2.0, z + dz), "black")
            b.cyl(g, "WaterTank", 7.0, 7.0, (x, y + 7.5, z), "wood_dark")
            for yy in (y + 5.6, y + 9.4):
                b.cyl(g, "TankBand", 0.3, 7.2, (x, yy, z), "metal")
            for k, (h, d) in enumerate(((0.5, 7.6), (0.8, 5.0), (0.6, 2.4))):
                b.cyl(g, "TankRoof", h, d, (x, y + 11.0 + (0, 0.5, 1.3)[k] + h / 2, z), "metal")
        for name, side, a in FIRE_ESCAPES:
            F, _, h = face_frame(name, side)
            fire_escape(b, F, g, a, min(h - 8, 40))
    with b.stage(3):
        for name, side, a, width, text, color in ROOF_SIGNS:
            F, _, h = face_frame(name, side)
            # Legs stand on the roof just behind the edge; the board faces out over the lobby.
            F2 = Frame(*F.at(a, h + 0.6, -2.5), F.W[0], F.W[2])
            for u in (-width / 2 + 1.5, width / 2 - 1.5):
                b.fbox(F2, g, "RoofSignLeg", u - 0.3, u + 0.3, 0, 3.4, -1.0, -0.4, "black")
                b.tube(g, "RoofSignBrace", F2.at(u, 0, -3.0), F2.at(u, 3.0, -1.0), 0.25, "black")
            b.fbox(F2, g, "RoofSignRim", -width / 2 - 0.25, width / 2 + 0.25, 2.95, 9.25, -0.33, -0.27,
                   color, **NEON)
            b.fbox(F2, g, "RoofSign", -width / 2, width / 2, 3.2, 9.0, -0.25, 0.25, "plate")
            b.ftext(F2, g, "RoofSignText", -width / 2 + 0.8, width / 2 - 0.8, 3.7, 8.5, 0.55, text, color,
                    "Bangers", "Regular", glow=True)
    with b.stage(5):
        for name, x, z, tall in (("N1", -40.0, -88.0, 14), ("FE", 166.0, -10.0, 12),
                                 ("NW2", -90.0, -70.0, 10), ("S2", 46.0, 118.0, 12),
                                 ("MN2", 90.0, -30.0, 9)):
            y = building(name)[5] + 0.6
            b.cyl(g, "Antenna", tall, 0.3, (x, y + tall / 2, z), "metal_light")
            for k in (0.55, 0.8):
                b.box(g, "AntennaBar", x - 1.4, x + 1.4, y + tall * k, y + tall * k + 0.15, z - 0.08,
                      z + 0.08, "metal_light")


def fire_escape(b, F, g, a, top):
    """Landings up a facade (from 14) joined by stairs, a railing on each, a drop ladder under the
    lowest. `a` is where it starts along the face (it is 7 wide)."""
    y = 14.0
    k = 0
    while y <= top:
        b.fbox(F, g, "FireLanding", a, a + 7, y - 0.25, y, 0.25, 2.85, "black")
        b.fbox(F, g, "FireRail", a, a + 7, y + 1.15, y + 1.3, 2.7, 2.85, "black")
        for u in (a, a + 6.85):
            b.fbox(F, g, "FireRail", u, u + 0.15, y, y + 1.15, 2.7, 2.85, "black")
        if y + 8 <= top:
            s0, s1 = (a + 0.6, a + 5.6) if k % 2 == 0 else (a + 5.6, a + 0.6)
            p0, p1 = F.at(s0, y, 1.55), F.at(s1, y + 8 - 0.25, 1.55)
            d = tuple(p1[i] - p0[i] for i in range(3))
            length = math.sqrt(sum(c * c for c in d))
            mid = tuple((p0[i] + p1[i]) / 2 for i in range(3))
            # A flight of stairs: a slab tilted between the landings, its width across the face.
            x_axis = norm(d)
            z_axis = F.W
            y_axis = cross(z_axis, x_axis)
            rows = [[x_axis[i], y_axis[i], z_axis[i]] for i in range(3)]
            b.part(g, "FireStair", (length, 0.2, 1.1), mid, "black", rows)
        y += 8
        k += 1
    for u in (a + 5.2, a + 6.4):
        b.fbox(F, g, "DropLadder", u, u + 0.12, 9.6, 13.75, 2.3, 2.42, "black")


# ---- small dressing -------------------------------------------------------------------------------------

MANHOLES = ((60.0, 1.0), (88.0, 0.0), (34.0, 36.0), (-42.0, -34.0), (36.0, 82.0), (112.0, 6.0),
            (0.0, -45.0))
PUDDLES = ((70.0, 3.0, 5.0, "pink"), (92.0, 6.5, 4.0, "cyan"), (36.0, -22.0, 4.0, "cyan"),
           (22.0, -49.0, 5.0, "yellow"), (-24.0, -52.0, 4.5, "pink"), (130.0, 5.0, 4.0, "lime"),
           (30.0, 60.0, 3.2, None), (-36.0, 30.0, 3.6, "lime"), (52.0, -14.0, 2.8, None))
CONES = ((67.5, 3.2), (94.5, 2.6), (24.6, -46.5), (40.0, 66.0))
CRATE_STACKS = ((100.6, -20.5), (100.6, 20.0), (-57.5, -23.0), (-58.0, 64.5), (146.0, 28.0),
                (-112.0, 24.0), (62.0, -43.0))
BARRELS = ((102.0, -24.6), (144.4, 31.6), (-58.0, 99.0), (-112.5, -24.0), (64.0, -46.5),
           (-62.0, -43.0))
DRAINS = ((50.0, 2.0), (76.0, 0.0), (96.0, -1.0), (-44.0, 44.0), (124.0, -33.0), (-84.0, 25.0))
# Cardboard boxes, a few to a pile: (x, z, turn).
BOX_PILES = ((101.8, -16.2, 10), (101.8, 24.6, -8), (-110.5, 19.5, 15), (60.0, -45.5, -12),
             (-57.0, -27.5, 6), (146.0, 23.5, 20), (-61.5, -46.5, -20))
VENDING = ((145.6, -6.0, -1, 0), (145.6, -2.4, -1, 0), (26.0, 45.8, 0, -1), (-53.5, -28.3, 0, 1))
POSTERS = (  # building, face, along, kind
    ("MN1", "W", 7.0, "wanted"), ("MS1", "W", 21.0, "flyer:SPRINT CLUB:lime"),
    ("NW3", "E", 4.0, "flyer:KARAOKE NIGHT:pink"), ("SW2", "E", 6.0, "flyer:NOODLE RUN 5K:yellow"),
    ("SW1", "E", 40.0, "wanted"), ("FS", "N", 6.0, "flyer:LOST: MY SPEED:cyan"),
    ("MS2", "E", 6.0, "wanted"), ("NW2", "S", 5.0, "flyer:TAG TOURNEY:orange"),
)
GRAFFITI = (  # building, face, along, height, width, text, colour, outline
    ("SW1", "E", 22.0, 17.0, 22.0, "TAG YOU'RE IT", "pink", "yellow"),
    ("S1", "N", 30.0, 19.0, 18.0, "RUN!", "lime", "ink"),
    ("S2", "N", 26.0, 19.5, 26.0, "SLIDE!", "cyan", "pink"),
    ("SE1", "W", 24.0, 13.0, 14.0, "UT", "yellow", "pink"),
    ("NW3", "E", 5.0, 12.5, 8.0, "IT", "red", "white"),
)


def dressing(b):
    g = "Dressing"
    with b.stage(5):
        for (x, z) in MANHOLES:
            y = floor_at(x, z)
            b.cyl(g, "Manhole", 0.06, 2.6, (x, y + 0.03, z), (52, 54, 62), Material="Metal")
            b.cyl(g, "ManholeRing", 0.05, 1.9, (x, y + 0.085, z), (38, 40, 48), Material="Metal")
            b.emitter(g, "ManholeSteam", (x, y + 0.4, z), (1.6, 0.2, 1.6), "Steam", rate=5)
        for (x, z, d, tint) in PUDDLES:
            y = floor_at(x, z)
            b.cyl(g, "Puddle", 0.05, d, (x, y + 0.025, z), (26, 34, 56), Material="Glass",
                  Transparency=0.3)
            if tint:
                b.cyl(g, "PuddleGlow", 0.1, d * 0.75, (x, y + 0.05, z), tint, **NEON,
                      Transparency=0.82)
        for (x, z) in DRAINS:  # a grate: a dark frame with bars across it
            y = floor_at(x, z)
            b.box(g, "DrainFrame", x - 1.5, x + 1.5, y, y + 0.05, z - 0.7, z + 0.7, (34, 36, 44),
                  Material="Metal")
            for k in range(6):
                bx = x - 1.25 + k * 0.5
                b.box(g, "DrainBar", bx - 0.1, bx + 0.1, y + 0.05, y + 0.1, z - 0.55, z + 0.55,
                      (70, 74, 84), Material="Metal")
        for k, (x, z, turn) in enumerate(BOX_PILES):
            y = floor_at(x, z)
            rows = rot_y(turn)
            for j, (ox, oz, oy, sx, sy, sz) in enumerate(((0, 0, 0, 2.2, 1.6, 1.8),
                                                          (1.3, 1.6, 0, 1.6, 1.2, 1.4),
                                                          (0.2, -0.1, 1.6, 1.6, 1.1, 1.3))):
                if j == 1 and k % 2:
                    continue
                c, sn = math.cos(math.radians(turn)), math.sin(math.radians(turn))
                px, pz = x + ox * c + oz * sn, z - ox * sn + oz * c
                b.part(g, "CardboardBox", (sx, sy, sz), (px, y + oy + sy / 2, pz),
                       (196, 158, 108), rows, Material="Cardboard")
                b.part(g, "BoxTape", (0.5, 0.05, sz), (px, y + oy + sy + 0.025, pz), (226, 200, 150),
                       rows, Material="Plastic")
        for (x, z) in CONES:
            y = floor_at(x, z)
            b.box(g, "ConeBase", x - 0.7, x + 0.7, y, y + 0.15, z - 0.7, z + 0.7, "orange")
            for k, (d, h0, h1) in enumerate(((1.0, 0.15, 0.95), (0.7, 0.95, 1.75), (0.4, 1.75, 2.35))):
                b.cyl(g, "Cone", h1 - h0, d, (x, y + (h0 + h1) / 2, z), "orange")
            b.cyl(g, "ConeBand", 0.25, 0.76, (x, y + 1.25, z), "white")
        for k, (x, z, dx, dz) in enumerate(((66.0, 7.5, 0, -1), (20.5, -44.5, 0, -1))):
            F = Frame(x, floor_at(x, z), z, dx, dz)
            for s in (1, -1):
                b.part(g, "WetFloorSign", (1.6 if s > 0 else 1.45, 2.6, 0.08), F.at(0, 1.3, s * 0.32),
                       "yellow", rot_about(F.rows, 0, s * 12))
            node = b.part(g, "WetFloorText", (1.4, 1.0, 0.02),
                          local(F.at(0, 1.55, 0.32), rot_about(F.rows, 0, 12), (0, 0, -0.07)),
                          (255, 255, 255), rot_about(F.rows, 0, 12), Transparency=1)
            node["children"] = [text_gui("Front", "WET\nFLOOR", "ink", "TitilliumWeb", "Heavy")]
        for k, (x, z) in enumerate(CRATE_STACKS):
            y = floor_at(x, z)
            n = 2 + (k % 2)
            for j in range(n):
                s = 2.4 - j * 0.3
                ox = (0.2 if j % 2 else -0.15)
                b.box(g, "Crate", x - s / 2 + ox, x + s / 2 + ox, y + j * 2.4 - (0.3 * j * (j - 1) / 2 if j > 1 else 0),
                      y + j * 2.4 + s - (0.3 * j * (j - 1) / 2 if j > 1 else 0), z - s / 2, z + s / 2, "crate")
        for k, (x, z) in enumerate(BARRELS):
            y = floor_at(x, z)
            c = ("mat_blue", "red", "lime")[k % 3]
            b.cyl(g, "Barrel", 2.8, 2.0, (x, y + 1.4, z), c, Material="Metal")
            for yy in (0.7, 2.1):
                b.cyl(g, "BarrelBand", 0.18, 2.06, (x, y + yy, z), "black")
        for k, (x, z, dx, dz) in enumerate(VENDING):
            y = floor_at(x, z)
            F = Frame(x, y, z, dx, dz)
            b.fbox(F, g, "VendingMachine", -1.6, 1.6, 0, 6.2, -2.4, 0, (30, 60, 90), Material="Metal")
            b.fbox(F, g, "VendingGlow", -1.35, 0.6, 1.6, 5.6, 0, 0.06, "cyan", **NEON, Transparency=0.15)
            b.fbox(F, g, "VendingSlot", -1.2, 0.5, 0.5, 1.2, 0, 0.1, "black")
            b.fbox(F, g, "VendingPanel", 0.85, 1.4, 2.8, 4.6, 0, 0.08, "plate")
            b.ftext(F, g, "VendingText", -1.3, 0.55, 4.8, 5.5, 0.12, "DRINKS", "ink", "Bangers", "Regular")
        for name, side, a, kind in POSTERS:
            F, _, _ = face_frame(name, side)
            poster(b, F, g, a, kind)
        for name, side, a, v, width, text, color, outline in GRAFFITI:
            F, _, _ = face_frame(name, side)
            node = b.ftext(F, g, "Graffiti", a - width / 2, a + width / 2, v, v + width * 0.32, 0.06,
                           text, color, "PermanentMarker", "Regular", stroke=outline)
        # Umbrellas over the cafe tables and lounge tables.
        for (x, z) in ((141.0, -14.0), (141.0, 14.0), LOUNGE_ISLANDS[0], LOUNGE_ISLANDS[3]):
            y = floor_at(x, z)
            b.cyl(g, "UmbrellaPole", 9.6 - y, 0.25, (x, (9.6 + y) / 2, z), "metal")
            for k, (d, h, c) in enumerate(((7.4, 0.25, "red"), (5.2, 0.3, "cream"), (2.4, 0.3, "red"))):
                b.cyl(g, "Umbrella", h, d, (x, 9.6 + (0, 0.25, 0.55)[k] + h / 2, z), c, hang=True,
                      Material="Fabric")
            b.ball(g, "UmbrellaTop", 0.5, (x, 10.95, z), "gold")
        # COINS ONLY plates and price tags on the shop counters.
        for key, side, x0, x1, kind, stripes, header, color in STALLS:
            if kind in ("trails", "tags", "titles", "victories"):
                F = stall_frame(side, x0, x1)
                h = (x1 - x0) / 2
                b.fbox(F, g, "CoinsOnly", h - 3.6, h - 0.6, 2.2, 3.0, 0.06, 0.12, "plate")
                b.ftext(F, g, "CoinsOnlyText", h - 3.5, h - 0.7, 2.25, 2.95, 0.17, "COINS ONLY", "gold",
                        "TitilliumWeb", "Heavy", glow=True)
        # Cables strung between the buildings, high over the streets.
        for p0, p1, depth in (((52, 38, -18), (58, 34, 18), 3), ((78, 40, -18), (70, 31, 18), 4),
                              ((96, 33, -18), (90, 36, 18), 3), ((-80, 36, -30), (-74, 30, 30), 4),
                              ((-100, 30, -30), (-108, 34, 30), 3), ((-60, 38, 70), (60, 44, 74), 6),
                              ((-60, 30, 92), (60, 34, 96), 5), ((-50, 30, 32), (-50, 28, -30), 3),
                              ((100, 40, -40), (100, 36, 18), 3), ((-20, 50, -70), (-66, 44, -60), 4),
                              ((120, 42, -36), (148, 40, -8), 3), ((40, 30, -24), (40, 32, 24), 3)):
            pts = [sag(p0, p1, i / 3, depth) for i in range(4)]
            for a_, c_ in zip(pts, pts[1:]):
                b.tube(g, "Cable", a_, c_, 0.12, "black", hang=True)
        # AC units under the windows, some with their fans turning.
        for k, (name, side, a, v) in enumerate((("MN1", "W", 5.0, 16.4), ("MN2", "S", 12.0, 24.4),
                                                ("MS1", "N", 18.0, 16.4), ("MS2", "N", 26.0, 24.4),
                                                ("NW3", "E", 7.0, 16.4), ("SW2", "N", 30.0, 24.4),
                                                ("FS", "N", 18.0, 16.4), ("FN", "S", 30.0, 24.4),
                                                ("SW1", "E", 50.0, 24.4), ("S1", "N", 8.0, 24.4),
                                                ("NE1", "W", 45.0, 16.4), ("W1", "E", 40.0, 26.4))):
            F, _, _ = face_frame(name, side)
            b.fbox(F, g, "ACUnit", a - 1.4, a + 1.4, v - 1.0, v + 1.0, 0.25, 1.85, (170, 176, 186),
                   Material="Metal")
            b.fdisc(F, g, "ACGrille", a, v, 1.85, 1.9, 1.5, (60, 64, 72))
            if k % 3 == 0:
                center = F.at(a, v, 1.95)
                spin = {"Spin": 300, "SpinCenter": vec(*center), "SpinAxis": vec(*F.W)}
                for k2, turn in enumerate((0, 90)):
                    b.part(g, "ACFan", (1.3, 0.22, 0.04), local(center, F.rows, (0, 0, -0.06 * k2)),
                           (40, 42, 48), rot_about(F.rows, 2, turn), attributes=dict(spin))
        for name, side, a in (("MN1", "S", 2.0), ("MS1", "N", 2.0), ("SW2", "E", 1.5),
                              ("NW3", "E", 14.5), ("FS", "N", 46.0), ("S2", "N", 58.0),
                              ("W1", "E", 1.2), ("FN", "S", 47.0)):
            F, _, h = face_frame(name, side)
            b.part(g, "DrainPipe", (h - 0.2, 0.5, 0.5), F.at(a, (h - 0.2) / 2, 0.55), "metal",
                   [[0, -1, 0], [1, 0, 0], [0, 0, 1]], Shape="Cylinder")
        # A big exhaust fan on the noodle bar's wall, turning.
        F = Frame(NOODLE[0], 0, 23.0, 1, 0)
        b.fbox(F, g, "ExhaustBox", -2.2, 2.2, 13.0, 17.4, 0.25, 1.1, (60, 64, 72), Material="Metal")
        center = F.at(0, 15.2, 1.2)
        for k2, turn in enumerate((0, 60, 120)):
            b.part(g, "ExhaustFan", (3.6, 0.5, 0.05), local(center, F.rows, (0, 0, -0.07 * k2)),
                   (130, 136, 146), rot_about(F.rows, 2, turn),
                   attributes={"Spin": 220, "SpinCenter": vec(*center), "SpinAxis": vec(*F.W)})


def poster(b, F, g, a, kind):
    """A paper poster on a wall at eye level."""
    if kind == "wanted":
        b.fbox(F, g, "Poster", a - 1.6, a + 1.6, 3.2, 7.6, 0.05, 0.1, (232, 214, 170))
        b.ftext(F, g, "PosterText", a - 1.4, a + 1.4, 6.6, 7.4, 0.15, "WANTED", "ink", "Bangers", "Regular")
        b.fdisc(F, g, "PosterArt", a, 5.75, 0.1, 0.15, 1.0, "ink")
        b.fbox(F, g, "PosterArt", a - 0.75, a + 0.75, 4.25, 5.25, 0.1, 0.15, "ink")
        b.ftext(F, g, "PosterText", a - 1.4, a + 1.4, 3.35, 4.15, 0.15, "IT", "red", "Bangers", "Regular")
    else:
        text, color = kind.split(":", 1)[1].rsplit(":", 1)
        b.fbox(F, g, "Flyer", a - 1.3, a + 1.3, 3.8, 7.2, 0.05, 0.1, color)
        b.ftext(F, g, "FlyerText", a - 1.15, a + 1.15, 5.0, 7.0, 0.15, text.replace(" ", "\n", 1), "ink",
                "Bangers", "Regular")
        b.fdisc(F, g, "Sticker", a + 1.9, 4.4, 0.05, 0.1, 0.9, ("pink", "cyan", "yellow")[len(text) % 3])
        sparkle(b, F, g, "StickerStar", a - 1.9, 6.0, 0.05, 0.9, "white")


# ---- atmosphere: rain near the lamps, mist ----------------------------------------------------------------

def atmosphere(b):
    g = "Atmosphere"
    with b.stage(4):
        lamps = [((POSTS_R - 1.6) * math.cos(math.radians(i * 22.5)), POST_TOP - 1.2,
                  (POSTS_R - 1.6) * math.sin(math.radians(i * 22.5))) for i in range(0, 16, 2)]
        lamps += [(x, 21.0, z) for (x, z) in ((-58.4, 49.6), (58.4, 63.0), (-58.4, 102.4),
                                             (58.4, 102.4), (0.0, 102.6))]
        lamps += [(124.0, 24.0, 0.0), (-90.0, 15.5, 0.0), (ARCH_X - 3, 26, -10)]
        for k, (x, y, z) in enumerate(lamps):
            for j in range(3):
                r = 1.2 + 2.2 * rand(k, j, 1)
                a = 2 * math.pi * rand(k, j, 2)
                px, pz = x + r * math.cos(a), z + r * math.sin(a)
                if inside_building(px, pz, 0.6):
                    continue
                top = y - 0.6 - 2.0 * rand(k, j, 3)
                length = 2.2 + 1.8 * rand(k, j, 4)
                bottom = max(HANG_MIN + 0.2, top - length)
                b.tube(g, "Rain", (px, top, pz), (px + 0.35, bottom, pz + 0.12), 0.045, (200, 220, 255),
                       hang=True, **NEON, Transparency=0.55)
        for (x, z, w, d) in ((-20, 76, 30, 14), (30, 96, 26, 8), (70, 0, 40, 10), (-80, 0, 30, 30),
                             (124, 0, 24, 30), (0, -55, 60, 10)):
            b.emitter(g, "GroundMist", (x, floor_at(x, z) + 0.6, z), (w, 0.2, d), "Mist", rate=3,
                      color=(150, 160, 210), speed=(0.2, 0.6), life=(4, 7), grow=(4, 9),
                      spread=(80, 80))


# ---- markers, views and the canvas ----------------------------------------------------------------------

def _marker(n, title, role, text, x, y, z):
    return {"n": n, "t": title, "role": role, "d": text, "x": round(x, 2), "y": round(y, 2),
            "z": round(z, 2), "f": 1}


SHOP_PROMPTS = {"deal": "TODAY'S DEAL", "trails": "TRAILS", "tags": "TAG EFFECTS",
                "titles": "TITLES", "victories": "VICTORIES", "crate": "MYSTERY CRATE"}


def markers():
    out = [_marker(1, "Spawn ring", "spawn", "16 spawn spots on a ring of radius %d round the lantern "
                   "pole, all facing north to the boards; from the south side of the ring the Market "
                   "Street arch sits at the right edge of the view. Turn on Spawns to see each spot "
                   "and its facing." % SPAWN_R, 0, 4, SPAWN_R),
           _marker(2, "Plaza center", "center", "The lantern pole (44 high, hung with paper lanterns, "
                   "string lights running out to 16 lamp posts round the plaza) with a ring of "
                   "benches round its base. The plaza is 80 across.", 0, 47, 0)]
    for k, (kind, cx) in enumerate(BOARDS):
        title = BOARD_TEXT[kind][0].title().replace("Leaders", "Leaders")
        out.append(_marker(3 + k, BOARD_TEXT[kind][0] + " screen", "board",
                           "Board %d of 3: %s, %s. 30 x 22 on the facade, bottom at %g, ten rows; "
                           "row text %g tall, readable from the plaza's edge (35 away). The game "
                           "fills this face." % (k + 1, BOARD_TEXT[kind][0], BOARD_TEXT[kind][1],
                                                  BOARD_BOTTOM, ROW_H - 0.2),
                           cx, 20, FACADE_Z + 3))
    n = 6
    for key, side, x0, x1, kind, stripes, header, color in STALLS:
        if key not in SHOP_PROMPTS:
            continue
        z = -COUNTER_FRONT + 0.8 if side == "N" else COUNTER_FRONT - 0.8
        out.append(_marker(n, SHOP_PROMPTS[key] + " prompt", "prompt",
                           "Where this stall's prompt goes: walk up to the counter (3.5 high) to "
                           "open the Shop on its page.", (x0 + x1) / 2, 4.6, z))
        n += 1
    for (sn, title, tips, sign, facing, (x, z)) in stations_info():
        out.append(_marker(n, "Station %d: %s" % (sn, title.title()), "station",
                           STATION_NOTES[sn], x, 5.5, z))
        n += 1
    out.append(_marker(n, "Lap start / finish", "lap", "The gate, split in two by a guide fence: in "
                       "on the west half (START), west down the sprint lane; back out on the east "
                       "half (FINISH) after the tag dummies.", 0, 5, 51))
    return out


STATION_NOTES = {
    1: "In through the gate's west half: a 40-long sprint lane, then the slide bar (underside 4.2, "
       "14 wide), then south through the crate tunnel (12 long, 12 wide, 4.2 inside: crouch).",
    2: "Three platforms 4 high across the south lane, heading east: a 6 gap you can walk-jump, "
       "then an 11 gap that needs a sprint.",
    3: "Sprint off the last platform at the flat wall (48 long, 16 high) beside the 13-wide lane "
       "and run along it; land on the mats at its end.",
    4: "North up the east side: the 6 x 6 chevron pad throws you onto the platform 16 high, 25 "
       "away (mats, a net on its far edges); slide down its ramp into the launch pen.",
    5: "South into the infield: a 4-wide ladder up the brick block to a ledge 14 high and 6 deep; "
       "its slide ramp runs down the other side. The block and ramp close the infield in two, so "
       "the ladder is the only way on.",
    6: "Three padded dummies in a marked ring: left click to swing. Then east and out through the "
       "gate's east half.",
}

ZONES = [
    ("CENTRAL PLAZA", 0, 10, -14), ("LEADERBOARD WALL", 0, 36, -60), ("MARKET STREET", 72, 16, 0),
    ("FOOD COURT", 124, 14, -10), ("NOODLE BAR & LOUNGE", -84, 14, 0), ("TRAINING ALLEY", 0, 26, 76),
]


def views():
    """Saved cameras. Eye views put the camera at a player's eyes (5 up), 120 degrees across."""
    def eye(name, group, x, z, tx, ty, tz, y_extra=0.0):
        y = floor_at(x, z) + EYE + y_extra
        return {"name": name, "group": group, "cam": [x, round(y, 2), z], "at": [tx, ty, tz],
                "fov": 120, "eye": True}

    def orbit(name, group, cam, at, fov=None):
        return {"name": name, "group": group, "cam": list(cam), "at": list(at), "fov": fov}

    s = spawn_points()
    sx, sz = [p for p in s if p[1] > 0 and p[0] > 0][-1]
    out = [
        orbit("Aerial overview", "Overview", (36, 236, 178), (12, 0, 14)),
        orbit("From the south-west", "Overview", (-150, 170, 150), (10, 0, -10)),
        orbit("Training Alley from above", "Overview", (0, 130, 22), (0, 0, 80), 55),
        eye("Spawn ring: facing the boards", "Eye level", sx, sz, sx, 17, FACADE_Z),
        eye("Down Market Street from the arch", "Eye level", 39.0, 0.0, 130, 7, 0),
        eye("Along the shop stalls", "Eye level", 47.0, 7.0, 84, 6, -12),
        eye("Food court", "Eye level", 110.0, 28.5, 130, 8, -24),
        eye("Noodle bar", "Eye level", -58.0, 6.0, -112, 8, -2),
        eye("Training Alley gate", "Eye level", 0.0, 26.0, 0, 9, 60),
        orbit("GLOBAL LEADERS board", "Boards", (-38, 19.8, -36), (-38, 19.8, FACADE_Z), 48),
        orbit("THIS SESSION board", "Boards", (0, 19.8, -36), (0, 19.8, FACADE_Z), 48),
        orbit("RICHEST PLAYERS board", "Boards", (38, 19.8, -36), (38, 19.8, FACADE_Z), 48),
        eye("1 Slide", "Stations", -31.0, 58.0, -46, 4.0, 58.5),
        eye("2 Gap jump", "Stations", -50.0, 95.0, -2, 6, 95),
        eye("3 Wall run", "Stations", -4.0, 95.0, 44, 9, 100, y_extra=GAP_H),
        eye("4 Launch pad", "Stations", 52.0, 92.0, 51, 12, 56, y_extra=RUN_MATS[4]),
        eye("5 Ladder", "Stations", 30.0, 82.0, 18.8, 9, 82),
        eye("6 Tag dummy", "Stations", -14.0, 70.0, -30, 3, 71.5),
    ]
    return out


LIGHTING = {  # the proposed lobby lighting (a Config.MapLighting preset in the game)
    "ClockTime": 23.0, "Brightness": 0.6, "Ambient": [42, 44, 82], "OutdoorAmbient": [52, 58, 108],
    "ColorShift_Top": [120, 140, 255], "FogColor": [86, 88, 150],
    "Atmosphere": {"Density": 0.36, "Haze": 1.6, "Color": [140, 150, 220], "Decay": [80, 70, 140],
                   "Glare": 0.2},
    "Bloom": {"Intensity": 0.9, "Size": 28, "Threshold": 0.85},
    "ColorCorrection": {"Saturation": 0.22, "Contrast": 0.12, "TintColor": [235, 238, 255]},
}

CANVAS = {
    "label": "Design v1",
    "extended": True,
    "labels": [{"t": t, "x": x, "y": y, "z": z, "k": "zone"} for t, x, y, z in ZONES],
    "markers": None,  # filled in below
    "views": None,
    "figure": [0, 0, 0],
    "sky": "#0b1030",
    "lighting": {
        "sky_top": "#0b1030", "sky_horizon": "#2a2c5c", "haze": "#2c2f5e", "fog_density": 0.0034,
        "hemi_sky": "#34407e", "hemi_ground": "#0c0e1c", "hemi": 0.42, "moon": "#9fb4ff",
        "moon_dir": [-0.55, 0.62, -0.56], "moon_intensity": 0.36, "exposure": 1.1, "bloom": 0.5,
        "game": LIGHTING,
    },
    "passes": ["Layout blockout", "Buildings, stalls and structures", "Signs",
               "Lighting and atmosphere", "Small dressing"],
    "legend": {
        "lights": [["Lantern", "#ffb347", "Warm paper lanterns and lamp posts"],
                   ["Stall", "#ffcf7a", "Warm stall and kitchen lights"],
                   ["Neon", "#ff2e93", "Neon washes from the signs"],
                   ["Flood", "#e1eeff", "Cool white floods over Training Alley"],
                   ["Moon", "#9fb4ff", "Cool moonlight from the north-west filling the shadows"]],
        "motion": "Moving: neon flicker, fans (the AC units and the noodle bar's exhaust), steam "
                  "and mist. Nothing else moves.",
    },
    "spawn_facing": [0, -1],
    "budget": PART_BUDGET,
    # The floor heights (for walking at eye level on the canvas): the plaza, promenade, food court
    # and deck; the rest is at 0.
    "floors": [["disc", 0, 0, PLAZA_R, PLAZA_TOP], ["rect", *PROMENADE, 0.15], ["rect", *FOOD, 0.15],
               ["rect", -111, LOUNGE[1], LOUNGE[2], LOUNGE[3], 0.4]],
}
CANVAS["markers"] = markers()
CANVAS["views"] = views()


# ---- checks ---------------------------------------------------------------------------------------------

FLOOR_NAMES = ("Asphalt", "OuterGround", "AlleyFloor", "PlazaFloor", "Promenade", "FoodCourtFloor",
               "Deck")


def jump_reach(drop, speed=SPRINT):
    """How far a running jump carries you before your feet fall `drop` below takeoff. No margin."""
    up = math.sqrt(2 * GRAVITY * JUMP)
    disc = up * up + 2 * GRAVITY * drop
    if disc < 0:
        return 0.0
    return speed * (up + math.sqrt(disc)) / GRAVITY


def clear_runs(m):
    """Solid things that face each other closer than CLEAR_RUN (a narrow way through), except a
    station's own designed gaps (the gap jumps, the dummies)."""
    obstacles = []
    for group, nodes in m.groups.items():
        for node in nodes:
            if node.get("className") not in mapcheck.SOLID_CLASSES:
                continue
            p = mapcheck.Part(node)
            if not p.solid or p.name in FLOOR_NAMES or p.cls == "TrussPart":
                continue
            floor = floor_at(*p.pos[0:1], p.pos[2])
            if p.hi[1] <= floor + 1.05 or p.lo[1] >= floor + 4.5:
                continue  # stepped onto, or over your head
            obstacles.append((p, group))
    problems = []
    for i, (a, ga) in enumerate(obstacles):
        for c, gc in obstacles[i + 1:]:
            if ga == gc and ga.startswith("Station"):
                continue
            ox = min(a.hi[0], c.hi[0]) - max(a.lo[0], c.lo[0])
            oz = min(a.hi[2], c.hi[2]) - max(a.lo[2], c.lo[2])
            gap = None
            if ox > 6 and 2.0 < -oz < CLEAR_RUN:
                gap = -oz
                mid = ((max(a.lo[0], c.lo[0]) + min(a.hi[0], c.hi[0])) / 2,
                       (min(a.hi[2], c.hi[2]) + max(a.lo[2], c.lo[2])) / 2)
            elif oz > 6 and 2.0 < -ox < CLEAR_RUN:
                gap = -ox
                mid = ((min(a.hi[0], c.hi[0]) + max(a.lo[0], c.lo[0])) / 2,
                       (max(a.lo[2], c.lo[2]) + min(a.hi[2], c.hi[2])) / 2)
            if gap is not None and walkable(*mid):
                problems.append("clear run: %s and %s are only %.1f apart near (%.0f, %.0f)" % (
                    a.name, c.name, gap, (a.pos[0] + c.pos[0]) / 2, (a.pos[2] + c.pos[2]) / 2))
    return problems


def hanging(b):
    problems = []
    for node in b.hanging:
        p = mapcheck.Part(node)
        if p.lo[1] < HANG_MIN - 1e-6:
            problems.append("hangs low: %s at (%.1f, %.1f, %.1f) comes down to %.2f" % (
                p.name, p.pos[0], p.pos[1], p.pos[2], p.lo[1]))
    return problems[:20]


def label_heights(m):
    """Board rows at least 1.3 tall, station tips at least 0.9."""
    problems = []
    need = {"RowName": 1.3, "RowValue": 1.3, "StationTip": 0.9, "BoardTitle": 2.0}
    for nodes in m.groups.values():
        for node in nodes:
            name = node["name"].rstrip("0123456789")
            if name in need and node["properties"]["Size"][1] < need[name] - 1e-6:
                problems.append("%s text is only %.2f tall" % (name, node["properties"]["Size"][1]))
    return problems[:10]


def stations_check(m):
    problems = []
    if SPRINT_LANE[0] - SPRINT_LANE[1] != 40 or abs(BAR[3] - BAR[2] - 14) > 1e-6 or BAR[4] != 4.2:
        problems.append("station 1: the sprint lane or slide bar isn't to size")
    if TUNNEL[1] - TUNNEL[0] < CLEAR_RUN or TUNNEL[3] - TUNNEL[2] != 12 or \
            not (mapcheck.CROUCH <= TUNNEL[4] < mapcheck.STAND):
        problems.append("station 1: the crate tunnel isn't 12 long, 12 wide and crouch height")
    gaps = tuple(GAP_PLATFORMS[i + 1][0] - GAP_PLATFORMS[i][1] for i in range(2))
    if gaps != (6.0, 11.0) or GAP_H > mapcheck.JUMP_UP:
        problems.append("station 2: the gaps are %s, not 6 then 11" % (gaps,))
    if gaps[0] > jump_reach(0, WALK) or gaps[1] <= jump_reach(0, WALK) or \
            gaps[1] > jump_reach(0) - mapcheck.JUMP_MARGIN:
        problems.append("station 2: 6 should be a walking jump, 11 a sprinting one")
    if RUN_WALL[1] - RUN_WALL[0] != 48 or RUN_WALL[4] != 16 or \
            abs(S_LANE[1] - S_LANE[0] - 14) > 1 or RUN_WALL[0] > GAP_PLATFORMS[-1][1]:
        problems.append("station 3: the wall run isn't 48 x 16 beside a 14-wide lane, from the "
                        "last platform")
    dist = math.hypot(LAUNCH_TARGET[0] - PAD_START[0], LAUNCH_TARGET[1] - PAD_START[2])
    landing = fly(PAD_START, LAUNCH, LAUNCH_PLATFORM[4] + MAT, PAD_EDGE)
    if LAUNCH_PAD[1] - LAUNCH_PAD[0] != 6 or LAUNCH_PAD[3] - LAUNCH_PAD[2] != 6 or \
            abs(dist - 24) > 3 or not landing or \
            math.hypot(landing[0] - LAUNCH_TARGET[0], landing[1] - LAUNCH_TARGET[1]) > 1:
        problems.append("station 4: the launch pad doesn't land on the platform about 24 away")
    x0, x1, z0, z1, top = LADDER_BLOCK
    if top != 14 or x1 - x0 != 6:
        problems.append("station 5: the ledge isn't 14 high and 6 deep")
    east_guide = min(g[0] for g in GUIDES if g[0] == g[2] and g[0] > x1)
    if east_guide - 0.2 - x1 < CLEAR_RUN:
        problems.append("station 5: something stands in front of the ladder")
    if GUIDE_H <= mapcheck.JUMP_UP:
        problems.append("the guide fences can be jumped")
    if len(spawn_points()) != SPAWNS or any(abs(math.hypot(x, z) - SPAWN_R) > 0.05
                                            for x, z in spawn_points()):
        problems.append("the spawns aren't 16 on a ring of radius 30")
    return problems


def check(m):
    b = m.builder
    problems = []
    if m.count() > PART_BUDGET:
        problems.append("%d parts: over the %d budget" % (m.count(), PART_BUDGET))
    problems += (hanging(b) + clear_runs(m) + label_heights(m) + stations_check(m)
                 + floods_check())
    return problems + mapcheck.check_map(m, ATTRIBUTES)


def build():
    b = Builder()
    ground(b)
    buildings(b)
    plaza(b)
    boards(b)
    promenade(b)
    market(b)
    food_court(b)
    lounge(b)
    alley(b)
    station_signs(b)
    alley_paint(b)
    wayfinding(b)
    rooftops(b)
    dressing(b)
    atmosphere(b)
    b.m.builder = b
    return b.m


if __name__ == "__main__":
    layout = build()
    per_pass = {}
    for nodes in layout.groups.values():
        for node in nodes:
            k = layout.passes.get(id(node), 0)
            per_pass[k] = per_pass.get(k, 0) + 1
    print("%d parts (budget %d), by pass %s; launch pad %s" % (
        layout.count(), PART_BUDGET, dict(sorted(per_pass.items())), LAUNCH))
    issues = check(layout)
    for line in issues:
        print("PROBLEM:", line)
    raise SystemExit(1 if issues else 0)
