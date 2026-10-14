#!/usr/bin/env python3
"""The Playroom, design v1 (design stage: not in the game yet). 2-6 players: a kid's bedroom at
giant scale, 96 x 96, walls and ceiling painted like the sky. Shown on the "Playroom" design
canvas (a 2D blueprint and the 3D model). Built with tools/maplib.py and checked with
tools/mapcheck.py like the real map generators. Run from the repo root:
    python3 tools/designs/playroom_v1.py                                     (checks only)
    python3 tools/designs/canvas_export.py playroom_v1 build/playroom.json   (for the canvas)

Built to the simple-arena template: one bounded room of big toys round a spinner, each toy with
a job:
  round    something to circle and juke round (the ABC blocks, the toy box, the train tunnel)
  through  a tunnel or arch that breaks line of sight (the castle gate, under the desk, the train
           tunnel: slide through it)
  over     a ramp or stairs up one side and off the other (the book stairs onto the bed, the
           castle's ramps up to its gatehouse and its keep)
  skill    the high spots only a move reaches:
           the desk top: only by a wall run along the wardrobe from the bed (24 apart)
           the toy box top: only by the castle slide. Run down the slide from the keep and jump
             right at the end of its lip, a speed strip that flings you 21 across onto the box.
             Jump early or late, or slide-jump without it, and you fall short.
           the jack-in-the-box: a launch pad onto the castle's gatehouse.
  hazard   the spinner: a low round stage in the middle with a bar sweeping round it to jump.
Axes: X east, Z south, Y up. The carpet is at 0.
"""
import math
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_x, rot_z  # noqa: E402

OUT = "src/maps/Playroom"
ATTRIBUTES = {"DisplayName": "Playroom", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "OutOfBounds": "Ceiling,Headboard,Wardrobe,Tower,Tunnel"}

GRAVITY = 196.2
JUMP = 7.2
SPRINT = 30
SLIDE_JUMP = 37  # a slide into a jump: the fastest anyone leaves a floor without a gadget
WALL_RUN = 30 * 1.6
CROUCH_ROOM = 4.2
LAUNCH_DRIVE = 0.08

R = 48  # the room: x and z from -48 to 48
CEIL = 40
CUT = 4  # the walls are built in two parts, split here (the canvas cuts them away above it)
# Clouds painted on the walls and the ceiling (decoration): (wall, along, height, size).
CLOUDS = (("N", -10, 26, 1.9), ("N", 26, 31, 1.4), ("S", -29, 28, 1.6), ("S", 19, 22, 2.1),
          ("W", 29, 30, 1.8), ("W", -32, 23, 1.3), ("E", -6, 26, 1.9), ("E", 35, 32, 1.4))
