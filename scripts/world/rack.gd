class_name Rack
extends Node3D
## Two-row tile rack (ıstaka) with 2 x 15 slots. Its owner sits on the +Z side; the board leans away toward -Z.
## Slot index = row * SLOTS + column, where row 1 is the upper row.

const LENGTH := 0.8
const HEIGHT := 0.18
const SLOTS := 15
const ROWS := 2
const TILT := 0.24 # radians the board leans back
const SLOT_GAP := 0.003
const ROW_GAP := 0.018

var _board := Basis(Vector3.RIGHT, -TILT)
var _board_origin := Vector3(0, 0.014, -0.016) # bottom of the board's front face
var _tiles := Node3D.new()
var _slots: Array[Tile] = []
var _gap := -1 # slot kept open for a tile hovering over the rack, -1 when none


func _ready() -> void:
	var wood := Mat.textured("wood_table_worn", 0.6, Color(1.0, 0.85, 0.7))
	var wood_dark := Mat.textured("wood_table_worn", 0.6, Color(0.6, 0.48, 0.4))
	Mat.part(self, RoundedBox.build(Vector3(LENGTH, 0.014, 0.1), 0.005), wood_dark, Vector3(0, 0.007, 0))
	var board := Mat.part(self, RoundedBox.build(Vector3(LENGTH, HEIGHT, 0.018), 0.006), wood,
		_board_origin + _board.y * HEIGHT * 0.5 - _board.z * 0.009)
	board.basis = _board
	for row in ROWS:
		var lip := Mat.part(self, RoundedBox.build(Vector3(LENGTH, 0.01, 0.03), 0.004), wood_dark,
			_board_origin + _board.y * (_row_bottom(row) - 0.005) + _board.z * 0.015)
		lip.basis = _board
	add_child(_tiles)
	_slots.resize(ROWS * SLOTS)
	# Collision for loose tiles and glasses (tiles on the rack are pinned and need none).
	var body := Colliders.static_body(self)
	Colliders.box(body, Vector3(LENGTH, 0.014, 0.1), Transform3D(Basis(), Vector3(0, 0.007, 0)))
	Colliders.box(body, Vector3(LENGTH, HEIGHT, 0.018), Transform3D(_board, _board_origin + _board.y * HEIGHT * 0.5 - _board.z * 0.009))


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


## Moves a tile into a free slot, sliding it there unless instant.
func put(tile: Tile, index: int, animate := true, time := 0.18) -> void:
	_slots[index] = tile
	tile.holder = self
	tile.pin()
	if tile.get_parent():
		tile.reparent(_tiles)
	else:
		_tiles.add_child(tile)
	var target := _slot_transform(index)
	if animate:
		tile.slide_to(target, time)
	else:
		tile.transform = target


## Can a tile be dropped at `index`: free, or its row has room for the neighbours to shift?
func can_insert(index: int) -> bool:
	return not _with_gap(index).is_empty()


## Opens a gap at `index` while a dragged tile hovers there (-1 closes it). Only moves tiles visually.
func show_gap(index: int) -> void:
	if index == _gap:
		return
	_gap = index
	var layout := _with_gap(index) if index >= 0 else _slots
	if layout.is_empty():
		layout = _slots
	_layout(layout)


## Drops a tile at `index`, pushing its row neighbours aside toward the nearest free slot.
func insert(tile: Tile, index: int) -> void:
	var layout := _with_gap(index)
	_gap = -1
	if layout.is_empty():
		_layout(_slots)
		put(tile, nearest_free(index))
		return
	_slots = layout
	_layout(_slots)
	put(tile, index, true, 0.08)


## Takes a tile off the rack and returns the slot it was in.
func release(tile: Tile) -> int:
	var index := _slots.find(tile)
	if index >= 0:
		_slots[index] = null
	tile.holder = null
	return index


