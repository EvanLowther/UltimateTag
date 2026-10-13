#!/usr/bin/env python3
"""Tag Mart, design v1 (design stage: not in the game yet). 2-6 players: a small supermarket,
70 x 56 inside, on three layers. Shown on the "Tag Mart" design canvas. Built with
tools/maplib.py and checked with tools/mapcheck.py like the real map generators, so it becomes
tools/tagmart_layout.py once the design is settled. Run from the repo root:
    python3 tools/designs/tagmart_v1.py                                     (checks only)
    python3 tools/designs/canvas_export.py tagmart_v1 build/tagmart.json   (for the canvas)

Axes: X east, Z south, Y up. Floor at 0, ceiling at 20 (high enough to jump on the shelves).
  The shop floor: three rows of shelves (12 x 4, 7 high: too high to jump onto) each side of a
    wide promo aisle down the middle, with aisles 6 wide between the rows (inside It's reach, so
    you go out the far end or round the block). Produce along the west wall, freezers along the
    east, checkouts at the front (south), the deli, kitchen and stockroom at the back.
  The shelf tops (7): every shelf top is a running lane. Climb up from a pallet, a produce bin,
    the freezer island or checkout belt 2, and jump row to row across the aisles. Sale banners
    hang across the promo aisle at shelf-top height: the two halves are 18 apart, too far to jump
    at a sprint, so wall-run along a banner (or slide-jump it).
  The office (9): the manager's office over the deli. Jump across from the first row of shelves,
    climb the stockroom ladder, or jump in from the top of the stockroom rack (up from the
    forklift); drop off its open front to get down.
  The back loop: slide under the deli's half-open hatch into the kitchen, out its back door into
    the stockroom (slide under the rack's bottom shelf), back out under the half-down shutter or
    through the strip-curtain door.
Moving parts: Scrubby, a floor-cleaning robot, laps the south half of the store (the front
aisle, aisle 2 and the outer aisles), blocking whichever aisle it's in and shoving anyone it
touches (PathMover "Scrubby", Knockback; stand on it and it carries you); the checkout belts
are speed strips; a sale sign turns over the promo stand.
"""
import math
import os
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map, rot_y  # noqa: E402

OUT = "src/maps/TagMart"
ATTRIBUTES = {"DisplayName": "Tag Mart", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "Lighting": "Indoor", "OutOfBounds": "Ceiling,OfficeRoof"}

# Movement numbers the layout is built round (Config + Roblox defaults; see mapcheck).
GRAVITY = 196.2
JUMP = 7.2  # jump height
SPRINT = 30  # sprint speed
SLIDE_JUMP = 37  # a slide into a jump
WALL_RUN = 30 * 1.6  # studs along a wall in one wall run
CROUCH_ROOM = 4.2  # slide gates: the gap under them (standing needs 5)

# ---- the store -----------------------------------------------------------------------------------
W, D = 35, 28  # inside half width (x) and half depth (z): 70 x 56
CEIL = 20
CUT = 10  # walls are built in two parts, split here (the canvas cuts them away above it)
SHELF_H = 7
ROWS = ((-12, -8), (-2, 2), (8, 12))  # z of the shelf rows (each 4 deep)
HALVES = ((-21, -9), (9, 21))  # x of the shelf blocks each side of the promo aisle
AISLES = ((-8, -2), (2, 8))  # z of the aisles between the rows
BACK = -17  # the back of the store (deli, kitchen, stockroom) is north of this
FRONT = 17  # the checkouts are south of this
PRODUCE = -26  # the produce runs from the west wall to here
FREEZERS = 26  # the freezers run from here to the east wall
PALLETS = ((-9, -5.5, -12, -8), (5.5, 9, 8, 12))  # x0, x1, z0, z1: steps up onto the shelves
PALLET_H = 4
TABLES = ((1, 6, -11, -9), (-6, -1, 9, 11))
BANNERS = (-7, 3, 13)  # z of the sale banners hanging across the promo aisle
BANNER_Y = (7.6, 13)
BANNER_X = (-8.5, 8.5)
# The back.
OFFICE = (-35, -10)  # x of the office (z -28 .. -17), its floor at 9 over the deli and kitchen
OFFICE_FLOOR = 9
OFFICE_TOP = 15
BALCONY = (-25, -12)  # x of the office's open front
DELI = (-35, -14)  # x of the deli counter (z -18.6 .. -17)
HATCH = (-14, -10.4)
KITCHEN_WALL = (-10.4, -10)  # x of the kitchen's east wall
KITCHEN_DOOR = (-22, -19)  # z of its back door into the stockroom
LADDER_Z = (-27, -23)  # the ladder up the kitchen's east wall into the office
SHUTTER = (2, 8)  # x of the stockroom's half-down shutter
STRIP_DOOR = (24, 28)  # x of the stockroom's strip-curtain door
RACK = (-4, 28, -24, -21.5)  # the stockroom's island rack
RACK_DECKS = ((CROUCH_ROOM, CROUCH_ROOM + 0.4), (8.0, 8.4))
CHECKOUTS = (-22, -14, -6, 2)  # x of the checkout counters (z 18 .. 24)

# Scrubby: a floor-cleaning robot lapping the south half of the store (front aisle, aisle 2,
# the outer aisles). Built where it rests; the game will move it along its path.
ROBOT = {"points": [[23.5, 14.5], [-23.5, 14.5], [-23.5, 5], [23.5, 5]], "speed": 7,
         "turn": 0.7, "rest": [18, 14.5, 180],
         "names": ["the front aisle", "the produce side", "aisle 2", "the freezer side"]}
ROBOT_SIZE = (4, 2.4)  # long, wide

