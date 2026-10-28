"""Shared building blocks for the Blender model scripts (dayi.py, hands.py, props.py).

Units are metres; characters face -Y (glTF +Z after export). Import from a script run with -P:
    sys.path.append(os.path.dirname(__file__)); from kit import *
"""
import math
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

STIFF = 2.0
SIZE_PER_RADIUS = 0.575  # visible radius of a lone ball / element radius at STIFF 2, threshold 0.6
SKIN = (0.93, 0.66, 0.5)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def empty(name, parent=None, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.parent = parent
    return obj


def material(name, color, roughness=0.6, metallic=0.0, alpha=1.0):
    """Named Principled material; alpha < 1 exports as a blended (see-through) glTF material."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


def finish(obj, mat, parent, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    if smooth:
        obj.data.shade_smooth()
    obj.parent = parent
    return obj


def link_mesh(name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def ball(co, size, scale=(1, 1, 1), rot=(0, 0, 0)):
    """Metaball element whose visible half-extent is roughly size * scale."""
    return {"type": "ELLIPSOID", "co": Vector(co), "r": size / SIZE_PER_RADIUS, "scale": scale, "rot": Euler(rot)}


def capsule(a, b, size):
    """Rounded limb from point a to point b with visible radius size."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    return {"type": "CAPSULE", "co": (a + b) / 2, "r": size / SIZE_PER_RADIUS,
            "half": axis.length / 2, "quat": Vector((1, 0, 0)).rotation_difference(axis)}


def moved(elements, matrix):
    """Elements transformed by a 4x4 matrix (rotation + translation, no scale)."""
    rot = matrix.to_quaternion()
    out = []
    for e in elements:
        e = dict(e, co=matrix @ e["co"])
        if e["type"] == "ELLIPSOID":
            e["rot"] = (rot @ e["rot"].to_quaternion()).to_euler()
        else:
            e["quat"] = rot @ e["quat"]
        out.append(e)
    return out


def scaled(elements, factor):
    """Elements uniformly scaled about the origin."""
    return [dict(e, co=e["co"] * factor, r=e["r"] * factor, **({"half": e["half"] * factor} if "half" in e else {}))
            for e in elements]


def blob(name, elements, mat, parent, resolution=0.009):
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
            el.rotation = e["rot"].to_quaternion()
        else:
            el.size_x = e["half"]  # half-length of the capsule's core segment
            el.rotation = e["quat"]
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.metaballs.remove(mb)
    return finish(link_mesh(name, mesh), mat, parent)


def sphere(name, co, size, scale, mat, parent, rot=(0, 0, 0), segments=32):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=segments // 2, radius=size)
    bm.to_mesh(mesh)
    bm.free()
    obj = link_mesh(name, mesh)
    obj.location = co
    obj.scale = scale
    obj.rotation_euler = rot
    return finish(obj, mat, parent)


def lathe(name, profile, mat, parent, location=(0, 0, 0), steps=64, subdiv=1):
    """Spins a (radius, height) profile around Z. Start and end the profile on the axis to close it."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0, z)) for r, z in profile]
    edges = [bm.edges.new((verts[i], verts[i + 1])) for i in range(len(verts) - 1)]
    bmesh.ops.spin(bm, geom=verts + edges, axis=(0, 0, 1), cent=(0, 0, 0), angle=math.tau, steps=steps,
                   use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = link_mesh(name, mesh)
    obj.location = location
    if subdiv:
        obj.modifiers.new("smooth", "SUBSURF").levels = subdiv
    return finish(obj, mat, parent)


def torus(name, major, minor, mat, parent, location=(0, 0, 0), rot=(0, 0, 0), arc=math.tau, segments=48, ring=12):
    """Ring around local Z; arc < tau gives an open handle."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    closed = arc >= math.tau - 1e-6
    count = segments if closed else segments + 1
    rings = []
    for i in range(count):
        a = arc * i / segments
        centre = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        rings.append([bm.verts.new(centre + out * math.cos(b) * minor + Vector((0, 0, math.sin(b) * minor)))
                      for b in (math.tau * j / ring for j in range(ring))])
    for i in range(count if closed else count - 1):
        r0, r1 = rings[i], rings[(i + 1) % count]
        for j in range(ring):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % ring], r0[(j + 1) % ring]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = link_mesh(name, mesh)
    obj.location = location
    obj.rotation_euler = rot
    return finish(obj, mat, parent)


