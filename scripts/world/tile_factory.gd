class_name TileFactory
## A shared Blender resin body with physically shaded, raised pad-print glyphs.
## Face +Z and dimensions are identical to the existing picking and rack contract.

const SIZE := Vector3(0.048,0.070,0.019)
const FAKE_OKEY := 4
const BODY := Color("e5dcc2")
const INK := [Color("b42c2d"),Color("1b1d21"),Color("174c9c"),Color("b17b10"),Color("286243")]
static var _mesh: ArrayMesh
static var _font: SystemFont
static var _glyphs := {}
static var _inks: Array[StandardMaterial3D] = []
static var _dot: CylinderMesh

static func _prepare() -> void:
	if _mesh != null:
		return
	var scene: Node3D = load("res://assets/models/table_details/okey_tile.glb").instantiate()
	var body := scene.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var placement := body.transform
	var parent := body.get_parent() as Node3D
	while parent != null:
		placement = parent.transform * placement
		parent = parent.get_parent() as Node3D
	_mesh = ArrayMesh.new()
	for i in body.mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(body.mesh,i,placement)
		st.set_material(body.mesh.surface_get_material(i))
		st.commit(_mesh)
	scene.free()
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Arial","Segoe UI","Segoe UI Symbol"])
	_font.font_weight = 700
	for color in INK:
		var ink := StandardMaterial3D.new()
		ink.albedo_color = color
		ink.roughness = 0.56
		ink.metallic_specular = 0.22
		_inks.append(ink)
	_dot = CylinderMesh.new()
	_dot.top_radius = 0.0017
	_dot.bottom_radius = 0.0017
	_dot.height = 0.00006
	_dot.radial_segments = 24

static func create(value: Vector2i) -> Tile:
	_prepare()
	var tile := Tile.new()
	tile.value = value
	tile.add_to_group("tiles")
	tile.mesh = _mesh
	var text := "★" if value.x == FAKE_OKEY else str(value.y)
	if not _glyphs.has(text):
		var glyph := TextMesh.new()
		glyph.font = _font
		glyph.font_size = 128
		glyph.pixel_size = 0.00028 if value.x != FAKE_OKEY else 0.00034
		glyph.text = text
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.depth = 0.00006
		_glyphs[text] = glyph
	var stamp := MeshInstance3D.new()
	stamp.mesh = _glyphs[text]
	stamp.material_override = _inks[value.x]
	stamp.position = Vector3(0,0.007 if value.x != FAKE_OKEY else 0,SIZE.z*0.5+0.000035)
	stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(stamp)
	if value.x != FAKE_OKEY:
		var dot := MeshInstance3D.new()
		dot.mesh = _dot
		dot.material_override = _inks[value.x]
		dot.position = Vector3(0,-0.020,SIZE.z*0.5+0.000035)
		dot.rotation.x = PI/2
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.add_child(dot)
	return tile
