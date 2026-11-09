#!/usr/bin/env python3
"""Canyon Express (4-8 players): two freight trains racing side by side through a sandstone canyon,
from the owner's reference picture and the "Canyon Express Map" canvas. Run from the repo root:
    python3 tools/canyon_layout.py
It rewrites `src/maps/CanyonExpress/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X along the track (the locomotives lead towards +X), Z across, Y up. THE TRAINS DON'T MOVE:
the world slides past them (shared/ScrollLine, client/ScrollWorld), so running on them is as solid
as the ground. Train A (z -12..0) never moves; Train B (z 13..25 as built) drifts along and in and
out, carrying whoever is on it, so the gap runs 4..22. Six cars each: locomotive, containers,
flatbeds with cargo, a boxcar. Roofs at 14, decks at 5; ladders on the car ends over the flatbeds.
Falling off is out (KillHeight, FallEliminates). The look matches the Space Station: smooth colours
and a modest part count (`simple_materials`).
Moving folders (each a Persistent model): Scroll<n> (one CHUNK of canyon each), TrackB<n> and RailB
(Train B's track, which follows its gap), TrainB, and Obstacle_<Kind>_<n>, which wait far along +X
until the timetable brings them down the line. Parts with ObstacleHit knock you back.
"""
import json
import math
import os
import sys

sys.path.insert(0, "tools")
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, matmul, rot_x, rot_y, rot_z  # noqa: E402
from mine_layout import STRATA, WOOD, beam, clad, jitter, rng, rock_rows, simple_materials  # noqa: E402

OUT = "src/maps/CanyonExpress"
ATTRIBUTES = {"DisplayName": "Canyon Express", "MinPlayers": 4, "MaxPlayers": 8, "InRotation": True,
              "Lighting": "Desert", "KillHeight": 2, "FallEliminates": True, "ScrollWorld": True,
              "OutOfBounds": "CabRoof,Stack"}

CAR, COUPLE, W, DECK, ROOF = 32, 3, 12, 5, 14
A_Z = (-12, 0)
B_Z = (13, 25)
CLEAR = ROOF + 4.4                         # the underside of low beams
CHUNK, CHUNKS = 200, 8                     # keep CHUNK equal to Config.ScrollWorld.ChunkLength
PARK = 300                                 # Config.ScrollWorld.ParkStep
POOLS = {"Gantry": 4, "Tunnel": 2, "SignA": 3, "SignB": 3}
SPAWNS = ((88, -6, ROOF), (58, -6, ROOF), (20, -6, DECK), (-12, -6, ROOF), (-46, -6, ROOF), (-86, -6, DECK),
          (-30, -3, ROOF), (40, -10, ROOF))
STEEL, DARK = (86, 89, 95), (47, 50, 54)
CONT_COLORS = ((199, 61, 142), (222, 202, 58), (62, 106, 168), (216, 129, 58), (156, 47, 47), (100, 132, 74), (70, 124, 130))

COLORS = {"deck": (86, 89, 95), "crate": (180, 138, 85)}
MATERIALS = {"deck": "DiamondPlate", "crate": "WoodPlanks"}


def car_x(i):
    return 103.5 - CAR / 2 - i * (CAR + COUPLE)


def block(m, g, name, a0, a1, b0, b1, c0, c1, color, material="SmoothPlastic", solid=False, **props):
    extra = {} if solid else dict(NO_HIT)
    extra.update(props)
    return m.block(g, name, a0, a1, b0, b1, c0, c1, color, Material=material, **extra)


def wheel(m, g, x, y, z, d, color=(52, 54, 58)):
    m.cylinder(g, "Wheel", 0.5, d, (x, y, z), color, rot_y(90), Material="Metal", **NO_HIT)


