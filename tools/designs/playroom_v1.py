#!/usr/bin/env python3
"""The Playroom, design v1 (design stage: not in the game yet). 2-6 players: a kid's bedroom at
giant scale, 60 x 60, walls and ceiling painted like the sky. Shown on the "Playroom" design
canvas (a 2D blueprint for now). Built with tools/maplib.py and checked with tools/mapcheck.py
like the real map generators. Run from the repo root:
    python3 tools/designs/playroom_v1.py                                     (checks only)
    python3 tools/designs/canvas_export.py playroom_v1 build/playroom.json   (for the canvas)

Built to the simple-arena template: one bounded room, eight big toys, each with a job:
  round    something to circle and juke round (the ABC blocks, the toy box, the train tunnel)
  through  a tunnel or arch that breaks line of sight (the castle gate, under the desk, the train
           tunnel: slide through it)
  over     a ramp or stairs up one side and off the other (the book stairs onto the bed, the
           castle ramp onto its gatehouse, the plank onto the toy box, the chair onto the desk)
Every high point has a walking way up; the moves are shortcuts, never the only way:
  skill    a wall run along the wardrobe from the bed to the desk (18 apart: too far to jump),
           and the jack-in-the-box, a launch pad onto the castle's gatehouse.
Axes: X east, Z south, Y up. The carpet is at 0.
"""
import math
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_x  # noqa: E402

OUT = "src/maps/Playroom"
ATTRIBUTES = {"DisplayName": "Playroom", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "OutOfBounds": "Ceiling,Headboard,Wardrobe,Tower,Tunnel,ChairBack"}

GRAVITY = 196.2
JUMP = 7.2
SPRINT = 30
WALL_RUN = 30 * 1.6
CROUCH_ROOM = 4.2
LAUNCH_DRIVE = 0.08

R = 30  # the room: x and z from -30 to 30
CEIL = 24
# The bed (north-west) and the books stacked as stairs up to it.
BED = (-28, -12, -28, -12, 6)  # x0, x1, z0, z1, top
BOOKS = (-22, -17)  # x of the book stairs, which run south from the bed one stud at a time
# The wardrobe on the west wall and the desk (south-west) with its chair.
WARDROBE = (-30, -27, -10, 4, 16)
DESK = (-27, -17, 6, 14, 6)  # x0, x1, z0, z1, top (its slab is 1 thick, on four legs)
CHAIR = (-16, -12, 8, 12, 3)
# The block castle (north-east): a gatehouse with an arch, towers, a ramp onto it.
GATEHOUSE = (14, 26, -26, -18, 8)
ARCH = (18, 22, 6)  # x0, x1, top
TOWERS = ((10, 14), (26, 30))
TOWER_H = 12
CASTLE_RAMP = (14, 18, -6)  # x0, x1, z of its foot (it rises north to the gatehouse)
# The toy box (south-east) and the plank up to it.
TOY_BOX = (14, 26, 12, 24, 6)
PLANK = (18, 22, 4)  # x0, x1, z of its foot (it rises south onto the box)
# The jack-in-the-box: a launch pad onto the castle's gatehouse.
JACK = (22, 26, 0, 4, 3)
LAUNCH = (-7, 46, -44)
# The train tunnel (south): slide through it along X.
TUNNEL = (-8, 4, 20, 28, 7)
TUNNEL_HOLE = (22, 26)  # z of the way through
# The spinner in the middle: a low round stage (two shallow steps) with a long bar sweeping round
# it at hip height: jump it as it comes (it shoves you if it hits you).
STAGE = ((12, 0.5), (10, 1.0))  # radius, top of each step
SPIN_BAR = (20, 1.2, 1.6, 2.8)  # length, width, bottom, top
SPIN_RATE = 72  # degrees a second: a turn every 5 seconds
SPIN_SHOVE = 60
# ABC blocks round the room: cubes a jump high.
BLOCKS = ((10, -14), (-2, -24), (-16, 22))
BLOCK = 4

