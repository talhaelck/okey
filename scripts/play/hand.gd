class_name Hand
extends Node3D
## The local player's physical reach: picks up tiles, arranges the rack with a 3D Ghost Preview,
## discards to the highlighted Right Discard Tray, snatches exposed tiles from opponent racks,
## and interacts with every prop on the kahvehane table.

signal stole
signal caught(by: Watcher)
signal tile_drawn(tile: Tile, from_discard: bool)
signal tile_discarded(tile: Tile)
signal finish_declared(tile: Tile)
signal tile_snatched(tile: Tile, from_rack: Node)
signal prop_used(prop_id: String, alt_action: bool)

const REACH := 1.85
const FOLLOW := 18.0
const CARRY_DISTANCE := 0.42
const RACK_LIFT := 0.025
const FELT_LIFT := 0.045

var camera: FocusCamera
var seat: Seat
var seats: Array[Seat] = []
var table: Table
var watchers: Array[Watcher] = []

var held: Tile
var exposure := 0.0
const BASE_NOTICE_TIME := 1.45
var coffee_boost_timer := 0.0
var hint := ""
var aim_override := Vector2(-1, -1)

var _origin: Node
var _origin_slot := -1
var _stolen_from: Rack
var _drew_from_pile := false
var _drew_from_discard := false
var _drop := {}
var _hovered: Tile
var _hovered_prop := {}
var _glove_rest: Transform3D
var _highlight := StandardMaterial3D.new()
var _okey_highlight := StandardMaterial3D.new()
var _ghost_preview: MeshInstance3D
var _ghost_mat := StandardMaterial3D.new()
var _tile_sound := AudioStreamPlayer3D.new()
var _pickup_sound: AudioStreamWAV
var _place_sound: AudioStreamWAV
var _throw_sound: AudioStreamWAV


func _ready() -> void:
	_glove_rest = seat.glove.global_transform
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.albedo_color = Color(0.96, 0.82, 0.46)
	_highlight.cull_mode = BaseMaterial3D.CULL_FRONT
	_highlight.grow = true
	_highlight.grow_amount = 0.0020

	_okey_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_okey_highlight.albedo_color = Color(1.0, 0.88, 0.24)
	_okey_highlight.cull_mode = BaseMaterial3D.CULL_FRONT
	_okey_highlight.grow = true
	_okey_highlight.grow_amount = 0.0025

	# 3D Ghost Tile Preview showing exact landing slot / discard tray
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.42, 0.98, 0.58, 0.48)
	_ghost_preview = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = TileFactory.SIZE * 1.03
	_ghost_preview.mesh = gm
	_ghost_preview.material_override = _ghost_mat
	_ghost_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_preview.visible = false
	add_child(_ghost_preview)

	_pickup_sound = _make_tile_sound(1850.0, 0.65, false)
	_place_sound = _make_tile_sound(1280.0, 0.92, true)
	_throw_sound = _make_tile_sound(1060.0, 1.0, true)
	_tile_sound.volume_db = -6.0
	_tile_sound.max_distance = 8.0
	add_child(_tile_sound)


func _unhandled_input(event: InputEvent) -> void:
	if not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.pressed:
		var ray := _ray()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if held:
				drop()
			else:
				_interact_primary(ray[0], ray[1])
		elif event.button_index == MOUSE_BUTTON_RIGHT and held != null:
			drop_in_place()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			throw_held_or_hovered(ray[0], ray[1])
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and held == null and not _hovered_prop.is_empty():
			_trigger_prop(_hovered_prop, true)
		elif event.keycode in [KEY_B, KEY_G] and held != null:
			drop_in_place()
		elif event.keycode == KEY_F:
			var ray := _ray()
			throw_held_or_hovered(ray[0], ray[1])


