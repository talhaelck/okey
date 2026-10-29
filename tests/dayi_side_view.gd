extends SceneTree
## Debug view of one seated Meshy dayı at the table, from the side and from the player's seat.
##   godot --path . --script tests/dayi_side_view.gd -- <out prefix> [seat index, default 2]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var index := int(args[1]) if args.size() > 1 else 2
	var turn := Basis(Vector3.UP, (index - 2) * PI * 0.5) # views are written for seat 2
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	world.add_child(Table.new())
	var seat := Seat.new()
	seat.seat_index = index
	world.add_child(seat)
	var cam := Camera3D.new()
	world.add_child(cam)
	for frame in 30:
		await process_frame
	for view in [["side", Vector3(2.0, 1.0, -1.15), Vector3(0, 0.75, -1.0)], ["hands", Vector3(0.45, 1.25, -0.25), Vector3(0, 0.8, -0.75)], ["player", Vector3(0, 1.35, 1.05), Vector3(0, 0.8, -0.6)]]:
		cam.look_at_from_position(turn * view[1], turn * view[2])
		cam.fov = 50
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("%s_%s.png" % [out, view[0]])
	quit()
