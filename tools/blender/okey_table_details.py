"""Blender 5.2 generator for the Okey Table, Okey Rack (Istaka), Kiraathane Chair,
Okey Tiles, and Turkish Coffeehouse tabletop props.
Exports each asset as a PBR GLB into assets/models/table_details/.
"""
import bpy
import bmesh
import math
import os
import random
import sys
import numpy as np
from mathutils import Matrix, Vector


def srgb_to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def srgb_tuple(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    return (srgb_to_lin(rgb[0]), srgb_to_lin(rgb[1]), srgb_to_lin(rgb[2]))


def enum(owner, prop, value):
    values = [i.identifier for i in owner.properties[prop].enum_items]
    if not values and prop == "export_format":
        from io_scene_gltf2 import get_format_items
        values = [i[0] for i in get_format_items(None, bpy.context)]
    return next(v for v in values if v == value)


def build(project: str) -> None:
    old = bpy.data.scenes.get("Okey_Table_Details")
    if old and old.get("okey_generated"):
        for obj in list(old.objects):
            if len(obj.users_scene) == 1:
                bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new("Okey_Table_Details")
    scene["okey_generated"] = True
    bpy.context.window.scene = scene
    mats = {}
    roots = []

    def pbr(name, color_srgb, rough=0.5, metal=0.0, alpha=1.0, emission_srgb=None, emission_strength=0.0):
        m = bpy.data.materials.new("table_" + name)
        m.use_nodes = True
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        lin = srgb_tuple(color_srgb)
        p.inputs["Base Color"].default_value = (*lin, alpha)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metal
        if "Alpha" in p.inputs:
            p.inputs["Alpha"].default_value = alpha
        if alpha < 1.0 and hasattr(m, "surface_render_method"):
            items = [i.identifier for i in m.bl_rna.properties["surface_render_method"].enum_items]
            m.surface_render_method = "BLENDED" if "BLENDED" in items else items[0]
        if emission_srgb is not None and emission_strength > 0.0:
            elin = srgb_tuple(emission_srgb)
            p.inputs["Emission Color"].default_value = (*elin, 1.0)
            p.inputs["Emission Strength"].default_value = emission_strength
        mats[name] = m
        return m

    def image(path, raw=False):
        im = bpy.data.images.load(path, check_existing=True)
        if raw:
            try:
                im.colorspace_settings.name = "Non-Color"
            except TypeError:
                pass
        return im

    texture_root = os.path.join(project, "assets", "textures")
    wood_diff = image(os.path.join(texture_root, "wood_table_worn", "diffuse.jpg"))
    wood_normal = image(os.path.join(texture_root, "wood_table_worn", "nor_gl.jpg"), True)
    wood_rough = image(os.path.join(texture_root, "wood_table_worn", "rough.jpg"), True)

    for label, tint, roughness in [
        ("walnut", (1.16, 0.76, 0.48), 0.38),
        ("walnut_dark", (0.74, 0.46, 0.28), 0.44),
        ("rack_wood", (1.36, 0.94, 0.60), 0.34),
    ]:
        m = pbr(label, (1.0, 1.0, 1.0), roughness)
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        baked = wood_diff.copy()
        baked.name = "table_" + label + "_albedo"
        baked.scale(1024, 1024)
        pixels = np.empty(1024 * 1024 * 4, np.float32)
        baked.pixels.foreach_get(pixels)
        pixels = pixels.reshape(-1, 4)
        pixels[:, :3] *= np.asarray(tint, np.float32)
        baked.pixels.foreach_set(pixels.ravel())
        baked.pack()
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = baked
        m.node_tree.links.new(tex.outputs["Color"], p.inputs["Base Color"])
        tex_n = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex_n.image = wood_normal
        normal = m.node_tree.nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = 0.28
        m.node_tree.links.new(tex_n.outputs["Color"], normal.inputs["Color"])
        m.node_tree.links.new(normal.outputs["Normal"], p.inputs["Normal"])
        tex_r = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex_r.image = wood_rough
        m.node_tree.links.new(tex_r.outputs["Color"], p.inputs["Roughness"])

    pbr("resin", (0.84, 0.79, 0.69), 0.62)
    pbr("porcelain", (0.86, 0.83, 0.77), 0.42)
    pbr("cobalt", (0.10, 0.25, 0.48), 0.34)
    pbr("red_stripe", (0.72, 0.14, 0.14), 0.32)
    pbr("glass", (0.92, 0.96, 0.98), 0.08, alpha=0.18)
    pbr("tea", (0.48, 0.06, 0.02), 0.22)
    pbr("tea_surface", (0.58, 0.11, 0.03), 0.24)
    pbr("coffee", (0.28, 0.15, 0.08), 0.55)
    pbr("foam", (0.58, 0.38, 0.22), 0.70)
    pbr("steel", (0.72, 0.74, 0.76), 0.32, 0.85)
    pbr("copper", (0.72, 0.42, 0.24), 0.36, 0.82)
    pbr("brass", (0.74, 0.56, 0.26), 0.38, 0.80)
    pbr("dark_iron", (0.14, 0.13, 0.12), 0.48, 0.70)
    pbr("leather_burgundy", (0.34, 0.12, 0.11), 0.62)
    pbr("cherry_amber", (0.52, 0.08, 0.06), 0.24)
    pbr("thread", (0.25, 0.16, 0.10), 0.88)
    pbr("chickpea", (0.80, 0.62, 0.32), 0.74)
    pbr("hazelnut", (0.55, 0.32, 0.16), 0.70)
    pbr("paper", (0.82, 0.78, 0.68), 0.94)
    pbr("paper_edge", (0.78, 0.75, 0.66), 0.94)
    pbr("pad_cover", (0.22, 0.34, 0.24), 0.82)
    pbr("blue_ink", (0.18, 0.32, 0.52), 0.88)
    pbr("pencil", (0.82, 0.52, 0.18), 0.68)
    pbr("pencil_wood", (0.74, 0.56, 0.36), 0.85)
    pbr("graphite", (0.15, 0.15, 0.14), 0.75)
    pbr("cig_paper", (0.94, 0.92, 0.88), 0.85)
    pbr("cig_filter", (0.82, 0.52, 0.24), 0.78)
    pbr("cig_ash", (0.32, 0.31, 0.30), 0.95)
    pbr("cig_ember", (0.98, 0.28, 0.06), 0.40, emission_srgb=(1.0, 0.32, 0.05), emission_strength=2.4)

    resin = next(n for n in mats["resin"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if "Coat Weight" in resin.inputs:
        resin.inputs["Coat Weight"].default_value = 0.25
        resin.inputs["Coat Roughness"].default_value = 0.18

    def v(p):
        return Vector((p[0], -p[2], p[1]))

    def root(name):
        obj = bpy.data.objects.new(name, None)
        scene.collection.objects.link(obj)
        roots.append(obj)
        return obj

    def apply_planar_uv(data):
        if not data.uv_layers:
            data.uv_layers.new(name="UVMap")
        uv = data.uv_layers[0]
        for face in data.polygons:
            n = face.normal
            for loop_idx in face.loop_indices:
                co = data.vertices[data.loops[loop_idx].vertex_index].co
                if abs(n.z) > 0.65:
                    uv.data[loop_idx].uv = (co.x * 1.2, co.y * 1.2)
                elif abs(n.x) > 0.65:
                    uv.data[loop_idx].uv = (co.y * 1.2, co.z * 1.2)
                else:
                    uv.data[loop_idx].uv = (co.x * 1.2, co.z * 1.2)

    def finish(obj, name, material, parent, smooth=True):
        obj.name = name
        obj.parent = parent
        if obj.data.materials:
            obj.data.materials[0] = mats[material]
        else:
            obj.data.materials.append(mats[material])
        apply_planar_uv(obj.data)
        for polygon in obj.data.polygons:
            polygon.use_smooth = smooth
        return obj

    def active(obj):
        bpy.ops.object.select_all(action=enum(bpy.ops.object.select_all.get_rna_type(), "action", "DESELECT"))
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

    def box(name, center, size, material, parent, bevel=0.002, rot_deg=(0.0, 0.0, 0.0)):
        bpy.ops.mesh.primitive_cube_add(size=1, location=v(center))
        obj = bpy.context.object
        obj.scale = (size[0], size[2], size[1])
        obj.rotation_euler = (
            math.radians(rot_deg[0]),
            math.radians(rot_deg[2]),
            math.radians(rot_deg[1]),
        )
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            mod = obj.modifiers.new("EdgeBevel", "BEVEL")
            mod.width, mod.segments = bevel, 4
            mod.harden_normals = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
            for p in obj.data.polygons:
                p.use_smooth = True
        return finish(obj, name, material, parent)

    def mesh(name, vertices, faces, material, parent, smooth=True):
        data = bpy.data.meshes.new(name)
        data.from_pydata([v(p) for p in vertices], [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        return finish(obj, name, material, parent, smooth=smooth)

    def lathe(name, center, profile, material, parent, steps=64):
        vertices, faces = [], []
        for r, y in profile:
            for i in range(steps):
                a = math.tau * i / steps
                vertices.append((center[0] + r * math.cos(a), center[1] + y, center[2] + r * math.sin(a)))
        for j in range(len(profile) - 1):
            for i in range(steps):
                a, b = j * steps + i, j * steps + (i + 1) % steps
                faces.append((a + steps, b + steps, b, a))
        return mesh(name, vertices, faces, material, parent)

    def tube(name, points, radius, material, parent, segments=12):
        points = [Vector(p) for p in points]
        vertices, faces = [], []
        for j, p in enumerate(points):
            t = (points[min(j + 1, len(points) - 1)] - points[max(0, j - 1)]).normalized()
            normal = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
            a = t.cross(normal).normalized()
            b = t.cross(a).normalized()
            r = radius[j] if isinstance(radius, list) else radius
            for i in range(segments):
                angle = math.tau * i / segments
                vertices.append(p + r * (a * math.cos(angle) + b * math.sin(angle)))
        for j in range(len(points) - 1):
            for i in range(segments):
                a, b = j * segments + i, j * segments + (i + 1) % segments
                faces.append((a, b, b + segments, a + segments))
        faces += [
            tuple(reversed(range(segments))),
            tuple((len(points) - 1) * segments + i for i in range(segments)),
        ]
        return mesh(name, vertices, faces, material, parent)

    def sphere(name, center, radii, material, parent):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1, location=v(center))
        obj = bpy.context.object
        obj.scale = (radii[0], radii[2], radii[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return finish(obj, name, material, parent)

    def ring(name, center, radius, thickness, material, parent, vertical=False):
        points = []
        for i in range(65):
            a = math.tau * i / 64
            points.append(
                (
                    center[0] + radius * math.cos(a),
                    center[1] + (radius * math.sin(a) if vertical else 0),
                    center[2] + (0 if vertical else radius * math.sin(a)),
                )
            )
        return tube(name, points, thickness, material, parent, 12)

    # 1. OKEY TABLE (okey_table.glb) — Rounded-corner walnut coffeehouse table with turned legs & brass corners
    tbl = root("okey_table")
    TOP = 0.75
    # Under-table chassis & carved aprons
    box("TableBed", (0, TOP - 0.042, 0), (1.42, 0.068, 1.42), "walnut", tbl, 0.022)
    box("TableSkirt", (0, TOP - 0.115, 0), (1.28, 0.110, 1.28), "walnut_dark", tbl, 0.018)
    # 4 sculpted warm walnut side rails with sleek low-profile rounded moldings
    for side_idx in range(4):
        ang = side_idx * 90.0
        rad = math.radians(ang)
        cx = math.sin(rad) * 0.655
        cz = math.cos(rad) * 0.655
        box(f"TableRim_{side_idx}", (cx, TOP + 0.004, cz), (1.30, 0.032, 0.145), "walnut", tbl, 0.014, rot_deg=(0, ang, 0))
        # Inner brass inlay strip bordering the felt
        icx = math.sin(rad) * 0.582
        icz = math.cos(rad) * 0.582
        box(f"TableBrassStrip_{side_idx}", (icx, TOP + 0.019, icz), (1.16, 0.004, 0.006), "brass", tbl, 0.001, rot_deg=(0, ang, 0))

    # 4 rounded corner blocks + antique brass corner plates & rivets
    for cx_s in (-1, 1):
        for cz_s in (-1, 1):
            tag = f"{'L' if cx_s < 0 else 'R'}{'F' if cz_s < 0 else 'B'}"
            lathe(
                f"CornerWood_{tag}",
                (cx_s * 0.635, TOP - 0.016, cz_s * 0.635),
                [(0.0, 0.0), (0.096, 0.0), (0.100, 0.020), (0.092, 0.036), (0.0, 0.036)],
                "walnut",
                tbl,
                steps=32,
            )
            lathe(
                f"CornerBrass_{tag}",
                (cx_s * 0.650, TOP + 0.019, cz_s * 0.650),
                [(0.0, 0.0), (0.054, 0.0), (0.056, 0.004), (0.0, 0.004)],
                "brass",
                tbl,
                steps=24,
            )
            # Turned traditional coffeehouse leg with brass foot ferrule
            lx, lz = cx_s * 0.575, cz_s * 0.575
            lathe(
                f"TurnedLeg_{tag}",
                (lx, 0.0, lz),
                [
                    (0.0, 0.0),
                    (0.036, 0.0),
                    (0.040, 0.06),
                    (0.030, 0.13),
                    (0.045, 0.22),
                    (0.032, 0.30),
                    (0.048, 0.44),
                    (0.064, 0.56),
                    (0.060, 0.68),
                    (0.0, 0.68),
                ],
                "walnut_dark",
                tbl,
                steps=32,
            )
            lathe(
                f"LegBrassFoot_{tag}",
                (lx, 0.0, lz),
                [(0.037, 0.0), (0.042, 0.065), (0.036, 0.068)],
                "brass",
                tbl,
                steps=24,
            )

    # 2. OKEY RACK / ISTAKA (okey_rack.glb) — Stepped 2-tier triangular prism matching reference image!
    # Built for 15 tiles of size (0.036, 0.052, 0.014): total slot width = 15 * 0.038 = 0.57m -> LENGTH = 0.62m
    rack = root("okey_rack")
    LENGTH = 0.62
    TILT_RAD = 0.30
    TILT_DEG = -math.degrees(TILT_RAD)
    c_t, s_t = math.cos(TILT_RAD), math.sin(TILT_RAD)

    def rack_pt(s_along: float, n_front: float) -> tuple[float, float]:
        # s_along: distance up the sloped face (0..0.130)
        # n_front: distance normal to the sloped face (+ toward player, - toward back)
        y0, z0 = 0.008, 0.032
        return (
            y0 + s_along * c_t + n_front * s_t,
            z0 - s_along * s_t + n_front * c_t,
        )

    # Construct exact stepped triangular prism cross-section (extruded along X from -L/2 to +L/2)
    # Profile in (y, z) with 2 distinct stepped tile shelves (row 0 at s=0.004, row 1 at s=0.064)
    y_bot0, z_bot0 = rack_pt(0.000, 0.018)
    y_led0, z_led0 = rack_pt(0.004, 0.018)
    y_in0,  z_in0  = rack_pt(0.004, 0.000)
    y_top0, z_top0 = rack_pt(0.062, 0.000)
    y_led1, z_led1 = rack_pt(0.062, 0.016)
    y_in1,  z_in1  = rack_pt(0.066, -0.002)
    y_top1, z_top1 = rack_pt(0.126, -0.002)
    y_crest, z_crest = rack_pt(0.130, -0.014)

    profile_yz = [
        (0.000, z_bot0),          # 0: front bottom on felt
        (y_led0, z_led0),         # 1: row 0 front lip
        (y_in0, z_in0),           # 2: row 0 inner corner
        (y_top0, z_top0),         # 3: row 0 back top
        (y_led1, z_led1),         # 4: row 1 front lip
        (y_in1, z_in1),           # 5: row 1 inner corner
        (y_top1, z_top1),         # 6: row 1 back top (crest front)
        (y_crest, z_crest),       # 7: top spine peak
        (0.000, -0.062),          # 8: rear base on felt
    ]
    half_x = LENGTH * 0.5 - 0.014
    r_verts = []
    for sx in (-half_x, half_x):
        for py, pz in profile_yz:
            r_verts.append((sx, py, pz))
    n_p = len(profile_yz)
    r_faces = []
    for i in range(n_p):
        ni = (i + 1) % n_p
        r_faces.append((i, ni, ni + n_p, i + n_p))
    mesh("RackSteppedBody", r_verts, r_faces, "rack_wood", rack, smooth=False)

    # Sleek black metal/plastic side end-strips with 2 brass rivets on each end (just like reference image!)
    for side_s, tag in ((-1, "L"), (1, "R")):
        x_in = side_s * half_x
        x_out = side_s * (LENGTH * 0.5)
        cap_verts = []
        for sx in ((x_out, x_in) if side_s < 0 else (x_in, x_out)):
            for py, pz in profile_yz:
                cap_verts.append((sx, py + 0.0008, pz + 0.0008))
        cap_faces = []
        for i in range(n_p):
            ni = (i + 1) % n_p
            cap_faces.append((i, ni, ni + n_p, i + n_p))
        # Outer cap polygon
        if side_s < 0:
            cap_faces.append(tuple(range(n_p - 1, -1, -1)))
        else:
            cap_faces.append(tuple(range(n_p, 2 * n_p)))
        mesh(f"RackBlackCap_{tag}", cap_verts, cap_faces, "dark_iron", rack, smooth=False)

        # 2 small rivets on each black strip
        for s_riv in (0.032, 0.096):
            ry, rz = rack_pt(s_riv, 0.005)
            sphere(f"RackRivet_{tag}_{int(s_riv*100)}", (side_s * (LENGTH * 0.5 - 0.007), ry, rz), (0.0028, 0.0028, 0.0016), "steel", rack)

    # 3. KIRAATHANE CHAIR (kiraathane_chair.glb) — Traditional walnut & tufted leather chair
    chair = root("kiraathane_chair")
    box("ChairFrame", (0.0, 0.445, 0.02), (0.50, 0.065, 0.47), "walnut_dark", chair, 0.018)
    box("ChairCushion", (0.0, 0.480, 0.02), (0.46, 0.055, 0.43), "leather_burgundy", chair, 0.024)
    # Curved backrest pillars & arched crest
    for sx, tag in ((-1, "L"), (1, "R")):
        tube(
            f"ChairBackPost_{tag}",
            [(sx * 0.22, 0.45, 0.22), (sx * 0.23, 0.72, 0.24), (sx * 0.21, 0.95, 0.25)],
            0.024,
            "walnut_dark",
            chair,
            16,
        )
    tube(
        "ChairBackArch",
        [(-0.21, 0.95, 0.25), (-0.11, 0.99, 0.25), (0.0, 1.00, 0.25), (0.11, 0.99, 0.25), (0.21, 0.95, 0.25)],
        0.026,
        "walnut",
        chair,
        16,
    )
    box("ChairBackPanel", (0.0, 0.76, 0.24), (0.42, 0.36, 0.045), "walnut", chair, 0.014)
    box("ChairBackLeather", (0.0, 0.76, 0.212), (0.36, 0.30, 0.032), "leather_burgundy", chair, 0.014)
    for sx in (-0.15, 0.15):
        for sy in (0.64, 0.88):
            sphere(f"ChairStud_{sx}_{sy}", (sx, sy, 0.194), (0.006, 0.006, 0.003), "brass", chair)
    for cx_s in (-1, 1):
        for cz_s in (-1, 1):
            lx, lz = cx_s * 0.20, 0.02 + cz_s * 0.18
            lathe(
                f"ChairLeg_{cx_s}_{cz_s}",
                (lx, 0.0, lz),
                [(0.018, 0.0), (0.022, 0.08), (0.019, 0.22), (0.026, 0.44)],
                "walnut_dark",
                chair,
                20,
            )
    ring("ChairStretcher", (0.0, 0.16, 0.02), 0.21, 0.012, "walnut_dark", chair)

    # 4. OKEY TILE (okey_tile.glb) — Sleek 3.6 x 5.2 x 1.4 cm ivory melamine tile with front circular dimple
    tile = root("okey_tile")
    body = box("ResinBody", (0, 0, 0), (0.036, 0.052, 0.014), "resin", tile, 0.0024)
    # Subtle circular dimple ring on lower front face (matching reference image!)
    ring("FrontDimpleRing", (0, -0.013, 0.0068), 0.0062, 0.0006, "paper_edge", tile, vertical=True)

    # 5. INCE BELLI TEA GLASS (ince_belli_tea.glb) — Red-and-white saucer, ruby tea, spoon, sugar cubes
    tea = root("ince_belli_tea")
    lathe(
        "TeaSaucer",
        (0, 0, 0),
        [(0, 0), (0.044, 0), (0.055, 0.003), (0.058, 0.008), (0.052, 0.011), (0.026, 0.007), (0, 0.006)],
        "porcelain",
        tea,
    )
    ring("SaucerRedOuter", (0, 0.0095, 0), 0.050, 0.0016, "red_stripe", tea)
    ring("SaucerRedInner", (0, 0.0082, 0), 0.038, 0.0010, "red_stripe", tea)
    # Radial red petals on the porcelain saucer like classic kahvehane tea saucers
    for i in range(12):
        a = math.tau * i / 12
        tube(
            f"SaucerStripe_{i}",
            [
                (math.cos(a) * 0.036, 0.0085, math.sin(a) * 0.036),
                (math.cos(a) * 0.052, 0.0102, math.sin(a) * 0.052),
            ],
            0.0022,
            "red_stripe",
            tea,
            8,
        )
    lathe(
        "TeaGlass",
        (0, 0.008, 0),
        [
            (0, 0),
            (0.021, 0),
            (0.025, 0.005),
            (0.025, 0.018),
            (0.018, 0.044),
            (0.020, 0.063),
            (0.027, 0.083),
            (0.028, 0.088),
            (0.0268, 0.088),
            (0.0258, 0.083),
            (0.019, 0.063),
            (0.0168, 0.044),
            (0.0235, 0.018),
            (0.0235, 0.007),
            (0.019, 0.003),
            (0, 0.003),
        ],
        "glass",
        tea,
        80,
    )
    ring("TeaGoldRim", (0, 0.095, 0), 0.0275, 0.0008, "brass", tea)
    lathe(
        "TeaLiquid",
        (0, 0.008, 0),
        [(0, 0.003), (0.019, 0.003), (0.023, 0.008), (0.023, 0.018), (0.0162, 0.044), (0.0185, 0.063), (0.0225, 0.074), (0, 0.074)],
        "tea",
        tea,
    )
    lathe("TeaMeniscus", (0, 0.082, 0), [(0, 0), (0.0218, 0), (0.0225, 0.0008), (0.0218, 0.0012), (0, 0.0004)], "tea_surface", tea)
    tube("TeaspoonHandle", [(0.030, 0.013, -0.029), (0.038, 0.014, 0.005), (0.044, 0.013, 0.038)], 0.0014, "steel", tea)
    sphere("TeaspoonBowl", (0.030, 0.013, -0.036), (0.0062, 0.0010, 0.0088), "steel", tea)
    for s in (-1, 1):
        box(f"SugarCube_{s}", (s * 0.034, 0.013, 0.025), (0.010, 0.009, 0.010), "porcelain", tea, 0.0008)

    # 6. TURKISH COFFEE (turkish_coffee.glb)
    coffee = root("turkish_coffee")
    lathe("CoffeeSaucer", (0, 0, 0), [(0, 0), (0.044, 0), (0.054, 0.004), (0.054, 0.008), (0.048, 0.010), (0.025, 0.008), (0, 0.007)], "porcelain", coffee)
    ring("CobaltSaucerRim", (0, 0.009, 0), 0.048, 0.0012, "cobalt", coffee)
    lathe("CoffeeCup", (0, 0.009, 0), [(0, 0), (0.020, 0), (0.026, 0.004), (0.033, 0.043), (0.033, 0.053), (0.031, 0.054), (0.030, 0.043), (0.024, 0.006), (0, 0.005)], "porcelain", coffee)
    ring("CoffeeCupRim", (0, 0.063, 0), 0.032, 0.0010, "brass", coffee)
    ring("CupHandle", (0.039, 0.038, 0), 0.015, 0.0034, "brass", coffee, True)
    lathe("CoffeeFoam", (0, 0.054, 0), [(0, 0), (0.029, 0), (0.030, 0.001), (0, 0.001)], "coffee", coffee)
    rng = random.Random(72)
    for i in range(28):
        a = rng.random() * math.tau
        r = math.sqrt(rng.random()) * 0.026
        sphere(f"FoamBubble_{i}", (math.cos(a) * r, 0.055, math.sin(a) * r), (0.0012, 0.0003, 0.0012), "foam", coffee)

    # 7. CHERRY AMBER TESPIH (cherry_tespih.glb)
    beads = root("cherry_tespih")
    beadpoints = []
    for i in range(33):
        a = math.tau * i / 33
        p = (math.cos(a) * 0.026, 0.004, math.sin(a) * 0.057)
        beadpoints.append(p)
        sphere(f"AmberBead_{i}", p, (0.0040, 0.0040, 0.0048), "cherry_amber", beads)
    tube("TespihThread", beadpoints + [beadpoints[0]], 0.0007, "thread", beads)
    tube("Imame", [(0.023, 0.004, 0.021), (0.029, 0.004, 0.037), (0.033, 0.004, 0.050)], 0.0030, "cherry_amber", beads)
    for idx, offset in enumerate((-0.0015, 0.0, 0.0015)):
        tube(f"Tassel_{idx}", [(0.033 + offset, 0.003, 0.050), (0.042 + offset, 0.002, 0.069), (0.045 + offset, 0.002, 0.077)], 0.0006, "brass", beads, 6)

    # 8. LEBLEBI / CEREZ BOWL (leblebi_bowl.glb)
    nuts = root("leblebi_bowl")
    lathe("CopperBowl", (0, 0, 0), [(0, 0), (0.030, 0), (0.046, 0.010), (0.055, 0.028), (0.054, 0.031), (0.050, 0.031), (0.042, 0.012), (0.026, 0.004), (0, 0.004)], "copper", nuts)
    ring("BowlRolledRim", (0, 0.030, 0), 0.052, 0.0018, "brass", nuts)
    for i in range(36):
        a = i * 2.39996
        r = math.sqrt((i + 0.5) / 36) * 0.044
        p = (math.cos(a) * r, 0.019 + (0.005 if i % 3 == 0 else 0), math.sin(a) * r)
        nut = sphere(f"RoastedLeblebi_{i}", p, (0.0058, 0.0050, 0.0060), "chickpea" if i % 4 else "hazelnut", nuts)
        nut.rotation_euler = (rng.random(), rng.random(), rng.random())

    # 9. ASHTRAY WITH CIGARETTES (cut_glass_ashtray.glb)
    ash = root("cut_glass_ashtray")
    tray = lathe("AshtrayGlass", (0, 0, 0), [(0, 0), (0.038, 0), (0.050, 0.005), (0.052, 0.022), (0.048, 0.026), (0.039, 0.025), (0.033, 0.011), (0, 0.009)], "glass", ash, 48)
    sphere("AshMound", (0, 0.011, 0), (0.028, 0.005, 0.028), "cig_ash", ash)
    # 2 resting cigarettes with orange filters & glowing ember tip
    cig_specs = [
        ((-0.048, 0.026, -0.012), (-0.018, 0.018, -0.004), (0.012, 0.013, 0.002), True),
        ((0.014, 0.026, 0.046), (0.006, 0.018, 0.020), (-0.002, 0.013, -0.005), False),
    ]
    for c_idx, (p_filt, p_mid, p_tip, lit) in enumerate(cig_specs):
        tube(f"CigFilter_{c_idx}", [p_filt, p_mid], 0.0038, "cig_filter", ash, 12)
        tube(f"CigPaper_{c_idx}", [p_mid, p_tip], 0.0037, "cig_paper", ash, 12)
        sphere(f"CigTip_{c_idx}", p_tip, (0.0038, 0.0038, 0.0038), "cig_ember" if lit else "cig_ash", ash)

    # 10. YAZBOZ PAD & PENCIL (yazboz_pad.glb)
    pad = root("yazboz_pad")
    box("NotebookCover", (0, 0.001, 0), (0.105, 0.002, 0.078), "pad_cover", pad, 0.0015)
    for i in range(5):
        box(f"PaperSheet_{i}", (0, 0.0024 + i * 0.00045, 0), (0.101, 0.0004, 0.074), "paper_edge" if i < 4 else "paper", pad, 0.00015)
    for i in range(5):
        tube(f"RuledLine_{i}", [(-0.045, 0.0045, -0.024 + i * 0.011), (0.045, 0.0045, -0.024 + i * 0.011)], 0.00015, "blue_ink", pad, 4)
    for idx, x in enumerate((-0.023, 0.0, 0.023)):
        tube(f"ScoreColumn_{idx}", [(x, 0.0045, -0.031), (x, 0.0045, 0.025)], 0.00015, "blue_ink", pad, 4)
    tube("Pencil", [(-0.045, 0.007, 0.045), (0.037, 0.007, 0.045)], 0.0025, "pencil", pad, 8)
    tube("PencilTipWood", [(0.037, 0.007, 0.045), (0.044, 0.007, 0.045)], 0.0015, "pencil_wood", pad, 8)
    tube("GraphitePoint", [(0.044, 0.007, 0.045), (0.046, 0.007, 0.045)], 0.0006, "graphite", pad, 8)

    folder = os.path.join(project, "assets", "models", "table_details")
    os.makedirs(folder, exist_ok=True)
    for model in roots:
        model.location = Vector((0.0, 0.0, 0.0))
        active(model)
        for child in model.children_recursive:
            child.select_set(True)
        with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
            bpy.ops.export_scene.gltf(
                filepath=os.path.join(folder, model.name + ".glb"),
                export_format=enum(bpy.ops.export_scene.gltf.get_rna_type(), "export_format", "GLB"),
                use_selection=True,
                use_active_scene=True,
                export_apply=True,
                export_animations=False,
            )
    for i, model in enumerate(roots):
        model.location.x = (i % 4) * 1.65
        model.location.y = (i // 4) * 1.65
    source = os.path.join(project, "tools", "blender", "source")
    os.makedirs(source, exist_ok=True)
    bpy.data.libraries.write(os.path.join(source, "okey_table_details.blend"), {scene}, fake_user=True)
    print("TABLE_DETAILS_READY", [r.name for r in roots])


if __name__ == "__main__":
    proj = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    build(proj)
