"""Locally authored Okey resin tile and Turkish tabletop accessories. Metres, Godot axes.
Exports each prop independently; original Blender scenes are preserved.
"""
import bpy
import math
import os
import random
from mathutils import Vector


def enum(owner, prop, value):
    values = [i.identifier for i in owner.properties[prop].enum_items]
    if not values and prop == "export_format":
        from io_scene_gltf2 import get_format_items
        values = [i[0] for i in get_format_items(None,bpy.context)]
    return next(v for v in values if v == value)


def build(project):
    old = bpy.data.scenes.get("Okey_Table_Details")
    if old and old.get("okey_generated"):
        for obj in list(old.objects):
            if len(obj.users_scene) == 1:
                bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new("Okey_Table_Details")
    scene["okey_generated"] = True
    bpy.context.window.scene = scene
    mats = {}
    roots = []

    def pbr(name,color,rough=.5,metal=0,alpha=1):
        m=bpy.data.materials.new("table_"+name)
        m.use_nodes=True
        p=next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        p.inputs["Base Color"].default_value=(*color,alpha)
        p.inputs["Roughness"].default_value=rough
        p.inputs["Metallic"].default_value=metal
        p.inputs["Alpha"].default_value=alpha
        if alpha < 1:
            items=[i.identifier for i in m.bl_rna.properties['surface_render_method'].enum_items]
            m.surface_render_method=next(v for v in items if v == "BLENDED") if "BLENDED" in items else items[0]
        mats[name]=m
        return m

    pbr("resin",(.79,.75,.65),.30)
    pbr("porcelain",(.82,.78,.67),.22)
    pbr("cobalt",(.014,.057,.16),.27)
    pbr("red_line",(.35,.018,.014),.3)
    pbr("glass",(.88,.94,.96),.07,alpha=.17)
    pbr("tea",(.16,.030,.007),.12)
    pbr("tea_surface",(.23,.051,.009),.07)
    pbr("coffee",(.095,.036,.014),.62)
    pbr("foam",(.30,.15,.055),.76)
    pbr("steel",(.48,.51,.52),.22,.94)
    pbr("copper",(.48,.22,.075),.29,.86)
    pbr("brass",(.45,.29,.10),.31,.78)
    pbr("cherry_amber",(.18,.012,.007),.17)
    pbr("thread",(.067,.034,.017),.9)
    pbr("chickpea",(.56,.34,.12),.76)
    pbr("hazelnut",(.26,.10,.029),.75)
    pbr("paper",(.78,.75,.64),.94)
    pbr("paper_edge",(.59,.56,.48),.96)
    pbr("pad_cover",(.12,.18,.13),.84)
    pbr("blue_ink",(.08,.16,.23),.9)
    pbr("pencil",(.57,.27,.065),.73)
    pbr("pencil_wood",(.47,.29,.13),.88)
    pbr("graphite",(.025,.025,.022),.8)
    resin=next(n for n in mats["resin"].node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    resin.inputs["Coat Weight"].default_value=.12
    resin.inputs["Coat Roughness"].default_value=.35

    def v(p): return Vector((p[0],-p[2],p[1]))

    def root(name):
        obj=bpy.data.objects.new(name,None)
        scene.collection.objects.link(obj)
        roots.append(obj)
        return obj

    def finish(obj,name,material,parent,smooth=True):
        obj.name=name
        obj.parent=parent
        obj.data.materials.append(mats[material])
        for polygon in obj.data.polygons:
            polygon.use_smooth=smooth
        return obj

    def active(obj):
        bpy.ops.object.select_all(action=enum(bpy.ops.object.select_all.get_rna_type(),"action","DESELECT"))
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj

    def box(name,center,size,material,parent,bevel=.001):
        bpy.ops.mesh.primitive_cube_add(size=1,location=v(center))
        obj=bpy.context.object
        obj.scale=(size[0],size[2],size[1])
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if bevel:
            mod=obj.modifiers.new("Manufactured edge","BEVEL")
            mod.width,mod.segments=bevel,5
            mod.harden_normals=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
            for p in obj.data.polygons: p.use_smooth=True
            mod=obj.modifiers.new("Face normals","WEIGHTED_NORMAL")
            mod.keep_sharp=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        return finish(obj,name,material,parent)

    def mesh(name,vertices,faces,material,parent):
        data=bpy.data.meshes.new(name)
        data.from_pydata([v(p) for p in vertices],[],faces)
        data.update()
        obj=bpy.data.objects.new(name,data)
        scene.collection.objects.link(obj)
        return finish(obj,name,material,parent)

    def lathe(name,center,profile,material,parent,steps=64):
        vertices,faces=[],[]
        for r,y in profile:
            for i in range(steps):
                a=math.tau*i/steps
                vertices.append((center[0]+r*math.cos(a),center[1]+y,center[2]+r*math.sin(a)))
        for j in range(len(profile)-1):
            for i in range(steps):
                a,b=j*steps+i,j*steps+(i+1)%steps
                faces.append((a+steps,b+steps,b,a))
        return mesh(name,vertices,faces,material,parent)

    def tube(name,points,radius,material,parent,segments=10):
        points=[Vector(p) for p in points]
        vertices,faces=[],[]
        for j,p in enumerate(points):
            t=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
            normal=Vector((0,1,0)) if abs(t.y)<.9 else Vector((1,0,0))
            a=t.cross(normal).normalized();b=t.cross(a).normalized()
            for i in range(segments):
                angle=math.tau*i/segments
                vertices.append(p+radius*(a*math.cos(angle)+b*math.sin(angle)))
        for j in range(len(points)-1):
            for i in range(segments):
                a,b=j*segments+i,j*segments+(i+1)%segments
                faces.append((a,b,b+segments,a+segments))
        faces += [tuple(reversed(range(segments))),tuple((len(points)-1)*segments+i for i in range(segments))]
        return mesh(name,vertices,faces,material,parent)

    def sphere(name,center,radii,material,parent):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=v(center))
        obj=bpy.context.object
        obj.scale=(radii[0],radii[2],radii[1])
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        return finish(obj,name,material,parent)

    def ring(name,center,radius,thickness,material,parent,vertical=False):
        points=[]
        for i in range(65):
            a=math.tau*i/64
            points.append((center[0]+radius*math.cos(a),center[1]+(radius*math.sin(a) if vertical else 0),center[2]+(0 if vertical else radius*math.sin(a))))
        return tube(name,points,thickness,material,parent,10)

    # Exact existing gameplay dimensions. Numbers are separate shared Godot TextMeshes.
    tile=root("okey_tile")
    body=box("ResinBody",(0,0,0),(.048,.070,.019),"resin",tile,.0022)
    cutter=box("Mould recess cutter",(0,0,-.0101),(.030,.048,.0018),"resin",tile,.0016)
    active(body)
    mod=body.modifiers.new("Shallow common back recess","BOOLEAN")
    mod.operation=enum(mod.bl_rna,"operation","DIFFERENCE")
    mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

    tea=root("ince_belli_tea")
    lathe("TeaSaucer",(0,0,0),[(0,0),(.044,0),(.053,.003),(.055,.007),(.050,.010),(.026,.007),(0,.006)],"porcelain",tea)
    ring("SaucerRedLine",(0,.009,0),.046,.0008,"red_line",tea)
    lathe("TeaGlass",(0,.008,0),[(0,0),(.020,0),(.024,.005),(.024,.018),(.018,.043),(.020,.062),(.026,.082),(.027,.087),(.0259,.087),(.0249,.082),(.0189,.062),(.0169,.043),(.0229,.018),(.0229,.007),(.019,.003),(0,.003)],"glass",tea,80)
    lathe("TeaLiquid",(0,.008,0),[(0,.003),(.019,.003),(.022,.008),(.022,.018),(.016,.043),(.018,.062),(.0215,.072),(0,.072)],"tea",tea)
    lathe("TeaMeniscus",(0,.080,0),[(0,0),(.0208,0),(.0215,.0007),(.0208,.0011),(0,.0003)],"tea_surface",tea)
    tube("TeaspoonHandle",[(.030,.013,-.029),(.037,.013,.005),(.042,.012,.035)],.00125,"steel",tea)
    sphere("TeaspoonBowl",(.030,.013,-.035),(.0058,.0008,.0083),"steel",tea)
    for s in [-1,1]:
        box("SugarCube",(s*.033,.013,.024),(.009,.009,.009),"porcelain",tea,.0006)

    coffee=root("turkish_coffee")
    lathe("CoffeeSaucer",(0,0,0),[(0,0),(.044,0),(.054,.004),(.054,.008),(.048,.010),(.025,.008),(0,.007)],"porcelain",coffee)
    ring("CobaltSaucerRim",(0,.009,0),.048,.0012,"cobalt",coffee)
    lathe("CoffeeCup",(0,.009,0),[(0,0),(.020,0),(.026,.004),(.033,.043),(.033,.053),(.031,.054),(.030,.043),(.024,.006),(0,.005)],"porcelain",coffee)
    ring("CoffeeCupRim",(0,.063,0),.032,.0009,"cobalt",coffee)
    ring("CupHandle",(.039,.038,0),.015,.0034,"porcelain",coffee,True)
    lathe("CoffeeFoam",(0,.054,0),[(0,0),(.029,0),(.030,.001),(0,.001)],"coffee",coffee)
    rng=random.Random(72)
    for i in range(28):
        a=rng.random()*math.tau;r=math.sqrt(rng.random())*.026
        sphere("FoamBubble",(math.cos(a)*r,.055,math.sin(a)*r),(.0011,.00025,.0011),"foam",coffee)
    for i in range(10):
        a=math.tau*i/10
        sphere("CupBluePetal",(math.cos(a)*.030,.036,math.sin(a)*.030),(.0018,.0042,.0018),"cobalt",coffee)

    beads=root("cherry_tespih")
    beadpoints=[]
    for i in range(33):
        a=math.tau*i/33
        p=(math.cos(a)*.026,.004,math.sin(a)*.057)
        beadpoints.append(p)
        sphere("AmberBead",p,(.0037,.0037,.0044),"cherry_amber",beads)
    tube("TespihThread",beadpoints+[beadpoints[0]],.0006,"thread",beads)
    tube("Imame",[(.023,.004,.021),(.029,.004,.037),(.033,.004,.050)],.0027,"cherry_amber",beads)
    for offset in [-.0015,0,.0015]:
        tube("Tassel",[(.033+offset,.003,.050),(.042+offset,.002,.069),(.045+offset,.002,.077)],.0005,"brass",beads,6)

    nuts=root("leblebi_bowl")
    lathe("CopperBowl",(0,0,0),[(0,0),(.029,0),(.043,.010),(.051,.026),(.050,.029),(.047,.029),(.040,.012),(.026,.004),(0,.004)],"copper",nuts)
    ring("BowlRolledRim",(0,.028,0),.049,.0015,"brass",nuts)
    for i in range(31):
        a=i*2.39996;r=math.sqrt((i+.5)/31)*.041
        p=(math.cos(a)*r,.018+(.004 if i%3==0 else 0),math.sin(a)*r)
        nut=sphere("RoastedLeblebi",p,(.0052,.0046,.0055),"chickpea" if i%4 else "hazelnut",nuts)
        nut.rotation_euler=(rng.random(),rng.random(),rng.random())

    ash=root("cut_glass_ashtray")
    tray=lathe("AshtrayGlass",(0,0,0),[(0,0),(.035,0),(.046,.005),(.047,.021),(.044,.025),(.036,.024),(.031,.011),(0,.009)],"glass",ash,48)
    for i in range(4):
        a=math.tau*i/4
        center=Vector((math.cos(a)*.043,.025,math.sin(a)*.043))
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.004,depth=.032,location=v(center))
        cut=bpy.context.object
        cut.rotation_euler=Vector((0,0,1)).rotation_difference(v((math.cos(a),0,math.sin(a)))).to_euler()
        active(tray)
        mod=tray.modifiers.new("Cigarette rest","BOOLEAN")
        mod.operation=enum(mod.bl_rna,"operation","DIFFERENCE")
        mod.object=cut
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cut,do_unlink=True)
    for i in range(12):
        a=math.tau*i/12
        tube("CutGlassFlute",[(math.cos(a)*.040,.005,math.sin(a)*.040),(math.cos(a)*.044,.018,math.sin(a)*.044)],.0014,"glass",ash,6)

    pad=root("yazboz_pad")
    box("NotebookCover",(0,.001,0),(.105,.002,.078),"pad_cover",pad,.0015)
    for i in range(5):
        box("PaperSheet",(0,.0024+i*.00045,0),(.101,.0004,.074),"paper_edge" if i<4 else "paper",pad,.00015)
    for i in range(5):
        tube("RuledLine",[(-.045,.0045,-.024+i*.011),(.045,.0045,-.024+i*.011)],.00012,"blue_ink",pad,4)
    for x in [-.023,0,.023]:
        tube("ScoreColumn",[(x,.0045,-.031),(x,.0045,.025)],.00012,"blue_ink",pad,4)
    for z in [-.024,.024]:
        tube("Staple",[(-.047,.0047,z-.002),(-.047,.0049,z+.002)],.0004,"steel",pad,6)
    tube("Pencil",[(-.045,.007,.045),(.037,.007,.045)],.0023,"pencil",pad,6)
    tube("PencilTipWood",[(.037,.007,.045),(.044,.007,.045)],.0014,"pencil_wood",pad,6)
    tube("GraphitePoint",[(.044,.007,.045),(.046,.007,.045)],.0005,"graphite",pad,6)

    folder=os.path.join(project,"assets","models","table_details")
    os.makedirs(folder,exist_ok=True)
    for model in roots:
        active(model)
        for child in model.children_recursive:
            child.select_set(True)
        with bpy.context.temp_override(scene=scene,view_layer=scene.view_layers[0]):
            bpy.ops.export_scene.gltf(filepath=os.path.join(folder,model.name+".glb"),export_format=enum(bpy.ops.export_scene.gltf.get_rna_type(),"export_format","GLB"),use_selection=True,use_active_scene=True,export_apply=False,export_animations=False)
    for i,model in enumerate(roots):
        model.location.x=(i%4)*.32
        model.location.y=(i//4)*.25
    source=os.path.join(project,"tools","blender","source")
    os.makedirs(source,exist_ok=True)
    bpy.data.libraries.write(os.path.join(source,"okey_table_details.blend"),{scene},fake_user=True)
    print("TABLE_DETAILS_READY",[r.name for r in roots])
