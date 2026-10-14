#!/usr/bin/env python3
"""Mini Golf, design v1 (design stage: not in the game yet). 2-6 players: an outdoor mini golf
park, 88 x 72 inside a hedge, sunny. Shown on the "Mini Golf" design canvas (a 2D plan and the
3D model). Built with tools/maplib.py and checked with tools/mapcheck.py like the real map
generators, so it becomes tools/minigolf_layout.py once the design is settled. Run from the repo
root:
    python3 tools/designs/minigolf_v1.py                                     (checks only)
    python3 tools/designs/canvas_export.py minigolf_v1 build/minigolf.json   (for the canvas)

Axes: X east, Z south, Y up. The grass is at 0. Six holes, each built round a big prop you loop
round, cut through or climb:
  1 Windmill (north-east): its felt runs through a tunnel in the windmill's base, 4.2 high:
    slide or crouch through under the turning blades.
  2 Castle (north-west): a curtain wall with a gate to run through, a ramp up to its rampart (8)
    and towers at the ends. The rampart is where the volcano's launch pad throws you.
  3 Volcano (south-west): three rock tiers a jump apart (3, 6, 9) and a launch pad in the crater
    that throws you across to the castle rampart.
  4 Pirate Cove (the middle): a pond you can't wade (fall in and you respawn at a spawn point:
    KillHeight). Cross it on the pier and the pirate ship (deck 4.5, the
    stern 7), the footbridge, or wall-run along the giant leaderboard standing in the water
    (the banks are 18 apart: too far to jump).
  5 Hedge Maze (north): hedges 6 high, too high to jump, with loops through it, not dead ends.
  6 The Hill (south-east): a green on a 4-high plateau with a giant golf ball on its tee.
Plus the clubhouse at the front (doors on three sides, a counter to hop, a ladder up the back to
its roof at 8.6) and trees to juke round.
Moving parts: the windmill's blades turn (around the windmill's axis: SpinAxis, new), a sign
turns on the clubhouse roof, smoke rises from the volcano.
"""
import math
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_x, rot_z  # noqa: E402

OUT = "src/maps/MiniGolf"
KILL = -4  # the pond: fall in and you respawn on the map's spawns
ATTRIBUTES = {"DisplayName": "Mini Golf", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "KillHeight": KILL,
              "OutOfBounds": "Hedge,WindmillBody,WindmillCap,Tower,GiantBall,Mast"}

# Movement numbers the layout is built round (Config + Roblox defaults; see mapcheck).
GRAVITY = 196.2
JUMP = 7.2  # jump height
SPRINT = 30
SLIDE_JUMP = 37
WALL_RUN = 30 * 1.6  # studs along a wall in one wall run
CROUCH_ROOM = 4.2  # slide gates: the gap under them (standing needs 5)
LAUNCH_DRIVE = 0.08  # Config.Gadgets.LaunchDriveTime

# ---- the park ------------------------------------------------------------------------------------
W, D = 44, 36  # inside half width (x) and half depth (z): 88 x 72
HEDGE_H = 6
FELT = 0.2  # felt lies on the grass, this thick
POND = (-20, 20, -12, 6)  # x0, x1, z0, z1
POND_FLOOR = -8
WATER = -0.7  # the water's surface (decoration)
# Hole 1: the windmill.
MILL = (24, 34, -30, -20)
MILL_TUNNEL = (26, 32)  # x of the tunnel through its base
MILL_TOP = 14
BLADE_HUB = (29, 10.5, -19.0)
BLADE_LEN = 5.5
# Hole 2: the castle.
CASTLE = (-38, -22, -30, -26)  # the curtain wall
CASTLE_H = 8
GATE = (-33, -27, 5.6)  # x0, x1, top
TOWERS = ((-40.5, -28), (-19.5, -28))
TOWER_R, TOWER_H = 2.5, 12
CASTLE_RAMP = (-37.6, -33.6, -14)  # x0, x1, z of its foot (it rises north to the rampart)
# Hole 3: the volcano.
VOLCANO = (-30, 18)
TIERS = ((9, 3), (6.5, 6), (4, 9))  # radius, top
LAUNCH = (0, 56, -62)  # the crater pad's LaunchVelocity: onto the castle rampart
# Hole 4: the pirate cove.
HULL = (-8, 4, -9, -3)  # x0, x1, z0, z1 of the main deck
DECK = 4.5
STERN = (4, 9, 7)  # x0, x1, top
BOW_TIP = -12
PIER = (-1, 3, 1.0)  # x0, x1, top (it runs from the hull to the south bank)
BRIDGE = (10, 14, 1.0)  # x0, x1, top (across the pond, north bank to south bank)
BOARD_X = -16  # the leaderboard stands in the water along Z here
BOARD = (-10, 4, 1.5, 10)  # z0, z1, bottom, top
# Hole 5: the hedge maze: cells 4 wide between hedges 1 thick.
MAZE_X = (-12.5, -7.5, -2.5, 2.5, 7.5, 12.5)  # hedge lines (centers) along X
MAZE_Z = (-31, -26, -21)  # hedge lines along Z
MAZE_H = 6
# Which hedge segments stand: across (at a Z line, over a column of cells) and along (at an X
# line, over a row of cells). The gaps are the ways through.
MAZE_ACROSS = {0: (0, 1, 3, 4), 1: (1, 3), 2: (1, 2, 3)}
MAZE_ALONG = {0: (1,), 1: (0,), 2: (1,), 3: (1,), 4: (0,), 5: (1,)}
# Hole 6: the hill.
HILL = (26, 40, 14, 30, 4)  # x0, x1, z0, z1, top
HILL_RAMP = (30, 34, 8)  # x0, x1, z of its foot (it rises south onto the hill)
BALL = (35.5, 22, 4)  # x, z, radius (on a tee on the hill)
# The clubhouse.
CLUB = (-10, 10, 22, 30)
CLUB_H = 8
ROOF_TOP = 8.6
LADDER_COLUMN = (5, 8, 30, 32)
TREES = ((40, -18), (39, 4), (16, 16), (-14, 31), (-20, -16), (40, -32), (20, 31), (-41, 4))

