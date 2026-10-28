extends SceneTree
## Short GPU smoke/measurement pass; never changes game quality or saves user settings.
## godot --path . --script scripts/debug/render_check.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	main.get_node("FocusCamera").mouse_control = false
	root.add_child(main)
	for frame in 120:
		await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 240:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
	var sum := 0.0
	for value in samples:
		sum += value
	samples.sort()
	print("Render check: %d frames, %.1f average FPS, %.2f ms p95 frame time" % [samples.size(),1000.0/(sum/samples.size()),samples[int(samples.size()*0.95)]])
	print("Visible primitives: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "; draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	main.queue_free()
	await process_frame
	quit()
