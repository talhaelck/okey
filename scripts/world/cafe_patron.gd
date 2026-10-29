class_name CafePatron
extends Node3D
## Imported Blender sculpt with head tracking, breathing and blink presentation.
const KINDS := ["sabri","temel","rifki"]
var head: Node3D
var torso: Node3D
var _eyes: Array[Node3D] = []
var _time := 0.0
var _blink := 2.0
var _blink_phase := -1.0
var _turn: Tween
var _reaction := 0.0

func build(kind: String) -> void:
	var model: Node3D = load("res://assets/models/patrons/%s.glb" % kind).instantiate()
	add_child(model)
	for node: Node3D in model.find_children("*","Node3D",true,false):
		if String(node.name).begins_with("Head"):
			head = node
		elif String(node.name).begins_with("Torso"):
			torso = node
		elif String(node.name).begins_with("EyeWhite") or String(node.name).begins_with("Iris") or String(node.name).begins_with("Pupil") or String(node.name).begins_with("EyeCatchlight"):
			_eyes.append(node)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var source := mi.mesh.surface_get_material(i) as StandardMaterial3D
				if source == null:
					continue
				var name := source.resource_name
				if name in ["patron_burgundy","patron_shirt","patron_olive","patron_cap","patron_trouser","patron_navy"]:
					mi.set_surface_override_material(i,SurfaceStyle.textured(source.albedo_color,SurfaceStyle.Kind.FABRIC,0.88))
	_time = randf()*TAU
	_blink = randf_range(2,5)

func turn_head(yaw: float) -> void:
	if head == null:
		return
	if _turn:
		_turn.kill()
	_turn = create_tween().set_trans(Tween.TRANS_SINE)
	_turn.tween_property(head,"rotation:y",clampf(yaw,-1.1,1.1),0.35)

func react() -> void:
	_reaction = 1.0

func _process(delta: float) -> void:
	_time += delta
	_reaction = maxf(0,_reaction-delta*1.8)
	if torso:
		torso.position.y = sin(_time*1.65)*0.0025
		torso.rotation.x = sin(_time*1.65)*0.004-_reaction*0.065
	if head:
		head.rotation.z = sin(_time*0.45)*0.012
	_blink -= delta
	if _blink < 0 and _blink_phase < 0:
		_blink_phase = 0
		_blink = randf_range(2.5,5.5)
	if _blink_phase >= 0:
		_blink_phase += delta
		var opening := 1.0-sin(clampf(_blink_phase/0.16,0,1)*PI)*0.94
		for eye in _eyes:
			eye.scale.y = opening
		if _blink_phase > 0.16:
			_blink_phase = -1
