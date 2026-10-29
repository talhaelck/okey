class_name DayiHands
extends SkeletonModifier3D
## A seated RiggedDayi's hands handling real tiles, on top of his mocap clip. Runs after the clip and HandsOnTable.
## Per hand, `weight` blends from the clip (0) to the action (1): the pinch point between thumb and index tips is
## carried to `point` by arm IK, the hand turns toward `fingers` / `palm`, and the fingers close by `grip`.
## A held tile is locked to the hand (a socket: the tile keeps the offset it had when pinched), so it really is in
## his hand wherever the hand goes, and is handed to the rack or the felt when let go.
## The actions (rearrange, discard, pick_up) are timed like a person: the head turns first, the body leans in,
## the hand speeds up and settles, fingers close, the tile is lifted, carried on an arc and set down.
## Points and directions are in the dayı's space (Buddy space: origin on the seat, -Z toward the table centre).

const BONE := "mixamorig_"
## Extra curl in degrees per joint when pinching: thumb and index meet, the others tuck in.
const PINCH := {
	"Thumb": [8.0, 18.0, 16.0], "Index": [22.0, 30.0, 20.0], "Middle": [34.0, 40.0, 26.0],
	"Ring": [50.0, 56.0, 34.0], "Pinky": [56.0, 60.0, 38.0],
}
const REACH_TIME := 0.6
const SETTLE_TIME := 0.18
const CARRY_TIME := 0.55
const LIFT := 0.035 # tiles come this far up off the felt before being carried
## Out of a rack slot a tile comes all the way up before it moves sideways, so it never slides through its neighbours.
const RACK_LIFT := TileFactory.SIZE.y + 0.02
const ARC := 0.06 # carried tiles rise this high mid-way
const LEAN := 0.4 # radians the upper body leans in for the farthest reach
const EASY_REACH := 0.75 # of his arm's length: closer than this he does not lean at all

var dayi: RiggedDayi
var hands: Array[HandState] = []


class HandState:
	var side := "Right"
	var sign := 1.0 # +1 for his right hand (+X), -1 for his left
	var upper := -1
	var lower := -1
	var wrist := -1
	var fingers := {} # finger name -> [joint 1, 2, 3, tip]
	var palm_sign := 1.0
	var weight := 0.0
	var grip := 0.0
	var point := Vector3.ZERO
	var aim := Vector3.FORWARD
	var palm := Vector3.DOWN
	var pinch := Vector3.ZERO # where the pinch point is now
	var tile: Tile
	var tile_offset := Transform3D()
	var flat := 0.0 # 0 = the tile as pinched, 1 = laid flat at flat_pose (fingers turning it to set it down)
	var flat_pose := Transform3D()
	var busy := false
	var lean := 0.0 # 0..1, how much this hand's current target needs him to lean in
	var arm := 0.5 # shoulder to wrist, fully stretched
	var miss := 0.0 # how far the pinch point was from the tile when it closed (tests check this)


func setup(owner_dayi: RiggedDayi) -> void:
	dayi = owner_dayi
	var skeleton := get_skeleton()
	for side in ["Left", "Right"]:
		var hand := HandState.new()
		hand.side = side
		hand.sign = -1.0 if side == "Left" else 1.0
		hand.upper = skeleton.find_bone(BONE + side + "Arm")
		hand.lower = skeleton.find_bone(BONE + side + "ForeArm")
		hand.wrist = skeleton.find_bone(BONE + side + "Hand")
		var rest := func(bone: int) -> Vector3: return skeleton.get_bone_global_rest(bone).origin
		hand.arm = (rest.call(hand.upper) - rest.call(hand.lower)).length() + (rest.call(hand.lower) - rest.call(hand.wrist)).length()
		hand.arm *= skeleton.global_basis.get_scale().x
		for finger in PINCH:
			var joints: Array[int] = []
			for j in range(1, 5):
				joints.append(skeleton.find_bone("%s%sHand%s%d" % [BONE, side, finger, j]))
			if joints.min() >= 0:
				hand.fingers[finger] = joints
		# Mixamo rests in a T/A-pose with the palms down; that fixes which way the palm normal points.
		var along: Vector3 = rest.call(hand.fingers.Middle[0]) - rest.call(hand.wrist)
		var across: Vector3 = rest.call(hand.fingers.Index[0]) - rest.call(_outer(hand)[0])
		hand.palm_sign = -1.0 if along.cross(across).y > 0.0 else 1.0
		hands.append(hand)


