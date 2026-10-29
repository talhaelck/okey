class_name Appearance
extends Resource
## What a dayı looks like: colours and which optional parts he wears.
## Small enough to save locally and to sync over the network later; the character creator edits one of these.

const SKINS: Array[Color] = [Color(0.9, 0.72, 0.62), Color(0.86, 0.66, 0.55), Color(0.76, 0.56, 0.44), Color(0.6, 0.43, 0.33)]
const VESTS: Array[Color] = [Color(0.36, 0.22, 0.15), Color(0.2, 0.32, 0.22), Color(0.17, 0.22, 0.38), Color(0.45, 0.16, 0.17),
	Color(0.38, 0.38, 0.4)]
const TROUSERS: Array[Color] = [Color(0.27, 0.28, 0.33), Color(0.33, 0.27, 0.2), Color(0.18, 0.18, 0.2)]
const CAPS: Array[Color] = [Color(0.4, 0.34, 0.28), Color(0.3, 0.3, 0.32), Color(0.16, 0.15, 0.15), Color(0.62, 0.55, 0.42)]
## Shirt worn under the vest; its rolled-up sleeves are on every dayı and on the first-person arms.
const SHIRT := Color(0.9, 0.88, 0.83)
const HAIRS: Array[Color] = [Color(0.14, 0.11, 0.1), Color(0.45, 0.43, 0.42), Color(0.85, 0.85, 0.83)]

@export var skin := SKINS[1]
@export var vest := VESTS[0]
@export var trousers := TROUSERS[0]
@export var cap := CAPS[0]
@export var hair := HAIRS[0]
@export var hat := true
@export var mustache := true


static func random() -> Appearance:
	var a := Appearance.new()
	a.skin = SKINS.pick_random()
	a.vest = VESTS.pick_random()
	a.trousers = TROUSERS.pick_random()
	a.cap = CAPS.pick_random()
	a.hair = HAIRS.pick_random()
	a.hat = randf() < 0.75
	a.mustache = randf() < 0.9
	return a


## Recolours and shows/hides the parts of an instanced dayi.glb or hands.glb (node names come from
## tools/blender). Parts it does not know (ring, watch, shoes, buttons) keep their Blender materials.
func apply(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		var look := _material_for(part)
		if look:
			mi.material_override = look
		if part.begins_with("hat_"):
			mi.visible = hat
		elif part.begins_with("mustache_"):
			mi.visible = mustache


func _material_for(part: String) -> Material:
	var kind := part.get_slice("_", 0)
	if kind in ["head", "arms"] or (kind == "hand" and not part.contains("ring") and not part.contains("watch")):
		return _skin_material(skin)
	if kind in ["vest", "trousers", "atlet", "sleeves", "hat"] and not part.contains("button"):
		# Woven cloth detail that sticks to the body (object-space projection).
		var colour := {"vest": vest, "trousers": trousers, "atlet": SHIRT, "sleeves": SHIRT, "hat": cap}[kind] as Color
		return Mat.textured("rough_linen", 0.08, colour, false, false)
	if kind in ["mustache", "brows", "hair"]:
		return Mat.material(hair, 0.9)
	return null


static var _skins := {}


# Skin lets a little light through, which keeps big round faces from looking like plastic.
static func _skin_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _skins.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.55
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.2
		m.subsurf_scatter_skin_mode = true
		_skins[key] = m
	return _skins[key]
