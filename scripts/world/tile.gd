class_name Tile
extends MeshInstance3D
## One okey tile. value = Vector2i(color, number); holder is the Rack or Table it sits on (null while carried).

const SLIDE_TIME := 0.22

var value: Vector2i
var holder: Node
var is_draw_pile := false
var is_indicator := false
var is_discard := false
var discard_seat := -1
var is_fallen := false
var fallen_origin_slot := -1
var fallen_from_rack: Node = null

var _tween: Tween
var _xray_stamp: MeshInstance3D
var _xray_heart: MeshInstance3D
var _okey_halo: MeshInstance3D


func set_xray(enabled: bool) -> void:
	if _xray_stamp == null:
		_xray_stamp = get_node_or_null("XRayStamp")
		_xray_heart = get_node_or_null("XRayHeart")
	if is_instance_valid(_xray_stamp):
		_xray_stamp.visible = enabled
	if is_instance_valid(_xray_heart):
		_xray_heart.visible = enabled
	if not enabled and _okey_halo != null:
		_okey_halo.visible = false


func set_okey_glow(enabled: bool) -> void:
	if enabled:
		if _okey_halo == null:
			_okey_halo = MeshInstance3D.new()
			_okey_halo.name = "OkeyHalo"
			var qm := QuadMesh.new()
			qm.size = Vector2(0.044, 0.060)
			_okey_halo.mesh = qm
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.no_depth_test = true
			mat.render_priority = 11
			mat.albedo_color = Color(1.0, 0.86, 0.18, 0.90)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_okey_halo.material_override = mat
			_okey_halo.rotation.y = PI
			_okey_halo.position = Vector3(0, 0, -TileFactory.SIZE.z * 0.5 - 0.00015)
			add_child(_okey_halo)
		_okey_halo.visible = true
	else:
		if _okey_halo != null:
			_okey_halo.visible = false



## Glides to a transform in the parent's space with a subtle physical arc.
func slide_to(target: Transform3D, time := SLIDE_TIME, arc_height := 0.035) -> void:
	stop_sliding()
	var start := transform
	var q_start := start.basis.get_rotation_quaternion().normalized()
	var q_end := target.basis.get_rotation_quaternion().normalized()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		var pos := start.origin.lerp(target.origin, t)
		pos.y += sin(t * PI) * arc_height
		var basis := Basis(q_start.slerp(q_end, t))
		transform = Transform3D(basis, pos), 0.0, 1.0, time)


func stop_sliding() -> void:
	if _tween:
		_tween.kill()
		_tween = null
