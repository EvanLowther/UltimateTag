#!/usr/bin/env python3
"""The Clocktower (the smallest map, 2-4 players): a round tower interior with four levels,
designed on the "Clocktower Map Rework" canvas (rework v1). Run from the repo root:
    python3 tools/clocktower_layout.py
It rewrites `src/maps/Clocktower/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south, Y up, the tower's center on the origin.
  THE PIT (0): the round pit (radius 28) with three spinning brass gears you ride (5 -> 10 -> 15,
    then mantle onto the gallery), and the escapement in the middle: a brass drum (7 high) to loop
    round or mantle onto, and its drive shaft out to the wall at 290 degrees, 4.2 off the floor:
    slide or crouch under it (a SlideBlocker stops standing players), or jump it.
  THE WORKS (0): the ring under the gallery (radius 30-40), behind the pit wall. Four doorways
    from the pit, counterweights hanging overhead, crates, and two spiral ramps that climb along
    the outer wall up through the gallery floor (90 -> 161 and 270 -> 341 degrees).
  THE GALLERY (24): the ring (radius 28-40) under the curved tower wall. The pendulum is a wide
    level platform on a long chain that swings across the pit and pauses just below the gallery's
    edge on opposite sides: step on, ride across, step off. Railings over the ramp openings (vault
    them to drop onto a ramp), two crates, and two flights of stairs up the tower wall.
  THE CLOCK DECK (40): a ring catwalk round the tower wall under the big clock face, and the crown
    wheel: a giant ring gear turning slowly inside it (8 degrees a second). Jump on from the deck
    and ride it round; drop off its rim onto the gallery, or into the pit through one of its gaps.
Moving parts are animated on each client from the server clock (client/MapAmbience: Spin,
SpinCarry, Swing, SwingLevel, Carry attributes). The curved walls are wall-runnable all round.
"""
import math
import sys

sys.path.insert(0, "tools")
from maplib import NO_HIT, Map, facing_out, matmul, polar, rot_y, rot_z  # noqa: E402

OUT = "src/maps/Clocktower"
ATTRIBUTES = {"DisplayName": "The Clocktower", "MinPlayers": 2, "MaxPlayers": 4,
              "InRotation": True, "Lighting": "Indoor"}
SEGMENTS = 48
SEG = 360 / SEGMENTS
PIT_R = 28  # floor 1 radius (the pit wall's inner face)
OUTER_R = 40  # the tower wall's inner face
FLOOR2 = 24  # gallery height
DECK = 40  # clock deck height
TOP = 58  # ceiling
WALL = 2
DOOR_TOP = 10

PIVOT = (0, TOP - 2, 0)
SWING_DIR = 65  # degrees: the pendulum swings along this line (between the gears)
SWING_PERIOD = 5.6  # seconds for a full there-and-back
PLATFORM_R = 6  # the pendulum's platform (12 across)
PLATFORM_T = 1.5
END_REACH = PIT_R - PLATFORM_R - 0.5  # platform center this far out at the end of a swing
END_TOP = FLOOR2 - 0.6  # platform top at the end of a swing: just below the gallery floor
# The chain length and swing angle that put the platform there.
_END_CENTER_Y = END_TOP - PLATFORM_T / 2
CHAIN = math.hypot(END_REACH, PIVOT[1] - _END_CENTER_Y)
SWING_AMPLITUDE = math.degrees(math.atan2(END_REACH, PIVOT[1] - _END_CENTER_Y))
LOW_CENTER_Y = PIVOT[1] - CHAIN  # platform center at the bottom of the swing

GEAR_R = 7
GEAR_RING = 18.5  # gear centers this far from the middle
GEARS = ((20, 5, 22), (110, 10, -22), (200, 15, 22))  # angle, top, spin

DRUM_R, DRUM_TOP = 5, 7  # the escapement drum in the middle of the pit
SHAFT_DEG, SHAFT_UNDER, SHAFT_D = 290, 4.2, 1.6  # its drive shaft (slide under it)

DOORWAYS = (63.75, 153.75, 243.75, 333.75)  # pit wall doorways (two wall panels each)
RAMP_IN, RAMP_OUT = 34.5, 39.5
RAMPS = ((90, 161.25), (270, 341.25))  # floor -> gallery, rising with the angle
STAIR_IN, STAIR_OUT = 35.5, 39.5
STAIRS = ((18.75, 63.75), (198.75, 243.75))  # gallery -> deck
DECK_IN = 32
WHEEL_IN, WHEEL_OUT = 18, 29
WHEEL_SEGMENTS = 24
WHEEL_GAPS = (0, 8, 16)  # missing segments (fall through)
WHEEL_SPIN = 8  # degrees per second

