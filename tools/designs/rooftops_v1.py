#!/usr/bin/env python3
"""Rooftop District, design v1 (design stage: not in the game yet). 8-12 players, sunny day.
Shown on the "Rooftop District" design canvas. Built with tools/maplib.py and checked with
tools/mapcheck.py like the real map generators, so it becomes tools/rooftops_layout.py once the
design is settled. Run from the repo root:
    python3 tools/designs/rooftops_v1.py           (checks only)
    python3 tools/designs/rooftops_v1.py --write   (writes src/maps/RooftopDistrict/)

Axes: X east, Z south, Y up. The street is far below and never playable: fall past KillHeight
(30) and you're out. Roofs sit on three tiers, 12 apart:
    LOW 40, MID 52, HIGH 64.
Nine buildings on a 200 x 200 block: a ring of eight round a central hub, with wide streets
between them (18-22 between ring neighbours, 38 round the hub) so the map stays open, with long
sight lines and room to run. Every gap has a way across in both directions, and most of them make
you use a move:
  same tier, too far to jump: billboard wall-runs (NE-E, SW-W), the duct bridge (slide under the
    duct), the swinging platform (hub-S), the billboard run and launch vent (hub-E), scaffold
    steps (W-hub).
  up a tier: fire escapes (NE->N, SW->S, W->NW), a plank to a ladder (N->NW, E->SE), a launch
    vent (S->SE), ladders onto the hub lookout.
  down a tier: jump the gap (every higher roof drops onto its lower neighbours).
"""
import math
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_x, rot_y, rot_z  # noqa: E402

OUT = "src/maps/RooftopDistrict"
LOW, MID, HIGH = 40, 52, 64
KILL = 30  # world Y: below this you're out
ATTRIBUTES = {"DisplayName": "Rooftop District", "MinPlayers": 8, "MaxPlayers": 12,
              "InRotation": True, "KillHeight": KILL, "OutOfBounds": "WaterTank,Duct"}

# Movement numbers the gaps are built round (Config + Roblox defaults).
GRAVITY = 196.2
JUMP = 7.2  # jump height
SPRINT = 30  # sprint speed
SLIDE_JUMP = 37  # the fastest you usually leave a roof (a slide into a jump)
ROOT = 3  # root part center above the feet
DRIVE = 0.08  # Config.Gadgets.LaunchDriveTime: launch velocity held before gravity takes over
WALL_RUN = 30 * 1.6  # studs along a wall in one wall run

# key: (x0, x1, z0, z1, roof, name, facade color, facade material)
BUILDINGS = {
    "NW": (-100, -52, -100, -52, HIGH, "Skyline Tower", (122, 168, 210), "Glass"),
    "N": (-34, 34, -100, -58, MID, "Glass Offices", (198, 202, 206), "Concrete"),
    "NE": (52, 100, -100, -52, LOW, "Warehouse", (168, 92, 70), "Brick"),
    "W": (-100, -58, -30, 30, LOW, "Billboard Block", (222, 192, 112), "Concrete"),
    "HUB": (-20, 20, -20, 20, MID, "Radio Hub", (232, 234, 238), "Concrete"),
    "E": (58, 100, -30, 30, LOW, "Depot", (186, 176, 156), "Metal"),
    "SW": (-100, -52, 52, 100, LOW, "Garden Flats", (160, 184, 150), "Plaster"),
    "S": (-34, 34, 58, 100, MID, "Apartments", (206, 124, 92), "Brick"),
    "SE": (52, 100, 52, 100, HIGH, "Hotel", (236, 222, 192), "Plaster"),
}
TIER_ROOF = {LOW: ((132, 130, 126), "Concrete"), MID: ((104, 120, 140), "Slate"),
             HIGH: ((214, 198, 158), "Sandstone")}
EDGE = 100  # the map's outer edge (glass barriers there)
POOL = (66, 90, 70, 88)  # the hotel's rooftop pool (x0, x1, z0, z1)

COLORS = {
    "steel": (110, 116, 126), "wood": (150, 112, 72), "duct": (170, 176, 186),
    "rail": (70, 74, 82), "pad": (255, 140, 40), "boost": (60, 200, 255), "puddle": (90, 170, 230),
    "glass": (190, 222, 240), "billboard": (40, 44, 52), "container_red": (190, 64, 52),
    "container_blue": (52, 102, 176), "planter": (120, 92, 70), "plant": (80, 160, 80),
    "ac": (196, 200, 204), "tank": (150, 110, 80), "coping": (226, 226, 220),
    "asphalt": (70, 72, 78), "sidewalk": (190, 188, 182), "brass": (198, 152, 82),
    "glow": (255, 150, 40),
}
MATERIALS = {"steel": "Metal", "wood": "WoodPlanks", "duct": "Metal", "rail": "Metal",
             "billboard": "Metal", "container_red": "CorrodedMetal",
             "container_blue": "CorrodedMetal", "planter": "Brick", "plant": "Grass", "ac": "Metal",
             "tank": "WoodPlanks", "asphalt": "Asphalt", "sidewalk": "Concrete", "brass": "Metal"}