func _interact_primary(from: Vector3, dir: Vector3) -> void:
	var tile := _pick(from, dir)
	var prop := table.pick_prop(from, dir, REACH)
	if not prop.is_empty() and (tile == null or from.distance_to(table.to_global(prop["pos"])) < from.distance_to(tile.global_position)):
		_trigger_prop(prop, false)
		return
	if tile != null:
		if tile.is_indicator:
			prop_used.emit("indicator_info", false)
			return
		# Snatches a fallen tile knocked off an opponent's rack!
		if tile.is_fallen:
			_snatch_fallen_tile(tile)
			return
		# Instant smart steal when clicking an opponent's rack tile!
		if _is_foreign(tile.holder):
			_attempt_steal_tile(tile)
			return
		# Instant draw when clicking a tile in the center draw pile or left discard pile!
		if tile.is_draw_pile or (tile.is_discard and tile.discard_seat == 3):
			var free_slot := seat.rack.nearest_free(Rack.SLOTS + 7)
			if free_slot >= 0:
				var from_disc := tile.is_discard
				var orig := tile.holder
				if orig:
					orig.release(tile)
				seat.animate_left_reach(tile.global_position, 0.18)
				_play_tile_sound(_pickup_sound, tile.global_position)
				seat.rack.put(tile, free_slot, true)
				tile_drawn.emit(tile, from_disc)
				return
		grab(tile)


func _snatch_fallen_tile(tile: Tile) -> void:
	if not is_instance_valid(tile) or not tile.is_fallen:
		return
	var origin_rack := tile.fallen_from_rack
	tile.is_fallen = false
	tile.fallen_from_rack = null
	var tile_pos := tile.global_position
	seat.animate_left_reach(tile_pos, 0.16)
	_play_tile_sound(_pickup_sound, tile_pos)

	var free_slot := seat.rack.nearest_free(Rack.SLOTS + 7)
	if free_slot >= 0:
		seat.rack.put(tile, free_slot, true)
		stole.emit()
	else:
		grab(tile)
	tile_snatched.emit(tile, origin_rack)



func _attempt_steal_tile(tile: Tile) -> void:
	var opp_rack := tile.holder as Rack
	if opp_rack == null:
		return
	var tile_pos := tile.global_position
	seat.animate_left_reach(tile_pos, 0.22)
	_play_tile_sound(_pickup_sound, tile_pos)

	# Check if the owner of this rack (or another alert watcher) catches the steal!
	for w in watchers:
		if w.seat.rack == opp_rack and w.is_watching(seat) and w.vision_multiplier > 0.35:
			w.caught_thief()
			caught.emit(w)
			return
		if w.can_see(tile_pos, seat) and w.vision_multiplier > 0.45:
			w.caught_thief()
			caught.emit(w)
			return

	# Clean steal! Move the stolen tile directly into the local player's rack (or hand if rack is full)
	var free_slot := seat.rack.nearest_free(Rack.SLOTS + 7)
	if free_slot >= 0:
		opp_rack.release(tile)
		seat.rack.put(tile, free_slot, true)
		stole.emit()
	else:
		grab(tile)


func _trigger_prop(prop: Dictionary, alt_action: bool) -> void:
	var id: String = prop["id"]
	var world_pos := table.to_global(prop["pos"])
	seat.animate_left_reach(world_pos, 0.22)
	_play_tile_sound(_pickup_sound, world_pos)
	prop_used.emit(id, alt_action)


func quick_discard(tile: Tile) -> void:
	if tile == null or tile.holder != seat.rack:
		return
	seat.rack.release(tile)
	_play_tile_sound(_throw_sound, tile.global_position)
	table.put_discard(0, tile)
	tile_discarded.emit(tile)


## Drops the currently held tile straight down from the hand onto the table below.
func drop_in_place() -> void:
	if held == null:
		return
	var tile := held
	var drop_pos := tile.global_position
	held = null
	_ghost_preview.visible = false
	seat.rack.set_highlighted_slot(-1)
	_play_tile_sound(_place_sound, drop_pos)
	var was_discarded := table.drop_loose_from_hand(tile, drop_pos, seat.rotation.y)
	if was_discarded and _origin == seat.rack:
		tile_discarded.emit(tile)
	if _stolen_from:
		stole.emit()
	_stolen_from = null
	_drew_from_pile = false
	_drew_from_discard = false
	exposure = 0.0


