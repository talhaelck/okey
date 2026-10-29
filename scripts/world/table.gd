class_name Table
extends Node3D
## Blender-authored walnut okey table with inset felt, 4 discard zones, center draw pile,
## and fully interactive kahvehane props (tea glasses, coffee, leblebi bowl, ashtray, tespih, sunglasses, magnifier, yazboz).

const TOP := 0.75 # height of the felt surface
const SIDE_TOP := 0.68 # height of the kahvehane side tea tables (yan sehpalar)
const SIZE := 1.3
const RIM := 0.07
const WOOD := Color(0.48, 0.27, 0.16)
const WOOD_DARK := Color(0.34, 0.19, 0.11)
const FELT := Color(0.16, 0.48, 0.3)

## 4 corner discard positions in Table local space:
## Seat 0 (+Z) throws to Front-Right; Seat 1 (+X) to Back-Right; Seat 2 (-Z) to Back-Left; Seat 3 (-X) to Front-Left.
const DISCARD_SPOTS := [
	Vector3(0.34, TOP, 0.24),   # Seat 0's discard (Front-Right)
	Vector3(0.34, TOP, -0.24),  # Seat 1's discard (Back-Right)
	Vector3(-0.34, TOP, -0.24), # Seat 2's discard (Back-Left)
	Vector3(-0.34, TOP, 0.24),  # Seat 3's discard (Front-Left)
]

var _pile := Node3D.new()
var _loose := Node3D.new()
var _discards: Array[Array] = [[], [], [], []]
var _draw_tiles: Array[Tile] = []
var indicator_tile: Tile
var indicator_value := Vector2i(0, 1)
var okey_value := Vector2i(0, 2)

var _discard_glow_pad: MeshInstance3D
var _discard_glow_mat := StandardMaterial3D.new()
var _draw_glow_pad: MeshInstance3D
var _draw_glow_mat := StandardMaterial3D.new()
var _left_draw_pad: MeshInstance3D
var _show_discard_guide := true
var _show_draw_guide := false

var props: Array[Dictionary] = []
var _hovered_prop_id := ""
var _prop_highlight := StandardMaterial3D.new()
var _contested_prop_id := ""
var _contest_highlight := StandardMaterial3D.new()

var _vapors: Array[Dictionary] = []
var _smoke_puffs: Array[Dictionary] = []
var _puddles: Array[MeshInstance3D] = []
var _time := 0.0
var smoke_active_timer := 0.0
var glasses_worn := false
var _baize_mat: ShaderMaterial


func set_felt_style(cloth_name: String) -> void:
	if _baize_mat == null:
		return
	var c := Color("123f26") # Authentic deep Anatolian emerald green
	if cloth_name == "Bordo":
		c = Color("4c1418") # Authentic rich kahvehane burgundy
	elif cloth_name == "Mavi":
		c = Color("142b4a") # Royal midnight blue
	_baize_mat.set_shader_parameter("felt_color", c)


func _ready() -> void:
	var felt := SIZE - RIM * 2.0
	var table_glb: Node3D = load("res://assets/models/table_details/okey_table.glb").instantiate()
	table_glb.name = "OkeyTableModel"
	add_child(table_glb)

	_baize_mat = ShaderMaterial.new()
	_baize_mat.shader = preload("res://assets/shaders/okey_felt.gdshader")
	SurfaceStyle.box(self, Vector3(felt, 0.012, felt), Vector3(0, TOP - 0.005, 0), _baize_mat, 0.006)
	set_felt_style(CafePreferences.cloth)

	_prop_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_prop_highlight.albedo_color = Color(0.98, 0.82, 0.42)
	_prop_highlight.cull_mode = BaseMaterial3D.CULL_FRONT
	_prop_highlight.grow = true
	_prop_highlight.grow_amount = 0.0025

	_contest_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_contest_highlight.albedo_color = Color(1.0, 0.45, 0.12)
	_contest_highlight.cull_mode = BaseMaterial3D.CULL_FRONT
	_contest_highlight.grow = true
	_contest_highlight.grow_amount = 0.0042

	_build_side_tables()
	_build_discard_markers()
	_build_interactive_props()

	add_child(_pile)
	add_child(_loose)


