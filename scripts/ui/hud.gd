class_name Hud
extends CanvasLayer
## Screen overlay: crosshair (observe mode), action hint, score, controls help and big event flashes.

var _crosshair := Control.new()
var _hint := Label.new()
var _score := Label.new()
var _flash := Label.new()
var _flash_tween: Tween
var _font := SystemFont.new()


func _ready() -> void:
	_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	_font.font_weight = 500

	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.draw.connect(func() -> void:
		_crosshair.draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.3))
		_crosshair.draw_circle(Vector2.ZERO, 1.5, Color(0.92, 0.85, 0.67, 0.7)))
	add_child(_crosshair)

	# Centred labels span the screen; equal top/bottom offsets shift them up or down from the middle.
	var title := Label.new()
	_label(title, 23, Vector4(0,0,0,0), Vector4(30,21,320,55))
	title.text = "S N E A K Y   O K E Y"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var subtitle := Label.new()
	_label(subtitle, 11, Vector4(0,0,0,0), Vector4(32,55,400,76))
	subtitle.text = "SON EL  /  GECE KAHVEHANESİ"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.modulate = Color("c2a879")
	_label(_hint, 17, Vector4(0, 1, 1, 1), Vector4(0, -125, 0, -95))
	_label(_score, 14, Vector4(1, 0, 1, 0), Vector4(-400, 28, -32, 60))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score.modulate = Color("dacbb2")
	var footer := Panel.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 26
	footer.offset_right = -26
	footer.offset_top = -57
	footer.offset_bottom = -20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03,0.025,0.02,0.72)
	panel.border_color = Color(0.65,0.52,0.32,0.2)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	footer.add_theme_stylebox_override("panel", panel)
	add_child(footer)
	var help := Label.new()
	_label(help, 13, Vector4(0, 1, 1, 1), Vector4(30, -54, -30, -23))
	help.text = "FARE  Etrafa bak     ·     SPACE / SAĞ TIK  Istakana odaklan     ·     SOL TIK  Taş al / bırak     ·     ESC  Fareyi bırak"
	help.modulate = Color("c9bfab")
	_label(_flash, 42, Vector4(0, 0, 1, 1), Vector4(0, -150, 0, -150))
	_flash.modulate.a = 0.0

	set_score(0, 0)


func show_crosshair(on: bool) -> void:
	_crosshair.visible = on


func set_hint(text: String) -> void:
	_hint.text = text


func set_score(stolen: int, caught: int) -> void:
	_score.text = "ÇALINAN  %02d      /      YAKALANMA  %02d" % [stolen, caught]


## Big centred message that pops in and fades out.
func flash(text: String, color: Color) -> void:
	_flash.text = text
	_flash.label_settings.font_color = color
	_flash.pivot_offset = _flash.size * 0.5
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 1.0, 0.08)
	_flash_tween.parallel().tween_property(_flash, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 1.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_interval(1.0)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.4)


# anchors / offsets are (left, top, right, bottom).
func _label(label: Label, font_size: int, anchors: Vector4, offsets: Vector4) -> void:
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = font_size
	settings.font_color = Color("ece4d4")
	settings.outline_size = 1
	settings.outline_color = Color(0.025, 0.02, 0.015, 0.7)
	settings.shadow_color = Color(0,0,0,0.65)
	settings.shadow_size = 3
	settings.shadow_offset = Vector2(0,2)
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.offset_left = offsets.x
	label.offset_top = offsets.y
	label.offset_right = offsets.z
	label.offset_bottom = offsets.w
	add_child(label)
