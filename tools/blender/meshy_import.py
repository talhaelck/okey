"""Makes a raw Meshy download game-ready: real-world size, origin at the bottom centre, fewer faces, smaller textures.

    blender -b --factory-startup -P tools/blender/meshy_import.py -- <raw.glb> <out.glb> <height m> <faces> <texture px> [preview.png]

Meshy scales everything to about 1.9 m and ships 300k-1M faces with 4k textures; a tea glass needs neither.
Raw downloads live in raw/meshy/ (ignored by git and Godot); the result goes to assets/models/meshy/.
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from kit import args, export, render_preview, reset  # noqa: E402


def bounds(meshes):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            lo, hi = Vector(map(min, lo, world)), Vector(map(max, hi, world))
    return lo, hi


def main():
    src, out, height, faces, texture = args()[:5]
    preview = args()[5] if len(args()) > 5 else None
    reset()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

    for obj in meshes:
        count = len(obj.data.polygons)
        if count > int(faces):
            mod = obj.modifiers.new("decimate", "DECIMATE")
            mod.ratio = int(faces) / count
            mod.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)

    # Scale to the requested height and put the origin at the bottom centre.
    lo, hi = bounds(meshes)
    factor = float(height) / (hi.z - lo.z)
    offset = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for obj in meshes:
        obj.data.transform(obj.matrix_world)
        obj.matrix_world.identity()
        for v in obj.data.vertices:
            v.co = (v.co - offset) * factor

    for image in bpy.data.images:
        w, h = image.size
        if max(w, h) > int(texture):
            image.scale(int(texture), int(texture) * h // w)
            image.pack()

    export(os.path.abspath(out))
    lo, hi = bounds(meshes)
    print("MESHY_IMPORT", os.path.basename(out), sum(len(o.data.polygons) for o in meshes), "faces,",
          tuple(round(v, 3) for v in hi - lo), "m")
    if preview:
        size = max(hi - lo)
        render_preview(os.path.abspath(preview), camera=(size * 0.9, -size * 2.1, size * 1.2),
                       target=(0, 0, (hi.z - lo.z) * 0.45), lens=60, size=700)


main()
