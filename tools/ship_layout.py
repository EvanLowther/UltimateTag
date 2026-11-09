#!/usr/bin/env python3
"""The Arctic Icebreaker (4-8 players): a red icebreaker stuck in pack ice, from the owner's reference
picture and the "Arctic Icebreaker Map" canvas. Run from the repo root:
    python3 tools/ship_layout.py
It rewrites `src/maps/ArcticIcebreaker/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X across the ship, Z along it (the bow at -Z), Y up. THE SHIP NEVER REALLY TILTS: it stands
still, while the `Sea` folder and the camera roll round it and everyone is pushed downhill
(shared/ShipRoll, client/ShipWorld). Three decks: the cargo deck (20), the helipad deck (30, two
ramps and two ladders up), and an engine loop (8) down the hatch's stairs. Four `Loose<n>` containers
slide across two lanes on each big tip, and you can ride them. Over the side is out (KillHeight,
FallEliminates); the rails have a gap on each long side. The look matches the Space Station: smooth
colours and a modest part count.
"""
import json
import math
import os
import sys

sys.path.insert(0, "tools")
import mapcheck  # noqa: E402
from canyon_layout import corrugated  # noqa: E402
from maplib import NO_HIT, Map, matmul, rot_x, rot_y, rot_z  # noqa: E402
from mine_layout import beam, jitter, rng, rock_rows, simple_materials  # noqa: E402

OUT = "src/maps/ArcticIcebreaker"
ATTRIBUTES = {"DisplayName": "Arctic Icebreaker", "MinPlayers": 4, "MaxPlayers": 8, "InRotation": True,
              "Lighting": "Arctic", "KillHeight": 4, "FallEliminates": True, "ShipRoll": True,
              "OutOfBounds": "Bridge,UpperContainer,CranePedestal,BowCap"}

D, PAD, LOW = 20, 30, 8
SPAWNS = ((-10, -66), (10, -18), (0, 8), (-28, -5), (29, -45), (0, 30, PAD), (-20, 40, PAD), (20, 22, PAD))
COLORS = {"hull": (143, 47, 42), "hulld": (108, 36, 32), "deck": (232, 238, 244), "steel": (90, 101, 112),
          "rail": (201, 210, 218), "orange": (201, 116, 47), "white": (233, 239, 244), "yellow": (222, 180, 42),
          "glass": (150, 186, 208), "floor": (150, 158, 166), "ice": (213, 227, 238)}
MATERIALS = {"steel": "Metal", "rail": "Metal", "floor": "DiamondPlate"}


def detail(m, g, name, x0, x1, y0, y1, z0, z1, color, **props):
    extra = dict(NO_HIT)
    extra.update(props)
    return m.block(g, name, x0, x1, y0, y1, z0, z1, color, **extra)


def stairs(m, g, x0, x1, z_from, z_to, y0, y1):
    steps = round(y1 - y0)
    run = (z_to - z_from) / steps
    for i in range(steps):
        a, b = sorted((z_from + run * i, z_from + run * (i + 1)))
        m.block(g, "Step", x0, x1, y0, y0 + (i + 1), a, b, "floor")


def railing(m, g, x0, z0, x1, z1, y, color="rail", height=3.2):
    """An invisible guard with thin posts and a top rail on it."""
    along_x = abs(x1 - x0) > abs(z1 - z0)
    a0, a1 = sorted((x0, x1) if along_x else (z0, z1))
    t = 0.14
    if along_x:
        m.block(g, "RailGuard", a0, a1, y, y + height, z0 - t, z0 + t, "rail", Transparency=1, CastShadow=False)
        detail(m, g, "TopRail", a0, a1, y + height - 0.2, y + height, z0 - 0.09, z0 + 0.09, color)
        detail(m, g, "MidRail", a0, a1, y + 1.6, y + 1.74, z0 - 0.17, z0 + 0.17, color)
    else:
        m.block(g, "RailGuard", x0 - t, x0 + t, y, y + height, a0, a1, "rail", Transparency=1, CastShadow=False)
        detail(m, g, "TopRail", x0 - 0.09, x0 + 0.09, y + height - 0.2, y + height, a0 + 0.3, a1 - 0.3, color)
        detail(m, g, "MidRail", x0 - 0.17, x0 + 0.17, y + 1.6, y + 1.74, a0 + 0.3, a1 - 0.3, color)
    span = a1 - a0
    n = max(1, round(span / 8))
    for k in range(n + 1):
        a = a0 + span * k / n if along_x else a0 + 0.3 + (span - 0.6) * k / n  # (corners don't share)
        if along_x:
            detail(m, g, "RailPost", a - 0.1, a + 0.1, y, y + height - 0.2, z0 - 0.1, z0 + 0.1, color)
        else:
            detail(m, g, "RailPost", x0 - 0.1, x0 + 0.1, y, y + height - 0.2, a - 0.1, a + 0.1, color)