COLORS = {
    "stone": (204, 206, 214), "stone_dark": (150, 153, 164), "floor": (172, 174, 184),
    "brass": (198, 152, 82), "brass_dark": (150, 110, 55), "iron": (88, 90, 100),
    "glow": (255, 150, 40), "blue": (80, 200, 255), "face": (246, 245, 238),
    "ink": (40, 40, 48), "wood": (150, 110, 70), "light": (255, 214, 160),
    "works_floor": (118, 112, 106), "ramp": (128, 96, 66), "hazard": (250, 200, 40),
}
MATERIALS = {
    "stone": "Plaster", "stone_dark": "Concrete", "floor": "Slate", "brass": "Metal",
    "brass_dark": "Metal", "iron": "Metal", "wood": "Wood", "works_floor": "Cobblestone",
    "ramp": "WoodPlanks",
}
NUMERALS = ("XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI")


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def hole_segments(spans):
    """Ring segment centers whose floor is cut away over the top of each climb in `spans`
    (the last three segments before its top)."""
    out = set()
    for _, a1 in spans:
        for k in range(1, 4):
            out.add(round((a1 - SEG * (k - 0.5)) % 360, 3))
    return out


GALLERY_HOLES = hole_segments(RAMPS)
DECK_HOLES = hole_segments(STAIRS)


def ring_piece(m, g, name, r0, r1, degrees, y0, y1, color, **props):
    """One segment of a flat ring from r0 to r1 at `degrees`."""
    width = 2 * math.pi * r1 / SEGMENTS * 1.05
    x, z = polar((r0 + r1) / 2, degrees)
    return m.part(g, name, (width, y1 - y0, r1 - r0), (x, (y0 + y1) / 2, z), color,
                  facing_out(degrees), **props)


def spiral(m, g, name, a0, a1, y0, y1, r0, r1, steps, color, thick=1.0, **props):
    """A ramp curving round the tower from (a0, y0) to (a1, y1), between radius r0 and r1:
    `steps` straight tilted pieces whose tops follow the rise."""
    rc = (r0 + r1) / 2
    da, dy = (a1 - a0) / steps, (y1 - y0) / steps
    length = 2 * r1 * math.sin(math.radians(abs(da)) / 2) * 1.03  # chord at the outer edge
    slope = math.degrees(math.atan2(dy, 2 * rc * math.sin(math.radians(abs(da)) / 2)))
    tilt = rot_z(-slope if da > 0 else slope)  # local -X points the way the angle grows
    for k in range(steps):
        mid = a0 + da * (k + 0.5)
        rows = matmul(facing_out(mid), tilt)
        up = (rows[0][1], rows[1][1], rows[2][1])
        x, z = polar(rc, mid)
        y = y0 + dy * (k + 0.5)
        m.part(g, name, (length, thick, r1 - r0),
               (x - up[0] * thick / 2, y - up[1] * thick / 2, z - up[2] * thick / 2), color, rows,
               **props)


def tower(m):
    g = "Tower"
    m.cylinder(g, "Floor", 2, 2 * (OUTER_R + WALL + 1), (0, -1, 0), "floor")
    # The pit wall, with four doorways into the Works.
    doors = set()
    for c in DOORWAYS:
        doors.add(round((c - SEG / 2) / SEG) % SEGMENTS)
        doors.add(round((c + SEG / 2) / SEG) % SEGMENTS)
    m.ring_wall(g, "PitWall", PIT_R, WALL, -1, FLOOR2, SEGMENTS, "stone", skip=doors)
    m.ring_wall(g, "PitWall", PIT_R, WALL, DOOR_TOP, FLOOR2, SEGMENTS, "stone",
                skip=set(range(SEGMENTS)) - doors)
    # The gallery floor, cut away over the tops of the two ramps.
    for i in range(SEGMENTS):
        degrees = i * SEG
        r1 = RAMP_IN if round(degrees, 3) in GALLERY_HOLES else OUTER_R + 0.5
        ring_piece(m, g, "Gallery", PIT_R, r1, degrees, FLOOR2 - 1, FLOOR2, "floor")
    # The tower wall goes all the way down (it's the Works' outer wall too).
    m.ring_wall(g, "TowerWall", OUTER_R, WALL, -1, TOP, SEGMENTS, "stone")
    m.cylinder(g, "Ceiling", 4, 2 * (OUTER_R + WALL + 1), (0, TOP + 2, 0), "stone_dark")

    # Trim: the Works' floor, a dark band round the top of the pit wall with Roman numerals, a
    # blue light strip along the base of the tower wall, the pit floor's pattern.
    d = "Details"
    m.ring_floor(d, "WorksFloor", PIT_R + WALL, OUTER_R, 0, 0.05, SEGMENTS, "works_floor",
                 **NO_HIT)
    m.ring_floor(d, "GalleryEdge", PIT_R - 0.1, PIT_R + 0.6, FLOOR2, FLOOR2 + 0.05, SEGMENTS,
                 "stone_dark", **NO_HIT)
    for i, numeral in enumerate(NUMERALS):
        m.on_ring(d, "Numeral", PIT_R, i * 30, FLOOR2 - 2.2, (3, 1.8, 0.15), "stone_dark",
                  children=[m.surface_text("Front", numeral, "ink", font="Garamond", pps=40)],
                  **NO_HIT)
    m.ring_wall(d, "BlueStrip", OUTER_R - 0.15, 0.1, FLOOR2 + 0.4, FLOOR2 + 0.8, SEGMENTS, "blue",
                Material="Neon", CastShadow=False, **NO_HIT)
    m.cylinder(d, "FloorRing", 0.06, 22, (0, 0.03, 0), "stone_dark", **NO_HIT)
    for i in range(12):
        x, z = polar(19, i * 30)
        m.part(d, "FloorLine", (14, 0.05, 0.4), (x * 0.95, 0.03, z * 0.95), "stone_dark",
               rot_y(-i * 30), **NO_HIT)


