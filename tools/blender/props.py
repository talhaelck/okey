"""Builds the Turkish kahvehane props and exports one glb per prop into a folder:
tea_set.glb (ince belli bardak, tea, saucer, spoon, sugar), tespih.glb, semaver.glb.

    blender -b --factory-startup -P tools/blender/props.py -- <out dir> [preview.png]

Origins sit on the surface the prop rests on.
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
from kit import *  # noqa: E402,F403

GLASS = [(0, 0.0), (0.021, 0.0), (0.023, 0.004), (0.02, 0.012), (0.017, 0.035), (0.0175, 0.05), (0.022, 0.075),
         (0.0255, 0.098), (0.0262, 0.1), (0.0245, 0.1), (0.0238, 0.098), (0.0207, 0.075), (0.0158, 0.05),
         (0.015, 0.035), (0.0175, 0.012), (0.0, 0.009)]
TEA = [(0, 0.0095), (0.0172, 0.0125), (0.0148, 0.035), (0.0155, 0.05), (0.0202, 0.075), (0.0218, 0.085), (0, 0.085)]


def tea_set(root):
    glass = material("glass", (0.92, 0.95, 0.95), 0.03, 0.0, 0.12)
    tea = material("tea", (0.3, 0.04, 0.008), 0.05)
    porcelain = material("porcelain", (0.96, 0.95, 0.92), 0.2)
    red = material("rim_red", (0.65, 0.07, 0.06), 0.35)
    gold = material("gold", (0.95, 0.72, 0.3), 0.25, 1.0)
    silver = material("silver", (0.85, 0.85, 0.87), 0.2, 1.0)
    sugar = material("sugar", (0.97, 0.97, 0.95), 0.9)

    lathe("saucer", [(0, 0), (0.035, 0), (0.05, 0.004), (0.058, 0.011), (0.0575, 0.0125), (0.049, 0.007),
                     (0.025, 0.005), (0, 0.005)], porcelain, root)
    torus("saucer_rim", 0.0573, 0.0016, red, root, location=(0, 0, 0.0115))
    torus("saucer_gold", 0.045, 0.0009, gold, root, location=(0, 0, 0.0068))
    lathe("tea", TEA, tea, root, location=(0, 0, 0.005))
    lathe("tea_glass", GLASS, glass, root, location=(0, 0, 0.005))
    # Teaspoon resting on the saucer, two sugar cubes beside the glass.
    spoon = empty("spoon", root, (0.035, -0.008, 0.012))
    spoon.rotation_euler = (0, -0.12, math.radians(-25))
    blob("spoon_handle", [capsule((-0.045, 0, 0), (0.02, 0, 0.002), 0.0022)], silver, spoon, 0.0012)
    sphere("spoon_bowl", (0.03, 0, 0.003), 1.0, (0.009, 0.0065, 0.0022), silver, spoon)
    for i, (x, y, yaw) in enumerate(((-0.036, 0.02, 0.3), (-0.028, 0.034, 1.0))):
        cube = box("sugar_%d" % i, (0.011, 0.011, 0.011), sugar, root, (x, y, 0.0105), bevel=0.0012)
        cube.rotation_euler = (0, 0, yaw)


def tespih(root):
    amber = material("amber", (0.85, 0.42, 0.05), 0.15, 0.0, 0.92)
    tassel = material("tassel", (0.55, 0.06, 0.05), 0.8)
    silver = material("silver", (0.85, 0.85, 0.87), 0.2, 1.0)
    bead_r = 0.0058
    # 33 beads in a loose loop lying on the table, opening toward +Y where the imame hangs.
    for i in range(33):
        a = math.radians(-60 + 300 * i / 32)
        sphere("bead_%02d" % i, (math.cos(a) * 0.06, math.sin(a) * 0.045, bead_r), bead_r, (1, 1, 1), amber, root,
               segments=16)
    start = Vector((math.cos(math.radians(-60)) * 0.06, math.sin(math.radians(-60)) * 0.045, bead_r))
    tail = start + Vector((0.018, -0.03, 0))
    blob("imame", [capsule(start + Vector((0.004, -0.006, 0)), tail, 0.0055)], amber, root, 0.002)
    torus("imame_cap", 0.004, 0.0012, silver, root, location=tail + Vector((0.002, -0.003, 0)), rot=(0, math.pi / 2, 0.6))
    for k in range(7):
        a = -0.5 + k * 0.17
        tip = tail + Vector((math.sin(a) * 0.025 + 0.012, -0.035, -0.003))
        blob("tassel_%d" % k, [capsule(tail + Vector((0.003, -0.005, 0)), tip, 0.0012)], tassel, root, 0.0008)


def semaver(root):
    brass = material("brass", (0.86, 0.62, 0.27), 0.28, 1.0)
    dark = material("dark_metal", (0.12, 0.1, 0.09), 0.5, 1.0)
    porcelain = material("porcelain", (0.96, 0.95, 0.92), 0.2)
    pattern = material("rim_red", (0.65, 0.07, 0.06), 0.35)
    lathe("semaver_body", [(0, 0), (0.1, 0), (0.105, 0.015), (0.06, 0.05), (0.06, 0.08), (0.12, 0.13),
                           (0.14, 0.24), (0.13, 0.34), (0.085, 0.4), (0.07, 0.43), (0.075, 0.45), (0.0, 0.455)],
          brass, root)
    for s in (-1, 1):
        torus("semaver_handle_%d" % (s > 0), 0.045, 0.008, dark, root, location=(s * 0.13, 0, 0.3),
              rot=(math.pi / 2, 0, math.pi / 2 if s > 0 else -math.pi / 2), arc=math.pi)
    blob("semaver_tap", [capsule((0, -0.12, 0.13), (0, -0.19, 0.12), 0.012),
                         capsule((0, -0.19, 0.12), (0, -0.2, 0.09), 0.009)], brass, root, 0.003)
    sphere("semaver_tap_key", (0, -0.17, 0.145), 0.014, (1, 0.5, 1), dark, root)
    # Porcelain demlik (teapot) on the crown.
    lathe("demlik", [(0, 0), (0.045, 0), (0.07, 0.04), (0.068, 0.08), (0.045, 0.11), (0.03, 0.115),
                     (0.035, 0.125), (0.012, 0.135), (0.014, 0.145), (0, 0.15)], porcelain, root,
          location=(0, 0, 0.455))
    torus("demlik_band", 0.0705, 0.003, pattern, root, location=(0, 0, 0.5))
    blob("demlik_spout", [capsule((0, -0.06, 0.48), (0, -0.11, 0.53), 0.011),
                          capsule((0, -0.11, 0.53), (0, -0.125, 0.55), 0.008)], porcelain, root, 0.003)
    torus("demlik_handle", 0.035, 0.007, porcelain, root, location=(0, 0.065, 0.51), rot=(math.pi / 2, 0, math.pi / 2),
          arc=math.pi)


BUILDERS = {"tea_set": tea_set, "tespih": tespih, "semaver": semaver}


def main():
    out = args()
    for name, build in BUILDERS.items():
        reset()
        build(empty(name))
        if out:
            export(os.path.join(out[0], name + ".glb"))
    if len(out) > 1:
        reset()
        for name, build, at in (("tea_set", tea_set, (0, 0, 0)), ("tespih", tespih, (0.17, -0.02, 0)),
                                ("semaver", semaver, (-0.3, 0.12, 0))):
            build(empty(name, location=at))
        render_preview(out[1], camera=(0.15, -0.75, 0.42), target=(-0.06, 0, 0.13), lens=50)


main()