def bogies(m, g, x0, x1, z0, z1):
    for bx in (x0 + 6, x1 - 6):
        block(m, g, "BogieFrame", bx - 4, bx + 4, 1.5, 2.3, z0 + 1.1, z1 - 1.1, DARK, "Metal")
        for z in (z0 + 0.55, z1 - 0.55):
            wheel(m, g, bx, 1.55, z, 3.1)
    block(m, g, "CarFrame", x0 + 0.1, x1 - 0.1, 2.3, 3.0, z0 + 0.4, z1 - 0.4, (58, 60, 64), "Metal")
    # The coupling between cars, sitting on the frame's end.
    block(m, g, "Coupler", x0 - 1.42, x0 + 0.1, 2.55, 3.15, (z0 + z1) / 2 - 0.45, (z0 + z1) / 2 + 0.45, (72, 74, 80), "Metal")


def flat_deck(m, g, x0, x1, z0, z1):
    """The car's solid deck, with planks or plate over it."""
    block(m, g, "Deck", x0, x1, 3, DECK, z0, z1, "deck", solid=True)


def corrugated(m, g, x0, x1, y0, y1, z0, z1, color):
    """A shipping container: a solid box, ribbed sides, corner posts and end doors."""
    block(m, g, "Container", x0, x1, y0, y1, z0, z1, color, "CorrodedMetal", solid=True)
    pale = tuple(min(255, c + 16) for c in color)
    dark = tuple(max(0, c - 34) for c in color)
    rib = x0 + 1.1
    while rib < x1 - 1.0:
        for z, s in ((z0, -1), (z1, 1)):
            block(m, g, "Rib", rib - 0.27, rib + 0.27, y0 + 0.5, y1 - 0.55, min(z, z + s * 0.14), max(z, z + s * 0.14), pale, "Metal")
        rib += 2.7
    for x, s in ((x0, -1), (x1, 1)):  # the end doors
        zm = (z0 + z1) / 2
        for a, b in ((z0 + 0.4, zm - 0.06), (zm + 0.06, z1 - 0.4)):
            block(m, g, "DoorPanel", min(x, x + s * 0.08), max(x, x + s * 0.08), y0 + 0.5, y1 - 0.55, a, b, pale, "Metal")
    for x in (x0, x1 - 0.5):
        for z in (z0, z1 - 0.5):
            block(m, g, "CornerPost", x - 0.19, x + 0.69, y0 - 0.07, y1 + 0.07, z - 0.19, z + 0.69, dark, "Metal")
    for z, s in ((z0, -1), (z1, 1)):  # top and bottom rails
        block(m, g, "ContRail", x0 + 0.72, x1 - 0.72, y1 - 0.5, y1 - 0.08, min(z, z + s * 0.11), max(z, z + s * 0.11), dark, "Metal")


def rail_guard(m, g, x0, x1, z, y0, y1):
    """Handrail on a walkway: posts and a top rail, with an invisible guard as tall."""
    block(m, g, "RailGuard", x0, x1, y0, y1, z - 0.15, z + 0.15, DARK, solid=True, Transparency=1, CastShadow=False)
    block(m, g, "HandRail", x0, x1, y1 - 0.14, y1 + 0.03, z - 0.08, z + 0.08, (196, 60, 46), "Metal")
    x = x0
    while x <= x1 + 0.01:
        block(m, g, "RailPost", x - 0.07, x + 0.07, y0, y1 - 0.13, z - 0.05, z + 0.05, (178, 56, 44), "Metal")
        x += 6