def box(name, size, mat, parent, location=(0, 0, 0), bevel=0.002):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = link_mesh(name, mesh)
    obj.location = location
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    return finish(obj, mat, parent)


def frame(forward, up=(0, 0, 1)):
    """Rotation matrix that turns local -Y toward `forward`, keeping local +Z as close to `up` as possible."""
    f = Vector(forward).normalized()
    y = -f
    z = (Vector(up) - y * Vector(up).dot(y)).normalized()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed().to_4x4()


def hand_elements(side, chubby=1.0):
    """A relaxed hand resting palm-down: palm at the origin, fingers toward -Y, back of hand +Z.
    side +1 is the left hand (thumb toward -X), -1 the right hand (thumb toward +X)."""
    t = -side  # thumb side
    palm = [ball((0, 0, 0), 0.042 * chubby, (1.0, 1.15, 0.47)),
            ball((t * 0.01, 0.025, 0.004), 0.035 * chubby, (1.0, 1.0, 0.55))]
    fingers = []
    # (offset toward the thumb, length, radius)
    for i, (x, length, radius) in enumerate(((0.027, 0.07, 0.0105), (0.009, 0.078, 0.011),
                                             (-0.009, 0.072, 0.0105), (-0.026, 0.058, 0.0092))):
        r = radius * chubby
        knuckle = Vector((t * x * chubby, -0.042, 0.004))
        mid = knuckle + Vector((t * x * 0.08, -length * 0.55, -0.004))
        tip = mid + Vector((t * x * 0.05, -length * 0.42, -0.017))
        fingers.append([capsule(knuckle, mid, r), capsule(mid, tip, r * 0.92)])
    thumb = [capsule((t * 0.034, 0.0, -0.004), (t * 0.056, -0.03, -0.008), 0.0135 * chubby),
             capsule((t * 0.056, -0.03, -0.008), (t * 0.058, -0.056, -0.012), 0.012 * chubby)]
    return palm, fingers, thumb


def hand(prefix, side, mat, parent, matrix=Matrix(), chubby=1.0, scale=1.0, resolution=0.0035):
    """Builds a hand as separate palm/finger meshes (separate so fingers do not melt together)."""
    palm, fingers, thumb = hand_elements(side, chubby)
    place = lambda elements: moved(scaled(elements, scale), matrix)  # noqa: E731
    res = resolution * scale
    parts = [blob(prefix + "_palm", place(palm), mat, parent, res), blob(prefix + "_thumb", place(thumb), mat, parent, res)]
    for i, finger in enumerate(fingers):
        parts.append(blob("%s_finger%d" % (prefix, i), place(finger), mat, parent, res))
    return parts


def render_preview(path, camera=(0.9, -2.1, 0.95), target=(0, 0, 0.45), lens=60, size=900):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    scene.world = world
    try:
        bg = world.node_tree.nodes["Background"]
        bg.inputs["Color"].default_value = (0.5, 0.47, 0.55, 1)
        bg.inputs["Strength"].default_value = 0.9
    except (AttributeError, KeyError):
        world.color = (0.5, 0.47, 0.55)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.location = camera
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.camera = cam
    for name, rot, energy in (("key", (50, 0, -35), 3.5), ("rim", (60, 0, 160), 2.0)):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.angle = math.radians(8)
        light.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(light)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, use_visible=True)
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.visible_get())
    print("EXPORTED", path, "faces before modifiers:", faces)
