#!/usr/bin/env python3
"""Canyon Express (4-8 players): two huge freight trains side by side through a winding sandstone
canyon at dusk, from the owner's reference picture. Run from the repo root:
    python3 tools/canyon_layout.py
It rewrites `src/maps/CanyonExpress/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X along the track (the locomotives lead towards +X), Z across, Y up. Everything is 2x the
character's scale (so you feel small): cars 64 long, 24 wide, decks at 10, roofs at 28. The jumps
stay human: the gap between the trains runs 4..22 and couplings are 4.
The numbers in this file are design units; `build` shrinks the finished map by SCALE, so set SCALE to
resize it (and keep the Config.ScrollWorld distances in step). Ladders go in after, at true size.
THE TRAINS DON'T MOVE: the world slides past them (shared/ScrollLine, client/ScrollWorld). Train A
(z -24..0) never moves; Train B (z 13..37 as built) drifts along and in and out, carrying whoever is
on it. Falling off is out (KillHeight, FallEliminates); the ground is really there under the trains.
Moving folders (Persistent models): Scroll<n> (one CHUNK each, built end to end from x 0), TrackB<n>
(Train B's rails, which follow its gap), TrainB, and Obstacle_<Kind>_<n>, which wait far along +X.
Each chunk or obstacle is moved whole round its own middle, and bends with the track ahead of and
behind the trains (ScrollLine.warp), so the line winds out of sight. Signs and signals face -X, the
way the trains come from. Parts with ObstacleHit knock you back.
"""
import math
import sys

sys.path.insert(0, "tools")
import mapcheck  # noqa: E402
from maplib import IDENTITY, NO_HIT, Map, matmul, rot_x, rot_y, rot_z  # noqa: E402
from mine_layout import STRATA, WOOD, beam, jitter, rng, rock_rows, simple_materials  # noqa: E402

OUT = "src/maps/CanyonExpress"
ATTRIBUTES = {"DisplayName": "Canyon Express", "MinPlayers": 4, "MaxPlayers": 8, "InRotation": True,
              "Lighting": "Dusk", "KillHeight": 4, "FallEliminates": True, "ScrollWorld": True,
              "OutOfBounds": "CabTop,CabTopTop,NoseTop,NoseTopTop,BigCargo,RoofVent"}

SCALE = 0.5                                # 2x the character, from a design drawn at 4x
CAR, COUPLE, W, DECK, ROOF = 128, 8, 48, 20, 56
A_Z = (-W, 0)
B_Z = (13 / SCALE, 13 / SCALE + W)         # the real gap at its middle is 13
ZA, ZB = sum(A_Z) / 2, sum(B_Z) / 2       # the two track centres
CLEAR = ROOF + 4.4 / SCALE                 # low beams leave a real 4.4 over the roofs
CHUNK, CHUNKS = 240, 16                    # CHUNK * SCALE = Config.ScrollWorld.ChunkLength
BUILT_AT = -12000 / SCALE                  # chunks wait here (Config.ScrollWorld.BuiltAt), far from the lobby
PARK = 2000                                # PARK * SCALE = Config.ScrollWorld.ParkStep
POOLS = {"Gantry": 5, "Tunnel": 3, "TunnelB": 3, "SignA": 3, "SignB": 3}
RAIL_TOP, WHEEL = 3.0, 12.0
SPAWNS = ((300, -24, ROOF), (150, -24, ROOF), (70, -14, DECK), (-60, -24, ROOF), (-190, -24, ROOF), (-330, -6, DECK),
          (-230, -38, ROOF), (210, -40, ROOF))
WALL_N, WALL_S = -170, 232                 # the canyon's inner faces
HALF_G = 400                               # the ground's half-width beyond the walls

STEEL, DARK = (86, 89, 95), (47, 50, 54)
CREAM, ORANGE, GREEN = (226, 214, 188), (214, 122, 54), (70, 104, 78)
TERRACES = ((196, 134, 82), (208, 150, 96), (186, 122, 74), (218, 164, 112), (176, 112, 70))
COLORS = {"deck": (86, 89, 95), "crate": (180, 138, 85)}
MATERIALS = {"deck": "DiamondPlate"}


def car_x(i):
    return (6 * CAR + 5 * COUPLE) / 2 - CAR / 2 - i * (CAR + COUPLE)


def block(m, g, name, a0, a1, b0, b1, c0, c1, color, material="SmoothPlastic", solid=False, **props):
    extra = {} if solid else dict(NO_HIT)
    extra.update(props)
    return m.block(g, name, a0, a1, b0, b1, c0, c1, color, Material=material, **extra)


def cyl_x(m, g, name, x0, x1, y, z, dia, color, material="SmoothPlastic"):
    """A cylinder lying along X."""
    m.cylinder(g, name, x1 - x0, dia, ((x0 + x1) / 2, y, z), color, IDENTITY, Material=material, **NO_HIT)


def cyl_z(m, g, name, z0, z1, x, y, dia, color, material="SmoothPlastic"):
    """A cylinder lying along Z (wheels and axles)."""
    m.cylinder(g, name, z1 - z0, dia, (x, y, (z0 + z1) / 2), color, rot_y(90), Material=material, **NO_HIT)


def cyl_y(m, g, name, y0, y1, x, z, dia, color, material="SmoothPlastic"):
    m.cylinder(g, name, y1 - y0, dia, (x, (y0 + y1) / 2, z), color, Material=material, **NO_HIT)


def rounded(m, g, name, x0, x1, y0, y1, z0, z1, r, color, solid=True):
    """A body with its top edges rounded: a box, a narrower box on it, and a cylinder along each
    top corner (a hair small, so no faces coincide)."""
    block(m, g, name, x0, x1, y0, y1 - r, z0, z1, color, solid=solid)
    block(m, g, name + "Top", x0, x1, y1 - r, y1, z0 + r, z1 - r, color, solid=solid)
    for z in (z0 + r, z1 - r):
        cyl_x(m, g, "EdgeRound", x0 + 0.14, x1 - 0.14, y1 - r, z, 2 * r - 0.2, color)