def container(m, g, x0, x1, y0, z0, z1, color, name=None):
    corrugated(m, g, x0, x1, y0, y0 + 8, z0, z1, color)
    # Snow on top, as in the picture.
    detail(m, g, "SnowCap", x0 + 0.5, x1 - 0.5, y0 + 8.02, y0 + 8.3, z0 + 0.5, z1 - 0.5, "white")
    if name:
        m.groups[g][-1 - next(i for i, node in enumerate(reversed(m.groups[g])) if node["name"].startswith("Container"))]["name"] = name


def build_hull(m):
    g = "Hull"
    m.block(g, "HullBase", -36, 36, 0, LOW - 0.6, -71, 70, "hulld")
    m.block(g, "HullFloor", -34.9, 34.9, LOW - 0.6, LOW, -69.9, 14.9, "floor")
    m.block(g, "HullSide", -36, -35, LOW - 0.6, D, -71, 70, "hull")
    m.block(g, "HullSide", 35, 36, LOW - 0.6, D, -71, 70, "hull")
    m.block(g, "HullEnd", -35, 35, LOW - 0.6, D, -71, -70, "hull")
    # The bow, stepping in to a point, with its deck capped in snow.
    for k, (w, z0, z1) in enumerate(((30, -80, -71), (20, -90, -80), (10, -99, -90))):
        m.block(g, "Bow", -w, w, 0, D, z0, z1, "hull")
        detail(m, g, "BowCap", -w + 0.3, w - 0.3, D - 0.02, D + 0.3, z0 + 0.3, z1 - 0.3, "white")
    # A pale waterline band and a dark band along the hull, and the name-stripe above.
    for x, s in ((-36, -1), (36, 1)):
        a, b = sorted((x, x + s * 0.1))
        detail(m, g, "HullBand", a, b, 2, 5, -70.6, 69.6, (222, 226, 232))
        detail(m, g, "HullBand", a, b, 16, 17.2, -70.6, 69.6, (232, 236, 240))
    # Icicles hanging from the deck's edge.
    for z in range(-66, 66, 7):
        for x, s in ((-36, -1), (36, 1)):
            h = rng.uniform(1.4, 3.2)
            detail(m, g, "Icicle", x + s * 0.07 - 0.2, x + s * 0.07 + 0.2, D - h, D - 0.07, z + rng.uniform(-1.4, 1.4) - 0.25, z + rng.uniform(1.6, 2) - 0.25, (205, 228, 242))


