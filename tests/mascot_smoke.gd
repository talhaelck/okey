extends SceneTree
## Integration checks: run with --headless --path . --script tests/mascot_smoke.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.get_node("FocusCamera").mouse_control = false
	root.add_child(main)
	await process_frame
	# Control gaze explicitly so random Watcher timers cannot race these assertions.
	for watcher: Watcher in main.watchers:
		watcher.set_process(false)
	_check(get_nodes_in_group("tiles").size() == 106, "All 106 tiles are still dealt/spawned")
	var hand: Hand = main.hand
	var eye: Vector3 = main.camera.global_position
	var pile_reachable := false
	for tile: Tile in get_nodes_in_group("tiles"):
		if tile.holder == main.table:
			var picked := hand._pick(eye, (tile.global_position-eye).normalized())
			if picked != null and picked.holder == main.table:
				pile_reachable = true
				break
	_check(pile_reachable, "Draw pile is reachable from the wider observation camera")
	for side_index in [1,3]:
		var reachable := false
		for tile: Tile in get_nodes_in_group("tiles"):
			if tile.holder == main.seats[side_index].rack:
				var picked := hand._pick(eye,(tile.global_position-eye).normalized())
				if picked != null and picked.holder == main.seats[side_index].rack:
					reachable = true
					break
		_check(reachable, "Side rack %d remains within stealing reach" % side_index)
	var expected := ["bunny", "panda", "dinosaur"]
	for i in 3:
		var seat: Seat = main.seats[i + 1]
		_check(seat.character == expected[i], "Expected mascot at seat %d" % (i + 1))
		var mascot: MascotCharacter = seat.buddy._mascot
		_check(mascot != null, "Procedural mascot loaded")
		if mascot == null:
			continue
		_check(mascot._eyes.size() == 2, "Both eyes animate")
		_check(mascot.head.find_children("*", "MeshInstance3D", true, false).size() > 20, "Face geometry exists")
		var body_transform := seat.buddy.transform
		# A side glance must move the head without pivoting the seated hips/feet.
		seat.buddy.look_toward(main.seats[(i + 2) % 4].head_anchor.global_position)
		await create_timer(0.4).timeout
		_check(absf(mascot.head.rotation.y) > 0.1, "Head turns toward the other seat")
		_check(seat.buddy.transform.is_equal_approx(body_transform), "Seated body stays in place")
		seat.buddy.look_home()
		await create_timer(0.4).timeout
		_check(absf(mascot.head.rotation.y) < 0.01, "Head returns to the rack")
		var watcher: Watcher = main.watchers[i]
		watcher.target = main.seats[0]
		watcher._set_state(Watcher.State.LOOK, 2.0)
		_check(watcher.is_watching(main.seats[0]), "Watching still detects the local player")
		_check(seat.buddy._alert.visible, "Yellow alert remains visible while watching")
		watcher.caught_thief()
		_check(mascot._reaction > 0.0, "Caught-thief gesture triggers the head shake")
		mascot._blink_time = 0.08
		mascot._process(0.01)
		_check(mascot._eyes[0].scale.y < 0.1, "Eyelids close during a blink")
		mascot._process(0.2)
		_check(is_equal_approx(mascot._eyes[0].scale.y, 1.0), "Eyes reopen after blinking")
	# Exercise real stealing and catching through Hand, not just visual reactions.
	for watcher: Watcher in main.watchers:
		watcher._set_state(Watcher.State.RACK,10.0)
	var stolen_tile: Tile
	for tile: Tile in get_nodes_in_group("tiles"):
		if tile.holder == main.seats[3].rack:
			stolen_tile = tile
			break
	hand.grab(stolen_tile)
	hand._drop = {"rack": main.seats[0].rack, "slot": main.seats[0].rack.nearest_free(0)}
	hand.drop()
	_check(hand.held == null and stolen_tile.holder == main.seats[0].rack, "Stolen tile can be placed on the local rack")
	_check(main.stolen == 1, "Successful steal updates the redesigned HUD")
	var foreign: Tile
	for tile: Tile in get_nodes_in_group("tiles"):
		if tile.holder == main.seats[1].rack:
			foreign = tile
			break
	hand.grab(foreign)
	_check(hand.held == foreign, "Hand can hold a stolen tile")
	main.watchers[0].target = main.seats[0]
	main.watchers[0]._set_state(Watcher.State.LOOK,2.0)
	hand._check_caught()
	_check(hand.held == null and foreign.holder == main.seats[1].rack, "Caught tile returns to its original rack")
	_check(main.caught == 1, "Caught event updates the redesigned HUD")
	_check(get_nodes_in_group("tiles").size() == 106, "Stealing/catching preserves the full tile set")
	# Existing imported characters are still supported by Buddy's public API.
	var legacy := Buddy.new()
	root.add_child(legacy)
	legacy.setup("rabbit", 0.85)
	legacy.look_home()
	legacy.gesture("No")
	_check(legacy._anim != null and legacy._anim.is_playing(), "Legacy glTF animations still play")
	legacy.queue_free()
	main.queue_free()
	await process_frame
	print("Mascot integration checks: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
