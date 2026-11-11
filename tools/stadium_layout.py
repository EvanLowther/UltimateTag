#!/usr/bin/env python3
"""Tag Stadium (6-12 players): a football stadium from the owner's reference picture and the
"Stadium Map" design canvas. Writes src/maps/TagStadium/.

    python3 tools/stadium_layout.py

The pitch (180 x 116) sits inside a running track round an oval bowl. You play on the pitch, its
grass and the track; the stands, crowd, roof and scoreboards are scenery behind the front wall
and an invisible wall over it, so they never collide (NO_HIT) and cost no physics.

- Lifting chunks (`Chunks`, shared/PitchChunks): 8 spots inside the lines, 4 up at a time, a new
  random set every Config.Stadium.Cycle seconds. Built lowered (flush with the grass, in holes cut
  through it); `ChunkSlot`, `ChunkMode` (Rise: straight up by `ChunkHeight`; Tilt: turned about
  `ChunkHinge`/`ChunkAxis` until its far end is `ChunkHeight` up over `ChunkLength`; Piston: the
  strut under a tilting ramp). Each hole's floor is 1 down.
- Corner sprinklers: a launch pad (`LaunchVelocity`) under a mist, throwing you 150 along the
  diagonal, about 59 short of the far sprinkler, so it can't loop you.
- Loose balls (`Balls`): physics balls the server owns (server/StadiumWorld).
- LED screens: Textures with `LedStart` (studs round their loop at the face's left edge) that the
  client scrolls the way the strip's arrows point.
- The crowd: 3D fans (`FanId`) in the front rows and the away end, crowd pictures (`CrowdBob`) on
  the rows behind, flag wavers (`Waver`), the choreography's card panels (`ChoreoA`/`ChoreoB`),
  smoke flares in groups (`FlareGroup`), roof flags (`RoofFlag`).
Pictures come from tools/stadium/art.py (uploaded by tools/stadium/upload.py); a part with an
`Image` attribute gets it in the game. Checks: mapcheck, every throw lands, and nothing floats:
every part touches something that leads down to the ground.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "stadium"))
import art  # noqa: E402
import mapcheck  # noqa: E402
from maplib import NO_HIT, SMOKE, Map, rot_z  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "src", "maps", "TagStadium")
rng = random.Random(11)

PX, PZ = 90, 58  # the pitch's half sizes
L = 80  # half the straights; the ends are half circles round (+-L, 0)
TRACK_IN, TRACK_OUT, WALL_OUT = 72, 88, 89.6
ROW, LOW0, LOW_N, UP0, UP_N = 3.4, 89.6, 12, 138, 10
CONC_R = LOW0 + ROW * LOW_N  # the walkway between the tiers
BACK_R = UP0 + ROW * UP_N
SEGS = 25  # pieces round each end (odd, so both ends of a curve match the straights)
LIFT = 0.05  # every other curved piece stands this much prouder (overlaps can't flicker)
STRIPE = 0.05  # the mown stripes' thickness, over the grass
GD, GH = 6.5, 7.5  # goal depth and height
BZ, BX = 60.5, 95.5  # pitch-side screens
AWAY_A, BUFFER_A, CHOREO_A = 0.72, 0.81, 0.9  # radians round the east (away) and west ends
FLOW_TILE = 16  # an LED strip's tile is 16 times its height (the picture is 1024 x 64)
LED_IMAGE = "stadium_led"

COLORS = {
    "grass": (62, 148, 53), "stripeA": (76, 175, 63), "stripeB": (67, 160, 56), "turf": (93, 187, 74),
    "line": (255, 255, 255), "track": (196, 82, 58), "lane": (246, 230, 223), "steel": (91, 101, 115),
    "piston": (163, 172, 183), "hole": (42, 47, 54), "concrete": (154, 161, 170), "rowA": (160, 166, 174),
    "rowB": (149, 156, 165), "walk": (135, 142, 152), "wall": (201, 205, 211), "backwall": (142, 149, 159),
    "roof": (238, 241, 245), "fascia": (214, 219, 226), "navy": (28, 36, 51), "yellow": (255, 210, 63),
    "red": (216, 35, 42), "white": (255, 255, 255), "post": (201, 208, 216), "glass": (191, 227, 245),
    "bench": (142, 151, 163), "dark": (26, 31, 40), "light": (255, 248, 218), "aisle": (196, 200, 207),
    "pole": (216, 221, 228), "orange": (242, 140, 40), "padgrey": (110, 119, 131), "away": (36, 71, 156),
    "awaylt": (159, 211, 255), "ball": (247, 247, 247), "black": (22, 22, 24), "board": (20, 26, 36),
}
MATERIALS = {"glass": "Glass", "post": "Metal", "piston": "Metal", "pole": "Metal", "steel": "Metal"}

ATTRIBUTES = {
    "DisplayName": "Tag Stadium", "MinPlayers": 6, "MaxPlayers": 12, "InRotation": True,
    "Stadium": True, "OutOfBounds": "Ball,DeskTop,SprinklerHead",
    # Up from the screen behind each goal onto the goal's top (a 4.5 jump across a 0.9 gap: too
    # fine for the check's 2-stud grid).
    "ReachRoutes": mapcheck.routes_attribute([((98.6, 3, 0), (93.5, 7.5, 0), False),
                                              ((-98.6, 3, 0), (-93.5, 7.5, 0), False)]),
}

# The lifting chunks: (name, pieces). Piece kinds: block (a solid column), disc (a round one), deck
# (a slab on pistons, open underneath), ramp (a slab hinged at `hinge`, rising away from it).
SLOTS = [
    ("Kickoff Disc", [("disc", 0, 0, 12, 5, True)]),
    ("Halfway Bridge", [("ramp", -41, -15, 26, 40, 10, -41), ("deck", -15, 15, 26, 40, 10, True),
                        ("ramp", 15, 41, 26, 40, 10, 41)]),
    ("Lookout", [("block", -54, -34, -44, -24, 8), ("ramp", -34, -12, -44, -24, 8, -12)]),
    ("Steps", [("block", 34, 42, -46, -26, 4), ("block", 42, 50, -46, -26, 8), ("block", 50, 58, -46, -26, 12)]),
    ("Low Table", [("deck", 22, 44, -12, 10, 5.2, False)]),
    ("Launch Ramp", [("ramp", -52, -22, 2, 20, 10, -52)]),
    ("Hop Blocks", [("block", 44, 58, 20, 34, 4), ("block", 64, 78, 38, 52, 7)]),
    ("Gap Jump", [("ramp", -77, -63, 42, 54, 6, -77), ("block", -53, -39, 42, 54, 5)]),
]
DISC_HOLE = 12.6  # the kickoff disc (radius 12) sits in a square hole this far each way, turf round it

SPRINKLERS = [(-84, -52), (84, -52), (84, 52), (-84, 52)]  # inside the corners, clear of the lines
LAUNCH_UP, LAUNCH_ACROSS = 110, 128
PAD_R = 5
PAD_Y = 0.05  # on the stripes

SPAWNS = [(-72, -12), (-72, 14), (72, -14), (72, 14), (0, -40), (0, 48), (-28, 50), (28, 48),
          (-6, -22), (12, -20), (-62, -46), (60, -50)]


# ---- the oval ----------------------------------------------------------------------------------

def perim(R):
    return 4 * L + 2 * math.pi * R


def oval_at(R, s):
    """A point s studs round the oval at radius R: (x, z, inward normal, the way round)."""
    P = perim(R)
    s %= P
    if s < 2 * L:
        return -L + s, -R, (0, 1), (1, 0)
    s -= 2 * L
    if s < math.pi * R:
        a = -math.pi / 2 + s / R
        return L + R * math.cos(a), R * math.sin(a), (-math.cos(a), -math.sin(a)), (-math.sin(a), math.cos(a))
    s -= math.pi * R
    if s < 2 * L:
        return L - s, R, (0, -1), (-1, 0)
    s -= 2 * L
    a = math.pi / 2 + s / R
    return -L + R * math.cos(a), R * math.sin(a), (-math.cos(a), -math.sin(a)), (-math.sin(a), math.cos(a))


def frame(t, n):
    """Rows for a part whose Front (-Z) faces `n` and whose local -X runs along `t` (both (x, z)):
    a texture on its Front reads left to right the way `t` goes."""
    X = (-t[0], 0, -t[1])
    Y = (0, 1, 0)
    Z = (-n[0], 0, -n[1])
    return [[X[i], Y[i], Z[i]] for i in range(3)]


def oval_pieces(r0, r1, segs=SEGS):
    """The pieces of a band round the oval from r0 to r1, in order round it: the two straights and
    `segs` pieces round each end. Curved pieces are boxes as wide as the band's outside, so they
    overlap a little; every other one (`alt`) stands LIFT prouder so no faces share a plane."""
    out = []
    half = math.pi / segs / 2
    rin = r0 * math.cos(half)
    width = 2 * r1 * math.tan(half)
    mid = (rin + r1) / 2

    def cap(cx, start, s_base, side):
        for k in range(segs):
            a = start + (k + 0.5) * math.pi / segs
            sm = s_base + (k + 0.5) * math.pi / segs * r0
            out.append({"center": (cx + mid * math.cos(a), mid * math.sin(a)), "width": width,
                        "depth": r1 - rin, "t": (-math.sin(a), math.cos(a)),
                        "n": (-math.cos(a), -math.sin(a)), "s0": sm - width / 2, "s1": sm + width / 2,
                        "alt": k % 2 == 0, "angle": a, "end": side, "face_r": rin})

    out.append({"center": (0, -(r0 + r1) / 2), "width": 2 * L, "depth": r1 - r0, "t": (1, 0), "n": (0, 1),
                "s0": 0, "s1": 2 * L, "alt": False, "angle": None, "end": None, "face_r": r0})
    cap(L, -math.pi / 2, 2 * L, "E")
    out.append({"center": (0, (r0 + r1) / 2), "width": 2 * L, "depth": r1 - r0, "t": (-1, 0), "n": (0, -1),
                "s0": 2 * L + math.pi * r0, "s1": 4 * L + math.pi * r0, "alt": False, "angle": None,
                "end": None, "face_r": r0})
    cap(-L, math.pi / 2, 4 * L + math.pi * r0, "W")
    return out


def region(x, z):
    """Who sits here: away (the east end), buffer (empty seats beside it), choreo (the west end's
    card display) or home."""
    if x > L:
        a = abs(math.atan2(z, x - L))
        if a < AWAY_A:
            return "away"
        if a < BUFFER_A:
            return "buffer"
    if x < -L:
        a = math.atan2(z, -(x + L))
        if abs(a) < CHOREO_A:
            return "choreo"
    return "home"


def piece_region(p):
    if p["angle"] is None:
        return "home"
    x = (L if p["end"] == "E" else -L) + 100 * math.cos(p["angle"])
    return region(x, 100 * math.sin(p["angle"]))


def oval_ring(m, group, name, r0, r1, y0, y1, color, segs=SEGS, texture=None, **props):
    """A band round the oval from r0 to r1 and y0 to y1. `texture(piece, height)` may give the
    children (Textures) for each piece."""
    nodes = []
    for p in oval_pieces(r0, r1, segs):
        lift = LIFT if p["alt"] else 0
        a, b = y0 - lift, y1 + lift
        kids = texture(p, b - a) if texture else None
        node = m.part(group, name, (p["width"], b - a, p["depth"]), (p["center"][0], (a + b) / 2, p["center"][1]),
                      color, frame(p["t"], p["n"]), children=kids, **props)
        nodes.append((node, p))
    return nodes


def tex(face, image, u, v, attributes=None, color=None, transparency=0):
    props = {"Face": face, "StudsPerTileU": round(u, 3), "StudsPerTileV": round(v, 3), "Texture": "",
             "Transparency": transparency}
    if color is not None:
        props["Color3"] = [round(c / 255, 3) for c in color]
    attrs = {"Image": image}
    attrs.update(attributes or {})
    return {"name": "Picture", "className": "Texture", "properties": props, "attributes": attrs}


def decal(face, image):
    return {"name": "Picture", "className": "Decal", "properties": {"Face": face, "Texture": ""},
            "attributes": {"Image": image}}


def led(face, height, start):
    return tex(face, LED_IMAGE, FLOW_TILE * height, height, {"LedStart": round(start, 3)})


def v3(v):
    return {"Vector3": [round(c, 3) for c in v]}


def cyl_y(m, group, name, x, y0, y1, z, diameter, color, **props):
    """An upright cylinder from y0 to y1."""
    return m.part(group, name, (y1 - y0, diameter, diameter), (x, (y0 + y1) / 2, z), color, rot_z(90),
                  Shape="Cylinder", **props)


def rod(m, group, name, a, b, diameter, color, **props):
    """A cylinder from point a to point b."""
    d = [b[i] - a[i] for i in range(3)]
    length = math.sqrt(sum(c * c for c in d))
    X = [c / length for c in d]
    helper = (0, 1, 0) if abs(X[1]) < 0.9 else (1, 0, 0)
    Z = [X[1] * helper[2] - X[2] * helper[1], X[2] * helper[0] - X[0] * helper[2], X[0] * helper[1] - X[1] * helper[0]]
    zl = math.sqrt(sum(c * c for c in Z))
    Z = [c / zl for c in Z]
    Y = [Z[1] * X[2] - Z[2] * X[1], Z[2] * X[0] - Z[0] * X[2], Z[0] * X[1] - Z[1] * X[0]]
    rows = [[X[i], Y[i], Z[i]] for i in range(3)]
    mid = [(a[i] + b[i]) / 2 for i in range(3)]
    return m.part(group, name, (length, diameter, diameter), mid, color, rows, Shape="Cylinder", **props)


def fan_triangles(m, group, name, center, R, a0, a1, segs, y0, y1, color, **props):
    """A flat fan (pie slice) from the center out to radius R between angles a0 and a1 (radians,
    in (x, z)), `segs` pieces of two flat wedges each, meeting exactly."""
    span = (a1 - a0) / segs
    for k in range(segs):
        a = a0 + (k + 0.5) * span
        c, s = math.cos(span / 2), math.sin(span / 2)
        radial, tangent = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))

        def world(t, r):
            return (center[0] + t * tangent[0] + r * radial[0], center[1] + t * tangent[1] + r * radial[1])

        for side in (-1, 1):
            m.flat_triangle(group, name, world(0, R * c), center, world(side * R * s, R * c), y0, y1, color, **props)


def triangle(m, group, name, p, q, r_, y0, y1, color, **props):
    """Any flat triangle (points (x, z)) as two right-angled ones split at the foot of the
    altitude onto its longest side."""
    pts = [p, q, r_]
    lengths = [math.dist(pts[(i + 1) % 3], pts[(i + 2) % 3]) for i in range(3)]
    i = lengths.index(max(lengths))
    apex, b, c = pts[i], pts[(i + 1) % 3], pts[(i + 2) % 3]
    bx, bz = c[0] - b[0], c[1] - b[1]
    t = ((apex[0] - b[0]) * bx + (apex[1] - b[1]) * bz) / (bx * bx + bz * bz)
    foot = (b[0] + t * bx, b[1] + t * bz)
    for end in (b, c):
        # (a sliver thinner than this is left out: rounded, it would overlap its neighbour)
        if math.dist(foot, end) > 0.08 and math.dist(foot, apex) > 0.08:
            m.flat_triangle(group, name, foot, apex, end, y0, y1, color, **props)


# ---- ground, pitch and track -------------------------------------------------------------------

def footprints_of(pieces):
    holes = []
    for piece in pieces:
        if piece[0] == "disc":
            _, x, z, _, _, _ = piece
            holes.append((x - DISC_HOLE, x + DISC_HOLE, z - DISC_HOLE, z + DISC_HOLE))
        else:
            holes.append(piece[1:5])
    return holes


def footprints():
    """Every chunk piece's hole (x0, x1, z0, z1)."""
    return [h for _, pieces in SLOTS for h in footprints_of(pieces)]