def locomotive(m, g, x0, x1, z0, z1, livery, nose_stripes):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    zm = (z0 + z1) / 2
    hood0, hood1 = zm - 3.5, zm + 3.5
    white = (232, 226, 212)
    # Long hood, cab, short nose (the nose leads towards +X).
    hx0, hx1 = x0 + 2.5, x1 - 11
    block(m, g, "Hood", hx0, hx1, DECK, ROOF, hood0, hood1, livery, "SmoothPlastic", solid=True)
    cx0, cx1 = hx1, x1 - 5
    block(m, g, "CabRoof", cx0, cx1, DECK, ROOF + 2, z0 + 1.5, z1 - 1.5, white, solid=True)
    block(m, g, "Nose", x1 - 5, x1 - 1, DECK, ROOF - 3.5, z0 + 1.8, z1 - 1.8, white, solid=True)
    # Nose stripes, slanted like the picture's.
    for k in range(7):
        y = DECK + 0.4 + k * 1.2
        if y > ROOF - 4:
            break
        for s, z in ((-1, z0 + 1.8), (1, z1 - 1.8)):
            m.part(g, "NoseStripe", (4.4, 0.55, 0.08), (x1 - 3, y, z + s * 0.04), nose_stripes, rot_z(14), Material="SmoothPlastic", **NO_HIT)
    for y in (DECK + 1.2, DECK + 3.0, DECK + 4.8):
        m.part(g, "NoseStripe", (0.08, 0.55, z1 - z0 - 4), (x1 - 0.96, y, zm), nose_stripes, rot_x(12), Material="SmoothPlastic", **NO_HIT)
    # Hood bands, doors, grilles and roof fans.
    for s, z in ((-1, hood0), (1, hood1)):
        block(m, g, "HoodBand", hx0 + 0.3, hx1 - 0.3, DECK + 1.6, DECK + 3.0, min(z, z + s * 0.08), max(z, z + s * 0.08), white)
        block(m, g, "HoodBand", hx0 + 0.3, hx1 - 0.3, DECK + 3.3, DECK + 3.7, min(z, z + s * 0.08), max(z, z + s * 0.08), nose_stripes)
        x = hx0 + 1
        while x < hx1 - 3:
            block(m, g, "HoodDoor", x, x + 1.9, DECK + 4.2, ROOF - 0.6, min(z, z + s * 0.1), max(z, z + s * 0.1), tuple(max(0, c - 22) for c in livery), "Metal")
            x += 5
    x = hx0 + 3
    while x < hx1 - 2:
        m.cylinder(g, "FanRing", 0.3, 4.2, (x, ROOF + 0.18, zm), (70, 72, 78), Material="Metal", **NO_HIT)
        x += 9
    m.cylinder(g, "Stack", 2.6, 1.3, (hx0 + 1.4, ROOF + 1.3, zm), (40, 42, 46), Material="Metal", **NO_HIT)
    # Cab windows.
    for s, z in ((-1, z0 + 1.5), (1, z1 - 1.5)):
        block(m, g, "CabWindow", cx0 + 0.5, cx1 - 0.5, ROOF - 2.6, ROOF + 0.8, min(z, z + s * 0.08), max(z, z + s * 0.08), (120, 160, 185), "Glass", Reflectance=0.2)
    for a, b in ((z0 + 2, zm - 0.3), (zm + 0.3, z1 - 2)):
        block(m, g, "CabWindow", cx1, cx1 + 0.08, ROOF - 2.6, ROOF + 0.9, a, b, (120, 160, 185), "Glass", Reflectance=0.2)
    # Headlights and a horn on the cab roof; the warning lamp the crew would watch.
    for s in (-1, 1):
        m.cylinder(g, "Headlight", 0.18, 1.0, (x1 - 0.85, ROOF - 4.4, zm + s * 1.2), (242, 236, 210), rot_y(0), Material="SmoothPlastic", **NO_HIT)
    block(m, g, "WarnLamp", cx0 + 1.6, cx0 + 3, ROOF + 2.02, ROOF + 2.7, zm - 0.7, zm + 0.7, (96, 92, 80), attributes={"WarnLamp": True})
    # Side walkways with red handrails, as in the picture.
    for z in (z0 + 0.3, z1 - 0.3):
        rail_guard(m, g, x0 + 2, x1 - 11.3, z, DECK, DECK + 3.2)
    # A pilot plough at the front.
    m.part(g, "Pilot", (1.6, 2.6, z1 - z0 - 1), (x1 + 0.1, 2.2, zm), (54, 86, 72), rot_z(-16), Material="Metal", **NO_HIT)


