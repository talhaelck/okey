class_name MascotCharacter
extends Node3D
## Seated, medium-build 3D interpretations of the user's panda/rabbit/dinosaur reference.
## Geometry is authored here, faces -Z, and needs no imported model or texture.

const KINDS := ["panda", "bunny", "dinosaur"]
const CREAM := Color("fff1d6")
const INK := Color("29252a")
const WHITE := Color("fff9ee")

static var _materials: Dictionary = {}
static var _sphere_mesh: SphereMesh

var head := Node3D.new()
var torso := Node3D.new()
var _eyes: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _time := 0.0
var _blink_wait := 2.0
var _blink_time := -1.0
var _reaction := 0.0
var _look_yaw := 0.0
var _look_tween: Tween
var _species := ""


func build(kind: String, height: float) -> void:
	assert(kind in KINDS, "Unknown mascot: " + kind)
	name = kind.capitalize()
	_species = kind
	_time = randf() * TAU
	_blink_wait = randf_range(1.5, 4.5)
	var fur := Color("e5dccb")
	var hoodie := Color("647446")
	var shorts := Color("333b30")
	if kind == "bunny":
		fur = Color("e8dcd4")
		hoodie = Color("ba6b79")
		shorts = Color("814657")
	elif kind == "dinosaur":
		fur = Color("789150")
		hoodie = Color("c79638")
		shorts = Color("526a3b")
	add_child(torso)
	torso.name = "BreathingTorso"
	_build_body(kind, fur, hoodie, shorts)
	head.name = "Head"
	head.position = Vector3(0, 0.68, -0.025)
	torso.add_child(head)
	if kind == "dinosaur":
		_build_dinosaur(fur)
	else:
		_build_mammal(kind, fur)
	head.scale = Vector3(0.97, 0.95, 0.97)
	var natural_height := 1.21 if kind == "bunny" else 0.99
	scale = Vector3.ONE * height / natural_height


func _process(delta: float) -> void:
	_time += delta
	torso.position.y = sin(_time * 1.65) * 0.004
	torso.rotation.z = sin(_time * 0.75) * 0.008
	var shake := 0.0
	if _reaction > 0.0:
		_reaction = maxf(0.0, _reaction - delta)
		shake = sin((1.0 - _reaction) * 24.0) * 0.22 * minf(_reaction * 3.0, 1.0)
	head.rotation.y = _look_yaw + shake
	head.rotation.x = sin(_time * 1.1) * 0.018
	for i in _ears.size():
		_ears[i].rotation.x = sin(_time * 1.45 + i * 0.8) * 0.035
	_blink_wait -= delta
	if _blink_wait <= 0.0 and _blink_time < 0.0:
		_blink_time = 0.0
		_blink_wait = randf_range(2.5, 5.5)
	var openness := 1.0
	if _blink_time >= 0.0:
		_blink_time += delta
		openness = maxf(0.06, absf(_blink_time - 0.09) / 0.09)
		if _blink_time >= 0.18:
			_blink_time = -1.0
			openness = 1.0
	for eye in _eyes:
		eye.scale.y = openness


func turn_head(yaw: float, duration: float) -> void:
	if _look_tween:
		_look_tween.kill()
	_look_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_look_tween.tween_property(self, "_look_yaw", yaw, duration)


func react() -> void:
	_reaction = 1.0


