class_name Hand
extends Node3D
## The local player's reach: the right glove picks tiles up and puts them on any rack or the felt.
## Aims with the mouse in rack mode, with the screen centre (crosshair) in observe mode.
## A tile lifted from someone else's rack is stolen until it lands; if a watcher looks at you
## meanwhile, it snaps back to its owner and you are caught.

signal stole
signal caught(by: Watcher)

const REACH := 1.65 # Keeps the draw pile and side racks reachable from the wider camera framing.
const FOLLOW := 18.0
const CARRY_DISTANCE := 0.4
const RACK_LIFT := 0.025
const FELT_LIFT := 0.05

var camera: FocusCamera
var seat: Seat
var seats: Array[Seat] = []
var table: Table
var watchers: Array[Watcher] = []

var held: Tile
## Builds only while a looking opponent can see the stolen tile; hidden in rack view.
var exposure := 0.0
const NOTICE_TIME := 0.55
## Short action text for the HUD ("" when nothing to do).
var hint := ""
## Fixed screen point to aim at instead of the mouse in rack mode (debug screenshots only).
var aim_override := Vector2(-1, -1)

var _origin: Node
var _origin_slot := -1
var _stolen_from: Rack
var _drop := {}
var _hovered: Tile
var _glove_rest: Transform3D
var _highlight := StandardMaterial3D.new()
var _tile_sound := AudioStreamPlayer3D.new()
var _pickup_sound: AudioStreamWAV
var _place_sound: AudioStreamWAV


func _ready() -> void:
	_glove_rest = seat.glove.global_transform
	# Inverted-hull outline drawn over the hovered tile.
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.albedo_color = Color(0.86, 0.73, 0.47)
	_highlight.cull_mode = BaseMaterial3D.CULL_FRONT
	_highlight.grow = true
	_highlight.grow_amount = 0.0015
	_pickup_sound = _make_tile_sound(1450.0,0.5)
	_place_sound = _make_tile_sound(920.0,0.8)
	_tile_sound.volume_db = -14
	_tile_sound.max_distance = 5.0
	add_child(_tile_sound)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return # this click only grabs the mouse (FocusCamera handles it)
	var ray := _ray()
	if held:
		drop()
	else:
		grab(_pick(ray[0], ray[1]))


func _process(delta: float) -> void:
	if camera.mouse_control and not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_set_hovered(null)
		hint = ""
		return
	var ray := _ray()
	if held:
		_set_hovered(null)
		_carry(ray[0], ray[1], delta)
		_check_caught(delta)
	else:
		_set_hovered(_pick(ray[0], ray[1]))
		hint = "" if _hovered == null else ("Sol tık: çal" if _is_foreign(_hovered.holder) else "Sol tık: al")
	var glove_target := _glove_rest
	if held:
		# Cup the tile from below so the glove never hides its face.
		glove_target.origin = held.global_position - held.global_basis.y * 0.06 			+ (camera.global_position - held.global_position).normalized() * 0.01
	seat.glove.global_transform = seat.glove.global_transform.interpolate_with(glove_target, 1.0 - exp(-FOLLOW * delta))


func grab(tile: Tile) -> void:
	if tile == null or held:
		return
	_origin = tile.holder
	_origin_slot = _origin.release(tile) if _origin else -1
	_stolen_from = _origin if _is_foreign(_origin) else null
	tile.stop_sliding()
	tile.reparent(self)
	held = tile
	exposure = 0.0
	_drop = {}
	_play_tile_sound(_pickup_sound,tile.global_position)


func drop() -> void:
	if held == null or _drop.is_empty():
		return
	var tile := held
	_play_tile_sound(_place_sound,tile.global_position)
	held = null
	if _drop.has("rack"):
		_drop.rack.put(tile, _drop.slot)
	else:
		table.put_loose(tile, _drop.point, seat.rotation.y)
	if _stolen_from and _drop.get("rack") != _stolen_from:
		stole.emit()
	_stolen_from = null
	exposure = 0.0


func _carry(from: Vector3, dir: Vector3, delta: float) -> void:
	_drop = _find_drop(from, dir)
	var target: Transform3D
	if _drop.has("rack"):
		target = _drop.rack.slot_global_transform(_drop.slot)
		target.origin += target.basis.z * RACK_LIFT
		hint = "Sol tık: ıstakaya koy"
	elif _drop.has("point"):
		target = Transform3D(Basis(Vector3.UP, seat.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5),
			_drop.point + Vector3.UP * FELT_LIFT)
		hint = "Sol tık: masaya bırak"
	else:
		var pos := from + dir * CARRY_DISTANCE
		target = Transform3D(Basis.looking_at(pos - camera.global_position), pos)
		hint = "Taşı bir ıstakaya ya da masaya götür"
	held.global_transform = held.global_transform.interpolate_with(target, 1.0 - exp(-FOLLOW * delta))


func is_stealing() -> bool:
	return held != null and _stolen_from != null


func _check_caught(delta: float) -> void:
	if _stolen_from == null:
		exposure = 0.0
		return
	for watcher in watchers:
		if watcher.can_see(held.global_position,seat):
			exposure = minf(1.0,exposure + delta/NOTICE_TIME)
			if exposure < 1.0:
				return
			var tile := held
			held = null
			_stolen_from.put(tile, _stolen_from.nearest_free(_origin_slot), true)
			_stolen_from = null
			exposure = 0.0
			watcher.caught_thief()
			caught.emit(watcher)
			return
	exposure = maxf(0.0,exposure-delta/0.35)


func _play_tile_sound(stream: AudioStreamWAV, point: Vector3) -> void:
	_tile_sound.global_position = point
	_tile_sound.stream = stream
	_tile_sound.play()


func _make_tile_sound(frequency: float, strength: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(1764*2)
	var random := RandomNumberGenerator.new()
	random.seed = int(frequency)
	for i in 1764:
		var t := i/22050.0
		var ring := sin(TAU*frequency*t)*0.44 + sin(TAU*frequency*2.31*t)*0.15
		var attack := random.randf_range(-0.3,0.3)*exp(-300*t)
		var value := strength*(ring*exp(-90*t)+attack)
		bytes.encode_s16(i*2,clampi(int(value*24000),-32768,32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream


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


# Nearest place under the ray to set the held tile: a free rack slot or a spot on the felt.
func _find_drop(from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_distance := REACH
	for other in seats:
		var hit := other.rack.board_hit(from, dir)
		if hit.is_empty():
			continue
		var slot := other.rack.nearest_free(hit.slot)
		var distance := from.distance_to(hit.point)
		if slot >= 0 and distance < best_distance:
			best = {"rack": other.rack, "slot": slot}
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
		_hovered.material_overlay = null
	_hovered = tile
	if tile:
		tile.material_overlay = _highlight
