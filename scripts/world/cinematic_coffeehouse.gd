extends Node3D
## Authentic 3-bay Turkish Kahvehane (Kıraathane) interior.
## Left Bay: Çay Ocağı with Copper Hood, Marble Counter & Kazanlı Semaver.
## Center Bay: Framed Turkish Flag, "DOSTLUK · MUHABBET · OKEY" plaque, Pendulum Clock & Cast-Iron Stove.
## Right Bay: Arched Galata/Bosphorus Window with Burgundy Velvet Drapes & Corner Tüplü TV.

const INTERIOR := preload("res://assets/models/environment/muhabbet_interior.glb")
const FLAG := preload("res://assets/decor/turkish_flag.svg")
const TILE := preload("res://assets/decor/iznik_tile.svg")
const NAZAR := preload("res://assets/decor/nazar.svg")
const KILIM := preload("res://assets/decor/kilim.svg")
const PRINT := preload("res://assets/decor/bosphorus_print.svg")

var _brass := SurfaceStyle.metal(Color("a5804d"), 0.42)
var _wood := SurfaceStyle.textured(Color("463326"))
var _room_lights: Array[Dictionary] = []
var _bulb_mat: StandardMaterial3D


func set_blackout(darkness: float) -> void:
	var mult := clampf(1.0 - darkness, 0.0, 1.0)
	for entry in _room_lights:
		var l: Light3D = entry["light"]
		var base_e: float = entry["energy"]
		if is_instance_valid(l):
			l.light_energy = base_e * mult
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = 3.2 * mult


func _ready() -> void:
	var interior := INTERIOR.instantiate()
	add_child(interior)
	for mi: MeshInstance3D in interior.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in ["Interior_night", "Interior_lantern_glass", "Interior_bulb", "Interior_crt_screen"]:
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
	# Steaming ince belli tea glasses & Turkish coffee set on the Afyon marble Çay Ocağı counter (x = -2.20)
	for x in [-2.88, -2.58, -2.32]:
		CafeProps.tea(self, Vector3(x, 0.958, -2.42))
	_coffee(Vector3(-1.98, 0.958, -2.46))

	# Tea & coffee canisters on the two walnut shelves inside the Çay Ocağı alcove (y = 1.24 and 1.64)
	for row in 2:
		for column in 4:
			var root := Node3D.new()
			root.position = Vector3(-2.74 + column * 0.36, 1.24 + row * 0.40, -2.92)
			add_child(root)
			if (row + column) % 3 == 0:
				CafeProps.tea(root, Vector3.ZERO)
			else:
				var tint := Color("bba47c") if column % 2 == 0 else Color("2b5850")
				SurfaceStyle.part(
					root,
					SurfaceStyle.lathe([
						Vector2(0, 0),
						Vector2(0.044, 0),
						Vector2(0.049, 0.014),
						Vector2(0.049, 0.155),
						Vector2(0.042, 0.175),
						Vector2(0, 0.175),
					]),
					Toon.material(tint, 0.46)
				)
				SurfaceStyle.part(root, Toon.cylinder(0.050, 0.012), _wood, Vector3(0, 0.178, 0))
				SurfaceStyle.lettering(
					root,
					"KAHVE" if (row + column) % 2 == 0 else "ÇAY",
					Vector3(0, 0.088, 0.051),
					14,
					0.001,
					Color("dfcca6")
				)

	# Steaming tea glasses on the side Kahvehane tables next to the open Tavla boards
	for side in [-1, 1]:
		CafeProps.tea(self, Vector3(side * 2.35 - 0.25, 0.758, -1.55))
		CafeProps.tea(self, Vector3(side * 2.35 + 0.26, 0.758, -1.28))
		CafeProps.tea(self, Vector3(side * 2.48 - 0.14, 0.758, 1.88))
		CafeProps.tea(self, Vector3(side * 2.48 + 0.16, 0.758, 2.04))


