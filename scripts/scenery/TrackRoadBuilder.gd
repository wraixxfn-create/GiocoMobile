class_name TrackRoadBuilder
extends RefCounted
## Costruisce la strada di un segmento: superficie in asfalto con texture
## generata, cordoli smussati, segnaletica dipinta e variazioni di superficie
## (rappezzi e giunti).
##
## Scelte di progetto:
## - la superficie di guida resta **esattamente a y = 0**: auto, cancelli e
##   ostacoli non cambiano quota e le collisioni restano affidabili;
## - cordoli e segnaletica sono uniti in un'unica mesh con colore per vertice
##   (un draw call per segmento) e la vernice non proietta ombre;
## - asfalto, cordoli e rappezzi usano tre materiali condivisi da tutta la
##   pista: nessuna texture pesante, nessun decal dinamico.

const ROAD_UV_LENGTH: float = 6.666  # 6 ripetizioni esatte per segmento di 40 m
const BEVEL: float = 0.045

static var _road_mesh: ArrayMesh = null
static var _paint_mesh: ArrayMesh = null
static var _accent_mesh: Mesh = null
static var _curb_mesh: Mesh = null
static var _dash_mesh: Mesh = null


## Crea la strada del segmento `segment_index` sotto `parent`.
static func build(parent: Node3D, segment_index: int) -> void:
	var half_length := GameConfig.SEGMENT_LENGTH * 0.5
	var half_width := GameConfig.TRACK_WIDTH * 0.5

	var surface := MeshInstance3D.new()
	surface.name = "Asphalt"
	surface.mesh = _road()
	surface.material_override = MaterialFactory.asphalt()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)

	var paint := MeshInstance3D.new()
	paint.name = "Paint"
	paint.mesh = _paint()
	paint.material_override = MaterialFactory.vertex_colored("road_paint", 0.62, false)
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(paint)

	_add_surface_variation(parent, segment_index, half_width, half_length)


# --------------------------------------------------------------- Superfici ---

## Sezione della carreggiata: piano di guida a y = 0, smusso sul bordo e
## spessore visibile (la strada è un manufatto, non un foglio di carta).
static func _road() -> ArrayMesh:
	if _road_mesh != null:
		return _road_mesh
	var half_width := GameConfig.TRACK_WIDTH * 0.5
	var half_length := GameConfig.SEGMENT_LENGTH * 0.5
	var chamfer := 0.06
	var thickness := 0.26
	# Profilo trasversale: (x, y, u).
	var profile: Array[Vector3] = [
		Vector3(-half_width, 0.0, 0.0),
		Vector3(-half_width - chamfer, -0.035, -0.012),
		Vector3(-half_width - chamfer, -thickness, -0.012),
		Vector3(half_width + chamfer, -thickness, 1.012),
		Vector3(half_width + chamfer, -0.035, 1.012),
		Vector3(half_width, 0.0, 1.0),
	]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var z_values: Array[float] = [-half_length, half_length]
	for z in z_values:
		for point in profile:
			verts.append(Vector3(point.x, point.y, z))
			uvs.append(Vector2(point.z, (z + half_length) / ROAD_UV_LENGTH))
			if point.y > -0.001:
				normals.append(Vector3.UP)
			elif point.x < 0.0:
				normals.append(Vector3.LEFT if point.y < -0.1 else Vector3(-0.5, 0.86, 0.0).normalized())
			else:
				normals.append(Vector3.RIGHT if point.y < -0.1 else Vector3(0.5, 0.86, 0.0).normalized())
	var count := profile.size()
	for i in count - 1:
		var a := i
		var b := i + 1
		var c := count + i + 1
		var d := count + i
		indices.append_array([a, b, c, a, c, d])
	# Faccia superiore: chiude il profilo tra l'ultimo punto e il primo.
	# Senza questa chiusura la carreggiata sarebbe un guscio aperto e si
	# vedrebbe il cielo attraverso l'asfalto.
	var last := count - 1
	indices.append_array([last, 0, count, last, count, count + last])
	_road_mesh = _mesh(verts, normals, uvs, indices)
	return _road_mesh


