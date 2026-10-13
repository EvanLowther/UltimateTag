#!/usr/bin/env python3
"""The Metro (2-6 players): an underground station, one long island platform between two
tracks, and one train running a loop. Designed on the "Metro Map" design canvas and ported from
its design data (tools/designs/metro_v1.json, the canvas's export: every part, the train's track
and timetable). Run from the repo root:
    python3 tools/metro_layout.py
It rewrites `src/maps/Metro/` (generated: don't edit those files by hand); Rojo syncs it.

The train picks up on the green side (track A, boarding), takes whoever got on round the long
west loop under the city, comes back on the pink side (track B, exit only: everyone is pushed
out of the nearest door), runs round the east loop empty and waits out of sight for a random
few seconds before coming in again. The map's TrainLine module is the track and timetable
(shared/TrainLine works out where the train is at any moment); its parts carry TrainCar,
TrainDoor, TrainGang/TrainGangT, TrainFx and TrainWarn attributes for client/Trains.

Axes: X east, Z south, Y up. Platform top at 0, track pits 4 deep, ceiling 18. Anyone on the
tracks or in front of the train when it comes in is killed (server/Trains); past the ends of the
platform the tunnel floor gives way (KillHeight). Both are deaths during a round: FallEliminates.
"""
import json
import os
import sys

sys.path.insert(0, "tools")
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map  # noqa: E402

DESIGN = "tools/designs/metro_v1.json"
OUT = "src/maps/Metro"
ATTRIBUTES = {"DisplayName": "The Metro", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "KillHeight": -25, "FallEliminates": True, "Lighting": "Indoor",
              "OutOfBounds": "Ceiling,WallTop,CarRoof,Kiosk,Vending,Shed,StaffRoomRoof,Tunnel,"
                             "TunnelRoof"}
FIRST_WAIT = 3  # seconds the train waits before its first run in a round

# The design's flags: 1 cylinder, 2 detail (no collision), 4 roof or ceiling, 8 slide gate,
# 128 tunnel.
CYLINDER, DETAIL, ROOF, GATE, TUNNEL = 1, 2, 4, 8, 128

# What each of the design's styles is: (name, material). Some styles cover several things; those
# get their names from `role` below.
STYLES = {
    0: ("TrackBed", "Slate"), 1: ("PlatformBody", "Concrete"), 2: ("PlatformFloor", "Concrete"),
    3: ("PlatformEdge", "Concrete"), 4: ("SafetyLine", "SmoothPlastic"),
    5: ("TactileStrip", "Concrete"), 6: ("Shed", "Metal"), 7: ("StandBlocker", "SmoothPlastic"),
    8: ("Steel", "Metal"), 9: ("Kiosk", "SmoothPlastic"), 10: ("Livery", "SmoothPlastic"),
    11: ("Vending", "SmoothPlastic"), 12: ("StaffRoom", "Metal"), 13: ("Shutter", "DiamondPlate"),
    14: ("Bench", "Wood"), 15: ("Wall", "CeramicTiles"), 16: ("GreenLane", "SmoothPlastic"),
    17: ("PinkLane", "SmoothPlastic"), 18: ("EdgeLight", "Neon"), 19: ("Trim", "SmoothPlastic"),
    20: ("Poster", "SmoothPlastic"), 21: ("Poster", "SmoothPlastic"),
    22: ("Poster", "SmoothPlastic"), 23: ("Poster", "SmoothPlastic"),
    24: ("ExitSign", "SmoothPlastic"), 25: ("DepartureBoard", "SmoothPlastic"),
    26: ("Ceiling", "Concrete"), 27: ("Light", "Neon"), 28: ("Sleeper", "Wood"),
    29: ("Rail", "Metal"), 30: ("ConductorRail", "Metal"), 31: ("Tunnel", "Concrete"),
    32: ("OldPlatform", "Concrete"), 33: ("OldNameStrip", "SmoothPlastic"),
    34: ("Void", "SmoothPlastic"), 35: ("CarFloor", "DiamondPlate"), 36: ("Bogie", "Metal"),
    37: ("CarBody", "Metal"), 38: ("CarGlass", "Glass"), 39: ("CabGlass", "Glass"),
    40: ("Headlight", "Neon"), 41: ("DestinationSign", "Neon"), 42: ("Gate", "Glass"),
    43: ("CarRoof", "Metal"), 44: ("CarSeat", "Fabric"), 45: ("PushArrow", "Neon"),
    46: ("GlassScreen", "Glass"), 47: ("TailLight", "Neon"),
}

POSTERS = ("TAG CITY", "RUN!", "DON'T GET CAUGHT", "MIND THE GAP", "LOOP LINE", "NEXT STOP: YOU")


