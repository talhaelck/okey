class_name Hud
extends CanvasLayer
## Atmospheric Kahvehane HUD: Turn & Okey status bar, interactive crosshair, quick-action bar,
## sunglasses/spill screen effects, and right-side banter pills (clickable or keys 1-6).

signal banter_spoken(phrase: String)
signal action_requested(action_id: String)

var camera: FocusCamera
var _glasses_tint := ColorRect.new()
var _crosshair := Control.new()
var _top_panel := PanelContainer.new()
var _turn_label := Label.new()
var _okey_label := Label.new()
var _stats_label := Label.new()
var _turn_bar := ProgressBar.new()
var _mode_badge := Label.new()

var _hint := Label.new()
var _score := Label.new()
var _flash := Label.new()
var _risk := ProgressBar.new()
var _action_bar := HBoxContainer.new()
var _help_button := Button.new()
var _banter_box := VBoxContainer.new()

var _menu := Control.new()
var _pause_page := VBoxContainer.new()
var _help_page := VBoxContainer.new()
var _resume_button := Button.new()
var _menu_panel := PanelContainer.new()

var _font := SystemFont.new()
var _flash_tween: Tween
var _hint_tween: Tween
var _saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _danger := 0.0
var _interactive := false
var _observe := true

const BANTER_ICON := preload("res://assets/ui/portrait_sabri.png")
const BANTER_LINES := [
	"Helal!",
	"Yok artık!",
	"Nasıl ya?",
	"Dayı sakin",
	"Çay koy!",
	"Taş ver!",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_font.font_weight = 600

	# Sunglasses / effect tint overlay
	_glasses_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glasses_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glasses_tint.color = Color(0.14, 0.09, 0.03, 0.0)
	add_child(_glasses_tint)

	# Center Crosshair
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var color := Color("ffdc8a") if _interactive else Color(0.90, 0.86, 0.76, 0.55)
		if _danger > 0.0:
			color = color.lerp(Color("ff5a36"), _danger)
		var r := 3.2 if _interactive else 1.8
		_crosshair.draw_circle(Vector2.ZERO, r + 1.2, Color(0, 0, 0, 0.55))
		_crosshair.draw_circle(Vector2.ZERO, r, color)
		if _interactive:
			_crosshair.draw_arc(Vector2.ZERO, 7.5, 0, TAU, 24, Color(color.r, color.g, color.b, 0.65), 1.3, true)
	)
	add_child(_crosshair)

	_build_top_status()
	_build_bottom_bar()

	_place(_hint, 13, Vector4(0.5, 1, 0.5, 1), Vector4(-240, -42, 240, -12))
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.08, 0.05, 0.03, 0.82)
	h_style.border_color = Color("6e4b30")
	h_style.set_border_width_all(1)
	h_style.set_corner_radius_all(12)
	h_style.content_margin_left = 14
	h_style.content_margin_right = 14
	_hint.add_theme_stylebox_override("normal", h_style)
	_hint.modulate.a = 0.0
	_place(_flash, 17, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 24, 300, 54))
	_flash.modulate.a = 0.0

	var help := _help_button
	help.text = "?"
	help.tooltip_text = "Kontroller · F1"
	help.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help.offset_left = -56
	help.offset_right = -20
	help.offset_top = 16
	help.offset_bottom = 52
	_style_button(help)
	help.pressed.connect(func() -> void: open_menu(true))
	add_child(help)

	_risk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_risk.offset_left = -95
	_risk.offset_right = 95
	_risk.offset_top = -54
	_risk.offset_bottom = -47
	_risk.max_value = 1.0
	_risk.show_percentage = false
	_risk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e26a3c")
	fill.set_corner_radius_all(3)
	_risk.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	_risk.add_theme_stylebox_override("background", back)
	add_child(_risk)
	_risk.hide()

	_build_banter()
	_build_menu()
	get_window().focus_exited.connect(func() -> void:
		if camera != null and camera.mouse_control and not _menu.visible:
			open_menu())


