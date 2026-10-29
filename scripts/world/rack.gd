class_name Rack
extends Node3D
## Stepped two-row Turkish Okey rack (ıstaka) with 2 x 15 slots matching media_1793282705533_e1a0f90d.png.
## Row 0 sits on the lower stepped shelf (s = 0.004..0.056) and Row 1 sits on the upper stepped shelf (s = 0.066..0.118).

const LENGTH := 0.62
const HEIGHT := 0.128
const SLOTS := 15
const ROWS := 2
const TILT := 0.30 # radians the board leans back
const SLOT_GAP := 0.002
const ROW_GAP := 0.010

var is_opponent := false
var stealable_open := false
var peek_reveal := false

var _board := Basis(Vector3.RIGHT, -TILT)
var _board_origin := Vector3(0, 0.008, 0.032)
var _tiles := Node3D.new()
var _slots: Array[Tile] = []
var _slot_markers: Array[MeshInstance3D] = []
var _active_slot_preview := -1
var _closed_position := Vector3.ZERO
var _steal_glow_mat := StandardMaterial3D.new()


func _ready() -> void:
	_closed_position=position
	var rack_glb: Node3D = load("res://assets/models/table_details/okey_rack.glb").instantiate()
	rack_glb.name = "OkeyRackModel"
	CoffeehouseMaterials.apply_to(rack_glb)
	add_child(rack_glb)
	add_child(_tiles)
	_slots.resize(ROWS * SLOTS)

	_steal_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_steal_glow_mat.albedo_color = Color(0.98, 0.84, 0.38)
	_steal_glow_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_steal_glow_mat.grow = true
	_steal_glow_mat.grow_amount = 0.0018

	_build_slot_previews()


var _tilt_tween: Tween


func _build_slot_previews() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.90, 0.35, 0.85)
	var qm := BoxMesh.new()
	qm.size = Vector3(TileFactory.SIZE.x + 0.002, TileFactory.SIZE.y + 0.002, 0.005)
	for idx in ROWS * SLOTS:
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = mat
		mi.transform = _base_slot_transform(idx)
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_slot_markers.append(mi)


func set_highlighted_slot(slot_idx: int) -> void:
	if _active_slot_preview == slot_idx:
		return
	if _active_slot_preview >= 0 and _active_slot_preview < _slot_markers.size():
		_slot_markers[_active_slot_preview].visible = false
	_active_slot_preview = slot_idx
	if _active_slot_preview >= 0 and _active_slot_preview < _slot_markers.size():
		_slot_markers[_active_slot_preview].visible = true


func tilt_open(duration := 3.5) -> void:
	if not is_opponent:
		return
	if _tilt_tween:
		_tilt_tween.kill()
	_tilt_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tilt_tween.tween_property(self, "rotation:x", deg_to_rad(-68.0), 0.26)
	# Lift the rear support by its rotated depth, keeping it above the felt.
	_tilt_tween.parallel().tween_property(self,"position",_closed_position+Vector3.UP*.059,0.26)
	_tilt_tween.tween_interval(duration)
	_tilt_tween.chain().set_trans(Tween.TRANS_SINE).tween_property(self, "rotation:x", 0.0, 0.32)
	_tilt_tween.parallel().tween_property(self,"position",_closed_position,0.32)


func update_opponent_steal_visuals(can_steal: bool, reveal_faces: bool, _owner_name: String, _state_txt: String) -> void:
	if not is_opponent:
		return
	stealable_open = can_steal
	peek_reveal = reveal_faces


func set_all_xray(enabled: bool, okey_val := Vector2i(-1, -1)) -> void:
	for t in _slots:
		if is_instance_valid(t):
			t.set_xray(enabled)
			if enabled and okey_val.x >= 0 and t.value == okey_val:
				t.set_okey_glow(true)
			else:
				t.set_okey_glow(false)


func dislodge_random_tile(table_ref: Node3D) -> Tile:
	var occupied: Array[int] = []
	for i in _slots.size():
		if _slots[i] != null and is_instance_valid(_slots[i]):
			occupied.append(i)
	if occupied.is_empty():
		return null
	var slot_idx: int = occupied.pick_random()
	var tile: Tile = _slots[slot_idx]
	_slots[slot_idx] = null
	tile.holder = null
	tile.is_fallen = true
	tile.fallen_from_rack = self
	tile.fallen_origin_slot = slot_idx

	var world_xf := tile.global_transform
	tile.reparent(table_ref)
	tile.global_transform = world_xf

	var drop_target_local := to_local(tile.global_position)
	drop_target_local.z -= 0.16
	drop_target_local.y = Table.TOP + 0.006
	var drop_target_world := to_global(drop_target_local)
	var drop_xf := Transform3D(Basis(Vector3.UP, global_rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5), drop_target_world)
	tile.slide_to(drop_xf, 0.28, 0.055)
	return tile


