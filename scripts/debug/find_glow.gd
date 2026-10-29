extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	
	print("--- SEARCHING GLOWING / UNSHADED / BLOOM OBJECTS ---")
	for mi in main.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or not mi.is_visible_in_tree():
			continue
		var mats: Array = []
		if mi.material_override:
			mats.append(mi.material_override)
		if mi.material_overlay:
			mats.append(mi.material_overlay)
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var sm = mi.mesh.surface_get_material(s)
				if sm:
					mats.append(sm)
		
		for m in mats:
			if m is StandardMaterial3D:
				var std: StandardMaterial3D = m
				if std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or std.emission_enabled or std.no_depth_test:
					print("FOUND: Node=", mi.get_path(), " Name=", mi.name, " Unshaded=", std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, " NoDepthTest=", std.no_depth_test, " Emission=", std.emission_enabled, " Albedo=", std.albedo_color, " Pos=", mi.global_position)
	main.queue_free()
	quit()
