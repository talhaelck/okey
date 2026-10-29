"""Second targeted Sabri-variant pass: reshape shoulder and wrist; remove watch/bracelet."""
import bpy,math,os,bmesh,hashlib,array
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def adjust(base):
 scene=bpy.data.scenes['Sabri_Varyant01_Calisma'];bpy.context.window.scene=scene;root=bpy.data.objects['Sabri_Varyant01']
 def find(prefix):return next(o for o in root.children_recursive if o.name.startswith(prefix))
 def signature(o):
  values=array.array('f',[0])*(len(o.data.vertices)*3);o.data.vertices.foreach_get('co',values);return hashlib.sha256(values.tobytes()).hexdigest()
 eyes={o.name:signature(o) for o in root.children_recursive if o.type=='MESH' and o.name.startswith(('FaceSkull','EyeWhite','Iris','Pupil','EyeCatchlight'))}
 # Remove every component of the wrist accessory, preserving the finger ring and necklace.
 removed=[]
 for o in list(root.children_recursive):
  if o.name.startswith(('Watch','Bracelet','WristBand')):removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
 def smooth(o,weights,name,iterations,factor):
  group=o.vertex_groups.new(name=name)
  for idx,w in weights:
   if w>.002:group.add([idx],min(1,w),'REPLACE')
  bpy.context.view_layer.objects.active=o
  mod=o.modifiers.new(name,'SMOOTH');mod.vertex_group=group.name;mod.factor=factor;mod.iterations=iterations;bpy.ops.object.modifier_apply(modifier=mod.name)
 # Sculpture the actual shoulder fabric. Protect the lapel opening and the torso silhouette.
 jacket=find('Variant01_ContinuousJacket');old=[v.co.copy() for v in jacket.data.vertices]
 weights=[]
 for v in jacket.data.vertices:
  x,y,z=v.co
  w=math.exp(-((abs(x)-.205)/.075)**2-((z-.512)/.071)**2-((y-.015)/.125)**2)
  # A small inward/downward adjustment removes the hard shoulder-cap ridge.
  if z>.45:
   v.co.x-=math.copysign(.0055*w,x);v.co.z-=.0065*w
  weights.append((v.index,w if z>.405 else 0))
 smooth(jacket,weights,'ShoulderFabricBlend',65,.52)
 bpy.context.view_layer.update();tree=BVHTree.FromObject(jacket,bpy.context.evaluated_depsgraph_get())
 for o in list(root.children_recursive):
  if o.type!='MESH' or not o.name.startswith('Stripe'):continue
  # The piping used to protrude at the shoulder. Terminate it cleanly on the upper sleeve.
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=Vector((0,0,.521)),plane_no=Vector((0,0,1)),clear_outer=True,clear_inner=False)
  bm.to_mesh(o.data);bm.free()
  for v in o.data.vertices:
   hit=tree.find_nearest(v.co)
   if hit[0] is not None:v.co=hit[0]+hit[1]*.0007
  o.data.update()
 shoulder_change=max((a-b.co).length for a,b in zip(old,jacket.data.vertices))
 # Anatomical wrist taper, without moving the hand or changing the fingers.
 wrist_changes=[]
 for side in ['L','R']:
  o=find('Variant01_HandForearm_'+side);old=[v.co.copy() for v in o.data.vertices];s=-1 if side=='L' else 1
  weights=[]
  for v in o.data.vertices:
   x,y,z=v.co;fade=math.exp(-((y-.325)/.028)**2)
   cx=s*(.234-(y-.25)*.34);cz=.246-(y-.25)*.24
   v.co.x=cx+(x-cx)*(1-.16*fade)
   v.co.z=cz+(z-cz)*(1-.10*fade)-.0025*fade
   weights.append((v.index,math.exp(-((y-.326)/.027)**2)))
  smooth(o,weights,'WristPalmBlend',38,.48)
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
  wrist_changes.append(max((a-b.co).length for a,b in zip(old,o.data.vertices)))
 assert eyes=={o.name:signature(o) for o in root.children_recursive if o.type=='MESH' and o.name in eyes},'Eye geometry changed unexpectedly'
 # Basic geometry checks on the edited continuous surfaces.
 for o in [jacket,find('Variant01_HandForearm_L'),find('Variant01_HandForearm_R')]:
  bm=bmesh.new();bm.from_mesh(o.data);print('CHECK',o.name,'boundary',sum(e.is_boundary for e in bm.edges),'nonmanifold',sum(not e.is_manifold for e in bm.edges));bm.free()
 bpy.ops.object.select_all(action=next(i.identifier for i in bpy.ops.object.select_all.get_rna_type().properties['action'].enum_items if i.identifier=='DESELECT'))
 root.select_set(True)
 for o in root.children_recursive:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 from io_scene_gltf2 import get_format_items
 fmt=next(i[0] for i in get_format_items(None,bpy.context) if i[0]=='GLB')
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/character_variants/sabri_varyant01.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/sabri_varyant01.blend'),{scene},fake_user=True)
 print('REMOVED',removed)
 print('SHOULDER_CHANGE_MM',round(shoulder_change*1000,2),'WRIST_CHANGE_MM',[round(x*1000,2) for x in wrist_changes],'EYES_UNCHANGED',True)
