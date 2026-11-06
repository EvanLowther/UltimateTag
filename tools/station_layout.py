#!/usr/bin/env python3
"""The Space Station (2-6 players): a white panelled station hall with a deep maintenance trench,
designed on the "Space Station Map" canvas (draft v5) from the owner's reference picture. Run from
the repo root:
    python3 tools/station_layout.py
It rewrites `src/maps/SpaceStation/` (generated: don't edit those files by hand); Rojo syncs it.

Axes: X east, Z south, Y up. The hall is 63 x 88 (x -31.5..31.5, z -44..44), ceiling 30.
  THE HALL (0): the left walkway (12 wide) along the left wall, whose blue light band is a
    wall-run strip; the trench down the middle; the open right floor with a darker zone; a low
    step under the window. The far wall holds a hexagon window (30 x 26) onto Earth.
  THE TRENCH (15 deep, 15 wide): too deep to jump out of, so dropping in commits you. Out by the
    stairs at the front end (14 steps) or the jump pad at the window end, which throws you onto
    the floor by the window. Two beams cross it at floor level (13 of headroom under them). A
    tunnel leaves its right wall at the bottom.
  THE L (16): the left catwalk and the front bridge. Up by the ladder halfway along the catwalk
    (on a post under its edge) or the jump pad below either open end; down off the open ends or
    over the railings (3.2: an invisible guard, thin rails on posts).
  THE HALLWAY: two sliding doors in the right wall (orange near the window, blue near the front)
    open when anyone is within Config.Doors.Range on either side (server/Doors, client/Doors: the
    Door, DoorSlide, DoorCenter attributes). Behind them an 8-wide hallway with windows to space;
    from each door a ramp runs down 15 to a flat bottom in the middle, where a tunnel runs west
    under the floor into the bottom of the trench.
Nothing kills (no KillHeight); every pad stays under the ceiling. Detail is NO_HIT and sits flat on
a surface (no signs, nothing hanging free).
"""
import math
import sys

sys.path.insert(0, "tools")
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_y  # noqa: E402

OUT = "src/maps/SpaceStation"
ATTRIBUTES = {"DisplayName": "Space Station", "MinPlayers": 2, "MaxPlayers": 6,
              "InRotation": True, "Lighting": "Space", "OutOfBounds": "Ceiling,HallwayRoof"}

W, L, CEIL, WALL, BOT = 31.5, 44, 30, 1, -16       # hall half-width, half-length, ceiling, walls
UPY, DT = 16, 0.8                                   # the L's deck top and thickness
TX0, TX1, TD, TZ0, TZ1 = -19.5, -4.5, -15, -34, 36  # the trench
TC = (TX0 + TX1) / 2
STEP_RUN, STEPS = 1.6, 14
STAIRS_FOOT = TZ1 - STEP_RUN * STEPS                # 13.6
BEAMS = (-16, 4)
TUN0, TUN1, TUN_TOP = -1, 7, -5                     # the tunnel (z band, roof)
DOORS = (("Orange", -24, "orange"), ("Blue", 30, "cyan"))
DW, DH = 5, 8
HX0, HX1, HZ0, HZ1, HH = W + WALL, W + WALL + 8, -30, 36, 12  # the hallway's inside
RS0, RN1 = DOORS[0][1] + DW / 2, DOORS[1][1] - DW / 2         # where its ramps start
CW_IN, CW_END, BR_IN, BR_END = -24.5, -30, 37, 18   # the L: catwalk inner edge and end, bridge
LADDER_Z = 7
WCY, R_IN = 15, 15                                  # the window's middle and inner radius
PADS = {  # name: (pad centre on its floor, LaunchVelocity)
    "CatwalkPad": ((-28, 0, -36), (0, 78, 16.5)),
    "BridgePad": ((25, 0, 40.5), (-16.5, 78, 0)),
    "TrenchPad": ((TC, TD, -29), (0, 100, -12)),
}
PAD_TARGETS = {"CatwalkPad": UPY, "BridgePad": UPY, "TrenchPad": 0}
SPAWNS = ((-22, 26), (-22, -24), (2, -30), (20, -14), (4, 12), (14, 32))

