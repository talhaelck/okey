class_name Seat
extends Node3D
## One player's place at the table: chair, rack, a dayı (or gloves for the local player) and camera anchors.
## Built facing the table centre from the +Z side, then rotated by seat_index * 90°.

const RACK_DISTANCE := 0.6
const CHAIR_DISTANCE := 1.15
const SEAT_TOP := 0.48
const EYE := Vector3(0, 1.35, 1.05)
const GLOVE := Color(0.88, 0.62, 0.48)

@export var seat_index := 0
@export var is_local := false

var rack: Rack
var head_anchor: Marker3D
var rack_focus_anchor: Marker3D
var buddy: Buddy
## The local player's right glove, which reaches for tiles.
var glove: MeshInstance3D


func _ready() -> void:
	rotation.y = seat_index * PI * 0.5
	rack = Rack.new()
	rack.position = Vector3(0, Table.TOP, RACK_DISTANCE)
	add_child(rack)
	_build_chair()
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
		buddy.setup(Appearance.random())
	head_anchor = _marker(EYE, EYE + Vector3.FORWARD)
	var rack_centre := rack.position + Vector3(0, 0.08, -0.015)
	rack_focus_anchor = _marker(rack_centre + Vector3(0, 0.27, 0.34), rack_centre)


func _build_chair() -> void:
	# The classic white plastic kahvehane chair; the model faces +Z, so turn it toward the table.
	Mat.model(self, "plastic_monobloc_chair_01", Vector3(0, 0, CHAIR_DISTANCE + 0.04), PI)


# The player's own hands resting on the table edge.
func _build_hands() -> void:
	for side in [-1, 1]:
		var hand := Mat.part(self, Mat.sphere(0.045), GLOVE, Vector3(side * 0.3, Table.TOP + 0.045, 0.72))
		hand.scale = Vector3(1.0, 0.8, 1.15)
		if side == 1:
			glove = hand


func _marker(pos: Vector3, target: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(Basis.looking_at(target - pos), pos)
	add_child(m)
	return m
