"""Continuous organic sculpted 3D Turkish coffeehouse characters (Dayilar) for Blender 5.2.

Built with continuous Catmull-Rom surface lofting and analytical ZBrush-style Gaussian facial sculpting:
- Single seamless HeadSculpt with rounded U-jawline, soft double-chin fold, tucked nape, plump smiling
  cheek apples, recessed eye sockets, expressive brow ridges, and nasolabial smile creases.
- Expressive recessed eyes with upper/lower eyelids, arched eyebrows, bulbous Turkish nose with nostrils,
  continuous 1-piece swept pala mustache, warm smile with upper teeth & lower lip, and skull-hugging hair.
- Broad seamless shoulders, natural inward-angled forearms, and meaty anatomical hands (with watch, ruby ring,
  or tespih) plus one-piece seated legs with slippers or classic leather loafers.
"""
from __future__ import annotations

import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector


def parse_out_dir() -> Path:
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1 :]
        if args:
            return Path(args[0]).resolve()
    return Path(__file__).resolve().parents[2] / "assets" / "models" / "patrons"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        bpy.data.materials.remove(block)
    for block in list(bpy.data.curves):
        bpy.data.curves.remove(block)


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(
    name: str,
    color: tuple[float, float, float],
    roughness: float = 0.58,
    metallic: float = 0.0,
    alpha: float = 1.0,
) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    lin = (srgb_to_lin(color[0]), srgb_to_lin(color[1]), srgb_to_lin(color[2]), 1.0)
    bsdf.inputs["Base Color"].default_value = lin
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.26
    if alpha < 1.0:
        if "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "blend_method"):
            m.blend_method = "BLEND"
    return m


def v(pos: tuple[float, float, float]) -> Vector:
    return Vector((pos[0], -pos[2], pos[1]))