COLORS = {
    "carpet": (88, 176, 92), "rug": (240, 214, 120), "sky": (150, 200, 245),
    "ceiling": (170, 214, 250), "bed": (60, 110, 200), "sheet": (240, 240, 250),
    "wood": (196, 150, 96), "dark_wood": (130, 90, 56), "red": (220, 60, 60),
    "yellow": (250, 210, 40), "cyan": (40, 200, 220), "grey": (150, 150, 156),
    "green": (90, 190, 90), "orange": (255, 140, 40), "pink": (255, 110, 170),
    "purple": (150, 100, 220), "white": (255, 255, 255), "ink": (30, 30, 36),
    "book1": (220, 70, 60), "book2": (60, 140, 220), "book3": (250, 200, 50),
    "book4": (90, 180, 100), "book5": (170, 100, 210),
}
MATERIALS = {"carpet": "Fabric", "rug": "Fabric", "sky": "SmoothPlastic", "bed": "Fabric",
             "sheet": "Fabric", "wood": "WoodPlanks", "dark_wood": "Wood"}
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


def room(m):
    g = "Room"
    m.block(g, "Floor", -R - 1, R + 1, -1, 0, -R - 1, R + 1, "carpet")
    for a, b, c, d in ((-R - 1, R + 1, -R - 1, -R), (-R - 1, R + 1, R, R + 1),
                       (-R - 1, -R, -R, R), (R, R + 1, -R, R)):
        m.block(g, "Wall", a, b, 0, CEIL, c, d, "sky")
    m.block(g, "Ceiling", -R - 1, R + 1, CEIL, CEIL + 1, -R - 1, R + 1, "ceiling")


def bed(m):
    g = "Bed"
    x0, x1, z0, z1, top = BED
    m.block(g, "Bed", x0, x1, 0, top, z0, z1, "bed")
    m.block(g, "Headboard", x0, x1, 0, top + 4, -R, z0, "dark_wood")
    m.block("Details", "Pillow", x0 + 2, x1 - 2, top + 0.05, top + 1.2, z0 + 1, z0 + 4, "sheet",
            **DETAIL)
    b0, b1 = BOOKS
    for k in range(5):  # one book a step: a stud high, two deep
        za = z1 + 2 * k
        m.block(g, "Book", b0 - 0.4 * (k % 2), b1 + 0.4 * (k % 2), 0, top - 1 - k, za, za + 2,
                ("book1", "book2", "book3", "book4", "book5")[k])


def wardrobe_desk(m):
    g = "Furniture"
    x0, x1, z0, z1, h = WARDROBE
    m.block(g, "Wardrobe", x0, x1, 0, h, z0, z1, "wood")
    x0, x1, z0, z1, top = DESK
    m.block(g, "Desk", x0, x1, top - 1, top, z0, z1, "wood")
    for x in (x0, x1 - 1):
        for z in (z0, z1 - 1):
            m.block(g, "DeskLeg", x, x + 1, 0, top - 1, z, z + 1, "dark_wood")
    x0, x1, z0, z1, seat = CHAIR
    m.block(g, "Chair", x0, x1, 0, seat, z0, z1, "red")
    m.block(g, "ChairBack", x1, x1 + 1, 0, seat + 5, z0, z1, "red")


def castle(m):
    g = "Castle"
    x0, x1, z0, z1, h = GATEHOUSE
    a0, a1, top = ARCH
    m.wall(g, "X", (z0, z1), (x0, x1), 0, h, "yellow", openings=[(a0, a1, top)],
           name="Gatehouse")
    for t0, t1 in TOWERS:
        m.block(g, "Tower", t0, t1, 0, TOWER_H, z0, z1, "yellow")
    r0, r1, foot = CASTLE_RAMP
    ramp_z(m, g, "CastleRamp", r0, r1, foot, 0, z1, h, "yellow")


