class_name Table
extends Node3D
## Square okey table: green felt, raised wooden rim, centre draw pile.

const TOP := 0.75 # height of the felt surface
const SIZE := 1.3
const RIM := 0.07
const WOOD := Color(0.48, 0.27, 0.16)
const WOOD_DARK := Color(0.34, 0.19, 0.11)
const FELT := Color(0.16, 0.48, 0.3)

var _pile := Node3D.new()


func _ready() -> void:
	var felt := SIZE - RIM * 2.0
	Toon.part(self, RoundedBox.build(Vector3(SIZE, 0.05, SIZE), 0.02), WOOD, Vector3(0, TOP - 0.035, 0))
	Toon.part(self, RoundedBox.build(Vector3(felt, 0.01, felt), 0.003), FELT, Vector3(0, TOP - 0.005, 0), 1.0)
	for side in 4:
		# Pinwheel layout so the four rim pieces never overlap at the corners.
		var pivot := Node3D.new()
		pivot.rotation.y = side * PI * 0.5
		add_child(pivot)
		Toon.part(pivot, RoundedBox.build(Vector3(SIZE - RIM, 0.03, RIM), 0.012), WOOD,
			Vector3(RIM * 0.5, TOP + 0.005, (SIZE - RIM) * 0.5))
	Toon.part(self, RoundedBox.build(Vector3(SIZE - 0.12, 0.08, SIZE - 0.12), 0.015), WOOD_DARK, Vector3(0, TOP - 0.1, 0))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg_height := TOP - 0.06
		Toon.part(self, Toon.cylinder(0.03, leg_height, 0.035), WOOD_DARK,
			Vector3(corner.x * 0.55, leg_height * 0.5, corner.y * 0.55))
	add_child(_pile)


## Face-down draw pile in the middle plus the face-up indicator tile.
func show_pile(tiles: Array, indicator: Vector2i) -> void:
	for child in _pile.get_children():
		child.queue_free()
	const COLUMNS := 8
	const ROWS := 2
	var lying := TileFactory.SIZE.z
	for i in tiles.size():
		var layer := floori(i / float(COLUMNS * ROWS))
		var column := i % COLUMNS
		var row := floori((i % (COLUMNS * ROWS)) / float(COLUMNS))
		var tile := TileFactory.create(tiles[i])
		tile.basis = Basis(Vector3.RIGHT, PI * 0.5) # face down
		tile.position = Vector3((column - (COLUMNS - 1) * 0.5) * 0.051, TOP + lying * (layer + 0.5) + 0.0005 * layer,
			(row - 0.5) * 0.074)
		_pile.add_child(tile)
	var shown := TileFactory.create(indicator)
	# Face up, readable from seat 0, slightly askew.
	shown.basis = Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, -PI * 0.5)
	shown.position = Vector3(0.28, TOP + lying * 0.5, 0.14)
	_pile.add_child(shown)
