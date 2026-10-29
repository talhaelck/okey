class_name RiggedDayi
extends Node3D
## A Meshy dayı rigged by Mixamo (tools/blender/mixamo_import.py), moved by Mixamo's motion-captured clips
## (tools/blender/mixamo_anim.py -> assets/models/dayi_rig/anim/*.glb), so his body moves like a real person's.
## Code only adds what a clip cannot know: it sizes and seats him on our chair, sits him a little more upright
## (Posture), moves his hands onto our felt and out of his rack (HandsOnTable: a small arm IK that keeps the clip's
## wrist and fingers), and turns his head toward whoever he looks at (HeadTurn: at most MAX_TURN on top of the clip).
## Bones are only ever rotated on top of the clip, never scaled. His hands pick up, carry and put down real tiles
## (DayiHands); while `demo` is on he does so now and then on his own.
## Local space = Buddy space: the origin is the seat top, -Z points at the table centre.

const BONE := "mixamorig_"
const CLIPS := "res://assets/models/dayi_rig/anim/"
const IDLE := "seated_idle"
const MAX_TURN := 0.8 # radians, about 45°
const KNEE_ABOVE_SEAT := 0.06
## The caricature torso is big for its legs; sized by the legs alone his shoulders end up ~1.2 m high. A real man's
## shoulders sit about this far above the seat, so taller dayıs are shrunk to it (their feet hang a little, under the table).
const SHOULDER_ABOVE_SEAT := 0.52
const HIPS_ABOVE_SEAT := 0.11

## Off in tests that check the resting hands.
static var demo := true

## How far the upper body leans in right now (DayiHands sets it while reaching), radians.
var lean := 0.0
## Where he is turned to look, radians about the vertical (0 = the table); shared by Posture (spine) and HeadTurn.
var yaw := 0.0
var hands := DayiHands.new()
var _skeleton: Skeleton3D
var _player := AnimationPlayer.new()
var _posture := Posture.new()
var _head_turn := HeadTurn.new()
var _hands_on_table := HandsOnTable.new()
var _turn: Tween


func build(kind: String) -> void:
	var body: Node3D = load("res://assets/models/dayi_rig/dayi_%s.glb" % kind).instantiate()
	body.rotation.y = PI # glTF models face +Z
	add_child(body)
	_skeleton = body.find_children("*", "Skeleton3D", true, false)[0]
	# Modifiers run in child order: straighten the back, then fix the hands for that back, then turn the head.
	_posture.dayi = self
	_skeleton.add_child(_posture)
	_hands_on_table.dayi = self
	var seat := get_parent().get_parent() as Seat
	if seat:
		_hands_on_table.rack = seat.rack
	_skeleton.add_child(_hands_on_table)
	_skeleton.add_child(hands)
	hands.setup(self)
	_head_turn.dayi = self
	_skeleton.add_child(_head_turn)
	body.add_child(_player)
	_player.add_animation_library("", _load_clips())
	_fit_to_chair(body)
	_player.play(IDLE)
	_player.seek(randf() * _player.current_animation_length, true)
	_seat_on_floor(body)
	if demo:
		_play_around()


## Every clip in CLIPS, retargeted from the exported bone nodes onto this skeleton. Only the hips keep their
## position track; the others would undo the shrunk head and hands. Bones this rig lacks (a missing pinky) are dropped.
func _load_clips() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for file in ResourceLoader.list_directory(CLIPS):
		if not file.ends_with(".glb"):
			continue
		var scene: Node = load(CLIPS + file).instantiate()
		var source: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		for clip_name in source.get_animation_list():
			var clip := source.get_animation(clip_name).duplicate() as Animation
			for track in range(clip.get_track_count() - 1, -1, -1):
				var path := clip.track_get_path(track)
				var bone := String(path.get_name(path.get_name_count() - 1))
				var keep := _skeleton.find_bone(bone) >= 0 and (clip.track_get_type(track) == Animation.TYPE_ROTATION_3D
					or (clip.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == BONE + "Hips"))
				if keep:
					clip.track_set_path(track, NodePath("Armature/Skeleton3D:" + bone))
				else:
					clip.remove_track(track)
			clip.loop_mode = Animation.LOOP_LINEAR if clip_name == IDLE else Animation.LOOP_NONE
			library.add_animation(clip_name, clip)
		scene.free()
	return library