CEILING_CLOUDS = ((-19, -13, 2.2), (22, 16, 1.9), (3, 32, 1.6), (-29, 29, 1.4))
# The bed (north-west), and the books stacked as stairs up to it, running east a stud a step.
BED = (-45, -20, -45, -20, 9)  # x0, x1, z0, z1, top
BOOKS = (-38, -30, 3)  # z0, z1 of the stairs, each book's depth
# The wardrobe on the west wall: wall-run along it from the bed to the desk.
WARDROBE = (-48, -43, -18, 2, 26)
DESK = (-43, -27, 4, 18, 9)  # x0, x1, z0, z1, top (its slab is 1 thick, on four legs)
CHAIR = (-38, -32, 8, 13, 3)  # pushed in under the desk
# The block castle (north-east), three levels: the gate on the ground, the gatehouse top (12),
# the keep on top of it (20); a ramp up to each, the slide down off the keep.
GATEHOUSE = (20, 40, -46, -32, 12)
ARCH = (27, 33, 8)  # x0, x1, top
TOWERS = ((14, 20), (40, 44))  # x of the towers at each end (z -46 .. -38)
TOWER_H = 26
RAMP1 = (21, 26, -14)  # x0, x1, z of its foot (it rises north to the gatehouse)
KEEP = (32, 40, -46, -38, 20)
RAMP2 = (22, -45.5, -41.5)  # x of its foot, z0, z1 (it rises east to the keep)
# The slide: down off the keep's front, over the gatehouse and out to a lip (a speed strip).
SLIDE = (34, 39, -8, 8)  # x0, x1, z where it meets the lip, the lip's height
LIP = 3  # the lip runs on flat this far past the slide's foot
LIP_BOOST = 55  # SpeedBoost: jump off the lip and you leave at least this fast
# The toy box: its top only reachable by jumping off the slide's lip.
TOY_BOX = (26, 44, 16, 34, 12)
# The jack-in-the-box: a launch pad onto the gatehouse (its velocity is worked out below).
JACK = (6, 10, -26, -22, 3)
JACK_TARGET = (26, -37)
# The train tunnel (south): slide through it along X.
TUNNEL = (-14, 6, 32, 44, 11)
TUNNEL_HOLE = (36, 40)  # z of the way through
# The spinner in the middle: a low round stage (two shallow steps) with a long bar sweeping round
# it at hip height: jump it as it comes (it shoves you if it hits you).
STAGE = ((18, 0.5), (15, 1.0))  # radius, top of each step
SPIN_BAR = (30, 1.2, 1.6, 2.8)  # length, width, bottom, top
SPIN_RATE = 72  # degrees a second: a turn every 5 seconds
SPIN_SHOVE = 60
# ABC blocks round the room: cubes a jump high.
BLOCKS = ((-6, -26), (10, 26), (-30, 40))
BLOCK = 5