func _build_side_tables() -> void:
	## Two authentic Turkish coffeehouse wooden side tables (Yan Sehpalar) beside Seat 0
	## so the player's tea, coffee, tespih, glasses, magnifier and yazboz sit next to them instead of cluttering the rack!
	var walnut := SurfaceStyle.textured(Color("4a2a18"))
	var walnut_dark := SurfaceStyle.textured(Color("2e190d"))
	var brass := SurfaceStyle.metal(Color("c89b42"), 0.32)
	var cloth := SurfaceStyle.textured(Color("7a231d"), SurfaceStyle.Kind.FABRIC)

	for side in [-1, 1]:
		var sehpa := Node3D.new()
		sehpa.name = "YanSehpaLeft" if side == -1 else "YanSehpaRight"
		sehpa.position = Vector3(side * 0.78, 0.0, 0.72)
		sehpa.rotation.y = side * -0.14
		add_child(sehpa)

		# Tabletop with carved dark rim and warm Anatolian runner cloth
		SurfaceStyle.box(sehpa, Vector3(0.36, 0.026, 0.42), Vector3(0, SIDE_TOP - 0.013, 0), walnut_dark, 0.005)
		SurfaceStyle.box(sehpa, Vector3(0.33, 0.008, 0.39), Vector3(0, SIDE_TOP - 0.002, 0), walnut, 0.003)
		SurfaceStyle.box(sehpa, Vector3(0.24, 0.004, 0.30), Vector3(0, SIDE_TOP + 0.001, 0), cloth, 0.001)
		SurfaceStyle.ring(sehpa, 0.055, 0.002, Vector3(0, SIDE_TOP + 0.003, -0.06), brass)

		# Lower shelf (alt tabla) + 4 turned wooden legs
		SurfaceStyle.box(sehpa, Vector3(0.28, 0.016, 0.34), Vector3(0, 0.24, 0), walnut_dark, 0.003)
		for lx in [-0.145, 0.145]:
			for lz in [-0.175, 0.175]:
				SurfaceStyle.rod(sehpa, Vector3(lx, 0.0, lz), Vector3(lx, SIDE_TOP - 0.02, lz), 0.018, walnut_dark)


func _build_discard_markers() -> void:
	var tray_wood := SurfaceStyle.textured(Color("4f2e1b"))
	var tray_brass := SurfaceStyle.metal(Color("d4a44e"), 0.30)

	for i in 4:
		var spot: Vector3 = DISCARD_SPOTS[i]
		var tray := Node3D.new()
		tray.position = spot
		tray.rotation.y = i * PI * 0.5
		add_child(tray)
		# Subtle recessed walnut & brass tile coaster base on the felt (NO floating 3D text clutter!)
		SurfaceStyle.box(tray, Vector3(0.058, 0.003, 0.074), Vector3(0, 0.001, 0), tray_wood, 0.002)
		SurfaceStyle.box(tray, Vector3(0.048, 0.0035, 0.064), Vector3(0, 0.0015, 0), tray_brass, 0.001)
		SurfaceStyle.box(tray, Vector3(0.042, 0.004, 0.058), Vector3(0, 0.0018, 0), SurfaceStyle.textured(Color("22140c")), 0.001)

	# Subtle Discard Target Pad on Seat 0's Right Discard Spot (DISCARD_SPOTS[0])
	_discard_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_discard_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_discard_glow_mat.albedo_color = Color(0.32, 0.96, 0.52, 0.28)
	_discard_glow_pad = MeshInstance3D.new()
	var dqm := QuadMesh.new()
	dqm.size = Vector2(0.068, 0.084)
	_discard_glow_pad.mesh = dqm
	_discard_glow_pad.material_override = _discard_glow_mat
	_discard_glow_pad.rotation.x = -PI * 0.5
	_discard_glow_pad.position = DISCARD_SPOTS[0] + Vector3(0, 0.0035, 0)
	add_child(_discard_glow_pad)

	# Subtle Draw Target Pads (Center Pile & Left Discard Spot)
	_draw_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_draw_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw_glow_mat.albedo_color = Color(1.0, 0.84, 0.32, 0.24)
	_draw_glow_pad = MeshInstance3D.new()
	var cqm := QuadMesh.new()
	cqm.size = Vector2(0.34, 0.14)
	_draw_glow_pad.mesh = cqm
	_draw_glow_pad.material_override = _draw_glow_mat
	_draw_glow_pad.rotation.x = -PI * 0.5
	_draw_glow_pad.position = Vector3(0, TOP + 0.002, 0)
	add_child(_draw_glow_pad)

	_left_draw_pad = MeshInstance3D.new()
	_left_draw_pad.mesh = dqm
	_left_draw_pad.material_override = _draw_glow_mat
	_left_draw_pad.rotation.x = -PI * 0.5
	_left_draw_pad.position = DISCARD_SPOTS[3] + Vector3(0, 0.0035, 0)
	add_child(_left_draw_pad)