# Size from the legs at rest: the knee-to-sole length is what has to fit under our chair's seat.
func _fit_to_chair(body: Node3D) -> void:
	var knee := _local("LeftLeg")
	var sole := _local("LeftToeBase").y - 0.015
	body.scale *= (Seat.SEAT_TOP + KNEE_ABOVE_SEAT) / (knee.y - sole)


# In the seated clip: soles on the floor, then no taller than a real man, hips on the middle of the seat.
func _seat_on_floor(body: Node3D) -> void:
	var sole := minf(_local("LeftToeBase").y, _local("RightToeBase").y) - 0.015
	body.position.y -= sole + Seat.SEAT_TOP
	var shoulders := _local("LeftArm").y
	if shoulders > SHOULDER_ABOVE_SEAT:
		body.scale *= SHOULDER_ABOVE_SEAT / shoulders
	var hips := _local("Hips")
	body.position -= hips - Vector3(0, HIPS_ABOVE_SEAT, 0)


func _local(bone: String) -> Vector3:
	return to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone(BONE + bone)).origin))


# --- Watcher API (through Buddy) ---------------------------------------------------------------------------

func turn_head(yaw: float, time: float) -> void:
	if _turn:
		_turn.kill()
	_turn = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_property(self, "yaw", clampf(yaw, -MAX_TURN, MAX_TURN), time * 1.6)


## Head shake: "no", or being caught.
func react() -> void:
	_head_turn.shake = 0.9


## Turns his head toward a point in his own space (or back to the table).
func look_at_point(point: Vector3, home := false) -> void:
	turn_head(0.0 if home else atan2(-point.x, -point.z), 0.2)


# --- Demo: until the rules engine drives him, he fiddles with his own tiles ---------------------------------

func _play_around() -> void:
	var seat := get_parent().get_parent() as Seat
	if seat == null:
		return
	await get_tree().create_timer(randf_range(3.0, 7.0)).timeout
	while is_inside_tree():
		var rack := seat.rack
		var table := get_tree().get_first_node_in_group("table") as Table
		var right := randf() < 0.6
		var filled: Array[int] = []
		var free: Array[int] = []
		for slot in Rack.SLOTS * Rack.ROWS:
			if (slot % Rack.SLOTS >= 7) == right:
				(filled if rack.tile_at(slot) else free).append(slot)
		if not filled.is_empty() and not free.is_empty():
			var slot: int = filled.pick_random()
			if randf() < 0.4 and table:
				var felt := Table.TOP - Seat.SEAT_TOP
				var spot := Vector3((0.48 if right else -0.48), felt, -0.51) # on the felt just past the rim, beside his rack
				var tile := await hands.discard(rack, slot, table, spot)
				if tile:
					await get_tree().create_timer(1.5).timeout
					await hands.pick_up(tile, table, rack, rack.nearest_free(slot))
			else:
				free.sort_custom(func(a: int, b: int) -> bool: return absi(a - slot) < absi(b - slot))
				await hands.rearrange(rack, slot, free[randi() % mini(3, free.size())])
		await get_tree().create_timer(randf_range(4.0, 9.0)).timeout


## The seated clip hunches far over its table, which brings the side players' heads at the camera. Leans the upper
## back and neck back a little, leans in when reaching, and takes the spine's share of turning to look (rotation
## only). It runs before HandsOnTable, so the hands are kept out of the rack after the body has moved.
class Posture extends SkeletonModifier3D:
	const UPRIGHT := [["Spine1", 0.08], ["Spine2", 0.1], ["Neck", -0.04]] # radians back; the neck keeps eyes on the table
	var dayi: RiggedDayi

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		var right := (skeleton.global_basis.inverse() * (dayi.global_basis * Vector3.RIGHT)).normalized()
		for part: Array in UPRIGHT:
			var bone := skeleton.find_bone(BONE + part[0])
			if bone < 0:
				continue
			var pose := skeleton.get_bone_global_pose(bone)
			pose.basis = Basis(right, float(part[1])) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
		# Leaning in to reach: the lower back takes most of it.
		for part: Array in [["Spine", 0.6], ["Spine1", 0.4]]:
			ArmIK.turn(skeleton, skeleton.find_bone(BONE + part[0]), right, -dayi.lean * float(part[1]))
		# Turning to look: the chest turns a little with the head.
		for part: Array in [["Spine1", 0.15], ["Spine2", 0.2]]:
			ArmIK.turn(skeleton, skeleton.find_bone(BONE + part[0]), Vector3.UP, dayi.yaw * float(part[1]))


