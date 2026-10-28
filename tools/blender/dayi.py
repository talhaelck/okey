"""Builds the seated kahvehane dayı in Blender and exports it as glTF.

Run headless:
    blender -b --factory-startup -P tools/blender/dayi.py -- <out.glb> [preview.png]

Units are metres, origin at the seat contact point, facing -Y (glTF +Z after export).
Every customisable part is its own top-level node under "Dayi" (hat_*, mustache_*, hair_*, ...)
so the game can toggle and recolour parts for the character creator.
"""
import math
import sys

import bpy
from mathutils import Euler, Vector

STIFF = 2.0
SIZE_PER_RADIUS = 0.575  # visible radius of a lone ball / element radius at STIFF 2, threshold 0.6

PALETTE = {
    "skin": (0.93, 0.66, 0.5),
    "atlet": (0.95, 0.94, 0.9),
    "vest": (0.36, 0.22, 0.15),
    "trousers": (0.27, 0.28, 0.33),
    "shoes": (0.18, 0.11, 0.07),
    "mustache": (0.14, 0.11, 0.1),
    "hair": (0.62, 0.62, 0.64),
    "cap": (0.4, 0.34, 0.28),
    "eye": (0.04, 0.04, 0.05),
    "shine": (1.0, 1.0, 1.0),
}


def material(name, roughness=0.6):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*PALETTE[name], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return m


def finish(obj, mat_name, parent, roughness=0.6):
    obj.data.materials.clear()
    obj.data.materials.append(material(mat_name, roughness))
    obj.data.shade_smooth()
    obj.parent = parent
    return obj


def ball(co, size, scale=(1, 1, 1), rot=(0, 0, 0)):
    """Metaball element whose visible half-extent is roughly size * scale."""
    return {"type": "ELLIPSOID", "co": co, "r": size / SIZE_PER_RADIUS, "scale": scale, "rot": rot}


def capsule(a, b, size):
    """Rounded limb from point a to point b with visible radius size."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    return {"type": "CAPSULE", "co": (a + b) / 2, "r": size / SIZE_PER_RADIUS,
            "half": axis.length / 2, "quat": Vector((1, 0, 0)).rotation_difference(axis)}


def blob(name, elements, mat_name, parent, resolution=0.014):
    """Merges metaball elements into one smooth mesh object."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = mb.render_resolution = resolution
    mb.threshold = 0.6
    tmp = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(tmp)
    for e in elements:
        el = mb.elements.new(type=e["type"])
        el.co = e["co"]
        el.radius = e["r"]
        el.stiffness = STIFF
        if e["type"] == "ELLIPSOID":
            el.size_x, el.size_y, el.size_z = e["scale"]
            el.rotation = Euler(e["rot"]).to_quaternion()
        else:
            # Capsule size_x is the half-length of its core segment.
            el.size_x = e["half"]
            el.rotation = e["quat"]
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.metaballs.remove(mb)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return finish(obj, mat_name, parent)


def sphere(name, co, size, scale, mat_name, parent, rot=(0, 0, 0), roughness=0.6):
    import bmesh
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=size)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = co
    obj.scale = scale
    obj.rotation_euler = rot
    return finish(obj, mat_name, parent, roughness)


