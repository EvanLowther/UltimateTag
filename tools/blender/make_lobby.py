# Ultimate Tag lobby generator (Blender, bpy).
#
# Builds the tropical island lobby from the reference art: a raised grass island on a sand
# beach, a central gazebo with the welcome sign, a beach firepit lounge, the leaderboard, the
# daily reward wheel, the avatar shop, the striped lighthouse, the gamepass board, docks, palms,
# hedgerows, rocks, crates, benches, lampposts, a faceted ocean and distant islands.
#
# Built for Roblox, light but editable:
#   * One mesh per object (a palm, a bench, the shop...). Every object is a separate, named
#     Blender object with its origin at its base (the reward wheel's at its center).
#   * Colors come from one shared palette texture (a single row of color swatches); each face's
#     UVs point at its swatch. One material, one texture, for everything.
#   * Glowing pieces (lamps, flames, the lighthouse lantern, neon ribbons) are separate objects
#     named *_Glow so Roblox can make them Neon. The reward wheel disc is separate so it spins.
#   * Repeated objects (palms, hedges, benches, crates, lampposts) are built once and copied; each
#     object has its own mesh named after it, so imported pieces are always named predictably.
#   * Sign text is not modeled: every sign's text panel (position, facing, size, lines) is written
#     to src/tools/LobbyData.luau, and the Roblox setup tool (src/tools/SetupLobby.luau) turns
#     them into real, editable Roblox text. Previews get temporary 3D text so signs read.
#   * Four marker cubes let the setup tool fix any scale, rotation or offset from the importer
#     (and spot a mirrored import).
#
# Units are studs (1 Blender unit = 1 stud), Z up, water level at Z = 0, the island's front
# (gamepass board, main ramp) faces -Y.
#
# Run without a window (from the repo root):
#   blender --background --python tools/blender/make_lobby.py -- [out_dir] [preview_dir]
# or open it in Blender's Text Editor and press Run Script (writes next to the .blend, or to
# ~/UltimateTagLobby if the file is unsaved).
# Writes <out_dir>/UltimateTagLobby.blend, UltimateTagLobby.fbx, LobbyPalette.png and, when a
# preview_dir is given, preview renders. Also writes src/tools/LobbyData.luau when run from the repo.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# --- Output locations ----------------------------------------------------------------------------
ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if ARGS:
    OUT_DIR = os.path.abspath(ARGS[0])
elif bpy.data.filepath:
    OUT_DIR = os.path.dirname(bpy.data.filepath)
else:
    OUT_DIR = os.path.join(os.path.expanduser("~"), "UltimateTagLobby")
PREVIEW_DIR = os.path.abspath(ARGS[1]) if len(ARGS) > 1 else None
REPO_DATA = os.path.join(os.getcwd(), "src", "tools", "LobbyData.luau")

SEED = 7
random.seed(SEED)

# --- Island shape ----------------------------------------------------------------------------------
ISLAND_RX, ISLAND_RY = 104.0, 80.0  # beach radii (X wide, Y deep)
GRASS_SCALE = 0.82  # grass plateau radius as a share of the beach radius
BEACH_Z = 1.4  # top of the beach
GRASS_Z = 4.0  # top of the grass plateau (most things stand here)
SHORE_Z = 0.3  # where the beach meets the water


def island_radius(theta, scale=1.0):
    """Radius of the beach edge at angle theta, an irregular rounded shape."""
    c, s = math.cos(theta), math.sin(theta)
    ellipse = 1.0 / math.sqrt((c / ISLAND_RX) ** 2 + (s / ISLAND_RY) ** 2)
    wobble = 1 + 0.055 * math.sin(3 * theta + 0.8) + 0.04 * math.sin(5 * theta + 2.1) + 0.022 * math.sin(9 * theta + 0.4)
    return ellipse * wobble * scale


def edge_point(deg, scale, z):
    t = math.radians(deg)
    r = island_radius(t, scale)
    return Vector((math.cos(t) * r, math.sin(t) * r, z))


# --- Palette ---------------------------------------------------------------------------------------
# sRGB colors, grouped so neighbours are similar (texture filtering at a distance blends neighbours).
PALETTE = [
    ("WaterDeep", (0.04, 0.36, 0.78)),
    ("WaterMid", (0.08, 0.52, 0.88)),
    ("WaterShallow", (0.16, 0.72, 0.90)),
    ("WaterLight", (0.32, 0.86, 0.93)),
    ("Foam", (0.90, 0.98, 1.00)),
    ("SeabedDeep", (0.18, 0.42, 0.55)),
    ("SeabedNear", (0.62, 0.80, 0.72)),
    ("SandWet", (0.85, 0.74, 0.52)),
    ("SandDark", (0.92, 0.78, 0.52)),
    ("Sand", (0.99, 0.88, 0.62)),
    ("Plaza", (0.98, 0.90, 0.70)),
    ("Cream", (0.97, 0.93, 0.82)),
    ("Dirt", (0.62, 0.44, 0.26)),
    ("GrassSide", (0.33, 0.62, 0.20)),
    ("Grass", (0.44, 0.80, 0.24)),
    ("GrassLight", (0.54, 0.87, 0.30)),
    ("LeafLight", (0.50, 0.90, 0.28)),
    ("Leaf", (0.30, 0.78, 0.22)),
    ("LeafDark", (0.17, 0.58, 0.18)),
    ("HedgeLight", (0.28, 0.66, 0.22)),
    ("Hedge", (0.18, 0.52, 0.18)),
    ("Bottle", (0.22, 0.62, 0.32)),
    ("Distant", (0.30, 0.52, 0.55)),
    ("DistantLight", (0.42, 0.64, 0.62)),
    ("RockLight", (0.68, 0.69, 0.72)),
    ("Rock", (0.56, 0.57, 0.61)),
    ("RockDark", (0.42, 0.43, 0.48)),
    ("Stone", (0.68, 0.68, 0.70)),
    ("StoneDark", (0.52, 0.52, 0.56)),
    ("Iron", (0.20, 0.20, 0.23)),
    ("Black", (0.08, 0.08, 0.10)),
    ("Navy", (0.09, 0.15, 0.32)),
    ("NavyLight", (0.15, 0.25, 0.50)),
    ("RoofBlueDark", (0.25, 0.33, 0.48)),
    ("RoofBlue", (0.34, 0.44, 0.62)),
    ("Blue", (0.18, 0.44, 0.95)),
    ("Neon", (0.20, 0.78, 1.00)),
    ("Cyan", (0.18, 0.84, 0.95)),
    ("Glass", (0.70, 0.90, 0.98)),
    ("White", (0.96, 0.96, 0.96)),
    ("Bamboo", (0.88, 0.78, 0.44)),
    ("BambooDark", (0.70, 0.60, 0.30)),
    ("Rope", (0.86, 0.76, 0.52)),
    ("WoodLight", (0.84, 0.62, 0.38)),
    ("Wood", (0.70, 0.46, 0.26)),
    ("WoodDark", (0.46, 0.29, 0.16)),
    ("Trunk", (0.63, 0.46, 0.28)),
    ("TrunkDark", (0.48, 0.33, 0.20)),
    ("Coconut", (0.42, 0.28, 0.14)),
    ("ShingleDark", (0.50, 0.24, 0.12)),
    ("Shingle", (0.64, 0.33, 0.18)),
    ("RedDark", (0.68, 0.10, 0.10)),
    ("Red", (0.90, 0.18, 0.18)),
    ("Pink", (0.98, 0.45, 0.70)),
    ("Purple", (0.60, 0.30, 0.86)),
    ("Orange", (1.00, 0.55, 0.10)),
    ("Flame", (1.00, 0.50, 0.08)),
    ("FlameCore", (1.00, 0.86, 0.26)),
    ("Lamp", (1.00, 0.88, 0.45)),
    ("Yellow", (1.00, 0.85, 0.15)),
    ("Gold", (1.00, 0.78, 0.15)),
    ("GoldDark", (0.85, 0.60, 0.10)),
    ("Green", (0.24, 0.76, 0.30)),
]
PAL_INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}
PAL_COLOR = dict(PALETTE)
CELL = 8  # pixels per swatch
PAL_CELLS = 128  # swatch slots in the texture (one row)


