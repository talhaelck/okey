class_name RoundedBox
## Box meshes with rounded edges (BoxMesh only has sharp corners).

# [normal, tangent_u, tangent_v] for each of the six faces.
const _FACES := [
	[Vector3.RIGHT, Vector3.BACK, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
]


static func build(size: Vector3, radius: float, segments: int = 3) -> ArrayMesh:
	var half := size * 0.5
	var r := clampf(radius, 0.0001, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in _FACES:
		var n: Vector3 = face[0]
		var tu: Vector3 = face[1]
		var tv: Vector3 = face[2]
		var us := _samples(tu.abs().dot(half), r, segments)
		var vs := _samples(tv.abs().dot(half), r, segments)
		var depth := n.abs().dot(half)
		for i in us.size() - 1:
			for j in vs.size() - 1:
				var a := n * depth + tu * us[i] + tv * vs[j]
				var b := n * depth + tu * us[i + 1] + tv * vs[j]
				var c := n * depth + tu * us[i + 1] + tv * vs[j + 1]
				var d := n * depth + tu * us[i] + tv * vs[j + 1]
				_add_triangle(st, a, b, c, n, inner, r)
				_add_triangle(st, a, c, d, n, inner, r)
	return st.commit()


# Grid coordinates along one face axis, packed densely near the edges so the arcs stay smooth.
static func _samples(extent: float, r: float, segments: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in segments + 1:
		out.append(-(extent - r) - r * cos(PI * 0.5 * i / segments))
	for i in range(segments, -1, -1):
		out.append((extent - r) + r * cos(PI * 0.5 * i / segments))
	return out


# Pushes each flat-face vertex out onto the rounded shell around the inner box.
static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, inner: Vector3, r: float) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0: # Godot treats clockwise triangles as front faces
		var swap := b
		b = c
		c = swap
	for p: Vector3 in [a, b, c]:
		var core := p.clamp(-inner, inner)
		var dir := (p - core).normalized()
		st.set_normal(dir)
		st.add_vertex(core + dir * r)
