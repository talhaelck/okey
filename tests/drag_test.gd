extends SceneTree
## Rack drag and drop: instant grab, insert with neighbours shifting, nothing lost.
## Run: godot --path . --headless --script res://tests/drag_test.gd

var fails := 0

func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1

func row_values(rack: Rack, row: int) -> Array:
	var out := []
	for c in Rack.SLOTS:
		var t: Tile = rack._slots[row * Rack.SLOTS + c]
		out.append(t.value.y if t else 0)
	return out

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for w in main.watchers:
		w._timer = 999.0
	var hand: Hand = main.hand
	var rack: Rack = main.seats[0].rack
	var count := func() -> int: return rack._slots.filter(func(t): return t != null).size()
	var before: int = count.call()
	print("upper before ", row_values(rack, 1))
	# Drag the first upper-row tile onto the 4th upper-row tile: neighbours must shift, nothing lost.
	var first := -1
	for c in Rack.SLOTS:
		if rack._slots[Rack.SLOTS + c]:
			first = c
			break
	var tile: Tile = rack._slots[Rack.SLOTS + first]
	var target := Rack.SLOTS + first + 3
	var displaced: Tile = rack._slots[target]
	hand.grab(tile)
	check(hand.held == tile, "grab is instant")
	check(rack.can_insert(target), "can insert onto an occupied slot")
	rack.show_gap(target)
	check(true, "gap preview runs")
	hand._drop = {"rack": rack, "slot": target}
	hand.drop()
	print("upper after  ", row_values(rack, 1))
	check(rack._slots[target] == tile, "dropped tile sits in the target slot")
	check(rack._slots.has(displaced) and rack._slots[target] != displaced, "displaced tile moved aside, not lost")
	check(count.call() == before, "tile count unchanged (%d)" % count.call())
	# Fill a full row scenario: a row with no free slot cannot take an insert.
	var full_rack := Rack.new()
	root.add_child(full_rack)
	var vals := []
	for i in Rack.SLOTS * 2:
		vals.append(Vector2i(i % 4, i % 13 + 1))
	full_rack.set_tiles(vals)
	check(not full_rack.can_insert(3), "full rack refuses inserts")
	print("FAILS: ", fails)
	quit(fails)
