"""Local Blender architectural model for the Godot animal Okey coffeehouse.
Godot coordinates are used in the authoring helpers: metres, Y up, table at origin.
Builds in its own scene, exports PBR GLB and saves the editable Blender source.
"""
import bpy
import bmesh
import math
import os
import numpy as np
from mathutils import Vector


def enum(owner, prop, value):
    items = [i.identifier for i in owner.properties[prop].enum_items]
    if not items and prop == "export_format":
        from io_scene_gltf2 import get_format_items
        items = [i[0] for i in get_format_items(None, bpy.context)]
    return next(i for i in items if i == value)


def build(project):
    name = "Muhabbet_Interior"
    previous = bpy.data.scenes.get(name)
    if previous and previous.get("okey_generated"):
        for obj in list(previous.objects):
            if len(obj.users_scene) == 1:
                bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.scenes.remove(previous)
    scene = bpy.data.scenes.new(name)
    scene["okey_generated"] = True
    scene.unit_settings.scale_length = 1
    bpy.context.window.scene = scene
    materials, batches = {}, {}

    def mat(name, color, rough=.65, metallic=0, glow=0):
        m = bpy.data.materials.new("muhabbet_" + name)
        m.use_nodes = True
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value = (*color, 1)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = metallic
        if glow:
            p.inputs["Emission Color"].default_value = (*color, 1)
            p.inputs["Emission Strength"].default_value = glow
        materials[name] = m
        return m

    mat("plaster", (.26, .23, .18), .94)
    mat("ceiling", (.075, .065, .050), .96)
    mat("teal", (.025, .064, .055), .72)
    mat("brass", (.36, .23, .095), .36, .78)
    mat("copper", (.40, .18, .065), .32, .72)
    mat("iron", (.014, .019, .017), .55, .65)
    mat("velvet", (.12, .027, .022), .86)
    mat("ivory", (.62, .51, .34), .45)
    mat("night", (.012, .036, .050), .34, glow=.20)
    mat("bulb", (1.0, .52, .16), .3, glow=3.5)
    mat("lantern_glass", (.57, .29, .09), .38, glow=.7)

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
    # Keep the plaster organic, with restrained colour variation rather than large dark stains.
    wall = image(os.path.join(texture_root,"worn_plaster_wall","diffuse.jpg")).copy()
    wall.name = "muhabbet_plaster_albedo"
    wall.scale(1024,1024)
    wall_pixels = np.empty(1024*1024*4,np.float32)
    wall.pixels.foreach_get(wall_pixels)
    wall_pixels = wall_pixels.reshape(-1,4)
    value = wall_pixels[:,:3].mean(axis=1)
    wall_pixels[:,:3] = np.asarray((.26,.23,.18),np.float32) * (.92 + value[:,None]*.16)
    wall.pixels.foreach_set(wall_pixels.ravel())
    wall.pack()
    m = materials["plaster"]
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = wall
    m.node_tree.links.new(tex.outputs["Color"],p.inputs["Base Color"])
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image(os.path.join(texture_root,"worn_plaster_wall","nor_gl.jpg"),True)
    normal = m.node_tree.nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = .12
    m.node_tree.links.new(tex.outputs["Color"],normal.inputs["Color"])
    m.node_tree.links.new(normal.outputs["Normal"],p.inputs["Normal"])
    for label, tint, roughness in [("walnut", (.70, .58, .43), .63), ("floor", (.90, .82, .67), .74), ("darkwood", (.32, .30, .26), .68), ("counter", (.75, .64, .48), .38)]:
        m = mat(label, (1, 1, 1), roughness)
        p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        baked = wood_diff.copy()
        baked.name = "muhabbet_" + label + "_albedo"
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
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = wood_normal
        normal = m.node_tree.nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = .22
        m.node_tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
        m.node_tree.links.new(normal.outputs["Normal"], p.inputs["Normal"])
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = wood_rough
        m.node_tree.links.new(tex.outputs["Color"], p.inputs["Roughness"])

    def godot_to_blender(p):
        return Vector((p[0], -p[2], p[1]))

    def mesh(name, vertices, faces, material, bevel=0, smooth=False):
        data = bpy.data.meshes.new(name)
        data.from_pydata([godot_to_blender(p) for p in vertices], [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        data.materials.append(materials[material])
        uv = data.uv_layers.new(name="UVMap")
        for face in data.polygons:
            n = face.normal
            for loop_index in face.loop_indices:
                co = data.vertices[data.loops[loop_index].vertex_index].co
                if abs(n.z) > .65:
                    value = (co.x * .65, co.y * .65)
                elif abs(n.x) > .65:
                    value = (co.y * .7, co.z * .7)
                else:
                    value = (co.x * .7, co.z * .7)
                uv.data[loop_index].uv = value
            face.use_smooth = smooth
        if bevel:
            mod = obj.modifiers.new("Soft worn edges", "BEVEL")
            mod.width, mod.segments = bevel, 3
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.modifier_apply(modifier=mod.name)
            obj.select_set(False)
        batches.setdefault(material, []).append(obj)
        return obj

    def box(name, c, size, material, bevel=.008):
        x, y, z = c
        a, b, d = [s / 2 for s in size]
        vs = [(x-a,y-b,z-d),(x+a,y-b,z-d),(x+a,y+b,z-d),(x-a,y+b,z-d),
              (x-a,y-b,z+d),(x+a,y-b,z+d),(x+a,y+b,z+d),(x-a,y+b,z+d)]
        fs = [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)]
        return mesh(name, vs, fs, material, bevel)

    def tube(name, points, radius, material, segments=12):
        points = [Vector(p) for p in points]
        vs, fs = [], []
        for j, p in enumerate(points):
            t = (points[min(j+1,len(points)-1)] - points[max(0,j-1)]).normalized()
            a = Vector((0,1,0)) if abs(t.y) < .9 else Vector((1,0,0))
            u = t.cross(a).normalized()
            v = t.cross(u).normalized()
            r = radius[j] if isinstance(radius, list) else radius
            for i in range(segments):
                angle = math.tau * i / segments
                vs.append(p + r * (u * math.cos(angle) + v * math.sin(angle)))
        for j in range(len(points)-1):
            for i in range(segments):
                a, b = j*segments+i, j*segments+(i+1)%segments
                fs.append((a,b,b+segments,a+segments))
        fs.extend([tuple(reversed(range(segments))),tuple((len(points)-1)*segments+i for i in range(segments))])
        return mesh(name,vs,fs,material,smooth=True)

    def lathe(name, c, profile, material, steps=48):
        vs, fs = [], []
        for r,y in profile:
            for i in range(steps):
                a = math.tau*i/steps
                vs.append((c[0]+r*math.cos(a),c[1]+y,c[2]+r*math.sin(a)))
        for j in range(len(profile)-1):
            for i in range(steps):
                a,b=j*steps+i,j*steps+(i+1)%steps
                fs.append((a+steps,b+steps,b,a))
        return mesh(name,vs,fs,material,smooth=True)

    def transform(center,yaw,p):
        x,y,z = p
        return (center[0]+math.cos(yaw)*x+math.sin(yaw)*z,center[1]+y,center[2]-math.sin(yaw)*x+math.cos(yaw)*z)

    def oriented_box(name,center,yaw,c,size,material,bevel=.008):
        x,y,z=c
        a,b,d=[s/2 for s in size]
        vs=[(x-a,y-b,z-d),(x+a,y-b,z-d),(x+a,y+b,z-d),(x-a,y+b,z-d),(x-a,y-b,z+d),(x+a,y-b,z+d),(x+a,y+b,z+d),(x-a,y+b,z+d)]
        return mesh(name,[transform(center,yaw,p) for p in vs],[(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)],material,bevel)

    def arch_band(name,center,yaw,radius,spring,width,depth,material):
        vs,fs=[],[]
        for i in range(49):
            a=math.pi*i/48
            for r,d in [(radius,0),(radius-width,0),(radius-width,-depth),(radius,-depth)]:
                vs.append(transform(center,yaw,(math.cos(a)*r,spring+math.sin(a)*r,d)))
        for i in range(48):
            for j in range(4):
                a=i*4+j;b=i*4+(j+1)%4
                fs.append((a+4,b+4,b,a))
        return mesh(name,vs,fs,material,bevel=.003)

    # Long warm timber boards, real bevels and deep skirting rather than flat decals.
    for row in range(26):
        for col in range(5):
            width=7/5
            box("parquet",(-3.5+(col+.5)*width,-.034,-3.25+(row+.5)*6.5/26),(width-.006,.065,6.5/26-.005),"floor",.003)
    box("back wall",(0,1.625,-3.30),(7.15,3.25,.16),"plaster")
    # Behind the local seat: a framed timber entrance and plaster wall.
    box("front left",(-2.07,1.625,3.30),(3.01,3.25,.16),"plaster")
    box("front right",(2.07,1.625,3.30),(3.01,3.25,.16),"plaster")
    box("over entrance",(0,2.81,3.30),(1.15,.88,.16),"plaster")
    box("door inset",(0,1.15,3.35),(1.10,2.30,.10),"darkwood")
    for x in [-.59,.59]:
        box("door frame",(x,1.18,3.17),(.09,2.36,.12),"walnut")
    box("door crown",(0,2.38,3.17),(1.30,.12,.12),"walnut")
    for y in [.45,1.2,1.9]:
        box("door panels",(0,y,3.24),(.80,.52,.025),"teal")
    tube("door handle",[(.39,1.04,3.16),(.39,1.15,3.16)],.014,"brass")

    for side in [-1,1]:
        center=(side*3.5,0,0)
        yaw=-side*math.pi/2
        for u in [-2.16,2.16]:
            oriented_box("side plaster",center,yaw,(u,1.625,-.02),(2.22,3.25,.15),"plaster")
        oriented_box("under window",center,yaw,(0,.425,-.02),(2.12,.85,.15),"plaster")
        # Masonry above a genuine arched opening.
        for i in range(40):
            u0=-1.06+2.12*i/40;u1=-1.06+2.12*(i+1)/40
            h0=2.0+math.sqrt(max(0,.95**2-u0**2))
            h1=2.0+math.sqrt(max(0,.95**2-u1**2))
            vs=[(u0,h0,-.1),(u1,h1,-.1),(u1,3.25,-.1),(u0,3.25,-.1),(u0,h0,.055),(u1,h1,.055),(u1,3.25,.055),(u0,3.25,.055)]
            mesh("arch spandrel",[transform(center,yaw,p) for p in vs],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2)],"plaster")
        arch_band("window arch",center,yaw,.99,2.0,.095,.15,"walnut")
        arch_band("arch inlay",center,yaw,.925,2.0,.012,.012,"brass")
        for u in [-.94,.94]:
            oriented_box("window jamb",center,yaw,(u,1.425,.025),(.10,1.15,.14),"walnut")
        oriented_box("deep sill",center,yaw,(0,.87,.09),(2.20,.09,.37),"walnut",.018)
        # Quiet blue night glass, recessed behind the window lattice.
        glass=[(-.9,.92,-.12),(.9,.92,-.12)]
        glass += [(math.cos(a)*.90,2+math.sin(a)*.90,-.12) for a in [math.pi*i/32 for i in range(33)]]
        mesh("night glass",[transform(center,yaw,p) for p in glass],[tuple(range(len(glass)))],"night")
        for u in [-.45,0,.45]:
            h=2+math.sqrt(max(0,.90**2-u**2))
            oriented_box("mullion",center,yaw,(u,(.94+h)/2,.0),(.037,h-.94,.075),"darkwood",.004)
        for y in [1.45,2.0]:
            oriented_box("cross rail",center,yaw,(0,y,0),(1.82,.043,.075),"darkwood",.004)

    # Recessed panelling, dado, coving and exposed beams form a continuous interior.
    for side in range(4):
        yaw=side*math.pi/2
        depth=3.20 if side%2==0 else 3.44
        length=7.0 if side%2==0 else 6.5
        center=(0,0,0)
        for i in range(14):
            u=-length/2+(i+.5)*length/14
            oriented_box("panel inset",center,yaw,(u,.43,-depth),(length/14-.065,.68,.04),"teal")
            oriented_box("panel stile",center,yaw,(u-length/28,.44,-depth+.034),(.032,.83,.065),"darkwood")
        for y,height in [(.055,.10),(.87,.07),(.94,.035),(3.06,.12)]:
            oriented_box("moulding",center,yaw,(0,y,-depth+.045),(length,height,.10),"walnut")
        oriented_box("dado inlay",center,yaw,(0,.905,-depth+.10),(length,.009,.009),"brass",.001)
    box("ceiling",(0,3.29,0),(7.2,.12,6.7),"ceiling")
    for z in [-2.8,-1.4,0,1.4,2.8]:
        box("ceiling beam",(0,3.13,z),(7.0,.19,.16),"darkwood",.012)
    for x in [-2.65,2.65]:
        box("cross beam",(x,3.03,0),(.13,.15,6.5),"walnut")

    # The service counter and arched shelving: strongly lit recesses and polished edges.
    box("counter carcass",(0,.405,-2.67),(5.55,.81,.57),"darkwood",.018)
    for i in range(9):
        x=(i-4)*.60
        box("counter inset",(x,.43,-2.367),(.50,.61,.025),"teal")
        box("counter stile",(x-.285,.44,-2.34),(.035,.70,.05),"walnut")
    box("counter worktop",(0,.86,-2.61),(5.72,.10,.79),"counter",.028)
    tube("brass foot rail",[(-2.5,.20,-2.20),(2.5,.20,-2.20)],.022,"brass")
    for x in [-2.25,2.25]:
        box("shelf recess",(x,1.86,-3.18),(1.08,1.75,.09),"darkwood")
        arch_band("alcove arch",(x,0,-3.04),0,.60,2.20,.075,.18,"walnut")
        for dx in [-.56,.56]:
            box("alcove post",(x+dx,1.65,-3.04),(.08,1.16,.22),"walnut")
        for y in [1.12,1.50,1.88,2.25]:
            box("shelf",(x,y,-3.0),(1.22,.045,.32),"counter",.008)
            box("shelf brass lip",(x,y-.025,-2.825),(1.21,.008,.012),"brass",.001)
    box("coffee board",(0,2.34,-3.04),(1.48,.34,.075),"walnut",.012)
    for x in [-.55,.55]:
        tube("sign hanger",[(x,2.60,-3.12),(x,2.58,-3.03),(x,2.50,-3.03)],.004,"iron",8)

    # Brass pendant and two lantern sconces. Godot supplies matching actual lights.
    tube("pendant cable",[(0,3.06,0),(0,2.35,0)],.008,"iron")
    shade=[(.045,.20),(.055,.15),(.13,.11),(.25,.035),(.30,0),(.30,-.012),(.28,-.014),(.23,.025),(.12,.10),(.04,.14)]
    lathe("pendant outer",(0,2.18,0),shade,"iron")
    lathe("pendant lining",(0,2.176,0),[(.278,0),(.23,.030),(.12,.103),(.045,.145)],"ivory")
    lathe("pendant rolled lip",(0,2.17,0),[(.285,0),(.300,.004),(.300,.012),(.285,.016)],"brass")
    lathe("pendant bulb",(0,2.17,0),[(0,-.045),(.023,-.035),(.027,0),(.018,.035),(0,.05)],"bulb",32)
    for x in [-3.0,3.0]:
        box("lantern back",(x,2.04,-3.10),(.14,.34,.045),"iron")
        tube("lantern bracket",[(x,2.18,-3.06),(x,2.20,-2.88),(x,2.10,-2.84)],.012,"brass")
        lathe("lantern roof",(x,2.15,-2.86),[(0,.05),(.09,.015),(.10,0),(.085,-.01)],"iron",8)
        lathe("lantern light",(x,1.99,-2.86),[(.057,0),(.063,.02),(.063,.13),(.055,.16)],"lantern_glass",8)
        for i in range(8):
            a=math.tau*i/8
            tube("lantern ribs",[(x+math.cos(a)*.066,1.98,-2.86+math.sin(a)*.066),(x+math.cos(a)*.066,2.15,-2.86+math.sin(a)*.066)],.004,"brass",8)
        lathe("lantern base",(x,1.97,-2.86),[(0,0),(.08,0),(.085,.012),(.06,.025)],"iron",8)

    # Upholstered corner seating, turned legs and small side tables complete the room behind the player.
    for side in [-1,1]:
        x=side*2.55
        box("banquette plinth",(x,.23,2.83),(1.45,.38,.60),"darkwood",.025)
        box("banquette cushion",(x,.46,2.80),(1.42,.14,.59),"velvet",.05)
        box("banquette back",(x,.83,3.06),(1.47,.69,.14),"walnut",.025)
        box("banquette pad",(x,.84,2.966),(1.33,.53,.09),"velvet",.035)
        for i in range(5):
            for y in [.72,.94]:
                lathe("upholstery stud",(x+(i-2)*.25,y,2.91),[(0,0),(.007,0),(.007,.004),(0,.006)],"brass",12)
        lathe("side table foot",(x,0,1.98),[(0,0),(.26,0),(.27,.04),(.065,.08),(.05,.65),(.20,.69)],"darkwood")
        lathe("side table top",(x,.69,1.98),[(0,0),(.35,0),(.36,.025),(.35,.055),(0,.055)],"counter")

    # Group by PBR material, preserving physical geometry and UVs.
    for label, objects in batches.items():
        bpy.ops.object.select_all(action=enum(bpy.ops.object.select_all.get_rna_type(),"action","DESELECT"))
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:
            bpy.ops.object.join()
        objects[0].name="Interior_"+label
    bpy.ops.object.select_all(action=enum(bpy.ops.object.select_all.get_rna_type(),"action","SELECT"))
    folder=os.path.join(project,"assets","models","environment")
    os.makedirs(folder,exist_ok=True)
    with bpy.context.temp_override(scene=scene, view_layer=scene.view_layers[0]):
        bpy.ops.export_scene.gltf(filepath=os.path.join(folder,"muhabbet_interior.glb"),export_format=enum(bpy.ops.export_scene.gltf.get_rna_type(),"export_format","GLB"),use_selection=False,use_active_scene=True,export_animations=False,export_apply=False)
    source=os.path.join(project,"tools","blender","source")
    os.makedirs(source,exist_ok=True)
    bpy.data.libraries.write(os.path.join(source,"muhabbet_interior.blend"),{scene},fake_user=True)
    print("INTERIOR_READY",len(scene.objects),"material groups; original Blender scenes preserved")
