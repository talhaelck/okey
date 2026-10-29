"""Generate the authentic Turkish Kahvehane (Kıraathane) interior for Okey Kıraathane.

Designed in Blender 5.2 with a classic 3-bay architectural layout:
- Left Bay (x = -2.18): Recessed 'ÇAY OCAĞI' alcove with Afyon marble counter,
  hammered copper exhaust hood (Bakır Davlumbaz), shelving, and two-teapot copper Semaver.
- Center Bay (x = 0.0): Kıraathane Wall of Honor (framed Turkish Flag & Motto spaces),
  octagonal walnut pendulum wall clock (Sarkaçlı Duvar Saati), Tavla rack, and
  traditional cast-iron coffeehouse stove (Döküm Soba & Borusu) with copper kettle (Güğüm).
- Right Bay (x = +2.15): Single grand arched Istanbul/Galata window flanked by
  pleated burgundy velvet drapes (Kadife Perdeler) + upper-right corner CRT TV (Tüplü TV)
  with rabbit-ear antennas and football match broadcast screen.
- Secondary kahvehane tables with green/burgundy baize (çuha), wooden spindle chairs,
  open Tavla (backgammon) boards, and classic green-enamel pendant lamps.
"""
from __future__ import annotations

import bmesh
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

def parse_root() -> str:
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1 :]
        if args:
            return os.path.abspath(args[0])
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)


def make_material(
    name: str,
    color: tuple[float, float, float],
    roughness: float = 0.5,
    metallic: float = 0.0,
    emission: tuple[float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission is not None and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def smooth_shaded(obj: bpy.types.Object) -> None:
    for poly in obj.data.polygons:
        poly.use_smooth = True


def export_glb(filepath: str) -> None:
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
    )


def v(x: float, y_up: float, z_back: float) -> Vector:
    return Vector((x, -z_back, y_up))


class MeshGroup:
    def __init__(self, material_key: str):
        self.material_key = material_key
        self.bm = bmesh.new()

    def box(self, sx: float, sy: float, sz: float, cx: float = 0.0, cy: float = 0.0, cz: float = 0.0, bevel: float = 0.0, yaw: float = 0.0):
        temp = bmesh.new()
        bmesh.ops.create_cube(temp, size=1.0)
        bmesh.ops.scale(temp, vec=(sx, sz, sy), verts=temp.verts)
        if bevel > 0.0:
            bmesh.ops.bevel(
                temp,
                geom=list(temp.verts) + list(temp.edges),
                offset=min(bevel, min(sx, sy, sz) * 0.32),
                segments=2,
                profile=0.5,
                affect='EDGES',
            )
        if abs(yaw) > 1e-5:
            bmesh.ops.rotate(temp, cent=(0, 0, 0), matrix=Matrix.Rotation(yaw, 3, 'Z'), verts=temp.verts)
        bmesh.ops.translate(temp, vec=v(cx, cy, cz), verts=temp.verts)
        self._merge(temp)

    def cylinder(self, r0: float, r1: float, h: float, cx: float = 0.0, cy: float = 0.0, cz: float = 0.0, segs: int = 24, axis: str = 'Y'):
        temp = bmesh.new()
        bmesh.ops.create_cone(temp, cap_ends=True, cap_tris=False, segments=segs, radius1=r0, radius2=r1, depth=h)
        if axis == 'X':
            bmesh.ops.rotate(temp, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'Y'), verts=temp.verts)
        elif axis == 'Z':
            bmesh.ops.rotate(temp, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'X'), verts=temp.verts)
        bmesh.ops.translate(temp, vec=v(cx, cy, cz), verts=temp.verts)
        self._merge(temp)

    def rod_between(self, p0: tuple[float, float, float], p1: tuple[float, float, float], r0: float, r1: float | None = None, segs: int = 16):
        if r1 is None:
            r1 = r0
        a = v(*p0)
        b = v(*p1)
        d = b - a
        length = d.length
        if length < 1e-5:
            return
        temp = bmesh.new()
        bmesh.ops.create_cone(temp, cap_ends=True, cap_tris=False, segments=segs, radius1=r0, radius2=r1, depth=length)
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_3x3()
        bmesh.ops.rotate(temp, cent=(0, 0, 0), matrix=rot, verts=temp.verts)
        bmesh.ops.translate(temp, vec=(a + b) * 0.5, verts=temp.verts)
        self._merge(temp)

    def lathe(self, points: list[tuple[float, float]], cx: float = 0.0, cy: float = 0.0, cz: float = 0.0, segs: int = 28):
        temp = bmesh.new()
        rings = []
        for rad, y_h in points:
            ring = []
            for s in range(segs):
                a = (s / segs) * math.tau
                ring.append(temp.verts.new(v(cx + math.cos(a) * rad, cy + y_h, cz + math.sin(a) * rad)))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for s in range(segs):
                sn = (s + 1) % segs
                try:
                    temp.faces.new((rings[i][s], rings[i][sn], rings[i + 1][sn], rings[i + 1][s]))
                except ValueError:
                    pass
        self._merge(temp)

    def _merge(self, temp: bmesh.types.BMesh):
        me = bpy.data.meshes.new("_tmp")
        temp.to_mesh(me)
        temp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def finish(self, name: str, mat: bpy.types.Material):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mat)
        smooth_shaded(obj)
        return obj


