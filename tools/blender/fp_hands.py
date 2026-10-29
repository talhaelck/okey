"""Builds the local player's first-person dayı forearms and hands from an MPFB human.

Realistic hands (real finger geometry, old-man skin texture, finger bones) on a heavy old dayı build,
cut below rolled-up shirt sleeves, with a gold ring (right) and a wristwatch (left).
Needs the MPFB extension and the makehuman_system_assets + skins02 packs (see CLAUDE.md).

    blender -b -P tools/blender/fp_hands.py -- <out.glb> [preview.png]

Output: two armatures "arm_r" and "arm_l". Each is posed palm down with its origin at the palm centre:
fingers toward -Y, back of the hand +Z (glTF: fingers +Z, back +Y), forearm running back along +Y.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(__file__))
from kit import args, lathe, material, render_preview, torus  # noqa: E402

from bl_ext.user_default.mpfb.services.exportservice import ExportService  # noqa: E402
from bl_ext.user_default.mpfb.services.humanservice import HumanService  # noqa: E402

FOREARM = 0.17  # metres of forearm kept behind the wrist; the rolled-up sleeve hides the cut
ARM_GROUPS = ("lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")

PHENOTYPE = {
    "gender": 1.0, "age": 0.85, "muscle": 0.55, "weight": 0.85, "proportions": 0.4, "height": 0.5,
    "cupsize": 0.5, "firmness": 0.35, "race": {"caucasian": 0.8, "asian": 0.15, "african": 0.05},
}
# Thick, short dayı fingers and meaty forearms.
TARGETS = {}
for _s in ("l", "r"):
    TARGETS.update({
        "%s-hand-fingers-diameter-incr" % _s: 0.8, "%s-hand-fingers-length-decr" % _s: 0.25,
        "%s-hand-scale-incr" % _s: 0.35, "%s-lowerarm-fat-incr" % _s: 0.7, "%s-lowerarm-muscle-incr" % _s: 0.3,
    })
TARGETS["measure-wrist-circ-incr"] = 0.6


def build_human():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    info = HumanService._create_default_human_info_dict()
    info["name"] = "fp_dayi"
    info["phenotype"] = PHENOTYPE
    info["targets"] = [{"target": k, "value": v} for k, v in TARGETS.items()]
    info["skin_mhmat"] = "old_caucasian_male/old_caucasian_male.mhmat"
    info["skin_material_type"] = "GAMEENGINE"
    info["rig"] = "game_engine"
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 1
    body = HumanService.deserialize_from_dict(info, settings)
    ExportService.bake_modifiers_remove_helpers(body, bake_masks=True, bake_subdiv=True)
    if body.data.shape_keys:
        bpy.context.view_layer.objects.active = body
        body.select_set(True)
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    return body.parent, body


def bone_head(rig, name):
    return rig.matrix_world @ rig.data.bones[name].head_local


def split_arm(rig, body, side):
    """Copies rig + body, keeps only this side's forearm and hand, and moves it into the hand's frame."""
    arm = rig.copy()
    arm.data = rig.data.copy()
    arm.name = "arm_" + side
    bpy.context.scene.collection.objects.link(arm)
    skin = body.copy()
    skin.data = body.data.copy()
    skin.name = "skin_" + side
    bpy.context.scene.collection.objects.link(skin)
    skin.parent = arm
    for mod in skin.modifiers:
        if mod.type == "ARMATURE":
            mod.object = arm

    wrist = bone_head(rig, "hand_" + side)
    elbow = bone_head(rig, "lowerarm_" + side)
    knuckle = bone_head(rig, "middle_01_" + side)
    across = (bone_head(rig, "index_01_" + side) - bone_head(rig, "pinky_01_" + side)).normalized()
    fingers = (knuckle - wrist).normalized()
    back = fingers.cross(across) if side == "r" else across.cross(fingers)
    up_arm = (elbow - wrist).normalized()

    # Keep vertices driven by this arm, up to FOREARM behind the wrist.
    world = skin.matrix_world
    bone_groups = {g.index for g in skin.vertex_groups if g.name in rig.data.bones}
    groups = {g for g in bone_groups if skin.vertex_groups[g].name.startswith(ARM_GROUPS)
              and skin.vertex_groups[g].name.endswith("_" + side)}
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    deform = bm.verts.layers.deform.active
    doomed = []
    for v in bm.verts:
        weights = v[deform]
        total = sum(w for g, w in weights.items() if g in bone_groups)
        ours = sum(w for g, w in weights.items() if g in groups)
        co = world @ v.co
        if total <= 0 or ours / total < 0.5 or (co - wrist).dot(up_arm) > FOREARM:
            doomed.append(v)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(skin.data)
    bm.free()

    # Rigidly move everything so the palm centre is the origin, fingers -Y, back of hand +Z.
    y = -fingers
    z = (back - y * back.dot(y)).normalized()
    x = y.cross(z)
    palm = wrist + (knuckle - wrist) * 0.45
    move = Matrix((x, y, z)).to_4x4() @ Matrix.Translation(-palm)
    skin.data.transform(move @ skin.matrix_world)
    skin.matrix_world = Matrix()
    skin.matrix_parent_inverse = Matrix()
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        eb.transform(move @ arm.matrix_world)
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.matrix_world = Matrix()
    print("ARM", side, "verts", len(skin.data.vertices), "hand head", arm.data.bones["hand_" + side].head_local,
          "lowerarm head", arm.data.bones["lowerarm_" + side].head_local)
    return arm, skin


# Relaxed resting curl per finger joint, in degrees (a hand lying on a table, not a flat A-pose hand).
CURL = {"index": (10, 14, 8), "middle": (12, 16, 9), "ring": (14, 18, 10), "pinky": (16, 20, 12)}
SPREAD_KEEP = 0.45  # how much of the A-pose finger spread survives


def relax(arm, skin, side):
    """Poses the fingers in a relaxed curl and makes that the rest pose, so the game only adds the grip."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bones = arm.pose.bones

    def rotate(name, matrix):
        pb = bones[name]
        h = pb.head.copy()
        pb.matrix = Matrix.Translation(h) @ matrix @ Matrix.Translation(-h) @ pb.matrix
        bpy.context.view_layer.update()

    middle_dir = (bones["middle_01_" + side].tail - bones["middle_01_" + side].head).normalized()
    for finger, curls in CURL.items():
        first = bones["%s_01_%s" % (finger, side)]
        d = (first.tail - first.head).normalized()
        # Close the spread toward the middle finger (rotation in the palm plane, around Z).
        spread = math.atan2(d.x, -d.y) - math.atan2(middle_dir.x, -middle_dir.y)
        rotate(first.name, Matrix.Rotation(-spread * (1.0 - SPREAD_KEEP), 4, "Z"))
        for j, degrees in enumerate(curls, 1):
            rotate("%s_0%d_%s" % (finger, j, side), Matrix.Rotation(math.radians(degrees), 4, "X"))
    # Thumb tucks in a little toward the index finger.
    sign = 1 if side == "r" else -1
    rotate("thumb_01_" + side, Matrix.Rotation(math.radians(-12 * sign), 4, "Z"))
    rotate("thumb_02_" + side, Matrix.Rotation(math.radians(10), 4, "X"))
    bpy.ops.object.mode_set(mode="OBJECT")

    # Bake the pose into the mesh, then make it the rest pose.
    mod = next(m for m in skin.modifiers if m.type == "ARMATURE")
    bpy.context.view_layer.objects.active = skin
    bpy.ops.object.modifier_apply(modifier=mod.name)
    new = skin.modifiers.new("Armature", "ARMATURE")
    new.object = arm
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def ring_radius(skin, arm, bone, at, axis):
    """Mean distance from the bone axis of the skin vertices around point `at`."""
    group = skin.vertex_groups.get(bone)
    dists = []
    for v in skin.data.vertices:
        if group is not None and not any(g.group == group.index and g.weight > 0.8 for g in v.groups):
            continue
        rel = v.co - at
        if abs(rel.dot(axis)) < 0.008:
            dists.append((rel - axis * rel.dot(axis)).length)
    dists.sort()
    return dists[len(dists) // 2] if dists else 0.01  # median ignores stray knuckle vertices


def attach(obj, arm, bone):
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def ring(arm, skin):
    b = arm.data.bones["ring_01_r"]
    axis = (b.tail_local - b.head_local).normalized()
    at = b.head_local + (b.tail_local - b.head_local) * 0.45
    r = ring_radius(skin, arm, "ring_01_r", at, axis)
    gold = material("gold", (0.95, 0.72, 0.3), 0.2, 1.0)
    obj = torus("ring_r", r + 0.0016, 0.0016, gold, None, location=at,
                rot=axis.to_track_quat("Z", "Y").to_euler(), segments=48, ring=10)
    attach(obj, arm, "ring_01_r")


def watch(arm, skin):
    b = arm.data.bones["lowerarm_l"]
    axis = (b.tail_local - b.head_local).normalized()  # toward the hand
    at = b.tail_local - axis * 0.035
    r = ring_radius(skin, arm, "lowerarm_l", at, axis)
    strap = material("strap", (0.16, 0.09, 0.05), 0.55)
    steel = material("steel", (0.82, 0.82, 0.84), 0.25, 1.0)
    dial = material("dial", (0.93, 0.9, 0.82), 0.3)
    rot = axis.to_track_quat("Z", "Y").to_euler()
    band = torus("watch_strap", r + 0.002, 0.0035, strap, None, location=at, rot=rot, segments=48, ring=8)
    band.scale = (1.0, 1.0, 2.4)  # flat, wide strap
    attach(band, arm, "lowerarm_l")
    up = Vector((0, 0, 1))
    case = lathe("watch_case", [(0, 0), (0.016, 0), (0.0172, 0.004), (0.0155, 0.0075), (0, 0.0075)], steel, None,
                 location=at + up * (r + 0.004), subdiv=0)
    face = lathe("watch_face", [(0, 0), (0.0132, 0), (0, 0.0004)], dial, None,
                 location=at + up * (r + 0.0118), subdiv=0)
    for part in (case, face):
        attach(part, arm, "lowerarm_l")


def sleeve(arm, skin, side):
    """Rolled-up shirt sleeve covering the forearm cut, plus the sleeve going on toward the elbow."""
    b = arm.data.bones["lowerarm_" + side]
    to_hand = (b.tail_local - b.head_local).normalized()
    wrist = b.tail_local
    at = wrist - to_hand * (FOREARM - 0.03)
    r = ring_radius(skin, arm, "lowerarm_" + side, at, to_hand)
    cloth = material("shirt", (0.88, 0.86, 0.8), 0.85)
    rot = (-to_hand).to_track_quat("Z", "Y").to_euler()
    roll = torus("sleeve_roll_" + side, r + 0.012, 0.012, cloth, None, location=at, rot=rot, segments=48, ring=12)
    roll.scale = (1.0, 1.0, 1.8)
    tube = lathe("sleeve_" + side, [(0, -0.01), (r + 0.006, -0.01), (r + 0.016, 0.06), (r + 0.024, 0.16), (0, 0.16)],
                 cloth, None, location=at, subdiv=1)
    tube.rotation_euler = rot
    for part in (roll, tube):
        attach(part, arm, "lowerarm_" + side)


def export(path):
    bpy.ops.object.select_all(action="DESELECT")
    for name in ("arm_r", "arm_l"):
        arm = bpy.data.objects[name]
        arm.select_set(True)
        for child in arm.children_recursive:
            child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_skins=True, export_animations=False, export_image_format="JPEG",
                              export_image_quality=90)
    print("EXPORTED", path)


def main():
    out = args()
    rig, body = build_human()
    arms = {side: split_arm(rig, body, side) for side in ("r", "l")}
    bpy.data.objects.remove(body)
    bpy.data.objects.remove(rig)
    for side, (arm, skin) in arms.items():
        relax(arm, skin, side)
    ring(*arms["r"])
    watch(*arms["l"])
    for side, (arm, skin) in arms.items():
        sleeve(arm, skin, side)
    if out:
        export(out[0])
    if len(out) > 1:
        # The preview camera looks along -Y, so the player's right is -X here.
        arms["r"][0].location = (-0.13, 0, 0)
        arms["l"][0].location = (0.13, 0, 0)
        bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, -0.025))
        render_preview(out[1], camera=(0.0, 0.42, 0.34), target=(0, -0.04, 0), lens=40)
        render_preview(out[1].replace(".png", "_side.png"), camera=(-0.55, -0.05, 0.06), target=(-0.13, 0.0, 0.0), lens=50)


main()
