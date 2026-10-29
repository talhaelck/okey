class_name Seat
extends Node3D
## One player's place at the table: chair, rack, a dayı (or first-person arms for the local player) and camera anchors.
## Built facing the table centre from the +Z side, then rotated by seat_index * 90°.

const RACK_DISTANCE := 0.6
const CHAIR_DISTANCE := 1.15
const SEAT_TOP := 0.48
const EYE := Vector3(0, 1.35, 1.05)
const ARMS := preload("res://assets/models/dayi/fp_arms.glb")
## Right hand's resting palm centre (the left one is mirrored): on the felt beside the rack, inside the rim.
const HAND_REST := Vector3(0.47, Table.TOP + 0.03, 0.66)

## The rigged Meshy dayı of each seat (seat 0 is the local player, who only shows his hands).
const DAYIS := ["esofmanli", "yasli", "gozluklu", "tespihli"]

@export var seat_index := 0
@export var is_local := false

var rack: Rack
var head_anchor: Marker3D
var rack_focus_anchor: Marker3D
var buddy: Buddy
## This player's tea glass (a physics body that can be knocked over).
var tea: TeaGlass
## How this seat's dayı looks (the local player only shows his hands).
var appearance := Appearance.random()
## Pivot of the local player's right hand, which reaches for tiles. Fingers point along its -Z.
var glove: Node3D
## Finger animation of the right hand.
var grip: FingerGrip
## The local player's left hand pivot and fingers; it only rests, breathes and drums.
var left_hand: Node3D
var left_grip: FingerGrip


func _ready() -> void:
	rotation.y = seat_index * PI * 0.5
	rack = Rack.new()
	rack.position = Vector3(0, Table.TOP, RACK_DISTANCE)
	add_child(rack)
	_build_chair()
	# Every player gets a glass of tea to the right of his rack.
	tea = TeaGlass.spawn(self, Vector3(0.6, Table.TOP, 0.58), randf() * TAU)
	if is_local:
		_build_hands()
		# Soft fill from behind the player so tile faces are readable under the overhead lamp.
		var fill := OmniLight3D.new()
		fill.position = EYE + Vector3(0, 0.25, 0.25)
		fill.light_color = Color(1.0, 0.9, 0.8)
		fill.light_energy = 0.5
		fill.omni_range = 1.6
		add_child(fill)
	else:
		buddy = Buddy.new()
		buddy.position = Vector3(0, SEAT_TOP, CHAIR_DISTANCE)
		add_child(buddy)
		buddy.setup_meshy(DAYIS[seat_index % DAYIS.size()])
	head_anchor = _marker(EYE, EYE + Vector3.FORWARD)
	var rack_centre := rack.position + Vector3(0, 0.08, -0.015)
	rack_focus_anchor = _marker(rack_centre + Vector3(0, 0.27, 0.34), rack_centre)


func _build_chair() -> void:
	# The classic white plastic kahvehane chair; the model faces +Z, so turn it toward the table.
	Mat.model(self, "plastic_monobloc_chair_01", Vector3(0, 0, CHAIR_DISTANCE + 0.04), PI)


# The player's own dayı hands resting on the table edge, with his tespih by the left one.
func _build_hands() -> void:
	var model: Node3D = ARMS.instantiate()
	add_child(model)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = HAND_REST * Vector3(side, 1, 1)
		# Turned in toward the rack, wrist a little higher than the fingertips.
		pivot.basis = Basis(Vector3.UP, side * 0.32) * Basis(Vector3.RIGHT, -0.16)
		add_child(pivot)
		var letter := "r" if side > 0 else "l"
		var arm: Node3D = model.find_child("arm_" + letter, true, false)
		arm.reparent(pivot, false)
		arm.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) # model fingers point +Z
		var fingers := FingerGrip.new()
		fingers.side = letter
		arm.find_children("*", "Skeleton3D", true, false)[0].add_child(fingers)
		if side > 0:
			glove = pivot
			grip = fingers
		else:
			left_hand = pivot
			left_grip = fingers
	model.queue_free()
	for mi: MeshInstance3D in find_children("skin_*", "MeshInstance3D", true, false):
		mi.material_override = skin_material(mi.get_active_material(0))
	for mi: MeshInstance3D in find_children("sleeve*", "MeshInstance3D", true, false):
		mi.material_override = Mat.textured("rough_linen", 0.05, Appearance.SHIRT, false, false)
	Mat.prop(self, "tespih", Vector3(-0.6, Table.TOP, 0.56), 0.4)


## MPFB's game-engine skin with a little light passing through, so the hands do not look like plastic.
static func skin_material(source: Material) -> Material:
	var m := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.3
	m.subsurf_scatter_skin_mode = true
	m.roughness = 0.62
	return m


func _marker(pos: Vector3, target: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(Basis.looking_at(target - pos), pos)
	add_child(m)
	return m