## Cordoli + strisce, in una sola mesh colorata per vertice.
static func _paint() -> ArrayMesh:
	if _paint_mesh != null:
		return _paint_mesh
	var half_width := GameConfig.TRACK_WIDTH * 0.5
	var half_length := GameConfig.SEGMENT_LENGTH * 0.5
	var parts: Array = []
	var curb_x := half_width + GameConfig.CURB_WIDTH * 0.5

	# Cordolo principale.
	for side: float in [-1.0, 1.0]:
		var curb := PropMeshes.box(
			Vector3(GameConfig.CURB_WIDTH, GameConfig.CURB_HEIGHT + 0.04, GameConfig.SEGMENT_LENGTH)
		)
		parts.append({
			"acc": _acc(curb),
			"color": SceneryPalette.CURB_LIGHT,
			"xform": Transform3D(Basis.IDENTITY, Vector3(side * curb_x, 0.06, 0.0)),
		})
		# Blocchi rossi: sporgono di 1 cm, come verniciati sopra il cordolo.
		for i in 8:
			var accent := PropMeshes.box(
				Vector3(GameConfig.CURB_WIDTH + 0.02, GameConfig.CURB_HEIGHT + 0.055, 2.5)
			)
			parts.append({
				"acc": _acc(accent),
				"color": SceneryPalette.CURB_RED,
				"xform": Transform3D(
					Basis.IDENTITY,
					Vector3(side * curb_x, 0.058, -half_length + 2.5 + i * 5.0),
				),
			})
		# Linea di margine continua, appena dentro l'asfalto.
		var edge := PropMeshes.box(Vector3(0.13, 0.012, GameConfig.SEGMENT_LENGTH))
		parts.append({
			"acc": _acc(edge),
			"color": SceneryPalette.LANE_PAINT,
			"xform": Transform3D(Basis.IDENTITY, Vector3(side * (half_width - 0.32), 0.007, 0.0)),
		})

	# Tratteggio di separazione corsie: due file, passo 5 m (continuo tra segmenti).
	for divider_x in [-GameConfig.TRACK_WIDTH / 6.0, GameConfig.TRACK_WIDTH / 6.0]:
		for i in 8:
			var dash := PropMeshes.box(Vector3(0.16, 0.012, 2.6))
			parts.append({
				"acc": _acc(dash),
				"color": SceneryPalette.LANE_PAINT,
				"xform": Transform3D(
					Basis.IDENTITY,
					Vector3(divider_x, 0.007, -half_length + 2.5 + i * 5.0),
				),
			})
	_paint_mesh = PropMeshes.merged_colored(parts, true)
	return _paint_mesh


## Rappezzi d'asfalto e giunti di dilatazione: superficie non uniforme, ma
## sempre sotto il piano di guida (nessun gradino per l'auto).
static func _add_surface_variation(
	parent: Node3D,
	segment_index: int,
	half_width: float,
	half_length: float,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("asphalt_variation_%d" % segment_index)
	var parts: Array = []
	var patch_count := rng.randi_range(3, 5)
	for i in patch_count:
		var width := rng.randf_range(0.7, 1.9)
		var depth := rng.randf_range(0.35, 0.9)
		var patch := PropMeshes.box(Vector3(width, 0.005, depth))
		var x := rng.randf_range(-half_width + 0.8, half_width - 0.8)
		var z := rng.randf_range(-half_length + 1.0, half_length - 1.0)
		var shade: float = rng.randf_range(0.0, 1.0)
		parts.append({
			"acc": _acc(patch),
			"color": SceneryPalette.ROAD_PATCH.lerp(SceneryPalette.ROAD_EDGE, shade * 0.35),
			"xform": Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(x, 0.003, z)),
		})
	# Giunti trasversali ogni 10 m: leggeri, mai sopra la segnaletica.
	for i in 4:
		var joint := PropMeshes.box(Vector3(GameConfig.TRACK_WIDTH - 0.9, 0.004, 0.035))
		parts.append({
			"acc": _acc(joint),
			"color": SceneryPalette.ROAD_JOINT,
			"xform": Transform3D(
				Basis.IDENTITY,
				Vector3(0.0, 0.0035, -half_length + 5.0 + i * 10.0),
			),
		})
	var instance := MeshInstance3D.new()
	instance.name = "SurfaceVariation"
	instance.mesh = PropMeshes.merged_colored(parts, true)
	instance.material_override = MaterialFactory.vertex_colored("road_patch_paint", 0.9, false)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


# ------------------------------------------------------------------ Helper ---

static func _acc(data: Dictionary) -> Dictionary:
	return {"verts": data["verts"], "tris": data["tris"]}


static func _mesh(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