COLORS = {
    "carpet": (88, 176, 92), "rug": (240, 214, 120), "sky": (150, 200, 245),
    "ceiling": (170, 214, 250), "bed": (60, 110, 200), "sheet": (240, 240, 250),
    "wood": (196, 150, 96), "dark_wood": (130, 90, 56), "red": (220, 60, 60),
    "yellow": (250, 210, 40), "cyan": (40, 200, 220), "grey": (150, 150, 156),
    "green": (90, 190, 90), "orange": (255, 140, 40), "pink": (255, 110, 170),
    "purple": (150, 100, 220), "white": (255, 255, 255), "ink": (30, 30, 36),
    "slide": (255, 90, 160), "lip": (255, 214, 10),
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


def ramp_x(m, g, name, z0, z1, xa, ya, xb, yb, color, thick=0.6, **props):
    """A slab whose top runs straight from (xa, ya) to (xb, yb) along X."""
    dx, dy = xb - xa, yb - ya
    ang = math.degrees(math.atan(dy / dx))
    a = math.radians(ang)
    normal = (-math.sin(a), math.cos(a), 0)
    mid = ((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2)
    pos = tuple(mid[i] - 0.5 * thick * normal[i] for i in range(3))
    return m.part(g, name, (math.hypot(dx, dy), thick, z1 - z0), pos, color, rot_z(ang), **props)


def slide_height(z):
    """The slide's surface height at z, from the keep's front down to the lip."""
    k0 = KEEP[3]
    return KEEP[4] + (SLIDE[3] - KEEP[4]) * (z - k0) / (SLIDE[2] - k0)


# ---- the room ---------------------------------------------------------------------------------------

def room(m):
    g = "Room"
    m.block(g, "Floor", -R - 1, R + 1, -1, 0, -R - 1, R + 1, "carpet")
    for a, b, c, d in ((-R - 1, R + 1, -R - 1, -R), (-R - 1, R + 1, R, R + 1),
                       (-R - 1, -R, -R, R), (R, R + 1, -R, R)):
        m.block(g, "Wall", a, b, 0, CUT, c, d, "sky")
        m.block(g, "WallUpper", a, b, CUT, CEIL, c, d, "sky")
    m.block(g, "Ceiling", -R - 1, R + 1, CEIL, CEIL + 1, -R - 1, R + 1, "ceiling")
    for wall, along, y, size in CLOUDS:
        cloud(m, wall, along, y, size)
    for x, z, size in CEILING_CLOUDS:
        for k, (dx, dz, w, d) in enumerate(CLOUD_PUFFS):
            lo = CEIL - 0.06 * (k + 1)
            m.block("Details", "Cloud", x + (dx - w / 2) * size, x + (dx + w / 2) * size,
                    lo - 0.04, lo, z + (dz - d / 2) * size, z + (dz + d / 2) * size, "white",
                    **DETAIL)


# A cloud is three puffs, each a little further off its surface than the last (puffs in one plane
# would flicker where they overlap): (offset along, offset up, width, height).
CLOUD_PUFFS = ((0, 0, 9, 3), (-1.8, 1.4, 4, 3), (1.6, 1.8, 4.6, 3.4))


def cloud(m, wall, along, y, size):
    for k, (da, dy, w, h) in enumerate(CLOUD_PUFFS):
        out = 0.06 * (k + 1)
        a0, a1 = along + (da - w / 2) * size, along + (da + w / 2) * size
        y0, y1 = y + (dy - h / 2) * size, y + (dy + h / 2) * size
        if wall == "N":
            m.block("Details", "Cloud", a0, a1, y0, y1, -R + out, -R + out + 0.04, "white",
                    **DETAIL)
        elif wall == "S":
            m.block("Details", "Cloud", a0, a1, y0, y1, R - out - 0.04, R - out, "white", **DETAIL)
        elif wall == "W":
            m.block("Details", "Cloud", -R + out, -R + out + 0.04, y0, y1, a0, a1, "white",
                    **DETAIL)
        else:
            m.block("Details", "Cloud", R - out - 0.04, R - out, y0, y1, a0, a1, "white", **DETAIL)


# ---- the bed, the wardrobe, the desk ----------------------------------------------------------------

def books():
    """The book stairs: (x0, x1, top) of each book, from the bed's edge outwards."""
    depth = BOOKS[2]
    out = []
    for k in range(BED[4] - 1):
        x0 = BED[1] + depth * k
        out.append((x0, x0 + depth, BED[4] - 1 - k))
    return out


def bed(m):
    g = "Bed"
    x0, x1, z0, z1, top = BED
    m.block(g, "Bed", x0, x1, 0, top, z0, z1, "bed")
    m.block(g, "Headboard", x0, x1, 0, top + 6, -R, z0, "dark_wood")
    m.block("Details", "Pillow", x0 + 3, x1 - 3, top + 0.05, top + 1.6, z0 + 1.5, z0 + 6, "sheet",
            **DETAIL)
    m.block("Details", "Blanket", x0 + 0.5, x1 - 0.5, top + 0.05, top + 0.3, z0 + 11, z1 - 0.5,
            "cyan", **DETAIL)
    bz0, bz1, _ = BOOKS
    for k, (a, b, h) in enumerate(books()):
        m.block(g, "Book", a, b, 0, h, bz0 - 0.6 * (k % 2), bz1 + 0.6 * (k % 2),
                ("book1", "book2", "book3", "book4", "book5")[k % 5])


def wardrobe_desk(m):
    g = "Furniture"
    x0, x1, z0, z1, h = WARDROBE
    m.block(g, "Wardrobe", x0, x1, 0, h, z0, z1, "wood")
    mid = (z0 + z1) / 2
    for a, b in ((z0 + 1, mid - 0.2), (mid + 0.2, z1 - 1)):
        m.block("Details", "WardrobeDoor", x1 + 0.05, x1 + 0.1, 1, h - 1, a, b, "dark_wood",
                **DETAIL)
    x0, x1, z0, z1, top = DESK
    m.block(g, "Desk", x0, x1, top - 1, top, z0, z1, "wood")
    for x in (x0, x1 - 1.2):
        for z in (z0, z1 - 1.2):
            m.block(g, "DeskLeg", x, x + 1.2, 0, top - 1, z, z + 1.2, "dark_wood")
    m.block("Details", "DeskLamp", x1 - 4, x1 - 2, top + 0.05, top + 5, z0 + 2, z0 + 4, "yellow",
            **DETAIL)
    x0, x1, z0, z1, seat = CHAIR
    m.block(g, "Chair", x0, x1, 0, seat, z0, z1, "red")
    m.block(g, "ChairBack", x0, x1, seat, seat + 4, z1, z1 + 1, "red")


# ---- the block castle and its slide ---------------------------------------------------------------

def castle(m):
    g = "Castle"
    d = "Details"
    x0, x1, z0, z1, h = GATEHOUSE
    a0, a1, top = ARCH
    m.wall(g, "X", (z0, z1), (x0, x1), 0, h, "yellow", openings=[(a0, a1, top)],
           name="Gatehouse")
    for t0, t1 in TOWERS:
        m.block(g, "Tower", t0, t1, 0, TOWER_H, z0, KEEP[3], "yellow")
    kx0, kx1, kz0, kz1, ktop = KEEP
    m.block(g, "Keep", kx0, kx1, h, ktop, kz0, kz1, "orange")
    r0, r1, foot = RAMP1
    ramp_z(m, g, "CastleRamp", r0, r1, foot, 0, z1, h, "yellow")
    foot2, rz0, rz1 = RAMP2
    ramp_x(m, g, "KeepRamp", rz0, rz1, foot2, h, kx0, ktop, "orange")
    for k in range(4):  # merlons along the gatehouse's front, over the arch
        mx = a0 + 0.5 + 1.6 * k
        m.block(d, "Merlon", mx - 0.5, mx + 0.5, h, h + 1.2, z1 - 1, z1, "yellow", **DETAIL)
    for k in range(4):  # and round the keep's back
        mx = kx0 + 1 + 2 * k
        m.block(d, "Merlon", mx - 0.5, mx + 0.5, ktop, ktop + 1.2, kz0, kz0 + 1, "orange",
                **DETAIL)
    # The slide: from the keep's front down over the gatehouse to the lip, on posts.
    sx0, sx1, zl, lip_y = SLIDE
    ramp_z(m, g, "Slide", sx0, sx1, kz1, ktop, zl, lip_y, "slide")
    m.block(g, "SlideLip", sx0, sx1, lip_y - 0.6, lip_y, zl, zl + LIP, "lip",
            attributes={"SpeedBoost": LIP_BOOST})
    for x in (sx0 - 0.15, sx1 + 0.15):  # its side rails (decoration), following its slope
        ramp_z(m, d, "SlideRail", x - 0.15, x + 0.15, kz1, slide_height(kz1) + 1.2, zl,
               slide_height(zl) + 1.2, "white", thick=0.3, **DETAIL)
    cx = (sx0 + sx1) / 2
    for z in (-26, -16):
        top_ = slide_height(z) - 0.7
        m.cylinder(g, "SlidePost", top_, 1.2, (cx, top_ / 2, z), "slide")
    m.cylinder(g, "SlidePost", lip_y - 0.6, 1.2, (cx, (lip_y - 0.6) / 2, zl + LIP / 2), "slide")


# ---- the toys -------------------------------------------------------------------------------------

def toys(m):
    g = "Toys"
    x0, x1, z0, z1, top = TOY_BOX
    m.block(g, "ToyBox", x0, x1, 0, top, z0, z1, "purple",
            children=[m.surface_text(f, "TOYS", COLORS["yellow"], pps=8)
                      for f in ("Front", "Back", "Left", "Right")])
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
                ("red", "cyan", "orange")[k],
                children=[m.surface_text(f, "ABC"[k], COLORS["white"], pps=16)
                          for f in ("Front", "Back", "Left", "Right", "Top")])


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


# ---- launches -------------------------------------------------------------------------------------

def fly(start, velocity, target_y, edge_z=None):
    """A launch from `start` with `velocity` (the game's drive time, then gravity): where your
    feet come down through target_y, and your height as you cross edge_z."""
    x, y, z = start
    vx, vy, vz = velocity
    t, dt, over_edge = 0.0, 1 / 240, None
    while t < 4:
        if t >= LAUNCH_DRIVE:
            vy -= GRAVITY * dt
        x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
        t += dt
        if edge_z is not None and over_edge is None and (z - edge_z) * vz >= 0:
            over_edge = y
        if vy < 0 and y <= target_y:
            return x, z, over_edge
    return None


def aim(start, target, top, edge_z):
    """The gentlest launch velocity that lands on `target` (x, z) at height `top`, crossing the
    edge at edge_z at least 1.5 above it."""
    dx, dz = target[0] - start[0], target[1] - start[2]
    dist = math.hypot(dx, dz)
    best = None
    for vy in range(30, 80):
        for k in range(40, 400):
            vh = k / 4
            v = (dx / dist * vh, vy, dz / dist * vh)
            hit = fly(start, v, top, edge_z)
            if not hit:
                continue
            x, z, edge = hit
            if math.hypot(x - target[0], z - target[1]) < 0.6 and edge and edge > top + 1.5:
                if best is None or vh * vh + vy * vy < best[0]:
                    best = (vh * vh + vy * vy, tuple(round(c, 1) for c in v))
                break
    return best[1]


JACK_START = ((JACK[0] + JACK[1]) / 2, JACK[4] + 0.2, (JACK[2] + JACK[3]) / 2)
LAUNCH = aim(JACK_START, JACK_TARGET, GATEHOUSE[4], GATEHOUSE[3])


# ---- demo players for the canvas (the game ignores these) -------------------------------------------

def demo_players():
    """Figures acting out a round on the canvas: closed loops of [x, y, z, flag] points. Flags:
    "j" jumps (or drops) into that point, "L" is thrown there (a launch pad, the slide's lip),
    "c" is a slide or crouch, "wr"/"wl" a wall run with the wall on the right/left."""
    ring = [[round(21 * math.cos(math.radians(a)), 2), 0,
             round(21 * math.sin(math.radians(a)), 2), ""] for a in range(0, 360, 30)]
    lane = WARDROBE[1] + 1.4
    bz = (BOOKS[0] + BOOKS[1]) / 2
    bed_run = [[2.5, 0, -29.4, ""]] + [[(a + b) / 2, h, bz, ""] for a, b, h in reversed(books())]
    bed_run += [
        [-24, BED[4], bz, ""], [lane, BED[4], -24, ""], [lane, BED[4], BED[3] - 0.5, ""],
        [lane, BED[4] + 1.4, -13, "wr"], [lane, BED[4] + 2.6, -7, "wr"],
        [lane, BED[4] + 1.4, 0, "wr"], [lane + 1, DESK[4], DESK[2] + 2, ""],
        [-30, DESK[4], 12, ""], [-23, 0, 13, "j"], [-23, 0, -12, ""], [-12, 0, -29.4, ""],
    ]
    sx = (SLIDE[0] + SLIDE[1]) / 2
    slide_run = [  # up both ramps to the keep, down the slide, off the lip onto the toy box
        [23.5, 0, -8, ""], [23.5, 0, RAMP1[2], ""], [23.5, GATEHOUSE[4], GATEHOUSE[3], ""],
        [23, GATEHOUSE[4], -43.5, ""], [KEEP[0], KEEP[4], -43.5, ""], [sx, KEEP[4], -42, ""],
        [sx, KEEP[4], KEEP[3] - 0.5, ""], [sx, slide_height(-30), -30, "c"],
        [sx, SLIDE[3] + 0.1, SLIDE[2], "c"], [sx, SLIDE[3], SLIDE[2] + LIP - 0.3, ""],
        [35.5, TOY_BOX[4], TOY_BOX[2] + 3, "L"], [35.5, TOY_BOX[4], 30, ""],
        [35.5, 0, 39, "j"], [22, 0, 40, ""], [22, 0, 10, ""],
    ]
    launch = [  # onto the jack-in-the-box, thrown onto the gatehouse, down the ramp
        [8, JACK[4] + 0.2, -24, ""], [JACK_TARGET[0], GATEHOUSE[4], JACK_TARGET[1], "L"],
        [23.5, GATEHOUSE[4], -33, ""], [23.5, 0, RAMP1[2], ""], [16, 0, -16, ""],
        [11, 0, -21, ""], [8, JACK[4] + 0.2, -24, "j"],
    ]
    tunnel = [  # through the train tunnel and back round its south side
        [-18, 0, 38, ""], [-14.5, 0, 38, "c"], [6.5, 0, 38, "c"], [10, 0, 38, ""],
        [10, 0, 46, ""], [-18, 0, 46, ""],
    ]
    return [
        {"tag": "", "color": "#3C82F0", "speed": 14, "offset": 0, "points": ring},
        {"tag": "IT", "color": "#E8423F", "speed": 14, "offset": -0.8, "points": ring},
        {"tag": "", "color": "#4CC46A", "speed": 12, "offset": 0, "points": bed_run,
         "cam": "Bed runner"},
        {"tag": "", "color": "#F2C94C", "speed": 12, "offset": 0, "points": slide_run,
         "cam": "Slide jump"},
        {"tag": "", "color": "#A66BFF", "speed": 11, "offset": 0, "points": launch},
        {"tag": "", "color": "#FF8A1F", "speed": 11, "offset": 0, "points": tunnel},
    ]


SPAWNS = ((-22, -10), (14, -14), (-20, 24), (20, 30), (0, 26), (-6, -42), (44, -10), (-38, 40))


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


# ---- the design canvas -------------------------------------------------------------------------------

def _marker(n, title, role, text, x, y, z):
    return {"n": n, "t": title, "role": role, "d": text, "x": x, "y": y, "z": z, "f": 1}


GAP_DESK = DESK[2] - BED[3]
GAP_BOX = TOY_BOX[2] - (SLIDE[2] + LIP)
LIP_RISE = TOY_BOX[4] - SLIDE[3]

CANVAS = {
    "label": "Design v1",
    "labels": [],
    "markers": [
        _marker(1, "Bed", "over", "A big soft platform, 9 up. Walk up the stack of books (a stud "
                "a step) and jump off any side.", -32, 13, -33),
        _marker(2, "Wardrobe run", "skill", "From the bed to the desk is %d: too far to jump. "
                "Wall-run along the wardrobe and land on the desk." % GAP_DESK, -30, 14, -4),
        _marker(3, "Desk", "through", "Run under it (the chair is pushed in). Its top, 9 up, is "
                "only reached by the wardrobe run.", -35, 12, 11),
        _marker(4, "Block castle", "over", "Three levels: run through the gate, walk up the ramp "
                "to the gatehouse (12), then the next ramp to the keep (20). Drop off anywhere.",
                26, 16, -30),
        _marker(5, "The slide", "skill", "Off the keep's front, over the gatehouse, down to a "
                "yellow lip (a speed strip). Jump right at the end of the lip and it flings you "
                "%d across onto the toy box. Early, late, or a slide-jump without it, and you "
                "fall short." % GAP_BOX, 36.5, 14, -14),
        _marker(6, "Toy box", "round", "A big box to circle, 12 high. Its lid is only reached "
                "by the slide jump: the highest safe spot in the room until someone follows.",
                35, 16, 26),
        _marker(7, "Jack-in-the-box", "skill", "A launch pad: it throws you onto the castle's "
                "gatehouse.", 8, 6, -24),
        _marker(8, "Train tunnel", "through", "Slide or crouch through it (4.2 high), or run "
                "round it.", -4, 14, 38),
        _marker(9, "ABC blocks", "round", "Cubes a jump high round the room to juke round and "
                "hop over.", 10, 8, 26),
        _marker(10, "The spinner", "hazard", "A low round stage in the middle (two shallow "
                "steps) with a %d-long bar sweeping round it every %d seconds at hip height. "
                "Jump it as it comes: it shoves you if it hits you. Cross the middle, or go "
                "round." % (SPIN_BAR[0], round(360 / SPIN_RATE)), 0, 6, 0),
    ],
    # [camera x, y, z, target x, y, z, walls and ceiling on (optional)]
    "views": {"Overview": [74, 92, 104, 0, 0, 0, 0], "Top": [0, 165, 0.01, 0, 0, 0, 0],
              "Player's eye": [-32, 6, 45, 8, 6, -12, 1], "Spinner": [28, 20, 32, 0, 1, 0, 0],
              "Bed & wardrobe": [-6, 30, 18, -34, 8, -14, 0],
              "Castle & slide": [6, 34, 12, 32, 10, -28, 0],
              "Slide jump": [-14, 28, 6, 36, 9, 6, 0],
              "Desk & tunnel": [14, 26, 16, -24, 4, 30, 0]},
    "figure": [0, 0, 0],
    "roof_names": ["Ceiling"],
    "roof_extra": ["Ceiling", "WallUpper", "Cloud"],
    "roof_label": "Walls & ceiling",
    "sky": "#BFE3FF",
    "ground": "#8DB3D6",
    "plan": {
        "blueprint": True,
        "heights": [["9", -30, -40], ["8..1", -9, -41], ["26", -45.5, -15.5], ["9", -36, 15.5],
                    ["12", 24, -40], ["20", 36, -43.5], ["26", 17, -42], ["20→8", 42, -20],
                    ["12", 40, 32], ["3", 8, -28], ["11", -4, 42.5], ["5", -6, -29.5],
                    ["1", 0, 9]],
        "routes": [
            {"k": "wallrun", "p": [[WARDROBE[1] + 1.4, BED[3] - 2],
                                   [WARDROBE[1] + 1.4, DESK[2] + 2]]},
            {"k": "launch", "p": [[8, -24], [JACK_TARGET[0], JACK_TARGET[1]]]},
            {"k": "slide", "p": [[-17, 38], [9, 38]]},
            {"k": "stairs", "p": [[4, -34], [-21, -34]]},
            {"k": "stairs", "p": [[23.5, -12], [23.5, -32]]},
            {"k": "stairs", "p": [[22, -43.5], [32, -43.5]]},
            {"k": "stairs", "p": [[36.5, -38], [36.5, -6]]},
            {"k": "jump", "p": [[36.5, -4], [36.5, TOY_BOX[2] + 2]]},
            {"k": "spin", "p": [[0, 0], [16, 0]]},
        ],
        "dims": [[-R, R + 3, R, R + 3, "%d" % (2 * R)], [R + 3, -R, R + 3, R, "%d" % (2 * R)],
                 [-39.6, BED[3], -39.6, DESK[2], "%d (wall run)" % GAP_DESK],
                 [43, SLIDE[2] + LIP, 43, TOY_BOX[2], "%d (lip jump)" % GAP_BOX]],
    },
}


# ---- checks ---------------------------------------------------------------------------------------

def jump_reach(drop, speed=SPRINT):
    """How far a running jump carries you before your feet fall `drop` below takeoff (negative:
    the landing is higher). No margin."""
    up = math.sqrt(2 * GRAVITY * JUMP)
    disc = up * up + 2 * GRAVITY * drop
    if disc < 0:
        return 0.0
    return speed * (up + math.sqrt(disc)) / GRAVITY


OFF_LIMITS = ("Wall", "WallUpper", "Ceiling", "Floor", "Wardrobe", "Tower", "Headboard", "Tunnel")


def surfaces(m, exclude):
    """Every solid top a player can stand on, as (x0, x1, z0, z1, top, name); the slide is
    sampled along its length, the ramps are skipped (they meet what they lead to)."""
    out = []
    nodes = [n for items in m.groups.values() for n in items]
    for p in mapcheck.parts_from_nodes(nodes):
        if not p.solid or p.name in exclude or p.name in OFF_LIMITS or "Spin" in p.attrs:
            continue  # (nobody takes a run-up on a spinning bar)
        if p.name == "Slide":
            for z in range(int(KEEP[3]), int(SLIDE[2])):
                out.append((SLIDE[0], SLIDE[1], z, z + 1, slide_height(z), "Slide"))
            continue
        if p.name in ("CastleRamp", "KeepRamp"):
            continue
        out.append((p.lo[0], p.hi[0], p.lo[2], p.hi[2], p.hi[1], p.name))
    return out


def rect_gap(a, b):
    dx = max(b[0] - a[1], a[0] - b[1], 0)
    dz = max(b[2] - a[3], a[2] - b[3], 0)
    return math.hypot(dx, dz)


def only_by(m, target, name, exclude=()):
    """Problems if any other top reaches `target` (x0, x1, z0, z1, top) with a plain slide jump,
    the fastest move without a gadget, and no margin at all."""
    problems = []
    for s in surfaces(m, (name,) + tuple(exclude)):
        rise = target[4] - s[4]
        if rise > JUMP:
            continue
        gap = rect_gap(s, target)
        if gap <= jump_reach(-rise, SLIDE_JUMP):
            problems.append(f"the {name} can be reached from the {s[5]} (a {gap:.1f} jump, "
                            f"{rise:+.1f})")
    return problems


def check(m):
    problems = []
    if GAP_DESK <= jump_reach(0, SLIDE_JUMP) or GAP_DESK > WALL_RUN or \
            WARDROBE[3] - WARDROBE[2] < GAP_DESK - 6:
        problems.append("the bed-to-desk gap isn't a wall run along the wardrobe")
    if DESK[4] - 1 - (CHAIR[4] + 4) < 0.5:
        problems.append("the chair doesn't fit under the desk")
    problems += only_by(m, DESK, "Desk", exclude=("DeskLeg", "Chair", "ChairBack"))
    # The lip jump: a boosted jump from the end of the lip makes it, a slide jump doesn't, and
    # jumping from the start of the lip still does (the lip is the whole window).
    boosted = jump_reach(-LIP_RISE, LIP_BOOST)
    if not (GAP_BOX + LIP <= boosted - 0.5 and GAP_BOX > jump_reach(-LIP_RISE, SLIDE_JUMP) + 2):
        problems.append(f"the lip jump ({GAP_BOX}, boost reaches {boosted:.1f}) isn't a "
                        "boost-only jump")
    problems += only_by(m, TOY_BOX, "ToyBox", exclude=("SlideLip",))
    if slide_height(GATEHOUSE[3]) - 0.6 - GATEHOUSE[4] < mapcheck.STAND:
        problems.append("the slide passes too low over the gatehouse to stand under")
    if (KEEP[4] - GATEHOUSE[4]) / (KEEP[0] - RAMP2[0]) > 1.0 or \
            GATEHOUSE[4] / (RAMP1[2] - GATEHOUSE[3]) > 1.0:
        problems.append("a castle ramp is too steep")
    if BLOCK > mapcheck.JUMP_UP:
        problems.append("the ABC blocks are too high to hop onto")
    if SPIN_BAR[3] - STAGE[-1][1] > JUMP - 3 or SPIN_BAR[0] / 2 > STAGE[-1][0]:
        problems.append("the spinner's bar is too high to jump or overhangs its stage")
    for x, z in SPAWNS:
        if math.hypot(x, z) < STAGE[0][0] + 1.5:
            problems.append(f"the spawn at ({x}, {z}) is on the spinner")
    landing = fly(JACK_START, LAUNCH, GATEHOUSE[4], GATEHOUSE[3])
    if not landing or math.hypot(landing[0] - JACK_TARGET[0], landing[1] - JACK_TARGET[1]) > 1:
        problems.append("the jack-in-the-box misses the gatehouse")
    lane = WARDROBE[1] + 1.4
    runs = [((lane, BED[4], BED[3] - 1), (lane, DESK[4], DESK[2] + 1), True),
            ((36.5, SLIDE[3], SLIDE[2] + LIP - 0.5), (36.5, TOY_BOX[4], TOY_BOX[2] + 2), False)]
    return problems + mapcheck.check_map(m, ATTRIBUTES, routes=runs)


DEMO = demo_players()

if __name__ == "__main__":
    layout = build()
    print(f"{layout.count()} parts, {len(layout.spawns)} spawns; desk {GAP_DESK} from the bed "
          f"(wall run); toy box {GAP_BOX} from the lip (the boost reaches "
          f"{jump_reach(-LIP_RISE, LIP_BOOST):.1f}, a slide jump "
          f"{jump_reach(-LIP_RISE, SLIDE_JUMP):.1f}); jack-in-the-box {LAUNCH}")
    issues = check(layout)
    for line in issues:
        print("PROBLEM:", line)
    raise SystemExit(1 if issues else 0)
