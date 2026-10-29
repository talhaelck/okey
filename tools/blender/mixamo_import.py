"""Turns a Mixamo download (FBX, T-pose, 65-bone skeleton with fingers) into a game GLB without animation, with the
caricature head and hands shrunk in the mesh (proportions.py). Motion comes from Mixamo clips (scripts/world/rigged_dayi.gd).

    blender -b --factory-startup -P tools/blender/mixamo_import.py -- <raw/mixamo/indir/x.fbx> <assets/models/dayi_rig/x.glb>
"""
import os
import sys

import bpy

sys.path.append(os.path.dirname(__file__))
from kit import args, reset  # noqa: E402
from neck_weights import fix_neck  # noqa: E402
from proportions import shrink  # noqa: E402

HEAD_SCALE = 0.65
HAND_SCALE = 0.6


def main():
    src, out = (os.path.abspath(p) for p in args()[:2])
    reset()
    bpy.ops.import_scene.fbx(filepath=src)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for obj in bpy.context.scene.objects:
        if obj.animation_data:
            obj.animation_data_clear()
    # Mixamo's FBX arrives as a 0.01-scaled, 90°-turned armature; bake that in so the skeleton is plain Y-up metres.
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type in {"ARMATURE", "MESH"})
    bpy.context.view_layer.objects.active = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    armature = bpy.context.view_layer.objects.active
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    print("NECK_REWEIGHTED", fix_neck(armature, mesh), "vertices")
    shrink(armature, mesh, HEAD_SCALE, HAND_SCALE)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=False, use_visible=True)
    bones = sum(len(o.data.bones) for o in bpy.data.objects if o.type == "ARMATURE")
    print("MIXAMO_GLB", out, os.path.getsize(out) // 1024, "KB,", bones, "bones")


main()
