class_name Hud
extends CanvasLayer
## Quiet game view; controls, scores and navigation live in the pause menu.

var camera: FocusCamera
var _crosshair := Control.new()
var _hint := Label.new()
var _score := Label.new()
var _flash := Label.new()
var _risk := ProgressBar.new()
var _ability := Control.new()
var _ability_key := Label.new()
var _menu := Control.new()
var _pause_page := VBoxContainer.new()
var _help_page := VBoxContainer.new()
var _resume_button := Button.new()
var _menu_panel := PanelContainer.new()
var _help_button := Button.new()
var _font := SystemFont.new()
var _flash_tween: Tween
var _hint_tween: Tween
var _saved_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _cooldown_fraction := 0.0
var _danger := 0.0
var _interactive := false
var _observe := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_font.font_weight = 500
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var color := Color("cfbd98") if _interactive else Color(0.85,0.83,0.76,0.45)
		if _danger > 0.0:
			color = color.lerp(Color("dc925b"),_danger)
		_crosshair.draw_circle(Vector2.ZERO,1.6 if _interactive else 1.0,color))
	add_child(_crosshair)
	_place(_hint,15,Vector4(0.5,1,0.5,1),Vector4(-220,-80,220,-52))
	_hint.modulate.a = 0.0
	_place(_flash,17,Vector4(0.5,0,0.5,0),Vector4(-300,36,300,66))
	_flash.modulate.a = 0.0
	_ability.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_ability.offset_left = 32
	_ability.offset_right = 64
	_ability.offset_top = -58
	_ability.offset_bottom = -26
	_ability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability.draw.connect(func() -> void:
		_ability.draw_circle(Vector2(16,16),15,Color(0.035,0.03,0.025,0.65))
		_ability.draw_arc(Vector2(16,16),15,-PI/2,TAU*(1.0-_cooldown_fraction)-PI/2,36,Color(0.75,0.65,0.47,0.6),1.5,true))
	add_child(_ability)
	_style_label(_ability_key,13,Color("d0c2a7"))
	_ability_key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ability_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ability_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability.add_child(_ability_key)
	var help := _help_button
	help.text = "?"
	help.tooltip_text = "Kontroller · F1"
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help.offset_left = -60
	help.offset_right = -28
	help.offset_top = -58
	help.offset_bottom = -26
	_style_button(help)
	help.pressed.connect(func() -> void: open_menu(true))
	add_child(help)
	_risk.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_risk.offset_left = -70
	_risk.offset_right = 70
	_risk.offset_top = -44
	_risk.offset_bottom = -40
	_risk.max_value = 1.0
	_risk.show_percentage = false
	_risk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ce8a56")
	fill.set_corner_radius_all(2)
	_risk.add_theme_stylebox_override("fill",fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0,0,0,0.25)
	_risk.add_theme_stylebox_override("background",back)
	add_child(_risk)
	_risk.hide()
	_build_menu()
	get_window().focus_exited.connect(func() -> void:
		if camera != null and camera.mouse_control and not _menu.visible:
			open_menu())

func _build_menu() -> void:
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.012,0.015,0.014,0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	var panel := _menu_panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -260
	panel.offset_bottom = 260
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("251a14")
	skin.border_color = Color(0.67,0.55,0.36,0.28)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(12)
	skin.content_margin_left = 32
	skin.content_margin_right = 32
	skin.content_margin_top = 28
	skin.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel",skin)
	_menu.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",20)
	panel.add_child(stack)
	var title := _text("Okey Kıraathane",27,Color("f2d3a0"))
	stack.add_child(title)
	stack.add_child(HSeparator.new())
	stack.add_child(_pause_page)
	stack.add_child(_help_page)
	_pause_page.add_theme_constant_override("separation",14)
	_pause_page.add_child(_text("Oyun duraklatıldı",15,Color("9daba3")))
	_style_label(_score,14,Color("aaa58f"))
	_pause_page.add_child(_score)
	_resume_button.text = "Oyuna dön"
	_style_button(_resume_button)
	_resume_button.pressed.connect(close_menu)
	_pause_page.add_child(_resume_button)
	var controls := Button.new()
	controls.text = "Kontroller"
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
	_help_page.add_theme_constant_override("separation",10)
	_help_page.add_child(_text("Kontroller",18,Color("e0d3b8")))
	for row in [["Fare","Etrafa bak"],["Space / Sağ tık","Masaya / ıstakaya odaklan"],["Sol tık","Taşı al veya bırak"],["Q","Masaya vur · elin boşken"],["S","Taşları sırala · ıstakadayken"],["Esc","Duraklat / devam et"]]:
		var line := HBoxContainer.new()
		var key := _text(row[0],14,Color("d2b47e"))
		key.custom_minimum_size.x = 135
		line.add_child(key)
		line.add_child(_text(row[1],14,Color("b9c0b8")))
		_help_page.add_child(line)
	var back_button := Button.new()
	back_button.text = "Geri"
	_style_button(back_button)
	back_button.pressed.connect(func() -> void: open_menu(false))
	_help_page.add_child(back_button)
	_menu.hide()
	set_score(0,0)

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