def gear(m, angle, top, spin):
    """A brass gear platform spinning around its axle; you ride it while standing on it."""
    g = "Gears"
    cx, cz = polar(GEAR_RING, angle)
    moving = {"Spin": spin, "SpinCenter": vec(cx, 0, cz), "SpinCarry": True}
    m.cylinder(g, "Gear", 1.5, 2 * GEAR_R, (cx, top - 0.75, cz), "brass", attributes=moving)
    for i in range(18):
        degrees = i * 20
        tx, tz = polar(GEAR_R + 0.5, degrees)
        m.part(g, "Tooth", (1.6, 1.3, 1.2), (cx + tx, top - 0.75, cz + tz), "brass_dark",
               facing_out(degrees), attributes=moving)
    # Spokes and hub on top (low enough to walk over).
    for k in range(2):
        m.part(g, "Spoke", (2 * GEAR_R - 1.5, 0.5, 1.6), (cx, top + 0.25, cz), "brass_dark",
               rot_y(angle + k * 90), attributes=moving)
    m.cylinder(g, "Hub", 0.8, 3, (cx, top + 0.4, cz), "brass_dark", attributes=moving)
    # The axle it turns on (doesn't move).
    m.cylinder(g, "Axle", top - 1.5, 2, (cx, (top - 1.5) / 2, cz), "iron")


def escapement(m):
    """The middle of the pit: a brass drum (loop round it, or mantle on and jump to the first
    gear) with an escape wheel turning on top, and its drive shaft out to the wall, low enough
    that you slide (or crouch, or jump) to get past."""
    g = "Escapement"
    m.cylinder(g, "Drum", DRUM_TOP, 2 * DRUM_R, (0, DRUM_TOP / 2, 0), "brass")
    m.cylinder(g, "DrumBand", 0.6, 2 * DRUM_R + 0.4, (0, 1, 0), "brass_dark", **NO_HIT)
    m.cylinder(g, "DrumBand", 0.6, 2 * DRUM_R + 0.4, (0, DRUM_TOP - 0.6, 0), "brass_dark",
               **NO_HIT)
    turning = {"Spin": 30, "SpinCenter": vec(0, 0, 0)}
    m.cylinder(g, "EscapeWheel", 0.08, 6, (0, DRUM_TOP + 0.04, 0), "glow", Material="Neon",
               attributes=turning, **NO_HIT)
    for i in range(12):
        x, z = polar(3.3, i * 30)
        m.part(g, "EscapeTooth", (0.9, 0.1, 0.5), (x, DRUM_TOP + 0.06, z), "glow",
               facing_out(i * 30), Material="Neon", attributes=turning, **NO_HIT)
    length = PIT_R - DRUM_R
    cx, cz = polar(DRUM_R + length / 2, SHAFT_DEG)
    rows = rot_y(-SHAFT_DEG)  # the cylinder's length runs out along SHAFT_DEG
    m.part(g, "DriveShaft", (length, SHAFT_D, SHAFT_D), (cx, SHAFT_UNDER + SHAFT_D / 2, cz),
           "iron", rows, Shape="Cylinder")
    m.part(g, "StandBlocker", (length, SHAFT_UNDER, SHAFT_D), (cx, SHAFT_UNDER / 2, cz),
           (255, 255, 255), rows, Transparency=1, CastShadow=False,
           attributes={"SlideBlocker": True})
    for r in (DRUM_R + 1, PIT_R - 1):  # collars
        x, z = polar(r, SHAFT_DEG)
        m.part(g, "ShaftCollar", (0.8, SHAFT_D + 0.6, SHAFT_D + 0.6),
               (x, SHAFT_UNDER + SHAFT_D / 2, z), "brass_dark", rows, Shape="Cylinder",
               **NO_HIT)
    for side in (-1, 1):  # hazard stripes either side of it on the floor
        x, z = polar(DRUM_R + length / 2, SHAFT_DEG)
        ox, oz = polar(1.6 * side, SHAFT_DEG + 90)
        m.part(g, "HazardStripe", (length, 0.05, 0.5), (x + ox, 0.03, z + oz), "hazard", rows,
               **NO_HIT)


