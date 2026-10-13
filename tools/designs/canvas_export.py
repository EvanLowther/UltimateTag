#!/usr/bin/env python3
"""Exports a map design for its 3D design canvas (the Design canvas viewer). Run from the
repo root:
    python3 tools/designs/canvas_export.py <design module> <out.json>
for example `python3 tools/designs/canvas_export.py rooftops_layout build/rooftops.json`. The
module (a design in tools/designs/, or a map generator in tools/) has `build()` (a maplib Map)
and a `CANVAS` dict: its labels, numbered markers and camera views. The viewer draws every part
(invisible ones skipped: the ladders' trusses, slide gates are shown as red glass), plays
spinning and swinging parts like client/MapAmbience, and marks the KillHeight.

Each part is [style, x, y, z, sx, sy, sz, rotation, flags, motion]; flags: 1 cylinder, 2 detail
(no collision), 4 roof (parts named in canvas["roof_names"]), 8 slide gate, 16 slip floor, 32
launch pad or speed boost, 64 wedge. Motions: spin, swing, and train cars ("car", plus "door" for
door panels), which run as canvas["train"] describes.
"""
import importlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)  # designs not in the game yet
sys.path.insert(0, os.path.dirname(HERE))  # map generators (tools/*_layout.py)
MATERIAL_CODES = {"Neon": "n", "Glass": "g"}


def export(m, canvas, kill_height=None, label="Design"):
    styles, style_index = [], {}
    rots, rot_index = [[1, 0, 0, 0, 1, 0, 0, 0, 1]], {}
    motions, motion_index, parts = [], {}, []
    for nodes in m.groups.values():
        for node in nodes:
            p = node["properties"]
            attrs = node.get("attributes") or {}
            transparency = p.get("Transparency", 0)
            gate = bool(attrs.get("SlideBlocker"))
            if transparency >= 1 and not gate:
                continue
            color = tuple(round(c * 255) for c in p["Color"])
            material = MATERIAL_CODES.get(p.get("Material"), "")
            alpha = 0.28 if gate else round(1 - transparency, 2)
            if gate:
                color, material = (230, 60, 60), "g"
            key = ("%02x%02x%02x" % color, material, alpha)
            if key not in style_index:
                style_index[key] = len(styles)
                styles.append(list(key))
            cf = p["CFrame"]["CFrame"]
            flat = [v for row in cf["orientation"] for v in row]
            ri = 0
            if flat != [1, 0, 0, 0, 1, 0, 0, 0, 1]:
                k = tuple(round(v, 4) for v in flat)
                if k not in rot_index:
                    rot_index[k] = len(rots)
                    rots.append(list(k))
                ri = rot_index[k]
            motion = {}
            if "Spin" in attrs:
                center = attrs.get("SpinCenter")
                motion["spin"] = attrs["Spin"]
                motion["c"] = [center["Vector3"][0], center["Vector3"][2]] if center else None
            if "SwingPivot" in attrs:
                axis = attrs["SwingAxis"]["Vector3"]
                n = math.sqrt(sum(a * a for a in axis)) or 1
                motion.update({"pivot": attrs["SwingPivot"]["Vector3"],
                               "axis": [round(a / n, 4) for a in axis],
                               "amp": attrs.get("SwingAmplitude", 0),
                               "period": attrs.get("SwingPeriod", 4),
                               "level": bool(attrs.get("SwingLevel"))})
            if "TrainCar" in attrs:  # rides the train (canvas["train"] says how it runs)
                motion["car"] = attrs["TrainCar"]
                if attrs.get("TrainDoor"):
                    motion["door"] = attrs["TrainDoor"]
            mi = -1
            if motion:
                mk = json.dumps(motion, sort_keys=True)
                if mk not in motion_index:
                    motion_index[mk] = len(motions)
                    motions.append(motion)
                mi = motion_index[mk]
            flags = 1 if p.get("Shape") == "Cylinder" else 0
            if node.get("className") == "WedgePart":
                flags |= 64
            if attrs.get("Slip"):
                flags |= 16
            elif attrs.get("LaunchVelocity") or attrs.get("SpeedBoost"):
                flags |= 32
            elif gate:
                flags |= 8
            elif p.get("CanCollide") is False:
                flags |= 2
            if canvas.get("roof_names") and node["name"].rstrip("0123456789") in canvas["roof_names"]:
                flags |= 4  # hidden until the viewer shows roofs and ceilings
            x, y, z = cf["position"]
            parts.append([style_index[key], *(round(v, 2) for v in (x, y, z, *p["Size"])), ri, flags,
                          mi])
    return {
        "label": label, "killHeight": kill_height, "styles": styles, "rots": rots, "parts": parts,
        "motions": motions, "labels": canvas["labels"], "markers": canvas["markers"],
        "spawns": [[round(x, 1), round(y + 0.5, 1), round(z, 1)] for x, y, z in m.spawns],
        "views": canvas["views"], "levels": canvas.get("levels", [{"label": "Whole map", "max": None}]),
        "figure": canvas["figure"], "train": canvas.get("train"), "killZones": canvas.get("kill_zones"),
    }


if __name__ == "__main__":
    design = importlib.import_module(sys.argv[1])
    data = {"v1": export(design.build(), design.CANVAS, design.ATTRIBUTES.get("KillHeight"),
                         design.CANVAS.get("label", "Design"))}
    with open(sys.argv[2], "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    print(f"{len(data['v1']['parts'])} parts -> {sys.argv[2]}")