def boxcar(m, g, x0, x1, z0, z1, color):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    bx1 = x1 - 3  # a platform at the front end, for the ladder
    block(m, g, "Boxcar", x0 + 0.4, bx1, DECK, ROOF, z0, z1, color, "Metal", solid=True)
    dark = tuple(max(0, c - 28) for c in color)
    x = x0 + 1.4
    while x < bx1 - 1:
        for z, s in ((z0, -1), (z1, 1)):
            block(m, g, "BoxRib", x - 0.18, x + 0.18, DECK + 0.3, ROOF - 0.3, min(z, z + s * 0.14), max(z, z + s * 0.14), dark, "Metal")
        x += 5.2
    for z, s in ((z0, -1), (z1, 1)):
        block(m, g, "Stripe", x0 + 0.8, bx1 - 0.6, DECK + 3.0, DECK + 4.1, min(z, z + s * 0.2), max(z, z + s * 0.2), (216, 129, 58))
        xm = (x0 + bx1) / 2
        block(m, g, "SlideDoor", xm - 3, xm + 3, DECK + 0.45, ROOF - 0.65, min(z, z + s * 0.3), max(z, z + s * 0.3), (150, 142, 124), "Metal")
    block(m, g, "RoofWalk", x0 + 1, bx1 - 1, ROOF + 0.11, ROOF + 0.16, (z0 + z1) / 2 - 1, (z0 + z1) / 2 + 1, (120, 104, 82), "WoodPlanks")


def cargo(m, g, x, z, w, h, d):
    """Timber-strapped crates: solid block, slats, straps."""
    block(m, g, "Cargo", x - w, x + w, DECK, DECK + h, z - d, z + d, jitter((180, 138, 85), 10), "WoodPlanks", solid=True)
    for sx in (-1, 1):
        block(m, g, "CargoSlat", x + sx * w * 0.7 - 0.2, x + sx * w * 0.7 + 0.2, DECK + 0.05, DECK + h + 0.09, z - d - 0.09, z + d + 0.09, (124, 90, 52), "Wood")


def flatbed(m, g, x0, x1, z0, z1, layout):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    # Plank floor over the deck, inside the stake pockets.
    xp = x0 + 1.2
    while xp < x1 - 1:
        m.part(g, "DeckPlank", (2.1, 0.2, z1 - z0 - 0.5), (xp, DECK, (z0 + z1) / 2), jitter(WOOD[2], 6), Material="WoodPlanks", **NO_HIT)
        xp += 2.35
    for w, h, d, ox, oz in layout:
        cargo(m, g, (x0 + x1) / 2 + ox, (z0 + z1) / 2 + oz, w, h, d)
    for x in (x0 + 2, x0 + 16, x1 - 2):  # stakes down the sides
        for z in (z0 + 0.15, z1 - 0.15):
            block(m, g, "Stake", x - 0.14, x + 0.14, DECK, DECK + 1.7, z - 0.14, z + 0.14, WOOD[1], "Wood")


def containers(m, g, x0, x1, z0, z1, c1, c2):
    flat_deck(m, g, x0, x1, z0, z1)
    bogies(m, g, x0, x1, z0, z1)
    mid = (x0 + x1) / 2
    corrugated(m, g, x0 + 0.5, mid - 0.5, DECK + 0.1, ROOF, z0 + 0.5, z1 - 0.5, c1)
    corrugated(m, g, mid + 0.5, x1 - 0.5, DECK + 0.1, ROOF, z0 + 0.5, z1 - 0.5, c2)


def build_train(m, g, zs, kinds):
    z0, z1 = zs
    for i, kind in enumerate(kinds):
        x = car_x(i)
        x0, x1 = x - CAR / 2, x + CAR / 2
        if kind[0] == "loco":
            locomotive(m, g, x0, x1, z0, z1, kind[1], kind[2])
        elif kind[0] == "box":
            boxcar(m, g, x0, x1, z0, z1, kind[1])
        elif kind[0] == "cont":
            containers(m, g, x0, x1, z0, z1, kind[1], kind[2])
        else:
            flatbed(m, g, x0, x1, z0, z1, kind[1])


def add_ladders(m, g, zs, spots):
    zm = (zs[0] + zs[1]) / 2
    for x, facing in spots:
        m.ladder(g, x, zm, (facing, 0), DECK, ROOF, width=4, color=(62, 64, 70), name="CarLadder")


