class_name TrackSegment
extends Node3D
## Un singolo tratto di pista costruito interamente con mesh primitive condivise:
## asfalto grigio largo, corsie, bordi laterali rialzati, terreno verde esteso
## fino all'orizzonte e decorazioni low-poly leggere.
## Ostacoli, cancelli e monete NON vivono qui: sono gestiti dai rispettivi
## manager in coordinate mondo, così non si spostano mai sotto l'auto.

## Larghezza della fascia chiara tra cordolo e prato.
const VERGE_WIDTH: float = 1.05
## Istanze decorative per segmento (MultiMesh: costo di disegno trascurabile).
const TUFT_INSTANCES: int = 64
const FLOWER_INSTANCES: int = 26

static var _grass_mesh: BoxMesh
static var _road_mesh: BoxMesh
static var _curb_base_mesh: BoxMesh
static var _curb_accent_mesh: BoxMesh
static var _shoulder_line_mesh: BoxMesh
static var _dash_mesh: BoxMesh
static var _verge_mesh: BoxMesh
static var _tuft_mesh: BoxMesh
static var _flower_mesh: SphereMesh
static var _post_mesh: BoxMesh
static var _post_cap_mesh: BoxMesh
static var _trunk_mesh: CylinderMesh
static var _cone_lower_mesh: CylinderMesh
static var _cone_upper_mesh: CylinderMesh
static var _crown_mesh: SphereMesh
static var _bush_mesh: SphereMesh
static var _rock_mesh: SphereMesh
static var _hill_mesh: SphereMesh

var segment_index: int = 0


func _ready() -> void:
	_ensure_meshes()
	_build()


## Ricostruisce il segmento con un nuovo indice (usato al riciclo).
func rebuild(new_index: int) -> void:
	segment_index = new_index
	for child in get_children():
		child.queue_free()
	_ensure_meshes()
	_build()


static func _ensure_meshes() -> void:
	if _road_mesh != null:
		return

	_grass_mesh = BoxMesh.new()
	_grass_mesh.size = Vector3(GameConfig.GRASS_WIDTH, 0.12, GameConfig.SEGMENT_LENGTH)

	_road_mesh = BoxMesh.new()
	_road_mesh.size = Vector3(GameConfig.TRACK_WIDTH, 0.12, GameConfig.SEGMENT_LENGTH)

	_curb_base_mesh = BoxMesh.new()
	_curb_base_mesh.size = Vector3(
		GameConfig.CURB_WIDTH,
		GameConfig.CURB_HEIGHT,
		GameConfig.SEGMENT_LENGTH,
	)

	_curb_accent_mesh = BoxMesh.new()
	_curb_accent_mesh.size = Vector3(
		GameConfig.CURB_WIDTH + 0.014,
		GameConfig.CURB_HEIGHT + 0.008,
		2.5,
	)

	_shoulder_line_mesh = BoxMesh.new()
	_shoulder_line_mesh.size = Vector3(0.10, 0.02, GameConfig.SEGMENT_LENGTH)

	_dash_mesh = BoxMesh.new()
	_dash_mesh.size = Vector3(0.16, 0.02, 2.6)

	_verge_mesh = BoxMesh.new()
	_verge_mesh.size = Vector3(VERGE_WIDTH, 0.10, GameConfig.SEGMENT_LENGTH)

	# Ciuffo d'erba: una scatoletta sottile, istanziata in MultiMesh.
	_tuft_mesh = BoxMesh.new()
	_tuft_mesh.size = Vector3(0.10, 0.36, 0.07)

	# Fiore: sfera minuscola a pochi segmenti (un solo draw call per segmento).
	_flower_mesh = SphereMesh.new()
	_flower_mesh.radius = 0.085
	_flower_mesh.height = 0.12
	_flower_mesh.radial_segments = 5
	_flower_mesh.rings = 2

	_post_mesh = BoxMesh.new()
	_post_mesh.size = Vector3(0.12, 0.56, 0.12)

	_post_cap_mesh = BoxMesh.new()
	_post_cap_mesh.size = Vector3(0.14, 0.12, 0.14)

	_trunk_mesh = CylinderMesh.new()
	_trunk_mesh.top_radius = 0.14
	_trunk_mesh.bottom_radius = 0.21
	_trunk_mesh.height = 1.0
	_trunk_mesh.radial_segments = 7
	_trunk_mesh.rings = 1

	_cone_lower_mesh = CylinderMesh.new()
	_cone_lower_mesh.top_radius = 0.18
	_cone_lower_mesh.bottom_radius = 0.95
	_cone_lower_mesh.height = 1.35
	_cone_lower_mesh.radial_segments = 8
	_cone_lower_mesh.rings = 1

	_cone_upper_mesh = CylinderMesh.new()
	_cone_upper_mesh.top_radius = 0.0
	_cone_upper_mesh.bottom_radius = 0.72
	_cone_upper_mesh.height = 1.25
	_cone_upper_mesh.radial_segments = 8
	_cone_upper_mesh.rings = 1

	_crown_mesh = SphereMesh.new()
	_crown_mesh.radius = 0.92
	_crown_mesh.height = 1.75
	_crown_mesh.radial_segments = 8
	_crown_mesh.rings = 4

	_bush_mesh = SphereMesh.new()
	_bush_mesh.radius = 0.55
	_bush_mesh.height = 0.85
	_bush_mesh.radial_segments = 7
	_bush_mesh.rings = 3

	_rock_mesh = SphereMesh.new()
	_rock_mesh.radius = 0.50
	_rock_mesh.height = 0.90
	_rock_mesh.radial_segments = 6
	_rock_mesh.rings = 3

	_hill_mesh = SphereMesh.new()
	_hill_mesh.radius = 18.0
	_hill_mesh.height = 7.0
	_hill_mesh.is_hemisphere = true
	_hill_mesh.radial_segments = 12
	_hill_mesh.rings = 5


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	# Seme deterministico: le decorazioni sono stabili per ogni segmento.
	rng.seed = segment_index * 1013904223 + 12345
	_add_ground(rng)
	_add_road_and_curbs()
	_add_lane_lines()
	_add_decorations(rng)


