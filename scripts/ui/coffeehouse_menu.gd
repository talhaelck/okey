extends Node
## Minimal main menu, shared settings, and live character selection.

const CREAM := CafeUi.INK
const GOLD := CafeUi.ACCENT
const MUTED := CafeUi.MUTED
const DARK_WOOD := Color("24170f")


const PATRON_ORDER := ["sabri", "rifki", "temel", "davut", "gozluklu", "tespihli", "yasli"]

const PATRON_DATA := {
	"gozluklu": {
		"model": "gozluklu", "title": "NİHAT DAYI",
		"quote": "\"Gözlük var, gözden kaçan taş yok.\"",
		"portrait": preload("res://assets/ui/portrait_gozluklu.png"),
		"stats": [["ŞANS", 0.72], ["MUHABBET", 0.66], ["SAKİNLİK", 0.88], ["TİLT", 0.30]],
	},
	"tespihli": {
		"model": "tespihli", "title": "CEMİL DAYI",
		"quote": "\"Sabırla dizilen taş,\nsonunda yerini bulur.\"",
		"portrait": preload("res://assets/ui/portrait_tespihli.png"),
		"stats": [["ŞANS", 0.76], ["MUHABBET", 0.90], ["SAKİNLİK", 0.70], ["TİLT", 0.48]],
	},
	"yasli": {
		"model": "yasli", "title": "HAMDİ AMCA",
		"quote": "\"Bu masada daha çok çay içersin.\"",
		"portrait": preload("res://assets/ui/portrait_yasli.png"),
		"stats": [["ŞANS", 0.82], ["MUHABBET", 0.78], ["SAKİNLİK", 0.94], ["TİLT", 0.18]],
	},
	"sabri": {
		"model": "sabri",
		"title": "SABRİ DAYI",
		"quote": "\"Taşlar karışır, muhabbet\nhiç bitmez.\"",
		"portrait": preload("res://assets/ui/portrait_sabri.png"),
		"stats": [["ŞANS", 0.78], ["MUHABBET", 0.92], ["SAKİNLİK", 0.58], ["TİLT", 0.45]],
	},
	"rifki": {
		"model": "rifki",
		"title": "RIFKI AMCA",
		"quote": "\"Gözlüğün üstünden bakarım,\ntaşın ciğerini okurum.\"",
		"portrait": preload("res://assets/ui/portrait_rifki.png"),
		"stats": [["ŞANS", 0.86], ["MUHABBET", 0.74], ["SAKİNLİK", 0.92], ["TİLT", 0.20]],
	},
	"temel": {
		"model": "temel",
		"title": "TEMEL REİS",
		"quote": "\"Okeyi ortaya atarım,\nçayı demli içerim.\"",
		"portrait": preload("res://assets/ui/portrait_temel.png"),
		"stats": [["ŞANS", 0.74], ["MUHABBET", 0.84], ["SAKİNLİK", 0.64], ["TİLT", 0.62]],
	},
	"davut": {
		"model": "davut",
		"title": "DAVUT USTA",
		"quote": "\"Benden taş çalanın\nçayını soğuturum.\"",
		"portrait": preload("res://assets/ui/portrait_davut.png"),
		"stats": [["ŞANS", 0.82], ["MUHABBET", 0.88], ["SAKİNLİK", 0.52], ["TİLT", 0.68]],
	},
}

var game: Node3D
var layer := CanvasLayer.new()
var root_ui := Control.new()
var shade := ColorRect.new()
var _font := SystemFont.new()
var _display := SystemFont.new()
var _screen := "home"
var _selected_card := "sabri"
var _time := 0.0
var _preview_stage: Node3D
var _opponent_order: Array[String] = []