def build_trains(m):
    lay1 = ((3, 4, 3, -9, -1.5), (2.5, 6, 3, 1, 1.5), (3.5, 3, 2.5, 9.5, -1.5))
    lay2 = ((3, 5, 3, -8.5, 1.5), (3, 3, 2.6, 0, -2), (3, 6, 3, 9, 1))
    kinds_a = (("loco", (226, 220, 206), (118, 124, 132)), ("cont", CONT_COLORS[0], CONT_COLORS[1]), ("flat", lay1),
               ("box", (183, 166, 140)), ("cont", CONT_COLORS[2], CONT_COLORS[6]), ("flat", lay2))
    kinds_b = (("loco", (184, 56, 47), (232, 226, 212)), ("flat", lay2), ("cont", CONT_COLORS[3], CONT_COLORS[2]),
               ("cont", CONT_COLORS[1], CONT_COLORS[4]), ("flat", lay1), ("box", (167, 154, 130)))
    build_train(m, "TrainA", A_Z, kinds_a)
    build_train(m, "TrainB", B_Z, kinds_b)
    # Ladders on the car ends that face a flatbed (a ladder needs the car behind it).
    def end(i, side):
        return car_x(i) + side * (CAR / 2 - 0.5)
    add_ladders(m, "TrainA", A_Z, ((end(1, -1), -1), (end(3, 1) - 2.5, 1), (end(4, -1), -1)))
    add_ladders(m, "TrainB", B_Z, ((end(2, 1), 1), (end(3, -1), -1), (end(5, 1) - 2.5, 1)))
    # A ladder up the side of each locomotive's rear end, from its deck.
    x_rear = car_x(0) - CAR / 2 + 2.5
    m.ladder("TrainA", x_rear, (A_Z[0] + A_Z[1]) / 2, (-1, 0), DECK, ROOF, width=4, color=(62, 64, 70), name="CarLadder")
    m.ladder("TrainB", x_rear, (B_Z[0] + B_Z[1]) / 2, (-1, 0), DECK, ROOF, width=4, color=(62, 64, 70), name="CarLadder")
    # Sparks off one wheel of Train B (the picture's braking train), dust under Train A.
    spark = m.particles("Sparks", 40, (0.2, 0.5), (18, 34), [(0, 0.5), (1, 0.1)], [(0, 0), (1, 1)], (255, 190, 90),
                        texture="rbxasset://textures/particles/sparkles_main.dds", direction="Left", spread=(24, 24), accel=(0, -80, 0), light=1)
    m.block("TrainB", "SparkPoint", car_x(1) + 6, car_x(1) + 7, 0.2, 1.2, B_Z[0] + 0.5, B_Z[0] + 1.5, (0, 0, 0), Transparency=1, CastShadow=False,
            children=[spark], **NO_HIT)


def rails(m, g, zc, group_rails=True):
    for s in (-3.1, 3.1):
        m.block(g, "Rail", -900, 900, 0.32, 0.86, zc + s - 0.16, zc + s + 0.16, (112, 116, 122), Material="Metal", **NO_HIT)
        m.block(g, "RailFoot", -900, 900, 0.12, 0.32, zc + s - 0.42, zc + s + 0.42, (88, 88, 88), Material="Metal", **NO_HIT)


def chunk_track(m, g, x0, zc):
    """Sleepers and ballast under one track, for one chunk."""
    x = x0 + 3
    while x < x0 + CHUNK - 1:
        m.part(g, "Sleeper", (1.8, 0.34, 10.2), (x, -0.02, zc), jitter(WOOD[3], 9), rot_y(rng.uniform(-1, 1)), Material="Wood", **NO_HIT)
        x += 9
    for _ in range(0):
        size = rng.uniform(0.5, 1.1)
        m.part(g, "Ballast", (size * 1.3, size * 0.7, size), (rng.uniform(x0, x0 + CHUNK), -0.1, zc + rng.uniform(-6.8, 6.8)),
               jitter((132, 118, 100), 12), rock_rows(26), Material="Slate", **NO_HIT)
    # The stone shelf the track runs on: a long ledge of chunky blocks.
    x = x0
    while x < x0 + CHUNK - 1:
        length = min(rng.uniform(60, 90), x0 + CHUNK - x)
        for s in (-1, 1):
            m.part(g, "Shelf", (length + 1, 10, 3.2), (x + length / 2, -5.4, zc + s * 7.1), jitter(rng.choice(STRATA), 8), rock_rows(2.2), Material="Sandstone", **NO_HIT)
        m.part(g, "ShelfTop", (length + 1, 0.8, 13), (x + length / 2, -0.75, zc), jitter((160, 142, 116), 8), rock_rows(0.5), Material="Slate", **NO_HIT)
        x += length


