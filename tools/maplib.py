#!/usr/bin/env python3
"""Shared helpers for the map generators (tools/*_layout.py): build parts in code and write them
as Rojo files under src/maps/<Name>/ so Rojo syncs the map into Studio by itself.

    from maplib import Map, rot_x, rot_y, rot_z, polar
    m = Map(materials={"wall": "Plaster"}, colors={"wall": (200, 200, 200)})
    m.block("Walls", "Wall", x0, x1, y0, y1, z0, z1, "wall")
    m.write("src/maps/MyMap", {"DisplayName": "My Map", "MinPlayers": 2, "MaxPlayers": 8,
                               "InRotation": True})

Axes: X east, Z south, Y up. Colors are RGB 0-255 tuples or names from the map's palette.
Detail parts should be NO_HIT (no collision, ignored by raycasts) so moves and the camera
ignore them.
"""
import json
import math
import os
import shutil

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
NO_HIT = {"CanCollide": False, "CanQuery": False, "CanTouch": False}
SMOKE = "rbxasset://textures/particles/smoke_main.dds"
SPARK = "rbxasset://textures/particles/sparkles_main.dds"


def rot_x(deg):
    """Turns about X: a part's -Z end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(deg):
    """Turns about Y."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(deg):
    """Turns about Z: a part's +X end rises for positive angles."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def polar(radius, degrees):
    """(x, z) at `radius` from the center, `degrees` around (0 = +X, 90 = +Z)."""
    a = math.radians(degrees)
    return radius * math.cos(a), radius * math.sin(a)


def facing_out(degrees):
    """Rotation for a part at `degrees` around the center whose local +Z points away from the
    center (local X runs along the circle, -Z faces the middle)."""
    return rot_y(90 - degrees)


def r(v):
    return round(v, 3)


def number_sequence(points):
    return {"NumberSequence": {"keypoints": [{"time": t, "value": v, "envelope": 0}
                                             for t, v in points]}}


class Map:
    def __init__(self, colors=None, materials=None):
        self.colors = colors or {}
        self.materials = materials or {}
        self.groups = {}
        self.spawns = []
        self.counts = {}

    def rgb(self, color):
        value = self.colors.get(color, color) if isinstance(color, str) else color
        return [r(v / 255) for v in value]

    def _name(self, name):
        n = self.counts.get(name, 0) + 1
        self.counts[name] = n
        return name if n == 1 else f"{name}{n}"

    def part(self, group, name, size, pos, color, rows=IDENTITY, children=None, **props):
        attributes = props.pop("attributes", None)
        material = self.materials.get(color, "SmoothPlastic") if isinstance(color, str) \
            else "SmoothPlastic"
        properties = {
            "Anchored": True, "Size": [r(v) for v in size], "Color": self.rgb(color),
            "Material": material, "TopSurface": "Smooth", "BottomSurface": "Smooth",
            "CFrame": {"CFrame": {"position": [r(v) for v in pos],
                                  "orientation": [[r(v) for v in row] for row in rows]}},
        }
        properties.update(props)
        node = {"name": self._name(name), "className": "Part", "properties": properties}
        if attributes:
            node["attributes"] = attributes
        if children:
            node["children"] = children
        self.groups.setdefault(group, []).append(node)
        return node

    def block(self, group, name, x0, x1, y0, y1, z0, z1, color, **props):
        """An axis-aligned block from its bounds."""
        return self.part(group, name, (x1 - x0, y1 - y0, z1 - z0),
                         ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, **props)

    def cylinder(self, group, name, length, diameter, pos, color, rows=None, **props):
        """A cylinder; by default standing upright (its length is vertical)."""
        return self.part(group, name, (length, diameter, diameter), pos, color,
                         rows if rows is not None else rot_z(90), Shape="Cylinder", **props)

    def ring_wall(self, group, name, radius, thickness, y0, y1, segments, color, skip=(),
                  **props):
        """A round wall: `segments` flat panels whose inner faces sit at `radius` (they overlap a
        little so there are no gaps). `skip` lists panel indices to leave out (doorways)."""
        width = 2 * math.pi * (radius + thickness) / segments * 1.04
        for i in range(segments):
            if i in skip:
                continue
            degrees = i * 360 / segments
            x, z = polar(radius + thickness / 2, degrees)
            self.part(group, name, (width, y1 - y0, thickness), (x, (y0 + y1) / 2, z), color,
                      facing_out(degrees), **props)

    def ring_floor(self, group, name, r0, r1, y0, y1, segments, color, **props):
        """A flat ring from radius r0 to r1 (wedges as overlapping boxes)."""
        width = 2 * math.pi * r1 / segments * 1.05
        for i in range(segments):
            degrees = i * 360 / segments
            x, z = polar((r0 + r1) / 2, degrees)
            self.part(group, name, (width, y1 - y0, r1 - r0), (x, (y0 + y1) / 2, z), color,
                      facing_out(degrees), **props)

    def on_ring(self, group, name, radius, degrees, y, size, color, out=0.0, children=None,
                **props):
        """A flat part on the inside of a round wall at `radius`, facing the middle (its -Z,
        "Front", faces the center). size = (width, height, depth)."""
        x, z = polar(radius - size[2] / 2 - out, degrees)
        return self.part(group, name, size, (x, y, z), color, facing_out(degrees),
                         children=children, **props)

    def light(self, group, pos, size=(1, 1, 1), color=(255, 200, 140), brightness=0.8,
              reach=24, flicker=False):
        extra = {"attributes": {"Flicker": True}} if flicker else {}
        self.part(group, "Light", size, pos, color, Material="Neon", CastShadow=False,
                  children=[{"name": "Glow", "className": "PointLight", "properties": {
                      "Brightness": brightness, "Range": reach, "Color": self.rgb(color),
                      "Shadows": False}}], **NO_HIT, **extra)

    def spawn(self, x, z, y=0.0):
        self.spawns.append((x, y, z))

    def surface_text(self, face, text, color, font="FredokaOne", pps=30, glow=False,
                     background=None):
        """A SurfaceGui with one label filling the face."""
        label = {"Size": {"UDim2": [[0.92, 0], [0.88, 0]]},
                 "Position": {"UDim2": [[0.04, 0], [0.06, 0]]},
                 "BackgroundTransparency": 1, "Text": text, "TextScaled": True,
                 "RichText": True, "Font": font, "TextColor3": self.rgb(color)}
        if background is not None:
            label["BackgroundTransparency"] = 0
            label["BackgroundColor3"] = self.rgb(background)
        gui = {"Face": face, "SizingMode": "PixelsPerStud", "PixelsPerStud": pps}
        if glow:
            gui["LightInfluence"] = 0
            gui["Brightness"] = 2
        return {"name": f"Text{face}", "className": "SurfaceGui", "properties": gui,
                "children": [{"name": "Label", "className": "TextLabel", "properties": label}]}

    def particles(self, name, rate, life, speed, size, transparency, color, texture=SMOKE,
                  direction="Top", spread=(10, 10), accel=(0, 0, 0), light=0):
        return {"name": name, "className": "ParticleEmitter", "properties": {
            "Rate": rate, "Lifetime": {"NumberRange": list(life)},
            "Speed": {"NumberRange": list(speed)}, "Size": number_sequence(size),
            "Transparency": number_sequence(transparency),
            "Color": {"ColorSequence": {"keypoints": [{"time": 0, "color": self.rgb(color)},
                                                      {"time": 1, "color": self.rgb(color)}]}},
            "Texture": texture, "EmissionDirection": direction,
            "SpreadAngle": {"Vector2": list(spread)}, "Acceleration": list(accel),
            "LightEmission": light, "Drag": 0.5,
        }}

    def count(self):
        return sum(len(v) for v in self.groups.values())

    def write(self, out_dir, attributes):
        """Writes the map as Rojo files (one folder per group, plus Spawns). The folder is
        generated: it's replaced each run."""
        if os.path.isdir(out_dir):
            shutil.rmtree(out_dir)
        os.makedirs(out_dir)

        def dump(name, data):
            with open(os.path.join(out_dir, name), "w") as f:
                json.dump(data, f, indent=1)
                f.write("\n")

        dump("init.meta.json", {"className": "Model", "attributes": attributes})
        for group, children in self.groups.items():
            dump(f"{group}.model.json", {"className": "Folder", "children": children})
        spawns = []
        for i, (x, y, z) in enumerate(self.spawns):
            spawns.append({"name": f"Spawn{i + 1}", "className": "Part", "properties": {
                "Anchored": True, "CanCollide": False, "CanQuery": False, "CanTouch": False,
                "CastShadow": False, "Transparency": 1, "Size": [2, 1, 2],
                "CFrame": {"CFrame": {"position": [r(x), r(y + 0.5), r(z)],
                                      "orientation": IDENTITY}}}})
        dump("Spawns.model.json", {"className": "Folder", "children": spawns})