## Moves each hand the clip puts below the felt, short of the table edge, too wide, or into his rack onto the felt in
## front of the rack: two-bone IK on the arm toward the corrected wrist, elbow bending the way the clip had it, then
## the clip's wrist rotation is put back so the fingers keep their motion. Every hand joint and fingertip is checked.
class HandsOnTable extends SkeletonModifier3D:
	const MARGIN := 0.012 # fingertips and wrist stay this far above the felt
	const RACK_MARGIN := 0.015 # and this far out of the rack
	const ON_FELT := 0.06 # how far past the table edge a hand that rests on the table is moved
	const PASSES := 3
	const MAX_X := 0.34 # the clip spreads the hands ~0.5 m; keep them in front of his own rack, out of the neighbours' way
	var dayi: Node3D
	var rack: Rack

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		var to_dayi := dayi.global_transform.affine_inverse() * skeleton.global_transform
		var to_skeleton := to_dayi.affine_inverse()
		var felt := Table.TOP - Seat.SEAT_TOP
		var edge := -(Seat.CHAIR_DISTANCE - Table.SIZE * 0.5)
		for side in ["Left", "Right"]:
			var upper := skeleton.find_bone(BONE + side + "Arm")
			var lower := skeleton.find_bone(BONE + side + "ForeArm")
			var hand := skeleton.find_bone(BONE + side + "Hand")
			var hand_basis := skeleton.get_bone_global_pose(hand).basis
			# The arm may fall short of a corrected wrist, so measure again after each solve.
			for attempt in PASSES:
				var points := _hand_points(skeleton, hand, side, to_dayi)
				var wrist: Vector3 = points[0]
				var shift := Vector3.ZERO
				if attempt == 0:
					shift.x = signf(wrist.x) * minf(0.0, MAX_X - absf(wrist.x))
					shift.z = minf(0.0, edge - ON_FELT - wrist.z)
				var lowest := INF
				for point in points:
					lowest = minf(lowest, point.y)
				shift.y = maxf(0.0, felt + MARGIN - lowest)
				if rack:
					# Back toward him by however far the deepest joint would be in or past the rack.
					var back := 0.0
					var owner := (dayi.global_basis.inverse() * rack.global_basis.z).normalized()
					for point in points:
						back = maxf(back, rack.penetration(dayi.global_transform * (point + shift), RACK_MARGIN))
					shift += owner * back
				if shift.length() < 0.001:
					break
				ArmIK.reach(skeleton, upper, lower, hand, to_skeleton * (wrist + shift))
				var pose := skeleton.get_bone_global_pose(hand)
				pose.basis = hand_basis
				skeleton.set_bone_global_pose(hand, pose)

	## Wrist first, then every finger joint and tip of that hand, in the dayı's space.
	func _hand_points(skeleton: Skeleton3D, hand: int, side: String, to_dayi: Transform3D) -> Array[Vector3]:
		var points: Array[Vector3] = [to_dayi * skeleton.get_bone_global_pose(hand).origin]
		for bone in range(hand + 1, skeleton.get_bone_count()):
			if skeleton.get_bone_name(bone).begins_with(BONE + side + "Hand"):
				points.append(to_dayi * skeleton.get_bone_global_pose(bone).origin)
		return points


## Turns his neck and head toward RiggedDayi.yaw on top of the chest's share (Posture): the head takes the most,
## the neck little, since twisting a neckless caricature's neck alone stretches the collar. Also shakes "no".
class HeadTurn extends SkeletonModifier3D:
	var dayi: RiggedDayi
	var shake := 0.0
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		shake = maxf(0.0, shake - delta)

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		var wobble := sin(_time * 22.0) * 0.3 * shake / 0.9
		for part: Array in [[BONE + "Neck", 0.2], [BONE + "Head", 0.45]]:
			var bone := skeleton.find_bone(part[0])
			if bone < 0:
				continue
			var pose := skeleton.get_bone_global_pose(bone)
			pose.basis = Basis(Vector3.UP, (dayi.yaw + wobble) * float(part[1])) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