def make_palette_image():
    img = bpy.data.images.new("LobbyPalette", width=CELL * PAL_CELLS, height=CELL, alpha=False)
    pixels = [0.0] * (img.size[0] * img.size[1] * 4)
    for x in range(img.size[0]):
        cell = min(x // CELL, len(PALETTE) - 1)
        r, g, b = PALETTE[cell][1]
        for y in range(img.size[1]):
            i = (y * img.size[0] + x) * 4
            pixels[i : i + 4] = [r, g, b, 1.0]
    img.pixels = pixels
    img.filepath_raw = os.path.join(OUT_DIR, "LobbyPalette.png")
    img.file_format = "PNG"
    img.save()
    return img


# --- Materials -------------------------------------------------------------------------------------
MATERIALS = {}


def make_materials(img):
    """Matte palette material (roughness 1, no specular or metal), a glowing variant for lights
    and a see-through variant for the ocean."""
    for name, glow, alpha in (("LobbyPalette", False, 1.0), ("LobbyGlow", True, 1.0), ("LobbyWater", False, 0.72)):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nodes, links = m.node_tree.nodes, m.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Metallic"].default_value = 0.0
        for spec in ("Specular IOR Level", "Specular"):
            if spec in bsdf.inputs:
                bsdf.inputs[spec].default_value = 0.0
        if glow:
            links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 3.0
        if alpha < 1.0:
            bsdf.inputs["Alpha"].default_value = alpha
            if hasattr(m, "surface_render_method"):
                m.surface_render_method = "BLENDED"
            elif hasattr(m, "blend_method"):
                m.blend_method = "BLEND"
        m.diffuse_color = (1, 1, 1, alpha)
        MATERIALS[name] = m


# --- Collections and data records ---------------------------------------------------------------
COLLECTIONS = {}


def collection(name):
    if name not in COLLECTIONS:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
        COLLECTIONS[name] = c
    return COLLECTIONS[name]


OBJECTS = []  # every lobby object for the setup tool
PANELS = []  # sign text panels
POINTS = {"Seats": [], "Prompts": [], "Colliders": [], "Spawn": None, "Wheel": None}
GLOW = {}  # glow part name -> (color, transparency)


def record(name, parts, category, collision, pivot, yaw=0.0):
    OBJECTS.append({"Name": name, "Parts": parts, "Category": category, "Collision": collision,
                    "Pivot": tuple(pivot), "Yaw": yaw})


def transform(loc=(0, 0, 0), rot=(0, 0, 0)):
    return Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()


def panel(owner, name, kind, lines, world, local_center, local_normal, size, local_up=(0, 0, 1)):
    """A text panel on a sign. `world` is the owner's world matrix; the rest is in the owner's
    local space. Normal points out of the sign face toward the reader."""
    center = world @ Vector(local_center)
    rot = world.to_3x3()
    normal = (rot @ Vector(local_normal)).normalized()
    up = (rot @ Vector(local_up)).normalized()
    PANELS.append({"Owner": owner, "Name": name, "Kind": kind, "Lines": lines,
                   "Center": tuple(center), "Normal": tuple(normal), "Up": tuple(up), "Size": tuple(size)})


def seat(owner, world, local_pos, local_forward):
    pos = world @ Vector(local_pos)
    fwd = (world.to_3x3() @ Vector(local_forward)).normalized()
    POINTS["Seats"].append({"Owner": owner, "Position": tuple(pos), "Forward": tuple(fwd)})


def prompt(owner, kind, world, local_pos, action, object_text):
    pos = world @ Vector(local_pos)
    POINTS["Prompts"].append({"Owner": owner, "Kind": kind, "Position": tuple(pos),
                              "Action": action, "ObjectText": object_text})


# --- Mesh builder ---------------------------------------------------------------------------------
class Mesh:
    """Collects primitives into one bmesh, remembering each face's palette color."""

    def __init__(self):
        self.bm = bmesh.new()
        self.layer = self.bm.faces.layers.int.new("pal")

    def _paint(self, verts, key):
        index = PAL_INDEX[key]
        for face in {f for v in verts for f in v.link_faces}:
            face[self.layer] = index

    def _paint_random(self, verts, keys):
        for face in {f for v in verts for f in v.link_faces}:
            face[self.layer] = PAL_INDEX[random.choice(keys)]

    @staticmethod
    def _matrix(loc, rot, scale, lift):
        return (Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
                @ Matrix.Translation((0, 0, lift)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1)))

    def box(self, size, key, loc=(0, 0, 0), rot=(0, 0, 0), base=True):
        m = self._matrix(loc, rot, size, size[2] / 2 if base else 0)
        verts = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"]
        self._paint(verts, key)
        return verts

    def cyl(self, r, h, key, loc=(0, 0, 0), rot=(0, 0, 0), sides=8, r_top=None, base=True):
        top = r if r_top is None else max(r_top, 0.001)
        m = self._matrix(loc, rot, (1, 1, 1), h / 2 if base else 0)
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=sides,
                                      radius1=r, radius2=top, depth=h, matrix=m)["verts"]
        self._paint(verts, key)
        return verts

    def ico(self, r, keys, loc=(0, 0, 0), scale=(1, 1, 1), jitter=0.0, rot=(0, 0, 0), sub=1):
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r)["verts"]
        for v in verts:
            v.co.x *= scale[0] * (1 + random.uniform(-jitter, jitter))
            v.co.y *= scale[1] * (1 + random.uniform(-jitter, jitter))
            v.co.z *= scale[2] * (1 + random.uniform(-jitter, jitter))
        bmesh.ops.transform(self.bm, matrix=self._matrix(loc, rot, (1, 1, 1), 0), verts=verts)
        if isinstance(keys, str):
            self._paint(verts, keys)
        else:
            self._paint_random(verts, keys)
        return verts

    def prism(self, points, depth, key, loc=(0, 0, 0), rot=(0, 0, 0)):
        """A flat shape from 2D points (x, z), `depth` thick along Y, centered on Y = 0."""
        m = self._matrix(loc, rot, (1, 1, 1), 0)
        front = [self.bm.verts.new(m @ Vector((x, -depth / 2, z))) for x, z in points]
        back = [self.bm.verts.new(m @ Vector((x, depth / 2, z))) for x, z in points]
        faces = [self.bm.faces.new(front), self.bm.faces.new(list(reversed(back)))]
        n = len(points)
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((front[i], back[i], back[j], front[j])))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        for f in faces:
            f[self.layer] = PAL_INDEX[key]
        return front + back

    def quads(self, rings, keys_for_band, closed=True):
        """Faces between consecutive vertex rings. keys_for_band(band, i) -> palette key."""
        faces = []
        for b in range(len(rings) - 1):
            lower, upper = rings[b], rings[b + 1]
            n = len(lower)
            for i in range(n if closed else n - 1):
                j = (i + 1) % n
                f = self.bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
                f[self.layer] = PAL_INDEX[keys_for_band(b, i)]
                faces.append(f)
        return faces

    def cap(self, ring, key):
        f = self.bm.faces.new(ring)
        f[self.layer] = PAL_INDEX[key]
        return f

    def finish(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        uv = me.uv_layers.new(name="UVMap")
        pal = me.attributes["pal"]
        for poly in me.polygons:
            poly.use_smooth = False  # flat, faceted low-poly shading
            u = (pal.data[poly.index].value + 0.5) / PAL_CELLS
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.5)
        return me


def place(name, me, category, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), material="LobbyPalette"):
    # Every object gets its own mesh named after it, so Studio's importer names the piece the
    # same whether it uses object or mesh names (shared meshes are copied).
    if me.users > 0:
        me = me.copy()
    me.name = name
    obj = bpy.data.objects.new(name, me)
    if not me.materials:
        me.materials.append(MATERIALS[material])
    collection(category).objects.link(obj)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    obj.scale = scale
    return obj


def glow(name, mesh, category, color_key, loc=(0, 0, 0), rot=(0, 0, 0), transparency=0.0):
    me = mesh.finish(name)
    me.materials.append(MATERIALS["LobbyGlow"])
    place(name, me, category, loc, rot)
    GLOW[name] = (PAL_COLOR[color_key], transparency)
    return name


# =================================================================================================
# Island, water and the far horizon
# =================================================================================================
def build_ocean():
    m = Mesh()
    size, n = 1600.0, 64
    verts = {}
    for iy in range(n + 1):
        for ix in range(n + 1):
            x = -size / 2 + size * ix / n
            y = -size / 2 + size * iy / n
            verts[(ix, iy)] = m.bm.verts.new((x, y, random.uniform(-0.18, 0.18)))
    for iy in range(n):
        for ix in range(n):
            a, b, c, d = verts[(ix, iy)], verts[(ix + 1, iy)], verts[(ix + 1, iy + 1)], verts[(ix, iy + 1)]
            for tri in ((a, b, c), (a, c, d)):
                f = m.bm.faces.new(tri)
                center = sum((v.co for v in tri), Vector()) / 3
                theta = math.atan2(center.y, center.x)
                d_edge = center.length - island_radius(theta)
                # Mostly one shade per zone, with the odd lighter or darker facet for sparkle.
                if d_edge < 28:
                    keys = ["WaterLight"] * 6 + ["WaterShallow"]
                elif d_edge < 90:
                    keys = ["WaterShallow"] * 6 + ["WaterLight"]
                elif d_edge < 220:
                    keys = ["WaterMid"] * 6 + ["WaterShallow"]
                else:
                    keys = ["WaterDeep"] * 6 + ["WaterMid"]
                f[m.layer] = PAL_INDEX[random.choice(keys)]
    me = m.finish("Ocean")
    me.materials.append(MATERIALS["LobbyWater"])
    place("Ocean", me, "Water")
    record("Ocean", ["Ocean"], "Water", "None", (0, 0, 0))


def build_seabed():
    """Sand under the water: shallow near the island (seen through the water as turquoise),
    dropping away to deep blue."""
    m = Mesh()
    sides = 64
    rings = []
    for scale, z in ((1.0, SHORE_Z - 0.2), (1.12, -3.0), (1.35, -9.0), (2.0, -22.0), (4.6, -40.0)):
        ring = []
        for i in range(sides):
            t = 2 * math.pi * i / sides
            r = island_radius(t) * scale
            ring.append(m.bm.verts.new((math.cos(t) * r, math.sin(t) * r, z)))
        rings.append(ring)
    m.quads(list(reversed(rings)), lambda b, i: ["SeabedDeep", "SeabedDeep", "SeabedNear", "SeabedNear"][b])
    place("Seabed", m.finish("Seabed"), "Water")
    record("Seabed", ["Seabed"], "Water", "Precise", (0, 0, 0))


def build_island():
    m = Mesh()
    sides = 72
    shape = [  # (radius scale, height) from the shore up to the grass top
        (1.0, SHORE_Z),
        (0.94, BEACH_Z - 0.2),
        (0.88, BEACH_Z),
        (GRASS_SCALE + 0.02, BEACH_Z + 0.05),
        (GRASS_SCALE, GRASS_Z - 0.4),
        (GRASS_SCALE - 0.015, GRASS_Z),
        (GRASS_SCALE - 0.1, GRASS_Z),
        (0.45, GRASS_Z),
    ]
    rings = []
    for scale, z in shape:
        ring = []
        for i in range(sides):
            t = 2 * math.pi * i / sides
            r = island_radius(t, scale)
            ring.append(m.bm.verts.new((math.cos(t) * r, math.sin(t) * r, z)))
        rings.append(ring)

    def band(b, i):
        if b == 0:
            return random.choice(["SandWet", "SandDark"])
        if b in (1, 2):
            return random.choice(["Sand", "Sand", "SandDark"])
        if b == 3:
            return "GrassSide"
        if b == 4:
            return "Grass"
        return random.choice(["Grass", "Grass", "GrassLight"])

    m.quads(rings, band)
    m.cap(rings[-1], "Grass")
    me = m.finish("Island_Base")
    place("Island_Base", me, "Island")
    record("Island_Base", ["Island_Base"], "Island", "Precise", (0, 0, 0))

    foam = Mesh()
    inner, outer = [], []
    for i in range(sides):
        t = 2 * math.pi * i / sides
        r = island_radius(t)
        inner.append(foam.bm.verts.new((math.cos(t) * (r - 1.5), math.sin(t) * (r - 1.5), 0.42)))
        outer.append(foam.bm.verts.new((math.cos(t) * (r + 3.5), math.sin(t) * (r + 3.5), 0.12)))
    foam.quads([inner, outer], lambda b, i: "Foam")
    place("Shoreline_Foam", foam.finish("Shoreline_Foam"), "Water")
    record("Shoreline_Foam", ["Shoreline_Foam"], "Water", "None", (0, 0, 0))


def build_distant_islands():
    for i, (x, y, r, h) in enumerate(((-520, 560, 120, 55), (-260, 650, 80, 34), (330, 620, 140, 62), (600, 430, 90, 40))):
        m = Mesh()
        m.ico(r, ["Distant", "DistantLight"], (0, 0, -r * 0.25), (1.0, 0.7, h / r), jitter=0.18, sub=2)
        m.cyl(r * 1.05, 2, "SandWet", (0, 0, -1.5), sides=14)
        name = f"Distant_Island_{i + 1:02d}"
        place(name, m.finish(name), "Horizon", (x, y, 0))
        record(name, [name], "Horizon", "None", (x, y, 0))


# =================================================================================================
# Ground details: plaza, paths, ramps, lounge sand
# =================================================================================================
def blob(m, center, rx, ry, z, key, sides=24, thickness=0.12, wobble=0.12, seed=0):
    rnd = random.Random(seed)
    top, bottom = [], []
    phases = [rnd.uniform(0, 6.28) for _ in range(3)]
    for i in range(sides):
        t = 2 * math.pi * i / sides
        k = 1 + wobble * (math.sin(2 * t + phases[0]) * 0.6 + math.sin(3 * t + phases[1]) * 0.4)
        x, y = center[0] + math.cos(t) * rx * k, center[1] + math.sin(t) * ry * k
        top.append(m.bm.verts.new((x, y, z + thickness)))
        bottom.append(m.bm.verts.new((x, y, z - 0.3)))
    m.quads([bottom, top], lambda b, i: key)
    m.cap(top, key)
    m.cap(list(reversed(bottom)), key)