COLORS = {
    "panel": (232, 236, 241), "trim": (246, 248, 250), "floor": (198, 204, 212),
    "darkfloor": (92, 100, 110), "metal": (118, 128, 140), "grate": (72, 80, 90),
    "rail": (226, 231, 236), "hazy": (242, 194, 48), "hazk": (26, 28, 31),
    "band": (16, 30, 42), "cyan": (58, 150, 172), "orange": (196, 112, 48),
    "purple": (132, 98, 178), "red": (170, 48, 48), "lamp": (222, 228, 236),
    "screen": (28, 62, 98), "glass": (190, 228, 255), "padrim": (125, 136, 148),
    "rib": (204, 210, 218), "kick": (96, 104, 114), "vent": (58, 64, 72), "crate": (150, 128, 92),
    "seam": (150, 156, 164), "foil": (214, 172, 74), "panelblue": (34, 66, 140),
    "white": (236, 238, 240), "dish": (210, 214, 220),
    "earth": (42, 104, 184), "land": (78, 138, 63), "air": (126, 200, 255),
    "gold": (215, 180, 90), "solar": (26, 53, 112), "pipe": (141, 152, 163),
    "redpipe": (176, 36, 44),
}
MATERIALS = {
    "panel": "SmoothPlastic", "trim": "SmoothPlastic", "floor": "SmoothPlastic",
    "darkfloor": "DiamondPlate", "metal": "Metal", "grate": "DiamondPlate", "rail": "Metal",
    "band": "SmoothPlastic", "cyan": "SmoothPlastic", "orange": "SmoothPlastic",
    "purple": "SmoothPlastic", "red": "SmoothPlastic", "lamp": "SmoothPlastic",
    "screen": "Glass", "glass": "Glass", "padrim": "Metal", "pipe": "Metal",
    "redpipe": "Metal", "gold": "Foil", "solar": "Glass", "rib": "SmoothPlastic", "kick": "Metal",
    "vent": "DiamondPlate", "crate": "WoodPlanks", "seam": "SmoothPlastic", "foil": "Foil",
    "panelblue": "Glass", "white": "SmoothPlastic", "dish": "Metal",
}
DETAIL = dict(NO_HIT, CastShadow=False)
RIBS = [-38.5 + 11 * k for k in range(8)]  # wall ribs, in line with the ceiling beams


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def between(m, group, name, a, b, width, thick, color, **props):
    """A bar from point a to point b (its X along the bar, level sideways)."""
    d = [b[i] - a[i] for i in range(3)]
    length = math.sqrt(sum(v * v for v in d))
    x = [v / length for v in d]
    z = [x[1] * 0 - x[2] * 1, x[2] * 0 - x[0] * 0, x[0] * 1 - x[1] * 0]  # x cross up
    zl = math.sqrt(sum(v * v for v in z)) or 1
    z = [v / zl for v in z] if zl > 1e-6 else [0, 0, 1]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    rows = [[x[i], y[i], z[i]] for i in range(3)]
    mid = [(a[i] + b[i]) / 2 for i in range(3)]
    return m.part(group, name, (length, thick, width), mid, color, rows, **props)


def glow(node, color, brightness=0.5, reach=12, kind="PointLight", face=None):
    """Gives a part a soft light of its own (no Neon in this map: lights do the glowing)."""
    props = {"Brightness": brightness, "Range": reach, "Color": color, "Shadows": False}
    if face:
        props["Face"] = face
    node.setdefault("children", []).append({"name": "Glow", "className": kind, "properties": props})
    return node


def surface_light(m, group, name, x0, x1, y0, y1, z0, z1, color, face="Bottom", reach=40,
                  brightness=1.0, angle=120):
    node = m.block(group, name, x0, x1, y0, y1, z0, z1, color, **DETAIL)
    node["children"] = [{"name": "Glow", "className": "SurfaceLight", "properties": {
        "Face": face, "Range": reach, "Angle": angle, "Brightness": brightness,
        "Color": m.rgb(color), "Shadows": False}}]
    return node


def stripes(m, group, axis, a0, a1, fixed0, fixed1, y, step=1.0):
    """Yellow and black hazard stripes laid on a floor along `axis`, 0.1 thick."""
    n = max(1, round((a1 - a0) / step))
    s = (a1 - a0) / n
    for i in range(n):
        c = "hazy" if i % 2 == 0 else "hazk"
        if axis == "Z":
            m.block(group, "Hazard", fixed0, fixed1, y, y + 0.1, a0 + i * s, a0 + (i + 1) * s, c,
                    **DETAIL)
        else:
            m.block(group, "Hazard", a0 + i * s, a0 + (i + 1) * s, y, y + 0.1, fixed0, fixed1, c,
                    **DETAIL)