func _build_body(kind: String, fur: Color, hoodie: Color, shorts: Color) -> void:
	# Seated hips, bent legs and feet hang in front of the chair.
	_ellipsoid(self, "Shorts", Vector3(0, 0.065, 0.015), Vector3(0.205, 0.12, 0.155), shorts)
	for side in [-1.0, 1.0]:
		_ellipsoid(self, "BentThigh", Vector3(side * 0.125, 0.025, -0.14), Vector3(0.105, 0.105, 0.19), shorts)
		_ellipsoid(self, "ShortsHem", Vector3(side * 0.125, -0.015, -0.255), Vector3(0.105, 0.075, 0.05), shorts.lightened(0.16))
		var leg_color := INK if kind == "panda" else fur
		_ellipsoid(self, "Shin", Vector3(side * 0.125, -0.14, -0.26), Vector3(0.072, 0.15, 0.075), leg_color)
		_ellipsoid(self, "Foot", Vector3(side * 0.125, -0.275, -0.30), Vector3(0.095, 0.06, 0.13), leg_color)
		for toe in 3:
			_ellipsoid(self, "Toe", Vector3(side * 0.125 + (toe - 1) * 0.038, -0.275, -0.405), Vector3(0.023, 0.025, 0.023), CREAM if kind == "dinosaur" else leg_color.lightened(0.08))
	# A soft, moderate belly entirely covered by the hoodie.
	_ellipsoid(torso, "Hoodie", Vector3(0, 0.30, 0), Vector3(0.235, 0.265, 0.18), hoodie)
	_ellipsoid(torso, "RibbedHem", Vector3(0, 0.115, -0.005), Vector3(0.222, 0.048, 0.174), hoodie.darkened(0.12))
	_ellipsoid(torso, "HoodBack", Vector3(0, 0.48, 0.075), Vector3(0.205, 0.105, 0.15), hoodie.darkened(0.15))
	_curve(torso, "HoodRim", [Vector3(-0.18, 0.48, -0.035), Vector3(-0.12, 0.44, -0.125), Vector3(0, 0.415, -0.16), Vector3(0.12, 0.44, -0.125), Vector3(0.18, 0.48, -0.035)], 0.021, hoodie.lightened(0.15))
	_ellipsoid(torso, "KangarooPocket", Vector3(0, 0.225, -0.157), Vector3(0.135, 0.07, 0.035), hoodie.lightened(0.06))
	for side in [-1.0, 1.0]:
		_curve(torso, "PocketSeam", [Vector3(side * 0.115, 0.27, -0.177), Vector3(side * 0.085, 0.23, -0.193), Vector3(side * 0.09, 0.19, -0.179)], 0.004, hoodie.darkened(0.16))
		_curve(torso, "Drawstring", [Vector3(side * 0.05, 0.439, -0.165), Vector3(side * 0.052, 0.38, -0.181), Vector3(side * 0.058, 0.34, -0.184)], 0.006, CREAM)
		_ellipsoid(torso, "DrawstringTip", Vector3(side * 0.058, 0.337, -0.184), Vector3(0.009, 0.015, 0.009), CREAM)
		# Sleeves slope down into relaxed forearms, with paws resting near the table.
		_segment(torso, "Sleeve", Vector3(side * 0.185, 0.425, 0), Vector3(side * 0.275, 0.28, -0.055), 0.086, hoodie)
		_segment(torso, "Forearm", Vector3(side * 0.275, 0.28, -0.055), Vector3(side * 0.27, 0.275, -0.235), 0.067, hoodie)
		_ellipsoid(torso, "Cuff", Vector3(side * 0.27, 0.275, -0.22), Vector3(0.073, 0.066, 0.035), hoodie.darkened(0.14))
		var paw_color := INK if kind == "panda" else fur
		_ellipsoid(torso, "Paw", Vector3(side * 0.27, 0.27, -0.285), Vector3(0.067, 0.054, 0.075), paw_color)
		_ellipsoid(torso, "Thumb", Vector3(side * 0.22, 0.275, -0.287), Vector3(0.027, 0.031, 0.038), paw_color)
		_curve(torso, "FabricFold", [Vector3(side*0.16,0.19,-0.127),Vector3(side*0.19,0.23,-0.11),Vector3(side*0.19,0.27,-0.106)], 0.003, hoodie.darkened(0.15))
		var stitch := SurfaceStyle.ring(torso, 0.061, 0.0018, Vector3(side*0.27,0.275,-0.241), SurfaceStyle.textured(hoodie.lightened(0.20), SurfaceStyle.Kind.FABRIC))
		stitch.rotation.x = PI/2.0
	# A small embroidered paw emblem on the chest.
	_ellipsoid(torso, "PawEmblem", Vector3(-0.115, 0.35, -0.155), Vector3(0.019, 0.015, 0.004), CREAM)
	for i in 3:
		_ellipsoid(torso, "EmblemToe", Vector3(-0.115 + (i - 1) * 0.017, 0.374 - absf(i - 1) * 0.005, -0.15), Vector3(0.007, 0.009, 0.004), CREAM)
	if kind == "bunny":
		_ellipsoid(self, "CottonTail", Vector3(0, 0.16, 0.205), Vector3(0.085, 0.08, 0.08), fur)
	elif kind == "dinosaur":
		_build_tail(fur)