def empty(
    name: str,
    pos: tuple[float, float, float] = (0.0, 0.0, 0.0),
    parent: bpy.types.Object | None = None,
) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.location = v(pos)
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def make_obj(
    name: str,
    bm: bmesh.types.BMesh,
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    subsurf: int = 1,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    if subsurf > 0:
        mod = obj.modifiers.new("Subsurf", "SUBSURF")
        mod.levels = subsurf
        mod.render_levels = subsurf
    return obj


def catmull_rom(p0: Vector, p1: Vector, p2: Vector, p3: Vector, t: float) -> Vector:
    t2 = t * t
    t3 = t2 * t
    return 0.5 * (
        (2.0 * p1)
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )


def add_ellipsoid(
    name: str,
    center: tuple[float, float, float],
    radii: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    segs: int = 28,
    rings: int = 20,
    subsurf: int = 1,
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    rot = (
        Matrix.Rotation(math.radians(rot_deg[0]), 4, "X")
        @ Matrix.Rotation(math.radians(rot_deg[2]), 4, "Y")
        @ Matrix.Rotation(math.radians(rot_deg[1]), 4, "Z")
    )
    c = v(center)
    rx, ry_height, rz_depth = radii[0], radii[1], radii[2]
    for vert in bm.verts:
        vert.co = c + (rot @ Vector((vert.co.x * rx, vert.co.y * rz_depth, vert.co.z * ry_height)))
    return make_obj(name, bm, material, parent, subsurf=subsurf)


def rounded_box(
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.004,
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vert in bm.verts:
        vert.co.x *= size[0]
        vert.co.y *= size[2]
        vert.co.z *= size[1]
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
    rot = (
        Matrix.Rotation(math.radians(rot_deg[0]), 4, "X")
        @ Matrix.Rotation(math.radians(rot_deg[2]), 4, "Y")
        @ Matrix.Rotation(math.radians(rot_deg[1]), 4, "Z")
    )
    c = v(center)
    for vert in bm.verts:
        vert.co = c + (rot @ vert.co)
    return make_obj(name, bm, material, parent, subsurf=0)


def spline_tube(
    name: str,
    points_and_radii: list[tuple[tuple[float, float, float], float | tuple[float, float]]],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    segs_ring: int = 20,
    steps_per_seg: int = 6,
    fixed_up: Vector | None = None,
    subsurf: int = 1,
    cap_ends: bool = True,
) -> bpy.types.Object:
    bm = bmesh.new()
    pts = [v(p[0]) for p in points_and_radii]
    rads = [p[1] if isinstance(p[1], tuple) else (p[1], p[1]) for p in points_and_radii]
    n = len(pts)
    samples = []
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(n - 1, i + 2)]
        r0, r1 = rads[i], rads[i + 1]
        cnt = steps_per_seg if i < n - 2 else steps_per_seg + 1
        for s in range(cnt):
            t = s / float(steps_per_seg)
            pos = catmull_rom(p0, p1, p2, p3, t)
            samples.append((pos, r0[0] + (r1[0] - r0[0]) * t, r0[1] + (r1[1] - r0[1]) * t))
    rings = []
    prev_nrm = Vector((0.0, 0.0, 1.0))
    for idx, (pos, rx, ry) in enumerate(samples):
        tan = (samples[min(len(samples) - 1, idx + 1)][0] - samples[max(0, idx - 1)][0]).normalized()
        if fixed_up is not None:
            up = fixed_up
            binrm = tan.cross(up)
            if binrm.length < 1e-4:
                binrm = Vector((1.0, 0.0, 0.0))
            binrm.normalize()
            nrm = binrm.cross(tan).normalized()
        else:
            nrm = prev_nrm - tan * prev_nrm.dot(tan)
            if nrm.length < 1e-4:
                nrm = Vector((0.0, 0.0, 1.0)).cross(tan)
            nrm.normalize()
            binrm = tan.cross(nrm).normalized()
            prev_nrm = nrm
        ring = [
            bm.verts.new(
                pos
                + binrm * (math.cos(k * math.tau / segs_ring) * rx)
                + nrm * (math.sin(k * math.tau / segs_ring) * ry)
            )
            for k in range(segs_ring)
        ]
        rings.append(ring)
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for k in range(segs_ring):
            kn = (k + 1) % segs_ring
            bm.faces.new((r0[k], r0[kn], r1[kn], r1[k]))
    if cap_ends:
        for idx, flip in ((0, True), (-1, False)):
            ring = rings[idx]
            c_vert = bm.verts.new(sum((vt.co for vt in ring), Vector((0.0, 0.0, 0.0))) / len(ring))
            for k in range(segs_ring):
                kn = (k + 1) % segs_ring
                bm.faces.new((ring[kn], ring[k], c_vert) if flip else (ring[k], ring[kn], c_vert))
    return make_obj(name, bm, material, parent, subsurf=subsurf)


def loft_garment(
    name: str,
    sections: list[tuple[float, float, float, float, float, float]],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    sides: int = 48,
    open_front_angle: float = 0.0,
    thickness: float = 0.018,
    u_neck_depth: float = 0.0,
) -> bpy.types.Object:
    bm = bmesh.new()
    pts = [Vector(s) for s in sections]
    n = len(pts)
    samples = []
    steps = 4
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(n - 1, i + 2)]
        cnt = steps if i < n - 2 else steps + 1
        for s in range(cnt):
            samples.append(catmull_rom(p0, p1, p2, p3, s / float(steps)))
    outer_rings, inner_rings = [], []
    is_open = open_front_angle > 0.001
    count = sides + 1 if is_open else sides
    top_y = sections[-1][0]
    for s_vec in samples:
        y_h, rx, rz_f, rz_b, x_off, z_off = s_vec[0], s_vec[1], s_vec[2], s_vec[3], s_vec[4], s_vec[5]
        o_ring, i_ring = [], []
        for k in range(count):
            if is_open:
                half = open_front_angle * 0.5
                ang = half + (k / float(sides)) * (math.tau - open_front_angle)
            else:
                ang = (k / float(sides)) * math.tau
            ca, sa = math.cos(ang), math.sin(ang)
            rz = 0.5 * (rz_f + rz_b) + 0.5 * (rz_f - rz_b) * ca
            y_cur = y_h
            if u_neck_depth > 0.0 and ca > 0.25 and y_h > top_y - 0.18:
                t_top = max(0.0, (y_h - (top_y - 0.18)) / 0.18)
                y_cur -= u_neck_depth * (t_top**1.5) * ((ca - 0.25) / 0.75) ** 1.6
            ox = x_off + sa * rx
            oz = z_off - ca * rz
            o_ring.append(bm.verts.new(v((ox, y_cur, oz))))
            if is_open:
                ix = x_off + sa * max(0.02, rx - thickness)
                iz = z_off - ca * max(0.02, rz - thickness)
                i_ring.append(bm.verts.new(v((ix, y_cur, iz))))
        outer_rings.append(o_ring)
        if is_open:
            inner_rings.append(i_ring)
    for i in range(len(outer_rings) - 1):
        r0, r1 = outer_rings[i], outer_rings[i + 1]
        for k in range(count - 1 if is_open else sides):
            kn = k + 1 if is_open else (k + 1) % sides
            bm.faces.new((r0[k], r0[kn], r1[kn], r1[k]))
    if is_open:
        for i in range(len(inner_rings) - 1):
            r0, r1 = inner_rings[i], inner_rings[i + 1]
            for k in range(count - 1):
                kn = k + 1
                bm.faces.new((r0[kn], r0[k], r1[k], r1[kn]))
        for i in range(len(outer_rings) - 1):
            bm.faces.new((outer_rings[i][0], outer_rings[i + 1][0], inner_rings[i + 1][0], inner_rings[i][0]))
            bm.faces.new((outer_rings[i + 1][-1], outer_rings[i][-1], inner_rings[i][-1], inner_rings[i + 1][-1]))
        for k in range(count - 1):
            kn = k + 1
            bm.faces.new((outer_rings[0][kn], outer_rings[0][k], inner_rings[0][k], inner_rings[0][kn]))
            bm.faces.new((outer_rings[-1][k], outer_rings[-1][kn], inner_rings[-1][kn], inner_rings[-1][k]))
    else:
        for idx, flip in ((0, True), (-1, False)):
            ring = outer_rings[idx]
            c_vert = bm.verts.new(sum((vt.co for vt in ring), Vector((0.0, 0.0, 0.0))) / len(ring))
            for k in range(sides):
                kn = (k + 1) % sides
                bm.faces.new((ring[kn], ring[k], c_vert) if flip else (ring[k], ring[kn], c_vert))
    return make_obj(name, bm, material, parent, subsurf=1)


def palette() -> dict[str, bpy.types.Material]:
    return {
        "skin": mat("patron_skin", (0.83, 0.59, 0.45), 0.52),
        "skin_warm": mat("patron_skin_warm", (0.80, 0.54, 0.41), 0.52),
        "nose": mat("patron_nose", (0.82, 0.49, 0.39), 0.48),
        "lip": mat("patron_lip", (0.68, 0.38, 0.33), 0.50),
        "mouth_dark": mat("patron_mouth_dark", (0.14, 0.05, 0.05), 0.88),
        "teeth": mat("patron_teeth", (0.92, 0.90, 0.84), 0.28),
        "eye_white": mat("patron_eye_white", (0.94, 0.92, 0.88), 0.20),
        "iris_brown": mat("patron_iris_brown", (0.25, 0.13, 0.06), 0.18),
        "pupil": mat("patron_pupil", (0.03, 0.03, 0.03), 0.10),
        "burgundy": mat("patron_burgundy", (0.50, 0.08, 0.11), 0.78),
        "white_stripe": mat("patron_white_stripe", (0.88, 0.86, 0.82), 0.72),
        "atlet": mat("patron_atlet", (0.87, 0.85, 0.80), 0.84),
        "shirt_beige": mat("patron_shirt", (0.66, 0.59, 0.49), 0.84),
        "shirt_chambray": mat("patron_shirt", (0.54, 0.58, 0.60), 0.84),
        "sweater_brown": mat("patron_sweater", (0.36, 0.22, 0.12), 0.86),
        "olive": mat("patron_olive", (0.24, 0.32, 0.19), 0.84),
        "cap": mat("patron_cap", (0.18, 0.17, 0.15), 0.80),
        "trouser_brown": mat("patron_trouser", (0.25, 0.20, 0.15), 0.84),
        "navy": mat("patron_navy", (0.16, 0.28, 0.46), 0.78),
        "navy_pants": mat("patron_navy_pants", (0.15, 0.20, 0.31), 0.80),
        "belt": mat("patron_belt", (0.20, 0.11, 0.06), 0.46),
        "shoe_brown": mat("patron_shoe", (0.22, 0.11, 0.05), 0.36),
        "slipper": mat("patron_slipper", (0.09, 0.09, 0.10), 0.46),
        "dark_hair": mat("patron_dark_hair", (0.08, 0.06, 0.05), 0.72),
        "brown_hair": mat("patron_brown_hair", (0.18, 0.12, 0.08), 0.72),
        "gray_hair": mat("patron_gray_hair", (0.56, 0.56, 0.57), 0.70),
        "gold": mat("patron_gold", (0.85, 0.65, 0.20), 0.28, 0.85),
        "frames": mat("patron_frames", (0.09, 0.07, 0.06), 0.28, 0.15),
        "glass": mat("patron_glass", (0.82, 0.88, 0.92), 0.12, 0.0, 0.22),
        "ruby": mat("patron_ruby", (0.65, 0.06, 0.09), 0.20),
        "watch_face": mat("patron_watch_face", (0.92, 0.89, 0.80), 0.25),
        "tespih": mat("patron_tespih", (0.64, 0.09, 0.09), 0.26),
    }


def build_hand_geometry(
    parent: bpy.types.Object,
    m: dict[str, bpy.types.Material],
    side: int,
    wrist_pos: tuple[float, float, float],
    with_ring: bool = False,
    with_watch: bool = False,
    with_tespih: bool = False,
    inward_yaw: float = 16.0,
) -> None:
    tag = "L" if side < 0 else "R"
    wx, wy, wz = wrist_pos
    yaw_h = side * inward_yaw

    add_ellipsoid(
        f"Palm{tag}",
        (wx, wy, wz - 0.026),
        (0.048, 0.021, 0.050),
        m["skin"],
        parent,
        rot_deg=(8.0, yaw_h, -side * 6.0),
    )

    f_specs = [
        ("Index", -side * 0.029, 0.052, 0.0120),
        ("Middle", -side * 0.009, 0.056, 0.0125),
        ("Ring", side * 0.011, 0.052, 0.0120),
        ("Pinky", side * 0.029, 0.044, 0.0105),
    ]
    for fname, fx_off, flen, frad in f_specs:
        fx = wx + fx_off
        fz0 = wz - 0.062
        spline_tube(
            f"Finger{fname}{tag}",
            [
                ((fx, wy + 0.002, fz0), (frad, frad * 0.90)),
                ((fx - side * 0.003, wy - 0.006, fz0 - flen * 0.55), (frad * 0.88, frad * 0.82)),
                ((fx - side * 0.005, wy - 0.020, fz0 - flen), (frad * 0.76, frad * 0.70)),
            ],
            m["skin"],
            parent,
            segs_ring=14,
            steps_per_seg=4,
        )

    spline_tube(
        f"Thumb{tag}",
        [
            ((wx - side * 0.036, wy - 0.003, wz - 0.014), (0.015, 0.013)),
            ((wx - side * 0.052, wy - 0.009, wz - 0.044), (0.013, 0.011)),
            ((wx - side * 0.048, wy - 0.018, wz - 0.068), (0.011, 0.010)),
        ],
        m["skin"],
        parent,
        segs_ring=14,
        steps_per_seg=4,
    )

    if with_ring:
        rx_pos = wx + side * 0.011
        rz_pos = wz - 0.076
        add_ellipsoid(f"RingBand{tag}", (rx_pos, wy + 0.004, rz_pos), (0.014, 0.012, 0.007), m["gold"], parent, subsurf=0)
        add_ellipsoid(f"RingRuby{tag}", (rx_pos, wy + 0.014, rz_pos), (0.009, 0.006, 0.011), m["ruby"], parent, subsurf=0)

    if with_watch:
        spline_tube(
            f"WatchBand{tag}",
            [
                ((wx - 0.040, wy, wz + 0.020), (0.010, 0.032)),
                ((wx, wy + 0.028, wz + 0.020), (0.038, 0.010)),
                ((wx + 0.040, wy, wz + 0.020), (0.010, 0.032)),
            ],
            m["gold"],
            parent,
            segs_ring=12,
            steps_per_seg=4,
            subsurf=0,
        )
        add_ellipsoid(f"WatchCase{tag}", (wx, wy + 0.030, wz + 0.020), (0.022, 0.006, 0.022), m["gold"], parent, subsurf=0)
        add_ellipsoid(f"WatchFace{tag}", (wx, wy + 0.034, wz + 0.020), (0.017, 0.003, 0.017), m["watch_face"], parent, subsurf=0)

    if with_tespih:
        for i in range(14):
            ang = (i / 14.0) * math.tau
            bx = wx - side * 0.022 + math.cos(ang) * 0.038
            bz = wz - 0.045 + math.sin(ang) * 0.034
            add_ellipsoid(f"TespihBead{i}", (bx, wy - 0.016, bz), (0.007, 0.006, 0.007), m["tespih"], parent, subsurf=0)


def build_head(
    torso: bpy.types.Object,
    m: dict[str, bpy.types.Material],
    hair_mat: bpy.types.Material,
    kind: str,
) -> bpy.types.Object:
    head = empty("Head", (0.0, 0.045, -0.006), torso)

    # Upper chest & base of neck attached to torso so collar/chest stay anchored
    spline_tube(
        "ChestNeckBase",
        [
            ((0.0, 0.415, -0.018), (0.152, 0.132)),
            ((0.0, 0.485, -0.012), (0.118, 0.102)),
            ((0.0, 0.562, -0.012), (0.102, 0.088)),
        ],
        m["skin"],
        torso,
        segs_ring=32,
        steps_per_seg=5,
    )

    # Continuous sculpted Head + Jaw + Double-Chin + Nape (single seamless surface!)
    bm_head = bmesh.new()
    segs_u = 72
    rings_v = 54

    profile_ctrl = [
        # y,     rx,    r_front, r_back, z_off
        (0.515, 0.104, 0.092, 0.078, -0.008),  # neck root tucked under jaw & nape
        (0.545, 0.110, 0.102, 0.076, -0.010),  # mid-neck
        (0.572, 0.118, 0.116, 0.078, -0.014),  # soft double-chin fullness (nape tucked!)
        (0.614, 0.136, 0.130, 0.092, -0.016),  # rounded jawline & chin
        (0.662, 0.146, 0.136, 0.118, -0.012),  # wide smiling cheeks & lower occiput
        (0.715, 0.136, 0.128, 0.132, -0.010),  # eye, cheekbone & back of skull
        (0.765, 0.124, 0.120, 0.126, -0.008),  # forehead dome
        (0.808, 0.098, 0.096, 0.102, -0.006),  # upper cranium
        (0.838, 0.055, 0.054, 0.058, -0.005),  # crown taper
        (0.848, 0.000, 0.000, 0.000, -0.005),  # crown pole
    ]

    def sample_profile(u_norm: float) -> Vector:
        n = len(profile_ctrl) - 1
        scaled = u_norm * (n - 1)
        idx = min(int(scaled), n - 2)
        t = scaled - idx
        p0 = Vector(profile_ctrl[max(0, idx - 1)])
        p1 = Vector(profile_ctrl[idx])
        p2 = Vector(profile_ctrl[idx + 1])
        p3 = Vector(profile_ctrl[min(n, idx + 2)])
        return catmull_rom(p0, p1, p2, p3, t)

    ring_verts = []
    for j in range(rings_v):
        u = j / float(rings_v)
        prof = sample_profile(u)
        py, rx, rf, rb, z_off = prof[0], prof[1], prof[2], prof[3], prof[4]
        row = []
        for i in range(segs_u):
            ang = (i / float(segs_u)) * math.tau
            ca, sa = math.cos(ang), math.sin(ang)
            r_z = 0.5 * (rf + rb) + 0.5 * (rf - rb) * ca
            px = sa * rx
            pz = z_off - ca * r_z

            if ca > 0.0:
                # 1. Natural smooth rounded chin contour without weird protrusion or crease
                d_chin = (px / 0.054) ** 2 + ((py - 0.604) / 0.034) ** 2
                if d_chin < 2.8:
                    pz -= 0.010 * math.exp(-d_chin) * ca
                    py -= 0.003 * math.exp(-d_chin) * ca
                # 2. Plump smiling cheek apples
                for s in (-1.0, 1.0):
                    d_cheek = ((px - s * 0.068) / 0.048) ** 2 + ((py - 0.670) / 0.038) ** 2
                    if d_cheek < 2.8:
                        bulge = 0.016 * math.exp(-d_cheek) * (ca**0.6)
                        pz -= bulge
                        px += s * bulge * 0.35
                # 3. Recessed Eye Sockets
                for s in (-1.0, 1.0):
                    d_eye = ((px - s * 0.044) / 0.032) ** 2 + ((py - 0.722) / 0.022) ** 2
                    if d_eye < 2.2:
                        pz += 0.016 * math.exp(-d_eye) * ca
                # 5. Expressive Brow Ridge
                for s in (-1.0, 1.0):
                    d_brow = ((px - s * 0.046) / 0.045) ** 2 + ((py - 0.752) / 0.016) ** 2
                    if d_brow < 2.5:
                        pz -= 0.011 * math.exp(-d_brow) * ca
                # 6. Nasolabial smile creases
                for s in (-1.0, 1.0):
                    t_c = max(0.0, min(1.0, (0.692 - py) / 0.052))
                    cx = s * (0.038 + t_c * 0.034)
                    cy = 0.692 - t_c * 0.052
                    d_nl = ((px - cx) / 0.010) ** 2 + ((py - cy) / 0.028) ** 2
                    if d_nl < 2.0:
                        pz += 0.006 * math.exp(-d_nl)

            row.append(bm_head.verts.new(v((px, py, pz))))
        ring_verts.append(row)

    top_pole = bm_head.verts.new(v((0.0, 0.848, -0.005)))
    bottom_pole = bm_head.verts.new(v((0.0, 0.515, -0.008)))
    for i in range(segs_u):
        inext = (i + 1) % segs_u
        bm_head.faces.new((ring_verts[0][inext], ring_verts[0][i], bottom_pole))
    for j in range(rings_v - 1):
        r0, r1 = ring_verts[j], ring_verts[j + 1]
        for i in range(segs_u):
            inext = (i + 1) % segs_u
            bm_head.faces.new((r0[i], r0[inext], r1[inext], r1[i]))
    for i in range(segs_u):
        inext = (i + 1) % segs_u
        bm_head.faces.new((ring_verts[-1][i], ring_verts[-1][inext], top_pole))

    make_obj("FaceSkull", bm_head, m["skin"], head, subsurf=1)

    # Bulbous Turkish Nose
    add_ellipsoid("NoseTip", (0.0, 0.694, -0.158), (0.038, 0.028, 0.032), m["nose"], head, rot_deg=(-8.0, 0.0, 0.0))
    spline_tube(
        "NoseBridge",
        [
            ((0.0, 0.740, -0.128), (0.015, 0.012)),
            ((0.0, 0.718, -0.146), (0.024, 0.018)),
            ((0.0, 0.696, -0.160), (0.034, 0.024)),
        ],
        m["nose"],
        head,
        segs_ring=20,
        steps_per_seg=6,
    )
    for s, tag in ((-1, "L"), (1, "R")):
        add_ellipsoid(
            f"Nostril{tag}",
            (s * 0.028, 0.688, -0.146),
            (0.018, 0.016, 0.018),
            m["nose"],
            head,
            rot_deg=(0.0, -s * 15.0, 0.0),
        )

    # Recessed Eyes + Upper & Lower Eyelids + Arched Eyebrows + Ears
    for s, tag in ((-1, "L"), (1, "R")):
        ex, ey, ez = s * 0.045, 0.720, -0.126
        yaw = -s * 8.0
        add_ellipsoid(f"EyeWhite{tag}", (ex, ey, ez), (0.020, 0.015, 0.015), m["eye_white"], head, rot_deg=(0.0, yaw, 0.0))
        add_ellipsoid(f"Iris{tag}", (ex, ey, ez - 0.0115), (0.0105, 0.0105, 0.005), m["iris_brown"], head, rot_deg=(0.0, yaw, 0.0))
        add_ellipsoid(f"Pupil{tag}", (ex, ey, ez - 0.0142), (0.006, 0.006, 0.004), m["pupil"], head, rot_deg=(0.0, yaw, 0.0))
        add_ellipsoid(
            f"EyeCatchlight{tag}",
            (ex - s * 0.003, ey + 0.003, ez - 0.0165),
            (0.0025, 0.0025, 0.002),
            m["eye_white"],
            head,
            subsurf=0,
        )

        spline_tube(
            f"UpperLid{tag}",
            [
                ((ex - s * 0.020, ey + 0.002, ez - 0.006), (0.005, 0.005)),
                ((ex, ey + 0.010, ez - 0.012), (0.007, 0.006)),
                ((ex + s * 0.021, ey + 0.001, ez - 0.005), (0.005, 0.005)),
            ],
            m["skin_warm"],
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )
        spline_tube(
            f"LowerLid{tag}",
            [
                ((ex - s * 0.019, ey - 0.004, ez - 0.006), (0.004, 0.004)),
                ((ex, ey - 0.009, ez - 0.011), (0.0055, 0.005)),
                ((ex + s * 0.020, ey - 0.003, ez - 0.005), (0.004, 0.004)),
            ],
            m["skin_warm"],
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )

        spline_tube(
            f"Brow{tag}",
            [
                ((s * 0.016, 0.748, -0.136), (0.012, 0.010)),
                ((s * 0.042, 0.758, -0.138), (0.014, 0.011)),
                ((s * 0.068, 0.752, -0.128), (0.012, 0.010)),
                ((s * 0.086, 0.738, -0.114), (0.007, 0.006)),
            ],
            hair_mat,
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )

        add_ellipsoid(
            f"EarBase{tag}",
            (s * 0.144, 0.692, -0.012),
            (0.018, 0.036, 0.026),
            m["skin_warm"],
            head,
            rot_deg=(0.0, s * 16.0, -s * 6.0),
        )
        spline_tube(
            f"EarHelix{tag}",
            [
                ((s * 0.140, 0.716, -0.024), (0.008, 0.008)),
                ((s * 0.154, 0.722, -0.010), (0.009, 0.009)),
                ((s * 0.158, 0.694, 0.004), (0.009, 0.009)),
                ((s * 0.148, 0.664, -0.010), (0.011, 0.010)),
            ],
            m["skin_warm"],
            head,
        )

    # Continuous 1-piece Pala Mustache
    spline_tube(
        "Mustache",
        [
            ((-0.088, 0.650, -0.118), (0.006, 0.006)),
            ((-0.074, 0.652, -0.128), (0.012, 0.011)),
            ((-0.050, 0.662, -0.142), (0.017, 0.014)),
            ((-0.024, 0.668, -0.150), (0.019, 0.015)),
            ((0.0, 0.669, -0.152), (0.018, 0.015)),
            ((0.024, 0.668, -0.150), (0.019, 0.015)),
            ((0.050, 0.662, -0.142), (0.017, 0.014)),
            ((0.074, 0.652, -0.128), (0.012, 0.011)),
            ((0.088, 0.650, -0.118), (0.006, 0.006)),
        ],
        hair_mat,
        head,
        fixed_up=Vector((0.0, 0.0, 1.0)),
    )

    # Warm smile + teeth + lower lip
    add_ellipsoid("MouthSmile", (0.0, 0.646, -0.142), (0.036, 0.010, 0.010), m["mouth_dark"], head)
    add_ellipsoid("UpperTeeth", (0.0, 0.650, -0.145), (0.028, 0.006, 0.008), m["teeth"], head)
    spline_tube(
        "LowerLip",
        [
            ((-0.034, 0.644, -0.136), (0.006, 0.005)),
            ((0.0, 0.638, -0.146), (0.009, 0.007)),
            ((0.034, 0.644, -0.136), (0.006, 0.005)),
        ],
        m["lip"],
        head,
        fixed_up=Vector((0.0, 0.0, 1.0)),
    )

    # Skull-hugging horseshoe hair cap + sideburns
    hair_pts = [
        ((-0.118, 0.692, -0.055), (0.008, 0.022)),
        ((-0.132, 0.728, -0.028), (0.012, 0.042)),
        ((-0.132, 0.722, 0.025), (0.014, 0.045)),
        ((-0.105, 0.712, 0.085), (0.015, 0.044)),
        ((0.0, 0.706, 0.118), (0.016, 0.044)),
        ((0.105, 0.712, 0.085), (0.015, 0.044)),
        ((0.132, 0.722, 0.025), (0.014, 0.045)),
        ((0.132, 0.728, -0.028), (0.012, 0.042)),
        ((0.118, 0.692, -0.055), (0.008, 0.022)),
    ]
    spline_tube("HairHorseshoe", hair_pts, hair_mat, head, segs_ring=20, steps_per_seg=6, fixed_up=Vector((0.0, 0.0, 1.0)))

    if kind == "sabri":
        # Lush thick wavy dayı hair volume on top & crown matching concept art
        add_ellipsoid("HairTopCap", (0.0, 0.795, -0.008), (0.134, 0.076, 0.132), hair_mat, head, rot_deg=(-7.0, 0.0, 0.0))
        add_ellipsoid("HairFrontWave", (0.0, 0.814, -0.068), (0.118, 0.046, 0.062), hair_mat, head, rot_deg=(-15.0, 0.0, 0.0))
        add_ellipsoid("HairLeftWave", (-0.054, 0.816, -0.055), (0.058, 0.040, 0.054), hair_mat, head, rot_deg=(-12.0, -10.0, 4.0))
        add_ellipsoid("HairRightWave", (0.054, 0.816, -0.055), (0.058, 0.040, 0.054), hair_mat, head, rot_deg=(-12.0, 10.0, -4.0))
        add_ellipsoid("HairCrown", (0.0, 0.822, 0.038), (0.115, 0.052, 0.088), hair_mat, head, rot_deg=(8.0, 0.0, 0.0))
    elif kind == "rifki":
        # Distinguished combed-back gray hair volume
        add_ellipsoid("HairTopCap", (0.0, 0.792, -0.006), (0.128, 0.066, 0.128), hair_mat, head, rot_deg=(-8.0, 0.0, 0.0))
        add_ellipsoid("HairSlickBack", (0.0, 0.806, -0.050), (0.108, 0.038, 0.058), hair_mat, head, rot_deg=(-18.0, 0.0, 0.0))
        add_ellipsoid("HairCrown", (0.0, 0.815, 0.040), (0.108, 0.048, 0.082), hair_mat, head, rot_deg=(6.0, 0.0, 0.0))
    elif kind == "davut":
        # Artisan dark hair with side part
        add_ellipsoid("HairTopCap", (0.0, 0.788, -0.005), (0.126, 0.064, 0.125), hair_mat, head, rot_deg=(-6.0, 0.0, 0.0))
        add_ellipsoid("HairSidePart", (-0.028, 0.802, -0.046), (0.098, 0.038, 0.052), hair_mat, head, rot_deg=(-12.0, -8.0, 2.0))
        add_ellipsoid("HairCrown", (0.0, 0.812, 0.038), (0.105, 0.048, 0.080), hair_mat, head, rot_deg=(6.0, 0.0, 0.0))

    return head


def build_LowerBody(
    root: bpy.types.Object,
    m: dict[str, bpy.types.Material],
    pants_mat: bpy.types.Material,
    is_sabri: bool,
) -> None:
    loft_garment(
        "PelvisPants",
        [
            (-0.06, 0.220, 0.195, 0.175, 0.0, -0.020),
            (0.02, 0.238, 0.218, 0.185, 0.0, -0.025),
            (0.11, 0.232, 0.212, 0.178, 0.0, -0.022),
        ],
        pants_mat,
        root,
        sides=40,
    )

    if is_sabri:
        for side, tag in ((-1, "L"), (1, "R")):
            spline_tube(
                f"Drawstring{tag}",
                [
                    ((side * 0.016, 0.105, -0.236), 0.0045),
                    ((side * 0.024, 0.055, -0.242), 0.0045),
                    ((side * 0.020, 0.005, -0.238), 0.0040),
                ],
                m["white_stripe"],
                root,
                segs_ring=8,
                steps_per_seg=4,
                subsurf=0,
            )
    else:
        loft_garment(
            "LeatherBelt",
            [
                (0.095, 0.235, 0.216, 0.180, 0.0, -0.024),
                (0.130, 0.232, 0.214, 0.178, 0.0, -0.024),
            ],
            m["belt"],
            root,
            sides=40,
        )
        rounded_box("BeltBuckle", (0.0, 0.112, -0.242), (0.044, 0.036, 0.012), m["gold"], root, bevel=0.003)

    for side, tag in ((-1, "L"), (1, "R")):
        spline_tube(
            f"FullLeg{tag}",
            [
                ((side * 0.112, 0.02, -0.04), (0.095, 0.090)),
                ((side * 0.122, 0.00, -0.19), (0.088, 0.084)),
                ((side * 0.128, -0.02, -0.33), (0.080, 0.078)),
                ((side * 0.128, -0.13, -0.37), (0.074, 0.072)),
                ((side * 0.125, -0.29, -0.36), (0.065, 0.064)),
                ((side * 0.122, -0.43, -0.35), (0.054, 0.054)),
            ],
            pants_mat,
            root,
            segs_ring=24,
            steps_per_seg=5,
        )

        if is_sabri:
            spline_tube(
                f"Ankle{tag}",
                [
                    ((side * 0.122, -0.42, -0.35), 0.042),
                    ((side * 0.122, -0.48, -0.35), 0.039),
                ],
                m["skin"],
                root,
                segs_ring=16,
                steps_per_seg=3,
            )
            rounded_box(
                f"SlipperSole{tag}",
                (side * 0.124, -0.505, -0.405),
                (0.098, 0.022, 0.215),
                m["slipper"],
                root,
                rot_deg=(0.0, -side * 5.0, 0.0),
                bevel=0.007,
            )
            add_ellipsoid(
                f"FootArch{tag}",
                (side * 0.124, -0.485, -0.395),
                (0.042, 0.024, 0.076),
                m["skin"],
                root,
                rot_deg=(6.0, -side * 5.0, 0.0),
            )
            for idx, z_s in enumerate((-0.375, -0.402, -0.428)):
                spline_tube(
                    f"SlipperStrap{tag}_{idx}",
                    [
                        ((side * 0.124 - 0.046, -0.495, z_s), (0.008, 0.011)),
                        ((side * 0.124, -0.460, z_s), (0.009, 0.012)),
                        ((side * 0.124 + 0.046, -0.495, z_s), (0.008, 0.011)),
                    ],
                    m["slipper"],
                    root,
                    segs_ring=12,
                    steps_per_seg=4,
                    fixed_up=Vector((0.0, 0.0, 1.0)),
                )
            for t_i in range(5):
                tx = side * 0.124 + side * (t_i - 1.8) * 0.015
                tz = -0.482 + abs(t_i - 1.5) * 0.005
                tr = 0.011 if t_i == 0 else max(0.0065, 0.0095 - t_i * 0.0007)
                add_ellipsoid(f"Toe{tag}_{t_i}", (tx, -0.490, tz), (tr, 0.009, tr * 1.3), m["skin"], root, subsurf=0)
        else:
            spline_tube(
                f"Sock{tag}",
                [
                    ((side * 0.122, -0.42, -0.35), 0.041),
                    ((side * 0.122, -0.48, -0.35), 0.039),
                ],
                m["trouser_brown"],
                root,
                segs_ring=14,
                steps_per_seg=3,
            )
            rounded_box(
                f"ShoeSole{tag}",
                (side * 0.124, -0.505, -0.405),
                (0.095, 0.022, 0.215),
                m["belt"],
                root,
                rot_deg=(0.0, -side * 5.0, 0.0),
                bevel=0.005,
            )
            add_ellipsoid(
                f"ShoeUpper{tag}",
                (side * 0.124, -0.480, -0.402),
                (0.048, 0.032, 0.098),
                m["shoe_brown"],
                root,
                rot_deg=(4.0, -side * 5.0, 0.0),
            )


def build_sabri(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Sabri")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["navy_pants"], is_sabri=True)

    loft_garment(
        "Atlet",
        [
            (0.08, 0.228, 0.205, 0.170, 0.0, -0.020),
            (0.20, 0.258, 0.242, 0.184, 0.0, -0.026),
            (0.32, 0.250, 0.232, 0.178, 0.0, -0.022),
            (0.43, 0.212, 0.176, 0.156, 0.0, -0.012),
            (0.51, 0.148, 0.122, 0.120, 0.0, -0.004),
        ],
        m["atlet"],
        torso,
        sides=44,
        u_neck_depth=0.115,
    )

    spline_tube(
        "GoldChain",
        [
            ((-0.092, 0.515, -0.095), (0.008, 0.008)),
            ((-0.072, 0.468, -0.142), (0.009, 0.009)),
            ((-0.036, 0.440, -0.162), (0.009, 0.009)),
            ((0.0, 0.432, -0.168), (0.009, 0.009)),
            ((0.036, 0.440, -0.162), (0.009, 0.009)),
            ((0.072, 0.468, -0.142), (0.009, 0.009)),
            ((0.092, 0.515, -0.095), (0.008, 0.008)),
        ],
        m["gold"],
        torso,
        segs_ring=14,
        steps_per_seg=5,
    )

    loft_garment(
        "TrackJacket",
        [
            (0.10, 0.242, 0.215, 0.180, 0.0, -0.022),
            (0.22, 0.270, 0.248, 0.194, 0.0, -0.028),
            (0.34, 0.264, 0.238, 0.188, 0.0, -0.022),
            (0.45, 0.238, 0.194, 0.170, 0.0, -0.012),
            (0.51, 0.176, 0.142, 0.138, 0.0, -0.006),
            (0.555, 0.142, 0.125, 0.122, 0.0, -0.004),
        ],
        m["burgundy"],
        torso,
        sides=48,
        open_front_angle=math.radians(74.0),
        thickness=0.018,
    )

    for s, tag in ((-1, "L"), (1, "R")):
        spline_tube(
            f"ZipTrim{tag}",
            [
                ((s * 0.086, 0.548, -0.098), 0.006),
                ((s * 0.128, 0.445, -0.152), 0.006),
                ((s * 0.162, 0.340, -0.190), 0.006),
                ((s * 0.165, 0.220, -0.198), 0.006),
                ((s * 0.148, 0.110, -0.172), 0.006),
            ],
            m["white_stripe"],
            torso,
            segs_ring=10,
            steps_per_seg=5,
            subsurf=0,
        )

        spline_tube(
            f"JacketSleeve{tag}",
            [
                ((s * 0.145, 0.512, -0.008), (0.076, 0.068)),
                ((s * 0.232, 0.455, -0.028), (0.072, 0.068)),
                ((s * 0.282, 0.355, -0.082), (0.066, 0.064)),
                ((s * 0.264, 0.275, -0.175), (0.056, 0.055)),
            ],
            m["burgundy"],
            torso,
            segs_ring=24,
            steps_per_seg=6,
        )

        spline_tube(
            f"SleeveCuff{tag}",
            [
                ((s * 0.264, 0.278, -0.170), (0.058, 0.057)),
                ((s * 0.252, 0.260, -0.202), (0.052, 0.051)),
            ],
            m["burgundy"],
            torso,
            segs_ring=24,
            steps_per_seg=3,
        )

        for idx, z_off in enumerate((-0.016, 0.0, 0.016)):
            spline_tube(
                f"Stripe{tag}_{idx}",
                [
                    ((s * 0.142, 0.562, -0.008 + z_off * 0.8), (0.0055, 0.0055)),
                    ((s * 0.278, 0.492, -0.028 + z_off), (0.0055, 0.0055)),
                    ((s * 0.344, 0.368, -0.082 + z_off), (0.0055, 0.0055)),
                    ((s * 0.318, 0.282, -0.172 + z_off), (0.0055, 0.0055)),
                ],
                m["white_stripe"],
                torso,
                segs_ring=10,
                steps_per_seg=6,
                subsurf=0,
            )

        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.252, 0.262, -0.198), (0.048, 0.044)),
                ((s * 0.232, 0.242, -0.265), (0.044, 0.038)),
                ((s * 0.208, 0.226, -0.328), (0.039, 0.030)),
            ],
            m["skin"],
            torso,
            segs_ring=20,
            steps_per_seg=5,
        )

        build_hand_geometry(
            torso,
            m,
            s,
            (s * 0.200, 0.220, -0.348),
            with_ring=(s == 1),
            with_watch=(s == -1),
        )

    build_head(torso, m, m["dark_hair"], "sabri")
    return root