def build_shell(m):
    g = "Shell"
    # Left and front walls, full height; the ceiling.
    m.block(g, "Wall", -W - WALL, -W, 0, CEIL + WALL, -L - WALL, L + WALL, "panel")
    m.block(g, "Wall", -W, W, 0, CEIL + WALL, L, L + WALL, "panel")
    m.block(g, "Ceiling", -W, W, CEIL, CEIL + WALL, -L, L, "panel")
    # The right wall: door openings at the floor, the tunnel hole below it.
    rx0, rx1 = W, W + WALL
    z = -L - WALL
    for _, dz, _ in DOORS:
        m.block(g, "Wall", rx0, rx1, BOT, CEIL + WALL, z, dz - DW / 2, "panel")
        m.block(g, "Wall", rx0, rx1, DH, CEIL + WALL, dz - DW / 2, dz + DW / 2, "panel")
        m.block(g, "Wall", rx0, rx1, BOT, 0, dz - DW / 2, dz + DW / 2, "panel")
        z = dz + DW / 2
    m.block(g, "Wall", rx0, rx1, BOT, CEIL + WALL, z, L + WALL, "panel")
    # (fix_right_wall cuts the tunnel through the piece between the doors)
    # Back wall: the hexagon window, a staircase of strips round it (the frame covers the steps).
    m.block(g, "Wall", -W, W, 0, 2, -L - WALL, -L, "panel")
    m.block(g, "Wall", -W, W, 28, CEIL + WALL, -L - WALL, -L, "panel")
    for k in range(2, 28):
        dy = max(abs(k - WCY), abs(k + 1 - WCY))
        half = R_IN - dy / math.sqrt(3)
        m.block(g, "Wall", -W, -half, k, k + 1, -L - WALL, -L, "panel")
        m.block(g, "Wall", half, W, k, k + 1, -L - WALL, -L, "panel")
    m.block(g, "ViewGlass", -16, 16, 1, 29, -L - WALL - 0.2, -L - WALL, "glass",
            Transparency=0.85, CastShadow=False)
    for i in range(6):  # frame bars along the six edges, alternate ones a little deeper
        mid = math.radians(60 * i + 30)
        back = -L + 0.1 * (i % 2)  # alternate bars stand off the wall a little, so none share a face
        m.part(g, "WindowFrame", (16.6, 1.8, 0.8),
               (13.5 * math.cos(mid), WCY + 13.5 * math.sin(mid), back + 0.4), "trim",
               rows_z(60 * i + 120), **DETAIL)
    for i in range(3):  # mullions across the glass, vertex to vertex
        z1 = -L - 0.1 - 0.1 * i
        m.part(g, "WindowFrame", (2 * R_IN, 0.7, 0.5), (0, WCY, z1 - 0.25), "trim",
               rows_z(60 * i), **DETAIL)


def rows_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def build_floors(m):
    g = "Floors"
    m.block(g, "Floor", -W, TX0, BOT, 0, -L, L, "floor")                   # left walkway
    m.block(g, "Floor", TX0, TX1, BOT, 0, TZ1, L, "floor")                 # trench front end
    m.block(g, "Floor", TX0, TX1, BOT, 0, -L, TZ0, "floor")                # trench back end
    m.block(g, "Floor", TX1, W, BOT, 1, -L, -36, "floor")                  # the step by the window
    m.block(g, "Floor", TX1, 9.5, TUN_TOP, 0, -36, L, "floor")             # right floor (over the tunnel)
    m.block(g, "Floor", 9.5, W, TUN_TOP, 0, -36, L, "darkfloor")
    m.block(g, "Fill", TX1, W, BOT, TUN_TOP, -36, TUN0, "metal")           # under it, round the tunnel
    m.block(g, "Fill", TX1, W, BOT, TUN_TOP, TUN1, L, "metal")
    m.block(g, "TrenchFloor", TX0, TX1, BOT, TD, TZ0, TZ1, "grate")
    m.block(g, "TunnelFloor", TX1, W, BOT, TD, TUN0, TUN1, "grate")
    m.block(g, "LightStrip", TX1, W, 0.4, 0.6, -35.95, -35.85, "cyan", **DETAIL)  # the step's edge


def fix_right_wall(m):
    """The right wall's middle piece runs from BOT to the ceiling; replace it with pieces that
    leave the tunnel hole (z TUN0..TUN1, y TD..TUN_TOP)."""
    rx0, rx1 = W, W + WALL
    za, zb = DOORS[0][1] + DW / 2, DOORS[1][1] - DW / 2
    shell = m.groups["Shell"]
    for node in list(shell):
        p = node["properties"]
        pos, size = p["CFrame"]["CFrame"]["position"], p["Size"]
        if node["name"].startswith("Wall") and abs(pos[0] - (rx0 + rx1) / 2) < 1e-6 \
                and abs(pos[2] - (za + zb) / 2) < 1e-6 and abs(size[2] - (zb - za)) < 1e-6:
            shell.remove(node)
    g = "Shell"
    m.block(g, "Wall", rx0, rx1, 0, CEIL + WALL, za, zb, "panel")
    m.block(g, "Wall", rx0, rx1, BOT, 0, za, TUN0, "panel")
    m.block(g, "Wall", rx0, rx1, BOT, 0, TUN1, zb, "panel")
    m.block(g, "Wall", rx0, rx1, TUN_TOP, 0, TUN0, TUN1, "panel")
    m.block(g, "Wall", rx0, rx1, BOT, TD, TUN0, TUN1, "panel")