def build_materials() -> dict[str, bpy.types.Material]:
    return {
        "walnut": make_material("Walnut", (0.17, 0.10, 0.065), roughness=0.46),
        "mahogany": make_material("Mahogany", (0.24, 0.11, 0.068), roughness=0.42),
        "carved_wood": make_material("CarvedWood", (0.12, 0.072, 0.045), roughness=0.52),
        "floor_wood": make_material("FloorWood", (0.14, 0.088, 0.055), roughness=0.50),
        "plaster": make_material("Plaster", (0.43, 0.34, 0.24), roughness=0.86),
        "ceiling": make_material("Ceiling", (0.20, 0.14, 0.095), roughness=0.78),
        "brass": make_material("Brass", (0.76, 0.56, 0.25), roughness=0.26, metallic=0.86),
        "copper": make_material("Copper", (0.74, 0.39, 0.20), roughness=0.28, metallic=0.88),
        "dark_metal": make_material("DarkMetal", (0.11, 0.10, 0.095), roughness=0.40, metallic=0.80),
        "marble": make_material("Marble", (0.78, 0.74, 0.67), roughness=0.30),
        "velvet": make_material("Velvet", (0.40, 0.08, 0.09), roughness=0.84),
        "felt": make_material("Felt", (0.09, 0.28, 0.17), roughness=0.86),
        "enamel_green": make_material("EnamelGreen", (0.10, 0.32, 0.20), roughness=0.32, metallic=0.25),
        "cream": make_material("Cream", (0.86, 0.79, 0.66), roughness=0.65),
        "tile_blue": make_material("TileBlue", (0.14, 0.34, 0.44), roughness=0.34),
        "crt_screen": make_material(
            "CrtScreen",
            (0.16, 0.55, 0.26),
            roughness=0.18,
            emission=(0.22, 0.68, 0.34),
            emission_strength=1.8,
        ),
        "lantern_glass": make_material(
            "LanternGlass",
            (1.0, 0.74, 0.38),
            roughness=0.22,
            emission=(0.98, 0.62, 0.26),
            emission_strength=1.35,
        ),
        "bulb": make_material(
            "Bulb",
            (1.0, 0.82, 0.50),
            roughness=0.15,
            emission=(1.0, 0.70, 0.34),
            emission_strength=2.6,
        ),
        "night": make_material(
            "Night",
            (0.18, 0.24, 0.35),
            roughness=0.18,
            emission=(0.24, 0.28, 0.38),
            emission_strength=1.0,
        ),
    }


def add_kahvehane_chair(g: dict[str, MeshGroup], cx: float, cz: float, yaw: float):
    def local_pt(lx: float, ly: float, lz: float) -> tuple[float, float, float]:
        c, s = math.cos(yaw), math.sin(yaw)
        return (cx + lx * c - lz * s, ly, cz + lx * s + lz * c)

    # Turned wooden legs
    for lx in (-0.19, 0.19):
        for lz in (-0.19, 0.19):
            p0 = local_pt(lx, 0.0, lz)
            p1 = local_pt(lx * 0.92, 0.44, lz * 0.92)
            g["walnut"].rod_between(p0, p1, 0.020, 0.017, segs=12)
    # Bentwood / spindle stretchers
    for s_side in (-0.18, 0.18):
        g["walnut"].rod_between(local_pt(s_side, 0.15, -0.18), local_pt(s_side, 0.15, 0.18), 0.011, 0.011, 10)
        g["walnut"].rod_between(local_pt(-0.18, 0.15, s_side), local_pt(0.18, 0.15, s_side), 0.011, 0.011, 10)
    # Rounded wooden seat frame + burgundy cushion
    g["walnut"].box(0.43, 0.042, 0.43, cx, 0.44, cz, bevel=0.015, yaw=yaw)
    g["velvet"].box(0.38, 0.032, 0.38, cx, 0.468, cz, bevel=0.012, yaw=yaw)
    # Curved backrest uprights & spindles
    for lx in (-0.185, 0.185):
        g["walnut"].rod_between(local_pt(lx, 0.45, -0.185), local_pt(lx * 1.03, 0.88, -0.225), 0.019, 0.016, 12)
    for lx in (-0.11, -0.037, 0.037, 0.11):
        g["mahogany"].rod_between(local_pt(lx, 0.46, -0.185), local_pt(lx, 0.83, -0.22), 0.010, 0.009, 10)
    # Top crest rail
    crest = local_pt(0.0, 0.87, -0.225)
    g["mahogany"].box(0.42, 0.065, 0.035, crest[0], crest[1], crest[2], bevel=0.012, yaw=yaw)


