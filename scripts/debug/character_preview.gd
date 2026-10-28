extends Node3D
## Open this scene with F6 to inspect the three seated mascots under neutral lighting.
## CLI: godot --path . scenes/character_preview.tscn -- --screenshot=screenshots/characters.png


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("ece8df")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("ecedff")
	settings.ambient_light_energy = 0.45
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	_light(Vector3(-35, -30, 0), 1.1, Color("fff1da"))
	_light(Vector3(-20, 140, 0), 0.6, Color("d9e6ff"))
	var floor_mesh := Toon.part(self, Toon.cylinder(200.0, 0.05), Color("e8e1d5"), Vector3(0, -0.355, 0))
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("c9c2b7")
	floor_material.roughness = 1.0
	floor_mesh.material_override = floor_material
	var names := ["PANDA", "TAVŞAN", "DİNOZOR"]
	for i in 3:
		var mascot := MascotCharacter.new()
		mascot.position.x = (1 - i) * 0.95
		mascot.rotation.y = [0.1, 0.0, -0.13][i]
		add_child(mascot)
		mascot.build(MascotCharacter.KINDS[i], 1.08 if i == 1 else 0.95)
		Toon.part(self, Toon.cylinder(0.225, 0.06), Color("a58b6c"), Vector3(mascot.position.x, -0.04, 0.04))
		for side in [-1.0, 1.0]:
			Toon.part(self, Toon.cylinder(0.027, 0.27), Color("a58b6c"), Vector3(mascot.position.x + side * 0.15, -0.19, 0.09))
		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 48
		label.pixel_size = 0.0015
		label.modulate = Color("605e54")
		label.outline_size = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(mascot.position.x, -0.28, -0.70)
		add_child(label)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 0.93, -4.0)
	camera.look_at(Vector3(0, 0.36, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.current = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_capture(arg.trim_prefix("--screenshot="))


func _light(angles: Vector3, energy: float, color: Color) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = true
	add_child(light)


func _capture(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	for frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save character preview: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("Screenshot saved: ", path)
	get_tree().quit()
