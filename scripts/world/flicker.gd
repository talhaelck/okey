extends Light3D
## Restless brightness, like a TV screen changing scenes.

var _base := 0.0
var _timer := 0.0


func _ready() -> void:
	_base = light_energy


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.08, 0.6)
		light_energy = _base * randf_range(0.5, 1.3)