def rail_guard(m, g, x0, x1, z, y0, height, color):
    """Handrail on a walkway: posts and rails, with an invisible guard as tall."""
    block(m, g, "RailGuard", x0, x1, y0, y0 + height, z - 0.2, z + 0.2, DARK, solid=True, Transparency=1, CastShadow=False)
    cyl_x(m, g, "HandRail", x0, x1, y0 + height, z, 0.8, color, "Metal")
    cyl_x(m, g, "HandRail", x0, x1, y0 + height * 0.55, z, 0.5, color, "Metal")
    n = max(1, round((x1 - x0) / 12))
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / n
        cyl_y(m, g, "RailPost", y0, y0 + height - 0.2, x + 0.3, z, 0.6, color, "Metal")


def bogies(m, g, x0, x1, z0, z1):
    """Sprung trucks that really sit on the rails, under a frame that really sits on them."""
    w_y = RAIL_TOP + WHEEL / 2
    zm = (z0 + z1) / 2
    for bx in (x0 + 26, x1 - 26):
        block(m, g, "TruckBeam", bx - 3, bx + 3, 10, 13, z0 + 4, z1 - 4, DARK, "Metal")
        for ax in (bx - 11, bx + 11):
            for z, s in ((zm - 12.4, -1), (zm + 12.4, 1)):
                cyl_z(m, g, "Wheel", z - 1.3, z + 1.3, ax, w_y, WHEEL, (52, 54, 58), "Metal")
                a, b = sorted((z + s * 1.3, z + s * 1.7))
                cyl_z(m, g, "Hub", a, b, ax, w_y, 5, (118, 122, 128), "Metal")
        for s in (-1, 1):
            z = zm + s * 15.5
            block(m, g, "TruckFrame", bx - 17, bx + 17, 9.5, 11.5, z - 0.8, z + 0.8, (58, 60, 64), "Metal")
    # The frame the deck sits on, resting on the springs and truck beams.
    block(m, g, "CarFrame", x0 + 2, x1 - 2, 13, 16, z0 + 3, z1 - 3, (58, 60, 64), "Metal")
    # A coupling reaching towards the next car.
    block(m, g, "Coupler", x0 - 3.9, x0 + 2.2, 13.4, 15.6, zm - 1.6, zm + 1.6, (72, 74, 80), "Metal")
    block(m, g, "Coupler", x1 - 2.2, x1 + 3.9, 13.45, 15.55, zm - 1.5, zm + 1.5, (78, 80, 86), "Metal")


def flat_deck(m, g, x0, x1, z0, z1, color="deck"):
    block(m, g, "Deck", x0, x1, 16, DECK, z0, z1, color, "DiamondPlate" if color == "deck" else "SmoothPlastic", solid=True)
    for z, s in ((z0, -1), (z1, 1)):
        a, b = sorted((z, z + s * 0.5))
        block(m, g, "SideSill", x0 + 0.5, x1 - 0.5, 16.6, 19.4, a, b, (64, 66, 72), "Metal")


def container(m, g, x0, x1, z0, z1, color, text=None):
    y0, y1 = DECK, ROOF
    block(m, g, "Container", x0, x1, y0, y1, z0, z1, color, solid=True)
    pale = tuple(min(255, c + 14) for c in color)
    dark = tuple(max(0, c - 40) for c in color)
    x = x0 + 4
    while x < x1 - 3:
        for z, s in ((z0, -1), (z1, 1)):
            a, b = sorted((z, z + s * 0.5))
            block(m, g, "Rib", x - 0.9, x + 0.9, y0 + 2, y1 - 2.2, a, b, pale)
        x += 5.6
    for z, s in ((z0, -1), (z1, 1)):  # top and bottom rails along the sides
        a, b = sorted((z, z + s * 0.75))
        block(m, g, "ContRail", x0 + 2.4, x1 - 2.4, y1 - 2, y1 - 0.3, a, b, dark)
        block(m, g, "ContRail", x0 + 2.4, x1 - 2.4, y0 + 0.2, y0 + 1.9, a, b, dark)
    for x, s in ((x0, -1), (x1, 1)):  # the end doors, with locking bars
        zm = (z0 + z1) / 2
        a, b = sorted((x, x + s * 0.35))
        for za, zb in ((z0 + 2.2, zm - 10), (zm + 10, z1 - 2.2)):  # (a clear strip up the middle, for ladders)
            block(m, g, "DoorPanel", a, b, y0 + 2, y1 - 2.2, za, zb, pale)
        a2, b2 = sorted((x, x + s * 0.8))
        for z in (zm - 18, zm - 13, zm + 13, zm + 18):
            block(m, g, "DoorBar", a2, b2, y0 + 1.6, y1 - 1.8, z - 0.35, z + 0.35, (160, 160, 162), "Metal")
    for x in (x0 - 0.6, x1 - 2):
        for z in (z0 - 0.9, z1 - 1.9):
            block(m, g, "CornerPost", x, x + 2.6, y0 + 0.06, y1 + 0.5, z, z + 2.8, dark)
    # Three shallow corrugations on the roof, low enough not to trip anyone.
    x = x0 + 8
    while x < x1 - 6:
        block(m, g, "RoofRib", x - 2, x + 2, y1 + 0.03, y1 + 0.1, z0 + 3, z1 - 3, pale)
        x += 12
    if text:
        for z, s, face in ((z0, -1, "Front"), (z1, 1, "Back")):
            a, b = sorted((z + s * 0.55, z + s * 0.62))
            xm = (x0 + x1) / 2
            node = block(m, g, "ContainerName", xm - 15, xm + 15, y0 + 12, y0 + 24, a, b, dark, Transparency=1, CastShadow=False)
            node["children"] = [m.surface_text(face, text, (240, 240, 236), pps=16)]