def build_ground(m):
    holes = footprints()
    # The concrete round the bowl (the stands stand on it) and the dark floor under every hole.
    # The ground the stands stand on: hidden under them, so it's invisible (its wide pieces overlap).
    oval_ring(m, "Ground", "Concrete", TRACK_OUT + 0.2, BACK_R + 4, -1, 0, "concrete", Transparency=1, **NO_HIT)
    for _, pieces in SLOTS:  # one floor under each chunk, a little bigger than its holes
        rects = [h for h in footprints_of(pieces)]
        m.block("Ground", "HoleFloor", min(h[0] for h in rects) - 0.5, max(h[1] for h in rects) + 0.5, -2, -1,
                min(h[2] for h in rects) - 0.5, max(h[3] for h in rects) + 0.5, "hole")
    # Grass inside the track: the middle with the chunk holes cut out, and the two ends.
    m.slab("Ground", "Grass", (-L, L, -TRACK_IN, TRACK_IN), -1, 0, holes, "grass")
    for cx, a0 in ((L, -math.pi / 2), (-L, math.pi / 2)):
        fan_triangles(m, "Ground", "Grass", (cx, 0), TRACK_IN, a0, a0 + math.pi, SEGS, -1, 0, "grass")
    # The kickoff disc's hole is square: turf fills its corners round a 24-sided circle that just
    # clears the disc (edges tangent to it).
    n = 24
    rr = DISC_HOLE / math.cos(math.pi / n)
    for k in range(n):
        a0 = math.radians(45 + 360 / n * k)
        a1 = math.radians(45 + 360 / n * (k + 1))
        v0 = (rr * math.cos(a0), rr * math.sin(a0))
        v1 = (rr * math.cos(a1), rr * math.sin(a1))

        def to_square(a):
            c, s = math.cos(a), math.sin(a)
            k_ = (DISC_HOLE + 0.06) / max(abs(c), abs(s))  # just over the hole's edge: no seam
            return (k_ * c, k_ * s)

        s0, s1 = to_square(a0), to_square(a1)
        color = "stripeB" if (v0[0] + v1[0]) / 2 > 0 else "stripeA"
        top = STRIPE + 0.05
        triangle(m, "Ground", "DiscCorner", v0, v1, s1, -0.95, top, color)
        if math.dist(s0, s1) > 1e-3:
            triangle(m, "Ground", "DiscCorner", v0, s1, s0, -0.95, top, color)
    # Mown stripes (laid over the grass, no collision), with the same holes.
    # (They reach a little past the lines, so every line lies on them.)
    for i in range(12):
        x0 = -PX + i * 15
        x0, x1 = x0 - (0.3 if i == 0 else 0), x0 + 15 + (0.3 if i == 11 else 0)
        m.slab("Pitch", "Stripe", (x0, x1, -PZ - 0.3, PZ + 0.3), 0, STRIPE, holes, "stripeB" if i % 2 else "stripeA",
               **NO_HIT)
    # The running track: straights and exact curved pieces.
    for sign in (-1, 1):
        m.block("Ground", "Track", -L, L, -1, 0, *sorted((sign * TRACK_IN, sign * TRACK_OUT)), "track")
    span = 180 / SEGS
    for cx, base in ((L, -90), (-L, 90)):
        for k in range(SEGS):
            m.ring_segment("Ground", "Track", TRACK_IN, TRACK_OUT, base + (k + 0.5) * span, span, -1, 0, "track",
                           center=(cx, 0))
    build_lanes(m)


