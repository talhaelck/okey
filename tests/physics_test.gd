extends SceneTree
## Jolt physics: dropped tiles settle on the felt, a pushed tea glass tips over and spills, the player's arm
## can knock a glass, and pinned rack tiles never move.
## Run: godot --path . --headless --fixed-fps 60 --script res://tests/physics_test.gd

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(5)
	for w in main.watchers:
		w._timer = 999.0
	var hand: Hand = main.hand
	var me: Seat = main.seats[0]
	var rack_tiles: Array = me.rack._slots.filter(func(t): return t != null)
	var before: Array = rack_tiles.map(func(t: Tile): return t.global_position)

	# A tile dropped on the felt lands and rests on it.
	var tile: Tile = rack_tiles[0]
	hand.grab(tile)
	hand._drop = {"point": Vector3(0.15, Table.TOP, 0.3)}
	hand.drop()
	check(not tile.freeze, "dropped tile is loose")
	await frames(150)
	var rest_y := Table.TOP + TileFactory.SIZE.z * 0.5
	check(absf(tile.global_position.y - rest_y) < 0.004, "tile rests on the felt (y=%.4f, want %.4f)" % [tile.global_position.y, rest_y])
	check(tile.linear_velocity.length() < 0.02, "tile has settled")
	check(tile.holder == main.table, "tile belongs to the table")

	# Picking it up again pins it.
	hand.grab(tile)
	check(tile.freeze, "picked-up tile is pinned")
	hand._drop = {"rack": me.rack, "slot": me.rack.nearest_free(0)}
	hand.drop()

	# A sideways shove at the rim tips a glass over and spills it.
	var glass: TeaGlass = main.seats[2].tea
	var spilled := [false]
	glass.spilled.connect(func(_g): spilled[0] = true)
	glass.apply_impulse(Vector3(0.25, 0, 0), glass.global_basis * Vector3(0, TeaGlass.GLASS_HEIGHT, 0))
	await frames(120)
	check(spilled[0], "shoved glass spills")

	# The player's arm sweeping through its own glass knocks it over.
	var mine: TeaGlass = me.tea
	var knocked := [false]
	mine.spilled.connect(func(_g): knocked[0] = true)
	var start := mine.global_position + Vector3(0.0, 0.075, -0.25)
	hand.set_process(false) # drive the arm directly; Hand would send it back to rest
	hand.arm.resting = false
	hand.arm.goal = Transform3D(hand.arm.rest.basis, start)
	await frames(40)
	hand.arm.goal = Transform3D(hand.arm.rest.basis, mine.global_position + Vector3(0.0, 0.075, 0.2))
	await frames(120)
	check(knocked[0], "arm knocks its tea glass over")

	# Pinned rack tiles never moved (all but the one that went for a walk).
	var moved := 0
	for i in range(1, rack_tiles.size()):
		if rack_tiles[i].global_position.distance_to(before[i]) > 0.001 and rack_tiles[i].holder == me.rack:
			moved += 1
	check(moved == 0, "rack tiles stay put (%d moved)" % moved)

	print("FAILS: ", fails)
	quit(fails)
