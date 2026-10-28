"""Builds the local player's first-person dayı hands (forearm, chubby fingers, gold ring, wristwatch).

    blender -b --factory-startup -P tools/blender/hands.py -- <out.glb> [preview.png]

Each hand is an empty ("hand_r", "hand_l") at the palm centre: fingers toward -Y, back of the hand +Z,
forearm running back along +Y toward the player.
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
from kit import *  # noqa: E402,F403


def build():
    reset()
    root = empty("Hands")
    skin = material("skin", SKIN, 0.55)
    gold = material("gold", (0.95, 0.72, 0.3), 0.25, 1.0)
    steel = material("steel", (0.8, 0.8, 0.82), 0.3, 1.0)
    strap = material("strap", (0.2, 0.12, 0.07), 0.6)
    dial = material("dial", (0.93, 0.9, 0.82), 0.3)

    for side, name in ((-1, "hand_r"), (1, "hand_l")):
        pivot = empty(name, root)
        hand(name, side, skin, pivot, chubby=1.12)
        blob(name + "_forearm", [capsule((0, 0.035, 0.004), (0, 0.32, 0.045), 0.034),
                                 ball((0, 0.13, 0.012), 0.04, (1.05, 1.6, 0.85))], skin, pivot, 0.006)
        if side < 0:
            # Gold ring on the ring finger, just past the knuckle.
            torus(name + "_ring", 0.0128, 0.0026, gold, pivot, location=(-0.0095 * 1.12, -0.062, 0.0),
                  rot=(math.pi / 2, 0, 0))
        else:
            wrist = (0, 0.05, 0.008)
            torus(name + "_watch_strap", 0.032, 0.006, strap, pivot, location=wrist, rot=(math.pi / 2, 0, 0))
            lathe(name + "_watch", [(0, 0), (0.016, 0), (0.017, 0.004), (0.015, 0.007), (0, 0.007)], steel, pivot,
                  location=(0, 0.05, 0.038), subdiv=0)
            lathe(name + "_watch_face", [(0, 0), (0.013, 0), (0, 0.0005)], dial, pivot,
                  location=(0, 0.05, 0.0452), subdiv=0)


def main():
    out = args()
    build()
    if out:
        export(out[0])
    if len(out) > 1:
        bpy.data.objects["hand_r"].location = (-0.12, 0, 0)
        bpy.data.objects["hand_l"].location = (0.12, 0, 0)
        render_preview(out[1], camera=(0.0, 0.45, 0.38), target=(0, -0.02, 0), lens=50)


main()
