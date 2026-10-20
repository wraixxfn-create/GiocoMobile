class_name TrackSegment
extends Node3D
## Un singolo tratto di pista, costruito interamente con primitive 3D:
## strada, linee di corsia, bordi, prato e decorazioni low-poly.
## TODO(fase 2): supporto per cancelli, ostacoli, monete, traguardo.

var segment_index: int = 0


func _ready() -> void:
	_build()


## Ricostruisce il segmento con un nuovo indice (usato al riciclo).
func rebuild(new_index: int) -> void:
	segment_index = new_index
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	# Seme deterministico: le decorazioni sono stabili per ogni segmento.
	rng.seed = segment_index * 1013904223
	_add_ground()
	_add_road()
	_add_lane_lines()
	_add_decorations(rng)


func _add_ground() -> void:
	# Prato alternato a due tonalità per dare senso di velocità.
	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(16.0, 0.08, GameConfig.SEGMENT_LENGTH)
	for side in [-1.0, 1.0]:
		var grass := MeshInstance3D.new()
		grass.mesh = grass_mesh
		grass.position = Vector3(
			side * (GameConfig.TRACK_WIDTH / 2.0 + 8.0),
			-0.06,
			0.0,
		)
		grass.material_override = MaterialFactory.grass(segment_index % 2 == 0)
		add_child(grass)


func _add_road() -> void:
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(GameConfig.TRACK_WIDTH, 0.1, GameConfig.SEGMENT_LENGTH)
	var road := MeshInstance3D.new()
	road.mesh = road_mesh
	road.position.y = -0.05
	road.material_override = MaterialFactory.road()
	add_child(road)

	# Bordi stradali gialli.
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(0.18, 0.04, GameConfig.SEGMENT_LENGTH)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		edge.mesh = edge_mesh
		edge.position = Vector3(side * (GameConfig.TRACK_WIDTH / 2.0 - 0.35), 0.01, 0.0)
		edge.material_override = MaterialFactory.edge()
		add_child(edge)


func _add_lane_lines() -> void:
	# Linee tratteggiate tra le tre corsie.
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.14, 0.04, 2.2)
	var divider_positions := [
		-GameConfig.TRACK_WIDTH / 6.0,
		GameConfig.TRACK_WIDTH / 6.0,
	]
	for divider_x in divider_positions:
		for dash_index in 8:
			var dash := MeshInstance3D.new()
			dash.mesh = dash_mesh
			dash.position = Vector3(
				divider_x,
				0.01,
				-GameConfig.SEGMENT_LENGTH / 2.0 + 2.5 + dash_index * 5.0,
			)
			dash.material_override = MaterialFactory.lane()
			add_child(dash)


func _add_decorations(rng: RandomNumberGenerator) -> void:
	var tree_count := rng.randi_range(3, 6)
	for _i in tree_count:
		var side := 1.0 if rng.randf() > 0.5 else -1.0
		var tree := _make_tree(rng)
		tree.position = Vector3(
			side * (GameConfig.TRACK_WIDTH / 2.0 + rng.randf_range(2.0, 9.0)),
			0.0,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH / 2.0, GameConfig.SEGMENT_LENGTH / 2.0),
		)
		add_child(tree)

	var rock_count := rng.randi_range(0, 2)
	for _i in rock_count:
		var side := 1.0 if rng.randf() > 0.5 else -1.0
		var rock := _make_rock(rng)
		rock.position = Vector3(
			side * (GameConfig.TRACK_WIDTH / 2.0 + rng.randf_range(1.5, 8.0)),
			0.0,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH / 2.0, GameConfig.SEGMENT_LENGTH / 2.0),
		)
		add_child(rock)


func _make_tree(rng: RandomNumberGenerator) -> Node3D:
	var tree := Node3D.new()

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 0.9
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.45
	trunk.material_override = MaterialFactory.trunk()
	tree.add_child(trunk)

	var foliage := MeshInstance3D.new()
	if rng.randf() > 0.5:
		var cone := ConeMesh.new()
		cone.radius = 0.85
		cone.height = 1.9
		foliage.mesh = cone
		foliage.position.y = 1.75
	else:
		var ball := IcosahedronMesh.new()
		ball.radius = 0.85
		foliage.mesh = ball
		foliage.position.y = 1.55
	foliage.material_override = MaterialFactory.foliage(
		rng.randi_range(0, GameConfig.FOLIAGE_COLORS.size() - 1)
	)
	tree.add_child(foliage)

	var scale_value := rng.randf_range(0.8, 1.6)
	tree.scale = Vector3(scale_value, scale_value, scale_value)
	return tree


func _make_rock(rng: RandomNumberGenerator) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	var rock_mesh := IcosahedronMesh.new()
	rock_mesh.radius = 0.5
	rock.mesh = rock_mesh
	rock.material_override = MaterialFactory.rock()
	rock.scale = Vector3(
		rng.randf_range(0.6, 1.4),
		rng.randf_range(0.4, 0.8),
		rng.randf_range(0.6, 1.4),
	)
	return rock