def build_trench(m):
    g = "Trench"
    # Linings and pipes on its walls (detail), red lights, the glow under the rims.
    m.block(g, "Lining", TX0 + 0.05, TX0 + 0.25, TD, -0.3, TZ0, STAIRS_FOOT, "metal", **DETAIL)
    for z0, z1, y0 in ((TZ0, TUN0, TD), (TUN1, STAIRS_FOOT, TD), (TUN0, TUN1, TUN_TOP)):
        m.block(g, "Lining", TX1 - 0.25, TX1 - 0.05, y0, -0.3, z0, z1, "metal", **DETAIL)
    m.block(g, "Lining", TX0 + 0.25, TX1 - 0.25, TD, -0.3, TZ0 + 0.05, TZ0 + 0.25, "metal", **DETAIL)
    for x, side in ((TX0 + 0.25, 1), (TX1 - 0.25, -1)):
        spans = [(TZ0 + 0.4, STAIRS_FOOT - 0.4)] if side > 0 else \
            [(TZ0 + 0.4, TUN0 - 1), (TUN1 + 1, STAIRS_FOOT - 0.4)]
        for z0, z1 in spans:
            for y, radius, color in ((-13.5, 0.55, "pipe"), (-12, 0.3, "redpipe"), (-6, 0.45, "pipe")):
                cx = x + side * (0.05 + radius)
                m.part(g, "Pipe", (z1 - z0, 2 * radius, 2 * radius), (cx, y, (z0 + z1) / 2), color,
                       rot_y(90), Shape="Cylinder", **DETAIL)
        if side > 0:
            m.block(g, "LightStrip", x + 0.05, x + 0.15, -0.9, -0.6, TZ0 + 0.4, STAIRS_FOOT - 0.4,
                    "lamp", **DETAIL)
        for z in (-28, -18, -8, 12):
            if side < 0 and TUN0 - 1.5 < z < TUN1 + 1.5:
                continue
            a, b = sorted((x + side * 0.05, x + side * 0.2))
            glow(m.block(g, "WarningLight", a, b, -2.0, -1.4, z - 0.5, z + 0.5, "red", **DETAIL),
                 m.rgb((255, 70, 60)), 0.6, 12)
    for z, side in ((-24, 1), (-6, -1), (8, 1)):
        x = TX0 + 0.25 if side > 0 else TX1 - 0.25
        a, b = sorted((x + side * 0.05, x + side * 0.25))
        node = m.block(g, "Lamp", a, b, -3.2, -2.6, z - 0.6, z + 0.6, "lamp", **DETAIL)
        node["children"] = [{"name": "Glow", "className": "PointLight", "properties": {
            "Brightness": 0.5, "Range": 22, "Color": m.rgb((215, 230, 255)), "Shadows": False}}]
    # Stairs out at the front end: 14 steps, each 1 up and 1.6 deep, a yellow nose on each.
    for k in range(STEPS):
        top = -1 - k
        z1 = TZ1 - STEP_RUN * k
        z0 = z1 - STEP_RUN
        m.block(g, "Step", TX0, TX1, TD, top, z0, z1, "metal")
        m.block(g, "StepNose", TX0, TX1, top, top + 0.1, z0, z0 + 0.4, "hazy", **DETAIL)
    # The beams across it, at floor level.
    for z in BEAMS:
        m.block(g, "Beam", TX0, TX1, -1.2, 0, z - 1, z + 1, "metal")
        stripes(m, g, "X", TX0, TX1, z - 1, z + 1, 0)
    # Hazard edges round the rim.
    stripes(m, g, "Z", TZ0, TZ1, TX0 - 1, TX0, 0)
    stripes(m, g, "Z", TZ0, TZ1, TX1, TX1 + 1, 0)
    stripes(m, g, "X", TX0, TX1, TZ1, TZ1 + 1, 0)
    stripes(m, g, "X", TX0, TX1, TZ0 - 1, TZ0, 0)
    # The electrical buzz (client/Sounds plays a part's SoundLoop in 3D): you hear it down here.
    for x, y, z in ((TC, TD + 3, -24), (TC, TD + 3, 0), (TC, TD + 4, 18), (14, TD + 4, 3)):
        m.block(g, "BuzzSound", x - 0.5, x + 0.5, y - 0.5, y + 0.5, z - 0.5, z + 0.5, "metal",
                Transparency=1, attributes={"SoundLoop": "amb_trench", "SoundNear": 5,
                                            "SoundRange": 24}, **DETAIL)
    # The tunnel's ceiling lights.
    m.block(g, "LightStrip", TX1, W, TUN_TOP - 0.2, TUN_TOP, 2.7, 3.3, "purple", **DETAIL)
    for x in (4, 16, 28):
        node = m.block(g, "Lamp", x - 1, x + 1, TUN_TOP - 0.2, TUN_TOP, 0.5, 2.3, "lamp", **DETAIL)
        node["children"] = [{"name": "Glow", "className": "PointLight", "properties": {
            "Brightness": 0.5, "Range": 16, "Color": m.rgb((215, 230, 255)), "Shadows": False}}]


def railing(m, g, a, b):
    """An invisible solid guard 3.2 high on the deck from a to b (x, z), with posts and a thin
    top rail and mid rail you see (the posts are wider than the rails, so no faces meet)."""
    (ax, az), (bx, bz) = a, b
    along_x = abs(az - bz) < 1e-6
    c = az + 0.15 if along_x else ax - 0.15  # the railing's centre line, on the deck

    def bar(lo, hi, half, y0, y1, name):
        if along_x:
            m.block(g, name, lo, hi, y0, y1, c - half, c + half, "rail", **DETAIL)
        else:
            m.block(g, name, c - half, c + half, y0, y1, lo, hi, "rail", **DETAIL)

    lo, hi = (ax, bx) if along_x else (az, bz)
    if along_x:
        m.block(g, "RailGuard", lo, hi, UPY, UPY + 3.2, az, az + 0.3, "rail", Transparency=1,
                CastShadow=False)
    else:
        m.block(g, "RailGuard", ax - 0.3, ax, UPY, UPY + 3.2, lo, hi, "rail", Transparency=1,
                CastShadow=False)
    bar(lo, hi, 0.1, UPY + 3.0, UPY + 3.2, "Rail")
    bar(lo, hi, 0.05, UPY + 1.6, UPY + 1.72, "Rail")
    n = max(1, round((hi - lo) / 3.5))
    for i in range(n + 1):
        p = min(max(lo + (hi - lo) * i / n, lo + 0.3), hi - 0.3)
        bar(p - 0.15, p + 0.15, 0.15, UPY, UPY + 3.0, "Post")


