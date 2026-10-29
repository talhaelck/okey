class_name MeshyDayi
extends Node3D
## A rigged Meshy kahvehane dayı seated at the table (tools/meshy.py: rig + Chair_Sit_Idle_M clip).
## The pose is the clip's first frame, frozen: its own arm motion rests a chin on a hand. Breathing, head turning
## and both arms (two-bone IK to a hand target) are procedural, so hands stay on the felt and never sink into it.
## Local space = Buddy space: the origin is the seat top, -Z points at the table centre.

const KINDS := ["yasli", "gozluklu", "tespihli", "esofmanli"]
const SIT_CLIP := "Chair_Sit_Idle_M"
## Hands rest on the felt in front of his own body, between the table edge and his rack; x is mirrored per side.
const HAND_REST := Vector3(0.2, 0.3, -0.47)
const HAND_SPEED := 9.0
## The caricature head is a third of the body and the hands are paddles; these shrink them on the skeleton.
const HEAD_SCALE := 0.6
const HAND_SCALE := 0.7
const NO_BONE := -1

var _skeleton: Skeleton3D
var _rest: Dictionary = {} # bone index -> local pose of the frozen frame
var _ready_pose := false
var _time := randf() * 10.0
var _yaw := 0.0
var _yaw_target := 0.0
var _turn: Tween
var _shake := 0.0
var _lean := 0.0
var _arms: Array[Dictionary] = []
var _head := NO_BONE
var _neck := NO_BONE
var _spine := NO_BONE


## Sized by his legs: thighs on the seat, soles on the floor (Seat.SEAT_TOP below this node).
func build(kind: String) -> void:
	var body: Node3D = load("res://assets/models/meshy/dayi_%s_sit.glb" % kind).instantiate()
	body.rotation.y = PI # glTF models face +Z
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Icosphere": # Meshy's rig helper ball
			mesh.visible = false
	var player: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	player.play(SIT_CLIP)
	player.seek(0.0, true)
	player.pause()
	_head = _skeleton.find_bone("Head")
	_neck = _skeleton.find_bone("neck")
	_spine = _skeleton.find_bone("Spine01")
	for side in ["Left", "Right"]:
		_arms.append({
			"upper": _skeleton.find_bone(side + "Arm"),
			"lower": _skeleton.find_bone(side + "ForeArm"),
			"hand": _skeleton.find_bone(side + "Hand"),
			"target": Vector3.ZERO,
			"current": Vector3.ZERO,
			"reach": 0.0,
		})
	_fit_to_chair(body)


func _fit_to_chair(body: Node3D) -> void:
	_skeleton.force_update_all_bone_transforms()
	var thigh := _bone_at("LeftUpLeg")
	var toe := _bone_at("LeftToeBase")
	var sole := toe.y - (thigh.y - toe.y) * 0.08 # the toe joint sits a little above the sole
	body.scale *= Seat.SEAT_TOP / (thigh.y - sole)
	var hips := _bone_at("Hips")
	thigh = _bone_at("LeftUpLeg")
	body.position -= Vector3(hips.x, thigh.y, hips.z)


func _bone_at(bone_name: String) -> Vector3:
	return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(bone_name)).origin))


func _process(delta: float) -> void:
	if _skeleton == null:
		return
	if not _ready_pose:
		for bone in _skeleton.get_bone_count():
			_rest[bone] = _skeleton.get_bone_pose(bone)
		for bone in [_head, _skeleton.find_bone("LeftHand"), _skeleton.find_bone("RightHand")]:
			if bone != NO_BONE:
				_rest[bone] = (_rest[bone] as Transform3D).scaled_local(Vector3.ONE * (HEAD_SCALE if bone == _head else HAND_SCALE))
		for arm in _arms:
			var hand_at := to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(arm.hand).origin))
			arm.side = signf(hand_at.x) if absf(hand_at.x) > 0.01 else 1.0
			arm.target = _rest_target(arm.side)
			arm.current = arm.target
		_ready_pose = true
	_time += delta
	_yaw = lerp_angle(_yaw, _yaw_target, minf(1.0, delta * 8.0))
	for bone: int in _rest:
		_skeleton.set_bone_pose(bone, _rest[bone])
	_breathe()
	_turn_head()
	for arm in _arms:
		arm.current = (arm.current as Vector3).lerp(arm.target, minf(1.0, delta * HAND_SPEED))
		_solve_arm(arm)
	_shake = maxf(0.0, _shake - delta)
	_lean = move_toward(_lean, 0.0, delta * 0.8)


