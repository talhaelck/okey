import bpy
import math
import os

def build_logo_emblem(output_path: str):
    bpy.ops.wm.read_homefile(use_empty=True)
    scene = bpy.context.scene

    avail_engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    if 'BLENDER_EEVEE_NEXT' in avail_engines:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    elif 'BLENDER_EEVEE' in avail_engines:
        scene.render.engine = 'BLENDER_EEVEE'
    else:
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 32

    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100

    def active_obj():
        return bpy.context.view_layer.objects.active

    def make_mat(name, color, roughness=0.35, metallic=0.0):
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs['Base Color'].default_value = color
            bsdf.inputs['Roughness'].default_value = roughness
            bsdf.inputs['Metallic'].default_value = metallic
        return mat

    mat_wood_dark = make_mat("DarkWalnut", (0.28, 0.14, 0.07, 1.0), 0.45)
    mat_wood_inner = make_mat("InnerWalnut", (0.38, 0.20, 0.10, 1.0), 0.50)
    mat_gold_rim = make_mat("GoldRim", (0.88, 0.65, 0.22, 1.0), 0.25, 0.40)
    mat_okey_text = make_mat("OkeyIvory", (0.98, 0.94, 0.85, 1.0), 0.22)
    mat_banner_bg = make_mat("BannerBg", (0.16, 0.07, 0.03, 1.0), 0.45)
    mat_banner_gold = make_mat("BannerGold", (0.98, 0.82, 0.36, 1.0), 0.25, 0.30)
    mat_tile_ivory = make_mat("TileIvory", (0.97, 0.94, 0.89, 1.0), 0.18)
    mat_tile_red = make_mat("TileRed", (0.86, 0.10, 0.08, 1.0), 0.25)
    mat_tile_blue = make_mat("TileBlue", (0.08, 0.42, 0.88, 1.0), 0.25)
    mat_saucer = make_mat("Saucer", (0.92, 0.92, 0.94, 1.0), 0.15, 0.10)
    mat_tea = make_mat("RubyTea", (0.75, 0.04, 0.01, 1.0), 0.08)
    mat_tea_rim = make_mat("TeaGoldRim", (0.92, 0.75, 0.28, 1.0), 0.20, 0.60)
    mat_mustache = make_mat("Mustache", (0.12, 0.05, 0.02, 1.0), 0.55)

    # 1. Main Background Shield Plaque (Warm walnut shield cartouche)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.58, depth=0.16, location=(0, 0.20, 0.04))
    plaque = active_obj()
    plaque.name = "Plaque"
    plaque.scale = (1.32, 1.0, 0.96)
    plaque.rotation_euler = (math.radians(90), 0, 0)
    plaque.data.materials.append(mat_wood_dark)

    # Inner plaque plate
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.46, depth=0.18, location=(0, 0.18, 0.04))
    inner = active_obj()
    inner.scale = (1.32, 1.0, 0.96)
    inner.rotation_euler = (math.radians(90), 0, 0)
    inner.data.materials.append(mat_wood_inner)

    # Outer Gold Bevel Rim
    bpy.ops.mesh.primitive_torus_add(major_radius=1.58, minor_radius=0.08, major_segments=64, minor_segments=16, location=(0, 0.14, 0.04))
    rim = active_obj()
    rim.name = "PlaqueRim"
    rim.scale = (1.32, 1.0, 0.96)
    rim.rotation_euler = (math.radians(90), 0, 0)
    rim.data.materials.append(mat_gold_rim)

    # 2. 3D Text "OKEY" (Centered, prominent, beautiful bevel)
    bpy.ops.object.text_add(location=(0, -0.06, 0.18))
    txt_okey = active_obj()
    txt_okey.name = "Text_OKEY"
    txt_okey.data.body = "OKEY"
    txt_okey.data.align_x = 'CENTER'
    txt_okey.data.align_y = 'CENTER'
    txt_okey.data.size = 1.15
    txt_okey.data.extrude = 0.16
    txt_okey.data.bevel_depth = 0.032
    txt_okey.data.bevel_resolution = 4
    txt_okey.rotation_euler = (math.radians(90), 0, 0)
    txt_okey.data.materials.append(mat_okey_text)

    # 3. Lower Banner Ribbon for "KIRAATHANE"
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.02, -0.56))
    banner = active_obj()
    banner.name = "BannerRibbon"
    banner.scale = (2.42, 0.12, 0.44)
    banner.data.materials.append(mat_banner_bg)

    # Gold rim around banner
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.04, -0.56))
    banner_rim = active_obj()
    banner_rim.scale = (2.48, 0.09, 0.50)
    banner_rim.data.materials.append(mat_gold_rim)

    # 3D Text "KIRAATHANE"
    bpy.ops.object.text_add(location=(0, -0.10, -0.56))
    txt_kiraathane = active_obj()
    txt_kiraathane.name = "Text_KIRAATHANE"
    txt_kiraathane.data.body = "KIRAATHANE"
    txt_kiraathane.data.align_x = 'CENTER'
    txt_kiraathane.data.align_y = 'CENTER'
    txt_kiraathane.data.size = 0.35
    txt_kiraathane.data.extrude = 0.09
    txt_kiraathane.data.bevel_depth = 0.015
    txt_kiraathane.data.bevel_resolution = 3
    txt_kiraathane.rotation_euler = (math.radians(90), 0, 0)
    txt_kiraathane.data.materials.append(mat_banner_gold)

    # 4. Flanking Okey Tiles:
    # Left Tile (8)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.54, 0.02, -0.54))
    tile_left = active_obj()
    tile_left.name = "Tile_Left"
    tile_left.scale = (0.38, 0.10, 0.52)
    tile_left.rotation_euler = (0, 0, math.radians(-12))
    tile_left.data.materials.append(mat_tile_ivory)

    bpy.ops.object.text_add(location=(-1.54, -0.06, -0.49))
    num_8 = active_obj()
    num_8.data.body = "8"
    num_8.data.align_x = 'CENTER'
    num_8.data.align_y = 'CENTER'
    num_8.data.size = 0.30
    num_8.data.extrude = 0.04
    num_8.rotation_euler = (math.radians(90), 0, math.radians(-12))
    num_8.data.materials.append(mat_tile_red)

    # Right Tile (?)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.54, 0.02, -0.54))
    tile_right = active_obj()
    tile_right.name = "Tile_Right"
    tile_right.scale = (0.38, 0.10, 0.52)
    tile_right.rotation_euler = (0, 0, math.radians(12))
    tile_right.data.materials.append(mat_tile_ivory)

    bpy.ops.object.text_add(location=(1.54, -0.06, -0.49))
    q_mark = active_obj()
    q_mark.data.body = "?"
    q_mark.data.align_x = 'CENTER'
    q_mark.data.align_y = 'CENTER'
    q_mark.data.size = 0.30
    q_mark.data.extrude = 0.04
    q_mark.rotation_euler = (math.radians(90), 0, math.radians(12))
    q_mark.data.materials.append(mat_tile_blue)

    # 5. Top Crest: Authentic Turkish Tea Glass (İnce Belli)
    # Saucer
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.40, depth=0.06, location=(0, 0.08, 1.16))
    saucer = active_obj()
    saucer.rotation_euler = (math.radians(18), 0, 0)
    saucer.data.materials.append(mat_saucer)

    # Saucer gold ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.40, minor_radius=0.016, major_segments=32, minor_segments=8, location=(0, 0.08, 1.18))
    s_ring = active_obj()
    s_ring.rotation_euler = (math.radians(18), 0, 0)
    s_ring.data.materials.append(mat_tea_rim)

    # Glass lower bulb
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.18, depth=0.18, location=(0, 0.04, 1.28))
    g_bottom = active_obj()
    g_bottom.rotation_euler = (math.radians(18), 0, 0)
    g_bottom.data.materials.append(mat_tea)

    # Glass waist (narrow neck)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.12, depth=0.14, location=(0, 0.0, 1.42))
    g_waist = active_obj()
    g_waist.rotation_euler = (math.radians(18), 0, 0)
    g_waist.data.materials.append(mat_tea)

    # Glass top flare
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.19, depth=0.18, location=(0, -0.04, 1.55))
    g_top = active_obj()
    g_top.rotation_euler = (math.radians(18), 0, 0)
    g_top.data.materials.append(mat_tea)

    # Glass gold rim
    bpy.ops.mesh.primitive_torus_add(major_radius=0.19, minor_radius=0.014, major_segments=24, minor_segments=8, location=(0, -0.07, 1.64))
    g_rim = active_obj()
    g_rim.rotation_euler = (math.radians(18), 0, 0)
    g_rim.data.materials.append(mat_tea_rim)

    # Steam swirl
    for s_idx, s_x in enumerate([-0.05, 0.05]):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.10, minor_radius=0.022, major_segments=24, minor_segments=10, location=(s_x, -0.08, 1.80 + s_idx * 0.14))
        steam = active_obj()
        steam.rotation_euler = (math.radians(35), math.radians(25 * (1 if s_idx == 0 else -1)), 0)
        steam_mat = make_mat(f"Steam_{s_idx}", (0.98, 0.92, 0.82, 0.65), 0.20)
        steam.data.materials.append(steam_mat)

    # 6. Bottom Turkish Mustache (Pala Bıyık)
    # Center knot
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.09, depth=0.08, location=(0, -0.06, -0.88))
    m_mid = active_obj()
    m_mid.rotation_euler = (math.radians(90), 0, 0)
    m_mid.data.materials.append(mat_mustache)

    # Curved wings
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.14, radius2=0.015, depth=0.68, location=(side * 0.32, -0.05, -0.90))
        stache = active_obj()
        stache.name = f"Mustache_{side}"
        stache.rotation_euler = (math.radians(90), math.radians(side * -26), math.radians(side * 82))
        stache.scale = (1.1, 0.6, 1.15)
        stache.data.materials.append(mat_mustache)

    # 7. Lighting
    # Key light
    bpy.ops.object.light_add(type='SUN', location=(3.5, -6.5, 4.5))
    sun = active_obj()
    sun.data.energy = 4.5
    sun.data.color = (1.0, 0.96, 0.88)
    sun.rotation_euler = (math.radians(38), math.radians(16), math.radians(24))

    # Rim light from behind/top
    bpy.ops.object.light_add(type='POINT', location=(-2.0, 3.5, 3.0))
    rim_lt = active_obj()
    rim_lt.data.energy = 90.0
    rim_lt.data.color = (1.0, 0.88, 0.60)

    # Front fill light
    bpy.ops.object.light_add(type='POINT', location=(0.0, -4.5, 0.1))
    fill_lt = active_obj()
    fill_lt.data.energy = 110.0
    fill_lt.data.color = (1.0, 0.94, 0.85)

    # Camera
    bpy.ops.object.camera_add(location=(0, -6.6, 0.16))
    cam = active_obj()
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.data.lens = 42
    scene.camera = cam

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    scene.render.filepath = output_path
    bpy.ops.render.render(write_still=True)
    print("Emblem rendered successfully to:", output_path)

if __name__ == "__main__":
    out = r"C:\Users\mfati\Documents\ChatGPT\Okey oyunu\okey\assets\ui\logo_emblem.png"
    build_logo_emblem(out)
