class_name Watcher
extends Node
## Stand-in brain for an opponent: mostly studies its own rack, now and then glances at another player.
## A short half-turn hints the glance before the full look. Whoever it looks at can be caught stealing.

enum State { RACK, HINT, LOOK, DISTRACTED }

const HINT_TIME := 0.55
const LOOK_TIME := Vector2(1.2, 2.4)
const RACK_TIME := Vector2(2.5, 6.0)
const LOCAL_BIAS := 0.55 # chance a glance goes to the local player

var seat: Seat
var local_seat: Seat
var others: Array[Seat] = []
var target: Seat

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
			target = local_seat if randf() < LOCAL_BIAS else others.pick_random()
			seat.buddy.look_toward(target.head_anchor.global_position, 0.25)
			_set_state(State.HINT, HINT_TIME)
		State.HINT:
			seat.buddy.look_toward(target.head_anchor.global_position)
			_set_state(State.LOOK, randf_range(LOOK_TIME.x, LOOK_TIME.y))
		State.LOOK:
			seat.buddy.look_home()
			_set_state(State.RACK, randf_range(RACK_TIME.x, RACK_TIME.y))
		State.DISTRACTED:
			seat.buddy.look_home()
			_set_state(State.RACK, randf_range(1.0,2.0))


func is_watching(other: Seat) -> bool:
	return _state == State.LOOK and target == other


func can_see(point: Vector3, owner: Seat) -> bool:
	if not is_watching(owner):
		return false
	var eye := seat.head_anchor.global_position
	var forward := (owner.head_anchor.global_position-eye).normalized()
	var direction := point-eye
	return direction.length() < 2.6 and forward.dot(direction.normalized()) > cos(deg_to_rad(55.0))


func distract(point: Vector3, duration := 1.8) -> void:
	seat.buddy.look_toward(point)
	_set_state(State.DISTRACTED,duration)


func attention_text() -> String:
	match _state:
		State.RACK: return "ıstakasında"
		State.HINT: return "başını çeviriyor"
		State.DISTRACTED: return "sese bakıyor"
		State.LOOK: return "SANA BAKIYOR" if target == local_seat else "başka yöne bakıyor"
	return ""


## Shakes its head at the thief and keeps staring a little longer.
func caught_thief() -> void:
	seat.buddy.gesture("No")
	_timer = maxf(_timer, 1.5)


func _set_state(state: State, time: float) -> void:
	_state = state
	_timer = time
	seat.buddy.set_alert(state == State.LOOK and target == local_seat)