func _rest_target(side: float) -> Vector3:
	return Vector3(HAND_REST.x * side, HAND_REST.y, HAND_REST.z)


## Hand reaches for a world point (stealing, drawing); release_hand() puts it back on the felt.
func reach(world_point: Vector3, left := false) -> void:
	for arm in _arms:
		if (arm.side < 0.0) == left:
			arm.target = to_local(world_point)


func release_hand() -> void:
	for arm in _arms:
		arm.target = _rest_target(arm.side)


func turn_head(yaw: float, time: float) -> void:
	if _turn:
		_turn.kill()
	_turn = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_turn.tween_property(self, "_yaw_target", yaw, time)


## Head shake: "no", or being caught.
func react() -> void:
	_shake = 0.9


func lean_forward(amount: float) -> void:
	_lean = amount


func laugh() -> void:
	_lean = -0.4
	_shake = 0.6


func _breathe() -> void:
	var breath := sin(_time * 1.7) * 0.012
	_rotate_bone(_spine, Vector3.RIGHT, breath - _lean * 0.18)


func _turn_head() -> void:
	var wobble := sin(_time * 24.0) * 0.35 * (_shake / 0.9) if _shake > 0.0 else 0.0
	var yaw := _yaw + wobble
	_rotate_bone(_neck, Vector3.UP, yaw * 0.4)
	_rotate_bone(_head, Vector3.UP, yaw * 0.6)


## Rotates a bone about an axis given in this node's space (UP = vertical, RIGHT = sideways).
func _rotate_bone(bone: int, axis: Vector3, angle: float) -> void:
	if bone == NO_BONE or is_zero_approx(angle):
		return
	var world_axis := global_basis * axis
	var skeleton_axis := (_skeleton.global_basis.inverse() * world_axis).normalized()
	var pose := _skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(skeleton_axis, angle) * pose.basis
	_skeleton.set_bone_global_pose(bone, pose)


## Two-bone IK: upper arm and forearm swing so the hand reaches the target; the elbow drops down and back.
func _solve_arm(arm: Dictionary) -> void:
	var upper: int = arm.upper
	var lower: int = arm.lower
	var hand: int = arm.hand
	if upper == NO_BONE or lower == NO_BONE or hand == NO_BONE:
		return
	var to_skeleton := _skeleton.global_transform.affine_inverse() * global_transform
	var target := to_skeleton * (arm.current as Vector3)
	var pole := to_skeleton.basis * Vector3(arm.side * 0.6, -0.8, 0.5)
	var shoulder := _skeleton.get_bone_global_pose(upper).origin
	var elbow := _skeleton.get_bone_global_pose(lower).origin
	var wrist := _skeleton.get_bone_global_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var to_target := target - shoulder
	var d := clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to_target.normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var bend := sqrt(maxf(a * a - along * along, 0.0))
	var side_dir := (pole - dir * pole.dot(dir)).normalized()
	_aim(upper, lower, shoulder + dir * along + side_dir * bend)
	_aim(lower, hand, shoulder + dir * d)


## Rotates `bone` about its own joint so that its child joint ends up at `desired`.
func _aim(bone: int, child: int, desired: Vector3) -> void:
	var pose := _skeleton.get_bone_global_pose(bone)
	var current := _skeleton.get_bone_global_pose(child).origin - pose.origin
	var wanted := desired - pose.origin
	if current.length() < 0.0001 or wanted.length() < 0.0001:
		return
	pose.basis = Basis(Quaternion(current.normalized(), wanted.normalized())) * pose.basis
	_skeleton.set_bone_global_pose(bone, pose)
