extends Node3D
## SON EL: an original late-night neighborhood coffeehouse, built from modeled details.

const WIDTH := 7.0
const DEPTH := 6.5
const HEIGHT := 3.25
var _wood := SurfaceStyle.textured(Color("453024"))
var _dark_wood := SurfaceStyle.textured(Color("271e18"))
var _brass := SurfaceStyle.metal()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 24107
	_shell()
	_bar()
	_windows()
	_wall_details()
	_lighting()
	var finish := CanvasLayer.new()
	finish.layer = -5
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://assets/shaders/film_finish.gdshader")
	overlay.material = grade
	finish.add_child(overlay)
	add_child(finish)


func _shell() -> void:
	for row in 16:
		for column in 4:
			var color := Color("634734").darkened(_rng.randf_range(0.0, 0.24))
			var x := -WIDTH / 2.0 + (column + 0.5) * WIDTH / 4.0
			var z := -DEPTH / 2.0 + (row + 0.5) * DEPTH / 16.0
			SurfaceStyle.box(self, Vector3(WIDTH/4.0-0.006,0.06,DEPTH/16.0-0.006), Vector3(x,-0.035,z), SurfaceStyle.textured(color), 0.003)
	var plaster := SurfaceStyle.textured(Color("514037"), SurfaceStyle.Kind.PLASTER, 0.96)
	for side in [-1, 1]:
		SurfaceStyle.box(self, Vector3(WIDTH,HEIGHT,0.12), Vector3(0,HEIGHT/2.0,side*DEPTH/2.0), plaster)
		SurfaceStyle.box(self, Vector3(0.12,HEIGHT,DEPTH), Vector3(side*WIDTH/2.0,HEIGHT/2.0,0), plaster)
	SurfaceStyle.box(self, Vector3(WIDTH,0.12,DEPTH), Vector3(0,HEIGHT,0), SurfaceStyle.textured(Color("2e2923"), SurfaceStyle.Kind.PLASTER))
	for side in 4:
		var wall := Node3D.new()
		wall.rotation.y = side * PI / 2.0
		add_child(wall)
		var length := WIDTH if side % 2 == 0 else DEPTH
		var depth := DEPTH/2.0 if side % 2 == 0 else WIDTH/2.0
		SurfaceStyle.box(wall, Vector3(length,0.88,0.06), Vector3(0,0.44,-depth+0.07), _dark_wood)
		for i in 14:
			var x := -length/2.0 + (i+0.5)*length/14.0
			SurfaceStyle.box(wall, Vector3(length/14.0-0.035,0.67,0.035), Vector3(x,0.44,-depth+0.11), _wood)
		for y in [0.08,0.87,2.82]:
			SurfaceStyle.box(wall, Vector3(length,0.055,0.09), Vector3(0,y,-depth+0.1), _wood)
		SurfaceStyle.box(wall, Vector3(length,0.012,0.015), Vector3(0,0.91,-depth+0.16), _brass, 0.003)
	for z in [-2.8,-1.4,0.0,1.4,2.8]:
		SurfaceStyle.box(self, Vector3(WIDTH,0.20,0.18), Vector3(0,3.11,z), _dark_wood)
	for x in [-2.6,2.6]:
		SurfaceStyle.box(self, Vector3(0.13,0.13,DEPTH), Vector3(x,3.00,0), _wood)
	SurfaceStyle.rod(self, Vector3(-3.3,2.98,-1.2), Vector3(3.3,2.98,-1.2), 0.023, SurfaceStyle.metal(Color("3b3429")))
	for x in [-2.0,0.0,2.0]:
		var joint := SurfaceStyle.ring(self, 0.028, 0.007, Vector3(x,2.98,-1.2), _brass)
		joint.rotation.z = PI/2.0


