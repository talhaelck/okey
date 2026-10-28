class_name Buddy
extends Node3D
## A dayı sitting in an opponent seat (model from tools/blender/dayi.py, looks from an Appearance).
## Visual only: Watcher decides where he looks and when he reacts. Faces the table along -Z when idle.
## All motion is procedural: breathing, head bob, turning (head leads, body follows) and head shakes.

const MODEL := preload("res://assets/models/dayi/dayi.glb")
const TURN_TIME := 0.3
const MAX_TURN := 1.75
const HEAD_SHARE := 0.45 # how much of a turn the head does on its own
const ALERT_HEIGHT := 1.25

var appearance: Appearance

var _body: Node3D
var _head: Node3D
var _head_yaw := 0.0
var _shake := 0.0
var _time := randf() * 10.0
var _turn_tween: Tween
var _alert := Label3D.new()


func setup(look: Appearance) -> void:
	appearance = look
	_body = MODEL.instantiate()
	_body.rotation.y = PI # glTF models face +Z
	add_child(_body)
	look.apply(_body)
	_head = _body.find_child("Head", true, false)

	_alert.text = "!"
	_alert.font_size = 160
	_alert.pixel_size = 0.001
	_alert.modulate = Color(1.0, 0.85, 0.1)
	_alert.outline_size = 36
	_alert.outline_modulate = Color(0.25, 0.1, 0.05)
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.position = Vector3(0, ALERT_HEIGHT, 0)
	_alert.visible = false
	add_child(_alert)


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	_body.scale = Vector3(1.0, 1.0 + sin(_time * 2.2) * 0.012, 1.0)
	_head.rotation = Vector3(sin(_time * 0.9) * 0.04, _head_yaw + sin(_time * 24.0) * _shake, sin(_time * 0.6) * 0.03)


## Turns toward a world point; amount 0 keeps facing the table, 1 looks straight at it.
func look_toward(point: Vector3, amount := 1.0) -> void:
	var d := get_parent_node_3d().to_local(point) - position
	_turn(clampf(atan2(-d.x, -d.z), -MAX_TURN, MAX_TURN) * amount)


func look_home() -> void:
	_turn(0.0)


## Disapproving "tsk tsk" head shake.
func shake_head() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_shake", 0.35, 0.08)
	tween.tween_property(self, "_shake", 0.0, 0.9).set_ease(Tween.EASE_IN)


func set_alert(on: bool) -> void:
	_alert.visible = on


func _turn(yaw: float) -> void:
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_property(self, "_head_yaw", yaw * HEAD_SHARE, TURN_TIME * 0.7)
	_turn_tween.tween_property(self, "rotation:y", yaw * (1.0 - HEAD_SHARE), TURN_TIME)