COLORS = {
    "floor": (236, 236, 230), "front_floor": (214, 200, 180), "kitchen_floor": (196, 70, 62),
    "stock_floor": (150, 150, 146), "wall": (238, 232, 218), "ceiling": (90, 94, 102),
    "shelf": (196, 202, 210), "shelf_dark": (60, 64, 72), "rail": (250, 250, 250),
    "pallet": (176, 130, 80), "box": (196, 160, 112), "steel": (110, 116, 126),
    "glass": (190, 222, 240), "counter": (226, 228, 232), "belt": (30, 30, 34),
    "pink": (255, 46, 136), "yellow": (255, 214, 10), "cyan": (25, 200, 230),
    "lime": (124, 220, 79), "ink": (24, 24, 28), "wood": (150, 112, 72),
    "kitchen": (214, 216, 220), "oven": (70, 74, 82), "office": (210, 200, 180),
    "lamp": (255, 248, 236), "robot": (255, 176, 30), "orange": (255, 138, 31),
    "freezer": (170, 212, 238), "cooler": (60, 120, 80),
}
MATERIALS = {
    "floor": "SmoothPlastic", "front_floor": "Concrete", "kitchen_floor": "CeramicTiles",
    "stock_floor": "Concrete", "wall": "Plaster", "ceiling": "Metal", "shelf": "Metal",
    "shelf_dark": "Metal", "pallet": "WoodPlanks", "box": "Cardboard", "steel": "Metal",
    "counter": "Metal", "belt": "Rubber", "wood": "WoodPlanks", "kitchen": "Metal",
    "oven": "Metal", "office": "Plaster", "robot": "SmoothPlastic", "freezer": "Metal",
}
PRODUCTS = ((230, 70, 60), (255, 160, 40), (255, 214, 10), (124, 200, 79), (25, 180, 230),
            (60, 110, 220), (170, 80, 220), (255, 90, 160), (240, 240, 235), (140, 90, 50),
            (40, 160, 120), (250, 120, 90))
DETAIL = dict(NO_HIT, CastShadow=False)


def vec(x, y, z):
    return {"Vector3": [round(x, 3), round(y, 3), round(z, 3)]}


def off(face, sign, depth=0.05, thick=0.05):
    """The span of a layer laid on a face at `face`, on the side `sign` (+1: towards +axis)."""
    a = face + sign * depth
    b = a + sign * thick
    return (min(a, b), max(a, b))


# ---- the shell -----------------------------------------------------------------------------------

def shell(m):
    g = "Store"
    # Floors: one piece per zone, meeting edge to edge.
    m.block(g, "Floor", -W, W, -1, 0, BACK, FRONT, "floor")
    m.block(g, "FrontFloor", -W, W, -1, 0, FRONT, D, "front_floor")
    m.block(g, "KitchenFloor", -W, KITCHEN_WALL[1], -1, 0, -D, BACK, "kitchen_floor")
    m.block(g, "StockFloor", KITCHEN_WALL[1], W, -1, 0, -D, BACK, "stock_floor")
    # Outer walls, split at CUT. The front (south) wall has the shop windows.
    for z0, z1 in ((-D - 1, -D), (D, D + 1)):
        if z0 > 0:
            m.wall(g, "X", (z0, z1), (-W - 1, W + 1), -1, CUT, "wall", name="Wall",
                   openings=[(-34, -27, 9, 3), (-26, -19, 9, 3), (-18, -11, 9, 3),
                             (-10, -3, 9, 3), (-2, 5, 9, 3)], frame=(60, 64, 72))
        else:
            m.block(g, "Wall", -W - 1, W + 1, -1, CUT, z0, z1, "wall")
        m.block(g, "WallUpper", -W - 1, W + 1, CUT, CEIL + 1, z0, z1, "wall")
    for x0, x1 in ((-W - 1, -W), (W, W + 1)):
        m.block(g, "Wall", x0, x1, -1, CUT, -D, D, "wall")
        m.block(g, "WallUpper", x0, x1, CUT, CEIL + 1, -D, D, "wall")
    m.block(g, "Ceiling", -W, W, CEIL, CEIL + 1, -D, D, "ceiling")
    d = "Details"
    for z in range(-24, 25, 8):  # roof trusses
        m.block(d, "Truss", -W, W, CEIL - 1.2, CEIL - 0.4, z - 0.3, z + 0.3, "steel", **DETAIL)
    # Lights: strips hanging over the aisles.
    for x in (-30, -15, 0, 15, 30):
        for z in (-14.5, -5, 5, 14.5, 22):
            m.light("Lights", (x, CEIL - 2.4, z), size=(8, 0.3, 1), color=COLORS["lamp"],
                    brightness=0.55, reach=20)


# ---- the shelves ---------------------------------------------------------------------------------

def shelf(m, x0, x1, z0, z1, seed, pallet_ends=()):
    """One block of shelving: a solid core you can wall-run along and run on top of, with
    products, price rails and a kick plate on both long faces (decoration) and sale posters on
    its ends."""
    m.block("Shelves", "Shelf", x0, x1, 0, SHELF_H, z0, z1, "shelf")
    d = "Details"
    third = (x1 - x0) / 3
    for side, face in ((-1, z0), (1, z1)):
        k0, k1 = off(face, side, 0.05, 0.1)
        m.block(d, "KickPlate", x0, x1, 0, 0.6, k0, k1, "shelf_dark", **DETAIL)
        p0, p1 = off(face, side, 0.05, 0.3)
        for level, (y0, y1) in enumerate(((0.75, 1.55), (1.95, 3.1), (3.5, 4.65), (5.05, 6.3))):
            for k in range(3):
                color = PRODUCTS[(seed * 7 + side * 3 + level * 5 + k * 2) % len(PRODUCTS)]
                m.block(d, "Products", x0 + k * third, x0 + (k + 1) * third, y0, y1, p0, p1, color,
                        **DETAIL)
        r0, r1 = off(face, side, 0.05, 0.45)
        for y in (1.6, 3.15, 4.7, 6.35):
            m.block(d, "PriceRail", x0, x1, y, y + 0.2, r0, r1, "rail", **DETAIL)
    for side, face in ((-1, x0), (1, x1)):
        if face in pallet_ends:
            continue
        e0, e1 = off(face, side, 0.05, 0.3)
        m.block(d, "EndCap", e0, e1, 0.6, 6.4, z0 + 0.3, z1 - 0.3,
                ("pink", "yellow", "cyan", "lime")[(seed + (side > 0)) % 4], **DETAIL)