func set_turn_guides(is_draw_phase: bool, holding_from_rack: bool) -> void:
	_show_draw_guide = is_draw_phase and not holding_from_rack
	_show_discard_guide = holding_from_rack


func _build_interactive_props() -> void:
	# Seat 0's tea glass sits on the Left Side Table (Yan Sehpa); opponents' tea glasses sit near their corners
	var tea_configs := [
		{"id": "tea_0", "pos": Vector3(-0.72, SIDE_TOP, 0.64), "yaw": -0.15, "seat": 0,
			"hint": "Sol tık: Çay Yudumla (Sakinleş)  ·  [E] Çayı Devir"},
		{"id": "tea_1", "pos": Vector3(0.61, TOP + 0.028, 0.24), "yaw": 0.40, "seat": 1,
			"hint": "Sol tık: Temel'in Çayını Devir! (Sabotaj)"},
		{"id": "tea_2", "pos": Vector3(0.24, TOP + 0.028, -0.61), "yaw": -0.55, "seat": 2,
			"hint": "Sol tık: Sabri'nin Çayını Devir! (Sabotaj)"},
		{"id": "tea_3", "pos": Vector3(-0.61, TOP + 0.028, -0.24), "yaw": 0.25, "seat": 3,
			"hint": "Sol tık: Rıfkı'nın Çayını Devir! (Sabotaj)"},
	]
	for cfg in tea_configs:
		var node := _details("ince_belli_tea", cfg["pos"], cfg["yaw"])
		_spawn_vapor(cfg["pos"] + Vector3(0, 0.095, 0), Color(0.96, 0.92, 0.86, 0.16), 0.018)
		_register_prop(cfg["id"], node, cfg["pos"], 0.09, cfg["hint"], {"seat": cfg["seat"], "spilled": false, "home_pos": cfg["pos"], "home_rot": node.rotation})

	# Turkish Coffee cup (on Right Side Table / Sağ Yan Sehpa)
	var coffee_pos := Vector3(0.72, SIDE_TOP, 0.64)
	var coffee_node := _details("turkish_coffee", coffee_pos, 0.25)
	_spawn_vapor(coffee_pos + Vector3(0, 0.070, 0), Color(0.95, 0.90, 0.84, 0.13), 0.014)
	_register_prop("coffee", coffee_node, coffee_pos, 0.09, "Sol tık: Türk Kahvesi İç (Odak & Hız)  ·  [E] Telve Sıçrat", {"home_pos": coffee_pos})

	# Tespih (on Left Side Table / Sol Yan Sehpa)
	var tespih_pos := Vector3(-0.82, SIDE_TOP, 0.75)
	var tespih_node := _details("cherry_tespih", tespih_pos, 0.2)
	_register_prop("tespih", tespih_node, tespih_pos, 0.09, "Sol tık: Tesbih Çek / Salla (Racon Kes)", {"home_pos": tespih_pos})

	# Leblebi Bowl (left rim of main table)
	var leblebi_pos := Vector3(-0.61, TOP + 0.028, 0.14)
	var leblebi_node := _details("leblebi_bowl", leblebi_pos, 0.0)
	_register_prop("leblebi", leblebi_node, leblebi_pos, 0.095, "Sol tık: Rakibe Leblebi Fırlat! (Dikkat Dağıt)", {})

	# Cut-Glass Ashtray (right rim of main table)
	var ash_pos := Vector3(0.61, TOP + 0.028, -0.14)
	var ash_node := _details("cut_glass_ashtray", ash_pos, 0.0)
	_spawn_vapor(ash_pos + Vector3(0.01, 0.024, 0.0), Color(0.78, 0.80, 0.85, 0.14), 0.012)
	_register_prop("ashtray", ash_node, ash_pos, 0.09, "Sol tık: Duman Üfle! (6 sn Sis Perdesi)", {})

	# Yazboz Score Pad (on Right Side Table / Sağ Yan Sehpa)
	var yazboz_pos := Vector3(0.83, SIDE_TOP, 0.75)
	var yazboz_node := _details("yazboz_pad", yazboz_pos, -0.18)
	_register_prop("yazboz", yazboz_node, yazboz_pos, 0.095, "Sol tık: Yazboz Defteri (Per & Skor Durumu)", {})

	# Special Accessory 1: Kabadayı Sunglasses (on Right Side Table / Sağ Yan Sehpa)
	var glasses_pos := Vector3(0.73, SIDE_TOP + 0.004, 0.79)
	var glasses_node := _build_sunglasses(glasses_pos)
	_register_prop("glasses", glasses_node, glasses_pos, 0.09, "Sol tık: Kabadayı Gözlüğü Tak/Çıkar (Şüphe Azaltır & Okey Parlar)", {})

	# Special Accessory 2: Brass Magnifying Glass (on Left Side Table / Sol Yan Sehpa)
	var mag_pos := Vector3(-0.71, SIDE_TOP + 0.003, 0.80)
	var mag_node := _build_magnifier(mag_pos)
	_register_prop("magnifier", mag_node, mag_pos, 0.09, "Sol tık: Büyüteçle Rakip Taşlarını Dikizle", {"home_pos": mag_pos, "home_rot": mag_node.rotation})


