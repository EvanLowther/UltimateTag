# Builds the Ultimate Tag lobby in Blender: a small low-poly tropical island with a central
# gazebo, beach firepit lounge, leaderboard, daily reward wheel, avatar shop, lighthouse,
# gamepass board, benches, crates, palms and idle blocky characters.
#
# Every piece is its own named object. Multi-part assets (a gazebo, a palm, a character) have a
# named Empty as their root, so you can move the whole thing or any single piece. Origins sit at
# the base of each piece. Units are studs (1 Blender unit = 1 stud), Z up, the island's front
# (where the gamepass board and main path are) faces -Y.
#
# Run (no window):
#   blender --background --python tools/blender/make_lobby.py -- <out_dir> [preview_dir]
# Writes <out_dir>/UltimateTagLobby.blend, <out_dir>/UltimateTagLobby.fbx and preview renders.
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "assets_src/lobby")
PREVIEW_DIR = os.path.abspath(ARGS[1]) if len(ARGS) > 1 else None

random.seed(11)
ISLAND_R = 95  # rough island radius
GRASS_Z = 1.6  # top of the grass, where most things stand

# --- Materials ---------------------------------------------------------------------------------
PALETTE = {
    "Water": (0.12, 0.55, 0.85),
    "Sand": (0.93, 0.83, 0.6),
    "Grass": (0.36, 0.7, 0.28),
    "Gravel": (0.8, 0.72, 0.58),
    "Hedge": (0.2, 0.52, 0.22),
    "Rock": (0.55, 0.55, 0.58),
    "RockDark": (0.42, 0.42, 0.46),
    "Wood": (0.62, 0.42, 0.24),
    "WoodDark": (0.42, 0.27, 0.15),
    "WoodLight": (0.78, 0.6, 0.38),
    "Shingle": (0.55, 0.25, 0.15),
    "RoofBlue": (0.32, 0.4, 0.55),
    "Palm": (0.25, 0.65, 0.25),
    "PalmDark": (0.17, 0.5, 0.2),
    "Trunk": (0.55, 0.4, 0.25),
    "Coconut": (0.35, 0.22, 0.1),
    "Stone": (0.5, 0.5, 0.52),
    "Flame": (1.0, 0.45, 0.05),
    "FlameCore": (1.0, 0.85, 0.2),
    "Iron": (0.2, 0.2, 0.22),
    "Navy": (0.08, 0.12, 0.25),
    "Gold": (0.98, 0.75, 0.15),
    "White": (0.95, 0.95, 0.95),
    "Red": (0.85, 0.15, 0.15),
    "Glass": (0.65, 0.85, 0.95),
    "Lamp": (1.0, 0.9, 0.5),
    "Cyan": (0.2, 0.85, 0.95),
    "Orange": (1.0, 0.55, 0.1),
    "Yellow": (1.0, 0.85, 0.15),
    "Pink": (0.95, 0.45, 0.65),
    "Purple": (0.55, 0.3, 0.8),
    "Green": (0.3, 0.75, 0.3),
    "Blue": (0.2, 0.45, 0.9),
    "Black": (0.05, 0.05, 0.05),
    "Bamboo": (0.8, 0.72, 0.4),
    "Bottle": (0.3, 0.6, 0.35),
}
GLOW = {"Flame", "FlameCore", "Lamp"}
_materials = {}


def mat(key):
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(key)
    color = (*PALETTE[key], 1)
    m.diffuse_color = color
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.85
        if key in GLOW and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = 2.0
    _materials[key] = m
    return m


# --- Building blocks ---------------------------------------------------------------------------
_collections = {}


def collection(name):
    if name not in _collections:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
        _collections[name] = c
    return _collections[name]


CURRENT = ["Island"]  # collection new objects go into


def place(obj, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, scale=None):
    collection(CURRENT[0]).objects.link(obj)
    if parent is not None:
        obj.parent = parent
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    if scale:
        obj.scale = scale
    return obj


def group(name, loc=(0, 0, 0), rot=(0, 0, 0), parent=None):
    """A named Empty that holds the pieces of one asset."""
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 2
    return place(e, loc, rot, parent)


def from_bmesh(name, bm, key, loc, rot, parent):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False  # flat low-poly shading
    me.materials.append(mat(key))
    return place(bpy.data.objects.new(name, me), loc, rot, parent)


def box(name, size, key, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, base=True):
    """A box `size` (x, y, z); with base=True its origin is the middle of its bottom face."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    lift = size[2] / 2 if base else 0
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, lift)) @ Matrix.Diagonal((*size, 1)), verts=bm.verts)
    return from_bmesh(name, bm, key, loc, rot, parent)


def cyl(name, r, h, key, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, sides=8, r_top=None):
    """A cylinder (or cone, with r_top) standing on its base."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=r,
                          radius2=r if r_top is None else r_top, depth=h)
    bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    return from_bmesh(name, bm, key, loc, rot, parent)


def rock(name, r, key, loc=(0, 0, 0), parent=None, squash=(1, 1, 0.7), jitter=0.25):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    for v in bm.verts:
        v.co.x *= squash[0] * (1 + random.uniform(-jitter, jitter))
        v.co.y *= squash[1] * (1 + random.uniform(-jitter, jitter))
        v.co.z *= squash[2] * (1 + random.uniform(-jitter, jitter))
    return from_bmesh(name, bm, key, loc, (0, 0, random.uniform(0, 360)), parent)


