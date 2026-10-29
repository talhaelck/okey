extends Node3D
## Four-sided Blender room. Gameplay and seat coordinates stay in the main scene.
const INTERIOR := preload("res://assets/models/environment/kahvehane_balanced.glb")
const FLAG := preload("res://assets/decor/turkish_flag.svg")
const PRINT := preload("res://assets/decor/bosphorus_print.svg")
const NAZAR := preload("res://assets/decor/nazar.svg")
const REFLECTION_ENERGY := 0.24
var _room_lights: Array[Dictionary] = []
var _interior_emissives: Array[Dictionary] = []
var _reflection_probe: ReflectionProbe
var _tv_material: ShaderMaterial

func set_blackout(darkness: float) -> void:
	var mult := clampf(1.0-darkness,0,1)
	for entry in _room_lights:
		if is_instance_valid(entry.light):entry.light.light_energy=entry.energy*mult
	for entry in _interior_emissives:entry.mat.emission_energy_multiplier=entry.base_energy*mult
	if _reflection_probe:_reflection_probe.intensity=REFLECTION_ENERGY*mult
	if _tv_material:_tv_material.set_shader_parameter("power",mult)

func _ready() -> void:
	var interior := INTERIOR.instantiate()
	interior.name="CalmInterior"
	add_child(interior)
	CoffeehouseMaterials.apply_to(interior)
	for mesh: MeshInstance3D in interior.find_children("*","MeshInstance3D",true,false):
		if mesh.name.begins_with("Courtyard distant sky"):
			var sky := ShaderMaterial.new()
			sky.shader=preload("res://assets/shaders/courtyard_dusk.gdshader")
			mesh.material_override=sky
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name.begins_with("CRT_Screen"):
			var tv := ShaderMaterial.new()
			tv.shader=preload("res://assets/shaders/cafe_crt.gdshader")
			_tv_material=tv
			mesh.material_override=tv
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if source==null:continue
			if source.resource_name.begins_with("CalmBulb") or source.resource_name.begins_with("CalmEmber"):
				var m: StandardMaterial3D=source.duplicate()
				mesh.set_surface_override_material(i,m)
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_interior_emissives.append({"mat":m,"base_energy":m.emission_energy_multiplier})
			if source.resource_name.begins_with("CalmGlass"):
				mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decor()
	_background_guests()
	_lighting()
	_reflection_probe=ReflectionProbe.new()
	_reflection_probe.name="RoomReflections"
	_reflection_probe.position=Vector3(0,1.5,0)
	_reflection_probe.size=Vector3(9.9,3.1,10.1)
	_reflection_probe.box_projection=true
	_reflection_probe.interior=true
	_reflection_probe.reflection_mask=2
	_reflection_probe.intensity=REFLECTION_ENERGY
	_reflection_probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
	_reflection_probe.update_mode=ReflectionProbe.UPDATE_ONCE
	add_child(_reflection_probe)
	# Keep the atmosphere gentle; existing focus blur and gameplay camera are untouched.
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		world.environment=world.environment.duplicate()
		world.environment.ambient_light_color=Color("bfc5c2")
		world.environment.ambient_light_energy=.20
		world.environment.volumetric_fog_density=.002
		world.environment.adjustment_saturation=.94
		world.environment.ssao_radius=.16
		world.environment.ssao_intensity=1.35
		world.environment.ssil_intensity=.65
	var haze := FogVolume.new()
	haze.name="WindowLightHaze"
	haze.size=Vector3(3.8,2.4,2.2)
	haze.position=Vector3(3.0,1.25,-.9)
	var fog := FogMaterial.new()
	fog.density=.022
	fog.albedo=Color("d8dfd8")
	fog.edge_fade=.45
	haze.material=fog
	add_child(haze)

func _picture(texture: Texture2D,at: Vector3,size: Vector2,yaw: float) -> void:
	var frame := Node3D.new()
	frame.position=Vector3(at.x*1.38,at.y,at.z*1.416)
	frame.rotation.y=yaw
	add_child(frame)
	var wood := Toon.material(Color("655542"),.82)
	SurfaceStyle.box(frame,Vector3(size.x+.055,size.y+.055,.028),Vector3.ZERO,wood,.006)
	var quad := QuadMesh.new()
	quad.size=size
	var m := StandardMaterial3D.new()
	m.albedo_texture=texture
	m.albedo_color=Color(.85,.83,.77)
	m.roughness=.95
	m.metallic_specular=.1
	SurfaceStyle.part(frame,quad,m,Vector3(0,0,.018))

