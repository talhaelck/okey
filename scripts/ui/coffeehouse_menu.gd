extends Node
## Coffeehouse Main Menu, Studio Character Select (Karakter Seç), and Illustrated Lobby (Lobi / Masa Kur)
## with rich painted artwork textures for the logo emblem, character portraits, and 4 venue cards.

const CREAM := Color("f4d8a8")
const GOLD := Color("e2a04a")
const MUTED := Color("b89b7c")
const DARK_WOOD := Color("24170f")

const LOGO_TEX := preload("res://assets/ui/logo_emblem.png")
const BANNER_KIRAATHANE := preload("res://assets/ui/venue_banner_kiraathane.png")

const PATRON_ORDER := ["sabri", "rifki", "temel", "davut"]

const PATRON_DATA := {
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

const VENUES := [
	{
		"id": "KIRAATHANE",
		"sub": "Galata · Sıcak Kehribar",
		"card_tex": preload("res://assets/ui/venue_kiraathane.png"),
		"banner_tex": preload("res://assets/ui/venue_banner_kiraathane.png"),
	},
	{
		"id": "SAHİL",
		"sub": "Boğaz Esintisi · Çay Bahçesi",
		"card_tex": preload("res://assets/ui/venue_sahil.png"),
		"banner_tex": preload("res://assets/ui/venue_sahil.png"),
	},
	{
		"id": "DAĞ EVİ",
		"sub": "Şömine Ateşi · Ahşap Salon",
		"card_tex": preload("res://assets/ui/venue_dagevi.png"),
		"banner_tex": preload("res://assets/ui/venue_dagevi.png"),
	},
	{
		"id": "YAZLIK",
		"sub": "Çardak Altı · Akşamüstü",
		"card_tex": preload("res://assets/ui/venue_yazlik.png"),
		"banner_tex": preload("res://assets/ui/venue_yazlik.png"),
	},
]

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


func _ready() -> void:
	CafePreferences.restore()
	_selected_card = CafePreferences.companion if PATRON_DATA.has(CafePreferences.companion) else "sabri"
	_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_font.font_weight = 700
	_display.font_names = PackedStringArray(["Georgia", "Cambria", "Arial Black"])
	_display.font_weight = 800
	game = preload("res://scenes/main.tscn").instantiate()
	game.get_node("FocusCamera").mouse_control = false
	add_child(game)
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


func _wood_button(text: String, action: Callable, primary := false, min_size := Vector2(230, 56), font_sz := 21) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_sz)
	b.add_theme_color_override("font_color", Color("261509") if primary else CREAM)
	b.add_theme_color_override("font_hover_color", Color("1b0e05") if primary else Color("fff2d6"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		if primary:
			style.bg_color = Color("dead5a") if state == "normal" else Color("f0bf6d")
			style.border_color = Color("a6722c")
		else:
			style.bg_color = Color("3b2618") if state == "normal" else Color("543723")
			style.border_color = Color("6e4b30")
		style.border_width_top = 2
		style.border_width_bottom = 4
		style.border_width_left = 2
		style.border_width_right = 2
		style.set_corner_radius_all(8)
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 6
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(action)
	return b


func _green_button(text: String, action: Callable, min_size := Vector2(270, 62)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color("f4fff2"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3a9442") if state == "normal" else Color("48b051")
		style.border_color = Color("26692c")
		style.border_width_top = 2
		style.border_width_bottom = 4
		style.set_corner_radius_all(28)
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = 8
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(action)
	return b


func _pill_toggle(text: String, active: bool, action: Callable, min_size := Vector2(108, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color("241409") if active else MUTED)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (Color("dead5a") if active else Color("1c130d")) if state == "normal" else (Color("ecc06e") if active else Color("2e2016"))
		style.border_color = Color("f2c97d") if active else Color("4a3525")
		style.set_border_width_all(1)
		style.set_corner_radius_all(18)
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(action)
	return b


func _home() -> void:
	_clear("home")

	# Illustrated OKEY KIRAATHANE Emblem (Steaming Tea Glass, 8 & ? Tiles, Mustache)
	var logo_rect := TextureRect.new()
	logo_rect.texture = LOGO_TEX
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.position = Vector2(72, 92)
	logo_rect.size = Vector2(390, 340)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(logo_rect)

	var btn_col := VBoxContainer.new()
	btn_col.position = Vector2(485, 162)
	btn_col.add_theme_constant_override("separation", 14)
	root_ui.add_child(btn_col)
	btn_col.add_child(_wood_button("OYNA", _table, true, Vector2(245, 58), 24))
	btn_col.add_child(_wood_button("KARAKTERLER", _characters, false, Vector2(245, 52), 19))
	btn_col.add_child(_wood_button("MEKANLAR", _table, false, Vector2(245, 52), 19))
	btn_col.add_child(_wood_button("AYARLAR", _settings, false, Vector2(245, 52), 19))
	btn_col.add_child(_wood_button("ÇIKIŞ", func() -> void: get_tree().quit(), false, Vector2(245, 52), 19))


func _characters() -> void:
	_clear("characters")

	var back_btn := _wood_button("←   KARAKTER SEÇ", _home, false, Vector2(240, 46), 19)
	back_btn.position = Vector2(48, 36)
	root_ui.add_child(back_btn)

	_preview_stage = Node3D.new()
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

	var patron := CafePatron.new()
	_preview_stage.add_child(patron)
	patron.build(model_kind)
	patron.position = Vector3(-0.92, 0.54, 0.0)
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
	key_light.light_energy = 1.65
	key_light.spot_range = 6.0
	key_light.spot_angle = 55.0
	key_light.shadow_enabled = true

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-0.92, 0.65, 1.55)
	fill_light.light_color = Color("ffc88a")
	fill_light.light_energy = 1.10
	fill_light.omni_range = 4.5
	_preview_stage.add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-1.25, 1.75, -0.75)
	rim_light.light_color = Color("ff9e52")
	rim_light.light_energy = 0.80
	rim_light.omni_range = 3.5
	_preview_stage.add_child(rim_light)

	# 4 Rich Illustrated Portrait Selector Cards in a vertical column
	var cards_col := VBoxContainer.new()
	cards_col.position = Vector2(720, 125)
	cards_col.add_theme_constant_override("separation", 12)
	root_ui.add_child(cards_col)

	for card_id in PATRON_ORDER:
		var active: bool = (_selected_card == card_id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(104, 104)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var st := StyleBoxFlat.new()
		st.bg_color = Color("26180f") if not active else Color("382315")
		st.border_color = GOLD if active else Color("5c4028")
		st.set_border_width_all(3 if active else 2)
		st.set_corner_radius_all(12)
		card.add_theme_stylebox_override("normal", st)
		card.add_theme_stylebox_override("hover", st)
		card.add_theme_stylebox_override("pressed", st)
		var pdata: Dictionary = PATRON_DATA[card_id]
		var ptex: Texture2D = pdata["portrait"]
		card.draw.connect(func() -> void:
			card.draw_texture_rect(ptex, Rect2(5, 5, 94, 94), false)
			card.draw_rect(Rect2(5, 5, 94, 94), GOLD if active else Color("6e4b30"), false, 2.5 if active else 1.5)
		)
		card.pressed.connect(func() -> void:
			_selected_card = card_id
			CafePreferences.cast = "Dayılar"
			CafePreferences.companion = pdata["model"]
			_apply_companion()
			CafePreferences.save()
			_characters()
		)
		cards_col.add_child(card)

	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(846, 125)
	info_panel.custom_minimum_size = Vector2(450, 444)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.11, 0.07, 0.04, 0.90)
	pstyle.border_color = Color("6e4b30")
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(14)
	pstyle.content_margin_left = 30
	pstyle.content_margin_right = 30
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	info_panel.add_theme_stylebox_override("panel", pstyle)
	root_ui.add_child(info_panel)

	var info_col := VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 14)
	info_panel.add_child(info_col)

	info_col.add_child(_label(cur_info["title"], 34, CREAM, true))
	info_col.add_child(_label(cur_info["quote"], 15, MUTED))

	var sep := HSeparator.new()
	sep.modulate = Color("6e4b30")
	info_col.add_child(sep)

	for stat_pair in cur_info["stats"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var slbl := _label(stat_pair[0], 14, CREAM)
		slbl.custom_minimum_size.x = 110
		row.add_child(slbl)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(210, 14)
		bar.max_value = 1.0
		bar.value = stat_pair[1]
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bfill := StyleBoxFlat.new()
		bfill.bg_color = GOLD
		bfill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", bfill)
		var bbg := StyleBoxFlat.new()
		bbg.bg_color = Color("2b1c12")
		bbg.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", bbg)
		row.add_child(bar)
		info_col.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	info_col.add_child(spacer)

	info_col.add_child(_wood_button("SEÇ", _table, true, Vector2(240, 54), 22))


func _table() -> void:
	_clear("table")

	var back_btn := _wood_button("←   LOBBİ", _home, false, Vector2(180, 44), 19)
	back_btn.position = Vector2(48, 32)
	root_ui.add_child(back_btn)

	var invite_btn := _pill_toggle("👥  Arkadaşını Davet Et   +", false, func() -> void: pass, Vector2(236, 42))
	invite_btn.position = Vector2(1304, 32)
	root_ui.add_child(invite_btn)

	var lobby_panel := PanelContainer.new()
	lobby_panel.position = Vector2(280, 102)
	lobby_panel.custom_minimum_size = Vector2(1040, 596)
	var lstyle := StyleBoxFlat.new()
	lstyle.bg_color = Color(0.08, 0.05, 0.03, 0.94)
	lstyle.border_color = Color("6e4b30")
	lstyle.set_border_width_all(2)
	lstyle.set_corner_radius_all(18)
	lstyle.content_margin_left = 36
	lstyle.content_margin_right = 36
	lstyle.content_margin_top = 22
	lstyle.content_margin_bottom = 22
	lobby_panel.add_theme_stylebox_override("panel", lstyle)
	root_ui.add_child(lobby_panel)

	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 12)
	lobby_panel.add_child(lcol)

	var v_names := ["KIRAATHANE", "SAHİL", "DAĞ EVİ", "YAZLIK"]
	var cur_idx := maxi(0, v_names.find(CafePreferences.venue))
	var cur_vdata: Dictionary = VENUES[cur_idx]

	# 1. Top Large Illustrated Panoramic Venue Banner (just like reference image!)
	var banner := Control.new()
	banner.custom_minimum_size = Vector2(640, 156)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var b_tex: Texture2D = cur_vdata["banner_tex"]
	banner.draw.connect(func() -> void:
		banner.draw_rect(Rect2(0, 0, 640, 156), Color("1a0f08"), true)
		banner.draw_texture_rect(b_tex, Rect2(4, 4, 632, 148), false)
		# Subtle bottom gradient strip for venue mood subtitle
		banner.draw_rect(Rect2(4, 118, 632, 34), Color(0.06, 0.03, 0.01, 0.72), true)
		banner.draw_string(_font, Vector2(20, 141), cur_vdata["id"] + "  ·  " + cur_vdata["sub"], HORIZONTAL_ALIGNMENT_CENTER, 600, 14, Color("f5dfa8"))
		banner.draw_rect(Rect2(2, 2, 636, 152), GOLD, false, 2.5)
	)
	lcol.add_child(banner)

	# 2. Venue Carousel Title & Arrows (< KIRAATHANE >)
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 28)
	lcol.add_child(nav_row)

	nav_row.add_child(_pill_toggle("‹", false, func() -> void:
		CafePreferences.venue = v_names[(cur_idx - 1 + v_names.size()) % v_names.size()]
		CafePreferences.save()
		_table()
	, Vector2(44, 38)))

	var v_title := _label(CafePreferences.venue, 28, CREAM, true)
	v_title.custom_minimum_size.x = 240
	v_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(v_title)

	nav_row.add_child(_pill_toggle("›", false, func() -> void:
		CafePreferences.venue = v_names[(cur_idx + 1) % v_names.size()]
		CafePreferences.save()
		_table()
	, Vector2(44, 38)))

	# 3. 4 Rich Illustrated Venue Cards Row (KIRAATHANE · SAHİL · DAĞ EVİ · YAZLIK)
	var venue_row := HBoxContainer.new()
	venue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	venue_row.add_theme_constant_override("separation", 16)
	lcol.add_child(venue_row)

	for vdata in VENUES:
		var vid: String = vdata["id"]
		var active: bool = (CafePreferences.venue == vid)
		var c_tex: Texture2D = vdata["card_tex"]
		var vcard := Button.new()
		vcard.custom_minimum_size = Vector2(220, 148)
		vcard.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vst := StyleBoxFlat.new()
		vst.bg_color = Color("24150c") if active else Color("170e08")
		vst.border_color = GOLD if active else Color("543a24")
		vst.set_border_width_all(3 if active else 1)
		vst.set_corner_radius_all(12)
		vcard.add_theme_stylebox_override("normal", vst)
		vcard.add_theme_stylebox_override("hover", vst)
		vcard.add_theme_stylebox_override("pressed", vst)
		vcard.draw.connect(func() -> void:
			# Rich illustrated artwork filling upper portion of the card
			vcard.draw_texture_rect(c_tex, Rect2(5, 5, 210, 94), false)
			vcard.draw_rect(Rect2(5, 5, 210, 94), GOLD if active else Color("4a3320"), false, 1.5)
			# Crisp title & subtitle below the artwork
			vcard.draw_string(_font, Vector2(10, 121), vid, HORIZONTAL_ALIGNMENT_CENTER, 200, 17, CREAM if active else Color("d8c09e"))
			vcard.draw_string(_font, Vector2(8, 139), vdata["sub"], HORIZONTAL_ALIGNMENT_CENTER, 204, 11, GOLD if active else MUTED)
		)
		vcard.pressed.connect(func() -> void:
			CafePreferences.venue = vid
			CafePreferences.save()
			_table()
		)
		venue_row.add_child(vcard)

	# 4. Match Options Row (MASA TÜRÜ · TAŞ HIZI · MASA ÇUHASI)
	var opts_row := HBoxContainer.new()
	opts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opts_row.add_theme_constant_override("separation", 42)
	lcol.add_child(opts_row)

	var mode_col := VBoxContainer.new()
	mode_col.add_theme_constant_override("separation", 8)
	mode_col.add_child(_label("MASA TÜRÜ", 13, MUTED))
	var mode_pills := HBoxContainer.new()
	mode_pills.add_theme_constant_override("separation", 10)
	for m_opt in ["4 KİŞİ", "2 KİŞİ"]:
		mode_pills.add_child(_pill_toggle(m_opt, CafePreferences.table_mode == m_opt, func() -> void:
			CafePreferences.table_mode = m_opt
			CafePreferences.save()
			_table()
		))
	mode_col.add_child(mode_pills)
	opts_row.add_child(mode_col)

	var spd_col := VBoxContainer.new()
	spd_col.add_theme_constant_override("separation", 8)
	spd_col.add_child(_label("TAŞ HIZI", 13, MUTED))
	var spd_pills := HBoxContainer.new()
	spd_pills.add_theme_constant_override("separation", 10)
	for s_opt in ["NORMAL", "HIZLI"]:
		spd_pills.add_child(_pill_toggle(s_opt, CafePreferences.tile_speed == s_opt, func() -> void:
			CafePreferences.tile_speed = s_opt
			CafePreferences.save()
			_table()
		))
	spd_col.add_child(spd_pills)
	opts_row.add_child(spd_col)

	var cloth_col := VBoxContainer.new()
	cloth_col.add_theme_constant_override("separation", 8)
	cloth_col.add_child(_label("MASA ÇUHASI", 13, MUTED))
	var cloth_pills := HBoxContainer.new()
	cloth_pills.add_theme_constant_override("separation", 10)
	for c_opt in ["Bordo", "Yeşil"]:
		cloth_pills.add_child(_pill_toggle(c_opt.to_upper(), CafePreferences.cloth == c_opt, func() -> void:
			CafePreferences.cloth = c_opt
			_apply_table()
			CafePreferences.save()
			_table()
		))
	cloth_col.add_child(cloth_pills)
	opts_row.add_child(cloth_col)

	var launch_row := HBoxContainer.new()
	launch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lcol.add_child(launch_row)
	launch_row.add_child(_green_button("MASA KUR", _play, Vector2(290, 62)))


func _settings() -> void:
	_clear("settings")
	var back_btn := _wood_button("←   AYARLAR", _home, false, Vector2(210, 44), 19)
	back_btn.position = Vector2(48, 36)
	root_ui.add_child(back_btn)

	var spanel := PanelContainer.new()
	spanel.position = Vector2(360, 130)
	spanel.custom_minimum_size = Vector2(520, 360)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.10, 0.07, 0.04, 0.90)
	pstyle.border_color = Color("6e4b30")
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(14)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 28
	pstyle.content_margin_bottom = 28
	spanel.add_theme_stylebox_override("panel", pstyle)
	root_ui.add_child(spanel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	spanel.add_child(col)

	col.add_child(_label("SES SEVİYESİ", 15, CREAM))
	col.add_child(_slider(CafePreferences.volume, 0, 1, func(val: float) -> void:
		CafePreferences.volume = val
		CafePreferences.apply()
	))

	col.add_child(_label("FARE HASSASİYETİ", 15, CREAM))
	col.add_child(_slider(CafePreferences.sensitivity, 0.4, 2.0, func(val: float) -> void:
		CafePreferences.sensitivity = val
	))

	col.add_child(_wood_button("TAM EKRAN: " + ("AÇIK" if CafePreferences.fullscreen else "KAPALI"), func() -> void:
		CafePreferences.fullscreen = not CafePreferences.fullscreen
		CafePreferences.apply()
		_settings()
	, false, Vector2(320, 48), 18))

	col.add_child(_wood_button("KAYDET VE DÖN", func() -> void:
		CafePreferences.save()
		_home()
	, true, Vector2(320, 52), 20))


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
	var chosen: String = CafePreferences.companion if CafePreferences.companion in CafePatron.KINDS else "sabri"
	game.seats[0].set_character(chosen)

	# The 3 opponents take the remaining 3 coffeehouse patrons
	var all_kinds := ["sabri", "temel", "rifki", "davut"]
	var opp_kinds: Array = []
	for k in all_kinds:
		if k != chosen:
			opp_kinds.append(k)

	for i in 3:
		game.seats[i + 1].set_character(opp_kinds[i])


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
	for mi: MeshInstance3D in game.table.find_children("*", "MeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial and mi.material_override.shader == preload("res://assets/shaders/okey_felt.gdshader"):
			var felt: Color = Color("3c1816") if CafePreferences.cloth == "Bordo" else Color("173928")
			mi.material_override.set_shader_parameter("felt_color", felt)


func _play(capture_mouse := true) -> void:
	_clear("play")
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