def build_deck(m):
    g = "Deck"
    for x0, x1, z0, z1 in ((-35, 35, -70, -54), (-35, 35, -12, 15), (-35, -20, -54, -12), (20, 35, -54, -12)):
        m.block(g, "CargoDeck", x0, x1, D - 0.6, D, z0, z1, "deck")
    # Dark lane markings and a walkway round the hatch, the picture's grey plate.
    for z0, z1 in ((-70, -54), (-12, 0)):
        detail(m, g, "LaneMark", -33, -32.4, D + 0.03, D + 0.09, z0 + 1, z1 - 1, "yellow")
        detail(m, g, "LaneMark", 32.4, 33, D + 0.03, D + 0.09, z0 + 1, z1 - 1, "yellow")
    for x0, x1, z0, z1 in ((-24, -20.6, -54, -12), (20.6, 24, -54, -12)):
        detail(m, g, "HatchPlate", x0, x1, D + 0.04, D + 0.1, z0, z1, (150, 158, 166), Material="DiamondPlate")
    # Snow drifts along the rails and against things.
    for x0, x1, z0, z1 in ((-35, -30, -68, -56), (30, 35, -68, -56), (-35, -30, -10, -2), (30, 35, -9, -3),
                           (-34, -24, -29, -20), (24, 34, -14, -10), (-14, 14, -13.6, -12.4), (-12, 12, -55.4, -54.4)):
        m.part(g, "SnowDrift", (x1 - x0, 0.7, z1 - z0), ((x0 + x1) / 2, D + 0.2, (z0 + z1) / 2), "white",
               matmul(rot_x(rng.uniform(0.4, 1.6)), rot_z(rng.uniform(0.4, 1.6))), **NO_HIT)
    # Hatch stairs and the engine ring below.
    stairs(m, g, 14, 20, -44, -24, LOW, D)
    stairs(m, g, -20, -14, -22, -42, LOW, D)
    for x0, x1, z0, z1 in ((-20.4, -20, -54, -12), (20, 20.4, -54, -12), (-20.4, 20.4, -54.4, -54), (-20.4, 20.4, -12, -11.6)):
        m.block(g, "RingWall", x0, x1, LOW, D - 0.6, z0, z1, "steel")
    # The engine: machinery blocks and big pipes, as seen down the hatch.
    m.block(g, "Engine", -9, 9, LOW, D - 2, -42, -24, (124, 136, 148), Material="Metal")
    detail(m, g, "EngineTop", -4, 4, D - 2, D + 2.5, -38, -28, (104, 115, 127), Material="Metal")
    for z in (-40, -36.5, -33, -29.5, -26):
        m.cylinder(g, "Pipe", 17.4, 1.3, (0, LOW + 7.4, z), (140, 152, 164), rot_y(0), Material="Metal", **NO_HIT)
        m.cylinder(g, "Pipe", 7, 0.9, (-9, LOW + 3.5, z), (120, 130, 142), Material="Metal", **NO_HIT)
    m.light(g, (0, D - 2.4, -48), (1.6, 0.3, 1.6), (232, 236, 228), 1.0, 28)
    m.light(g, (0, D - 2.4, -18), (1.6, 0.3, 1.6), (232, 236, 228), 1.0, 28)
    # Rails round the deck, with a gap on each long side, and round the hatch.
    railing(m, g, -35, -70, -35, -28, D); railing(m, g, -35, -18, -35, 15, D)
    railing(m, g, 35, -70, 35, -50, D); railing(m, g, 35, -40, 35, 15, D)
    railing(m, g, -35, -70, 35, -70, D)
    railing(m, g, -20, -54, 20, -54, D, "orange"); railing(m, g, -20, -12, 20, -12, D, "orange")
    railing(m, g, -20, -54, -20, -44, D, "orange"); railing(m, g, -20, -32, -20, -12, D, "orange")
    railing(m, g, 20, -54, 20, -32, D, "orange"); railing(m, g, 20, -22, 20, -12, D, "orange")


def build_containers(m):
    g = "Cargo"
    container(m, g, -34, -24, D, -50, -30, (63, 103, 160))
    container(m, g, -34, -24, D + 8.3, -50, -38, (168, 75, 60), name="UpperContainer")
    container(m, g, 24, 34, D, -36, -16, (168, 58, 52))
    container(m, g, -34, -24, D, 1, 13, (194, 185, 164))
    container(m, g, 24, 34, D, 5, 13, (63, 103, 160))
    # Lashed crates to climb up on (4 high, then the 8-high containers are a jump).
    for x0, x1, z0, z1 in ((-23.5, -20.5, -46, -42), (20.5, 23.5, -30, -26), (-23.5, -20, 3, 7), (20, 23.5, 7, 11),
                           (-20, -16, -57.5, -54.6), (14, 18, -57.5, -54.6), (-18, -14, -11.7, -9.3), (14, 18, -11.7, -9.3)):
        m.block(g, "Crate", x0, x1, D, D + 4, z0, z1, (150, 128, 92))
        detail(m, g, "SnowCap", x0 + 0.3, x1 - 0.3, D + 4.02, D + 4.2, z0 + 0.3, z1 - 0.3, "white")
    # Winches near the rails.
    for x, s in ((-29, 1), (29, -1)):
        m.block(g, "Winch", x - 2.5, x + 2.5, D, D + 1.2, -14.5, -10.5, "steel")
        m.cylinder(g, "WinchDrum", 3.6, 3.4, (x, D + 2.6, -12.5), "yellow", rot_y(90), **NO_HIT)
        detail(m, g, "WinchStand", x - 2.4, x - 2, D + 1.2, D + 4.2, -13.6, -11.4, "yellow")
        detail(m, g, "WinchStand", x + 2, x + 2.4, D + 1.2, D + 4.2, -13.6, -11.4, "yellow")