def build_rifki(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Rifki")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["trouser_brown"], is_sabri=False)

    loft_garment(
        "ShirtBody",
        [
            (0.10, 0.224, 0.200, 0.165, 0.0, -0.022),
            (0.22, 0.252, 0.232, 0.180, 0.0, -0.026),
            (0.34, 0.244, 0.222, 0.174, 0.0, -0.020),
            (0.45, 0.204, 0.168, 0.150, 0.0, -0.010),
            (0.535, 0.130, 0.114, 0.112, 0.0, -0.004),
        ],
        m["shirt_beige"],
        torso,
        sides=44,
    )

    loft_garment(
        "SweaterVest",
        [
            (0.11, 0.238, 0.214, 0.176, 0.0, -0.022),
            (0.22, 0.264, 0.244, 0.188, 0.0, -0.026),
            (0.34, 0.256, 0.234, 0.182, 0.0, -0.020),
            (0.45, 0.222, 0.184, 0.162, 0.0, -0.010),
            (0.525, 0.162, 0.132, 0.130, 0.0, -0.004),
        ],
        m["sweater_brown"],
        torso,
        sides=44,
        u_neck_depth=0.115,
    )

    for idx, by in enumerate((0.20, 0.26, 0.32, 0.38)):
        add_ellipsoid(f"VestButton{idx}", (0.0, by, -0.258), (0.011, 0.011, 0.006), m["belt"], torso, subsurf=0)

    for s, tag in ((-1, "L"), (1, "R")):
        spline_tube(
            f"RolledSleeve{tag}",
            [
                ((s * 0.145, 0.508, -0.008), (0.072, 0.066)),
                ((s * 0.228, 0.450, -0.028), (0.068, 0.064)),
                ((s * 0.275, 0.350, -0.085), (0.062, 0.060)),
            ],
            m["shirt_beige"],
            torso,
            segs_ring=22,
            steps_per_seg=5,
        )
        spline_tube(
            f"RolledCuff{tag}",
            [
                ((s * 0.275, 0.354, -0.080), (0.066, 0.064)),
                ((s * 0.268, 0.318, -0.125), (0.062, 0.060)),
            ],
            m["shirt_beige"],
            torso,
            segs_ring=22,
            steps_per_seg=3,
        )
        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.266, 0.315, -0.125), (0.050, 0.046)),
                ((s * 0.238, 0.262, -0.235), (0.044, 0.038)),
                ((s * 0.208, 0.226, -0.328), (0.039, 0.030)),
            ],
            m["skin"],
            torso,
            segs_ring=20,
            steps_per_seg=5,
        )
        build_hand_geometry(
            torso,
            m,
            s,
            (s * 0.200, 0.220, -0.348),
            with_tespih=(s == -1),
        )

    head = build_head(torso, m, m["gray_hair"], "rifki")

    # Dark rectangular eyeglasses at eye height (y = 0.720)
    rounded_box("GlassesBridge", (0.0, 0.726, -0.148), (0.026, 0.007, 0.007), m["frames"], head, bevel=0.002)
    for s, tag in ((-1, "L"), (1, "R")):
        gx, gy, gz = s * 0.048, 0.720, -0.146
        spline_tube(
            f"GlassesRim{tag}",
            [
                ((gx - 0.028, gy + 0.019, gz), 0.0042),
                ((gx + 0.028, gy + 0.019, gz), 0.0042),
                ((gx + 0.030, gy - 0.017, gz), 0.0042),
                ((gx - 0.026, gy - 0.017, gz), 0.0042),
                ((gx - 0.028, gy + 0.019, gz), 0.0042),
            ],
            m["frames"],
            head,
            segs_ring=10,
            steps_per_seg=4,
            cap_ends=False,
            subsurf=0,
            fixed_up=Vector((0.0, 1.0, 0.0)),
        )
        rounded_box(f"GlassesLens{tag}", (gx, gy, gz + 0.002), (0.054, 0.034, 0.003), m["glass"], head, bevel=0.001)
        spline_tube(
            f"GlassesTemple{tag}",
            [
                ((s * 0.078, gy + 0.012, gz + 0.004), 0.0038),
                ((s * 0.136, gy + 0.008, -0.068), 0.0038),
                ((s * 0.144, gy - 0.004, -0.012), 0.0035),
            ],
            m["frames"],
            head,
            segs_ring=8,
            steps_per_seg=4,
            subsurf=0,
        )

    return root