func _bar() -> void:
	SurfaceStyle.box(self, Vector3(5.2,0.79,0.56), Vector3(0,0.395,-2.63), _dark_wood, 0.025)
	for i in 10:
		SurfaceStyle.box(self, Vector3(0.48,0.62,0.035), Vector3((i-4.5)*0.5,0.41,-2.33), _wood)
	SurfaceStyle.box(self, Vector3(5.45,0.09,0.75), Vector3(0,0.84,-2.58), SurfaceStyle.textured(Color("67462d"), SurfaceStyle.Kind.WOOD, 0.38), 0.025)
	SurfaceStyle.rod(self, Vector3(-2.4,0.21,-2.18), Vector3(2.4,0.21,-2.18), 0.022, _brass)
	for side in [-1,1]:
		var x: float = side*1.94
		SurfaceStyle.box(self, Vector3(1.1,1.35,0.09), Vector3(x,1.78,-3.12), _dark_wood)
		for y in [1.18,1.62,2.06,2.48]:
			SurfaceStyle.box(self, Vector3(1.20,0.045,0.24), Vector3(x,y,-3.02), _wood)
			if y < 2.4:
				for i in 5:
					CafeProps.bottle(self, Vector3(x+(i-2)*0.19,y+0.027,-3.01), [Color("263d31"),Color("684627"),Color("344842")][i%3], _rng.randf_range(0.20,0.33))
		for dx in [-0.57,0.57]:
			SurfaceStyle.box(self, Vector3(0.06,1.38,0.25), Vector3(x+dx,1.8,-3.01), _wood)
	SurfaceStyle.box(self, Vector3(2.12,0.94,0.065), Vector3(0,2.05,-3.12), _brass, 0.018)
	SurfaceStyle.box(self, Vector3(2.06,0.88,0.075), Vector3(0,2.05,-3.10), SurfaceStyle.textured(Color("173830"), SurfaceStyle.Kind.LEATHER), 0.015)
	var title := SurfaceStyle.lettering(self, "SON EL", Vector3(0,2.19,-3.05), 96, 0.0035)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	font.font_weight = 700
	title.font = font
	SurfaceStyle.lettering(self, "G E C E   K A H V E H A N E S İ", Vector3(0,1.88,-3.05), 27, 0.002)
	SurfaceStyle.lettering(self, "•  ÇAY DEMLİ, OYUN UZUN  •", Vector3(0,1.73,-3.05), 19, 0.002, Color("a4926a"))
	CafeProps.samovar(self, Vector3(1.6,0.89,-2.54))
	for x in [-1.55,-1.1,0.95]:
		CafeProps.tea(self, Vector3(x,0.89,-2.40))
	for x in [-1.9,1.9]:
		CafeProps.stool(self, Vector3(x,0,-1.8))
	CafeProps.hanging_lamp(self, Vector3(-1.8,2.12,-2.55), 1.0, 0.17)
	CafeProps.hanging_lamp(self, Vector3(1.8,2.12,-2.55), 1.0, 0.17)


func _windows() -> void:
	for side in [-1,1]:
		var window := Node3D.new()
		window.position = Vector3(side*3.42,1.82,0.1)
		window.rotation.y = -side*PI/2.0
		add_child(window)
		SurfaceStyle.box(window, Vector3(2.1,1.64,0.13), Vector3.ZERO, _dark_wood)
		var rain := ShaderMaterial.new()
		rain.shader = preload("res://assets/shaders/rain_window.gdshader")
		SurfaceStyle.box(window, Vector3(1.94,1.47,0.015), Vector3(0,0,0.08), rain, 0.001)
		for x in [-0.97,0.0,0.97]:
			SurfaceStyle.box(window, Vector3(0.055,1.53,0.09), Vector3(x,0,0.13), _wood)
		for y in [-0.75,0.0,0.75]:
			SurfaceStyle.box(window, Vector3(2.0,0.05,0.09), Vector3(0,y,0.13), _wood)
		SurfaceStyle.box(window, Vector3(2.25,0.07,0.28), Vector3(0,-0.84,0.15), _wood)
		for edge in [-1,1]:
			for fold in 5:
				var cloth := SurfaceStyle.part(window, Toon.cylinder(0.065,1.80), SurfaceStyle.textured(Color("4c2525"), SurfaceStyle.Kind.FABRIC, 0.95), Vector3(edge*(0.95+fold*0.07),-0.03,0.19))
				cloth.scale.z = 0.65
		SurfaceStyle.rod(window, Vector3(-1.42,0.92,0.15), Vector3(1.42,0.92,0.15), 0.019, _brass)