def locomotive_a(m, g, x0, x1, z0, z1):
    """The white locomotive with grey slanted stripes and a dark green plough."""
    white, grey = (232, 228, 216), (120, 126, 134)
    loco_common(m, g, x0, x1, z0, z1, white, white, (196, 60, 46))
    nose0, nose1 = z0 + 6, z1 - 6
    # Slanted grey stripes down the nose's sides and front, as in the picture.
    for k in range(4):
        x = x1 - 26 + k * 6.4
        for z, s in ((nose0, -1), (nose1, 1)):
            m.part(g, "NoseStripe", (3.4, 22, 0.3), (x, DECK + 12, z + s * 0.2), grey, rot_z(26), **NO_HIT)
    for k in range(4):
        z = (z0 + z1) / 2 - 12 + k * 8
        m.part(g, "NoseStripe", (0.3, 22, 3.6), (x1 - 3.8, DECK + 12, z), grey, rot_x(24), **NO_HIT)
    # The corrugated green plough at the front, resting on the frame.
    zm = (z0 + z1) / 2
    m.part(g, "Pilot", (5, 15, W - 4), (x1 + 1.4, 9.5, zm), (54, 86, 72), rot_z(-14), **NO_HIT)
    for k in range(10):
        z = zm - 20 + k * 4.4
        m.part(g, "PilotRib", (0.9, 15, 1.6), (x1 + 4.05, 9.6, z), (40, 66, 56), rot_z(-14), **NO_HIT)


def locomotive_b(m, g, x0, x1, z0, z1):
    """The red-and-white locomotive."""
    white, red = (234, 228, 216), (184, 56, 47)
    loco_common(m, g, x0, x1, z0, z1, red, white, (196, 60, 46))
    zm = (z0 + z1) / 2
    # Red plough, and a white chevron band round the nose.
    m.part(g, "Pilot", (5, 15, W - 4), (x1 + 1.4, 9.5, zm), (166, 44, 38), rot_z(-14), **NO_HIT)
    for s, z in ((-1, z0 + 6), (1, z1 - 6)):
        a, b = sorted((z, z + s * 0.3))
        block(m, g, "NoseBand", x1 - 26, x1 - 6.2, DECK + 12, DECK + 16, a, b, white)
    block(m, g, "NoseBand", x1 - 5.9, x1 - 5.6, DECK + 12, DECK + 16, z0 + 6.2, z1 - 6.2, white)
    m.part(g, "LocoName", (0.4, 7, 20), (x1 - 5.7, DECK + 5.5, zm), (168, 44, 38), Transparency=1, CastShadow=False, **NO_HIT,
           children=[m.surface_text("Right", "UT-1", (240, 234, 220), pps=18)])


def loco_common(m, g, x0, x1, z0, z1, body, upper, rail):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    zm = (z0 + z1) / 2
    hood0, hood1 = zm - 15, zm + 15
    hx0, hx1 = x0 + 10, x1 - 46
    cx0, cx1 = hx1, x1 - 26
    n0, n1 = x1 - 26, x1 - 6
    rounded(m, g, "Hood", hx0, hx1, DECK, ROOF, hood0, hood1, 4, body)
    rounded(m, g, "CabTop", cx0, cx1, DECK, ROOF + 8, z0 + 4, z1 - 4, 5, upper)
    rounded(m, g, "NoseTop", n0, n1, DECK, ROOF - 12, z0 + 6, z1 - 6, 5, body)
    # A sill between the deck and the hood, and panel lines along it.
    for z, s in ((hood0, -1), (hood1, 1)):
        a, b = sorted((z, z + s * 0.3))
        block(m, g, "HoodBand", hx0 + 1, hx1 - 1, DECK + 11, DECK + 15, a, b, upper)
        a2, b2 = sorted((z, z + s * 0.5))
        x = hx0 + 3
        while x < hx1 - 7:
            block(m, g, "HoodDoor", x, x + 7, DECK + 17, ROOF - 7, a2, b2, tuple(max(0, c - 22) for c in body))
            x += 11
        block(m, g, "HoodName", hx0 + 18, hx0 + 42, DECK + 3, DECK + 9.5, a2, b2, body, Transparency=1, CastShadow=False,
              children=[m.surface_text("Front" if s < 0 else "Back", "ULTIMATE", (240, 236, 224), pps=14)])
    # Roof fans in round housings.
    x = hx0 + 12
    while x < hx1 - 8:
        cyl_y(m, g, "FanRing", ROOF + 0.03, ROOF + 1.4, x, zm, 16, (92, 96, 104), "Metal")
        cyl_y(m, g, "FanGrille", ROOF + 1.45, ROOF + 1.7, x, zm, 13, (40, 42, 46), "Metal")
        x += 28
    cyl_y(m, g, "RoofVent", ROOF, ROOF + 8, hx0 + 4, zm - 10, 3.4, (46, 48, 52), "Metal")
    cyl_y(m, g, "RoofVent", ROOF, ROOF + 8, hx0 + 4, zm + 10, 3.4, (46, 48, 52), "Metal")
    # Cab windows on all sides, framed.
    glass = (150, 186, 208)
    for z, s, in ((z0 + 4, -1), (z1 - 4, 1)):
        a, b = sorted((z, z + s * 0.25))
        block(m, g, "CabGlass", cx0 + 2.5, cx1 - 2.5, ROOF - 9, ROOF + 1, a, b, glass, Reflectance=0.25)
        a, b = sorted((z, z + s * 0.45))
        block(m, g, "CabFrame", cx0 + 1.5, cx1 - 1.5, ROOF - 10, ROOF - 9, a, b, DARK)
        block(m, g, "CabFrame", cx0 + 1.5, cx1 - 1.5, ROOF + 1, ROOF + 2, a, b, DARK)
        xm = (cx0 + cx1) / 2
        a4, b4 = sorted((z, z + s * 0.6))
        block(m, g, "CabFrame", xm - 0.6, xm + 0.6, ROOF - 10.1, ROOF + 2.1, a4, b4, DARK)
    for za, zb in ((z0 + 7, zm - 1), (zm + 1, z1 - 7)):
        block(m, g, "CabGlass", cx1 + 0.02, cx1 + 0.3, ROOF - 9, ROOF + 2, za, zb, glass, Reflectance=0.25)
    # Round headlights in deep rims, a light beam ahead, and a horn on the cab.
    for s in (-1, 1):
        z = zm + s * 8
        cyl_x(m, g, "HeadRim", n1 + 0.02, n1 + 1.1, DECK + 24, z, 8, DARK, "Metal")
        cyl_x(m, g, "Headlight", n1 + 1.12, n1 + 1.5, DECK + 24, z, 6, (252, 234, 188))
        lamp = m.part(g, "HeadGlow", (0.5, 0.5, 0.5), (n1 + 1.7, DECK + 24, z), (252, 234, 188), Transparency=1, CastShadow=False, **NO_HIT)
        lamp["children"] = [{"name": "Beam", "className": "SpotLight", "properties": {
            "Brightness": 3, "Range": 60, "Angle": 50, "Face": "Right", "Color": m.rgb((255, 226, 176)), "Shadows": False}}]
    cyl_x(m, g, "Horn", cx0 + 4, cx0 + 12, ROOF + 10, zm - 5, 2.2, (178, 170, 110), "Metal")
    cyl_x(m, g, "Horn", cx0 + 5, cx0 + 11, ROOF + 10, zm + 5, 2.0, (178, 170, 110), "Metal")
    for x in (cx0 + 8,):
        cyl_y(m, g, "HornStem", ROOF + 8, ROOF + 10, x, zm, 1.2, (100, 100, 104), "Metal")
    block(m, g, "WarnLamp", cx1 - 7, cx1 - 2, ROOF + 8.03, ROOF + 9.4, zm - 2.5, zm + 2.5, (96, 92, 80), attributes={"WarnLamp": True})
    # Side walkways with handrails; steps down the side at each end.
    for z in (z0 + 1.2, z1 - 1.2):
        rail_guard(m, g, x0 + 10, x1 - 46.5, z, DECK, 7.4 / SCALE, rail)
    for z, s in ((z0, -1), (z1, 1)):
        for x in (x0 + 3, x1 - 44):
            for k in range(4):
                a, b = sorted((z + s * 0.2, z + s * 2.4))
                block(m, g, "Stirrup", x, x + 5, 4 + k * 3.6, 4.5 + k * 3.6, a, b, rail, "Metal")
            a, b = sorted((z + s * 0.1, z + s * 2.4))
            block(m, g, "StirrupSide", x - 0.3, x, 4, 16.6, a, b, rail, "Metal")
            block(m, g, "StirrupSide", x + 5, x + 5.3, 4, 16.6, a, b, rail, "Metal")