func _build_top_status() -> void:
	_top_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_panel.offset_left = 18
	_top_panel.offset_top = 16
	_top_panel.offset_right = 410
	_top_panel.offset_bottom = 114
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.07, 0.04, 0.84)
	st.border_color = Color(0.76, 0.56, 0.30, 0.48)
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	_top_panel.add_theme_stylebox_override("panel", st)
	add_child(_top_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_top_panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)
	_style_label(_turn_label, 15, Color("ffd78a"))
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_turn_label)

	_style_label(_mode_badge, 12, Color("b9cfa6"))
	top_row.add_child(_mode_badge)

	_turn_bar.custom_minimum_size = Vector2(0, 5)
	_turn_bar.max_value = 1.0
	_turn_bar.value = 1.0
	_turn_bar.show_percentage = false
	var tf := StyleBoxFlat.new()
	tf.bg_color = Color("e5a94c")
	tf.set_corner_radius_all(2)
	_turn_bar.add_theme_stylebox_override("fill", tf)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0, 0, 0, 0.35)
	_turn_bar.add_theme_stylebox_override("background", tb)
	vbox.add_child(_turn_bar)

	_style_label(_okey_label, 13, Color("e6d4b5"))
	vbox.add_child(_okey_label)

	_style_label(_stats_label, 12, Color("b8b09c"))
	vbox.add_child(_stats_label)


func _build_bottom_bar() -> void:
	_action_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_action_bar.offset_left = 18
	_action_bar.offset_right = 620
	_action_bar.offset_top = -42
	_action_bar.offset_bottom = -14
	_action_bar.add_theme_constant_override("separation", 6)
	add_child(_action_bar)

	var actions := [
		["focus", "Istaka [Boşluk]"],
		["draw", "Taş Çek [D]"],
		["sort", "Per Diz [S]"],
		["knock", "Masaya Vur [Q]"],
		["blackout", "Şalter [K]"],
		["finish", "Eli Aç [G]"],
	]
	for item in actions:
		var b := Button.new()
		b.text = item[1]
		b.custom_minimum_size = Vector2(0, 26)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color("ebd6b0"))
		for state in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.10, 0.06, 0.04, 0.75) if state == "normal" else Color(0.24, 0.15, 0.08, 0.90)
			st.border_color = Color(0.65, 0.45, 0.25, 0.40)
			st.set_border_width_all(1)
			st.set_corner_radius_all(6)
			st.content_margin_left = 8
			st.content_margin_right = 8
			b.add_theme_stylebox_override(state, st)
		var act_id: String = item[0]
		b.pressed.connect(func() -> void: action_requested.emit(act_id))
		_action_bar.add_child(b)


