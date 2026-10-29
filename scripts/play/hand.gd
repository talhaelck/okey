class_name Hand
extends Node3D
## The local player's reach: the right hand picks tiles up and puts them on any rack or the felt.
## Aims with the mouse in rack mode, with the screen centre (crosshair) in observe mode.
## Tile moves are instant drag and drop: press on a tile to pick it up, release over a rack slot or the felt to
## put it down (a quick click that ends where it started keeps the tile in hand for a second click instead).
## Racks open a gap under the dragged tile. The visible hand (ArmMotion) only follows; it never holds anything up.
## A tile lifted from someone else's rack is stolen until it lands; if a watcher looks at you
## meanwhile, it snaps back to its owner and you are caught.

signal stole
signal caught(by: Watcher)

const REACH := 1.5
const FOLLOW := 30.0 # how snappily the dragged tile follows the cursor
const CARRY_DISTANCE := 0.4
const RACK_LIFT := 0.02
const FELT_LIFT := 0.04
const CLICK_TIME := 0.25 # seconds; a shorter press that ends where it started keeps the tile in hand
const PINCH_UPRIGHT := 1.35 # radians the fingers point down when pinching a standing tile's top edge
const PINCH_FLAT := 1.15 # ... and a tile lying on the felt

var camera: FocusCamera
var seat: Seat
var seats: Array[Seat] = []
var table: Table
var watchers: Array[Watcher] = []

var held: Tile
## Short action text for the HUD ("" when nothing to do).
var hint := ""
## Fixed screen point to aim at instead of the mouse in rack mode (debug screenshots only).
var aim_override := Vector2(-1, -1)

var arm := ArmMotion.new()
var left_arm := ArmMotion.new()

var _origin: Node
var _origin_slot := -1
var _stolen_from: Rack
var _drop := {}
var _gap_rack: Rack
var _pressed_at := 0.0
var _hovered: Tile


func _ready() -> void:
	for motion: ArmMotion in [arm, left_arm]:
		motion.table = table
		for other in seats:
			motion.racks.append(other.rack)
		add_child(motion)
	arm.setup(seat.glove, seat.grip)
	left_arm.setup(seat.left_hand, seat.left_grip)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return # this click only grabs the mouse (FocusCamera handles it)
	var now := Time.get_ticks_msec() / 1000.0
	if event.pressed:
		if held:
			drop()
		else:
			var ray := _ray()
			grab(_pick(ray[0], ray[1]))
			_pressed_at = now
	elif held and not _drop.is_empty():
		var back_home: bool = _drop.get("rack") == _origin and _drop.get("slot") == _origin_slot
		if not (back_home and now - _pressed_at < CLICK_TIME):
			drop()


func _process(delta: float) -> void:
	var ray := _ray()
	if held:
		_drop = _find_drop(ray[0], ray[1])
		_show_gap(_drop.get("rack"), _drop.get("slot", -1))
		var target := _carry_target(ray[0], ray[1])
		held.global_transform = held.global_transform.interpolate_with(target, 1.0 - exp(-FOLLOW * delta))
		_check_caught()
	else:
		_set_hovered(_pick(ray[0], ray[1]))
		hint = "" if _hovered == null else ("Sol tık: çal" if _is_foreign(_hovered.holder) else "Sol tık: al")
	# The hand just follows the tile; it never gates the move.
	arm.resting = held == null
	arm.grip_goal = 1.0 if held else 0.0
	if held:
		arm.goal = _pinch_pose(held.global_transform)


## Takes the tile into the hand right away.
func grab(tile: Tile) -> void:
	if tile == null or held:
		return
	_set_hovered(null)
	_origin = tile.holder
	_origin_slot = _origin.release(tile) if _origin else -1
	_stolen_from = _origin if _is_foreign(_origin) else null
	tile.pin()
	tile.stop_sliding()
	tile.reparent(self)
	held = tile


## Puts the held tile where _drop says, right away.
func drop() -> void:
	if held == null or _drop.is_empty():
		return
	var tile := held
	held = null
	_show_gap(null, -1)
	if _drop.has("rack"):
		_drop.rack.insert(tile, _drop.slot)
	else:
		table.put_loose(tile, _drop.point, seat.rotation.y)
	if _stolen_from and _drop.get("rack") != _stolen_from:
		stole.emit()
	_stolen_from = null


