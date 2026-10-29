"""Remove room battens; recessed narrow window with a real 3D courtyard.
Build on the saved unified scene. Earlier source and open Blender scenes remain intact.
"""
import bpy, math, os, random
from mathutils import Vector, Matrix

def build(base):
    with bpy.data.libraries.load(os.path.join(base,'tools/blender/source/kahvehane_unified.blend'),link=False) as (src,dst):
        dst.scenes=[s for s in src.scenes if s.startswith('Kahvehane_Butunluk')][:1]
    scene=dst.scenes[0];scene.name='Kahvehane_Avlu';bpy.context.window.scene=scene
    def v(p):return Vector((p[0],-p[2],p[1]))
    mats={}
    def mat(key,color,rough=.8,metal=0,emission=0):
        m=bpy.data.materials.new(key);m.use_nodes=True;n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)];rgb=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
        n.inputs['Base Color'].default_value=(*rgb,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal
        if emission:n.inputs['Emission Color'].default_value=(*rgb,1);n.inputs['Emission Strength'].default_value=emission
        mats[key]=m;return m
    for key,args in {
        'CalmPlaster':('b1a792',.94),'CafeDado':('b0b3a3',.76),
        'CafeWindowFrame':('a6a88e',.63),'CafeWindowStone':('c0baa6',.85),
        'CourtyardStucco':('a5aa9e',.94),'CourtyardOchre':('aaa28b',.94),
        'CourtyardStone':('6d7770',.96),'CourtyardRoof':('655b4e',.95),
        'CourtyardDark':('343d39',.87),'CourtyardGlass':('939f99',.32,0,.22),
        'CourtyardWood':('6e7464',.85),'CourtyardLeaf':('566b50',.95),
        'CourtyardLeafLight':('778064',.95),'CourtyardBranch':('645e4b',.94),
        'CourtyardSky':('93a9b1',1,0,.6)
    }.items():mat(key,*args)
    def finish(o,name,key):o.name=name;o.data.materials.append(mats[key]);return o
    def box(name,p,size,key,r=.004):
        bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,name,key)
        if r:
            mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=min(r,min(size)*.35);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
            mod=o.modifiers.new('Surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
        return o
    def tube(name,pts,r,key):
        d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.resolution_u=16;d.bevel_depth=r;d.bevel_resolution=3
        sp=d.splines.new('BEZIER');sp.bezier_points.add(len(pts)-1)
        for bp,p in zip(sp.bezier_points,pts):bp.co=v(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);d.materials.append(mats[key]);return o
    # Remove the busy applied timbers, the old wide opening and its flat skyline.
    prefixes=('Ceiling transverse','Wall timber','Picture height wall','Wall rail','Sage tongue',
              'Right lime','Window below','Window above','Window oak','WindowOutside','Window mullion','Window transom',
              'Deep window','Curtain pole','Soft linen')
    for o in list(scene.objects):
        if o.name.startswith(prefixes):bpy.data.objects.remove(o,do_unlink=True)
    # Only a patterned ceramic dado. No strips crossing pictures or ceiling.
    for x in [-4.77,4.77]:box('Patterned lower wall',(x,.44,0),(.045,.88,9.72),'CafeDado',.003)
    box('Patterned lower wall rear',(0,.44,-4.85),(9.57,.88,.045),'CafeDado',.003)
    for x in [-2.75,2.75]:box('Patterned lower wall entry',(x,.44,4.85),(3.98,.88,.045),'CafeDado',.003)
    # A 1.12m opening, 1.54m high, cut through a 28cm thick wall.
    x,zc,w,y0,y1=4.899,-1.345,1.12,1.12,2.66
    za,zb=zc-w/2,zc+w/2
    for a,b in [(-4.956,za),(zb,4.956)]:box('Narrow window side wall',(x,1.6,(a+b)/2),(.28,3.2,b-a),'CalmPlaster',0)
    box('Narrow window wall below',(x,y0/2,zc),(.28,y0,w),'CalmPlaster',0)
    box('Narrow window wall above',(x,(y1+3.2)/2,zc),(.28,3.2-y1,w),'CalmPlaster',0)
    # Window sits towards the outside. Splayed stone reveals provide visible depth.
    for z in [za+.02,zb-.02]:box('Deep window side reveal',(4.84,(y0+y1)/2,z),(.37,y1-y0,.045),'CafeWindowStone',.006)
    for y in [y0,y1]:box('Deep window lintel',(4.84,y,zc),(.37,.05,w),'CafeWindowStone',.006)
    box('Stone window sill',(4.76,y0-.035,zc),(.55,.065,w+.15),'CafeWindowStone',.010)
    for z in [za+.055,zb-.055]:box('Narrow painted window jamb',(4.99,(y0+y1)/2,z),(.06,y1-y0,.058),'CafeWindowFrame',.006)
    for y in [y0+.04,y1-.04]:box('Narrow painted window header',(4.99,y,zc),(.06,.058,w-.06),'CafeWindowFrame',.005)
    box('Window centre stile',(4.97,(y0+y1)/2,zc),(.065,y1-y0-.09,.032),'CafeWindowFrame',.004)
    box('Window upper transom',(4.97,2.19,zc),(.065,.032,w-.08),'CafeWindowFrame',.004)
    tube('Window latch',[(4.93,1.79,zc+.035),(4.91,1.79,zc+.035),(4.91,1.72,zc+.035)],.006,'CourtyardDark')
    # Clear opening: the courtyard itself is rendered beyond it, with genuine parallax.
    # The exterior has multiple depths, a low garden wall, paving, buildings and foliage.
    box('Courtyard paving',(10,-.08,-1),(11,.14,17),'CourtyardStone',.004)
    for z in [i*.62-6 for i in range(19)]:box('Paving joint',(8.0,.001,z),(6,.001,.004),'CourtyardDark',0)
    box('Courtyard low wall',(6.70,.44,-.2),(.18,.88,6),'CourtyardStucco',.018)
    box('Courtyard low wall coping',(6.70,.91,-.2),(.26,.07,6.08),'CafeWindowStone',.010)
    # Opposite plaster facade is four metres beyond the window, rather than a picture in the frame.
    box('Opposite courtyard facade',(10.2,2.45,-1),(.40,4.9,13),'CourtyardStucco',.018)
    box('Opposite roof fascia',(9.96,4.86,-1),(.43,.16,13.2),'CourtyardRoof',.018)
    box('Opposite upper cornice',(9.95,3.13,-1),(.14,.06,13),'CafeWindowStone',.004)
    for z in [-5,-2.9,-.8,1.3,3.4]:
        for y in [1.12,3.94]:
            box('Courtyard recessed window',(9.975,y,z),(.018,.98,.69),'CourtyardDark',.006)
            box('Courtyard window glass',(9.95,y,z),(.012,.88,.59),'CourtyardGlass',.003)
            for zz in [z-.34,z+.34]:box('Courtyard window surround',(9.91,y,zz),(.07,1.04,.055),'CafeWindowStone',.004)
            for yy in [y-.50,y+.50]:box('Courtyard window surround',(9.91,yy,z),(.07,.055,.73),'CafeWindowStone',.004)
            box('Courtyard window mullion',(9.90,y,z),(.055,.94,.022),'CourtyardWood',.003)
            box('Courtyard window crossbar',(9.90,y,z),(.055,.026,.64),'CourtyardWood',.003)
            box('Courtyard projecting sill',(9.83,y-.54,z),(.24,.06,.82),'CafeWindowStone',.005)
    box('Distant courtyard wing',(13.3,3.0,5.6),(4.2,6.0,1.0),'CourtyardOchre',.012)
    box('Distant courtyard roof',(13.3,6.04,5.6),(4.5,.20,1.25),'CourtyardRoof',.025)
    # Slim tree and clearly shaped leaves: close foliage gives the strongest head-movement parallax.
    tube('Courtyard small tree trunk',[(7.4,0,-2.3),(7.43,1.5,-2.26),(7.27,2.5,-2.18),(7.36,3.7,-2.12)],.045,'CourtyardBranch')
    branches=[((7.43,1.7,-2.26),(7.10,2.72,-2.95)),((7.30,2.45,-2.18),(7.62,3.25,-1.36)),((7.32,3.0,-2.14),(6.97,3.75,-2.6))]
    rng=random.Random(33)
    for start,end in branches:
        tube('Courtyard tree branch',[start,((start[0]+end[0])/2,(start[1]+end[1])/2,(start[2]+end[2])/2),end],.018,'CourtyardBranch')
        for i in range(13):
            t=.4+i/20;p=Vector(start).lerp(Vector(end),t)
            p+=Vector((rng.uniform(-.22,.22),rng.uniform(-.1,.2),rng.uniform(-.24,.24)))
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=v(p));o=bpy.context.object
            o.scale=(.10,.20,.025);o.rotation_euler=(rng.uniform(-.7,.7),rng.uniform(-.6,.6),rng.uniform(-1,1))
            finish(o,'Courtyard individual leaf','CourtyardLeafLight' if i%3==0 else 'CourtyardLeaf')
            for poly in o.data.polygons:poly.use_smooth=True
    box('Courtyard distant sky',(17,6,-1),(.04,16,28),'CourtyardSky',0)
    # Move the intact stove a little away from the window; it remains in the same corner.
    stove=next(o for o in scene.objects if o.name.startswith('KuzineAssembly'));stove.location+=v((0,0,.47))
    # Move the service-side conversation group into the unused floor area as a unit.
    delta=v((.10,0,3.05))
    for o in list(scene.objects):
        if o.parent is None and o.name.startswith(('BackgroundTable','PlasticCafeChair','BentwoodCafeChair','Background_','TeaGlass','Pendant')) and o.location.x<-.5:
            o.location+=delta
    chair=next(o for o in scene.objects if o.name.startswith('BentwoodCafeChair') and o.location.x<0)
    originals=[chair]+list(chair.children_recursive);copies={o:o.copy() for o in originals}
    for old,new in copies.items():
        scene.collection.objects.link(new)
        if old.parent in copies:new.parent=copies[old.parent]
    extra=copies[chair];extra.name='ExtraConversationChair'
    old=v((-1.994,0,1.35));new=v((-3.51,0,1.35))
    extra.matrix_world=Matrix.Translation(new)@Matrix.Rotation(math.pi,4,'Z')@Matrix.Translation(-old)@extra.matrix_world
    bpy.ops.object.select_all(action='DESELECT')
    for o in scene.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/kahvehane_courtyard.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
    bpy.data.libraries.write(os.path.join(base,'tools/blender/source/kahvehane_courtyard.blend'),{scene},fake_user=True)
    print('COURTYARD_READY',len(scene.objects),'window',w,'metres')
