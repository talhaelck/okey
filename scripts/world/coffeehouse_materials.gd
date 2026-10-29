class_name CoffeehouseMaterials
extends RefCounted
## Physical materials for the room and furniture. Triplanar sampling is measured in metres.
const MAPS := "res://assets/textures/coffeehouse_pbr/"
static var _materials: Dictionary = {}

static func apply_to(root: Node3D) -> void:
 for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:
   continue
  for surface in mesh.mesh.get_surface_count():
   var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
   if source==null:
    continue
   var family := source.resource_name.get_slice(".",0)
   if family=="CafeDado":
    if not _materials.has("dado"):
     var dado := ShaderMaterial.new()
     dado.shader=preload("res://assets/shaders/cafe_dado.gdshader")
     dado.set_shader_parameter("ceramic_color",Color("a4ad9c"))
     dado.set_shader_parameter("motif_color",Color("6f8474"))
     _materials["dado"]=dado
    mesh.set_surface_override_material(surface,_materials["dado"])
    mesh.layers |= 2
    continue
   if family=="CalmPlaster":
    if not _materials.has("quiet_plaster"):
     var plaster := ShaderMaterial.new()
     plaster.shader=preload("res://assets/shaders/cafe_plaster.gdshader")
     plaster.set_shader_parameter("surface_scan",preload("res://assets/textures/worn_plaster_wall/diffuse.jpg"))
     plaster.set_shader_parameter("plaster_color",Color("b1a792"))
     _materials["quiet_plaster"]=plaster
    mesh.set_surface_override_material(surface,_materials["quiet_plaster"])
    mesh.layers |= 2
    continue
   if family in ["CafePanelWood","CafePanelInset","CafeTableWalnut","CafeWalnut","CafeWalnutEdge","CafeRackWood","CalmOak","CalmDarkOak","CalmFloor","table_walnut","table_walnut_dark","table_rack_wood"]:
    mesh.set_surface_override_material(surface,_quiet_wood(family))
    mesh.layers |= 2
    continue
   if family in ["CalmGlass","CafeWindowGlass"]:
    var glass := ShaderMaterial.new()
    glass.shader=preload("res://assets/shaders/thin_glass.gdshader")
    mesh.set_surface_override_material(surface,glass)
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    continue
   var material := material_for(source)
   if material!=null:
    mesh.set_surface_override_material(surface,material)
    # Room reflections belong to hard surfaces; character skin uses its own shading.
    mesh.layers |= 2

static func _quiet_wood(family: String) -> ShaderMaterial:
 var key := "quiet_"+family
 if _materials.has(key):return _materials[key]
 var m := ShaderMaterial.new()
 m.shader=preload("res://assets/shaders/cafe_walnut.gdshader")
 m.set_shader_parameter("grain_texture",preload("res://assets/textures/wood_table_worn/diffuse.jpg"))
 m.set_shader_parameter("rough_texture",load(MAPS+"worn_wood_roughness.png"))
 var color := Color("765a40")
 var scale := Vector3(.60,.85,.60)
 if family in ["CafeWalnutEdge","CalmDarkOak","table_walnut_dark"]:color=Color("554633")
 if family=="CalmFloor":
  color=Color("78634d")
  scale=Vector3(.35,.35,.70)
 if family=="CafeRackWood":
  color=Color("876b4d")
  scale=Vector3(.8,2.5,2.5)
 if family=="table_rack_wood":
  color=Color("806044")
  scale=Vector3(1.2,3.2,2.5)
 if family=="CafeTableWalnut":color=Color("79583d")
 if family=="CafePanelWood":color=Color("9b8668")
 if family=="CafePanelInset":color=Color("87785f")
 m.set_shader_parameter("wood_color",color)
 m.set_shader_parameter("grain_scale",scale)
 m.set_shader_parameter("surface_roughness",.66 if family=="CafeRackWood" else .76)
 _materials[key]=m
 return m