FELTS = {  # hole: (x0, x1, z0, z1, floor) of its felt
    1: (26, 32, -34, -16, 0), 2: (-33, -27, -34, -16, 0), 3: (-21.5, -13, 16, 20, 0),
    4: (-1, 3, 6, 16, 0), 5: (-2, 2, -25.5, -21.5, 0), 6: (28, 34, 20, 24, 4),
}
CUPS = {1: (29, -32.5, 0), 2: (-30, -32.5, 0), 3: (-19.5, 18, 0), 4: (0, -6, DECK),
        5: (0, -23.5, 0), 6: (29.5, 22, 4)}
HOLE_NAMES = {1: "WINDMILL", 2: "CASTLE", 3: "VOLCANO", 4: "PIRATE COVE", 5: "HEDGE MAZE",
              6: "THE HILL"}

COLORS = {
    "grass": (106, 190, 75), "felt": (40, 168, 90), "bumper": (250, 250, 246),
    "hedge": (46, 128, 62), "water": (60, 170, 235), "pond_wall": (120, 116, 108),
    "pond_floor": (40, 70, 90), "wood": (150, 104, 62), "dark_wood": (100, 66, 40),
    "mill": (238, 226, 200), "mill_roof": (200, 70, 60), "blade": (250, 246, 236),
    "stone": (168, 166, 160), "stone_dark": (122, 120, 116), "rock": (110, 92, 82),
    "rock_dark": (84, 70, 64), "lava": (255, 110, 30), "pad": (255, 214, 10),
    "hull": (130, 80, 46), "sail": (250, 248, 240), "ink": (24, 24, 28), "club": (250, 244, 232),
    "club_roof": (40, 120, 200), "trim": (255, 214, 10), "sand": (236, 214, 160),
    "flag": (232, 66, 63), "white": (255, 255, 255), "board": (24, 30, 44), "pink": (255, 46, 136),
    "cyan": (25, 200, 230), "trunk": (110, 76, 50), "leaves": (70, 160, 70),
    "golfball": (248, 248, 248), "cup": (20, 24, 22), "path": (214, 206, 190),
}
MATERIALS = {
    "grass": "Grass", "felt": "Fabric", "hedge": "Grass", "pond_wall": "Slate",
    "wood": "WoodPlanks", "dark_wood": "Wood", "mill": "Plaster", "mill_roof": "Brick",
    "stone": "Cobblestone", "stone_dark": "Cobblestone", "rock": "Rock", "rock_dark": "Basalt",
    "hull": "WoodPlanks", "sail": "Fabric", "club": "Plaster", "club_roof": "Metal",
    "sand": "Sand", "trunk": "Wood", "leaves": "Grass", "path": "Pavement",
}
DETAIL = dict(NO_HIT, CastShadow=False)


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def ramp_z(m, g, name, x0, x1, za, ya, zb, yb, color, thick=0.6, **props):
    """A slab whose top runs straight from (za, ya) to (zb, yb) along Z."""
    dz, dy = zb - za, yb - ya
    ang = math.degrees(math.atan(dy / -dz))
    a = math.radians(ang)
    normal = (0, math.cos(a), math.sin(a))
    mid = ((x0 + x1) / 2, (ya + yb) / 2, (za + zb) / 2)
    pos = tuple(mid[i] - 0.5 * thick * normal[i] for i in range(3))
    return m.part(g, name, (x1 - x0, thick, math.hypot(dz, dy)), pos, color, rot_x(ang), **props)


def sign(m, g, name, x, z, text, color, facing="Back", width=5, post_h=3.2):
    """A hole sign on a post (decoration): the board faces +Z ("Back") or -Z ("Front")."""
    m.block(g, name + "Post", x - 0.15, x + 0.15, 0, post_h, z - 0.15, z + 0.15, "dark_wood",
            **DETAIL)
    m.block(g, name, x - width / 2, x + width / 2, post_h, post_h + 1.4, z - 0.2, z + 0.2, color,
            **DETAIL, children=[m.surface_text(f, text, COLORS["ink"], pps=12)
                                for f in ("Front", "Back")])


# ---- the ground, the hedge, the pond -------------------------------------------------------------

