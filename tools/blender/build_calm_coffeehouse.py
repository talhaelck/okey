"""An uncluttered, four-sided neighbourhood kahvehane. All dimensions in metres.
Creates an isolated scene; leaves earlier room/character scenes intact.
"""
import bpy,math,os,random
from mathutils import Vector

def build(base):
 previous=bpy.data.scenes.get('Kahvehane_Sade_360')
 if previous:bpy.data.scenes.remove(previous)
 scene=bpy.data.scenes.new('Kahvehane_Sade_360');bpy.context.window.scene=scene
 rng=random.Random(42)
 def xyz(p):return (p[0],-p[2],p[1])
 def mat(name,color,rough=.7,metal=0,alpha=1,emission=0):
  m=bpy.data.materials.new(name);m.use_nodes=True
  n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
  rgb=tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
  # Input colours are sRGB; Blender node inputs store linear colour.
  rgb=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)
  n.inputs['Base Color'].default_value=(*rgb,alpha);n.inputs['Roughness'].default_value=rough;n.inputs['Metallic'].default_value=metal;n.inputs['Alpha'].default_value=alpha
  if emission:n.inputs['Emission Color'].default_value=(*rgb,1);n.inputs['Emission Strength'].default_value=emission
  m.diffuse_color=(*rgb,alpha)
  return m
 mats={k:mat(k,*args) for k,args in {
 'CalmPlaster':('b6ac96',.94),'CalmSage':('69766a',.9),'CalmCeiling':('9f998a',.95),
 'CalmOak':('806548',.73),'CalmFloor':('8c7053',.8),'CalmDarkOak':('4b4033',.8),
 'CalmIron':('343935',.83,.35),'CalmSteel':('aaa99e',.42,.78),'CalmCopper':('9d6845',.65,.73),
 'CalmBronze':('8c795a',.65,.65),'CalmCream':('d8d1bb',.38),'CalmPorcelain':('e3dcc9',.28),
 'CalmTea':('541a0c',.18),'CalmGlass':('d4e0d9',.14,0,.24),
 'CalmPlastic':('c7c9b9',.63),'CalmPlasticGreen':('617565',.66),
 'CalmFabric':('697c7b',.97),'CalmMarble':('bdb5a1',.63),'CalmFelt':('3b5b49',.94),
 'CalmBulb':('ffe0ae',.6,0,1,1.1),'CalmEmber':('a94e25',.8,0,1,.22),
 'CalmWindow':('687d83',.85),'CalmBlack':('272b29',.7)
 }.items()}
 def finish(o,name,key,smooth=False):
  o.name=name;o.data.materials.append(mats[key])
  if smooth:
   for p in o.data.polygons:p.use_smooth=True
  return o
 def bevel(o,width=.008):
  m=o.modifiers.new('Soft manufactured edges','BEVEL');m.width=width;m.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
  return o
 def box(name,p,size,key,edge=.005):
  bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  finish(o,name,key)
  if edge:bevel(o,min(edge,min(size)*.4))
  return o
 def mesh(name,verts,faces,key,smooth=False):
  data=bpy.data.meshes.new(name);data.from_pydata([xyz(p) for p in verts],[],faces);data.update()
  o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);return finish(o,name,key,smooth)
 def lathe(name,p,profile,key,n=80):
  verts=[(p[0]+r*math.cos(j*math.tau/n),p[1]+h,p[2]+r*math.sin(j*math.tau/n)) for r,h in profile for j in range(n)]
  # Clockwise in Godot XZ; Blender export retains outward normals.
  faces=[(k*n+j,(k+1)*n+j,(k+1)*n+(j+1)%n,k*n+(j+1)%n) for k in range(len(profile)-1) for j in range(n)]
  o=mesh(name,verts,faces,key,True)
  o.data.set_sharp_from_angle(angle=math.radians(48));return o
 def tube(name,points,r,key):
  data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=20;data.bevel_depth=r;data.bevel_resolution=4
  sp=data.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
  for bp,p in zip(sp.bezier_points,points):bp.co=xyz(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
  o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);data.materials.append(mats[key]);return o
 def sphere(name,p,size,key):
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,location=xyz(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,key,True)
 def group(name,fn,p,angle=0):
  before=set(scene.objects);fn();children=set(scene.objects)-before
  root=bpy.data.objects.new(name,None);scene.collection.objects.link(root)
  for o in children:
   if o.parent not in children:o.parent=root
  root.location=xyz(p);root.rotation_euler.z=angle
  return root
 # Warm lime walls and quiet sage wainscot; no dense ornamental grid.
 box('Back lime wall',(0,1.6,-3.55),(7.2,3.2,.16),'CalmPlaster',0)
 box('Entry lime wall',(0,1.6,3.55),(7.2,3.2,.16),'CalmPlaster',0)
 box('Left lime wall',(-3.55,1.6,0),(.16,3.2,7.0),'CalmPlaster',0)
 # The right wall is built around an actual window opening, not a picture on a wall.
 for z,length in [(-2.65,1.8),(1.7,3.7)]:box('Right lime wall',(3.55,1.6,z),(.16,3.2,length),'CalmPlaster',0)
 box('Window below',(3.55,.55,-.95),(.16,1.1,1.6),'CalmPlaster',0)
 box('Window above',(3.55,2.92,-.95),(.16,.56,1.6),'CalmPlaster',0)
 box('Quiet ceiling',(0,3.23,0),(7.2,.12,7.2),'CalmCeiling',0)
 for i in range(24):
  z=-3.45+i*.30
  # Wide floor boards with staggered joints and tiny seams.
  for a,b in [(-3.5,-.8+(i%3)*.65),(-.8+(i%3)*.65,3.5)]:box('Wide floor board',((a+b)/2,-.034,z),(b-a-.003,.06,.297),'CalmFloor',.001)
 for side in [-1,1]:
  for along in range(20):
   t=-3.33+along*.35
   box('Sage tongue groove',(t,.44,side*3.448),(.347,.88,.035),'CalmSage',.002)
   box('Sage tongue groove',(side*3.448,.44,t),(.035,.88,.347),'CalmSage',.002)
  for y,h in [(.07,.12),(.90,.055)]:
   box('Wall rail',(0,y,side*3.423),(6.94,h,.045),'CalmDarkOak')
   box('Wall rail',(side*3.423,y,0),(.045,h,6.94),'CalmDarkOak')
 # One readable service counter: closed cupboards, shallow backsplash, a single shelf.
 counter_before=set(scene.objects)
 box('Tea counter carcass',(-2.07,.44,-3.08),(2.08,.86,.61),'CalmDarkOak',.018)
 for x in [-2.58,-1.56]:
  box('Closed oak cupboard',(x,.45,-2.76),(.995,.76,.035),'CalmOak',.008)
  tube('Cupboard handle',[(x+.30,.59,-2.728),(x+.30,.59,-2.706),(x+.30,.48,-2.706),(x+.30,.48,-2.728)],.006,'CalmBronze')
 box('Honed stone counter',(-2.07,.903,-3.055),(2.16,.055,.69),'CalmMarble',.013)
 box('Plain tile splashback',(-2.07,1.23,-3.431),(2.12,.60,.025),'CalmCream',.004)
 # Few broad grout lines, no floating unexplained blocks.
 for x in [-2.60,-2.07,-1.54]:box('Fine tile joint',(x,1.23,-3.415),(.002,.59,.001),'CalmMarble',0)
 box('Open oak shelf',(-2.07,1.64,-3.26),(2.12,.038,.27),'CalmOak',.006)
 for x in [-2.84,-1.30]:tube('Shelf bracket',[(x,1.64,-3.19),(x,1.46,-3.41),(x,1.64,-3.41)],.009,'CalmIron')
 # A low, quiet wall-mounted extraction canopy rather than a towering sign.
 mesh('Folded copper canopy',[(-3.16,1.93,-3.44),(-.98,1.93,-3.44),(-.98,1.93,-2.94),(-3.16,1.93,-2.94),(-3.00,2.22,-3.43),(-1.14,2.22,-3.43),(-1.14,2.22,-3.17),(-3.00,2.22,-3.17)],[(0,3,2,1),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5),(4,5,6,7)],'CalmCopper')
 box('Canopy folded lip',(-2.07,1.93,-2.94),(2.18,.035,.025),'CalmCopper',.008)
 # Shaped teapots: hollow turned vessel, rolled lip, lid, tapered hollow spout, formed handle.
 def teapot(p,scale=1,key='CalmSteel',lid=True):
  def make():
   lathe('Teapot vessel',(0,0,0),[(0,0),(.066,0),(.080,.010),(.093,.035),(.101,.080),(.100,.125),(.091,.165),(.073,.187),(.069,.193),(.065,.193),(.065,.183),(.086,.158),(.094,.120),(.095,.080),(.087,.036),(.074,.017),(0,.017)],key)
   if lid:
    lathe('Domed fitted lid',(0,.193,0),[(0,0),(.073,0),(.075,.004),(.071,.009),(.060,.020),(.036,.031),(0,.034)],key)
    lathe('Bakelite lid knob',(0,.225,0),[(0,0),(.012,0),(.015,.008),(.015,.016),(.011,.021),(0,.022)],'CalmBlack',48)
   # Tapered swept spout with inner bore and rolled opening.
   controls=[Vector((.080,.065,0)),Vector((.121,.083,0)),Vector((.155,.128,0)),Vector((.169,.184,0))]
   pts=[];radii=[]
   for k in range(25):
    t=k/24;u=1-t
    pts.append(u*u*u*controls[0]+3*u*u*t*controls[1]+3*u*t*t*controls[2]+t*t*t*controls[3]);radii.append(.026*(1-t)+.014*t)
   rings=len(pts);side_count=rings*48;verts=[]
   for inner in [False,True]:
    for k,pt in enumerate(pts):
     tangent=(pts[min(k+1,rings-1)]-pts[max(k-1,0)]).normalized();u=Vector((0,0,1));w=tangent.cross(u).normalized();r=radii[k]-(.0025 if inner else 0)
     for j in range(48):verts.append(tuple(pt+r*(u*math.cos(j*math.tau/48)+w*math.sin(j*math.tau/48))))
   faces=[]
   for inner in range(2):
    off=inner*side_count
    for k in range(rings-1):
     for j in range(48):
      f=(off+k*48+j,off+k*48+(j+1)%48,off+(k+1)*48+(j+1)%48,off+(k+1)*48+j);faces.append(f if not inner else tuple(reversed(f)))
   for j in range(48):
    a=(rings-1)*48;faces.append((a+j,a+(j+1)%48,side_count+a+(j+1)%48,side_count+a+j))
   mesh('Hollow formed teapot spout',verts,faces,key,True)
   tube('Bakelite teapot handle',[(-.086,.145,0),(-.151,.164,0),(-.178,.128,0),(-.167,.071,0),(-.094,.051,0)],.011,'CalmBlack')
   for y in [.145,.051]:sphere('Handle rivet',(-.090,y,.011),(.006,.006,.003),'CalmBronze')
  root=group('Stacked tea kettle',make,p);root.scale=(scale,)*3
  for o in root.children:
   if o.type=='MESH' and (o.name.startswith('Teapot vessel') or o.name.startswith('Domed fitted lid')):
    mod=o.modifiers.new('Formed metal curvature','SUBSURF');mod.levels=1;mod.render_levels=1
  return root
 box('Counter burner',(-1.58,.946,-3.06),(.32,.032,.29),'CalmIron',.015)
 teapot((-1.58,.962,-3.06),1.12,lid=False)
 teapot((-1.58,1.170,-3.06),.73,'CalmCopper')
 teapot((-2.48,1.66,-3.23),.86,'CalmCream')
 # Exported tea glass is reused by the interactive table without touching its hit areas.
 def tea(p):
  def make():
   lathe('Porcelain tea saucer',(0,0,0),[(0,0),(.037,0),(.049,.004),(.055,.010),(.056,.013),(.053,.016),(.043,.012),(.027,.008),(0,.008)],'CalmPorcelain',96)
   for r in [.048,.051]:lathe('Fine red saucer band',(0,.013,0),[(r-.0006,0),(r+.0006,0),(r+.0006,.0006),(r-.0006,.0006)],'CalmCopper',96)
   profile=[(.020,.010),(.024,.014),(.024,.022),(.022,.032),(.019,.047),(.019,.057),(.021,.073),(.025,.093),(.028,.104),(.028,.107),(.0265,.107),(.0265,.104),(.0235,.093),(.0195,.073),(.0175,.057),(.0175,.047),(.0205,.032),(.0225,.022),(.0215,.016),(.018,.014),(.020,.010)]
   lathe('Thin tulip glass', (0,0,0),profile,'CalmGlass',96)
   lathe('Amber tea',(0,0,0),[(0,.016),(.021,.016),(.0215,.023),(.0195,.033),(.017,.047),(.017,.057),(.019,.073),(.022,.088),(0,.088)],'CalmTea',96)
   tube('Tea spoon',[(.034,.017,-.023),(.035,.017,.020),(.037,.018,.040)],.0013,'CalmSteel')
   sphere('Spoon bowl',(.034,.017,-.024),(.005,.001,.009),'CalmSteel')
  return group('TeaGlass',make,p)
 tea((-2.78,.932,-2.96));tea((-2.57,.932,-3.03))
 # Small porcelain sugar bowl with a separate fitted lid.
 lathe('Sugar bowl',(-2.17,.932,-3.11),[(0,0),(.040,0),(.055,.026),(.056,.052),(.05,.060),(.046,.06),(.046,.016),(0,.016)],'CalmPorcelain')
 lathe('Sugar bowl lid',(-2.17,.993,-3.11),[(0,0),(.055,0),(.053,.006),(.036,.015),(.009,.022),(.010,.033),(0,.036)],'CalmPorcelain')
 counter_parts=set(scene.objects)-counter_before
 service=bpy.data.objects.new('ServiceCounterAssembly',None);scene.collection.objects.link(service)
 for o in counter_parts:
  if o.parent not in counter_parts:o.parent=service
 service.location=xyz((-.55,0,-.70))
 # A detailed compact enamel soba in a different quadrant, facing into the room.
 def stove():
  for x in [-.18,.18]:
   for z in [-.15,.15]:tube('Splayed cast foot',[(x*1.08,.025,z*1.1),(x,.06,z),(.85*x,.15,.85*z)],.018,'CalmIron')
  lathe('Soba enamel barrel',(0,0,0),[(0,.13),(.22,.13),(.233,.15),(.235,.20),(.235,.66),(.232,.72),(.225,.76),(.235,.78),(.235,.80),(0,.80)],'CalmIron',112)
  for y,r in [(.17,.237),(.71,.236),(.785,.242)]:lathe('Rolled stove seam',(0,y,0),[(r-.006,0),(r,.003),(r,.010),(r-.006,.013)],'CalmBronze',112)
  lathe('Cast cooking plate',(0,.80,0),[(0,0),(.232,0),(.236,.006),(.236,.018),(.225,.023),(0,.023)],'CalmIron',112)
  for r in [.09,.14,.19]:lathe('Concentric cooking ring',(0,.824,0),[(r-.001,0),(r+.001,0)],'CalmBlack',112)
  box('Stove door', (0,.46,.228),(.25,.26,.033),'CalmIron',.027)
  box('Recessed ember window',(0,.47,.248),(.176,.152,.008),'CalmBlack',.022)
  for i in range(6):sphere('Visible quiet coal',(rng.uniform(-.065,.065),rng.uniform(.415,.51),.254),(rng.uniform(.012,.026),.018,.006),'CalmEmber')
  for x in [-.066,-.033,0,.033,.066]:tube('Protective fire grille',[(x,.401,.264),(x,.538,.264)],.0033,'CalmIron')
  for y in [.38,.54]:tube('Door hinge',[(-.132,y-.019,.241),(-.132,y+.019,.241)],.007,'CalmIron')
  tube('Wood cool door latch',[(.12,.46,.25),(.155,.46,.272),(.195,.46,.272)],.007,'CalmDarkOak')
  box('Ash drawer',(0,.245,.229),(.23,.067,.028),'CalmIron',.007)
  tube('Ash drawer handle',[(-.048,.245,.249),(-.045,.245,.275),(.045,.245,.275),(.048,.245,.249)],.004,'CalmIron')
  for i in range(5):box('Adjustable air vent',(-.056+i*.028,.30,.244),(.013,.018,.003),'CalmBlack',.002)
  lathe('Flue pipe',(0,.82,-.14),[(.052,0),(.052,2.12),(.046,2.12),(.046,0)],'CalmIron',64)
  tube('Flue wall elbow',[(0,2.94,-.14),(0,3.005,-.20),(0,3.02,-.49)],.052,'CalmIron')
  for y in [1.36,2.09,2.83]:lathe('Flue seam',(0,y,-.14),[(.052,0),(.054,.003),(.054,.012),(.052,.015)],'CalmIron',64)
  teapot((.0,.824,.03),.72,'CalmCopper')
  tube('Poker',[(.34,.025,-.13),(.33,.64,-.15),(.34,.69,-.15),(.37,.68,-.15)],.005,'CalmIron')
 group('CornerSoba',stove,(2.94,0,1.22),-math.pi/2)
 # Window now on the side wall; shallow frame, real sill and restrained curtains.
 for z in [-1.77,-.13]:box('Window oak jamb',(3.435,1.88,z),(.09,1.64,.055),'CalmOak',.006)
 for y in [1.08,2.68]:box('Window oak header',(3.435,y,-.95),(.09,.055,1.70),'CalmOak',.006)
 box('Deep window sill',(3.37,1.07,-.95),(.27,.06,1.86),'CalmMarble',.012)
 mesh('WindowOutside',[(3.59,1.10,-1.74),(3.59,1.10,-.16),(3.59,2.65,-.16),(3.59,2.65,-1.74)],[(0,1,2,3)],'CalmWindow')
 box('Window mullion',(3.42,1.88,-.95),(.06,1.56,.035),'CalmOak',.004)
 box('Window transom',(3.42,2.10,-.95),(.06,.035,1.60),'CalmOak',.004)
 tube('Curtain pole',[(3.30,2.78,-1.98),(3.30,2.78,.08)],.012,'CalmIron')
 for z in [-1.87,-.03]:
  verts=[];faces=[]
  for h in range(13):
   for j in range(25):
    zz=z+(j/24-.5)*.22;xx=3.28+math.sin(j/24*math.tau*3)*.022
    verts.append((xx,1.04+h/12*1.66,zz))
  for h in range(12):
   for j in range(24):a=h*25+j;faces.append((a,a+1,a+26,a+25))
  mesh('Soft linen curtain',verts,faces,'CalmFabric',True)
 # Entry opposite counter, giving the fourth player a deliberate view too.
 box('Entrance oak door',(0,1.12,3.448),(1.02,2.24,.065),'CalmDarkOak',.014)
 for x in [-.54,.54]:box('Door frame',(x,1.16,3.40),(.055,2.33,.10),'CalmOak',.006)
 box('Door frame',(0,2.31,3.40),(1.13,.06,.10),'CalmOak',.006)
 box('Door frosted pane',(0,1.52,3.407),(.70,1.04,.015),'CalmWindow',.009)
 tube('Door handle',[(.35,.98,3.395),(.35,.98,3.35),(.27,.98,3.35)],.009,'CalmBronze')
 def clock():
  box('Pendulum clock cabinet',(0,0,0),(.30,.48,.065),'CalmOak',.018)
  def dial():lathe('Clock porcelain dial',(0,0,0),[(0,0),(.126,0),(.132,.006),(.132,.013),(0,.013)],'CalmPorcelain',96)
  d=group('Clock dial',dial,(0,.07,.04));d.rotation_euler.x=math.pi/2
  for i in range(12):
   a=i*math.tau/12;tube('Clock hour mark',[(math.sin(a)*.105,.07+math.cos(a)*.105,.058),(math.sin(a)*.116,.07+math.cos(a)*.116,.058)],.0017,'CalmIron')
  tube('Clock hour hand',[(0,.07,.06),(-.047,.12,.06)],.003,'CalmIron')
  tube('Clock minute hand',[(0,.07,.062),(.065,.11,.062)],.0018,'CalmIron')
  tube('Pendulum rod',[(0,-.075,.044),(0,-.17,.044)],.0025,'CalmBronze')
  sphere('Pendulum bob',(0,-.175,.045),(.036,.036,.008),'CalmBronze')
 group('WallClock',clock,(-3.42,1.92,.35),math.pi/2)
 # Two small background tables, three chairs total. No overlapping chair/table footprints.
 def cafe_table(p):
  def make():
   lathe('Round oak cafe top',(0,.72,0),[(0,0),(.33,0),(.35,.012),(.35,.038),(.337,.048),(0,.048)],'CalmOak',96)
   lathe('Cast pedestal',(0,0,0),[(0,.02),(.25,.02),(.25,.035),(.19,.055),(.045,.13),(.035,.65),(.08,.72),(0,.72)],'CalmIron',80)
  group('BackgroundTable',make,p)
 def chair(p,angle,plastic=False,key='CalmPlastic'):
  def make():
   if plastic:
    box('Moulded plastic seat',(0,.445,0),(.40,.045,.38),key,.022)
    for x in [-.168,.168]:
     for z in [-.15,.15]:tube('Tapered plastic leg',[(x*1.22,.015,z*1.3),(x,.42,z)],.018,key)
    # A continuous curved shell border and open ventilation slots, recognisable monobloc silhouette.
    tube('Moulded curved back rail',[(-.19,.45,.16),(-.20,.73,.20),(-.16,.87,.23),(0,.90,.25),(.16,.87,.23),(.20,.73,.20),(.19,.45,.16)],.023,key)
    for x in [-.12,-.04,.04,.12]:tube('Ventilated plastic back',[(x,.49,.17),(x,.68,.20),(x,.85,.235)],.013,key)
   else:
    box('Oak cafe seat',(0,.45,0),(.39,.045,.37),'CalmOak',.02)
    for x in [-.16,.16]:
     for z in [-.15,.15]:tube('Oak chair leg',[(x*1.12,.01,z*1.15),(x,.44,z)],.017,'CalmDarkOak')
     tube('Bentwood back upright',[(x,.43,.15),(x,.69,.19),(x*.8,.86,.20)],.019,'CalmDarkOak')
    for y in [.66,.81]:tube('Bentwood back slat',[(-.15,y,.20),(0,y,.23),(.15,y,.20)],.025,'CalmOak')
  group('PlasticCafeChair' if plastic else 'BentwoodCafeChair',make,p,angle)
 cafe_table((-2.57,0,1.92));chair((-2.57,0,2.58),0,True);chair((-3.20,0,1.92),-math.pi/2,False)
 cafe_table((2.55,0,-2.25));chair((2.55,0,-2.91),math.pi,True,'CalmPlasticGreen')
 tea((-2.60,.768,1.93));tea((2.51,.768,-2.20))
 # Soft pendants spread the interest and illumination around the four viewpoints.
 def lamp(p,r=.28):
  def make():
   lathe('Enamel pendant shade',(0,0,0),[(r,0),(r,.012),(r*.93,.029),(r*.70,.095),(r*.32,.18),(r*.20,.195),(r*.17,.22),(0,.22)],'CalmSage',96)
   lathe('Warm shade underside',(0,-.001,0),[(r*.97,0),(r*.90,.023),(r*.68,.087),(r*.30,.172)],'CalmCream',96)
   tube('Pendant flex',[(0,.21,0),(0,3.16-p[1],0)],.004,'CalmIron')
   sphere('PendantBulb',(0,.055,0),(.034,.04,.034),'CalmBulb')
  group('Pendant',make,p)
 lamp((0,2.48,0),.36);lamp((-2.57,2.35,1.92),.20);lamp((2.55,2.35,-2.25),.20)
 # Export one reusable glass separately for the game's existing interactive tea props.
 reusable=tea((0,0,0));reusable.name='TeaGlassAsset'
 bpy.ops.object.select_all(action='DESELECT');reusable.select_set(True)
 for o in reusable.children_recursive:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/calm_tea_glass.glb'),export_format='GLB',use_selection=True,export_apply=True)
 for o in list(reusable.children_recursive)+[reusable]:bpy.data.objects.remove(o,do_unlink=True)
 # Enlarge the shell without stretching furniture or props.
 shell=('Back lime wall','Entry lime wall','Left lime wall','Right lime wall','Window below','Window above','Quiet ceiling','Wide floor board','Sage tongue groove','Wall rail','Window oak','Deep window sill','WindowOutside','Window mullion','Window transom','Curtain pole','Soft linen curtain','Entrance oak door','Door frame','Door frosted pane','Door handle')
 for o in list(scene.objects):
  if o.parent:continue
  if o.name.startswith(shell):
   o.location.x*=1.2;o.location.y*=1.2;o.scale.x*=1.2;o.scale.y*=1.2
  elif o.name.startswith(('BackgroundTable','PlasticCafeChair','BentwoodCafeChair','Pendant','WallClock','TeaGlass')):
   o.location.x*=1.2;o.location.y*=1.2
  elif o.name.startswith('CornerSoba'):
   o.location.x=3.64;o.location.y*=1.2
 for asset,p,yaw in [('cut_glass_ashtray',(-3.17,.768,2.20),.2),('cherry_tespih',(-2.95,.768,2.40),.4),('cut_glass_ashtray',(3.16,.768,-2.72),0),('cherry_tespih',(2.95,.768,-2.58),-.3)]:
  before=set(scene.objects);bpy.ops.import_scene.gltf(filepath=os.path.join(base,'assets/models/table_details',asset+'.glb'))
  imported=set(scene.objects)-before
  root=bpy.data.objects.new('Background_'+asset,None);scene.collection.objects.link(root)
  for o in imported:
   if o.parent not in imported:o.parent=root
  root.location=xyz(p);root.rotation_euler.z=yaw
 bpy.ops.object.select_all(action='DESELECT')
 for o in scene.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=os.path.join(base,'assets/models/environment/kahvehane_calm.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True)
 bpy.data.libraries.write(os.path.join(base,'tools/blender/source/kahvehane_calm.blend'),{scene},fake_user=True)
 print('CALM_ROOM_SAVED',len(scene.objects),'objects')
