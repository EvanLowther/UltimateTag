#!/usr/bin/env python3
"""The Clocktower (smallest map, 2-4 players), from the user's reference: a compact round tower
interior, two floors. Run from the repo root:
    python3 tools/clocktower_layout.py
It rewrites `src/maps/Clocktower/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south, Y up, the tower's center on the origin.
  FLOOR 1: the bottom of the round pit (radius 28). Its wall is 24 tall and curved: wall-run
  around it, or climb it (two hops) and pull up onto the gallery.
  FLOOR 2: the gallery, a ring (radius 28 to 40) at 24 high, under the tower's outer wall (also
  curved, also wall-runnable), with the big clock face, glowing gears, hanging weights.
  GEARS: four brass gear platforms spinning slowly (you ride them), climbing in a spiral
  5 -> 10 -> 15 -> 20 from floor 1 to the gallery: jump and mantle from one to the next.
  PENDULUM: hangs from the top through the middle and swings; its bob (8.5 to 15.5 high at the
  bottom of its swing) knocks back anyone it hits (jumping across the middle, on a gear).
Moving parts are animated on each client from the server clock (client/MapAmbience: Spin,
SpinCarry, Swing, Knockback attributes).
"""
import math
import sys

sys.path.insert(0, "tools")
from maplib import IDENTITY, NO_HIT, Map, facing_out, matmul, polar, rot_y, rot_z  # noqa: E402

OUT = "src/maps/Clocktower"
SEGMENTS = 48
PIT_R = 28  # floor 1 radius (the pit wall's inner face)
OUTER_R = 40  # the tower wall's inner face
FLOOR2 = 24  # gallery height
TOP = 58  # ceiling
WALL = 2

PIVOT = (0, TOP - 2, 0)
BOB_Y = 12  # bob center at the bottom of the swing
BOB = 7
SWING_DIR = 65  # degrees: the pendulum swings along this line (between the gears)
SWING_AMPLITUDE = 18
SWING_PERIOD = 5.2

GEAR_R = 7
GEAR_RING = 18.5  # gear centers this far from the middle
GEARS = ((20, 5, 22), (110, 10, -22), (200, 15, 22), (290, 20, -22))  # angle, top, spin

COLORS = {
    "stone": (204, 206, 214), "stone_dark": (150, 153, 164), "floor": (172, 174, 184),
    "brass": (198, 152, 82), "brass_dark": (150, 110, 55), "iron": (88, 90, 100),
    "glow": (255, 150, 40), "blue": (80, 200, 255), "face": (246, 245, 238),
    "ink": (40, 40, 48), "wood": (150, 110, 70), "light": (255, 214, 160),
}
MATERIALS = {
    "stone": "Plaster", "stone_dark": "Concrete", "floor": "Slate", "brass": "Metal",
    "brass_dark": "Metal", "iron": "Metal", "wood": "Wood",
}
NUMERALS = ("XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI")


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def tower(m):
    g = "Tower"
    # Floor 1, the pit wall, the gallery floor, the outer wall, the ceiling.
    m.cylinder(g, "Floor", 2, 2 * (PIT_R + WALL + 1), (0, -1, 0), "floor")
    m.ring_wall(g, "PitWall", PIT_R, WALL, -1, FLOOR2, SEGMENTS, "stone")
    m.ring_floor(g, "Gallery", PIT_R, OUTER_R + 0.5, FLOOR2 - 1, FLOOR2, SEGMENTS, "floor")
    m.ring_wall(g, "TowerWall", OUTER_R, WALL, FLOOR2 - 2, TOP, SEGMENTS, "stone")
    m.cylinder(g, "Ceiling", 4, 2 * (OUTER_R + WALL + 1), (0, TOP + 2, 0), "stone_dark")

    # Trim: a dark band around the top of the pit wall with Roman numerals, a blue light strip
    # along the base of the tower wall, the floor's pattern.
    d = "Details"
    m.ring_floor(d, "GalleryEdge", PIT_R - 0.1, PIT_R + 0.6, FLOOR2, FLOOR2 + 0.05, SEGMENTS,
                 "stone_dark", **NO_HIT)
    for i, numeral in enumerate(NUMERALS):
        m.on_ring(d, "Numeral", PIT_R, i * 30, FLOOR2 - 2.2, (3, 1.8, 0.15), "stone_dark",
                  children=[m.surface_text("Front", numeral, "ink", font="Garamond", pps=40)],
                  **NO_HIT)
    m.ring_wall(d, "BlueStrip", OUTER_R - 0.15, 0.1, FLOOR2 + 0.4, FLOOR2 + 0.8, SEGMENTS, "blue",
                Material="Neon", CastShadow=False, **NO_HIT)
    m.cylinder(d, "FloorRing", 0.06, 22, (0, 0.03, 0), "stone_dark", **NO_HIT)
    m.cylinder(d, "FloorDisc", 0.08, 16, (0, 0.04, 0), "floor", **NO_HIT)
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