def build_temel(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Temel")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["trouser_brown"], is_sabri=False)

    loft_garment(
        "ShirtBody",
        [
            (0.10, 0.222, 0.198, 0.164, 0.0, -0.022),
            (0.22, 0.248, 0.228, 0.178, 0.0, -0.026),
            (0.34, 0.240, 0.218, 0.172, 0.0, -0.020),
            (0.45, 0.200, 0.165, 0.148, 0.0, -0.010),
            (0.535, 0.128, 0.112, 0.110, 0.0, -0.004),
        ],
        m["shirt_chambray"],
        torso,
        sides=44,
    )

    loft_garment(
        "Waistcoat",
        [
            (0.11, 0.236, 0.210, 0.174, 0.0, -0.022),
            (0.22, 0.262, 0.240, 0.186, 0.0, -0.026),
            (0.34, 0.254, 0.230, 0.180, 0.0, -0.020),
            (0.45, 0.218, 0.182, 0.160, 0.0, -0.010),
            (0.525, 0.160, 0.130, 0.128, 0.0, -0.004),
        ],
        m["olive"],
        torso,
        sides=44,
        open_front_angle=math.radians(60.0),
        thickness=0.016,
    )

    for s, tag in ((-1, "L"), (1, "R")):
        spline_tube(
            f"RolledSleeve{tag}",
            [
                ((s * 0.145, 0.508, -0.008), (0.072, 0.066)),
                ((s * 0.228, 0.450, -0.028), (0.068, 0.064)),
                ((s * 0.275, 0.350, -0.085), (0.062, 0.060)),
            ],
            m["shirt_chambray"],
            torso,
            segs_ring=22,
            steps_per_seg=5,
        )
        spline_tube(
            f"RolledCuff{tag}",
            [
                ((s * 0.275, 0.354, -0.080), (0.066, 0.064)),
                ((s * 0.268, 0.318, -0.125), (0.062, 0.060)),
            ],
            m["shirt_chambray"],
            torso,
            segs_ring=22,
            steps_per_seg=3,
        )
        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.266, 0.315, -0.125), (0.050, 0.046)),
                ((s * 0.238, 0.262, -0.235), (0.044, 0.038)),
                ((s * 0.208, 0.226, -0.328), (0.039, 0.030)),
            ],
            m["skin"],
            torso,
            segs_ring=20,
            steps_per_seg=5,
        )
        build_hand_geometry(torso, m, s, (s * 0.200, 0.220, -0.348))

    head = build_head(torso, m, m["brown_hair"], "temel")

    # Classic Turkish Kasket (flat cap) sitting snugly on the crown (y = 0.815)
    add_ellipsoid(
        "CapCrown",
        (0.0, 0.818, -0.016),
        (0.146, 0.052, 0.156),
        m["cap"],
        head,
        rot_deg=(7.0, 0.0, 0.0),
    )
    add_ellipsoid(
        "CapVisor",
        (0.0, 0.792, -0.128),
        (0.110, 0.015, 0.075),
        m["cap"],
        head,
        rot_deg=(14.0, 0.0, 0.0),
    )
    return root