def build_upper(m):
    g = "Upper"
    m.block(g, "Catwalk", -W, CW_IN, UPY - DT, UPY, CW_END, L, "grate")
    m.block(g, "Bridge", CW_IN, BR_END, UPY - DT, UPY, BR_IN, L, "grate")
    # Light strips on the deck edges; cyan on the open ends, where the pads land.
    for z0, z1 in ((CW_END, LADDER_Z - 1.5), (LADDER_Z + 1.5, BR_IN)):  # (not over the ladder)
        m.block(g, "LightStrip", CW_IN + 0.05, CW_IN + 0.15, UPY - 0.6, UPY - 0.3, z0, z1, "lamp", **DETAIL)
    m.block(g, "LightStrip", CW_IN, BR_END, UPY - 0.6, UPY - 0.3, BR_IN - 0.15, BR_IN - 0.05, "lamp", **DETAIL)
    m.block(g, "LightStrip", -W, CW_IN, UPY - 0.65, UPY - 0.15, CW_END - 0.15, CW_END - 0.05, "cyan", **DETAIL)
    m.block(g, "LightStrip", BR_END + 0.05, BR_END + 0.15, UPY - 0.65, UPY - 0.15, BR_IN, L, "cyan", **DETAIL)
    # Brackets from the walls up to the decks' undersides.
    for z in RIBS:
        if z < CW_END or abs(z - LADDER_Z) < 3:
            continue
        between(m, g, "Bracket", (-W + 0.6, 11.5, z), (CW_IN - 0.8, UPY - DT - 0.2, z), 0.4, 0.4,
                "metal", **DETAIL)
    for x in (-16, -4, 8):
        between(m, g, "Bracket", (x, 11.5, L - 0.2), (x, UPY - DT - 0.2, BR_IN + 0.8), 0.4, 0.4,
                "metal", **DETAIL)
    for z in (-24, -12, 0, 12, 24, 36):  # lamps under the catwalk
        node = m.block(g, "Lamp", -29, -27, UPY - DT - 0.15, UPY - DT, z - 0.6, z + 0.6, "lamp", **DETAIL)
        if z in (-12, 24):
            node["children"] = [{"name": "Glow", "className": "SpotLight", "properties": {
                "Face": "Bottom", "Range": 22, "Angle": 100, "Brightness": 0.7,
                "Color": m.rgb((240, 248, 255)), "Shadows": False}}]
    railing(m, g, (CW_IN, CW_END), (CW_IN, LADDER_Z - 1.5))
    railing(m, g, (CW_IN, LADDER_Z + 1.5), (CW_IN, BR_IN))
    railing(m, g, (CW_IN, BR_IN), (BR_END, BR_IN))
    # The ladder, flush on a post under the catwalk's edge.
    m.block(g, "LadderPost", CW_IN - 2, CW_IN, 0, UPY - DT, LADDER_Z - 2, LADDER_Z + 2, "panel")
    m.ladder(g, CW_IN, LADDER_Z, (1, 0), 0, UPY, width=2)


def build_pads(m):
    g = "Gadgets"
    for name, ((x, y, z), velocity) in PADS.items():
        m.cylinder(g, name, 0.4, 5.4, (x, y + 0.2, z), "padrim",
                   attributes={"LaunchVelocity": vec(*velocity)})
        glow(m.cylinder(g, "PadGlow", 0.1, 4.2, (x, y + 0.45, z), "cyan", **DETAIL),
             m.rgb((90, 200, 230)), 0.7, 14)


