class_name Table
extends Node3D
## Walnut okey table with inset felt, brass details and a center draw pile.

const TOP := 0.75 # height of the felt surface
const SIZE := 1.3
const RIM := 0.07
const WOOD := Color(0.48, 0.27, 0.16)
const WOOD_DARK := Color(0.34, 0.19, 0.11)
const FELT := Color(0.16, 0.48, 0.3)

var _pile := Node3D.new()
var _loose := Node3D.new()


func _ready() -> void:
	var felt := SIZE - RIM * 2.0
	var walnut := SurfaceStyle.textured(Color("68472f"), SurfaceStyle.Kind.WOOD, 0.5)
	var dark := SurfaceStyle.textured(Color("33251d"))
	var brass := SurfaceStyle.metal(Color("a1824e"), 0.45)
	SurfaceStyle.box(self, Vector3(SIZE+0.14,0.075,SIZE+0.14), Vector3(0,TOP-0.042,0), walnut, 0.025)
	SurfaceStyle.box(self, Vector3(felt,0.012,felt), Vector3(0,TOP-0.005,0), SurfaceStyle.textured(Color("25473b"), SurfaceStyle.Kind.FABRIC, 0.94), 0.006)
	for side in 4:
		var pivot := Node3D.new()
		pivot.rotation.y = side * PI * 0.5
		add_child(pivot)
		SurfaceStyle.box(pivot, Vector3(1.30,0.035,0.14), Vector3(0.07,TOP+0.004,0.65), walnut, 0.012)
		SurfaceStyle.box(pivot, Vector3(1.30,0.005,0.003), Vector3(0.07,TOP+0.024,0.603), brass, 0.001)
		# Fine stitched edge sits flush with the cloth, outside all drop slots.
		for i in 42:
			SurfaceStyle.box(pivot, Vector3(0.012,0.001,0.001), Vector3((i-20.5)*0.025,TOP+0.002,0.553), Toon.material(Color("8a8864")), 0.0003)
	SurfaceStyle.box(self, Vector3(SIZE,0.13,SIZE), Vector3(0,TOP-0.13,0), dark, 0.02)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		SurfaceStyle.part(self, SurfaceStyle.lathe([Vector2(0.035,0),Vector2(0.04,0.05),Vector2(0.029,0.13),Vector2(0.036,0.42),Vector2(0.06,0.54),Vector2(0.055,0.65)]), dark, Vector3(corner.x*0.57,0,corner.y*0.57))
		SurfaceStyle.part(self, Toon.cylinder(0.025,0.002), brass, Vector3(corner.x*0.65,TOP+0.023,corner.y*0.65))
	CafeProps.tea(self, Vector3(-0.64,TOP+0.023,0.60), true)
	CafeProps.tea(self, Vector3(0.64,TOP+0.023,-0.60))
	SurfaceStyle.box(self, Vector3(0.22,0.045,0.004), Vector3(0,TOP-0.038,0.723), brass, 0.005)
	SurfaceStyle.lettering(self, "SON EL  /  04", Vector3(0,TOP-0.038,0.727), 26, 0.0007, Color("372c1b"))
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