def build_loose(m):
    colors = ((216, 166, 58), (181, 87, 58), (75, 138, 124), (125, 90, 153))
    lanes = ((1, -18, -62), (2, 16, -62), (3, -14, -5), (4, 15, -5))
    for i, x, z in lanes:
        container(m, f"Loose{i}", x - 6, x + 6, D + 0.1, z - 4, z + 4, colors[i - 1])
        # Skid rails under it (they slide with it).
        for ox in (-4, 4):
            detail(m, f"Loose{i}", "Skid", x + ox - 0.4, x + ox + 0.4, D + 0.02, D + 0.1, z - 3.8, z + 3.8, "steel")


def build_helipad(m):
    g = "Helipad"
    m.block(g, "PadDeck", -32, 32, D, PAD - 0.5, 15, 45, "hull")
    m.block(g, "PadTop", -32.0, 32.0, PAD - 0.5, PAD, 15, 45, "deck")
    m.cylinder(g, "PadCircle", 0.08, 26, (0, PAD + 0.05, 30), (178, 190, 200), **NO_HIT)
    m.cylinder(g, "PadRing", 0.08, 21, (0, PAD + 0.1, 30), (232, 238, 244), **NO_HIT)
    for x0, x1, z0, z1 in ((-5, -3, 24, 36), (3, 5, 24, 36), (-3, 3, 29, 31)):
        detail(m, g, "PadH", x0, x1, PAD + 0.14, PAD + 0.2, z0, z1, (57, 66, 75))
    # Two ramps up from the cargo deck (each step 1 high), with rails along their outer sides.
    for x0, x1 in ((-17, -7), (7, 17)):
        n = 10
        for i in range(n):
            m.block(g, "RampStep", x0, x1, D, D + (i + 1), 0 + 1.5 * i, 1.5 * (i + 1), (170, 184, 196))
    # Ladders on the front wall of the helipad deck.
    for x in (-22, 22):
        m.ladder(g, x, 15, (0, -1), D, PAD, width=4, color=(62, 68, 74), name="ShipLadder")
    # Rails round the helipad deck, open at the ramps and ladders.
    railing(m, g, -32, 15, -24.5, 15, PAD); railing(m, g, -19.5, 15, -17, 15, PAD)
    railing(m, g, -7, 15, 7, 15, PAD); railing(m, g, 17, 15, 19.5, 15, PAD); railing(m, g, 24.5, 15, 32, 15, PAD)
    railing(m, g, -32, 15, -32, 45, PAD); railing(m, g, 32, 15, 32, 45, PAD)
    # Hull under the helipad's sides, and its stripe.
    for x, s in ((-32, -1), (32, 1)):
        a, b = sorted((x, x + s * 0.08))
        detail(m, g, "DeckBand", a, b, PAD - 3, PAD - 2, 16, 44, (232, 236, 240))


