#!/usr/bin/env python3
"""Tag Mart (2-6 players): a small supermarket, 70 x 56, on three layers. Designed on the
"Tag Mart" design canvas and ported from its design data (tools/designs/market_v1.json, the
canvas's export; its generator never made it into the repo). Run from the repo root:
    python3 tools/market_layout.py
It rewrites `src/maps/TagMart/` (generated: don't edit those files by hand); Rojo syncs it.

The shop floor: aisles of shelves either side of a wide promo aisle (a stand with a turning sign,
sale tables, pallets), checkouts with belts that are speed strips, produce (bins, a cooler wall,
a misting gantry to slide under), freezers (a chest-freezer island, a wall of freezer doors to
wall-run), the service desk, a cart corral and a kiddie ride by the doors. The shelf tops (7 up)
are running lanes: get up from a pallet, a produce bin, the freezer island or checkout belt 2 and
jump the 6-stud aisles; sale banners hang across the promo aisle (18 across: wall-run a banner or
slide-jump). The back: slide under the deli hatch into the kitchen, on through the stockroom
(slide under the rack, or the half-down shutter back to the shop floor) and up the stockroom
ladder to the manager's office (9 up) over the deli. The design's cleaning robot (Scrubby) is
left out.

Axes: X east, Z south, Y up. Floor at 0, ceiling 20.
"""
import os
import sys

sys.path.insert(0, "tools")
sys.path.insert(0, "tools/designs")
import canvas_import as ci  # noqa: E402
import mapcheck  # noqa: E402
from maplib import Map  # noqa: E402

DESIGN = "tools/designs/market_v1.json"
OUT = "src/maps/TagMart"
ATTRIBUTES = {"DisplayName": "Tag Mart", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "Lighting": "Indoor", "OutOfBounds": "Ceiling,WallTop"}
BELT_BOOST = 40  # studs/s off a checkout belt (the export doesn't keep the value: tune in game)
SILL_DROP = 0.1  # window sill strips sit this much lower than the design (clear of the glass)
LADDER = (-10.0, -25, (1, 0), 0, 9)  # the stockroom ladder up to the office: x, z, facing, y0, y1

# What each of the design's styles is: (name, material, group).
STYLES = {
    0: ("Floor", "CeramicTiles", "Building"), 1: ("Floor", "CeramicTiles", "Building"),
    2: ("Floor", "CeramicTiles", "Building"), 3: ("Floor", "Concrete", "Building"),
    4: ("Wall", "Plaster", "Building"), 5: ("Window", "Glass", "Building"),
    6: ("Trim", "SmoothPlastic", "Detail"), 7: ("Ceiling", "Concrete", "Building"),
    8: ("Steel", "Metal", "Fixtures"), 17: ("ShelfEdge", "SmoothPlastic", "Detail"),
    22: ("Sign", "SmoothPlastic", "Detail"), 23: ("Sign", "SmoothPlastic", "Detail"),
    24: ("EndCap", "SmoothPlastic", "Detail"), 25: ("RackPost", "Metal", "Fixtures"),
    26: ("Pallet", "WoodPlanks", "Detail"), 27: ("DeliGlass", "Glass", "Fixtures"),
    36: ("FreezerDoor", "Glass", "Detail"), 37: ("FreezerLid", "Glass", "Detail"),
    38: ("Sign", "SmoothPlastic", "Detail"), 39: ("LaneLight", "Neon", "Detail"),
    45: ("CounterTop", "WoodPlanks", "Detail"), 46: ("StripCurtain", "Glass", "Detail"),
    47: ("Boxes", "Cardboard", "Fixtures"), 48: ("Light", "Neon", "Detail"),
    49: ("Shelf", "Metal", "Fixtures"), 50: ("Table", "WoodPlanks", "Fixtures"),
    51: ("Cooler", "Metal", "Fixtures"), 52: ("StandBlocker", "SmoothPlastic", "Fixtures"),
    53: ("Freezer", "Metal", "Fixtures"), 54: ("Counter", "Metal", "Fixtures"),
    55: ("Belt", "Rubber", "Fixtures"), 56: ("BackWall", "Plaster", "Building"),
    57: ("Oven", "Metal", "Fixtures"), 58: ("Office", "Plaster", "Building"),
}
PRODUCTS = set(range(9, 22)) - {17}  # boxes on the shelves, one color each
PRODUCE = set(range(28, 36))  # fruit in the bins, labels on the cooler wall
MENUS = set(range(40, 45))  # the deli's menu boards


