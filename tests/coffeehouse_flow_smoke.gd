extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var menu: Node = load("res://scenes/coffeehouse.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var old := [CafePreferences.cast,CafePreferences.companion,CafePreferences.cloth]
	check(menu.game.process_mode == Node.PROCESS_MODE_DISABLED,"Menu must suspend gameplay")
	check(not menu.game.hud.visible,"Gameplay HUD leaked into menu")
	CafePreferences.cast = "Dayılar"
	CafePreferences.companion = "sabri"
	CafePreferences.cloth = "Bordo"
	menu._apply_table()
	check(menu.game.seats[2].character == "sabri","Patron selection was not applied")
	check(menu.game.seats[2].buddy._patron != null,"Patron presentation missing")
	var found := false
	for mi: MeshInstance3D in menu.game.table.find_children("*","MeshInstance3D",true,false):
		if mi.material_override is ShaderMaterial and mi.material_override.shader.resource_path.ends_with("okey_felt.gdshader"):
			found = true
			var color: Color = mi.material_override.get_shader_parameter("felt_color")
			check(color.r > color.g,"Burgundy cloth was not applied")
	check(found,"Table cloth shader not found")
	menu._characters()
	check(is_instance_valid(menu._preview),"Character preview missing")
	CafePreferences.cast = "Hayvanlar"
	CafePreferences.companion = "bunny"
	menu._apply_companion()
	check(menu.game.seats[2].character == "bunny","Mascot selection was not retained")
	check(menu.game.seats[2].buddy._mascot != null,"Mascot presentation missing")
	menu._table()
	menu._settings()
	menu._home()
	menu._play(false)
	check(not menu.layer.visible,"Menu did not close when starting")
	check(menu.game.hud.visible,"Game HUD did not resume")
	check(menu.game.process_mode == Node.PROCESS_MODE_INHERIT,"Gameplay did not resume")
	menu.game.hud.open_menu()
	check(paused,"Pause menu failed after table setup")
	menu.game.hud.close_menu()
	check(not paused,"Resume failed after table setup")
	var mesh := TileFactory.create(Vector2i(0,13))
	check(mesh.get_aabb().size.is_equal_approx(TileFactory.SIZE),"Tile physical size changed")
	mesh.free()
	CafePreferences.cast = old[0]
	CafePreferences.companion = old[1]
	CafePreferences.cloth = old[2]
	menu.free()
	await process_frame
	print("COFFEEHOUSE_FLOW: PASS" if failures.is_empty() else "COFFEEHOUSE_FLOW: FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
