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
	_font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Black", "Arial"])
	_font.font_weight = 800

	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.draw.connect(func() -> void:
		_crosshair.draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.45))
		_crosshair.draw_circle(Vector2.ZERO, 3.5, Color(1, 1, 1, 0.95)))
	add_child(_crosshair)

	# Centred labels span the screen; equal top/bottom offsets shift them up or down from the middle.
	_label(_hint, 22, Vector4(0, 0, 1, 1), Vector4(0, 100, 0, 100))
	_label(_score, 24, Vector4(0, 0, 0, 0), Vector4(20, 16, 700, 60))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var help := Label.new()
	_label(help, 16, Vector4(0, 1, 1, 1), Vector4(20, -40, 0, -12))
	help.text = "Fare: etrafa bak    Space / Sağ tık: ıstakaya odaklan    Sol tık: taş al / bırak    Esc: fareyi bırak"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help.modulate.a = 0.8
	_label(_flash, 64, Vector4(0, 0, 1, 1), Vector4(0, -150, 0, -150))
	_flash.modulate.a = 0.0

	set_score(0, 0)


func show_crosshair(on: bool) -> void:
	_crosshair.visible = on


func set_hint(text: String) -> void:
	_hint.text = text


func set_score(stolen: int, caught: int) -> void:
	_score.text = "Çalınan taş: %d     Yakalanma: %d" % [stolen, caught]


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
	settings.outline_size = maxi(4, font_size / 5)
	settings.outline_color = Color(0.1, 0.06, 0.15)
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