func _build_mammal(kind: String, fur: Color) -> void:
	_ellipsoid(head, "HeadShape", Vector3.ZERO, Vector3(0.245, 0.235, 0.195), fur)
	_ellipsoid(head, "LowerCheeks", Vector3(0, -0.085, -0.02), Vector3(0.25, 0.13, 0.18), fur)
	for side in [-1.0, 1.0]:
		var ear := Node3D.new()
		head.add_child(ear)
		ear.position = Vector3(side * 0.175, 0.17, 0.015)
		if kind == "panda":
			_ellipsoid(ear, "RoundEar", Vector3.ZERO, Vector3(0.083, 0.095, 0.055), INK)
			_ellipsoid(ear, "InnerEar", Vector3(0, 0, -0.046), Vector3(0.047, 0.059, 0.012), Color("625148"))
			var patch := _ellipsoid(head, "EyePatch", Vector3(side * 0.096, 0.005, -0.18), Vector3(0.086, 0.101, 0.04), INK)
			patch.rotation.z = -side * 0.23
		else:
			ear.position = Vector3(side * 0.13, 0.17, 0.005)
			ear.rotation.z = -side * 0.22
			_ellipsoid(ear, "LongEar", Vector3(0, 0.14, 0), Vector3(0.069, 0.215, 0.048), fur)
			_ellipsoid(ear, "PinkInnerEar", Vector3(0, 0.15, -0.038), Vector3(0.043, 0.17, 0.017), Color("e99a9f"))
			_ears.append(ear)
		_eye(head, Vector3(side * 0.095, 0.012, -0.214 if kind == "panda" else -0.187), 0.048, INK if kind == "panda" else fur)
		_ellipsoid(head, "Blush", Vector3(side * 0.166, -0.065, -0.163), Vector3(0.038, 0.022, 0.009), Color("efb5a0") if kind == "panda" else Color("f2b0b3"))
		_curve(head, "Eyebrow", [Vector3(side * 0.067, 0.119, -0.171), Vector3(side * 0.091, 0.13, -0.167), Vector3(side * 0.12, 0.12, -0.157)], 0.009, INK if kind == "panda" else Color("996754"))
	# A small open smile sits behind the two muzzle lobes.
	_ellipsoid(head, "Smile", Vector3(0, -0.111, -0.184), Vector3(0.058, 0.053, 0.022), Color("643c32"))
	_ellipsoid(head, "Tongue", Vector3(0, -0.135, -0.204), Vector3(0.031, 0.016, 0.008), Color("ed9292"))
	for side in [-1.0, 1.0]:
		_ellipsoid(head, "Muzzle", Vector3(side * 0.034, -0.065, -0.197), Vector3(0.057, 0.04, 0.03), WHITE)
	_ellipsoid(head, "Nose", Vector3(0, -0.044, -0.23), Vector3(0.03, 0.02, 0.019), INK if kind == "panda" else Color("d97e8b"), 0.27)
	_ellipsoid(head, "NoseGlint", Vector3(-0.008, -0.037, -0.247), Vector3(0.008, 0.003, 0.002), Color("b9aaa0"))
	if kind == "bunny":
		_ellipsoid(head, "FrontTeeth", Vector3(0, -0.098, -0.212), Vector3(0.019, 0.019, 0.008), WHITE)
		for side in [-1.0, 1.0]:
			var tuft := _ellipsoid(head, "CheekFluff", Vector3(side * 0.225, -0.05, 0), Vector3(0.044, 0.035, 0.065), fur)
			tuft.rotation.z = side * 0.4
	for i in 3:
		var tuft := _ellipsoid(head, "HairTuft", Vector3((i - 1) * 0.035, 0.223 + (0.015 if i == 1 else 0.0), -0.015), Vector3(0.025, 0.05, 0.031), fur)
		tuft.rotation.z = (i - 1) * -0.25