func _build_sunglasses(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "kabadayi_glasses"
	root.position = pos
	root.rotation.y = -0.22
	add_child(root)
	var gold := SurfaceStyle.metal(Color("c99e48"), 0.25)
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.06, 0.05, 0.04, 0.88)
	lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens_mat.roughness = 0.12
	lens_mat.metallic = 0.35
	for side in [-1, 1]:
		var rim := SurfaceStyle.ring(root, 0.022, 0.0022, Vector3(side * 0.028, 0.012, 0), gold)
		rim.rotation.x = PI * 0.35
		var lens := SurfaceStyle.part(root, Toon.cylinder(0.021, 0.002), lens_mat, Vector3(side * 0.028, 0.012, 0))
		lens.rotation.x = PI * 0.85
		SurfaceStyle.rod(root, Vector3(side * 0.048, 0.014, 0), Vector3(side * 0.044, 0.004, -0.065), 0.002, gold)
	SurfaceStyle.rod(root, Vector3(-0.008, 0.015, 0.002), Vector3(0.008, 0.015, 0.002), 0.002, gold)
	return root


func _build_magnifier(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "brass_magnifier"
	root.position = pos
	root.rotation.y = 0.35
	add_child(root)
	var brass := SurfaceStyle.metal(Color("b88b3a"), 0.28)
	var wood := SurfaceStyle.textured(Color("3d2214"))
	SurfaceStyle.ring(root, 0.028, 0.0035, Vector3(0, 0.004, 0), brass)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.78, 0.88, 0.92, 0.32)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	SurfaceStyle.part(root, Toon.cylinder(0.026, 0.002), glass, Vector3(0, 0.004, 0))
	SurfaceStyle.rod(root, Vector3(0, 0.004, 0.029), Vector3(0, 0.004, 0.082), 0.0045, wood)
	return root


func _register_prop(id: String, node: Node3D, pos: Vector3, radius: float, hint_text: String, meta: Dictionary) -> void:
	props.append({
		"id": id,
		"node": node,
		"pos": pos,
		"radius": radius,
		"hint": hint_text,
		"meta": meta,
	})


## Raycasts against all interactive tabletop props and returns the closest hit dictionary (or empty).
func pick_prop(from: Vector3, dir: Vector3, max_dist := 1.75) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for p in props:
		var node: Node3D = p["node"]
		if not is_instance_valid(node) or not node.visible:
			continue
		var center := to_global(p["pos"] + Vector3(0, 0.035, 0))
		var r: float = p["radius"]
		var oc := from - center
		var b := oc.dot(dir)
		var c := oc.dot(oc) - r * r
		var disc := b * b - c
		if disc < 0.0:
			continue
		var dist := -b - sqrt(disc)
		if dist < 0.05:
			dist = -b + sqrt(disc)
		if dist > 0.05 and dist < best_d:
			best_d = dist
			best = p
	return best


