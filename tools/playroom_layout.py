#!/usr/bin/env python3
"""The Playroom (2-6 players): a kid's bedroom at giant scale, 96 x 96, walls and ceiling painted
like the sky. Designed on the "Playroom" design canvas and ported from its design data
(tools/designs/playroom_v1.json, the canvas's export). Run from the repo root:
    python3 tools/playroom_layout.py
It rewrites `src/maps/Playroom/` (generated: don't edit those files by hand); Rojo syncs it.

Big toys round a spinner, each one to loop round, run through, walk over or reach with a move:
  - the spinner: a low round stage with a 30-long bar sweeping round at hip height (Spin 72,
    Knockback: jump it as it comes);
  - the bed (9): walk up the stack of books, then wall-run the wardrobe onto the desk (9; the
    only way up there); run under the desk;
  - the block castle: through the gate, up the ramps to the gatehouse (12) and the keep (20),
    down the slide to its yellow lip (a speed strip): jump at the very end and it flings you onto
    the toy box (12; the only way up);
  - the jack-in-the-box: step on its lid and it springs open (client/PopUps, server/PopUps),
    throwing you onto the gatehouse; it stays out 2 s, so whoever's chasing waits. Its lid turns
    on a hinge along the box's top back edge, which is also the lid's bottom back edge, so the lid
    is always joined to the box (the design's hinge sat in the air above and behind the box);
  - the train tunnel (slide or crouch through, SlideBlocker) and ABC blocks to juke round.

Axes: X east, Z south, Y up. Floor at 0, ceiling 40.
"""
import math
import sys

sys.path.insert(0, "tools")
sys.path.insert(0, "tools/designs")
import canvas_import as ci  # noqa: E402
import mapcheck  # noqa: E402
from maplib import NO_HIT, Map  # noqa: E402

DESIGN = "tools/designs/playroom_v1.json"
OUT = "src/maps/Playroom"
ATTRIBUTES = {"DisplayName": "Playroom", "MinPlayers": 2, "MaxPlayers": 6, "InRotation": True,
              "Lighting": "Bright",
              "OutOfBounds": "Ceiling,Wardrobe,Tower,Headboard,Tunnel"}

# Things the export doesn't keep, set here (tune in game).
LIP_BOOST = 50  # studs/s off the slide's lip: a jump at its end carries about 22 onto the toy box
BAR_KNOCKBACK = 45  # studs/s: the spinner's bar shoves you this hard
JACK = {"PopRise": 6, "PopTime": 0.12, "PopBack": 0.4, "PopCooldown": 2, "PopAngle": -110}
JACK_TARGET = (26, 12, -37)  # where the jack throws you: the castle's gatehouse
JACK_UP = 70  # studs/s up off the jack (the speed across follows from the target)

# The jack-in-the-box: the box is x 5..11, y 0..5, z -27..-21. Its lid rebuilt flush with the
# box's back (the design's hung 0.2 over it) so the hinge line is a real edge of both.
BOX = (5, 11, 0, 5, -27, -21)
LID_OVERHANG = 0.2  # past the box at the sides and the front (a lip to open it by)
LID_THICK = 0.3
HINGE = (8, BOX[3], BOX[4])  # a point on the hinge line: the box's top back edge
HINGE_BARRELS = (5.9, 10.1)  # x of the two hinge knuckles on that edge

LAUNCH_DRIVE, ROOT, GRAVITY = mapcheck.LAUNCH_DRIVE, mapcheck.ROOT, mapcheck.GRAVITY


def launch_velocity(x0, z0, top, x1, z1, y1, vy):
    """The launch from a pad whose top is at `top` that lands on (x1, y1, z1)."""
    start = top + ROOT
    after_drive = start + vy * LAUNCH_DRIVE
    land = y1 + ROOT
    a, b, c = GRAVITY / 2, -vy, land - after_drive
    t = (-b + math.sqrt(b * b - 4 * a * c)) / (2 * a) + LAUNCH_DRIVE
    return [round((x1 - x0) / t, 3), vy, round((z1 - z0) / t, 3)]


def vec(x, y, z):
    return {"Vector3": [x, y, z]}


