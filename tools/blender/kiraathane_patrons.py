"""Continuous organic sculpted 3D Turkish coffeehouse characters (Dayilar) for Blender 5.2.

Features:
- 4 fully distinct characters with unique face shapes, jawlines, noses, hairstyles, and outfits:
  1. SABRI: Iconic Turkish Dayı. Round friendly face, thick wavy black hair with sideburns (NO HAT),
     wide sweeping black pala mustache, warm brown eyes, red track jacket with seamless shoulder stripes,
     white atlet undershirt, gold necklace, ruby pinky ring, navy sweatpants with white piping, slippers.
  2. RIFKI: Dignified retired civil servant / gentleman. Slender oval face, receding hairline with
     combed-back silver-gray hair (NO HAT), neat trimmed silver-gray mustache, hazel eyes, thin dark reading
     glasses, cream dress shirt under warm brown wool knit sweater vest with buttons, amber tespih in hand,
     tailored brown trousers, leather belt, classic brown oxford shoes.
  3. TEMEL: Energetic Karadeniz craftsman / fisherman. Angular face with high cheekbones, iconic prominent
     Karadeniz kemerli burun (aquiline hooked nose), sea-blue eyes, auburn horseshoe mustache, authentic
     Turkish Sekiz Köşe Kasket (8-panel tweed cap with curved visor and button), auburn wavy hair locks
     peeking out beneath cap, light chambray worker shirt with rolled-up cuffs, dark olive worker vest.
  4. DAVUT: Solid neighborhood butcher / esnaf master. Broad masculine square jaw, sturdy neck, strong
     straight nose, dark eyes, solid Anatolian chevron mustache, vintage side-parted pompadour dark hair
     (NO HAT), rolled-sleeve navy worker shirt, brown leather belt with brass buckle, work trousers and boots.
- Seamless anatomical shoulders: Deltoid shoulder joints eliminate detached floating sleeve caps.
- Natural skin-tone blended noses: No clown pink or bulbous spheres.
- Full hierarchical joint rig (Root -> Pelvis -> Hips -> Knees -> Feet; Torso -> Head; Shoulders -> Elbows -> Wrists -> Hands)
  allowing standing up, celebration gestures, and tile-playing movements while maintaining full compatibility
  with Godot's cafe_patron.gd (Head and Torso nodes).
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
        bpy.context.view_layer.update()
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
        bpy.context.view_layer.update()
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
    segs: int = 24,
    rings: int = 16,
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
        vert.co.x *= size[0] * 0.5
        vert.co.z *= size[1] * 0.5
        vert.co.y *= -size[2] * 0.5
    if bevel > 0.0:
        bmesh.ops.bevel(
            bm,
            geom=bm.edges[:] + bm.verts[:],
            offset=bevel,
            segments=2,
            profile=0.5,
            affect="EDGES",
        )
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
    segs_ring: int = 18,
    steps_per_seg: int = 5,
    cap_ends: bool = True,
    subsurf: int = 1,
    fixed_up: Vector | None = None,
) -> bpy.types.Object:
    bm = bmesh.new()
    pts: list[Vector] = []
    radii_list: list[tuple[float, float]] = []
    for pos, rad in points_and_radii:
        pts.append(v(pos))
        if isinstance(rad, (int, float)):
            radii_list.append((float(rad), float(rad)))
        else:
            radii_list.append((float(rad[0]), float(rad[1])))

    n = len(pts)
    samples: list[tuple[Vector, tuple[float, float]]] = []
    for i in range(n - 1):
        p0 = pts[max(0, i - 1)]
        p1 = pts[i]
        p2 = pts[i + 1]
        p3 = pts[min(n - 1, i + 2)]
        r1 = radii_list[i]
        r2 = radii_list[i + 1]
        cnt = steps_per_seg if i < n - 2 else steps_per_seg + 1
        for s in range(cnt):
            t = s / float(steps_per_seg)
            p_interp = catmull_rom(p0, p1, p2, p3, t)
            rx = (1.0 - t) * r1[0] + t * r2[0]
            ry = (1.0 - t) * r1[1] + t * r2[1]
            samples.append((p_interp, (rx, ry)))

    rings = []
    prev_normal = None
    for idx, (center, (rx, ry)) in enumerate(samples):
        if idx == 0:
            tangent = (samples[1][0] - center).normalized()
        elif idx == len(samples) - 1:
            tangent = (center - samples[idx - 1][0]).normalized()
        else:
            tangent = (samples[idx + 1][0] - samples[idx - 1][0]).normalized()

        if fixed_up is not None:
            up_raw = v((fixed_up.x, fixed_up.y, fixed_up.z))
            side_vec = tangent.cross(up_raw)
            if side_vec.length < 1e-4:
                side_vec = tangent.cross(Vector((1.0, 0.0, 0.0)))
            side_vec = side_vec.normalized()
            normal = side_vec.cross(tangent).normalized()
        else:
            if prev_normal is None:
                guide = Vector((0.0, 0.0, 1.0))
                if abs(tangent.dot(guide)) > 0.9:
                    guide = Vector((1.0, 0.0, 0.0))
                normal = tangent.cross(guide).normalized()
            else:
                normal = prev_normal - tangent * tangent.dot(prev_normal)
                if normal.length < 1e-4:
                    guide = Vector((0.0, 0.0, 1.0))
                    normal = tangent.cross(guide).normalized()
                else:
                    normal = normal.normalized()
            side_vec = tangent.cross(normal).normalized()
            prev_normal = normal

        ring_verts = []
        for j in range(segs_ring):
            ang = (j / float(segs_ring)) * math.tau
            ca, sa = math.cos(ang), math.sin(ang)
            offset = side_vec * (ca * rx) + normal * (sa * ry)
            ring_verts.append(bm.verts.new(center + offset))
        rings.append(ring_verts)

    for i in range(len(rings) - 1):
        r0 = rings[i]
        r1 = rings[i + 1]
        for j in range(segs_ring):
            jn = (j + 1) % segs_ring
            bm.faces.new((r0[j], r0[jn], r1[jn], r1[j]))

    if cap_ends:
        c_start = bm.verts.new(samples[0][0])
        r_start = rings[0]
        for j in range(segs_ring):
            jn = (j + 1) % segs_ring
            bm.faces.new((r_start[jn], r_start[j], c_start))
        c_end = bm.verts.new(samples[-1][0])
        r_end = rings[-1]
        for j in range(segs_ring):
            jn = (j + 1) % segs_ring
            bm.faces.new((r_end[j], r_end[jn], c_end))

    return make_obj(name, bm, material, parent, subsurf=subsurf)


def loft_garment(
    name: str,
    sections: list[tuple[float, float, float, float, float, float]],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    sides: int = 44,
    open_front_angle: float = 0.0,
    thickness: float = 0.016,
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
            bm.faces.new((outer_rings[i][-1], inner_rings[i][-1], inner_rings[i + 1][-1], outer_rings[i + 1][-1]))
        r_bot_o, r_bot_i = outer_rings[0], inner_rings[0]
        r_top_o, r_top_i = outer_rings[-1], inner_rings[-1]
        for k in range(count - 1):
            kn = k + 1
            bm.faces.new((r_bot_o[k], r_bot_i[k], r_bot_i[kn], r_bot_o[kn]))
            bm.faces.new((r_top_o[k], r_top_o[kn], r_top_i[kn], r_top_i[k]))
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
        # Natural Mediterranean skin tones (warm & blended, NO clown pink!)
        "skin": mat("patron_skin", (0.84, 0.62, 0.50), 0.54),
        "skin_warm": mat("patron_skin_warm", (0.83, 0.58, 0.46), 0.54),
        "skin_elderly": mat("patron_skin_elderly", (0.84, 0.65, 0.54), 0.58),
        "skin_karadeniz": mat("patron_skin_karadeniz", (0.82, 0.60, 0.48), 0.54),
        "nose": mat("patron_nose", (0.83, 0.58, 0.47), 0.52),
        "lip": mat("patron_lip", (0.72, 0.42, 0.38), 0.50),
        "mouth_dark": mat("patron_mouth_dark", (0.14, 0.05, 0.05), 0.88),
        "teeth": mat("patron_teeth", (0.92, 0.90, 0.84), 0.28),
        "eye_white": mat("patron_eye_white", (0.94, 0.92, 0.88), 0.20),
        # Distinct iris colors
        "iris_brown": mat("patron_iris_brown", (0.24, 0.12, 0.05), 0.18),
        "iris_hazel": mat("patron_iris_hazel", (0.34, 0.25, 0.10), 0.18),
        "iris_blue": mat("patron_iris_blue", (0.12, 0.28, 0.48), 0.18),
        "iris_dark": mat("patron_iris_dark", (0.10, 0.07, 0.05), 0.18),
        "pupil": mat("patron_pupil", (0.02, 0.02, 0.02), 0.10),
        # Distinct clothing materials
        "burgundy": mat("patron_burgundy", (0.50, 0.08, 0.11), 0.78),
        "white_stripe": mat("patron_white_stripe", (0.88, 0.86, 0.82), 0.72),
        "atlet": mat("patron_atlet", (0.87, 0.85, 0.80), 0.84),
        "shirt_beige": mat("patron_shirt_beige", (0.70, 0.64, 0.54), 0.84),
        "shirt_chambray": mat("patron_shirt_chambray", (0.42, 0.50, 0.58), 0.84),
        "sweater_brown": mat("patron_sweater_brown", (0.32, 0.20, 0.12), 0.88),
        "olive": mat("patron_olive", (0.22, 0.28, 0.18), 0.84),
        "tweed_cap": mat("patron_tweed_cap", (0.20, 0.22, 0.19), 0.86),
        "trouser_brown": mat("patron_trouser", (0.24, 0.18, 0.14), 0.84),
        "navy": mat("patron_navy", (0.14, 0.22, 0.38), 0.78),
        "navy_pants": mat("patron_navy_pants", (0.12, 0.16, 0.26), 0.80),
        "belt": mat("patron_belt", (0.18, 0.10, 0.05), 0.46),
        "shoe_brown": mat("patron_shoe", (0.20, 0.10, 0.05), 0.36),
        "slipper": mat("patron_slipper", (0.09, 0.09, 0.10), 0.46),
        # Distinct hair colors
        "dark_hair": mat("patron_dark_hair", (0.05, 0.04, 0.04), 0.65),
        "brown_hair": mat("patron_brown_hair", (0.16, 0.11, 0.07), 0.68),
        "auburn_hair": mat("patron_auburn_hair", (0.30, 0.14, 0.07), 0.66),
        "gray_hair": mat("patron_gray_hair", (0.64, 0.64, 0.66), 0.68),
        # Accessories
        "gold": mat("patron_gold", (0.85, 0.65, 0.20), 0.28, 0.85),
        "frames": mat("patron_frames", (0.08, 0.06, 0.05), 0.28, 0.15),
        "glass": mat("patron_glass", (0.82, 0.88, 0.92), 0.12, 0.0, 0.22),
        "ruby": mat("patron_ruby", (0.65, 0.06, 0.09), 0.20),
        "watch_face": mat("patron_watch_face", (0.92, 0.89, 0.80), 0.25),
        "tespih": mat("patron_tespih", (0.65, 0.12, 0.06), 0.26),
    }


def build_hand_geometry(
    parent: bpy.types.Object,
    m: dict[str, bpy.types.Material],
    side: int,
    wrist_pos: tuple[float, float, float],
    skin_mat: bpy.types.Material | None = None,
    with_ring: bool = False,
    with_watch: bool = False,
    with_tespih: bool = False,
    inward_yaw: float = 16.0,
) -> None:
    tag = "L" if side < 0 else "R"
    s_mat = skin_mat or m["skin"]
    wx, wy, wz = wrist_pos
    yaw_h = side * inward_yaw

    # Palm smoothly anchored at wrist
    add_ellipsoid(
        f"Palm{tag}",
        (wx, wy, wz - 0.024),
        (0.046, 0.020, 0.048),
        s_mat,
        parent,
        rot_deg=(8.0, yaw_h, -side * 6.0),
    )

    f_specs = [
        ("Index", -side * 0.028, 0.050, 0.0115),
        ("Middle", -side * 0.009, 0.054, 0.0120),
        ("Ring", side * 0.010, 0.050, 0.0115),
        ("Pinky", side * 0.028, 0.042, 0.0100),
    ]
    for fname, fx_off, flen, frad in f_specs:
        fx = wx + fx_off
        fz0 = wz - 0.060
        spline_tube(
            f"Finger{fname}{tag}",
            [
                ((fx, wy + 0.002, fz0), (frad, frad * 0.90)),
                ((fx - side * 0.003, wy - 0.006, fz0 - flen * 0.55), (frad * 0.88, frad * 0.82)),
                ((fx - side * 0.005, wy - 0.020, fz0 - flen), (frad * 0.76, frad * 0.70)),
            ],
            s_mat,
            parent,
            segs_ring=12,
            steps_per_seg=4,
        )

    spline_tube(
        f"Thumb{tag}",
        [
            ((wx - side * 0.035, wy - 0.003, wz - 0.014), (0.014, 0.012)),
            ((wx - side * 0.050, wy - 0.009, wz - 0.042), (0.012, 0.011)),
            ((wx - side * 0.046, wy - 0.018, wz - 0.066), (0.011, 0.010)),
        ],
        s_mat,
        parent,
        segs_ring=12,
        steps_per_seg=4,
    )

    if with_ring:
        rx_pos = wx + side * 0.010
        rz_pos = wz - 0.074
        add_ellipsoid(f"RingBand{tag}", (rx_pos, wy + 0.004, rz_pos), (0.013, 0.011, 0.007), m["gold"], parent, subsurf=0)
        add_ellipsoid(f"RingRuby{tag}", (rx_pos, wy + 0.013, rz_pos), (0.008, 0.006, 0.010), m["ruby"], parent, subsurf=0)

    if with_watch:
        spline_tube(
            f"WatchBand{tag}",
            [
                ((wx - 0.038, wy, wz + 0.020), (0.009, 0.030)),
                ((wx, wy + 0.026, wz + 0.020), (0.036, 0.009)),
                ((wx + 0.038, wy, wz + 0.020), (0.009, 0.030)),
            ],
            m["gold"],
            parent,
            segs_ring=10,
            steps_per_seg=4,
            subsurf=0,
        )
        add_ellipsoid(f"WatchCase{tag}", (wx, wy + 0.028, wz + 0.020), (0.020, 0.006, 0.020), m["gold"], parent, subsurf=0)
        add_ellipsoid(f"WatchFace{tag}", (wx, wy + 0.032, wz + 0.020), (0.016, 0.003, 0.016), m["watch_face"], parent, subsurf=0)

    if with_tespih:
        for i in range(14):
            ang = (i / 14.0) * math.tau
            bx = wx - side * 0.020 + math.cos(ang) * 0.036
            bz = wz - 0.070 + math.sin(ang) * 0.040
            by = wy - 0.010 + math.sin(ang * 2.0) * 0.006
            add_ellipsoid(f"TespihBead_{i}", (bx, by, bz), (0.006, 0.006, 0.007), m["tespih"], parent, subsurf=0)


def build_head(
    torso: bpy.types.Object,
    m: dict[str, bpy.types.Material],
    hair_mat: bpy.types.Material,
    kind: str,
) -> bpy.types.Object:
    """Builds an anatomically distinct head with custom skull profiles, facial features, and hair/hat."""
    # Head joint positioned at the anatomical pivot (C7 / neck base)
    head = empty("Head", (0.0, 0.520, -0.010), torso)

    # Character-specific skin tone & skull shape profiles
    skin_mat = m["skin"]
    if kind == "rifki":
        skin_mat = m["skin_elderly"]
    elif kind == "temel":
        skin_mat = m["skin_karadeniz"]

    # Continuous Neck base anchored on Torso to guarantee seamless collar fit
    spline_tube(
        "ChestNeckBase",
        [
            ((0.0, 0.425, -0.018), (0.138, 0.120)),
            ((0.0, 0.485, -0.014), (0.112, 0.098)),
            ((0.0, 0.550, -0.010), (0.094, 0.084)),
        ],
        skin_mat,
        torso,
        segs_ring=28,
        steps_per_seg=4,
    )

    # Sculpted Head Profiles per Character
    if kind == "sabri":
        # Broad, friendly Turkish Dayı skull with rounded jaw & warm cheeks
        profile_ctrl = [
            (0.520, 0.092, 0.082, 0.072, -0.008),  # neck root
            (0.555, 0.104, 0.098, 0.074, -0.010),  # mid neck
            (0.582, 0.118, 0.112, 0.076, -0.014),  # soft double-chin
            (0.615, 0.134, 0.126, 0.090, -0.014),  # rounded broad jaw
            (0.665, 0.144, 0.134, 0.114, -0.012),  # smiling cheek apples
            (0.718, 0.136, 0.126, 0.128, -0.010),  # cheekbones & temple
            (0.768, 0.124, 0.118, 0.124, -0.008),  # forehead dome
            (0.812, 0.096, 0.094, 0.098, -0.006),  # upper cranium
            (0.840, 0.052, 0.050, 0.054, -0.005),  # crown taper
            (0.848, 0.000, 0.000, 0.000, -0.005),  # crown pole
        ]
    elif kind == "rifki":
        # Slender, dignified oval skull with refined jaw & higher forehead
        profile_ctrl = [
            (0.520, 0.082, 0.074, 0.068, -0.008),  # refined neck
            (0.555, 0.092, 0.086, 0.070, -0.010),
            (0.582, 0.104, 0.098, 0.074, -0.012),
            (0.615, 0.118, 0.110, 0.086, -0.012),  # neat elegant chin
            (0.665, 0.128, 0.120, 0.110, -0.010),  # gentle cheekbones
            (0.718, 0.126, 0.118, 0.122, -0.008),  # intellectual brow
            (0.772, 0.118, 0.114, 0.120, -0.006),  # high forehead
            (0.816, 0.090, 0.088, 0.094, -0.005),
            (0.842, 0.048, 0.046, 0.050, -0.004),
            (0.848, 0.000, 0.000, 0.000, -0.004),
        ]
    elif kind == "temel":
        # Angular Black Sea skull with prominent high cheekbones & tapered jaw
        profile_ctrl = [
            (0.520, 0.084, 0.076, 0.070, -0.008),  # lean neck
            (0.555, 0.094, 0.088, 0.072, -0.010),
            (0.582, 0.106, 0.100, 0.074, -0.012),
            (0.615, 0.120, 0.112, 0.086, -0.013),  # angular chin
            (0.665, 0.138, 0.128, 0.112, -0.010),  # high Karadeniz cheekbones
            (0.718, 0.132, 0.124, 0.124, -0.008),  # keen brow
            (0.768, 0.120, 0.116, 0.122, -0.006),
            (0.812, 0.092, 0.090, 0.096, -0.005),
            (0.838, 0.050, 0.048, 0.052, -0.004),
            (0.846, 0.000, 0.000, 0.000, -0.004),
        ]
    else:  # davut
        # Broad masculine square jaw with sturdy neck and flat chin
        profile_ctrl = [
            (0.520, 0.096, 0.088, 0.076, -0.008),  # muscular neck
            (0.555, 0.110, 0.104, 0.078, -0.010),
            (0.582, 0.124, 0.118, 0.082, -0.014),
            (0.615, 0.140, 0.132, 0.094, -0.015),  # heavy square jaw
            (0.665, 0.146, 0.136, 0.118, -0.012),  # sturdy esnaf cheeks
            (0.718, 0.138, 0.128, 0.130, -0.010),  # strong brow
            (0.768, 0.126, 0.120, 0.126, -0.008),
            (0.812, 0.098, 0.096, 0.100, -0.006),
            (0.840, 0.054, 0.052, 0.056, -0.005),
            (0.848, 0.000, 0.000, 0.000, -0.005),
        ]

    bm_head = bmesh.new()
    segs_u = 64
    rings_v = 48

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
                # Recessed Eye Sockets
                for s in (-1.0, 1.0):
                    d_eye = ((px - s * 0.044) / 0.032) ** 2 + ((py - 0.722) / 0.022) ** 2
                    if d_eye < 2.2:
                        pz += 0.015 * math.exp(-d_eye) * ca
                # Expressive Brow Ridge
                for s in (-1.0, 1.0):
                    d_brow = ((px - s * 0.046) / 0.045) ** 2 + ((py - 0.752) / 0.016) ** 2
                    if d_brow < 2.5:
                        pz -= 0.010 * math.exp(-d_brow) * ca
                # Cheeks
                for s in (-1.0, 1.0):
                    d_ch = ((px - s * 0.066) / 0.046) ** 2 + ((py - 0.672) / 0.036) ** 2
                    if d_ch < 2.5:
                        pz -= 0.012 * math.exp(-d_ch) * (ca**0.6)

            row.append(bm_head.verts.new(v((px, py, pz))))
        ring_verts.append(row)

    top_pole = bm_head.verts.new(v((0.0, profile_ctrl[-1][0], profile_ctrl[-1][4])))
    bottom_pole = bm_head.verts.new(v((0.0, profile_ctrl[0][0], profile_ctrl[0][4])))
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

    make_obj("FaceSkull", bm_head, skin_mat, head, subsurf=1)

    # 1. Distinct Noses (Skin-toned natural blending, NO clown red balls!)
    nose_mat = skin_mat
    if kind == "temel":
        # ICONIC KARADENİZ KEMERLİ BURUN (Aquiline hooked nose)
        add_ellipsoid("NoseTip", (0.0, 0.680, -0.166), (0.024, 0.022, 0.026), nose_mat, head, rot_deg=(-20.0, 0.0, 0.0))
        spline_tube(
            "NoseBridge",
            [
                ((0.0, 0.742, -0.126), (0.012, 0.010)),
                ((0.0, 0.724, -0.154), (0.020, 0.016)),  # arched prominent bridge!
                ((0.0, 0.702, -0.168), (0.024, 0.018)),
                ((0.0, 0.682, -0.166), (0.022, 0.018)),
            ],
            nose_mat,
            head,
            segs_ring=16,
            steps_per_seg=5,
        )
        for s, tag in ((-1, "L"), (1, "R")):
            add_ellipsoid(f"Nostril{tag}", (s * 0.022, 0.682, -0.148), (0.013, 0.012, 0.014), nose_mat, head)
    elif kind == "rifki":
        # Refined, straight, elegant elderly gentleman nose
        add_ellipsoid("NoseTip", (0.0, 0.692, -0.146), (0.020, 0.018, 0.020), nose_mat, head, rot_deg=(-6.0, 0.0, 0.0))
        spline_tube(
            "NoseBridge",
            [
                ((0.0, 0.740, -0.124), (0.011, 0.009)),
                ((0.0, 0.718, -0.138), (0.016, 0.013)),
                ((0.0, 0.694, -0.146), (0.019, 0.015)),
            ],
            nose_mat,
            head,
            segs_ring=16,
            steps_per_seg=4,
        )
        for s, tag in ((-1, "L"), (1, "R")):
            add_ellipsoid(f"Nostril{tag}", (s * 0.020, 0.690, -0.138), (0.012, 0.011, 0.012), nose_mat, head)
    elif kind == "davut":
        # Solid, sturdy, masculine Anatolian nose
        add_ellipsoid("NoseTip", (0.0, 0.690, -0.154), (0.026, 0.022, 0.024), nose_mat, head, rot_deg=(-8.0, 0.0, 0.0))
        spline_tube(
            "NoseBridge",
            [
                ((0.0, 0.740, -0.126), (0.014, 0.012)),
                ((0.0, 0.716, -0.144), (0.022, 0.017)),
                ((0.0, 0.692, -0.154), (0.025, 0.018)),
            ],
            nose_mat,
            head,
            segs_ring=16,
            steps_per_seg=4,
        )
        for s, tag in ((-1, "L"), (1, "R")):
            add_ellipsoid(f"Nostril{tag}", (s * 0.024, 0.686, -0.144), (0.014, 0.013, 0.014), nose_mat, head)
    else:  # sabri
        # Classic friendly Turkish Dayı nose with rounded tip
        add_ellipsoid("NoseTip", (0.0, 0.692, -0.154), (0.027, 0.023, 0.025), nose_mat, head, rot_deg=(-8.0, 0.0, 0.0))
        spline_tube(
            "NoseBridge",
            [
                ((0.0, 0.740, -0.126), (0.013, 0.011)),
                ((0.0, 0.718, -0.144), (0.022, 0.017)),
                ((0.0, 0.694, -0.154), (0.026, 0.018)),
            ],
            nose_mat,
            head,
            segs_ring=16,
            steps_per_seg=4,
        )
        for s, tag in ((-1, "L"), (1, "R")):
            add_ellipsoid(f"Nostril{tag}", (s * 0.025, 0.688, -0.144), (0.014, 0.013, 0.014), nose_mat, head)

    # 2. Distinct Expressive Eyes
    iris_mat = m["iris_brown"]
    if kind == "rifki":
        iris_mat = m["iris_hazel"]
    elif kind == "temel":
        iris_mat = m["iris_blue"]
    elif kind == "davut":
        iris_mat = m["iris_dark"]

    eye_y = 0.720
    eye_z = -0.126
    for s, tag in ((-1, "L"), (1, "R")):
        ex = s * 0.044
        yaw = -s * 8.0
        add_ellipsoid(f"EyeWhite{tag}", (ex, eye_y, eye_z), (0.019, 0.014, 0.014), m["eye_white"], head, rot_deg=(0.0, yaw, 0.0))
        add_ellipsoid(f"Iris{tag}", (ex, eye_y, eye_z - 0.0105), (0.0100, 0.0100, 0.005), iris_mat, head, rot_deg=(0.0, yaw, 0.0))
        add_ellipsoid(f"Pupil{tag}", (ex, eye_y, eye_z - 0.0132), (0.0055, 0.0055, 0.004), m["pupil"], head, rot_deg=(0.0, yaw, 0.0))
        add_ellipsoid(f"EyeCatchlight{tag}", (ex - s * 0.003, eye_y + 0.003, eye_z - 0.0152), (0.0022, 0.0022, 0.002), m["eye_white"], head, subsurf=0)

        # Distinct Eyebrows
        if kind == "rifki":
            spline_tube(
                f"Brow{tag}",
                [
                    ((s * 0.018, 0.744, -0.134), (0.009, 0.007)),
                    ((s * 0.044, 0.752, -0.136), (0.010, 0.008)),
                    ((s * 0.070, 0.746, -0.126), (0.008, 0.006)),
                ],
                m["gray_hair"],
                head,
                fixed_up=Vector((0.0, 0.0, 1.0)),
            )
        elif kind == "temel":
            spline_tube(
                f"Brow{tag}",
                [
                    ((s * 0.016, 0.748, -0.136), (0.011, 0.009)),
                    ((s * 0.042, 0.760, -0.138), (0.013, 0.010)),
                    ((s * 0.072, 0.750, -0.126), (0.009, 0.007)),
                ],
                m["auburn_hair"],
                head,
                fixed_up=Vector((0.0, 0.0, 1.0)),
            )
        elif kind == "davut":
            spline_tube(
                f"Brow{tag}",
                [
                    ((s * 0.016, 0.748, -0.136), (0.014, 0.011)),
                    ((s * 0.044, 0.754, -0.138), (0.015, 0.012)),
                    ((s * 0.076, 0.748, -0.126), (0.011, 0.009)),
                ],
                m["dark_hair"],
                head,
                fixed_up=Vector((0.0, 0.0, 1.0)),
            )
        else:  # sabri
            spline_tube(
                f"Brow{tag}",
                [
                    ((s * 0.016, 0.748, -0.136), (0.012, 0.010)),
                    ((s * 0.042, 0.758, -0.138), (0.014, 0.011)),
                    ((s * 0.072, 0.750, -0.128), (0.010, 0.008)),
                ],
                m["dark_hair"],
                head,
                fixed_up=Vector((0.0, 0.0, 1.0)),
            )

        # Ears
        add_ellipsoid(f"EarBase{tag}", (s * 0.136, 0.692, -0.012), (0.016, 0.034, 0.024), m["skin_warm"], head, rot_deg=(0.0, s * 16.0, -s * 6.0))
        spline_tube(
            f"EarHelix{tag}",
            [
                ((s * 0.132, 0.714, -0.024), (0.007, 0.007)),
                ((s * 0.146, 0.720, -0.010), (0.008, 0.008)),
                ((s * 0.150, 0.694, 0.004), (0.008, 0.008)),
                ((s * 0.140, 0.666, -0.010), (0.010, 0.009)),
            ],
            m["skin_warm"],
            head,
        )

    # 3. Distinct Mustaches per Character
    if kind == "rifki":
        # Neatly trimmed gentleman's silver-gray mustache
        spline_tube(
            "Mustache",
            [
                ((-0.048, 0.656, -0.134), (0.006, 0.006)),
                ((-0.028, 0.662, -0.144), (0.011, 0.009)),
                ((0.0, 0.665, -0.148), (0.013, 0.010)),
                ((0.028, 0.662, -0.144), (0.011, 0.009)),
                ((0.048, 0.656, -0.134), (0.006, 0.006)),
            ],
            m["gray_hair"],
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )
    elif kind == "temel":
        # Dynamic Karadeniz horseshoe mustache in rich auburn
        spline_tube(
            "Mustache",
            [
                ((-0.062, 0.636, -0.130), (0.007, 0.007)),
                ((-0.048, 0.652, -0.140), (0.013, 0.011)),
                ((-0.022, 0.665, -0.150), (0.017, 0.013)),
                ((0.0, 0.668, -0.152), (0.016, 0.013)),
                ((0.022, 0.665, -0.150), (0.017, 0.013)),
                ((0.048, 0.652, -0.140), (0.013, 0.011)),
                ((0.062, 0.636, -0.130), (0.007, 0.007)),
            ],
            m["auburn_hair"],
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )
    elif kind == "davut":
        # Solid Anatolian chevron mustache in dark brown
        spline_tube(
            "Mustache",
            [
                ((-0.066, 0.652, -0.128), (0.007, 0.007)),
                ((-0.040, 0.663, -0.144), (0.016, 0.013)),
                ((0.0, 0.667, -0.150), (0.017, 0.013)),
                ((0.040, 0.663, -0.144), (0.016, 0.013)),
                ((0.066, 0.652, -0.128), (0.007, 0.007)),
            ],
            m["dark_hair"],
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )
    else:  # sabri
        # Full sweeping pala mustache
        spline_tube(
            "Mustache",
            [
                ((-0.084, 0.652, -0.120), (0.006, 0.006)),
                ((-0.068, 0.656, -0.130), (0.012, 0.010)),
                ((-0.044, 0.664, -0.144), (0.017, 0.013)),
                ((-0.020, 0.669, -0.150), (0.018, 0.014)),
                ((0.0, 0.670, -0.152), (0.017, 0.014)),
                ((0.020, 0.669, -0.150), (0.018, 0.014)),
                ((0.044, 0.664, -0.144), (0.017, 0.013)),
                ((0.068, 0.656, -0.130), (0.012, 0.010)),
                ((0.084, 0.652, -0.120), (0.006, 0.006)),
            ],
            m["dark_hair"],
            head,
            fixed_up=Vector((0.0, 0.0, 1.0)),
        )

    # Mouth, teeth & lower lip
    add_ellipsoid("MouthSmile", (0.0, 0.646, -0.142), (0.034, 0.009, 0.009), m["mouth_dark"], head)
    add_ellipsoid("UpperTeeth", (0.0, 0.650, -0.145), (0.026, 0.005, 0.007), m["teeth"], head)
    spline_tube(
        "LowerLip",
        [
            ((-0.030, 0.644, -0.136), (0.006, 0.005)),
            ((0.0, 0.638, -0.146), (0.008, 0.006)),
            ((0.030, 0.644, -0.136), (0.006, 0.005)),
        ],
        m["lip"],
        head,
        fixed_up=Vector((0.0, 0.0, 1.0)),
    )

    # 4. Distinct Hairstyles & Headwear per Character
    if kind == "sabri":
        # Wavy, textured Turkish Dayı hair with natural sideburns (NO HAT!)
        hair_pts = [
            ((-0.116, 0.690, -0.045), (0.010, 0.025)),  # sideburn L
            ((-0.128, 0.730, -0.020), (0.014, 0.040)),
            ((-0.126, 0.724, 0.035), (0.016, 0.044)),
            ((-0.098, 0.714, 0.085), (0.016, 0.044)),
            ((0.0, 0.708, 0.114), (0.017, 0.044)),
            ((0.098, 0.714, 0.085), (0.016, 0.044)),
            ((0.126, 0.724, 0.035), (0.016, 0.044)),
            ((0.128, 0.730, -0.020), (0.014, 0.040)),
            ((0.116, 0.690, -0.045), (0.010, 0.025)),  # sideburn R
        ]
        spline_tube("HairHorseshoe", hair_pts, m["dark_hair"], head, segs_ring=18, steps_per_seg=5, fixed_up=Vector((0.0, 0.0, 1.0)))
        # Layered crown hair & frontal wave
        add_ellipsoid("HairTopCap", (0.0, 0.796, -0.006), (0.130, 0.068, 0.128), m["dark_hair"], head, rot_deg=(-7.0, 0.0, 0.0))
        add_ellipsoid("HairFrontWave", (0.0, 0.812, -0.064), (0.112, 0.042, 0.058), m["dark_hair"], head, rot_deg=(-14.0, 0.0, 0.0))
        add_ellipsoid("HairLeftWave", (-0.050, 0.814, -0.050), (0.054, 0.038, 0.050), m["dark_hair"], head, rot_deg=(-12.0, -10.0, 4.0))
        add_ellipsoid("HairRightWave", (0.050, 0.814, -0.050), (0.054, 0.038, 0.050), m["dark_hair"], head, rot_deg=(-12.0, 10.0, -4.0))

    elif kind == "rifki":
        # Distinguished receding silver-gray hair (NO HAT!) + reading glasses
        hair_pts = [
            ((-0.110, 0.700, -0.020), (0.010, 0.028)),
            ((-0.120, 0.724, 0.030), (0.014, 0.038)),
            ((-0.092, 0.714, 0.080), (0.015, 0.040)),
            ((0.0, 0.708, 0.108), (0.016, 0.040)),
            ((0.092, 0.714, 0.080), (0.015, 0.040)),
            ((0.120, 0.724, 0.030), (0.014, 0.038)),
            ((0.110, 0.700, -0.020), (0.010, 0.028)),
        ]
        spline_tube("HairHorseshoe", hair_pts, m["gray_hair"], head, segs_ring=16, steps_per_seg=4, fixed_up=Vector((0.0, 0.0, 1.0)))
        add_ellipsoid("HairSideL", (-0.105, 0.755, 0.010), (0.032, 0.052, 0.078), m["gray_hair"], head, rot_deg=(6.0, 0.0, 0.0))
        add_ellipsoid("HairSideR", (0.105, 0.755, 0.010), (0.032, 0.052, 0.078), m["gray_hair"], head, rot_deg=(6.0, 0.0, 0.0))
        add_ellipsoid("HairBackNape", (0.0, 0.740, 0.075), (0.095, 0.055, 0.060), m["gray_hair"], head)

        # Elegant reading glasses resting on the bridge
        rounded_box("GlassesBridge", (0.0, 0.724, -0.144), (0.024, 0.006, 0.006), m["frames"], head, bevel=0.002)
        for s, tag in ((-1, "L"), (1, "R")):
            gx, gy, gz = s * 0.046, 0.720, -0.142
            spline_tube(
                f"GlassesRim{tag}",
                [
                    ((gx - 0.026, gy + 0.018, gz), 0.0038),
                    ((gx + 0.026, gy + 0.018, gz), 0.0038),
                    ((gx + 0.028, gy - 0.016, gz), 0.0038),
                    ((gx - 0.024, gy - 0.016, gz), 0.0038),
                    ((gx - 0.026, gy + 0.018, gz), 0.0038),
                ],
                m["frames"],
                head,
                segs_ring=8,
                steps_per_seg=3,
                cap_ends=False,
                subsurf=0,
                fixed_up=Vector((0.0, 1.0, 0.0)),
            )
            rounded_box(f"GlassesLens{tag}", (gx, gy, gz + 0.002), (0.050, 0.032, 0.003), m["glass"], head, bevel=0.001)
            spline_tube(
                f"GlassesTemple{tag}",
                [
                    ((s * 0.074, gy + 0.012, gz + 0.004), 0.0035),
                    ((s * 0.130, gy + 0.008, -0.068), 0.0035),
                    ((s * 0.138, gy - 0.004, -0.012), 0.0032),
                ],
                m["frames"],
                head,
                segs_ring=8,
                steps_per_seg=3,
                subsurf=0,
            )

    elif kind == "temel":
        # AUTHENTIC TURKISH SEKİZ KÖŞE KASKET (Eight-Panel Tweed Flat Cap)
        # Auburn wavy hair escaping underneath
        add_ellipsoid("HairSideL", (-0.108, 0.742, -0.018), (0.028, 0.036, 0.032), m["auburn_hair"], head)
        add_ellipsoid("HairSideR", (0.108, 0.742, -0.018), (0.028, 0.036, 0.032), m["auburn_hair"], head)
        add_ellipsoid("HairBackNape", (0.0, 0.728, 0.076), (0.070, 0.040, 0.036), m["auburn_hair"], head)

        # 8-Panel Kasket: Wide crown, structured front peak & button
        add_ellipsoid("CapCrown", (0.0, 0.822, -0.012), (0.144, 0.048, 0.148), m["tweed_cap"], head, rot_deg=(8.0, 0.0, 0.0))
        add_ellipsoid("CapVisor", (0.0, 0.794, -0.128), (0.108, 0.012, 0.074), m["tweed_cap"], head, rot_deg=(16.0, 0.0, 0.0))
        add_ellipsoid("CapButton", (0.0, 0.850, -0.008), (0.012, 0.008, 0.012), m["tweed_cap"], head, subsurf=0)

    else:  # davut
        # Classic vintage side-parted pompadour dark hair (NO HAT!)
        hair_pts = [
            ((-0.114, 0.696, -0.035), (0.010, 0.024)),
            ((-0.124, 0.730, -0.015), (0.013, 0.038)),
            ((-0.122, 0.724, 0.035), (0.015, 0.042)),
            ((-0.096, 0.714, 0.082), (0.015, 0.042)),
            ((0.0, 0.708, 0.110), (0.016, 0.042)),
            ((0.096, 0.714, 0.082), (0.015, 0.042)),
            ((0.122, 0.724, 0.035), (0.015, 0.042)),
            ((0.124, 0.730, -0.015), (0.013, 0.038)),
            ((0.114, 0.696, -0.035), (0.010, 0.024)),
        ]
        spline_tube("HairHorseshoe", hair_pts, m["dark_hair"], head, segs_ring=18, steps_per_seg=5, fixed_up=Vector((0.0, 0.0, 1.0)))
        add_ellipsoid("HairTopCap", (0.0, 0.796, -0.006), (0.128, 0.068, 0.126), m["dark_hair"], head, rot_deg=(-7.0, 0.0, 0.0))
        # Side-parted pompadour lifted on the left, swept to the right
        add_ellipsoid("HairPompadour", (-0.018, 0.816, -0.056), (0.110, 0.042, 0.062), m["dark_hair"], head, rot_deg=(-14.0, -6.0, 0.0))

    return head


def build_LowerBody(
    root: bpy.types.Object,
    m: dict[str, bpy.types.Material],
    pants_mat: bpy.types.Material,
    is_sabri: bool,
) -> bpy.types.Object:
    """Builds a seated lower body with clean pelvic & leg joint hierarchy."""
    pelvis = empty("Pelvis", (0.0, 0.08, -0.02), root)

    loft_garment(
        "PelvisPants",
        [
            (-0.06, 0.220, 0.195, 0.175, 0.0, -0.020),
            (0.02, 0.238, 0.218, 0.185, 0.0, -0.025),
            (0.11, 0.232, 0.212, 0.178, 0.0, -0.022),
        ],
        pants_mat,
        pelvis,
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
                pelvis,
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
            pelvis,
            sides=40,
        )
        rounded_box("BeltBuckle", (0.0, 0.112, -0.242), (0.044, 0.036, 0.012), m["gold"], pelvis, bevel=0.003)

    for side, tag in ((-1, "L"), (1, "R")):
        hip = empty(f"Hip{tag}", (side * 0.112, 0.02, -0.04), pelvis)
        knee = empty(f"Knee{tag}", (side * 0.128, -0.02, -0.33), hip)

        spline_tube(
            f"Thigh{tag}",
            [
                ((side * 0.112, 0.02, -0.04), (0.095, 0.090)),
                ((side * 0.122, 0.00, -0.19), (0.088, 0.084)),
                ((side * 0.128, -0.02, -0.33), (0.080, 0.078)),
            ],
            pants_mat,
            hip,
            segs_ring=20,
            steps_per_seg=5,
        )

        spline_tube(
            f"Calf{tag}",
            [
                ((side * 0.128, -0.02, -0.33), (0.080, 0.078)),
                ((side * 0.128, -0.13, -0.37), (0.074, 0.072)),
                ((side * 0.125, -0.28, -0.37), (0.066, 0.064)),
                ((side * 0.122, -0.42, -0.35), (0.058, 0.056)),
            ],
            pants_mat,
            knee,
            segs_ring=20,
            steps_per_seg=5,
        )

        ankle = empty(f"AnkleJoint{tag}", (side * 0.122, -0.42, -0.35), knee)

        if is_sabri:
            spline_tube(
                f"Ankle{tag}",
                [
                    ((side * 0.122, -0.42, -0.35), 0.042),
                    ((side * 0.122, -0.48, -0.35), 0.039),
                ],
                m["skin"],
                ankle,
                segs_ring=16,
                steps_per_seg=3,
            )
            rounded_box(
                f"SlipperSole{tag}",
                (side * 0.124, -0.505, -0.405),
                (0.098, 0.022, 0.215),
                m["slipper"],
                ankle,
                rot_deg=(0.0, -side * 5.0, 0.0),
                bevel=0.007,
            )
            add_ellipsoid(
                f"FootArch{tag}",
                (side * 0.124, -0.485, -0.395),
                (0.042, 0.024, 0.076),
                m["skin"],
                ankle,
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
                    ankle,
                    segs_ring=12,
                    steps_per_seg=4,
                    fixed_up=Vector((0.0, 0.0, 1.0)),
                )
            for t_i in range(5):
                tx = side * 0.124 + side * (t_i - 1.8) * 0.015
                tz = -0.482 + abs(t_i - 1.5) * 0.005
                tr = 0.011 if t_i == 0 else max(0.0065, 0.0095 - t_i * 0.0007)
                add_ellipsoid(f"Toe{tag}_{t_i}", (tx, -0.490, tz), (tr, 0.009, tr * 1.3), m["skin"], ankle, subsurf=0)
        else:
            spline_tube(
                f"Sock{tag}",
                [
                    ((side * 0.122, -0.42, -0.35), 0.041),
                    ((side * 0.122, -0.48, -0.35), 0.039),
                ],
                pants_mat,
                ankle,
                segs_ring=14,
                steps_per_seg=3,
            )
            rounded_box(
                f"ShoeSole{tag}",
                (side * 0.124, -0.505, -0.405),
                (0.095, 0.022, 0.215),
                m["belt"],
                ankle,
                rot_deg=(0.0, -side * 5.0, 0.0),
                bevel=0.005,
            )
            add_ellipsoid(
                f"ShoeUpper{tag}",
                (side * 0.124, -0.480, -0.402),
                (0.048, 0.032, 0.098),
                m["shoe_brown"],
                ankle,
                rot_deg=(4.0, -side * 5.0, 0.0),
            )

    return pelvis


def build_sabri(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Sabri")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["navy_pants"], is_sabri=True)

    # Undershirt (atlet)
    loft_garment(
        "Atlet",
        [
            (0.08, 0.228, 0.205, 0.170, 0.0, -0.020),
            (0.20, 0.258, 0.242, 0.184, 0.0, -0.026),
            (0.32, 0.250, 0.232, 0.178, 0.0, -0.022),
            (0.43, 0.220, 0.180, 0.158, 0.0, -0.012),
            (0.51, 0.150, 0.124, 0.120, 0.0, -0.004),
        ],
        m["atlet"],
        torso,
        sides=44,
        u_neck_depth=0.115,
    )

    spline_tube(
        "GoldChain",
        [
            ((-0.088, 0.510, -0.095), (0.008, 0.008)),
            ((-0.068, 0.465, -0.140), (0.009, 0.009)),
            ((-0.034, 0.438, -0.160), (0.009, 0.009)),
            ((0.0, 0.430, -0.165), (0.009, 0.009)),
            ((0.034, 0.438, -0.160), (0.009, 0.009)),
            ((0.068, 0.465, -0.140), (0.009, 0.009)),
            ((0.088, 0.510, -0.095), (0.008, 0.008)),
        ],
        m["gold"],
        torso,
        segs_ring=14,
        steps_per_seg=4,
    )

    # Track Jacket Torso with full anatomical shoulder width
    loft_garment(
        "TrackJacket",
        [
            (0.10, 0.242, 0.215, 0.180, 0.0, -0.022),
            (0.22, 0.270, 0.248, 0.194, 0.0, -0.028),
            (0.34, 0.264, 0.238, 0.188, 0.0, -0.022),
            (0.44, 0.246, 0.198, 0.174, 0.0, -0.012),  # broad shoulder span
            (0.51, 0.180, 0.144, 0.138, 0.0, -0.006),
            (0.550, 0.144, 0.126, 0.122, 0.0, -0.004),
        ],
        m["burgundy"],
        torso,
        sides=48,
        open_front_angle=math.radians(72.0),
        thickness=0.018,
    )

    # Arms with seamless shoulder joints
    for s, tag in ((-1, "L"), (1, "R")):
        sh_pos = (s * 0.226, 0.435, -0.018)
        shoulder = empty(f"Shoulder{tag}", sh_pos, torso)
        elbow = empty(f"Elbow{tag}", (s * 0.265, 0.355, -0.078), shoulder)
        wrist = empty(f"Wrist{tag}", (s * 0.200, 0.220, -0.348), elbow)

        # Seamless Deltoid Shoulder Ball connecting torso to arm with NO GAP!
        add_ellipsoid(f"ShoulderCap{tag}", sh_pos, (0.068, 0.062, 0.065), m["burgundy"], shoulder)

        # Zipper Trim
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
            steps_per_seg=4,
            subsurf=0,
        )

        # Upper Arm Sleeve
        spline_tube(
            f"JacketSleeve{tag}",
            [
                (sh_pos, (0.064, 0.058)),
                ((s * 0.265, 0.355, -0.078), (0.058, 0.054)),
                ((s * 0.252, 0.275, -0.175), (0.054, 0.050)),
            ],
            m["burgundy"],
            shoulder,
            segs_ring=22,
            steps_per_seg=5,
        )

        spline_tube(
            f"SleeveCuff{tag}",
            [
                ((s * 0.252, 0.278, -0.170), (0.057, 0.056)),
                ((s * 0.242, 0.260, -0.202), (0.052, 0.051)),
            ],
            m["white_stripe"],
            elbow,
            segs_ring=18,
            steps_per_seg=3,
        )

        # Continuous White Stripes from collar across shoulder cap down the arm
        for stripe_idx, st_off in ((0, 0.0), (1, 0.016)):
            spline_tube(
                f"ArmStripe{tag}_{stripe_idx}",
                [
                    ((s * 0.148, 0.485, -0.012 + st_off), 0.0035),
                    ((s * 0.228, 0.442, -0.018 + st_off), 0.0035),
                    ((s * 0.274, 0.358, -0.078 + st_off), 0.0035),
                    ((s * 0.258, 0.275, -0.178 + st_off), 0.0035),
                ],
                m["white_stripe"],
                shoulder,
                segs_ring=8,
                steps_per_seg=4,
                subsurf=0,
            )

        # Forearm flowing into hand
        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.240, 0.258, -0.205), (0.046, 0.042)),
                ((s * 0.220, 0.235, -0.285), (0.041, 0.035)),
                ((s * 0.202, 0.222, -0.348), (0.036, 0.026)),
            ],
            m["skin"],
            elbow,
            segs_ring=18,
            steps_per_seg=4,
        )

        build_hand_geometry(
            wrist,
            m,
            s,
            (s * 0.200, 0.220, -0.348),
            with_ring=(s == 1),
            with_watch=False,
        )

    build_head(torso, m, m["dark_hair"], "sabri")
    return root


def build_rifki(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Rifki")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["trouser_brown"], is_sabri=False)

    # Cream collared dress shirt
    loft_garment(
        "ShirtBody",
        [
            (0.10, 0.224, 0.200, 0.166, 0.0, -0.022),
            (0.22, 0.250, 0.230, 0.180, 0.0, -0.026),
            (0.34, 0.242, 0.220, 0.174, 0.0, -0.020),
            (0.44, 0.236, 0.185, 0.162, 0.0, -0.010),
            (0.535, 0.134, 0.116, 0.114, 0.0, -0.004),
        ],
        m["shirt_beige"],
        torso,
        sides=44,
    )

    # Wool Knit Sweater Vest with V-neck
    loft_garment(
        "KnitVest",
        [
            (0.10, 0.236, 0.210, 0.174, 0.0, -0.022),
            (0.22, 0.262, 0.240, 0.188, 0.0, -0.028),
            (0.34, 0.254, 0.230, 0.182, 0.0, -0.022),
            (0.44, 0.244, 0.192, 0.170, 0.0, -0.012),
            (0.525, 0.158, 0.128, 0.126, 0.0, -0.004),
        ],
        m["sweater_brown"],
        torso,
        sides=44,
        u_neck_depth=0.135,
    )

    # Shirt Collar Tips around neck
    for s, tag in ((-1, "L"), (1, "R")):
        spline_tube(
            f"CollarTip{tag}",
            [
                ((s * 0.040, 0.525, -0.116), (0.014, 0.006)),
                ((s * 0.075, 0.490, -0.138), (0.012, 0.005)),
            ],
            m["shirt_beige"],
            torso,
            segs_ring=8,
            steps_per_seg=3,
            subsurf=0,
        )

    # Arms with seamless shoulder joints
    for s, tag in ((-1, "L"), (1, "R")):
        sh_pos = (s * 0.220, 0.435, -0.018)
        shoulder = empty(f"Shoulder{tag}", sh_pos, torso)
        elbow = empty(f"Elbow{tag}", (s * 0.262, 0.355, -0.078), shoulder)
        wrist = empty(f"Wrist{tag}", (s * 0.200, 0.220, -0.348), elbow)

        # Deltoid cap in sweater vest material
        add_ellipsoid(f"ShoulderCap{tag}", sh_pos, (0.065, 0.060, 0.062), m["sweater_brown"], shoulder)

        # Sleeve in shirt material
        spline_tube(
            f"RolledSleeve{tag}",
            [
                (sh_pos, (0.062, 0.056)),
                ((s * 0.262, 0.355, -0.078), (0.056, 0.052)),
            ],
            m["shirt_beige"],
            shoulder,
            segs_ring=20,
            steps_per_seg=4,
        )

        spline_tube(
            f"RolledCuff{tag}",
            [
                ((s * 0.262, 0.355, -0.078), (0.062, 0.058)),
                ((s * 0.252, 0.315, -0.125), (0.058, 0.054)),
            ],
            m["shirt_beige"],
            elbow,
            segs_ring=20,
            steps_per_seg=3,
        )

        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.250, 0.312, -0.125), (0.046, 0.042)),
                ((s * 0.228, 0.260, -0.235), (0.040, 0.035)),
                ((s * 0.202, 0.222, -0.348), (0.035, 0.024)),
            ],
            m["skin_elderly"],
            elbow,
            segs_ring=18,
            steps_per_seg=4,
        )

        build_hand_geometry(
            wrist,
            m,
            s,
            (s * 0.200, 0.220, -0.348),
            skin_mat=m["skin_elderly"],
            with_tespih=(s == -1),
        )

    build_head(torso, m, m["gray_hair"], "rifki")
    return root


def build_temel(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Temel")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["trouser_brown"], is_sabri=False)

    # Chambray blue work shirt
    loft_garment(
        "ShirtBody",
        [
            (0.10, 0.222, 0.198, 0.164, 0.0, -0.022),
            (0.22, 0.248, 0.228, 0.178, 0.0, -0.026),
            (0.34, 0.240, 0.218, 0.172, 0.0, -0.020),
            (0.44, 0.236, 0.185, 0.162, 0.0, -0.010),
            (0.535, 0.134, 0.116, 0.114, 0.0, -0.004),
        ],
        m["shirt_chambray"],
        torso,
        sides=44,
    )

    # Olive canvas work vest
    loft_garment(
        "Waistcoat",
        [
            (0.11, 0.236, 0.210, 0.174, 0.0, -0.022),
            (0.22, 0.262, 0.240, 0.186, 0.0, -0.026),
            (0.34, 0.254, 0.230, 0.180, 0.0, -0.020),
            (0.44, 0.242, 0.192, 0.170, 0.0, -0.010),
            (0.525, 0.160, 0.130, 0.128, 0.0, -0.004),
        ],
        m["olive"],
        torso,
        sides=44,
        open_front_angle=math.radians(58.0),
        thickness=0.016,
    )

    # Arms with seamless shoulder joints
    for s, tag in ((-1, "L"), (1, "R")):
        sh_pos = (s * 0.220, 0.435, -0.018)
        shoulder = empty(f"Shoulder{tag}", sh_pos, torso)
        elbow = empty(f"Elbow{tag}", (s * 0.265, 0.355, -0.080), shoulder)
        wrist = empty(f"Wrist{tag}", (s * 0.200, 0.220, -0.348), elbow)

        # Deltoid cap in shirt material
        add_ellipsoid(f"ShoulderCap{tag}", sh_pos, (0.065, 0.060, 0.062), m["shirt_chambray"], shoulder)

        spline_tube(
            f"RolledSleeve{tag}",
            [
                (sh_pos, (0.062, 0.056)),
                ((s * 0.265, 0.355, -0.080), (0.056, 0.052)),
            ],
            m["shirt_chambray"],
            shoulder,
            segs_ring=20,
            steps_per_seg=4,
        )

        spline_tube(
            f"RolledCuff{tag}",
            [
                ((s * 0.265, 0.355, -0.080), (0.062, 0.058)),
                ((s * 0.255, 0.315, -0.125), (0.058, 0.054)),
            ],
            m["shirt_chambray"],
            elbow,
            segs_ring=20,
            steps_per_seg=3,
        )

        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.252, 0.312, -0.125), (0.046, 0.042)),
                ((s * 0.230, 0.260, -0.235), (0.040, 0.035)),
                ((s * 0.202, 0.222, -0.348), (0.035, 0.024)),
            ],
            m["skin_karadeniz"],
            elbow,
            segs_ring=18,
            steps_per_seg=4,
        )

        build_hand_geometry(wrist, m, s, (s * 0.200, 0.220, -0.348), skin_mat=m["skin_karadeniz"])

    build_head(torso, m, m["brown_hair"], "temel")
    return root


def build_davut(m: dict[str, bpy.types.Material]) -> bpy.types.Object:
    root = empty("Davut")
    torso = empty("Torso", (0.0, 0.0, 0.0), root)

    build_LowerBody(root, m, m["navy_pants"], is_sabri=False)

    # Sturdy navy rolled shirt
    loft_garment(
        "NavyShirt",
        [
            (0.10, 0.230, 0.205, 0.170, 0.0, -0.022),
            (0.22, 0.258, 0.236, 0.185, 0.0, -0.026),
            (0.34, 0.250, 0.226, 0.178, 0.0, -0.020),
            (0.44, 0.244, 0.192, 0.168, 0.0, -0.010),
            (0.535, 0.140, 0.120, 0.118, 0.0, -0.004),
        ],
        m["navy"],
        torso,
        sides=44,
    )

    # Leather esnaf apron / vest
    loft_garment(
        "ApronVest",
        [
            (0.11, 0.238, 0.212, 0.176, 0.0, -0.022),
            (0.22, 0.265, 0.244, 0.188, 0.0, -0.026),
            (0.34, 0.258, 0.234, 0.182, 0.0, -0.020),
            (0.44, 0.248, 0.196, 0.172, 0.0, -0.010),
            (0.525, 0.162, 0.132, 0.128, 0.0, -0.004),
        ],
        m["belt"],
        torso,
        sides=44,
        open_front_angle=math.radians(52.0),
        thickness=0.016,
    )

    # Arms with seamless shoulder joints
    for s, tag in ((-1, "L"), (1, "R")):
        sh_pos = (s * 0.226, 0.435, -0.018)
        shoulder = empty(f"Shoulder{tag}", sh_pos, torso)
        elbow = empty(f"Elbow{tag}", (s * 0.268, 0.355, -0.080), shoulder)
        wrist = empty(f"Wrist{tag}", (s * 0.200, 0.220, -0.348), elbow)

        # Deltoid cap in navy shirt material
        add_ellipsoid(f"ShoulderCap{tag}", sh_pos, (0.067, 0.062, 0.064), m["navy"], shoulder)

        spline_tube(
            f"RolledSleeve{tag}",
            [
                (sh_pos, (0.064, 0.058)),
                ((s * 0.268, 0.355, -0.080), (0.058, 0.054)),
            ],
            m["navy"],
            shoulder,
            segs_ring=20,
            steps_per_seg=4,
        )

        spline_tube(
            f"RolledCuff{tag}",
            [
                ((s * 0.268, 0.355, -0.080), (0.064, 0.060)),
                ((s * 0.258, 0.315, -0.125), (0.060, 0.056)),
            ],
            m["navy"],
            elbow,
            segs_ring=20,
            steps_per_seg=3,
        )

        spline_tube(
            f"Forearm{tag}",
            [
                ((s * 0.255, 0.312, -0.125), (0.048, 0.044)),
                ((s * 0.232, 0.260, -0.235), (0.042, 0.036)),
                ((s * 0.202, 0.222, -0.348), (0.036, 0.025)),
            ],
            m["skin"],
            elbow,
            segs_ring=18,
            steps_per_seg=4,
        )

        build_hand_geometry(wrist, m, s, (s * 0.200, 0.220, -0.348), with_watch=(s == -1))

    build_head(torso, m, m["dark_hair"], "davut")
    return root


def build_local_hand(m: dict[str, bpy.types.Material], side: int) -> bpy.types.Object:
    root = empty("LocalHandLeft" if side < 0 else "LocalHand")
    build_hand_geometry(root, m, side, (0.0, 0.0, 0.0), with_ring=(side > 0), with_watch=(side < 0), inward_yaw=0.0)
    return root


def select_hierarchy(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    stack = [obj]
    while stack:
        cur = stack.pop()
        cur.select_set(True)
        for ch in cur.children:
            stack.append(ch)
    bpy.context.view_layer.objects.active = obj


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

    builders = [
        ("sabri", lambda: build_sabri(m)),
        ("rifki", lambda: build_rifki(m)),
        ("temel", lambda: build_temel(m)),
        ("davut", lambda: build_davut(m)),
        ("local_hand", lambda: build_local_hand(m, 1)),
        ("local_hand_left", lambda: build_local_hand(m, -1)),
    ]

    x_offset = 0.0
    for name, fn in builders:
        root = fn()
        root.location = Vector((0.0, 0.0, 0.0))
        export_glb(root, out_dir / f"{name}.glb")
        if name == "sabri":
            variant_path = out_dir.parent / "character_variants" / "sabri_varyant01.glb"
            export_glb(root, variant_path)
        root.location = Vector((x_offset, 0.0, 0.0))
        x_offset += 1.25

    blend_dir = Path(__file__).resolve().parent / "source"
    blend_dir.mkdir(parents=True, exist_ok=True)
    blend_path = blend_dir / "kiraathane_patrons.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))


if __name__ == "__main__":
    out_dir = parse_out_dir()
    build(out_dir)