func _decor() -> void:
	_picture(FLAG,Vector3(0,1.97,-3.435),Vector2(.74,.49),0)
	_picture(PRINT,Vector3(-2.35,1.84,3.435),Vector2(.72,.45),PI)
	# A single small nazar at the entrance rather than a repeated wall pattern.
	var q := QuadMesh.new()
	q.size=Vector2(.095,.12)
	var m := StandardMaterial3D.new()
	m.albedo_texture=NAZAR
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.roughness=.7
	var charm := SurfaceStyle.part(self,q,m,Vector3(.72,2.05,4.84))
	charm.rotation.y=PI

func _lighting() -> void:
	# Practical pools of light: table, two conversation nooks, service counter and window.
	_spot(Vector3(0,2.43,0),Vector3(0,.73,0),Color("ffddb2"),1.12,65,3.8,.18)
	for p in [Vector3(-2.75,2.30,1.35),Vector3(2.95,2.30,1.85)]:
		_spot(p,Vector3(p.x,.73,p.z),Color("ffe1b7"),1.05,56,3.1,.13)
	_spot(Vector3(0,2.5,-3.83),Vector3(0,.76,-3.83),Color("ffdfb7"),.70,58,3.2,.16)
	_spot(Vector3(-4.15,1.88,-2.85),Vector3(-4.42,.93,-2.85),Color("ffe4bf"),.82,65,2.2,.12)
	_spot(Vector3(5.15,2.47,-1.55),Vector3(1.0,.15,.2),Color("d5e2dd"),1.3,28,7.3,.13)
	_room_lights[-1].light.light_volumetric_fog_energy=1.8
	# Daylight on the actual exterior facade, several metres behind the window.
	_spot(Vector3(6.2,5.5,-4.3),Vector3(10.0,2.1,-1.0),Color("c8d6e3"),.85,76,14,.45)
	for p in [Vector3(0,1.65,-1.65),Vector3(1.65,1.65,0),Vector3(0,1.65,1.65),Vector3(-1.65,1.65,0)]:
		_omni(p,Color("e4d9c6"),.15,3.6)
	for z in [-4.62,4.62]:
		for x in [-1.65,1.65]:
			_omni(Vector3(x,2.05,z),Color("ffd5a0"),.40,2.0)
	_omni(Vector3(2.85,2.2,-4.50),Color("b7ced1"),.10,1.1)
	_omni(Vector3(4.40,1.95,.80),Color("ffe6c3"),.80,2.9)
	_spot(Vector3(3.22,1.65,1.12),Vector3(4.15,.43,.27),Color("e2dfcd"),.65,62,2.8,.26)
	_omni(Vector3(3.10,1.25,.20),Color("cfcec0"),.35,2.2)
	for p in [Vector3(-3.25,.75,0),Vector3(0,.75,3.5),Vector3(0,.75,-3.5)]:
		_omni(p,Color("c8c7b6"),.13,3.4)
	for z in [-3.8,3.8]:
		for x in [-2.6,2.6]:
			_omni(Vector3(x,1.15,z),Color("dbcfb8"),.20,3.0)
	_spot(Vector3(-4.40,2.1,.8),Vector3(-4.45,1.3,.4),Color("ffdfb2"),.45,65,2.8,.15)

func _background_guests() -> void:
	for cfg in [["sabri",Vector3(-2.75,0,.558),PI],["temel",Vector3(-1.994,0,1.35),PI/2],["rifki",Vector3(2.95,0,2.642),0.0],["davut",Vector3(-.18,0,-4.52),PI]]:
		var chair := Node3D.new()
		chair.name="BackgroundGuest_"+cfg[0]
		chair.position=cfg[1]
		chair.rotation.y=cfg[2]
		add_child(chair)
		var guest := CafePatron.new()
		guest.position.y=.445
		chair.add_child(guest)
		guest.build(cfg[0])
		guest.turn_head(randf_range(-.12,.12))

func _omni(pos: Vector3,color: Color,energy: float,radius: float) -> void:
	var light := OmniLight3D.new()
	light.position=pos
	light.light_color=color
	light.light_energy=energy
	light.omni_range=radius
	light.light_size=.35
	light.light_volumetric_fog_energy=.10
	add_child(light)
	_room_lights.append({"light":light,"energy":energy})

func _spot(pos: Vector3,target: Vector3,color: Color,energy: float,angle: float,radius: float,size: float) -> void:
	var light := SpotLight3D.new()
	add_child(light)
	light.position=pos
	light.look_at(target,Vector3.FORWARD if absf(pos.x-target.x)+absf(pos.z-target.z)<.01 else Vector3.UP)
	light.light_color=color
	light.light_energy=energy
	light.spot_angle=angle
	light.spot_angle_attenuation=.7
	light.spot_range=radius
	light.spot_attenuation=.7
	light.shadow_enabled=true
	light.shadow_blur=1.7
	light.shadow_bias=.025
	light.shadow_normal_bias=.55
	light.light_size=size
	light.light_volumetric_fog_energy=.14
	_room_lights.append({"light":light,"energy":energy})