def build_walls_detail(m):
    g = "Detail"
    # The wall-run strip: a dark band with cyan lines and squares, 4 to 8 up along the left wall.
    m.block(g, "RunBand", -W + 0.05, -W + 0.2, 3.9, 8.1, -30, 30, "band", **DETAIL)
    for y0 in (3.9, 7.9):
        m.block(g, "LightStrip", -W + 0.25, -W + 0.35, y0, y0 + 0.2, -30, 30, "cyan", **DETAIL)
    for i in range(8):
        z = -26.25 + 7.5 * i
        node = m.block(g, "RunLight", -W + 0.25, -W + 0.35, 5.2, 6.8, z - 0.8, z + 0.8, "cyan", **DETAIL)
        if i % 2 == 0:
            glow(node, m.rgb((90, 200, 230)), 0.45, 12)
    # Light strips along the walls.
    # The airlock in the front wall (closed: a panel on the wall), under the bridge.
    m.block(g, "Airlock", 4, 16, 0, 11.2, L - 0.2, L - 0.05, "metal", **DETAIL)
    m.block(g, "AirlockSeam", 9.9, 10.1, 0.2, 11, L - 0.3, L - 0.2, "orange", **DETAIL)
    m.block(g, "AirlockFrame", 3.2, 16.8, 11.2, 12, L - 0.35, L - 0.05, "trim", **DETAIL)
    for x0 in (3.2, 16):
        m.block(g, "AirlockFrame", x0, x0 + 0.8, 0, 11.2, L - 0.35, L - 0.05, "trim", **DETAIL)
    m.block(g, "LightStrip", 3.2, 16.8, 12.1, 12.35, L - 0.25, L - 0.15, "orange", **DETAIL)
    # Ceiling beams and light panels (the middle row lights the hall).
    for k in range(8):
        z = -38.5 + 11 * k
        m.block(g, "CeilingBeam", -W, W, CEIL - 1.2, CEIL, z - 0.6, z + 0.6, "panel", **DETAIL)
    for k in range(7):
        z = -33 + 11 * k
        for x in (-16, 0, 16):
            if x == 0:
                node = surface_light(m, g, "CeilingLight", x - 3.5, x + 3.5, CEIL - 0.2, CEIL,
                                     z - 1.5, z + 1.5, "lamp", reach=44, brightness=0.75)
                node["children"][0]["properties"]["Color"] = m.rgb((205, 222, 255))
            else:
                m.block(g, "CeilingLight", x - 3.5, x + 3.5, CEIL - 0.2, CEIL, z - 1.5, z + 1.5,
                        "lamp", **DETAIL)
    # Props: a console and a crate on the step, a crate on the floor.
    m.block(g, "Console", 20, 26, 1, 4, -42.6, -40.4, "trim")
    m.block(g, "Crate", 27, 30, 1, 4, -41.5, -38.5, "metal")
    m.block(g, "Crate", 8.5, 11.5, 0, 3, -11.5, -8.5, "metal")
    m.block(g, "CrateStripe", 8.6, 11.4, 3, 3.1, -10.2, -9.8, "orange", **DETAIL)


def build_more_detail(m):
    g = "Detail"
    near_door = lambda z: any(abs(z - dz) < 4.6 for _, dz, _ in DOORS)  # noqa: E731
    # Ribs up the side walls, in line with the ceiling beams (not over the wall-run band, the
    # catwalk or the doors), and a dark kick plate along the foot of each wall.
    for z in RIBS:
        cuts = []
        if -30 < z < 30:
            cuts.append((3.7, 8.3))
        if z > CW_END:
            cuts.append((UPY - DT - 0.1, UPY + 0.1))
        y = 1.2
        for c0, c1 in cuts + [(CEIL - 1.2, CEIL)]:
            m.block(g, "Rib", -W + 0.05, -W + 0.55, y, c0, z - 0.6, z + 0.6, "rib", **DETAIL)
            y = c1
        if not near_door(z):
            m.block(g, "Rib", W - 0.55, W - 0.05, 1.2, CEIL - 1.2, z - 0.6, z + 0.6, "rib", **DETAIL)
    m.block(g, "KickPlate", -W + 0.05, -W + 0.3, 0, 1.2, -L, L, "kick", **DETAIL)
    z = -L
    for _, dz, _ in DOORS:
        m.block(g, "KickPlate", W - 0.3, W - 0.05, 0, 1.2, z, dz - DW / 2 - 0.7, "kick", **DETAIL)
        z = dz + DW / 2 + 0.7
    m.block(g, "KickPlate", W - 0.3, W - 0.05, 0, 1.2, z, L, "kick", **DETAIL)
    # Floor seams every 8 across the right floor and the left walkway.
    for z in range(-32, 44, 8):
        m.block(g, "Seam", TX1 + 1.1, W - 0.35, 0, 0.06, z - 0.1, z + 0.1, "seam", **DETAIL)
        m.block(g, "Seam", -W + 0.35, TX0 - 1.1, 0, 0.06, z - 0.1, z + 0.1, "seam", **DETAIL)
    # Pipes along the ceiling, hanging from the beams.
    for x, radius, color in ((-11, 0.45, "pipe"), (-9.9, 0.3, "redpipe"), (21, 0.5, "pipe")):
        m.part(g, "Pipe", (2 * L - 0.1, 2 * radius, 2 * radius), (x, CEIL - 1.2 - radius, 0),
               color, rot_y(90), Shape="Cylinder", **DETAIL)
    # Vents high on the end walls.
    for x0 in (-26, 20):
        m.block(g, "Vent", x0, x0 + 6, 24, 27, L - 0.25, L - 0.05, "vent", **DETAIL)
        m.block(g, "Vent", x0, x0 + 6, 24, 27, -L + 0.05, -L + 0.25, "vent", **DETAIL)
    # Cargo: a stack of crates on the right floor (jump up them), one more by the front.
    for x0, y0, z0 in ((19, 0, 14), (23.2, 0, 14), (21.1, 4, 14), (11, 0, 24)):
        m.block(g, "Cargo", x0, x0 + 4, y0, y0 + 4, z0, z0 + 4, "metal")
        m.block(g, "CargoStripe", x0 + 0.3, x0 + 3.7, y0 + 1.6, y0 + 2.2, z0 - 0.15, z0 - 0.05,
                "orange", **DETAIL)
    # A terminal against the left wall by the front, its screen softly lit.
    m.block(g, "Terminal", -W, -28.5, 0, 3.6, 31, 36, "trim")
    glow(m.block(g, "TerminalScreen", -28.45, -28.35, 1.8, 3.2, 31.5, 35.5, "screen", **DETAIL),
         m.rgb((90, 160, 230)), 0.4, 10)
    # A bench on the step, facing the window.
    m.block(g, "Bench", 4, 16, 1, 2.6, -39.6, -38.2, "kick")
    glow(m.block(g, "ConsoleScreen", 20.5, 25.5, 2.7, 3.9, -40.35, -40.25, "screen", **DETAIL),
         m.rgb((90, 160, 230)), 0.4, 10)
    for x in (-19.5, 19.5):
        glow(m.block(g, "LightStrip", x - 0.25, x + 0.25, 4, 26, -L + 0.05, -L + 0.15, "cyan",
                     **DETAIL), m.rgb((90, 200, 230)), 0.5, 14)