def coach(m, g, x0, x1, z0, z1, body, stripe):
    """A coach (the picture's cream and orange one), with a rounded roof, windows and a door."""
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    bx1 = x1 - 12  # a platform at the front end, for the ladder
    rounded(m, g, "Coach", x0 + 0.5, bx1, DECK, ROOF, z0, z1, 7, body)
    for z, s in ((z0, -1), (z1, 1)):
        a, b = sorted((z, z + s * 0.3))
        block(m, g, "CoachStripe", x0 + 5, bx1 - 1, DECK + 7, DECK + 11, a, b, stripe)
        block(m, g, "CoachStripe", x0 + 5, bx1 - 1, DECK + 2, DECK + 4.6, a, b, GREEN)
        x = x0 + 12
        k = 0
        while x < bx1 - 12:
            if k == 4:  # the door, in place of a window
                block(m, g, "CoachDoor", x, x + 11, DECK + 1, ROOF - 12, min(a, z + s * 0.5), max(b, z + s * 0.5), (168, 156, 134))
            else:
                a2, b2 = sorted((z, z + s * 0.5))
                block(m, g, "WinFrame", x, x + 11, DECK + 13, ROOF - 13, a2, b2, (150, 138, 118))
                a3, b3 = sorted((z, z + s * 0.75))
                block(m, g, "CoachPane", x + 1.1, x + 9.9, DECK + 14.1, ROOF - 14.1, a3, b3, (108, 150, 176), Reflectance=0.25)
            x += 14
            k += 1
    # Roof vents along the ridge.
    zm = (z0 + z1) / 2
    x = x0 + 16
    while x < bx1 - 8:
        cyl_y(m, g, "RoofVent", ROOF, ROOF + 2.2, x, zm, 4.4, (150, 152, 156), "Metal")
        x += 26
    block(m, g, "WarnLamp", (x0 + bx1) / 2 - 2, (x0 + bx1) / 2 + 2, ROOF + 0.05, ROOF + 1.5, zm + 12, zm + 16, (96, 92, 80), attributes={"WarnLamp": True})


def cargo_pile(m, g, x, z, color):
    """A stack you can climb: steps of 5, up to a big crate at 15."""
    for ox, oz, w, d, h, name in ((-16, 0, 5, 7, 5, "Crate"), (-7, 0, 3.9, 8, 10, "Crate"), (5.5, 0, 8.5, 11, 15, "Crate")):
        cx, cz = x + ox, z + oz
        block(m, g, name, cx - w, cx + w, DECK + 0.3, DECK + h, cz - d, cz + d, jitter(color, 8), solid=True)
        for s in (-1, 1):
            block(m, g, "CrateBand", cx + s * w * 0.55 - 0.5, cx + s * w * 0.55 + 0.5, DECK + 0.4, DECK + h + 0.14, cz - d - 0.2, cz + d + 0.2, (112, 84, 50))


def flatbed(m, g, x0, x1, z0, z1, piles):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    xp = x0 + 4.2
    while xp < x1 - 5:
        m.part(g, "DeckPlank", (7.6, 0.2, W - 1.5), (xp, DECK + 0.02, (z0 + z1) / 2), jitter(WOOD[2], 6), **NO_HIT)
        xp += 8
    zm = (z0 + z1) / 2
    for ox, oz, color in piles:
        cargo_pile(m, g, (x0 + x1) / 2 + ox, zm + oz, color)
    for x in (x0 + 8, x0 + 46, x0 + 84, x1 - 8):
        for z in (z0 + 0.6, z1 - 0.6):
            block(m, g, "Stake", x - 0.5, x + 0.5, DECK, DECK + 7, z - 0.5, z + 0.5, WOOD[1])


def containers(m, g, x0, x1, z0, z1, c1, c2, n1, n2):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    mid = (x0 + x1) / 2
    container(m, g, x0 + 4, mid - 2, z0 + 2, z1 - 2, c1, n1)
    container(m, g, mid + 2, x1 - 4, z0 + 2, z1 - 2, c2, n2)
    zm = (z0 + z1) / 2
    block(m, g, "WarnLamp", mid - 1.5, mid + 1.5, DECK + 0.02, DECK + 2, zm - 1.5, zm + 1.5, (96, 92, 80), attributes={"WarnLamp": True})