def on_head(center, radius, yaw_deg, pitch_deg, lift=0.0):
    """Point on the head sphere: yaw 0 = straight ahead (-Y), positive yaw to the character's left (+X)."""
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    return Vector(center) + d * (radius + lift)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = bpy.data.objects.new("Dayi", None)
    bpy.context.scene.collection.objects.link(root)

    head_c, head_r = (0, 0, 0.8), 0.24

    # Seated body: trousers, then belly/chest under a vest with a V opening.
    blob("trousers", [
        ball((0, 0.0, 0.08), 0.19, (1.0, 0.95, 0.6)),
        *[capsule((s * 0.1, -0.02, 0.07), (s * 0.11, -0.24, 0.07), 0.08) for s in (-1, 1)],
        *[capsule((s * 0.11, -0.26, 0.06), (s * 0.11, -0.27, -0.17), 0.075) for s in (-1, 1)],
    ], "trousers", root)
    for s in (-1, 1):
        sphere("shoe_%s" % ("l" if s > 0 else "r"), (s * 0.11, -0.31, -0.22), 1.0, (0.075, 0.11, 0.05),
               "shoes", root, roughness=0.4)

    torso = [ball((0, -0.04, 0.24), 0.23, (1.0, 0.95, 0.9)), ball((0, 0.0, 0.42), 0.2, (1.05, 0.85, 0.75))]
    blob("atlet", torso, "atlet", root)
    vest = blob("vest", [dict(e, r=e["r"] * 1.06) for e in torso], "vest", root)
    cutter = bpy.data.objects.new("vest_cut", bpy.data.meshes.new("vest_cut"))
    import bmesh
    bm = bmesh.new()
    # V-shaped wedge in front of the chest: wide at the neck, narrowing to the belly.
    pts = [(-0.11, -0.4, 0.62), (0.11, -0.4, 0.62), (0.02, -0.4, 0.2), (-0.02, -0.4, 0.2)]
    front = [bm.verts.new(p) for p in pts]
    back = [bm.verts.new((x, -0.05, z)) for x, _, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(cutter.data)
    bm.free()
    bpy.context.scene.collection.objects.link(cutter)
    mod = vest.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    cutter.hide_render = cutter.hide_viewport = True
    for i, z in enumerate((0.42, 0.33, 0.24)):
        sphere("vest_button_%d" % i, (0.075 - (0.42 - z) * 0.12, -0.255 - (0.42 - z) * 0.12, z), 0.014,
               (1, 0.6, 1), "shoes", root, roughness=0.3)

    # Arms resting forward on the table edge, mitten hands with a thumb.
    arms = []
    for s in (-1, 1):
        shoulder, elbow, wrist = (s * 0.22, 0.0, 0.45), (s * 0.3, -0.06, 0.27), (s * 0.2, -0.3, 0.3)
        arms += [capsule(shoulder, elbow, 0.065), capsule(elbow, wrist, 0.06),
                 ball((s * 0.18, -0.36, 0.31), 0.07, (1.0, 1.15, 0.75)),
                 ball((s * 0.12, -0.33, 0.33), 0.03, (1.0, 1.3, 0.9))]
    blob("arms", arms, "skin", root)

    # Head: big round dome, ears and a bulbous nose all melted together.
    blob("head", [
        ball(head_c, head_r, (1.0, 0.95, 1.0)),
        ball((0, -0.03, 0.66), 0.17, (1.1, 0.9, 0.6)),  # jowls / chin
        *[ball((s * 0.24, -0.02, 0.78), 0.055, (0.5, 0.9, 1.1)) for s in (-1, 1)],
        ball(on_head(head_c, head_r, 0, -8, 0.0), 0.065, (1.05, 1.0, 0.95)),
    ], "skin", root)

    for s in (-1, 1):
        side = "l" if s > 0 else "r"
        eye = on_head(head_c, head_r, s * 17, 8, -0.01)
        sphere("eye_" + side, eye, 1.0, (0.032, 0.02, 0.046), "eye", root,
               rot=(0, 0, math.radians(s * 17)), roughness=0.15)
        sphere("eye_shine_" + side, eye + Vector((s * 0.008, -0.014, 0.016)), 0.011, (1, 1, 1), "shine", root)

    # Customisable parts.
    blob("brows_bushy", [capsule(on_head(head_c, head_r, s * 8, 19, 0.01), on_head(head_c, head_r, s * 28, 21, 0.0), 0.024)
                         for s in (-1, 1)], "mustache", root)
    blob("mustache_pala", [
        *[capsule(on_head(head_c, head_r, s * 4, -18, 0.04), on_head(head_c, head_r, s * 22, -24, 0.0), 0.034)
          for s in (-1, 1)],
        *[capsule(on_head(head_c, head_r, s * 22, -24, 0.0), on_head(head_c, head_r, s * 30, -40, -0.02), 0.026)
          for s in (-1, 1)],
    ], "mustache", root)
    blob("hair_fringe", [ball(on_head(head_c, head_r, a, 14, -0.035), 0.055, (1, 1, 0.75))
                         for a in range(100, 261, 16)], "hair", root)
    blob("hat_kasket", [
        ball((0, 0.01, 0.97), 0.25, (1.02, 1.05, 0.4)),
        ball((0, -0.2, 0.93), 0.15, (1.15, 0.65, 0.12), rot=(math.radians(-12), 0, 0)),
    ], "cap", root)


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 900
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.color = (0.55, 0.5, 0.62)
    scene.world = world
    try:
        bg = world.node_tree.nodes["Background"]
        bg.inputs["Color"].default_value = (0.55, 0.5, 0.62, 1)
        bg.inputs["Strength"].default_value = 0.9
    except (AttributeError, KeyError):
        pass
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.location = (0.9, -2.1, 0.95)
    cam.rotation_euler = (Vector((0, 0, 0.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 60
    scene.camera = cam
    for name, rot, energy in (("key", (50, 0, -35), 3.5), ("rim", (60, 0, 160), 2.0)):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.angle = math.radians(8)
        light.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(light)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


HEAD_PARTS = ("head", "eye_", "brows_", "mustache_", "hair_", "hat_")


def group_head():
    """Parents every head part under a "Head" pivot at the neck so the game can turn and shake it."""
    root = bpy.data.objects["Dayi"]
    pivot = bpy.data.objects.new("Head", None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.location = (0, 0, 0.58)
    pivot.parent = root
    bpy.context.view_layer.update()
    for obj in list(root.children):
        if obj.name.startswith(HEAD_PARTS):
            world = obj.matrix_world.copy()
            obj.parent = pivot
            obj.matrix_world = world


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build()
    group_head()
    if args:
        bpy.ops.export_scene.gltf(filepath=args[0], export_format="GLB", export_apply=True, use_visible=True)
    if len(args) > 1:
        render_preview(args[1])
    tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.visible_get())
    print("DAYI DONE, faces:", tris)


main()
