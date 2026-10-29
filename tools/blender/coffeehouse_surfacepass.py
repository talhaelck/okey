"""Preserve the room layout; repair surface normals and add coffeehouse fixture details."""
import bpy,bmesh,math,os
from mathutils import Vector

def improve(base):
 scene=bpy.data.scenes['Coffeehouse_SurfacePass'];bpy.context.window.scene=scene
 # Planar faces keep planar normals; curved stove/samovar surfaces stay smooth.
 original=[o for o in scene.objects if o.type=='MESH']
 for obj in original:
  bpy.context.view_layer.objects.active=obj
  mesh=obj.data
  if hasattr(mesh,'normals_split_custom_set'):mesh.normals_split_custom_set([(0,0,0)]*len(mesh.loops))
  if hasattr(mesh,'set_sharp_from_angle'):mesh.set_sharp_from_angle(angle=math.radians(48))
  mod=obj.modifiers.new('Area weighted fixture normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
  bpy.ops.object.modifier_apply(modifier=mod.name)
 mats={}
 for o in original:
  for mat in o.data.materials:
   if mat:mats[mat.name.split('.')[0]]=mat
 def v(p):return Vector((p[0],-p[2],p[1]))
 def assign(o,name,key):
  o.name=name;o.data.materials.append(mats[key]);return o
 def rod(name,a,b,r,key):
  aa,bb=v(a),v(b);d=bb-aa
  bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=d.length,location=(aa+bb)/2)
  o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized())
  assign(o,name,key)
  for p in o.data.polygons:p.use_smooth=abs(p.normal.z)<.5
  bevel=o.modifiers.new('Machined edge','BEVEL');bevel.width=min(.002,r*.20);bevel.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
  return o
 def curve(name,points,r,key):
  data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=r;data.bevel_resolution=3;data.resolution_u=12
  spline=data.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
  for bp,p in zip(spline.bezier_points,points):bp.co=v(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
  o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.data.materials.append(mats[key]);return o
 def box(name,p,size,key,bevel=.003):
  bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  assign(o,name,key);mod=o.modifiers.new('Soft edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name);return o
 # Stove front: properly assembled cast hinges and a cool-touch wooden latch.
 for h in [.385,.515]:
  rod('StoveDoorHinge',(.635,h-.021,-2.418),(.635,h+.021,-2.418),.009,'DarkMetal')
  rod('StoveHingePin',(.635,h-.027,-2.418),(.635,h+.027,-2.418),.003,'Brass')
 rod('StoveLatchSpindle',(.865,.45,-2.448),(.865,.45,-2.394),.006,'DarkMetal')
 rod('StoveWoodLatch',(.865,.45,-2.394),(.922,.45,-2.394),.010,'CarvedWood')
 # Ash drawer handle and lower vent slots.
 curve('AshDrawerPull',[(.685,.205,-2.421),(.690,.205,-2.391),(.785,.205,-2.391),(.79,.205,-2.421)],.006,'DarkMetal')
 for i in range(6):box('StoveVentSlot',(.69+i*.020,.275,-2.452),(.008,.033,.003),'DarkMetal',.001)
 # Poker and small coal shovel rest safely next to the stove.
 curve('StovePoker',[(1.065,.075,-2.64),(1.075,.79,-2.70),(1.085,.84,-2.70),(1.11,.835,-2.70),(1.105,.79,-2.70)],.006,'DarkMetal')
 rod('CoalShovelShaft',(1.15,.14,-2.65),(1.15,.71,-2.70),.007,'DarkMetal')
 box('CoalShovelBlade',(1.15,.085,-2.64),(.085,.11,.018),'DarkMetal',.008)
 # Semaver original body location is read from the author's scene: detailed tap on front of the kazan.
 # These fittings belong to the same copper/brass palette as the original boiler.
 rod('SemaverTapPipe',(-2.04,1.105,-2.50),(-2.04,1.105,-2.32),.009,'Brass')
 curve('SemaverTapSpout',[(-2.04,1.105,-2.32),(-2.04,1.09,-2.29),(-2.04,1.055,-2.29)],.008,'Brass')
 rod('SemaverValveStem',(-2.04,1.105,-2.36),(-2.04,1.143,-2.36),.004,'Brass')
 rod('SemaverValveHandle',(-2.075,1.145,-2.36),(-2.005,1.145,-2.36),.008,'DarkMetal')
 # Spoon rail inside the tea alcove, with individual hooks and metal spoons.
 rod('TeaSpoonRail',(-3.04,1.48,-2.93),(-2.62,1.48,-2.93),.006,'Brass')
 for i in range(5):
  x=-3.00+i*.073
  curve('SpoonHook',[(x,1.49,-2.93),(x,1.48,-2.91),(x,1.45,-2.91)],.002,'Brass')
  rod('HangingTeaSpoon',(x,1.455,-2.905),(x,1.355,-2.905),.0018,'Brass')
  # Spoon bowl is a shallow formed oval, with no oversized chrome highlights.
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=v((x,1.342,-2.905)))
  o=bpy.context.object;o.scale=(.008,.0017,.015);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);assign(o,'TeaSpoonBowl','Brass')
  for p in o.data.polygons:p.use_smooth=True
 # New materials remain physically plausible even when opening the editable source alone.
 for key,rough,metal in [('Copper',.60,.78),('Brass',.53,.73),('DarkMetal',.83,.38),('Marble',.54,0),('EnamelGreen',.49,.10)]:
  p=next(n for n in mats[key].node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 # Export exactly this room scene; all character and unsaved scenes are preserved.
 bpy.ops.object.select_all(action=next(i.identifier for i in bpy.ops.object.select_all.get_rna_type().properties['action'].enum_items if i.identifier=='DESELECT'))
 for o in scene.objects:o.select_set(True)
 from io_scene_gltf2 import get_format_items
 fmt=next(i[0] for i in get_format_items(None,bpy.context) if i[0]=='GLB')
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/muhabbet_surfacepass.glb'),export_format=fmt,use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/muhabbet_surfacepass.blend'),{scene},fake_user=True)
 print('SURFACEPASS_READY',len(scene.objects),'objects')
