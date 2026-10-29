extends Node3D
## Blender-authored walnut interior. All lights are placed against actual windows and fixtures.

const INTERIOR := preload("res://assets/models/environment/muhabbet_interior.glb")
const FLAG := preload("res://assets/decor/turkish_flag.svg")
const TILE := preload("res://assets/decor/iznik_tile.svg")
const NAZAR := preload("res://assets/decor/nazar.svg")
const KILIM := preload("res://assets/decor/kilim.svg")
const PRINT := preload("res://assets/decor/bosphorus_print.svg")

var _brass := SurfaceStyle.metal(Color("a5804d"),0.42)
var _wood := SurfaceStyle.textured(Color("463326"))


func _ready() -> void:
	var interior := INTERIOR.instantiate()
	add_child(interior)
	for mi: MeshInstance3D in interior.find_children("*","MeshInstance3D",true,false):
		if String(mi.name) in ["Interior_night","Interior_lantern_glass","Interior_bulb"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if String(mi.name) == "Interior_night":
			var glass := ShaderMaterial.new()
			glass.shader = preload("res://assets/shaders/coffeehouse_window.gdshader")
			mi.material_override = glass
	_counter_props()
	_decor()
	_framed_prints()
	_lighting()
	var finish := CanvasLayer.new()
	finish.layer = -5
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://assets/shaders/film_finish.gdshader")
	overlay.material = grade
	finish.add_child(overlay)
	add_child(finish)


func _counter_props() -> void:
	CafeProps.samovar(self,Vector3(0.72,0.92,-2.58))
	for x in [-0.9,-0.45,0.55]:
		CafeProps.tea(self,Vector3(x,0.92,-2.43))
	_coffee(Vector3(1.70,0.92,-2.49))
	for x in [-2.25,2.25]:
		for row in 3:
			for column in 3:
				var root := Node3D.new()
				root.position = Vector3(x+(column-1)*0.32,1.145+row*0.38,-3.0)
				add_child(root)
				if (row+column)%3 == 0:
					CafeProps.tea(root,Vector3.ZERO)
				else:
					var tint := Color("bba47c") if column%2 == 0 else Color("325f58")
					SurfaceStyle.part(root,SurfaceStyle.lathe([Vector2(0,0),Vector2(0.044,0),Vector2(0.049,0.014),Vector2(0.049,0.16),Vector2(0.042,0.18),Vector2(0,0.18)]),Toon.material(tint,0.48))
					SurfaceStyle.part(root,Toon.cylinder(0.050,0.012),_wood,Vector3(0,0.183,0))
					SurfaceStyle.lettering(root,"KAHVE" if row%2 == 0 else "ÇAY",Vector3(0,0.09,0.051),14,0.001,Color("dfcca6"))
	for side in [-1,1]:
		CafeProps.tea(self,Vector3(side*2.55,0.752,1.98))
		CafeProps.tea(self,Vector3(side*2.55+0.13,0.752,2.1))


func _coffee(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var copper := SurfaceStyle.metal(Color("a5693c"),0.34)
	var tray := SurfaceStyle.part(root,Toon.cylinder(0.19,0.006),copper)
	tray.scale.z = 0.6
	var porcelain := Toon.material(Color("bdb08f"),0.3)
	var cup := Node3D.new()
	cup.position = Vector3(-0.075,0.009,0)
	root.add_child(cup)
	SurfaceStyle.part(cup,SurfaceStyle.lathe([Vector2(0,0),Vector2(0.058,0),Vector2(0.06,0.006),Vector2(0,0.008)]),porcelain)
	SurfaceStyle.part(cup,SurfaceStyle.lathe([Vector2(0.026,0.01),Vector2(0.034,0.015),Vector2(0.038,0.065),Vector2(0.034,0.069),Vector2(0.030,0.02),Vector2(0,0.02)]),porcelain)
	SurfaceStyle.ring(cup,0.036,0.002,Vector3(0,0.066,0),Toon.material(Color("2b646a"),0.3))
	SurfaceStyle.part(cup,Toon.cylinder(0.031,0.002),Toon.material(Color("49301e"),0.6),Vector3(0,0.058,0))
	var handle := SurfaceStyle.ring(cup,0.019,0.005,Vector3(-0.044,0.04,0),porcelain)
	handle.rotation.x = PI/2
	var cezve := Node3D.new()
	cezve.position = Vector3(0.08,0.01,0)
	root.add_child(cezve)
	SurfaceStyle.part(cezve,SurfaceStyle.lathe([Vector2(0,0),Vector2(0.046,0),Vector2(0.050,0.018),Vector2(0.031,0.094),Vector2(0.036,0.103),Vector2(0.030,0.107),Vector2(0.026,0.09)]),copper)
	SurfaceStyle.rod(cezve,Vector3(0.027,0.086,0),Vector3(0.18,0.15,0),0.008,copper)
	SurfaceStyle.rod(cezve,Vector3(0.12,0.124,0),Vector3(0.20,0.16,0),0.011,_wood)


func _image(texture: Texture2D, pos: Vector3, size: Vector2, repeats := Vector2.ONE) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(0.74,0.70,0.62)
	m.roughness = 0.92
	m.metallic_specular = 0.15
	m.uv1_scale = Vector3(repeats.x,repeats.y,1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return SurfaceStyle.part(self,quad,m,pos)


func _decor() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia","Times New Roman"])
	font.font_weight = 700
	var letters := TextMesh.new()
	letters.text = "ÇAY OCAĞI"
	letters.font = font
	letters.font_size = 64
	letters.pixel_size = 0.0033
	letters.depth = 0.003
	SurfaceStyle.part(self,letters,Toon.material(Color("cfbd98"),0.82),Vector3(0,2.34,-2.992))
	_clock(Vector3(-1.25,1.89,-3.06))
	SurfaceStyle.box(self,Vector3(1.03,0.71,0.04),Vector3(-1.16,2.70,-3.075),_wood,0.008)
	_image(FLAG,Vector3(-1.16,2.70,-3.05),Vector2(0.96,0.64))
	SurfaceStyle.rod(self,Vector3(2.99,2.78,-3.06),Vector3(2.99,2.63,-3.06),0.003,_brass)
	_image(NAZAR,Vector3(2.99,2.47,-3.045),Vector2(0.22,0.28))
	for side in [-1,1]:
		var border := _image(TILE,Vector3(side*3.395,0.985,0),Vector2(6.35,0.09),Vector2(42,1))
		border.rotation.y = -side*PI/2
	var rug := _image(KILIM,Vector3(0,0.003,2.40),Vector2(1.75,0.85))
	rug.rotation.x = -PI/2
	# A handwritten menu on the front-right wall, lit by the nearby window.
	var board := Node3D.new()
	board.position = Vector3(3.36,1.9,1.70)
	board.rotation.y = -PI/2
	add_child(board)
	SurfaceStyle.box(board,Vector3(0.64,0.90,0.05),Vector3.ZERO,_wood)
	SurfaceStyle.box(board,Vector3(0.57,0.83,0.02),Vector3(0,0,0.031),Toon.material(Color("1b2c27"),0.94))
	SurfaceStyle.lettering(board,"ÇAY OCAĞI",Vector3(0,0.27,0.049),30,0.002,Color("c6b490"))
	SurfaceStyle.lettering(board,"Türk kahvesi\nDemli çay\nAdaçayı\n\nMuhabbet ikramımız",Vector3(0,-0.07,0.049),20,0.002,Color("b2aa93"))


func _lighting() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffca82")
	glow.emission_enabled = true
	glow.emission = Color("ffb65b")
	glow.emission_energy_multiplier = 2.8
	SurfaceStyle.part(self,Toon.cylinder(0.105,0.006),glow,Vector3(0,2.123,0))
	_spot(Vector3(0,2.14,0),Vector3(0,0.72,0),Color("ffdaad"),2.1,66,4.3,0.20)
	# Lights outside the openings cast actual arched-frame shadows across the interior.
	_spot(Vector3(-3.9,2.5,0.10),Vector3(0.3,0.75,-0.2),Color("779da9"),1.6,48,7.0,0.11)
	_spot(Vector3(3.9,2.4,-0.1),Vector3(-0.3,0.85,0.25),Color("8aabae"),1.0,52,7.0,0.12)
	for side in [-1,1]:
		_omni(Vector3(side*3.12,1.75,0),Color("a1b6b6"),0.20,2.8)
	_omni(Vector3(0,1.75,2.1),Color("ccd0c6"),0.30,3.7)
	_omni(Vector3(0,1.22,1.55),Color("e5d6ba"),0.50,2.1)
	for x in [-3.0,3.0]:
		_omni(Vector3(x,2.08,-2.69),Color("ffc286"),0.75,1.55)
	for x in [-2.25,2.25]:
		_omni(Vector3(x,2.45,-2.82),Color("dca56e"),0.26,1.15)
	_omni(Vector3(0,2.00,-1.70),Color("eed1ae"),1.1,4.2)
	_omni(Vector3(0,2.47,-2.82),Color("edcf9f"),0.25,1.7)
	_spot(Vector3(0.72,2.17,-2.30),Vector3(0.72,1.14,-2.58),Color("f4c898"),0.50,36,1.9,0.12)
	_spot(Vector3(-1.16,2.97,-2.44),Vector3(-1.16,2.70,-3.05),Color("eed9b9"),0.45,38,1.35,0.10)


func _framed_prints() -> void:
	for at in [Vector3(1.18,1.80,-3.045),Vector3(-3.36,1.86,-1.78),Vector3(3.36,1.86,1.10)]:
		var frame := Node3D.new()
		frame.position = at
		frame.rotation.y = PI/2 if at.x < -3 else (-PI/2 if at.x > 3 else 0.0)
		add_child(frame)
		SurfaceStyle.box(frame,Vector3(0.73,0.51,0.045),Vector3.ZERO,_wood,0.009)
		SurfaceStyle.box(frame,Vector3(0.68,0.46,0.007),Vector3(0,0,0.026),_brass,0.002)
		var picture := _image(PRINT,Vector3.ZERO,Vector2(0.63,0.42))
		picture.reparent(frame,false)
		picture.position = Vector3(0,0,0.033)


func _clock(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var bezel := SurfaceStyle.part(root,Toon.cylinder(0.215,0.045),_brass)
	bezel.rotation.x = PI/2
	var face := SurfaceStyle.part(root,Toon.cylinder(0.192,0.049),Toon.material(Color("bfb08d"),0.86),Vector3(0,0,0.01))
	face.rotation.x = PI/2
	var ink := Toon.material(Color("342a21"),0.9)
	for i in 12:
		var angle := i*TAU/12.0
		SurfaceStyle.rod(root,Vector3(sin(angle)*0.16,cos(angle)*0.16,0.039),Vector3(sin(angle)*0.178,cos(angle)*0.178,0.039),0.003,ink)
	SurfaceStyle.rod(root,Vector3(0,0,0.044),Vector3(-0.055,0.09,0.044),0.005,ink)
	SurfaceStyle.rod(root,Vector3(0,0,0.045),Vector3(0.13,0.026,0.045),0.003,ink)


func _omni(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.light_size = 0.22
	light.light_volumetric_fog_energy = 0.3
	add_child(light)


func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, angle: float, radius: float, size: float) -> void:
	var light := SpotLight3D.new()
	add_child(light)
	light.position = pos
	light.look_at(target,Vector3.FORWARD if absf(pos.x-target.x)+absf(pos.z-target.z)<0.01 else Vector3.UP)
	light.light_color = color
	light.light_energy = energy
	light.spot_angle = angle
	light.spot_range = radius
	light.spot_attenuation = 0.7
	light.shadow_enabled = true
	light.shadow_blur = 2.5
	light.light_size = size
	light.light_volumetric_fog_energy = 0.45
