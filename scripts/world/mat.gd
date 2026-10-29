class_name Mat
## Shared materials (plain PBR colours and Poly Haven texture sets) and helpers for spawning simple mesh parts.

static var _materials := {}


static func material(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var key: String = "%s/%s" % [color.to_html(), roughness]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		_materials[key] = m
	return _materials[key]


## Poly Haven texture set from assets/polyhaven/<id>, projected triplanar so procedural meshes need no UVs.
## tile = metres covered by one repeat; albedo false keeps only the surface detail and uses tint as the colour.
static func textured(id: String, tile := 1.0, tint := Color.WHITE, albedo := true, world := true) -> ORMMaterial3D:
	var key := "%s/%s/%s/%s/%s" % [id, tile, tint.to_html(), albedo, world]
	if not _materials.has(key):
		var base := "res://assets/polyhaven/%s/%s_" % [id, id]
		var m := ORMMaterial3D.new()
		m.albedo_color = tint
		if albedo:
			m.albedo_texture = load(base + "diff.jpg")
		m.normal_enabled = true
		m.normal_texture = load(base + "nor_gl.jpg")
		m.orm_texture = load(base + "arm.jpg")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = world
		m.uv1_scale = Vector3.ONE / tile
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[key] = m
	return _materials[key]


static func glow(color: Color, energy := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func part(parent: Node3D, mesh: Mesh, look: Variant, pos := Vector3.ZERO, roughness := 0.7) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = look if look is Material else material(look, roughness)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Instances a Poly Haven model from assets/polyhaven/<id>/<id>.gltf.
static func model(parent: Node3D, id: String, pos := Vector3.ZERO, yaw := 0.0, scale := 1.0) -> Node3D:
	var node: Node3D = load("res://assets/polyhaven/%s/%s.gltf" % [id, id]).instantiate()
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale
	parent.add_child(node)
	return node


## Instances one of our own Blender props from assets/models/props/<id>.glb (tools/blender/props.py).
static func prop(parent: Node3D, id: String, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var node: Node3D = load("res://assets/models/props/%s.glb" % id).instantiate()
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)
	return node


## Instances a Meshy-generated model from assets/models/meshy/<id>.glb (tools/blender/meshy_import.py).
static func meshy(parent: Node3D, id: String, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	var node: Node3D = load("res://assets/models/meshy/%s.glb" % id).instantiate()
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)
	return node


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