## Closest empty slot to index, preferring the same row; -1 when the rack is full.
func nearest_free(index: int) -> int:
	var row := index / SLOTS
	var column := index % SLOTS
	for r in [row, 1 - row]:
		for offset in SLOTS:
			for c in [column - offset, column + offset]:
				if c >= 0 and c < SLOTS and _slots[r * SLOTS + c] == null:
					return r * SLOTS + c
	return -1


func tile_at(index: int) -> Tile:
	return _slots[index]


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
	if absf(u) > LENGTH * 0.5 + 0.02 or v < -0.03 or v > HEIGHT + 0.03:
		return {}
	var row := 1 if v > _row_bottom(1) - ROW_GAP * 0.5 else 0
	var column := clampi(roundi(u / (TileFactory.SIZE.x + SLOT_GAP) + (SLOTS - 1) * 0.5), 0, SLOTS - 1)
	return {"point": global_transform * hit, "slot": row * SLOTS + column}


## Lowest height a hand may be at above a world point without passing through the board (-INF where clear).
## Tiles themselves are not obstacles: fingers touch them.
func clearance(point: Vector3) -> float:
	var local := to_local(point)
	if absf(local.x) > LENGTH * 0.5 + 0.02:
		return -INF
	var depth := (local - _board_origin).dot(_board.z) # 0 at the board's front face, + toward the owner
	if depth > -0.035 and depth < 0.0:
		return to_global(_board_origin + _board.y * (HEIGHT + 0.012)).y
	if absf(local.z) < 0.05:
		return global_position.y + 0.016 # the base under the tiles
	return -INF


## How far a world point has to move toward the owner (the rack's +Z) to be `margin` clear of the owner's side of
## the rack: anything below the top of the board that is in or past the board, its tiles and lips, or on the base.
## Points beyond the board count too, so a hand never ends up through it. 0 when clear; seated hands use this.
func penetration(point: Vector3, margin := 0.0) -> float:
	var local := to_local(point)
	if absf(local.x) > LENGTH * 0.5 + margin:
		return 0.0
	var rel := local - _board_origin
	var depth := rel.dot(_board.z) # 0 at the board's front face, + toward the owner
	var front := 0.035 + margin # tiles and lips stand this far out of the board face
	if rel.dot(_board.y) < HEIGHT + margin and depth < front:
		return (front - depth) / _board.z.z
	if absf(local.z) < 0.05 + margin and local.y < 0.014 + margin:
		return 0.05 + margin - local.z
	return 0.0


# Slot contents after making room at `index`: the tiles between it and the nearest free slot in the same row
# move one step toward that free slot. Empty when the row is full.
func _with_gap(index: int) -> Array[Tile]:
	var slots: Array[Tile] = _slots.duplicate()
	if slots[index] == null:
		return slots
	var row := index / SLOTS * SLOTS
	var column := index % SLOTS
	for offset in range(1, SLOTS):
		for direction in [-1, 1]:
			var free: int = column + direction * offset
			if free < 0 or free >= SLOTS or slots[row + free] != null:
				continue
			var c := free
			while c != column:
				slots[row + c] = slots[row + c - direction]
				c -= direction
			slots[index] = null
			return slots
	return []


func _layout(layout: Array[Tile]) -> void:
	for i in layout.size():
		if layout[i]:
			layout[i].slide_to(_slot_transform(i), 0.1)


func _slot_transform(index: int) -> Transform3D:
	var row := index / SLOTS
	var x := (index % SLOTS - (SLOTS - 1) * 0.5) * (TileFactory.SIZE.x + SLOT_GAP)
	var origin := _board_origin + Vector3.RIGHT * x \
		+ _board.y * (_row_bottom(row) + TileFactory.SIZE.y * 0.5) \
		+ _board.z * (TileFactory.SIZE.z * 0.5 + 0.001)
	return Transform3D(_board, origin)


func _row_bottom(row: int) -> float:
	return 0.005 + row * (TileFactory.SIZE.y + ROW_GAP)