func _add_ground(rng: RandomNumberGenerator) -> void:
	# Terreno verde ampio su entrambi i lati fino all'orizzonte, a doppia tonalità.
	var outer_edge := GameConfig.TRACK_WIDTH / 2.0 + GameConfig.CURB_WIDTH
	var grass_center_x := outer_edge + GameConfig.GRASS_WIDTH / 2.0
	var grass_material := MaterialFactory.grass(segment_index % 2 == 0)
	var verge_material := MaterialFactory.verge()

	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var grass := MeshInstance3D.new()
		grass.mesh = _grass_mesh
		grass.position = Vector3(side * grass_center_x, -0.08, 0.0)
		grass.material_override = grass_material
		grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(grass)

		# Fascia chiara tra cordolo e prato: stacca la pista dallo sfondo.
		var verge := MeshInstance3D.new()
		verge.mesh = _verge_mesh
		verge.position = Vector3(side * (outer_edge + VERGE_WIDTH * 0.5), -0.035, 0.0)
		verge.material_override = verge_material
		verge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(verge)

	_add_grass_details(rng, outer_edge)


func _add_road_and_curbs() -> void:
	var road := MeshInstance3D.new()
	road.mesh = _road_mesh
	road.position.y = -0.06
	road.material_override = MaterialFactory.road(segment_index % 2 == 1)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)

	var half_road := GameConfig.TRACK_WIDTH / 2.0
	var curb_x := half_road + GameConfig.CURB_WIDTH / 2.0
	var primary_mat := MaterialFactory.edge()
	var accent_mat := MaterialFactory.curb_accent()
	var line_mat := MaterialFactory.lane()

	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		# Cordolo rialzato continuo bianco ai due lati della pista.
		var curb_base := MeshInstance3D.new()
		curb_base.mesh = _curb_base_mesh
		curb_base.position = Vector3(side * curb_x, 0.07, 0.0)
		curb_base.material_override = primary_mat
		add_child(curb_base)

		# Blocchi alternati rossi lungo il cordolo per leggibilità e senso di velocità.
		for block_index in 8:
			var curb_accent := MeshInstance3D.new()
			curb_accent.mesh = _curb_accent_mesh
			curb_accent.position = Vector3(
				side * curb_x,
				0.072,
				-GameConfig.SEGMENT_LENGTH / 2.0 + 2.5 + block_index * 5.0,
			)
			curb_accent.material_override = accent_mat
			curb_accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(curb_accent)

		# Linea bianca continua interna a bordo corsia.
		var shoulder_line := MeshInstance3D.new()
		shoulder_line.mesh = _shoulder_line_mesh
		shoulder_line.position = Vector3(side * (half_road - 0.16), 0.012, 0.0)
		shoulder_line.material_override = line_mat
		shoulder_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shoulder_line)