def role(style, size, flags, motion, pos):
    """A name for parts whose style covers several things."""
    sx, sy, sz = size
    if style == 4:
        if motion and "door" in motion:
            return "Door"
        if motion:
            return "GrabPole"
        return "HazardStripe" if sy > 0.5 or sz < 0.1 or sx < 0.1 else "SafetyLine"
    if style == 8:
        if motion:
            return "Wheel"
        return "ScaffoldPost" if sy > 4 and sx > 0.3 else "Rod"
    if style == 9:
        return "Kiosk" if sx > 5 else "Bollard"
    if style == 10:
        return "Vending" if not flags & DETAIL else "Livery"
    if style == 12:
        return "StaffRoomRoof" if sy < 1 else "StaffRoom"
    if style == 13:
        return "Shutter" if not flags & DETAIL else "LineMap"
    if style == 14:
        return "OldBench" if flags & TUNNEL else "Bench"
    if style == 15:
        if sx < 2 and sz < 2:
            return "Column"
        return "WallTop" if flags & ROOF else "Wall"
    if style in (16, 17):
        lane = "Green" if style == 16 else "Pink"
        if sy < 0.1:
            return lane + "LaneMark"
        if sx > 100:
            return lane + "Stripe"
        return lane + "LaneSign" if sz > 3 else lane + "ColumnBand"
    if style == 19:
        if motion and "gang" in motion:
            return "Gangway"
        if motion:
            return "CarTrim"
        return "NameBoard" if sx > 10 and sy > 2 else "Trim"
    if style == 20 and motion:
        return "CarSign"
    if style == 27:
        if flags & TUNNEL:
            return "TunnelLight"
        return "CarLight" if motion else "Light"
    if style == 29:
        return "Rail"
    if style == 31:
        return "TunnelRoof" if flags & ROOF else "Tunnel"
    if style == 35 and motion and "gang" in motion:
        return "GangwayFloor"
    if style == 36:
        if motion and "gang" in motion:
            return "Gangway"
        return "Bogie" if sy > 1 else "RoofUnit"
    if style == 43:
        return "CarRoof"
    return STYLES[style][0]


def text_face(size, pos):
    """The face of a flat sign that looks into the station."""
    sx, _, sz = size
    if sz <= sx:  # thin along Z: on a wall along X
        return "Back" if pos[2] < 0 else "Front"
    return "Right" if pos[0] < 0 else "Left"


def build():
    data = json.load(open(DESIGN))["v1"]
    m = Map()
    styles, rots, motions = data["styles"], data["rots"], data["motions"]
    posters = 0
    for p in data["parts"]:
        style, x, y, z, sx, sy, sz, ri, flags, mi = p
        motion = motions[mi] if mi >= 0 else None
        if motion and motion.get("fx") == "nose":
            continue  # the design's danger box in front of the train (viewer only)
        color_hex, code, alpha = styles[style]
        color = tuple(int(color_hex[i:i + 2], 16) for i in (0, 2, 4))
        name = role(style, (sx, sy, sz), flags, motion, (x, y, z))
        r = rots[ri]
        rows = [r[0:3], r[3:6], r[6:9]]
        props = {"Material": STYLES[style][1]}
        if flags & CYLINDER:
            props["Shape"] = "Cylinder"
        if flags & DETAIL:
            props.update(NO_HIT)
        if code == "n":
            props["Material"] = "Neon"
        if code == "g":
            props["Material"] = "Glass"
            props["Transparency"] = round(1 - alpha, 2)
            props["CastShadow"] = False
        attributes = {}
        children = None
        if flags & GATE:  # slide gates: an invisible blocker that only stops standing players
            name = "StandBlocker"
            props = {"Transparency": 1, "CastShadow": False}
            attributes["SlideBlocker"] = True
        if motion:
            if "car" in motion:
                attributes["TrainCar"] = motion["car"] + 1
            if "door" in motion:
                attributes["TrainDoor"] = motion["door"]
            if "gang" in motion:
                attributes["TrainGang"] = motion["gang"] + 1
                attributes["TrainGangT"] = motion.get("t", 0.5)
            if "warn" in motion:
                attributes["TrainWarn"] = motion["warn"]
            if motion.get("fx") == "push":
                attributes["TrainFx"] = "Push"
            if motion.get("fx") == "gate":
                # No entry at the exit stop: shown and solid only then (client/Trains).
                attributes["TrainFx"] = "Gate"
                props.update({"Transparency": 1, "CanCollide": False, "CanQuery": False,
                              "CanTouch": False})
        # Signs and lights.
        if name == "NameBoard":
            children = [m.surface_text(text_face((sx, sy, sz), (x, y, z)), "THE METRO",
                                       (255, 255, 255), font="GothamBlack", pps=12)]
        elif name == "Poster":
            text = POSTERS[posters % len(POSTERS)]
            posters += 1
            children = [m.surface_text(text_face((sx, sy, sz), (x, y, z)), text, (255, 255, 255),
                                       font="Bangers", pps=12)]
        elif name == "ExitSign":
            children = [m.surface_text(text_face((sx, sy, sz), (x, y, z)), "WAY OUT<br/>(CLOSED)",
                                       (30, 30, 34), font="GothamBlack", pps=12)]
        elif name == "LineMap":
            children = [m.surface_text(text_face((sx, sy, sz), (x, y, z)),
                                       "LOOP LINE<br/>board on green<br/>exit on pink",
                                       (240, 240, 240), font="GothamBlack", pps=12)]
        elif name in ("GreenLaneSign", "PinkLaneSign"):
            text = "BOARD HERE" if name.startswith("Green") else "EXIT ONLY"
            children = [m.surface_text(f, text, (20, 20, 24), font="GothamBlack", pps=12)
                        for f in ("Left", "Right")]
        elif name == "OldNameStrip":
            children = [m.surface_text(f, "OLD TAG STREET", (240, 230, 210), font="GothamBlack",
                                       pps=10) for f in ("Front", "Back")]
        elif name == "Light" and abs(y - 17.7) < 0.1 and int(x) % 2 == 0:
            children = [{"name": "Glow", "className": "PointLight", "properties": {
                "Brightness": 0.7, "Range": 30, "Color": m.rgb((255, 244, 220)),
                "Shadows": False}}]
        elif name == "CarLight":
            children = [{"name": "Glow", "className": "PointLight", "properties": {
                "Brightness": 0.6, "Range": 16, "Color": m.rgb((255, 244, 220)),
                "Shadows": False}}]
        if attributes:
            props["attributes"] = attributes
        group = ("Train" if motion and ("car" in motion or "gang" in motion) else
                 "Tunnels" if flags & TUNNEL else "Station")
        m.part(group, name, (sx, sy, sz), (x, y, z), color, rows, children=children, **props)
    for x, y, z in data["spawns"]:
        m.spawn(x, z, y - 0.5)
    return m, data