def build_lanes(m):
    """Seven lane lines round the track, laid on it (every other curved piece a little prouder)."""
    for k in range(7):
        R = TRACK_IN + 0.4 + k * (TRACK_OUT - TRACK_IN - 0.8) / 6
        for sign in (-1, 1):
            m.block("Lines", "Lane", -L, L, 0, 0.07, sign * R - 0.12, sign * R + 0.12, "lane", **NO_HIT)
        for cx, start in ((L, -math.pi / 2), (-L, math.pi / 2)):
            pieces = 21  # odd: both ends prouder than the straights they meet
            for j in range(pieces):
                a = start + (j + 0.5) * math.pi / pieces
                w = 2 * R * math.tan(math.pi / pieces / 2) + 0.02
                top = 0.07 + (0.05 if j % 2 == 0 else 0)
                m.part("Lines", "Lane", (w, top, 0.24), (cx + R * math.cos(a), top / 2, R * math.sin(a)), "lane",
                       frame((-math.sin(a), math.cos(a)), (-math.cos(a), -math.sin(a))), **NO_HIT)


def build_lines(m):
    """The pitch markings, laid on the stripes. Kept off the chunk holes: the disc and the bridge
    deck carry their own bit of the halfway line."""
    y0, y1, w = STRIPE, STRIPE + 0.07, 0.5

    def hline(x0, x1, z):
        m.block("Lines", "Line", x0, x1, y0, y1, z - w / 2, z + w / 2, "line", **NO_HIT)

    def vline(x, z0, z1):
        m.block("Lines", "Line", x - w / 2, x + w / 2, y0, y1, z0, z1, "line", **NO_HIT)

    # Touchlines run the full length; goal lines stop at them (no overlap).
    hline(-PX - w / 2, PX + w / 2, -PZ)
    hline(-PX - w / 2, PX + w / 2, PZ)
    for x in (-PX, PX):
        vline(x, -PZ + w / 2, PZ - w / 2)
    # The halfway line stops short of the seams round the disc and the bridge.
    vline(0, -PZ + w / 2, -DISC_HOLE - 0.4)
    vline(0, DISC_HOLE + 0.4, 25.8)
    vline(0, 40.2, PZ - w / 2)
    for s in (-1, 1):
        g = s * PX
        for depth, half in ((30, 35), (10, 15)):
            edge = g - s * depth
            vline(edge, -half + w / 2, half - w / 2)
            for z in (-half, half):
                lo, hi = (edge - w / 2, g - w / 2) if s > 0 else (g + w / 2, edge + w / 2)
                hline(lo, hi, z)
        cyl_y(m, "Lines", "Spot", g - s * 18, y0, y1, 0, 1.4, "line", **NO_HIT)
    arc(m, 0, 0, 18, 0, 2 * math.pi, 36)
    a = math.acos(12 / 18)
    arc(m, -72, 0, 18, -a, a, 10)
    arc(m, 72, 0, 18, math.pi - a, math.pi + a, 10)
    for cx, cz, a0 in ((-PX, -PZ, 0), (PX, -PZ, math.pi / 2), (PX, PZ, math.pi), (-PX, PZ, 1.5 * math.pi)):
        arc(m, cx, cz, 2, a0, a0 + math.pi / 2, 4)
        cyl_y(m, "Lines", "CornerPost", cx, STRIPE + 0.07, 4.2, cz, 0.24, "white", **NO_HIT)
        flag_z = cz + (1.4 if cz < 0 else -1.4)
        m.block("Lines", "CornerFlag", cx - 0.03, cx + 0.03, 3.1, 4.1, min(cz, flag_z) + 0.12 * (1 if cz < 0 else 0),
                max(cz, flag_z) - 0.12 * (0 if cz < 0 else 1), "yellow" if cx < 0 else "red", **NO_HIT)


def arc(m, cx, cz, R, a0, a1, pieces):
    """A painted arc: short straight pieces, every other one a little prouder."""
    span = (a1 - a0) / pieces
    for j in range(pieces):
        a = a0 + (j + 0.5) * span
        w = 2 * R * math.tan(abs(span) / 2) + 0.06
        top = STRIPE + 0.12 + (0.05 if j % 2 == 0 else 0)  # always prouder than the straight lines
        m.part("Lines", "Line", (w, top - STRIPE, 0.5), (cx + R * math.cos(a), (top + STRIPE) / 2, cz + R * math.sin(a)),
               "line", frame((-math.sin(a), math.cos(a)), (-math.cos(a), -math.sin(a))), **NO_HIT)


# ---- the lifting chunks ------------------------------------------------------------------------