def build_train(m, g, zs, kinds):
    z0, z1 = zs
    for i, kind in enumerate(kinds):
        x = car_x(i)
        x0, x1 = x - CAR / 2, x + CAR / 2
        if kind[0] == "locoA":
            locomotive_a(m, g, x0, x1, z0, z1)
        elif kind[0] == "locoB":
            locomotive_b(m, g, x0, x1, z0, z1)
        elif kind[0] == "coach":
            coach(m, g, x0, x1, z0, z1, kind[1], kind[2])
        elif kind[0] == "cont":
            containers(m, g, x0, x1, z0, z1, kind[1], kind[2], kind[3], kind[4])
        else:
            flatbed(m, g, x0, x1, z0, z1, kind[1])


def build_trains(m):
    magenta, yellow, blue, orange, green, teal = (205, 58, 142), (226, 206, 56), (58, 104, 168), (218, 128, 54), (92, 136, 80), (70, 124, 130)
    p1 = ((-40, -8, (180, 138, 85)), (28, 6, (92, 128, 78)))
    p2 = ((-36, 6, (92, 128, 78)), (30, -6, (180, 138, 85)))
    kinds_a = (("locoA",), ("cont", magenta, yellow, "UTX", "UTX"), ("flat", p1), ("coach", CREAM, ORANGE), ("cont", blue, teal, "RUN", "UTX"), ("flat", p2))
    kinds_b = (("locoB",), ("flat", p2), ("cont", orange, blue, "UTX", "TAG"), ("cont", yellow, green, "UTX", "UTX"), ("flat", p1), ("coach", (218, 206, 182), (196, 60, 46)))
    build_train(m, "TrainA", A_Z, kinds_a)
    build_train(m, "TrainB", B_Z, kinds_b)
    # Sparks off Train B's wheels (the picture), real little trails on the rail.
    spark = m.particles("Sparks", 60, (0.25, 0.6), (40, 80), [(0, 1.0), (1, 0.2)], [(0, 0), (1, 1)], (255, 190, 90),
                        texture="rbxasset://textures/particles/sparkles_main.dds", direction="Left", spread=(22, 22), accel=(0, -160, 0), light=1)
    block(m, "TrainB", "SparkPoint", car_x(1) + 14, car_x(1) + 15, RAIL_TOP + 0.5, RAIL_TOP + 1.5, ZB - 13, ZB - 12, (0, 0, 0), Transparency=1, CastShadow=False,
          children=[spark])


def rock(m, g, name, size, pos, color, lean=8):
    m.part(g, name, size, pos, color, rock_rows(lean), Material="SmoothPlastic", **NO_HIT)


def cactus(m, g, x, z):
    h = rng.uniform(12, 22)
    green = jitter((104, 132, 78), 8)
    cyl_y(m, g, "Cactus", -1, h, x, z, 3, green)
    for s in (-1, 1):
        ay = h * rng.uniform(0.45, 0.7)
        beam(m, g, "CactusArm", (x, ay, z), (x + s * 5, ay, z), 2.2, 2.2, green, "SmoothPlastic")
        cyl_y(m, g, "Cactus", ay - 0.5, ay + rng.uniform(4, 8), x + s * 5, z, 2.2, green)


def track_chunk(m, g, x0, zc):
    """Ballast, sleepers and rails for one chunk of one track, sitting on the ground."""
    xa, xb = x0, x0 + CHUNK  # (exactly end to end, so rails line up with no overlap)
    block(m, g, "Ballast", xa, xb, -0.6, 1.2, zc - 30, zc + 30, jitter((140, 124, 106), 5))
    for s in (-1, 1):  # sloped ballast shoulders
        m.part(g, "BallastSide", (xb - xa - 0.4 - (0.3 if zc > 0 else 0), 1.0, 12), ((xa + xb) / 2, 0.15, zc + s * 34.5), (150, 134, 112), rot_x(s * 9), **NO_HIT)
    x = x0 + 8
    while x < x0 + CHUNK - 1:
        m.part(g, "Sleeper", (7, 1.6, 40), (x, 1.75, zc), jitter(WOOD[3], 8), rot_y(rng.uniform(-0.6, 0.6)), **NO_HIT)
        x += 22
    for s in (-12.4, 12.4):
        block(m, g, "RailFoot", xa, xb, 2.5, 2.55 + 0.25, zc + s - 1.3, zc + s + 1.3, (96, 96, 98), "Metal")
        block(m, g, "Rail", xa, xb, 2.8, RAIL_TOP + 1.0, zc + s - 0.7, zc + s + 0.7, (126, 130, 136), "Metal")


def terraced_wall(m, g, x0, z, out, seed_top):
    """A canyon wall: broad stepped terraces going up and back, each a few long segments."""
    y, back = 0.0, 0.0
    for tier, base in enumerate(TERRACES):
        h = rng.uniform(34, 56)
        x = x0 - 6
        while x < x0 + CHUNK + 4:
            w = min(rng.uniform(70, 110), x0 + CHUNK + 6 - x)
            d = rng.uniform(70, 110)
            jog = rng.uniform(-9, 9)
            face = z + out * (back + jog)
            zc = face + out * d / 2
            color = jitter(base, 4)
            # (each a hair tilted, so no two segments' tops share a plane)
            yaw = matmul(rot_y(rng.uniform(-1.8, 1.8)), matmul(rot_x(rng.uniform(0.2, 0.6)), rot_z(rng.uniform(0.2, 0.6))))
            m.part(g, "Terrace", (w + 3, h, d), (x + w / 2, y + h / 2, zc), color, yaw, **NO_HIT)
            # A pale sand cap on the terrace, and a darker band low on its face.
            m.part(g, "TerraceTop", (w + 1, 1.2, d - 6), (x + w / 2, y + h + 0.62, zc + out * 3), (226, 186, 134), yaw, **NO_HIT)
            x += w
        y += h
        back += rng.uniform(24, 40)


