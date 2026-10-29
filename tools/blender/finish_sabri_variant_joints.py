import bpy,math,os,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def finish(base):
 scene=bpy.data.scenes['Sabri_Varyant01_Calisma'];bpy.context.window.scene=scene;root=bpy.data.objects['Sabri_Varyant01']
 def find(prefix):return next(o for o in root.children_recursive if o.name.startswith(prefix))
 def apply(o,mod):
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 # Blend the existing seated hip crease over a broader cloth region.
 pants=find('Variant01_ContinuousTrousers');group=pants.vertex_groups.new(name='HipTransition')
 for v in pants.data.vertices:
  x,y,z=v.co;weight=math.exp(-((z-.005)/.075)**2)*math.exp(-((y-.12)/.19)**2)
  if weight>.01:group.add([v.index],weight,'REPLACE')
 sm=pants.modifiers.new('Sculpt hip fabric blend','SMOOTH');sm.factor=.55;sm.iterations=18;sm.vertex_group=group.name;apply(pants,sm)
 # Surface-fitted iris/pupil discs replace protruding ellipsoids, retaining gaze and eye colour.
 for side in ['L','R']:
  eye=find('EyeWhite'+side);tree=BVHTree.FromObject(eye,bpy.context.evaluated_depsgraph_get())
  oldiris=find('Iris'+side);cx=sum(v.co.x for v in oldiris.data.vertices)/len(oldiris.data.vertices);cz=sum(v.co.z for v in oldiris.data.vertices)/len(oldiris.data.vertices)
  parent=oldiris.parent;iris_material=oldiris.data.materials[0];pupil=find('Pupil'+side);pupil_material=pupil.data.materials[0]
  bpy.data.objects.remove(oldiris,do_unlink=True);bpy.data.objects.remove(pupil,do_unlink=True)
  def surface(x,z):
   h=tree.ray_cast(Vector((x,.6,z)),Vector((0,-1,0)));return h[0].y if h[0] is not None else .14
  for part,radius,mat in [('Iris',.0090,iris_material),('Pupil',.0046,pupil_material)]:
   verts=[(cx,surface(cx,cz)+(.0002 if part=='Iris' else .0004),cz)];faces=[];steps=64;bands=12
   for i in range(1,bands+1):
    r=radius*i/bands
    for j in range(steps):
     a=j*math.tau/steps;x=cx+math.cos(a)*r;z=cz+math.sin(a)*r;verts.append((x,surface(x,z)+(.0002 if part=='Iris' else .0004),z))
   for j in range(steps):faces.append((0,1+j,1+(j+1)%steps))
   for i in range(bands-1):
    for j in range(steps):
     a=1+i*steps+j;b=1+i*steps+(j+1)%steps;faces.append((a,b,b+steps,a+steps))
   data=bpy.data.meshes.new('Surface'+part);data.from_pydata(verts,[],faces);data.update()
   bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
   o=bpy.data.objects.new(part+side+'_Variant01',data);scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat)
   for p in data.polygons:p.use_smooth=True
   if part=='Iris':
    attr=data.color_attributes.new(name='IrisTone',type='FLOAT_COLOR',domain='POINT')
    for v in data.vertices:
     dx=v.co.x-cx;dz=v.co.z-cz;a=math.atan2(dz,dx);r=math.hypot(dx,dz)/radius;grain=.80+.12*math.sin(a*37)+.08*math.sin(a*71+r*5);rim=1-.4*r**5
     attr.data[v.index].color=(.11*grain*rim,.052*grain*rim,.014*grain*rim,1)
    material=mat.copy();o.data.materials[0]=material;pr=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED');vc=material.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='IrisTone';material.node_tree.links.new(vc.outputs['Color'],pr.inputs['Base Color'])
  catch=find('EyeCatchlight'+side)
  for v in catch.data.vertices:v.co.y=surface(v.co.x,v.co.z)+.0007
 # Keep sculpt contours but export a practical amount of geometry, no benchmark loop.
 targets=[('Variant01_ContinuousJacket',38000),('Variant01_ContinuousTrousers',36000),('FaceSkull_Variant01',65000),('Variant01_HandForearm_L',16000),('Variant01_HandForearm_R',16000)]
 for prefix,target in targets:
  o=find(prefix)
  if prefix=='FaceSkull_Variant01':
   sm=o.modifiers.new('Relax voxel sampling','SMOOTH');sm.factor=.4;sm.iterations=4;apply(o,sm)
  d=o.modifiers.new('Final sculpt surface density','DECIMATE');d.ratio=min(1,target/len(o.data.vertices));apply(o,d)
  for p in o.data.polygons:p.use_smooth=True
 # Verify that the repaired load-bearing joints are single connected surfaces.
 for prefix,target in targets:
  o=find(prefix);bm=bmesh.new();bm.from_mesh(o.data);seen=set();components=[]
  for v in bm.verts:
   if v in seen:continue
   stack=[v];count=0;seen.add(v)
   while stack:
    q=stack.pop();count+=1
    for e in q.link_edges:
     other=e.other_vert(q)
     if other not in seen:seen.add(other);stack.append(other)
   components.append(count)
  boundary=sum(e.is_boundary for e in bm.edges);bm.free()
  print('CHECK',prefix,'vertices',len(o.data.vertices),'components',sorted(components,reverse=True)[:8],'boundary_edges',boundary)
 bpy.ops.object.select_all(action=next(i.identifier for i in bpy.ops.object.select_all.get_rna_type().properties['action'].enum_items if i.identifier=='DESELECT'))
 root.select_set(True)
 for o in root.children_recursive:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 from io_scene_gltf2 import get_format_items
 fmt=next(i[0] for i in get_format_items(None,bpy.context) if i[0]=='GLB')
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/character_variants/sabri_varyant01.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/sabri_varyant01.blend'),{scene},fake_user=True)
 print('SABRI_VARIANT_FINISHED')