func hand_for(point: Vector3) -> HandState:
	return hands[1] if point.x >= 0.0 else hands[0]


# --- Actions -----------------------------------------------------------------------------------------------

## Picks the tile in `from` up and puts it into the free slot `to` on the same rack.
func rearrange(rack: Rack, from: int, to: int) -> void:
	var tile := rack.tile_at(from)
	var hand := hand_for(_slot_top(rack, from))
	if tile == null or hand.busy or rack.tile_at(to) != null:
		return
	hand.busy = true
	await _take(hand, _slot_top(rack, from), _rack_aim(hand), func() -> void: rack.release(tile), tile, RACK_LIFT)
	await _carry(hand, _slot_top(rack, to) + Vector3.UP * RACK_LIFT, CARRY_TIME)
	await _move(hand, _slot_top(rack, to), SETTLE_TIME * 1.4)
	rack.put(_let_go(hand), to, true, 0.1)
	await _retreat(hand)


## Takes the tile in `slot` off the rack and sets it down on the felt at `spot` (a point on the felt): while the
## hand comes down the fingers turn it face up, readable for him, and let go just above the felt; it lands by physics.
func discard(rack: Rack, slot: int, table: Table, spot: Vector3) -> Tile:
	var tile := rack.tile_at(slot)
	var hand := hand_for(spot)
	if tile == null or hand.busy:
		return null
	hand.busy = true
	await _take(hand, _slot_top(rack, slot), _rack_aim(hand), func() -> void: rack.release(tile), tile, RACK_LIFT)
	var yaw := dayi.global_rotation.y
	var at := table.to_local(dayi.to_global(spot))
	at.y = Table.TOP + TileFactory.SIZE.z * 0.5 + Table.DROP_HEIGHT
	hand.flat_pose = table.global_transform * Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), at)
	var release := spot + Vector3.UP * (TileFactory.SIZE.z + Table.DROP_HEIGHT + 0.006)
	# Out over the end of the rack at the height it left the slot, then down beside it.
	var over := Vector3(spot.x, hand.point.y, spot.z)
	_plan_lean(hand, spot)
	await _carry(hand, over, CARRY_TIME, _felt_aim(hand))
	await _carry(hand, release + Vector3.UP * 0.05, CARRY_TIME * 0.6, Basis(), 0.0)
	var lay := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lay.tween_property(hand, "flat", 1.0, SETTLE_TIME * 1.5)
	await _move(hand, release, SETTLE_TIME * 1.5)
	table.put_loose(_let_go(hand), dayi.to_global(spot), yaw)
	hand.flat = 0.0
	await _retreat(hand)
	return tile


## Picks a loose tile up from the felt and puts it into the free slot `to`.
func pick_up(tile: Tile, table: Table, rack: Rack, to: int) -> void:
	var top := dayi.to_local(tile.global_position) + Vector3.UP * TileFactory.SIZE.z * 0.5
	var hand := hand_for(top)
	if hand.busy or rack.tile_at(to) != null:
		return
	hand.busy = true
	await _take(hand, top, _felt_aim(hand), func() -> void: table.release(tile), tile)
	# Straight up to above the rack's tiles, across, and down into the slot.
	var above := _slot_top(rack, to) + Vector3.UP * RACK_LIFT
	_plan_lean(hand, above)
	await _carry(hand, Vector3(top.x, above.y, top.z), CARRY_TIME * 0.6, _rack_aim(hand), 0.0)
	await _carry(hand, above, CARRY_TIME)
	await _move(hand, _slot_top(rack, to), SETTLE_TIME * 1.4)
	rack.put(_let_go(hand), to, true, 0.1)
	await _retreat(hand)


