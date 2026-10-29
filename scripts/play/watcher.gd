class_name Watcher
extends Node
## Opponent brain: studies its own rack, glances at players, reacts to tea spills.

enum State { RACK, HINT, LOOK, WIPING }

const HINT_TIME := 0.55
const LOOK_TIME := Vector2(1.2, 2.3)
const RACK_TIME := Vector2(2.6, 5.8)
const LOCAL_BIAS := 0.52 # chance a glance goes to the local player

var seat: Seat
var local_seat: Seat
var others: Array[Seat] = []
var target: Seat
var vision_multiplier := 1.0

var _state := State.RACK
var _timer := 0.0


func _ready() -> void:
	_timer = randf_range(RACK_TIME.x, RACK_TIME.y)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	match _state:
		State.RACK:
			target = local_seat if randf() < LOCAL_BIAS else (others.pick_random() if not others.is_empty() else local_seat)
			seat.buddy.look_toward(target.head_anchor.global_position, 0.28)
			_set_state(State.HINT, HINT_TIME)
		State.HINT:
			seat.buddy.look_toward(target.head_anchor.global_position)
			_set_state(State.LOOK, randf_range(LOOK_TIME.x, LOOK_TIME.y))
		State.LOOK:
			seat.buddy.look_home()
			_set_state(State.RACK, randf_range(RACK_TIME.x, RACK_TIME.y))
		State.WIPING:
			seat.buddy.look_home()
			_set_state(State.RACK, randf_range(1.4, 2.5))


func is_watching(other: Seat) -> bool:
	if _state == State.WIPING:
		return false
	return _state == State.LOOK and target == other


func can_see(point: Vector3, owner: Seat) -> bool:
	if not is_watching(owner) or vision_multiplier <= 0.08:
		return false
	var eye := seat.head_anchor.global_position
	var forward := (owner.head_anchor.global_position - eye).normalized()
	var direction := point - eye
	var max_dist := 2.6 * clampf(vision_multiplier, 0.25, 1.2)
	var fov_deg := 55.0 * clampf(vision_multiplier, 0.35, 1.0)
	return direction.length() < max_dist and forward.dot(direction.normalized()) > cos(deg_to_rad(fov_deg))


func spill_distract(duration := 5.2) -> void:
	seat.buddy.look_home()
	seat.buddy.gesture("Wipe")
	if is_instance_valid(seat.rack):
		seat.rack.tilt_open(duration)
	var lines := [
		"Lan çay döküldü, taşlar ıslandı!",
		"Hay eline sağlık, masa göl oldu!",
		"Peçete verin ula çay devrildi!",
	]
	seat.buddy.say(lines.pick_random(), duration * 0.85, Color("ff9e78"))
	_set_state(State.WIPING, duration)


func attention_text() -> String:
	match _state:
		State.RACK: return "ıstakasında"
		State.HINT: return "başını çeviriyor"
		State.WIPING: return "çayı siliyor!"
		State.LOOK: return "SANA BAKIYOR" if target == local_seat else "başka yöne bakıyor"
	return ""


## Shakes its head at the thief and shouts a kahvehane line.
func caught_thief() -> void:
	seat.buddy.gesture("No")
	var lines := [
		"Elini çek lan ıstakamdan!",
		"Gözümün önünde taş çalıyor!",
		"Hoppala! Bırak o taşı yerine!",
		"Ula hırsız var masada!",
	]
	seat.buddy.say(lines.pick_random(), 3.0, Color("ff8066"))
	_timer = maxf(_timer, 1.8)


func _set_state(state: State, time: float) -> void:
	_state = state
	_timer = time
	seat.buddy.set_alert(state == State.LOOK and target == local_seat)
