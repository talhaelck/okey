class_name Table
extends Node3D
## Square okey table: green felt, raised wooden rim, centre draw pile.

const TOP := 0.75 # height of the felt surface
const SIZE := 1.5
const RIM := 0.07
const FELT := Color(0.07, 0.3, 0.17)

var _pile := Node3D.new()
var _loose := Node3D.new()


func _ready() -> void:
	var wood := Mat.textured("wood_table_worn", 0.9)
	var wood_dark := Mat.textured("wood_table_worn", 0.9, Color(0.55, 0.45, 0.4))
	var cloth := Mat.textured("rough_linen", 0.12, FELT, false)
	var felt := SIZE - RIM * 2.0
	Mat.part(self, RoundedBox.build(Vector3(SIZE, 0.05, SIZE), 0.02), wood, Vector3(0, TOP - 0.035, 0))
	Mat.part(self, RoundedBox.build(Vector3(felt, 0.01, felt), 0.003), cloth, Vector3(0, TOP - 0.005, 0))
	for side in 4:
		# Pinwheel layout so the four rim pieces never overlap at the corners.
		var pivot := Node3D.new()
		pivot.rotation.y = side * PI * 0.5
		add_child(pivot)
		Mat.part(pivot, RoundedBox.build(Vector3(SIZE - RIM, 0.03, RIM), 0.012), wood,
			Vector3(RIM * 0.5, TOP + 0.005, (SIZE - RIM) * 0.5))
	Mat.part(self, RoundedBox.build(Vector3(SIZE - 0.12, 0.08, SIZE - 0.12), 0.015), wood_dark, Vector3(0, TOP - 0.1, 0))
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var leg_height := TOP - 0.06
		Mat.part(self, Mat.cylinder(0.03, leg_height, 0.035), wood_dark,
			Vector3(corner.x * 0.62, leg_height * 0.5, corner.y * 0.62))
	add_child(_pile)
	add_child(_loose)


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
		tile.holder = self
		tile.basis = Basis(Vector3.RIGHT, PI * 0.5) # face down
		tile.position = Vector3((column - (COLUMNS - 1) * 0.5) * 0.051, TOP + lying * (layer + 0.5) + 0.0005 * layer,
			(row - 0.5) * 0.074)
		_pile.add_child(tile)
	var shown := TileFactory.create(indicator)
	shown.holder = self
	# Face up, readable from seat 0, slightly askew.
	shown.basis = Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, -PI * 0.5)
	shown.position = Vector3(0.28, TOP + lying * 0.5, 0.14)
	_pile.add_child(shown)


## Lays a tile face up on the felt at a world point, its numbers upright for someone facing along yaw.
func put_loose(tile: Tile, point: Vector3, yaw: float) -> void:
	tile.holder = self
	tile.reparent(_loose)
	var local := to_local(point)
	local.y = TOP + TileFactory.SIZE.z * 0.5
	tile.slide_to(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), local))


func release(tile: Tile) -> int:
	tile.holder = null
	return -1


## Where a world-space ray meets the felt, or null if it lands outside the playing area.
func felt_hit(from: Vector3, dir: Vector3) -> Variant:
	var hit: Variant = Plane(Vector3.UP, TOP).intersects_ray(to_local(from), dir)
	if hit == null:
		return null
	var half := SIZE * 0.5 - RIM - TileFactory.SIZE.y * 0.5
	if absf(hit.x) > half or absf(hit.z) > half:
		return null
	return to_global(hit)