def toys(m):
    g = "Toys"
    x0, x1, z0, z1, top = TOY_BOX
    m.block(g, "ToyBox", x0, x1, 0, top, z0, z1, "purple")
    p0, p1, foot = PLANK
    ramp_z(m, g, "Plank", p0, p1, foot, 0, z0, top, "wood")
    x0, x1, z0, z1, top = JACK
    m.block(g, "JackBox", x0, x1, 0, top, z0, z1, "pink")
    m.block(g, "JackPad", x0 + 0.5, x1 - 0.5, top, top + 0.2, z0 + 0.5, z1 - 0.5, "yellow",
            attributes={"LaunchVelocity": vec(*LAUNCH)})
    x0, x1, z0, z1, h = TUNNEL
    t0, t1 = TUNNEL_HOLE
    m.block(g, "Tunnel", x0, x1, 0, h, z0, t0, "grey")
    m.block(g, "Tunnel", x0, x1, 0, h, t1, z1, "grey")
    m.block(g, "Tunnel", x0, x1, CROUCH_ROOM, h, t0, t1, "grey")
    m.block(g, "StandBlocker", x0, x1, 0, CROUCH_ROOM, t0, t1, (255, 255, 255),
            Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
    for k, (x, z) in enumerate(BLOCKS):
        m.block(g, "Block", x - BLOCK / 2, x + BLOCK / 2, 0, BLOCK, z - BLOCK / 2, z + BLOCK / 2,
                ("red", "cyan", "orange")[k])


def spinner(m):
    g = "Spinner"
    bottom = 0
    for k, (radius, top) in enumerate(STAGE):
        m.cylinder(g, "Stage", top - bottom, radius * 2, (0, (top + bottom) / 2, 0),
                   ("rug", "yellow")[k])
        bottom = top
    deck = STAGE[-1][1]
    length, width, y0, y1 = SPIN_BAR
    m.cylinder(g, "SpinPost", y1 + 0.6 - deck, 2.4, (0, (deck + y1 + 0.6) / 2, 0), "red")
    m.block(g, "SpinBar", -length / 2, length / 2, y0, y1, -width / 2, width / 2, "red",
            attributes={"Spin": SPIN_RATE, "SpinCenter": vec(0, 0, 0), "Knockback": SPIN_SHOVE})
    for x in (-length / 2 + 0.6, length / 2 - 0.6):  # bumpers on its ends (decoration)
        m.block("Details", "SpinBumper", x - 0.6, x + 0.6, y1 + 0.05, y1 + 0.4, -width / 2,
                width / 2, "yellow", **DETAIL,
                attributes={"Spin": SPIN_RATE, "SpinCenter": vec(0, 0, 0)})


SPAWNS = ((-6, -16), (-8, 12), (12, 8), (-14, -2), (14, -4), (0, 15), (4, -24), (27, -8))


def build():
    m = Map(COLORS, MATERIALS)
    room(m)
    bed(m)
    wardrobe_desk(m)
    castle(m)
    toys(m)
    spinner(m)
    for x, z in SPAWNS:
        m.spawn(x, z)
    return m


# ---- the design canvas -------------------------------------------------------------------------

def _label(text, x, y, z, kind="zone"):
    return {"t": text, "x": x, "y": y, "z": z, "f": 1, "k": kind}


def _marker(n, title, role, text, x, y, z):
    return {"n": n, "t": title, "role": role, "d": text, "x": x, "y": y, "z": z, "f": 1}


CANVAS = {
    "label": "Design v1",
    "labels": [],
    "markers": [
        _marker(1, "Bed", "over", "A big soft platform, 6 up. Walk up the stack of books (a stud "
                "a step) and jump off any side.", -20, 8, -20),
        _marker(2, "Wardrobe run", "skill", "From the bed to the desk is 18: too far to jump. "
                "Wall-run along the wardrobe and land on the desk.", -22.5, 10, 1.5),
        _marker(3, "Desk", "through", "Run under it (5 of headroom), or climb the chair (3) "
                "onto the desk top (6).", -22, 8, 10),
        _marker(4, "Block castle", "through", "Run through the gatehouse arch, or walk up the "
                "ramp onto its top (8). The towers are out of bounds.", 20, 10, -14),
        _marker(5, "Toy box", "over", "Circle it, or walk the plank up onto its lid (6).", 20, 8,
                18),
        _marker(6, "Jack-in-the-box", "skill", "A launch pad: it throws you onto the castle's "
                "gatehouse.", 24, 5, 2),
        _marker(7, "Train tunnel", "through", "Slide or crouch through it (4.2 high), or run "
                "round it.", -2, 9, 24),
        _marker(8, "ABC blocks", "round", "Three cubes a jump high round the room to juke round "
                "and hop over.", 10, 6, -14),
        _marker(9, "The spinner", "hazard", "A low round stage in the middle (two shallow steps) "
                "with a long bar sweeping round it every %d seconds at hip height. Jump it as it "
                "comes: it shoves you if it hits you. Cross the middle, or go round."
                % round(360 / SPIN_RATE), 0, 6, 0),
    ],
    "views": {"Overview": [44, 56, 60, 0, 0, 0], "Top": [0, 100, 0.01, 0, 0, 0]},
    "figure": [0, 0, 0],
    "roof_names": ["Ceiling"],
    "roof_extra": ["Ceiling"],
    "plan": {
        "blueprint": True,
        "heights": [["6", -16, -24], ["16", -28.5, 8.5], ["6", -20, 13], ["3", -14, 10.5],
                    ["8", 23, -22], ["12", 12, -28.5], ["6", 24, 22], ["3", 24, 2],
                    ["7", 0, 26.5], ["4", 10, -17], ["5..1", -19.5, -6], ["1", 0, 6.5]],
        "routes": [
            {"k": "wallrun", "p": [[-25.6, -13], [-25.6, 7]]},
            {"k": "launch", "p": [[24, 2], [20, -22]]},
            {"k": "slide", "p": [[-10, 24], [6, 24]]},
            {"k": "spin", "p": [[0, 0], [10.6, 0]]},
            {"k": "stairs", "p": [[-19.5, -1], [-19.5, -13]]},
            {"k": "stairs", "p": [[16, -5], [16, -17]]},
            {"k": "stairs", "p": [[20, 5], [20, 11]]},
        ],
        "dims": [[-30, 32, 30, 32, "60"], [32, -30, 32, 30, "60"],
                 [-23.6, -12, -23.6, 6, "18 (wall run)"]],
    },
}


# ---- checks ---------------------------------------------------------------------------------------

def jump_reach(drop, speed=SPRINT):
    up = math.sqrt(2 * GRAVITY * JUMP)
    disc = up * up + 2 * GRAVITY * drop
    if disc < 0:
        return 0.0
    return speed * (up + math.sqrt(disc)) / GRAVITY


def launch_landing():
    """Where the jack-in-the-box drops you: (x, z) where your feet come down through the
    gatehouse's height, and your height as you pass over its front edge."""
    vx, vy, vz = LAUNCH
    x = (JACK[0] + JACK[1]) / 2
    z = (JACK[2] + JACK[3]) / 2
    y = JACK[4] + 0.2
    t, dt, over_edge = 0.0, 1 / 240, None
    while t < 4:
        if t >= LAUNCH_DRIVE:
            vy -= GRAVITY * dt
        x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
        t += dt
        if over_edge is None and z <= GATEHOUSE[3]:
            over_edge = y
        if vy < 0 and y <= GATEHOUSE[4]:
            return x, z, over_edge
    return None


def check(m):
    problems = []
    gap = DESK[2] - BED[3]
    if gap <= jump_reach(0) + 0.5:
        problems.append(f"a sprinting jump clears the {gap} from the bed to the desk")
    if gap > WALL_RUN or WARDROBE[3] - WARDROBE[2] < gap - 6:
        problems.append("the wardrobe doesn't carry a wall run from the bed to the desk")
    if DESK[4] - CHAIR[4] > mapcheck.JUMP_UP or DESK[4] - 1 < mapcheck.STAND:
        problems.append("the desk isn't a jump up from the chair, or too low to run under")
    if SPIN_BAR[3] - STAGE[-1][1] > JUMP - 3 or SPIN_BAR[1] / 2 > 1 or \
            SPIN_BAR[0] / 2 > STAGE[-1][0]:
        problems.append("the spinner's bar is too high to jump, too wide, or overhangs its stage")
    for x, z in SPAWNS:
        if math.hypot(x, z) < STAGE[0][0] + 1.5:
            problems.append(f"the spawn at ({x}, {z}) is on the spinner")
    if BLOCK > mapcheck.JUMP_UP:
        problems.append("the ABC blocks are too high to hop onto")
    landing = launch_landing()
    if landing is None:
        problems.append("the jack-in-the-box doesn't come back down")
    else:
        x, z, edge = landing
        x0, x1, z0, z1, h = GATEHOUSE
        if not (x0 + 1 < x < x1 - 1 and z0 + 1 < z < z1 - 1):
            problems.append(f"the jack-in-the-box lands at ({x:.1f}, {z:.1f}), not on the castle")
        if edge is None or edge < h + 1:
            problems.append("the jack-in-the-box's arc clips the castle's front edge")
    runs = [((-25.6, BED[4], BED[3] - 1), (-25.6, DESK[4], DESK[2] + 1), True)]
    return problems + mapcheck.check_map(m, ATTRIBUTES, routes=runs)


if __name__ == "__main__":
    layout = build()
    x, z, edge = launch_landing() or (0, 0, 0)
    print(f"{layout.count()} parts, {len(layout.spawns)} spawns; the jack-in-the-box lands at "
          f"({x:.1f}, {z:.1f}), {edge:.1f} high over the castle's edge")
    issues = check(layout)
    for line in issues:
        print("PROBLEM:", line)
    raise SystemExit(1 if issues else 0)