## Ciuffi d'erba e fiori sparsi sul prato, raggruppati in due MultiMesh:
## centinaia di dettagli con due soli draw call per segmento.
func _add_grass_details(rng: RandomNumberGenerator, outer_edge: float) -> void:
	var tuft_holder := _make_multimesh(
		_tuft_mesh,
		MaterialFactory.vertex_colored("grass_tuft"),
		TUFT_INSTANCES,
	)
	var flower_holder := _make_multimesh(
		_flower_mesh,
		MaterialFactory.vertex_colored("flower", 0.72),
		FLOWER_INSTANCES,
	)
	var tuft_colors: Array[Color] = [
		GameConfig.COLOR_GRASS.lightened(0.10),
		GameConfig.COLOR_GRASS_ALT.darkened(0.05),
		GameConfig.FOLIAGE_COLORS[1],
	]

	for index in TUFT_INSTANCES:
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var height := rng.randf_range(0.65, 1.35)
		var width := rng.randf_range(0.75, 1.35)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(width, height, width)
		)
		var origin := Vector3(
			side * (outer_edge + rng.randf_range(0.35, 26.0)),
			0.17 * height,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH * 0.5, GameConfig.SEGMENT_LENGTH * 0.5),
		)
		tuft_holder.multimesh.set_instance_transform(index, Transform3D(basis, origin))
		tuft_holder.multimesh.set_instance_color(
			index,
			tuft_colors[rng.randi_range(0, tuft_colors.size() - 1)],
		)

	for index in FLOWER_INSTANCES:
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var scale_value := rng.randf_range(0.75, 1.45)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(scale_value, scale_value, scale_value)
		)
		var origin := Vector3(
			side * (outer_edge + rng.randf_range(0.9, 18.0)),
			0.16 + 0.04 * scale_value,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH * 0.5, GameConfig.SEGMENT_LENGTH * 0.5),
		)
		flower_holder.multimesh.set_instance_transform(index, Transform3D(basis, origin))
		flower_holder.multimesh.set_instance_color(
			index,
			GameConfig.FLOWER_COLORS[rng.randi_range(0, GameConfig.FLOWER_COLORS.size() - 1)],
		)

	add_child(tuft_holder)
	add_child(flower_holder)


func _make_multimesh(
	mesh: Mesh,
	material: Material,
	count: int,
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# `use_colors` va impostato PRIMA di allocare le istanze.
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var holder := MultiMeshInstance3D.new()
	holder.name = "GrassDetails"
	holder.multimesh = multimesh
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _add_lane_lines() -> void:
	var divider_positions: Array[float] = [
		-GameConfig.TRACK_WIDTH / 6.0,
		GameConfig.TRACK_WIDTH / 6.0,
	]
	var lane_mat := MaterialFactory.lane()
	for divider_x in divider_positions:
		for dash_index in 8:
			var dash := MeshInstance3D.new()
			dash.mesh = _dash_mesh
			dash.position = Vector3(
				divider_x,
				0.012,
				-GameConfig.SEGMENT_LENGTH / 2.0 + 2.5 + dash_index * 5.0,
			)
			dash.material_override = lane_mat
			dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(dash)


func _add_decorations(rng: RandomNumberGenerator) -> void:
	var outer_curb := GameConfig.TRACK_WIDTH / 2.0 + GameConfig.CURB_WIDTH

	# Delineatori laterali minimali ben distanziati lungo il bordo esterno.
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		for post_index in 2:
			var post_z := -10.0 + post_index * 20.0
			var post := _make_post()
			post.position = Vector3(side * (outer_curb + 0.55), 0.0, post_z)
			add_child(post)

	# Alberi low-poly ben distanziati ai lati della strada.
	var tree_count := rng.randi_range(4, 6)
	for _i in tree_count:
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var tree := _make_tree(rng)
		tree.position = Vector3(
			side * (outer_curb + rng.randf_range(2.6, 15.0)),
			-0.02,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH / 2.0, GameConfig.SEGMENT_LENGTH / 2.0),
		)
		add_child(tree)

	# Cespugli e rocce leggere sul prato.
	var bush_count := rng.randi_range(1, 3)
	for _i in bush_count:
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var bush := _make_bush(rng)
		bush.position = Vector3(
			side * (outer_curb + rng.randf_range(1.6, 11.0)),
			0.18,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH / 2.0, GameConfig.SEGMENT_LENGTH / 2.0),
		)
		add_child(bush)

	var rock_count := rng.randi_range(1, 2)
	for _i in rock_count:
		var side: float = 1.0 if rng.randf() > 0.5 else -1.0
		var rock := _make_rock(rng)
		rock.position = Vector3(
			side * (outer_curb + rng.randf_range(2.0, 13.0)),
			0.10,
			rng.randf_range(-GameConfig.SEGMENT_LENGTH / 2.0, GameConfig.SEGMENT_LENGTH / 2.0),
		)
		add_child(rock)

	# Colline low-poly morbide in lontananza per arricchire il profilo dell'orizzonte.
	if segment_index % 2 == 0:
		for side in sides:
			var hill := _make_hill(rng)
			hill.position = Vector3(
				side * rng.randf_range(58.0, 82.0),
				-0.30,
				rng.randf_range(-16.0, 16.0),
			)
			add_child(hill)