func _coffee(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var copper := SurfaceStyle.metal(Color("a5693c"), 0.34)
	var tray := SurfaceStyle.part(root, Toon.cylinder(0.18, 0.006), copper)
	tray.scale.z = 0.62
	var porcelain := Toon.material(Color("bdb08f"), 0.3)
	var cup := Node3D.new()
	cup.position = Vector3(-0.07, 0.009, 0)
	root.add_child(cup)
	SurfaceStyle.part(cup, SurfaceStyle.lathe([Vector2(0, 0), Vector2(0.056, 0), Vector2(0.058, 0.006), Vector2(0, 0.008)]), porcelain)
	SurfaceStyle.part(cup, SurfaceStyle.lathe([Vector2(0.025, 0.01), Vector2(0.033, 0.015), Vector2(0.037, 0.064), Vector2(0.033, 0.068), Vector2(0.029, 0.02), Vector2(0, 0.02)]), porcelain)
	SurfaceStyle.ring(cup, 0.035, 0.002, Vector3(0, 0.065, 0), Toon.material(Color("2b646a"), 0.3))
	SurfaceStyle.part(cup, Toon.cylinder(0.030, 0.002), Toon.material(Color("49301e"), 0.6), Vector3(0, 0.057, 0))
	var handle := SurfaceStyle.ring(cup, 0.018, 0.005, Vector3(-0.042, 0.039, 0), porcelain)
	handle.rotation.x = PI / 2
	var cezve := Node3D.new()
	cezve.position = Vector3(0.075, 0.01, 0)
	root.add_child(cezve)
	SurfaceStyle.part(cezve, SurfaceStyle.lathe([Vector2(0, 0), Vector2(0.044, 0), Vector2(0.048, 0.018), Vector2(0.030, 0.092), Vector2(0.035, 0.101), Vector2(0.029, 0.105), Vector2(0.025, 0.088)]), copper)
	SurfaceStyle.rod(cezve, Vector3(0.026, 0.084, 0), Vector3(0.17, 0.145, 0), 0.008, copper)
	SurfaceStyle.rod(cezve, Vector3(0.115, 0.12, 0), Vector3(0.19, 0.155, 0), 0.011, _wood)


func _image(texture: Texture2D, pos: Vector3, size: Vector2, repeats := Vector2.ONE) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(0.78, 0.73, 0.65)
	m.roughness = 0.90
	m.metallic_specular = 0.15
	m.uv1_scale = Vector3(repeats.x, repeats.y, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return SurfaceStyle.part(self, quad, m, pos)


func _decor() -> void:
	# 1. "ÇAY OCAĞI" brass/cream lettering directly on the hammered copper hood apron in the Left Bay
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	font.font_weight = 700
	var letters := TextMesh.new()
	letters.text = "ÇAY OCAĞI"
	letters.font = font
	letters.font_size = 54
	letters.pixel_size = 0.0028
	letters.depth = 0.004
	SurfaceStyle.part(self, letters, Toon.material(Color("ebd6a7"), 0.45), Vector3(-2.20, 2.08, -2.216))

	# 2. Center Bay Wall of Honor: Wood-framed Turkish Flag at top center (0.0, 2.58, -3.06)
	SurfaceStyle.box(self, Vector3(0.96, 0.66, 0.04), Vector3(0.0, 2.58, -3.07), _wood, 0.008)
	SurfaceStyle.box(self, Vector3(0.90, 0.60, 0.012), Vector3(0.0, 2.58, -3.052), _brass, 0.003)
	_image(FLAG, Vector3(0.0, 2.58, -3.042), Vector2(0.86, 0.56))

	# 3. Center Bay Kıraathane Plaque below the flag: "DOSTLUK · MUHABBET · OKEY"
	var motto := Node3D.new()
	motto.position = Vector3(0.0, 1.92, -3.06)
	add_child(motto)
	SurfaceStyle.box(motto, Vector3(0.94, 0.40, 0.038), Vector3.ZERO, _wood, 0.008)
	SurfaceStyle.box(motto, Vector3(0.88, 0.34, 0.014), Vector3(0, 0, 0.020), Toon.material(Color("5c1818"), 0.85))
	SurfaceStyle.lettering(motto, "DOSTLUK · MUHABBET\nOKEY", Vector3(0, 0.015, 0.033), 26, 0.0024, Color("f0dbb0"))

	# 4. Pendulum Wall Clock Dial & Hands mounted on the walnut clock case at (-0.72, 2.04, -2.99)
	_clock(Vector3(-0.72, 2.04, -2.995))

	# 5. Nazar Boncuğu hanging on the left-center pilaster
	SurfaceStyle.rod(self, Vector3(-1.12, 2.74, -2.94), Vector3(-1.12, 2.59, -2.94), 0.003, _brass)
	_image(NAZAR, Vector3(-1.12, 2.44, -2.93), Vector2(0.20, 0.25))

	# 6. İznik Tile Frieze along both side walls above the walnut lambri wainscoting
	for side in [-1, 1]:
		var border := _image(TILE, Vector3(side * 3.34, 1.11, 0), Vector2(6.30, 0.09), Vector2(42, 1))
		border.rotation.y = -side * PI / 2

	# 7. Anatolian Kilim rugs on the floorboards
	var center_rug := _image(KILIM, Vector3(0, 0.003, 0.0), Vector2(2.65, 2.35))
	center_rug.rotation.x = -PI / 2
	var entry_rug := _image(KILIM, Vector3(0, 0.003, 2.42), Vector2(1.75, 0.85))
	entry_rug.rotation.x = -PI / 2

	# 8. Chalkboard Price Menu on the front-right side wall
	var board := Node3D.new()
	board.position = Vector3(3.32, 1.88, 0.78)
	board.rotation.y = -PI / 2
	add_child(board)
	SurfaceStyle.box(board, Vector3(0.64, 0.88, 0.045), Vector3.ZERO, _wood)
	SurfaceStyle.box(board, Vector3(0.57, 0.81, 0.018), Vector3(0, 0, 0.028), Toon.material(Color("192b24"), 0.92))
	SurfaceStyle.lettering(board, "KIRAATHANE TARİFE", Vector3(0, 0.27, 0.044), 24, 0.0018, Color("dec696"))
	SurfaceStyle.lettering(
		board,
		"Tavşan Kanı Çay .... 10₺\nTürk Kahvesi ....... 25₺\nOralet / Ihlamur ... 15₺\n\nMasa & Muhabbet İkramımız",
		Vector3(0, -0.06, 0.044),
		17,
		0.0016,
		Color("c9c0a8")
	)


func _lighting() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffc678")
	glow.emission_enabled = true
	glow.emission = Color("ffad48")
	glow.emission_energy_multiplier = 1.9
	_bulb_mat = glow
	SurfaceStyle.part(self, Toon.cylinder(0.115, 0.008), glow, Vector3(0, 1.855, 0))

	# 1. Main Okey Table warm amber pendant spotlight
	_spot(Vector3(0, 1.84, 0.08), Vector3(0, 0.72, -0.05), Color("ffca85"), 1.48, 66, 4.6, 0.05)

	# 2. Golden-hour / Bosphorus evening light streaming through the Right Bay Arched Window (x = 2.15)
	_spot(Vector3(2.15, 2.18, -3.55), Vector3(0.35, 0.82, -0.25), Color("ff9e58"), 1.15, 48, 6.5, 0.08)

	# 3. Warm pendant pools over the two background Kahvehane & Tavla tables
	for side in [-1, 1]:
		_spot(Vector3(side * 2.35, 1.84, -1.42), Vector3(side * 2.35, 0.72, -1.42), Color("ffb866"), 0.95, 56, 3.2, 0.06)
		_omni(Vector3(side * 2.75, 1.75, 0.0), Color("d8b68c"), 0.24, 3.2)

	# 4. Warm brass wall sconces on the 4 back-wall pilasters
	for sx in [-3.28, -1.12, 1.12, 3.28]:
		_omni(Vector3(sx, 2.08, -2.58), Color("ffbe76"), 0.25, 1.8)

	# 5. Çay Ocağı counter & copper Semaver warm spotlight (Left Bay)
	_spot(Vector3(-2.15, 1.92, -2.25), Vector3(-2.15, 0.95, -2.52), Color("ffbf78"), 0.72, 52, 2.5, 0.08)

	# 6. Cast-Iron Kahvehane Stove glowing fire-grate ember light (Center-Right)
	_omni(Vector3(0.74, 0.46, -2.35), Color("ff7b32"), 0.52, 2.0)

	# 7. Center Wall of Honor (Turkish Flag & Motto Plaque) warm accent light
	_spot(Vector3(0.0, 2.95, -2.25), Vector3(0.0, 2.25, -3.05), Color("f4d4aa"), 0.55, 46, 2.4, 0.08)

	# 8. Soft fill lights for foreground & patrons
	_omni(Vector3(0, 1.95, -1.65), Color("eec99a"), 0.88, 4.2)
	_omni(Vector3(0, 1.55, 1.85), Color("e4cca8"), 0.44, 3.4)


func _framed_prints() -> void:
	# Framed vintage Bosphorus prints on the left and right side walls between pilasters
	for at in [Vector3(-3.32, 1.92, -0.76), Vector3(-3.32, 1.92, 0.78), Vector3(3.32, 1.92, -0.76)]:
		var frame := Node3D.new()
		frame.position = at
		frame.rotation.y = PI / 2 if at.x < 0.0 else -PI / 2
		add_child(frame)
		SurfaceStyle.box(frame, Vector3(0.74, 0.52, 0.042), Vector3.ZERO, _wood, 0.009)
		SurfaceStyle.box(frame, Vector3(0.68, 0.46, 0.008), Vector3(0, 0, 0.024), _brass, 0.002)
		var picture := _image(PRINT, Vector3.ZERO, Vector2(0.63, 0.42))
		picture.reparent(frame, false)
		picture.position = Vector3(0, 0, 0.031)


func _clock(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var bezel := SurfaceStyle.part(root, Toon.cylinder(0.145, 0.028), _brass)
	bezel.rotation.x = PI / 2
	var face := SurfaceStyle.part(root, Toon.cylinder(0.128, 0.032), Toon.material(Color("dfd1b0"), 0.82), Vector3(0, 0, 0.006))
	face.rotation.x = PI / 2
	var ink := Toon.material(Color("2b1f16"), 0.9)
	for i in 12:
		var angle := i * TAU / 12.0
		SurfaceStyle.rod(root, Vector3(sin(angle) * 0.102, cos(angle) * 0.102, 0.025), Vector3(sin(angle) * 0.118, cos(angle) * 0.118, 0.025), 0.0025, ink)
	SurfaceStyle.rod(root, Vector3(0, 0, 0.028), Vector3(-0.042, 0.065, 0.028), 0.004, ink)
	SurfaceStyle.rod(root, Vector3(0, 0, 0.029), Vector3(0.088, 0.020, 0.029), 0.0025, ink)


func _omni(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.light_size = 0.22
	light.light_volumetric_fog_energy = 0.28
	add_child(light)
	_room_lights.append({"light": light, "energy": energy})


func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, angle: float, radius: float, size: float) -> void:
	var light := SpotLight3D.new()
	add_child(light)
	light.position = pos
	light.look_at(target, Vector3.FORWARD if absf(pos.x - target.x) + absf(pos.z - target.z) < 0.01 else Vector3.UP)
	light.light_color = color
	light.light_energy = energy
	light.spot_angle = angle
	light.spot_range = radius
	light.spot_attenuation = 0.7
	light.shadow_enabled = true
	light.shadow_blur = 2.5
	light.light_size = size
	light.light_volumetric_fog_energy = 0.42
	_room_lights.append({"light": light, "energy": energy})
