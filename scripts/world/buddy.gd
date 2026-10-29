class_name Buddy
extends Node3D
## Animated character in an opponent seat: authored patrons/mascots with 3D speech bubbles & reactions.

const TURN_TIME := 0.3
const MAX_TURN := 1.75

var _anim: AnimationPlayer
var _idle := ""
var _tween: Tween
var _alert := Label3D.new()
var _speech := Label3D.new()
var _speech_tween: Tween
var _mascot: MascotCharacter
var _patron: CafePatron
var _rigged: RiggedPatron


func setup(model: String, height: float) -> void:
	if model in MascotCharacter.KINDS:
		_mascot = MascotCharacter.new()
		add_child(_mascot)
		_mascot.build(model, height)
	elif model in CafePatron.KINDS:
		_patron = CafePatron.new()
		add_child(_patron)
		_patron.build(model)
	elif model in RiggedPatron.KINDS:
		_rigged = RiggedPatron.new()
		add_child(_rigged)
		_rigged.build(model)
	else:
		_setup_imported(model, height)
	_setup_alert(height)
	_setup_speech(height)


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
	_alert.text = ""
	_alert.font_size = 64
	_alert.pixel_size = 0.00075
	_alert.modulate = Color(1.0, 0.82, 0.12)
	_alert.outline_size = 16
	_alert.outline_modulate = Color(0.25, 0.08, 0.04)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.position = Vector3(0, height + 0.10, 0)
	_alert.visible = false
	add_child(_alert)


func _setup_speech(height: float) -> void:
	_speech.text = ""
	_speech.font_size = 32
	_speech.pixel_size = 0.00075
	_speech.modulate = Color("fff2d6")
	_speech.outline_size = 12
	_speech.outline_modulate = Color(0.12, 0.07, 0.04, 0.95)
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.position = Vector3(0, height + 0.16, 0)
	_speech.visible = false
	add_child(_speech)


func say(line: String, duration := 2.6, color := Color("fff2d6")) -> void:
	_speech.text = ""
	_speech.modulate = color
	_speech.visible = true
	_speech.scale = Vector3.ONE * 0.75
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_property(_speech, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_speech_tween.tween_interval(duration)
	_speech_tween.tween_callback(func() -> void: _speech.visible = false)


## Turns toward a world point; amount 0 keeps facing the table, 1 looks straight at it.
func look_toward(point: Vector3, amount := 1.0) -> void:
	var d := get_parent_node_3d().to_local(point) - position
	_turn(clampf(atan2(-d.x, -d.z), -MAX_TURN, MAX_TURN) * amount)


func look_home() -> void:
	_turn(0.0)


func gesture(suffix: String) -> void:
	if _rigged:
		_rigged.gesture(suffix)
		return
	if _patron:
		if suffix == "No":
			_patron.react()
		elif suffix == "Reach":
			_patron.lean_forward(1.0)
		elif suffix == "Hit":
			_patron.flinch_hit()
		elif suffix == "Wipe":
			_patron.wipe_spill(4.8)
		elif suffix == "Laugh":
			_patron.laugh()
		return
	if _mascot:
		if suffix in ["No", "Hit"]:
			_mascot.react()
		return
	var name := _animation(suffix)
	if not name.is_empty():
		_anim.play(name, 0.15)


func set_alert(on: bool) -> void:
	_alert.visible = on


func _turn(yaw: float) -> void:
	if _rigged:
		_rigged.turn_head(yaw, TURN_TIME)
		return
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
