extends Node
## A live coffeehouse backdrop, with functional local table setup and settings.

const CREAM := Color("f2d3a0")
const MUTED := Color("b99c7e")
var game: Node3D
var layer := CanvasLayer.new()
var page := VBoxContainer.new()
var heading := Label.new()
var footer := Label.new()
var shade := ColorRect.new()
var _font := SystemFont.new()
var _display := SystemFont.new()
var _screen := "home"
var _time := 0.0
var _preview: Node3D
var _preview_light: OmniLight3D
var _preview_chair: Node3D

func _ready() -> void:
	CafePreferences.restore()
	_font.font_names = PackedStringArray(["Segoe UI","Arial"])
	_font.font_weight = 600
	_display.font_names = PackedStringArray(["Georgia","Cambria"])
	_display.font_weight = 700
	game = preload("res://scenes/main.tscn").instantiate()
	game.get_node("FocusCamera").mouse_control = false
	add_child(game)
	game.hud.hide()
	game.hud.process_mode = Node.PROCESS_MODE_DISABLED
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.camera.set_process(false)
	game.camera.attributes.dof_blur_near_enabled = false
	game.camera.attributes.dof_blur_far_enabled = false
	_apply_table()
	_build_ui()
	_home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args: Dictionary = game._user_args()
	if args.has("game-shot") or args.has("screenshot"):
		_play(false)
		args["screenshot"] = args.get("game-shot",args.get("screenshot",""))
		game._capture(args)
		return
	if args.has("menu-shot"):
		if args.has("page"):
			match args["page"]:
				"characters": _characters()
				"table": _table()
		for i in 35:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["menu-shot"])
		get_tree().quit()

func _build_ui() -> void:
	layer.layer = 8
	add_child(layer)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/menu_shade.gdshader")
	shade.material = material
	layer.add_child(shade)
	var margin := MarginContainer.new()
	margin.anchor_right = 0.41
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left",64)
	margin.add_theme_constant_override("margin_right",32)
	margin.add_theme_constant_override("margin_top",48)
	margin.add_theme_constant_override("margin_bottom",42)
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	margin.add_child(column)
	var eyebrow := _label("BİR MASA. BOL MUHABBET.",13,MUTED)
	column.add_child(eyebrow)
	heading = _label("OKEY",76,CREAM)
	heading.add_theme_font_override("font",_display)
	column.add_child(heading)
	var subtitle := _label("K I R A A T H A N E",20,Color("d99547"))
	column.add_child(subtitle)
	var line := HSeparator.new()
	line.modulate = Color("89613d")
	column.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	column.add_child(spacer)
	page.add_theme_constant_override("separation",12)
	column.add_child(page)
	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spring)
	footer = _label("Çay hazır. Masada bir yerin var.",14,MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer)
	var location := _label("MUHABBET KIRAATHANESİ",13,CREAM)
	location.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	location.offset_left = -320
	location.offset_top = -56
	location.offset_right = -48
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(location)

