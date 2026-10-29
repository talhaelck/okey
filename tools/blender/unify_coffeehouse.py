"""Coherent 360-degree cafe art pass. Separate source scenes, preserved originals.
Run build(base) through Blender MCP; all game-space dimensions are metres.
"""
import bpy, math, os
from mathutils import Vector, Matrix

def build(base):
    path=os.path.join(base,'tools/blender/source/kahvehane_atmosphere.blend')
    with bpy.data.libraries.load(path,link=False) as (src,dst):
        dst.scenes=[s for s in src.scenes if s.startswith('Kahvehane_Atmosfer')][:1]
    scene=dst.scenes[0];scene.name='Kahvehane_Butunluk';bpy.context.window.scene=scene
    def v(p): return Vector((p[0],-p[2],p[1]))
    def material(name,hex,rough=.7,metal=0):
        m=bpy.data.materials.new(name);m.use_nodes=True
        n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        rgb=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
        rgb=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
        n.inputs['Base Color'].default_value=(*rgb,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal
        return m
    mats={k:material(k,*a) for k,a in {
        'CafeWalnut':('69513c',.73), 'CafeWalnutEdge':('504331',.78),
        'CafeEnamel':('343e36',.38,.22), 'CafeStoveIron':('323431',.68,.35),
        'CafeStoveEdge':('575850',.49,.65), 'CafeHearth':('6c716a',.92),
        'CafeWarmLinen':('b9b2a0',.96), 'CafeLampCream':('d4c6aa',.55),
        'CafeLampBrass':('8b7758',.55,.55), 'CafeDark':('171b18',.91),
        'CafeStoveFire':('682e13',.95), 'CafeRackWood':('806446',.65)
    }.items()}
    def assign(o,name,key):o.name=name;o.data.materials.clear();o.data.materials.append(mats[key]);return o
    def smooth(o):
        for p in o.data.polygons:p.use_smooth=True
        return o
    def edge(o,width=.005,segments=4):
        bpy.context.view_layer.objects.active=o
        m=o.modifiers.new('Crafted edge radius','BEVEL');m.width=width;m.segments=segments
        bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Stable surface normals','WEIGHTED_NORMAL');m.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=m.name)
        return o
    def box(name,p,size,key,r=.006):
        bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object
        o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        assign(o,name,key)
        if r:edge(o,min(r,min(size)*.4))
        return o
    def mesh(name,pts,faces,key):
        d=bpy.data.meshes.new(name);d.from_pydata([v(p) for p in pts],[],faces);d.update()
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);assign(o,name,key);return o
    def tube(name,pts,r,key):
        d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.resolution_u=24;d.bevel_depth=r;d.bevel_resolution=4
        sp=d.splines.new('BEZIER');sp.bezier_points.add(len(pts)-1)
        for bp,p in zip(sp.bezier_points,pts):bp.co=v(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);d.materials.append(mats[key]);return o
    def lathe(name,p,prof,key,n=96):
        pts=[(p[0]+r*math.cos(j*math.tau/n),p[1]+h,p[2]+r*math.sin(j*math.tau/n)) for r,h in prof for j in range(n)]
        faces=[(k*n+j,(k+1)*n+j,(k+1)*n+(j+1)%n,k*n+(j+1)%n) for k in range(len(prof)-1) for j in range(n)]
        return smooth(mesh(name,pts,faces,key))
    def remove_tree(o):
        for c in list(o.children_recursive):bpy.data.objects.remove(c,do_unlink=True)
        bpy.data.objects.remove(o,do_unlink=True)
    # Remove competing accent objects; architectural rhythm replaces isolated decoration.
    remove_prefix=('Brick bay','Aged brick','Antique','Decorative hunting','Walnut fore','Trigger guard','Rifle wall','Radiator','Draped work','Jacket sleeve','Coat hook','Curved coat')
    for o in list(scene.objects):
        if o.name.startswith(remove_prefix):remove_tree(o)
    shell=('Back lime','Entry lime','Left lime','Right lime','Window below','Window above','Quiet ceiling','Wide floor','Sage tongue','Wall rail','Window oak','Deep window','WindowOutside','Window mullion','Window transom','Curtain pole','Soft linen','Entrance oak','Door frame','Door frosted','Door handle')
    # Expand only the architecture. The table, chair sizes and all game coordinates stay intact.
    for o in list(scene.objects):
        if o.parent is None and o.name.startswith(shell):
            o.location.x*=1.15;o.location.y*=1.18;o.scale.x*=1.15;o.scale.y*=1.18
        if o.type=='MESH' and o.name.startswith(('Sage tongue','Wall rail')):
            o.data=o.data.copy();assign(o,o.name,'CafeWalnut' if o.name.startswith('Sage') else 'CafeWalnutEdge')
        if o.name.startswith('Soft linen'):
            o.data=o.data.copy();assign(o,o.name,'CafeWarmLinen')
    # Relocate complete assemblies, keeping their contents and real-world proportions.
    def move_group(o,old,new,angle=0):
        o.matrix_world=Matrix.Translation(v(new))@Matrix.Rotation(angle,4,'Z')@Matrix.Translation(-v(old))@o.matrix_world
    service=next(o for o in scene.objects if o.name.startswith('ServiceCounterAssembly'))
    move_group(service,(-2.62,0,-3.78),(-4.42,0,-2.85),math.pi/2)
    # The counter canopy has a folded edge now; flat razor-thin corners no longer catch light.
    for o in service.children_recursive:
        if o.name.startswith('Folded copper canopy'):o.data=o.data.copy();edge(o,.012)
    # TV belongs to the rear seating nook; all parts shift together.
    for o in scene.objects:
        if o.parent is None and o.name.startswith(('CRT','TV ')):o.location+=v((.35,0,-.78))
    clock=next(o for o in scene.objects if o.name.startswith('WallClock'));clock.location.x=-4.77
    old_tables=[(-3.084,0,2.304),(3.06,0,-2.70)]
    new_tables=[(-2.85,0,-1.70),(2.95,0,1.85)]
    for o in list(scene.objects):
        if o.parent is None and o.name.startswith(('BackgroundTable','PlasticCafeChair','BentwoodCafeChair','Background_','TeaGlass','Pendant')):
            if o.name.startswith('Pendant') and abs(o.location.x)<.1:continue
            i=0 if o.location.x<0 else 1
            # A half turn keeps the chairs around their own table and facing inward.
            move_group(o,old_tables[i],new_tables[i],math.pi)
    # Old stove is preserved in the previous source, replaced here with a compact enamel kuzine.
    stove=next(o for o in scene.objects if o.name.startswith('CornerSoba'));remove_tree(stove)
    before=set(scene.objects)
    box('Kuzine hearth slab',(0,.022,0),(.94,.045,.83),'CafeHearth',.025)
    for x in [-.255,.255]:
        for z in [-.20,.20]:
            tube('Kuzine curved cast foot',[(x*1.1,.045,z*1.12),(x,.075,z),(x*.92,.17,z*.9)],.022,'CafeStoveIron')
    box('Kuzine rounded enamel casing',(0,.40,0),(.60,.48,.49),'CafeEnamel',.035)
    box('Kuzine lower cast plinth',(0,.167,0),(.635,.055,.525),'CafeStoveIron',.018)
    box('Kuzine rolled top',(0,.655,0),(.66,.05,.55),'CafeStoveEdge',.025)
    box('Kuzine inset hotplate',(0,.684,0),(.60,.012,.49),'CafeStoveIron',.020)
    for x,r in [(-.16,.105),(.14,.11)]:
        lathe('Kuzine lift out cooking lid',(x,.693,.035),[(0,0),(r-.006,0),(r,.002),(r,.006),(r-.004,.009),(0,.009)],'CafeStoveEdge')
        for rad in [r*.50,r*.80]:lathe('Hotplate concentric seam',(x,.702,.035),[(rad-.0008,0),(rad+.0008,0)],'CafeDark')
        box('Hotplate lifting notch',(x,.702,.035),(.023,.002,.005),'CafeDark',.001)
    # Framed firebox and warming compartment, authentic solid doors rather than a fake glowing screen.
    for x,w in [(-.165,.205),(.115,.285)]:
        box('Cast door shadow reveal',(x,.438,.251),(w+.028,.293,.016),'CafeDark',.016)
        box('Enamel oven door',(x,.438,.264),(w,.265,.026),'CafeEnamel',.015)
        box('Door recessed centre',(x,.438,.280),(w-.035,.216,.006),'CafeStoveIron',.012)
        for h in [.345,.53]:tube('Barrel door hinge',[(x-w/2-.006,h-.022,.279),(x-w/2-.006,h+.022,.279)],.009,'CafeStoveEdge')
        tube('Oven nickel latch',[(x+w*.25,.46,.282),(x+w*.25,.46,.316),(x+w*.25,.408,.316)],.006,'CafeStoveEdge')
    box('Kuzine ash drawer',(-.165,.24,.264),(.205,.064,.026),'CafeStoveIron',.008)
    tube('Ash drawer pull',[(-.20,.24,.28),(-.20,.24,.312),(-.13,.24,.312),(-.13,.24,.28)],.0045,'CafeStoveEdge')
    # Small vent slots provide depth and real occlusion without conspicuous emissive dots.
    for i in range(5):box('Firebox ventilation slot',(-.227+i*.031,.37,.286),(.017,.008,.004),'CafeDark',.002)
    lathe('Kuzine flue collar',(.17,.69,-.17),[(.058,0),(.069,0),(.069,.025),(.058,.04),(.053,.04),(.053,0)],'CafeStoveEdge')
    lathe('Kuzine flue vertical',(.17,.73,-.17),[(.055,0),(.055,1.60),(.050,1.60),(.050,0)],'CafeStoveIron',80)
    tube('Kuzine swept flue elbow',[(.17,2.30,-.17),(.17,2.40,-.20),(.17,2.44,-.34),(.17,2.44,-.57)],.055,'CafeStoveIron')
    for y in [1.25,1.88]:lathe('Flue rolled coupling',(.17,y,-.17),[(.055,0),(.058,.003),(.058,.022),(.055,.026)],'CafeStoveEdge',80)
    for y in [1.42,2.15]:tube('Flue wall fixing',[(.17,y,-.17),(.17,y,-.57)],.008,'CafeStoveEdge')
    root=bpy.data.objects.new('KuzineAssembly',None);scene.collection.objects.link(root)
    for o in set(scene.objects)-before:
        if o!=root and o.parent is None:o.parent=root
    root.location=v((4.15,0,-.20));root.rotation_euler.z=-math.pi/2
    # Timber ceiling bands and regular wall bays unify all four views, not just the starting camera.
    for z in [-2.65,2.65]:box('Ceiling transverse timber',(0,3.09,z),(9.70,.19,.16),'CafeWalnutEdge',.012)
    for x in [-4.76,4.76]:
        for z in [-4.84,0,4.84]:box('Wall timber upright',(x,1.57,z),(.10,3.14,.11),'CafeWalnutEdge',.008)
    for z in [-4.88,4.88]:
        for x in [-2.2,2.2]:box('Wall timber upright',(x,1.57,z),(.10,3.14,.085),'CafeWalnutEdge',.008)
        box('Picture height wall rail',(0,2.57,z),(9.62,.055,.055),'CafeWalnutEdge',.007)
    # Warm wall lamps with small opaque enamel shades; practical lights are added in Godot.
    for x,z,ang in [(-1.65,-4.81,0),(1.65,-4.81,0),(-1.65,4.81,math.pi),(1.65,4.81,math.pi),(4.72,.80,-math.pi/2),(-4.72,.80,math.pi/2)]:
        before=set(scene.objects)
        box('Sconce wall rose',(0,0,0),(.10,.16,.035),'CafeLampBrass',.022)
        tube('Sconce bent arm',[(0,-.015,.015),(0,-.045,.13),(0,.04,.19)],.009,'CafeLampBrass')
        lathe('Sconce enamel shade',(0,.04,.19),[(.10,0),(.10,.010),(.08,.035),(.035,.085),(.025,.09),(0,.09)],'CafeEnamel')
        lathe('Sconce warm diffuser',(0,.038,.19),[(0,0),(.092,0),(.092,.005),(0,.005)],'CafeLampCream')
        g=bpy.data.objects.new('WallSconce',None);scene.collection.objects.link(g)
        for o in set(scene.objects)-before:
            if o!=g:o.parent=g
        g.location=v((x,2.02,z));g.rotation_euler.z=ang
    # Rear nook bench is broad, quiet and physically grounded.
    box('Rear bench seat',(0,.445,-4.52),(2.40,.085,.44),'CafeWalnut',.025)
    box('Rear bench back',(0,.76,-4.70),(2.40,.43,.055),'CafeWalnut',.018)
    for x in [-1.04,1.04]:
        for z in [-4.67,-4.38]:box('Bench sturdy leg',(x,.215,z),(.065,.43,.065),'CafeWalnutEdge',.007)
    export_scene(base,scene,'assets/models/environment/kahvehane_unified.glb','tools/blender/source/kahvehane_unified.blend')
    build_rack(base,mats)
    bpy.context.window.scene=scene
    print('UNIFIED_ROOM',len(scene.objects),'objects; expanded shell 9.66 x 9.91m')

