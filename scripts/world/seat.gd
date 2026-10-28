class_name Seat
extends Node3D
## One player's place at the table: chair, rack, character (or gloves for the local player) and camera anchors.
## Built facing the table centre from the +Z side, then rotated by seat_index * 90°.

const RACK_DISTANCE := 0.5
const CHAIR_DISTANCE := 1.0
const SEAT_TOP := 0.48
const EYE := Vector3(0, 1.28, 1.30)
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
var _arm_meshes: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []


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
	var wood := SurfaceStyle.textured(Color("3d291d"), SurfaceStyle.Kind.WOOD, 0.54, true)
	var leather := SurfaceStyle.textured(Color("50302b"), SurfaceStyle.Kind.LEATHER, 0.72)
	SurfaceStyle.box(self, Vector3(0.48,0.07,0.45), Vector3(0,0.445,CHAIR_DISTANCE+0.02), wood, 0.025)
	SurfaceStyle.box(self, Vector3(0.44,0.065,0.41), Vector3(0,0.475,CHAIR_DISTANCE+0.02), leather, 0.03)
	SurfaceStyle.box(self, Vector3(0.48,0.52,0.065), Vector3(0,0.73,CHAIR_DISTANCE+0.23), wood, 0.025)
	SurfaceStyle.box(self, Vector3(0.39,0.40,0.055), Vector3(0,0.75,CHAIR_DISTANCE+0.19), leather, 0.025)
	for x in [-0.18,0.18]:
		for y in [0.59,0.91]:
			SurfaceStyle.part(self, Toon.sphere(0.006), SurfaceStyle.metal(), Vector3(x,y,CHAIR_DISTANCE+0.155))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		SurfaceStyle.part(self, Toon.cylinder(0.025, 0.42), wood,
			Vector3(corner.x * 0.19, 0.21, CHAIR_DISTANCE + 0.02 + corner.y * 0.18))


# Cartoon gloves resting on the table edge, like the player's own hands.
func _build_hands() -> void:
	for side in [-1, 1]:
		var hand := SurfaceStyle.part(self, Toon.sphere(0.044), SurfaceStyle.textured(Color("b1a393"), SurfaceStyle.Kind.LEATHER), Vector3(side * 0.30, Table.TOP + 0.045, 0.77))
		hand.scale = Vector3(1.0, 0.8, 1.15)
		_hands.append(hand)
		for finger in 3:
			var tip := SurfaceStyle.part(hand, Toon.sphere(0.014), SurfaceStyle.textured(Color("b1a393"), SurfaceStyle.Kind.LEATHER), Vector3((finger-1)*0.023,0,-0.03))
			tip.scale = Vector3(0.85,0.85,1.5)
		SurfaceStyle.part(hand, Toon.sphere(0.018), SurfaceStyle.textured(Color("b1a393"), SurfaceStyle.Kind.LEATHER), Vector3(-side*0.034,0.002,-0.006))
		SurfaceStyle.rod(self, Vector3(side*0.4,0.6,1.13), Vector3(side*0.33,0.71,0.97), 0.065, SurfaceStyle.textured(Color("34413b"), SurfaceStyle.Kind.FABRIC))
		var arm := SurfaceStyle.part(self, Toon.cylinder(0.044,1.0,0.038), SurfaceStyle.textured(Color("34413b"), SurfaceStyle.Kind.FABRIC))
		_arm_meshes.append(arm)
		if side == 1:
			glove = hand


func _process(_delta: float) -> void:
	for i in _arm_meshes.size():
		var start := Vector3((-1 if i == 0 else 1)*0.33,0.71,0.97)
		var end := _hands[i].position
		var direction := end-start
		_arm_meshes[i].position = (start+end)*0.5
		_arm_meshes[i].quaternion = Quaternion(Vector3.UP, direction.normalized())
		_arm_meshes[i].scale = Vector3(1,direction.length(),1)


func _marker(pos: Vector3, target: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(Basis.looking_at(target - pos), pos)
	add_child(m)
	return m