func put_back_fallen(tile: Tile) -> void:
	if tile == null or not is_instance_valid(tile):
		return
	if not tile.is_fallen:
		return
	tile.is_fallen = false
	tile.fallen_from_rack = null
	var target_slot := nearest_free(tile.fallen_origin_slot)
	if target_slot >= 0:
		put(tile, target_slot, true)
	else:
		tile.queue_free()


## Lays a fresh hand out: first half on the upper row, the rest on the lower row, each row centred.
func set_tiles(values: Array) -> void:
	for tile in _slots:
		if tile:
			tile.queue_free()
	_slots.fill(null)
	var upper_count := ceili(values.size() / 2.0)
	for i in values.size():
		var row := 1 if i < upper_count else 0
		var in_row := upper_count if row == 1 else values.size() - upper_count
		var column := (i if row == 1 else i - upper_count) + floori((SLOTS - in_row) / 2.0)
		put(TileFactory.create(values[i]), row * SLOTS + column, false)


func count() -> int:
	var n := 0
	for t in _slots:
		if is_instance_valid(t):
			n += 1
	return n


func get_tiles() -> Array[Tile]:
	var out: Array[Tile] = []
	for t in _slots:
		if is_instance_valid(t):
			out.append(t)
	return out


## Moves a tile into a free slot, sliding it there unless instant.
func put(tile: Tile, index: int, animate := true) -> void:
	if index < 0 or index >= _slots.size():
		index = nearest_free(SLOTS + 7)
	if index < 0:
		return
	_slots[index] = tile
	tile.holder = self
	tile.is_draw_pile = false
	tile.is_discard = false
	tile.is_indicator = false
	tile.discard_seat = -1
	tile.material_overlay = null
	if tile.get_parent():
		tile.reparent(_tiles)
	else:
		_tiles.add_child(tile)
	var target := _slot_transform(index)
	if animate:
		tile.slide_to(target)
	else:
		tile.transform = target


## If target slot is occupied, swaps or shifts tiles so player can drop anywhere on their rack.
func put_or_swap(tile: Tile, index: int, origin_slot := -1) -> void:
	index = clampi(index, 0, ROWS * SLOTS - 1)
	var occupant := _slots[index]
	if occupant == null or not is_instance_valid(occupant):
		put(tile, index, true)
		return
	if origin_slot >= 0 and origin_slot < _slots.size() and _slots[origin_slot] == null:
		_slots[index] = null
		put(occupant, origin_slot, true)
		put(tile, index, true)
	else:
		var free_idx := nearest_free(index)
		if free_idx >= 0:
			_slots[index] = null
			put(occupant, free_idx, true)
			put(tile, index, true)


## Takes a tile off the rack and returns the slot it was in.
func release(tile: Tile) -> int:
	var index := _slots.find(tile)
	if index >= 0:
		_slots[index] = null
	tile.holder = null
	tile.material_overlay = null
	return index


## Closest empty slot to index, preferring the same row; -1 when the rack is full.
func nearest_free(index: int) -> int:
	index = clampi(index, 0, ROWS * SLOTS - 1)
	var row := index / SLOTS
	var column := index % SLOTS
	for r in [row, 1 - row]:
		for offset in SLOTS:
			for c in [column - offset, column + offset]:
				if c >= 0 and c < SLOTS and _slots[r * SLOTS + c] == null:
					return r * SLOTS + c
	return -1


## Reuses the same tile objects and values; never creates or deletes a tile.
func sort_tiles(by_number := false) -> void:
	var tiles: Array[Tile] = get_tiles()
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool:
		var ka := 1000 if a.value.x == TileFactory.FAKE_OKEY else (a.value.y * 5 + a.value.x if by_number else a.value.x * 14 + a.value.y)
		var kb := 1000 if b.value.x == TileFactory.FAKE_OKEY else (b.value.y * 5 + b.value.x if by_number else b.value.x * 14 + b.value.y)
		return ka < kb)
	_slots.fill(null)
	var upper := ceili(tiles.size() / 2.0)
	for i in tiles.size():
		var row := 1 if i < upper else 0
		var in_row := upper if row == 1 else tiles.size() - upper
		var column := (i if row == 1 else i - upper) + floori((SLOTS - in_row) / 2.0)
		put(tiles[i], row * SLOTS + column)


func pop_ai_discard(okey_val: Vector2i) -> Tile:
	var tiles := get_tiles()
	if tiles.is_empty():
		return null
	var best_tile: Tile = tiles[0]
	var best_score := 999
	for t in tiles:
		var v := okey_val if t.value.x == TileFactory.FAKE_OKEY else t.value
		var score := 0
		if t.value == okey_val:
			score += 100
		for other in tiles:
			if other == t:
				continue
			var ov := okey_val if other.value.x == TileFactory.FAKE_OKEY else other.value
			if ov.x == v.x and abs(ov.y - v.y) <= 2:
				score += 3
			if ov.y == v.y and ov.x != v.x:
				score += 3
		score += randi() % 2
		if score < best_score:
			best_score = score
			best_tile = t
	release(best_tile)
	return best_tile


