class_name Colliders
## Physics layers and helpers for the static collision of the table, racks and room (Jolt Physics).

const STATIC := 1 # table, racks, floor
const TILES := 2
const PROPS := 4 # tea glasses and other things that can be knocked over
const HANDS := 8 # the local player's arms


## A StaticBody3D on the STATIC layer, added under `parent`.
static func static_body(parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = STATIC
	body.collision_mask = 0
	parent.add_child(body)
	return body


static func box(body: CollisionObject3D, size: Vector3, xf := Transform3D()) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.transform = xf
	body.add_child(shape)
	return shape


static func cylinder(body: CollisionObject3D, radius: float, height: float, xf := Transform3D()) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.transform = xf
	body.add_child(shape)
	return shape


## Capsule lying along local Z (CapsuleShape3D stands along Y), centred at `center`.
static func capsule_z(body: CollisionObject3D, radius: float, length: float, center: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = length
	shape.shape = capsule
	shape.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center)
	body.add_child(shape)
	return shape