func _build_dinosaur(fur: Color) -> void:
	_ellipsoid(head, "HeadShape", Vector3(0, 0.005, 0.015), Vector3(0.23, 0.24, 0.195), fur)
	_ellipsoid(head, "LowerJaw", Vector3(0, -0.112, -0.105), Vector3(0.193, 0.085, 0.15), Color("e9d39a"))
	_ellipsoid(head, "Smile", Vector3(0, -0.079, -0.202), Vector3(0.139, 0.045, 0.049), Color("604532"))
	_ellipsoid(head, "Tongue", Vector3(0, -0.099, -0.241), Vector3(0.041, 0.014, 0.01), Color("dc9290"))
	_ellipsoid(head, "RoundSnout", Vector3(0, -0.025, -0.17), Vector3(0.203, 0.09, 0.13), fur.lightened(0.08))
	for side in [-1.0, 1.0]:
		_eye(head, Vector3(side * 0.101, 0.086, -0.157), 0.048, fur)
		_ellipsoid(head, "Nostril", Vector3(side * 0.102, 0.003, -0.284), Vector3(0.012, 0.009, 0.005), fur.darkened(0.45))
		_ellipsoid(head, "Blush", Vector3(side * 0.183, -0.023, -0.176), Vector3(0.031, 0.023, 0.009), Color("d9ad6f"))
		_ellipsoid(head, "LittleTooth", Vector3(side * 0.079, -0.079, -0.249), Vector3(0.017, 0.018, 0.012), WHITE)
		_curve(head, "Eyebrow", [Vector3(side * 0.07, 0.181, -0.117), Vector3(side * 0.094, 0.19, -0.114), Vector3(side * 0.12, 0.18, -0.107)], 0.009, fur.darkened(0.43))
		for i in 3:
			_ellipsoid(head, "Freckle", Vector3(side * (0.17 + i * 0.013), 0.065 - i * 0.025, -0.115), Vector3(0.012, 0.014, 0.007), fur.darkened(0.13))
	for i in 4:
		var angle := i * 0.53
		var pos := Vector3(0, 0.219 * cos(angle), 0.025 + 0.182 * sin(angle))
		var spike := _ellipsoid(head, "OrangeCrest", pos, Vector3(0.044, 0.074 - i * 0.008, 0.041), Color("e8a044"))
		spike.rotation.x = angle


func _build_tail(fur: Color) -> void:
	var points: Array[Vector3] = [Vector3(0, 0.1, 0.12), Vector3(0.13, 0.08, 0.30), Vector3(0.28, 0.1, 0.36), Vector3(0.4, 0.17, 0.36), Vector3(0.46, 0.25, 0.33)]
	for i in points.size() - 1:
		var radius := 0.09 * (1.0 - float(i) / points.size())
		_segment(self, "Tail", points[i], points[i + 1], radius, fur)
		_ellipsoid(self, "TailSpike", points[i + 1] + Vector3(0, radius, 0), Vector3(0.025, 0.04, 0.027), Color("e8a044"))
	_ellipsoid(self, "TailTip", points[-1], Vector3(0.026, 0.04, 0.026), fur)


func _eye(parent: Node3D, pos: Vector3, radius: float, lid: Color) -> void:
	var eye := Node3D.new()
	eye.name = "BlinkingEye"
	eye.position = pos
	eye.scale.z = 0.65
	parent.add_child(eye)
	_eyes.append(eye)
	_ellipsoid(eye, "EyeRim", Vector3.ZERO, Vector3(radius, radius * 1.19, radius * 0.40), Color("302927"))
	_ellipsoid(eye, "EyeWhite", Vector3(0, 0, -radius * 0.17), Vector3(radius * 0.86, radius * 1.03, radius * 0.39), WHITE)
	_ellipsoid(eye, "Iris", Vector3(0, -radius * 0.015, -radius * 0.46), Vector3(radius * 0.68, radius * 0.87, radius * 0.25), Color("62472d"), 0.25)
	_ellipsoid(eye, "Pupil", Vector3(0, 0, -radius * 0.65), Vector3(radius * 0.49, radius * 0.70, radius * 0.15), Color("171c20"), 0.19)
	_ellipsoid(eye, "Catchlight", Vector3(-radius * 0.21, radius * 0.34, -radius * 0.79), Vector3(radius * 0.20, radius * 0.23, radius * 0.055), WHITE, 0.15)
	_ellipsoid(eye, "SmallCatchlight", Vector3(radius * 0.22, -radius * 0.30, -radius * 0.78), Vector3(radius * 0.085, radius * 0.095, radius * 0.04), WHITE)
	var eyelid: Array[Vector3] = []
	for i in 9:
		var angle := PI * (0.06 + float(i)/8.0*0.88)
		eyelid.append(Vector3(cos(angle)*radius*0.99, sin(angle)*radius*1.16, -radius*0.2))
	_curve(eye, "Eyelid", eyelid, radius*0.095, lid)


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), roughness]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic_specular = 0.2
		_materials[key] = mat
	return _materials[key]


