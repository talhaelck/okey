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
func put(tile: Tile, index: int, animate := true) -> void:
	_slots[index] = tile
	tile.holder = self
	if tile.get_parent():
		tile.reparent(_tiles)
	else:
		_tiles.add_child(tile)
	var target := _slot_transform(index)
	if animate:
		tile.slide_to(target)
	else:
		tile.transform = target


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


func _slot_transform(index: int) -> Transform3D:
	var row := index / SLOTS
	var x := (index % SLOTS - (SLOTS - 1) * 0.5) * (TileFactory.SIZE.x + SLOT_GAP)
	var origin := _board_origin + Vector3.RIGHT * x \
		+ _board.y * (_row_bottom(row) + TileFactory.SIZE.y * 0.5) \
		+ _board.z * (TileFactory.SIZE.z * 0.5 + 0.001)
	return Transform3D(_board, origin)


func _row_bottom(row: int) -> float:
	return 0.005 + row * (TileFactory.SIZE.y + ROW_GAP)
