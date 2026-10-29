"""Targeted Blender repairs to independent Sabri variant, preserving the original game asset."""
import bpy,math,os,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def fix(base):
 scene=bpy.data.scenes['Sabri_Varyant01_Calisma'];bpy.context.window.scene=scene
 root=bpy.data.objects['Sabri_Varyant01']
 def find(prefix):return next(o for o in root.children_recursive if o.name.startswith(prefix))
 def select(objects,active=None):
  bpy.ops.object.select_all(action=next(i.identifier for i in bpy.ops.object.select_all.get_rna_type().properties['action'].enum_items if i.identifier=='DESELECT'))
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=active or objects[0]
 def evaluated(o):
  dg=bpy.context.evaluated_depsgraph_get();data=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg)
  o.modifiers.clear();o.data=data
 def unify(parts,name,voxel,iterations=2):
  parent=parts[0].parent
  for o in parts:evaluated(o)
  select(parts);bpy.ops.object.join();o=bpy.context.object;o.name=name
  r=o.modifiers.new('Continuous joint surface','REMESH');r.mode='VOXEL';r.voxel_size=voxel;r.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=r.name)
  s=o.modifiers.new('Relax joint transitions','SMOOTH');s.factor=.32;s.iterations=iterations;bpy.ops.object.modifier_apply(modifier=s.name)
  for p in o.data.polygons:p.use_smooth=True
  o.parent=parent
  return o
 # Keep a single pre-edit checkpoint in the editable-source folder.
 checkpoint=os.path.join(base,'tools/blender/source/sabri_varyant01_before_joint_fixes.blend')
 if not os.path.exists(checkpoint):bpy.data.libraries.write(checkpoint,{scene},fake_user=True)
 # 1. Continuous jacket/sleeve/cuff shell. The sleeveless shirt and zipper stay untouched.
 jacketparts=[find('TrackJacket')]+[find('JacketSleeve'+s) for s in ['L','R']]+[find('SleeveCuff'+s) for s in ['L','R']]
 jacket=unify(jacketparts,'Variant01_ContinuousJacket',.0018,3)
 # Project existing three-stripe decoration onto the repaired outer fabric.
 bpy.context.view_layer.update();jt=BVHTree.FromObject(jacket,bpy.context.evaluated_depsgraph_get())
 for o in root.children_recursive:
  if o.type!='MESH' or not o.name.startswith('Stripe'):continue
  evaluated(o)
  for v in o.data.vertices:
   hit=jt.find_nearest(v.co)
   if hit[0] is not None:
    v.co=hit[0]+hit[1]*.0008
  o.data.update()
 # 2. Forearm, wrist, palm and fingers become a continuous skin mesh per hand.
 hands=[]
 for side in ['L','R']:
  parts=[find('Forearm'+side),find('Palm'+side),find('Thumb'+side)]
  parts += [find('Finger'+finger+side) for finger in ['Index','Middle','Ring','Pinky']]
  hand=unify(parts,'Variant01_HandForearm_'+side,.00085,3)
  hands.append(hand)
 # 3. One pair of trousers: pelvis and seated thighs blend instead of ending in a flat block.
 trousers=unify([find('PelvisPants'),find('FullLegL'),find('FullLegR')],'Variant01_ContinuousTrousers',.0018,3)
 # 4. Surface-fitted eyelids, with the same opening and gaze as the existing character.
 skull=find('FaceSkull');head_parent=skull.parent
 evaluated(skull);bpy.context.view_layer.update();tree=BVHTree.FromObject(skull,bpy.context.evaluated_depsgraph_get())
 def skin_front(x,z):
  hit=tree.ray_cast(Vector((x,.6,z)),Vector((0,-1,0)))
  return hit[0].y if hit[0] is not None else .12
 skin=skull.data.materials[0]
 patches=[]
 for side in ['L','R']:
  white=find('EyeWhite'+side);bpy.context.view_layer.update();et=BVHTree.FromObject(white,bpy.context.evaluated_depsgraph_get())
  # Rest geometry is baked in the head local coordinates.
  points=[v.co for v in white.data.vertices];cx=sum(v.x for v in points)/len(points);cz=sum(v.z for v in points)/len(points)
  for upper in [True,False]:
   old=find(('UpperLid' if upper else 'LowerLid')+side);bpy.data.objects.remove(old,do_unlink=True)
   verts=[];faces=[];steps=56;bands=9
   for k in range(bands+1):
    t=k/bands;blend=t*t*(3-2*t)
    for j in range(steps+1):
     a=math.pi*j/steps;dx=math.cos(a)*(.0185+t*.012)
     opening=.0068 if upper else .0063
     z=cz+(1 if upper else -1)*math.sin(a)*(opening+t*.0175)
     x=cx+dx
     innerx=cx+math.cos(a)*.0185;innerz=cz+(1 if upper else -1)*math.sin(a)*opening
     hit=et.ray_cast(Vector((innerx,.6,innerz)),Vector((0,-1,0)))
     inner=hit[0].y if hit[0] is not None else .136
     y=(1-blend)*(inner+.00045)+blend*(skin_front(x,z)+.00015)
     # Avoid any eyelid intersections with the eyeball.
     shell=et.ray_cast(Vector((x,.6,z)),Vector((0,-1,0)))
     if shell[0] is not None:y=max(y,shell[0].y+.00045)
     verts.append((x,y,z))
   for k in range(bands):
    for j in range(steps):
     a=k*(steps+1)+j;faces.append((a,a+1,a+steps+2,a+steps+1))
   data=bpy.data.meshes.new('EyelidSurface');data.from_pydata(verts,[],faces);data.update()
   bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
   o=bpy.data.objects.new(('UpperLid' if upper else 'LowerLid')+side+'_Variant01',data);scene.collection.objects.link(o);o.parent=head_parent;o.data.materials.append(skin)
   for p in data.polygons:p.use_smooth=True
   sol=o.modifiers.new('Eyelid tissue thickness','SOLIDIFY');sol.thickness=.0018;sol.offset=-1
   patches.append(o)
 # Blend only the new skin patches into the original skull; preserve nose, ears and expression objects.
 skull=unify([skull]+patches,'FaceSkull_Variant01',.00075,2)
 # Surface hygiene and a light density reduction on the larger merged garments.
 for o in [jacket,trousers]+hands:
  d=o.modifiers.new('Sculpt surface density','DECIMATE');d.ratio=.58
  select([o]);bpy.ops.object.modifier_apply(modifier=d.name)
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 # A named editable file and GLB affect only this independent character.
 select([root]+list(root.children_recursive),root)
 from io_scene_gltf2 import get_format_items
 fmt=next(i[0] for i in get_format_items(None,bpy.context) if i[0]=='GLB')
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/character_variants/sabri_varyant01.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/sabri_varyant01.blend'),{scene},fake_user=True)
 print('REPAIRED',[(o.name,len(o.data.vertices)) for o in [jacket,trousers,skull]+hands])
