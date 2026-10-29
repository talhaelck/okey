extends SceneTree
## Tile atlas mapping: every tile value has its own atlas cell inside the 8x7 grid.
## Run: godot --path . --headless --script res://tests/tiles_test.gd

func _init() -> void:
	var seen := {}
	var fails := 0
	for color in TileFactory.COLORS:
		for number in range(1, TileFactory.NUMBERS + 1):
			var cell := TileFactory.cell(Vector2i(color, number))
			if seen.has(cell) or cell < 0 or cell >= 52:
				print("FAIL cell ", cell, " for ", Vector2i(color, number))
				fails += 1
			seen[cell] = true
	if TileFactory.cell(Vector2i(TileFactory.FAKE_OKEY, 0)) != 52:
		print("FAIL fake okey cell")
		fails += 1
	var tile := TileFactory.create(Vector2i(2, 7))
	if tile.face.get_instance_shader_parameter("cell") != 2.0 * 13 + 6:
		print("FAIL instance parameter ", tile.face.get_instance_shader_parameter("cell"))
		fails += 1
	tile.free()
	print("FAILS: ", fails)
	quit(fails)
