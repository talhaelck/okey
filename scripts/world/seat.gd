class_name Seat
extends Node3D
## One player's place at the table: chair, rack, character (or gloves for the local player) and camera anchors.
## Built facing the table centre from the +Z side, then rotated by seat_index * 90°.

const RACK_DISTANCE := 0.5
const CHAIR_DISTANCE := 1.0
const SEAT_TOP := 0.48
const EYE := Vector3(0, 1.15, 0.92)
const GLOVE := Color(0.97, 0.97, 0.97)

@export var seat_index := 0
@export var is_local := false
## Mascot kind (panda/bunny/dinosaur) or legacy glTF filename; unused for the local player.
@export var character := ""
## Overall model height in metres (sitting models need less than standing ones).
@export var character_height := 0.85

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
	elif not character.is_empty():
		buddy = Buddy.new()
		buddy.position = Vector3(0, SEAT_TOP, CHAIR_DISTANCE)
		add_child(buddy)
		buddy.setup(character, character_height)
	head_anchor = _marker(EYE, EYE + Vector3.FORWARD)
	var rack_centre := rack.position + Vector3(0, 0.08, -0.015)
	rack_focus_anchor = _marker(rack_centre + Vector3(0, 0.27, 0.34), rack_centre)


func _build_chair() -> void:
	var wood := Color(0.5, 0.28, 0.16)
	Toon.part(self, RoundedBox.build(Vector3(0.46, 0.06, 0.44), 0.025), Color(0.75, 0.2, 0.25),
		Vector3(0, 0.45, CHAIR_DISTANCE + 0.02))
	Toon.part(self, RoundedBox.build(Vector3(0.46, 0.5, 0.06), 0.025), wood, Vector3(0, 0.74, CHAIR_DISTANCE + 0.23))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		Toon.part(self, Toon.cylinder(0.025, 0.42), wood,
			Vector3(corner.x * 0.19, 0.21, CHAIR_DISTANCE + 0.02 + corner.y * 0.18))


# Cartoon gloves resting on the table edge, like the player's own hands.
func _build_hands() -> void:
	for side in [-1, 1]:
		var hand := Toon.part(self, Toon.sphere(0.045), GLOVE, Vector3(side * 0.3, Table.TOP + 0.045, 0.66))
		hand.scale = Vector3(1.0, 0.8, 1.15)
		if side == 1:
			glove = hand


func _marker(pos: Vector3, target: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(Basis.looking_at(target - pos), pos)
	add_child(m)
	return m