func set_hovered_prop(id: String) -> void:
	if _hovered_prop_id == id:
		return
	for p in props:
		if p["id"] == _hovered_prop_id and is_instance_valid(p["node"]):
			for mi: MeshInstance3D in (p["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
				if mi.material_overlay != _contest_highlight:
					mi.material_overlay = null
	_hovered_prop_id = id
	for p in props:
		if p["id"] == _hovered_prop_id and is_instance_valid(p["node"]):
			for mi: MeshInstance3D in (p["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
				if mi.material_overlay != _contest_highlight:
					mi.material_overlay = _prop_highlight


func set_contested_prop(id: String) -> void:
	if _contested_prop_id == id:
		return
	if not _contested_prop_id.is_empty():
		var old_p := find_prop(_contested_prop_id)
		if not old_p.is_empty() and is_instance_valid(old_p["node"]):
			for mi: MeshInstance3D in (old_p["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
				if mi.material_overlay == _contest_highlight:
					mi.material_overlay = null
	_contested_prop_id = id
	if not _contested_prop_id.is_empty():
		var p := find_prop(_contested_prop_id)
		if not p.is_empty() and is_instance_valid(p["node"]):
			for mi: MeshInstance3D in (p["node"] as Node3D).find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = _contest_highlight



func find_prop(id: String) -> Dictionary:
	for p in props:
		if p["id"] == id:
			return p
	return {}


## Animates sipping your own tea glass or Turkish coffee cup.
func animate_drink(id: String, camera_pos: Vector3) -> void:
	var p := find_prop(id)
	if p.is_empty():
		return
	var node: Node3D = p["node"]
	var home: Vector3 = p["meta"].get("home_pos", p["pos"])
	var mouth_local := to_local(camera_pos + Vector3(0, -0.14, 0)).lerp(home, 0.32)
	mouth_local.y = home.y + 0.30
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", mouth_local, 0.28)
	tw.parallel().tween_property(node, "rotation:x", -0.55, 0.28)
	tw.tween_interval(0.35)
	tw.tween_property(node, "position", home, 0.30)
	tw.parallel().tween_property(node, "rotation:x", 0.0, 0.30)


## Tips a tea glass over and creates an expanding dark-red tea puddle on the green felt!
func spill_tea(prop_id: String) -> int:
	var p := find_prop(prop_id)
	if p.is_empty():
		return -1
	var node: Node3D = p["node"]
	var seat_idx: int = p["meta"].get("seat", 1)
	var home: Vector3 = p["meta"].get("home_pos", p["pos"])
	p["meta"]["spilled"] = true

	var toward_center := (-home).normalized()
	var spill_spot := home.lerp(Vector3.ZERO, 0.32)
	spill_spot.y = home.y + 0.002

	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", home + Vector3(toward_center.x * 0.06, -0.008, toward_center.z * 0.06), 0.16)
	tw.parallel().tween_property(node, "rotation:z", PI * 0.44, 0.16)

	var puddle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.17
	cyl.bottom_radius = 0.18
	cyl.height = 0.002
	cyl.radial_segments = 28
	puddle.mesh = cyl
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.30, 0.04, 0.015, 0.86)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.roughness = 0.54
	pmat.metallic = 0.0
	pmat.metallic_specular = 0.12
	puddle.material_override = pmat
	puddle.position = spill_spot
	puddle.scale = Vector3(0.05, 1.0, 0.05)
	add_child(puddle)
	_puddles.append(puddle)

	var ptw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ptw.tween_property(puddle, "scale", Vector3(1.15, 1.0, 0.92), 0.65)
	ptw.tween_interval(4.2)
	ptw.tween_property(pmat, "albedo_color:a", 0.0, 1.0)
	ptw.tween_callback(func() -> void:
		_puddles.erase(puddle)
		puddle.queue_free()
		if is_instance_valid(node):
			var rtw := create_tween()
			rtw.tween_property(node, "position", home, 0.25)
			rtw.parallel().tween_property(node, "rotation", p["meta"]["home_rot"], 0.25)
			p["meta"]["spilled"] = false
	)
	return seat_idx


## Launches a 3D roasted chickpea (leblebi) in a parabolic arc at an opponent's head!
func launch_leblebi(target_world_pos: Vector3, on_hit: Callable) -> void:
	var p := find_prop("leblebi")
	var start_local: Vector3 = p.get("pos", Vector3(-0.63, TOP + 0.04, 0.12)) + Vector3(0, 0.04, 0)
	var end_local := to_local(target_world_pos)
	var mid_bounce := end_local.lerp(Vector3.ZERO, 0.35)
	mid_bounce.y = TOP + 0.015

	var pea := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.026
	pea.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d8a44e")
	mat.roughness = 0.65
	pea.material_override = mat
	pea.position = start_local
	add_child(pea)

	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var pos := start_local.lerp(end_local, t)
		pos.y += sin(t * PI) * 0.26
		pea.position = pos, 0.0, 1.0, 0.34)
	tw.tween_callback(func() -> void:
		if on_hit.is_valid():
			on_hit.call()
	)
	tw.tween_method(func(t: float) -> void:
		var pos := end_local.lerp(mid_bounce, t)
		pos.y += sin(t * PI) * 0.12
		pea.position = pos, 0.0, 1.0, 0.28)
	tw.tween_callback(func() -> void: pea.queue_free())


## Blows a thick cloud of cigarette smoke over the center of the table for 6.5 seconds.
func puff_smoke() -> void:
	smoke_active_timer = 6.5
	for child in _smoke_puffs:
		if is_instance_valid(child["node"]):
			child["node"].queue_free()
	_smoke_puffs.clear()

	for i in 9:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16 + (i % 3) * 0.05
		sm.height = sm.radius * 1.4
		puff.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.82, 0.80, 0.76, 0.0)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		puff.material_override = mat
		var angle := i * TAU / 9.0
		var r := 0.12 + (i % 2) * 0.16
		var base := Vector3(cos(angle) * r, TOP + 0.18 + (i % 3) * 0.06, sin(angle) * r)
		puff.position = base
		add_child(puff)
		_smoke_puffs.append({"node": puff, "mat": mat, "base": base, "phase": i * 0.8})


## Spins and lifts the crimson amber tespih.
func spin_tespih() -> void:
	var p := find_prop("tespih")
	if p.is_empty():
		return
	var node: Node3D = p["node"]
	var home: Vector3 = p["meta"]["home_pos"]
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", home + Vector3(0.05, 0.14, -0.06), 0.18)
	tw.parallel().tween_property(node, "rotation:y", node.rotation.y + TAU, 0.36)
	tw.tween_property(node, "position", home, 0.22)


func toggle_glasses() -> bool:
	glasses_worn = not glasses_worn
	var p := find_prop("glasses")
	if not p.is_empty() and is_instance_valid(p["node"]):
		(p["node"] as Node3D).visible = not glasses_worn
	return glasses_worn


func animate_magnifier(camera_pos: Vector3, duration := 4.2) -> void:
	var p := find_prop("magnifier")
	if p.is_empty():
		return
	var node: Node3D = p["node"]
	var home: Vector3 = p["meta"]["home_pos"]
	var eye_local := to_local(camera_pos).lerp(Vector3(0, TOP + 0.38, 0.25), 0.55)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", eye_local, 0.25)
	tw.parallel().tween_property(node, "rotation:x", PI * 0.42, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(node, "position", home, 0.28)
	tw.parallel().tween_property(node, "rotation", p["meta"]["home_rot"], 0.28)


func animate_neighbor_take(prop_id: String, seat_idx: int, duration := 5.0) -> void:
	var p := find_prop(prop_id)
	if p.is_empty() or not is_instance_valid(p["node"]):
		return
	var node: Node3D = p["node"]
	var home: Vector3 = p["meta"].get("home_pos", p["pos"])
	var neighbor_target := home + Vector3(0.18 if seat_idx == 1 else -0.18, 0.08, -0.14)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", neighbor_target, 0.35)
	tw.tween_interval(duration)
	tw.tween_property(node, "position", home, 0.35)



func _spawn_vapor(origin: Vector3, tint: Color, radius: float) -> void:
	for k in 3:
		var wisp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = radius * (0.85 + k * 0.25)
		sm.height = sm.radius * 2.6
		sm.radial_segments = 12
		sm.rings = 8
		wisp.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = tint
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		wisp.material_override = mat
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.position = origin + Vector3(0, k * 0.04, 0)
		add_child(wisp)
		_vapors.append({
			"node": wisp,
			"mat": mat,
			"base": origin,
			"base_alpha": tint.a,
			"phase": k * 2.1 + origin.x * 3.7 + origin.z * 5.1,
		})


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 4.5)
	if is_instance_valid(_discard_glow_pad):
		_discard_glow_pad.visible = _show_discard_guide
		_discard_glow_mat.albedo_color.a = lerpf(0.16, 0.42, pulse)
	if is_instance_valid(_draw_glow_pad):
		_draw_glow_pad.visible = _show_draw_guide
		_draw_glow_mat.albedo_color.a = lerpf(0.14, 0.36, pulse)
	if is_instance_valid(_left_draw_pad):
		_left_draw_pad.visible = _show_draw_guide
	for v in _vapors:
		var node: MeshInstance3D = v["node"]
		var mat: StandardMaterial3D = v["mat"]
		var base: Vector3 = v["base"]
		var phase: float = v["phase"]
		var cycle := fmod(_time * 0.55 + phase, 1.0)
		node.position = base + Vector3(
			sin(_time * 1.8 + phase) * 0.012 * cycle,
			cycle * 0.14,
			cos(_time * 1.5 + phase) * 0.010 * cycle
		)
		var alpha: float = v["base_alpha"] * sin(cycle * PI)
		mat.albedo_color.a = alpha

	if smoke_active_timer > 0.0:
		smoke_active_timer = maxf(0.0, smoke_active_timer - delta)
		var fade := clampf(smoke_active_timer / 1.5, 0.0, 1.0)
		for sp in _smoke_puffs:
			var pnode: MeshInstance3D = sp["node"]
			var pmat: StandardMaterial3D = sp["mat"]
			var pbase: Vector3 = sp["base"]
			var ph: float = sp["phase"]
			if is_instance_valid(pnode):
				pnode.position = pbase + Vector3(sin(_time * 1.4 + ph) * 0.04, cos(_time * 1.1 + ph) * 0.02, sin(_time * 1.2 - ph) * 0.04)
				pmat.albedo_color.a = 0.28 * fade
		if smoke_active_timer <= 0.0:
			for sp in _smoke_puffs:
				if is_instance_valid(sp["node"]):
					sp["node"].queue_free()
			_smoke_puffs.clear()


func _details(id: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var prop: Node3D = load("res://assets/models/table_details/%s.glb" % id).instantiate()
	prop.name = id
	prop.position = pos
	prop.rotation.y = yaw
	add_child(prop)
	for mi: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat != null and mat.resource_name.begins_with("table_glass"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var glass := ShaderMaterial.new()
				glass.shader = preload("res://assets/shaders/thin_glass.gdshader")
				mi.set_surface_override_material(i, glass)
	return prop


## Face-down draw pile in the middle plus the face-up indicator tile.
func show_pile(tiles: Array, indicator: Vector2i) -> void:
	for child in _pile.get_children():
		child.queue_free()
	for child in _loose.get_children():
		child.queue_free()
	_draw_tiles.clear()
	for i in 4:
		_discards[i].clear()

	indicator_value = indicator
	okey_value = TileFactory.okey_from_indicator(indicator)

	const COLUMNS := 8
	const ROWS := 2
	var lying := TileFactory.SIZE.z
	for i in tiles.size():
		var layer := floori(i / float(COLUMNS * ROWS))
		var column := i % COLUMNS
		var row := floori((i % (COLUMNS * ROWS)) / float(COLUMNS))
		var tile := TileFactory.create(tiles[i])
		tile.holder = self
		tile.is_draw_pile = true
		tile.basis = Basis(Vector3.RIGHT, PI * 0.5) # face down
		tile.position = Vector3((column - (COLUMNS - 1) * 0.5) * 0.039, TOP + lying * (layer + 0.5) + 0.0005 * layer,
			(row - 0.5) * 0.056)
		_pile.add_child(tile)
		_draw_tiles.append(tile)

	indicator_tile = TileFactory.create(indicator)
	indicator_tile.holder = self
	indicator_tile.is_indicator = true
	indicator_tile.basis = Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, -PI * 0.5)
	indicator_tile.position = Vector3(0.20, TOP + lying * 0.5, 0.09)
	_pile.add_child(indicator_tile)


func draw_count() -> int:
	var valid := 0
	for t in _draw_tiles:
		if is_instance_valid(t) and t.is_draw_pile:
			valid += 1
	return valid


func pop_draw_tile() -> Tile:
	while not _draw_tiles.is_empty():
		var t: Tile = _draw_tiles.pop_back()
		if is_instance_valid(t) and t.is_draw_pile:
			t.is_draw_pile = false
			t.holder = null
			return t
	return null


func top_discard(seat_idx: int) -> Tile:
	var stack: Array = _discards[seat_idx % 4]
	while not stack.is_empty():
		var top: Tile = stack.back()
		if is_instance_valid(top) and top.holder == self:
			return top
		stack.pop_back()
	return null


## Places a discarded tile face-up onto a player's right-hand corner discard stack.
func put_discard(seat_idx: int, tile: Tile) -> void:
	seat_idx = posmod(seat_idx, 4)
	var stack: Array = _discards[seat_idx]
	tile.holder = self
	tile.is_draw_pile = false
	tile.is_indicator = false
	tile.is_discard = true
	tile.discard_seat = seat_idx
	if tile.get_parent() != _loose:
		tile.reparent(_loose)
	var spot: Vector3 = DISCARD_SPOTS[seat_idx]
	var height_idx := stack.size()
	var local_pos := spot + Vector3(
		sin(height_idx * 1.7) * 0.004,
		TileFactory.SIZE.z * (0.5 + height_idx * 1.02),
		cos(height_idx * 2.3) * 0.004
	)
	var yaw := seat_idx * PI * 0.5
	stack.append(tile)
	tile.slide_to(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), local_pos), 0.24, 0.055)


## Lays a tile face up on the felt at a world point; snaps to Seat 0's discard stack only if placed near the right discard tray!
func put_loose(tile: Tile, point: Vector3, yaw: float) -> bool:
	var local := to_local(point)
	if Vector2(local.x - DISCARD_SPOTS[0].x, local.z - DISCARD_SPOTS[0].z).length() < 0.14:
		put_discard(0, tile)
		return true
	tile.holder = self
	tile.is_draw_pile = false
	tile.is_discard = false
	tile.reparent(_loose)
	local.x = clampf(local.x, -SIZE * 0.46, SIZE * 0.46)
	local.z = clampf(local.z, -SIZE * 0.46, SIZE * 0.46)
	local.y = TOP + TileFactory.SIZE.z * 0.5
	tile.slide_to(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), local), 0.18, 0.025)
	return false


