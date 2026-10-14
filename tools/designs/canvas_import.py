"""Turns a design canvas's own data back into map parts, for designs whose generator never made
it into the repo (the Metro, Tag Mart): the canvas's `this._data` saved as JSON in
tools/designs/ is every part the viewer draws (see canvas_export.py for the format). What the
export doesn't keep (names, most materials, attributes, invisible parts such as ladder trusses)
the map generator adds back; `parts` and `props` do the rest.
"""
import json

CYLINDER, DETAIL, ROOF, GATE, SLIP, BOOST, WEDGE, TUNNEL, BALL = 1, 2, 4, 8, 16, 32, 64, 128, 256
NO_HIT = {"CanCollide": False, "CanQuery": False, "CanTouch": False}


def load(path):
    """The design's data (its one version)."""
    with open(path) as f:
        return json.load(f)["v1"]


def parts(data):
    """Every part as a dict: index, style, color (r, g, b), code ("n" neon, "g" glass, ""),
    alpha, pos, size, rows (orientation), flags and motion (or None)."""
    styles, rots, motions = data["styles"], data["rots"], data["motions"]
    for index, p in enumerate(data["parts"]):
        style, x, y, z, sx, sy, sz, ri, flags, mi = p
        color_hex, code, alpha = styles[style]
        r = rots[ri]
        yield {
            "index": index, "style": style,
            "color": tuple(int(color_hex[i:i + 2], 16) for i in (0, 2, 4)),
            "code": code, "alpha": alpha, "pos": (x, y, z), "size": (sx, sy, sz),
            "rows": [r[0:3], r[3:6], r[6:9]], "flags": flags,
            "motion": motions[mi] if mi >= 0 else None,
        }


def props(part, material):
    """A part's properties from its flags and style: shape, collision, neon, glass."""
    out = {"Material": material}
    flags = part["flags"]
    if flags & CYLINDER:
        out["Shape"] = "Cylinder"
    elif flags & BALL:
        out["Shape"] = "Ball"
    if flags & DETAIL:
        out.update(NO_HIT)
    if part["code"] == "n":
        out["Material"] = "Neon"
    if part["code"] == "g":
        out["Material"] = "Glass"
        out["Transparency"] = round(1 - part["alpha"], 2)
        out["CastShadow"] = False
    return out


def place(m, group, name, part, props, children=None):
    """Adds the part to the map (a WedgePart if the design's is one) and returns its node."""
    node = m.part(group, name, part["size"], part["pos"], part["color"], part["rows"],
                  children=children, **props)
    if part["flags"] & WEDGE:
        node["className"] = "WedgePart"
    return node


def text_face(size, pos):
    """The face of a flat sign on a wall that looks into the room (the room is round 0, 0)."""
    sx, _, sz = size
    if sz <= sx:  # thin along Z: on a wall along X
        return "Back" if pos[2] < 0 else "Front"
    return "Right" if pos[0] < 0 else "Left"
