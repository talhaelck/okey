"""Run after coffeehouse_surfacepass.improve in its isolated Blender scene."""
import bpy,bmesh,math,os
from mathutils import Vector

def finish(base):
 scene=bpy.data.scenes['Coffeehouse_SurfacePass'];bpy.context.window.scene=scene
 mats={m.name.split('.')[0]:m for o in scene.objects if o.type=='MESH' for m in o.data.materials if m}
 def v(p):return Vector((p[0],-p[2],p[1]))
 def components(bm):
  seen=set()
  for vert in list(bm.verts):
   if vert in seen:continue
   comp={vert};seen.add(vert);todo=[vert]
   while todo:
    for edge in todo.pop().link_edges:
     for n in edge.verts:
      if n not in seen:seen.add(n);comp.add(n);todo.append(n)
   yield comp
 def box(name,p,size,key,bevel=.004):
  bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mats[key])
  mod=o.modifiers.new('Rolled edges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
  return o
 def tube(name,points,r,key):
  data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=r;data.bevel_resolution=4;data.resolution_u=16
  spline=data.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
  for bp,p in zip(spline.bezier_points,points):bp.co=v(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
  o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);data.materials.append(mats[key])
 # Replace the stacked upper hood with a single folded sheet, preserving the apron/sign.
 if not scene.objects.get('CopperHoodTaper'):
  o=scene.objects['Interior_copper'];bm=bmesh.new();bm.from_mesh(o.data)
  for comp in list(components(bm)):
   pts=[o.matrix_world@p.co for p in comp]
   if min(p.z for p in pts)>2.17 and min(p.x for p in pts)>-3.21 and max(p.x for p in pts)<-1.19:
    bmesh.ops.delete(bm,geom=list(comp),context='VERTS')
  bm.to_mesh(o.data);bm.free()
  pts=[]
  for y,w,d,z in [(2.195,1.67,.55,-2.61),(2.66,.88,.34,-2.72)]:
   pts.extend([v((-2.2+sx*w/2,y,z+sz*d/2)) for sx,sz in [(-1,-1),(1,-1),(1,1),(-1,1)]])
  mesh=bpy.data.meshes.new('Folded hood sheet');mesh.from_pydata(pts,[],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]);mesh.update()
  o=bpy.data.objects.new('CopperHoodTaper',mesh);scene.collection.objects.link(o);mesh.materials.append(mats['Copper'])
  mod=o.modifiers.new('Folded edges','BEVEL');mod.width=.006;mod.segments=3
  box('CopperHoodDuct',(-2.2,2.94,-2.72),(.87,.56,.33),'Copper',.008)
 # Tap belongs on the boiler, not at the middle of the counter.
 for o in scene.objects:
  if o.name.startswith('Semaver') and o.location.x< -1.8:o.location.x+=.52
 # Rebuild rotational shells with 96 radial samples. Preserve every original height/radius
 # so scale and style stay consistent, while rims no longer have zigzag highlights.
 if not scene.get('round_surfaces_finished'):
  count=0
  for name in ['Interior_brass','Interior_dark_metal','Interior_copper']:
   obj=scene.objects[name];bm=bmesh.new();bm.from_mesh(obj.data)
   for comp in list(components(bm)):
    pts=[obj.matrix_world@p.co for p in comp];lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    stove=.35<lo.x and hi.x<1.13 and .0<=lo.z<1.24 and hi.y>2.29 and lo.y<3.07
    boiler=name=='Interior_copper' and lo.x> -1.73 and hi.x< -1.3 and lo.z>.95
    if not(stove or boiler) or len(comp)<48:continue
    cx=(lo.x+hi.x)/2;cy=(lo.y+hi.y)/2
    if abs((hi.x-lo.x)-(hi.y-lo.y))>.012:continue
    rings={}
    for p in pts:rings.setdefault(round(p.z,5),[]).append(math.hypot(p.x-cx,p.y-cy))
    profile=[]
    for z,radii in sorted(rings.items()):
     radii=sorted(radii);r=radii[len(radii)//2]
     if max(radii)-min(radii)>.008:break
     profile.append((z,r))
    else:
     if len(profile)<2:continue
     verts=[];faces=[];n=96
     for z,r in profile:
      for j in range(n):verts.append((cx+r*math.cos(math.tau*j/n),cy+r*math.sin(math.tau*j/n),z))
     for k in range(len(profile)-1):
      for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
     faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+j for j in range(n))])
     mesh=bpy.data.meshes.new('Turned fixture shell');mesh.from_pydata(verts,[],faces);mesh.update()
     fresh=bpy.data.objects.new('TurnedFixture_%02d'%count,mesh);scene.collection.objects.link(fresh);mesh.materials.append(obj.data.materials[0])
     for p in mesh.polygons:p.use_smooth=len(p.vertices)==4
     # Sharp profile creases retain the clean, machined rims.
     mesh.set_sharp_from_angle(angle=math.radians(42))
     bmesh.ops.delete(bm,geom=list(comp),context='VERTS');count+=1
   bm.to_mesh(obj.data);bm.free()
  # Real kettle fittings: curved spout, lid knob, and insulated loop handle.
  tube('StoveKettleSpout',[(.84,1.04,-2.64),(.94,1.08,-2.64),(.98,1.18,-2.64)],.018,'Copper')
  tube('StoveKettleHandle',[(.69,1.17,-2.64),(.61,1.20,-2.64),(.56,1.12,-2.64),(.60,1.01,-2.64),(.66,1.02,-2.64)],.012,'DarkMetal')
  box('StoveKettleLidKnob',(.77,1.246,-2.64),(.033,.024,.033),'DarkMetal',.009)
  for x,side in [(-1.71,-1),(-1.33,1)]:
   tube('SemaverSideHandle',[(x,1.39,-2.54),(x+side*.055,1.39,-2.54),(x+side*.055,1.28,-2.54),(x,1.28,-2.54)],.009,'DarkMetal')
  scene['round_surfaces_finished']=True
  print('Turned fixture shells',count)
 # Keep source previews plausible; game applies the shared triplanar maps.
 for key,rough,metal in [('Copper',.72,.72),('Brass',.72,.64),('DarkMetal',.83,.38)]:
  p=next(n for n in mats[key].node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 bpy.ops.object.select_all(action='DESELECT')
 for o in scene.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/muhabbet_surfacepass.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/muhabbet_surfacepass.blend'),{scene},fake_user=True)
 print('Coffeehouse final geometry exported')
