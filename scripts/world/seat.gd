class_name Seat
extends Node3D
## One player's place at the table: chair, rack, character (or gloves for the local player) and camera anchors.
## Built facing the table centre from the +Z side, then rotated by seat_index * 90°.

const RACK_DISTANCE := 0.50
const CHAIR_DISTANCE := 0.96
const SEAT_TOP := 0.55
const EYE := Vector3(0, 1.32, 1.16)
const GLOVE := Color(0.97, 0.97, 0.97)
const PATRON_NAMES := {
	"sabri": "Sabri Dayı",
	"temel": "Temel Reis",
	"rifki": "Rıfkı Amca",
	"davut": "Davut Usta",
}

@export var seat_index := 0
@export var is_local := false
@export var character := "sabri"
@export var character_height := 0.85

var rack: Rack
var head_anchor: Marker3D
var rack_focus_anchor: Marker3D
var buddy: Buddy
## The local player's right hand, which reaches for tiles & props.
var glove: MeshInstance3D
var left_hand: MeshInstance3D
var _arm_meshes: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []
var _knock_tween: Tween
var _left_rest := Vector3.ZERO


func display_name() -> String:
	var base_name: String = PATRON_NAMES.get(character, character.capitalize())
	if is_local:
		return "%s (Sen)" % base_name
	return base_name


func _ready() -> void:
	rotation.y = seat_index * PI * 0.5
	rack = Rack.new()
	rack.is_opponent = not is_local
	rack.position = Vector3(0, Table.TOP, 0.57) if is_local else Vector3(0, Table.TOP, RACK_DISTANCE)
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
	var rack_centre := rack.position + Vector3(0, 0.056, -0.01)
	rack_focus_anchor = _marker(rack_centre + Vector3(0, 0.24, 0.34), rack_centre)


func _build_chair() -> void:
	var chair_glb: Node3D = load("res://assets/models/table_details/kiraathane_chair.glb").instantiate()
	chair_glb.name = "KiraathaneChair"
	chair_glb.position = Vector3(0, 0, CHAIR_DISTANCE)
	add_child(chair_glb)


func _build_hands() -> void:
	var sleeve_colors := {
		"sabri": Color("82151d"),
		"rifki": Color("4e321e"),
		"temel": Color("2e4228"),
		"davut": Color("1e3450"),
	}
	var sleeve_mat := SurfaceStyle.textured(sleeve_colors.get(character, Color("82151d")), SurfaceStyle.Kind.FABRIC)
	for side in [-1, 1]:
		var hand := MeshInstance3D.new()
		hand.position = Vector3(side*0.37,Table.TOP+0.042,0.75)
		add_child(hand)
		var path := "res://assets/models/patrons/local_hand_left.glb" if side == -1 else "res://assets/models/patrons/local_hand.glb"
		var model: Node3D = load(path).instantiate()
		hand.add_child(model)
		_hands.append(hand)
		if side == -1:
			_left_rest = hand.position
			left_hand = hand
		SurfaceStyle.rod(self, Vector3(side*0.4,0.6,1.13), Vector3(side*0.33,0.71,0.97), 0.065, sleeve_mat)
		var arm := SurfaceStyle.part(self, Toon.cylinder(0.044,1.0,0.038), sleeve_mat)
		_arm_meshes.append(arm)
		if side == 1:
			glove = hand
	if not character.is_empty():
		var path := "res://assets/models/patrons/%s.glb" % character
		if ResourceLoader.exists(path):
			var local_body: Node3D = load(path).instantiate()
			local_body.name = "LocalPlayerBody"
			local_body.position = Vector3(0, SEAT_TOP, CHAIR_DISTANCE)
			var omit_keywords := [
				"head", "skull", "face", "neck", "eye", "brow", "lid",
				"nose", "ear", "mustache", "cap", "hat", "hair", "lip",
				"chin", "beard", "glasses", "arm", "hand", "finger",
				"palm", "wrist", "sleeve", "bicep", "chestneck",
				"chain", "necklace", "collar", "jacket", "atlet", "shirt",
				"sweater", "vest", "button"
			]
			for node in local_body.find_children("*", "", true, false):
				var n_low: String = node.name.to_lower()
				for kw in omit_keywords:
					if kw in n_low:
						node.queue_free()
						break
			add_child(local_body)


func set_character(new_char: String) -> void:
	character = new_char
	if is_local:
		for arm in _arm_meshes:
			if is_instance_valid(arm):
				arm.queue_free()
		_arm_meshes.clear()
		for h in _hands:
			if is_instance_valid(h):
				h.queue_free()
		_hands.clear()
		var old_body := get_node_or_null("LocalPlayerBody")
		if is_instance_valid(old_body):
			old_body.queue_free()
		_build_hands()
	else:
		if is_instance_valid(buddy):
			buddy.queue_free()
		buddy = Buddy.new()
		buddy.position = Vector3(0, SEAT_TOP, CHAIR_DISTANCE)
		add_child(buddy)
		buddy.setup(character, character_height)


func _process(_delta: float) -> void:
	for i in _arm_meshes.size():
		var start := Vector3((-1 if i == 0 else 1)*0.33,0.71,0.97)
		var end := _hands[i].position
		var direction := end-start
		_arm_meshes[i].position = (start+end)*0.5
		_arm_meshes[i].quaternion = Quaternion(Vector3.UP, direction.normalized())
		_arm_meshes[i].scale = Vector3(1,direction.length(),1)


func knock_table() -> void:
	if _hands.is_empty():
		return
	if _knock_tween:
		_knock_tween.kill()
	var left := _hands[0]
	_knock_tween = create_tween()
	_knock_tween.tween_property(left,"position",_left_rest+Vector3(0,0.06,-0.04),0.10)
	_knock_tween.tween_property(left,"position",_left_rest+Vector3(0,-0.018,-0.04),0.055)
	_knock_tween.tween_property(left,"position",_left_rest+Vector3(0,0.025,-0.04),0.055)
	_knock_tween.tween_property(left,"position",_left_rest+Vector3(0,-0.018,-0.04),0.055)
	_knock_tween.tween_property(left,"position",_left_rest,0.18)


## Animates the local player's left hand reaching out to touch/interact with a prop on the table.
func animate_left_reach(world_target: Vector3, hold_time := 0.18) -> void:
	if _hands.is_empty():
		return
	if _knock_tween:
		_knock_tween.kill()
	var left := _hands[0]
	var local_target := to_local(world_target)
	local_target.y = maxf(Table.TOP + 0.04, local_target.y)
	_knock_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_knock_tween.tween_property(left, "position", local_target, 0.16)
	_knock_tween.tween_interval(hold_time)
	_knock_tween.tween_property(left, "position", _left_rest, 0.24)


func _marker(pos: Vector3, target: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.transform = Transform3D(Basis.looking_at(target - pos), pos)
	add_child(m)
	return m