func open_menu(controls := false) -> void:
	if not _menu.visible:
		_saved_mouse_mode = Input.mouse_mode
	_menu.show()
	_menu_panel.offset_top = -240
	_menu_panel.offset_bottom = 240
	_pause_page.visible = not controls
	_help_page.visible = controls
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_crosshair.hide()
	_hint.hide()
	_risk.hide()
	_ability.hide()
	_help_button.hide()
	if not controls:
		_resume_button.grab_focus()

func close_menu() -> void:
	_menu.hide()
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse_mode
	show_crosshair(_observe)
	_hint.visible = not _hint.text.is_empty()
	_ability.show()
	_help_button.show()

func set_table_state(_watchers: Array[Watcher], focused: bool, cooldown: float, exposure: float, stealing: bool, _holding := false) -> void:
	_observe = not focused
	_cooldown_fraction = clampf(cooldown/8.0,0,1) if not focused else 0.0
	_ability_key.text = "S" if focused else "Q"
	_ability.queue_redraw()
	_danger = exposure if stealing and not focused else 0.0
	_risk.visible = _danger > 0.05 and not _menu.visible
	_risk.value = _danger
	_crosshair.queue_redraw()

func show_crosshair(on: bool) -> void:
	_crosshair.visible = on and not _menu.visible

func set_hint(value: String) -> void:
	var text := value.replace("Sol tık: ","")
	if text == "Taşı bir ıstakaya ya da masaya götür":
		text = "Bırakacağın yeri seç"
	elif not text.is_empty():
		text = "Sol tık · " + text.capitalize()
	_interactive = not text.is_empty()
	if _hint.text == text:
		return
	_hint.text = text
	_hint.visible = not _menu.visible and not text.is_empty()
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint,"modulate:a",0.8 if not text.is_empty() else 0.0,0.12)

func set_score(stolen: int, caught: int) -> void:
	_score.text = "Başarılı çalma  %d     ·     Yakalanma  %d" % [stolen,caught]

func flash(text: String, color: Color) -> void:
	_flash.text = text
	_flash.label_settings.font_color = color.lerp(Color("d7cfbd"),0.5)
	if _flash_tween:
		_flash_tween.kill()
	_flash.modulate.a = 0.0
	_flash.position.y = 26
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash,"modulate:a",0.95,0.15)
	_flash_tween.tween_property(_flash,"position:y",36.0,0.18)
	_flash_tween.chain().tween_interval(1.5)
	_flash_tween.chain().tween_property(_flash,"modulate:a",0.0,0.25)

func _style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font",_font)
	label.add_theme_font_size_override("font_size",size)
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = size
	settings.font_color = color
	settings.shadow_color = Color(0,0,0,0.6)
	settings.shadow_size = 2
	settings.shadow_offset = Vector2(0,1)
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	_style_label(label,size,color)
	label.text = value
	return label

func _place(label: Label, size: int, anchors: Vector4, offsets: Vector4) -> void:
	_style_label(label,size,Color("d7cebb"))
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
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font",_font)
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",Color("d8d6c9"))
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3b291e") if state == "normal" else Color("644329")
		style.set_corner_radius_all(6)
		style.border_color = Color(0.65,0.57,0.39,0.6 if state == "focus" else 0.15)
		style.set_border_width_all(1)
		button.add_theme_stylebox_override(state,style)
