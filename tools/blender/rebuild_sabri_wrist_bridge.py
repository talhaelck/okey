import bpy,math,os,bmesh
from mathutils import Vector

def bridge(base):
 root=bpy.data.objects['Sabri_Varyant01'];scene=bpy.context.scene
 def select(objects):
  bpy.ops.object.select_all(action=next(i.identifier for i in bpy.ops.object.select_all.get_rna_type().properties['action'].enum_items if i.identifier=='DESELECT'))
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
 for side in ['L','R']:
  hand=next(o for o in root.children_recursive if o.name=='Variant01_HandForearm_'+side);s=-1 if side=='L' else 1
  profiles=[(.290,.037,.034,.236),(.300,.035,.032,.233),(.310,.034,.030,.230),(.320,.033,.028,.227),(.330,.033,.027,.225),(.340,.035,.026,.223),(.350,.039,.025,.222),(.360,.043,.024,.221),(.370,.045,.022,.220)]
  verts=[];faces=[];steps=48
  for y,rx,rz,cz in profiles:
   cx=s*(.234-(y-.25)*.34)
   for j in range(steps):
    a=j*math.tau/steps;verts.append((cx+rx*math.cos(a),y,cz+rz*math.sin(a)))
  for i in range(len(profiles)-1):
   for j in range(steps):
    a=i*steps+j;b=i*steps+(j+1)%steps;faces.append((a,b,b+steps,a+steps))
  faces+=[tuple(reversed(range(steps))),tuple((len(profiles)-1)*steps+j for j in range(steps))]
  data=bpy.data.meshes.new('WristConnectingSurface');data.from_pydata(verts,[],faces);data.update()
  bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
  o=bpy.data.objects.new('WristConnectingSurface',data);scene.collection.objects.link(o);o.parent=hand.parent;o.data.materials.append(hand.data.materials[0])
  select([hand,o]);bpy.ops.object.join()
  rem=hand.modifiers.new('Fuse anatomical wrist bridge','REMESH');rem.mode='VOXEL';rem.voxel_size=.0008;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
  group=hand.vertex_groups.new(name='WristSurfaceRelax')
  for v in hand.data.vertices:
   w=math.exp(-((v.co.y-.335)/.035)**2)
   if w>.005:group.add([v.index],w,'REPLACE')
  sm=hand.modifiers.new('Relax wrist transition','SMOOTH');sm.vertex_group=group.name;sm.factor=.55;sm.iterations=22;bpy.ops.object.modifier_apply(modifier=sm.name)
  dec=hand.modifiers.new('Retain wrist silhouette','DECIMATE');dec.ratio=min(1,18000/len(hand.data.vertices));bpy.ops.object.modifier_apply(modifier=dec.name)
  for p in hand.data.polygons:p.use_smooth=True
  bm=bmesh.new();bm.from_mesh(hand.data);print('WRIST',side,'open edges',sum(e.is_boundary for e in bm.edges),'vertices',len(hand.data.vertices));bm.free()
 select([root]+list(root.children_recursive));bpy.context.view_layer.objects.active=root
 from io_scene_gltf2 import get_format_items
 fmt=next(i[0] for i in get_format_items(None,bpy.context) if i[0]=='GLB')
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/character_variants/sabri_varyant01.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/sabri_varyant01.blend'),{scene},fake_user=True)
