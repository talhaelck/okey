class_name CafeUi
extends RefCounted
const INK := Color("e7e2d5")
const MUTED := Color("aaa99b")
const ACCENT := Color("bba982")
static func panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=Color(.095,.115,.10,1.0)
	s.border_color=Color(.65,.67,.57,.20)
	s.set_border_width_all(1)
	s.set_corner_radius_all(14)
	s.content_margin_left=28;s.content_margin_right=28
	s.content_margin_top=26;s.content_margin_bottom=26
	return s
static func button(b: Button,primary := false) -> void:
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color=Color("596d56") if primary else Color("29312b")
		if state=="hover":s.bg_color=s.bg_color.lightened(.10)
		if state=="pressed":s.bg_color=s.bg_color.darkened(.10)
		s.border_color=ACCENT if state=="focus" else Color(.65,.69,.59,.18)
		s.set_border_width_all(2 if state=="focus" else 1)
		s.set_corner_radius_all(8)
		s.content_margin_left=18;s.content_margin_right=18
		s.content_margin_top=9;s.content_margin_bottom=9
		b.add_theme_stylebox_override(state,s)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(key,INK)
static func theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new();f.font_names=PackedStringArray(["Segoe UI","Arial"]);f.font_weight=500
	t.default_font=f;t.default_font_size=18
	t.set_color("font_color","Label",INK)
	t.set_stylebox("panel","PanelContainer",panel())
	for type in ["HSlider","VSlider"]:
		var track := StyleBoxFlat.new();track.bg_color=Color("343d35");track.set_corner_radius_all(3);track.content_margin_top=3;track.content_margin_bottom=3
		t.set_stylebox("slider",type,track)
		var fill: StyleBoxFlat=track.duplicate();fill.bg_color=Color("84967a")
		t.set_stylebox("grabber_area",type,fill);t.set_stylebox("grabber_area_highlight",type,fill)
	return t