def chunk_wall(m, g, x0, z, out, top):
    """One canyon wall, in chunky sandstone layers, out to `x0 + CHUNK`."""
    m.block(g, "CanyonCore", x0, x0 + CHUNK, -40, top, min(z + out * 18, z - out * 2), max(z + out * 18, z - out * 2), STRATA[2], Material="Sandstone", **NO_HIT)
    clad(m, "x", z, -out if out else 1, x0, x0 + CHUNK, -14, top, proud=(0.4, 1.6), lean=1.5, group=g)
    # Plain mesas standing back from the wall.
    for tier in range(2):
        x = x0
        while x < x0 + CHUNK:
            w = rng.uniform(60, 90)
            h = rng.uniform(16, 34)
            d = rng.uniform(24, 36)
            zc = z + out * (12 + tier * 28 + d * 0.3)
            m.part(g, "Mesa", (w, h + 6, d), (x + w / 2, top + tier * 14 + h / 2 - 3, zc), jitter(STRATA[(tier + rng.randint(0, 3)) % len(STRATA)], 5), rock_rows(2),
                   Material="SmoothPlastic", **NO_HIT)
            x += w * 0.95


def wooden_shelf(m, g, x, y, z, out):
    """A plank shelf bolted to the canyon wall on two braces (the picture's lookouts)."""
    for k in range(3):
        px = x - 3.2 + k * 3.2
        m.part(g, "ShelfPlank", (3.0, 0.3, 8), (px, y, z + out * 3.4), jitter(WOOD[2], 10), Material="WoodPlanks", **NO_HIT)
    for s in (-3, 3):
        beam(m, g, "Brace", (x + s, y - 0.5, z + out * 6.6), (x + s, y - 5, z), 0.5, 0.5, WOOD[1])
        beam(m, g, "Brace", (x + s, y - 0.5, z), (x + s, y - 0.5, z + out * 6.8), 0.5, 0.6, WOOD[1])


def signal_mast(m, g, x, z):
    """A trackside signal on a solid foot."""
    y = 0
    block(m, g, "MastFoot", x - 1, x + 1, -1.5, 0.6, z - 1, z + 1, (128, 124, 116), "Concrete")
    block(m, g, "Mast", x - 0.25, x + 0.25, 0.6, 19, z - 0.25, z + 0.25, (64, 66, 70), "Metal")
    block(m, g, "SignalHead", x - 0.6, x + 0.6, 19, 22.4, z - 0.8, z + 0.8, (28, 30, 32), "Metal")
    m.cylinder(g, "SignalLamp", 0.14, 0.9, (x - 0.66, 21.5, z), (172, 52, 42), rot_y(0), **NO_HIT)
    m.cylinder(g, "SignalLamp", 0.14, 0.9, (x - 0.66, 20, z), (66, 150, 74), rot_y(0), **NO_HIT)


