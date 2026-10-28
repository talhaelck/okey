extends Node3D
## The kahvehane at night: tiled floor, wood-panelled walls under smoke-yellowed plaster, a hanging lamp over
## our table, a couple of background tables with regulars, shelves, an old TV and dim wall sconces.
## Props are CC0 Poly Haven models (assets/polyhaven); everything is placed relative to our table at the origin.

const WIDTH := 8.0 # along X
const DEPTH := 7.5 # along Z
const HEIGHT := 3.0
const PANEL := 1.1 # height of the wooden wainscot
const WALL := 0.06
const TEA_TABLE_TOP := 0.757 # round_wooden_table_01 at 0.75 scale
const LAMP_WARM := Color(1.0, 0.82, 0.62)

var _fan: Node3D


func _ready() -> void:
	_build_shell()
	_hanging_lamp(Vector3(0, HEIGHT, 0), 9.0, true)
	_background_table(Vector3(-2.7, 0, -2.2), 0.4)
	_background_table(Vector3(2.8, 0, -2.0), -0.3)
	_background_table(Vector3(-2.6, 0, 2.4), 0.9)
	_props()


func _process(delta: float) -> void:
	if _fan:
		_fan.rotate_y(delta * 2.5)


func _build_shell() -> void:
	var floor_mat := Mat.textured("brown_floor_tiles", 1.0)
	var plaster := Mat.textured("yellow_plaster_02", 2.0, Color(0.95, 0.85, 0.7))
	var panel := Mat.textured("dark_paneled_wood", 1.2)
	var ceiling := Mat.textured("plastered_wall", 2.0, Color(0.55, 0.5, 0.45))
	Mat.part(self, BoxMesh.new(), floor_mat, Vector3(0, -0.05, 0)).scale = Vector3(WIDTH, 0.1, DEPTH)
	Mat.part(self, BoxMesh.new(), ceiling, Vector3(0, HEIGHT + 0.05, 0)).scale = Vector3(WIDTH, 0.1, DEPTH)
	# Four walls: [centre, length, facing yaw].
	for wall in [[Vector3(0, 0, -DEPTH / 2), WIDTH, 0.0], [Vector3(0, 0, DEPTH / 2), WIDTH, PI],
			[Vector3(-WIDTH / 2, 0, 0), DEPTH, PI / 2], [Vector3(WIDTH / 2, 0, 0), DEPTH, -PI / 2]]:
		var pivot := Node3D.new()
		pivot.position = wall[0]
		pivot.rotation.y = wall[2]
		add_child(pivot)
		var length: float = wall[1]
		Mat.part(pivot, BoxMesh.new(), plaster, Vector3(0, HEIGHT / 2, 0)).scale = Vector3(length, HEIGHT, WALL)
		Mat.part(pivot, BoxMesh.new(), panel, Vector3(0, PANEL / 2, WALL)).scale = Vector3(length, PANEL, 0.03)
		Mat.part(pivot, BoxMesh.new(), Mat.textured("dark_paneled_wood", 1.2, Color(0.6, 0.5, 0.45)),
			Vector3(0, PANEL, WALL + 0.02)).scale = Vector3(length, 0.05, 0.06)


## Industrial pendant with a warm spot cone that also lights the smoke in the air.
func _hanging_lamp(at: Vector3, energy: float, main := false) -> void:
	Mat.model(self, "hanging_industrial_lamp", at)
	var bulb := at + Vector3(0, -1.2, 0)
	var spot := SpotLight3D.new()
	spot.position = bulb
	spot.rotation.x = -PI / 2
	spot.light_color = LAMP_WARM
	spot.light_energy = energy
	spot.spot_range = 4.0
	spot.spot_angle = 55.0
	spot.spot_angle_attenuation = 0.8
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 1.5 if main else 0.8
	add_child(spot)
	var glow := OmniLight3D.new()
	glow.position = bulb + Vector3(0, 0.15, 0)
	glow.light_color = LAMP_WARM
	glow.light_energy = energy * 0.08
	glow.omni_range = 3.5
	add_child(glow)


