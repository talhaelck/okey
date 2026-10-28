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