def works(m):
    """The Works: the ring under the gallery. Spiral ramps up to the gallery along the outer
    wall, counterweights hanging overhead, crates to vault."""
    g = "Works"
    for a0, a1 in RAMPS:
        spiral(m, g, "Ramp", a0, a1, 0, FLOOR2, RAMP_IN, RAMP_OUT, 12, "ramp")
    # Railings round the openings the ramps come up through (vault them to drop onto a ramp).
    for degrees in sorted(GALLERY_HOLES):
        ring_piece(m, g, "Railing", RAMP_IN - 0.5, RAMP_IN, degrees, FLOOR2, FLOOR2 + 3.2, "iron")
    for degrees in (45, 225):
        x, z = polar(35, degrees)
        m.cylinder(g, "Counterweight", 8, 4, (x, 13, z), "brass")
        m.block(g, "WeightChain", x - 0.15, x + 0.15, 17, FLOOR2 - 1, z - 0.15, z + 0.15, "iron",
                **NO_HIT)
    for degrees in (20, 200):
        x, z = polar(35, degrees)
        m.part(g, "Crate", (4, 3.5, 4), (x, 1.75, z), "wood", facing_out(degrees))
    for degrees in (0, 60, 180, 240):
        x, z = polar(OUTER_R - 0.6, degrees)
        m.light("Lights", (x, 16, z), size=(0.8, 1.2, 0.8), brightness=0.7, reach=22)
    for degrees in (120, 300):
        x, z = polar(PIT_R + WALL + 0.6, degrees)
        m.light("Lights", (x, 16, z), size=(0.8, 1.2, 0.8), brightness=0.6, reach=20,
                flicker=degrees == 300)


