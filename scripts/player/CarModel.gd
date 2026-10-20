class_name CarModel
extends RefCounted
## Costruisce un'automobile stilizzata gialla e nera usando esclusivamente
## mesh primitive semplici (BoxMesh, CylinderMesh) e materiali condivisi.
## Restituisce i perni delle ruote (anteriori nei primi 2 indici, posteriori negli ultimi 2).

const WHEEL_RADIUS: float = 0.33
const WHEEL_WIDTH: float = 0.26
const WHEEL_BASE_X: float = 0.73
const WHEEL_BASE_Z: float = 1.04


static func build(car: Node3D) -> Array[Node3D]:
	_add_chassis_and_body(car)
	_add_cabin_and_stripes(car)
	_add_spoiler_and_mirrors(car)
	_add_lights(car)
	return _add_wheels(car)


static func _add_chassis_and_body(car: Node3D) -> void:
	var body_yellow := MaterialFactory.car_paint(GameConfig.COLOR_CAR_BODY)
	var trim_black := MaterialFactory.car_black()

	# Pianale inferiore, minigonne laterali, splitter anteriore ed estrattore posteriore neri.
	car.add_child(_box(Vector3(1.56, 0.14, 3.28), Vector3(0.0, 0.25, 0.0), trim_black))
	car.add_child(_box(Vector3(1.48, 0.06, 0.22), Vector3(0.0, 0.20, -1.62), trim_black))
	car.add_child(_box(Vector3(1.44, 0.10, 0.18), Vector3(0.0, 0.24, 1.62), trim_black))

	# Scocca principale gialla ben visibile e proporzionata.
	car.add_child(_box(Vector3(1.50, 0.36, 3.12), Vector3(0.0, 0.50, 0.0), body_yellow))

	# Cofano anteriore leggermente inclinato in avanti e coda posteriore sagomata.
	var hood := _box(Vector3(1.38, 0.10, 0.98), Vector3(0.0, 0.68, -0.96), body_yellow)
	hood.rotation.x = deg_to_rad(-4.5)
	car.add_child(hood)

	car.add_child(_box(Vector3(1.42, 0.10, 0.80), Vector3(0.0, 0.70, 1.06), body_yellow))

	# Fasce nere anteriore e posteriore per accentuare il contrasto giallo/nero.
	car.add_child(_box(Vector3(1.38, 0.18, 0.08), Vector3(0.0, 0.56, 1.56), trim_black))
	car.add_child(_box(Vector3(1.16, 0.14, 0.08), Vector3(0.0, 0.44, -1.56), trim_black))


static func _add_cabin_and_stripes(car: Node3D) -> void:
	var body_yellow := MaterialFactory.car_paint(GameConfig.COLOR_CAR_BODY)
	var trim_black := MaterialFactory.car_black()
	var cabin_glass := MaterialFactory.car_glass()

	# Abitacolo nero fumé raccordato al tetto giallo con parabrezza e lunotto inclinati.
	car.add_child(_box(Vector3(1.20, 0.35, 1.06), Vector3(0.0, 0.855, 0.05), cabin_glass))

	var windshield := _box(Vector3(1.18, 0.10, 0.44), Vector3(0.0, 0.845, -0.60), cabin_glass)
	windshield.rotation.x = deg_to_rad(-42.0)
	car.add_child(windshield)

	var rear_window := _box(Vector3(1.18, 0.10, 0.48), Vector3(0.0, 0.85, 0.74), cabin_glass)
	rear_window.rotation.x = deg_to_rad(36.0)
	car.add_child(rear_window)

	# Tetto giallo a filo sopra l'abitacolo con striscia racing centrale nera continua.
	car.add_child(_box(Vector3(1.20, 0.055, 1.12), Vector3(0.0, 1.055, 0.05), body_yellow))
	car.add_child(_box(Vector3(0.36, 0.03, 1.14), Vector3(0.0, 1.095, 0.05), trim_black))

	var hood_stripe := _box(Vector3(0.36, 0.025, 0.96), Vector3(0.0, 0.74, -0.96), trim_black)
	hood_stripe.rotation.x = deg_to_rad(-4.5)
	car.add_child(hood_stripe)

	car.add_child(_box(Vector3(0.36, 0.025, 0.78), Vector3(0.0, 0.76, 1.06), trim_black))


