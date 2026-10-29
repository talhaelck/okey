"""Re-weights a Mixamo dayı's chin, jowls and neck so the whole face moves with the head.

Mixamo's auto-weights split these neckless caricatures' double chins between the head and the chest, so the chin
stretched like dough whenever the head turned or looked down. Here everything above a slanted jaw line (through the
neck joint, dropping toward the face, rising toward the nape) goes fully to the head, with a short smooth blend into
the original weights below it. Used by mixamo_import.py on a transform-applied armature (bones "mixamorig:<Name>").
"""
from mathutils import Vector

FORWARD_SLANT = 0.8 # how much the jaw line drops toward the face (1 = 45°)
BLEND = 0.45 # blend band half-width, in neck lengths
REACH = 1.4 # vertices within this many head heights of the head joint are considered
WIDTH = (0.42, 0.6) # sideways from the neck axis, in head heights: fully head inside, untouched outside (shoulders)


def smoothstep(edge0, edge1, x):
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def fix_neck(armature, mesh, prefix="mixamorig:"):
    bones = armature.data.bones
    neck = bones[prefix + "Neck"].head_local
    head = bones[prefix + "Head"].head_local
    top = bones[prefix + "HeadTop_End"].head_local
    forward = (bones[prefix + "LeftToeBase"].head_local - bones[prefix + "LeftFoot"].head_local)
    forward.z = 0.0
    forward.normalize()
    up = (head - neck).normalized()
    normal = (up + forward * FORWARD_SLANT).normalized()
    blend = (head - neck).length * BLEND
    height = (top - head).length
    reach = height * REACH

    groups = {g.name: g for g in mesh.vertex_groups}
    head_group = groups.get(prefix + "Head") or mesh.vertex_groups.new(name=prefix + "Head")
    index = {g.index: g for g in mesh.vertex_groups}
    changed = 0
    for vertex in mesh.data.vertices:
        if (vertex.co - head).length > reach:
            continue
        side = vertex.co - neck
        side -= up * side.dot(up) + forward * side.dot(forward)
        t = smoothstep(-blend, blend, (vertex.co - neck).dot(normal))
        t *= 1.0 - smoothstep(WIDTH[0] * height, WIDTH[1] * height, side.length)
        if t <= 0.0:
            continue
        for g in list(vertex.groups):
            group = index[g.group]
            if group != head_group:
                group.add([vertex.index], g.weight * (1.0 - t), "REPLACE")
        current = next((g.weight for g in vertex.groups if g.group == head_group.index), 0.0)
        head_group.add([vertex.index], current * (1.0 - t) + t, "REPLACE")
        changed += 1
    return changed