def export_scene(base,scene,glb,blend):
    bpy.context.window.scene=scene;bpy.ops.object.select_all(action='DESELECT')
    for o in scene.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(base,glb),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
    bpy.data.libraries.write(os.path.join(base,blend),{scene},fake_user=True)

def build_rack(base,mats):
    scene=bpy.data.scenes.new('Istaka_Ceviz_Isleme');bpy.context.window.scene=scene
    # A single routed, solid walnut section. Front support planes exactly match Rack._base_slot_transform.
    c,s=math.cos(.30),math.sin(.30)
    def point(x,h,n):return (x,-(.032-s*h+c*n),.008+c*h+s*n)
    profile=[(-.007,.021),(.004,.021),(.004,0),(.063,0),(.063,.018),(.066,.018),(.066,-.003),(.126,-.003),(.129,-.009),(.126,-.016),(-.007,-.016)]
    pts=[point(x,h,n) for x in [-.309,.309] for h,n in profile];count=len(profile)
    faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    d=bpy.data.meshes.new('Routed walnut board');d.from_pydata(pts,[],faces);d.update()
    o=bpy.data.objects.new('Istaka solid routed body',d);scene.collection.objects.link(o);d.materials.append(mats['CafeRackWood'])
    # Closed topology and recalculated normals stop the rack from leaking hidden tile faces.
    import bmesh
    bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(d);bm.free()
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    m=o.modifiers.new('Soft hand finished edges','BEVEL');m.width=.0018;m.segments=5;bpy.ops.object.modifier_apply(modifier=m.name)
    m=o.modifiers.new('Walnut surface normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
    # Two real triangular stands with rounded toes and recessed felt feet.
    for x in [-.255,.255]:
        section=[(-.075,.002),(.012,.002),(-.022,.119)]
        vs=[(xx,-z,y) for xx in [x-.012,x+.012] for z,y in section]
        d=bpy.data.meshes.new('Support joinery');d.from_pydata(vs,[],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]);d.update()
        o=bpy.data.objects.new('Istaka joined support',d);scene.collection.objects.link(o);d.materials.append(mats['CafeRackWood'])
        bpy.context.view_layer.objects.active=o
        m=o.modifiers.new('Rounded support edge','BEVEL');m.width=.002;m.segments=4;bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Support normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=m.name)
    export_scene(base,scene,'assets/models/table_details/okey_rack_refined.glb','tools/blender/source/okey_rack_refined.blend')