static func _add_spoiler_and_mirrors(car: Node3D) -> void:
	var body_yellow := MaterialFactory.car_paint(GameConfig.COLOR_CAR_BODY)
	var trim_black := MaterialFactory.car_black()

	# Alettone posteriore nero con paratie laterali gialle.
	car.add_child(_box(Vector3(1.48, 0.065, 0.32), Vector3(0.0, 1.00, 1.42), trim_black))
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		car.add_child(_box(
			Vector3(0.09, 0.24, 0.12),
			Vector3(side * 0.46, 0.87, 1.40),
			trim_black,
		))
		car.add_child(_box(
			Vector3(0.055, 0.18, 0.36),
			Vector3(side * 0.75, 1.01, 1.42),
			body_yellow,
		))
		# Specchietti retrovisori neri.
		car.add_child(_box(
			Vector3(0.16, 0.09, 0.12),
			Vector3(side * 0.72, 0.80, -0.44),
			trim_black,
		))


static func _add_lights(car: Node3D) -> void:
	var front_light_mesh := BoxMesh.new()
	front_light_mesh.size = Vector3(0.30, 0.11, 0.08)

	var rear_light_mesh := BoxMesh.new()
	rear_light_mesh.size = Vector3(0.34, 0.11, 0.08)

	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var headlight := MeshInstance3D.new()
		headlight.mesh = front_light_mesh
		headlight.position = Vector3(side * 0.50, 0.54, -1.58)
		headlight.material_override = MaterialFactory.headlight()
		headlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.add_child(headlight)

		var taillight := MeshInstance3D.new()
		taillight.mesh = rear_light_mesh
		taillight.position = Vector3(side * 0.48, 0.57, 1.59)
		taillight.material_override = MaterialFactory.taillight()
		taillight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		car.add_child(taillight)


static func _add_wheels(car: Node3D) -> Array[Node3D]:
	var wheels: Array[Node3D] = []

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = WHEEL_RADIUS
	wheel_mesh.bottom_radius = WHEEL_RADIUS
	wheel_mesh.height = WHEEL_WIDTH
	wheel_mesh.radial_segments = 14
	wheel_mesh.rings = 1

	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = WHEEL_RADIUS * 0.58
	rim_mesh.bottom_radius = WHEEL_RADIUS * 0.58
	rim_mesh.height = WHEEL_WIDTH + 0.02
	rim_mesh.radial_segments = 12
	rim_mesh.rings = 1

	var spoke_mesh := BoxMesh.new()
	spoke_mesh.size = Vector3(WHEEL_WIDTH + 0.03, WHEEL_RADIUS * 0.85, 0.06)

	var wheel_offsets: Array[Vector3] = [
		Vector3(-WHEEL_BASE_X, WHEEL_RADIUS, -WHEEL_BASE_Z),
		Vector3(WHEEL_BASE_X, WHEEL_RADIUS, -WHEEL_BASE_Z),
		Vector3(-WHEEL_BASE_X, WHEEL_RADIUS, WHEEL_BASE_Z),
		Vector3(WHEEL_BASE_X, WHEEL_RADIUS, WHEEL_BASE_Z),
	]
	for offset in wheel_offsets:
		var pivot := Node3D.new()
		pivot.position = offset

		var tire := MeshInstance3D.new()
		tire.mesh = wheel_mesh
		tire.rotation.z = PI / 2.0
		tire.material_override = MaterialFactory.tire()
		pivot.add_child(tire)

		var rim := MeshInstance3D.new()
		rim.mesh = rim_mesh
		rim.rotation.z = PI / 2.0
		rim.material_override = MaterialFactory.car_rim()
		pivot.add_child(rim)

		var spoke := MeshInstance3D.new()
		spoke.mesh = spoke_mesh
		spoke.material_override = MaterialFactory.car_black()
		pivot.add_child(spoke)

		car.add_child(pivot)
		wheels.append(pivot)
	return wheels


static func _box(size: Vector3, box_pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.position = box_pos
	box.material_override = material
	return box
