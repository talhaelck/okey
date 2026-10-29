class_name FocusCamera
extends Camera3D
## First-person camera with two modes:
##  - Observe (Masa Görünümü): free head look + WASD physical leaning around the table; your own rack is blurred.
##  - Rack (Istaka Görünümü): zoomed onto your rack; the table and opponents beyond it are blurred.
## Space or Right Mouse Button toggles between Masa and Istaka views.

const LOOK_SENSITIVITY := 0.0025
const YAW_LIMIT := 1.38
const PITCH_MIN := -0.95
const PITCH_MAX := 0.60
const BLEND_TIME := 0.32

const OBSERVE_NEAR := 0.36
const OBSERVE_FAR := 4.20
const RACK_NEAR := 0.04
const RACK_FAR := 0.70

var mouse_control := true
var focused := false
var magnifier_active := false

var _head: Node3D
var _rack: Node3D
var _yaw := 0.0
var _pitch := -0.26
var _blend := 0.0
var _lean_offset := Vector3.ZERO
var _shake := 0.0
var _time := 0.0
var _tween: Tween


func attach_to_seat(seat: Seat) -> void:
	_head = seat.head_anchor
	_rack = seat.rack_focus_anchor


func look(yaw: float, pitch: float) -> void:
	_yaw = clampf(yaw, -YAW_LIMIT, YAW_LIMIT)
	_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)


func jolt(amount := 0.018) -> void:
	_shake = maxf(_shake, amount)


func set_focused(value: bool, instant := false) -> void:
	focused = value
	if mouse_control:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if focused else Input.MOUSE_MODE_CAPTURED
	if _tween:
		_tween.kill()
	var target := 1.0 if focused else 0.0
	if instant:
		_blend = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_blend", target, BLEND_TIME)


func _unhandled_input(event: InputEvent) -> void:
	if not mouse_control:
		return
	if event is InputEventMouseMotion:
		if not focused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw = clampf(_yaw - event.relative.x * LOOK_SENSITIVITY * CafePreferences.sensitivity, -YAW_LIMIT, YAW_LIMIT)
			_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY * CafePreferences.sensitivity, PITCH_MIN, PITCH_MAX)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			set_focused(not focused)
		elif event.keycode == KEY_TAB and not focused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			set_focused(not focused)
		elif event.button_index == MOUSE_BUTTON_LEFT and not focused and mouse_control \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if _head == null:
		return
	_time += delta
	_shake = maxf(0.0, _shake - delta * 0.06)

	# WASD physical leaning in Masa Görünümü (peek closer to opponents or center pile)
	var target_lean := Vector3.ZERO
	if not focused and mouse_control:
		if Input.is_key_pressed(KEY_W):
			target_lean.z -= 0.12
			target_lean.y -= 0.03
		if Input.is_key_pressed(KEY_S):
			target_lean.z += 0.06
		if Input.is_key_pressed(KEY_A):
			target_lean.x -= 0.11
		if Input.is_key_pressed(KEY_D):
			target_lean.x += 0.11
	_lean_offset = _lean_offset.lerp(target_lean, 1.0 - exp(-10.0 * delta))

	var shake_vec := Vector3(
		sin(_time * 43.0) * _shake,
		cos(_time * 37.0) * _shake,
		0.0
	)
	var head_xf := _head.global_transform
	head_xf.origin += head_xf.basis * (_lean_offset + shake_vec)
	var look_xf := head_xf * Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, -_lean_offset.x * 0.25)), Vector3.ZERO)
	global_transform = look_xf.interpolate_with(_rack.global_transform, _blend)

	var dof := attributes as CameraAttributesPractical
	dof.dof_blur_near_distance = lerpf(OBSERVE_NEAR, RACK_NEAR, _blend)
	dof.dof_blur_far_distance = exp(lerpf(log(OBSERVE_FAR), log(RACK_FAR), _blend))
	var target_fov := 38.0 if magnifier_active else 75.0
	fov = lerpf(fov, target_fov, 1.0 - exp(-12.0 * delta))