def build_chunks(m):
    for slot, (name, pieces) in enumerate(SLOTS, 1):
        rects = [p for p in pieces if p[0] != "disc"]
        for piece in pieces:
            kind = piece[0]
            base = {"ChunkSlot": slot}
            if kind == "disc":
                _, x, z, radius, h, paint = piece
                rise = dict(base, ChunkMode="Rise", ChunkHeight=h)
                cyl_y(m, "Chunks", "ChunkDisc", x, -1 - h, 0, z, 2 * radius, "steel", attributes=rise)
                cyl_y(m, "Chunks", "ChunkTurf", x, 0, 0.06, z, 2 * radius - 0.02, "turf", attributes=rise, **NO_HIT)
                if paint:
                    m.block("Chunks", "ChunkPaint", x - 0.25, x + 0.25, 0.06, 0.13, z - radius + 0.3, z + radius - 0.3,
                            "line", attributes=rise, **NO_HIT)
                    cyl_y(m, "Chunks", "ChunkPaint", x, 0.07, 0.18, z, 1.4, "line", attributes=rise, **NO_HIT)
                seam_circle(m, slot, x, z, radius)
                continue
            x0, x1, z0, z1, h = piece[1:6]
            if kind == "block":
                rise = dict(base, ChunkMode="Rise", ChunkHeight=h)
                m.block("Chunks", "ChunkBlock", x0, x1, -1 - h, 0, z0, z1, "steel", attributes=rise)
                m.block("Chunks", "ChunkTurf", x0 + 0.01, x1 - 0.01, 0, 0.06, z0 + 0.01, z1 - 0.01, "turf",
                        attributes=rise, **NO_HIT)
            elif kind == "deck":
                paint = piece[6]
                rise = dict(base, ChunkMode="Rise", ChunkHeight=h)
                m.block("Chunks", "ChunkDeck", x0, x1, -1.2, 0, z0, z1, "steel", attributes=rise)
                m.block("Chunks", "ChunkTurf", x0 + 0.01, x1 - 0.01, 0, 0.06, z0 + 0.01, z1 - 0.01, "turf",
                        attributes=rise, **NO_HIT)
                for px, pz in ((x0 + 3, z0 + 3), (x1 - 3, z0 + 3), (x0 + 3, z1 - 3), (x1 - 3, z1 - 3)):
                    cyl_y(m, "Chunks", "ChunkPiston", px, -1.2 - h, -1.2, pz, 1.4, "piston", attributes=rise, **NO_HIT)
                if paint:
                    m.block("Chunks", "ChunkPaint", -0.25, 0.25, 0.06, 0.13, z0 + 0.3, z1 - 0.3, "line",
                            attributes=rise, **NO_HIT)
            elif kind == "ramp":
                hinge = piece[6]
                far = x1 if hinge == x0 else x0
                direction = 1 if far > hinge else -1
                length = abs(far - hinge)
                zc = (z0 + z1) / 2
                # Turning +angle about +Z lifts the +X end, so the axis points the way that lifts `far`.
                tilt = dict(base, ChunkMode="Tilt", ChunkHeight=h, ChunkLength=length,
                            ChunkHinge=v3((hinge, 0, zc)), ChunkAxis=v3((0, 0, direction)))
                m.block("Chunks", "ChunkRamp", x0, x1, -1.2, 0, z0, z1, "steel", attributes=tilt)
                m.block("Chunks", "ChunkTurf", x0 + 0.01, x1 - 0.01, 0, 0.06, z0 + 0.01, z1 - 0.01, "turf",
                        attributes=tilt, **NO_HIT)
                at = 0.82
                strut = at * h + 2.4
                piston = dict(base, ChunkMode="Piston", ChunkHeight=h, ChunkLength=length, PistonAt=at,
                              ChunkHinge=v3((hinge, 0, zc)), ChunkDir=direction)
                cyl_y(m, "Chunks", "ChunkPiston", hinge + direction * at * length, -1.2 - strut, -1.2, zc, 1.4,
                      "piston", attributes=piston, **NO_HIT)
            seam_rect(m, slot, piece[1:5], [p[1:5] for p in rects if p is not piece])


def seam_rect(m, slot, rect, others):
    """The edge of a chunk's hole, laid on the stripes (it flashes before the chunk moves); edges
    shared with another piece of the same chunk are left out."""
    x0, x1, z0, z1 = rect
    w = 0.3
    y0, y1 = STRIPE, STRIPE + 0.07
    attrs = {"ChunkSeam": slot}

    def shared(axis, value, lo, hi):
        for o in others:
            if axis == "x" and value in (o[0], o[1]) and min(hi, o[3]) - max(lo, o[2]) > 0.5:
                return True
            if axis == "z" and value in (o[2], o[3]) and min(hi, o[1]) - max(lo, o[0]) > 0.5:
                return True
        return False

    # Strips along X cover the corners; strips along Z stop at them, or run to the shared edge.
    left, right = not shared("x", x0, z0, z1), not shared("x", x1, z0, z1)
    for x in (x0, x1):
        if not shared("x", x, z0, z1):
            m.block("Seams", "Seam", x - w / 2, x + w / 2, y0, y1, z0 - w / 2, z1 + w / 2, "dark", attributes=attrs, **NO_HIT)
    for z in (z0, z1):
        if not shared("z", z, x0, x1):
            m.block("Seams", "Seam", x0 + (w / 2 if left else 0), x1 - (w / 2 if right else 0), y0, y1, z - w / 2, z + w / 2,
                    "dark", attributes=attrs, **NO_HIT)


def seam_circle(m, slot, x, z, radius):
    pieces = 32
    for j in range(pieces):
        a = (j + 0.5) * 2 * math.pi / pieces
        w = 2 * (radius + 0.15) * math.tan(math.pi / pieces) + 0.04
        bottom = STRIPE + (0.05 if j % 2 == 0 else 0)
        top = bottom + 0.1  # over the turf round the disc
        m.part("Seams", "Seam", (w, top - bottom, 0.3), (x + (radius + 0.15) * math.cos(a), (top + bottom) / 2,
                                                            z + (radius + 0.15) * math.sin(a)),
               "dark", frame((-math.sin(a), math.cos(a)), (-math.cos(a), -math.sin(a))),
               attributes={"ChunkSeam": slot}, **NO_HIT)


# ---- goals, screens, sprinklers, benches, balls ------------------------------------------------

def build_goals(m):
    for s in (-1, 1):
        g, b = s * PX, s * (PX + GD)
        lo, hi = sorted((g, b))
        for z in (-12, 12):
            cyl_y(m, "Goals", "GoalPost", g, STRIPE + 0.07, GH, z, 0.9, "white")  # on the goal line
            cyl_y(m, "Goals", "GoalBackPost", b, 0, GH, z, 0.6, "post")
            rod(m, "Goals", "GoalBar", (g, GH, z), (b, GH, z), 0.6, "post")
        rod(m, "Goals", "Crossbar", (g, GH, -12.45), (g, GH, 12.45), 0.9, "white")
        rod(m, "Goals", "GoalBar", (b, GH, -12.3), (b, GH, 12.3), 0.6, "post")
        for z0, z1, color in ((-12, 0, "yellow"), (0, 12, "red")):
            tint = COLORS[color]
            m.block("Goals", "GoalNet", b - 0.05, b + 0.05, 0, GH - 0.2, z0, z1, "white", Transparency=1,
                    children=[tex(f, "stadium_net", 1.1, 1.1, color=tint) for f in ("Right", "Left")])
            m.block("Goals", "GoalTop", lo + 0.45 * (s > 0), hi - 0.45 * (s < 0), GH - 0.2, GH, z0, z1, "white",
                    Transparency=1, children=[tex(f, "stadium_net", 1.1, 1.1, color=tint) for f in ("Top", "Bottom")])
        for z, color in ((-12, "yellow"), (12, "red")):
            m.block("Goals", "GoalNet", lo, hi, 0, GH - 0.2, z - 0.05, z + 0.05, "white", Transparency=1,
                    children=[tex(f, "stadium_net", 1.1, 1.1, color=COLORS[color]) for f in ("Front", "Back")])
        z = -10.5
        while z <= 10.6:
            m.block("Goals", "GoalSlat", lo + 0.6, hi - 0.6, GH, GH + 0.1, z - 0.16, z + 0.16,
                    "yellow" if z < 0 else "red", **NO_HIT)
            z += 3