def ball(name, r, key, loc=(0, 0, 0), parent=None, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return from_bmesh(name, bm, key, loc, (0, 0, 0), parent)


def text(name, body, size, key, loc=(0, 0, 0), rot=(90, 0, 0), parent=None, depth=0.15):
    """3D text, standing up and facing -Y by default, converted to a mesh."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = depth
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = place(bpy.data.objects.new(name, curve), loc, rot, parent)
    obj.data.materials.append(mat(key))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


def face_toward(obj, target):
    """Turns an asset root so its front (-Y) points at `target` (x, y)."""
    dx, dy = target[0] - obj.location.x, target[1] - obj.location.y
    obj.rotation_euler.z = math.atan2(dx, -dy)


def sign_board(name, lines, loc, parent=None, width=10, height=3, board="WoodLight", ink="WoodDark",
               post_height=5, rot=(0, 0, 0), text_size=0.9):
    """A board on one post (or two if wide) with lines of text on its front."""
    g = group(name, loc, rot, parent)
    posts = [0] if width <= 8 else [-width / 2 + 0.6, width / 2 - 0.6]
    for i, x in enumerate(posts):
        box(f"{name}_Post{i + 1}", (0.5, 0.5, post_height), "WoodDark", (x, 0, 0), parent=g)
    box(f"{name}_Board", (width, 0.4, height), board, (0, 0, post_height - 0.3), parent=g)
    n = len(lines)
    for i, line in enumerate(lines):
        z = post_height - 0.3 + height / 2 + (n / 2 - i - 0.5) * text_size * 1.25
        text(f"{name}_Text{i + 1}", line, text_size, ink, (0, -0.3, z), parent=g)
    return g


# --- Island ------------------------------------------------------------------------------------
def island_radius(theta):
    return ISLAND_R * (1 + 0.1 * math.sin(3 * theta + 1) + 0.07 * math.sin(5 * theta + 2.3) + 0.04 * math.sin(9 * theta))


def slab(name, key, scale, z_top, z_bottom, taper, sides=48):
    bm = bmesh.new()
    top, bottom = [], []
    for i in range(sides):
        t = 2 * math.pi * i / sides
        r = island_radius(t) * scale
        top.append(bm.verts.new((math.cos(t) * r, math.sin(t) * r, z_top)))
        bottom.append(bm.verts.new((math.cos(t) * r * taper, math.sin(t) * r * taper, z_bottom)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bmesh(name, bm, key, (0, 0, 0), (0, 0, 0), None)


def build_island():
    CURRENT[0] = "Island"
    water = bpy.data.meshes.new("Ocean")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=12, y_segments=12, size=600)
    for v in bm.verts:
        v.co.z = random.uniform(-0.4, 0.4)
    from_bmesh("Ocean", bm, "Water", (0, 0, 0), (0, 0, 0), None)
    slab("IslandSand", "Sand", 1.0, 1.0, -8, 0.85)
    slab("IslandGrass", "Grass", 0.8, GRASS_Z, 0.5, 0.97)


def path_segment(name, a, b, width, parent):
    a, b = Vector((*a, 0)), Vector((*b, 0))
    mid = (a + b) / 2
    length = (b - a).length
    yaw = math.degrees(math.atan2(b.y - a.y, b.x - a.x))
    box(name, (length, width, 0.25), "Gravel", (mid.x, mid.y, GRASS_Z - 0.05), (0, 0, yaw), parent)
    cyl(f"{name}_Joint", width / 2, 0.25, "Gravel", (b.x, b.y, GRASS_Z - 0.05), parent=parent, sides=10)


PATHS = {
    "Main": [(0, -96), (0, -70), (4, -40), (2, -14)],
    "Firepit": [(-8, 2), (-30, 0), (-44, 2)],
    "Shop": [(10, 0), (30, 2), (44, 2)],
    "Lighthouse": [(6, 14), (16, 32), (24, 46)],
    "DockWest": [(-6, -40), (-35, -55), (-60, -66)],
    "DockNorth": [(-10, 16), (-40, 45), (-58, 64)],
}


def build_paths():
    CURRENT[0] = "Paths"
    g = group("Paths")
    for name, pts in PATHS.items():
        for i in range(len(pts) - 1):
            path_segment(f"Path{name}_{i + 1}", pts[i], pts[i + 1], 7, g)


def build_hedges_and_rocks():
    CURRENT[0] = "Island"
    hedges = group("Hedgerows")
    gaps = [(-95, -80), (205, 235), (115, 145)]  # front entrance and the two docks (degrees)
    count = 0
    for deg in range(0, 360, 9):
        if any(lo <= deg <= hi or lo <= deg - 360 <= hi for lo, hi in gaps):
            continue
        t = math.radians(deg)
        r = island_radius(t) * 0.8
        count += 1
        length = r * math.radians(9) + 1.5  # long enough to meet the next segment
        box(f"Hedge{count}", (length, 3, 4), "Hedge", (math.cos(t) * r, math.sin(t) * r, GRASS_Z - 0.2),
            (0, 0, deg + 90), hedges)
    rocks = group("RockClusters")
    for c in range(9):
        t = math.radians(c * 40 + random.uniform(-10, 10))
        r = island_radius(t) * random.uniform(0.9, 1.0)
        cluster = group(f"RockCluster{c + 1}", (math.cos(t) * r, math.sin(t) * r, 0.5), parent=rocks)
        for k in range(random.randint(2, 4)):
            size = random.uniform(2.5, 5.5)
            rock(f"RockCluster{c + 1}_Rock{k + 1}", size, random.choice(["Rock", "RockDark"]),
                 (random.uniform(-4, 4), random.uniform(-4, 4), size * 0.3), cluster)


def build_dock(name, deg):
    CURRENT[0] = "Docks"
    t = math.radians(deg)
    r = island_radius(t) * 0.86
    g = group(name, (math.cos(t) * r, math.sin(t) * r, 0), (0, 0, deg - 90))
    # Local +Y points out to sea.
    for i in range(14):
        box(f"{name}_Plank{i + 1}", (7, 1.5, 0.35), random.choice(["Wood", "WoodLight"]), (0, i * 1.7, 1.6), parent=g)
    for i in range(5):
        for x in (-3.3, 3.3):
            cyl(f"{name}_Support{i + 1}{'L' if x < 0 else 'R'}", 0.35, 5.6, "WoodDark", (x, i * 5.6, -4), parent=g, sides=6)
    for x in (-3.3, 3.3):
        cyl(f"{name}_MooringPost{'L' if x < 0 else 'R'}", 0.5, 8, "WoodDark", (x, 23.5, -4), parent=g, sides=6)
        cyl(f"{name}_MooringRope{'L' if x < 0 else 'R'}", 0.7, 0.5, "WoodLight", (x, 23.5, 2.6), parent=g, sides=8)
    return g


def palm(name, loc, lean_deg, height_segments=6):
    CURRENT[0] = "Palms"
    g = group(name, loc)
    direction = Vector((0, 0, 1))
    point = Vector((0, 0, 0))
    lean_axis = Vector((math.cos(math.radians(lean_deg)), math.sin(math.radians(lean_deg)), 0)).cross(Vector((0, 0, 1)))
    for i in range(height_segments):
        r = 0.9 - i * 0.07
        seg = cyl(f"{name}_Trunk{i + 1}", r, 3.4, "Trunk", tuple(point), parent=g, sides=6, r_top=r - 0.07)
        seg.rotation_euler = Vector((0, 0, 1)).rotation_difference(direction).to_euler()
        point = point + direction * 3.2
        direction = (Matrix.Rotation(math.radians(-6 - i * 1.5), 3, lean_axis) @ direction).normalized()
    top = point
    for k in range(3):
        a = math.radians(k * 120)
        ball(f"{name}_Coconut{k + 1}", 0.55, "Coconut", tuple(top + Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, -0.4))), g)
    for f in range(7):
        frond = bpy.data.meshes.new(f"{name}_Frond{f + 1}")
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 4.2, 0)) @ Matrix.Diagonal((2.2, 8.4, 0.3, 1)), verts=bm.verts)
        # Droop: bend the far half of the leaf down.
        for v in bm.verts:
            if v.co.y > 4:
                v.co.z -= (v.co.y - 4) * 0.35
            if v.co.y > 7:
                v.co.x *= 0.5
        yaw = f * 360 / 7 + random.uniform(-8, 8)
        from_bmesh(f"{name}_Frond{f + 1}", bm, random.choice(["Palm", "PalmDark"]), tuple(top + Vector((0, 0, 0.3))),
                   (random.uniform(8, 22), 0, yaw), g)
    return g


def lamppost(name, loc, parent):
    g = group(name, loc, parent=parent)
    cyl(f"{name}_Base", 0.7, 0.8, "Iron", parent=g, sides=8)
    cyl(f"{name}_Pole", 0.22, 9, "Iron", (0, 0, 0.8), parent=g, sides=6)
    box(f"{name}_Arm", (1.8, 0.25, 0.25), "Iron", (0.7, 0, 9.4), parent=g)
    box(f"{name}_Lantern", (1.1, 1.1, 1.4), "Lamp", (1.5, 0, 8.4), parent=g)
    cyl(f"{name}_Cap", 0.9, 0.5, "Iron", (1.5, 0, 9.8), parent=g, sides=4, r_top=0.1)
    return g


def flower_box(name, loc, yaw, parent):
    g = group(name, loc, (0, 0, yaw), parent)
    box(f"{name}_Planter", (4, 1.4, 1.2), "WoodDark", parent=g)
    box(f"{name}_Soil", (3.7, 1.1, 0.2), "Coconut", (0, 0, 1.1), parent=g)
    for i in range(5):
        x = -1.6 + i * 0.8
        ball(f"{name}_Leaves{i + 1}", 0.5, "Hedge", (x, 0, 1.5), g)
        ball(f"{name}_Flower{i + 1}", 0.35, random.choice(["Red", "Yellow", "Pink", "Purple"]), (x, -0.1, 1.95), g)
    return g


# --- Props ---------------------------------------------------------------------------------------
def bench(name, loc, yaw, parent):
    g = group(name, loc, (0, 0, yaw), parent)
    for i in range(3):
        box(f"{name}_Seat{i + 1}", (5, 0.5, 0.25), "Wood", (0, -0.6 + i * 0.6, 1.6), parent=g)
    for i in range(2):
        box(f"{name}_Back{i + 1}", (5, 0.25, 0.45), "Wood", (0, 0.75, 2.3 + i * 0.6), parent=g)
    for x in (-2.1, 2.1):
        box(f"{name}_Leg{'L' if x < 0 else 'R'}", (0.3, 1.6, 1.6), "Iron", (x, 0, 0), parent=g)
        box(f"{name}_BackPost{'L' if x < 0 else 'R'}", (0.3, 0.3, 1.6), "Iron", (x, 0.75, 1.6), parent=g)
    return g


def crate_stack(name, loc, layout, parent):
    g = group(name, loc, (0, 0, random.uniform(0, 40)), parent)
    for i, (x, y, z) in enumerate(layout):
        c = group(f"{name}_Crate{i + 1}", (x * 3.1, y * 3.1, z * 3), (0, 0, random.uniform(-8, 8)), g)
        box(f"{name}_Crate{i + 1}_Body", (3, 3, 3), "Wood", parent=c)
        for side, (sx, sy) in enumerate(((0, -1.52), (0, 1.52))):
            box(f"{name}_Crate{i + 1}_Plank{side + 1}", (3.1, 0.12, 0.5), "WoodDark", (sx, sy, 1.25), parent=c)
            box(f"{name}_Crate{i + 1}_Brace{side + 1}", (0.4, 0.12, 3.6), "WoodDark", (sx, sy, 0.0), (0, 45, 0), c)
    return g


SKINS = ["Yellow", "WoodLight", "Sand", "Coconut"]
SHIRTS = ["Blue", "Red", "Green", "White", "Purple", "Orange", "Navy", "Cyan"]
PANTS = ["Navy", "Black", "WoodDark", "Blue", "Iron"]


def character(name, loc, yaw, pose, parent):
    """A blocky Roblox-style avatar. Origin at the feet. Poses: stand, wave, sit, look."""
    g = group(name, loc, (0, 0, yaw), parent)
    skin, shirt, pants = random.choice(SKINS), random.choice(SHIRTS), random.choice(PANTS)
    sit = pose == "sit"
    hip = 1.4 if sit else 2  # sitting: on a seat about 1.6 high
    for side, x in (("L", -0.5), ("R", 0.5)):
        leg = group(f"{name}_Leg{side}", (x, 0, hip), (90 if sit else 0, 0, 0), g)
        box(f"{name}_Leg{side}_Mesh", (1, 1, 2), pants, (0, 0, -2), parent=leg)
    box(f"{name}_Torso", (2, 1, 2), shirt, (0, 0, hip), parent=g)
    for side, x in (("L", -1.5), ("R", 1.5)):
        raise_arm = pose == "wave" and side == "R"
        arm = group(f"{name}_Arm{side}", (x, 0, hip + 2), (0, -150 if raise_arm else 0, 0), g)
        box(f"{name}_Arm{side}_Mesh", (1, 1, 2), skin if raise_arm else shirt, (0, 0, -2), parent=arm)
    head = group(f"{name}_Head", (0, 0, hip + 2), (0, 0, 35 if pose == "look" else 0), g)
    box(f"{name}_Head_Mesh", (1.2, 1.2, 1.2), skin, parent=head)
    for x in (-0.25, 0.25):
        box(f"{name}_Eye{'L' if x < 0 else 'R'}", (0.15, 0.05, 0.25), "Black", (x, -0.61, 0.65), parent=head)
    box(f"{name}_Smile", (0.45, 0.05, 0.08), "Black", (0, -0.61, 0.32), parent=head)
    return g


# --- Landmarks ---------------------------------------------------------------------------------
def build_gazebo():
    CURRENT[0] = "Gazebo"
    g = group("Gazebo", (0, 8, GRASS_Z))
    cyl("Gazebo_Floor", 13, 1.2, "WoodLight", parent=g, sides=8)
    box("Gazebo_Steps", (7, 3, 0.6), "Wood", (0, -13.5, 0), (0, 0, 0), g)
    for i in range(8):
        a = math.radians(22.5 + i * 45)
        x, y = math.cos(a) * 12, math.sin(a) * 12
        cyl(f"Gazebo_Post{i + 1}", 0.55, 10, "Wood", (x, y, 1.2), parent=g, sides=6)
        # Railings between posts, except the front opening (facing -Y).
        b = math.radians(22.5 + (i + 1) * 45)
        mid = math.radians(22.5 + i * 45 + 22.5)
        if abs(math.degrees(mid) % 360 - 270) < 1:
            continue
        mx, my = math.cos(mid) * 11.1, math.sin(mid) * 11.1
        length = 2 * 12 * math.sin(math.radians(22.5))
        for k, z in enumerate((2.6, 4.2)):
            box(f"Gazebo_Rail{i + 1}_{k + 1}", (length, 0.35, 0.35), "WoodDark", (mx, my, z), (0, 0, math.degrees(mid) + 90), g)
    cyl("Gazebo_RoofLower", 15.5, 4.5, "Shingle", (0, 0, 11), parent=g, sides=8, r_top=7)
    cyl("Gazebo_RoofUpper", 8.5, 4.5, "Shingle", (0, 0, 14.5), parent=g, sides=8, r_top=0.6)
    ball("Gazebo_Finial", 0.8, "Gold", (0, 0, 19.3), g)
    # Welcome sign over the entrance.
    sign = group("Gazebo_WelcomeSign", (0, -14.4, 11.4), parent=g)
    box("Gazebo_WelcomeSign_Board", (17, 0.6, 5.2), "Navy", parent=sign)
    text("Gazebo_WelcomeSign_Line1", "WELCOME TO", 1.2, "Yellow", (0, -0.4, 4.0), parent=sign)
    text("Gazebo_WelcomeSign_Line2", "ULTIMATE TAG", 2.0, "Orange", (0, -0.4, 1.8), parent=sign)
    for i, x in enumerate((-5, 5)):
        bench(f"Gazebo_Bench{i + 1}", (x, 6, 1.2), 0, g)
    pit = group("Gazebo_FirePit", (0, 0, 1.2), parent=g)
    for i in range(8):
        a = math.radians(i * 45)
        box(f"Gazebo_FirePit_Stone{i + 1}", (1.1, 0.9, 0.8), "Stone", (math.cos(a) * 1.8, math.sin(a) * 1.8, 0), (0, 0, i * 45), pit)
    cyl("Gazebo_FirePit_Flame", 0.9, 2.2, "Flame", parent=pit, sides=5, r_top=0)
    cyl("Gazebo_FirePit_FlameCore", 0.5, 1.4, "FlameCore", parent=pit, sides=5, r_top=0)
    return g


def build_firepit_lounge():
    CURRENT[0] = "FirepitLounge"
    g = group("FirepitLounge", (-52, 4, GRASS_Z))
    sign_board("FirepitLounge_Sign", ["BEACH FIREPIT", "LOUNGE"], (12, -10, 0), g, width=9, height=3.4, rot=(0, 0, -20))
    pit = group("FirepitLounge_Firepit", parent=g)
    for i in range(10):
        a = math.radians(i * 36)
        rock(f"FirepitLounge_Firepit_Stone{i + 1}", 1.0, "Stone", (math.cos(a) * 3.2, math.sin(a) * 3.2, 0.5), pit, squash=(1, 1, 0.8))
    for i, (x, y, h) in enumerate(((0, 0, 3.6), (0.8, 0.5, 2.6), (-0.7, -0.4, 2.8))):
        cyl(f"FirepitLounge_Firepit_Flame{i + 1}", 1.0, h, "Flame", (x, y, 0.2), parent=pit, sides=5, r_top=0)
    cyl("FirepitLounge_Firepit_FlameCore", 0.6, 2.0, "FlameCore", (0, 0, 0.2), parent=pit, sides=5, r_top=0)
    logs = group("FirepitLounge_LogPile", (6, 6, 0), parent=g)
    for i, (x, z) in enumerate(((-1.1, 0), (0, 0), (1.1, 0), (-0.55, 0.95), (0.55, 0.95), (0, 1.9))):
        cyl(f"FirepitLounge_Log{i + 1}", 0.55, 4, "Trunk", (x, -2, z + 0.55), (-90, 0, 0), logs, sides=6)
    for i, (x, y, yaw) in enumerate(((-6, 3, 120), (0, 7, 180), (6, -4, 60))):
        bench(f"FirepitLounge_Bench{i + 1}", (x, y, 0), yaw, g)
    for i, (x, y, yaw) in enumerate(((-7, -6, 40), (-3, -8.5, 15))):
        chair = group(f"FirepitLounge_BeachChair{i + 1}", (x, y, 0), (0, 0, yaw), g)
        box(f"FirepitLounge_BeachChair{i + 1}_Seat", (2.4, 3, 0.3), random.choice(["Red", "Blue", "Yellow"]), (0, 0, 1.0), (-8, 0, 0), chair)
        box(f"FirepitLounge_BeachChair{i + 1}_Back", (2.4, 0.3, 3), "White", (0, 1.6, 1.0), (-30, 0, 0), chair)
        for lx in (-1.1, 1.1):
            box(f"FirepitLounge_BeachChair{i + 1}_Leg{'L' if lx < 0 else 'R'}", (0.2, 3.2, 0.2), "WoodLight", (lx, 0, 0.5), (0, 0, 0), chair)
    table = group("FirepitLounge_Table", (2, -9, 0), parent=g)
    cyl("FirepitLounge_Table_Leg", 0.25, 2.4, "WoodDark", parent=table, sides=6)
    cyl("FirepitLounge_Table_Top", 1.8, 0.3, "WoodLight", (0, 0, 2.4), parent=table, sides=10)
    for i, (x, y) in enumerate(((-0.6, 0.3), (0.2, -0.5), (0.7, 0.5))):
        cyl(f"FirepitLounge_Bottle{i + 1}", 0.22, 0.9, "Bottle", (x, y, 2.7), parent=table, sides=6)
        cyl(f"FirepitLounge_Bottle{i + 1}_Neck", 0.09, 0.4, "Bottle", (x, y, 3.6), parent=table, sides=6)
    for i, (x, y) in enumerate(((-0.1, 0.9), (0.9, -0.3))):
        cyl(f"FirepitLounge_Glass{i + 1}", 0.2, 0.45, "Glass", (x, y, 2.7), parent=table, sides=6)
    anchor = group("FirepitLounge_DriftwoodAnchor", (-9, 9, 0), (0, 0, 30), g)
    cyl("FirepitLounge_Driftwood", 0.6, 7, "WoodLight", (0, 0, 0.6), (0, 90, 0), anchor, sides=6)
    cyl("FirepitLounge_Anchor_Shank", 0.3, 5, "Iron", (0, 0, 0.5), (0, 0, 0), anchor, sides=6)
    box("FirepitLounge_Anchor_Stock", (3, 0.4, 0.4), "Iron", (0, 0, 4.5), parent=anchor)
    cyl("FirepitLounge_Anchor_Ring", 0.6, 0.3, "Iron", (0, 0, 5.4), (90, 0, 0), anchor, sides=8)
    for side in (-1, 1):
        box(f"FirepitLounge_Anchor_Arm{'L' if side < 0 else 'R'}", (2.6, 0.35, 0.35), "Iron", (side * 1.0, 0, 0.9), (0, side * -35, 0), anchor)
        cyl(f"FirepitLounge_Anchor_Fluke{'L' if side < 0 else 'R'}", 0.45, 1.0, "Iron", (side * 2.1, 0, 1.6), (0, 0, 0), anchor, sides=4, r_top=0)
    return g


def build_leaderboard():
    CURRENT[0] = "Leaderboard"
    g = group("Leaderboard", (14, -22, GRASS_Z))
    for i, x in enumerate((-8.5, 8.5)):
        box(f"Leaderboard_Post{i + 1}", (0.9, 0.9, 15), "WoodDark", (x, 0.4, 0), parent=g)
    box("Leaderboard_Board", (17, 0.6, 10), "Navy", (0, 0, 2.5), parent=g)
    box("Leaderboard_FrameTop", (18, 0.8, 0.6), "Wood", (0, 0, 12.5), parent=g)
    box("Leaderboard_FrameBottom", (18, 0.8, 0.6), "Wood", (0, 0, 2.2), parent=g)
    box("Leaderboard_Banner", (19, 0.8, 3), "Gold", (0, -0.2, 12.6), parent=g)
    text("Leaderboard_BannerLine1", "GLOBAL LEADERBOARD:", 0.95, "Navy", (0, -0.75, 14.6), parent=g)
    text("Leaderboard_BannerLine2", "TOTAL SURVIVAL WINS", 0.95, "Navy", (0, -0.75, 13.4), parent=g)
    rows = [("1. TagMaster99", "1,240"), ("2. SpeedySlide", "1,105"), ("3. WallRunner", "987"),
            ("4. NotIt_Ever", "860"), ("5. BlockyBolt", "742")]
    for i, (who, score) in enumerate(rows):
        z = 10.6 - i * 1.7
        box(f"Leaderboard_Row{i + 1}", (15.5, 0.2, 1.3), "Blue" if i % 2 == 0 else "Navy", (0, -0.35, z - 0.65), parent=g)
        text(f"Leaderboard_Row{i + 1}_Name", who, 0.8, "White", (-3, -0.55, z), parent=g)
        text(f"Leaderboard_Row{i + 1}_Score", score, 0.8, "Gold", (5.5, -0.55, z), parent=g)
    return g


def build_reward_wheel():
    CURRENT[0] = "RewardWheel"
    g = group("RewardWheel", (36, 22, GRASS_Z))
    box("RewardWheel_Base", (7, 3, 0.8), "WoodDark", parent=g)
    for i, x in enumerate((-2.6, 2.6)):
        cyl(f"RewardWheel_BambooPost{i + 1}", 0.4, 11, "Bamboo", (x, 0.6, 0.8), (0, x * 3, 0), g, sides=6)
        for k in range(3):
            cyl(f"RewardWheel_BambooRing{i + 1}_{k + 1}", 0.48, 0.25, "WoodDark", (x + (k + 1) * 0.12 * (1 if x > 0 else -1) * 0.5, 0.6, 3 + k * 3), parent=g, sides=6)
    wheel = group("RewardWheel_Wheel", (0, 0, 8.5), (0, 12, 0), g)
    colors = ["Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Pink"]
    radius = 4.6
    for i, key in enumerate(colors):
        bm = bmesh.new()
        a0, a1 = math.radians(i * 45), math.radians((i + 1) * 45)
        pts = [(0, 0)] + [(math.cos(a0 + (a1 - a0) * k / 3) * radius, math.sin(a0 + (a1 - a0) * k / 3) * radius) for k in range(4)]
        front = [bm.verts.new((x, -0.3, z)) for x, z in pts]
        back = [bm.verts.new((x, 0.3, z)) for x, z in pts]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for k in range(len(pts)):
            j = (k + 1) % len(pts)
            bm.faces.new((front[k], front[j], back[j], back[k]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        from_bmesh(f"RewardWheel_Segment{i + 1}", bm, key, (0, 0, 0), (0, 0, 0), wheel)
    for k in range(16):  # the rim: a ring of short gold pieces around the segments
        a = math.radians(k * 22.5 + 11.25)
        box(f"RewardWheel_Rim{k + 1}", (2 * (radius + 0.3) * math.sin(math.radians(11.25)) + 0.1, 0.8, 0.5), "Gold",
            (math.cos(a) * (radius + 0.25), 0, math.sin(a) * (radius + 0.25)), (0, -math.degrees(a) + 90, 0), wheel, base=False)
    cyl("RewardWheel_Hub", 0.8, 0.9, "White", (0, -0.45, 0), (90, 0, 0), wheel, sides=8)
    cyl("RewardWheel_Pointer", 0.7, 1.6, "Red", (0, -0.6, 8.5 + radius + 1.7), (180, 0, 0), g, sides=3, r_top=0)
    sign_board("RewardWheel_Sign", ["DAILY", "REWARD WHEEL"], (-6.5, -2, 0), g, width=6, height=2.8, text_size=0.6, post_height=3.5)
    return g


def build_shop():
    CURRENT[0] = "AvatarShop"
    g = group("AvatarShop", (60, 0, GRASS_Z))
    face_toward(g, (0, 0))
    box("AvatarShop_Foundation", (19, 14, 0.8), "Stone", parent=g)
    box("AvatarShop_Walls", (18, 13, 10), "Wood", (0, 0, 0.8), parent=g)
    for i in range(5):
        box(f"AvatarShop_PlankLine{i + 1}", (18.1, 13.1, 0.15), "WoodDark", (0, 0, 2.5 + i * 2), parent=g)
    bm = bmesh.new()
    w, d, h = 10.5, 7.8, 5.5
    v = [bm.verts.new(p) for p in ((-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0), (-w, 0, h), (w, 0, h))]
    for f in ((v[0], v[1], v[5], v[4]), (v[2], v[3], v[4], v[5]), (v[0], v[4], v[3]), (v[1], v[2], v[5]), (v[3], v[2], v[1], v[0])):
        bm.faces.new(f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    from_bmesh("AvatarShop_Roof", bm, "RoofBlue", (0, 0, 10.8), (0, 0, 0), g)
    box("AvatarShop_Door", (3.2, 0.3, 5.8), "WoodDark", (0, -6.6, 0.8), parent=g)
    ball("AvatarShop_DoorKnob", 0.2, "Gold", (1.1, -6.8, 3.6), g)
    for i, x in enumerate((-5.5, 5.5)):
        box(f"AvatarShop_Window{i + 1}_Frame", (4.2, 0.35, 3.6), "WhitE".capitalize() if False else "White", (x, -6.55, 3.2), parent=g)
        box(f"AvatarShop_Window{i + 1}_Glass", (3.6, 0.4, 3.0), "Glass", (x, -6.6, 3.5), parent=g)
        box(f"AvatarShop_Window{i + 1}_Bar", (0.2, 0.45, 3.0), "White", (x, -6.62, 3.5), parent=g)
    for i in range(6):
        box(f"AvatarShop_Awning{i + 1}", (3.3, 2.6, 0.25), "Red" if i % 2 == 0 else "White", (-8.25 + i * 3.3, -7.6, 7.4), (-20, 0, 0), g)
    sign = group("AvatarShop_MainSign", (0, -6.9, 8.2), parent=g)
    box("AvatarShop_MainSign_Board", (13, 0.4, 2.6), "Navy", parent=sign)
    text("AvatarShop_MainSign_Line1", "AVATAR SHOP", 1.0, "Yellow", (0, -0.3, 1.75), parent=sign)
    text("AvatarShop_MainSign_Line2", "/ CUSTOMIZE", 0.7, "White", (0, -0.3, 0.7), parent=sign)
    # Window icons: a T-shirt and a hat.
    shirt = group("AvatarShop_ShirtIcon", (-5.5, -6.9, 5.4), parent=g)
    box("AvatarShop_ShirtIcon_Body", (1.4, 0.2, 1.6), "Red", parent=shirt)
    box("AvatarShop_ShirtIcon_Sleeves", (2.6, 0.2, 0.6), "Red", (0, 0, 1.0), parent=shirt)
    hat = group("AvatarShop_HatIcon", (5.5, -6.9, 5.4), parent=g)
    cyl("AvatarShop_HatIcon_Brim", 1.2, 0.2, "Navy", (0, 0, 0.6), (90, 0, 0), hat, sides=10)
    cyl("AvatarShop_HatIcon_Top", 0.7, 1.4, "Navy", (0, 0, 0.7), (0, 0, 0), hat, sides=10)
    side = group("AvatarShop_SkinsSign", (9.2, 0, 4.5), (0, 0, 90), g)
    box("AvatarShop_SkinsSign_Board", (8, 0.4, 3.8), "WoodLight", parent=side)
    text("AvatarShop_SkinsSign_Line1", "SKINS &", 1.1, "WoodDark", (0, -0.3, 2.6), parent=side)
    text("AvatarShop_SkinsSign_Line2", "EMOTES", 1.1, "WoodDark", (0, -0.3, 1.1), parent=side)
    return g


def build_lighthouse():
    CURRENT[0] = "Lighthouse"
    g = group("Lighthouse", (30, 60, GRASS_Z))
    rock("Lighthouse_BaseRock", 8, "RockDark", (0, 0, 0.5), g, squash=(1.2, 1.2, 0.35))
    z = 1.5
    bands = 8
    for i in range(bands):
        r0 = 6 - i * 0.28
        cyl(f"Lighthouse_Band{i + 1}", r0, 3.6, "Red" if i % 2 == 0 else "White", (0, 0, z), parent=g, sides=16, r_top=r0 - 0.28)
        z += 3.6
    box("Lighthouse_Door", (2.2, 0.6, 3.8), "WoodDark", (0, -5.8, 1.5), parent=g)
    cyl("Lighthouse_Gallery", 5.4, 0.6, "Iron", (0, 0, z), parent=g, sides=16)
    for i in range(12):
        a = math.radians(i * 30)
        cyl(f"Lighthouse_RailPost{i + 1}", 0.12, 1.6, "White", (math.cos(a) * 5.1, math.sin(a) * 5.1, z + 0.6), parent=g, sides=4)
    cyl("Lighthouse_Rail", 5.15, 0.2, "White", (0, 0, z + 2.1), parent=g, sides=16)
    cyl("Lighthouse_Lantern", 3, 4, "Lamp", (0, 0, z + 0.6), parent=g, sides=8)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        box(f"Lighthouse_LanternFrame{i + 1}", (0.25, 0.25, 4), "Red", (math.cos(a) * 3.05, math.sin(a) * 3.05, z + 0.6), parent=g)
    cyl("Lighthouse_Dome", 3.7, 3, "Red", (0, 0, z + 4.6), parent=g, sides=8, r_top=0.2)
    ball("Lighthouse_Finial", 0.5, "Gold", (0, 0, z + 7.8), g)
    sign_board("Lighthouse_Sign", ["TAG ISLAND", "LIGHTHOUSE"], (-9, -10, 0), g, width=6.5, height=2.8, text_size=0.7, post_height=4, rot=(0, 0, 20))
    return g


def build_gamepass_board():
    CURRENT[0] = "GamepassBoard"
    g = group("GamepassBoard", (0, -64, GRASS_Z))
    for i, x in enumerate((-13, 13)):
        box(f"GamepassBoard_Post{i + 1}", (1, 1, 14), "WoodDark", (x, 0.5, 0), parent=g)
    box("GamepassBoard_Board", (26, 0.8, 11), "WoodLight", (0, 0, 2.5), parent=g)
    box("GamepassBoard_TitleBar", (27, 0.9, 2.6), "Navy", (0, -0.1, 13.2), parent=g)
    text("GamepassBoard_Title", "GAMEPASSES & BOOSTS", 1.3, "Gold", (0, -0.7, 14.5), parent=g)
    panels = [("VIP Pass", -8.3), ("Speed Trail", 0), ("Coin Boosters", 8.3)]
    for i, (title, x) in enumerate(panels):
        p = group(f"GamepassBoard_Panel{i + 1}", (x, -0.5, 3.3), parent=g)
        box(f"GamepassBoard_Panel{i + 1}_Back", (7.6, 0.3, 9), "Navy", parent=p)
        text(f"GamepassBoard_Panel{i + 1}_Title", title, 0.75, "White", (0, -0.25, 1.1), parent=p)
        icon = group(f"GamepassBoard_Panel{i + 1}_Icon", (0, -0.4, 4.2), parent=p)
        if i == 0:  # gold crown
            box(f"GamepassBoard_Crown_Band", (4, 0.4, 1.2), "Gold", parent=icon)
            for k in range(5):
                cx = -1.6 + k * 0.8
                cyl(f"GamepassBoard_Crown_Spike{k + 1}", 0.45, 1.6 if k % 2 == 0 else 1.1, "Gold", (cx, 0, 1.2), (0, 0, 45), icon, sides=4, r_top=0)
            for k, cx in enumerate((-1.2, 0, 1.2)):
                ball(f"GamepassBoard_Crown_Gem{k + 1}", 0.25, ["Red", "Blue", "Green"][k], (cx, -0.25, 0.6), icon)
        elif i == 1:  # speed trail
            for k, (cx, cz, w) in enumerate(((-0.5, 2.2, 3.6), (-1.0, 1.2, 4.2), (-0.5, 0.2, 3.6))):
                box(f"GamepassBoard_Trail_Streak{k + 1}", (w, 0.3, 0.45), "Cyan", (cx, 0, cz), parent=icon)
            cyl("GamepassBoard_Trail_Arrow", 1.1, 1.8, "Blue", (1.8, 0, 1.4), (0, 90, 0), icon, sides=3, r_top=0)
        else:  # coins
            for k in range(4):
                cyl(f"GamepassBoard_Coins_Stack{k + 1}", 0.9, 0.35, "Gold", (-1.1, 0, k * 0.38), parent=icon, sides=10)
            cyl("GamepassBoard_Coins_Big", 1.4, 0.35, "Gold", (1.0, 0.2, 1.6), (90, 0, 0), icon, sides=12)
            ball("GamepassBoard_Coins_Shine", 0.3, "White", (1.0, -0.2, 2.1), icon)
    return g


def build_props():
    CURRENT[0] = "Props"
    benches = group("Benches")
    spots = [((-9, -40, GRASS_Z), 90), ((13, -40, GRASS_Z), -90), ((-20, 14, GRASS_Z), 180), ((22, 12, GRASS_Z), 200),
             ((-24, -48, GRASS_Z), 30), ((28, -8, GRASS_Z), 0), ((-30, 38, GRASS_Z), 140), ((10, 34, GRASS_Z), -60)]
    for i, (loc, yaw) in enumerate(spots):
        bench(f"Bench{i + 1}", loc, yaw, benches)
    crates = group("CrateStacks")
    crate_stack("CrateStack1", (-28, 22, GRASS_Z), [(0, 0, 0), (1, 0, 0), (0, 1, 0), (0.5, 0.3, 1)], crates)
    crate_stack("CrateStack2", (46, -20, GRASS_Z), [(0, 0, 0), (1, 0, 0), (0.5, 0, 1)], crates)
    crate_stack("CrateStack3", (-62, -42, GRASS_Z), [(0, 0, 0), (0, 1, 0), (0, 0.5, 1), (1, 0.3, 0)], crates)
    lamps = group("Lampposts")
    for i, (x, y) in enumerate(((-10, -80), (9, -50), (-8, -26), (16, -4), (-24, 6), (14, 26), (-36, 52), (38, 6))):
        lamppost(f"Lamppost{i + 1}", (x, y, GRASS_Z), lamps)
    flowers = group("FlowerBoxes")
    for i, (x, y, yaw) in enumerate(((49, -9, 90), (49, 9, 90), (-6, -68, 0), (6, -68, 0), (20, 50, 30), (-14, -6, 45))):
        flower_box(f"FlowerBox{i + 1}", (x, y, GRASS_Z), yaw, flowers)
    CURRENT[0] = "Characters"
    people = group("Characters")
    chars = [((0, -6, GRASS_Z + 1.2), 0, "wave"), ((-5, 14.2, GRASS_Z + 1.2), 180, "sit"), ((-49, 11, GRASS_Z), 200, "sit"),
             ((-44, -2, GRASS_Z), 120, "look"), ((8, -28, GRASS_Z), 10, "look"), ((48, -2, GRASS_Z), -90, "stand"),
             ((30, 16, GRASS_Z), 30, "wave"), ((-8, -46, GRASS_Z), -45, "stand")]
    for i, (loc, yaw, pose) in enumerate(chars):
        character(f"Character{i + 1}_{pose.capitalize()}", loc, yaw, pose, people)


def render_previews():
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    world = bpy.data.worlds.new("Sky")
    world.color = (0.55, 0.78, 0.95)
    scene.world = world
    cam_data = bpy.data.cameras.new("PreviewCamera")
    cam_data.lens = 32
    cam_data.clip_end = 3000
    cam = bpy.data.objects.new("PreviewCamera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    shots = {"overview": ((-150, -175, 125), (5, 5, 0)), "front": ((0, -150, 40), (0, 0, 8)), "top": ((0, -1, 330), (0, 0, 0))}
    for name, (eye, target) in shots.items():
        cam.location = eye
        cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, f"lobby_{name}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_island()
    build_paths()
    build_hedges_and_rocks()
    build_dock("DockWest", 218)
    build_dock("DockNorth", 128)
    for i, (deg, rf, lean) in enumerate(((200, 0.82, 200), (160, 0.84, 150), (95, 0.83, 90), (60, 0.85, 40),
                                         (330, 0.84, 330), (300, 0.83, 280), (250, 0.83, 240))):
        t = math.radians(deg)
        r = island_radius(t) * rf
        palm(f"PalmTree{i + 1}", (math.cos(t) * r, math.sin(t) * r, GRASS_Z), lean)
    build_gazebo()
    build_firepit_lounge()
    build_leaderboard()
    build_reward_wheel()
    build_shop()
    build_lighthouse()
    build_gamepass_board()
    build_props()
    os.makedirs(OUT_DIR, exist_ok=True)
    if PREVIEW_DIR:
        render_previews()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "UltimateTagLobby.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, "UltimateTagLobby.fbx"), use_selection=True,
                             object_types={"MESH", "EMPTY"}, axis_forward="-Z", axis_up="Y", apply_unit_scale=True)
    meshes = sum(1 for o in bpy.data.objects if o.type == "MESH")
    empties = sum(1 for o in bpy.data.objects if o.type == "EMPTY")
    print(f"LOBBY done: {meshes} meshes, {empties} groups")


main()