## Throws/flings the held or hovered tile across the table in the aim direction!
func throw_held_or_hovered(from: Vector3, dir: Vector3) -> void:
	if held != null:
		var tile := held
		var from_rack := (_origin == seat.rack)
		held = null
		_ghost_preview.visible = false
		seat.rack.set_highlighted_slot(-1)
		_play_tile_sound(_throw_sound, tile.global_position)
		var was_discarded := table.throw_tile(tile, from, dir, seat.rotation.y)
		if was_discarded and from_rack:
			tile_discarded.emit(tile)
		if _stolen_from:
			stole.emit()
		_stolen_from = null
		_drew_from_pile = false
		_drew_from_discard = false
		exposure = 0.0
	elif is_instance_valid(_hovered):
		if _hovered.holder == seat.rack:
			var tile := _hovered
			_set_hovered(null)
			seat.rack.release(tile)
			_play_tile_sound(_throw_sound, tile.global_position)
			var was_discarded := table.throw_tile(tile, from, dir, seat.rotation.y)
			if not was_discarded:
				# Pressing [F] on a rack tile while aiming anywhere on the right or neutral area discards it if needed
				pass
			else:
				tile_discarded.emit(tile)
		elif _hovered.holder == table and not _hovered.is_draw_pile and not _hovered.is_indicator:
			var tile := _hovered
			_set_hovered(null)
			table.release(tile)
			_play_tile_sound(_throw_sound, tile.global_position)
			table.throw_tile(tile, from, dir, seat.rotation.y)


func _process(delta: float) -> void:
	coffee_boost_timer = maxf(0.0, coffee_boost_timer - delta)
	if camera.mouse_control and not camera.focused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_set_hovered(null)
		table.set_hovered_prop("")
		seat.rack.set_highlighted_slot(-1)
		_ghost_preview.visible = false
		hint = ""
		return
	var ray := _ray()
	var follow_speed := FOLLOW * (1.4 if coffee_boost_timer > 0.0 else 1.0)
	if held:
		_set_hovered(null)
		table.set_hovered_prop("")
		_carry(ray[0], ray[1], delta, follow_speed)
		_check_caught(delta)
	else:
		_ghost_preview.visible = false
		var r_hit := seat.rack.board_hit(ray[0], ray[1])
		seat.rack.set_highlighted_slot(r_hit.get("slot", -1) if not r_hit.is_empty() else -1)
		var tile := _pick(ray[0], ray[1])
		var prop := table.pick_prop(ray[0], ray[1], REACH)
		var use_prop := not prop.is_empty() and (tile == null or ray[0].distance_to(table.to_global(prop["pos"])) < ray[0].distance_to(tile.global_position))
		if use_prop:
			_set_hovered(null)
			_hovered_prop = prop
			table.set_hovered_prop(prop["id"])
			hint = prop["hint"]
		else:
			_hovered_prop = {}
			table.set_hovered_prop("")
			_set_hovered(tile)
			hint = _build_tile_hint(tile)

	var glove_target := _glove_rest
	if held:
		glove_target.origin = held.global_position - held.global_basis.y * 0.06 \
			+ (camera.global_position - held.global_position).normalized() * 0.01
	elif not _hovered_prop.is_empty():
		var prop_world := table.to_global(_hovered_prop["pos"])
		glove_target.origin = _glove_rest.origin.lerp(prop_world + Vector3(0, 0.04, 0.08), 0.22)
	seat.glove.global_transform = seat.glove.global_transform.interpolate_with(glove_target, 1.0 - exp(-follow_speed * delta))