def loop_s(x, z, side):
    """Distance round the pitch-side screens' loop (the same way round as the stands)."""
    if side == "S":
        return x + BX
    if side == "E":
        return 2 * BX + z + BZ
    if side == "N":
        return 2 * BX + 2 * BZ + BX - x
    return 4 * BX + 2 * BZ + BZ - z


SIDES = {"S": ((1, 0), (0, 1)), "E": ((0, 1), (-1, 0)), "N": ((-1, 0), (0, -1)), "W": ((0, -1), (1, 0))}


def screen(m, x0, x1, z0, z1, side):
    """A pitch-side screen, 3 high: LED on both long faces, scrolling round the loop."""
    t, n = SIDES[side]
    along = side in ("S", "N")
    length = (x1 - x0) if along else (z1 - z0)
    thick = (z1 - z0) if along else (x1 - x0)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    # The ends of the screen along the loop: low s first.
    a = (cx - t[0] * length / 2, cz - t[1] * length / 2)
    b = (cx + t[0] * length / 2, cz + t[1] * length / 2)
    s_lo, s_hi = loop_s(*a, side), loop_s(*b, side)
    m.part("Screens", "Screen", (length, 3, thick), (cx, 1.5, cz), "navy", frame(t, n),
           children=[led("Front", 3, s_lo), led("Back", 3, -s_hi)])


def build_screens(m):
    for side, z in (("S", -BZ), ("N", BZ)):
        for x0, x1 in ((-84, -36), (-12, 12), (36, 84)):
            screen(m, x0, x1, z - 0.5, z + 0.5, side)
    for side, x in (("E", BX), ("W", -BX)):
        for z0, z1 in ((-52, -22), (22, 52)):
            screen(m, x - 0.5, x + 0.5, z0, z1, side)
        # Behind the goal, clear of it: the step up onto the goal's top.
        gx = (1 if x > 0 else -1) * (PX + GD + 2.1)
        screen(m, gx - 1.2, gx + 1.2, -12, 12, side)


def build_sprinklers(m):
    for x, z in SPRINKLERS:
        d = (-x, -z)
        length = math.hypot(*d)
        d = (d[0] / length, d[1] / length)
        velocity = (d[0] * LAUNCH_ACROSS, LAUNCH_UP, d[1] * LAUNCH_ACROSS)
        # The pad sits on the lines it crosses (the goal line, the corner arc).
        cyl_y(m, "Sprinklers", "SprinklerPad", x, PAD_Y, PAD_Y + 0.2, z, 2 * PAD_R, "padgrey",
              attributes={"LaunchVelocity": v3(velocity)})
        cyl_y(m, "Sprinklers", "SprinklerHead", x, PAD_Y + 0.2, 1.8, z, 1.3, "orange",
              attributes={"SoundLoop": "amb_sprinkler", "SoundNear": 12, "SoundRange": 70}, **NO_HIT)
        # The mist: an emitter on the head facing up the diagonal.
        up = math.radians(52)
        f = (d[0] * math.cos(up), math.sin(up), d[1] * math.cos(up))
        Z = (-f[0], -f[1], -f[2])
        X = (Z[2], 0, -Z[0])  # up x Z
        xl = math.hypot(X[0], X[2])
        X = (X[0] / xl, 0, X[2] / xl)
        Y = (Z[1] * X[2] - Z[2] * X[1], Z[2] * X[0] - Z[0] * X[2], Z[0] * X[1] - Z[1] * X[0])
        rows = [[X[i], Y[i], Z[i]] for i in range(3)]
        mist = m.particles("Mist", 60, (1.2, 1.7), (20, 34), [(0, 1.2), (0.5, 3.5), (1, 6)],
                           [(0, 0.45), (0.6, 0.75), (1, 1)], (244, 251, 255), direction="Front",
                           spread=(28, 10), accel=(0, -30, 0))
        m.part("Sprinklers", "SprinklerMist", (0.6, 0.6, 0.6), (x, 1.8, z), "orange", rows, Transparency=1,
               children=[mist], **NO_HIT)


def build_benches(m):
    for x, seats in ((-24, ("red", "yellow")), (24, ("away", "white"))):
        m.block("Benches", "BenchBase", x - 8.4, x + 8.4, 0, 0.15, -71, -63.4, "bench")
        # The glass canopy: a half tube along X, in panels; glass ends cut to its curve.
        panels, R, cz, cy = 10, 3.6, -67.2, 0.15
        for k in range(panels):
            a = (k + 0.5) * math.pi / panels
            w = 2 * R * math.tan(math.pi / panels / 2) + 0.05
            rows = [[1, 0, 0], [0, math.cos(a), math.sin(a)], [0, -math.sin(a), math.cos(a)]]
            m.part("Benches", "Canopy", (16.6, w, 0.12), (x, cy + R * math.sin(a), cz + R * math.cos(a)), "glass",
                   rows, Transparency=0.55)
        for ex in (x - 8.2, x + 8.2):
            strips = 7
            for j in range(strips):
                z0 = cz - R + 0.2 + j * (2 * R - 0.4) / strips
                z1 = z0 + (2 * R - 0.4) / strips
                edge = max(abs(z0 - cz), abs(z1 - cz))
                top = cy + math.sqrt(max(0.0, R * R - edge * edge)) - 0.1
                m.block("Benches", "CanopyEnd", ex - 0.06, ex + 0.06, cy, top, z0, z1, "glass", Transparency=0.55)
        for i in range(6):
            sx = x - 6.5 + i * 2.6
            color = seats[i % 2]
            m.block("Benches", "BenchSeat", sx - 1, sx + 1, cy, 1.4, -68.6, -67.4, color, **NO_HIT)
            m.block("Benches", "BenchSeat", sx - 1, sx + 1, cy, 2.9, -69.3, -68.9, color, **NO_HIT)
    # The technical area: a dashed white box in front of the bench.
        tx0, tx1, tz0, tz1 = x - 10, x + 10, -63.2, -59.2
        xx = tx0
        while xx < tx1 - 0.5:
            for zz in (tz0, tz1):
                m.block("Lines", "TechArea", xx, xx + 1.1, 0, 0.07, zz - 0.15, zz + 0.15, "line", **NO_HIT)
            xx += 2
        for xx in (tx0, tx1):
            zz = tz0 + 0.6
            while zz < tz1 - 0.6:
                m.block("Lines", "TechArea", xx - 0.15, xx + 0.15, 0, 0.07, zz, zz + 1.1, "line", **NO_HIT)
                zz += 2
    m.block("Benches", "Desk", -2.4, 2.4, 0, 2.4, -66, -64.4, "dark")
    m.block("Benches", "DeskTop", -2.2, 2.2, 2.4, 2.6, -66, -64.4, "white", **NO_HIT)
    m.block("Benches", "DeskBoard", -0.9, 0.9, 2.6, 3.8, -65.4, -65.1, "navy", **NO_HIT)


def ico_dirs():
    ph = (1 + math.sqrt(5)) / 2
    pts = []
    for a, b in ((1, ph), (-1, ph), (1, -ph), (-1, -ph)):
        pts += [(0, a, b), (a, b, 0), (b, 0, a)]
    return [tuple(c / math.sqrt(1 + ph * ph) for c in p) for p in pts]


def build_balls(m):
    homes = [(-30, -10), (12, 20), (48, 6), (-70, -30), (20, -50)]
    for i, (x, z) in enumerate(homes, 1):
        group = f"Ball{i}"
        y = 2 + STRIPE
        m.part(group, "Ball", (4, 4, 4), (x, y, z), "ball", Shape="Ball",
               attributes={"Ball": i, "BallHome": v3((x, y, z))})
        for d in ico_dirs():
            Y = (0, 1, 0) if abs(d[1]) < 0.9 else (1, 0, 0)
            Z = (d[1] * Y[2] - d[2] * Y[1], d[2] * Y[0] - d[0] * Y[2], d[0] * Y[1] - d[1] * Y[0])
            zl = math.sqrt(sum(c * c for c in Z))
            Z = tuple(c / zl for c in Z)
            Y = (Z[1] * d[2] - Z[2] * d[1], Z[2] * d[0] - Z[0] * d[2], Z[0] * d[1] - Z[1] * d[0])
            rows = [[d[k], Y[k], Z[k]] for k in range(3)]
            c = 1.93
            m.part(group, "Patch", (0.16, 1.35, 1.35), (x + d[0] * c, y + d[1] * c, z + d[2] * c), "black", rows,
                   Shape="Cylinder", **NO_HIT)