def build_bridge(m):
    g = "Superstructure"
    m.block(g, "Bridge", -28, 28, PAD, 66, 45, 70, "hull")
    detail(m, g, "RoofCap", -30, 30, 66, 67.5, 43, 71, "white")
    # Two rows of windows round the wheelhouse, with white frames.
    for y0, y1 in ((56, 61), (45, 49)):
        x = -26
        while x < 25:
            detail(m, g, "BridgePane", x, x + 3.4, y0, y1, 44.9, 44.98, "glass", Reflectance=0.15)
            x += 4.4
        for s, xf in ((-1, -28), (1, 28)):
            a, b = sorted((xf, xf + s * 0.08))
            for z in range(47, 68, 5):
                detail(m, g, "BridgePane", a, b, y0, y1, z, z + 3.4, "glass", Reflectance=0.15)
    detail(m, g, "Band", -28.14, 28.14, 53, 54, 44.86, 70.14, (232, 236, 240))
    lamp_attrs = {"ShipWarnLamp": True}
    detail(m, g, "WarnLamp", -2.5, 2.5, 67.5, 70, 54, 59, (106, 111, 115), attributes=lamp_attrs)
    detail(m, g, "WarnLamp", -29, -26.5, 67.5, 69, 44, 46, (106, 111, 115), attributes=lamp_attrs)
    detail(m, g, "WarnLamp", 26.5, 29, 67.5, 69, 44, 46, (106, 111, 115), attributes=lamp_attrs)
    # Mast and radar on the roof.
    m.cylinder(g, "Mast", 12, 1.0, (0, 73.5, 62), "steel", Material="Metal", **NO_HIT)
    detail(m, g, "Radar", -5, 5, 79, 80, 61.3, 62.7, "white")
    for x in (-10, 10):
        m.cylinder(g, "Funnel", 8, 4, (x, 71.5, 64), (40, 44, 50), **NO_HIT)


def crane(m, x, s):
    """A yellow deck crane on the helipad deck's corner (scenery, as in the picture)."""
    g = "Cranes"
    z = 41
    m.block(g, "CranePedestal", x - 2, x + 2, PAD, PAD + 12, z - 2, z + 2, "yellow")
    arm_end = (x + s * 16, PAD + 22, z - 32)
    start = (x, PAD + 12, z)
    beam(m, g, "CraneArm", start, arm_end, 1.6, 1.8, COLORS["yellow"], "SmoothPlastic")
    beam(m, g, "CraneTie", (x, PAD + 12, z), (x + s * 8, PAD + 22, z - 16), 0.5, 0.5, COLORS["yellow"], "SmoothPlastic")
    beam(m, g, "CraneCable", (arm_end[0], PAD + 21, arm_end[2]), (arm_end[0], D + 12, arm_end[2]), 0.14, 0.14, (40, 40, 44), "Metal")
    detail(m, g, "CraneHook", arm_end[0] - 0.7, arm_end[0] + 0.7, D + 10, D + 12, arm_end[2] - 0.4, arm_end[2] + 0.4, (60, 62, 66), Material="Metal")


def build_sea(m):
    g = "Sea"
    m.block(g, "IceSheet", -1400, 1400, -2, 0, -1400, 1400, "ice", **NO_HIT)
    m.block(g, "Channel", -46, 46, 0, 0.14, 70, 1000, (58, 76, 90), **NO_HIT)
    for _ in range(130):
        a, d = rng.uniform(0, math.tau), rng.uniform(60, 520)
        x, z = math.cos(a) * d, math.sin(a) * d * 1.3
        if abs(x) < 52 and z > -112:
            continue
        w, h, depth = rng.uniform(14, 44), rng.uniform(2, 8), rng.uniform(12, 36)
        m.part(g, "Floe", (w, h, depth), (x, h * 0.3, z), jitter((226, 238, 246), 8), matmul(rot_y(rng.uniform(0, 180)), rock_rows(9)), **NO_HIT)


def build_weather(m):
    snow = m.particles("Snow", 90, (4, 7), (12, 20), [(0, 0.28), (1, 0.28)], [(0, 0.05), (1, 0.45)], (255, 255, 255), direction="Bottom",
                       spread=(14, 14), accel=(6, 0, 0))
    m.block("Weather", "SnowCloud", -110, 110, 92, 93, -130, 110, (255, 255, 255), Transparency=1, CastShadow=False, children=[snow], **NO_HIT)


def build():
    m = Map(colors=COLORS, materials=MATERIALS)
    build_hull(m)
    build_deck(m)
    build_containers(m)
    build_loose(m)
    build_helipad(m)
    build_bridge(m)
    crane(m, -28, 1)
    crane(m, 28, -1)
    build_sea(m)
    build_weather(m)
    for s in SPAWNS:
        m.spawn(s[0], s[1], s[2] if len(s) > 2 else D)
    simple_materials(m)
    return m


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
    issues = mapcheck.check_map(layout, ATTRIBUTES)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    for group in layout.groups:
        if group == "Sea" or group.startswith("Loose"):
            persistent(group)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