func _label(text: String, size: int, color := CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",_font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
	label.add_theme_constant_override("shadow_offset_y",2)
	return label

func _clear(screen: String, title: String) -> void:
	_screen = screen
	for node in page.get_children():
		page.remove_child(node)
		node.queue_free()
	heading.text = title
	heading.add_theme_font_size_override("font_size",76 if screen == "home" else 38)
	if is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
	if is_instance_valid(_preview_light):
		_preview_light.queue_free()
		_preview_light = null
	if is_instance_valid(_preview_chair):
		_preview_chair.queue_free()
		_preview_chair = null

func _button(text: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 56
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",_font)
	b.add_theme_font_size_override("font_size",21)
	b.add_theme_color_override("font_color",Color("2a180e") if primary else CREAM)
	b.add_theme_color_override("font_hover_color",Color("25160e") if primary else Color("fff0d2"))
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (Color("d8984e") if primary else Color("342318")) if state == "normal" else (Color("f0b66c") if primary else Color("573b26"))
		style.border_color = Color("ae773e") if primary else Color("785337")
		style.border_width_top = 1
		style.border_width_bottom = 3
		style.set_corner_radius_all(7)
		style.shadow_color = Color(0,0,0,0.3)
		style.shadow_size = 5
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(action)
	page.add_child(b)
	return b

func _home() -> void:
	_clear("home","OKEY")
	_button("OYNA",_table,true)
	_button("KARAKTERLER",_characters)
	_button("AYARLAR",_settings)
	_button("ÇIKIŞ",func() -> void: get_tree().quit())
	footer.text = "Çay hazır. Masada bir yerin var."

func _characters() -> void:
	_clear("characters","KARAKTERLER")
	page.add_child(_label("Karşı koltuğun misafirini seç",16,MUTED))
	_button("MASA: " + CafePreferences.cast,func() -> void:
		CafePreferences.cast = "Hayvanlar" if CafePreferences.cast == "Dayılar" else "Dayılar"
		CafePreferences.companion = "sabri" if CafePreferences.cast == "Dayılar" else "panda"
		_apply_companion()
		CafePreferences.save()
		_characters())
	var options := [["sabri","SABRİ  ·  Bordo eşofman"],["temel","TEMEL  ·  Kasket ve yelek"],["rifki","RIFKI  ·  Kır saç ve gözlük"]] if CafePreferences.cast == "Dayılar" else [["panda","PANDA  ·  Yeşil kapüşon"],["bunny","TAVŞAN  ·  Pembe kapüşon"],["dinosaur","DİNOZOR  ·  Sarı kapüşon"]]
	for item in options:
		var kind: String = item[0]
		_button(item[1],func() -> void:
			CafePreferences.companion = kind
			_apply_companion()
			CafePreferences.save()
			_characters(),CafePreferences.companion == kind)
	_button("‹  GERİ",_home)
	if CafePreferences.cast == "Dayılar":
		var patron := CafePatron.new()
		game.add_child(patron)
		patron.build(CafePreferences.companion)
		patron.scale = Vector3.ONE*1.3
		_preview = patron
	else:
		var mascot := MascotCharacter.new()
		game.add_child(mascot)
		mascot.build(CafePreferences.companion,1.25)
		_preview = mascot
	_preview.position = Vector3(1.35,0.57,1.1)
	_preview.rotation.y = PI-0.25
	_preview_chair = Node3D.new()
	game.add_child(_preview_chair)
	_preview_chair.position = Vector3(1.35,0,1.1)
	_preview_chair.rotation.y = PI-0.25
	var wood := SurfaceStyle.textured(Color("463326"))
	SurfaceStyle.box(_preview_chair,Vector3(0.58,0.07,0.54),Vector3(0,0.53,0),wood,0.025)
	SurfaceStyle.box(_preview_chair,Vector3(0.58,0.54,0.07),Vector3(0,0.86,0.23),wood,0.025)
	for x in [-0.23,0.23]:
		for z in [-0.20,0.20]:
			SurfaceStyle.rod(_preview_chair,Vector3(x,0,z),Vector3(x,0.53,z),0.027,wood)
	_preview_light = OmniLight3D.new()
	_preview_light.position = Vector3(1.7,1.5,2.0)
	_preview_light.omni_range = 3.0
	_preview_light.light_energy = 0.65
	_preview_light.light_color = Color("ffe0b0")
	game.add_child(_preview_light)
	footer.text = "Seçimin oyun masasındaki karşı koltuğa uygulanır."

func _table() -> void:
	_clear("table","MASA KUR")
	page.add_child(_label("MUHABBET KIRAATHANESİ",18))
	page.add_child(_label("4 koltuk · Yerel masa",14,MUTED))
	page.add_child(_label("MASA ÖRTÜSÜ",13,MUTED))
	for cloth in ["Bordo","Yeşil"]:
		_button(cloth,func() -> void:
			CafePreferences.cloth = cloth
			_apply_table()
			CafePreferences.save()
			_table(),CafePreferences.cloth == cloth)
	_button("MASAYA OTUR",_play,true)
	_button("‹  GERİ",_home)
	footer.text = "Taşlarını düzenle. Gözler başka yere bakarken fırsatı yakala."

func _settings() -> void:
	_clear("settings","AYARLAR")
	page.add_child(_label("SES",14,MUTED))
	_slider(CafePreferences.volume,0,1,func(value: float) -> void:
		CafePreferences.volume = value
		CafePreferences.apply())
	page.add_child(_label("FARE HASSASİYETİ",14,MUTED))
	_slider(CafePreferences.sensitivity,0.4,2,func(value: float) -> void: CafePreferences.sensitivity = value)
	_button("TAM EKRAN: " + ("AÇIK" if CafePreferences.fullscreen else "KAPALI"),func() -> void:
		CafePreferences.fullscreen = not CafePreferences.fullscreen
		CafePreferences.apply()
		_settings())
	_button("KAYDET VE GERİ DÖN",func() -> void:
		CafePreferences.save()
		_home(),true)
	footer.text = "Ayarlar bu bilgisayarda saklanır."

func _slider(value: float, minimum: float, maximum: float, changed: Callable) -> void:
	var s := HSlider.new()
	s.custom_minimum_size.y = 35
	s.min_value = minimum
	s.max_value = maximum
	s.step = 0.05
	s.value = value
	s.value_changed.connect(changed)
	page.add_child(s)

func _apply_companion() -> void:
	# Keep all three species at the table, changing the opposite seat by swapping.
	var target: Seat = game.seats[2]
	var kinds := CafePatron.KINDS if CafePreferences.cast == "Dayılar" else MascotCharacter.KINDS
	if not target.character in kinds:
		for i in 3:
			_set_companion(game.seats[i+1],kinds[i])
	for seat: Seat in game.seats.slice(1):
		if seat.character == CafePreferences.companion and seat != target:
			var previous := target.character
			_set_companion(target,CafePreferences.companion)
			_set_companion(seat,previous)
			return

func _set_companion(seat: Seat, kind: String) -> void:
	seat.buddy.free()
	seat.character = kind
	seat.character_height = 1.08 if kind == "bunny" else 0.95
	seat.buddy = Buddy.new()
	seat.buddy.position = Vector3(0,Seat.SEAT_TOP,Seat.CHAIR_DISTANCE)
	seat.add_child(seat.buddy)
	seat.buddy.setup(kind,seat.character_height)

func _apply_table() -> void:
	_apply_companion()
	for mi: MeshInstance3D in game.table.find_children("*","MeshInstance3D",true,false):
		if mi.material_override is ShaderMaterial and mi.material_override.shader == preload("res://assets/shaders/okey_felt.gdshader"):
			mi.material_override.set_shader_parameter("felt_color",Color("64272a") if CafePreferences.cloth == "Bordo" else Color("254e37"))

func _play(save_preferences := true) -> void:
	if save_preferences:
		CafePreferences.save()
	if is_instance_valid(_preview):
		_preview.queue_free()
	if is_instance_valid(_preview_chair):
		_preview_chair.queue_free()
	if is_instance_valid(_preview_light):
		_preview_light.queue_free()
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.camera.mouse_control = true
	game.camera.set_process(true)
	game.camera.attributes.dof_blur_near_enabled = true
	game.camera.attributes.dof_blur_far_enabled = true
	game.camera.set_focused(false,true)
	game.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	game.hud.show()
	layer.hide()
	set_process(false)
	game.hud.flash("Masaya hoş geldin",CREAM)

func _process(delta: float) -> void:
	_time += delta
	for seat: Seat in game.seats.slice(1):
		if seat.buddy._patron:
			seat.buddy._patron._process(delta)
	if is_instance_valid(_preview):
		_preview._process(delta)
	if _screen == "characters":
		game.camera.position = Vector3(1.0,1.42,3.0)
		game.camera.look_at(Vector3(1.0,1.11,1.0))
	else:
		game.camera.position = Vector3(1.95+sin(_time*0.08)*0.06,1.63,2.65)
		game.camera.look_at(Vector3(-0.35,1.04,-0.35))

func _unhandled_input(event: InputEvent) -> void:
	if layer.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_home()
		get_viewport().set_input_as_handled()
