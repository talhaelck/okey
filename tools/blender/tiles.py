"""Builds the okey tile mesh: a bakelite block with softly bevelled edges and a UV-mapped face.

    blender -b --factory-startup -P tools/blender/tiles.py -- <out.glb>

Size matches TileFactory.SIZE (0.048 wide, 0.07 tall, 0.019 thick). In glTF/Godot terms the printed face
points +Z and the numbers stand upright along +Y. Faces looking toward the front get UVs 0..1 across the whole
tile front (u right, v down); every other face gets UV (-1, -1), which tile.gdshader draws as plain bakelite.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
from kit import args, reset  # noqa: E402

WIDTH, HEIGHT, THICK = 0.048, 0.07, 0.019
BEVEL = 0.0045


def build():
    reset()
    # Blender axes: X = width, Z = height, -Y = the printed face (glTF +Z after export).
    mesh = bpy.data.meshes.new("tile")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(WIDTH, THICK, HEIGHT), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("tile", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bevel = obj.modifiers.new("bevel", "BEVEL")
    bevel.width = BEVEL
    bevel.segments = 5
    bevel.profile = 0.6
    bevel.harden_normals = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="bevel")

    uv = mesh.uv_layers.new(name="UVMap")
    front = Vector((0, -1, 0))
    for poly in mesh.polygons:
        facing = poly.normal.dot(front) > 0.3
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (co.x / WIDTH + 0.5, co.z / HEIGHT + 0.5) if facing else (-1.0, -1.0)
    mesh.shade_smooth()
    return obj


def main():
    out = args()
    build()
    bpy.ops.export_scene.gltf(filepath=out[0], export_format="GLB", export_materials="NONE")
    print("EXPORTED", out[0], "faces:", len(bpy.data.objects["tile"].data.polygons))


main()
