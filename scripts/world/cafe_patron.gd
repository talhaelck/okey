class_name CafePatron
extends Node3D
## Imported Blender sculpt with head tracking, breathing, blink, and chaotic table reactions.
const KINDS := ["sabri", "temel", "rifki", "davut"]
var head: Node3D
var torso: Node3D
var _eyes: Array[Node3D] = []
var _time := 0.0
var _blink := 2.0
var _blink_phase := -1.0
var _turn: Tween
var _reaction := 0.0
var _lean := 0.0
var _wiping := 0.0
var _hit_wobble := 0.0
var _laugh := 0.0

func build(kind: String) -> void:
	var model: Node3D = load("res://assets/models/patrons/%s.glb" % kind).instantiate()
	add_child(model)
	for node: Node3D in model.find_children("*","Node3D",true,false):
		var n := String(node.name)
		if n == "Head" or n.begins_with("Head_"):
			head = node
		elif n == "Torso" or n.begins_with("Torso_"):
			torso = node
		elif n.begins_with("EyeWhite") or n.begins_with("Iris") or n.begins_with("Pupil") or n.begins_with("EyeCatchlight"):
			_eyes.append(node)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var source := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if source == null:
					continue
				var name := source.resource_name
				if name in ["patron_burgundy","patron_shirt","patron_atlet","patron_sweater","patron_olive","patron_cap","patron_trouser","patron_navy","patron_navy_pants","patron_white_stripe"]:
					mi.set_surface_override_material(i,SurfaceStyle.textured(source.albedo_color,SurfaceStyle.Kind.FABRIC,0.88))
				elif name in ["patron_belt","patron_shoe","patron_slipper"]:
					mi.set_surface_override_material(i,SurfaceStyle.textured(source.albedo_color,SurfaceStyle.Kind.LEATHER,0.62))
				elif name in ["patron_skin","patron_skin_plain","patron_skin_warm","patron_nose","patron_lip"]:
					var skin_mat := source.duplicate() as StandardMaterial3D
					skin_mat.roughness = 0.52
					skin_mat.rim_enabled = true
					skin_mat.rim = 0.22
					skin_mat.rim_tint = 0.65
					mi.set_surface_override_material(i,skin_mat)
	_time = randf()*TAU
	_blink = randf_range(2,5)

func turn_head(yaw: float) -> void:
	if head == null:
		return
	if _turn:
		_turn.kill()
	_turn = create_tween().set_trans(Tween.TRANS_SINE)
	_turn.tween_property(head,"rotation:y",clampf(yaw,-1.1,1.1),0.32)

func react() -> void:
	_reaction = 1.0

func lean_forward(amount := 1.0) -> void:
	_lean = amount

func flinch_hit() -> void:
	_hit_wobble = 1.0
	_reaction = 1.0

func wipe_spill(duration := 4.5) -> void:
	_wiping = duration

func laugh() -> void:
	_laugh = 1.6

func _process(delta: float) -> void:
	_time += delta
	_reaction = maxf(0, _reaction - delta * 1.8)
	_lean = maxf(0, _lean - delta * 2.2)
	_hit_wobble = maxf(0, _hit_wobble - delta * 2.6)
	_wiping = maxf(0, _wiping - delta)
	_laugh = maxf(0, _laugh - delta)
	if torso:
		var breath := sin(_time * 1.65) * 0.0025
		var laugh_bounce := absf(sin(_time * 14.0)) * 0.018 * clampf(_laugh, 0.0, 1.0)
		torso.position.y = breath + laugh_bounce
		var lean_pitch := _lean * 0.16 + (0.22 if _wiping > 0.0 else 0.0)
		torso.rotation.x = sin(_time * 1.65) * 0.004 - _reaction * 0.08 + lean_pitch - _hit_wobble * 0.18
		torso.rotation.z = sin(_time * 9.5) * 0.07 if _wiping > 0.0 else sin(_time * 12.0) * 0.05 * _hit_wobble
	if head:
		var wobble_z := sin(_time * 22.0) * 0.14 * _hit_wobble
		var wipe_x := 0.25 if _wiping > 0.0 else 0.0
		head.rotation.z = sin(_time * 0.45) * 0.012 + wobble_z
		head.rotation.x = wipe_x - _hit_wobble * 0.22 + sin(_time * 14.0) * 0.06 * clampf(_laugh, 0.0, 1.0)
	_blink -= delta
	if _blink < 0 and _blink_phase < 0:
		_blink_phase = 0
		_blink = randf_range(2.5, 5.5)
	if _blink_phase >= 0:
		_blink_phase += delta
		var opening := 1.0 - sin(clampf(_blink_phase / 0.16, 0, 1) * PI) * 0.94
		for eye in _eyes:
			eye.scale.y = opening
		if _blink_phase > 0.16:
			_blink_phase = -1
