# Builds the Ultimate Tag character in Blender: a smooth, low-poly cartoon person (Crab Game
# style proportions, our own model and outfit). Every R15 body part is its own mesh, plus the
# hair, tracksuit stripes and zipper as separate pieces so each can have its own color.
#
# Run (no window):
#   blender --background --python tools/blender/make_character.py -- <out_dir> [preview_dir]
# Writes:
#   <out_dir>/Character.fbx          meshes to import in Studio (Avatar > Import 3D)
#   src/shared/BodyLayout.luau       part sizes, centers and joint positions (not used by the game yet)
#   [preview_dir]/front.png etc.     preview renders
#
# Units are studs. Blender is Z-up and the character faces -Y (Blender's front view).
# Roblox is Y-up and faces -Z, so a Blender point (x, y, z) is Roblox (-x, z, y). The
# character's right side is Blender -X.
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT_DIR = os.path.abspath(ARGS[0] if ARGS else "assets_src")
PREVIEW_DIR = os.path.abspath(ARGS[1]) if len(ARGS) > 1 else None
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# --- Proportions (studs). Heights are above the ground. ---------------------------------------
ANKLE, KNEE, HIP = 0.36, 1.52, 2.72  # leg joints
HIP_X = 0.3  # hip joint distance from the middle
WAIST, NECK = 3.2, 4.48
SHOULDER_Z, SHOULDER_X = 4.3, 0.8
ELBOW, WRIST = 3.3, 2.28
HEAD_Z = 5.1  # middle of the head