def wall_shelf(m, g, x, y, z, out):
    """A plank lookout bolted to a canyon wall, with a ladder down to the terrace below (the
    picture's). It is braced into the wall, so nothing hangs in the air."""
    zf = z - out * 14
    for k in range(6):
        px = x - 12.5 + k * 5
        m.part(g, "ShelfPlank", (4.6, 0.6, 15), (px, y, z - out * 6.5), jitter(WOOD[2], 7), **NO_HIT)
    for s in (-11, 11):
        beam(m, g, "Brace", (x + s, y - 1.3, zf), (x + s, y - 12, z + out * 1.5), 1.4, 1.4, WOOD[1], "SmoothPlastic")
        beam(m, g, "Brace", (x + s, y - 1.3, z + out * 1.5), (x + s, y - 1.3, zf), 1.2, 1.6, WOOD[1], "SmoothPlastic")
    beam(m, g, "ShelfRail", (x - 12, y + 7, zf), (x + 12, y + 7, zf), 0.7, 0.7, WOOD[0], "SmoothPlastic")
    for s in (-12, 0, 12):
        beam(m, g, "ShelfPost", (x + s, y + 0.2, zf), (x + s, y + 7.4, zf), 0.7, 0.7, WOOD[0], "SmoothPlastic")


def signal_mast(m, g, x, z):
    """A trackside signal, facing back up the line towards the oncoming train."""
    block(m, g, "MastFoot", x - 4, x + 4, 0, 2.4, z - 4, z + 4, (128, 124, 116))
    cyl_y(m, g, "Mast", 2.4, 62, x, z, 1.8, (64, 66, 70), "Metal")
    face_x = x - 3
    block(m, g, "SignalHead", face_x, x + 3, 62, 76, z - 4, z + 4, (28, 30, 32), "Metal")
    for y, c in ((72.5, (172, 52, 42)), (65.5, (66, 150, 74))):
        cyl_x(m, g, "SignalLamp", face_x - 0.4, face_x - 0.02, y, z, 4, c)
        block(m, g, "SignalHood", face_x - 3, face_x - 0.02, y + 2.1, y + 2.6, z - 2.4, z + 2.4, (20, 22, 24), "Metal")


def telegraph_pole(m, g, x, z):
    """A line of poles beside the track, with wires, on their own feet."""
    cyl_y(m, g, "Pole", -1, 70, x, z, 2.4, jitter(WOOD[0], 5))
    block(m, g, "PoleArm", x - 1, x + 1, 62, 63.4, z - 12, z + 12, WOOD[1])
    for k in (-10, 0, 10):
        cyl_y(m, g, "Insulator", 63.4, 65, x, z + k, 1, (200, 200, 196))
        beam(m, g, "Wire", (x, 65.2, z + k), (x - CHUNK, 65.2, z + k), 0.18, 0.18, (40, 40, 42), "Metal")


def build_chunks(m):
    for i in range(CHUNKS):
        g = f"Scroll{i}"
        x0 = BUILT_AT + i * CHUNK
        # The ground, wall to wall, so the trains really run over something.
        block(m, g, "Ground", x0 - 8, x0 + CHUNK + 8, -6 - (i % 2) * 0.12, -(i % 2) * 0.12, WALL_N - HALF_G - (i % 2) * 0.12, WALL_S + HALF_G + (i % 2) * 0.12, (212, 172, 124))
        track_chunk(m, g, x0, ZA)
        track_chunk(m, f"TrackB{i}", x0, ZB)
        # A wide drainage ditch between and beside the tracks.
        m.part(g, "SandDrift", (CHUNK * 0.9, 0.5, 26), (x0 + CHUNK / 2, 0.08, WALL_N + 42), (222, 182, 134), matmul(rot_x(0.4), rot_z(0.3)), **NO_HIT)
        m.part(g, "SandDrift", (CHUNK * 0.9, 0.5, 26), (x0 + CHUNK / 2, 0.1, WALL_S - 42), (222, 182, 134), matmul(rot_x(0.3), rot_z(-0.4)), **NO_HIT)
        terraced_wall(m, g, x0, WALL_N, -1, i)
        terraced_wall(m, g, x0, WALL_S, 1, i)
        # Rocks and scrub standing on the ground beside the track.
        for _ in range(5):
            side = rng.choice((-1, 1))
            z = -92 - rng.uniform(0, 60) if side < 0 else 142 + rng.uniform(0, 70)
            size = rng.uniform(3, 11)
            rock(m, g, "Rock", (size * 1.5, size, size * 1.2), (x0 + rng.uniform(4, CHUNK - 4), size * 0.34, z), jitter(rng.choice(STRATA), 8), 22)
        for _ in range(2):
            side = rng.choice((-1, 1))
            cactus(m, g, x0 + rng.uniform(10, CHUNK - 10), -96 - rng.uniform(0, 50) if side < 0 else 148 + rng.uniform(0, 50))
        telegraph_pole(m, g, x0 + CHUNK, -110)
        if i % 2 == 0:
            signal_mast(m, g, x0 + rng.uniform(30, CHUNK - 30), -86)
        if i % 3 == 1:
            wall_shelf(m, g, x0 + rng.uniform(40, CHUNK - 40), rng.uniform(40, 60), WALL_S, 1)
        if i % 3 == 2:
            wall_shelf(m, g, x0 + rng.uniform(40, CHUNK - 40), rng.uniform(40, 60), WALL_N, -1)
    # Great mesas that never move, closing the far ends of the canyon (well short of the lobby).
    for side in (-1, 1):
        for k in range(16):
            z = -1600 + k * 213 + rng.uniform(-40, 40)
            h, w = rng.uniform(300, 480), rng.uniform(260, 420)
            m.part("FarMesas", "FarMesa", (w, h, w * 0.8), (side * (2300 + rng.uniform(0, 120)), h / 2 - 30, z), jitter(rng.choice(TERRACES), 6), rock_rows(2), CastShadow=False, **NO_HIT)
    block(m, "FarMesas", "FarSand", -2700, 2700, -46, -40, -3000, 3000, (196, 156, 112), CastShadow=False)


