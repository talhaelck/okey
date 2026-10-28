class_name Toon
## Shared physically shaded base materials and mesh helpers (legacy name retained).

static var _materials := {}


static func material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var key: String = "%s/%s" % [color.to_html(), roughness]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		m.metallic_specular = 0.3
		_materials[key] = m
	return _materials[key]


static func glow(color: Color, energy := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func part(parent: Node3D, mesh: Mesh, color: Color, pos := Vector3.ZERO, roughness := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, roughness)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


static func cylinder(radius: float, height: float, top_radius := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	return m