def build_chunks(m):
    for i in range(CHUNKS):
        g = f"Scroll{i}"
        x0 = i * CHUNK
        chunk_track(m, g, x0, -6)
        chunk_track(m, f"TrackB{i}", x0, 19)
        chunk_wall(m, g, x0, -44, -1, 28 + (i * 7) % 16)
        chunk_wall(m, g, x0, 68, 1, 26 + (i * 11) % 18)
        # The canyon floor beyond the shelves, far below the deck.
        m.block(g, "CanyonFloor", x0, x0 + CHUNK, -42, -40, -44, 68, (176, 138, 92), Material="Sand", **NO_HIT)
        for _ in range(4):
            size = rng.uniform(1.0, 5.0)
            m.part(g, "FloorRock", (size * 1.5, size, size * 1.2), (x0 + rng.uniform(0, CHUNK), -39.5 + size * 0.2, rng.uniform(-40, 64)),
                   jitter(rng.choice(STRATA), 10), rock_rows(24), Material="Sandstone", **NO_HIT)
        for k in range(1):
            x = x0 + 30 + k * 90 + rng.uniform(0, 110)
            side, z = rng.choice(((1, -44), (-1, 68)))
            wooden_shelf(m, g, x, rng.uniform(16, 26), z, side)
        # Trackside: signals, rocks and scrub on the shelves' outer edge.
        signal_mast(m, g, x0 + 90 + rng.uniform(0, 20), -18)
        for _ in range(4):
            size = rng.uniform(0.8, 2.6)
            m.part(g, "SideRock", (size * 1.4, size, size * 1.2), (x0 + rng.uniform(0, CHUNK), size * 0.1 - 0.5, -14 - rng.uniform(0, 3)),
                   jitter(rng.choice(STRATA), 10), rock_rows(26), Material="Sandstone", **NO_HIT)
    # Train B's rails follow its gap; Train A's stay put.
    rails(m, "RailA", -6)
    rails(m, "RailB", 19)
    # Distant mesas that never move, so the near canyon has something to slide against.
    for k in range(12):
        for side in (-1, 1):
            x, z = -900 + k * 150 + rng.uniform(-14, 14), side * rng.uniform(250, 340) + 12
            h, w = rng.uniform(90, 170), rng.uniform(70, 130)
            m.part("FarMesas", "FarMesa", (w, h, w * 0.8), (x, h / 2 - 30, z), jitter(rng.choice(STRATA), 8), rock_rows(3), Material="Sandstone", **NO_HIT)
    m.block("FarMesas", "FarSand", -1500, 1500, -52, -48, -700, 700, (196, 156, 106), Material="Sand", **NO_HIT)


def obstacle_folder(kind, n):
    return f"Obstacle_{kind}_{n}"


def lattice_post(m, g, x, z, y0, y1):
    block(m, g, "Post", x - 1.75, x + 1.75, y0, y1, z - 1.75, z + 1.75, (84, 88, 94), "Metal")


def build_gantry(m, g, base):
    z0, z1 = -28, 50
    block(m, g, "PostFoot", base - 2.4, base + 2.4, -1, 0.5, z0 - 2.4, z0 + 2.4, (128, 124, 116), "Concrete")
    block(m, g, "PostFoot", base - 2.4, base + 2.4, -1, 0.5, z1 - 2.4, z1 + 2.4, (128, 124, 116), "Concrete")
    lattice_post(m, g, base, z0, 0.5, CLEAR + 7.4)
    lattice_post(m, g, base, z1, 0.5, CLEAR + 7.4)
    # The beam: a hit box under a steel truss with signal heads.
    block(m, g, "GantryBeam", base - 1.5, base + 1.5, CLEAR, CLEAR + 1.6, z0, z1, (92, 96, 102), "Metal", attributes={"ObstacleHit": True})
    block(m, g, "GantryTop", base - 1.5, base + 1.5, CLEAR + 5.8, CLEAR + 6.8, z0, z1, (86, 90, 96), "Metal")
    for z in range(z0 + 13, z1, 13):
        block(m, g, "TrussPost", base - 0.5, base + 0.5, CLEAR + 1.6, CLEAR + 5.8, z - 0.5, z + 0.5, (72, 76, 82), "Metal")
    for z in (-6, 19):
        block(m, g, "SignalHead", base - 0.8, base + 0.8, CLEAR + 6.9, CLEAR + 11, z - 1.2, z + 1.2, (28, 30, 32), "Metal")
        for y, c in ((CLEAR + 9.9, (172, 52, 42)), (CLEAR + 8.3, (66, 150, 74))):
            m.cylinder(g, "SignalLamp", 0.14, 1.2, (base + 0.87, y, z), c, rot_y(0), **NO_HIT)