def grounds(m):
    g = "Ground"
    # The ground: one slab down to the pond's floor, with the pond cut out of it.
    m.slab(g, "Grass", (-W - 2, W + 2, -D - 2, D + 2), POND_FLOOR, 0, [POND], "grass")
    x0, x1, z0, z1 = POND
    m.block(g, "PondFloor", x0, x1, POND_FLOOR - 1, POND_FLOOR, z0, z1, "pond_floor")
    m.block("Details", "Water", x0, x1, WATER - 0.1, WATER, z0, z1, "water",
            Transparency=0.35, Material="Glass", **DETAIL)
    # Stone edging round the pond (decoration on the grass).
    fx0, fx1 = FELTS[4][0] - 0.6, FELTS[4][1] + 0.6  # hole 4's felt and bumpers meet the pond
    for a, b, c, d in ((x0 - 0.8, x1 + 0.8, z0 - 0.8, z0), (x0 - 0.8, fx0, z1, z1 + 0.8),
                       (fx1, x1 + 0.8, z1, z1 + 0.8), (x0 - 0.8, x0, z0, z1),
                       (x1, x1 + 0.8, z0, z1)):
        m.block("Details", "PondEdge", a, b, 0.05, 0.25, c, d, "stone", **DETAIL)
    # The hedge round the park, and an invisible wall above it.
    for a, b, c, d in ((-W - 2, W + 2, -D - 2, -D), (-W - 2, W + 2, D, D + 2),
                       (-W - 2, -W, -D, D), (W, W + 2, -D, D)):
        m.block(g, "Hedge", a, b, 0, HEDGE_H, c, d, "hedge")
        m.block(g, "Boundary", a, b, HEDGE_H, 40, c, d, (255, 255, 255), Transparency=1,
                CastShadow=False)
    # A path from the clubhouse door to the first tees (decoration).
    m.block("Details", "Path", -5, 5, 0.05, 0.1, 16.5, 21.5, "path", **DETAIL)


def felts(m):
    """The holes' felt (a floor finish on the grass or the hill), bumpers along their long sides
    where nothing else stands, cups and flags."""
    g = "Course"
    d = "Details"
    for hole, (x0, x1, z0, z1, floor) in FELTS.items():
        m.block(g, "Felt", x0, x1, floor, floor + FELT, z0, z1, "felt")
        cx, cz, cy = CUPS[hole]
        top = (DECK if hole == 4 else floor + FELT)
        m.cylinder(d, "Cup", 0.04, 1.3, (cx, top + 0.07, cz), "cup", **DETAIL)
        px = cx + 0.9  # the flag stands beside the cup
        m.block(d, "FlagPole", px - 0.08, px + 0.08, top, top + 4.5, cz - 0.08, cz + 0.08,
                "white", **DETAIL)
        m.block(d, "Flag", px + 0.08, px + 1.6, top + 3.4, top + 4.4, cz - 0.04, cz + 0.04,
                "flag", **DETAIL, children=[m.surface_text(f, str(hole), COLORS["white"], pps=20)
                                            for f in ("Front", "Back")])
    # Bumpers (low white rails, a step over) along the felts' long sides, outside the props.
    for x0, x1, z0, z1 in ((26, 32, -20, -16), (26, 32, -34, -30), (-33, -27, -26, -16),
                           (-33, -27, -34, -30)):
        for a, b in ((x0 - 0.6, x0), (x1, x1 + 0.6)):
            m.block(g, "Bumper", a, b, 0, 0.8, z0, z1, "bumper")
    for z0, z1 in ((15.4, 16), (20, 20.6)):
        m.block(g, "Bumper", -21, -13, 0, 0.8, z0, z1, "bumper")
    for a, b in ((-1.6, -1), (3, 3.6)):
        m.block(g, "Bumper", a, b, 0, 0.8, 6.8, 16, "bumper")
    for hole, (x, z, facing) in {1: (35.5, -14, "Back"), 2: (-24.5, -14, "Back"),
                                 3: (-12, 22.5, "Back"), 4: (6, 12, "Back"),
                                 5: (0, -18.5, "Back"), 6: (36, 12.5, "Back")}.items():
        sign(m, d, "HoleSign", x, z, f"{hole}  {HOLE_NAMES[hole]}",
             ("pink", "cyan", "trim", "pink", "cyan", "trim")[hole - 1], facing)


# ---- hole 1: the windmill ------------------------------------------------------------------------

