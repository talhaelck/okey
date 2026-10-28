class_name CafeProps
## Original modeled cafe props; all measurements are metres.


static func tea(parent: Node3D, pos: Vector3, steam := false) -> void:
	var root := Node3D.new()
	root.name = "TeaGlass"
	root.position = pos
	parent.add_child(root)
	var ceramic := Toon.material(Color("ddd0ae"), 0.3)
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(0, 0), Vector2(0.047, 0), Vector2(0.055, 0.006), Vector2(0.054, 0.009), Vector2(0.028, 0.007), Vector2(0, 0.006)]), ceramic)
	SurfaceStyle.ring(root, 0.046, 0.0012, Vector3(0, 0.009, 0), Toon.material(Color("7d3225")))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.72, 0.68, 0.51, 0.24)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.16
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(0.021, 0.009), Vector2(0.025, 0.02), Vector2(0.019, 0.045), Vector2(0.024, 0.079), Vector2(0.027, 0.09)]), glass)
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(0.019, 0.012), Vector2(0.022, 0.025), Vector2(0.017, 0.046), Vector2(0.022, 0.071), Vector2(0, 0.071)]), Toon.material(Color("59200b"), 0.18))
	SurfaceStyle.ring(root, 0.0265, 0.0012, Vector3(0, 0.09, 0), SurfaceStyle.metal(Color("a9916e"), 0.2))
	SurfaceStyle.rod(root, Vector3(0.031, 0.014, -0.024), Vector3(0.043, 0.014, 0.029), 0.0015, SurfaceStyle.metal(Color("a9a99e")))
	SurfaceStyle.part(root, Toon.sphere(0.007), SurfaceStyle.metal(Color("a9a99e")), Vector3(0.032, 0.014, -0.024)).scale = Vector3(0.65, 0.2, 1)
	if steam:
		_steam(root, Vector3(0, 0.095, 0), 10)


static func bottle(parent: Node3D, pos: Vector3, color: Color, height := 0.25) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * height / 0.25
	parent.add_child(root)
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(0,0), Vector2(0.036,0), Vector2(0.04,0.014), Vector2(0.04,0.15), Vector2(0.018,0.18), Vector2(0.014,0.235), Vector2(0.017,0.24), Vector2(0.017,0.25), Vector2(0,0.25)]), Toon.material(color, 0.22))
	SurfaceStyle.part(root, Toon.cylinder(0.0405, 0.07), SurfaceStyle.textured(Color("c2ae80"), SurfaceStyle.Kind.FABRIC), Vector3(0, 0.1, 0))
	SurfaceStyle.part(root, Toon.cylinder(0.018, 0.012), SurfaceStyle.metal(), Vector3(0, 0.25, 0))


static func samovar(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.name = "CopperSamovar"
	parent.add_child(root)
	var copper := SurfaceStyle.metal(Color("a66e3e"), 0.3)
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(0,0),Vector2(0.14,0),Vector2(0.14,0.04),Vector2(0.08,0.07),Vector2(0.09,0.12),Vector2(0.16,0.17),Vector2(0.18,0.31),Vector2(0.15,0.43),Vector2(0.12,0.46),Vector2(0.17,0.47),Vector2(0.16,0.49),Vector2(0.07,0.52),Vector2(0.025,0.55),Vector2(0,0.55)]), copper)
	for y in [0.16, 0.43, 0.48]:
		SurfaceStyle.ring(root, 0.16, 0.006, Vector3(0, y, 0), copper)
	for side in [-1, 1]:
		var handle := SurfaceStyle.ring(root, 0.063, 0.012, Vector3(side * 0.183, 0.34, 0), SurfaceStyle.metal(Color("382f29")))
		handle.rotation.z = PI * 0.5
	SurfaceStyle.rod(root, Vector3(0,0.20,0.14), Vector3(0,0.20,0.25), 0.017, copper)
	SurfaceStyle.rod(root, Vector3(0,0.20,0.25), Vector3(0,0.15,0.25), 0.017, copper)
	SurfaceStyle.rod(root, Vector3(-0.035,0.24,0.22), Vector3(0.035,0.24,0.22), 0.01, copper)
	_steam(root, Vector3(0, 0.55, 0), 16)


static func stool(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	SurfaceStyle.part(root, Toon.cylinder(0.20, 0.075), SurfaceStyle.textured(Color("402b26"), SurfaceStyle.Kind.LEATHER), Vector3(0, 0.62, 0))
	for x in [-1, 1]:
		for z in [-1, 1]:
			SurfaceStyle.rod(root, Vector3(x*0.15,0,z*0.15), Vector3(x*0.115,0.6,z*0.115), 0.022, SurfaceStyle.metal(Color("35332e")))
	SurfaceStyle.ring(root, 0.18, 0.012, Vector3(0, 0.23, 0), SurfaceStyle.metal())


static func hanging_lamp(parent: Node3D, pos: Vector3, cable_length: float, radius := 0.28) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var black := SurfaceStyle.metal(Color("242723"), 0.5)
	SurfaceStyle.rod(root, Vector3(0, 0.14, 0), Vector3(0, cable_length, 0), 0.008, black)
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(radius,0), Vector2(radius*0.99,0.014), Vector2(radius*0.78,0.055), Vector2(radius*0.38,0.14), Vector2(radius*0.19,0.16), Vector2(0,0.16)]), Toon.material(Color("24473d"), 0.31))
	SurfaceStyle.ring(root, radius, 0.007, Vector3.ZERO, SurfaceStyle.metal())
	SurfaceStyle.part(root, SurfaceStyle.lathe([Vector2(0.025,0.145),Vector2(radius*0.19,0.14),Vector2(radius*0.38,0.12),Vector2(radius*0.78,0.042),Vector2(radius*0.96,0.004)]), Toon.material(Color("c4b58f"), 0.42))
	SurfaceStyle.part(root, Toon.cylinder(0.023,0.055), black, Vector3(0,0.096,0))
	var bulb := SurfaceStyle.part(root, Toon.sphere(0.035), Toon.glow(Color("ffd5a2"), 3.0), Vector3(0,0.035,0))
	bulb.scale = Vector3(0.8,1.35,0.8)
	var interior := OmniLight3D.new()
	interior.position = Vector3(0,0.025,0)
	interior.light_color = Color("ffd5a2")
	interior.light_energy = 0.12
	interior.omni_range = 0.55
	root.add_child(interior)


static func _steam(parent: Node3D, pos: Vector3, count: int) -> void:
	var particles := GPUParticles3D.new()
	particles.position = pos
	particles.amount = count
	particles.lifetime = 2.5
	particles.preprocess = 1.0
	particles.visibility_aabb = AABB(Vector3(-0.3, -0.1, -0.3), Vector3(0.6, 0.8, 0.6))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12.0
	process.gravity = Vector3(0.015, 0.01, 0)
	process.initial_velocity_min = 0.035
	process.initial_velocity_max = 0.08
	process.scale_min = 0.35
	process.scale_max = 0.9
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	gradient.colors = PackedColorArray([Color(0.7,0.7,0.65,0.0),Color(0.7,0.7,0.65,0.025),Color(0.7,0.7,0.65,0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var puff := QuadMesh.new()
	puff.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var soft := GradientTexture2D.new()
	soft.width = 32
	soft.height = 32
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1, 0.5)
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = fade
	material.albedo_texture = soft
	puff.material = material
	particles.draw_pass_1 = puff
	parent.add_child(particles)