## A round table with regulars around it, under its own lamp.
func _background_table(at: Vector3, yaw: float) -> void:
	var table := Node3D.new()
	table.position = at
	table.rotation.y = yaw
	add_child(table)
	Mat.model(table, "round_wooden_table_01", Vector3.ZERO, 0.0, 0.75)
	for i in 3:
		var angle := i * TAU / 3.0 + 0.3
		var dir := Vector3(sin(angle), 0, cos(angle))
		var seat_pos := dir * 0.85
		Mat.model(table, "plastic_monobloc_chair_01", seat_pos, angle + PI)
		if i < 2:
			Mat.prop(table, "tea_set", dir * 0.35 + Vector3(0, TEA_TABLE_TOP, 0), randf() * TAU)
			var regular := Buddy.new()
			regular.position = seat_pos + Vector3(0, Seat.SEAT_TOP - 0.03, 0) - dir * 0.04
			regular.rotation.y = angle
			table.add_child(regular)
			regular.setup(Appearance.random())
	_hanging_lamp(Vector3(at.x, HEIGHT, at.z), 3.0)


func _props() -> void:
	var back := -DEPTH / 2 + WALL / 2 + 0.03
	var left := -WIDTH / 2 + WALL / 2 + 0.03
	var right := WIDTH / 2 - WALL / 2 - 0.03

	# Shelves along the left wall with a few things on top.
	for z in [-0.6, 0.0]:
		var shelf := Mat.model(self, "painted_wooden_shelves", Vector3(left + 0.02, 0, z), PI / 2)
		shelf.scale = Vector3.ONE * 1.2
	Mat.model(self, "jug_01", Vector3(left + 0.22, 1.36, -0.6), PI / 2)
	Mat.prop(self, "semaver", Vector3(left + 0.24, 1.36, 0.0), PI / 2)
	for i in 3:
		Mat.prop(self, "tea_set", Vector3(left + 0.2, 1.36, 0.22 + i * 0.1), randf() * TAU)
	Mat.model(self, "mantel_clock_01", Vector3(left + 0.2, 1.36, 0.25), PI / 2, 1.1)

	# Old TV up on a bracket in the back-right corner, its screen glow flickering on the wall.
	var tv_at := Vector3(right - 0.45, 1.85, back + 0.45)
	Mat.part(self, BoxMesh.new(), Mat.textured("dark_paneled_wood", 1.0), tv_at - Vector3(0, 0.03, 0)).scale = Vector3(0.75, 0.05, 0.6)
	Mat.model(self, "Television_01", tv_at, -PI / 4)
	var screen := OmniLight3D.new()
	screen.position = tv_at + Vector3(-0.35, 0.25, 0.35)
	screen.light_color = Color(0.55, 0.7, 1.0)
	screen.light_energy = 0.9
	screen.omni_range = 2.5
	screen.set_script(preload("res://scripts/world/flicker.gd"))
	add_child(screen)

	# Pictures and warm sconces on the back wall.
	Mat.model(self, "hanging_picture_frame_01", Vector3(-1.0, 1.75, back), 0.0, 1.2)
	Mat.model(self, "hanging_picture_frame_01", Vector3(1.3, 1.7, back), 0.0, 0.9)
	for x in [-2.6, 2.4]:
		Mat.model(self, "industrial_wall_sconce", Vector3(x, 1.6, back))
		_sconce_light(Vector3(x, 1.75, back + 0.2))
	for z in [-2.2, 2.2]:
		Mat.model(self, "industrial_wall_sconce", Vector3(right, 1.6, z), -PI / 2)
		_sconce_light(Vector3(right - 0.2, 1.75, z))

	Mat.model(self, "potted_plant_01", Vector3(left + 0.45, 0, back + 0.45))
	_fan = Mat.model(self, "ceiling_fan", Vector3(2.4, HEIGHT, 1.8))


func _sconce_light(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = LAMP_WARM
	light.light_energy = 0.7
	light.omni_range = 2.2
	add_child(light)