def train_module(train):
    """The track and timetable as a Luau module (shared/TrainLine reads it)."""
    def num(v):
        return repr(round(v, 4)) if isinstance(v, float) else repr(v)

    segs = []
    for g in train["segs"]:
        if g[0] == "L":
            segs.append(f'\t\t{{ kind = "L", s0 = {num(g[1])}, len = {num(g[2])}, x = {num(g[3])}, '
                        f'z = {num(g[4])}, heading = {num(g[5])} }},')
        else:
            segs.append(f'\t\t{{ kind = "A", s0 = {num(g[1])}, len = {num(g[2])}, cx = {num(g[3])}, '
                        f'cz = {num(g[4])}, heading = {num(g[5])}, radius = {num(g[6])}, '
                        f'side = {num(g[7])} }},')
    s = train["schedule"]
    run = lambda k: f"{{ {', '.join(num(v) for v in s[k])} }}"  # noqa: E731
    stops = ", ".join(f"{k} = {num(v)}" for k, v in train["stops"].items())
    doors = ", ".join(num(v) for v in train["doors"])
    return "\n".join([
        "-- Generated by tools/metro_layout.py from the Metro design: don't edit by hand.",
        "-- The train's track (lines and arcs, by distance s along it), its stops, the cars and",
        "-- the timetable; shared/TrainLine works out where the train is from these.",
        "return {",
        "\tsegs = {",
        *segs,
        "\t},",
        f"\tlength = {num(train['length'])},",
        f"\tstops = {{ {stops} }},",
        f"\tcars = {train['cars']},",
        f"\tcarLen = {num(train['carLen'])},",
        f"\tgap = {num(train['gap'])},",
        f"\tbogie = {num(train['bogie'])},",
        f"\twidth = {num(train['width'])},",
        f"\tfloorY = {num(train['floorY'])},",
        f"\trestNose = {num(train['restNose'])},",
        f"\tdoors = {{ {doors} }},",
        "\tschedule = {",
        f"\t\tfirstWait = {FIRST_WAIT},",
        *[f"\t\t{k} = {num(s[k])}," for k in ("waitMin", "waitMax", "warn", "doorsOpen", "board",
                                              "doorsClose", "departDelay", "exitOpen",
                                              "exitPush", "exitClose")],
        *[f"\t\t{k} = {run(k)}," for k in ("approach", "ride", "leave")],
        "\t},",
        "}",
        "",
    ])


def check(m):
    return mapcheck.check_map(m, ATTRIBUTES)


if __name__ == "__main__":
    layout, design = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    # The train is one streaming unit, so no client ever has only part of it.
    path = os.path.join(OUT, "Train.model.json")
    node = json.load(open(path))
    node["className"] = "Model"
    node["properties"] = {"ModelStreamingMode": "Persistent"}
    with open(path, "w") as f:
        json.dump(node, f, indent=1)
        f.write("\n")
    with open(os.path.join(OUT, "TrainLine.luau"), "w") as f:
        f.write(train_module(design["train"]))
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