def windmill(m):
    g = "Windmill"
    d = "Details"
    x0, x1, z0, z1 = MILL
    t0, t1 = MILL_TUNNEL
    for a, b in ((x0, t0), (t1, x1)):  # the legs either side of the tunnel
        m.block(g, "WindmillBody", a, b, 0, CROUCH_ROOM + FELT, z0, z1, "mill")
    m.block(g, "WindmillBody", x0, x1, CROUCH_ROOM + FELT, MILL_TOP, z0, z1, "mill")
    m.block(g, "StandBlocker", t0, t1, FELT, CROUCH_ROOM + FELT, z0, z1, (255, 255, 255),
            Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
    m.block(g, "WindmillCap", x0 + 1, x1 - 1, MILL_TOP, MILL_TOP + 2, z0 + 1, z1 - 1, "mill_roof")
    m.block(g, "WindmillCap", x0 + 2.5, x1 - 2.5, MILL_TOP + 2, MILL_TOP + 4, z0 + 2.5, z1 - 2.5,
            "mill_roof")
    # Windows and a door painted on (decoration off the walls).
    for x in (x0 + 2, x1 - 3.5):
        m.block(d, "MillWindow", x, x + 1.5, 8, 10.5, z1 + 0.05, z1 + 0.1, "board", **DETAIL)
    m.block(d, "MillSign", t0 + 0.5, t1 - 0.5, 5.4, 6.6, z1 + 0.05, z1 + 0.1, "trim", **DETAIL,
            children=[m.surface_text("Back", "HOLE 1", COLORS["ink"], pps=14)])
    # The blades turn round the windmill's axis (+Z), high enough to run under.
    hx, hy, hz = BLADE_HUB
    turning = {"Spin": 40, "SpinCenter": vec(hx, hy, hz), "SpinAxis": vec(0, 0, 1)}
    m.cylinder(d, "BladeHub", 0.8, 1.6, (hx, hy, hz - 0.1), "dark_wood", rows=rot_y90(),
               attributes=turning, **DETAIL)
    for k in range(4):
        ang = 45 + 90 * k
        a = math.radians(ang)
        r = (0.8 + BLADE_LEN) / 2
        m.part(d, "Blade", (BLADE_LEN - 0.8, 1.4, 0.15),
               (hx + r * math.cos(a), hy + r * math.sin(a), hz + 0.4), "blade", rot_z(ang),
               attributes=turning, **DETAIL)


def rot_y90():
    """A cylinder's length (its X) turned to run along Z."""
    return [[0, 0, -1], [0, 1, 0], [1, 0, 0]]


# ---- hole 2: the castle --------------------------------------------------------------------------

def castle(m):
    g = "Castle"
    d = "Details"
    x0, x1, z0, z1 = CASTLE
    gx0, gx1, top = GATE
    m.wall(g, "X", (z0, z1), (x0, x1), 0, CASTLE_H, "stone", openings=[(gx0, gx1, top)],
           name="CastleWall")
    for x, z in TOWERS:
        m.cylinder(g, "Tower", TOWER_H, TOWER_R * 2, (x, TOWER_H / 2, z), "stone_dark")
        for k in range(8):  # merlons round the tower top
            a = math.radians(22.5 + 45 * k)
            px, pz = x + (TOWER_R - 0.5) * math.cos(a), z + (TOWER_R - 0.5) * math.sin(a)
            m.block(d, "Merlon", px - 0.45, px + 0.45, TOWER_H, TOWER_H + 1.2, pz - 0.45, pz + 0.45,
                    "stone_dark", **DETAIL)
        m.block(d, "Banner", x - 0.6, x + 0.6, TOWER_H + 1.2, TOWER_H + 4, z - 0.04, z + 0.04,
                "pink", **DETAIL)
    for k in range(int((x1 - x0) / 2)):  # merlons along the rampart's back edge
        px = x0 + 1 + 2 * k
        if TOWERS[0][0] + TOWER_R < px - 0.5 and px + 0.5 < TOWERS[1][0] - TOWER_R:
            m.block(d, "Merlon", px - 0.5, px + 0.5, CASTLE_H, CASTLE_H + 1.2, z0, z0 + 1,
                    "stone", **DETAIL)
    rx0, rx1, foot = CASTLE_RAMP
    ramp_z(m, g, "CastleRamp", rx0, rx1, foot, 0, z1, CASTLE_H, "dark_wood")
    m.block(d, "GateSign", gx0 + 0.5, gx1 - 0.5, top + 0.4, top + 1.6, z1 + 0.05, z1 + 0.1, "trim",
            **DETAIL, children=[m.surface_text("Back", "HOLE 2", COLORS["ink"], pps=14)])


# ---- hole 3: the volcano -------------------------------------------------------------------------

def volcano(m):
    g = "Volcano"
    d = "Details"
    vx, vz = VOLCANO
    bottom = 0
    for k, (radius, top) in enumerate(TIERS):
        m.cylinder(g, "Volcano", top - bottom, radius * 2, (vx, (top + bottom) / 2, vz),
                   ("rock", "rock_dark", "rock")[k])
        bottom = top
    crater = TIERS[-1][1]
    m.cylinder(d, "Lava", 0.05, (TIERS[-1][0] - 0.4) * 2, (vx, crater + 0.075, vz), "lava",
               Material="Neon", **DETAIL)
    m.cylinder(g, "LaunchPad", 0.3, 3.6, (vx, crater + 0.15, vz), "pad",
               attributes={"LaunchVelocity": vec(*LAUNCH)},
               children=[m.particles("Smoke", rate=6, life=(2, 3.5), speed=(4, 8), size=((0, 2),
                                     (1, 6)), transparency=((0, 0.4), (1, 1)),
                                     color=(90, 86, 84))])


# ---- hole 4: the pirate cove ---------------------------------------------------------------------

def cove(m):
    g = "Cove"
    d = "Details"
    hx0, hx1, hz0, hz1 = HULL
    sx0, sx1, stern = STERN
    m.block(g, "Hull", hx0, hx1, POND_FLOOR, DECK, hz0, hz1, "hull")
    m.block(g, "Hull", sx0, sx1, POND_FLOOR, stern, hz0, hz1, "hull")
    mid = (hz0 + hz1) / 2
    for side in (hz0, hz1):  # the bow: two flat wedges meeting at the tip
        m.flat_triangle(g, "Hull", (hx0, mid), (hx0, side), (BOW_TIP, mid), POND_FLOOR, DECK,
                        "hull")
    # Rails, a mast with a sail and a crow's nest, a flag, cannons (decoration).
    for z0, z1 in ((hz0, hz0 + 0.3), (hz1 - 0.3, hz1)):
        m.block(d, "ShipRail", hx0 + 0.2, hx1, DECK, DECK + 1.1, z0, z1, "dark_wood", **DETAIL)
        m.block(d, "ShipRail", sx0, sx1 - 0.2, stern, stern + 1.1, z0, z1, "dark_wood", **DETAIL)
    m.block(g, "Mast", -2.5, -1.5, DECK, 18, mid - 0.5, mid + 0.5, "dark_wood")
    m.block(d, "Sail", -1.42, -1.32, 8, 15.5, hz0 - 0.5, hz1 + 0.5, "sail", **DETAIL)
    m.block(d, "CrowsNest", -3.5, -0.5, 16, 17, mid - 1.5, mid + 1.5, "wood", **DETAIL)
    m.block(d, "PirateFlag", -1.45, -1.4, 18, 19.6, mid - 1.2, mid + 1.2, "ink", **DETAIL)
    for x in (-5, 0):
        for z, out in ((hz0, -1), (hz1, 1)):
            m.cylinder(d, "Cannon", 1.6, 0.7, (x, DECK - 1.2, z + out * 0.75), "ink",
                       rows=rot_y90(), **DETAIL)
    m.block(d, "ShipName", hx0 + 2, hx0 + 8, 1.2, 2.6, hz1 + 0.05, hz1 + 0.1, "trim", **DETAIL,
            children=[m.surface_text("Back", "THE BOGEY", COLORS["ink"], pps=12)])
    # The pier from the south bank to the ship, on pilings.
    px0, px1, ptop = PIER
    m.block(g, "Pier", px0, px1, ptop - 0.5, ptop, hz1, POND[3], "wood")
    for x in (px0 + 0.4, px1 - 0.4):
        for z in (hz1 + 1, (hz1 + POND[3]) / 2, POND[3] - 1):
            m.cylinder(g, "Piling", ptop - 0.5 - POND_FLOOR, 0.6,
                       (x, (ptop - 0.5 + POND_FLOOR) / 2, z), "dark_wood")
    # The footbridge across the east end.
    bx0, bx1, btop = BRIDGE
    m.block(g, "Bridge", bx0, bx1, btop - 0.6, btop, POND[2], POND[3], "wood")
    for x in (bx0 + 0.15, bx1 - 0.15):
        m.block(d, "BridgeRail", x - 0.15, x + 0.15, btop + 0.9, btop + 1.15, POND[2], POND[3],
                "dark_wood", **DETAIL)
        for z in range(POND[2] + 2, POND[3], 4):
            m.block(d, "BridgePost", x - 0.15, x + 0.15, btop, btop + 0.9, z - 0.15, z + 0.15,
                    "dark_wood", **DETAIL)
    for z in (POND[2] + 6, POND[3] - 6):
        m.block(g, "BridgePier", bx0 + 1, bx1 - 1, POND_FLOOR, btop - 0.6, z - 1, z + 1, "stone")
    # The giant leaderboard standing in the water: wall-run along it across the pond.
    z0, z1, bottom, top = BOARD
    m.block(g, "Leaderboard", BOARD_X - 0.2, BOARD_X + 0.2, bottom, top, z0, z1, "board",
            children=[m.surface_text(f, "LEADERBOARD", COLORS["trim"], pps=8, glow=True)
                      for f in ("Left", "Right")])
    for z in (z0 + 0.4, z1 - 0.4):
        m.block(g, "BoardPost", BOARD_X - 0.4, BOARD_X + 0.4, POND_FLOOR, bottom, z - 0.4, z + 0.4,
                "stone_dark")


# ---- hole 5: the hedge maze ----------------------------------------------------------------------

def maze(m):
    g = "Maze"
    for x in MAZE_X:  # posts at every crossing
        for z in MAZE_Z:
            m.block(g, "Hedge", x - 0.5, x + 0.5, 0, MAZE_H, z - 0.5, z + 0.5, "hedge")
    for line, cols in MAZE_ACROSS.items():
        z = MAZE_Z[line]
        for c in cols:
            m.block(g, "Hedge", MAZE_X[c] + 0.5, MAZE_X[c + 1] - 0.5, 0, MAZE_H, z - 0.5, z + 0.5,
                    "hedge")
    for line, rows in MAZE_ALONG.items():
        x = MAZE_X[line]
        for r in rows:
            m.block(g, "Hedge", x - 0.5, x + 0.5, 0, MAZE_H, MAZE_Z[r] + 0.5, MAZE_Z[r + 1] - 0.5,
                    "hedge")


# ---- hole 6: the hill ----------------------------------------------------------------------------

def hill(m):
    g = "Hill"
    d = "Details"
    x0, x1, z0, z1, top = HILL
    m.block(g, "Hill", x0, x1, 0, top, z0, z1, "rock")
    rx0, rx1, foot = HILL_RAMP
    ramp_z(m, g, "HillRamp", rx0, rx1, foot, 0, z0, top, "path")
    bx, bz, radius = BALL
    m.cylinder(g, "Tee", 1.6, 1.2, (bx, top + 0.8, bz), "pink")
    m.part(g, "GiantBall", (radius * 2,) * 3, (bx, top + 1.5 + radius, bz), "golfball",
           Shape="Ball")
    for x0_, x1_, z0_, z1_ in ((18, 24, 18, 24), (21, 26, 8, 12)):  # sand bunkers
        m.block(d, "Bunker", x0_, x1_, 0.05, 0.1, z0_, z1_, "sand", **DETAIL)


# ---- the clubhouse -------------------------------------------------------------------------------

def clubhouse(m):
    g = "Clubhouse"
    d = "Details"
    x0, x1, z0, z1 = CLUB
    m.wall(g, "X", (z0, z0 + 1), (x0, x1), 0, CLUB_H, "club", name="ClubWall",
           openings=[(-8, -4, 6, 3), (-2, 2, 6), (4, 8, 6, 3)], frame=(40, 120, 200))
    m.wall(g, "X", (z1 - 1, z1), (x0, x1), 0, CLUB_H, "club", name="ClubWall")
    for a, b in ((x0, x0 + 1), (x1 - 1, x1)):
        m.wall(g, "Z", (a, b), (z0 + 1, z1 - 1), 0, CLUB_H, "club", name="ClubWall",
               openings=[(24, 28, 6)])
    m.block(g, "ClubRoof", x0 - 0.5, x1 + 0.5, CLUB_H, ROOF_TOP, z0 - 0.5, z1, "club_roof")
    m.block(g, "Counter", -6, 6, 0, 3.5, 26.5, 27.5, "wood")
    m.block(d, "ClubSign", -4, 4, 6.4, 7.6, z0 - 0.1, z0 - 0.05, "trim", **DETAIL,
            children=[m.surface_text("Front", "CLUBHOUSE", COLORS["ink"], pps=12)])
    m.block(d, "MenuBoard", -5, 5, 4.5, 6.5, z1 - 1.1, z1 - 1.05, "board", **DETAIL,
            children=[m.surface_text("Front", "PUTTERS · BALLS · SNACKS", COLORS["trim"], pps=12)])
    for x in (-7, 7):  # racks of putters (decoration)
        m.block(d, "PutterRack", x - 1, x + 1, 0, 3, z1 - 1.8, z1 - 1.05, "dark_wood", **DETAIL)
    # The ladder up the back to the roof, on a column.
    cx0, cx1, cz0, cz1 = LADDER_COLUMN
    m.block(g, "LadderColumn", cx0, cx1, 0, ROOF_TOP, cz0, cz1, "club")
    m.ladder(g, (cx0 + cx1) / 2, cz1, (0, 1), 0, ROOF_TOP, width=2)
    # A sign turning on the roof (decoration).
    m.block(d, "SignPole", -0.2, 0.2, ROOF_TOP, 13, 25.8, 26.2, "ink", **DETAIL)
    m.block(d, "RoofSign", -4, 4, 13, 15.6, 25.85, 26.15, "pink", **DETAIL,
            attributes={"Spin": 30, "SpinCenter": vec(0, 14.3, 26)},
            children=[m.surface_text(f, "MINI GOLF", COLORS["white"], pps=10, glow=True)
                      for f in ("Front", "Back")])


def trees(m):
    for x, z in TREES:
        m.cylinder("Trees", "Trunk", 4.5, 1.2, (x, 2.25, z), "trunk")
        m.part("Details", "TreeTop", (6, 6, 6), (x, 6.5, z), "leaves", Shape="Ball", **DETAIL)


# ---- demo players for the canvas (the game ignores these) ----------------------------------------

def demo_players():
    """Paths for figures acting out a round on the canvas: closed loops of [x, y, z, flag] points.
    Flags: "j" jumps (or drops) into that point, "L" is thrown there by a launch pad, "c" is a
    slide or crouch, "wr"/"wl" a wall run with the wall on the right/left."""
    f = FELT
    chase = [[-13, 0, 19, ""], [13, 0, 19, ""], [13, 0, 34, ""], [-13, 0, 34, ""]]
    pond = [  # a wall run along the leaderboard, onto the ship, off the stern, over the bridge
        [-14.6, 0, 10, ""], [-14.6, 0, 7, ""], [-14.6, 1.6, 3, "wl"], [-14.6, 2.6, -3, "wl"],
        [-14.6, 1.6, -9.5, "wl"], [-14.6, 0, -13.5, ""], [-5, 0, -13.5, ""],
        [-4, DECK, -7.5, "j"], [2.5, DECK, -6, ""], [6, STERN[2], -6, "j"], [8, STERN[2], -6, ""],
        [12, BRIDGE[2], -4, "j"], [12, BRIDGE[2], 5, ""], [12, 0, 8, ""], [-12, 0, 9, ""],
    ]
    mill = [  # up the felt and through the windmill's tunnel, back round the maze side
        [29, f, -14, ""], [29, f, -19, ""], [29, f, -20.5, "c"], [29, f, -29.5, "c"],
        [29, f, -31.5, ""], [26, 0, -33.8, ""], [18.5, 0, -33.8, ""], [18.5, 0, -14, ""],
    ]
    launch = [  # up the volcano, thrown onto the castle rampart, down and back
        [-19.5, 0, 22, ""], [-22.4, TIERS[0][1], 21, "j"], [-25.6, TIERS[1][1], 20, "j"],
        [-28.5, TIERS[2][1], 18.5, "j"], [-30, TIERS[2][1] + 0.3, 18, ""],
        [-30, CASTLE_H, -28, "L"], [-24, CASTLE_H, -28, ""], [-23.5, 0, -22, "j"],
        [-22.5, 0, -14, ""], [-22.5, 0, 8, ""], [-19.5, 0, 14, ""],
    ]
    return [
        {"tag": "", "color": "#3C82F0", "speed": 14, "offset": 0, "points": chase},
        {"tag": "IT", "color": "#E8423F", "speed": 14, "offset": -0.7, "points": chase},
        {"tag": "", "color": "#4CC46A", "speed": 13, "offset": 0, "points": pond,
         "cam": "Pond runner"},
        {"tag": "", "color": "#F2C94C", "speed": 11, "offset": 0, "points": mill},
        {"tag": "", "color": "#A66BFF", "speed": 12, "offset": 0, "points": launch,
         "cam": "Launch"},
    ]


SPAWNS = ((-6, 18), (6, 18), (-30, 3), (30, 3), (-24, -17), (20, -22), (0, -16), (38, -27))


def build():
    m = Map(COLORS, MATERIALS)
    grounds(m)
    felts(m)
    windmill(m)
    castle(m)
    volcano(m)
    cove(m)
    maze(m)
    hill(m)
    clubhouse(m)
    trees(m)
    for x, z in SPAWNS:
        m.spawn(x, z)
    return m


# ---- the design canvas ---------------------------------------------------------------------------

def _label(text, x, y, z, kind="zone"):
    return {"t": text, "x": x, "y": y, "z": z, "f": 1, "k": kind}


def _marker(n, title, text, x, y, z):
    return {"n": n, "t": title, "d": text, "x": x, "y": y, "z": z, "f": 1}


CANVAS = {
    "label": "Design v1",
    "labels": [
        _label("1 Windmill", 29, 20, -25), _label("2 Castle", -30, 15, -28),
        _label("3 Volcano", -30, 13, 18), _label("4 Pirate Cove", 0, 21, -6),
        _label("5 Hedge Maze", 0, 8, -26), _label("6 The Hill", 33, 15, 22),
        _label("Clubhouse", 0, 17, 26),
        _label("Rampart · 8 up", -30, 10, -26.5, "feature"),
        _label("Leaderboard run", BOARD_X, 11.5, -3, "feature"),
        _label("Launch pad", -30, 10.5, 18, "feature"),
        _label("Roof · 8.6 up", 0, 10, 23, "feature"),
    ],
    "markers": [
        _marker(1, "Windmill", "Hole 1 runs through a tunnel in the windmill's base, 4.2 high: "
                "slide or crouch through under the turning blades. Its walls are 14 high, good "
                "for a wall run round the corner.", 29, 16, -18),
        _marker(2, "Castle", "A curtain wall with a gate to run through and towers at its ends. "
                "Walk up the ramp onto the rampart (8 up) and drop off the back, or land on it "
                "from the volcano's launch pad.", -30, 11, -24),
        _marker(3, "Volcano", "Three rock tiers a jump apart (3, 6, 9). The crater is a launch "
                "pad: it throws you right across to the castle rampart.", -24, 11, 18),
        _marker(4, "Pirate ship", "The ship sits in the pond: walk the pier up to its deck (4.5) "
                "and stern (7), then jump off to the north bank or drop onto the footbridge.",
                0, 9, -6),
        _marker(5, "Hedge Maze", "Hedges 6 high (too high to jump, fine to wall-run) with loops "
                "through it and no dead ends. Hole 5's cup is in the middle.", 0, 9, -28.5),
        _marker(6, "The Hill", "A green on a 4-high plateau (jump up or take the ramp) with a "
                "giant golf ball on its tee to loop round.", 33, 16, 20),
        _marker(7, "Leaderboard run", "The banks are 18 apart here, too far to jump: wall-run "
                "along the giant leaderboard standing in the water. Fall in the pond and you "
                "respawn at a spawn point.", BOARD_X, 13, 0),
        _marker(8, "Clubhouse", "Doors on three sides and a counter to hop: a shortcut through. "
                "The ladder at the back goes up to the roof, 8.6 up.", -3, 12, 26),
        _marker(9, "Footbridge", "The easy way over the pond's east end.", 12, 4, -3),
    ],
    "views": {  # [camera x, y, z, target x, y, z]
        "Overview": [52, 62, 78, 0, 0, -2], "Top": [0, 128, 0.01, 0, 0, 0],
        "Windmill": [44, 16, -4, 29, 6, -24], "Castle": [-14, 22, -6, -30, 5, -27],
        "Volcano": [-8, 22, 36, -30, 5, 18], "Pirate Cove": [24, 20, 18, -2, 3, -5],
        "Leaderboard run": [-2, 12, 16, -16, 4, -3], "Hedge Maze": [16, 30, -6, 0, 2, -26],
        "The Hill": [14, 22, 40, 33, 5, 21], "Clubhouse": [-22, 18, 12, 0, 4, 26],
    },
    "figure": [-4, 0, 14],
    "roof_names": [],
    "roof_extra": [],
    "cutaways": [{"label": "Clubhouse roof", "box": [-10.6, 10.6, CLUB_H, 30, CLUB[2] - 0.6,
                                                     CLUB[3]]}],
    "sky": "#8FD3F7",
    "plan": {  # extra marks for the 2D plan
        "heights": [["8", -30, -28], ["3", -30, 25.8], ["6", -30, 23.2], ["9", -32, 15],
                    ["4.5", -6.5, -4], ["7", 6.5, -8], ["8.6", 6, 28], ["4", 30, 27],
                    ["1", 12, 2], ["1", 1, 1]],
        "routes": [
            {"k": "wallrun", "p": [[BOARD_X + 1.4, 8], [BOARD_X + 1.4, -14]]},
            {"k": "wallrun", "p": [[BOARD_X - 1.4, -14], [BOARD_X - 1.4, 8]]},
            {"k": "launch", "p": [[VOLCANO[0], VOLCANO[1]], [-30, -28]]},
            {"k": "slide", "p": [[29, -17], [29, -33]]},
            {"k": "jump", "p": [[-4, -7.5], [-4, -13.5]]},
            {"k": "jump", "p": [[8, -6], [12, -4]]},
            {"k": "ladder", "p": [[6.5, 33.5], [6.5, 31]]},
        ],
    },
}
DEMO = demo_players()


# ---- checks --------------------------------------------------------------------------------------

def jump_reach(drop, speed=SPRINT):
    """How far a running jump carries you before your feet fall `drop` below takeoff (negative:
    the landing is higher). No margin."""
    up = math.sqrt(2 * GRAVITY * JUMP)
    disc = up * up + 2 * GRAVITY * drop
    if disc < 0:
        return 0.0
    return speed * (up + math.sqrt(disc)) / GRAVITY


def launch_landing():
    """Where the crater pad drops you: the (x, z) where your feet come down through the rampart's
    height, and your height as you pass over its front edge."""
    vx, vy, vz = LAUNCH
    x, z = VOLCANO
    y = TIERS[-1][1] + 0.3
    t, dt, over_edge = 0.0, 1 / 240, None
    while t < 4:
        if t >= LAUNCH_DRIVE:
            vy -= GRAVITY * dt
        x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
        t += dt
        if over_edge is None and z <= CASTLE[3]:
            over_edge = y
        if vy < 0 and y <= CASTLE_H:
            return x, z, over_edge
    return None


def check(m):
    problems = []
    gap = POND[3] - POND[2]
    if gap <= jump_reach(0) + 0.5:
        problems.append(f"a sprinting jump ({jump_reach(0):.1f}) clears the {gap} pond")
    if gap > WALL_RUN or BOARD[1] - BOARD[0] < gap - 6 or BOARD[2] > 2:
        problems.append("the leaderboard doesn't carry a wall run across the pond")
    for (radius, top), below in zip(TIERS, (0,) + tuple(t for _, t in TIERS)):
        if top - below > mapcheck.JUMP_UP:
            problems.append(f"the volcano tier at {top} is out of jumping reach")
    if DECK - PIER[2] > mapcheck.JUMP_UP or STERN[2] - DECK > mapcheck.JUMP_UP:
        problems.append("the ship's deck isn't a jump up from the pier")
    if HILL[4] > mapcheck.JUMP_UP:
        problems.append("the hill is too high to jump onto")
    if MAZE_H <= mapcheck.JUMP_UP:
        problems.append("the maze hedges can be jumped onto")
    if BLADE_HUB[1] - BLADE_LEN < 5:
        problems.append("the windmill's blades come down to head height")
    landing = launch_landing()
    if landing is None:
        problems.append("the launch pad doesn't come back down")
    else:
        x, z, edge = landing
        x0, x1, z0, z1 = CASTLE
        if not (x0 + 1 < x < x1 - 1 and z0 + 0.5 < z < z1 - 0.5):
            problems.append(f"the launch pad lands at ({x:.1f}, {z:.1f}), not on the rampart")
        if edge is None or edge < CASTLE_H + 1:
            problems.append("the launch pad's arc clips the rampart's front edge")
    if len(m.spawns) < ATTRIBUTES["MaxPlayers"]:
        problems.append("not enough spawns")
    # Wall runs along the leaderboard, both sides, both ways (bank to bank).
    runs = [((BOARD_X + side * 1.4, 0, POND[3] + 1), (BOARD_X + side * 1.4, 0, POND[2] - 1), True)
            for side in (-1, 1)]
    return problems + mapcheck.check_map(m, ATTRIBUTES, routes=runs)


if __name__ == "__main__":
    layout = build()
    x, z, edge = launch_landing() or (0, 0, 0)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns; "
          f"the launch pad lands at ({x:.1f}, {z:.1f}), {edge:.1f} high over the rampart's edge")
    issues = check(layout)
    for line in issues:
        print("PROBLEM:", line)
    if "--write" in sys.argv:
        os.chdir(REPO)
        layout.write(OUT, ATTRIBUTES)
        print(f"wrote {OUT}/")
    raise SystemExit(1 if issues else 0)