func _build_tile_hint(tile: Tile) -> String:
	if tile == null:
		return ""
	var desc := TileFactory.describe(tile.value)
	var is_okey := (tile.value == table.okey_value)
	var okey_tag := " ★ OKEY!" if is_okey else ""
	if tile.is_fallen:
		return "🖐️ Sol tık: DÜŞEN TAŞI KAP! [%s%s]" % [desc, okey_tag]
	if tile.is_indicator:
		return "Gösterge: %s  →  Okey: %s" % [desc, TileFactory.describe(table.okey_value)]
	if tile.is_draw_pile:
		return "Sol tık: Ortadan Taş Çek [D] (%d kaldı)" % table.draw_count()
	if tile.is_discard:
		if tile.discard_seat == 3:
			return "Sol tık: Yandan Al (%s%s)" % [desc, okey_tag]
		elif tile.discard_seat == 0:
			return "Senin Attığın Taş (%s)" % desc
		else:
			return "Sol tık: Rakibin Attığı Taşı Çal (%s)" % desc
	if _is_foreign(tile.holder):
		var opp_rack := tile.holder as Rack
		if opp_rack and (opp_rack.stealable_open or table.glasses_worn):
			return "🖐️ Sol tık: Rakip Istakasından Çal! [%s%s]" % [desc, okey_tag]
		return "⚠️ Rakip Bakıyor! Önce Çayını Devir / Leblebi At, Sonra Taşını Çal [%s]" % desc
	return "%s%s  ·  Sol tık: Al/Koy  ·  Sağ tık: Bırak  ·  [F] Fırlat" % [desc, okey_tag]


func grab(tile: Tile) -> void:
	if tile == null or held or tile.is_indicator:
		return
	_origin = tile.holder
	_drew_from_pile = tile.is_draw_pile
	_drew_from_discard = tile.is_discard and tile.discard_seat == 3
	_origin_slot = _origin.release(tile) if _origin else -1
	_stolen_from = _origin if (_is_foreign(_origin) or (tile.is_discard and tile.discard_seat in [1, 2])) else null
	tile.stop_sliding()
	tile.reparent(self)
	held = tile
	exposure = 0.0
	_drop = {}
	_play_tile_sound(_pickup_sound, tile.global_position)


func drop() -> void:
	if held == null:
		return
	if _drop.is_empty():
		drop_in_place()
		return
	var tile := held
	_play_tile_sound(_place_sound, tile.global_position)
	held = null
	_ghost_preview.visible = false
	seat.rack.set_highlighted_slot(-1)
	if _drop.has("finish"):
		table.put_discard(0, tile)
		finish_declared.emit(tile)
	elif _drop.has("rack"):
		var target_rack: Rack = _drop.rack
		if target_rack == seat.rack and _origin == seat.rack:
			target_rack.put_or_swap(tile, _drop.slot, _origin_slot)
		else:
			var free_slot := target_rack.nearest_free(_drop.slot)
			target_rack.put(tile, free_slot if free_slot >= 0 else _drop.slot)
		if target_rack == seat.rack and (_drew_from_pile or _drew_from_discard):
			tile_drawn.emit(tile, _drew_from_discard)
	elif _drop.has("discard"):
		table.put_discard(0, tile)
		if _origin == seat.rack:
			tile_discarded.emit(tile)
	else:
		var was_discarded := table.put_loose(tile, _drop.point, seat.rotation.y)
		if was_discarded and _origin == seat.rack:
			tile_discarded.emit(tile)
	if _stolen_from and _drop.get("rack") != _stolen_from:
		stole.emit()
	_stolen_from = null
	_drew_from_pile = false
	_drew_from_discard = false
	exposure = 0.0