# Names and materials by the design's part index.
def describe(i):
    if i == 0:
        return "Carpet", "Fabric"
    if 1 <= i <= 8:
        return ("Wall" if i % 2 else "SkyWall"), "SmoothPlastic"
    if i == 9:
        return "Ceiling", "SmoothPlastic"
    if 10 <= i <= 45:
        return "Cloud", "SmoothPlastic"
    names = {
        46: ("Pillow", "Fabric"), 47: ("Blanket", "Fabric"), 48: ("WardrobeDoor", "Wood"),
        49: ("WardrobeDoor", "Wood"), 50: ("DeskLamp", "SmoothPlastic"),
        59: ("SlideRail", "SmoothPlastic"), 60: ("SlideRail", "SmoothPlastic"),
        61: ("JackSpring", "Metal"), 62: ("ClownHead", "SmoothPlastic"),
        63: ("ClownNose", "SmoothPlastic"), 64: ("ClownHat", "SmoothPlastic"),
        65: ("ClownHat", "SmoothPlastic"), 66: ("Crank", "SmoothPlastic"),
        67: ("Crank", "SmoothPlastic"), 68: ("SpinnerCap", "SmoothPlastic"),
        69: ("SpinnerCap", "SmoothPlastic"), 70: ("Bed", "Fabric"), 71: ("Headboard", "Wood"),
        80: ("Wardrobe", "Wood"), 81: ("Desk", "Wood"), 86: ("Chair", "SmoothPlastic"),
        87: ("Chair", "SmoothPlastic"), 88: ("Gatehouse", "SmoothPlastic"),
        89: ("Gate", "SmoothPlastic"), 90: ("Gatehouse", "SmoothPlastic"),
        91: ("Tower", "SmoothPlastic"), 92: ("Tower", "SmoothPlastic"),
        93: ("Keep", "SmoothPlastic"), 94: ("Ramp", "SmoothPlastic"),
        95: ("Ramp", "SmoothPlastic"), 96: ("Slide", "SmoothPlastic"),
        97: ("SlideLip", "SmoothPlastic"), 101: ("ToyBox", "Wood"),
        102: ("JackBox", "SmoothPlastic"), 103: ("JackLid", "SmoothPlastic"),
        107: ("StandBlocker", "SmoothPlastic"), 111: ("Stage", "SmoothPlastic"),
        112: ("Stage", "SmoothPlastic"), 113: ("Hub", "SmoothPlastic"),
        114: ("SpinnerBar", "SmoothPlastic"),
    }
    if i in names:
        return names[i]
    if 51 <= i <= 58:
        return "Battlement", "SmoothPlastic"
    if 72 <= i <= 79:
        return "Book", "SmoothPlastic"
    if 82 <= i <= 85:
        return "DeskLeg", "Wood"
    if 98 <= i <= 100:
        return "SlidePost", "SmoothPlastic"
    if 104 <= i <= 106:
        return "Tunnel", "SmoothPlastic"
    if 108 <= i <= 110:
        return "Block", "Wood"
    raise KeyError(i)


GROUPS = {"Room": range(0, 46), "Bedroom": range(46, 51), "Castle": (51, 52, 53, 54, 55, 56,
          57, 58, 59, 60, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100),
          "Jack": (61, 62, 63, 64, 65, 66, 67, 102, 103), "Spinner": (68, 69, 111, 112, 113, 114)}


def group_of(i):
    for name, members in GROUPS.items():
        if i in members:
            return name
    return "Toys"