func evaluate_hand(okey_val: Vector2i) -> Dictionary:
	var tiles := get_tiles()
	var wilds := 0
	var pool: Array[Vector2i] = []
	for t in tiles:
		if t.value == okey_val:
			wilds += 1
		elif t.value.x == TileFactory.FAKE_OKEY:
			pool.append(okey_val)
		else:
			pool.append(t.value)
	var used := []
	used.resize(pool.size())
	used.fill(false)
	var valid_sets := 0

	for color in 4:
		for n in range(1, 12):
			var i1 := _find_unused(pool, used, Vector2i(color, n))
			var i2 := _find_unused(pool, used, Vector2i(color, n + 1))
			var i3 := _find_unused(pool, used, Vector2i(color, n + 2))
			if i1 >= 0 and i2 >= 0 and i3 >= 0:
				used[i1] = true
				used[i2] = true
				used[i3] = true
				valid_sets += 1
				var next_n := n + 3
				while next_n <= 13:
					var ix := _find_unused(pool, used, Vector2i(color, next_n))
					if ix >= 0:
						used[ix] = true
						next_n += 1
					else:
						break

	for n in range(1, 14):
		var found_indices: Array[int] = []
		var seen_colors: Array[int] = []
		for i in pool.size():
			if not used[i] and pool[i].y == n and not (pool[i].x in seen_colors):
				seen_colors.append(pool[i].x)
				found_indices.append(i)
		if found_indices.size() >= 3:
			for idx in found_indices:
				used[idx] = true
			valid_sets += 1

	for i in pool.size():
		if used[i] or wilds <= 0:
			continue
		for j in range(i + 1, pool.size()):
			if used[j]:
				continue
			var a := pool[i]
			var b := pool[j]
			var can_pair: bool = (a.x == b.x and absi(a.y - b.y) >= 1 and absi(a.y - b.y) <= 2) or (a.y == b.y and a.x != b.x)
			if can_pair:
				used[i] = true
				used[j] = true
				wilds -= 1
				valid_sets += 1
				break

	var unmatched := 0
	for i in pool.size():
		if not used[i]:
			unmatched += 1
	unmatched = maxi(0, unmatched - wilds * 2)
	return {
		"total": tiles.size(),
		"sets": valid_sets,
		"unmatched": unmatched,
		"can_finish": tiles.size() >= 14 and unmatched <= 1,
	}


func _find_unused(pool: Array[Vector2i], used: Array, target: Vector2i) -> int:
	for i in pool.size():
		if not used[i] and pool[i] == target:
			return i
	return -1


func slot_global_transform(index: int) -> Transform3D:
	return global_transform * _slot_transform(index)


## Where a world-space ray meets the board's tile face: {point, slot}, or empty if it misses.
func board_hit(from: Vector3, dir: Vector3) -> Dictionary:
	var inv := global_transform.affine_inverse()
	var face := _board_origin + _board.z * (TileFactory.SIZE.z * 0.5 + 0.001)
	var hit: Variant = Plane(_board.z, face).intersects_ray(inv * from, inv.basis * dir)
	if hit == null:
		return {}
	var rel: Vector3 = hit - face
	var u := rel.dot(Vector3.RIGHT)
	var v := rel.dot(_board.y)
	if absf(u) > LENGTH * 0.5 + 0.03 or v < -0.04 or v > HEIGHT + 0.04:
		return {}
	var row := 1 if v > _row_bottom(1) - ROW_GAP * 0.5 else 0
	var column := clampi(roundi(u / (TileFactory.SIZE.x + SLOT_GAP) + (SLOTS - 1) * 0.5), 0, SLOTS - 1)
	return {"point": global_transform * hit, "slot": row * SLOTS + column}


func _base_slot_transform(index: int) -> Transform3D:
	var row := index / SLOTS
	var x := (index % SLOTS - (SLOTS - 1) * 0.5) * (TileFactory.SIZE.x + SLOT_GAP)
	var step_z_offset := -0.002 if row == 1 else 0.001
	var origin := _board_origin + Vector3.RIGHT * x \
		+ _board.y * (_row_bottom(row) + TileFactory.SIZE.y * 0.5) \
		+ _board.z * (TileFactory.SIZE.z * 0.5 + step_z_offset)
	return Transform3D(_board, origin)


func _slot_transform(index: int) -> Transform3D:
	return _base_slot_transform(index)


func _row_bottom(row: int) -> float:
	return 0.004 + row * (TileFactory.SIZE.y + ROW_GAP)