def pendulum(m):
    """The pendulum: a chain from the top and a heavy bob, swinging through the middle."""
    g = "Pendulum"
    sx, sz = polar(1, SWING_DIR)
    axis = (-sz, 0, sx)  # horizontal, square to the swing
    swing = {"SwingPivot": vec(*PIVOT), "SwingAxis": vec(*axis),
             "SwingAmplitude": SWING_AMPLITUDE, "SwingPeriod": SWING_PERIOD}
    bob_top = BOB_Y + BOB / 2
    links = int((PIVOT[1] - bob_top) // 2.2)
    for i in range(links):
        y = bob_top + 1.1 + i * 2.2
        m.part(g, "ChainLink", (0.5, 2.5, 1.3), (0, y, 0), "iron", rot_y(90 * (i % 2)),
               attributes=swing, **NO_HIT)
    bob = dict(swing)
    bob["Knockback"] = 75
    m.part(g, "Bob", (BOB, BOB, BOB), (0, BOB_Y, 0), "stone_dark", rot_y(SWING_DIR),
           attributes=bob)
    m.part(g, "BobBand", (BOB + 0.3, 1, BOB + 0.3), (0, BOB_Y + 1.5, 0), "brass",
           rot_y(SWING_DIR), attributes=swing, **NO_HIT)
    m.part(g, "BobRing", (1.2, 1.6, 1.6), (0, bob_top + 0.6, 0), "iron", rot_y(SWING_DIR),
           attributes=swing, **NO_HIT)
    # The housing it hangs from.
    m.block(g, "Housing", -3, 3, TOP - 3, TOP, -3, 3, "iron")


def clock_face(m, degrees=270, y=41, size=24):
    """The big clock on the tower wall: a white face, numerals, hands."""
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
    for i in range(8):
        a = math.radians(i * 45)
        offset = size / 2 + 0.3
        tx, tz = polar(radius - 0.1, degrees)
        # teeth around the rim, in the wall's plane
        side = (math.cos(a) * offset, math.sin(a) * offset)
        ux, uz = polar(1, degrees + 90)  # along the wall
        m.part(g, "WallGearTooth", (0.2, 0.8, 0.8), (tx + ux * side[0], y + side[1], tz + uz * side[0]),
               "glow", rows, Material="Neon", **NO_HIT)


def details(m):
    d = "Details"
    # Arched doorways set into both walls (decoration, flush so wall runs still work).
    for degrees in (65, 155, 245, 335):
        m.on_ring(d, "Doorway", PIT_R, degrees, 5, (6, 10, 0.12), "stone_dark", **NO_HIT)
        m.on_ring(d, "DoorArch", PIT_R, degrees, 10.4, (6.8, 1, 0.16), "stone_dark", **NO_HIT)
    for degrees in (0, 90, 180):
        m.on_ring(d, "Doorway", OUTER_R, degrees, FLOOR2 + 5.5, (6, 11, 0.12), "stone_dark",
                  **NO_HIT)
        m.on_ring(d, "DoorGlow", OUTER_R, degrees, FLOOR2 + 5.5, (6.6, 11.6, 0.06), "blue",
                  Material="Neon", **NO_HIT)
    # Glowing gears on both walls.
    for degrees in (40, 130, 220, 310):
        glowing_gear(m, PIT_R, degrees, 13, 5)
    for degrees in (30, 150, 210, 330):
        glowing_gear(m, OUTER_R, degrees, FLOOR2 + 10, 6)
    # Hanging counterweights on chains over the gallery (above head height).
    for degrees in (45, 135, 225, 315):
        x, z = polar(35, degrees)
        m.block(d, "WeightChain", x - 0.15, x + 0.15, FLOOR2 + 12, TOP, z - 0.15, z + 0.15,
                "iron", **NO_HIT)
        m.cylinder(d, "Counterweight", 4, 2.6, (x, FLOOR2 + 10, z), "brass", **NO_HIT)
    # Pipes up the tower wall.
    for degrees in (60, 240):
        x, z = polar(OUTER_R - 0.8, degrees)
        m.cylinder(d, "Pipe", TOP - FLOOR2, 1.2, (x, (TOP + FLOOR2) / 2, z), "iron", **NO_HIT)
    # Lamps: on the pit wall and around the gallery.
    for degrees in (65, 155, 245, 335):
        x, z = polar(PIT_R - 0.6, degrees)
        m.light("Lights", (x, 17, z), size=(0.8, 1.2, 0.8), brightness=0.7, reach=22,
                flicker=(degrees == 155))
    for i in range(8):
        x, z = polar(OUTER_R - 0.6, i * 45 + 22.5)
        m.light("Lights", (x, FLOOR2 + 8, z), size=(0.8, 1.2, 0.8), brightness=0.7, reach=24)
    m.light("Lights", (0, TOP - 4, 0), size=(2, 0.4, 2), brightness=1, reach=40)

    # Floor 1 props: crates and weights to vault, in the gaps between the gears.
    for degrees in (65, 245):
        x, z = polar(23, degrees)
        m.block("Props", "Crate", x - 2, x + 2, 0, 3.5, z - 2, z + 2, "wood")
    for degrees in (155, 335):
        x, z = polar(23, degrees)
        m.cylinder("Props", "Weight", 3.2, 3, (x, 1.6, z), "brass")


def build():
    m = Map(COLORS, MATERIALS)
    tower(m)
    for angle, top, spin in GEARS:
        gear(m, angle, top, spin)
    pendulum(m)
    clock_face(m)
    details(m)
    # Spawns: two on floor 1, two on the gallery.
    for radius, degrees, y in ((9, 155, 0), (9, 335, 0), (34, 65, FLOOR2), (34, 245, FLOOR2)):
        x, z = polar(radius, degrees)
        m.spawn(x, z, y)
    return m


def check(m):
    """Clearances that matter: the pendulum's bob must miss the gears at the end of its swing,
    gears must be jumpable to each other, the top gear must reach the gallery."""
    problems = []
    reach = (PIVOT[1] - BOB_Y) * math.sin(math.radians(SWING_AMPLITUDE))
    sx, sz = polar(1, SWING_DIR)
    for sign in (1, -1):
        bx, bz = sx * reach * sign, sz * reach * sign
        for angle, top, _ in GEARS:
            gx, gz = polar(GEAR_RING, angle)
            gap = math.hypot(bx - gx, bz - gz) - (GEAR_R + 0.6) - BOB * math.sqrt(2) / 2
            bob_bottom = PIVOT[1] - (PIVOT[1] - BOB_Y) * math.cos(math.radians(SWING_AMPLITUDE)) - BOB / 2
            if gap < 0.5 and bob_bottom < top + 1:
                problems.append(f"pendulum hits the gear at {angle} degrees")
    for (a1, t1, _), (a2, t2, _) in zip(GEARS, GEARS[1:]):
        x1, z1 = polar(GEAR_RING, a1)
        x2, z2 = polar(GEAR_RING, a2)
        gap = math.hypot(x1 - x2, z1 - z2) - 2 * (GEAR_R + 0.6)
        if gap > 11 or t2 - t1 > 7:
            problems.append(f"gear {a1} -> {a2}: gap {gap:.1f}, rise {t2 - t1}")
    last = GEARS[-1]
    edge_gap = PIT_R - (GEAR_RING + GEAR_R + 0.6)
    if edge_gap > 6 or FLOOR2 - last[1] > 7:
        problems.append(f"top gear to gallery: gap {edge_gap:.1f}, rise {FLOOR2 - last[1]}")
    if PIT_R > GEAR_RING + GEAR_R + 0.6 + 0.5:
        pass
    else:
        problems.append("gears touch the pit wall")
    return problems


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, {"DisplayName": "The Clocktower", "MinPlayers": 2, "MaxPlayers": 4,
                       "InRotation": True, "Lighting": "Indoor"})
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