def build():
    data = ci.load(DESIGN)
    m = Map()
    texts = {}
    for index, face, text, color_hex, glow in data["texts"]:
        color = tuple(int(color_hex[k:k + 2], 16) for k in (0, 2, 4))
        texts.setdefault(index, []).append(m.surface_text(face, text, color, glow=bool(glow)))
    tx, ty, tz = JACK_TARGET
    jack_launch = launch_velocity(8, -24, BOX[3] + LID_THICK, tx, tz, ty, JACK_UP)
    for part in ci.parts(data):
        i = part["index"]
        name, material = describe(i)
        props = ci.props(part, material)
        attributes = {}
        motion = part["motion"]
        if part["flags"] & ci.GATE:  # the tunnel's slide gate: invisible, stops standing players
            props = {"Transparency": 1, "CastShadow": False}
            attributes["SlideBlocker"] = True
        if motion and "spin" in motion:
            attributes["Spin"] = motion["spin"]
            if motion.get("c") is not None:
                attributes["SpinCenter"] = vec(motion["c"][0], 0, motion["c"][1])
        if name == "SpinnerBar":
            attributes["Knockback"] = BAR_KNOCKBACK
        if name == "SlideLip":
            attributes["SpeedBoost"] = LIP_BOOST
        if motion and motion.get("pop"):
            attributes["PopUp"] = motion["pop"]
            attributes["PopRole"] = motion["role"].capitalize()
        if name == "JackLid":
            # Rebuilt flush with the box's back, its hinge on the shared edge (see the top).
            x0, x1, y0, y1, z0, z1 = BOX
            part = dict(part, pos=((x0 + x1) / 2, y1 + LID_THICK / 2,
                                   (z0 + z1 + LID_OVERHANG) / 2),
                        size=(x1 - x0 + 2 * LID_OVERHANG, LID_THICK, z1 - z0 + LID_OVERHANG))
            attributes.update(JACK)
            attributes["PopHinge"] = vec(*HINGE)
            attributes["PopHingeAxis"] = vec(1, 0, 0)
            attributes["LaunchVelocity"] = vec(*jack_launch)
        if attributes:
            props["attributes"] = attributes
        ci.place(m, group_of(i), name, part, props, texts.get(i))

    # The lid's hinge knuckles, on the hinge line (they don't move: the lid turns round them).
    for x in HINGE_BARRELS:
        m.cylinder("Jack", "Hinge", 1.2, 0.5, (x, HINGE[1], HINGE[2]), (150, 150, 156),
                   [[1, 0, 0], [0, 1, 0], [0, 0, 1]], Material="Metal", **NO_HIT)

    # Light: a ceiling lamp, and lights in the corners (the design has none).
    m.cylinder("Room", "CeilingLamp", 0.4, 8, (0, 39.75, 0), (255, 248, 225), Material="Neon",
               CastShadow=False, **NO_HIT)
    for x, z, brightness in ((0, 0, 2.2), (-26, -26, 1.4), (26, -26, 1.4), (-26, 26, 1.4),
                             (26, 26, 1.4)):
        m.part("Room", "RoomLight", (1, 0.2, 1), (x, 39.6, z), (255, 248, 225), Transparency=1,
               CastShadow=False, **NO_HIT,
               children=[{"name": "Glow", "className": "SurfaceLight", "properties": {
                   "Face": "Bottom", "Range": 60, "Angle": 120, "Brightness": brightness,
                   "Color": m.rgb((255, 248, 232)), "Shadows": False}}])
    for x, y, z in data["spawns"]:
        m.spawn(x, z, y - 0.5)
    return m


# Ways the reach check can't work out itself: the wardrobe wall run from the bed to the desk,
# and the slide-lip jump onto the toy box (both one way: you drop back down). Kept on the map
# (ReachRoutes) so the check finds them on the map's folder too.
ROUTES = (((-41.6, 9, -20), (-38, 9, 8), False), ((36.5, 8, -6), (36.5, 12, 18), False))
ATTRIBUTES["ReachRoutes"] = mapcheck.routes_attribute(ROUTES)


def check(m):
    problems = mapcheck.check_map(m, ATTRIBUTES)
    # The jack must throw you onto the gatehouse: fly the throw from the lid and see where it
    # lands (the reach check only knows it lands somewhere).
    nodes = [n for group in m.groups.values() for n in group]
    lid = next(n for n in nodes if n["name"] == "JackLid")
    vx, vy, vz = lid["attributes"]["LaunchVelocity"]["Vector3"]
    reach = mapcheck.Reach(mapcheck.parts_from_nodes(nodes), [(x, y + 0.5, z) for x, y, z in m.spawns])
    reach.build()
    top = BOX[3] + LID_THICK
    landing = reach.fly(8, top + ROOT, -24, vx, vy, vz)
    if landing is None or abs(reach.nodes[landing][2] - JACK_TARGET[1]) > 0.5:
        problems.append(f"the jack's throw doesn't land on the gatehouse ({landing and reach.nodes[landing][:3]})")
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