# Preview colors (Roblox colors come from Config.Body, these are only for the renders).
PREVIEW = {
    "Skin": (0.91, 0.75, 0.59),
    "Jacket": (0.91, 0.42, 0.17),
    "Pants": (0.2, 0.22, 0.26),
    "Stripe": (0.96, 0.96, 0.96),
    "Shoes": (0.94, 0.94, 0.94),
    "Hair": (0.34, 0.23, 0.15),
    "Eye": (0.98, 0.98, 0.98),
    "Pupil": (0.08, 0.08, 0.08),
    "Mouth": (0.35, 0.16, 0.14),
}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def lathe(name, profile, sides=12, axis="Z", center=(0.0, 0.0, 0.0)):
    """Spins a profile around an axis. profile: (height, rx, ry) rings, r = 0 is a pole.
    Axis Z: rx is X radius, ry is Y radius. Axis Y (shoes): rx is X radius, ry is Z radius."""
    bm = bmesh.new()
    rings = []
    cx, cy, cz = center
    for h, rx, ry in profile:
        if rx <= 1e-6:
            point = (cx, cy, cz + h) if axis == "Z" else (cx, cy + h, cz)
            rings.append([bm.verts.new(point)])
            continue
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            u, v = math.cos(a) * rx, math.sin(a) * ry
            point = (cx + u, cy + v, cz + h) if axis == "Z" else (cx + u, cy + h, cz + v)
            ring.append(bm.verts.new(point))
        rings.append(ring)
    for lower, upper in zip(rings, rings[1:]):
        if len(lower) == 1 and len(upper) == 1:
            continue
        if len(lower) == 1:
            for i in range(sides):
                bm.faces.new((lower[0], upper[(i + 1) % sides], upper[i]))
        elif len(upper) == 1:
            for i in range(sides):
                bm.faces.new((lower[i], lower[(i + 1) % sides], upper[0]))
        else:
            for i in range(sides):
                j = (i + 1) % sides
                bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def ribbon(name, profile, angle, width, offset=1.03, center=(0.0, 0.0, 0.0)):
    """A thin strip lying on the surface of a lathe at `angle` (radians): stripes, zipper."""
    bm = bmesh.new()
    cx, cy, cz = center
    pairs = []
    for h, rx, ry in profile:
        if rx < 0.06:
            continue
        row = []
        for da in (-width, width):
            a = angle + da
            row.append(bm.verts.new((cx + math.cos(a) * rx * offset, cy + math.sin(a) * ry * offset, cz + h)))
        pairs.append(row)
    for lower, upper in zip(pairs, pairs[1:]):
        bm.faces.new((lower[0], lower[1], upper[1], upper[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Make sure the strip faces outward from the limb.
    for face in bm.faces:
        out = Vector((math.cos(angle), math.sin(angle), 0))
        if face.normal.dot(out) < 0:
            face.normal_flip()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def ellipsoid_profile(rz, rx, ry, rings=8, jaw=1.0):
    """Rings for an egg shape. jaw < 1 narrows the bottom half (chin)."""
    out = []
    for i in range(rings + 1):
        t = -math.pi / 2 + math.pi * i / rings
        h = math.sin(t) * rz
        k = math.cos(t)
        if h < 0:
            k *= jaw + (1 - jaw) * (1 + h / rz)
        out.append((h, max(k * rx, 0), max(k * ry, 0)))
    return out


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def cut_hairline(obj, center_z):
    """Trims the hair into a cap: the edge sits high at the forehead (-Y) and low at the back."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Slice along a tilted plane and drop everything below it, for a clean edge.
    bmesh.ops.bisect_plane(
        bm,
        geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
        plane_co=(0, 0, center_z + 0.02),
        plane_no=Vector((0, 0.42, 1)).normalized(),
        clear_inner=True,
    )
    bm.to_mesh(obj.data)
    bm.free()


def flatten_below(obj, z):
    for v in obj.data.vertices:
        if v.co.z < z:
            v.co.z = z


def build():
    parts = {}  # name -> (object, color key, parent part for details)
    details = {}

    # Head (egg shape with a narrower chin), nose and neck.
    head = lathe("HeadShape", ellipsoid_profile(0.58, 0.48, 0.52, rings=12, jaw=0.82), 18, center=(0, 0, HEAD_Z))
    nose = lathe("Nose", ellipsoid_profile(0.09, 0.07, 0.06, rings=6), 8, center=(0, -0.5, HEAD_Z - 0.08))
    neck = lathe("Neck", [(NECK - 0.05, 0, 0), (NECK - 0.04, 0.18, 0.18), (HEAD_Z - 0.35, 0.18, 0.18), (HEAD_Z - 0.33, 0, 0)], 10)
    parts["Head"] = (join([head, nose, neck], "Head"), "Skin")
    hair = lathe("Hair", ellipsoid_profile(0.62, 0.52, 0.56, rings=14), 18, center=(0, 0.03, HEAD_Z + 0.04))
    cut_hairline(hair, HEAD_Z)
    details["Hair"] = (hair, "Hair", "Head")
    # Face: eyes with pupils and a mouth (the character faces -Y; its right is -X).
    for side, sign in (("Right", -1), ("Left", 1)):
        eye = lathe(side + "Eye", ellipsoid_profile(0.1, 0.1, 0.1, rings=6), 10, center=(0.17 * sign, -0.47, HEAD_Z + 0.05))
        details[side + "Eye"] = (eye, "Eye", "Head")
        pupil = lathe(side + "Pupil", ellipsoid_profile(0.055, 0.055, 0.055, rings=6), 8, center=(0.17 * sign, -0.545, HEAD_Z + 0.05))
        details[side + "Pupil"] = (pupil, "Pupil", "Head")
    mouth = lathe("Mouth", ellipsoid_profile(0.025, 0.11, 0.03, rings=4), 10, center=(0, -0.42, HEAD_Z - 0.27))
    details["Mouth"] = (mouth, "Mouth", "Head")

    # Torso: chest tapers to the waist, rounded shoulders.
    upper = [
        (WAIST - 0.07, 0, 0),
        (WAIST - 0.05, 0.46, 0.29),
        (WAIST + 0.3, 0.52, 0.32),
        (WAIST + 0.7, 0.62, 0.36),
        (WAIST + 1.0, 0.66, 0.37),
        (NECK - 0.08, 0.62, 0.34),
        (NECK + 0.02, 0.38, 0.26),
        (NECK + 0.05, 0, 0),
    ]
    parts["UpperTorso"] = (lathe("UpperTorso", upper, 14), "Jacket")
    details["Zipper"] = (ribbon("Zipper", upper, -math.pi / 2, 0.025, 1.01), "Stripe", "UpperTorso")
    lower = [
        (HIP - 0.17, 0, 0),
        (HIP - 0.12, 0.44, 0.29),
        (HIP + 0.03, 0.55, 0.35),
        (HIP + 0.28, 0.57, 0.36),
        (WAIST + 0.0, 0.51, 0.32),
        (WAIST + 0.07, 0, 0),
    ]
    parts["LowerTorso"] = (lathe("LowerTorso", lower, 14), "Pants")

    for side, sign in (("Right", -1), ("Left", 1)):
        x = SHOULDER_X * sign
        stripe_angle = 0 if sign > 0 else math.pi  # outside of the limb
        upper_arm = [
            (SHOULDER_Z + 0.16, 0, 0),
            (SHOULDER_Z + 0.1, 0.15, 0.15),
            (SHOULDER_Z + 0.02, 0.21, 0.21),
            (ELBOW + 0.5, 0.19, 0.19),
            (ELBOW + 0.05, 0.165, 0.165),
            (ELBOW - 0.08, 0.1, 0.1),
            (ELBOW - 0.12, 0, 0),
        ]
        parts[side + "UpperArm"] = (lathe(side + "UpperArm", upper_arm, 12, center=(x, 0, 0)), "Jacket")
        lower_arm = [
            (ELBOW + 0.08, 0, 0),
            (ELBOW + 0.03, 0.12, 0.12),
            (ELBOW - 0.05, 0.165, 0.165),
            (WRIST + 0.4, 0.15, 0.15),
            (WRIST + 0.06, 0.125, 0.125),
            (WRIST - 0.03, 0.08, 0.08),
            (WRIST - 0.06, 0, 0),
        ]
        parts[side + "LowerArm"] = (lathe(side + "LowerArm", lower_arm, 12, center=(x, 0, 0)), "Jacket")
        hand = [
            (WRIST + 0.02, 0, 0),
            (WRIST - 0.03, 0.08, 0.13),
            (WRIST - 0.13, 0.115, 0.2),
            (WRIST - 0.36, 0.11, 0.19),
            (WRIST - 0.5, 0.08, 0.12),
            (WRIST - 0.55, 0, 0),
        ]
        parts[side + "Hand"] = (lathe(side + "Hand", hand, 10, center=(x, 0, 0)), "Skin")

        lx = HIP_X * sign
        upper_leg = [
            (HIP + 0.23, 0, 0),
            (HIP + 0.18, 0.18, 0.18),
            (HIP + 0.06, 0.29, 0.3),
            (HIP - 0.32, 0.27, 0.28),
            (KNEE + 0.23, 0.2, 0.21),
            (KNEE + 0.06, 0.16, 0.16),
            (KNEE - 0.02, 0, 0),
        ]
        parts[side + "UpperLeg"] = (lathe(side + "UpperLeg", upper_leg, 12, center=(lx, 0, 0)), "Pants")
        lower_leg = [
            (KNEE + 0.18, 0, 0),
            (KNEE + 0.13, 0.15, 0.15),
            (KNEE + 0.03, 0.2, 0.21),
            (KNEE - 0.42, 0.19, 0.2),
            (ANKLE + 0.19, 0.14, 0.15),
            (ANKLE + 0.04, 0.1, 0.1),
            (ANKLE, 0, 0),
        ]
        parts[side + "LowerLeg"] = (lathe(side + "LowerLeg", lower_leg, 12, center=(lx, 0, 0)), "Pants")
        # Shoe: spun along the forward axis (-Y is forward), flat sole.
        shoe = [
            (0.2, 0, 0),
            (0.17, 0.18, 0.16),
            (0.05, 0.24, 0.22),
            (-0.2, 0.25, 0.2),
            (-0.45, 0.22, 0.15),
            (-0.6, 0.14, 0.1),
            (-0.64, 0, 0),
        ]
        foot = lathe(side + "Foot", shoe, 12, axis="Y", center=(lx, 0, 0.18))
        flatten_below(foot, 0.0)
        parts[side + "Foot"] = (foot, "Shoes")

        for limb, profile, cx, key in (
            ("UpperArm", upper_arm, x, "Jacket"),
            ("LowerArm", lower_arm, x, "Jacket"),
            ("UpperLeg", upper_leg, lx, "Pants"),
            ("LowerLeg", lower_leg, lx, "Pants"),
        ):
            name = side + limb + "Stripe"
            details[name] = (ribbon(name, profile, stripe_angle, 0.07, 1.03, center=(cx, 0, 0)), "Stripe", side + limb)
    return parts, details


def to_roblox(v):
    return [round(-v[0], 4), round(v[2], 4), round(v[1], 4)]


def bounds(obj):
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    lo, hi = Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))
    return (lo + hi) / 2, hi - lo


def joints():
    out = {
        "Root": ("HumanoidRootPart", "LowerTorso", (0, 0, HIP + 0.27)),
        "Waist": ("LowerTorso", "UpperTorso", (0, 0, WAIST)),
        "Neck": ("UpperTorso", "Head", (0, 0, NECK)),
    }
    for side, sign in (("Right", -1), ("Left", 1)):
        x, lx = SHOULDER_X * sign, HIP_X * sign
        out[side + "Shoulder"] = ("UpperTorso", side + "UpperArm", (x, 0, SHOULDER_Z))
        out[side + "Elbow"] = (side + "UpperArm", side + "LowerArm", (x, 0, ELBOW))
        out[side + "Wrist"] = (side + "LowerArm", side + "Hand", (x, 0, WRIST))
        out[side + "Hip"] = ("LowerTorso", side + "UpperLeg", (lx, 0, HIP))
        out[side + "Knee"] = (side + "UpperLeg", side + "LowerLeg", (lx, 0, KNEE))
        out[side + "Ankle"] = (side + "LowerLeg", side + "Foot", (lx, 0, ANKLE))
    return out


def write_layout(parts, details):
    lines = [
        "--!strict",
        "-- GENERATED by tools/blender/make_character.py. Do not edit by hand; change the script",
        "-- and run it again. Roblox studs, Y up, facing -Z. Sizes and centers are each mesh's",
        "-- bounding box; joints are world positions with the character standing on Y = 0.",
        "export type Part = { size: Vector3, center: Vector3, color: string, parent: string? }",
        "export type Joint = { part0: string, part1: string, position: Vector3 }",
        "",
        "local function v(x: number, y: number, z: number): Vector3",
        "\treturn Vector3.new(x, y, z)",
        "end",
        "",
        "local BodyLayout = {",
        f"\tHipHeight = {HIP},",
        f"\tRootCenter = v({0}, {HIP + 1}, {0}),",
        "\tParts = {",
    ]

    def entry(name, obj, color, parent=None):
        center, size = bounds(obj)
        c, s = to_roblox(center), to_roblox(size)
        s = [abs(n) for n in s]
        extra = f', parent = "{parent}"' if parent else ""
        lines.append(
            f'\t\t{name} = {{ size = v({s[0]}, {s[1]}, {s[2]}), center = v({c[0]}, {c[1]}, {c[2]}), color = "{color}"{extra} }},'
        )

    for name, (obj, color) in sorted(parts.items()):
        entry(name, obj, color)
    lines.append("\t} :: { [string]: Part },")
    lines.append("\tDetails = {")
    for name, (obj, color, parent) in sorted(details.items()):
        entry(name, obj, color, parent)
    lines.append("\t} :: { [string]: Part },")
    lines.append("\tJoints = {")
    for name, (p0, p1, pos) in sorted(joints().items()):
        r = to_roblox(pos)
        lines.append(f'\t\t{name} = {{ part0 = "{p0}", part1 = "{p1}", position = v({r[0]}, {r[1]}, {r[2]}) }},')
    lines.append("\t} :: { [string]: Joint },")
    lines.append("}")
    lines.append("")
    lines.append("return BodyLayout")
    path = os.path.join(REPO, "src", "shared", "BodyLayout.luau")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", path)


def export_fbx(parts, details):
    os.makedirs(OUT_DIR, exist_ok=True)
    objects = [o for o, _ in parts.values()] + [o for o, _, _ in details.values()]
    for obj in objects:
        # Each mesh's origin at its bounding-box center (that's where Roblox puts a MeshPart's).
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        bpy.ops.object.shade_smooth()
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, "Character.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        mesh_smooth_type="FACE",
    )
    print("wrote", path)


def render_previews(parts, details):
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    for obj, key in parts.values():
        obj.color = (*PREVIEW[key], 1)
    for obj, key, _ in details.values():
        obj.color = (*PREVIEW[key], 1)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "OBJECT"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 700, 1000
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.color = (0.55, 0.7, 0.85)
    scene.world = world
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 6.6
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    scene.camera = camera
    target = Vector((0, 0, 2.9))
    for name, direction in (("front", (0, -1, 0)), ("side", (-1, 0, 0)), ("three_quarter", (-0.7, -0.7, 0.15))):
        d = Vector(direction).normalized()
        camera.location = target + d * 20
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath)


clear_scene()
parts, details = build()
for obj in [o for o, _ in parts.values()] + [o for o, _, _ in details.values()]:
    for poly in obj.data.polygons:
        poly.use_smooth = True
write_layout(parts, details)
if PREVIEW_DIR:
    render_previews(parts, details)
export_fbx(parts, details)