def build_tunnel(m, g, base):
    half = 38
    z0, z1 = -44, 66
    block(m, g, "TunnelRoof", base - half, base + half, CLEAR, CLEAR + 3, -16, 40, (116, 90, 62), "Slate", attributes={"ObstacleHit": True})
    block(m, g, "TunnelMass", base - half, base + half, CLEAR + 3, CLEAR + 46, z0, z1, STRATA[2], "Sandstone")
    for a, b in ((z0, -30), (46, z1)):
        block(m, g, "TunnelSide", base - half, base + half, -40, CLEAR + 3, a, b, STRATA[4], "Sandstone")
    # The portal's cut-stone arch faces at each end, and rock over the top.
    for sx in (-1, 1):
        x = base + sx * half
        block(m, g, "PortalBlock", min(x, x + sx * 0.5), max(x, x + sx * 0.5), CLEAR - 1.4, CLEAR + 2.2, -30, 46, (150, 132, 108))
        for a in ((-31.6, -30), (46, 47.6)):
            block(m, g, "PortalJamb", min(x, x + sx * 0.8), max(x, x + sx * 0.8), 0, CLEAR, a[0], a[1], (142, 124, 100))
    for _ in range(6):
        sx = rng.choice((-1, 1))
        size = rng.uniform(6, 16)
        m.part(g, "TunnelRock", (size * 1.5, size, size * 1.3), (base + sx * half * rng.uniform(0.7, 1.05), CLEAR + rng.uniform(8, 42), rng.uniform(z0, z1)),
               jitter(rng.choice(STRATA), 9), rock_rows(18), Material="Sandstone", **NO_HIT)


def build_sign(m, g, base, zpole, zfar):
    """A trackside sign on an arm that sweeps along one train's outer half."""
    a, b = sorted((zpole, zfar))
    block(m, g, "PostFoot", base - 1.8, base + 1.8, -1, 0.5, zpole - 1.8, zpole + 1.8, (128, 124, 116), "Concrete")
    lattice_post(m, g, base, zpole, 0.5, ROOF + 12)
    block(m, g, "SignBoard", base - 0.5, base + 0.5, ROOF + 1, ROOF + 9, a, b, (222, 178, 58), "SmoothPlastic", attributes={"ObstacleHit": True})
    z = a + 0.5
    k = 0
    while z < b - 1:  # hazard stripes down the board
        if k % 2 == 0:
            block(m, g, "SignStripe", base + 0.52, base + 0.6, ROOF + 1.5, ROOF + 8.5, z, min(z + 2, b - 0.1), (32, 32, 34))
        z += 2.05
        k += 1
    block(m, g, "SignArm", base - 0.3, base + 0.3, ROOF + 9.04, ROOF + 10, a, b, (70, 74, 80), "Metal")


def build_obstacles(m):
    slot = 5  # built far along the line, where no one ever goes, waiting to be called
    for kind, count in POOLS.items():
        for n in range(1, count + 1):
            g, base = obstacle_folder(kind, n), slot * PARK
            slot += 1
            if kind == "Gantry":
                build_gantry(m, g, base)
            elif kind == "Tunnel":
                build_tunnel(m, g, base)
            elif kind == "SignA":
                build_sign(m, g, base, -20, -5.6)
            else:
                build_sign(m, g, base, 33, 19)


def build():
    m = Map(colors=COLORS, materials=MATERIALS)
    build_trains(m)
    build_chunks(m)
    build_obstacles(m)
    for x, z, y in SPAWNS:
        m.spawn(x, z, y)
    simple_materials(m)
    return m


def check(m):
    return mapcheck.check_map(m, ATTRIBUTES)


def persistent(group):
    path = os.path.join(OUT, f"{group}.model.json")
    node = json.load(open(path))
    node["className"] = "Model"
    node["properties"] = {"ModelStreamingMode": "Persistent"}
    with open(path, "w") as f:
        json.dump(node, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    for group in layout.groups:
        if group.startswith(("Scroll", "TrackB", "Obstacle_")) or group in ("TrainB", "RailB"):
            persistent(group)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
