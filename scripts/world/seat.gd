class_name Seat
extends Node3D
## One player's place at the table: chair, rack, a dayı (or gloves for the local player) and camera anchors.
## Built facing the table centre from the +Z side, then rotated by seat_index * 90°.

const RACK_DISTANCE := 0.6
const CHAIR_DISTANCE := 1.15
const SEAT_TOP := 0.48
const EYE := Vector3(0, 1.35, 1.05)
const HANDS := preload("res://assets/models/dayi/hands.glb")
const HAND_REST := Vector3(0.28, Table.TOP + 0.022, 0.74)

@export var seat_index := 0
@export var is_local := false

var rack: Rack
var head_anchor: Marker3D
var rack_focus_anchor: Marker3D
var buddy: Buddy
## How this seat's dayı looks (the local player only shows his hands).
var appearance := Appearance.random()
## Pivot of the local player's right hand, which reaches for tiles. Fingers point along its -Z.
var glove: Node3D


func _ready() -> void:
	rotation.y = seat_index * PI * 0.5
	rack = Rack.new()
	rack.position = Vector3(0, Table.TOP, RACK_DISTANCE)
	add_child(rack)
	_build_chair()
	# Every player gets a glass of tea to the right of his rack.
	Mat.prop(self, "tea_set", Vector3(0.52, Table.TOP, 0.56), randf() * TAU)
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
		buddy.setup(appearance)
	head_anchor = _marker(EYE, EYE + Vector3.FORWARD)
	var rack_centre := rack.position + Vector3(0, 0.08, -0.015)
	rack_focus_anchor = _marker(rack_centre + Vector3(0, 0.27, 0.34), rack_centre)


func _build_chair() -> void:
	# The classic white plastic kahvehane chair; the model faces +Z, so turn it toward the table.
	Mat.model(self, "plastic_monobloc_chair_01", Vector3(0, 0, CHAIR_DISTANCE + 0.04), PI)


# The player's own dayı hands resting on the table edge, with his tespih by the left one.
func _build_hands() -> void:
	var model: Node3D = HANDS.instantiate()
	add_child(model)
	appearance.apply(model)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = HAND_REST * Vector3(side, 1, 1)
		pivot.rotation.y = side * 0.12
		add_child(pivot)
		var hand: Node3D = model.find_child("hand_r" if side > 0 else "hand_l", true, false)
		hand.reparent(pivot, false)
		hand.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) # model fingers point +Z
		if side > 0:
			glove = pivot
	model.queue_free()
	Mat.prop(self, "tespih", Vector3(-0.5, Table.TOP, 0.6), 0.4)


func _marker(pos: Vector3, target: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(Basis.looking_at(target - pos), pos)
	add_child(m)
	return m