func _make_post() -> Node3D:
	var holder := Node3D.new()

	var stem := MeshInstance3D.new()
	stem.mesh = _post_mesh
	stem.position.y = 0.26
	stem.material_override = MaterialFactory.post()
	holder.add_child(stem)

	var reflector := MeshInstance3D.new()
	reflector.mesh = _post_cap_mesh
	reflector.position.y = 0.44
	reflector.material_override = MaterialFactory.post_reflector()
	reflector.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(reflector)

	return holder


func _make_tree(rng: RandomNumberGenerator) -> Node3D:
	var tree := Node3D.new()

	var trunk := MeshInstance3D.new()
	trunk.mesh = _trunk_mesh
	trunk.position.y = 0.50
	trunk.material_override = MaterialFactory.trunk()
	tree.add_child(trunk)

	var palette_index := rng.randi_range(0, GameConfig.FOLIAGE_COLORS.size() - 1)
	var foliage_mat := MaterialFactory.foliage(palette_index)
	if rng.randf() > 0.45:
		var lower_cone := MeshInstance3D.new()
		lower_cone.mesh = _cone_lower_mesh
		lower_cone.position.y = 1.45
		lower_cone.material_override = foliage_mat
		tree.add_child(lower_cone)

		var upper_cone := MeshInstance3D.new()
		upper_cone.mesh = _cone_upper_mesh
		upper_cone.position.y = 2.30
		upper_cone.material_override = MaterialFactory.foliage_highlight(palette_index)
		tree.add_child(upper_cone)
	else:
		var crown := MeshInstance3D.new()
		crown.mesh = _crown_mesh
		crown.position.y = 1.68
		crown.material_override = foliage_mat
		tree.add_child(crown)

		# Seconda chioma più chiara: dà volume alla sfera low-poly.
		var crown_top := MeshInstance3D.new()
		crown_top.mesh = _crown_mesh
		crown_top.position = Vector3(0.16, 2.02, -0.10)
		crown_top.scale = Vector3(0.62, 0.55, 0.62)
		crown_top.material_override = MaterialFactory.foliage_highlight(palette_index)
		tree.add_child(crown_top)

	var scale_value := rng.randf_range(0.85, 1.45)
	tree.scale = Vector3(scale_value, scale_value, scale_value)
	tree.rotation.y = rng.randf_range(0.0, TAU)
	return tree


func _make_bush(rng: RandomNumberGenerator) -> MeshInstance3D:
	var bush := MeshInstance3D.new()
	bush.mesh = _bush_mesh
	bush.material_override = MaterialFactory.foliage(
		rng.randi_range(0, GameConfig.FOLIAGE_COLORS.size() - 1)
	)
	var xz_scale := rng.randf_range(0.8, 1.3)
	bush.scale = Vector3(xz_scale, rng.randf_range(0.65, 0.95), xz_scale)
	return bush


func _make_rock(rng: RandomNumberGenerator) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	rock.mesh = _rock_mesh
	rock.material_override = MaterialFactory.rock()
	rock.rotation.y = rng.randf_range(0.0, TAU)
	rock.scale = Vector3(
		rng.randf_range(0.65, 1.35),
		rng.randf_range(0.45, 0.78),
		rng.randf_range(0.65, 1.35),
	)
	return rock


func _make_hill(rng: RandomNumberGenerator) -> MeshInstance3D:
	var hill := MeshInstance3D.new()
	hill.mesh = _hill_mesh
	hill.material_override = MaterialFactory.hill()
	hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hill.scale = Vector3(
		rng.randf_range(1.1, 1.8),
		rng.randf_range(0.55, 1.15),
		rng.randf_range(1.2, 2.0),
	)
	return hill