# ---- the bowl ----------------------------------------------------------------------------------

def low_top(i):
    return 5 + 1.7 * (i + 1)


def up_top(i):
    return 31 + 2 * (i + 1)


def rows_list():
    out = []
    for i in range(LOW_N):
        out.append({"r": LOW0 + ROW * i, "top": low_top(i), "tier": 0, "i": i, "gi": i})
    for i in range(UP_N):
        out.append({"r": UP0 + ROW * i, "top": up_top(i), "tier": 1, "i": i, "gi": LOW_N + i})
    return out


TUNNELS = (-60, -20, 20, 60)
AISLES_X = (-40, 0, 40)


def in_tunnel(row, x, z):
    return row["tier"] == 0 and 5 <= row["i"] <= 8 and abs(x) < L and any(abs(x - t) < 4.6 for t in TUNNELS)


def near_aisle(x, z, R, gap=1.4):
    if abs(x) < L:
        return any(abs(x - a) < gap for a in AISLES_X)
    cx = L if x > 0 else -L
    a = math.atan2(z, x - cx)
    step = math.pi / 5
    k = round(a / step)
    return abs(a - k * step) * R < gap and abs(abs(a) - math.pi / 2) > 0.05


def build_bowl(m):
    # Front wall round the track (solid) with its LED band, and an invisible wall over it.
    oval_ring(m, "Bowl", "FrontWall", TRACK_OUT, WALL_OUT, -0.5, 5, "wall",
              texture=lambda p, h: [led("Front", h, p["s0"])])
    oval_ring(m, "Bowl", "BoundaryWall", TRACK_OUT, WALL_OUT, 5, 70, "wall", Transparency=1, CastShadow=False)
    # Terraces, the walkway, the upper tier's LED front, the back wall, the roof.
    for row in rows_list():
        def seats(p, h, row=row):
            away = piece_region(p) in ("away", "buffer")
            return [tex("Top", "stadium_seats_away" if away else "stadium_seats", 2.6, 3.4)]
        # Every other terrace starts a little lower: neighbours' flat pieces overlap at the seams.
        oval_ring(m, "Bowl", "Terrace", row["r"], row["r"] + ROW, -0.1 * (row["gi"] % 2), row["top"],
                  "rowA" if row["i"] % 2 else "rowB", texture=seats, **NO_HIT)
    walk = low_top(LOW_N - 1) - 0.1  # a step down from the last row
    oval_ring(m, "Bowl", "Walkway", CONC_R, UP0, -0.2, walk, "walk", **NO_HIT)
    oval_ring(m, "Bowl", "TierFront", UP0 - 1, UP0, walk, 31, "wall",
              texture=lambda p, h: [led("Front", h, p["s0"])], **NO_HIT)
    oval_ring(m, "Bowl", "BackWall", BACK_R, BACK_R + 2, 0, 58, "backwall", **NO_HIT)
    oval_ring(m, "Bowl", "Roof", 141, BACK_R + 6, 62, 63.6, "roof", **NO_HIT)
    oval_ring(m, "Bowl", "Fascia", 141.3, 143, 59.6, 62, "fascia", **NO_HIT)
    P = perim(BACK_R + 1)
    s = 0
    while s < P - 1:
        x, z, _, _ = oval_at(BACK_R + 1, s)
        cyl_y(m, "Bowl", "Strut", x, 58, 62, z, 1.6, "post", **NO_HIT)
        s += P / round(P / 26)
    P = perim(143.8)
    s = 0
    while s < P - 1:
        x, z, n, t = oval_at(143.8, s)
        m.part("Bowl", "Floodlight", (5, 1.4, 1.4), (x, 61.3, z), "light", frame(t, n), **NO_HIT)
        s += P / round(P / 11)
    # Aisles: stairs across the terraces between sections.
    for row in rows_list():
        R = row["r"] + ROW / 2
        for z0, z1 in ((row["r"] + 0.05, row["r"] + ROW - 0.05), (-row["r"] - ROW + 0.05, -row["r"] - 0.05)):
            for ax in AISLES_X:
                m.block("Bowl", "Aisle", ax - 0.8, ax + 0.8, row["top"], row["top"] + 0.06, z0, z1, "aisle", **NO_HIT)
        for cx in (L, -L):
            for k in range(-2, 3):
                a = k * math.pi / 5 + (0 if cx > 0 else math.pi)
                if cx > 0 and region(cx + R * math.cos(a), R * math.sin(a)) in ("away", "buffer"):
                    continue
                if cx < 0 and region(cx + R * math.cos(a), R * math.sin(a)) == "choreo":
                    continue
                n = (-math.cos(a), -math.sin(a))
                t = (-math.sin(a), math.cos(a))
                m.part("Bowl", "Aisle", (1.6, 0.12, ROW - 0.1), (cx + R * math.cos(a), row["top"] + 0.06, R * math.sin(a)),
                       "aisle", frame(t, n), **NO_HIT)
    # Tunnel mouths in the lower tier.
    for tx in TUNNELS:
        for side in (-1, 1):
            r0, r1 = LOW0 + ROW * 5 - 0.06, LOW0 + ROW * 9 + 0.06  # just proud of the risers
            z0, z1 = (r0, r1) if side > 0 else (-r1, -r0)
            m.block("Bowl", "Tunnel", tx - 4, tx + 4, 0.3, low_top(8) + 0.3, z0, z1, "dark", **NO_HIT)
            f0, f1 = (r0 - 0.06, r1 + 0.06) if side > 0 else (-r1 - 0.06, -r0 + 0.06)
            for fx in (tx - 4.6, tx + 4):
                m.block("Bowl", "TunnelFrame", fx, fx + 0.6, 0.3, low_top(8) + 0.9, f0, f1, "wall", **NO_HIT)
    # Glass dividers either side of the away end.
    for sign in (-1, 1):
        a = sign * (AWAY_A + BUFFER_A) / 2
        for r0, r1, height in ((LOW0, CONC_R, 29), (UP0, BACK_R, 56)):
            mid = (r0 + r1) / 2
            n = (-math.sin(a), math.cos(a))
            t = (math.cos(a), math.sin(a))
            m.part("Bowl", "AwayGlass", (r1 - r0, height, 0.3), (L + mid * math.cos(a), height / 2, mid * math.sin(a)),
                   "glass", frame(t, n), Transparency=0.6, **NO_HIT)
            m.part("Bowl", "AwayRail", (r1 - r0, 0.6, 0.5), (L + mid * math.cos(a), height + 0.3, mid * math.sin(a)),
                   "away", frame(t, n), **NO_HIT)


# ---- the crowd ---------------------------------------------------------------------------------