def build_davut(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Davut")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)
    build_LowerBody(root, m, m["navy_pants"], is_sabri=False)

    loft_garment(
        "ShirtBody",
        [
            (0.10, 0.222, 0.198, 0.164, 0.0, -0.022),
            (0.22, 0.248, 0.228, 0.178, 0.0, -0.026),
            (0.34, 0.240, 0.218, 0.172, 0.0, -0.020),
            (0.45, 0.200, 0.165, 0.148, 0.0, -0.010),
            (0.535, 0.128, 0.112, 0.110, 0.0, -0.004),
        ],
        m["navy"],
        torso,
        sides=44,
    )

    loft_garment(
        "ApronVest",
        [
            (0.11, 0.236, 0.210, 0.174, 0.0, -0.022),
            (0.22, 0.262, 0.240, 0.186, 0.0, -0.026),
            (0.34, 0.254, 0.230, 0.180, 0.0, -0.020),
            (0.45, 0.218, 0.182, 0.160, 0.0, -0.010),
            (0.525, 0.160, 0.130, 0.128, 0.0, -0.004),
        ],
        m["trouser_brown"],
        torso,
        sides=44,
        open_front_angle=math.radians(50.0),
        thickness=0.016,
    )

    for s, tag in ((-1, "L"), (1, "R")):
        spline_tube(
            f"RolledSleeve{tag}",
            [
                ((s * 0.145, 0.508, -0.008), (0.072, 0.066)),
                ((s * 0.228, 0.450, -0.028), (0.068, 0.064)),
                ((s * 0.275, 0.350, -0.085), (0.062, 0.060)),
            ],
            m["navy"],
            torso,
            segs_ring=22,
            steps_per_seg=5,
        )
        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.266, 0.315, -0.125), (0.050, 0.046)),
                ((s * 0.238, 0.262, -0.235), (0.044, 0.038)),
                ((s * 0.208, 0.226, -0.328), (0.039, 0.030)),
            ],
            m["skin"],
            torso,
            segs_ring=20,
            steps_per_seg=5,
        )
        build_hand_geometry(torso, m, s, (s * 0.200, 0.220, -0.348))

    head = build_head(torso, m, m["dark_hair"], "davut")
    return root