func _carry(from: Vector3, dir: Vector3, delta: float, follow_speed: float) -> void:
	_drop = _find_drop(from, dir)
	var target: Transform3D
	if _drop.has("finish"):
		var fin_xf := Transform3D(Basis(Vector3.UP, seat.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5),
			table.indicator_tile.global_position + Vector3(0, 0.025, 0))
		target = fin_xf
		_ghost_preview.visible = true
		_ghost_preview.global_transform = fin_xf
		_ghost_mat.albedo_color = Color(1.0, 0.86, 0.25, 0.58)
		seat.rack.set_highlighted_slot(-1)
		hint = "Sol tık: GÖSTERGEYE VUR & ELİ BİTİR! (Okey Aç)"
	elif _drop.has("rack"):
		var slot_xf: Transform3D = _drop.rack.slot_global_transform(_drop.slot)
		target = slot_xf
		target.origin += target.basis.z * RACK_LIFT
		_ghost_preview.visible = true
		_ghost_preview.global_transform = slot_xf
		_ghost_mat.albedo_color = Color(0.42, 0.98, 0.58, 0.45)
		seat.rack.set_highlighted_slot(_drop.slot if _drop.rack == seat.rack else -1)
		hint = "Sol tık: Istakaya Koy (#%d)  ·  Sağ tık: Bırak  ·  [F] Fırlat" % (_drop.slot + 1)
	elif _drop.has("discard"):
		var dpos := table.to_global(Table.DISCARD_SPOTS[0])
		var disc_xf := Transform3D(Basis(Vector3.UP, seat.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5),
			dpos + Vector3.UP * 0.010)
		target = Transform3D(disc_xf.basis, dpos + Vector3.UP * FELT_LIFT)
		_ghost_preview.visible = true
		_ghost_preview.global_transform = disc_xf
		_ghost_mat.albedo_color = Color(0.35, 0.98, 0.55, 0.58)
		seat.rack.set_highlighted_slot(-1)
		hint = "Sol tık: SAĞA TAŞ AT  ·  [F] Hızlı Fırlat"
	elif _drop.has("point"):
		var pt_xf := Transform3D(Basis(Vector3.UP, seat.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5),
			_drop.point + Vector3.UP * 0.009)
		target = Transform3D(pt_xf.basis, _drop.point + Vector3.UP * FELT_LIFT)
		_ghost_preview.visible = true
		_ghost_preview.global_transform = pt_xf
		_ghost_mat.albedo_color = Color(0.95, 0.82, 0.42, 0.42)
		seat.rack.set_highlighted_slot(-1)
		hint = "Sol tık: Buraya Koy  ·  Sağ tık: Elden Bırak  ·  [F] Fırlat"
	else:
		var pos := from + dir * CARRY_DISTANCE
		target = Transform3D(Basis.looking_at(pos - camera.global_position), pos)
		_ghost_preview.visible = false
		seat.rack.set_highlighted_slot(-1)
		hint = "Sol/Sağ tık: Elden Bırak  ·  [F] Masaya Fırlat"
	held.global_transform = held.global_transform.interpolate_with(target, 1.0 - exp(-follow_speed * delta))


func is_stealing() -> bool:
	return held != null and _stolen_from != null


func _check_caught(delta: float) -> void:
	if _stolen_from == null:
		exposure = 0.0
		return
	var notice_time := BASE_NOTICE_TIME
	if coffee_boost_timer > 0.0:
		notice_time *= 1.45
	if table.glasses_worn:
		notice_time *= 1.40
	if table.smoke_active_timer > 0.0:
		notice_time *= 1.85
	for watcher in watchers:
		if watcher.can_see(held.global_position, seat):
			exposure = minf(1.0, exposure + delta / notice_time)
			if exposure < 1.0:
				return
			var tile := held
			held = null
			_ghost_preview.visible = false
			if _stolen_from is Rack:
				_stolen_from.put(tile, _stolen_from.nearest_free(_origin_slot), true)
			_stolen_from = null
			exposure = 0.0
			watcher.caught_thief()
			caught.emit(watcher)
			return
	exposure = maxf(0.0, exposure - delta / 0.35)


func _play_tile_sound(stream: AudioStreamWAV, point: Vector3) -> void:
	_tile_sound.global_position = point
	_tile_sound.pitch_scale = randf_range(0.94, 1.06)
	_tile_sound.stream = stream
	_tile_sound.play()