static func _pbr(family: String,scale: float,metallic: float,normal_strength: float) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_texture = load(MAPS+family+"_albedo.png")
 m.roughness_texture = load(MAPS+family+"_roughness.png")
 m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
 m.roughness = 1.0
 m.normal_enabled = true
 m.normal_texture = load(MAPS+family+"_normal.png")
 m.normal_scale = normal_strength
 m.metallic = metallic
 m.metallic_specular = 0.30
 m.uv1_triplanar = true
 m.uv1_world_triplanar = true
 m.uv1_scale = Vector3.ONE*scale
 m.uv1_triplanar_sharpness = 5.0
 m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return m

static func _wood(tint: Color,scale: Vector3) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_texture = preload("res://assets/textures/wood_table_worn/diffuse.jpg")
 m.albedo_color = tint
 m.normal_enabled = true
 m.normal_texture = preload("res://assets/textures/wood_table_worn/nor_gl.jpg")
 m.normal_scale = 0.10
 m.roughness_texture = load(MAPS+"worn_wood_roughness.png")
 m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
 m.roughness = 1.0
 m.metallic_specular = 0.24
 m.uv1_triplanar = true
 m.uv1_world_triplanar = true
 m.uv1_triplanar_sharpness = 6.0
 m.uv1_scale = scale
 m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 return m