def describe(part):
    """(name, material, group) for a part."""
    style, flags, size = part["style"], part["flags"], part["size"]
    sx, sy, sz = size
    if style in PRODUCTS:
        return "Products", "SmoothPlastic", "Detail"
    if style in PRODUCE:
        return "Produce", "SmoothPlastic", "Detail"
    if style in MENUS:
        return "MenuBoard", "SmoothPlastic", "Detail"
    name, material, group = STYLES[style]
    if style == 4 and flags & ci.ROOF:
        name = "WallTop"
    elif style == 8:
        name = "Beam" if flags & ci.ROOF else "Steel" if flags & ci.DETAIL else "Gantry"
    elif style in (22, 23) and not flags & ci.DETAIL:
        name, group = "Banner", "Fixtures"
    elif style == 23 and part["motion"]:
        name = "KiddieRide"
    elif style == 47 and flags & ci.DETAIL:
        group = "Detail"
    elif style == 50:
        name = ("Hatch" if sy > 4 else "Desk" if part["pos"][1] > 9 else
                "ProduceBin" if sz > 5 else "SaleTable")
    elif style == 54:
        name = ("ServiceDesk" if sx > 5 and sz > 3 else "DeliCounter" if sx > 15 else
                "Checkout")
    elif style == 56 and sy < 4:
        name = "Oven"
    elif style == 58:
        name = "OfficeFloor" if sy < 1 else "Office"
    if flags & ci.DETAIL:
        group = "Detail"
    return name, material, group


def build():
    data = ci.load(DESIGN)
    m = Map()
    texts = {}
    for index, face, text, color_hex, glow in data["texts"]:
        color = tuple(int(color_hex[i:i + 2], 16) for i in (0, 2, 4))
        texts.setdefault(index, []).append(m.surface_text(face, text, color, glow=bool(glow)))
    for part in ci.parts(data):
        motion = part["motion"]
        if motion and motion.get("mover"):
            continue  # Scrubby, the cleaning robot: not in this map
        if part["style"] == 57 and part["flags"] & ci.DETAIL:
            continue  # the ladder's rails and rungs: built again below with its truss
        name, material, group = describe(part)
        if part["style"] == 6 and part["size"][0] >= 7 and part["size"][1] == 0.4:
            # Window sills: the design's poke 0.1 up into the glass; sit them just under it.
            x, y, z = part["pos"]
            part["pos"] = (x, y - SILL_DROP, z)
        props = ci.props(part, material)
        attributes = {}
        children = texts.get(part["index"])
        if part["flags"] & ci.GATE:  # slide gates: an invisible blocker for standing players
            name, props = "StandBlocker", {"Transparency": 1, "CastShadow": False}
            attributes["SlideBlocker"] = True
        if part["flags"] & ci.BOOST:
            attributes["SpeedBoost"] = BELT_BOOST
        if motion and "spin" in motion:
            attributes["Spin"] = motion["spin"]
            if motion.get("c"):
                attributes["SpinCenter"] = {"Vector3": [motion["c"][0], 0, motion["c"][1]]}
        if name == "Light" and int(part["pos"][0]) % 2 == 0:
            children = (children or []) + [{"name": "Glow", "className": "PointLight",
                                            "properties": {"Brightness": 0.6, "Range": 24,
                                                           "Color": m.rgb((255, 248, 236)),
                                                           "Shadows": False}}]
        if attributes:
            props["attributes"] = attributes
        m.part(group, name, part["size"], part["pos"], part["color"], part["rows"],
               children=children, **props)
    x, z, facing, y0, y1 = LADDER
    m.ladder("Fixtures", x, z, facing, y0, y1, color=(70, 74, 82))
    for x, y, z in data["spawns"]:
        m.spawn(x, z, y - 0.5)
    return m


def check(m):
    return mapcheck.check_map(m, ATTRIBUTES)


if __name__ == "__main__":
    layout = build()
    issues = check(layout)
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns")
    for line in issues:
        print("PROBLEM:", line)
    layout.write(OUT, ATTRIBUTES)
    print(f"wrote {OUT}/ (Rojo syncs it into ServerStorage.Maps)")
    raise SystemExit(1 if issues else 0)
