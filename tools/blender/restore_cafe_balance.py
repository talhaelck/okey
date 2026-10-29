"""Restore original rack silhouette, continuous table joinery and quiet timber dado.
Export game assets, then leave a lit, furnished Blender work scene visible.
"""
import bpy, math, os, bmesh
from mathutils import Vector

def build(base):
    def load_scene(file,prefix):
        with bpy.data.libraries.load(os.path.join(base,file),link=False) as (src,dst):dst.scenes=[n for n in src.scenes if n.startswith(prefix)][:1]
        s=dst.scenes[0];bpy.context.window.scene=s;return s
    room=load_scene('tools/blender/source/kahvehane_courtyard.blend','Kahvehane_Avlu');room.name='Kahvehane_Dengeli'
    def v(p):return Vector((p[0],-p[2],p[1]))
    mats={}
    def mat(name,color,rough=.75,metal=0):
        m=bpy.data.materials.new(name);m.use_nodes=True;n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)];rgb=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb]
        n.inputs['Base Color'].default_value=(*rgb,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal;m.diffuse_color=(*rgb,1)
        mats[name]=m;return m
    for key,args in {'CafePanelWood':('79674f',.80),'CafePanelInset':('685c48',.86),'CafeTableWalnut':('79583d',.66),'CalmOak':('806548',.75),'CafePaper':('c0bba8',.98),'CafePaperInk':('73786e',.95),'CafeIron':('3b4039',.76,.3),'CafeLinen':('a7a58f',.94),'CafeFelt':('2c4940',.96)}.items():mat(key,*args)
    def finish(o,name,key):o.name=name;o.data.materials.append(mats[key]);return o
    def edge(o,r):
        bpy.context.view_layer.objects.active=o
        m=o.modifiers.new('Hand finished edges','BEVEL');m.width=r;m.segments=4;bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
    def box(name,p,size,key,r=.004):
        bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,name,key)
        if r:edge(o,min(r,min(size)*.35))
        return o
    def mesh(name,points,faces,key):
        d=bpy.data.meshes.new(name);d.from_pydata([v(p) for p in points],[],faces);d.update()
        bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(d);bm.free()
        o=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(o);finish(o,name,key);return o
    def lathe(name,p,prof,key):
        n=64;pts=[(p[0]+r*math.cos(j*math.tau/n),p[1]+h,p[2]+r*math.sin(j*math.tau/n)) for r,h in prof for j in range(n)]
        fs=[(k*n+j,(k+1)*n+j,(k+1)*n+(j+1)%n,k*n+(j+1)%n) for k in range(len(prof)-1) for j in range(n)]
        o=mesh(name,pts,fs,key)
        for poly in o.data.polygons:poly.use_smooth=True
        return o
    def export(s,path):
        bpy.context.window.scene=s;bpy.ops.object.select_all(action='DESELECT')
        for o in s.objects:o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(base,path),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
    # Remove the printed ceramic band entirely. Use recessed panels in a muted timber palette.
    for o in list(room.objects):
        if o.name.startswith(('Patterned lower','Courtyard individual leaf','Courtyard tree branch','Courtyard small tree')):bpy.data.objects.remove(o,do_unlink=True)
    for axis,side,intervals in [('x',-1,[(-4.8,4.8)]),('x',1,[(-4.8,4.8)]),('z',-1,[(-4.75,4.75)]),('z',1,[(-4.75,-.77),(.77,4.75)])]:
        def p(along,y,depth):return (side*(4.77-depth),y,along) if axis=='x' else (along,y,side*(4.85-depth))
        def sz(length,height,thick):return (thick,height,length) if axis=='x' else (length,height,thick)
        for a,b in intervals:
            box('Quiet timber dado backing',p((a+b)/2,.44,0),sz(b-a,.88,.025),'CafePanelInset')
            for y,h in [(.065,.095),(.878,.045)]:box('Dado narrow finishing rail',p((a+b)/2,y,.023),sz(b-a,h,.035),'CafePanelWood')
            count=round((b-a)/.64);width=(b-a)/count
            for i in range(count):
                c=a+(i+.5)*width
                box('Recessed timber panel',p(c,.46,.020),sz(width-.085,.65,.018),'CafePanelInset',.009)
                for end in [c-width/2+.025,c+width/2-.025]:box('Panel frame stile',p(end,.46,.032),sz(.032,.71,.022),'CafePanelWood',.003)
                for y in [.115,.805]:box('Panel frame crosspiece',p(c,y,.032),sz(width-.05,.028,.022),'CafePanelWood',.003)
    # Quiet the exterior: no oversized tree leaves directly against the glass.
    # Lower the opposite eaves so the window shows an open dusk sky above real architecture.
    for o in room.objects:
        if o.name.startswith('Opposite courtyard facade'):
            o.scale.z*=.58;o.location.z=1.42
        if o.name.startswith('Opposite roof fascia'):o.location.z=2.86
        if o.name.startswith('Opposite upper cornice'):o.location.z=2.72
    for o in list(room.objects):
        if o.name.startswith('Courtyard ') and o.location.z>3.2 and 'window' in o.name.lower():bpy.data.objects.remove(o,do_unlink=True)
        elif o.name.startswith('Courtyard projecting sill') and o.location.z>3.2:bpy.data.objects.remove(o,do_unlink=True)
    # Linen side curtains are shallow, open and softly draped, keeping the opening readable.
    for z in [-2.0,-.69]:
        pts=[];faces=[]
        for y in range(17):
            h=y/16
            for j in range(25):
                u=j/24;pts.append((4.64+.022*math.sin(u*math.tau*3),1.06+h*1.69,z+(u-.5)*(.23+.06*(1-h))))
        for y in range(16):
            for j in range(24):a=y*25+j;faces.append((a,a+1,a+26,a+25))
        o=mesh('Open linen curtain',pts,faces,'CafeLinen')
        for f in o.data.polygons:f.use_smooth=True
        m=o.modifiers.new('Hem thickness','SOLIDIFY');m.thickness=.003
    # A third conversation table belongs to the existing rear bench, rather than more wall clutter.
    lathe('Bench conversation table',(0,0,-3.83),[(0,.70),(.34,.70),(.365,.715),(.365,.755),(.35,.768),(0,.768)],'CalmOak')
    lathe('Bench table pedestal',(0,0,-3.83),[(0,.018),(.24,.018),(.26,.03),(.19,.06),(.035,.15),(.035,.68),(.10,.70),(0,.70)],'CafeIron')
    # One empty bentwood chair beside the bench table.
    original=next(o for o in room.objects if o.name.startswith('BentwoodCafeChair'))
    src=[original]+list(original.children_recursive);copies={o:o.copy() for o in src}
    for old,new in copies.items():
        room.collection.objects.link(new)
        if old.parent in copies:new.parent=copies[old.parent]
    chair=copies[original];chair.name='BenchConversationChair';chair.location=v((.78,0,-3.83));chair.rotation_euler.z=math.pi/2
    # A small freestanding newspaper holder gives the entry a purpose.
    for x in [2.55,2.98]:
        for z in [4.29,4.55]:box('Newspaper rack leg',(x,.32,z),(.025,.64,.025),'CafePanelWood')
    box('Newspaper rack shelf',(2.765,.31,4.42),(.47,.025,.30),'CafePanelWood')
    box('Newspaper rack back',(2.765,.62,4.53),(.47,.40,.025),'CafePanelWood')
    box('Newspaper rack retaining rail',(2.765,.49,4.28),(.47,.035,.024),'CafePanelWood')
    for i in range(3):
        o=box('Folded newspaper',(2.64+i*.11,.58,4.43-i*.009),(.18,.32,.012),'CafePaper',.001);o.rotation_euler.x=-.16
    export(room,'assets/models/environment/kahvehane_balanced.glb')
    # Rebuild only the faulty table perimeter. Existing leg design is preserved.
    table=load_scene('tools/blender/source/okey_table_plain.blend','OkeyTable_Sade');table.name='OkeyTable_JoinedCorners'
    for o in list(table.objects):
        if o.name.startswith(('TableRim','TableBed')):bpy.data.objects.remove(o,do_unlink=True)
    def rounded(half,r):
        pts=[]
        for x,z,a in [(half-r,half-r,0),(-half+r,half-r,90),(-half+r,-half+r,180),(half-r,-half+r,270)]:
            for i in range(17):
                t=math.radians(a+i*90/16);pts.append((x+r*math.cos(t),z+r*math.sin(t)))
        return pts
    # Loop follows clockwise corners with equal vertex count for the inner and outer opening.
    def outline(h,r):
        out=[]
        for cx,cz,start in [(h-r,h-r,0),(-h+r,h-r,90),(-h+r,-h+r,180),(h-r,-h+r,270)]:
            for j in range(17):
                a=math.radians(start+j*90/16);out.append((cx+r*math.cos(a),cz+r*math.sin(a)))
        return out
    outer,inner=outline(.71,.055),outline(.583,.009);n=len(outer)
    pts=[(x,y,z) for y in [.702,.758] for loop in [outer,inner] for x,z in loop];faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    frame=mesh('Continuous walnut table frame',pts,faces,'CafeTableWalnut');edge(frame,.003)
    # Rounded bed hides below the frame, never sticking out as square corner blocks.
    loop=outline(.706,.053);n=len(loop);pts=[(x,y,z) for y in [.674,.705] for x,z in loop]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    bed=mesh('Rounded continuous table bed',pts,faces,'CafePanelInset');edge(bed,.003)
    export(table,'assets/models/table_details/okey_table_joined.glb')
    bpy.data.libraries.write(os.path.join(base,'tools/blender/source/okey_table_joined.blend'),{table},fake_user=True)
    # Visible workbench includes the actual game table and restored racks, in a separate preview collection.
    bpy.context.window.scene=room;preview=bpy.data.collections.new('PREVIEW - table racks and lighting');room.collection.children.link(preview)
    for original in table.objects:
        o=original.copy();o.name='Preview_'+original.name;preview.objects.link(o);o.parent=None;o.matrix_world=original.matrix_world.copy()
    def import_preview(file):
        before=set(room.objects);bpy.ops.import_scene.gltf(filepath=os.path.join(base,file));added=set(room.objects)-before
        for o in added:
            for coll in list(o.users_collection):coll.objects.unlink(o)
            preview.objects.link(o)
        return added
    for i in range(4):
        imported=import_preview('assets/models/table_details/okey_rack.glb')
        root=bpy.data.objects.new('Preview_Rack',None);preview.objects.link(root)
        for o in imported:
            if o.parent not in imported:o.parent=root
        root.location=v((math.sin(i*math.pi/2)*.50,.75,math.cos(i*math.pi/2)*.50));root.rotation_euler.z=i*math.pi/2
    # Felt for the Blender workbench (the game owns its existing interactive felt).
    felt=box('Preview_Felt',(0,.745,0),(1.16,.012,1.16),'CafeFelt',.005)
    for coll in list(felt.users_collection):coll.objects.unlink(felt)
    preview.objects.link(felt)
    def area(name,p,power,size,color,target):
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
        o=bpy.data.objects.new(name,d);preview.objects.link(o);o.location=v(p);o.rotation_euler=(v(target)-o.location).to_track_quat('-Z','Y').to_euler()
    area('Preview warm table light',(0,2.45,0),180,1.15,(1,.83,.65),(0,.75,0))
    area('Preview window fill',(4.8,2.4,-1.4),140,1.4,(.70,.79,1),(0,1,0))
    for x,z in [(-2.75,1.35),(2.95,1.85),(0,-3.83)]:area('Preview cafe pool',(x,2.4,z),95,.9,(1,.80,.60),(x,.7,z))
    world=bpy.data.worlds.new('Cafe preview dusk');world.use_nodes=True
    world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.18,.20,.21,1);world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.35;room.world=world
    bpy.ops.object.camera_add(location=v((1.8,1.8,2.9)));cam=bpy.context.object;cam.name='Preview_Camera';cam.rotation_euler=(v((0,1,-1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=24;room.camera=cam
    room.render.engine='CYCLES';room.cycles.samples=32
    for screen in bpy.data.screens:
        for ar in screen.areas:
            if ar.type=='VIEW_3D':
                sp=ar.spaces.active;sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True
                sp.region_3d.view_perspective='CAMERA'
    bpy.data.libraries.write(os.path.join(base,'tools/blender/source/kahvehane_balanced.blend'),{room},fake_user=True)
    bpy.context.window.scene=room
    finish_preview(base,room)
    print('BALANCED_ASSETS_SAVED; active Blender scene',room.name)

def finish_preview(base,room):
    bpy.context.window.scene=room
    for o in list(room.objects):
        if o.name.startswith('Courtyard projecting sill') and o.location.z>3.2:bpy.data.objects.remove(o,do_unlink=True)
    preview=next(c for c in room.collection.children if c.name.startswith('PREVIEW -'))
    if not any(o.name.startswith('Clear window glass pane') for o in room.objects):
        m=bpy.data.materials.new('CafeWindowGlass');m.use_nodes=True
        bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.70,.80,.85,1);bs.inputs['Alpha'].default_value=.035;bs.inputs['Roughness'].default_value=.10
        data=bpy.data.meshes.new('Window glass');data.from_pydata([(5.005,1.86,1.17),(5.005,.83,1.17),(5.005,.83,2.60),(5.005,1.86,2.60)],[],[(0,1,2,3)]);data.update()
        o=bpy.data.objects.new('Clear window glass pane',data);room.collection.objects.link(o);data.materials.append(m)
    # The Blender workbench also has scanned grain and pores; no solid-colour placeholder table.
    image=bpy.data.images.load(os.path.join(base,'assets/textures/wood_table_worn/diffuse.jpg'),check_existing=True)
    normals=bpy.data.images.load(os.path.join(base,'assets/textures/wood_table_worn/nor_gl.jpg'),check_existing=True);normals.colorspace_settings.name='Non-Color'
    materials={m for o in room.objects if o.type=='MESH' for m in o.data.materials if m and m.name.split('.')[0] in ['CafePanelWood','CafePanelInset','CafeTableWalnut','CalmOak']}
    for m in materials:
        nodes=m.node_tree.nodes
        if any(n.label=='Cafe preview scanned grain' for n in nodes):continue
        bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');base_color=tuple(bs.inputs['Base Color'].default_value)
        tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.label='Cafe preview scanned grain'
        ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.58,.58,.58,1);ramp.color_ramp.elements[1].position=.32;ramp.color_ramp.elements[1].color=(1.10,1.10,1.10,1)
        mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[1].default_value=base_color
        m.node_tree.links.new(tex.outputs['Color'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],bs.inputs['Base Color'])
        texn=nodes.new('ShaderNodeTexImage');texn.image=normals;normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.10
        m.node_tree.links.new(texn.outputs['Color'],normal.inputs['Color']);m.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
    bpy.ops.object.select_all(action='DESELECT');preview_objects=set(preview.all_objects)
    for o in room.objects:
        if o not in preview_objects and o.type not in ['CAMERA','LIGHT']:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/kahvehane_balanced.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
    for ar in bpy.context.window.screen.areas:
        if ar.type=='VIEW_3D':
            sp=ar.spaces.active;sp.overlay.show_overlays=False;sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True
            sp.region_3d.view_perspective='CAMERA'
            sp.region_3d.view_camera_zoom=12
    bpy.data.libraries.write(os.path.join(base,'tools/blender/source/kahvehane_balanced.blend'),{room},fake_user=True)