## Drops a tile straight from the player's hand onto the table below with a natural physical drop.
func drop_loose_from_hand(tile: Tile, world_from: Vector3, yaw: float) -> bool:
	var local := to_local(world_from)
	local.x = clampf(local.x, -SIZE * 0.44, SIZE * 0.44)
	local.z = clampf(local.z, -SIZE * 0.44, SIZE * 0.44)
	if Vector2(local.x - DISCARD_SPOTS[0].x, local.z - DISCARD_SPOTS[0].z).length() < 0.14:
		put_discard(0, tile)
		return true
	tile.holder = self
	tile.is_draw_pile = false
	tile.is_discard = false
	tile.reparent(_loose)
	var land_pos := Vector3(local.x, TOP + TileFactory.SIZE.z * 0.5, local.z)
	var flat_basis := Basis(Vector3.UP, yaw + randf_range(-0.18, 0.18)) * Basis(Vector3.RIGHT, -PI * 0.5)
	tile.slide_to(Transform3D(flat_basis, land_pos), 0.16, 0.015)
	return false


## Flings/throws a tile across the table in a fast ballistic arc with spin and bounce!
func throw_tile(tile: Tile, from_world: Vector3, dir_world: Vector3, yaw: float) -> bool:
	var hit: Variant = felt_hit(from_world, dir_world)
	var target_local: Vector3
	if hit != null:
		target_local = to_local(hit)
	else:
		var flat_dir := Vector3(dir_world.x, 0.0, dir_world.z).normalized()
		if flat_dir.length_squared() < 0.01:
			flat_dir = Vector3.FORWARD
		target_local = to_local(from_world) + flat_dir * 0.48
	target_local.x = clampf(target_local.x, -SIZE * 0.44, SIZE * 0.44)
	target_local.z = clampf(target_local.z, -SIZE * 0.44, SIZE * 0.44)

	# If thrown toward the right side of the table (or Seat 0's discard zone), land on Seat 0's discard pile!
	if target_local.x > 0.10 and target_local.z > -0.10:
		put_discard(0, tile)
		return true

	tile.holder = self
	tile.is_draw_pile = false
	tile.is_discard = false
	tile.reparent(_loose)
	var land_pos := Vector3(target_local.x, TOP + TileFactory.SIZE.z * 0.5, target_local.z)
	var spin_yaw := yaw + randf_range(-0.65, 0.65)
	var flat_basis := Basis(Vector3.UP, spin_yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	tile.slide_to(Transform3D(flat_basis, land_pos), 0.22, 0.085)
	return false


func release(tile: Tile) -> int:
	tile.holder = null
	if tile.is_draw_pile:
		tile.is_draw_pile = false
		_draw_tiles.erase(tile)
	if tile.is_discard and tile.discard_seat >= 0 and tile.discard_seat < 4:
		_discards[tile.discard_seat].erase(tile)
		tile.is_discard = false
	return -1


## Where a world-space ray meets the tabletop, or null if it lands outside the table.
func felt_hit(from: Vector3, dir: Vector3) -> Variant:
	var hit: Variant = Plane(Vector3.UP, TOP).intersects_ray(to_local(from), dir)
	if hit == null:
		return null
	var half := SIZE * 0.5 - 0.03
	if absf(hit.x) > half or absf(hit.z) > half:
		return null
	return to_global(hit)
