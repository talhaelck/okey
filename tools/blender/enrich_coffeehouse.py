"""Hand-authored neighbourhood cafe fixtures, applied after build_calm_coffeehouse.
Preserves the clean playing surface and all character assets.
"""
import bpy,math,os,random
from mathutils import Vector
def enrich(base):
 source=bpy.data.scenes['Kahvehane_Sade_360'];scene=source.copy();scene.name='Kahvehane_Atmosfer'
 bpy.context.window.scene=scene
 # Copy objects and parent links so the earlier room stays independently editable.
 copies={o:o.copy() for o in list(scene.objects)}
 for old,new in copies.items():
  scene.collection.objects.link(new)
  for c in list(old.users_collection):
   if c==scene.collection:c.objects.unlink(old)
 for old,new in copies.items():
  if old.parent in copies:new.parent=copies[old.parent]
 rng=random.Random(13)
 def v(p):return Vector((p[0],-p[2],p[1]))
 def mat(name,color,rough=.7,metal=0):
  m=bpy.data.materials.new(name);m.use_nodes=True
  n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
  rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)];rgb=[((c+.055)/1.055)**2.4 for c in rgb]
  n.inputs['Base Color'].default_value=(*rgb,1);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal
  # Fine physical pores: small relief without broad diagonal patterns.
  noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=160
  bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.00025
  m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],n.inputs['Normal'])
  return m
 mats={k:mat(k,*a) for k,a in {'CafeBakelite':('363b37',.58),'CafeRubber':('222825',.88),'CafeSteel':('8b908b',.48,.75),'CalmOak':('806548',.8),'CalmIron':('343935',.8,.3),'CalmCopper':('aa744b',.60,.7),'CafeBrick':('825b47',.95),'CafeMortar':('827d6c',.98),'CafeBottle':('28523c',.24),'CafeLabel':('d9d1aa',.88),'CafeCoat':('655f4e',.98),'CafeRadiator':('a5a598',.74),'CafeCream':('d2ccb4',.68)}.items()}
 def assign(o,name,key):o.name=name;o.data.materials.append(mats[key]);return o
 def box(name,p,size,key,bevel=.007):
  bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);assign(o,name,key)
  if bevel:
   m=o.modifiers.new('Rounded manufactured edge','BEVEL');m.width=min(bevel,min(size)*.35);m.segments=4;bpy.ops.object.modifier_apply(modifier=m.name)
   m=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
  return o
 def tube(name,points,r,key):
  data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=18;data.bevel_depth=r;data.bevel_resolution=4
  sp=data.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
  for bp,p in zip(sp.bezier_points,points):bp.co=v(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
  o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);data.materials.append(mats[key]);return o
 def mesh(name,pts,faces,key):
  me=bpy.data.meshes.new(name);me.from_pydata([v(p) for p in pts],[],faces);me.update();o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);assign(o,name,key)
  for p in me.polygons:p.use_smooth=True
  return o
 def lathe(name,p,prof,key,n=80):
  pts=[(p[0]+r*math.cos(j*math.tau/n),p[1]+h,p[2]+r*math.sin(j*math.tau/n)) for r,h in prof for j in range(n)]
  faces=[(k*n+j,(k+1)*n+j,(k+1)*n+(j+1)%n,k*n+(j+1)%n) for k in range(len(prof)-1) for j in range(n)]
  return mesh(name,pts,faces,key)
 # One small old brick bay behind the flag; other plaster walls stay quiet.
 box('Brick bay mortar',(.25,2.035,-4.13),(1.85,2.27,.025),'CafeMortar',.004)
 for row in range(21):
  for col in range(8):
   x=-.66+col*.235+(row%2)*.115
   if x>1.12:continue
   left=max(-.675,x-.111);right=min(1.175,x+.111)
   if right-left<.03:continue
   brick=box('Aged brick',((left+right)/2,.955+row*.107,-4.105),(right-left,.096,.035),'CafeBrick',.005)
   brick.rotation_euler.y=rng.uniform(-.008,.008)
 for x in [-.72,1.22]:box('Brick bay oak edging',(x,2.035,-4.08),(.035,2.27,.05),'CalmOak',.005)
 # A complete CRT television: rounded cabinet, convex glass, bezel, controls and wall bracket.
 tx,ty,tz=2.50,2.18,-3.92
 box('CRT bakelite cabinet',(tx,ty,tz),(.66,.46,.38),'CafeBakelite',.045)
 box('CRT recessed black bezel',(tx-.035,ty+.012,tz+.198),(.525,.368,.026),'CafeRubber',.030)
 pts=[];faces=[]
 for iy in range(17):
  for ix in range(25):
   u=(ix/24-.5)*.46;w=(iy/16-.5)*.30;bulge=.025*(1-(u/.24)**2)*(1-(w/.16)**2)
   pts.append((tx-.035+u,ty+.012+w,tz+.216+bulge))
 for iy in range(16):
  for ix in range(24):a=iy*25+ix;faces.append((a,a+1,a+26,a+25))
 screen=mesh('CRT_Screen',pts,faces,'CafeRubber')
 uv=screen.data.uv_layers.new(name='ScreenUV')
 for loop in screen.data.loops:
  index=loop.vertex_index;uv.data[loop.index].uv=(index%25/24,index//25/16)
 for y in [ty+.07,ty-.025]:
  dial=lathe('CRT tuning dial',(0,0,0),[(0,0),(.022,0),(.024,.006),(.023,.016),(0,.016)],'CafeBakelite',48)
  dial.rotation_euler.x=math.pi/2;dial.location=v((tx+.278,y,tz+.205))
 for i in range(8):box('CRT speaker grille',(tx+.278,ty-.12+i*.009,tz+.204),(.052,.0025,.005),'CafeRubber',.001)
 for i in range(10):box('CRT side cooling vent',(tx+.331,ty-.12+i*.024,tz-.04),(.002,.008,.15),'CafeRubber',.001)
 box('TV wall shelf',(tx,ty-.255,tz-.025),(.76,.035,.46),'CalmOak',.008)
 for x in [tx-.23,tx+.23]:tube('TV steel shelf bracket',[(x,ty-.29,tz+.10),(x,ty-.53,-4.12),(x,ty-.26,-4.12)],.013,'CalmIron')
 tube('TV power cord',[(tx+.25,ty-.18,tz-.15),(tx+.36,ty-.52,-4.11),(tx+.38,1.33,-4.11)],.003,'CafeRubber')
 # An antique decorative double-barrel hunting gun above the brick bay.
 stock=[(-.64,2.79),(-.64,2.68),(-.54,2.66),(-.30,2.71),(-.18,2.73),(-.10,2.75),(-.13,2.82),(-.32,2.80),(-.53,2.80)]
 pts=[(x,y,z) for z in [-4.04,-3.99] for x,y in stock];n=len(stock)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 o=mesh('Antique walnut gunstock',pts,faces,'CalmOak');m=o.modifiers.new('Carved stock rounding','BEVEL');m.width=.014;m.segments=4
 box('Antique receiver',(-.09,2.765,-4.015),(.19,.052,.055),'CafeSteel',.009)
 for z in [-4.034,-4.005]:tube('Decorative hunting barrel',[(0,2.782,z),(.63,2.782,z)],.011,'CalmIron')
 box('Walnut fore-end',(.19,2.757,-4.016),(.26,.035,.055),'CalmOak',.012)
 tube('Trigger guard',[(-.15,2.75,-3.985),(-.16,2.70,-3.985),(-.06,2.69,-3.985),(-.02,2.75,-3.985)],.004,'CalmIron')
 for x in [-.44,.43]:tube('Rifle wall peg',[(x,2.73,-4.13),(x,2.73,-3.97)],.008,'CalmIron')
 # Coat rack and one draped coat at the entrance-side wall.
 box('Coat hook board',(2.16,1.94,4.11),(1.05,.14,.035),'CalmOak',.010)
 for x in [1.78,2.15,2.52]:tube('Curved coat hook',[(x,1.93,4.09),(x,1.86,4.02),(x,1.91,3.98)],.008,'CafeSteel')
 pts=[];faces=[]
 for y in range(19):
  h=y/18;half=.24*(1-.20*h)
  for j in range(25):
   u=j/24*2-1;pts.append((2.15+u*half,.98+h*.87,4.00-.045*math.cos(u*math.tau*2)-.025*math.sin(h*6)))
 for y in range(18):
  for j in range(24):a=y*25+j;faces.append((a,a+1,a+26,a+25))
 coat=mesh('Draped work jacket',pts,faces,'CafeCoat');sol=coat.modifiers.new('Cloth thickness','SOLIDIFY');sol.thickness=.004
 tube('Jacket sleeve L',[(1.99,1.78,3.99),(1.84,1.53,3.99),(1.89,1.18,4.00)],.045,'CafeCoat')
 tube('Jacket sleeve R',[(2.31,1.78,3.99),(2.41,1.51,3.99),(2.36,1.17,4.00)],.045,'CafeCoat')
 # Short radiator under the window, not another table or repeated decoration.
 for z in [-1.85,-1.63,-1.41,-1.19,-.97,-.75]:
  box('Radiator cast section',(3.99,.48,z),(.15,.65,.16),'CafeRadiator',.055)
 for y in [.24,.71]:tube('Radiator manifold',[(4.0,y,-1.98),(4.0,y,-.65)],.022,'CafeRadiator')
 # Two small side tables return, with uncluttered individual props.
 for x,z in [(-.92,.75),(.88,.76)]:
  lathe('YanSehpaTop',(x,.671,z),[(0,0),(.17,0),(.18,.009),(.18,.031),(.17,.039),(0,.039)],'CalmOak')
  for dx in [-.10,.10]:
   for dz in [-.10,.10]:tube('YanSehpaLeg',[(x+dx*1.25,.015,z+dz*1.25),(x+dx,.675,z+dz)],.013,'CalmOak')
 # Mineral water bottle with proper rolled neck, crown cap and paper label.
 p=(.90,.710,.76)
 lathe('Ribbed soda bottle',p,[(0,0),(.025,0),(.030,.008),(.030,.09),(.028,.13),(.019,.16),(.012,.178),(.012,.218),(.015,.223),(.015,.230),(.010,.232),(.010,.221),(.008,.218)],'CafeBottle',96)
 lathe('Bottle paper sleeve',(p[0],p[1]+.055,p[2]),[(.0302,0),(.0302,.052)],'CafeLabel',96)
 lathe('Bottle crown cap',(p[0],p[1]+.230,p[2]),[(0,0),(.015,0),(.015,.005),(0,.006)],'CafeSteel',64)
 # One ashtray on a third narrow stand opposite the local player.
 box('Small ashtray stand',(-.89,.68,-.58),(.28,.035,.29),'CalmOak',.025)
 for x in [-1.0,-.78]:
  for z in [-.68,-.48]:tube('Ashtray stand leg',[(x,.015,z),(x,.664,z)],.012,'CalmOak')
 before=set(scene.objects);bpy.ops.import_scene.gltf(filepath=os.path.join(base,'assets/models/table_details/cut_glass_ashtray.glb'))
 added=set(scene.objects)-before;root=bpy.data.objects.new('SideAshtray',None);scene.collection.objects.link(root)
 for o in added:
  if o.parent not in added:o.parent=root
 root.location=v((-.89,.699,-.58))
 # Craft detail on the existing stove and kettles, rather than scaling them up.
 stove=next(o for o in scene.objects if o.name.startswith('CornerSoba'))
 # Dark fuel with glowing seams replaces the old bright round coal dots.
 for o in list(scene.objects):
  if o.name.startswith('Visible quiet coal'):bpy.data.objects.remove(o,do_unlink=True)
 for i in range(5):
  x=-.063+i*.031;y=.43+(i%2)*.023
  o=box('Charred stove fuel',(x,y,.256),(.032,.022,.012),'CafeRubber',.006);o.parent=stove
 for pot in list(scene.objects):
  if pot.name.startswith('Stacked tea kettle'):
   lip=lathe('Teapot rolled spout lip',(.169,.184,0),[(.014,0),(.015,.0015),(.015,.004),(.012,.004)],'CafeSteel',64);lip.parent=pot
 for y in [.19,.68]:
  for a in range(12):
   t=a*math.tau/12;obj=lathe('Stove seam rivet',(0,0,0),[(0,0),(.004,0),(.005,.002),(0,.004)],'CafeSteel',16)
   obj.parent=stove;obj.location=v((.237*math.cos(t),y,.237*math.sin(t)))
 # Save separately; Godot loads the new room without touching old source files.
 bpy.ops.object.select_all(action='DESELECT')
 for o in scene.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/kahvehane_atmosphere.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/kahvehane_atmosphere.blend'),{scene},fake_user=True)
 print('ATMOSPHERE_SAVED',len(scene.objects))