def build_doors(m):
    g = "Doors"
    for name, dz, color in DOORS:
        center = vec(W + WALL / 2, DH / 2, dz)
        for sign in (-1, 1):  # the two leaves, each sliding into the wall its own way
            z0, z1 = sorted((dz, dz + sign * DW / 2))
            attrs = {"Door": name, "DoorSlide": vec(0, 0, sign * DW / 2), "DoorCenter": center}
            m.block(g, "DoorLeaf", W + 0.35, W + 0.65, 0, DH, z0, z1, "metal", attributes=attrs)
            edge = dz + sign * 0.35
            for x0, x1 in ((W + 0.25, W + 0.3), (W + 0.7, W + 0.75)):
                m.block(g, "DoorLight", x0, x1, 1.2, DH - 1.2, edge - 0.1, edge + 0.1, color,
                        attributes=dict(attrs), **DETAIL)
        for face, (x0, x1) in ((-1, (W - 0.3, W - 0.05)), (1, (W + WALL + 0.05, W + WALL + 0.3))):
            m.block(g, "DoorFrame", x0, x1, 0, DH + 0.6, dz - DW / 2 - 0.6, dz - DW / 2, "trim", **DETAIL)
            m.block(g, "DoorFrame", x0, x1, 0, DH + 0.6, dz + DW / 2, dz + DW / 2 + 0.6, "trim", **DETAIL)
            m.block(g, "DoorFrame", x0, x1, DH, DH + 0.6, dz - DW / 2, dz + DW / 2, "trim", **DETAIL)
            gx0, gx1 = (x0 - 0.1, x0) if face < 0 else (x1, x1 + 0.1)
            glow(m.block(g, "DoorLight", gx0, gx1, DH + 0.15, DH + 0.45, dz - DW / 2, dz + DW / 2, color, **DETAIL),
                 m.rgb(COLORS[color]), 0.6, 12)


def build_hallway(m):
    g = "Hallway"
    # Outer wall with windows to space, end walls, the roof.
    m.wall(g, "Z", (HX1, HX1 + WALL), (HZ0 - WALL, HZ1 + WALL), BOT, HH + WALL, "panel",
           openings=[(z, z + 6, 9, 3) for z in range(HZ0 + 4, HZ1 - 7, 8)],
           glass=COLORS["glass"], frame=COLORS["trim"])
    m.block(g, "Wall", HX0, HX1, BOT, HH + WALL, HZ0 - WALL, HZ0, "panel")
    m.block(g, "Wall", HX0, HX1, BOT, HH + WALL, HZ1, HZ1 + WALL, "panel")
    m.block(g, "HallwayRoof", HX0, HX1, HH, HH + WALL, HZ0, HZ1, "panel")
    # Floor: a bottom slab, landings at the doors, two ramps down to the flat middle.
    m.block(g, "Floor", HX0, HX1, BOT, TD, HZ0, HZ1, "grate")
    m.block(g, "Floor", HX0, HX1, TD, 0, HZ0, RS0, "floor")
    m.block(g, "Floor", HX0, HX1, TD, 0, RN1, HZ1, "floor")
    mid_x = (HX0 + HX1) / 2
    for z_hi, z_lo in ((RS0, TUN0), (RN1, TUN1)):
        length = abs(z_lo - z_hi)
        node = m.part(g, "Ramp", (HX1 - HX0, -TD, length), (mid_x, TD / 2, (z_hi + z_lo) / 2),
                      "floor", rot_y(180) if z_hi < z_lo else rot_y(0))
        node["className"] = "WedgePart"
        for x in (HX0 + 0.05, HX1 - 0.05):  # purple lines on the walls along the ramp
            between(m, g, "LightStrip", (x, 0.6, z_hi), (x, TD + 0.6, z_lo), 0.1, 0.2, "purple", **DETAIL)
    for k in range(6):
        z = HZ0 + 5 + 11 * k
        node = surface_light(m, g, "CeilingLight", mid_x - 1.2, mid_x + 1.2, HH - 0.2, HH, z - 1,
                             z + 1, "lamp", reach=26, brightness=0.55)
        node["children"][0]["properties"]["Color"] = m.rgb((205, 222, 255))