def strip(m, a, b, width, z, key):
    a, b = Vector((a[0], a[1], z)), Vector((b[0], b[1], z))
    d = b - a
    yaw = math.degrees(math.atan2(d.y, d.x))
    mid = (a + b) / 2
    m.box((d.length + width * 0.6, width, 0.24), key, (mid.x, mid.y, z - 0.12), (0, 0, yaw))


def build_ground_details():
    m = Mesh()
    blob(m, (2, -18), 40, 30, GRASS_Z, "Plaza", seed=1)
    place("Plaza", m.finish("Plaza"), "Island")
    record("Plaza", ["Plaza"], "Island", "None", (2, -18, GRASS_Z))

    paths = {
        "Path_Firepit": [(-34, -14), (-44, -8)],
        "Path_Lighthouse": [(8, 10), (14, 30), (18, 40)],
        "Path_Shop": [(36, -14), (48, -8)],
        "Path_Wheel": [(24, -2), (32, 10)],
        "Path_DockWest": [(-26, -36), (-50, -50)],
        "Path_DockEast": [(30, 8), (52, 34), (62, 42)],
    }
    for name, pts in paths.items():
        p = Mesh()
        for i in range(len(pts) - 1):
            strip(p, pts[i], pts[i + 1], 7.5, GRASS_Z + 0.06, "Plaza")
        place(name, p.finish(name), "Island")
        record(name, [name], "Island", "None", (pts[0][0], pts[0][1], GRASS_Z))

    lounge = Mesh()
    blob(lounge, (-56, -6), 17, 14, GRASS_Z, "Sand", seed=2)
    place("Lounge_Sand", lounge.finish("Lounge_Sand"), "Island")
    record("Lounge_Sand", ["Lounge_Sand"], "Island", "None", (-56, -6, GRASS_Z))

    # Ramps from the grass down to the beach at the hedge gaps.
    for name, deg in (("Ramp_Front", -90), ("Ramp_DockWest", 214), ("Ramp_DockEast", 38)):
        t = math.radians(deg)
        top = edge_point(deg, GRASS_SCALE - 0.03, GRASS_Z)
        bottom = edge_point(deg, GRASS_SCALE + 0.09, BEACH_Z)
        length = (Vector((top.x, top.y, 0)) - Vector((bottom.x, bottom.y, 0))).length
        r = Mesh()
        # Wedge: flat top at grass height sloping down to the beach, 12 wide.
        r.prism([(0, 0), (length, 0), (0, GRASS_Z - BEACH_Z + 0.1)], 12, "Plaza", (0, 0, 0), (0, 0, 0))
        yaw = math.degrees(t)
        obj_loc = (top.x, top.y, BEACH_Z - 0.05)
        # Prism lies in local XZ with depth along Y: rotate so +X points outward (down the slope).
        place(name, r.finish(name), "Island", obj_loc, (0, 0, yaw))
        record(name, [name], "Island", "Precise", obj_loc, yaw)


# =================================================================================================
# Nature: hedges, rocks, palms, bushes
# =================================================================================================
def hedge_mesh(name, variant):
    m = Mesh()
    rnd = random.Random(100 + variant)
    m.box((10.4, 3.2, 3.6), "Hedge", (0, 0, 0))
    for k in range(6):
        x = -4.4 + k * 1.75 + rnd.uniform(-0.3, 0.3)
        m.ico(1.55 + rnd.uniform(-0.15, 0.3), ["Hedge", "HedgeLight", "HedgeLight"], (x, rnd.uniform(-0.4, 0.4), 3.6), (1.1, 1.0, 0.9), jitter=0.12)
    for k in range(3):
        m.ico(1.2, ["Hedge", "HedgeLight"], (-3.5 + k * 3.5, -1.3, 1.8), (1.2, 0.8, 1.0), jitter=0.1)
    return m.finish(name)


def build_hedges():
    meshes = [hedge_mesh("HedgeMeshA", 0), hedge_mesh("HedgeMeshB", 1)]
    gaps = [(-103, -77), (202, 226), (26, 50)]
    count = 0
    step = 7
    for deg in range(0, 360, step):
        mid = deg + step / 2
        signed = mid if mid <= 180 else mid - 360
        if any(lo <= signed <= hi or lo <= mid <= hi for lo, hi in gaps):
            continue
        a = edge_point(deg, GRASS_SCALE - 0.035, GRASS_Z - 0.1)
        b = edge_point(deg + step, GRASS_SCALE - 0.035, GRASS_Z - 0.1)
        c = (a + b) / 2
        d = b - a
        count += 1
        name = f"Hedgerow_{count:02d}"
        yaw = math.degrees(math.atan2(d.y, d.x))
        place(name, meshes[count % 2], "Nature", tuple(c), (0, 0, yaw), ((d.length + 1.2) / 10.4, 1, 1))
        record(name, [name], "Nature", "Box", tuple(c), yaw)


def rock_cluster(name, loc, size, count, seed):
    rnd_state = random.getstate()
    random.seed(seed)
    m = Mesh()
    for k in range(count):
        s = size * random.uniform(0.55, 1.0)
        off = (random.uniform(-size, size) * 0.7, random.uniform(-size, size) * 0.7, s * 0.25)
        m.ico(s, ["Rock", "RockLight", "RockDark", "Rock"], off, (random.uniform(0.9, 1.3), random.uniform(0.9, 1.3), random.uniform(0.6, 0.9)), jitter=0.22, rot=(0, 0, random.uniform(0, 360)))
    random.setstate(rnd_state)
    place(name, m.finish(name), "Nature", loc)
    record(name, [name], "Nature", "Hull", loc)


def build_rocks():
    clusters = [
        ("Rock_Cluster_01", edge_point(236, 0.97, 0.4), 7.5, 4),
        ("Rock_Cluster_02", edge_point(-62, 0.96, 0.4), 8.0, 4),
        ("Rock_Cluster_03", edge_point(-12, 0.98, 0.4), 6.0, 3),
        ("Rock_Cluster_04", edge_point(74, 0.97, 0.4), 6.5, 3),
        ("Rock_Cluster_05", edge_point(166, 0.98, 0.4), 6.0, 3),
        ("Rock_Cluster_06", (-34, 44, GRASS_Z - 0.5), 9.0, 5),
    ]
    for i, (name, loc, size, count) in enumerate(clusters):
        rock_cluster(name, tuple(loc), size, count, SEED * 10 + i)


def palm_mesh(name, height_segments, lean, seed):
    rnd = random.Random(seed)
    m = Mesh()
    direction = Vector((0, 0, 1))
    point = Vector((0, 0, -0.5))
    axis = Vector((1, 0, 0))  # trunks lean toward -Y in mesh space; objects rotate to aim
    for i in range(height_segments):
        r = 1.05 - i * 0.07
        rot = direction.rotation_difference(Vector((0, 0, 1)))
        euler = Vector((0, 0, 1)).rotation_difference(direction).to_euler()
        seg_rot = tuple(math.degrees(a) for a in euler)
        m.cyl(r, 3.6, "Trunk" if i % 2 == 0 else "TrunkDark", tuple(point), seg_rot, sides=6, r_top=r - 0.08)
        m.cyl(r + 0.15, 0.45, "TrunkDark", tuple(point + direction * 3.2), seg_rot, sides=6)
        point = point + direction * 3.5
        bend = -(lean + i * 1.8) * (1 if i % 2 == 0 else 0.6)
        direction = (Matrix.Rotation(math.radians(bend), 3, axis) @ direction).normalized()
    top = point
    m.ico(1.3, ["LeafDark", "Leaf"], tuple(top + Vector((0, 0, 0.2))), (1, 1, 0.7))
    for k in range(3):
        a = math.radians(k * 120 + 30)
        m.ico(0.65, "Coconut", tuple(top + Vector((math.cos(a) * 1.0, math.sin(a) * 1.0, -0.6))))
    fronds = 9
    for f in range(fronds):
        yaw = f * 360 / fronds + rnd.uniform(-10, 10)
        key = ["Leaf", "LeafDark", "LeafLight"][f % 3]
        base = top + Vector((0, 0, 0.4))
        pitch = rnd.uniform(-12, 4)  # first segment slightly up or level
        seg_point = base
        widths = (3.0, 2.6, 1.5)
        for s, width in enumerate(widths):
            length = 3.4 - s * 0.3
            pitch -= 18 + s * 6  # droop more toward the tip
            dir_v = Euler((0, math.radians(-pitch), math.radians(yaw))).to_matrix() @ Vector((1, 0, 0))
            centre = seg_point + dir_v * (length / 2)
            # Diamond-ish leaf piece: a thin box tapered by its width.
            m.box((length + 0.4, width, 0.28), key, tuple(centre), (0, -pitch, yaw), base=False)
            seg_point = seg_point + dir_v * length
    return m.finish(name)


def build_palms():
    meshes = [palm_mesh("PalmMeshA", 6, 5, 1), palm_mesh("PalmMeshB", 7, 4, 2), palm_mesh("PalmMeshC", 5, 7, 3)]
    spots = [
        ((-84, -22), 70, 1.05), ((-74, 24), 120, 1.0), ((-44, 60), 150, 0.95), ((-6, 64), 185, 1.05),
        ((48, 58), 200, 1.0), ((86, 26), 250, 1.08), ((86, -30), 300, 0.95), ((-62, -52), 30, 1.0),
    ]
    for i, ((x, y), yaw, s) in enumerate(spots):
        name = f"Palm_Tree_{i + 1:02d}"
        place(name, meshes[i % 3], "Nature", (x, y, GRASS_Z - 0.3), (0, 0, yaw), (s, s, s))
        record(name, [name], "Nature", "None", (x, y, GRASS_Z), yaw)
        POINTS["Colliders"].append({"Owner": name, "Position": (x, y, GRASS_Z), "Radius": 1.3 * s, "Height": 12 * s})


def build_bushes():
    spots = [(-24, 46), (-44, 36), (14, 52), (32, 54), (70, 14), (44, -22), (-30, -30), (-70, 8), (64, -24), (-12, 30)]
    for i, (x, y) in enumerate(spots):
        m = Mesh()
        for k in range(4):
            a = k * 1.7
            m.ico(1.4 + (k % 2) * 0.4, ["Leaf", "LeafDark", "LeafLight"], (math.cos(a) * 1.3, math.sin(a) * 1.3, 0.9), (1, 1, 0.85), jitter=0.15)
        name = f"Bush_{i + 1:02d}"
        place(name, m.finish(name), "Nature", (x, y, GRASS_Z))
        record(name, [name], "Nature", "None", (x, y, GRASS_Z))


# =================================================================================================
# Props: benches, crates, lampposts, docks
# =================================================================================================
def bench_mesh():
    m = Mesh()
    for i in range(3):
        m.box((5.6, 0.55, 0.3), "WoodLight", (0, -0.65 + i * 0.65, 1.7))
    for i in range(2):
        m.box((5.6, 0.3, 0.55), "Wood", (0, 0.95, 2.4 + i * 0.75), (-8, 0, 0))
    for x in (-2.4, 2.4):
        m.box((0.35, 1.9, 0.35), "Iron", (x, 0, 1.4))
        m.box((0.35, 0.35, 1.7), "Iron", (x, -0.75, 0))
        m.box((0.35, 0.35, 3.4), "Iron", (x, 0.85, 0), (-8, 0, 0))
    return m.finish("BenchMesh")


