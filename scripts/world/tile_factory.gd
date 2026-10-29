class_name TileFactory
## Shared Blender resin tile (3.6 x 5.2 x 1.4 cm) matching real Turkish Okey tile proportions
## with bold upper numeral and lower circular dimple with colored heart mark.

const SIZE := Vector3(0.036, 0.052, 0.014)
const FAKE_OKEY := 4
const BODY := Color("f6efdb")
const INK := [Color("d82222"), Color("1b1d21"), Color("0e72d8"), Color("e67e12"), Color("1f7a42")]
const COLOR_NAMES := ["Kırmızı", "Siyah", "Mavi", "Sarı", "Sahte Okey"]
static var _mesh: ArrayMesh
static var _body_mat: StandardMaterial3D
static var _dimple_mat: StandardMaterial3D
static var _dimple_mesh: TorusMesh
static var _font: SystemFont
static var _glyphs := {}
static var _heart_glyph: TextMesh
static var _inks: Array[StandardMaterial3D] = []


static func describe(value: Vector2i) -> String:
	if value.x == FAKE_OKEY:
		return "Sahte Okey ★"
	var c := clampi(value.x, 0, 3)
	return "%s %d" % [COLOR_NAMES[c], value.y]


static func okey_from_indicator(indicator: Vector2i) -> Vector2i:
	if indicator.x == FAKE_OKEY:
		return Vector2i(0, 1)
	return Vector2i(indicator.x, (indicator.y % 13) + 1)


static func _prepare() -> void:
	if _mesh != null:
		return
	
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color("f6efdc") # Realistic ivory melamine tile body
	_body_mat.roughness = 0.20
	_body_mat.metallic_specular = 0.38
	
	_mesh = RoundedBox.build(SIZE, 0.0022, 3)
	_mesh.surface_set_material(0, _body_mat)

	_dimple_mat = StandardMaterial3D.new()
	_dimple_mat.albedo_color = Color("ded4bd") # Indented dimple ring
	_dimple_mat.roughness = 0.45
	_dimple_mesh = TorusMesh.new()
	_dimple_mesh.inner_radius = 0.0052
	_dimple_mesh.outer_radius = 0.0065
	_dimple_mesh.rings = 24
	_dimple_mesh.ring_segments = 12

	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Segoe UI", "Arial"])
	_font.font_weight = 800
	for color in INK:
		var ink := StandardMaterial3D.new()
		ink.albedo_color = color
		ink.roughness = 0.38
		ink.metallic_specular = 0.25
		_inks.append(ink)
	_heart_glyph = TextMesh.new()
	_heart_glyph.font = _font
	_heart_glyph.font_size = 64
	_heart_glyph.pixel_size = 0.00016
	_heart_glyph.text = "♥"
	_heart_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heart_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heart_glyph.depth = 0.00008


static func create(value: Vector2i) -> Tile:
	_prepare()
	var tile := Tile.new()
	tile.value = value
	tile.add_to_group("tiles")
	tile.mesh = _mesh
	tile.material_override = _body_mat
	var text := "★" if value.x == FAKE_OKEY else str(value.y)
	if not _glyphs.has(text):
		var glyph := TextMesh.new()
		glyph.font = _font
		glyph.font_size = 118
		glyph.pixel_size = 0.00021 if value.x != FAKE_OKEY else 0.00026
		glyph.text = text
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.depth = 0.00008
		_glyphs[text] = glyph
	var stamp := MeshInstance3D.new()
	stamp.mesh = _glyphs[text]
	stamp.material_override = _inks[clampi(value.x, 0, 4)]
	stamp.position = Vector3(0, 0.0065 if value.x != FAKE_OKEY else 0.0, SIZE.z * 0.5 + 0.00012)
	stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(stamp)
	if value.x != FAKE_OKEY:
		var dimple := MeshInstance3D.new()
		dimple.mesh = _dimple_mesh
		dimple.material_override = _dimple_mat
		dimple.rotation.x = PI * 0.5
		dimple.position = Vector3(0, -0.013, SIZE.z * 0.5 + 0.00008)
		dimple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.add_child(dimple)

		var heart := MeshInstance3D.new()
		heart.mesh = _heart_glyph
		heart.material_override = _inks[clampi(value.x, 0, 3)]
		heart.position = Vector3(0, -0.013, SIZE.z * 0.5 + 0.00012)
		heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.add_child(heart)

	# Luminous X-Ray Silhouette on the back face for Kabadayı Sunglasses & Magnifier
	var xray_mat := StandardMaterial3D.new()
	xray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xray_mat.no_depth_test = true
	xray_mat.render_priority = 10
	var base_ink: Color = INK[clampi(value.x, 0, 3)]
	xray_mat.albedo_color = Color(base_ink.r, base_ink.g, base_ink.b, 0.96)

	var xray_stamp := MeshInstance3D.new()
	xray_stamp.name = "XRayStamp"
	xray_stamp.mesh = _glyphs[text]
	xray_stamp.material_override = xray_mat
	xray_stamp.rotation.y = PI
	xray_stamp.position = Vector3(0, 0.0065 if value.x != FAKE_OKEY else 0.0, -SIZE.z * 0.5 - 0.00012)
	xray_stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	xray_stamp.visible = false
	tile.add_child(xray_stamp)

	if value.x != FAKE_OKEY:
		var xray_heart := MeshInstance3D.new()
		xray_heart.name = "XRayHeart"
		xray_heart.mesh = _heart_glyph
		xray_heart.material_override = xray_mat
		xray_heart.rotation.y = PI
		xray_heart.position = Vector3(0, -0.013, -SIZE.z * 0.5 - 0.00012)
		xray_heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		xray_heart.visible = false
		tile.add_child(xray_heart)

	return tile