def shelves(m):
    seed = 0
    for z0, z1 in ROWS:
        for x0, x1 in HALVES:
            ends = [face for face in (x0, x1) for px0, px1, pz0, pz1 in PALLETS
                    if (pz0, pz1) == (z0, z1) and face in (px0, px1)]
            shelf(m, x0, x1, z0, z1, seed, pallet_ends=ends)
            seed += 1
    # Aisle signs hanging over each aisle, two-sided.
    d = "Details"
    names = {(-1, 0): "1  SNACKS", (1, 0): "2  CEREAL", (-1, 1): "3  DRINKS", (1, 1): "4  CLEANING"}
    for (sx, ai), text in names.items():
        a, b = AISLES[ai]
        x = sx * 15
        m.block(d, "AisleSign", x - 0.15, x + 0.15, 14, 15.6, a + 0.6, b - 0.6,
                ("yellow", "pink")[ai], **DETAIL,
                children=[m.surface_text(f, text, COLORS["ink"], pps=10)
                          for f in ("Left", "Right")])
        for z in (a + 1, b - 1):
            m.block(d, "Hanger", x - 0.05, x + 0.05, 15.6, CEIL - 0.4, z - 0.05, z + 0.05, "steel",
                    **DETAIL)


# ---- the promo aisle -----------------------------------------------------------------------------

def promo(m):
    g = "Promo"
    d = "Details"
    # The spinning stand in the middle: a solid base to juke round, a sign turning on top.
    m.cylinder(g, "PromoStand", 3.4, 2.6, (0, 1.7, 0), "pink")
    m.cylinder(d, "StandPole", 1.4, 0.3, (0, 4.1, 0), "steel", **DETAIL)
    m.part(d, "SpinningSign", (4.4, 2.2, 0.3), (0, 5.95, 0), "yellow",
           attributes={"Spin": 45}, **DETAIL,
           children=[m.surface_text(f, "TAG MART", COLORS["ink"], pps=10)
                     for f in ("Front", "Back")])
    for x0, x1, z0, z1 in TABLES:  # sale tables: hurdle them
        m.block(g, "SaleTable", x0, x1, 0, 3, z0, z1, "wood")
        m.block(d, "SaleGoods", x0 + 0.3, x1 - 0.3, 3.05, 3.6, z0 + 0.3, z1 - 0.3, "orange",
                **DETAIL)
    for x0, x1, z0, z1 in PALLETS:  # pallets of boxes against the shelf ends: the way up
        m.block(g, "Pallet", x0, x1, 0, PALLET_H, z0, z1, "box")
        m.block(d, "PalletBase", x0 - 0.1, x1 + 0.1, 0, 0.5, z0 - 0.1, z1 + 0.1, "pallet", **DETAIL)
        m.block(d, "PalletWrap", x0 + 0.4, x1 - 0.4, PALLET_H + 0.05, PALLET_H + 0.1, z0 + 0.4,
                z1 - 0.4, "glass", Material="Glass", Transparency=0.5, **DETAIL)
    # Sale banners hanging across the promo aisle at shelf-top height: solid, so you can
    # wall-run along them from one half of the shelves to the other.
    texts = ("SALE", "2 FOR 1", "NEW!")
    colors = ("pink", "yellow", "cyan")
    for z, text, color in zip(BANNERS, texts, colors):
        m.block(g, "Banner", BANNER_X[0], BANNER_X[1], BANNER_Y[0], BANNER_Y[1], z - 0.2, z + 0.2,
                color, children=[m.surface_text(f, text, COLORS["ink"], pps=8)
                                 for f in ("Front", "Back")])
        for x in (BANNER_X[0] + 1, BANNER_X[1] - 1):
            m.block(d, "BannerCable", x - 0.05, x + 0.05, BANNER_Y[1], CEIL - 0.4, z - 0.05,
                    z + 0.05, "steel", **DETAIL)


# ---- produce and freezers ------------------------------------------------------------------------