def build_benches(bench_me):
    spots = [((-26, -26), 90), ((30, -28), -90), ((-16, 28), 200), ((18, 30), 160), ((-4, -48), 0), ((44, 22), 220)]
    for i, ((x, y), yaw) in enumerate(spots):
        name = f"Park_Bench_{i + 1:02d}"
        loc = (x, y, GRASS_Z)
        place(name, bench_me, "Props", loc, (0, 0, yaw))
        record(name, [name], "Props", "Box", loc, yaw)
        seat(name, transform(loc, (0, 0, yaw)), (0, 0, 2.0), (0, -1, 0))


def crate_mesh(name, layout, seed):
    rnd = random.Random(seed)
    m = Mesh()
    for (x, y, z) in layout:
        yaw = rnd.uniform(-10, 10)
        c = (x * 3.3, y * 3.3, z * 3.1)
        m.box((3.1, 3.1, 3.1), "Wood", c, (0, 0, yaw))
        for face in (-1, 1):
            for dz in (0.15, 2.65):
                m.box((3.3, 0.25, 0.4), "WoodDark", (c[0], c[1], c[2] + dz), (0, 0, yaw))
            m.box((0.4, 0.25, 3.6), "WoodDark", (c[0], c[1], c[2] + 1.55), (0, 45, yaw), base=False)
    return m.finish(name)


def build_crates():
    stacks = [
        ("Crate_Stack_01", (-36, -22, GRASS_Z), [(0, 0, 0), (1, 0, 0), (0.5, 0.2, 1)], 15),
        ("Crate_Stack_02", (-36, 48, GRASS_Z + 5.5), [(0, 0, 0), (0.6, 0.8, 0)], 25),
        ("Crate_Stack_03", (72, -18, GRASS_Z), [(0, 0, 0), (0, 1, 0), (0.1, 0.5, 1), (1, 0.4, 0)], 35),
        ("Crate_Stack_04", (-70, -12, GRASS_Z), [(0, 0, 0), (1, 0.2, 0)], 45),
    ]
    for name, loc, layout, seed in stacks:
        yaw = random.uniform(0, 90)
        place(name, crate_mesh(name, layout, seed), "Props", loc, (0, 0, yaw))
        record(name, [name], "Props", "Box", loc, yaw)


def build_lampposts():
    body = Mesh()
    body.cyl(0.8, 0.9, "Iron", sides=8)
    body.cyl(0.25, 10.5, "Iron", (0, 0, 0.9), sides=6)
    body.box((2.2, 0.3, 0.3), "Iron", (0.9, 0, 10.9))
    body.box((0.3, 0.3, 1.0), "Iron", (1.9, 0, 10.0))
    body.cyl(1.0, 0.6, "Iron", (1.9, 0, 9.9), sides=4, rot=(0, 0, 45), r_top=0.2)
    for dx, dy in ((-0.55, -0.55), (0.55, -0.55), (0.55, 0.55), (-0.55, 0.55)):
        body.box((0.15, 0.15, 1.6), "Iron", (1.9 + dx, dy, 8.3))
    body_me = body.finish("LamppostMesh")
    lamp = Mesh()
    lamp.box((1.0, 1.0, 1.5), "Lamp", (1.9, 0, 8.35))
    lamp_me = lamp.finish("LamppostGlowMesh")
    lamp_me.materials.append(MATERIALS["LobbyGlow"])
    for i, ((x, y), yaw) in enumerate((((-24, -44), 0), ((24, -44), 180), ((-26, 12), 30), ((22, -8), 150))):
        name = f"Street_Lamppost_{i + 1:02d}"
        place(f"{name}_Body", body_me, "Props", (x, y, GRASS_Z), (0, 0, yaw))
        place(f"{name}_Glow", lamp_me, "Props", (x, y, GRASS_Z), (0, 0, yaw))
        GLOW[f"{name}_Glow"] = (PAL_COLOR["Lamp"], 0.0)
        record(name, [f"{name}_Body", f"{name}_Glow"], "Props", "Box", (x, y, GRASS_Z), yaw)


def build_docks():
    for i, deg in enumerate((214, 38)):
        name = f"Wooden_Dock_{i + 1}"
        start = edge_point(deg, 0.9, 0)
        loc = (start.x, start.y, 0)
        yaw = deg - 90  # local +Y points out to sea
        m = Mesh()
        for k in range(16):
            m.box((7.4, 1.55, 0.35), "WoodLight" if k % 2 == 0 else "Wood", (0, k * 1.7, 1.75))
        for x in (-3.6, 3.6):
            m.box((0.5, 27.5, 0.5), "WoodDark", (x, 12.9, 1.3))
        for k in range(4):
            for x in (-3.6, 3.6):
                m.cyl(0.42, 7, "WoodDark", (x, k * 8.2, -5), sides=6)
        for x in (-3.4, 3.4):
            m.cyl(0.55, 9.2, "WoodDark", (x, 26.6, -5), sides=6)
            m.cyl(0.75, 0.5, "Rope", (x, 26.6, 3.1), sides=8)
            m.cyl(0.62, 0.3, "WoodLight", (x, 26.6, 4.2), sides=6)
        place(name, m.finish(name), "Props", loc, (0, 0, yaw))
        record(name, [name], "Props", "Precise", loc, yaw)


# =================================================================================================
# Landmarks
# =================================================================================================
def build_gazebo():
    loc, yaw = (0, 10, GRASS_Z), 0
    world = transform(loc, (0, 0, yaw))
    m = Mesh()
    # Raised octagonal stone base in three tiers, with steps up the front.
    for k, (r, h) in enumerate(((13.6, 0.8), (12.9, 0.8), (12.2, 0.8))):
        m.cyl(r, h, "Stone" if k % 2 == 0 else "StoneDark", (0, 0, k * 0.8), rot=(0, 0, 22.5), sides=8)
    for k in range(3):
        m.box((8, 1.6, 0.8 * (k + 1)), "Stone" if k % 2 == 0 else "StoneDark", (0, -14.2 - (2 - k) * 1.6 + 1.6, 0))
    floor_z = 2.4
    m.cyl(12.0, 0.25, "WoodLight", (0, 0, floor_z), rot=(0, 0, 22.5), sides=8)
    post_r = 10.8
    post_h = 10.5
    for i in range(8):
        a = math.radians(i * 45)
        x, y = math.cos(a) * post_r, math.sin(a) * post_r
        m.box((0.9, 0.9, post_h), "Wood", (x, y, floor_z), (0, 0, i * 45))
        m.box((1.3, 1.3, 0.5), "WoodDark", (x, y, floor_z), (0, 0, i * 45))
        # Railing between this post and the next, except the front opening (-Y side).
        mid_deg = i * 45 + 22.5
        if abs(((mid_deg - 270) + 180) % 360 - 180) < 30:
            continue
        mid = math.radians(mid_deg)
        side = 2 * post_r * math.sin(math.radians(22.5))
        mx, my = math.cos(mid) * post_r * math.cos(math.radians(22.5)), math.sin(mid) * post_r * math.cos(math.radians(22.5))
        for z in (floor_z + 1.0, floor_z + 3.2):
            m.box((side - 0.8, 0.35, 0.45), "WoodDark", (mx, my, z), (0, 0, mid_deg + 90))
        for b in range(5):
            f = (b + 1) / 6 - 0.5
            bx = mx + math.cos(mid + math.pi / 2) * f * (side - 0.8)
            by = my + math.sin(mid + math.pi / 2) * f * (side - 0.8)
            m.box((0.3, 0.3, 2.2), "Wood", (bx, by, floor_z + 1.0), (0, 0, mid_deg + 90))
    # Beam ring at the top of the posts.
    top_z = floor_z + post_h
    for i in range(8):
        mid_deg = i * 45 + 22.5
        mid = math.radians(mid_deg)
        side = 2 * post_r * math.sin(math.radians(22.5))
        mx, my = math.cos(mid) * post_r * math.cos(math.radians(22.5)), math.sin(mid) * post_r * math.cos(math.radians(22.5))
        m.box((side + 0.6, 0.8, 0.9), "WoodDark", (mx, my, top_z - 0.9), (0, 0, mid_deg + 90))
    # Multi-tier shingle roof: stepped layers that overhang.
    layers = [(15.2, 13.0, 1.3, "Shingle"), (13.2, 10.8, 1.3, "ShingleDark"), (11.0, 8.6, 1.3, "Shingle"),
              (8.8, 7.6, 0.9, "WoodDark"),
              (8.6, 6.4, 1.3, "Shingle"), (6.6, 4.4, 1.3, "ShingleDark"), (4.6, 2.2, 1.3, "Shingle"), (2.4, 0.3, 1.6, "ShingleDark")]
    z = top_z
    for r0, r1, h, key in layers:
        m.cyl(r0, h, key, (0, 0, z), rot=(0, 0, 22.5), sides=8, r_top=r1)
        z += h * 0.92
    m.ico(0.9, "Gold", (0, 0, z + 0.6))
    m.cyl(0.25, 2.2, "Gold", (0, 0, z + 1.0), sides=6, r_top=0.02)
    # Welcome sign over the entrance, leaning back slightly against the roof.
    sign_y, sign_z, sign_w, sign_h = -12.6, top_z + 1.0, 22.0, 7.6
    m.box((sign_w, 0.7, sign_h), "WoodLight", (0, sign_y, sign_z), (-8, 0, 0))
    for dz in (0.0, sign_h - 0.6):
        m.box((sign_w + 0.8, 0.9, 0.6), "WoodDark", (0, sign_y - 0.05, sign_z + dz), (-8, 0, 0))
    for dx in (-sign_w / 2, sign_w / 2):
        m.box((0.6, 0.9, sign_h), "WoodDark", (dx, sign_y - 0.05, sign_z), (-8, 0, 0))
    lean = Euler((math.radians(-8), 0, 0)).to_matrix()
    face_center = Vector((0, sign_y, sign_z)) + lean @ Vector((0, -0.4, sign_h / 2))
    panel("Gazebo", "WelcomeText", "Welcome", ["WELCOME TO", "ULTIMATE TAG"], world, tuple(face_center),
          tuple(lean @ Vector((0, -1, 0))), (sign_w - 1.4, sign_h - 1.4), tuple(lean @ Vector((0, 0, 1))))
    # Four interior benches along the back half, and a stone ring fire pit in the middle.
    for k, deg in enumerate((45, 90, 135, 180)):
        a = math.radians(deg)
        bx, by = math.cos(a) * 8.0, math.sin(a) * 8.0
        bench_yaw = deg - 90
        m.box((4.6, 1.4, 0.35), "WoodLight", (bx, by, floor_z + 1.4), (0, 0, bench_yaw))
        m.box((4.6, 0.35, 1.2), "Wood", (bx + math.cos(a) * 0.7, by + math.sin(a) * 0.7, floor_z + 1.75), (0, 0, bench_yaw))
        for s in (-1.8, 1.8):
            lx = bx + math.cos(a + math.pi / 2) * s
            ly = by + math.sin(a + math.pi / 2) * s
            m.box((0.35, 1.2, 1.4), "WoodDark", (lx, ly, floor_z), (0, 0, bench_yaw))
        seat("Gazebo", world, (bx, by, floor_z + 1.8), (-math.cos(a), -math.sin(a), 0))
    for i in range(8):
        a = math.radians(i * 45)
        m.ico(0.75, ["Stone", "StoneDark"], (math.cos(a) * 2.0, math.sin(a) * 2.0, floor_z + 0.5), (1.1, 1.0, 0.8), jitter=0.1)
    for k in range(2):
        m.cyl(0.35, 3.2, "TrunkDark", (0, 0, floor_z + 0.6), rot=(90, 0, 45 + k * 90), sides=6, base=False)
    place("Gazebo", m.finish("Gazebo"), "Landmarks", loc, (0, 0, yaw))
    fire = Mesh()
    fire.cyl(1.1, 2.6, "Flame", (0, 0, floor_z + 0.4), sides=5, r_top=0.05)
    fire.cyl(0.7, 1.9, "Flame", (0.6, 0.3, floor_z + 0.4), rot=(0, 0, 30), sides=4, r_top=0.05)
    glow("Gazebo_Fire_Glow", fire, "Landmarks", "Flame", loc, (0, 0, yaw))
    record("Gazebo", ["Gazebo", "Gazebo_Fire_Glow"], "Landmarks", "Precise", loc, yaw)


