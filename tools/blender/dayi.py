"""Builds the seated kahvehane dayı in Blender and exports it as glTF.

Run headless:
    blender -b --factory-startup -P tools/blender/dayi.py -- <out.glb> [preview.png]

Units are metres, origin at the seat contact point, facing -Y (glTF +Z after export).
Every customisable part is its own top-level node under "Dayi" (hat_*, mustache_*, hair_*, ...)
so the game can toggle and recolour parts for the character creator.
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
from kit import *  # noqa: E402,F403

COLORS = {
    "skin": SKIN,
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
ROUGHNESS = {"shoes": 0.4, "eye": 0.15}


def mat(name):
    return material(name, COLORS[name], ROUGHNESS.get(name, 0.6))


def on_head(center, radius, yaw_deg, pitch_deg, lift=0.0):
    """Point on the head sphere: yaw 0 = straight ahead (-Y), positive yaw to the character's left (+X)."""
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    return Vector(center) + d * (radius + lift)


def build():
    reset()
    root = empty("Dayi")

    head_c, head_r = (0, 0, 0.8), 0.24

    # Seated body: trousers, then belly/chest under a vest with a V opening.
    blob("trousers", [
        ball((0, 0.0, 0.08), 0.19, (1.0, 0.95, 0.6)),
        *[capsule((s * 0.1, -0.02, 0.07), (s * 0.11, -0.24, 0.07), 0.08) for s in (-1, 1)],
        *[capsule((s * 0.11, -0.26, 0.06), (s * 0.11, -0.27, -0.17), 0.075) for s in (-1, 1)],
    ], mat("trousers"), root)
    for s in (-1, 1):
        sphere("shoe_%s" % ("l" if s > 0 else "r"), (s * 0.11, -0.31, -0.22), 1.0, (0.075, 0.11, 0.05),
               mat("shoes"), root)

    torso = [ball((0, -0.04, 0.24), 0.23, (1.0, 0.95, 0.9)), ball((0, 0.0, 0.42), 0.2, (1.05, 0.85, 0.75))]
    blob("atlet", torso, mat("atlet"), root)
    vest = blob("vest", [dict(e, r=e["r"] * 1.06) for e in torso], mat("vest"), root)
    cutter = bpy.data.objects.new("vest_cut", bpy.data.meshes.new("vest_cut"))
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
               (1, 0.6, 1), mat("shoes"), root)

    # Arms resting forward on the table edge, ending in real chubby hands.
    arms = []
    for side in (-1, 1):
        shoulder, elbow, wrist = (side * 0.22, 0.0, 0.45), (side * 0.3, -0.06, 0.27), (side * 0.2, -0.3, 0.3)
        arms += [capsule(shoulder, elbow, 0.065), capsule(elbow, wrist, 0.058)]
        reach = Vector(wrist) - Vector(elbow)
        reach.z = 0
        palm = Vector(wrist) + reach.normalized() * 0.08 + Vector((0, 0, -0.012))
        hand("hand_" + ("l" if side > 0 else "r"), side, mat("skin"), root,
             Matrix.Translation(palm) @ frame(reach), chubby=1.1, scale=1.45)
    blob("arms", arms, mat("skin"), root)

    # Head: big round dome, ears and a bulbous nose all melted together.
    blob("head", [
        ball(head_c, head_r, (1.0, 0.95, 1.0)),
        ball((0, -0.03, 0.66), 0.17, (1.1, 0.9, 0.6)),  # jowls / chin
        *[ball((s * 0.24, -0.02, 0.78), 0.055, (0.5, 0.9, 1.1)) for s in (-1, 1)],
        ball(on_head(head_c, head_r, 0, -8, 0.0), 0.065, (1.05, 1.0, 0.95)),
    ], mat("skin"), root)

    for s in (-1, 1):
        side = "l" if s > 0 else "r"
        eye = on_head(head_c, head_r, s * 17, 8, -0.01)
        sphere("eye_" + side, eye, 1.0, (0.032, 0.02, 0.046), mat("eye"), root,
               rot=(0, 0, math.radians(s * 17)))
        sphere("eye_shine_" + side, eye + Vector((s * 0.008, -0.014, 0.016)), 0.011, (1, 1, 1), mat("shine"), root)

    # Customisable parts.
    blob("brows_bushy", [capsule(on_head(head_c, head_r, s * 8, 19, 0.01), on_head(head_c, head_r, s * 28, 21, 0.0), 0.024)
                         for s in (-1, 1)], mat("mustache"), root)
    blob("mustache_pala", [
        *[capsule(on_head(head_c, head_r, s * 4, -18, 0.04), on_head(head_c, head_r, s * 22, -24, 0.0), 0.034)
          for s in (-1, 1)],
        *[capsule(on_head(head_c, head_r, s * 22, -24, 0.0), on_head(head_c, head_r, s * 30, -40, -0.02), 0.026)
          for s in (-1, 1)],
    ], mat("mustache"), root)
    blob("hair_fringe", [ball(on_head(head_c, head_r, a, 14, -0.035), 0.055, (1, 1, 0.75))
                         for a in range(100, 261, 16)], mat("hair"), root)
    blob("hat_kasket", [
        ball((0, 0.01, 0.97), 0.25, (1.02, 1.05, 0.4)),
        ball((0, -0.2, 0.93), 0.15, (1.15, 0.65, 0.12), rot=(math.radians(-12), 0, 0)),
    ], mat("cap"), root)


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
    out = args()
    build()
    group_head()
    if out:
        export(out[0])
    if len(out) > 1:
        render_preview(out[1])


main()