# Head first, then the arm: reach just above `top`, settle onto it, pinch, and lift the tile out.
func _take(hand: HandState, top: Vector3, aim: Basis, detach: Callable, tile: Tile, lift := LIFT) -> void:
	dayi.look_at_point(top)
	_plan_lean(hand, top)
	await get_tree().create_timer(0.15).timeout
	hand.point = hand.pinch
	hand.aim = -aim.z
	hand.palm = -aim.y
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blend.tween_property(hand, "weight", 1.0, REACH_TIME)
	await _carry(hand, top + Vector3.UP * 0.03, REACH_TIME)
	await _move(hand, top, SETTLE_TIME)
	hand.miss = hand.pinch.distance_to(top)
	await _close(hand, 1.0)
	detach.call()
	tile.pin()
	tile.holder = null
	hand.tile = tile
	hand.tile_offset = _hand_world(hand).affine_inverse() * tile.global_transform
	await _move(hand, top + Vector3.UP * lift, SETTLE_TIME * (1.0 + lift * 6.0))


# Opens the fingers on the held tile and returns it (the caller puts it somewhere).
func _let_go(hand: HandState) -> Tile:
	var tile := hand.tile
	hand.tile = null
	create_tween().tween_property(hand, "grip", 0.0, 0.15)
	return tile


# The hand comes back up and the clip takes the arm over again; the head goes back to the table.
func _retreat(hand: HandState) -> void:
	await get_tree().create_timer(0.12).timeout
	_move(hand, hand.point + Vector3(0, 0.05, 0.08), REACH_TIME)
	var blend := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blend.tween_property(hand, "weight", 0.0, REACH_TIME)
	dayi.look_at_point(Vector3.ZERO, true)
	await blend.finished
	hand.busy = false


func _close(hand: HandState, amount: float) -> void:
	var tween := create_tween()
	tween.tween_property(hand, "grip", amount, 0.16)
	await tween.finished


## Moves the pinch point in a straight eased line.
func _move(hand: HandState, to: Vector3, time: float) -> void:
	await _carry(hand, to, time, Basis(), 0.0)


## Moves the pinch point along an arc that rises `arc` mid-way, easing in and out; turns the hand to `aim` if given.
func _carry(hand: HandState, to: Vector3, time: float, aim := Basis(), arc := ARC) -> void:
	var from := hand.point
	var from_aim := hand.aim
	var from_palm := hand.palm
	var turn := aim != Basis()
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var e := smoothstep(0.0, 1.0, t)
		hand.point = from.lerp(to, e) + Vector3.UP * arc * sin(PI * e)
		if turn:
			hand.aim = from_aim.slerp(-aim.z, e)
			hand.palm = from_palm.slerp(-aim.y, e)
	, 0.0, 1.0, time)
	await tween.finished


# Pinching an upright rack tile by its top edge: fingers nearly straight down, so none reach through the board.
func _rack_aim(hand: HandState) -> Basis:
	return _aim_basis(Vector3(-hand.sign * 0.15, -0.95, -0.15))


# Pinching a tile lying on the felt: fingers forward and down, which keeps the wrist back and the reach long.
func _felt_aim(hand: HandState) -> Basis:
	return _aim_basis(Vector3(-hand.sign * 0.2, -0.45, -0.9))


func _aim_basis(fingers: Vector3) -> Basis:
	var f := fingers.normalized()
	# Palm faces down, or toward the table centre (-Z) when the fingers themselves point almost straight down.
	var toward := Vector3.DOWN.lerp(Vector3.FORWARD, clampf((-f.y - 0.6) / 0.35, 0.0, 1.0))
	var palm := (toward - f * toward.dot(f)).normalized()
	return Basis(f.cross(-palm), -palm, -f) # -z = fingers, -y = palm


func _slot_top(rack: Rack, slot: int) -> Vector3:
	var at := rack.slot_global_transform(slot)
	return dayi.to_local(at.origin + at.basis.y.normalized() * (TileFactory.SIZE.y * 0.5 + 0.004))


# How much a reach to `point` needs him to lean in: none within an easy reach of the shoulder, fully at arm's length.
func _plan_lean(hand: HandState, point: Vector3) -> void:
	var skeleton := get_skeleton()
	var shoulder := dayi.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hand.upper).origin))
	hand.lean = clampf((shoulder.distance_to(point) / hand.arm - EASY_REACH) / (1.0 - EASY_REACH), 0.0, 1.0)


