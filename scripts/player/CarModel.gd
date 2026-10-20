class_name CarModel
extends RefCounted
## Costruisce un'automobile stilizzata gialla e nera usando esclusivamente
## mesh primitive semplici (BoxMesh, CylinderMesh) e materiali condivisi.
## Restituisce i perni delle ruote (anteriori nei primi 2 indici, posteriori negli ultimi 2).
##
## Il modello è ancora un blockout: il livello di evoluzione non cambia la
## forma dell'auto ma solo i materiali (carrozzeria + barra luminosa sul tetto),
## così la meccanica dei cancelli è già giocabile e verificabile senza modelli
## definitivi. Quando arriveranno i modelli veri basterà sostituire i mesh
## mantenendo le stesse chiamate a `apply_evolution_level()`.

const WHEEL_RADIUS: float = 0.33
const WHEEL_WIDTH: float = 0.26
const WHEEL_BASE_X: float = 0.73
const WHEEL_BASE_Z: float = 1.04

## Chiavi con cui il modello espone i nodi da aggiornare al cambio di livello.
const META_BODY_MESHES: StringName = &"evolution_body_meshes"
const META_PIPS: StringName = &"evolution_pips"
const META_LEVEL: StringName = &"evolution_level"

const PIP_SIZE := Vector3(0.13, 0.06, 0.24)
const PIP_SPACING: float = 0.22


static func build(car: Node3D) -> Array[Node3D]:
	_add_chassis_and_body(car)
	_add_cabin_and_stripes(car)
	_add_spoiler_and_mirrors(car)
	_add_lights(car)
	_add_evolution_pips(car)
	var wheels := _add_wheels(car)
	_collect_evolution_meshes(car)
	return wheels


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


## Barra di cinque spie sul tetto: mostra a colpo d'occhio il livello raggiunto
## (spente = livello 0, tutte accese = livello massimo).
static func _add_evolution_pips(car: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "EvolutionPips"
	holder.position = Vector3(0.0, 1.14, 0.52)
	car.add_child(holder)

	var pips: Array[Node3D] = []
	var pip_count := GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL
	var center_offset := (pip_count - 1) * 0.5
	for index in pip_count:
		var pip := _box(
			PIP_SIZE,
			Vector3((index - center_offset) * PIP_SPACING, 0.0, 0.0),
			MaterialFactory.pip_off(),
		)
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(pip)
		pips.append(pip)
	car.set_meta(META_PIPS, pips)


## Individua i mesh con la verniciatura base gialla: sono le parti di
## carrozzeria che cambiano colore con l'evoluzione.
static func _collect_evolution_meshes(car: Node3D) -> void:
	var base_paint := MaterialFactory.car_paint(GameConfig.COLOR_CAR_BODY)
	var body_meshes: Array[Node] = []
	_collect_meshes_with_material(car, base_paint, body_meshes)
	car.set_meta(META_BODY_MESHES, body_meshes)


static func _collect_meshes_with_material(
	node: Node,
	material: Material,
	found: Array[Node],
) -> void:
	for child in node.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.material_override == material:
			found.append(mesh_instance)
		_collect_meshes_with_material(child, material, found)


## Applica il colore del livello alla carrozzeria e accende le spie.
## È l'unico punto che traduce `evolution_level` in aspetto dell'auto.
static func apply_evolution_level(car: Node3D, level: int) -> void:
	var clamped := clampi(
		level,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)
	var body_color: Color = GameConfig.EVOLUTION_COLORS[clamped]
	var paint := MaterialFactory.car_paint(body_color)
	var lit_material := MaterialFactory.emissive(
		"pip_%s" % body_color.to_html(false),
		body_color,
		1.8,
	)

	var body_meshes: Array = car.get_meta(META_BODY_MESHES, [])
	for mesh in body_meshes:
		var mesh_instance := mesh as MeshInstance3D
		if is_instance_valid(mesh_instance):
			mesh_instance.material_override = paint

	var pips: Array = car.get_meta(META_PIPS, [])
	for index in pips.size():
		var pip := pips[index] as MeshInstance3D
		if not is_instance_valid(pip):
			continue
		# Primo livello = indice 1: le spie accese sono quelle sotto il livello.
		pip.material_override = lit_material if index < clamped else MaterialFactory.pip_off()
	car.set_meta(META_LEVEL, clamped)


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