static func material_for(source: StandardMaterial3D) -> StandardMaterial3D:
 var id := source.resource_name.get_slice(".",0)
 if _materials.has(id):
  return _materials[id]
 var m: StandardMaterial3D
 match id:
  "CourtyardGlass":
   m = source.duplicate()
   m.albedo_color = Color("7d735b")
   m.emission_enabled = true
   m.emission = Color("d3b37c")
   m.emission_energy_multiplier = .25
   m.roughness = .42
  "CafeLinen":
   m = _pbr("lime_plaster",8.0,0,.12)
   m.albedo_texture = null
   m.albedo_color = Color("a7a58f")
   m.metallic_specular = .08
  "CafeEnamel":
   m = _pbr("cast_iron",5.0,.22,.07)
   m.albedo_texture = null
   m.albedo_color = Color("56634f")
   m.roughness_texture = null
   m.roughness = .38
  "CafeStoveIron", "CafeStoveEdge", "CafeHearth":
   m = _pbr("cast_iron",3.0,.35,.18)
   m.albedo_texture = null
   m.albedo_color = source.albedo_color
   m.roughness_texture = null
   m.roughness = .52 if id=="CafeStoveEdge" else .78
  "CalmSage":
   m = source.duplicate()
   m.albedo_color = Color("3e493e")
   m.roughness = .64
  "CalmCeiling":
   m = _pbr("lime_plaster",1.2,0,.12)
   m.albedo_texture = null
   m.albedo_color = Color("8f8775")
  "CafeWarmLinen":
   m = _pbr("lime_plaster",8.0,0,.15)
   m.albedo_texture = null
   m.albedo_color = Color("b9b2a0")
  "CafeBrick":
   m = _pbr("lime_plaster",3.8,0,.38)
   m.albedo_texture = null
   m.albedo_color = Color("825b47")
   m.roughness = .98
   m.metallic_specular = .08
  "CafeMortar":
   m = _pbr("lime_plaster",3.5,0,.30)
   m.albedo_texture = null
   m.albedo_color = Color("827d6c")
  "CafeSteel", "CalmSteel":
   m = _pbr("cast_iron",6.0,.72,.08)
   m.albedo_texture = null
   m.albedo_color = Color("9d9f96")
   m.roughness_texture = null
   m.roughness = .44
   m.anisotropy_enabled = true
   m.anisotropy = .30
  "CafeCoat":
   m = _pbr("lime_plaster",6.0,0,.18)
   m.albedo_texture = null
   m.albedo_color = Color("655f4e")
   m.metallic_specular = .10
  "CafeBottle":
   m = source.duplicate()
   m.roughness = .20
   m.metallic_specular = .32
  "CafeBakelite":
   m = _pbr("cast_iron",4.0,0,.08)
   m.albedo_texture = null
   m.albedo_color = Color("363b37")
   m.roughness_texture = null
   m.roughness = .56
  "CalmPlaster":
   m = _pbr("lime_plaster",0.72,0.0,0.18)
   m.albedo_texture = null
   m.albedo_color = Color("b8af99")
   m.normal_scale = .08
   m.metallic_specular = 0.12
  "CalmOak":
   m = _wood(Color("e6cfab"),Vector3(.38,.60,.38))
  "CalmDarkOak":
   m = _wood(Color("c2b49e"),Vector3(.45,.65,.45))
  "CalmFloor":
   m = _wood(Color("e9d6b4"),Vector3(.35,.35,.70))
  "CalmIron":
   m = _pbr("cast_iron",2.0,0.28,0.30)
   m.albedo_texture = null
   m.albedo_color = Color("343935")
   m.normal_scale = .08
   m.roughness_texture = null
   m.roughness = .85
  "CalmCopper":
   m = _pbr("hammered_copper",1.6,0.65,0.12)
   m.albedo_texture = null
   m.albedo_color = Color("9d6845")
   m.roughness = .80
  "CalmMarble":
   m = _pbr("honed_marble",.8,0.0,.10)
   m.metallic_specular = .2
  "CalmGlass":
   m = source.duplicate()
   m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   m.albedo_color = Color(.82,.90,.88,.18)
   m.roughness = .14
   m.cull_mode = BaseMaterial3D.CULL_DISABLED
  "CalmTea":
   m = source.duplicate()
   m.roughness = .45
   m.metallic_specular = .08
  "Copper":
   m = _pbr("hammered_copper",1.5,0.72,0.18)
  "Brass", "table_brass":
   m = _pbr("hammered_copper",1.8,0.64,0.08)
   m.albedo_texture = null
   m.albedo_color = Color("7d715b")
  "DarkMetal", "table_dark_iron":
   m = _pbr("cast_iron",2.0,0.38,0.55)
  "Marble":
   m = _pbr("honed_marble",1.1,0.0,0.15)
   m.metallic_specular = 0.22
  "Plaster":
   m = _pbr("lime_plaster",0.9,0.0,0.45)
   m.metallic_specular = 0.12
  "Walnut":
   m = _wood(Color("f0dec7"),Vector3(0.42,0.65,0.42))
  "Mahogany":
   m = _wood(Color("e6c6ac"),Vector3(0.46,0.75,0.46))
  "CarvedWood":
   m = _wood(Color("cdb89b"),Vector3(0.55,0.8,0.55))
  "FloorWood":
   m = _wood(Color("d0b49a"),Vector3(0.48,0.48,0.95))
   m.normal_scale = 0.12
  "Ceiling":
   m = _pbr("lime_plaster",0.6,0.0,0.20)
   m.albedo_color = Color("766959")
  "EnamelGreen":
   m = _pbr("cast_iron",2.0,0.12,0.12)
   m.albedo_texture = null
   m.albedo_color = Color("274439")
   m.roughness_texture = null
   m.roughness = 0.48
  "TileBlue":
   m = source.duplicate()
   m.albedo_color = Color("48656c")
   m.roughness = 0.52
   m.metallic_specular = 0.22
  "Velvet":
   m = source.duplicate()
   m.albedo_color = Color("74333a")
   m.roughness = 0.94
   m.metallic_specular = 0.12
  "table_walnut", "table_walnut_dark", "table_rack_wood":
   m = _wood(Color("bcb9ae"),Vector3(.65,.65,.65))
   m.cull_mode = source.cull_mode
   if id=="table_walnut_dark":m.albedo_color=Color("c4b295")
   m.roughness_texture = null
   m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
   m.roughness = .88
   m.metallic_specular = .14
   m.normal_scale = .06
  "table_leather_burgundy":
   m = source.duplicate()
   m.roughness = 0.82
   m.metallic_specular = 0.20
   m.normal_enabled = true
   m.normal_texture = load(MAPS+"cast_iron_normal.png")
   m.normal_scale = 0.16
 if m!=null:
  # Imported furniture contains intentionally double-sided panels, including rack backs.
  m.cull_mode = source.cull_mode
  m.resource_name = "Coffeehouse_"+id
  _materials[id] = m
 return m
