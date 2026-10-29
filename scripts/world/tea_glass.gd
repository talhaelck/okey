class_name TeaGlass
extends RigidBody3D
## The ince belli tea glass of a tea set (tools/blender/props.py) as a physics body: hands and tiles can
## knock it over. Tipping past SPILL_ANGLE spills the tea (splash, stain on the felt) and emits `spilled`,
## which the stealing rules will use as a noise everyone notices.

signal spilled(glass: TeaGlass)

const PROP := preload("res://assets/models/props/tea_set.glb")
const SPILL_ANGLE := 50.0
const GLASS_HEIGHT := 0.1
const SAUCER_FLOOR := 0.005 # the glass stands this high on the saucer

static var _stain: Texture2D

var _tea: Node3D
var _spilled := false


## Places a tea set with a physical glass at a point in `parent`'s space.
static func spawn(parent: Node3D, pos: Vector3, yaw: float) -> TeaGlass:
	var tea_set: Node3D = PROP.instantiate()
	tea_set.position = pos
	tea_set.rotation.y = yaw
	parent.add_child(tea_set)
	# The saucer is solid so the glass stands on it.
	Colliders.cylinder(Colliders.static_body(tea_set), 0.058, SAUCER_FLOOR, Transform3D(Basis(), Vector3(0, SAUCER_FLOOR * 0.5, 0)))
	var glass := TeaGlass.new()
	tea_set.add_child(glass)
	glass.position = Vector3(0, SAUCER_FLOOR, 0)
	for part in ["tea_glass", "tea"]:
		var node := tea_set.find_child(part, true, false) as Node3D
		if node:
			node.reparent(glass, true)
	glass._tea = glass.find_child("tea", true, false) as Node3D
	return glass


func _init() -> void:
	mass = 0.15 # glass plus tea
	collision_layer = Colliders.PROPS
	collision_mask = Colliders.STATIC | Colliders.TILES | Colliders.PROPS | Colliders.HANDS
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.035, 0)
	can_sleep = true
	var grip := PhysicsMaterial.new()
	grip.friction = 0.9 # tips over when knocked rather than sliding away
	grip.bounce = 0.05
	physics_material_override = grip
	Colliders.cylinder(self, 0.024, GLASS_HEIGHT, Transform3D(Basis(), Vector3(0, GLASS_HEIGHT * 0.5, 0)))


func _physics_process(_delta: float) -> void:
	if not _spilled and global_basis.y.dot(Vector3.UP) < cos(deg_to_rad(SPILL_ANGLE)):
		_spill()


func _spill() -> void:
	_spilled = true
	if _tea:
		_tea.visible = false
	var mouth := global_transform * Vector3(0, GLASS_HEIGHT, 0)
	_splash(mouth)
	_stain_at(Vector3(mouth.x, Table.TOP, mouth.z))
	spilled.emit(self)


func _scene() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_tree().root


func _splash(at: Vector3) -> void:
	var drops := GPUParticles3D.new()
	drops.one_shot = true
	drops.amount = 48
	drops.lifetime = 0.7
	drops.explosiveness = 0.9
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0.6, 0)
	process.spread = 70.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.9
	process.gravity = Vector3(0, -9.8, 0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	drops.process_material = process
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.0025
	drop_mesh.height = 0.005
	drop_mesh.material = Mat.material(Color(0.35, 0.06, 0.01), 0.05)
	drops.draw_pass_1 = drop_mesh
	_scene().add_child(drops)
	drops.global_position = at
	drops.emitting = true
	get_tree().create_timer(2.0).timeout.connect(drops.queue_free)


func _stain_at(at: Vector3) -> void:
	var decal := Decal.new()
	decal.texture_albedo = _stain_texture()
	decal.size = Vector3(0.16, 0.06, 0.12)
	decal.modulate = Color(0.45, 0.16, 0.05, 0.85)
	_scene().add_child(decal)
	decal.global_position = at
	decal.rotation.y = randf() * TAU
	decal.scale = Vector3.ONE * 0.2
	decal.create_tween().tween_property(decal, "scale", Vector3.ONE, 0.6).set_ease(Tween.EASE_OUT)


# A soft, irregular puddle drawn once: radial falloff with a wobbly edge.
static func _stain_texture() -> Texture2D:
	if _stain == null:
		var size := 128
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var p := Vector2(x, y) / size * 2.0 - Vector2.ONE
				var wobble := 0.82 + 0.12 * sin(p.angle() * 5.0) + 0.06 * sin(p.angle() * 11.0 + 1.3)
				var a := clampf((wobble - p.length()) * 6.0, 0.0, 1.0)
				# Darker ring at the edge where tea dries.
				var ring := clampf(1.0 - absf(wobble - p.length() - 0.05) * 12.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a * (0.55 + 0.45 * ring)))
		_stain = ImageTexture.create_from_image(image)
	return _stain