def produce(m):
    g = "Produce"
    d = "Details"
    m.block(g, "WallCooler", -W, -33.5, 0, 7, -11, 11, "cooler")
    for k, z0 in enumerate(range(-11, 11, 4)):
        z1 = min(z0 + 4, 11)
        m.block(d, "Greens", -33.45, -33.15, 1, 6, z0 + 0.2, z1 - 0.2,
                ((80, 170, 70), (220, 60, 50), (250, 150, 40), (120, 190, 60))[k % 4], **DETAIL)
    fruit = ((220, 50, 50), (250, 160, 40), (250, 220, 60), (120, 190, 60), (150, 60, 160))
    for k, (z0, z1) in enumerate(((-11, -1.5), (1.5, 11))):
        m.block(g, "ProduceBin", -30, -26, 0, 3, z0, z1, "wood")
        step = (z1 - z0) / 3
        for j in range(3):
            m.block(d, "Fruit", -29.7, -26.3, 3, 3.06, z0 + j * step + 0.15, z0 + (j + 1) * step
                    - 0.15, fruit[(k * 3 + j) % len(fruit)], **DETAIL)
    # The misting gantry across the lane by the cooler: slide under it.
    m.block(g, "MistBar", -33.5, -30, CROUCH_ROOM, 8.5, -0.3, 0.3, "steel",
            children=[m.surface_text(f, "FRESH", COLORS["lime"], pps=10)
                      for f in ("Front", "Back")])
    m.block(g, "StandBlocker", -33.5, -30, 0, CROUCH_ROOM, -0.5, 0.5, (255, 255, 255),
            Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
    for x in (-33.25, -30.25):
        m.block(g, "MistPost", x - 0.15, x + 0.15, 0, CROUCH_ROOM, -0.15, 0.15, "steel")


def freezers(m):
    g = "Freezers"
    d = "Details"
    m.block(g, "FreezerCase", 33.5, W, 0, 8, -11, 11, "freezer")
    for z0 in range(-11, 11, 3):
        z1 = min(z0 + 3, 11)
        m.block(d, "FreezerDoor", 33.15, 33.45, 0.8, 7.4, z0 + 0.15, z1 - 0.15, "glass",
                Material="Glass", Transparency=0.35, **DETAIL)
        m.block(d, "DoorHandle", 33.0, 33.1, 3, 5.5, z1 - 0.6, z1 - 0.45, "steel", **DETAIL)
    m.block(g, "ChestFreezer", 26, 30, 0, 3.5, -10, 10, "freezer")
    for z0 in range(-10, 10, 4):
        m.block(d, "FreezerLid", 26.2, 29.8, 3.5, 3.56, z0 + 0.15, z0 + 3.85, "glass",
                Material="Glass", Transparency=0.4, **DETAIL)


# ---- the front: checkouts, service desk, entrance ------------------------------------------------

def front(m):
    g = "Front"
    d = "Details"
    for i, x in enumerate(CHECKOUTS):
        m.block(g, "Checkout", x - 0.8, x + 0.8, 0, 3.5, 18, 24, "counter")
        m.block(g, "Belt", x - 0.6, x + 0.6, 3.5, 3.65, 18.4, 22.4, "belt",
                attributes={"SpeedBoost": 44})
        m.block(d, "Register", x - 0.6, x + 0.6, 3.5, 4.6, 22.7, 23.7, "ink", **DETAIL)
        m.block(d, "LanePole", x - 0.1, x + 0.1, 3.5, 7, 18.1, 18.3, "steel", **DETAIL)
        m.block(d, "LaneLight", x - 0.5, x + 0.5, 7, 8, 18.0, 18.4, "lime", Material="Neon",
                **DETAIL, children=[m.surface_text(f, str(i + 1), COLORS["ink"], pps=20)
                                    for f in ("Front", "Back")])
    m.block(g, "ServiceDesk", -34, -27, 0, 4, 19.5, 23.5, "counter")
    m.block(d, "ServiceSign", -33.5, -27.5, 6.5, 8, 21.3, 21.7, "yellow", **DETAIL,
            children=[m.surface_text(f, "CUSTOMER SERVICE", COLORS["ink"], pps=10)
                      for f in ("Front", "Back")])
    m.block(g, "CartCorral", 26, 33, 0, 3.5, 24.5, 27, "steel")
    for x in (27, 29, 31):
        m.block(d, "Cart", x - 0.8, x + 0.8, 3.55, 4.6, 24.8, 26.7, "pink", **DETAIL)
    # The kiddie ride by the doors: a rocket turning on its base.
    m.block(g, "RideBase", 28.5, 31.5, 0, 0.8, 18.5, 21.5, "yellow")
    m.cylinder(d, "Rocket", 3.2, 1.6, (30, 2.45, 20), "cyan", attributes={"Spin": 30}, **DETAIL)
    for x0, x1 in ((28.1, 29.3), (30.7, 31.9)):
        m.block(d, "RocketFin", x0, x1, 0.9, 2.0, 19.92, 20.08, "pink", **DETAIL,
                attributes={"Spin": 30, "SpinCenter": vec(30, 2.45, 20)})
    # The entrance doors (closed: decoration on the wall), the store's sign over them.
    for x0, x1 in ((10, 15.9), (16.1, 22)):
        m.block(d, "EntranceDoor", x0, x1, 0, 6.5, D - 0.1, D - 0.05, "glass", Material="Glass",
                Transparency=0.4, **DETAIL)
    m.block(d, "StoreSign", 8, 24, 7, 9.6, D - 0.1, D - 0.05, "pink", **DETAIL,
            children=[m.surface_text("Front", "TAG MART", COLORS["yellow"], pps=10, glow=True)])
    m.block(d, "GumballMachine", 23, 24, 0, 3.5, 26.4, 27.4, "pink", **DETAIL)


# ---- the back: deli, kitchen, office, stockroom --------------------------------------------------

def back(m):
    g = "Back"
    d = "Details"
    # The deli counter (too tall to jump with its glass) and the half-open hatch at its end.
    m.block(g, "DeliCounter", DELI[0], DELI[1], 0, 4, -18.6, BACK, "counter")
    m.block(g, "SneezeGuard", DELI[0], DELI[1], 4, 6, -17.6, -17.3, "glass", Material="Glass",
            Transparency=0.5, CastShadow=False)
    for k, x0 in enumerate(range(-34, -14, 4)):
        m.block(d, "DeliFood", x0 + 0.2, x0 + 3.8, 2.4, 3.6, *off(BACK, 1),
                ((230, 120, 110), (240, 200, 120), (200, 90, 80), (250, 230, 200), (180, 110, 70))
                [k % 5], **DETAIL)
    m.block(d, "DeliSign", -30, -20, 6.4, 7.8, -17.3, -17.2, "pink", **DETAIL,
            children=[m.surface_text("Back", "DELI · BAKERY", COLORS["yellow"], pps=10)])
    m.block(g, "Hatch", HATCH[0], HATCH[1], CROUCH_ROOM, OFFICE_FLOOR - 0.6, -18.6, BACK, "wood")
    m.block(g, "StandBlocker", HATCH[0], HATCH[1], 0, CROUCH_ROOM, -18.6, BACK, (255, 255, 255),
            Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
    # The kitchen's east wall (its back door into the stockroom) and the column the office
    # ladder stands on.
    m.wall(g, "Z", KITCHEN_WALL, (-D, BACK), 0, OFFICE_FLOOR - 0.6, "kitchen", name="Wall",
           openings=[(KITCHEN_DOOR[0], KITCHEN_DOOR[1], 7)])
    m.block(g, "LadderColumn", -12.4, KITCHEN_WALL[0], 0, OFFICE_FLOOR - 0.6, LADDER_Z[0],
            LADDER_Z[1], "kitchen")
    m.ladder(g, KITCHEN_WALL[1], sum(LADDER_Z) / 2, (1, 0), 0, OFFICE_FLOOR, width=4)
    # Kitchen: ovens along the back wall, a prep table to hurdle, lights under the office.
    m.block(g, "Oven", -33, -15, 0, 6, -D, -26.6, "oven")
    for x0 in range(-32, -15, 4):
        m.block(d, "OvenDoor", x0, x0 + 3, 1, 4, -26.55, -26.5, "ink", **DETAIL)
    m.block(g, "PrepTable", -28, -18, 0, 3, -24, -22.4, "kitchen")
    m.block(d, "Dough", -26, -20, 3.05, 3.4, -23.6, -22.8, (240, 220, 180), **DETAIL)
    for x in (-28, -18):
        m.light("Lights", (x, OFFICE_FLOOR - 0.85, -22), size=(6, 0.3, 0.8),
                color=COLORS["lamp"], brightness=0.5, reach=14)

    # The office over the deli and kitchen.
    m.block(g, "OfficeFloor", OFFICE[0], OFFICE[1], OFFICE_FLOOR - 0.6, OFFICE_FLOOR, -D, BACK,
            "office")
    m.wall(g, "X", (BACK - 0.4, BACK), OFFICE, OFFICE_FLOOR, OFFICE_TOP, "office", name="Wall",
           openings=[(-34, -26, 14, 10.5), (BALCONY[0], BALCONY[1], OFFICE_TOP)],
           frame=(60, 64, 72))
    m.wall(g, "Z", KITCHEN_WALL, (-D, BACK - 0.4), OFFICE_FLOOR, OFFICE_TOP, "office",
           name="Wall", openings=[(LADDER_Z[0] - 0.2, LADDER_Z[1] + 0.2, OFFICE_TOP)])
    m.block(g, "OfficeRoof", OFFICE[0], OFFICE[1], OFFICE_TOP, OFFICE_TOP + 0.5, -D, BACK,
            "ceiling")
    m.block(g, "Desk", -31, -26, OFFICE_FLOOR, OFFICE_FLOOR + 3, -26, -24, "wood")
    m.block(d, "Monitor", -30, -28.6, OFFICE_FLOOR + 3.05, OFFICE_FLOOR + 4.2, -25.4, -25.2, "ink",
            **DETAIL)
    m.block(g, "FilingCabinet", -22, -18, OFFICE_FLOOR, OFFICE_FLOOR + 4.5, -D, -27, "steel")
    m.block(g, "Safe", -15, -13, OFFICE_FLOOR, OFFICE_FLOOR + 3, -27.5, -25.5, "ink")
    m.block(d, "CctvScreens", -W + 0.05, -W + 0.1, OFFICE_FLOOR + 2, OFFICE_FLOOR + 5, -26, -20,
            "ink", **DETAIL)
    m.block(d, "OfficeSign", BALCONY[0] + 2, BALCONY[0] + 9, OFFICE_TOP - 1.6, OFFICE_TOP - 0.3,
            BACK + 0.05, BACK + 0.1, "yellow", **DETAIL,
            children=[m.surface_text("Back", "MANAGER", COLORS["ink"], pps=10)])
    m.light("Lights", (-22, OFFICE_TOP - 0.35, -22), size=(6, 0.3, 0.8), color=COLORS["lamp"],
            brightness=0.5, reach=14)

    # The stockroom: its front wall (half-down shutter, strip-curtain door), the island rack
    # (slide under its bottom shelf, or climb it), boxes, a parked forklift, a flickering light.
    x0 = KITCHEN_WALL[1]
    m.wall(g, "X", (BACK - 0.4, BACK), (x0, W), 0, CUT, "wall", name="Wall",
           openings=[(SHUTTER[0], SHUTTER[1], CUT), (STRIP_DOOR[0], STRIP_DOOR[1], 8)])
    m.block(g, "WallUpper", x0, W, CUT, CEIL, BACK - 0.4, BACK, "wall")
    m.block(g, "Shutter", SHUTTER[0], SHUTTER[1], CROUCH_ROOM, CUT, BACK - 0.35, BACK - 0.05,
            "steel", Material="DiamondPlate")
    m.block(g, "StandBlocker", SHUTTER[0], SHUTTER[1], 0, CROUCH_ROOM, BACK - 0.4, BACK,
            (255, 255, 255), Transparency=1, CastShadow=False, attributes={"SlideBlocker": True})
    for k in range(int((STRIP_DOOR[1] - STRIP_DOOR[0]) / 0.5)):
        sx = STRIP_DOOR[0] + 0.25 + k * 0.5
        m.block(d, "CurtainStrip", sx - 0.2, sx + 0.2, 0.6, 8, BACK - 0.25 + 0.04 * (k % 2),
                BACK - 0.2 + 0.04 * (k % 2), "glass", Material="Glass", Transparency=0.55,
                **DETAIL)
    m.block(d, "StaffSign", 13, 21, 7, 8.6, BACK + 0.05, BACK + 0.1, "ink", **DETAIL,
            children=[m.surface_text("Back", "STAFF ONLY", (255, 255, 255), pps=10)])
    rx0, rx1, rz0, rz1 = RACK
    posts = [rx0 + k * (rx1 - rx0) / 5 for k in range(6)]
    for px in posts:
        for pz in (rz0 + 0.2, rz1 - 0.2):
            m.block(g, "RackPost", px - 0.2, px + 0.2, 0, RACK_DECKS[-1][0], pz - 0.2, pz + 0.2,
                    "orange")
    # the lower deck sits between the posts; the top deck lies on them, a clear run on top
    (low0, low1), (top0, top1) = RACK_DECKS
    m.block(g, "RackDeck", rx0 + 0.2, rx1 - 0.2, low0, low1, rz0 + 0.1, rz1 - 0.1, "steel")
    m.block(g, "RackDeck", rx0 - 0.3, rx1 + 0.3, top0, top1, rz0 - 0.1, rz1 + 0.1, "steel")
    for k, bx in enumerate(posts[:-1]):
        if k % 2 == 0:
            m.block(d, "Boxes", bx + 0.8, bx + 5.6, low1 + 0.05, low1 + 2.6, rz0 + 0.3, rz1 - 0.3,
                    "box", **DETAIL)
    m.block(g, "BoxPile", 2, 20, 0, 2, -D, -27, "box")
    m.block(g, "Forklift", 30, 34.6, 0, 3.5, -27.6, -24.6, "yellow")
    m.block(d, "ForkliftMast", 29.4, 29.9, 0, 7, -27.4, -24.8, "ink", **DETAIL)
    m.block(d, "LoadingDoor", 6, 16, 0, 9, -D + 0.05, -D + 0.1, "steel", Material="DiamondPlate",
            **DETAIL)
    m.light("Lights", (12, CEIL - 2.4, -22), size=(8, 0.3, 1), color=COLORS["lamp"],
            brightness=0.5, reach=18, flicker=True)


# ---- Scrubby -------------------------------------------------------------------------------------

def robot(m):
    """Scrubby, built where it rests (in the front aisle heading west). Every part carries
    PathMover = "Scrubby"; the body shoves anyone it touches and carries anyone on it."""
    rx, rz, _ = ROBOT["rest"]
    long_, wide = ROBOT_SIZE
    x0, x1 = rx - long_ / 2, rx + long_ / 2
    z0, z1 = rz - wide / 2, rz + wide / 2
    mover = {"PathMover": "Scrubby"}
    m.block("Robot", "ScrubbyBody", x0, x1, 0.25, 2.4, z0, z1, "robot",
            attributes=dict(mover, Knockback=40, Carry=True))
    m.block("Robot", "ScrubbyBrush", x0 - 0.2, x0 + 0.9, 0.05, 0.5, z0 + 0.2, z1 - 0.2, "ink",
            attributes=mover, **DETAIL)
    m.block("Robot", "ScrubbySeat", x0 + 2.4, x1 - 0.2, 2.45, 3.3, z0 + 0.4, z1 - 0.4, "ink",
            attributes=mover, **DETAIL)
    m.block("Robot", "ScrubbyBeacon", x0 + 2.9, x0 + 3.3, 3.35, 3.95, rz - 0.2, rz + 0.2, "orange",
            Material="Neon", attributes=mover, **DETAIL)
    for z in (z0 + 0.5, z1 - 0.5):
        m.block("Robot", "ScrubbyLight", x0 - 0.1, x0 - 0.05, 1.4, 1.9, z - 0.3, z + 0.3, "lamp",
                Material="Neon", attributes=mover, **DETAIL)
    for zz in ((z0 - 0.1, z0 - 0.05), (z1 + 0.05, z1 + 0.1)):
        m.block("Robot", "ScrubbyStripe", x0 + 0.3, x1 - 0.3, 1.0, 1.5, zz[0], zz[1], "ink",
                attributes=mover, **DETAIL)


def robot_pose(t):
    """Where Scrubby is t seconds after leaving its rest place: (x, z, heading degrees). Straight
    runs at ROBOT["speed"], turning on the spot at each corner for ROBOT["turn"] seconds."""
    pts = ROBOT["points"]
    legs = []
    for i, (ax, az) in enumerate(pts):
        bx, bz = pts[(i + 1) % len(pts)]
        legs.append((ax, az, bx, bz, math.hypot(bx - ax, bz - az),
                     math.degrees(math.atan2(bz - az, bx - ax))))
    lap = sum(leg[4] / ROBOT["speed"] + ROBOT["turn"] for leg in legs)
    rx, rz, _ = ROBOT["rest"]
    start = abs(rx - legs[0][0]) / ROBOT["speed"]  # the rest place is on the first leg
    t = (t + start) % lap
    for i, (ax, az, bx, bz, length, h) in enumerate(legs):
        run = length / ROBOT["speed"]
        if t < run:
            f = t / run
            return ax + (bx - ax) * f, az + (bz - az) * f, h
        t -= run
        if t < ROBOT["turn"]:
            nh = legs[(i + 1) % len(legs)][5]
            turn = (nh - h + 180) % 360 - 180
            return bx, bz, h + turn * t / ROBOT["turn"]
        t -= ROBOT["turn"]
    return legs[0][0], legs[0][1], legs[0][5]


def robot_lap():
    pts = ROBOT["points"]
    return sum(math.dist(pts[i], pts[(i + 1) % len(pts)]) / ROBOT["speed"] + ROBOT["turn"]
               for i in range(len(pts)))


# ---- demo players for the canvas (the game ignores these) ----------------------------------------

def demo_players():
    """Paths for figures acting out a round on the canvas: closed loops of [x, y, z, flag] points.
    Flags: "j" jumps (or drops) into that point, "c" is a slide or crouch, "wr"/"wl" a wall run
    with the wall on the right/left."""
    chase = [[-18, 0, 17.0, ""], [-10, 0, 17.0, ""], [-10, 0, 25.8, ""], [-18, 0, 25.8, ""]]
    high = [  # onto a pallet, up the shelves, across an aisle, a banner run, off the far end
        [-3.2, 0, -10, ""], [-6.6, PALLET_H, -10, "j"], [-7.4, PALLET_H, -10, ""],
        [-10.6, SHELF_H, -10, "j"], [-11.0, SHELF_H, -8.8, ""], [-19.0, SHELF_H, -8.8, ""],
        [-19.0, SHELF_H, -1.0, "j"], [-18.0, SHELF_H, 1.4, ""], [-9.6, SHELF_H, 1.4, ""],
        [-7.5, SHELF_H + 1.4, 1.7, "wr"], [0.0, SHELF_H + 2.6, 1.7, "wr"],
        [7.5, SHELF_H + 1.4, 1.7, "wr"], [9.8, SHELF_H, 1.4, ""], [20.4, SHELF_H, 1.0, ""],
        [23.4, 0, -0.6, "j"], [23.4, 0, -13.4, ""], [-3.5, 0, -13.4, ""],
    ]
    back_loop = [  # under the deli hatch, through the kitchen, under the rack and the shutter
        [-12.2, 0, -15.9, ""], [-12.2, 0, -16.6, "c"], [-12.2, 0, -19.4, "c"],
        [-11.6, 0, -20.5, ""], [-8.6, 0, -20.5, ""], [-7.0, 0, -22.0, ""], [-7.0, 0, -25.6, ""],
        [12.0, 0, -25.6, ""], [12.0, 0, -24.6, "c"], [12.0, 0, -20.9, "c"], [11.0, 0, -19.6, ""],
        [5.0, 0, -19.6, ""], [5.0, 0, -18.2, "c"], [5.0, 0, -16.2, "c"], [4.0, 0, -15.9, ""],
    ]
    return [
        {"tag": "", "color": "#3C82F0", "speed": 14, "offset": 0, "points": chase},
        {"tag": "IT", "color": "#E8423F", "speed": 14, "offset": -0.7, "points": chase},
        {"tag": "", "color": "#4CC46A", "speed": 12, "offset": 0, "points": high,
         "cam": "Shelf runner"},
        {"tag": "", "color": "#F2C94C", "speed": 10, "offset": 0, "points": back_loop},
    ]


SPAWNS = ((-15, -5), (15, -5), (-15, -14.5), (15, -14.5), (-30.5, 14), (30.5, 14), (-18, 21),
          (5, -6))


def build():
    m = Map(COLORS, MATERIALS)
    shell(m)
    shelves(m)
    promo(m)
    produce(m)
    freezers(m)
    front(m)
    back(m)
    robot(m)
    for x, z in SPAWNS:
        m.spawn(x, z)
    return m


# ---- the design canvas ---------------------------------------------------------------------------

def _label(text, x, y, z, kind="zone"):
    return {"t": text, "x": x, "y": y, "z": z, "f": 1, "k": kind}


def _marker(n, title, text, x, y, z):
    return {"n": n, "t": title, "d": text, "x": x, "y": y, "z": z, "f": 1}


CANVAS = {
    "label": "Design v1",
    "labels": [
        _label("Promo aisle", 0, 3.2, -4), _label("Produce", -31, 4.5, -6),
        _label("Freezers", 31, 5, -6), _label("Checkouts", -10, 5, 26.5),
        _label("Deli", -27, 8, -15.5), _label("Office · 9 up", -30, 16.5, -22),
        _label("Stockroom", 20, 11, -26), _label("Front aisle", -14, 1.5, 14.5),
        _label("Back aisle", 14, 1.5, -14.5),
        _label("Shelf tops · 7 up", -15, 8.6, 0, "feature"),
        _label("Shelf tops · 7 up", 15, 8.6, 0, "feature"),
        _label("Scrubby's lap", 0, 1.5, 5, "feature"),
    ],
    "markers": [
        _marker(1, "Shelf tops", "Every shelf is 7 high, too high to jump onto from the floor, "
                "and its top is a running lane. Climb up from a pallet, a produce bin, the "
                "freezer island or checkout belt 2, then jump row to row across the aisles (6 "
                "apart).", -15, 9.5, -10),
        _marker(2, "Banner runs", "Sale banners hang across the promo aisle at shelf-top height. "
                "The two halves of the shelves are 18 apart: too far to jump at a sprint, so "
                "wall-run along a banner or slide-jump the gap.", 0, 14.5, 3),
        _marker(3, "Promo aisle", "The wide aisle down the middle: a stand with a turning sign to "
                "juke round, sale tables to hurdle, and two pallets of boxes against the shelf "
                "ends (the easy way onto the shelf tops).", 0, 8.5, 0),
        _marker(4, "The office", "The manager's office over the deli, 9 up. Jump across from the "
                "first row of shelves, climb the ladder in the stockroom, or jump in off the top "
                "of the stockroom rack. Drop off its open front to get out.", -24, 12, -22),
        _marker(5, "Deli hatch", "The deli counter's glass is too tall to jump, but the hatch at "
                "its end is half open: slide under it into the kitchen.", -12.2, 6, -16),
        _marker(6, "Kitchen", "Ovens and a prep table under the office. Its back door opens into "
                "the stockroom, so the back of the store is a second, quieter loop.", -22, 5, -21),
        _marker(7, "Stockroom rack", "Slide under the rack's bottom shelf to cross the stockroom, "
                "or hop up onto its top from the forklift and jump across into the office.",
                12, 10.5, -23),
        _marker(8, "Shutter", "The stockroom's shutter is half down: slide under it to get back "
                "to the shop floor (or use the strip-curtain door further along).", 5, 6, -16),
        _marker(9, "Checkouts", "Four counters to loop round. The belts are speed strips: jump "
                "up, run along one and shoot out of the lane (from lane 2 you land on the shelf "
                "tops).", -14, 6, 21),
        _marker(10, "Produce", "Fruit bins to jump, a cooler wall, and a misting gantry over the "
                "lane by the wall: slide under it.", -31, 6, 0),
        _marker(11, "Freezers", "A chest-freezer island to hurdle, and a wall of freezer doors to "
                "wall-run along.", 30, 6.5, 0),
        _marker(12, "Scrubby", "A floor-cleaning robot lapping the south half of the store (the "
                "front aisle, aisle 2 and the outer aisles) every %d seconds. It blocks whichever "
                "aisle it's in and shoves anyone it touches; stand on it and it carries you."
                % round(robot_lap()), 0, 5, 9.5),
        _marker(13, "Front of store", "The service desk, the cart corral and a kiddie ride to "
                "dodge round by the doors.", 28, 7, 22),
    ],
    "views": {  # [camera x, y, z, target x, y, z]; looking under the office cuts it away
        "Overview": [48, 70, 70, 0, 2, -2], "Top": [0, 118, 0.01, 0, 0, 0],
        "Shop floor": [-2, 6.5, 25, 1, 4, -4], "Shelf tops": [-28, 19, 18, -4, 6, -3],
        "Banner run": [14, 21, 17, -1, 8, 2], "Back loop": [12, 36, 4, -12, 2, -22],
        "Stockroom": [26, 36, -2, 8, 2, -23], "Checkouts": [-2, 26, 6, -14, 1, 22],
        "Office": [-8, 30, -4, -24, 10, -23],
    },
    "figure": [-4, 0, -4],
    "roof_names": ["Ceiling"],
    "roof_extra": ["Ceiling", "OfficeRoof", "WallUpper", "Truss", "Light"],
    # Toggles that cut part of the model away to see under it: parts whose centers are in the box
    # (x0, x1, y0, y1, z0, z1). The office hides the kitchen and the deli.
    "cutaways": [{"label": "Office", "box": [-35.5, -9.9, 8.35, 30, -28.5, -16.9]}],
}
MOVERS = {"Scrubby": ROBOT}
DEMO = demo_players()


# ---- checks --------------------------------------------------------------------------------------

def jump_reach(drop, speed=SPRINT):
    """How far a running jump carries you before your feet fall `drop` below takeoff (negative:
    the landing is higher). No margin."""
    up = math.sqrt(2 * GRAVITY * JUMP)
    disc = up * up + 2 * GRAVITY * drop
    if disc < 0:
        return 0.0
    return speed * (up + math.sqrt(disc)) / GRAVITY


def _segment_distance(p, a, b):
    ax, az = a
    dx, dz = b[0] - ax, b[1] - az
    f = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(p[0] - ax - dx * f, p[1] - az - dz * f)


def robot_clearance(m):
    """Sweeps Scrubby's footprint round its lap and lists anything solid in its way."""
    nodes = [n for group, items in m.groups.items() if group != "Robot" for n in items]
    parts = [p for p in mapcheck.parts_from_nodes(nodes) if p.solid and p.hi[1] > 0.3]
    long_, wide = ROBOT_SIZE
    hits = set()
    t, lap = 0.0, robot_lap()
    while t < lap:
        x, z, h = robot_pose(t)
        probe = mapcheck.Part({"name": "Probe", "className": "Part", "properties": {
            "Size": [long_, 3.7, wide],
            "CFrame": {"CFrame": {"position": [x, 2.15, z], "orientation": rot_y(-h)}}}})
        for p in parts:
            if p.hi[0] < probe.lo[0] or p.lo[0] > probe.hi[0] or p.hi[2] < probe.lo[2] \
                    or p.lo[2] > probe.hi[2]:
                continue
            if mapcheck._obb_overlap(probe, p, shrink=0.05):
                hits.add(f"{p.name} near ({x:.1f}, {z:.1f})")
        t += 0.1
    return sorted(hits)


def check(m):
    problems = []
    if SHELF_H <= mapcheck.JUMP_UP:
        problems.append("the shelves can be jumped onto from the floor")
    if PALLET_H > mapcheck.JUMP_UP or SHELF_H - PALLET_H > mapcheck.JUMP_UP:
        problems.append("the pallets don't step up onto the shelves")
    aisle = AISLES[0][1] - AISLES[0][0]
    if aisle > jump_reach(0) - 2.5:
        problems.append(f"the aisles ({aisle}) can't be jumped from shelf top to shelf top")
    gap = HALVES[1][0] - HALVES[0][1]
    if gap <= jump_reach(0) + 0.5:
        problems.append(f"a sprinting jump ({jump_reach(0):.1f}) clears the {gap} promo aisle")
    if gap >= jump_reach(0, SLIDE_JUMP) or gap > WALL_RUN:
        problems.append(f"the {gap} promo aisle is out of reach of a slide jump or a wall run")
    if BANNER_X[1] - BANNER_X[0] < gap - 2 or BANNER_Y[0] < SHELF_H:
        problems.append("the banners don't span the promo aisle at shelf-top height")
    balcony_gap = ROWS[0][0] - BACK
    if balcony_gap > jump_reach(-(OFFICE_FLOOR - SHELF_H)) - 2.5:
        problems.append("the office balcony is out of reach from the shelf tops")
    if CEIL - SHELF_H < JUMP + 5.5:
        problems.append("the ceiling is too low to jump on the shelf tops")
    problems += [f"Scrubby hits {hit}" for hit in robot_clearance(m)]
    if len(m.spawns) < ATTRIBUTES["MaxPlayers"]:
        problems.append("not enough spawns")
    pts = ROBOT["points"]
    for x, z in SPAWNS:
        near = min(_segment_distance((x, z), pts[i], pts[(i + 1) % len(pts)])
                   for i in range(len(pts)))
        if near < ROBOT_SIZE[0] / 2 + 1.5:
            problems.append(f"the spawn at ({x}, {z}) is in Scrubby's way")
    # Wall runs along the banners, both ways (from the end of one shelf half to the other).
    runs = []
    for z, (z0, z1) in zip(BANNERS, ROWS):
        edge = z0 + 0.8 if z < z0 else z1 - 0.8
        runs.append(((HALVES[0][1] - 1, SHELF_H, edge), (HALVES[1][0] + 1, SHELF_H, edge), True))
    return problems + mapcheck.check_map(m, ATTRIBUTES, routes=runs)


if __name__ == "__main__":
    layout = build()
    print(f"{layout.count()} parts in {len(layout.groups)} groups, {len(layout.spawns)} spawns; "
          f"Scrubby laps in {robot_lap():.1f} s")
    issues = check(layout)
    for line in issues:
        print("PROBLEM:", line)
    if "--write" in sys.argv:
        os.chdir(REPO)
        layout.write(OUT, ATTRIBUTES)
        print(f"wrote {OUT}/")
    raise SystemExit(1 if issues else 0)