def add_side_table_with_tavla(g: dict[str, MeshGroup], cx: float, cz: float, felt_key: str, with_tavla: bool = True):
    # Classic Turkish Kahvehane square wooden table with green/burgundy baize (çuha)
    g["walnut"].box(0.86, 0.055, 0.86, cx, 0.72, cz, bevel=0.018)
    g["mahogany"].box(0.76, 0.045, 0.76, cx, 0.675, cz, bevel=0.010)
    g[felt_key].box(0.76, 0.016, 0.76, cx, 0.748, cz, bevel=0.005)
    # Corner brass brackets
    for sx in (-0.41, 0.41):
        for sz in (-0.41, 0.41):
            g["brass"].box(0.045, 0.048, 0.045, cx + sx, 0.722, cz + sz, bevel=0.004)
    # 4 turned wooden legs
    for sx in (-0.35, 0.35):
        for sz in (-0.35, 0.35):
            g["walnut"].cylinder(0.022, 0.032, 0.70, cx + sx, 0.35, cz + sz, segs=14)
            g["brass"].cylinder(0.024, 0.025, 0.035, cx + sx, 0.018, cz + sz, segs=14)

    if with_tavla:
        # Open wooden Tavla (Backgammon) board on the table!
        tx, tz = cx + 0.04, cz + 0.02
        # Two hinged wooden halves
        for half in (-0.115, 0.115):
            g["carved_wood"].box(0.22, 0.028, 0.34, tx + half, 0.768, tz, bevel=0.004)
            g["cream"].box(0.195, 0.008, 0.31, tx + half, 0.781, tz, bevel=0.002)
            # Alternating dark/red points stripes
            for pt in range(6):
                pz = tz - 0.125 + pt * 0.050
                mat_k = "velvet" if pt % 2 == 0 else "carved_wood"
                g[mat_k].box(0.075, 0.004, 0.018, tx + half - 0.048, 0.786, pz)
                g[mat_k].box(0.075, 0.004, 0.018, tx + half + 0.048, 0.786, pz)
        # Brass hinges
        g["brass"].box(0.014, 0.030, 0.04, tx, 0.770, tz - 0.11)
        g["brass"].box(0.014, 0.030, 0.04, tx, 0.770, tz + 0.11)