def build_crowd(m):
    fan_id = 0
    waver_id = 0
    wavers = []
    rows = rows_list()
    for row in rows:
        Rf = row["r"] + 1.0
        P = perim(Rf)
        count = int(P / 2.6)
        front = (row["tier"] == 0 and row["i"] <= 1) or (row["tier"] == 1 and row["i"] == 0)
        for j in range(count):
            x, z, n, t = oval_at(Rf, P * j / count)
            where = region(x, z)
            if where in ("buffer", "choreo") or in_tunnel(row, x, z) or near_aisle(x, z, Rf):
                continue
            if where == "away":
                if j % 3:
                    continue
            elif not front or rng.random() > 0.9:
                continue
            fan_id += 1
            shirt = rng.choice(art.AWAY_SHIRTS if where == "away" else art.HOME_SHIRTS)
            skin = rng.choice(art.SKIN)
            if rng.random() < 0.1:
                skin = art.WHITE if where == "away" else rng.choice([art.YEL, art.RED])
            attrs = {"FanId": fan_id, "FanF": round(j / count, 4)}
            rows_ = frame(t, n)
            y = row["top"]
            m.part("Crowd", "Fan", (1.5, 3.1, 0.9), (x, y + 1.55, z), shirt, rows_, attributes=attrs, **NO_HIT)
            m.part("Crowd", "FanHead", (1.15, 1.15, 1.15), (x, y + 3.675, z), skin, rows_, attributes=attrs, **NO_HIT)
            if y + 13 < 59 and rng.random() < (0.1 if where == "away" else 0.07) and all(
                    math.hypot(x - wx, z - wz) > 9 or abs(y - wy) > 6 for wx, wy, wz in wavers):
                wavers.append((x, y, z))
                waver_id += 1
                pivot = (x - n[0] * 0.1, y + 2.6, z - n[1] * 0.1)
                wattrs = {"Waver": waver_id, "WaverPivot": v3(pivot), "WaverAxis": v3((n[0], 0, n[1]))}
                image = "stadium_flag_away" if where == "away" else "stadium_flag_home"
                top = (pivot[0], pivot[1] + 10, pivot[2])
                rod(m, "Crowd", "FlagPole", pivot, top, 0.28, "pole", attributes=wattrs, **NO_HIT)
                # The flag hangs off the pole's top, out to one side (its own local -X), flat to the pitch.
                fx, fz = pivot[0] - t[0] * 3.9 * -1, pivot[2] - t[1] * 3.9 * -1
                m.part("Crowd", "Flag", (7.6, 4.8, 0.12), (fx, pivot[1] + 7.5, fz), "yellow" if where != "away" else "away",
                       rows_, attributes=wattrs, children=[decal("Front", image), decal("Back", image)], **NO_HIT)
    # Crowd pictures on every terrace without 3D fans (and behind the away end's), bobbing.
    for row in rows:
        front = (row["tier"] == 0 and row["i"] <= 1) or (row["tier"] == 1 and row["i"] == 0)
        for p in oval_pieces(row["r"], row["r"] + ROW):
            where = piece_region(p)
            if where in ("choreo", "buffer"):
                continue
            if front and where == "home":
                continue
            Rc = row["r"] + (2.2 if where == "away" else 1.2)
            image = "stadium_crowd_away" if where == "away" else "stadium_crowd_home"
            spans = []
            if p["angle"] is None:
                breaks = [-L, -64.6, -55.4, -41.4, -38.6, -24.6, -15.4, -1.4, 1.4, 15.4, 24.6, 38.6, 41.4, 55.4, 64.6, L]
                for a, b in zip(breaks, breaks[1:]):
                    mid = (a + b) / 2
                    if any(abs(mid - ax) < 1.5 for ax in AISLES_X):
                        continue
                    if row["tier"] == 0 and 5 <= row["i"] <= 8 and any(abs(mid - tx) < 4.7 for tx in TUNNELS):
                        continue
                    spans.append((a, b))
                sign = -1 if p["n"][1] > 0 else 1
                for a, b in spans:
                    x = (a + b) / 2
                    m.part("Crowd", "CrowdCard", (b - a, 5, 0.2), (x, row["top"] + 2.1, sign * Rc), "white",
                           frame(p["t"], p["n"]), Transparency=1, attributes={"CrowdBob": round(rng.random(), 3)},
                           children=[tex("Front", image, 26, 5)], **NO_HIT)
            else:
                cx = L if p["end"] == "E" else -L
                a = p["angle"]
                if near_aisle(cx + Rc * math.cos(a), Rc * math.sin(a), Rc, gap=2.6):
                    continue
                w = 2 * Rc * math.tan(math.pi / SEGS / 2) + 0.04
                m.part("Crowd", "CrowdCard", (w, 5, 0.2), (cx + Rc * math.cos(a), row["top"] + 2.1, Rc * math.sin(a)),
                       "white", frame(p["t"], p["n"]), Transparency=1, attributes={"CrowdBob": round(rng.random(), 3)},
                       children=[tex("Front", image, 26, 5)], **NO_HIT)
    return fan_id, waver_id


def build_choreo(m):
    """The west end's card display: a panel per terrace piece, four cards across, flipping between
    two pictures (client/StadiumWorld)."""
    rows = rows_list()
    pieces = [p for p in oval_pieces(LOW0, LOW0 + ROW) if piece_region(p) == "choreo"]
    cols = len(pieces) * 4
    pic_a, pic_b = art.choreo_pictures(cols, len(rows))
    a_min = min(p["angle"] for p in pieces) - math.pi / SEGS / 2
    a_max = max(p["angle"] for p in pieces) + math.pi / SEGS / 2
    for row in rows:
        y = len(rows) - 1 - row["gi"]
        for p in oval_pieces(row["r"], row["r"] + ROW):
            if piece_region(p) != "choreo":
                continue
            Rc = row["r"] + 1.2
            a = p["angle"]
            # Columns run the way round the oval (s): the west end goes from +Z round to -Z.
            k = pieces.index(next(q for q in pieces if abs(q["angle"] - a) < 1e-6))
            cards_a, cards_b, frames = [], [], []
            for c in range(4):
                col = k * 4 + c
                ca, cb = pic_a[y][col], pic_b[y][col]
                cards_a.append(",".join(str(v) for v in ca))
                cards_b.append(",".join(str(v) for v in cb))
                frames.append({"name": f"Card{c + 1}", "className": "Frame", "properties": {
                    "Size": {"UDim2": [[0.25, -2], [1, -2]]}, "Position": {"UDim2": [[c * 0.25, 1], [0, 1]]},
                    "BackgroundColor3": [round(v / 255, 3) for v in ca], "BorderSizePixel": 0}})
            gui = {"name": "Cards", "className": "SurfaceGui", "properties": {
                "Face": "Front", "SizingMode": "PixelsPerStud", "PixelsPerStud": 6, "LightInfluence": 0.6},
                "children": frames}
            u = (a - a_min) / (a_max - a_min)
            w = 2 * Rc * math.tan(math.pi / SEGS / 2) + 0.04
            m.part("Choreo", "ChoreoPanel", (w, 5, 0.2), (-L + Rc * math.cos(a), row["top"] + 2.1, Rc * math.sin(a)),
                   "dark", frame(p["t"], p["n"]), children=[gui],
                   attributes={"ChoreoA": "|".join(cards_a), "ChoreoB": "|".join(cards_b), "ChoreoU": round(u, 3)},
                   **NO_HIT)
    return cols


def build_flares(m):
    """Smoke flares round both tiers, lit in groups (client/StadiumWorld): home ones red and yellow,
    the away end's blue and white. Each blows its smoke out towards the pitch."""
    rows = rows_list()
    placed = []

    def place(where_wanted, count, colors, groups):
        tries = 0
        made = 0
        while made < count and tries < 3000:
            tries += 1
            row = rng.choice(rows)
            R = row["r"] + 0.25
            x, z, n, t = oval_at(R, rng.random() * perim(R))
            if region(x, z) != where_wanted or in_tunnel(row, x, z) or near_aisle(x, z, R):
                continue
            if any(math.hypot(x - px, z - pz) < 14 for px, pz in placed):
                continue
            placed.append((x, z))
            d = 0
            while d < 200:
                if abs(x + n[0] * d) < PX + 3 and abs(z + n[1] * d) < PZ + 3:
                    break
                d += 1
            travel = min(130, max(20, d - 3))
            drag, life = 0.35, 5.5
            speed = travel * drag / (1 - math.exp(-drag * life))
            color = colors[made % 2]
            smoke = m.particles("Smoke", 7, (life - 0.5, life + 0.5), (speed * 0.9, speed * 1.05),
                                [(0, 3), (0.4, 10), (1, 17)], [(0, 0.2), (0.7, 0.55), (1, 1)], color,
                                direction="Front", spread=(14, 8), accel=(0, 1.6, 0))
            smoke["properties"]["Drag"] = drag
            smoke["properties"]["Enabled"] = False
            m.part("Flares", "Flare", (0.4, 1.4, 0.4), (x, row["top"] + 0.7, z), color, frame(t, n),
                   children=[smoke], attributes={"FlareGroup": groups[made % len(groups)]}, **NO_HIT)
            made += 1
        return made

    home = place("home", 34, (art.RED, art.YEL), (1, 2, 3, 4, 5))
    away = place("away", 7, ((47, 111, 224), (242, 246, 255)), (6,))
    return home, away