func _ready() -> void:
	CafePreferences.restore()
	CafePreferences.venue="KIRAATHANE"
	CafePreferences.table_mode="4 KİŞİ"
	_selected_card = CafePreferences.companion if PATRON_DATA.has(CafePreferences.companion) else "sabri"
	_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_font.font_weight = 500
	_display.font_names = PackedStringArray(["Georgia", "Cambria", "Arial Black"])
	_display.font_weight = 600
	game = preload("res://scenes/main.tscn").instantiate()
	game.get_node("FocusCamera").mouse_control = false
	add_child(game)
	for seat: Seat in game.seats.slice(1):
		_opponent_order.append(seat.character)
	game.hud.hide()
	game.hud.process_mode = Node.PROCESS_MODE_DISABLED
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.camera.set_process(false)
	game.camera.attributes.dof_blur_near_enabled = false
	game.camera.attributes.dof_blur_far_enabled = false
	_set_local_hands_visible(false)
	game.table.set_turn_guides(false, false)
	if is_instance_valid(game.table._discard_glow_pad):
		game.table._discard_glow_pad.visible = false
	_apply_table()
	_build_base_ui()
	_home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args: Dictionary = game._user_args()
	if args.has("game-shot") or args.has("screenshot"):
		_play(false)
		args["screenshot"] = args.get("game-shot", args.get("screenshot", ""))
		game._capture(args)
		return
	if args.has("menu-shot"):
		if args.has("page"):
			match args["page"]:
				"characters":
					_selected_card = "sabri"
					_characters()
				"table": _table()
				"lobby":
					CafePreferences.venue = "KIRAATHANE"
					_table()
		for i in 35:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["menu-shot"])
		get_tree().quit()


func _set_local_hands_visible(vis: bool) -> void:
	var s0: Seat = game.seats[0]
	for child in s0.get_children():
		if child != s0.rack and child.name != "KiraathaneChair" and not (child is Marker3D):
			if child is Node3D:
				(child as Node3D).visible = vis


func _build_base_ui() -> void:
	layer.layer = 8
	add_child(layer)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/menu_shade.gdshader")
	shade.material = material
	layer.add_child(shade)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.theme = CafeUi.theme()
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_ui)


func _clear(screen: String) -> void:
	_screen = screen
	shade.visible = (screen != "characters")
	game.table.visible = (screen != "characters")
	game.get_node("Seats").visible = (screen != "characters")
	game.get_node("Room").visible = (screen != "characters")
	for node in root_ui.get_children():
		root_ui.remove_child(node)
		node.queue_free()
	if is_instance_valid(_preview_stage):
		_preview_stage.queue_free()
		_preview_stage = null


