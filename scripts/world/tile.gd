class_name Tile
extends MeshInstance3D
## One okey tile. value = Vector2i(color, number); holder is the Rack or Table it sits on (null while carried).

const SLIDE_TIME := 0.18

var value: Vector2i
var holder: Node

var _tween: Tween


## Glides to a transform in the parent's space.
func slide_to(target: Transform3D, time := SLIDE_TIME) -> void:
	stop_sliding()
	var start := transform
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void: transform = start.interpolate_with(target, t), 0.0, 1.0, time)


func stop_sliding() -> void:
	if _tween:
		_tween.kill()
		_tween = null