# Crossings.
DUCT = (-40, -37)  # z range of the duct over the duct bridge
DUCT_UNDER = 4.2  # slide-height gap under it
STEPS = ((-52, -46, 44), (-40, -34, 48), (-28, -23, 52))  # W -> hub scaffold steps (x0, x1, top)
SWING_PIVOT = (0, 92, 39)
SWING_PERIOD = 5.0
SWING_R = 5  # the platform's radius
SWING_T = 1.5
_half_gap = (58 - 20) / 2
SWING_REACH = _half_gap - SWING_R - 0.5  # center's reach from the pivot at the end of a swing
_end_center_y = MID - 0.6 - SWING_T / 2
SWING_CHAIN = math.hypot(SWING_REACH, SWING_PIVOT[1] - _end_center_y)
SWING_AMPLITUDE = math.degrees(math.atan2(SWING_REACH, SWING_PIVOT[1] - _end_center_y))
LAUNCHES = {  # name: (pad center x, z, roof, target x, z, target roof)
    "DepotVent": (63, 0, LOW, 12, 0, MID),
    "ApartmentVent": (29, 80, MID, 60, 80, HIGH),
}


def launch_velocity(x0, z0, y0, x1, z1, y1, vy=85.0):
    """The launch that lands on (x1, z1) at roof y1, with the drive time held at full speed."""
    start = y0 + 0.6 + ROOT
    after_drive = start + vy * DRIVE
    land = y1 + ROOT
    a, b, c = GRAVITY / 2, -vy, land - after_drive
    t = (-b + math.sqrt(b * b - 4 * a * c)) / (2 * a) + DRIVE
    return ((x1 - x0) / t, vy, (z1 - z0) / t), t


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def ramp_x(m, g, name, z0, z1, xa, ya, xb, yb, color, thick=0.6, **props):
    """A slab whose top runs straight from (xa, ya) to (xb, yb) along X."""
    dx, dy = xb - xa, yb - ya
    ang = math.degrees(math.atan(dy / dx))
    a = math.radians(ang)
    normal = (-math.sin(a), math.cos(a), 0)
    mid = ((xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2)
    pos = tuple(mid[i] - 0.5 * thick * normal[i] for i in range(3))
    return m.part(g, name, (math.hypot(dx, dy), thick, z1 - z0), pos, color, rot_z(ang), **props)


def ramp_z(m, g, name, x0, x1, za, ya, zb, yb, color, thick=0.6, **props):
    """A slab whose top runs straight from (za, ya) to (zb, yb) along Z."""
    dz, dy = zb - za, yb - ya
    ang = math.degrees(math.atan(dy / -dz))
    a = math.radians(ang)
    normal = (0, math.cos(a), math.sin(a))
    mid = ((x0 + x1) / 2, (ya + yb) / 2, (za + zb) / 2)
    pos = tuple(mid[i] - 0.5 * thick * normal[i] for i in range(3))
    return m.part(g, name, (x1 - x0, thick, math.hypot(dz, dy)), pos, color, rot_x(ang), **props)


# ---- buildings --------------------------------------------------------------------------------

def building(m, key):
    x0, x1, z0, z1, roof, name, color, material = BUILDINGS[key]
    g = "Buildings"
    roof_color, roof_material = TIER_ROOF[roof]
    if key == "SE":  # the hotel: a deeper roof layer with the pool cut into it
        m.block(g, key + "Body", x0, x1, 0, roof - 2.5, z0, z1, color, Material=material)
        m.slab("Roofs", key + "Roof", (x0, x1, z0, z1), roof - 2.5, roof, [POOL], roof_color,
               Material=roof_material)
    else:
        m.block(g, key + "Body", x0, x1, 0, roof - 0.5, z0, z1, color, Material=material)
        m.block("Roofs", key + "Roof", x0, x1, roof - 0.5, roof, z0, z1, roof_color,
                Material=roof_material)
    # Coping round the roof edge (four strips that meet at the corners without overlapping) and
    # window bands on every face (decoration).
    d = "Facades"
    for bx0, bx1, bz0, bz1 in ((x0, x1, z0, z0 + 0.6), (x0, x1, z1 - 0.6, z1),
                               (x0, x0 + 0.6, z0 + 0.6, z1 - 0.6), (x1 - 0.6, x1, z0 + 0.6, z1 - 0.6)):
        m.block(d, "Coping", bx0, bx1, roof, roof + 0.25, bz0, bz1, "coping", **NO_HIT)
    band = (55, 75, 100) if material == "Glass" else (150, 190, 225)
    y = 6
    while y < roof - 5:
        for bx0, bx1, bz0, bz1 in ((x0 + 1, x1 - 1, z0 - 0.15, z0), (x0 + 1, x1 - 1, z1, z1 + 0.15),
                                   (x0 - 0.15, x0, z0 + 1, z1 - 1), (x1, x1 + 0.15, z0 + 1, z1 - 1)):
            m.block(d, "Windows", bx0, bx1, y, y + 2.4, bz0, bz1, band, Material="Glass", **NO_HIT)
        y += 6
    # Glass barriers on the map's outer edges, so nobody runs off the world by accident.
    b = "Barriers"
    glass = {"Material": "Glass", "Transparency": 0.6, "CastShadow": False}
    # (Just inside the coping; the ones along Z stop at the ones along X, so none overlap.)
    za = z0 + (1.1 if z0 == -EDGE else 0.6)
    zb = z1 - (1.1 if z1 == EDGE else 0.6)
    if x0 == -EDGE:
        m.block(b, "GlassBarrier", x0 + 0.6, x0 + 1.1, roof, roof + 5.5, za, zb, "glass", **glass)
    if x1 == EDGE:
        m.block(b, "GlassBarrier", x1 - 1.1, x1 - 0.6, roof, roof + 5.5, za, zb, "glass", **glass)
    if z0 == -EDGE:
        m.block(b, "GlassBarrier", x0 + 0.6, x1 - 0.6, roof, roof + 5.5, z0 + 0.6, z0 + 1.1,
                "glass", **glass)
    if z1 == EDGE:
        m.block(b, "GlassBarrier", x0 + 0.6, x1 - 0.6, roof, roof + 5.5, z1 - 1.1, z1 - 0.6,
                "glass", **glass)


def billboard(m, g, x0, x1, y0, y1, z0, z1, text, color):
    """A billboard: a solid sign (wall-run along it) with an ad on both faces."""
    along_x = (x1 - x0) > (z1 - z0)
    faces = ("Front", "Back") if along_x else ("Left", "Right")
    m.block(g, "Billboard", x0, x1, y0, y1, z0, z1, "billboard",
            children=[m.surface_text(f, text, (255, 255, 255), background=color, pps=8)
                      for f in faces])


# ---- crossings ---------------------------------------------------------------------------------

def crossings(m):
    g = "Crossings"
    # 1. Duct bridge, hub <-> Glass Offices (52): a girder with a duct across it at slide height.
    m.block(g, "Girder", -3, 3, MID - 1, MID, -58, -20, "steel")
    m.block(g, "GirderWeb", -0.4, 0.4, MID - 3, MID - 1, -58, -20, "steel", **NO_HIT)
    m.block(g, "Duct", -7, 7, MID + DUCT_UNDER, MID + DUCT_UNDER + 3.4, DUCT[0], DUCT[1], "duct")
    m.block(g, "StandBlocker", -3.2, 3.2, MID, MID + DUCT_UNDER, DUCT[0], DUCT[1], (255, 255, 255),
            Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
    for x in (-7.5, 7.5):
        m.block(g, "DuctPost", x - 0.5, x + 0.5, 0, MID + DUCT_UNDER + 3.4, DUCT[0] + 1,
                DUCT[1] - 1, "steel", **NO_HIT)

    # 2. Billboard run, hub -> Depot: wall-run down along a billboard (either side).
    for z, text, color in ((-8, "TAG CITY", (220, 60, 70)), (8, "RUN!", (40, 120, 220))):
        billboard(m, g, 22, 56, 42, 58, z - 0.3, z + 0.3, text, color)
        for x in (26, 52):
            m.block(g, "SignPost", x - 0.4, x + 0.4, 0, 42, z - 0.4, z + 0.4, "steel", **NO_HIT)

    # 3/13. Launch vents: Depot -> hub, Apartments -> Hotel.
    for name, (px, pz, roof, tx, tz, troof) in LAUNCHES.items():
        velocity, _ = launch_velocity(px, pz, roof, tx, tz, troof)
        m.block(g, name, px - 2, px + 2, roof, roof + 0.6, pz - 2, pz + 2, "pad", Material="Neon",
                attributes={"LaunchVelocity": vec(*velocity)})
        m.block(g, "VentGrille", px - 2.4, px + 2.4, roof, roof + 0.4, pz - 2.4, pz + 2.4, "rail",
                **NO_HIT)

    # 4. The swing, hub <-> Apartments (both 52): a level platform on a chain swinging along Z,
    # pausing just below each roof's edge. Hung from a gantry over the street.
    px, py, pz = SWING_PIVOT
    swing = {"SwingPivot": vec(px, py, pz), "SwingAxis": vec(1, 0, 0),
             "SwingAmplitude": round(SWING_AMPLITUDE, 3), "SwingPeriod": SWING_PERIOD}
    level = dict(swing, SwingLevel=True)
    ride = dict(level, Carry=True)
    low_center = py - SWING_CHAIN
    top = low_center + SWING_T / 2
    links = int((py - top - 1) // 2.2)
    for i in range(links):
        m.part(g, "ChainLink", (0.5, 2.5, 1.3), (px, top + 1.4 + i * 2.2, pz), "rail",
               rot_y(90 * (i % 2)), attributes=swing, **NO_HIT)
    m.cylinder(g, "SwingPlatform", SWING_T, 2 * SWING_R, (px, low_center, pz), "brass",
               attributes=ride)
    m.cylinder(g, "SwingRim", 0.3, 2 * SWING_R + 0.6, (px, top - 0.25, pz), "glow",
               Material="Neon", attributes=level, **NO_HIT)
    for z in (15, 63):  # the gantry: posts on both roofs, a beam over the street
        for x in (-9, 9):
            m.block(g, "GantryPost", x - 0.6, x + 0.6, MID, py + 1, z - 0.6, z + 0.6, "steel")
        m.block(g, "GantryBeam", -9.6, 9.6, py + 1, py + 2.4, z - 0.6, z + 0.6, "steel", **NO_HIT)
    m.block(g, "GantryBeam", -0.7, 0.7, py - 0.2, py + 1, 15.6, 62.4, "steel", **NO_HIT)

    # 5. Scaffold steps, Billboard Block <-> hub: platforms 4 up at a time.
    for x0, x1, step_top in STEPS:
        m.block(g, "Step", x0, x1, step_top - 1, step_top, -4, 4, "wood")
        for x in (x0 + 0.4, x1 - 0.4):
            for z in (-3.6, 3.6):
                m.block(g, "ScaffoldPole", x - 0.2, x + 0.2, 0, step_top - 1, z - 0.2, z + 0.2,
                        "steel", **NO_HIT)

    # 6/7. Billboard alleys (low tier, 22 across): wall-run along either billboard.
    for x, text, color in ((64, "FIZZ", (240, 120, 40)), (94, "SKY HIGH", (90, 60, 200))):
        billboard(m, g, x - 0.3, x + 0.3, 36, 54, -55, -27, text, color)
    for x, text, color in ((-94, "BOUNCE", (40, 170, 120)), (-64, "TOP DECK", (220, 70, 140))):
        billboard(m, g, x - 0.3, x + 0.3, 36, 54, 27, 55, text, color)
    for x, z0, z1 in ((64, -55, -27), (94, -55, -27), (-94, 27, 55), (-64, 27, 55)):
        for z in (z0 + 4, z1 - 4):
            m.block(g, "SignPost", x - 0.4, x + 0.4, 0, 36, z - 0.4, z + 0.4, "steel", **NO_HIT)
    # Speed strips leading into one lane of each alley.
    m.block(g, "SpeedStrip", 64.5, 69, LOW, LOW + 0.15, -72, -53, "boost", Material="Neon",
            attributes={"SpeedBoost": 42})
    m.block(g, "SpeedStrip", -63.4, -59, LOW, LOW + 0.15, 53, 68, "boost", Material="Neon",
            attributes={"SpeedBoost": 42})

    # 8. Fire escape, Warehouse (40) -> Glass Offices (52), on the offices' east wall.
    m.block(g, "Plank", 40, 52, LOW - 1, LOW, -64, -60, "wood")
    m.block(g, "Landing", 34, 40, LOW - 1, LOW, -64, -60, "steel")
    ramp_z(m, g, "FireEscape", 35, 39, -64, LOW, -86, MID, "steel")
    m.block(g, "Landing", 34, 40, MID - 1, MID, -90, -86, "steel")
    m.block(g, "Handrail", 40, 40.2, LOW, MID + 3, -90, -60, "rail", **NO_HIT)
    # 9. Fire escape, Garden Flats (40) -> Apartments (52), on the apartments' west wall.
    m.block(g, "Plank", -52, -40, LOW - 1, LOW, 90, 94, "wood")
    m.block(g, "Landing", -40, -34, LOW - 1, LOW, 90, 94, "steel")
    ramp_z(m, g, "FireEscape", -39, -35, 90, LOW, 68, MID, "steel")
    m.block(g, "Landing", -40, -34, MID - 1, MID, 64, 68, "steel")
    m.block(g, "Handrail", -40.2, -40, LOW, MID + 3, 64, 94, "rail", **NO_HIT)
    # 10. Fire escape, Billboard Block (40) -> Skyline Tower (64): two flights up its south wall.
    m.block(g, "Plank", -94, -90, LOW - 1, LOW, -44, -30, "wood")
    m.block(g, "Landing", -94, -90, LOW - 1, LOW, -48, -44, "steel")
    ramp_x(m, g, "FireEscape", -47.5, -44.5, -90, LOW, -68, MID, "steel")
    m.block(g, "Landing", -68, -64, MID - 1, MID, -52, -44, "steel")
    ramp_x(m, g, "FireEscape", -51.5, -48.5, -68, MID, -90, HIGH, "steel")
    m.block(g, "Landing", -94, -90, HIGH - 1, HIGH, -52, -48, "steel")
    m.block(g, "Handrail", -94, -64, LOW, HIGH + 3, -44, -43.8, "rail", **NO_HIT)

    # 11. Plank to a ladder, Glass Offices (52) -> Skyline Tower (64).
    m.block(g, "Plank", -52, -34, MID - 1, MID, -84, -80, "wood")
    m.ladder(g, -52, -82, (1, 0), MID, HIGH)
    # 12. Plank to a ladder, Depot (40) -> Hotel (64): 24 up the hotel's wall.
    m.block(g, "Plank", 78, 82, LOW - 1, LOW, 30, 52, "wood")
    m.ladder(g, 80, 52, (0, -1), LOW, HIGH)


# ---- roofs ------------------------------------------------------------------------------------

def puddle(m, g, x, z, y, size=8):
    """Three overlapping discs at slightly different heights (level overlaps flicker):
    decoration, you run straight through."""
    wet = {"Material": "Glass", "Transparency": 0.35, "Reflectance": 0.15, **NO_HIT}
    for layer, (dx, dz, k) in enumerate(((0, 0, 1), (size * 0.35, size * 0.17, 0.6),
                                         (-size * 0.37, -size * 0.13, 0.5))):
        m.cylinder(g, "Puddle", 0.12, size * k, (x + dx, y + 0.06 + layer * 0.05, z + dz),
                   "puddle", **wet)


def ac_unit(m, g, x0, x1, z0, z1, roof):
    m.block(g, "ACUnit", x0, x1, roof, roof + 3.5, z0, z1, "ac")
    m.cylinder(g, "ACFan", 0.1, min(x1 - x0, z1 - z0) - 0.8,
               ((x0 + x1) / 2, roof + 3.55, (z0 + z1) / 2), "rail",
               attributes={"Spin": 240}, **NO_HIT)


def roofs(m):
    g = "RoofProps"
    # Skyline Tower (64): helipad, stair house (a ladder up it), AC units.
    m.cylinder(g, "Helipad", 0.08, 18, (-80, HIGH + 0.04, -80), (60, 64, 70), **NO_HIT)
    for x0, x1, z0, z1 in ((-84, -83, -84, -76), (-77, -76, -84, -76), (-83, -77, -80.5, -79.5)):
        m.block(g, "HelipadH", x0, x1, HIGH + 0.08, HIGH + 0.14, z0, z1, (245, 245, 245), **NO_HIT)
    m.block(g, "StairHouse", -70, -62, HIGH, HIGH + 9, -70, -62, (110, 150, 190))
    m.ladder(g, -66, -62, (0, 1), HIGH, HIGH + 9)
    ac_unit(m, g, -92, -88, -94, -90, HIGH)
    ac_unit(m, g, -66, -62, -96, -92, HIGH)
    # Glass Offices (52): skylights to jump, AC units.
    for x0, x1 in ((-22, -8), (8, 22)):
        m.block(g, "Skylight", x0, x1, MID, MID + 2.5, -82, -78, "glass", Material="Glass",
                Transparency=0.3)
    ac_unit(m, g, -28, -24, -96, -92, MID)
    ac_unit(m, g, 22, 26, -72, -68, MID)
    # Warehouse (40): stacked crates (jump up them), a skylight, a rain puddle.
    m.block(g, "Crate", 84, 90, LOW, LOW + 3.5, -76, -70, "wood")
    m.block(g, "Crate", 85, 89, LOW + 3.5, LOW + 7, -75, -71, "wood")
    m.block(g, "Skylight", 72, 86, LOW, LOW + 2.5, -96, -92, "glass", Material="Glass",
            Transparency=0.3)
    puddle(m, g, 76, -84, LOW)
    # Depot (40): shipping containers (ladders up them; wall-run along them), a crate.
    m.block(g, "Container", 80, 88, LOW, LOW + 8.5, -24, -8, "container_red")
    m.block(g, "Container", 80, 88, LOW, LOW + 8.5, 8, 24, "container_blue")
    for z in (-16, 16):
        m.ladder(g, 80, z, (-1, 0), LOW, LOW + 8.5)
    m.block(g, "Crate", 70, 74, LOW, LOW + 3.5, -20, -16, "wood")
    # Hotel (64): the pool (a shallow pit to run through), loungers to jump, a cabana, sign.
    x0, x1, z0, z1 = POOL
    m.block(g, "PoolFloor", x0, x1, HIGH - 2.5, HIGH - 2.4, z0, z1, "puddle", Material="Glass",
            Transparency=0.2, **NO_HIT)
    m.block(g, "PoolWater", x0, x1, HIGH - 0.4, HIGH - 0.3, z0, z1, (80, 180, 235),
            Material="Glass", Transparency=0.55, **NO_HIT)
    for x in (70, 76, 82, 88):
        m.block(g, "Lounger", x - 1, x + 1, HIGH, HIGH + 1.4, 92, 96, (250, 250, 245))
    m.block(g, "Cabana", 92, 98, HIGH, HIGH + 5, 70, 80, (240, 200, 120))
    m.block(g, "HotelSign", 84, 98, HIGH + 1, HIGH + 7, 52.3, 52.6, (40, 40, 48), **NO_HIT,
            children=[m.surface_text(f, "HOTEL", (255, 210, 120), glow=True, pps=10)
                      for f in ("Front", "Back")])
    # Apartments (52): water towers (slide under the tank between its legs), AC units.
    for tx, tz in ((-14, 80), (12, 76)):
        for dx in (-3, 3):
            for dz in (-3, 3):
                m.block(g, "TowerLeg", tx + dx - 0.4, tx + dx + 0.4, MID, MID + DUCT_UNDER,
                        tz + dz - 0.4, tz + dz + 0.4, "steel")
        m.cylinder(g, "WaterTank", 8, 8, (tx, MID + DUCT_UNDER + 4, tz), "tank")
        m.block(g, "StandBlocker", tx - 2.6, tx + 2.6, MID, MID + DUCT_UNDER, tz - 2.6, tz + 2.6,
                (255, 255, 255), Transparency=1, CastShadow=False,
                attributes={"SlideBlocker": True})
    ac_unit(m, g, -30, -26, 92, 96, MID)
    for z in (88, 92):  # laundry lines (decoration)
        m.block(g, "Line", 0, 20, MID + 6, MID + 6.05, z - 0.03, z + 0.03, (240, 240, 240),
                **NO_HIT)
        for i, x in enumerate(range(2, 19, 4)):
            m.block(g, "Laundry", x, x + 2, MID + 4, MID + 6, z - 0.05, z + 0.05,
                    ((230, 90, 90), (90, 150, 230), (250, 220, 90), (120, 200, 120))[i % 4],
                    **NO_HIT)
    # Garden Flats (40): planters and a low greenhouse to jump.
    for z in (69, 83):
        for x0, x1 in ((-94, -80), (-72, -58)):
            m.block(g, "Planter", x0, x1, LOW, LOW + 3, z, z + 2.5, "planter")
            m.block(g, "Plants", x0 + 0.3, x1 - 0.3, LOW + 3, LOW + 3.8, z + 0.3, z + 2.2, "plant",
                    **NO_HIT)
    m.block(g, "Greenhouse", -96, -84, LOW, LOW + 5, 88, 98, "glass", Material="Glass",
            Transparency=0.4)
    # Billboard Block (40): a rooftop billboard (wall-run along it), AC units.
    billboard(m, g, -90.3, -89.7, LOW, LOW + 12, -22, 8, "GO FAST", (250, 180, 40))
    ac_unit(m, g, -72, -68, -24, -20, LOW)
    ac_unit(m, g, -70, -66, 16, 20, LOW)
    # The hub (52): the lookout in the middle (ladders up two sides), AC units in the corners,
    # the radio mast with a turning radar dish.
    m.block(g, "Lookout", -7, 7, MID, HIGH - 0.5, -7, 7, (232, 234, 238))
    m.block(g, "LookoutTop", -7, 7, HIGH - 0.5, HIGH, -7, 7, TIER_ROOF[HIGH][0],
            Material=TIER_ROOF[HIGH][1])
    m.ladder(g, -7, 0, (-1, 0), MID, HIGH)
    m.ladder(g, 0, -7, (0, -1), MID, HIGH)
    for sx in (-1, 1):
        for sz in (-1, 1):
            ac_unit(m, g, sx * 14 - (4 if sx < 0 else 0), sx * 14 + (0 if sx < 0 else 4),
                    sz * 14 - (4 if sz < 0 else 0), sz * 14 + (0 if sz < 0 else 4), MID)
            m.block(g, "MastLeg", sx * 1.5 - 0.15, sx * 1.5 + 0.15, HIGH, HIGH + 36, sz * 1.5 - 0.15,
                    sz * 1.5 + 0.15, (200, 60, 60), **NO_HIT)
    for y in range(HIGH + 6, HIGH + 36, 6):
        m.block(g, "MastBar", -1.8, 1.8, y, y + 0.25, -1.8, 1.8, (200, 60, 60), **NO_HIT)
    m.block(g, "MastLight", -0.5, 0.5, HIGH + 36, HIGH + 37, -0.5, 0.5, (255, 60, 60),
            Material="Neon", **NO_HIT)
    m.part(g, "RadarDish", (6, 0.3, 2), (0, HIGH + 30.5, 0), (235, 235, 240),
           attributes={"Spin": 60, "SpinCenter": vec(0, 0, 0)}, **NO_HIT)


# ---- the street far below (decoration) ---------------------------------------------------------

def street(m):
    g = "Street"
    m.block(g, "Asphalt", -170, 170, -1, 0, -170, 170, "asphalt")
    for key, (x0, x1, z0, z1, *_rest) in BUILDINGS.items():
        m.block(g, "Sidewalk", x0 - 4, x1 + 4, 0, 0.3, z0 - 4, z1 + 4, "sidewalk", **NO_HIT)
    for c in (-41, 41):  # road lines, broken where they cross
        for a, b in ((-158, -41.3), (-40.7, 40.7), (41.3, 158.3)):
            m.block(g, "RoadLine", c - 0.3, c + 0.3, 0.02, 0.08, a, b, (240, 200, 60), **NO_HIT)
            m.block(g, "RoadLine", a, b, 0.02, 0.08, c - 0.3, c + 0.3, (240, 200, 60), **NO_HIT)
    cars = ((-41.0, -120, 0), (-41, 10, 0), (41, -80, 0), (41, 70, 0), (-120, -41, 90),
            (10, -41, 90), (90, 41, 90), (-70, 41, 90), (37, -10, 0), (-37, 30, 0),
            (-10, 37, 90), (25, -37, 90), (130, 41, 90), (-41, 130, 0))
    palette = ((220, 60, 60), (60, 120, 220), (240, 200, 60), (245, 245, 245), (40, 40, 44),
               (80, 180, 100))
    for i, (x, z, turn) in enumerate(cars):
        rows = rot_y(turn)
        m.part(g, "Car", (4.4, 2, 9), (x, 1.3, z), palette[i % len(palette)], rows, **NO_HIT)
        m.part(g, "CarCabin", (4, 1.6, 5), (x, 3.1, z), (60, 70, 80), rows, **NO_HIT)
    for x, z in ((-28, -28), (28, -28), (-28, 28), (28, 28), (-28, 0), (28, 0), (0, -28),
                 (0, 28)):
        m.cylinder(g, "TreeTrunk", 5, 1, (x, 2.5, z), (110, 80, 50), **NO_HIT)
        m.part(g, "TreeTop", (7, 7, 7), (x, 7.5, z), "plant", Shape="Ball", **NO_HIT)
    # The rest of the city round the block, too far to reach.
    for i, (x, z, w, d, h) in enumerate((
        (-150, -140, 30, 30, 70), (-140, -60, 24, 40, 50), (-150, 30, 30, 30, 90),
        (-140, 120, 34, 30, 45), (-60, 150, 40, 24, 60), (40, 145, 30, 30, 100),
        (130, 140, 36, 36, 55), (150, 50, 28, 40, 75), (145, -40, 30, 30, 45),
        (140, -130, 36, 30, 110), (50, -150, 40, 24, 65), (-40, -150, 30, 28, 85),
    )):
        color = ((210, 196, 170), (170, 190, 210), (200, 170, 160), (180, 200, 180))[i % 4]
        m.block("City", "CityBlock", x - w / 2, x + w / 2, 0, h, z - d / 2, z + d / 2, color,
                Material="Concrete", **NO_HIT)


SPAWNS = (  # x, z, roof
    (-80, -80, HIGH), (-14, -70, MID), (16, -90, MID), (92, -88, LOW), (-76, 0, LOW),
    (-12, -11, MID), (-12, 11, MID), (72, 4, LOW), (-76, 78, LOW), (-22, 92, MID), (20, 92, MID),
    (60, 94, HIGH),
)


def build():
    m = Map(COLORS, MATERIALS)
    for key in BUILDINGS:
        building(m, key)
    crossings(m)
    roofs(m)
    street(m)
    for x, z, y in SPAWNS:
        m.spawn(x, z, y)
    return m


# ---- the design canvas (labels, numbered routes, camera views) ----------------------------------

def _label(text, x, y, z, kind="zone"):
    return {"t": text, "x": x, "y": y, "z": z, "f": 1, "k": kind}


def _marker(n, title, text, x, y, z):
    return {"n": n, "t": title, "d": text, "x": x, "y": y, "z": z, "f": 1}


CANVAS = {
    "label": "Design v1.2 (flush ladders, no slipping)",
    "labels": [_label(f"{b[5]} · {b[4]}", (b[0] + b[1]) / 2, b[4] + 7, (b[2] + b[3]) / 2)
               for b in BUILDINGS.values()] + [
        _label("Pool", 78, 66, 79, "feature"),
        _label("Water towers: slide under", 0, 63, 78, "feature"),
        _label("Helipad", -80, 66, -86, "feature"), _label("Containers", 84, 51, 0, "feature")],
    "markers": [
        _marker(1, "Duct bridge", "Glass Offices ↔ Radio Hub, both at 52. A girder bridge with a duct "
                "across it at 4.2: slide or crouch under it. You can't walk under it upright or jump "
                "over it.", 0, 58, -39),
        _marker(2, "Billboard run", "Radio Hub → Depot. Jump off the hub's east edge beside either "
                "billboard and wall-run down to the Depot, 12 lower.", 39, 60, 0),
        _marker(3, "Depot launch vent", "Depot → Radio Hub. A vent that throws you 12 up and about 50 "
                "across onto the hub.", 63, 44, 0),
        _marker(4, "The swing", "Radio Hub ↔ Apartments, both at 52. A platform swinging across the "
                "street that pauses just below each roof edge every 2.5 seconds: step on, ride, step "
                "off.", 0, 56, 39),
        _marker(5, "Scaffold steps", "Billboard Block (40) ↔ Radio Hub (52): three platforms, 4 up "
                "each and 6 apart. Hop up or down.", -40, 54, 0),
        _marker(6, "East billboard alley", "Warehouse ↔ Depot, both at 40 and 22 apart: too far to "
                "jump, so wall-run along either billboard. A speed strip on the Warehouse feeds the "
                "west lane.", 79, 56, -41),
        _marker(7, "West billboard alley", "Garden Flats ↔ Billboard Block, both at 40 and 22 apart: "
                "wall-run along either billboard. A speed strip on the Garden Flats feeds the east "
                "lane.", -79, 56, 41),
        _marker(8, "Warehouse fire escape", "Warehouse (40) → Glass Offices (52): walk the plank, run "
                "up the fire escape.", 37, 48, -75),
        _marker(9, "Garden fire escape", "Garden Flats (40) → Apartments (52): walk the plank, run up "
                "the fire escape.", -37, 48, 79),
        _marker(10, "Tower fire escape", "Billboard Block (40) → Skyline Tower (64): a plank, then two "
                "flights up the tower's south wall.", -79, 58, -48),
        _marker(11, "Tower ladder", "Glass Offices (52) → Skyline Tower (64): walk the plank to the "
                "ladder on the tower's wall and climb 12.", -43, 58, -82),
        _marker(12, "Hotel ladder", "Depot (40) → Hotel (64): walk the plank to the ladder on the "
                "hotel's wall and climb 24.", 80, 50, 41),
        _marker(13, "Apartment launch vent", "Apartments (52) → Hotel (64): a vent that throws you onto "
                "the hotel roof, short of the pool.", 29, 58, 80),
        _marker(14, "Lookout", "The high ground in the middle of the hub: ladders up its west and "
                "north sides (12). You can see the whole map from here.", 0, 69, 0),
        _marker(15, "Drop-offs", "Every higher roof drops onto its lower neighbours: jump the 18-22 "
                "gap. Drops only go down.", -43, 62, -62),
        _marker(16, "Fall line", "Below 30 you're out. Edges inside the map are open; only the map's "
                "outer edge has glass.", -41, 31, 0),
    ],
    "views": {"Overview": [200, 185, 230, 0, 40, 0], "Top": [0, 360, 0.01, 0, 0, 0],
              "Hub": [44, 82, 44, 0, 52, 0], "North": [0, 100, 10, 0, 50, -78],
              "East": [10, 95, 0, 80, 44, 0], "South": [0, 100, -10, 0, 50, 78],
              "West": [-10, 95, 0, -80, 44, 0], "From the street": [-39, 6, -39, 0, 50, 0]},
    "figure": [10, 52, -9],
}


# ---- checks -----------------------------------------------------------------------------------

def jump_reach(drop, speed=SPRINT):
    """How far a running jump carries you before your feet fall `drop` below takeoff."""
    up = math.sqrt(2 * GRAVITY * JUMP)
    t = (up + math.sqrt(up * up + 2 * GRAVITY * drop)) / GRAVITY
    return speed * t


def check(m):
    problems = []
    # Same-tier gaps must be too far to just jump (so they need the move), and every drop down a
    # tier must be in reach of a sprinting jump.
    flat = jump_reach(0, SLIDE_JUMP)
    for label, gap in (("NE-E alley", 22), ("SW-W alley", 22), ("hub-N", 38), ("hub-S", 38)):
        if gap <= flat:
            problems.append(f"{label} ({gap}) can be jumped flat ({flat:.1f})")
        if gap > WALL_RUN and "alley" in label:
            problems.append(f"{label} is longer than a wall run")
    for label, gap, drop in (("Skyline Tower -> Glass Offices", 18, 12),
                             ("Glass Offices -> Warehouse", 18, 12),
                             ("Hotel -> Apartments", 18, 12), ("Apartments -> Garden Flats", 18, 12),
                             ("Skyline Tower -> Billboard Block", 22, 24),
                             ("Hotel -> Depot", 22, 24)):
        reach = jump_reach(drop)
        if gap > reach - 2:
            problems.append(f"{label}: a {gap} gap down {drop} is out of reach ({reach:.1f})")
    # Scaffold steps: each a short hop up.
    edges = [(-58, LOW)] + [(x1, top) for _, x1, top in STEPS]
    starts = [x0 for x0, _, _ in STEPS] + [-20]
    tops = [top for _, _, top in STEPS] + [MID]
    for (edge, y_from), start, y_to in zip(edges, starts, tops):
        if start - edge > 8 or y_to - y_from > 4.5:
            problems.append(f"scaffold step at {start}: gap {start - edge}, rise {y_to - y_from}")
    # The swing pauses just below both roofs.
    end_top = SWING_PIVOT[1] - SWING_CHAIN * math.cos(math.radians(SWING_AMPLITUDE)) + SWING_T / 2
    if not 0 < MID - end_top < 1.5:
        problems.append(f"the swing's ends are {MID - end_top:.2f} below the roofs")
    if len(m.spawns) < ATTRIBUTES["MaxPlayers"]:
        problems.append("not enough spawns")
    # Flicker, windows, reach (and back). Wall runs are the routes it can't work out itself.
    runs = []
    for x in (65.6, 92.4):  # Warehouse <-> Depot alley, both lanes
        runs.append(((x, LOW, -54), (x, LOW, -28), True))
    for x in (-62.4, -95.6):  # Garden Flats <-> Billboard Block alley
        runs.append(((x, LOW, 54), (x, LOW, 28), True))
    for z in (-6.5, 6.5):  # hub -> Depot billboard run
        runs.append(((19, MID, z), (61, LOW, z), False))
    return problems + mapcheck.check_map(m, ATTRIBUTES, routes=runs)


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    if "--write" in sys.argv:
        os.chdir(REPO)
        layout.write(OUT, ATTRIBUTES)
        print(f"wrote {OUT}/")
    raise SystemExit(1 if issues else 0)