func _wall_details() -> void:
	var menu := Node3D.new()
	menu.position = Vector3(3.38,1.77,-1.75)
	menu.rotation.y = -PI/2.0
	add_child(menu)
	SurfaceStyle.box(menu, Vector3(0.8,1.08,0.06), Vector3.ZERO, _wood)
	SurfaceStyle.box(menu, Vector3(0.73,1.01,0.065), Vector3(0,0,0.01), SurfaceStyle.textured(Color("1d2925"), SurfaceStyle.Kind.PLASTER))
	SurfaceStyle.lettering(menu, "ÇAY OCAĞI", Vector3(0,0.34,0.05), 36, 0.0021, Color("dbd2b8"))
	SurfaceStyle.lettering(menu, "Taze çay\nTürk kahvesi\nAdaçayı\n\nMuhabbet ikramımız", Vector3(0,-0.07,0.05), 23, 0.0021, Color("bfbca6"))
	var clock_root := Node3D.new()
	clock_root.position = Vector3(-2.9,2.32,-3.13)
	add_child(clock_root)
	var face := SurfaceStyle.part(clock_root, Toon.cylinder(0.26,0.045), _brass)
	face.rotation.x = PI/2.0
	face = SurfaceStyle.part(clock_root, Toon.cylinder(0.235,0.05), Toon.material(Color("c3b691")))
	face.rotation.x = PI/2.0
	for i in 12:
		var angle := TAU*i/12.0
		SurfaceStyle.rod(clock_root, Vector3(sin(angle)*0.195,cos(angle)*0.195,0.03), Vector3(sin(angle)*0.216,cos(angle)*0.216,0.03), 0.004, _dark_wood)
	SurfaceStyle.rod(clock_root, Vector3(0,0,0.04), Vector3(-0.08,0.10,0.04), 0.007, _dark_wood)
	SurfaceStyle.rod(clock_root, Vector3(0,0,0.045), Vector3(0.15,0.06,0.045), 0.004, _dark_wood)
	for i in 3:
		var frame := Node3D.new()
		frame.position = Vector3(-3.39,1.85,-1.7+i*0.52)
		frame.rotation.y = PI/2.0
		add_child(frame)
		SurfaceStyle.box(frame, Vector3(0.35,0.48,0.045), Vector3.ZERO, _brass)
		SurfaceStyle.box(frame, Vector3(0.31,0.44,0.05), Vector3(0,0,0.008), Toon.material(Color("a99973")))
		SurfaceStyle.lettering(frame, ["♠","♦","♣"][i], Vector3(0,0.01,0.037), 80, 0.003, Color("385044"))
	CafeProps.stool(self, Vector3(-2.8,0,1.8))
	SurfaceStyle.box(self, Vector3(0.65,0.06,0.65), Vector3(-2.75,0.78,2.5), _wood, 0.025)
	SurfaceStyle.rod(self, Vector3(-2.75,0,2.5), Vector3(-2.75,0.76,2.5), 0.07, _dark_wood)
	CafeProps.tea(self, Vector3(-2.7,0.82,2.5))


func _lighting() -> void:
	CafeProps.hanging_lamp(self, Vector3(0,2.0,-0.65), 1.22, 0.34)
	_spot(Vector3(0,1.95,-0.65), Vector3(0,0.7,0), Color("ffd4a0"), 2.1, 63.0, 5.0)
	_omni(Vector3(0,1.65,1.9), Color("eac69e"), 0.65, 4.0)
	_omni(Vector3(-2.7,1.9,0.1), Color("78a6b0"), 0.75, 4.2)
	_omni(Vector3(2.8,1.8,0.1), Color("668fa2"), 0.4, 3.8)
	for x in [-1.8,1.8]:
		_spot(Vector3(x,2.08,-2.55), Vector3(x,0.8,-2.55), Color("ffc17d"), 1.2, 58.0, 3.0)
	_omni(Vector3(0,2.2,-2.7), Color("e4b777"), 0.5, 2.4)
	for x in [-2.9,2.9]:
		SurfaceStyle.box(self, Vector3(0.12,0.28,0.08), Vector3(x,1.9,-3.05), _brass)
		SurfaceStyle.part(self, Toon.sphere(0.063), Toon.glow(Color("ffc881"), 2.0), Vector3(x,1.96,-2.96))
		_omni(Vector3(x,1.97,-2.87), Color("ffbb74"), 0.55, 1.4)


func _omni(pos: Vector3, color: Color, energy: float, distance: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	light.light_size = 0.25
	add_child(light)


func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, angle: float, distance: float) -> void:
	var light := SpotLight3D.new()
	add_child(light)
	light.position = pos
	light.look_at(target, Vector3.FORWARD if absf(pos.x-target.x)+absf(pos.z-target.z)<0.01 else Vector3.UP)
	light.light_color = color
	light.light_energy = energy
	light.spot_angle = angle
	light.spot_range = distance
	light.spot_attenuation = 0.6
	light.shadow_enabled = true
	light.light_size = 0.12
	light.shadow_blur = 2.0
