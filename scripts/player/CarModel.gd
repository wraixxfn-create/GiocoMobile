class_name CarModel
extends RefCounted
## Costruisce l'auto low-poly a partire da primitive 3D
## (nessun asset esterno). Restituisce i perni delle ruote per la rotazione.

const WHEEL_RADIUS := 0.36
const WHEEL_WIDTH := 0.3
const WHEEL_BASE_X := 0.92
const WHEEL_BASE_Z := 1.15


static func build(car: Node3D) -> Array[Node3D]:
	_add_body(car)
	_add_cabin(car)
	_add_spoiler(car)
	_add_lights(car)
	return _add_wheels(car)


static func _add_body(car: Node3D) -> void:
	car.add_child(_box(
		Vector3(1.8, 0.55, 3.6),
		Vector3(0.0, 0.62, 0.0),
		MaterialFactory.car_paint(GameConfig.COLOR_CAR_BODY),
	))


static func _add_cabin(car: Node3D) -> void:
	car.add_child(_box(
		Vector3(1.5, 0.5, 1.7),
		Vector3(0.0, 1.12, 0.25),
		MaterialFactory.car_glass(),
	))


static func _add_spoiler(car: Node3D) -> void:
	car.add_child(_box(
		Vector3(1.7, 0.08, 0.4),
		Vector3(0.0, 1.18, 1.72),
		MaterialFactory.car_accent(),
	))
	car.add_child(_box(
		Vector3(0.12, 0.35, 0.12),
		Vector3(-0.6, 0.98, 1.72),
		MaterialFactory.car_accent(),
	))
	car.add_child(_box(
		Vector3(0.12, 0.35, 0.12),
		Vector3(0.6, 0.98, 1.72),
		MaterialFactory.car_accent(),
	))


static func _add_lights(car: Node3D) -> void:
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(0.35, 0.15, 0.1)
	for side in [-1.0, 1.0]:
		var headlight := MeshInstance3D.new()
		headlight.mesh = light_mesh
		headlight.position = Vector3(side * 0.55, 0.62, -1.82)
		headlight.material_override = MaterialFactory.headlight()
		car.add_child(headlight)

		var taillight := MeshInstance3D.new()
		taillight.mesh = light_mesh
		taillight.position = Vector3(side * 0.55, 0.62, 1.82)
		taillight.material_override = MaterialFactory.taillight()
		car.add_child(taillight)


static func _add_wheels(car: Node3D) -> Array[Node3D]:
	var wheels: Array[Node3D] = []
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = WHEEL_RADIUS
	wheel_mesh.bottom_radius = WHEEL_RADIUS
	wheel_mesh.height = WHEEL_WIDTH

	var positions: Array[Vector3] = [
		Vector3(-WHEEL_BASE_X, WHEEL_RADIUS, -WHEEL_BASE_Z),
		Vector3(WHEEL_BASE_X, WHEEL_RADIUS, -WHEEL_BASE_Z),
		Vector3(-WHEEL_BASE_X, WHEEL_RADIUS, WHEEL_BASE_Z),
		Vector3(WHEEL_BASE_X, WHEEL_RADIUS, WHEEL_BASE_Z),
	]
	for position in positions:
		var pivot := Node3D.new()
		pivot.position = position
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI / 2.0
		wheel.material_override = MaterialFactory.tire()
		pivot.add_child(wheel)
		car.add_child(pivot)
		wheels.append(pivot)
	return wheels


static func _box(size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.position = position
	box.material_override = material
	return box