def build(root: str) -> None:
    clear_scene()
    mats = build_materials()
    g = {k: MeshGroup(k) for k in mats}

    # =========================================================================
    # 1. FLOOR, WALLS, COFFERED CEILING & PILASTERS
    # =========================================================================
    # Floorboards with subtle plank grooves
    g["floor_wood"].box(7.0, 0.08, 6.6, 0.0, -0.04, 0.0)
    for i in range(-13, 14):
        g["carved_wood"].box(0.012, 0.004, 6.4, i * 0.25, 0.001, 0.0)

    # Outer Plaster Walls (Back, Front, Left, Right)
    g["plaster"].box(7.0, 3.35, 0.14, 0.0, 1.675, -3.18)
    g["plaster"].box(7.0, 3.35, 0.14, 0.0, 1.675, 3.18)
    g["plaster"].box(0.14, 3.35, 6.50, -3.45, 1.675, 0.0)
    g["plaster"].box(0.14, 3.35, 6.50, 3.45, 1.675, 0.0)

    # Ceiling & Coffered Walnut Beams
    g["ceiling"].box(7.0, 0.12, 6.6, 0.0, 3.34, 0.0)
    for bx in (-3.30, -1.12, 1.12, 3.30):
        g["walnut"].box(0.18, 0.18, 6.36, bx, 3.22, 0.0, bevel=0.012)
        g["mahogany"].box(0.22, 0.04, 6.38, bx, 3.13, 0.0, bevel=0.006)
    for bz in (-3.05, -1.52, 0.0, 1.52, 3.05):
        g["walnut"].box(6.80, 0.16, 0.18, 0.0, 3.23, bz, bevel=0.012)

    # Classic Turkish Kıraathane Ceviz Lambri (Wainscoting y = 0..1.05)
    # Back wall lambri
    g["walnut"].box(6.84, 1.02, 0.06, 0.0, 0.51, -3.10)
    g["mahogany"].box(6.88, 0.065, 0.095, 0.0, 1.04, -3.09, bevel=0.012)
    g["carved_wood"].box(6.88, 0.11, 0.08, 0.0, 0.055, -3.09, bevel=0.008)
    for i in range(-10, 11):
        px = i * 0.32
        g["mahogany"].box(0.24, 0.74, 0.025, px, 0.53, -3.065, bevel=0.008)
        g["carved_wood"].box(0.18, 0.66, 0.018, px, 0.53, -3.052, bevel=0.005)

    # Side walls lambri + İznik tile frieze border backing
    for side in (-1, 1):
        sx = side * 3.38
        g["walnut"].box(0.06, 1.02, 6.32, sx, 0.51, 0.0)
        g["mahogany"].box(0.095, 0.065, 6.36, sx - side * 0.01, 1.04, 0.0, bevel=0.012)
        g["carved_wood"].box(0.08, 0.11, 6.36, sx - side * 0.01, 0.055, 0.0, bevel=0.008)
        for iz in range(-9, 10):
            pz = iz * 0.32
            g["mahogany"].box(0.025, 0.74, 0.24, sx - side * 0.032, 0.53, pz, bevel=0.008)
            g["carved_wood"].box(0.018, 0.66, 0.18, sx - side * 0.042, 0.53, pz, bevel=0.005)
        # Upper crown cornice on side walls
        g["walnut"].box(0.14, 0.12, 6.36, sx - side * 0.02, 3.16, 0.0, bevel=0.012)

    # 4 Fluted Back-Wall Walnut Pilasters dividing the back wall into 3 grand bays:
    # Left Bay (-3.30 .. -1.12), Center Bay (-1.12 .. +1.12), Right Bay (+1.12 .. +3.30)
    for px in (-3.28, -1.12, 1.12, 3.28):
        g["walnut"].box(0.20, 3.18, 0.14, px, 1.59, -3.05, bevel=0.014)
        g["mahogany"].box(0.25, 0.16, 0.18, px, 0.08, -3.04, bevel=0.010)
        g["mahogany"].box(0.24, 0.11, 0.18, px, 1.05, -3.04, bevel=0.010)
        g["mahogany"].box(0.26, 0.18, 0.22, px, 3.06, -3.02, bevel=0.014)
        # Fluted vertical grooves
        for fl in (-0.05, 0.0, 0.05):
            g["carved_wood"].box(0.022, 1.82, 0.025, px + fl, 2.04, -2.975, bevel=0.004)

    # Side-wall pilasters at z = -1.52, 0.0, +1.52
    for side in (-1, 1):
        sx = side * 3.34
        for pz in (-1.52, 0.0, 1.52):
            g["walnut"].box(0.14, 3.18, 0.20, sx, 1.59, pz, bevel=0.014)
            g["mahogany"].box(0.18, 0.11, 0.24, sx, 1.05, pz, bevel=0.010)
            g["mahogany"].box(0.20, 0.18, 0.25, sx, 3.06, pz, bevel=0.014)

    # =========================================================================
    # 2. LEFT BAY (x = -2.20): AUTHENTIC "ÇAY OCAĞI" ALCOVE, COPPER HOOD & SEMAVER
    # =========================================================================
    cx_cay = -2.20
    # Tiled alcove backsplash (İznik blue & cream diamond/grid tiles)
    g["carved_wood"].box(1.94, 1.08, 0.04, cx_cay, 1.52, -3.07, bevel=0.008)
    g["cream"].box(1.84, 0.98, 0.02, cx_cay, 1.52, -3.05)
    for tx_i in range(-4, 5):
        for ty_i in range(3):
            if (tx_i + ty_i) % 2 == 0:
                g["tile_blue"].box(0.16, 0.16, 0.012, cx_cay + tx_i * 0.19, 1.18 + ty_i * 0.22, -3.038, bevel=0.003)

    # Two warm walnut shelves on the Çay Ocağı back wall for tea/sugar tins
    for sy in (1.22, 1.62):
        g["walnut"].box(1.72, 0.038, 0.24, cx_cay, sy, -2.94, bevel=0.006)
        for bx_off in (-0.68, 0.0, 0.68):
            g["brass"].box(0.025, 0.09, 0.18, cx_cay + bx_off, sy - 0.055, -2.96, bevel=0.003)

    # Çay Ocağı Marble & Walnut Service Counter (x = -3.12 .. -1.26, z = -2.46)
    g["walnut"].box(1.86, 0.90, 0.58, cx_cay, 0.45, -2.56, bevel=0.014)
    # Front decorative burgundy & mahogany panels on the counter
    for p_off in (-0.58, 0.0, 0.58):
        g["mahogany"].box(0.50, 0.66, 0.035, cx_cay + p_off, 0.46, -2.265, bevel=0.008)
        g["velvet"].box(0.40, 0.54, 0.020, cx_cay + p_off, 0.46, -2.250, bevel=0.005)
    # Afyon White/Cream Marble Countertop (Mermer Tezgah)
    g["marble"].box(1.94, 0.058, 0.66, cx_cay, 0.928, -2.55, bevel=0.012)
    g["brass"].box(1.96, 0.020, 0.68, cx_cay, 0.900, -2.55, bevel=0.004)
    # Brass foot rail in front of the Çay Ocağı counter
    g["brass"].cylinder(0.016, 0.016, 1.76, cx_cay, 0.14, -2.16, segs=16, axis='X')
    for f_off in (-0.76, 0.0, 0.76):
        g["brass"].cylinder(0.014, 0.014, 0.12, cx_cay + f_off, 0.14, -2.22, segs=12, axis='Z')

    # Hammered Copper Exhaust Hood (Bakır Davlumbaz) over the Çay Ocağı!
    # Vertical apron + trapezoidal hood rising to the ceiling
    g["copper"].box(1.92, 0.24, 0.64, cx_cay, 2.08, -2.56, bevel=0.014)
    g["brass"].box(1.96, 0.035, 0.67, cx_cay, 1.965, -2.56, bevel=0.006)
    g["brass"].box(1.96, 0.030, 0.67, cx_cay, 2.195, -2.56, bevel=0.006)
    # Recessed dark plaque on the front of the copper hood for "ÇAY OCAĞI" lettering
    g["carved_wood"].box(1.28, 0.16, 0.025, cx_cay, 2.08, -2.235, bevel=0.006)
    g["brass"].box(1.32, 0.18, 0.015, cx_cay, 2.08, -2.242, bevel=0.004)
    # Stepped pyramidal copper hood upper tiers & chimney duct
    g["copper"].box(1.66, 0.24, 0.54, cx_cay, 2.31, -2.61, bevel=0.014)
    g["copper"].box(1.36, 0.24, 0.44, cx_cay, 2.53, -2.66, bevel=0.014)
    g["copper"].box(0.88, 0.56, 0.34, cx_cay, 2.92, -2.72, bevel=0.010)
    g["brass"].box(0.94, 0.035, 0.38, cx_cay, 2.66, -2.72, bevel=0.005)

    # Large Traditional Kazanlı Bakır Semaver on the right side of the Çay Ocağı counter
    sx_sem, sy_sem, sz_sem = -1.52, 0.955, -2.54
    g["copper"].lathe(
        [
            (0.0, 0.0),
            (0.16, 0.0),
            (0.17, 0.04),
            (0.14, 0.08),
            (0.18, 0.14),
            (0.19, 0.42),
            (0.16, 0.48),
            (0.17, 0.52),
            (0.0, 0.52),
        ],
        sx_sem,
        sy_sem,
        sz_sem,
        segs=24,
    )
    g["brass"].cylinder(0.045, 0.045, 0.16, sx_sem, sy_sem + 0.58, sz_sem, segs=16)
    # Two teapots (Çift Demlik) on top of the Semaver
    for dx_off, dy_off, mat_d in ((-0.08, 0.53, "copper"), (0.08, 0.53, "cream")):
        g[mat_d].lathe(
            [
                (0.0, 0.0),
                (0.055, 0.0),
                (0.072, 0.05),
                (0.062, 0.12),
                (0.042, 0.15),
                (0.0, 0.165),
            ],
            sx_sem + dx_off,
            sy_sem + dy_off,
            sz_sem,
            segs=18,
        )
        g["brass"].cylinder(0.016, 0.008, 0.028, sx_sem + dx_off, sy_sem + dy_off + 0.175, sz_sem, segs=12)

    # =========================================================================
    # 3. CENTER BAY (x = 0.0): WALL OF HONOR, PENDULUM CLOCK & CAST-IRON STOVE
    # =========================================================================
    # Dado shelf & Wooden Gazetelik / Tavla Rack at center-left
    g["walnut"].box(0.84, 0.045, 0.22, -0.32, 1.12, -2.96, bevel=0.008)
    # Stacked closed Tavla boards on the shelf
    g["carved_wood"].box(0.44, 0.065, 0.18, -0.42, 1.175, -2.96, bevel=0.005)
    g["mahogany"].box(0.42, 0.060, 0.17, -0.40, 1.238, -2.96, bevel=0.005)

    # Octagonal/Arched Walnut Pendulum Wall Clock Case (Sarkaçlı Duvar Saati) at (-0.72, 2.02, -3.04)
    clk_x, clk_y, clk_z = -0.72, 2.02, -3.04
    g["walnut"].box(0.38, 0.68, 0.09, clk_x, clk_y - 0.08, clk_z, bevel=0.014)
    g["mahogany"].box(0.42, 0.06, 0.12, clk_x, clk_y + 0.27, clk_z, bevel=0.008)
    g["mahogany"].box(0.42, 0.06, 0.12, clk_x, clk_y - 0.43, clk_z, bevel=0.008)
    # Lower pendulum window & golden brass pendulum bob
    g["carved_wood"].box(0.24, 0.24, 0.02, clk_x, clk_y - 0.24, clk_z + 0.042, bevel=0.004)
    g["brass"].cylinder(0.005, 0.005, 0.18, clk_x, clk_y - 0.21, clk_z + 0.052, segs=10)
    g["brass"].cylinder(0.048, 0.048, 0.016, clk_x, clk_y - 0.29, clk_z + 0.055, segs=18, axis='Z')

    # Traditional Cast-Iron Turkish Kahvehane Stove (Döküm Soba & Borusu) at (+0.74, 0.0, -2.68)
    st_x, st_z = 0.74, -2.68
    # Scalloped brass hearth floor tray (Pirinç Soba Altlığı)
    g["brass"].cylinder(0.36, 0.38, 0.022, st_x, 0.011, st_z, segs=24)
    g["dark_metal"].cylinder(0.33, 0.34, 0.016, st_x, 0.022, st_z, segs=24)
    # 4 short cast-iron legs
    for sa in (0.25, 0.75, 1.25, 1.75):
        ang = sa * math.pi
        g["dark_metal"].cylinder(0.026, 0.018, 0.14, st_x + math.cos(ang) * 0.20, 0.08, st_z + math.sin(ang) * 0.20, segs=10)
    # Cast-iron cylindrical stove body with decorative brass rings
    g["dark_metal"].lathe(
        [
            (0.0, 0.14),
            (0.23, 0.14),
            (0.25, 0.20),
            (0.22, 0.26),
            (0.24, 0.62),
            (0.26, 0.68),
            (0.22, 0.74),
            (0.25, 0.88),
            (0.21, 0.94),
            (0.0, 0.95),
        ],
        st_x,
        0.0,
        st_z,
        segs=24,
    )
    g["brass"].cylinder(0.255, 0.255, 0.025, st_x, 0.22, st_z, segs=24)
    g["brass"].cylinder(0.258, 0.258, 0.025, st_x, 0.70, st_z, segs=24)
    g["brass"].cylinder(0.235, 0.235, 0.028, st_x, 0.93, st_z, segs=24)
    # Glowing fire-grate door on front of stove (+Z in game = toward players)
    g["brass"].box(0.18, 0.15, 0.04, st_x, 0.45, st_z + 0.23, bevel=0.006)
    g["lantern_glass"].box(0.13, 0.09, 0.025, st_x, 0.45, st_z + 0.245, bevel=0.003)
    for bar_x in (-0.035, 0.0, 0.035):
        g["dark_metal"].box(0.008, 0.095, 0.030, st_x + bar_x, 0.45, st_z + 0.248)
    # Tall black stovepipe (Soba Borusu) rising up and elbowing into the back wall
    g["dark_metal"].cylinder(0.062, 0.062, 1.82, st_x, 1.84, st_z - 0.06, segs=18)
    g["brass"].cylinder(0.068, 0.068, 0.025, st_x, 1.65, st_z - 0.06, segs=18)
    g["brass"].cylinder(0.068, 0.068, 0.025, st_x, 2.35, st_z - 0.06, segs=18)
    g["dark_metal"].cylinder(0.064, 0.064, 0.36, st_x, 2.74, st_z - 0.22, segs=18, axis='Z')
    g["brass"].cylinder(0.095, 0.095, 0.025, st_x, 2.74, -3.04, segs=20, axis='Z')
    # Copper/Brass Water Kettle (Güğüm) steaming on top of the stove!
    g["copper"].lathe(
        [
            (0.0, 0.95),
            (0.105, 0.95),
            (0.125, 1.02),
            (0.095, 1.12),
            (0.055, 1.18),
            (0.065, 1.22),
            (0.0, 1.23),
        ],
        st_x + 0.03,
        0.0,
        st_z + 0.04,
        segs=20,
    )

    # =========================================================================
    # 4. RIGHT BAY (x = +2.15): ARCHED ISTANBUL WINDOW, VELVET DRAPES & CRT TV
    # =========================================================================
    wx, wz = 2.15, -3.05
    # Window Sill & Outer Walnut Frame
    g["walnut"].box(1.52, 0.07, 0.22, wx, 1.06, -2.98, bevel=0.012)
    g["walnut"].box(0.11, 1.56, 0.14, wx - 0.68, 1.84, wz, bevel=0.010)
    g["walnut"].box(0.11, 1.56, 0.14, wx + 0.68, 1.84, wz, bevel=0.010)
    g["walnut"].box(1.46, 0.12, 0.14, wx, 2.62, wz, bevel=0.012)
    g["mahogany"].box(1.26, 0.09, 0.15, wx, 2.71, wz, bevel=0.010)

    # Glowing Istanbul Night/Dusk Window Glass Pane (Interior_night -> coffeehouse_window.gdshader)
    g["night"].box(1.26, 1.48, 0.018, wx, 1.84, -3.06)

    # Classic Turkish Wooden Window Muntins (Ahşap Pencere Kayıtları)
    g["walnut"].box(0.042, 1.48, 0.045, wx, 1.84, -3.04, bevel=0.005)
    g["walnut"].box(1.26, 0.042, 0.045, wx, 1.84, -3.04, bevel=0.005)
    g["walnut"].box(1.26, 0.036, 0.042, wx, 2.24, -3.04, bevel=0.005)

    # Brass Curtain Rod & Pleated Burgundy Kahvehane Drapes (Kadife Perdeler)
    g["brass"].cylinder(0.018, 0.018, 1.78, wx, 2.82, -2.92, segs=16, axis='X')
    for finial_s in (-0.91, 0.91):
        g["brass"].cylinder(0.032, 0.012, 0.06, wx + finial_s, 2.82, -2.92, segs=14, axis='X')
    # Top pleated valance (Korniş Fırfırı)
    g["velvet"].box(1.66, 0.16, 0.08, wx, 2.74, -2.93, bevel=0.015)
    # Left & Right draped curtain panels tied back with brass/gold tassels
    for c_side in (-1, 1):
        cx_drape = wx + c_side * 0.64
        for pleat in (-0.07, 0.0, 0.07):
            g["velvet"].cylinder(0.048, 0.056, 1.72, cx_drape + pleat, 1.92, -2.93, segs=12)
        # Golden tie-back band
        g["brass"].cylinder(0.088, 0.088, 0.042, cx_drape, 1.62, -2.93, segs=16)

    # Corner Bracket & Vintage Wooden Tüplü CRT TV (Upper-Right Corner: x = 2.98, y = 2.48, z = -2.64)
    tv_x, tv_y, tv_z = 2.98, 2.48, -2.64
    tv_yaw = -0.56
    fn_x, fn_z = math.sin(tv_yaw), math.cos(tv_yaw)
    rt_x, rt_z = math.cos(tv_yaw), -math.sin(tv_yaw)
    g["walnut"].box(0.58, 0.045, 0.44, tv_x, tv_y - 0.21, tv_z, bevel=0.008, yaw=tv_yaw)
    g["dark_metal"].box(0.05, 0.22, 0.34, tv_x - 0.12 * fn_x, tv_y - 0.32, tv_z - 0.12 * fn_z, bevel=0.004, yaw=tv_yaw)
    # Wooden CRT TV Cabinet
    g["mahogany"].box(0.54, 0.40, 0.36, tv_x, tv_y, tv_z, bevel=0.018, yaw=tv_yaw)
    g["carved_wood"].box(0.50, 0.36, 0.04, tv_x + 0.165 * fn_x, tv_y, tv_z + 0.165 * fn_z, bevel=0.010, yaw=tv_yaw)
    # Glowing Green Football Match Broadcast Screen + White Pitch Lines!
    scr_x = tv_x + 0.184 * fn_x - 0.04 * rt_x
    scr_z = tv_z + 0.184 * fn_z - 0.04 * rt_z
    g["crt_screen"].box(0.36, 0.28, 0.018, scr_x, tv_y + 0.01, scr_z, bevel=0.006, yaw=tv_yaw)
    # White football pitch center line & touchlines on screen
    g["cream"].box(0.008, 0.24, 0.006, scr_x + 0.011 * fn_x, tv_y + 0.01, scr_z + 0.011 * fn_z, yaw=tv_yaw)
    g["cream"].box(0.32, 0.008, 0.006, scr_x + 0.011 * fn_x, tv_y + 0.11, scr_z + 0.011 * fn_z, yaw=tv_yaw)
    g["cream"].box(0.32, 0.008, 0.006, scr_x + 0.011 * fn_x, tv_y - 0.09, scr_z + 0.011 * fn_z, yaw=tv_yaw)
    # Control panel knobs on the right of the CRT screen
    for ky_off in (0.07, 0.0, -0.07):
        kx = tv_x + 0.186 * fn_x + 0.19 * rt_x
        kz = tv_z + 0.186 * fn_z + 0.19 * rt_z
        g["brass"].box(0.032, 0.032, 0.020, kx, tv_y + ky_off, kz, bevel=0.005, yaw=tv_yaw)
    # Rabbit-ear V-antennas on top of the TV
    g["brass"].cylinder(0.045, 0.055, 0.03, tv_x, tv_y + 0.21, tv_z, segs=14)
    g["brass"].rod_between((tv_x, tv_y + 0.22, tv_z), (tv_x - 0.18, tv_y + 0.50, tv_z + 0.08), 0.005, 0.003, 8)
    g["brass"].rod_between((tv_x, tv_y + 0.22, tv_z), (tv_x + 0.14, tv_y + 0.48, tv_z - 0.10), 0.005, 0.003, 8)

    # =========================================================================
    # 5. HERO PENDANT LAMP, SIDE PENDANTS, WALL SCONCES & SECONDARY TABLES
    # =========================================================================
    # Central Okey Table Brass & Dark-Bronze Pendant Lamp (x = 0, z = 0)
    g["brass"].cylinder(0.075, 0.095, 0.05, 0.0, 3.26, 0.0, segs=20)
    g["dark_metal"].cylinder(0.014, 0.014, 1.18, 0.0, 2.66, 0.0, segs=14)
    g["brass"].lathe(
        [
            (0.04, 2.12),
            (0.08, 2.08),
            (0.06, 2.02),
            (0.22, 1.96),
            (0.35, 1.88),
            (0.38, 1.84),
            (0.34, 1.84),
            (0.20, 1.93),
            (0.0, 1.95),
        ],
        0.0,
        0.0,
        0.0,
        segs=28,
    )
    g["bulb"].cylinder(0.11, 0.13, 0.045, 0.0, 1.86, 0.0, segs=20)

    # 2 Classic Green-Enamel Kahvehane Pendant Lamps over the background side tables
    for side in (-1, 1):
        lx, lz = side * 2.35, -1.42
        g["brass"].cylinder(0.05, 0.06, 0.04, lx, 3.26, lz, segs=16)
        g["dark_metal"].cylinder(0.009, 0.009, 1.24, lx, 2.63, lz, segs=12)
        g["brass"].cylinder(0.038, 0.052, 0.055, lx, 2.02, lz, segs=16)
        g["enamel_green"].lathe(
            [
                (0.042, 2.00),
                (0.15, 1.94),
                (0.22, 1.87),
                (0.23, 1.85),
                (0.20, 1.85),
                (0.0, 1.95),
            ],
            lx,
            0.0,
            lz,
            segs=22,
        )
        g["bulb"].cylinder(0.06, 0.07, 0.035, lx, 1.86, lz, segs=16)

    # 4 Brass & Amber Lantern Wall Sconces mounted directly on the 4 back-wall pilasters
    for sx in (-3.28, -1.12, 1.12, 3.28):
        g["brass"].box(0.09, 0.18, 0.03, sx, 2.12, -2.97, bevel=0.005)
        g["brass"].rod_between((sx, 2.14, -2.96), (sx, 2.18, -2.82), 0.012, 0.010, 10)
        g["brass"].cylinder(0.068, 0.045, 0.035, sx, 2.18, -2.81, segs=14)
        g["lantern_glass"].cylinder(0.048, 0.038, 0.12, sx, 2.10, -2.81, segs=14)
        g["brass"].cylinder(0.042, 0.015, 0.03, sx, 2.03, -2.81, segs=14)

    # 4 Main Okey Table Chairs (for the 4 players at radius ~1.18)
    main_seats = [
        (0.0, 1.22, math.pi),        # South (local player)
        (1.28, 0.0, -math.pi * 0.5), # East (Sabri Dayı)
        (0.0, -1.22, 0.0),           # North (Temel Reis)
        (-1.28, 0.0, math.pi * 0.5), # West (Rıfkı)
    ]
    for cx, cz, yaw in main_seats:
        add_kahvehane_chair(g, cx, cz, yaw)

    # Background & Foreground Side Kahvehane Tables with Tavla boards & chairs
    for side in (-1, 1):
        # Back-side tables (visible behind left/right players)
        tx, tz = side * 2.35, -1.42
        add_side_table_with_tavla(g, tx, tz, "felt" if side < 0 else "velvet", with_tavla=True)
        add_kahvehane_chair(g, tx - side * 0.56, tz, side * math.pi * 0.5)
        add_kahvehane_chair(g, tx, tz - 0.56, 0.0)

        # Foreground corner tables (visible in menu / wide shots)
        fx, fz = side * 2.48, 1.95
        add_side_table_with_tavla(g, fx, fz, "velvet" if side < 0 else "felt", with_tavla=False)
        add_kahvehane_chair(g, fx - side * 0.55, fz, side * math.pi * 0.5)

    for key, group in g.items():
        group.finish(f"Interior_{key}", mats[key])

    export_glb(os.path.join(root, "assets", "models", "environment", "muhabbet_interior.glb"))


if __name__ == "__main__":
    build(parse_root())