def build_firepit_lounge():
    center = Vector((-56, -6, GRASS_Z))
    # Firepit: 8 boulders around criss-crossed logs, with interlocking flame pyramids.
    pit = Mesh()
    for i in range(8):
        a = math.radians(i * 45 + 10)
        pit.ico(1.15, ["Rock", "RockLight", "RockDark"], (math.cos(a) * 3.3, math.sin(a) * 3.3, 0.6), (1.1, 1.0, 0.8), jitter=0.18)
    for k in range(4):
        pit.cyl(0.42, 4.6, "Trunk" if k % 2 == 0 else "TrunkDark", (0, 0, 0.5 + (k // 2) * 0.6), rot=(90, 0, 20 + k * 45), sides=6, base=False)
    # A log pile beside it.
    for k, (x, z) in enumerate(((-1.2, 0), (0, 0), (1.2, 0), (-0.6, 1.0), (0.6, 1.0), (0, 2.0))):
        pit.cyl(0.55, 4.2, "Trunk", (6.2 + x, 4.4, 0.55 + z), rot=(90, 0, 0), sides=6, base=False)
    loc = tuple(center)
    place("Lounge_Firepit", pit.finish("Lounge_Firepit"), "Lounge_Zone", loc)
    flames = Mesh()
    for k, (x, y, h) in enumerate(((0, 0, 4.0), (0.8, 0.4, 2.9), (-0.7, -0.5, 3.1))):
        flames.cyl(1.25, h, "Flame", (x, y, 0.4), rot=(0, 0, k * 20), sides=4, r_top=0.05)
    glow("Lounge_Flames_Glow", flames, "Lounge_Zone", "Flame", loc)
    core = Mesh()
    for k, (x, y, h) in enumerate(((0.1, 0.1, 2.6), (-0.3, 0.3, 1.9))):
        core.cyl(0.75, h, "FlameCore", (x, y, 0.4), rot=(0, 0, 45 + k * 15), sides=4, r_top=0.05)
    glow("Lounge_FlameCore_Glow", core, "Lounge_Zone", "FlameCore", loc)
    record("Lounge_Firepit", ["Lounge_Firepit", "Lounge_Flames_Glow", "Lounge_FlameCore_Glow"], "Lounge_Zone", "Hull", loc)

    # Signpost with an arrow plank pointing to the shore (-X) and the lounge sign.
    sign_loc = (-38, -18, GRASS_Z)
    sign_yaw = -25
    world = transform(sign_loc, (0, 0, sign_yaw))
    s = Mesh()
    s.box((0.8, 0.8, 9.5), "WoodDark", (0, 0, 0))
    s.box((9.5, 0.5, 3.6), "WoodLight", (0, -0.6, 5.2))
    s.box((10.1, 0.6, 0.4), "WoodDark", (0, -0.65, 8.8))
    s.box((10.1, 0.6, 0.4), "WoodDark", (0, -0.65, 5.0))
    s.prism([(-6.5, 0), (-2.0, 1.1), (3.0, 1.1), (3.0, -1.1), (-2.0, -1.1)], 0.45, "Wood", (-1.0, -0.6, 3.6), (0, 0, 0))
    place("Signpost_Beach", s.finish("Signpost_Beach"), "Lounge_Zone", sign_loc, (0, 0, sign_yaw))
    record("Signpost_Beach", ["Signpost_Beach"], "Lounge_Zone", "Box", sign_loc, sign_yaw)
    panel("Signpost_Beach", "SignText", "Wood", ["BEACH FIREPIT", "LOUNGE"], world, (0, -0.9, 7.0), (0, -1, 0), (9.0, 3.2))

    # Three beach chairs with angled backs and armrests, facing the fire.
    colors = ["Red", "Blue", "Yellow"]
    for i, deg in enumerate((200, 250, 300)):
        a = math.radians(deg)
        cx, cy = center.x + math.cos(a) * 9.0, center.y + math.sin(a) * 9.0
        yaw = deg + 90
        c = Mesh()
        paint = colors[i]
        for k in range(4):
            c.box((2.8, 0.5, 0.25), paint, (0, -1.1 + k * 0.6, 1.6), (6, 0, 0))
        for k in range(4):
            c.box((0.55, 0.25, 3.6), paint, (-1.05 + k * 0.7, 1.2, 1.5), (-28, 0, 0))
        for x in (-1.7, 1.7):
            c.box((0.4, 3.2, 0.25), "White", (x, -0.2, 2.6))
            c.box((0.3, 0.3, 2.6), "White", (x, -1.6, 0))
            c.box((0.3, 0.3, 1.8), "White", (x, 1.1, 0))
        name = f"Lounge_BeachChair_{i + 1:02d}"
        cloc = (cx, cy, GRASS_Z)
        place(name, c.finish(name), "Lounge_Zone", cloc, (0, 0, yaw))
        record(name, [name], "Lounge_Zone", "Box", cloc, yaw)
        seat(name, transform(cloc, (0, 0, yaw)), (0, -0.2, 1.9), (0, -1, 0))

    # Low coffee table with three bottles.
    t = Mesh()
    t.box((4.2, 2.6, 0.35), "WoodLight", (0, 0, 1.6))
    for x in (-1.7, 1.7):
        for y in (-1.0, 1.0):
            t.box((0.35, 0.35, 1.6), "WoodDark", (x, y, 0))
    for k, (x, y) in enumerate(((-1.0, 0.4), (0.0, -0.5), (1.1, 0.3))):
        t.cyl(0.28, 1.1, "Bottle", (x, y, 1.95), sides=6)
        t.cyl(0.12, 0.55, "Bottle", (x, y, 3.05), sides=6)
    tloc = (center.x + 3.5, center.y - 11.5, GRASS_Z)
    place("Lounge_Table", t.finish("Lounge_Table"), "Lounge_Zone", tloc, (0, 0, 15))
    record("Lounge_Table", ["Lounge_Table"], "Lounge_Zone", "Box", tloc, 15)

    # A big decorative anchor leaning on a driftwood log.
    an = Mesh()
    an.cyl(0.9, 8.5, "WoodLight", (0, 0.4, 0.9), rot=(0, 90, 0), sides=6, base=False)
    an.box((0.7, 0.7, 8.0), "Iron", (0, -0.6, 0.4), (25, 0, 0))
    an.box((4.2, 0.6, 0.6), "Iron", (0, -2.6, 7.3), (25, 0, 0))
    an.cyl(0.9, 0.4, "Iron", (0, -3.3, 8.6), rot=(90, 0, 0), sides=8, base=False)
    for side in (-1, 1):
        an.box((3.6, 0.6, 0.6), "Iron", (side * 1.6, 0.2, 1.5), (25, side * -40, 0))
        an.prism([(0, 0), (1.4, 0.9), (0.2, 1.8)], 0.5, "Iron", (side * 2.8, 0.4, 2.2), (25, 0, 90 if side < 0 else -90))
    aloc = (center.x - 7.5, center.y + 10.5, GRASS_Z)
    place("Lounge_Anchor", an.finish("Lounge_Anchor"), "Lounge_Zone", aloc, (0, 0, 20))
    record("Lounge_Anchor", ["Lounge_Anchor"], "Lounge_Zone", "Hull", aloc, 20)


def build_leaderboard():
    loc, yaw = (-20, -24, GRASS_Z), -12
    world = transform(loc, (0, 0, yaw))
    m = Mesh()
    for x in (-11.2, 11.2):
        m.box((2.4, 2.4, 1.2), "Stone", (x, 0, 0))
        m.box((1.8, 1.8, 18.5), "Wood", (x, 0, 1.2))
        m.box((2.2, 2.2, 0.6), "WoodDark", (x, 0, 19.7))
    m.box((25.4, 2.0, 1.6), "WoodDark", (0, 0, 18.1))
    m.box((20.4, 0.8, 14.6), "WoodDark", (0, 0.3, 3.2))
    m.box((19.4, 0.6, 13.6), "Navy", (0, 0, 3.7))
    m.box((20.8, 1.0, 0.9), "Wood", (0, -0.1, 2.6))
    m.box((22.0, 1.2, 3.6), "GoldDark", (0, -0.25, 14.2))
    m.box((21.4, 1.3, 3.0), "Gold", (0, -0.3, 14.5))
    # Golden crown on top of the crossbeam.
    m.box((4.6, 1.2, 1.4), "Gold", (0, 0, 19.7))
    for k in range(5):
        x = -1.9 + k * 0.95
        m.cyl(0.55, 2.2 if k % 2 == 0 else 1.6, "Gold", (x, 0, 21.0), rot=(0, 0, 45), sides=4, r_top=0.05)
    for k, (x, key) in enumerate(((-1.3, "Red"), (0, "Blue"), (1.3, "Green"))):
        m.ico(0.35, key, (x, -0.6, 20.4))
    place("Leaderboard", m.finish("Leaderboard"), "UI_Assets", loc, (0, 0, yaw))
    record("Leaderboard", ["Leaderboard"], "UI_Assets", "Box", loc, yaw)
    panel("Leaderboard", "Header", "BoardHeader", ["GLOBAL LEADERBOARD:", "TOTAL SURVIVAL WINS"], world, (0, -1.0, 16.0), (0, -1, 0), (20.6, 2.8))
    panel("Leaderboard", "Screen", "Leaderboard", [], world, (0, -0.35, 8.1), (0, -1, 0), (18.6, 8.6))


def build_reward_wheel():
    loc, yaw = (34, 14, GRASS_Z), -28
    world = transform(loc, (0, 0, yaw))
    stand = Mesh()
    stand.box((9, 4.5, 0.8), "WoodDark", (0, 0, 0))
    hub_z = 9.5
    for side in (-1, 1):
        for depth in (-1.2, 1.2):
            # A-frame legs leaning in to meet under the hub.
            stand.cyl(0.38, 10.8, "Bamboo", (side * 3.6, depth, 0.8), rot=(0, side * -18, 0), sides=6)
            for k in range(3):
                stand.cyl(0.46, 0.3, "BambooDark", (side * (3.6 - (k + 1) * 0.85), depth, 0.8 + (k + 1) * 2.6), rot=(0, side * -18, 0), sides=6)
    stand.box((7.5, 0.6, 0.6), "Bamboo", (0, -1.2, 4.0))
    stand.box((7.5, 0.6, 0.6), "Bamboo", (0, 1.2, 4.0))
    stand.cyl(0.4, 3.2, "BambooDark", (0, 0, hub_z), rot=(90, 0, 0), sides=6, base=False)
    # Pointer: a sharp red wedge at the top, pointing down at the wheel.
    stand.box((0.6, 0.6, 2.6), "Wood", (0, -0.9, hub_z + 6.0))
    stand.prism([(-0.9, 1.6), (0.9, 1.6), (0, -0.3)], 0.6, "Red", (0, -1.4, hub_z + 5.0))
    # Small sign on the base.
    stand.box((6.4, 0.4, 2.4), "WoodLight", (0, -2.5, 0.8), (-15, 0, 0))
    place("RewardWheel_Stand", stand.finish("RewardWheel_Stand"), "UI_Assets", loc, (0, 0, yaw))
    tilt = Euler((math.radians(-15), 0, 0)).to_matrix()
    panel("RewardWheel", "SignText", "Wood", ["DAILY REWARD", "WHEEL"], world,
          tuple(Vector((0, -2.5, 0.8)) + tilt @ Vector((0, -0.25, 1.2))), tuple(tilt @ Vector((0, -1, 0))), (6.0, 2.0), tuple(tilt @ Vector((0, 0, 1))))
    # The wheel: separate so it can spin. Origin at its center; it faces -Y.
    w = Mesh()
    radius, thick, sides = 5.6, 0.8, 24
    colors = ["Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Pink"]
    front_c = w.bm.verts.new((0, -thick / 2, 0))
    back_c = w.bm.verts.new((0, thick / 2, 0))
    rim_front, rim_back = [], []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        rim_front.append(w.bm.verts.new((math.cos(a) * radius, -thick / 2, math.sin(a) * radius)))
        rim_back.append(w.bm.verts.new((math.cos(a) * radius, thick / 2, math.sin(a) * radius)))
    for i in range(sides):
        j = (i + 1) % sides
        f = w.bm.faces.new((front_c, rim_front[j], rim_front[i]))
        f[w.layer] = PAL_INDEX[colors[(i * 8) // sides]]  # 3 triangles per color segment
        f = w.bm.faces.new((back_c, rim_back[i], rim_back[j]))
        f[w.layer] = PAL_INDEX["WoodDark"]
        f = w.bm.faces.new((rim_front[i], rim_front[j], rim_back[j], rim_back[i]))
        f[w.layer] = PAL_INDEX["Gold"]
    w.cyl(radius + 0.35, 0.5, "GoldDark", (0, 0.1, 0), rot=(90, 0, 0), sides=sides, base=False)
    w.cyl(1.0, 1.4, "White", (0, -0.2, 0), rot=(90, 0, 0), sides=10, base=False)
    w.cyl(0.4, 1.8, "Gold", (0, -0.3, 0), rot=(90, 0, 0), sides=6, base=False)
    for i in range(8):
        a = math.radians(i * 45)
        w.ico(0.3, "White", (math.cos(a) * (radius - 0.4), -0.6, math.sin(a) * (radius - 0.4)))
    wheel_loc = tuple(world @ Vector((0, -1.9, hub_z)))
    place("RewardWheel_Wheel", w.finish("RewardWheel_Wheel"), "UI_Assets", wheel_loc, (0, 0, yaw))
    record("RewardWheel", ["RewardWheel_Stand", "RewardWheel_Wheel"], "UI_Assets", "Hull", loc, yaw)
    axis = (world.to_3x3() @ Vector((0, -1, 0))).normalized()
    POINTS["Wheel"] = {"Owner": "RewardWheel", "Part": "RewardWheel_Wheel", "Center": wheel_loc, "Axis": tuple(axis), "Segments": 8}
    prompt("RewardWheel", "RewardWheel", world, (0, -5.5, 3.0), "Spin", "Daily Reward Wheel")


def build_shop():
    loc = (60, 2, GRASS_Z)
    yaw = -40  # front (-Y) turned toward the plaza
    world = transform(loc, (0, 0, yaw))
    m = Mesh()
    W, D, H = 20.0, 14.0, 10.0  # footprint and wall height
    t = 0.8  # wall thickness
    m.box((W + 1.2, D + 1.2, 0.9), "Stone", (0, 0, 0))
    # Front wall with a recessed doorway (left) and an open counter window (right).
    fy = -D / 2 + t / 2
    door_x, door_w, door_h = -4.5, 3.8, 6.6
    win_x, win_w, win_z0, win_z1 = 4.5, 6.0, 3.6, 7.2
    pieces = [
        (-W / 2 + (door_x - door_w / 2 + W / 2) / 2, door_x - door_w / 2 + W / 2, 0.9, H),
        ((door_x + door_w / 2 + win_x - win_w / 2) / 2, (win_x - win_w / 2) - (door_x + door_w / 2), 0.9, H),
        ((win_x + win_w / 2 + W / 2) / 2, W / 2 - (win_x + win_w / 2), 0.9, H),
    ]
    for cx, w_, z0, z1 in pieces:
        m.box((w_, t, z1 - z0), "Wood", (cx, fy, z0))
    m.box((door_w, t, H - door_h - 0.9), "Wood", (door_x, fy, 0.9 + door_h))
    m.box((win_w, t, win_z0 - 0.9), "Wood", (win_x, fy, 0.9))
    m.box((win_w, t, H - win_z1), "Wood", (win_x, fy, win_z1))
    m.box((door_w - 0.4, 0.4, door_h - 0.2), "WoodDark", (door_x, fy + t * 0.6, 0.9))  # recessed door
    m.ico(0.25, "Gold", (door_x + 1.2, fy + 0.1, 0.9 + door_h * 0.45))
    for dx in (-door_w / 2 - 0.25, door_w / 2 + 0.25):
        m.box((0.5, t + 0.3, door_h + 0.5), "White", (door_x + dx, fy, 0.9))
    m.box((door_w + 1.0, t + 0.3, 0.5), "White", (door_x, fy, 0.9 + door_h))
    # Counter window frame, counter shelf and a striped awning.
    for dx in (-win_w / 2 - 0.25, win_w / 2 + 0.25):
        m.box((0.5, t + 0.3, win_z1 - win_z0 + 0.5), "White", (win_x + dx, fy, win_z0 - 0.25))
    m.box((win_w + 1.0, 1.8, 0.4), "WoodLight", (win_x, fy - 0.6, win_z0 - 0.2))
    for k in range(6):
        m.box((win_w / 6 + 0.05, 2.6, 0.25), "Red" if k % 2 == 0 else "White", (win_x - win_w / 2 + (k + 0.5) * win_w / 6, fy - 1.3, win_z1 + 0.7), (-22, 0, 0))
    # Side and back walls, with a hollow window on each side.
    for sx in (-1, 1):
        x = sx * (W / 2 - t / 2)
        m.box((t, D, 3.2 - 0.9), "Wood", (x, 0, 0.9))
        m.box((t, D, H - 6.8), "Wood", (x, 0, 6.8))
        m.box((t, D / 2 - 2.2, 3.6), "Wood", (x, -D / 4 - 1.1, 3.2))
        m.box((t, D / 2 - 2.2, 3.6), "Wood", (x, D / 4 + 1.1, 3.2))
        m.box((0.2, 4.4, 3.6), "Glass", (x - sx * 0.1, 0, 3.2))
        m.box((t + 0.3, 5.0, 0.4), "White", (x, 0, 3.0))
        m.box((t + 0.3, 5.0, 0.4), "White", (x, 0, 6.8))
        m.box((t + 0.3, 0.3, 3.6), "White", (x, 0, 3.2))
    m.box((W, t, H - 0.9), "Wood", (0, D / 2 - t / 2, 0.9))
    # Plank lines and corner posts.
    for k in range(5):
        z = 2.4 + k * 1.6
        m.box((W + 0.1, 0.12, 0.18), "WoodDark", (0, -D / 2 - 0.02, z))
        m.box((0.12, D + 0.1, 0.18), "WoodDark", (-W / 2 - 0.02, 0, z))
        m.box((0.12, D + 0.1, 0.18), "WoodDark", (W / 2 + 0.02, 0, z))
    for cx in (-W / 2, W / 2):
        for cy in (-D / 2, D / 2):
            m.box((1.1, 1.1, H), "WoodDark", (cx, cy, 0.9))
    # Asymmetric roof: a long front slope and a short steep back slope, in shingle rows.
    eave_front, eave_back, ridge_y, ridge_z = -D / 2 - 2.2, D / 2 + 1.4, 2.5, H + 6.8
    for k in range(5):
        y0 = eave_front + (ridge_y - eave_front) * k / 5
        y1 = eave_front + (ridge_y - eave_front) * (k + 1) / 5
        z0 = H + 0.9 + (ridge_z - H - 0.9) * k / 5
        z1 = H + 0.9 + (ridge_z - H - 0.9) * (k + 1) / 5
        length = math.hypot(y1 - y0, z1 - z0)
        pitch = math.degrees(math.atan2(z1 - z0, y1 - y0))
        m.box((W + 3.0, length + 0.3, 0.6), "RoofBlue" if k % 2 == 0 else "RoofBlueDark", (0, (y0 + y1) / 2, (z0 + z1) / 2 - 0.3), (pitch, 0, 0))
    back_len = math.hypot(eave_back - ridge_y, ridge_z - H - 0.9)
    back_pitch = math.degrees(math.atan2(-(ridge_z - H - 0.9), eave_back - ridge_y))
    m.box((W + 3.0, back_len + 0.3, 0.6), "RoofBlueDark", (0, (ridge_y + eave_back) / 2, (ridge_z + H + 0.9) / 2 - 0.3), (back_pitch, 0, 0))
    m.box((W + 3.2, 1.0, 0.8), "WoodDark", (0, ridge_y, ridge_z - 0.3))
    for sx in (-1, 1):  # gable ends
        m.prism([(-D / 2, 0), (D / 2, 0), (ridge_y, ridge_z - H - 0.9)], 0.8, "Wood", (sx * (W / 2 - 0.4), 0, H + 0.9), (0, 0, 90))
    m.box((2.0, 2.0, 5.0), "Stone", (-6.0, 3.5, ridge_z - 3.0))  # chimney
    # Porch deck and steps.
    m.box((W + 1.2, 4.2, 0.6), "WoodLight", (0, -D / 2 - 2.6, 0.3))
    m.box((6.0, 1.6, 0.45), "WoodLight", (door_x, -D / 2 - 5.4, 0.0))
    # Main sign standing on the front roof slope.
    sy, sz = -D / 2 + 1.0, H + 2.8
    m.box((15.0, 0.7, 4.6), "Navy", (0, sy, sz))
    m.box((15.8, 0.9, 0.6), "WoodDark", (0, sy + 0.05, sz - 0.3))
    m.box((15.8, 0.9, 0.6), "WoodDark", (0, sy + 0.05, sz + 4.4))
    for x in (-5.5, 5.5):
        m.box((0.6, 0.6, 3.0), "WoodDark", (x, sy + 0.6, H + 0.9))
    panel("AvatarShop", "MainSign", "Banner", ["AVATAR SHOP", "/ CUSTOMIZE"], world, (0, sy - 0.45, sz + 2.3), (0, -1, 0), (14.2, 4.0))
    # Big side panel on the right wall: SKINS & EMOTES.
    m.box((0.5, 9.0, 4.8), "WoodLight", (W / 2 + 0.6, -1.0, 2.3))
    m.box((0.6, 9.6, 0.5), "WoodDark", (W / 2 + 0.65, -1.0, 2.1))
    m.box((0.6, 9.6, 0.5), "WoodDark", (W / 2 + 0.65, -1.0, 7.1))
    panel("AvatarShop", "SidePanel", "Skins", ["SKINS &", "EMOTES"], world, (W / 2 + 0.95, -1.0, 4.7), (1, 0, 0), (8.4, 4.2))
    # Three small hanging signs under the porch beam with icon shapes: T-shirt, hat, star.
    m.box((W + 1.2, 0.6, 0.6), "WoodDark", (0, -D / 2 - 4.4, 7.6))
    for x in (-W / 2 - 0.1, W / 2 + 0.1):
        m.box((0.6, 0.6, 7.0), "WoodDark", (x, -D / 2 - 4.4, 0.6))
    for k, x in enumerate((-7.0, 0.5, 7.5)):
        m.box((0.12, 0.12, 1.0), "Rope", (x - 1.0, -D / 2 - 4.4, 6.6))
        m.box((0.12, 0.12, 1.0), "Rope", (x + 1.0, -D / 2 - 4.4, 6.6))
        m.box((3.2, 0.3, 2.6), "WoodLight", (x, -D / 2 - 4.4, 4.0))
        iy = -D / 2 - 4.65
        if k == 0:  # flat blocky T-shirt
            m.box((1.2, 0.2, 1.3), "Red", (x, iy, 4.6))
            m.box((2.2, 0.2, 0.55), "Red", (x, iy, 5.6))
        elif k == 1:  # blocky fedora
            m.box((2.4, 0.2, 0.3), "Navy", (x, iy, 4.9))
            m.box((1.4, 0.2, 0.9), "Navy", (x, iy, 5.2))
            m.box((1.45, 0.25, 0.25), "Red", (x, iy, 5.25))
        else:  # star for skins & emotes
            pts = []
            for p in range(10):
                a = math.radians(90 + p * 36)
                r = 1.05 if p % 2 == 0 else 0.45
                pts.append((math.cos(a) * r, math.sin(a) * r))
            m.prism(pts, 0.2, "Gold", (x, iy, 5.3))
    place("AvatarShop", m.finish("AvatarShop"), "Shop_Structure", loc, (0, 0, yaw))
    record("AvatarShop", ["AvatarShop"], "Shop_Structure", "Hull", loc, yaw)
    prompt("AvatarShop", "Shop", world, (door_x, -D / 2 - 3.5, 3.0), "Open Shop", "Avatar Shop")
    # Two flower boxes under the side windows.
    for sx in (-1, 1):
        fb = Mesh()
        fb.box((1.2, 5.0, 1.0), "WoodDark", (0, 0, 0))
        for k in range(5):
            fb.ico(0.45, "Leaf", (0, -2.0 + k, 1.2))
            fb.ico(0.32, ["Red", "Yellow", "Pink", "Purple"][k % 4], (sx * 0.2, -2.0 + k, 1.6))
        name = f"Shop_FlowerBox_{1 if sx < 0 else 2}"
        floc = tuple(world @ Vector((sx * (W / 2 + 1.2), 0, 2.3)))
        place(name, fb.finish(name), "Shop_Structure", floc, (0, 0, yaw))
        record(name, [name], "Shop_Structure", "None", floc, yaw)


def build_lighthouse():
    loc, yaw = (24, 52, GRASS_Z), 200
    world = transform(loc, (0, 0, yaw))
    m = Mesh()
    m.ico(11, ["Rock", "RockDark", "RockLight"], (0, 0, -1.5), (1.2, 1.2, 0.45), jitter=0.12)
    base_z = 3.0
    m.cyl(7.4, 1.0, "StoneDark", (0, 0, base_z - 1.0), sides=16)
    z = base_z
    bands = 8
    for i in range(bands):
        r0 = 6.4 - i * 0.26
        m.cyl(r0, 4.6, "Red" if i % 2 == 0 else "White", (0, 0, z), sides=16, r_top=r0 - 0.26)
        z += 4.6
    m.box((2.4, 1.2, 4.2), "WoodDark", (0, -6.2, base_z))
    m.box((3.2, 1.0, 0.5), "White", (0, -6.3, base_z + 4.2))
    for k, wz in enumerate((14.0, 24.0)):
        m.box((1.2, 1.0, 1.8), "Black", (0, -(6.4 - (wz / 4.6) * 0.26) + 0.1, base_z + wz))
    top_z = z
    m.cyl(6.4, 0.9, "Black", (0, 0, top_z), sides=16)
    for i in range(16):
        a = math.radians(i * 22.5)
        m.box((0.22, 0.22, 2.0), "Black", (math.cos(a) * 6.0, math.sin(a) * 6.0, top_z + 0.9))
    m.cyl(6.1, 0.3, "Black", (0, 0, top_z + 2.8), sides=16)
    m.cyl(3.9, 0.6, "Black", (0, 0, top_z + 0.9), sides=8)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        m.box((0.4, 0.4, 5.0), "Black", (math.cos(a) * 3.6, math.sin(a) * 3.6, top_z + 1.5))
    m.cyl(4.5, 4.0, "Red", (0, 0, top_z + 6.4), sides=8, r_top=0.6)
    m.ico(0.7, "Black", (0, 0, top_z + 10.7))
    m.cyl(0.18, 2.0, "Black", (0, 0, top_z + 11.2), sides=4)
    # Keeper's hut against the tower.
    hx, hy = 7.0, -3.5
    m.box((7.5, 7.0, 6.0), "White", (hx + 2.0, hy, base_z - 0.6))
    m.prism([(-4.2, 0), (4.2, 0), (0, 3.2)], 8.4, "Red", (hx + 2.0, hy, base_z + 5.4), (0, 0, 90))
    m.box((1.8, 0.4, 3.4), "WoodDark", (hx + 2.0, hy - 3.6, base_z - 0.6))
    m.box((1.6, 0.4, 1.6), "Glass", (hx + 4.6, hy - 3.55, base_z + 1.4))
    place("Lighthouse_Tower", m.finish("Lighthouse_Tower"), "Lighthouse", loc, (0, 0, yaw))
    lantern = Mesh()
    lantern.cyl(3.4, 4.6, "Lamp", (0, 0, top_z + 1.5), sides=8)
    glow("Lighthouse_Lantern_Glow", lantern, "Lighthouse", "Lamp", loc, (0, 0, yaw))
    record("Lighthouse", ["Lighthouse_Tower", "Lighthouse_Lantern_Glow"], "Lighthouse", "Hull", loc, yaw)
    # Sign post nearby.
    sloc, syaw = (8, 36, GRASS_Z), -15
    sworld = transform(sloc, (0, 0, syaw))
    s = Mesh()
    s.box((0.7, 0.7, 6.5), "WoodDark", (-3.2, 0, 0))
    s.box((0.7, 0.7, 6.5), "WoodDark", (3.2, 0, 0))
    s.box((8.0, 0.45, 2.8), "WoodLight", (0, -0.4, 3.4))
    place("Lighthouse_Sign", s.finish("Lighthouse_Sign"), "Lighthouse", sloc, (0, 0, syaw))
    record("Lighthouse_Sign", ["Lighthouse_Sign"], "Lighthouse", "Box", sloc, syaw)
    panel("Lighthouse_Sign", "SignText", "Wood", ["TAG ISLAND", "LIGHTHOUSE"], sworld, (0, -0.7, 4.8), (0, -1, 0), (7.6, 2.5))


def build_gamepass_board():
    loc, yaw = (2, -60, GRASS_Z), 0
    world = transform(loc, (0, 0, yaw))
    m = Mesh()
    for x in (-15.0, 15.0):
        m.box((2.8, 2.8, 1.0), "Stone", (x, 0, 0))
        m.box((2.2, 2.2, 17.0), "Wood", (x, 0, 1.0))
        m.cyl(1.4, 0.8, "WoodDark", (x, 0, 18.0), sides=4, rot=(0, 0, 45), r_top=0.3)
    m.box((28.0, 1.2, 12.5), "WoodDark", (0, 0.2, 3.5))
    m.box((27.0, 0.8, 11.5), "WoodLight", (0, -0.1, 4.0))
    m.box((30.0, 1.6, 3.4), "Navy", (0, -0.2, 15.0))
    m.box((30.6, 1.8, 0.5), "Gold", (0, -0.2, 14.8))
    m.box((30.6, 1.8, 0.5), "Gold", (0, -0.2, 18.2))
    plates = [("VIP Pass", -8.6, "Purple"), ("Speed Trail", 0.0, "NavyLight"), ("Coin Boosters", 8.6, "Green")]
    for i, (title, x, key) in enumerate(plates):
        m.box((8.0, 0.5, 9.6), "WoodDark", (x, -0.65, 4.7))
        m.box((7.4, 0.5, 9.0), key, (x, -0.85, 5.0))
        m.box((7.0, 0.3, 2.0), "Navy", (x, -1.15, 5.4))
        iz = 10.2
        iy = -1.4
        if i == 0:  # golden crown
            m.box((4.4, 0.6, 1.4), "Gold", (x, iy, iz))
            for k in range(5):
                cx = x - 1.8 + k * 0.9
                m.cyl(0.55, 2.0 if k % 2 == 0 else 1.4, "Gold", (cx, iy, iz + 1.4), rot=(0, 0, 45), sides=4, r_top=0.05)
            for k, key2 in enumerate(("Red", "Blue", "Green")):
                m.ico(0.32, key2, (x - 1.2 + k * 1.2, iy - 0.4, iz + 0.7))
        elif i == 2:  # three overlapping gold coins
            for k, (cx, cz) in enumerate(((-1.4, 0.4), (1.2, 0.8), (-0.1, 2.0))):
                m.cyl(1.35, 0.45, "Gold" if k != 1 else "GoldDark", (x + cx, iy - k * 0.12, iz + cz), rot=(90, 0, 0), sides=12, base=False)
                m.cyl(0.85, 0.55, "Yellow", (x + cx, iy - k * 0.12 - 0.05, iz + cz), rot=(90, 0, 0), sides=12, base=False)
        else:  # speed trail: a shoe-like block (ribbons are glow)
            m.box((1.6, 0.6, 1.1), "White", (x + 1.6, iy, iz + 0.6))
            m.box((0.9, 0.6, 0.9), "White", (x + 1.25, iy, iz + 1.7))
        panel("GamepassBoard", f"Label{i + 1}", "Label", [title], world, (x, -1.45, 6.4), (0, -1, 0), (6.8, 1.8))
    place("GamepassBoard", m.finish("GamepassBoard"), "UI_Assets", loc, (0, 0, yaw))
    ribbons = Mesh()
    for k, (cx, cz, length) in enumerate(((-1.0, 12.6, 4.6), (-1.6, 11.4, 5.4), (-1.0, 10.2, 4.6))):
        ribbons.box((length, 0.25, 0.5), "Neon", (cx, -1.5, cz), (0, 6 - k * 6, 0), base=False)
    glow("GamepassBoard_Trail_Glow", ribbons, "UI_Assets", "Neon", loc, (0, 0, yaw))
    record("GamepassBoard", ["GamepassBoard", "GamepassBoard_Trail_Glow"], "UI_Assets", "Box", loc, yaw)
    panel("GamepassBoard", "Title", "Banner", ["GAMEPASSES & BOOSTS"], world, (0, -1.05, 16.6), (0, -1, 0), (28.6, 2.8))


# =================================================================================================
# Markers, spawn, previews, export
# =================================================================================================
def build_markers():
    for name, pos in (("Marker_O", (0, 0, 0)), ("Marker_X", (100, 0, 0)), ("Marker_Y", (0, 100, 0)), ("Marker_Z", (0, 0, 100))):
        m = Mesh()
        m.box((0.6, 0.6, 0.6), "Red", (0, 0, 0), base=False)
        place(name, m.finish(name), "Markers", pos)


def lua_vec(v):
    return "v(" + ", ".join(f"{c:.3f}" for c in v) + ")"


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_data():
    lines = [
        "--!strict",
        "-- GENERATED by tools/blender/make_lobby.py. Don't edit by hand: change the script and run it again.",
        "-- Positions and directions are in Blender coordinates (studs, Z up, island front toward -Y);",
        "-- tools/SetupLobby converts them to Roblox. Used once, when setting up an imported lobby.",
        "local function v(x: number, y: number, z: number): { number }",
        "\treturn { x, y, z }",
        "end",
        "",
        "local LobbyData = {}",
        "",
        "-- Every lobby object: its mesh parts, Studio folder, collision, and pivot (base point and yaw).",
        "LobbyData.Objects = {",
    ]
    for o in OBJECTS:
        parts = ", ".join(lua_str(p) for p in o["Parts"])
        lines.append(f"\t{{ Name = {lua_str(o['Name'])}, Parts = {{ {parts} }}, Category = {lua_str(o['Category'])}, "
                     f"Collision = {lua_str(o['Collision'])}, Pivot = {lua_vec(o['Pivot'])}, Yaw = {o['Yaw']:.2f} }},")
    lines.append("}")
    lines.append("")
    lines.append("-- Glowing parts (made Neon): color (0-1) and transparency.")
    lines.append("LobbyData.Glow = {")
    for name, (rgb, transparency) in GLOW.items():
        lines.append(f"\t[{lua_str(name)}] = {{ Color = {lua_vec(rgb)}, Transparency = {transparency:.2f} }},")
    lines.append("}")
    lines.append("")
    lines.append("-- Sign text panels: owner object, kind (the setup tool's text style), lines, and where they sit.")
    lines.append("LobbyData.Panels = {")
    for p in PANELS:
        text_lines = ", ".join(lua_str(t) for t in p["Lines"])
        lines.append(f"\t{{ Owner = {lua_str(p['Owner'])}, Name = {lua_str(p['Name'])}, Kind = {lua_str(p['Kind'])}, Lines = {{ {text_lines} }},")
        lines.append(f"\t\tCenter = {lua_vec(p['Center'])}, Normal = {lua_vec(p['Normal'])}, Up = {lua_vec(p['Up'])}, Size = {{ {p['Size'][0]:.2f}, {p['Size'][1]:.2f} }} }},")
    lines.append("}")
    lines.append("")
    lines.append("-- Bench and chair seats (Roblox Seat parts): position and the way a sitter faces.")
    lines.append("LobbyData.Seats = {")
    for s in POINTS["Seats"]:
        lines.append(f"\t{{ Owner = {lua_str(s['Owner'])}, Position = {lua_vec(s['Position'])}, Forward = {lua_vec(s['Forward'])} }},")
    lines.append("}")
    lines.append("")
    lines.append("-- ProximityPrompts: the shop and the reward wheel.")
    lines.append("LobbyData.Prompts = {")
    for p in POINTS["Prompts"]:
        lines.append(f"\t{{ Owner = {lua_str(p['Owner'])}, Kind = {lua_str(p['Kind'])}, Position = {lua_vec(p['Position'])}, "
                     f"Action = {lua_str(p['Action'])}, ObjectText = {lua_str(p['ObjectText'])} }},")
    lines.append("}")
    lines.append("")
    lines.append("-- Invisible trunk colliders for palms (the trees themselves don't collide).")
    lines.append("LobbyData.Colliders = {")
    for c in POINTS["Colliders"]:
        lines.append(f"\t{{ Owner = {lua_str(c['Owner'])}, Position = {lua_vec(c['Position'])}, Radius = {c['Radius']:.2f}, Height = {c['Height']:.2f} }},")
    lines.append("}")
    lines.append("")
    w = POINTS["Wheel"]
    lines.append("-- The reward wheel: the part that spins, its center and axis (pointing out of its front).")
    lines.append(f"LobbyData.Wheel = {{ Owner = {lua_str(w['Owner'])}, Part = {lua_str(w['Part'])}, Center = {lua_vec(w['Center'])}, "
                 f"Axis = {lua_vec(w['Axis'])}, Segments = {w['Segments']} }}")
    sp = POINTS["Spawn"]
    lines.append("")
    lines.append("-- Where players appear in the lobby, and the way they face.")
    lines.append(f"LobbyData.Spawn = {{ Position = {lua_vec(sp['Position'])}, Forward = {lua_vec(sp['Forward'])} }}")
    lines.append("")
    lines.append("-- Marker cubes in the import, in Blender coordinates (the setup tool fixes scale and rotation with them).")
    lines.append("LobbyData.Markers = { Marker_O = v(0, 0, 0), Marker_X = v(100, 0, 0), Marker_Y = v(0, 100, 0), Marker_Z = v(0, 0, 100) }")
    lines.append("")
    lines.append(f"-- Invisible walls in a ring this far from the island's center keep players from swimming away.")
    lines.append(f"LobbyData.BoundaryRadius = {max(ISLAND_RX, ISLAND_RY) * 1.45:.1f}")
    lines.append("")
    lines.append("return LobbyData")
    if os.path.isdir(os.path.dirname(REPO_DATA)):
        with open(REPO_DATA, "w") as f:
            f.write("\n".join(lines) + "\n")
        print("wrote", REPO_DATA)
    else:
        path = os.path.join(OUT_DIR, "LobbyData.luau")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        print("wrote", path)


def build_preview_text():
    """3D text for the sign panels, only for previews (not exported: Roblox text is made by the setup tool)."""
    styles = {
        "Welcome": [("White", 0.32), ("Orange", 0.55)],
        "Wood": [("WoodDark", 0.42), ("WoodDark", 0.42)],
        "Banner": [("Yellow", 0.5), ("White", 0.38)],
        "Skins": [("Yellow", 0.42), ("White", 0.42)],
        "Label": [("White", 0.6)],
        "BoardHeader": [("Navy", 0.4), ("Red", 0.36)],
    }
    for p in PANELS:
        if p["Kind"] == "Leaderboard":
            rows = ["#1  TagMaster99  1,240", "#2  SpeedySlide  1,105", "#3  WallRunner  987", "#4  NotIt_Ever  860", "#5  BlockyBolt  742"]
            content = [(r, "White", 0.11) for r in rows]
        else:
            style = styles.get(p["Kind"], [("White", 0.4)])
            content = [(line, style[min(i, len(style) - 1)][0], style[min(i, len(style) - 1)][1]) for i, line in enumerate(p["Lines"])]
        n = len(content)
        width, height = p["Size"]
        normal, up = Vector(p["Normal"]), Vector(p["Up"])
        right = up.cross(normal).normalized()
        for i, (line, key, share) in enumerate(content):
            size = height * share if n <= 2 else height * share
            offset = ((n - 1) / 2 - i) * (height / max(n, 1))
            curve = bpy.data.curves.new(f"Preview_{p['Owner']}_{p['Name']}_{i}", "FONT")
            curve.body = line
            curve.size = size
            curve.extrude = 0.08
            curve.align_x = "CENTER"
            curve.align_y = "CENTER"
            obj = bpy.data.objects.new(curve.name, curve)
            collection("PreviewOnly").objects.link(obj)
            # Text faces +Z with its up along +Y: build a basis from (right, up, normal).
            basis = Matrix((right, up, normal)).transposed().to_4x4()
            obj.matrix_world = Matrix.Translation(Vector(p["Center"]) + normal * 0.12 + up * offset) @ basis
            mat = bpy.data.materials.new(f"PreviewText_{key}")
            mat.use_nodes = False
            mat.diffuse_color = (*PAL_COLOR[key], 1)
            curve.materials.append(mat)
            # Shrink lines that are too wide for the panel.
            bpy.context.view_layer.update()
            dims = obj.dimensions
            if dims.x > width:
                obj.scale = (width / dims.x,) * 3


def render_previews():
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    engine_set = False
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            engine_set = True
            break
        except TypeError:
            continue
    if not engine_set:
        scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.42, 0.68, 0.95, 1)
    bg.inputs["Strength"].default_value = 1.2
    scene.world = world
    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.6
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("Sun", sun_data)
    sun.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(-35)))
    collection("PreviewOnly").objects.link(sun)
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam_data.lens = 35
    cam_data.clip_end = 5000
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    collection("PreviewOnly").objects.link(cam)
    scene.camera = cam
    shots = {
        "hero": ((0, -205, 112), (0, 4, 6)),
        "left": ((-190, -150, 90), (-10, 0, 6)),
        "right": ((185, -140, 85), (15, 5, 6)),
        "plaza": ((-6, -112, 30), (0, -10, 12)),
        "shop": ((15, -55, 22), (55, 5, 10)),
    }
    for name, (eye, target) in shots.items():
        cam.location = eye
        cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, f"lobby_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath)


def export():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "UltimateTagLobby.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        in_preview = any(c.name == "PreviewOnly" for c in obj.users_collection)
        if obj.type == "MESH" and not in_preview:
            obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "UltimateTagLobby.fbx"),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )
    print("exported", os.path.join(OUT_DIR, "UltimateTagLobby.fbx"))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)  # no default cube, camera or light
    os.makedirs(OUT_DIR, exist_ok=True)
    img = make_palette_image()
    make_materials(img)
    build_ocean()
    build_seabed()
    build_island()
    build_distant_islands()
    build_ground_details()
    build_hedges()
    build_rocks()
    build_palms()
    build_bushes()
    build_benches(bench_mesh())
    build_crates()
    build_lampposts()
    build_docks()
    build_gazebo()
    build_firepit_lounge()
    build_leaderboard()
    build_reward_wheel()
    build_shop()
    build_lighthouse()
    build_gamepass_board()
    build_markers()
    POINTS["Spawn"] = {"Position": (12, -42, GRASS_Z), "Forward": (0, 1, 0)}
    write_data()
    if PREVIEW_DIR:
        build_preview_text()
        render_previews()
    export()
    meshes = sum(1 for o in bpy.data.objects if o.type == "MESH" and not any(c.name in ("PreviewOnly", "Markers") for c in o.users_collection))
    print(f"LOBBY done: {len(OBJECTS)} objects, {meshes} mesh parts, {len(PANELS)} text panels")


main()