static func _ellipsoid(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color, roughness := 0.83) -> MeshInstance3D:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 1.0
		_sphere_mesh.height = 2.0
		_sphere_mesh.radial_segments = 48
		_sphere_mesh.rings = 24
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = _sphere_mesh
	part.material_override = _appearance(parent, label, color, roughness)
	part.position = pos
	part.scale = size
	parent.add_child(part)
	return part


static func _segment(parent: Node3D, label: String, from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var direction := to - from
	var part := _ellipsoid(parent, label, (from + to) * 0.5, Vector3(radius, direction.length() * 0.5 + radius * 0.5, radius), color)
	part.quaternion = Quaternion(Vector3.UP, direction.normalized())


static func _curve(parent: Node3D, label: String, points: Array[Vector3], radius: float, color: Color) -> void:
	# A continuous swept tube replaces the old chain of visibly separate beads.
	var path: Array[Vector3] = []
	for i in points.size()-1:
		var p0 := points[maxi(0,i-1)]
		var p1 := points[i]
		var p2 := points[i+1]
		var p3 := points[mini(points.size()-1,i+2)]
		for sample in 4:
			var t := sample/4.0
			path.append(0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
	path.append(points[-1])
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	const SIDES := 8
	for i in path.size():
		var tangent := (path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
		var basis := Basis.looking_at(tangent, Vector3.RIGHT if absf(tangent.dot(Vector3.UP))>0.95 else Vector3.UP)
		for k in SIDES:
			var normal := basis.x*cos(TAU*k/SIDES)+basis.y*sin(TAU*k/SIDES)
			vertices.append(path[i]+normal*radius)
			normals.append(normal)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in path.size()-1:
		for k in SIDES:
			var a := i*SIDES+k
			var b := (i+1)*SIDES+k
			var c := (i+1)*SIDES+(k+1)%SIDES
			var d := i*SIDES+(k+1)%SIDES
			for triangle: Array in [[a,b,c],[a,c,d]]:
				if (vertices[triangle[1]]-vertices[triangle[0]]).cross(vertices[triangle[2]]-vertices[triangle[0]]).dot(normals[triangle[0]])>0:
					triangle.reverse()
				for index: int in triangle:
					st.set_normal(normals[index])
					st.add_vertex(vertices[index])
	SurfaceStyle.part(parent, st.commit(), _appearance(parent, label, color, 0.85))


static func _appearance(parent: Node3D, label: String, color: Color, roughness: float) -> Material:
	if label in ["Shorts","BentThigh","ShortsHem","Hoodie","RibbedHem","HoodBack","KangarooPocket","PocketSeam","Drawstring","DrawstringTip","Sleeve","Forearm","Cuff","PawEmblem","EmblemToe","HoodRim","FabricFold"]:
		return SurfaceStyle.textured(color, SurfaceStyle.Kind.FABRIC, 0.91)
	if label in ["HeadShape","LowerCheeks","RoundEar","LongEar","PinkInnerEar","InnerEar","EyePatch","Blush","Muzzle","CheekFluff","HairTuft","Paw","Thumb","Foot","Shin","Toe","CottonTail","RoundSnout","LowerJaw","Freckle","Tail","TailTip","OrangeCrest","TailSpike","Eyelid"]:
		var owner_node: Node = parent
		while owner_node != null and not owner_node is MascotCharacter:
			owner_node = owner_node.get_parent()
		var scaly: bool = owner_node != null and owner_node._species == "dinosaur"
		return SurfaceStyle.textured(color, SurfaceStyle.Kind.SCALES if scaly else SurfaceStyle.Kind.FUR, 0.73 if scaly else 0.92)
	return _material(color, roughness)
