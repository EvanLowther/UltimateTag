# Smooth one-piece character body (v2). Grows a continuous body from a stick-figure skeleton
# with Blender's Skin modifier, smooths it with subdivision, and adds a head, face, hair and
# shoes. Colors (jacket, pants, skin, stripes, zipper) are assigned by body region.
#
# Run (no window):
#   blender --background --python tools/blender/smooth_body.py -- <preview_dir>
#
# Units are studs, Blender Z-up, character faces -Y, its right side is -X.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
PREVIEW_DIR = os.path.abspath(ARGS[0] if ARGS else "previews")

WAIST, WRIST, HEAD_Z = 3.15, 2.3, 5.12

COLORS = {
    "Skin": (0.91, 0.74, 0.58),
    "Jacket": (0.86, 0.36, 0.13),
    "Pants": (0.17, 0.19, 0.24),
    "Stripe": (0.97, 0.97, 0.97),
    "Shoes": (0.95, 0.95, 0.95),
    "Sole": (0.45, 0.45, 0.5),
    "Hair": (0.3, 0.19, 0.12),
    "Eye": (0.99, 0.99, 0.99),
    "Pupil": (0.05, 0.05, 0.05),
    "Mouth": (0.45, 0.18, 0.16),
}


def material(name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*COLORS[name], 1)
    return mat