func _build_banter() -> void:
	_banter_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_banter_box.offset_left = -260
	_banter_box.offset_right = -18
	_banter_box.offset_top = -364
	_banter_box.offset_bottom = -14
	_banter_box.add_theme_constant_override("separation", 8)
	add_child(_banter_box)

	var pills_col := VBoxContainer.new()
	pills_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	pills_col.add_theme_constant_override("separation", 7)
	_banter_box.add_child(pills_col)

	for i in BANTER_LINES.size():
		var phrase: String = BANTER_LINES[i]
		var b := Button.new()
		b.text = "       %s" % phrase
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(168, 42)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color("f2d8a8"))
		for state in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.13, 0.08, 0.05, 0.86) if state == "normal" else Color(0.26, 0.17, 0.10, 0.94)
			st.border_color = Color(0.75, 0.54, 0.30, 0.42)
			st.set_border_width_all(1)
			st.set_corner_radius_all(21)
			st.content_margin_left = 14
			b.add_theme_stylebox_override(state, st)
		var icon_rect := TextureRect.new()
		icon_rect.texture = BANTER_ICON
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(8, 7)
		icon_rect.size = Vector2(28, 28)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon_rect)
		b.pressed.connect(func() -> void:
			flash("💬  " + phrase, Color("f0b865"))
			banter_spoken.emit(phrase)
		)
		pills_col.add_child(b)

	var chat_row := HBoxContainer.new()
	chat_row.add_theme_constant_override("separation", 6)
	_banter_box.add_child(chat_row)

	var input := LineEdit.new()
	input.placeholder_text = "Mesaj yaz..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(190, 38)
	input.add_theme_font_override("font", _font)
	input.add_theme_font_size_override("font_size", 13)
	input.add_theme_color_override("font_color", Color("f2dfc0"))
	input.add_theme_color_override("font_placeholder_color", Color(0.68, 0.60, 0.49, 0.72))
	for state in ["normal", "focus"]:
		var ist := StyleBoxFlat.new()
		ist.bg_color = Color(0.09, 0.06, 0.04, 0.88)
		ist.border_color = Color(0.68, 0.49, 0.28, 0.45 if state == "normal" else 0.85)
		ist.set_border_width_all(1)
		ist.set_corner_radius_all(19)
		ist.content_margin_left = 14
		ist.content_margin_right = 12
		input.add_theme_stylebox_override(state, ist)
	chat_row.add_child(input)

	var send_btn := Button.new()
	send_btn.text = "➤"
	send_btn.custom_minimum_size = Vector2(38, 38)
	send_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	send_btn.add_theme_font_override("font", _font)
	send_btn.add_theme_font_size_override("font_size", 15)
	send_btn.add_theme_color_override("font_color", Color("f7e4c0"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var sst := StyleBoxFlat.new()
		sst.bg_color = Color(0.18, 0.11, 0.07, 0.90) if state == "normal" else Color(0.32, 0.20, 0.11, 0.96)
		sst.border_color = Color(0.76, 0.56, 0.31, 0.52)
		sst.set_border_width_all(1)
		sst.set_corner_radius_all(19)
		send_btn.add_theme_stylebox_override(state, sst)
	var submit_chat := func() -> void:
		var msg := input.text.strip_edges()
		if not msg.is_empty():
			flash("💬  " + msg, Color("f0b865"))
			banter_spoken.emit(msg)
			input.clear()
		input.release_focus()
	send_btn.pressed.connect(submit_chat)
	input.text_submitted.connect(func(_t: String) -> void: submit_chat.call())
	chat_row.add_child(send_btn)


func _build_menu() -> void:
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.012, 0.015, 0.014, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	var panel := _menu_panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -265
	panel.offset_right = 265
	panel.offset_top = -275
	panel.offset_bottom = 275
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("251a14")
	skin.border_color = Color(0.67, 0.55, 0.36, 0.28)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(12)
	skin.content_margin_left = 32
	skin.content_margin_right = 32
	skin.content_margin_top = 26
	skin.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", skin)
	_menu.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	panel.add_child(stack)
	var title := _text("Okey Kıraathane", 27, Color("f2d3a0"))
	stack.add_child(title)
	stack.add_child(HSeparator.new())
	stack.add_child(_pause_page)
	stack.add_child(_help_page)
	_pause_page.add_theme_constant_override("separation", 14)
	_pause_page.add_child(_text("Oyun duraklatıldı", 15, Color("9daba3")))
	_style_label(_score, 14, Color("aaa58f"))
	_pause_page.add_child(_score)
	_resume_button.text = "Oyuna dön"
	_style_button(_resume_button)
	_resume_button.pressed.connect(close_menu)
	_pause_page.add_child(_resume_button)
	var controls := Button.new()
	controls.text = "Kontroller & Sabotaj Rehberi"
	_style_button(controls)
	controls.pressed.connect(func() -> void: open_menu(true))
	_pause_page.add_child(controls)
	var home_button := Button.new()
	home_button.text = "Ana menü · masadan ayrıl"
	_style_button(home_button)
	home_button.pressed.connect(func() -> void:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/coffeehouse.tscn"))
	_pause_page.add_child(home_button)
	var quit_button := Button.new()
	quit_button.text = "Oyundan çık"
	_style_button(quit_button)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_pause_page.add_child(quit_button)
	_help_page.add_theme_constant_override("separation", 8)
	_help_page.add_child(_text("Kontroller & Sabotajlar", 18, Color("e0d3b8")))
	var help_rows := [
		["Fare + WASD", "Etrafa bak & masaya doğru eğil"],
		["Space / Sağ Tık", "Masa Görünümü ↔ Istaka Görünümü"],
		["Sol Tık (Masa)", "Çay/Kahve iç, Çay devir, Leblebi at, Duman üfle"],
		["Sol Tık (Taş)", "Ortadan/Yandan taş çek, Rakip ıstakasından çal"],
		["D / F", "Hızlı taş çek [D] · Üzerindeki taşı sağa at [F]"],
		["S / G", "Taşları diz [S] · Eli aç / Okey bitir [G]"],
		["Q / K", "Masaya vur [Q] · Karanlıkta Okey şalteri [K]"],
		["1 - 6 / Tab", "Muhabbet replikleri · Fare imlecini serbest bırak"],
	]
	for row in help_rows:
		var line := HBoxContainer.new()
		var key := _text(row[0], 13, Color("d2b47e"))
		key.custom_minimum_size.x = 145
		line.add_child(key)
		line.add_child(_text(row[1], 13, Color("b9c0b8")))
		_help_page.add_child(line)
	var back_button := Button.new()
	back_button.text = "Geri"
	_style_button(back_button)
	back_button.pressed.connect(func() -> void: open_menu(false))
	_help_page.add_child(back_button)
	_menu.hide()
	set_score(0, 0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _menu.visible:
				close_menu()
			else:
				open_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1:
			open_menu(true)
			get_viewport().set_input_as_handled()
		elif not _menu.visible and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var idx: int = event.keycode - KEY_1
			if idx >= 0 and idx < BANTER_LINES.size():
				var phrase: String = BANTER_LINES[idx]
				flash("💬  " + phrase, Color("f0b865"))
				banter_spoken.emit(phrase)
				get_viewport().set_input_as_handled()


func open_menu(controls := false) -> void:
	if not _menu.visible:
		_saved_mouse_mode = Input.mouse_mode
	_menu.show()
	_menu_panel.offset_top = -265
	_menu_panel.offset_bottom = 265
	_pause_page.visible = not controls
	_help_page.visible = controls
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.hide()
	_hint.hide()
	_risk.hide()
	_action_bar.hide()
	_help_button.hide()
	if not controls:
		_resume_button.grab_focus()


func close_menu() -> void:
	_menu.hide()
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse_mode
	show_crosshair(_observe)
	_hint.visible = not _hint.text.is_empty()
	_action_bar.show()
	_help_button.show()


func update_match_hud(turn_text: String, turn_ratio: float, okey_text: String, stats_text: String, mode_text: String, glasses_on: bool) -> void:
	_turn_label.text = turn_text
	_turn_bar.value = clampf(turn_ratio, 0.0, 1.0)
	_okey_label.text = okey_text
	_stats_label.text = stats_text
	_mode_badge.text = mode_text + ("  ·  🕶️ GÖZLÜK (X-RAY AÇIK)" if glasses_on else "")
	var target_alpha := 0.28 if glasses_on else 0.0
	_glasses_tint.color.a = lerpf(_glasses_tint.color.a, target_alpha, 0.15)


func set_table_state(_watchers: Array[Watcher], focused: bool, _cooldown: float, exposure: float, stealing: bool, _holding := false) -> void:
	_observe = not focused
	_danger = exposure if stealing and not focused else 0.0
	_risk.visible = _danger > 0.05 and not _menu.visible
	_risk.value = _danger
	_crosshair.queue_redraw()


func show_crosshair(on: bool) -> void:
	_crosshair.visible = on and not _menu.visible


func set_hint(value: String) -> void:
	var text := value
	_interactive = not text.is_empty()
	_crosshair.queue_redraw()
	if _hint.text == text:
		return
	_hint.text = text
	_hint.visible = not _menu.visible and not text.is_empty()
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 0.92 if not text.is_empty() else 0.0, 0.10)


func set_score(stolen: int, caught: int) -> void:
	_score.text = "Başarılı çalma: %d     ·     Yakalanma: %d" % [stolen, caught]


func flash(text: String, color: Color) -> void:
	_flash.text = text
	_flash.label_settings.font_color = color.lerp(Color("f5ebd6"), 0.35)
	if _flash_tween:
		_flash_tween.kill()
	_flash.modulate.a = 0.0
	_flash.position.y = 20
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash, "modulate:a", 0.98, 0.14)
	_flash_tween.tween_property(_flash, "position:y", 30.0, 0.16)
	_flash_tween.chain().tween_interval(1.8)
	_flash_tween.chain().tween_property(_flash, "modulate:a", 0.0, 0.25)


func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = size
	settings.font_color = color
	settings.shadow_color = Color(0, 0, 0, 0.68)
	settings.shadow_size = 2
	settings.shadow_offset = Vector2(0, 1)
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	_style_label(label, size, color)
	label.text = value
	return label


func _place(label: Label, size: int, anchors: Vector4, offsets: Vector4) -> void:
	_style_label(label, size, Color("eee4d0"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.offset_left = offsets.x
	label.offset_top = offsets.y
	label.offset_right = offsets.z
	label.offset_bottom = offsets.w
	add_child(label)


func _style_button(button: Button) -> void:
	button.custom_minimum_size.y = 42
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("d8d6c9"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3b291e") if state == "normal" else Color("644329")
		style.set_corner_radius_all(6)
		style.border_color = Color(0.65, 0.57, 0.39, 0.6 if state == "focus" else 0.15)
		style.set_border_width_all(1)
		button.add_theme_stylebox_override(state, style)