func _hand_world(hand: HandState) -> Transform3D:
	var skeleton := get_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(hand.wrist)


# --- Posing ------------------------------------------------------------------------------------------------

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if dayi == null or hands.is_empty():
		return
	var to_dayi := dayi.global_transform.affine_inverse() * skeleton.global_transform
	var to_skeleton := to_dayi.affine_inverse()
	var lean := 0.0
	for hand in hands:
		lean = maxf(lean, hand.weight * hand.lean)
		if hand.weight > 0.001 or hand.grip > 0.001:
			_pose(skeleton, hand, to_skeleton)
		hand.pinch = to_dayi * _pinch_point(skeleton, hand)
		if hand.tile:
			var held := _hand_world(hand) * hand.tile_offset
			hand.tile.global_transform = held.interpolate_with(hand.flat_pose, hand.flat) if hand.flat > 0.0 else held
	dayi.lean = lean * LEAN


func _pose(skeleton: Skeleton3D, hand: HandState, to_skeleton: Transform3D) -> void:
	# Turn the hand toward the action's direction, as much as the weight says.
	var wrist := skeleton.get_bone_global_pose(hand.wrist)
	var now := _frame(skeleton, hand)
	var want := _orthonormal(to_skeleton.basis * hand.aim, to_skeleton.basis * hand.palm)
	var turn := Quaternion.IDENTITY.slerp((want * now.inverse()).get_rotation_quaternion(), hand.weight)
	var hand_basis := Basis(turn) * wrist.basis
	skeleton.set_bone_global_pose(hand.wrist, Transform3D(hand_basis, wrist.origin))
	# Close the fingers, then carry the pinch point to its goal with the arm.
	var palm := _palm_normal(skeleton, hand)
	for finger: String in hand.fingers:
		var joints: Array = hand.fingers[finger]
		for j in 3:
			var along: Vector3 = skeleton.get_bone_global_pose(joints[j + 1]).origin - skeleton.get_bone_global_pose(joints[j]).origin
			ArmIK.turn(skeleton, joints[j], along.cross(palm), deg_to_rad(PINCH[finger][j] * hand.grip))
	var offset := _pinch_point(skeleton, hand) - wrist.origin
	var goal := wrist.origin.lerp(to_skeleton * hand.point - offset, hand.weight)
	ArmIK.reach(skeleton, hand.upper, hand.lower, hand.wrist, goal)
	var reached := skeleton.get_bone_global_pose(hand.wrist)
	skeleton.set_bone_global_pose(hand.wrist, Transform3D(hand_basis, reached.origin))


func _pinch_point(skeleton: Skeleton3D, hand: HandState) -> Vector3:
	var thumb: Vector3 = skeleton.get_bone_global_pose(hand.fingers.Thumb[3]).origin
	var index: Vector3 = skeleton.get_bone_global_pose(hand.fingers.Index[3]).origin
	return (thumb + index) * 0.5


# The hand's current orientation as a basis: -z along the fingers, -y out of the palm.
func _frame(skeleton: Skeleton3D, hand: HandState) -> Basis:
	var along := skeleton.get_bone_global_pose(hand.fingers.Middle[0]).origin - skeleton.get_bone_global_pose(hand.wrist).origin
	return _orthonormal(along, _palm_normal(skeleton, hand))


func _orthonormal(fingers: Vector3, palm: Vector3) -> Basis:
	var f := fingers.normalized()
	var p := (palm - f * palm.dot(f)).normalized()
	return Basis(f.cross(-p), -p, -f)


func _palm_normal(skeleton: Skeleton3D, hand: HandState) -> Vector3:
	var along := skeleton.get_bone_global_pose(hand.fingers.Middle[0]).origin - skeleton.get_bone_global_pose(hand.wrist).origin
	var across := skeleton.get_bone_global_pose(hand.fingers.Index[0]).origin - skeleton.get_bone_global_pose(_outer(hand)[0]).origin
	return (along.cross(across) * hand.palm_sign).normalized()


# The outermost finger: the pinky, or the ring finger on a rig without one.
func _outer(hand: HandState) -> Array:
	return hand.fingers.get("Pinky", hand.fingers.Ring)
