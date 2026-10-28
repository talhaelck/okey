class_name Rack
extends Node3D
## Two-row tile rack (ıstaka). Its owner sits on the +Z side; the board leans away toward -Z.

const LENGTH := 0.8
const SLOTS := 15
const TILT := 0.24 # radians the board leans back
const SLOT_GAP := 0.003
const ROW_GAP := 0.018
const WOOD := Color(0.8, 0.5, 0.32)
const WOOD_DARK := Color(0.62, 0.36, 0.22)

var _board := Basis(Vector3.RIGHT, -TILT)
var _board_origin := Vector3(0, 0.014, -0.016) # bottom of the board's front face
var _tiles := Node3D.new()


func _ready() -> void:
	Toon.part(self, RoundedBox.build(Vector3(LENGTH, 0.014, 0.1), 0.005), WOOD_DARK, Vector3(0, 0.007, 0))
	var board := Toon.part(self, RoundedBox.build(Vector3(LENGTH, 0.18, 0.018), 0.006), WOOD,
		_board_origin + _board.y * 0.09 - _board.z * 0.009)
	board.basis = _board
	for row in 2:
		var lip := Toon.part(self, RoundedBox.build(Vector3(LENGTH, 0.01, 0.03), 0.004), WOOD_DARK,
			_board_origin + _board.y * (_row_bottom(row) - 0.005) + _board.z * 0.015)
		lip.basis = _board
	add_child(_tiles)


## Lays tiles out: first half on the upper row, the rest on the lower row, each row centred.
func set_tiles(tiles: Array) -> void:
	for child in _tiles.get_children():
		child.queue_free()
	var upper_count := ceili(tiles.size() / 2.0)
	for i in tiles.size():
		var row := 1 if i < upper_count else 0
		var in_row := upper_count if row == 1 else tiles.size() - upper_count
		var slot := (i if row == 1 else i - upper_count) + floori((SLOTS - in_row) / 2.0)
		var tile := TileFactory.create(tiles[i])
		tile.basis = _board
		tile.position = _slot_position(row, slot)
		_tiles.add_child(tile)


func _slot_position(row: int, slot: int) -> Vector3:
	var x := (slot - (SLOTS - 1) * 0.5) * (TileFactory.SIZE.x + SLOT_GAP)
	return _board_origin + Vector3.RIGHT * x \
		+ _board.y * (_row_bottom(row) + TileFactory.SIZE.y * 0.5) \
		+ _board.z * (TileFactory.SIZE.z * 0.5 + 0.001)


func _row_bottom(row: int) -> float:
	return 0.005 + row * (TileFactory.SIZE.y + ROW_GAP)
