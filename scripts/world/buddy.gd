class_name Buddy
extends Node3D
## Animated character in an opponent seat: authored mascots or legacy CC0 glTF models.
## Visual only: Watcher decides where it looks and when it reacts. Faces the table along -Z when idle.

const TURN_TIME := 0.3
const MAX_TURN := 1.75

var _anim: AnimationPlayer
var _idle := ""
var _tween: Tween
var _alert := Label3D.new()
var _mascot: MascotCharacter
var _patron: CafePatron


func setup(model: String, height: float) -> void:
	if model in MascotCharacter.KINDS:
		_mascot = MascotCharacter.new()
		add_child(_mascot)
		_mascot.build(model, height)
	elif model in CafePatron.KINDS:
		_patron = CafePatron.new()
		add_child(_patron)
		_patron.build(model)
	else:
		_setup_imported(model, height)
	_setup_alert(height)


func _setup_imported(model: String, height: float) -> void:
	var body: Node3D = load("res://assets/models/characters/%s.glb" % model).instantiate()
	add_child(body)
	body.scale = Vector3.ONE * height / _bounds(body).size.y
	body.rotation.y = PI # glTF models face +Z
	_anim = body.find_children("*", "AnimationPlayer", true, false)[0]
	_idle = _animation("Sitting_Idle")
	if _idle.is_empty():
		_idle = _animation("Idle")
	_anim.get_animation(_idle).loop_mode = Animation.LOOP_LINEAR
	_anim.play(_idle)
	_anim.seek(randf() * _anim.current_animation_length)
	_anim.animation_finished.connect(func(_name: StringName) -> void: _anim.play(_idle, 0.2))


func _setup_alert(height: float) -> void:
	_alert.text = "!"
	_alert.font_size = 160
	_alert.pixel_size = 0.001
	_alert.modulate = Color(1.0, 0.85, 0.1)
	_alert.outline_size = 36
	_alert.outline_modulate = Color(0.25, 0.1, 0.05)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.position = Vector3(0, height + 0.15, 0)
	_alert.visible = false
	add_child(_alert)


## Turns toward a world point; amount 0 keeps facing the table, 1 looks straight at it.
func look_toward(point: Vector3, amount := 1.0) -> void:
	var d := get_parent_node_3d().to_local(point) - position
	_turn(clampf(atan2(-d.x, -d.z), -MAX_TURN, MAX_TURN) * amount)


func look_home() -> void:
	_turn(0.0)


func gesture(suffix: String) -> void:
	if _patron:
		if suffix == "No":
			_patron.react()
		return
	if _mascot:
		if suffix == "No":
			_mascot.react()
		return
	var name := _animation(suffix)
	if not name.is_empty():
		_anim.play(name, 0.15)


func set_alert(on: bool) -> void:
	_alert.visible = on


func _turn(yaw: float) -> void:
	if _patron:
		_patron.turn_head(yaw)
		return
	if _mascot:
		_mascot.turn_head(yaw, TURN_TIME)
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation:y", yaw, TURN_TIME)


# Animation names carry armature prefixes ("CharacterArmature|Idle"), so match on the suffix.
func _animation(suffix: String) -> String:
	for name in _anim.get_animation_list():
		if name == suffix or name.ends_with("|" + suffix):
			return name
	return ""


func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != root:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var box := xf * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