def link(obj):
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    return obj


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def skeleton_body():
    """The body from the neck down as one piece: (position, (radius across, radius front-back))."""
    joints = {
        "pelvis": ((0, 0, 2.86), (0.5, 0.33)),
        "belly": ((0, 0, 3.3), (0.44, 0.3)),
        "chest": ((0, 0, 3.86), (0.55, 0.34)),
        "upperchest": ((0, 0, 4.22), (0.5, 0.3)),
        "neck": ((0, 0, 4.5), (0.17, 0.17)),
        "necktop": ((0, 0, 4.72), (0.16, 0.16)),
    }
    edges = [("pelvis", "belly"), ("belly", "chest"), ("chest", "upperchest"), ("upperchest", "neck"), ("neck", "necktop")]
    for side, s in (("R", -1), ("L", 1)):
        joints["shoulder" + side] = ((0.66 * s, 0.02, 4.2), (0.2, 0.2))
        joints["elbow" + side] = ((0.8 * s, 0.04, 3.28), (0.15, 0.155))
        joints["wrist" + side] = ((0.83 * s, 0.0, WRIST), (0.115, 0.12))
        joints["hand" + side] = ((0.84 * s, -0.03, WRIST - 0.42), (0.085, 0.15))
        joints["hip" + side] = ((0.29 * s, 0, 2.66), (0.27, 0.27))
        joints["knee" + side] = ((0.3 * s, -0.03, 1.52), (0.18, 0.19))
        joints["ankle" + side] = ((0.3 * s, 0.0, 0.3), (0.12, 0.125))
        edges += [
            ("upperchest", "shoulder" + side),
            ("shoulder" + side, "elbow" + side),
            ("elbow" + side, "wrist" + side),
            ("wrist" + side, "hand" + side),
            ("pelvis", "hip" + side),
            ("hip" + side, "knee" + side),
            ("knee" + side, "ankle" + side),
        ]
    names = list(joints)
    mesh = bpy.data.meshes.new("Body")
    mesh.from_pydata([joints[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
    obj = link(bpy.data.objects.new("Body", mesh))
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    for i, name in enumerate(names):
        mesh.skin_vertices[0].data[i].radius = joints[name][1]
        mesh.skin_vertices[0].data[i].use_root = name == "pelvis"
    sub = obj.modifiers.new("Smooth", "SUBSURF")
    sub.levels = 3
    sub.render_levels = 3
    apply_modifiers(obj)
    return obj


def egg(name, center, radii, jaw=1.0, segments=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=center)
    obj = bpy.context.active_object
    obj.name = name
    for v in obj.data.vertices:
        x, y, z = v.co
        k = jaw + (1 - jaw) * (1 + z) if z < 0 else 1.0  # narrower toward the chin
        v.co = Vector((x * radii[0] * k, y * radii[1] * k, z * radii[2]))
    bpy.ops.object.shade_smooth()
    return obj


def cut_loops(body, heights):
    """Adds an edge loop all the way round at each height, so color edges (hem, cuffs) are straight."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    for z in heights:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z), plane_no=(0, 0, 1))
    bm.to_mesh(body.data)
    bm.free()


def color_body(body):
    """Paints the body by region: skin hands, jacket above the waist, pants below, stripes down
    the outside of every limb, a zipper down the front."""
    mats = ["Skin", "Jacket", "Pants", "Stripe"]
    for m in mats:
        body.data.materials.append(material(m))
    for poly in body.data.polygons:
        c, n = poly.center, poly.normal
        arm = abs(c.x) > 0.62 and c.z > 1.6
        if arm and c.z < WRIST - 0.02:
            key = "Skin"  # hands
        elif c.z >= 4.55:
            key = "Skin"  # neck
        elif arm or c.z >= WAIST:
            key = "Jacket"
        else:
            key = "Pants"
        leg = c.z < 2.55 and not arm
        outward = n.x * (1 if c.x > 0 else -1)
        if key != "Skin" and (arm or leg) and outward > 0.975:
            key = "Stripe"  # thin side stripes down the outside of each limb
        if key == "Jacket" and abs(c.x) < 0.025 and n.y < -0.8 and WAIST + 0.05 < c.z < 4.45:
            key = "Stripe"  # zipper
        poly.material_index = mats.index(key)


def head_and_face():
    head = egg("Head", (0, 0, HEAD_Z), (0.47, 0.5, 0.6), jaw=0.8)
    head.data.materials.append(material("Skin"))
    nose = egg("Nose", (0, -0.5, HEAD_Z - 0.08), (0.06, 0.07, 0.09), segments=16, rings=10)
    nose.data.materials.append(material("Skin"))
    hair = egg("Hair", (0, 0.03, HEAD_Z + 0.05), (0.5, 0.54, 0.62), segments=40, rings=24)
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    bmesh.ops.bisect_plane(
        bm,
        geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
        plane_co=(0, 0, 0),  # the hair's own coordinates (its center is the object location)
        plane_no=Vector((0, 0.45, 1)).normalized(),
        clear_inner=True,
    )
    bm.to_mesh(hair.data)
    bm.free()
    hair.data.materials.append(material("Hair"))
    solid = hair.modifiers.new("Thickness", "SOLIDIFY")
    solid.thickness = 0.04
    for s in (-1, 1):
        eye = egg("Eye", (0.17 * s, -0.43, HEAD_Z + 0.06), (0.11, 0.1, 0.12), segments=20, rings=12)
        eye.data.materials.append(material("Eye"))
        pupil = egg("Pupil", (0.17 * s, -0.525, HEAD_Z + 0.06), (0.05, 0.03, 0.055), segments=16, rings=10)
        pupil.data.materials.append(material("Pupil"))
        brow = egg("Brow", (0.17 * s, -0.47, HEAD_Z + 0.21), (0.09, 0.025, 0.02), segments=12, rings=6)
        brow.data.materials.append(material("Hair"))
    mouth = egg("Mouth", (0, -0.43, HEAD_Z - 0.3), (0.12, 0.03, 0.025), segments=16, rings=6)
    mouth.data.materials.append(material("Mouth"))


def shoes():
    for s in (-1, 1):
        shoe = egg("Shoe", (0.3 * s, -0.14, 0.13), (0.2, 0.36, 0.22), segments=24, rings=14)
        for v in shoe.data.vertices:
            v.co.z = max(v.co.z, -0.1)  # flat sole just above the ground (local coordinates)
        shoe.data.materials.append(material("Shoes"))
        sole = egg("Sole", (0.3 * s, -0.14, 0.04), (0.21, 0.37, 0.04), segments=24, rings=8)
        sole.data.materials.append(material("Sole"))


def render():
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = False
    scene.render.resolution_x, scene.render.resolution_y = 700, 1000
    world = bpy.data.worlds.new("World")
    world.color = (0.55, 0.7, 0.85)
    scene.world = world
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 6.6
    cam = bpy.data.objects.new("Camera", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((0, 0, 2.9))
    for name, d in (("front", (0, -1, 0)), ("side", (-1, 0, 0)), ("three_quarter", (-0.7, -0.7, 0.15))):
        d = Vector(d).normalized()
        cam.location = target + d * 20
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, "smooth_" + name + ".png")
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
body = skeleton_body()
cut_loops(body, (WAIST, WRIST - 0.02, 4.55))
color_body(body)
head_and_face()
shoes()
render()
print("done")