## Synthesizes an authentic percussive melamine-on-wood Okey tile clack ("şak! / tık!") with secondary micro-bounce.
func _make_tile_sound(frequency: float, strength: float, with_bounce := true) -> AudioStreamWAV:
	var mix_rate := 44100
	var samples := int(mix_rate * 0.095)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frequency * 17.0)
	var lp := 0.0
	for i in samples:
		var t := float(i) / float(mix_rate)
		# 1) Sharp broadband impact transient (melamine edge hitting walnut/tile)
		var raw_noise := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw_noise, 0.42)
		var click := (raw_noise * 0.65 + lp * 0.35) * exp(-520.0 * t)
		# 2) Melamine high-density body modes (inharmonic resonant partials)
		var m1 := sin(TAU * (frequency * 1.65) * t) * exp(-170.0 * t) * 0.38
		var m2 := sin(TAU * (frequency * 2.78) * t + 0.4) * exp(-240.0 * t) * 0.24
		var m3 := sin(TAU * (frequency * 4.15) * t + 1.1) * exp(-360.0 * t) * 0.14
		# 3) Warm walnut rack / table cavity knock
		var wood := (sin(TAU * 340.0 * t) * 0.34 + sin(TAU * 580.0 * t) * 0.22) * exp(-115.0 * t)
		var v := (click * 0.72 + m1 + m2 + m3 + wood)
		# 4) Realistic secondary micro-bounce 14ms after initial contact
		if with_bounce and t > 0.014:
			var tb := t - 0.014
			var b_click := rng.randf_range(-0.6, 0.6) * exp(-650.0 * tb)
			var b_ring := sin(TAU * (frequency * 1.92) * tb) * exp(-220.0 * tb) * 0.25
			v += (b_click + b_ring) * 0.42
		v = tanh(v * strength * 1.65)
		bytes.encode_s16(i * 2, clampi(int(v * 28000.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.data = bytes
	return stream


func _ray() -> Array[Vector3]:
	var viewport := get_viewport()
	var pos := viewport.get_mouse_position() if (camera.focused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED) else viewport.get_visible_rect().size * 0.5
	if camera.focused and aim_override.x >= 0.0:
		pos = aim_override
	return [camera.project_ray_origin(pos), camera.project_ray_normal(pos)]


func _pick(from: Vector3, dir: Vector3) -> Tile:
	var best: Tile
	var best_distance := REACH
	for tile: Tile in get_tree().get_nodes_in_group("tiles"):
		if tile == held:
			continue
		if tile.holder == null and not tile.is_fallen:
			continue
		var pad := 0.024 if tile.is_fallen else (0.012 if _is_foreign(tile.holder) else 0.005)
		var box := AABB(-TileFactory.SIZE * 0.5, TileFactory.SIZE).grow(pad)
		var inv := tile.global_transform.affine_inverse()
		var hit: Variant = box.intersects_ray(inv * from, inv.basis * dir)
		if hit == null:
			continue
		var distance := from.distance_to(tile.global_transform * hit)
		if distance < best_distance:
			best = tile
			best_distance = distance
	return best


func _find_drop(from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_distance := REACH
	for other in seats:
		var hit := other.rack.board_hit(from, dir)
		if hit.is_empty():
			continue
		var slot: int = hit.slot if other == seat else other.rack.nearest_free(hit.slot)
		var distance := from.distance_to(hit.point)
		if slot >= 0 and distance < best_distance:
			best = {"rack": other.rack, "slot": slot}
			best_distance = distance
	var felt: Variant = table.felt_hit(from, dir)
	if felt != null and from.distance_to(felt) < best_distance:
		var local_felt := table.to_local(felt)
		if is_instance_valid(table.indicator_tile) and _origin == seat.rack and felt.distance_to(table.indicator_tile.global_position) < 0.085:
			return {"finish": true, "point": felt}
		# Only snap to the right discard tray when aiming near DISCARD_SPOTS[0]; anywhere else places freely on the table!
		if _origin == seat.rack and Table.is_in_discard_zone(local_felt):
			return {"discard": true, "point": felt}
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
		var is_okey := (tile.value == table.okey_value)
		tile.material_overlay = _okey_highlight if is_okey else _highlight