def post(m, g, x, z, y0, y1):
    """A steel lattice mast: four legs, cross bars and a concrete foot."""
    block(m, g, "PostFoot", x - 8, x + 8, 0, 4, z - 8, z + 8, (128, 124, 116))
    for ox in (-4, 4):
        for oz in (-4, 4):
            block(m, g, "PostLeg", x + ox - 0.8, x + ox + 0.8, 4, y1, z + oz - 0.8, z + oz + 0.8, (84, 88, 94), "Metal")
    y = 4
    flip = 1
    while y < y1 - 8:
        for oz in (-4, 4):
            a, b = (-4, 4) if flip > 0 else (4, -4)
            beam(m, g, "Lattice", (x + a, y, z + oz), (x + b, y + 8, z + oz), 0.5, 0.5, (70, 74, 80), "Metal")
        block(m, g, "PostBand", x - 4.6, x + 4.6, y + 7.7, y + 8.3, z - 4.6, z + 4.6, (70, 74, 80), "Metal")
        flip = -flip
        y += 8


def signal_head(m, g, base, z, y):
    """A gantry signal: its lamps on the -X side, facing the oncoming trains."""
    block(m, g, "SignalHead", base - 3.4, base + 3.4, y, y + 18, z - 5, z + 5, (28, 30, 32), "Metal")
    for k, c in enumerate(((172, 52, 42), (216, 164, 56), (66, 150, 74))):
        ly = y + 14.4 - k * 5.4
        cyl_x(m, g, "SignalLamp", base - 3.8, base - 3.42, ly, z, 4, c)
        block(m, g, "SignalHood", base - 7, base - 3.42, ly + 2.4, ly + 3, z - 2.8, z + 2.8, (20, 22, 24), "Metal")


def build_gantry(m, g, base):
    z0, z1 = -94, 126
    post(m, g, base, z0, 4, CLEAR + 26)
    post(m, g, base, z1, 4, CLEAR + 26)
    block(m, g, "GantryBeam", base - 4, base + 4, CLEAR, CLEAR + 4, z0, z1, (92, 96, 102), "Metal", attributes={"ObstacleHit": True})
    block(m, g, "GantryTop", base - 4, base + 4, CLEAR + 20, CLEAR + 22, z0, z1, (86, 90, 96), "Metal")
    z = z0 + 6
    flip = 1
    while z < z1 - 10:
        a, b = (CLEAR + 4, CLEAR + 20) if flip > 0 else (CLEAR + 20, CLEAR + 4)
        for ox in (-3.6, 3.6):
            beam(m, g, "Lattice", (base + ox, a, z), (base + ox, b, z + 14), 0.8, 0.8, (72, 76, 82), "Metal")
        flip = -flip
        z += 14
    for z in (ZA, ZB):
        signal_head(m, g, base, z, CLEAR + 22.1)


def arch_stones(m, g, x, centre_z, y_c, radius, a0, a1, count, color, thick=12):
    """Stones round a quarter-arch at a tunnel mouth, each turned to follow the curve."""
    for k in range(count):
        a = math.radians(a0 + (a1 - a0) * (k + 0.5) / count)
        step = math.radians(abs(a1 - a0) / count)
        z, y = centre_z + math.cos(a) * radius, y_c + math.sin(a) * radius
        stone = jitter(color, 7)
        m.part(g, "ArchStone", (5 + k * 0.24, thick, radius * step + 0.3), (x, y, z), stone, rot_x(-math.degrees(a) + 90.8), **NO_HIT)


def build_bore(m, g, base, zc, side):
    """One train's tunnel: a low flat crown over the train, a rounded shoulder on its outer side
    and a thin wall on the inner (the trains can run very close together)."""
    half_len, edge = 260, 24
    x0, x1 = base - half_len, base + half_len
    inner = zc - side * (edge + 2)          # the inner wall's face, towards the other train
    outer = zc + side * (edge + 2)          # where the crown ends and the shoulder starts
    r = 16                                 # the outer shoulder's radius
    z0, z1 = sorted((inner, outer))
    rock_color = (168, 118, 74)
    block(m, g, "TunnelCrown", x0, x1, CLEAR, CLEAR + 3, z0, z1, (118, 92, 66), attributes={"ObstacleHit": True})
    # The rounded shoulder: facets stepping out and down, then a wall to the ground.
    facets = 7
    centre_y = CLEAR - r
    for k in range(facets):
        a = math.radians(90 * (k + 0.5) / facets)
        step = math.radians(90 / facets)
        z = outer + side * math.sin(a) * r
        y = centre_y + math.cos(a) * r
        m.part(g, "TunnelFacet", (x1 - x0 + k * 0.2, 2, r * step + 0.4), (base, y, z), jitter((118, 92, 66), 4), rot_x(side * math.degrees(a)), **NO_HIT)
    wall_z = outer + side * r
    a, b = sorted((wall_z, wall_z + side * 3))
    block(m, g, "TunnelWall", x0, x1, 0, centre_y + 0.4, a, b, (112, 86, 62))
    a, b = sorted((inner, inner - side * 1.5))
    block(m, g, "TunnelWall", x0, x1, 0, CLEAR + 3, a, b, (112, 86, 62))
    # The mountain over it: long rounded ridges stepping up, wider than the bore.
    zo = wall_z + side * 60
    za, zb = sorted((inner - side * 20, zo))
    for k, (grow, top) in enumerate(((0, 40), (-36, 80), (-80, 124))):
        shrink = -grow * 0.5
        m.part(g, "Mountain", (2 * half_len + grow + 40, top, zb - za - shrink * 0.8), (base, CLEAR + 3 + top / 2 + k * 0.1, (za + zb) / 2), jitter(rock_color, 8), rock_rows(1.2), **NO_HIT)
    for _ in range(9):
        sx = rng.uniform(-half_len, half_len)
        size = rng.uniform(26, 60)
        rock(m, g, "MountainRock", (size * 1.5, size, size * 1.2), (base + sx, CLEAR + rng.uniform(20, 90), rng.uniform(za, zb)), jitter(rng.choice(STRATA), 8), 16)
    # Warm lamps down the bore, on the wall.
    x = x0 + 26
    while x < x1:
        lamp = block(m, g, "TunnelLamp", x - 1.4, x + 1.4, 42, 44.8, min(wall_z - side * 0.6, wall_z), max(wall_z - side * 0.6, wall_z), (252, 226, 170))
        lamp["children"] = [{"name": "Glow", "className": "PointLight", "properties": {"Brightness": 1.1, "Range": 44, "Color": m.rgb((255, 214, 150)), "Shadows": False}}]
        x += 96
    # Stone arches round both mouths, with a keystone at the shoulder.
    stone = (160, 138, 110)
    for sx in (-1, 1):
        xf = base + sx * (half_len + 1.6)
        a0, a1 = 0, 90
        if side > 0:
            arch_stones(m, g, xf, outer, centre_y, r + 6, a0, a1, 9, stone)
        else:
            arch_stones(m, g, xf, outer, centre_y, r + 6, 180 - a1, 180 - a0, 9, stone)
        block(m, g, "PortalLintel", xf - 2.6, xf + 2.6, CLEAR + 3, CLEAR + 15, z0 - 1, z1 + 1, jitter(stone, 5))
        a, b = sorted((wall_z - side * 0.25, wall_z + side * 12))
        block(m, g, "PortalJamb", xf - 2.7, xf + 2.7, 0.1, centre_y, a, b, jitter(stone, 5))
        a, b = sorted((inner + side * 0.25, inner - side * 5))
        block(m, g, "PortalJamb", xf - 2.75, xf + 2.75, 0.14, CLEAR + 3.4, a, b, jitter(stone, 5))
        block(m, g, "Keystone", xf - 3.1, xf + 3.1, CLEAR + 2, CLEAR + 12, (z0 + z1) / 2 - 7, (z0 + z1) / 2 + 7, (182, 158, 124))
        # Rock either side of the mouth, spread on the ground.
        m.part(g, "PortalRock", (30, 64, 80), (xf + sx * 12, 30, wall_z + side * 46), jitter(rock_color, 6), rock_rows(3), **NO_HIT)