func _label(text: String, size: int, color := CREAM, use_display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _display if use_display else _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _wood_button(text: String, action: Callable, primary := false, min_size := Vector2(280,50), font_sz := 18) -> Button:
	var b := Button.new()
	b.text=text
	b.custom_minimum_size=min_size
	CafeUi.button(b,primary)
	b.add_theme_font_size_override("font_size",font_sz)
	b.pressed.connect(action)
	return b

func _pill_toggle(text: String,active: bool,action: Callable,min_size := Vector2(108,40)) -> Button:
	return _wood_button(text,action,active,min_size,16)

func _page(title: String, width: float = 540) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left=-width-80;panel.offset_right=-80
	panel.offset_top=-355;panel.offset_bottom=355
	root_ui.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",18)
	panel.add_child(col)
	var header := HBoxContainer.new();header.add_theme_constant_override("separation",18)
	header.add_child(_wood_button("Geri",_home,false,Vector2(72,40),15))
	var heading := _label(title,27);heading.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	header.add_child(heading);col.add_child(header)
	col.add_child(HSeparator.new())
	return col

func _home() -> void:
	_clear("home")
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left=80;panel.offset_right=470;panel.offset_top=-280;panel.offset_bottom=280
	root_ui.add_child(panel)
	var col := VBoxContainer.new();col.add_theme_constant_override("separation",14);panel.add_child(col)
	col.add_child(_label("OKEY",49,CREAM,true))
	col.add_child(_label("Kıraathane",23,MUTED))
	var gap := Control.new();gap.custom_minimum_size.y=24;col.add_child(gap)
	col.add_child(_wood_button("Oyna",_play,true))
	col.add_child(_wood_button("Karakterler",_characters))
	col.add_child(_wood_button("Ayarlar",_settings))
	col.add_child(_wood_button("Çıkış",func() -> void: get_tree().quit()))


func _characters() -> void:
	_clear("characters")

	_preview_stage = Node3D.new()
	_preview_stage.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(_preview_stage)

	var floor_mesh := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(8.0, 8.0)
	floor_mesh.mesh = fm
	floor_mesh.material_override = SurfaceStyle.textured(Color("3b2618"), SurfaceStyle.Kind.WOOD, 0.72)
	_preview_stage.add_child(floor_mesh)

	var wall_mesh := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(9.0, 5.0)
	wall_mesh.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("18100b")
	wmat.roughness = 0.95
	wall_mesh.material_override = wmat
	wall_mesh.position = Vector3(0.0, 2.2, -1.2)
	_preview_stage.add_child(wall_mesh)

	var cur_info: Dictionary = PATRON_DATA.get(_selected_card, PATRON_DATA["sabri"])
	var model_kind: String = cur_info["model"]

	var patron: Variant = RiggedPatron.new() if model_kind in RiggedPatron.KINDS else CafePatron.new()
	_preview_stage.add_child(patron)
	patron.build(model_kind)
	patron.position = Vector3(-0.92, Seat.SEAT_TOP, 0.0)
	patron.rotation.y = PI + 0.28

	var chair: Node3D = load("res://assets/models/table_details/kiraathane_chair.glb").instantiate()
	_preview_stage.add_child(chair)
	chair.position = Vector3(-0.92, 0.0, 0.0)
	chair.rotation.y = PI + 0.28

	var key_light := SpotLight3D.new()
	key_light.position = Vector3(-0.30, 2.05, 2.05)
	_preview_stage.add_child(key_light)
	key_light.look_at(Vector3(-0.92, 0.85, 0.0), Vector3.UP)
	key_light.light_color = Color("ffd9a6")
	key_light.light_energy = 1.15
	key_light.spot_range = 6.0
	key_light.spot_angle = 55.0
	key_light.shadow_enabled = true

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-0.92, 0.65, 1.55)
	fill_light.light_color = Color("ffc88a")
	fill_light.light_energy = .50
	fill_light.omni_range = 4.5
	_preview_stage.add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.25, 1.75, -0.75)
	rim_light.light_color = Color("ff9e52")
	rim_light.light_energy = .35
	rim_light.omni_range = 3.5
	_preview_stage.add_child(rim_light)

	var col := _page("Karakterler",550)
	col.add_child(_label(cur_info["title"].capitalize(),25))
	var quote := _label(str(cur_info["quote"]).replace("\n"," "),16,MUTED)
	quote.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size.y=45
	col.add_child(quote)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;col.add_child(scroll)
	var grid := GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);scroll.add_child(grid)
	for card_id in PATRON_ORDER:
		var data: Dictionary=PATRON_DATA[card_id]
		var card := _wood_button(str(data.title).capitalize(),func() -> void:
			_selected_card=card_id
			CafePreferences.cast="Dayılar";CafePreferences.companion=card_id
			_apply_companion();CafePreferences.save();_characters()
		,card_id==_selected_card,Vector2(225,78),15)
		card.icon=data.portrait;card.expand_icon=true
		card.add_theme_constant_override("icon_max_width",48)
		card.add_theme_constant_override("h_separation",12)
		card.alignment=HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(card)
	col.add_child(_wood_button("Tamam",_home,true,Vector2(0,48)))

func _table() -> void:
	_play()

