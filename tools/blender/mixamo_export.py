"""Turns a game-ready Meshy dayı (assets/models/meshy/<name>.glb) into an FBX with embedded textures for Mixamo's
auto-rigger, which adds finger bones that Meshy's rig lacks.

    blender -b --factory-startup -P tools/blender/mixamo_export.py -- <in.glb> <out.fbx>
"""
import os
import sys

import bpy

sys.path.append(os.path.dirname(__file__))
from kit import args, reset  # noqa: E402


def main():
    src, out = (os.path.abspath(p) for p in args()[:2])
    reset()
    bpy.ops.import_scene.gltf(filepath=src)
    # FBX can only embed textures that exist as files, so write the packed glTF images next to the output first.
    folder = os.path.join(os.path.dirname(out), os.path.splitext(os.path.basename(out))[0] + "_tex")
    os.makedirs(folder, exist_ok=True)
    for i, image in enumerate(bpy.data.images):
        if image.size[0] == 0:
            continue
        image.filepath_raw = os.path.join(folder, "tex_%d.png" % i)
        image.file_format = "PNG"
        image.save()
    bpy.ops.export_scene.fbx(filepath=out, use_selection=False, object_types={"MESH"}, path_mode="COPY",
                             embed_textures=True, apply_unit_scale=True, bake_space_transform=False)
    print("MIXAMO_FBX", out, os.path.getsize(out) // 1024, "KB")


main()
