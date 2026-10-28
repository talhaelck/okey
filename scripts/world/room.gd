extends Node3D
## Cozy placeholder room: floor, walls, rug, window, hanging lamp and lights.

const SIZE := 5.0
const HEIGHT := 2.8
const WALL := Color(0.24, 0.3, 0.55)


func _ready() -> void:
	Toon.part(self, RoundedBox.build(Vector3(SIZE, 0.1, SIZE), 0.01), Color(0.55, 0.37, 0.25), Vector3(0, -0.05, 0))
	Toon.part(self, Toon.cylinder(1.35, 0.01), Color(0.72, 0.22, 0.27), Vector3(0, 0.005, 0))
	Toon.part(self, RoundedBox.build(Vector3(SIZE, 0.1, SIZE), 0.01), Color(0.32, 0.36, 0.58), Vector3(0, HEIGHT, 0))
	for side in 4:
		var pivot := Node3D.new()
		pivot.rotation.y = side * PI * 0.5
		add_child(pivot)
		Toon.part(pivot, RoundedBox.build(Vector3(SIZE, HEIGHT, 0.1), 0.01), WALL, Vector3(0, HEIGHT * 0.5, -SIZE * 0.5))
	_build_window(Vector3(0.9, 1.5, -SIZE * 0.5 + 0.05))
	_build_lamp()


func _build_window(pos: Vector3) -> void:
	Toon.part(self, RoundedBox.build(Vector3(1.3, 0.85, 0.08), 0.06), Color(0.45, 0.25, 0.6), pos)
	var glass := MeshInstance3D.new()
	glass.mesh = RoundedBox.build(Vector3(1.1, 0.65, 0.04), 0.05)
	glass.material_override = Toon.glow(Color(0.35, 0.85, 0.65), 0.8)
	glass.position = pos + Vector3(0, 0, 0.03)
	add_child(glass)


func _build_lamp() -> void:
	var shade_y := 1.95
	Toon.part(self, Toon.cylinder(0.008, HEIGHT - shade_y), Color(0.15, 0.15, 0.15),
		Vector3(0, (HEIGHT + shade_y) * 0.5, 0))
	Toon.part(self, Toon.cylinder(0.3, 0.2, 0.07), Color(0.98, 0.72, 0.2), Vector3(0, shade_y, 0))
	var bulb := MeshInstance3D.new()
	bulb.mesh = Toon.sphere(0.07)
	bulb.material_override = Toon.glow(Color(1.0, 0.9, 0.7), 3.0)
	bulb.position = Vector3(0, shade_y - 0.1, 0)
	add_child(bulb)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, shade_y - 0.2, 0)
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.light_energy = 2.4
	lamp.omni_range = 5.0
	lamp.shadow_enabled = true
	add_child(lamp)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-55, 35, 0)
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.light_energy = 0.35
	add_child(fill)