def build_space(m):
    g = "Space"
    m.part(g, "Earth", (320, 320, 320), (0, -135, -330), "earth", Shape="Ball", **DETAIL)
    m.part(g, "Atmosphere", (332, 332, 332), (0, -135, -330), "air", Shape="Ball",
           Transparency=0.82, **DETAIL)
    for i, (dx, dy, dz) in enumerate(((0.25, 0.85, 0.46), (-0.4, 0.8, 0.45), (0.05, 0.7, 0.71),
                                      (0.55, 0.65, 0.52), (-0.15, 0.95, 0.27))):
        n = math.sqrt(dx * dx + dy * dy + dz * dz)
        d = 102 - 3 * (i % 2)
        m.part(g, "Land", (120, 120, 120), (dx / n * d, -135 + dy / n * d, -330 + dz / n * d),
               "land", Shape="Ball", **DETAIL)
    # Satellites: big, light-coloured and lit by a lamp of their own so they read against space.
    for x, y, z, k in ((-8, 36, -130, 1.0), (26, 10, -175, 0.7), (-32, 4, -215, 0.5),
                       (112, 20, 6, 0.8)):
        satellite(m, g, x, y, z, k)


def satellite(m, g, x, y, z, k):
    """A satellite centred at (x, y, z), `k` times full size (full: about 66 across): a gold
    body, two wings of three solar panels in white frames, a dish and an antenna."""
    def box(name, x0, x1, y0, y1, z0, z1, color):
        m.block(g, name, x + x0 * k, x + x1 * k, y + y0 * k, y + y1 * k, z + z0 * k, z + z1 * k,
                color, **DETAIL)
    box("Satellite", -4, 4, -3, 3, -4, 4, "foil")
    box("Satellite", -4.2, 4.2, -0.5, 0.5, -4.2, 4.2, "white")
    for side in (-1, 1):
        a, b = sorted((side * 4, side * 6))
        box("SatelliteArm", a, b, -0.4, 0.4, -0.4, 0.4, "white")
        for i in range(3):
            p0 = 6 + i * 9.4
            a, b = sorted((side * p0, side * (p0 + 9)))
            box("SolarPanel", a, b, -0.15, 0.15, -6, 6, "panelblue")
            fa, fb = sorted((side * (p0 + 9), side * (p0 + 9.4)))
            box("SolarFrame", fa, fb, -0.25, 0.25, -6.2, 6.2, "white")
            box("SolarFrame", a, b, -0.25, 0.25, -6.2, -6.0, "white")
            box("SolarFrame", a, b, -0.25, 0.25, 6.0, 6.2, "white")
    m.part(g, "SatelliteDish", (0.8 * k, 9 * k, 9 * k), (x, y + 1 * k, z + 4.4 * k), "dish",
           [[0, 0, 1], [0, 1, 0], [-1, 0, 0]], Shape="Cylinder", **DETAIL)
    box("SatelliteAntenna", -0.25, 0.25, 3, 9, -0.25, 0.25, "white")
    glow(m.block(g, "SatelliteLamp", x - 0.5, x + 0.5, y + 10 * k, y + 11 * k, z + 18 * k,
                 z + 19 * k, "white", Transparency=1, **DETAIL), m.rgb((255, 250, 240)), 2, 60)


def build():
    m = Map(colors=COLORS, materials=MATERIALS)
    build_shell(m)
    build_floors(m)
    fix_right_wall(m)
    build_trench(m)
    build_upper(m)
    build_pads(m)
    build_walls_detail(m)
    build_more_detail(m)
    build_doors(m)
    build_hallway(m)
    build_space(m)
    for x, z in SPAWNS:
        m.spawn(x, z)
    return m


def check(m):
    problems = mapcheck.check_map(m, ATTRIBUTES)
    # Each pad must throw you onto its target.
    nodes = [n for group in m.groups.values() for n in group]
    reach = mapcheck.Reach(mapcheck.parts_from_nodes(nodes), [(x, y + 0.5, z) for x, y, z in m.spawns])
    reach.build()
    for name, ((x, y, z), velocity) in PADS.items():
        landing = reach.fly(x, y + 0.4 + mapcheck.ROOT, z, *velocity)
        where = reach.nodes[landing][:3] if landing is not None else None
        print(f"{name}: lands at {where} (x, z, y)")
        if where is None or abs(where[2] - PAD_TARGETS[name]) > 0.6:
            problems.append(f"{name} doesn't land at {PAD_TARGETS[name]} ({where})")
    for i, (x, z) in enumerate(SPAWNS):
        for j in range(i):
            if math.dist((x, z), SPAWNS[j]) < 18:
                problems.append(f"spawns {j + 1} and {i + 1} are under 18 studs apart")
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
