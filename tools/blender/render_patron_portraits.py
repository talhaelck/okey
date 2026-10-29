import bpy
import math
import os

def render_portraits(ui_dir: str):
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
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100

    # Camera at comfortable distance, slight 3/4 angle showing face, hair, neck & chest
    cam = bpy.data.objects.get("PortraitCam")
    if not cam:
        bpy.ops.object.camera_add(location=(0.08, 1.18, 0.72))
        cam = bpy.context.view_layer.objects.active
        cam.name = "PortraitCam"
    cam.location = (0.08, 1.18, 0.72)
    cam.rotation_euler = (math.radians(88.5), math.radians(0.0), math.radians(176.0))
    cam.data.lens = 70
    scene.camera = cam

    # Lighting
    key_lt = bpy.data.objects.get("PortraitKeyLight")
    if not key_lt:
        bpy.ops.object.light_add(type='POINT', location=(0.45, 1.15, 1.10))
        key_lt = bpy.context.view_layer.objects.active
        key_lt.name = "PortraitKeyLight"
    key_lt.location = (0.45, 1.15, 1.10)
    key_lt.data.energy = 55.0
    key_lt.data.color = (1.0, 0.95, 0.88)

    fill_lt = bpy.data.objects.get("PortraitFillLight")
    if not fill_lt:
        bpy.ops.object.light_add(type='POINT', location=(-0.55, 0.95, 0.80))
        fill_lt = bpy.context.view_layer.objects.active
        fill_lt.name = "PortraitFillLight"
    fill_lt.location = (-0.55, 0.95, 0.80)
    fill_lt.data.energy = 28.0
    fill_lt.data.color = (1.0, 0.90, 0.82)

    rim_lt = bpy.data.objects.get("PortraitRimLight")
    if not rim_lt:
        bpy.ops.object.light_add(type='POINT', location=(-0.10, -0.65, 1.10))
        rim_lt = bpy.context.view_layer.objects.active
        rim_lt.name = "PortraitRimLight"
    rim_lt.location = (-0.10, -0.65, 1.10)
    rim_lt.data.energy = 38.0
    rim_lt.data.color = (1.0, 0.85, 0.60)

    all_roots = ["Sabri", "Rifki", "Temel", "Davut", "local_hand", "local_hand_left"]

    def set_tree_hide(root_obj, hide):
        root_obj.hide_render = hide
        for child in root_obj.children_recursive:
            child.hide_render = hide

    # Hide all characters completely
    for name in all_roots:
        o = bpy.data.objects.get(name)
        if o:
            set_tree_hide(o, True)

    targets = {
        "sabri": "Sabri",
        "rifki": "Rifki",
        "temel": "Temel",
        "davut": "Davut",
    }

    for p_id, root_name in targets.items():
        obj = bpy.data.objects.get(root_name)
        if not obj:
            continue
        orig_loc = obj.location.copy()
        obj.location = (0, 0, 0)
        set_tree_hide(obj, False)

        out_path = os.path.join(ui_dir, f"portrait_{p_id}.png")
        scene.render.filepath = out_path
        bpy.ops.render.render(write_still=True)
        print("Rendered portrait:", out_path)

        set_tree_hide(obj, True)
        obj.location = orig_loc

    # Restore visibility
    for name in ["Sabri", "Rifki", "Temel", "Davut"]:
        o = bpy.data.objects.get(name)
        if o:
            set_tree_hide(o, False)

if __name__ == "__main__":
    render_portraits(r"C:\Users\mfati\Documents\ChatGPT\Okey oyunu\okey\assets\ui")
