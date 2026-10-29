class_name FingerGrip
extends SkeletonModifier3D
## Finger animation for a first-person hand on top of its relaxed rest pose (tools/blender/fp_hands.py):
## a thumb-and-index pinch for holding tiles, and drumming on the felt while idle.
## The rest pose is palm down with fingers along +Z, so curling is a rotation about the skeleton's X axis.

## Extra curl in degrees per joint at full grip: index and middle pinch, ring and pinky tuck into the palm.
const GRIP := {
	"index": [30.0, 40.0, 26.0], "middle": [38.0, 48.0, 30.0],
	"ring": [58.0, 66.0, 40.0], "pinky": [64.0, 70.0, 42.0],
}
const THUMB := [18.0, 26.0, 22.0]
const DRUM_ORDER := ["pinky", "ring", "middle", "index"]
const DRUM_LIFT := 24.0

## "r" or "l": which hand's bones this drives.
var side := "r"
## 0 = relaxed, 1 = pinching a tile.
var grip := 0.0
## 0..1 strength of the idle finger drumming.
var drum := 0.0

var _time := randf() * 10.0


func _process(delta: float) -> void:
	_time += delta


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or (grip <= 0.001 and drum <= 0.001):
		return
	for finger: String in GRIP:
		var curls: Array = GRIP[finger]
		var tap := 0.0
		if drum > 0.0:
			# Fingers fall one after another, pinky first, like waiting for your turn.
			var phase := _time * 9.0 - DRUM_ORDER.find(finger) * 0.85
			tap = pow(maxf(0.0, sin(phase)), 3.0) * DRUM_LIFT * drum
		for j in 3:
			var degrees: float = curls[j] * grip - (tap if j == 0 else tap * 0.3)
			_bend(skeleton, "%s_0%d_%s" % [finger, j + 1, side], Vector3.RIGHT, degrees)
	# The thumb swings in under the index finger.
	var thumb_axis := Vector3(0.0, -1.0, -1.0 if side == "r" else 1.0).normalized()
	for j in 3:
		_bend(skeleton, "thumb_0%d_%s" % [j + 1, side], thumb_axis, THUMB[j] * grip)


func _bend(skeleton: Skeleton3D, bone_name: String, axis: Vector3, degrees: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0 or absf(degrees) < 0.01:
		return
	# Rotate about a skeleton-space axis, expressed in the parent's space so the rest of the chain follows.
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var turn := Basis(axis, deg_to_rad(degrees))
	var local := Basis(skeleton.get_bone_pose_rotation(bone))
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * turn * parent_basis * local).get_rotation_quaternion())
