class_name FocusCamera
extends Camera3D
## First-person camera with two modes:
##  - Observe: free head look around the table; your own rack (close by) is blurred.
##  - Rack: zoomed onto your rack; everything beyond it is blurred.
## Space or right mouse button toggles. Esc frees the mouse, left click grabs it again.

const LOOK_SENSITIVITY := 0.0025
const YAW_LIMIT := 1.3
const PITCH_MIN := -0.95
const PITCH_MAX := 0.6
const BLEND_TIME := 0.35

# Depth-of-field distances (metres) for each mode; interpolated during the transition.
const OBSERVE_NEAR := 0.85
const OBSERVE_FAR := 60.0
const RACK_NEAR := 0.05
const RACK_FAR := 0.6

## When false the camera never touches the mouse mode (used by the screenshot tool).
var mouse_control := true
var focused := false

var _head: Node3D
var _rack: Node3D
var _yaw := 0.0
var _pitch := -0.35
var _blend := 0.0
var _tween: Tween


func attach_to_seat(seat: Seat) -> void:
	_head = seat.head_anchor
	_rack = seat.rack_focus_anchor


## Points the head directly (yaw/pitch in radians, clamped to the usual limits).
func look(yaw: float, pitch: float) -> void:
	_yaw = clampf(yaw, -YAW_LIMIT, YAW_LIMIT)
	_pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)


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
	if event is InputEventMouseMotion:
		if not focused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw = clampf(_yaw - event.relative.x * LOOK_SENSITIVITY, -YAW_LIMIT, YAW_LIMIT)
			_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			set_focused(not focused)
		elif event.keycode == KEY_ESCAPE and mouse_control:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			set_focused(not focused)
		elif event.button_index == MOUSE_BUTTON_LEFT and not focused and mouse_control \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled() # this click is not a grab


func _process(_delta: float) -> void:
	if _head == null:
		return
	var look := _head.global_transform * Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), Vector3.ZERO)
	global_transform = look.interpolate_with(_rack.global_transform, _blend)

	var dof := attributes as CameraAttributesPractical
	dof.dof_blur_near_distance = lerpf(OBSERVE_NEAR, RACK_NEAR, _blend)
	# Log-space so the far blur creeps in gradually instead of snapping at the end.
	dof.dof_blur_far_distance = exp(lerpf(log(OBSERVE_FAR), log(RACK_FAR), _blend))