func _settings() -> void:
	_clear("settings")
	var col := _page("Ayarlar",550)
	col.add_child(_label("Ses",16,MUTED))
	var volume := _label(str(roundi(CafePreferences.volume*100))+" %",16)
	col.add_child(volume)
	col.add_child(_slider(CafePreferences.volume,0,1,func(value: float) -> void:
		CafePreferences.volume=value;CafePreferences.apply();CafePreferences.save()
		volume.text=str(roundi(value*100))+" %"
	))
	col.add_child(_label("Fare hassasiyeti",16,MUTED))
	var sensitivity := _label("%.1f"%CafePreferences.sensitivity,16);col.add_child(sensitivity)
	col.add_child(_slider(CafePreferences.sensitivity,.4,2,func(value: float) -> void:
		CafePreferences.sensitivity=value;CafePreferences.save();sensitivity.text="%.1f"%value
	))
	var fullscreen := CheckButton.new();fullscreen.text="Tam ekran";fullscreen.button_pressed=CafePreferences.fullscreen
	fullscreen.toggled.connect(func(value: bool) -> void:
		CafePreferences.fullscreen=value;CafePreferences.apply();CafePreferences.save()
	)
	col.add_child(fullscreen)
	col.add_child(HSeparator.new())
	col.add_child(_label("Masa örtüsü",16,MUTED))
	var cloth := HBoxContainer.new();cloth.add_theme_constant_override("separation",10);col.add_child(cloth)
	for option in ["Bordo","Yeşil"]:
		cloth.add_child(_pill_toggle(option,CafePreferences.cloth==option,func() -> void:
			CafePreferences.cloth=option;_apply_table();CafePreferences.save();_settings()
		))
	col.add_child(_label("Oyun temposu",16,MUTED))
	var speed := HBoxContainer.new();speed.add_theme_constant_override("separation",10);col.add_child(speed)
	for option in ["NORMAL","HIZLI"]:
		speed.add_child(_pill_toggle(option.capitalize(),CafePreferences.tile_speed==option,func() -> void:
			CafePreferences.tile_speed=option;CafePreferences.save();_settings()
		))


func _slider(value: float, minimum: float, maximum: float, changed: Callable) -> HSlider:
	var s := HSlider.new()
	s.custom_minimum_size.y = 35
	s.min_value = minimum
	s.max_value = maximum
	s.step = 0.05
	s.value = value
	s.value_changed.connect(changed)
	return s


func _apply_companion() -> void:
	var chosen: String = CafePreferences.companion if CafePreferences.companion in CafePatron.KINDS or CafePreferences.companion in RiggedPatron.KINDS else "sabri"
	game.seats[0].set_character(chosen)

	# Keep this table's shuffled guests stable while browsing clothes and character cards.
	for i in 3:
		if game.seats[i + 1].character != _opponent_order[i]:
			game.seats[i + 1].set_character(_opponent_order[i])
	_set_local_hands_visible(_screen=="play")


func _set_companion(seat: Seat, kind: String) -> void:
	if is_instance_valid(seat.buddy):
		seat.buddy.queue_free()
	seat.character = kind
	seat.character_height = 0.95
	seat.buddy = Buddy.new()
	seat.buddy.position = Vector3(0, Seat.SEAT_TOP, Seat.CHAIR_DISTANCE)
	seat.add_child(seat.buddy)
	seat.buddy.setup(kind, seat.character_height)


func _apply_table() -> void:
	_apply_companion()
	game.table.set_felt_style(CafePreferences.cloth)


func _play(capture_mouse := true) -> void:
	_clear("play")
	game.randomize_player_place()
	game._turn_max=9.0 if CafePreferences.tile_speed=="HIZLI" else 16.0
	game._turn_timer=game._turn_max
	_set_local_hands_visible(true)
	layer.hide()
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	game.hud.show()
	game.hud.close_menu()
	game.camera.set_process(true)
	game.camera.mouse_control = capture_mouse
	game.camera.attributes.dof_blur_near_enabled = true
	game.camera.attributes.dof_blur_far_enabled = true
	game.camera.set_focused(false, true)
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if _screen!="home" and _screen!="play" and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		_home()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	if _screen == "characters":
		var pos := Vector3(-0.15 + sin(_time * 0.25) * 0.015, 1.05, 1.72)
		game.camera.global_transform = Transform3D(Basis.IDENTITY, pos).looking_at(Vector3(-0.15, 0.88, 0.0), Vector3.UP)
	elif _screen == "table":
		var pos := Vector3(sin(_time * 0.22) * 0.14, 1.52, 1.58)
		game.camera.global_transform = Transform3D(Basis.IDENTITY, pos).looking_at(Vector3(0, 0.85, -0.35), Vector3.UP)
	else:
		var pos := Vector3(-0.16 + sin(_time * 0.24) * 0.05, 1.32, 1.18 + cos(_time * 0.19) * 0.03)
		game.camera.global_transform = Transform3D(Basis.IDENTITY, pos).looking_at(Vector3(0.08, 0.86, -0.30), Vector3.UP)
