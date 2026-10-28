class_name SurfaceStyle
## Shared tactile materials and reusable modeled details for the night coffeehouse.

enum Kind { WOOD, PLASTER, FABRIC, LEATHER, SCALES, FUR }
const TACTILE := preload("res://assets/shaders/tactile.gdshader")
static var _cache: Dictionary = {}


static func textured(color: Color, kind := Kind.WOOD, roughness := 0.68, vertical := false) -> Material:
	var key := "%s:%s:%.2f:%s" % [color.to_html(), kind, roughness, vertical]
	if kind == Kind.WOOD or kind == Kind.PLASTER:
		if not _cache.has(key):
			var scan := StandardMaterial3D.new()
			var folder := "wood_table_worn" if kind == Kind.WOOD else "worn_plaster_wall"
			var base := "res://assets/textures/%s/" % folder
			scan.albedo_texture = load(base + "diffuse.jpg")
			scan.normal_enabled = true
			scan.normal_texture = load(base + "nor_gl.jpg")
			scan.normal_scale = 0.16 if kind == Kind.WOOD else 0.3
			scan.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			scan.roughness_texture = load(base + "rough.jpg")
			scan.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			scan.roughness = roughness
			scan.metallic_specular = 0.32
			scan.uv1_triplanar = true
			scan.uv1_triplanar_sharpness = 8.0
			scan.uv1_scale = Vector3.ONE * (0.8 if kind == Kind.WOOD else 0.34)
			scan.uv1_offset = Vector3(color.r*7.3,color.g*5.0,color.b*3.0)
			if kind == Kind.WOOD:
				scan.albedo_color = Color(color.r*2.45,color.g*3.59,color.b*5.42)
			else:
				scan.albedo_color = Color(color.r*2.0,color.g*2.0,color.b*2.0)
			_cache[key] = scan
		return _cache[key]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = TACTILE
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("surface_kind", kind)
		mat.set_shader_parameter("base_roughness", roughness)
		mat.set_shader_parameter("vertical_grain", vertical)
		_cache[key] = mat
	return _cache[key]


static func metal(color := Color("9f7942"), roughness := 0.36) -> StandardMaterial3D:
	var key := "metal:%s:%.2f" % [color.to_html(), roughness]
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.72
		mat.roughness = roughness
		_cache[key] = mat
	return _cache[key]


static func part(parent: Node3D, shape: Mesh, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, radius := 0.01) -> MeshInstance3D:
	return part(parent, RoundedBox.build(size, radius, 3), material, pos)


static func rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var direction := to - from
	var mesh := part(parent, Toon.cylinder(radius, direction.length()), material, (from + to) * 0.5)
	mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return mesh


static func ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 40
	mesh.ring_segments = 10
	return part(parent, mesh, material, pos)


## Revolve a radius/height profile around Y. Used for lampshades, glasses and turned wood.
static func lathe(profile: Array[Vector2], segments := 40) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in profile.size() - 1:
		var slope := profile[j + 1] - profile[j]
		for i in segments:
			for corner: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var angle := TAU * corner.x / segments
				var radius := profile[corner.y].x
				st.set_normal(Vector3(cos(angle) * slope.y, -slope.x, sin(angle) * slope.y).normalized())
				st.set_uv(Vector2(float(corner.x) / segments, float(corner.y) / (profile.size() - 1)))
				st.add_vertex(Vector3(cos(angle) * radius, profile[corner.y].y, sin(angle) * radius))
	return st.commit()


static func lettering(parent: Node3D, text: String, pos: Vector3, size := 48, pixel := 0.003, color := Color("d7bb80")) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.position = pos
	parent.add_child(label)
	return label
