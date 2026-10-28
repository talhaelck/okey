class_name TileFactory
## Builds okey tiles. A tile is Vector2i(color, number); color 4 is the fake okey.
## The printed face points along the tile's local +Z, upright along +Y.

const SIZE := Vector3(0.048, 0.07, 0.019)
const FAKE_OKEY := 4
const INK := [
	Color("a92e2b"), # red
	Color("16191b"), # black
	Color("214c8a"), # blue
	Color("8e590d"), # golden yellow, dark enough to read on ivory
	Color("286243"), # fake okey
]
const BODY := Color("e5dcc2")

static var _mesh: ArrayMesh
static var _font: SystemFont


static func create(tile: Vector2i) -> Tile:
	if _mesh == null:
		_mesh = RoundedBox.build(SIZE, 0.005, 2)
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial Black", "Arial"])
		_font.font_weight = 800
	var mi := Tile.new()
	mi.value = tile
	mi.add_to_group("tiles")
	mi.mesh = _mesh
	mi.material_override = Toon.material(BODY, 0.32)
	var ink: Color = INK[tile.x]
	if tile.x == FAKE_OKEY:
		mi.add_child(_print("★", ink, 72, Vector3(0, 0.0, 0)))
	else:
		mi.add_child(_print(str(tile.y), ink, 64, Vector3(0, 0.007, 0)))
		mi.add_child(_print("●", ink, 22, Vector3(0, -0.021, 0)))
	return mi


static func _print(text: String, ink: Color, font_size: int, offset: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = font_size
	label.pixel_size = 0.0005
	label.modulate = ink
	label.outline_size = 0
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.double_sided = false
	label.position = offset + Vector3(0, 0, SIZE.z * 0.5 + 0.0004)
	return label
