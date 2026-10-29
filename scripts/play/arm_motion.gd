class_name ArmMotion
extends Node
## Moves one first-person arm like a real arm: springy, lifting over things on the way to its goal, and never
## sinking into the felt, the racks or the draw pile. Closes the fingers on request and, while resting,
## breathes and now and then drums its fingers on the table.
## The pivot is the palm centre with fingers along its -Z and the forearm along +Z (see Seat._build_hands).

const OMEGA := 22.0 # spring stiffness, critically damped: quick enough to keep up with a dragged tile
const TURN := 14.0
const TRAVEL_LIFT := 0.15 # how high the hand rises per metre still to travel
const MAX_LIFT := 0.04
const FINGERTIPS := 0.075 # palm centre to fingertips
## Points along the hand checked against obstacles: [distance toward the elbow (- = toward the fingertips), margin].
const SAMPLES := [[-0.075, 0.006], [-0.035, 0.012], [0.0, 0.02], [0.07, 0.03], [0.16, 0.04]]

var pivot: Node3D
var grip: FingerGrip
var table: Table
var racks: Array[Rack] = []
var rest: Transform3D
var goal: Transform3D
## When true the goal is the rest pose, with breathing and finger drumming.
var resting := true
var grip_goal := 0.0

var _body := AnimatableBody3D.new() # the arm's solid shape, so it pushes tiles and glasses
var _velocity := Vector3.ZERO
var _time := randf() * 10.0
var _drum_in := randf_range(2.0, 5.0)


func setup(arm_pivot: Node3D, fingers: FingerGrip) -> void:
	pivot = arm_pivot
	grip = fingers
	rest = pivot.global_transform
	goal = rest
	# Hand from fingertips to wrist, then the forearm toward the elbow (pivot: fingers -Z, forearm +Z).
	_body.collision_layer = Colliders.HANDS
	_body.collision_mask = Colliders.TILES | Colliders.PROPS
	_body.sync_to_physics = true
	Colliders.capsule_z(_body, 0.024, 0.13, Vector3(0, -0.005, -0.03))
	Colliders.capsule_z(_body, 0.034, 0.3, Vector3(0, 0.0, 0.17))
	add_child(_body)
	_body.global_transform = rest


func arrived(tolerance := 0.012) -> bool:
	return pivot.global_position.distance_to(goal.origin) < tolerance and _velocity.length() < 0.25


func _process(delta: float) -> void:
	_time += delta
	if resting:
		goal = rest
		goal.origin += Vector3(sin(_time * 0.7) * 0.004, sin(_time * 1.3) * 0.003, cos(_time * 0.9) * 0.003)
		_drum(delta)
	else:
		grip.drum = move_toward(grip.drum, 0.0, delta * 4.0)

	# Travel high, settle low: lift the aim point by how far there still is to go.
	var target := goal
	var away := Vector2(target.origin.x - pivot.global_position.x, target.origin.z - pivot.global_position.z).length()
	target.origin.y += minf(MAX_LIFT, away * TRAVEL_LIFT)
	target.origin.y += _lift(target)

	var position := pivot.global_position
	_velocity += ((target.origin - position) * OMEGA * OMEGA - _velocity * 2.0 * OMEGA) * delta
	position += _velocity * delta
	var pose := Transform3D(pivot.global_basis.orthonormalized().slerp(target.basis.orthonormalized(), 1.0 - exp(-TURN * delta)), position)
	var lift := _lift(pose)
	if lift > 0.0:
		pose.origin.y += lift
		_velocity.y = maxf(_velocity.y, 0.0)
	pivot.global_transform = pose
	grip.grip = move_toward(grip.grip, grip_goal, delta * 6.5)


func _physics_process(_delta: float) -> void:
	if pivot:
		_body.global_transform = pivot.global_transform.orthonormalized()


## How far the pose must rise so no part of the hand is inside the table, a rack or the pile.
func _lift(pose: Transform3D) -> float:
	var lift := 0.0
	for sample: Array in SAMPLES:
		var point := pose.origin + pose.basis.z * float(sample[0])
		var floor_y := table.clearance(point)
		for rack in racks:
			floor_y = maxf(floor_y, rack.clearance(point))
		lift = maxf(lift, floor_y + float(sample[1]) - point.y)
	return lift


func _drum(delta: float) -> void:
	_drum_in -= delta
	if _drum_in < 0.0:
		grip.drum = move_toward(grip.drum, 1.0, delta * 5.0)
		if _drum_in < -1.8:
			_drum_in = randf_range(3.0, 8.0)
	else:
		grip.drum = move_toward(grip.drum, 0.0, delta * 3.0)