# Keeps a gap open in the rack under the dragged tile (a null rack closes any gap).
func _show_gap(rack: Rack, slot: int) -> void:
	if _gap_rack and _gap_rack != rack:
		_gap_rack.show_gap(-1)
	_gap_rack = rack
	if rack:
		rack.show_gap(slot)


func _carry_target(from: Vector3, dir: Vector3) -> Transform3D:
	if _drop.has("rack"):
		var slot: Transform3D = _drop.rack.slot_global_transform(_drop.slot)
		slot.origin += slot.basis.z * RACK_LIFT
		hint = "Bırak: ıstakaya koy"
		return slot
	if _drop.has("point"):
		hint = "Bırak: masaya koy"
		return Transform3D(_flat_basis(), _drop.point + Vector3.UP * FELT_LIFT)
	hint = "Taşı bir ıstakaya ya da masaya götür"
	var pos := from + dir * CARRY_DISTANCE
	return Transform3D(Basis.looking_at(pos - camera.global_position), pos)


func _flat_basis() -> Basis:
	return Basis(Vector3.UP, seat.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5)


## Where the hand pivot (palm centre) goes to pinch a tile at `tile_pose` between thumb and index:
## over the top edge of a standing tile, or onto the top of a lying one, coming from the player's shoulder.
func _pinch_pose(tile_pose: Transform3D) -> Transform3D:
	var center := tile_pose.origin
	var face := tile_pose.basis.z
	var touch: Vector3
	var pitch: float
	if absf(face.y) > 0.7:
		touch = center + Vector3.UP * (TileFactory.SIZE.z * 0.5 + 0.004)
		pitch = PINCH_FLAT
	else:
		var toward_me := face if face.dot(camera.global_position - center) > 0.0 else -face
		# Fingertips just over the top edge, so the hand never covers the number.
		touch = center + tile_pose.basis.y * (TileFactory.SIZE.y * 0.5 + 0.012) + toward_me * 0.004
		pitch = PINCH_UPRIGHT
	var shoulder := arm.rest.origin + arm.rest.basis.z * 0.35
	var forward := touch - shoulder
	forward.y = 0.0
	forward = forward.normalized()
	var fingers := (forward * cos(pitch) + Vector3.DOWN * sin(pitch)).normalized()
	return Transform3D(Basis.looking_at(fingers, Vector3.UP), touch - fingers * ArmMotion.FINGERTIPS)


func _check_caught() -> void:
	if _stolen_from == null:
		return
	for watcher in watchers:
		if watcher.is_watching(seat):
			var tile := held
			held = null
			_show_gap(null, -1)
			_stolen_from.insert(tile, _origin_slot)
			_stolen_from = null
			watcher.caught_thief()
			caught.emit(watcher)
			return


func _ray() -> Array[Vector3]:
	var viewport := get_viewport()
	var pos := viewport.get_mouse_position() if camera.focused else viewport.get_visible_rect().size * 0.5
	if camera.focused and aim_override.x >= 0.0:
		pos = aim_override
	return [camera.project_ray_origin(pos), camera.project_ray_normal(pos)]


# Closest tile under the ray within arm's reach.
func _pick(from: Vector3, dir: Vector3) -> Tile:
	var best: Tile
	var best_distance := REACH
	var box := AABB(-TileFactory.SIZE * 0.5, TileFactory.SIZE)
	for tile: Tile in get_tree().get_nodes_in_group("tiles"):
		if tile == held or tile.holder == null:
			continue
		var inv := tile.global_transform.affine_inverse()
		var hit: Variant = box.intersects_ray(inv * from, inv.basis * dir)
		if hit == null:
			continue
		var distance := from.distance_to(tile.global_transform * hit)
		if distance < best_distance:
			best = tile
			best_distance = distance
	return best


# Nearest place under the ray to set the held tile: a rack slot (neighbours make room) or a spot on the felt.
func _find_drop(from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_distance := REACH
	for other in seats:
		var hit := other.rack.board_hit(from, dir)
		if hit.is_empty():
			continue
		var distance := from.distance_to(hit.point)
		if other.rack.can_insert(hit.slot) and distance < best_distance:
			best = {"rack": other.rack, "slot": hit.slot}
			best_distance = distance
	var felt: Variant = table.felt_hit(from, dir)
	if felt != null and from.distance_to(felt) < best_distance:
		best = {"point": felt}
	return best


func _is_foreign(holder: Node) -> bool:
	return holder is Rack and holder != seat.rack


func _set_hovered(tile: Tile) -> void:
	if tile == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.set_highlight(false)
	_hovered = tile
	if tile:
		tile.set_highlight(true)
