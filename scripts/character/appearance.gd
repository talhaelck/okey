class_name Appearance
extends Resource
## What a dayı looks like: colours and which optional parts he wears.
## Small enough to save locally and to sync over the network later; the character creator edits one of these.

const SKINS: Array[Color] = [Color(0.96, 0.74, 0.6), Color(0.93, 0.66, 0.5), Color(0.84, 0.57, 0.41), Color(0.68, 0.45, 0.31)]
const VESTS: Array[Color] = [Color(0.36, 0.22, 0.15), Color(0.2, 0.32, 0.22), Color(0.17, 0.22, 0.38), Color(0.45, 0.16, 0.17),
	Color(0.38, 0.38, 0.4)]
const TROUSERS: Array[Color] = [Color(0.27, 0.28, 0.33), Color(0.33, 0.27, 0.2), Color(0.18, 0.18, 0.2)]
const CAPS: Array[Color] = [Color(0.4, 0.34, 0.28), Color(0.3, 0.3, 0.32), Color(0.16, 0.15, 0.15), Color(0.62, 0.55, 0.42)]
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


## Recolours and shows/hides the parts of an instanced dayi.glb (node names come from tools/blender/dayi.py).
func apply(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		var source := mi.mesh.surface_get_material(0) as BaseMaterial3D
		mi.material_override = _material_for(part, _color_for(part, source.albedo_color if source else Color.WHITE))
		if part.begins_with("hat_"):
			mi.visible = hat
		elif part.begins_with("mustache_"):
			mi.visible = mustache


func _material_for(part: String, color: Color) -> Material:
	if part in ["head", "arms"]:
		return _skin_material(color)
	if part in ["vest", "trousers", "atlet"] or part.begins_with("hat_"):
		# Woven cloth detail that sticks to the body (object-space projection).
		return Mat.textured("rough_linen", 0.08, color, false, false)
	if part.begins_with("eye"):
		return Mat.material(color, 0.15)
	return Mat.material(color, 0.9 if part.get_slice("_", 0) in ["mustache", "brows", "hair"] else 0.6)


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


func _color_for(part: String, fallback: Color) -> Color:
	if part in ["head", "arms"]:
		return skin
	if part == "vest":
		return vest
	if part == "trousers":
		return trousers
	if part.begins_with("hat_"):
		return cap
	if part.begins_with("mustache_") or part.begins_with("brows_") or part.begins_with("hair_"):
		return hair
	return fallback