def pendulum(m):
    """The pendulum: a long chain from the top and a wide round platform that stays level as it
    swings across the middle (stand on it and ride it from one side of the gallery to the
    other)."""
    g = "Pendulum"
    sx, sz = polar(1, SWING_DIR)
    axis = (-sz, 0, sx)  # horizontal, square to the swing
    swing = {"SwingPivot": vec(*PIVOT), "SwingAxis": vec(*axis),
             "SwingAmplitude": round(SWING_AMPLITUDE, 3), "SwingPeriod": SWING_PERIOD}
    level = dict(swing)
    level["SwingLevel"] = True
    ride = dict(level)
    ride["Carry"] = True
    top = LOW_CENTER_Y + PLATFORM_T / 2
    links = int((PIVOT[1] - top - 1) // 2.2)
    for i in range(links):
        y = top + 1.4 + i * 2.2
        m.part(g, "ChainLink", (0.5, 2.5, 1.3), (0, y, 0), "iron", rot_y(90 * (i % 2)),
               attributes=swing, **NO_HIT)
    m.cylinder(g, "Platform", PLATFORM_T, 2 * PLATFORM_R, (0, LOW_CENTER_Y, 0), "brass",
               attributes=ride)
    m.cylinder(g, "PlatformRim", 0.3, 2 * PLATFORM_R + 0.6, (0, top - 0.1, 0), "glow",
               Material="Neon", attributes=level, **NO_HIT)
    m.cylinder(g, "PlatformTop", 0.1, 2 * PLATFORM_R - 2, (0, top + 0.03, 0), "brass_dark",
               attributes=level, **NO_HIT)
    m.block(g, "Shackle", -0.8, 0.8, top, top + 1.2, -0.8, 0.8, "iron", attributes=level,
            **NO_HIT)
    # The housing it hangs from.
    m.block(g, "Housing", -3, 3, TOP - 3, TOP, -3, 3, "iron")


def gallery(m):
    """Crates on the gallery, and the stairs up the tower wall to the clock deck."""
    g = "Gallery"
    for degrees in (100, 280):
        x, z = polar(32, degrees)
        m.part(g, "Crate", (4, 3.5, 4), (x, FLOOR2 + 1.75, z), "wood", facing_out(degrees))
    for a0, a1 in STAIRS:
        spiral(m, g, "ClockStairs", a0, a1, FLOOR2, DECK, STAIR_IN, STAIR_OUT, 8, "ramp")


def clock_deck(m):
    """The clock deck at 40: a ring catwalk round the tower wall (cut away over the stairs), and
    the crown wheel turning inside it."""
    g = "Deck"
    for i in range(SEGMENTS):
        degrees = i * SEG
        if round(degrees, 3) in DECK_HOLES:
            ring_piece(m, g, "Deck", DECK_IN, STAIR_IN, degrees, DECK - 1, DECK, "floor")
            ring_piece(m, g, "Railing", STAIR_IN - 0.5, STAIR_IN, degrees, DECK, DECK + 3.2,
                       "iron")
        else:
            ring_piece(m, g, "Deck", DECK_IN, OUTER_R + 0.5, degrees, DECK - 1, DECK, "floor")
    m.ring_floor(g, "DeckEdge", DECK_IN, DECK_IN + 0.4, DECK, DECK + 0.05, SEGMENTS, "blue",
                 Material="Neon", **NO_HIT)
    for i in range(12):  # brackets under the deck (decoration)
        x, z = polar(OUTER_R - 3, i * 30 + 15)
        m.part(g, "Bracket", (0.6, 2.5, 6), (x, DECK - 2.2, z), "iron", facing_out(i * 30 + 15),
               **NO_HIT)

    g = "CrownWheel"
    turning = {"Spin": WHEEL_SPIN, "SpinCenter": vec(0, 0, 0), "SpinCarry": True}
    trim = {"Spin": WHEEL_SPIN, "SpinCenter": vec(0, 0, 0)}
    step = 360 / WHEEL_SEGMENTS
    width = 2 * math.pi * WHEEL_OUT / WHEEL_SEGMENTS * 1.04
    for i in range(WHEEL_SEGMENTS):
        if i in WHEEL_GAPS:
            continue
        degrees = i * step
        x, z = polar((WHEEL_IN + WHEEL_OUT) / 2, degrees)
        m.part(g, "Wheel", (width, 1, WHEEL_OUT - WHEEL_IN), (x, DECK - 0.5, z), "brass",
               facing_out(degrees), attributes=turning)
        x, z = polar(WHEEL_IN + 0.25, degrees)
        m.part(g, "WheelGlow", (2 * math.pi * WHEEL_IN / WHEEL_SEGMENTS, 0.12, 0.5),
               (x, DECK + 0.04, z), "glow", facing_out(degrees), Material="Neon",
               attributes=trim, **NO_HIT)
        for k in range(2):
            tooth = degrees + (k - 0.5) * step / 2
            x, z = polar(WHEEL_OUT + 0.4, tooth)
            m.part(g, "WheelTooth", (1.2, 0.8, 0.8), (x, DECK - 0.5, z), "brass_dark",
                   facing_out(tooth), attributes=trim, **NO_HIT)
    for i in range(6):  # rollers it turns on, on arms from the tower wall (decoration)
        degrees = i * 60 + 30
        x, z = polar(WHEEL_IN + 4, degrees)
        m.part(g, "Roller", (1.2, 1.4, 1.4), (x, DECK - 1.8, z), "iron",
               matmul(facing_out(degrees), rot_y(90)), Shape="Cylinder", **NO_HIT)
        x, z = polar((WHEEL_IN + 4 + OUTER_R) / 2, degrees)
        m.part(g, "RollerArm", (0.5, 0.5, OUTER_R - WHEEL_IN - 4), (x, DECK - 2.4, z), "iron",
               facing_out(degrees), **NO_HIT)


def clock_face(m, degrees=270, y=48, size=19):
    """The big clock on the tower wall, over the clock deck: a white face, numerals, hands."""
    g = "Clock"
    x, z = polar(OUTER_R - 0.3, degrees)
    m.part(g, "ClockFace", (0.4, size, size), (x, y, z), "face",
           matmul(facing_out(degrees), rot_y(-90)), Shape="Cylinder", **NO_HIT)
    rim_x, rim_z = polar(OUTER_R - 0.2, degrees)
    m.part(g, "ClockRim", (0.3, size + 1.6, size + 1.6), (rim_x, y, rim_z), "stone_dark",
           matmul(facing_out(degrees), rot_y(-90)), Shape="Cylinder", **NO_HIT)
    # Numerals and hands drawn on a flat plate in front of the face.
    labels = []
    for i, numeral in enumerate(NUMERALS):
        a = math.radians(i * 30)
        px, py = 0.5 + 0.40 * math.sin(a), 0.5 - 0.40 * math.cos(a)
        labels.append({"name": f"N{i}", "className": "TextLabel", "properties": {
            "AnchorPoint": {"Vector2": [0.5, 0.5]},
            "Position": {"UDim2": [[round(px, 3), 0], [round(py, 3), 0]]},
            "Size": {"UDim2": [[0.14, 0], [0.1, 0]]}, "BackgroundTransparency": 1,
            "Text": numeral, "TextScaled": True, "Font": "Garamond",
            "TextColor3": m.rgb("ink")}})
    for name, length, width, rotation in (("Hour", 0.26, 0.035, 150), ("Minute", 0.38, 0.022, 290)):
        labels.append({"name": name, "className": "Frame", "properties": {
            "AnchorPoint": {"Vector2": [0.5, 1]},
            "Position": {"UDim2": [[0.5, 0], [0.5, 0]]},
            "Size": {"UDim2": [[width, 0], [length, 0]]}, "Rotation": rotation,
            "BackgroundColor3": m.rgb("ink"), "BorderSizePixel": 0}})
    gui = {"name": "Face", "className": "SurfaceGui", "properties": {
        "Face": "Front", "SizingMode": "PixelsPerStud", "PixelsPerStud": 20},
        "children": labels}
    m.on_ring(g, "ClockPlate", OUTER_R, degrees, y, (size, size, 0.1), "face", out=0.5,
              Transparency=1, children=[gui], **NO_HIT)
    # The clock's hands as parts too, big enough to read from the pit (decoration).
    hx, hz = polar(OUTER_R - 0.9, degrees)
    m.part(g, "MinuteHand", (0.2, size * 0.42, 0.5), (hx, y + size * 0.19, hz), "ink",
           matmul(facing_out(degrees), rot_y(-90)), **NO_HIT)
    m.part(g, "HourHand", (0.2, 0.6, size * 0.3), (hx, y, hz + size * 0.13), "ink",
           matmul(facing_out(degrees), rot_y(-90)), **NO_HIT)


def glowing_gear(m, radius, degrees, y, size):
    """A gear set into a wall, its rim glowing orange (decoration)."""
    g = "Details"
    rows = matmul(facing_out(degrees), rot_y(-90))
    x, z = polar(radius - 0.1, degrees)
    m.part(g, "WallGear", (0.2, size, size), (x, y, z), "glow", rows, Shape="Cylinder",
           Material="Neon", **NO_HIT)
    x2, z2 = polar(radius - 0.2, degrees)
    m.part(g, "WallGearHole", (0.2, size * 0.68, size * 0.68), (x2, y, z2), "brass_dark", rows,
           Shape="Cylinder", **NO_HIT)


def details(m):
    d = "Details"
    for degrees in DOORWAYS:  # arches over the doorways
        m.on_ring(d, "DoorArch", PIT_R, degrees, DOOR_TOP + 0.4, (8, 1, 0.16), "stone_dark",
                  **NO_HIT)
    for degrees in (0, 90, 180):  # sealed doorways in the tower wall above the gallery
        m.on_ring(d, "Doorway", OUTER_R, degrees, FLOOR2 + 5.5, (6, 11, 0.12), "stone_dark",
                  **NO_HIT)
        m.on_ring(d, "DoorGlow", OUTER_R, degrees, FLOOR2 + 5.5, (6.6, 11.6, 0.06), "blue",
                  Material="Neon", **NO_HIT)
    for degrees in (40, 130, 220, 310):
        glowing_gear(m, PIT_R, degrees, 13, 5)
    for degrees in (150, 330):
        glowing_gear(m, OUTER_R, degrees, FLOOR2 + 9, 6)
    for degrees in (0, 180):
        glowing_gear(m, OUTER_R, degrees, 12, 6)  # in the Works
    for degrees in (120, 300):
        x, z = polar(OUTER_R - 0.8, degrees)
        m.cylinder(d, "Pipe", TOP + 1, 1.2, (x, (TOP - 1) / 2, z), "iron", **NO_HIT)
    # Lamps: on the pit wall, round the gallery, round the deck, and one at the top.
    for degrees in DOORWAYS:
        x, z = polar(PIT_R - 0.6, degrees)
        m.light("Lights", (x, 17, z), size=(0.8, 1.2, 0.8), brightness=0.7, reach=22,
                flicker=(degrees == 153.75))
    for i in range(8):
        x, z = polar(OUTER_R - 0.6, i * 45 + 22.5)
        m.light("Lights", (x, FLOOR2 + 8, z), size=(0.8, 1.2, 0.8), brightness=0.7, reach=24)
    for degrees in (0, 90, 180):
        x, z = polar(OUTER_R - 0.6, degrees)
        m.light("Lights", (x, DECK + 6, z), size=(0.8, 1.2, 0.8), brightness=0.7, reach=24)
    m.light("Lights", (0, TOP - 4, 0), size=(2, 0.4, 2), brightness=1, reach=40)

    # Floor 1 props: crates and weights to vault, clear of the gears and the doorways.
    for degrees in (45, 225):
        x, z = polar(23, degrees)
        m.part("Props", "Crate", (4, 3.5, 4), (x, 1.75, z), "wood", facing_out(degrees))
    for degrees in (135, 315):
        x, z = polar(23, degrees)
        m.cylinder("Props", "Weight", 3.2, 3, (x, 1.6, z), "brass")


SPAWNS = ((9, 155, 0), (9, 335, 0), (35, 0, 0), (35, 180, 0), (31, 10, FLOOR2),
          (31, 190, FLOOR2))  # radius, degrees, floor


def build():
    m = Map(COLORS, MATERIALS)
    tower(m)
    for angle, top, spin in GEARS:
        gear(m, angle, top, spin)
    escapement(m)
    works(m)
    pendulum(m)
    gallery(m)
    clock_deck(m)
    clock_face(m)
    details(m)
    for radius, degrees, y in SPAWNS:
        x, z = polar(radius, degrees)
        m.spawn(x, z, y)
    return m


# ---- checks ----------------------------------------------------------------------------------

def solids(m):
    """Every part that blocks players: (name, center, rotation rows, half size, is cylinder).
    Spinning parts count where they are built (they turn in place); the swinging pendulum is
    left out (it only ever passes through the air over the pit)."""
    out = []
    for nodes in m.groups.values():
        for node in nodes:
            p = node["properties"]
            attrs = node.get("attributes") or {}
            if p.get("CanCollide") is False or "SwingPivot" in attrs:
                continue
            if p.get("Transparency", 0) >= 1 and not attrs.get("SlideBlocker"):
                continue
            cf = p["CFrame"]["CFrame"]
            out.append((node["name"].rstrip("0123456789"), cf["position"], cf["orientation"],
                        [s / 2 for s in p["Size"]], p.get("Shape") == "Cylinder"))
    return out


def blocked(boxes, point, skip=()):
    """The name of the first solid part containing `point`, or None."""
    for name, center, rows, half, cylinder in boxes:
        if name in skip:
            continue
        d = [point[i] - center[i] for i in range(3)]
        local = [sum(rows[i][j] * d[i] for i in range(3)) for j in range(3)]
        if cylinder:
            if abs(local[0]) <= half[0] and math.hypot(local[1], local[2]) <= half[1]:
                return name
        elif all(abs(local[j]) <= half[j] for j in range(3)):
            return name
    return None


def at(radius, degrees, y):
    x, z = polar(radius, degrees)
    return (x, y, z)


BODY = (0.6, 2.5, 4.5, 5.4)  # heights above your feet that must be clear to walk through


def check(m):
    problems = []
    tooth_r = GEAR_R + 1.1  # gear plus teeth
    # The pendulum's platform must miss every gear and the drum along its whole swing, and stop
    # just below the gallery's edge at both ends.
    sx, sz = polar(1, SWING_DIR)
    steps = 60
    for k in range(-steps, steps + 1):
        angle = math.radians(SWING_AMPLITUDE) * k / steps
        along = CHAIN * math.sin(angle)
        cy = PIVOT[1] - CHAIN * math.cos(angle)
        px, pz = sx * along, sz * along
        for gear_angle, top, _ in GEARS:
            gx, gz = polar(GEAR_RING, gear_angle)
            apart = math.hypot(px - gx, pz - gz) - tooth_r - PLATFORM_R
            if apart < 0.3 and cy - PLATFORM_T / 2 < top + 1 and cy + PLATFORM_T / 2 > top - 1.5:
                problems.append(f"the pendulum platform hits the gear at {gear_angle} degrees")
                break
        if math.hypot(px, pz) < DRUM_R + PLATFORM_R and cy - PLATFORM_T / 2 < DRUM_TOP + 5.5:
            problems.append("the pendulum platform passes too low over the drum")
            break
    end_y = PIVOT[1] - CHAIN * math.cos(math.radians(SWING_AMPLITUDE)) + PLATFORM_T / 2
    end_gap = PIT_R - (CHAIN * math.sin(math.radians(SWING_AMPLITUDE)) + PLATFORM_R)
    if not (0 < FLOOR2 - end_y < 1.5 and 0 < end_gap < 1.5):
        problems.append(f"swing end: {FLOOR2 - end_y:.2f} below the gallery, {end_gap:.2f} from "
                        "its edge")
    # Jumps: gear to gear, the top gear to the gallery, the drum to the first gear, the deck to
    # the crown wheel; the chain must swing clear of the wheel.
    for (a1, t1, _), (a2, t2, _) in zip(GEARS, GEARS[1:]):
        x1, z1 = polar(GEAR_RING, a1)
        x2, z2 = polar(GEAR_RING, a2)
        gap = math.hypot(x1 - x2, z1 - z2) - 2 * tooth_r
        if gap > 11 or t2 - t1 > 7:
            problems.append(f"gear {a1} -> {a2}: gap {gap:.1f}, rise {t2 - t1}")
    edge_gap = PIT_R - (GEAR_RING + tooth_r)
    if edge_gap > 6 or FLOOR2 - GEARS[-1][1] > 10 or edge_gap < 0.5:
        problems.append(f"top gear to gallery: gap {edge_gap:.1f}")
    if GEAR_RING - tooth_r - DRUM_R > 6.5:
        problems.append("the drum is too far from the first gear to jump")
    if not 2 <= DECK_IN - WHEEL_OUT <= 4:
        problems.append("the crown wheel is out of jumping reach of the deck")
    if (PIVOT[1] - DECK) * math.tan(math.radians(SWING_AMPLITUDE)) > WHEEL_IN - 1:
        problems.append("the pendulum chain swings into the crown wheel")

    # Walk-throughs: nothing solid in the way, a body's height above the floor.
    boxes = solids(m)

    def walk(label, points, skip=()):
        for point in points:
            hit = blocked(boxes, point, skip)
            if hit:
                x, y, z = point
                problems.append(f"{label} is blocked by {hit} at ({x:.1f}, {y:.1f}, {z:.1f})")
                return

    for c in DOORWAYS:  # from the pit, through the wall, into the Works
        walk(f"the doorway at {c}", [at(r / 2, c + off, h) for r in range(46, 75)
                                     for off in (-2, 0, 2) for h in BODY])
    rings = (("the Works loop", 32, 0), ("the gallery loop", 29, FLOOR2),
             ("the deck loop", 33.5, DECK))
    for label, radius, floor_y in rings:
        walk(label, [at(radius, a / 2, floor_y + h) for a in range(720) for h in BODY])
    for spans, r0, r1, y0, y1, name in ((RAMPS, RAMP_IN, RAMP_OUT, 0, FLOOR2, "Ramp"),
                                        (STAIRS, STAIR_IN, STAIR_OUT, FLOOR2, DECK,
                                         "ClockStairs")):
        for a0, a1 in spans:
            points = []
            for k in range(100):
                f = (k + 0.5) / 100
                for r in (r0 + 1, (r0 + r1) / 2, r1 - 1):
                    points += [at(r, a0 + (a1 - a0) * f, y0 + (y1 - y0) * f + h) for h in BODY]
            walk(f"the climb from {a0} to {a1}", points, skip=(name,))
    for i, (x, y, z) in enumerate(m.spawns):
        walk(f"spawn {i + 1}", [(x + dx, y + h, z + dz) for dx in (-0.8, 0.8)
                                for dz in (-0.8, 0.8) for h in BODY])
        if not blocked(boxes, (x, y - 0.3, z)):
            problems.append(f"spawn {i + 1} has no floor under it")
        for j in range(i):
            if math.dist((x, y, z), m.spawns[j]) < 18:
                problems.append(f"spawns {j + 1} and {i + 1} are under 18 studs apart")
    if len(m.spawns) < ATTRIBUTES["MaxPlayers"]:
        problems.append(f"only {len(m.spawns)} spawns for {ATTRIBUTES['MaxPlayers']} players")
    print(f"pendulum: chain {CHAIN:.1f}, swing +/-{SWING_AMPLITUDE:.1f} degrees, platform top "
          f"{LOW_CENTER_Y + PLATFORM_T / 2:.1f} at the bottom and {end_y:.1f} at the ends "
          f"({end_gap:.2f} from the gallery edge)")
    return problems


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