def build_sign(m, g, base, zpole, z_board_a, z_board_b):
    """A big board on an arm over one train's outer half. Its stripes and arrow face -X, towards
    the trains coming down the line."""
    a, b = sorted((z_board_a, z_board_b))
    post(m, g, base, zpole, 4, ROOF + 36)
    block(m, g, "SignArm", base - 2, base + 2, ROOF + 30, ROOF + 33, min(a, zpole), max(b, zpole), (70, 74, 80), "Metal")
    block(m, g, "SignBoard", base - 1.5, base + 1.5, ROOF + 1, ROOF + 30, a, b, (222, 178, 58), attributes={"ObstacleHit": True})
    z = a + 1
    k = 0
    while z < b - 2:
        if k % 2 == 0:
            m.part(g, "SignStripe", (0.3, 28, 2.6), (base - 1.7, ROOF + 15.5, z + 1.3), (32, 32, 34), rot_x(0.5), **NO_HIT)
        z += 2.8
        k += 1


def build_obstacles(m):
    slot = 3  # built far along the line, where no one ever goes, waiting to be called
    for kind, count in POOLS.items():
        for n in range(1, count + 1):
            g, base = f"Obstacle_{kind}_{n}", slot * PARK
            slot += 1
            if kind == "Gantry":
                build_gantry(m, g, base)
            elif kind == "Tunnel":
                build_bore(m, g, base, ZA, -1)
            elif kind == "TunnelB":
                build_bore(m, g, base, ZB, 1)
            elif kind == "SignA":
                build_sign(m, g, base, -78, -48, -24)
            else:
                build_sign(m, g, base, B_Z[1] + 31, ZB, B_Z[1])


def shrink(m):
    """Scales every part (and its lights' reach) by SCALE."""
    def do(node):
        props = node.get("properties", {})
        if "CFrame" in props:  # (a part: particles and labels have a Size of their own)
            props["Size"] = [round(v * SCALE, 4) for v in props["Size"]]
            frame = props["CFrame"]["CFrame"]
            frame["position"] = [round(v * SCALE, 4) for v in frame["position"]]
        if "Range" in props:
            props["Range"] = round(props["Range"] * SCALE, 2)
        for child in node.get("children", ()):
            do(child)
    for group in m.groups.values():
        for node in group:
            do(node)


def add_ladders(m):
    """Ladders are real-sized (Roblox's climbing trusses come in 2-stud steps), so they go in after
    the shrink, on the car ends that face a flatbed and each locomotive's rear."""
    def end(i, side, inset):
        return (car_x(i) + side * (CAR / 2 - inset)) * SCALE
    spots = (("TrainA", ZA, ((end(1, -1, 4), -1), (end(3, 1, 12), 1), (end(4, -1, 4), -1), (end(0, -1, 10), -1))),
             ("TrainB", ZB, ((end(2, 1, 4), 1), (end(3, -1, 4), -1), (end(5, 1, 12), 1), (end(0, -1, 10), -1))))
    for g, zm, ladders in spots:
        for x, facing in ladders:
            # (wide, and the rails stop level with what they're on)
            m.ladder(g, x, zm * SCALE, (facing, 0), DECK * SCALE, ROOF * SCALE, width=8, color=(62, 64, 70), name="CarLadder", over=0)


def build():
    m = Map(colors=COLORS, materials=MATERIALS)
    build_trains(m)
    build_chunks(m)
    build_obstacles(m)
    shrink(m)
    add_ladders(m)
    for x, z, y in SPAWNS:
        m.spawn(x * SCALE, z * SCALE, y * SCALE)
    simple_materials(m)
    # Parts that move every frame cast no shadows (redrawing them each frame is the map's biggest cost).
    for g, nodes in m.groups.items():
        if g.startswith(("Scroll", "TrackB", "Obstacle_")):
            for node in nodes:
                node["properties"]["CastShadow"] = False
    return m


if __name__ == "__main__":
    layout = build()
    issues = mapcheck.check_map(layout, ATTRIBUTES)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES, models=[g for g in layout.groups if g.startswith(("Scroll", "TrackB", "Obstacle_")) or g == "TrainB"])
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
