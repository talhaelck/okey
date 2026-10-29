"""Turns a Mixamo animation download (FBX, with or without skin) into a skeleton-only GLB clip for the dayıs.

    blender -b --factory-startup -P tools/blender/mixamo_anim.py -- <raw/mixamo/anim/x.fbx> <assets/models/dayi_rig/anim/x.glb>

Mixamo's armature comes 0.01-scaled and turned 90°; it is baked in exactly as mixamo_import.py does for the
characters, so the clip's bones match theirs. Bone locations are keyed in the old centimetre units, so they are
scaled down with it. The clip is named after the output file.
"""
import os
import sys

import bpy

sys.path.append(os.path.dirname(__file__))
from kit import args, reset  # noqa: E402


def fcurves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def main():
    src, out = (os.path.abspath(p) for p in args()[:2])
    name = os.path.splitext(os.path.basename(out))[0]
    reset()
    bpy.ops.import_scene.fbx(filepath=src)
    for obj in [o for o in bpy.context.scene.objects if o.type != "ARMATURE"]:
        bpy.data.objects.remove(obj)
    armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    unit = armature.scale[0]
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    action = armature.animation_data.action
    action.name = name
    for curve in fcurves(action):
        if curve.data_path.endswith(".location"):
            for key in curve.keyframe_points:
                key.co.y *= unit
                key.handle_left.y *= unit
                key.handle_right.y *= unit
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=False)
    print("MIXAMO_ANIM", out, os.path.getsize(out) // 1024, "KB,", name, tuple(action.frame_range))


main()