def build_roof_flags(m):
    R = BACK_R + 4
    P = perim(R)
    count = round(P / 40)
    for k in range(count):
        x, z, n, t = oval_at(R, P * k / count)
        away = region(x, z) == "away"
        image = "stadium_flag_away" if away else "stadium_flag_home"
        cyl_y(m, "Crowd", "RoofPole", x, 63.6, 90, z, 0.64, "pole", **NO_HIT)
        # The flag flies out along local +X (= -t) from the pole.
        fx, fz = x - t[0] * 7.7, z - t[1] * 7.7
        m.part("Crowd", "RoofFlag", (15, 9.4, 0.2), (fx, 84.8, fz), "away" if away else "yellow", frame(t, n),
               attributes={"RoofFlag": v3((x, 84.8, z))}, children=[decal("Front", image), decal("Back", image)],
               **NO_HIT)


def build_scoreboards(m):
    for s in (-1, 1):
        x = s * 224
        face = "Left" if s > 0 else "Right"
        m.block("Bowl", "BoardBase", x - 2, x + 2, 63.6, 65.2, -76, 76, "board", **NO_HIT)
        for z in (-50, 0, 50):
            cyl_y(m, "Bowl", "BoardStrut", x + s * 2.2, 63.6, 92, z, 1.4, "post", **NO_HIT)
        m.block("Bowl", "Scoreboard", x - 1.5, x + 1.5, 65, 99.4, -75, 75, "board", children=[scoreboard_gui(face)], **NO_HIT)


def scoreboard_gui(face):
    def frame_(name, pos, size, color):
        return {"name": name, "className": "Frame", "properties": {
            "Position": {"UDim2": [[pos[0], 0], [pos[1], 0]]}, "Size": {"UDim2": [[size[0], 0], [size[1], 0]]},
            "BackgroundColor3": [round(c / 255, 3) for c in color], "BorderSizePixel": 0}}

    def label(name, text, pos, size, color, font="Bangers"):
        return {"name": name, "className": "TextLabel", "properties": {
            "Position": {"UDim2": [[pos[0], 0], [pos[1], 0]]}, "Size": {"UDim2": [[size[0], 0], [size[1], 0]]},
            "BackgroundTransparency": 1, "Text": text, "TextScaled": True, "Font": font,
            "TextColor3": [round(c / 255, 3) for c in color]}}

    def image(name, picture, pos, size):
        return {"name": name, "className": "ImageLabel", "properties": {
            "Position": {"UDim2": [[pos[0], 0], [pos[1], 0]]}, "Size": {"UDim2": [[size[0], 0], [size[1], 0]]},
            "BackgroundTransparency": 1, "Image": "", "ScaleType": "Fit"}, "attributes": {"Image": picture}}

    kids = [
        frame_("Back", (0, 0), (1, 1), (5, 8, 14)),
        frame_("HomeEnd", (0, 0), (0.1, 1), art.YEL),
        frame_("AwayEnd", (0.9, 0), (0.1, 1), art.RED),
        image("HomeCrest", "stadium_crest_home", (0.135, 0.06), (0.17, 0.7)),
        image("AwayCrest", "stadium_crest_away", (0.695, 0.06), (0.17, 0.7)),
        label("HomeName", "TAGGERS", (0.12, 0.78), (0.2, 0.18), art.YEL),
        label("AwayName", "RUNNERS", (0.68, 0.78), (0.2, 0.18), art.AWAY_LT),
        label("HomeLabel", "HOME", (0.34, 0.05), (0.12, 0.12), (201, 211, 224), "GothamBold"),
        label("AwayLabel", "AWAY", (0.54, 0.05), (0.12, 0.12), (201, 211, 224), "GothamBold"),
        label("Score", "0 : 0", (0.33, 0.16), (0.34, 0.56), (255, 178, 26), "GothamBlack"),
        frame_("ClockBack", (0.4, 0.74), (0.2, 0.2), (26, 6, 6)),
        label("Clock", "00:00", (0.41, 0.75), (0.18, 0.18), (255, 74, 61), "Code"),
    ]
    return {"name": "Board", "className": "SurfaceGui", "properties": {
        "Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": 8, "LightInfluence": 0},
        "children": kids}


# ---- checks ------------------------------------------------------------------------------------

def floating(m, ground=-0.95, gap=0.06):
    """Every part must touch (or overlap) another part, in a chain that reaches the ground (a part
    whose bottom is at or under `ground`). Returns the parts that don't, by name."""
    nodes = [n for group in m.groups.values() for n in group]
    parts = mapcheck.parts_from_nodes(nodes)
    boxes = []
    for p in parts:
        ext = [sum(abs(p.axis(j)[i]) * p.half[j] for j in range(3)) for i in range(3)]
        boxes.append(([p.pos[i] - ext[i] for i in range(3)], [p.pos[i] + ext[i] for i in range(3)]))
    cell = 24.0
    grid = {}
    for i, (lo, hi) in enumerate(boxes):
        for gx in range(int(math.floor(lo[0] / cell)), int(math.floor(hi[0] / cell)) + 1):
            for gz in range(int(math.floor(lo[2] / cell)), int(math.floor(hi[2] / cell)) + 1):
                grid.setdefault((gx, gz), []).append(i)
    parent = list(range(len(parts)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    seen = set()
    for members in grid.values():
        for ai in range(len(members)):
            a = members[ai]
            for b in members[ai + 1:]:
                if (a, b) in seen:
                    continue
                seen.add((a, b))
                la, ha = boxes[a]
                lb, hb = boxes[b]
                if any(la[k] > hb[k] + gap or lb[k] > ha[k] + gap for k in range(3)):
                    continue
                if find(a) == find(b):
                    continue
                if mapcheck._obb_overlap(parts[a], parts[b], grow_a=(gap, gap, gap), shrink=0):
                    parent[find(a)] = find(b)
    grounded = {find(i) for i, (lo, _) in enumerate(boxes) if lo[1] <= ground}
    loose = {}
    for i, p in enumerate(parts):
        if find(i) not in grounded:
            loose.setdefault(p.name, []).append(tuple(round(c, 1) for c in p.pos))
    return loose


def check(m):
    problems = mapcheck.check_map(m, ATTRIBUTES)
    nodes = [n for group in m.groups.values() for n in group]
    reach = mapcheck.Reach(mapcheck.parts_from_nodes(nodes), [(x, y + 0.5, z) for x, y, z in m.spawns])
    reach.build()
    for x, z in SPRINKLERS:
        d = (-x, -z)
        length = math.hypot(*d)
        vx, vz = d[0] / length * LAUNCH_ACROSS, d[1] / length * LAUNCH_ACROSS
        landing = reach.fly(x, PAD_Y + 0.2 + mapcheck.ROOT, z, vx, LAUNCH_UP, vz)
        where = reach.nodes[landing][:3] if landing is not None else None
        far = (-x, -z)
        short = math.hypot(where[0] - far[0], where[1] - far[1]) if where else None
        print(f"sprinkler at {(x, z)}: lands at {where}, {short and round(short)} short of the far one")
        if where is None or short < PAD_R + 20:
            problems.append(f"sprinkler at {(x, z)} lands at {where}: too close to the far sprinkler or nowhere")
    loose = floating(m)
    for name, spots in sorted(loose.items()):
        problems.append(f"floating: {len(spots)} x {name}, e.g. at {spots[:3]}")
    return problems


def build():
    m = Map(colors=COLORS, materials=MATERIALS)
    build_ground(m)
    build_lines(m)
    build_chunks(m)
    build_goals(m)
    build_screens(m)
    build_sprinklers(m)
    build_benches(m)
    build_balls(m)
    build_bowl(m)
    fans, wavers = build_crowd(m)
    cols = build_choreo(m)
    home, away = build_flares(m)
    build_roof_flags(m)
    build_scoreboards(m)
    for x, z in SPAWNS:
        m.spawn(x, z, 0)
    print(f"{fans} fans ({wavers} with flags), choreography {cols} cards across, flares {home} home + {away} away")
    return m


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    balls = [f"Ball{i}" for i in range(1, 6)]
    layout.write(OUT, ATTRIBUTES, models=["Chunks"] + balls)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