def build_local_hand(m: dict[str, bpy.types.Material], side: int) -> bpy.types.Object:
    root = empty("LocalHandLeft" if side < 0 else "LocalHand")
    build_hand_geometry(root, m, side, (0.0, 0.0, 0.0), with_ring=(side > 0), with_watch=(side < 0), inward_yaw=0.0)
    return root


def select_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    stack = [root]
    while stack:
        obj = stack.pop()
        obj.select_set(True)
        stack.extend(obj.children)
    bpy.context.view_layer.objects.active = root


def export_glb(root: bpy.types.Object, filepath: Path) -> None:
    filepath.parent.mkdir(parents=True, exist_ok=True)
    select_hierarchy(root)
    bpy.ops.export_scene.gltf(
        filepath=str(filepath),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )


def build(out_dir: Path) -> None:
    clear_scene()
    m = palette()
    builders = {
        "sabri": lambda: build_sabri(m),
        "temel": lambda: build_temel(m),
        "rifki": lambda: build_rifki(m),
        "davut": lambda: build_davut(m),
        "local_hand": lambda: build_local_hand(m, 1),
        "local_hand_left": lambda: build_local_hand(m, -1),
    }
    x_offset = 0.0
    for name, fn in builders.items():
        root = fn()
        root.location = Vector((0.0, 0.0, 0.0))
        export_glb(root, out_dir / f"{name}.glb")
        root.location = Vector((x_offset, 0.0, 0.0))
        x_offset += 1.25

    blend_dir = Path(__file__).resolve().parent / "source"
    blend_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_dir / "kiraathane_patrons.blend"))


if __name__ == "__main__":
    build(parse_out_dir())
