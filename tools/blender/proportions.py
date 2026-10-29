"""Shrinks a rigged dayı's caricature head and hands in the mesh itself, not on bones at runtime.

Each vertex moves toward the joint by as much as it belongs to the head or hand bones (its skin weight), so the
collar and wrist blend smoothly; the bones inside are scaled about the same joint, so the Mixamo weights stay
valid. Scaling the bones at runtime instead stretched the collar whenever the head turned.
Used by mixamo_import.py on a transform-applied Mixamo armature (bone names "mixamorig:<Name>").
"""
import bpy
from mathutils import Vector

HEAD_BONES = ("Head", "HeadTop_End")
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")


def hand_bones(side):
    return [side + "Hand"] + ["%sHand%s%d" % (side, f, j) for f in FINGERS for j in range(1, 5)]


def shrink(armature, mesh, head_scale, hand_scale, prefix="mixamorig:"):
    parts = [(prefix + "Head", [prefix + b for b in HEAD_BONES], head_scale)]
    for side in ("Left", "Right"):
        parts.append((prefix + side + "Hand", [prefix + b for b in hand_bones(side)], hand_scale))
    pivots = {pivot: armature.data.bones[pivot].head_local.copy() for pivot, _, _ in parts}

    groups = {g.name: g.index for g in mesh.vertex_groups}
    for vertex in mesh.data.vertices:
        weights = {g.group: g.weight for g in vertex.groups}
        offset = Vector()
        for pivot, bones, scale in parts:
            w = min(1.0, sum(weights.get(groups[b], 0.0) for b in bones if b in groups))
            if w > 0.0:
                offset += (vertex.co - pivots[pivot]) * (scale - 1.0) * w
        vertex.co += offset

    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    for pivot, bones, scale in parts:
        centre = pivots[pivot]
        for name in bones:
            bone = armature.data.edit_bones.get(name)
            if bone is None:
                continue
            if name != pivot:
                bone.head = centre + (bone.head - centre) * scale
            bone.tail = centre + (bone.tail - centre) * scale
    bpy.ops.object.mode_set(mode="OBJECT")
