"""Original seated coffeehouse patrons; local Blender geometry, no external generation."""
import bpy, math, os, random
from mathutils import Vector, Matrix

def build(project):
    for old in list(bpy.data.scenes):
        if old.name.startswith('Kiraathane_Patrons') and old.get('okey_generated'):
            for obj in list(old.objects):
                if len(obj.users_scene)==1:
                    bpy.data.objects.remove(obj,do_unlink=True)
            bpy.data.scenes.remove(old)
    scene=bpy.data.scenes.new('Kiraathane_Patrons')
    scene['okey_generated']=True
    bpy.context.window.scene=scene
    rng=random.Random(41)
    mats={}
    def mat(name,rgb,rough=.65,metal=0):
        m=bpy.data.materials.new('patron_'+name);m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1)
        p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
        mats[name]=m
    mat('skin',(.56,.29,.15),.67);mat('skin_light',(.62,.34,.19),.68)
    mat('crease',(.29,.12,.062),.83);mat('inner_ear',(.40,.17,.105),.75)
    mat('hair',(.037,.022,.016),.81);mat('hair_glint',(.079,.051,.032),.82)
    mat('grey',(.28,.26,.23),.85);mat('silver',(.42,.39,.33),.8)
    mat('eye',(.83,.79,.68),.32);mat('iris',(.12,.062,.021),.4);mat('pupil',(.007,.005,.004),.23)
    mat('glint',(.99,.96,.82),.21);mat('mouth',(.075,.017,.011),.85);mat('teeth',(.74,.69,.55),.45)
    mat('burgundy',(.22,.027,.032),.87);mat('shirt',(.68,.61,.45),.91)
    mat('olive',(.088,.105,.061),.95);mat('trouser',(.092,.055,.03),.89)
    mat('cap',(.105,.086,.058),.97);mat('shoe',(.024,.019,.014),.74)
    mat('sole',(.054,.044,.031),.96);mat('seam',(.19,.15,.093),.95)
    mat('gold',(.49,.28,.081),.3,.78);mat('plaid',(.27,.19,.105),.94)
    mat('navy',(.039,.063,.072),.92);mat('lens',(.13,.09,.045),.28,.24)
    roots=[]
    def v(p):return Vector((p[0],-p[2],p[1]))
    def empty(name,parent=None,at=(0,0,0)):
        o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.parent=parent;o.location=v(at);return o
    def finish(o,name,material,parent):
        o.name=name;o.data.materials.append(mats[material]);o.parent=parent
        for p in o.data.polygons:p.use_smooth=True
        return o
    def ell(name,p,s,material,parent,segments=32,rings=20):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=v(p))
        o=bpy.context.object;o.scale=(s[0],s[2],s[1])
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        return finish(o,name,material,parent)
    def curve(name,points,r,material,parent,radii=None):
        data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=12;data.bevel_depth=r;data.bevel_resolution=3
        sp=data.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
        for i,(bp,p) in enumerate(zip(sp.bezier_points,points)):
            bp.co=v(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
            if radii:bp.radius=radii[i]
        o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mats[material]);return o
    def limb(name,a,b,r,material,parent,flatten=1):
        aa,bb=v(a),v(b);d=bb-aa
        o=ell(name,(0,0,0),(r,d.length/2+r*.5,r*flatten),material,parent)
        o.location=(aa+bb)/2;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized());return o
    def ring(name,c,rx,ry,r,material,parent,plane='xy'):
        points=[]
        for i in range(33):
            a=i*math.tau/32
            points.append((c[0]+math.cos(a)*rx,c[1]+(math.sin(a)*ry if plane=='xy' else 0),c[2]+(math.sin(a)*ry if plane!='xy' else 0)))
        return curve(name,points,r,material,parent)
    for kind in ['sabri','temel','rifki']:
        root=empty(kind);roots.append(root)
        torso=empty('Torso',root)
        heavy=kind=='sabri';old=kind=='rifki'
        width=.22 if heavy else .155
        coat='burgundy' if heavy else ('navy' if old else 'olive')
        # Seated anatomy: thighs follow seat, calves descend to the floor.
        for side in [-1,1]:
            hip=(side*.11,.035,.025);knee=(side*.155,-.005,-.24);ankle=(side*.15,-.37,-.22)
            limb('TrouserThigh',hip,knee,.10 if heavy else .068,coat if heavy else 'trouser',root)
            limb('TrouserCalf',knee,ankle,.067 if heavy else .048,coat if heavy else 'trouser',root)
            ell('ShoeSole',(side*.15,-.418,-.27),(.071,.020,.12),'sole',root)
            ell('LeatherShoe',(side*.15,-.397,-.28),(.069,.040,.112),'shoe',root)
            for j in range(3):
                curve('ShoeLace',[(side*.15-.025,-.369,-.26-j*.012),(side*.15+.025,-.369,-.26-j*.012)],.0015,'seam',root)
        # Tailored horizontal rings give shoulders and a flat hem, rather than an egg silhouette.
        rings=[(.015,.17,.108),(.06,.205,.13),(.18,.245,.172),(.30,.235,.153),(.41,.205,.114),(.465,.155,.087),(.49,.075,.059)] if heavy else [(.015,.115,.083),(.06,.14,.096),(.18,.154,.11),(.30,.162,.106),(.41,.173,.087),(.465,.135,.069),(.49,.065,.05)]
        def garment(name, material, start, end, offset):
            verts=[];faces=[];steps=48
            for y,w,d in rings:
                for j in range(steps+1):
                    phi=start+(end-start)*j/steps
                    verts.append(v((math.sin(phi)*(w+offset),y,.012-math.cos(phi)*(d+offset))))
            for i in range(len(rings)-1):
                for j in range(steps):
                    a=i*(steps+1)+j;faces.append((a,a+steps+1,a+steps+2,a+1))
            data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
            o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);finish(o,name,material,torso)
            mod=o.modifiers.new('Tailored cloth smoothing','SUBSURF');mod.levels=2
            return o
        garment('SeatedCoat',coat,-math.pi,math.pi,0)
        garment('ShirtFront','shirt',-.55,.55,.002)
        for side in [-1,1]:
            curve('CollarFold',[(side*.06,.48,-.046),(side*.11,.445,-.076),(side*.079,.39,-.107)],.013,coat,torso,[.5,1,.3])
            for j in range(3):
                curve('WaistClothFold',[(side*.065,.08+j*.018,-.109),(side*.11,.071+j*.018,-.112),(side*.145,.083+j*.018,-.104)],.0016,'seam' if not heavy else 'burgundy',torso,[.1,1,.1])
        if not heavy:
            for j in range(8):
                y=.13+j*.037
                curve('ShirtCheck',[(-.062,y,-.104),(0,y,-.108),(.062,y,-.104)],.0007,'plaid',torso)
            for j in range(5):
                x=(j-2)*.024
                curve('ShirtCheck',[(x,.13,-.109),(x,.28,-.1),(x,.425,-.08)],.0007,'plaid',torso)
        # Collar and open jacket edges sit over the shirt, rather than drawn textures.
        for side in [-1,1]:
            curve('JacketOpening',[(side*.062,.46,-.064),(side*.09,.39,-.153),(side*.128,.18,-.14),(side*.10,.025,-.105)],.010,coat,torso)
            curve('PipedSeam',[(side*.067,.45,-.073),(side*.096,.36,-.160),(side*.131,.18,-.148),(side*.103,.04,-.117)],.0013,'gold' if heavy else 'seam',torso)
            shoulder=(side*(width-.025),.43,.0);elbow=(side*(width+.04),.25,-.14);wrist=(side*.205,.32,-.36)
            limb('UpperSleeve',shoulder,elbow,.075 if heavy else .056,coat if heavy else 'shirt',torso)
            limb('ForeSleeve',elbow,wrist,.060 if heavy else .045,coat if heavy else 'shirt',torso)
            ring('RolledCuff',(side*.205,.32,-.35),.043,.036,.009,coat,torso)
            ell('Palm',(side*.205,.319,-.399),(.044,.026,.052),'skin',torso)
            for finger in range(4):
                x=side*.205+(finger-1.5)*.019
                length=[.045,.056,.052,.038][finger]
                a=(x,.319,-.419);b=(x,.313,-.419-length)
                limb('Finger',a,b,.009,'skin',torso)
                ell('Knuckle',(x,.334,-.433),(.009,.005,.012),'skin_light',torso,16,10)
                ell('Fingernail',(x,.319,-.411-length),(.006,.002,.008),'shirt',torso,16,10)
            limb('Thumb',(side*.175,.318,-.393),(side*.15,.307,-.429),.014,'skin',torso)
            if heavy:
                for stripe in range(3):
                    curve('TrackStripe',[(shoulder[0]+side*(stripe-1)*.012,.465,-.045),(elbow[0]+side*(stripe-1)*.012,.29,-.18),(wrist[0]+side*(stripe-1)*.012,.35,-.343)],.0022,'shirt',torso)
            else:
                # Shirt plaid on forearms and chest; restrained millimetre scale.
                for j in range(0):
                    curve('CuffCheck',[(side*.175,.353,-.23-j*.022),(side*.235,.353,-.23-j*.022)],.0009,'plaid',torso)
                ell('VestPocket',(side*.095,.24,-.118),(.044,.047,.012),coat,torso)
                curve('PocketStitch',[(side*.095-.035,.265,-.133),(side*.095+.035,.265,-.133)],.001,'seam',torso)
        ell('Neck',(0,.49,.0),(.065,.064,.064),'skin',torso)
        head=empty('Head',torso,(0,.663,-.01))
        # One continuous sculpted face, fused from anatomical masses.
        parts=[]
        def face(n,p,s):
            o=ell(n,p,s,'skin',head,40,28);parts.append(o);return o
        face('Cranium',(0,.015,.0),(.144 if heavy else .117,.177,.119))
        face('Jaw',(0,-.085,-.027),(.129 if heavy else .092,.093,.095))
        for side in [-1,1]:
            face('Cheek',(side*.073,-.041,-.093),(.045 if heavy else .034,.049,.024))
            face('Ear',(side*(.15 if heavy else .124),.003,.002),(.032,.054,.024))
        face('NoseBridge',(0,.002,-.110),(.027,.069,.034))
        face('NoseTip',(0,-.022,-.156),(.041 if heavy else .032,.031,.041 if heavy else .047))
        for side in [-1,1]:face('NostrilWing',(side*.028,-.038,-.141),(.019,.020,.021))
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();sculpt=bpy.context.object
        rem=sculpt.modifiers.new('Continuous facial topology','REMESH');rem.mode='VOXEL';rem.voxel_size=.0024;rem.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=rem.name)
        sm=sculpt.modifiers.new('Relax sculpt','SMOOTH');sm.factor=.65;sm.iterations=5;bpy.ops.object.modifier_apply(modifier=sm.name)
        sculpt.name='SculptedFace'
        for side in [-1,1]:
            ex=side*.057;ez=-.110
            ell('EarConcha',(side*(.15 if heavy else .124),.004,-.020),(.018,.034,.007),'inner_ear',head)
            curve('EarHelix',[(side*.146,.038,-.024),(side*.167,.012,-.020),(side*.152,-.032,-.019)],.004,'skin_light',head)
            ell('EyeWhite',(ex,.036,ez),(.030,.019,.021),'eye',head)
            ell('Iris',(ex-side*.003,.034,ez-.022),(.011,.012,.003),'iris',head)
            ell('Pupil',(ex-side*.003,.034,ez-.0248),(.0065,.009,.0018),'pupil',head)
            ell('EyeCatchlight',(ex-.004,.041,ez-.027),(.0028,.003,.001),'glint',head,16,10)
            # Partly hooded almond-shaped eyelids, rim and subtle lower-eye bags.
            curve('UpperLid',[(ex-.031,.035,ez-.003),(ex-.019,.049,ez-.020),(ex+.012,.050,ez-.022),(ex+.031,.037,ez-.001)],.007,'skin',head,[.6,1,1,.5])
            curve('LowerLid',[(ex-.031,.033,ez-.003),(ex,.015,ez-.020),(ex+.031,.035,ez-.002)],.004,'skin_light',head,[.4,1,.4])
            curve('UnderEye',[(ex-.025,.005,ez-.008),(ex,-.001,ez-.012),(ex+.020,.007,ez-.004)],.0012,'crease',head,[.15,1,.1])
            curve('Eyebrow',[(ex-.034,.078,-.108),(ex-.011,.091,-.118),(ex+.022,.081,-.112),(ex+.036,.066,-.096)],.009,'grey' if old else 'hair',head,[.4,1,1,.25])
            ell('Nostril',(side*.026,-.047,-.163),(.009,.005,.007),'crease',head)
            curve('SmileCrease',[(side*.041,-.053,-.127),(side*.063,-.078,-.121),(side*.059,-.101,-.113)],.0015,'crease',head,[.1,1,.1])
        # A shallow curved smile, covered by a strand-shaped moustache.
        curve('QuietSmile',[(-.040,-.094,-.138),(0,-.105,-.143),(.040,-.094,-.138)],.0022,'mouth',head,[.25,1,.25])
        curve('LowerLip',[(-.035,-.103,-.135),(0,-.113,-.138),(.035,-.103,-.135)],.002,'skin_light',head,[.1,1,.1])
        for side in [-1,1]:
            for j in range(8):
                curve('MoustacheStrand',[(side*.006,-.059-j*.0015,-.157),(side*.026,-.065-j*.002,-.150),(side*.051,-.065-j*.001,-.134),(side*.068,-.053-j*.001,-.119)],.003,'grey' if old else 'hair',head,[.45,1,.8,.03])
        # Bald crown and swept side hair; no separate bulbous hair cap.
        for side in [-1,1]:
            ell('SideHair',(side*.110,.074,.025),(.016,.050,.075),'grey' if old else 'hair',head)
            for j in range(15):
                curve('CombedHair',[(side*.094,.131-j*.004,.030),(side*.122,.103-j*.0035,.014),(side*.119,.064-j*.0035,-.031)],.0014,'silver' if old else 'hair_glint',head,[.1,1,.2])
        if kind=='temel':
            ell('FlatCapCrown',(0,.162,.012),(.151,.058,.135),'cap',head,48,24)
            ell('FlatCapBrim',(0,.139,-.092),(.15,.012,.098),'cap',head,48,16)
            curve('CapWelt',[(-.14,.143,-.047),(0,.139,-.167),(.14,.143,-.047)],.002,'seam',head)
            for side in [-1,1]:curve('CapPanelSeam',[(0,.215,.012),(side*.08,.186,-.067),(side*.12,.147,-.071)],.001,'seam',head)
        if old:
            for side in [-1,1]:
                ring('SpectacleRim',(side*.058,.036,-.141),.039,.031,.002,'gold',head)
                curve('SpectacleTemple',[(side*.097,.039,-.137),(side*.13,.042,-.025),(side*.14,.025,.005)],.0018,'gold',head)
            curve('SpectacleBridge',[(-.018,.04,-.143),(0,.046,-.161),(.018,.04,-.143)],.002,'gold',head)
            for j in range(3):curve('ForeheadCrease',[(-.056,.11+j*.013,-.092),(0,.116+j*.013,-.108),(.056,.11+j*.013,-.092)],.0008,'crease',head,[.1,.8,.1])
        if heavy:
            # Gold chain, pendant and wristwatch, kept physically modest.
            curve('NeckChain',[(-.062,.45,-.076),(-.047,.406,-.153),(0,.392,-.169),(.047,.406,-.153),(.062,.45,-.076)],.0028,'gold',torso)
            ell('Pendant',(0,.38,-.171),(.009,.012,.003),'gold',torso)
            ring('WatchBand',(-.205,.324,-.344),.046,.032,.004,'gold',torso)
            ell('WatchFace',(-.205,.360,-.346),(.018,.005,.017),'gold',torso)
        # Export each character separately, with named articulated presentation pivots.
        bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
        for c in root.children_recursive:c.select_set(True)
        folder=os.path.join(project,'assets','models','patrons');os.makedirs(folder,exist_ok=True)
        from io_scene_gltf2 import get_format_items
        fmt=next(i[0] for i in get_format_items(None,bpy.context) if i[0]=='GLB')
        bpy.ops.export_scene.gltf(filepath=os.path.join(folder,kind+'.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_animations=False)
        if heavy:
            local_hand=empty('LocalHand')
            for child in list(torso.children):
                if child.type=='MESH' and child.location.x > .13 and child.name.startswith(('Palm','Finger','Knuckle','Fingernail','Thumb')):
                    duplicate=child.copy();duplicate.data=child.data
                    scene.collection.objects.link(duplicate);duplicate.parent=local_hand
                    duplicate.location=child.location-v((.205,.319,-.399))
            bpy.ops.object.select_all(action='DESELECT');local_hand.select_set(True)
            for child in local_hand.children_recursive:child.select_set(True)
            bpy.ops.export_scene.gltf(filepath=os.path.join(folder,'local_hand.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_animations=False)
            left=empty('LocalHand_Left')
            for child in local_hand.children:
                data=child.data.copy()
                data.transform(Matrix.Diagonal((-1,1,1,1)) @ child.matrix_local)
                data.flip_normals()
                duplicate=bpy.data.objects.new(child.name+'_Left',data)
                scene.collection.objects.link(duplicate);duplicate.parent=left
            bpy.ops.object.select_all(action='DESELECT');left.select_set(True)
            for child in left.children:child.select_set(True)
            bpy.ops.export_scene.gltf(filepath=os.path.join(folder,'local_hand_left.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_animations=False)
        root.location.x=len(roots)*1.0
    source=os.path.join(project,'tools','blender','source');os.makedirs(source,exist_ok=True)
    bpy.data.libraries.write(os.path.join(source,'kiraathane_patrons.blend'),{scene},fake_user=True)
    print('PATRONS_READY', [r.name for r in roots])
