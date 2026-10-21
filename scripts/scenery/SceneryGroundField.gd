@tool
class_name SceneryGroundField
extends Node3D
## Terreno tropicale del livello dimostrativo: una sola mesh continua, con
## ondulazioni morbide che si alzano allontanandosi dalla pista, una fascia
## sabbiosa lungo il bordo e chiazze di erba in tre toni (colore per vertice).
##
## Perché una mesh unica e statica:
## - niente giunzioni visibili tra segmenti riciclati;
## - un solo draw call per tutto il prato;
## - la pista può scorrere senza che il terreno "nuoti" sotto l'auto.
## Il livello dura 800 m: il terreno copre abbondantemente corsa + orizzonte
## visibile (la foschia chiude la vista molto prima della fine della mesh).
##
## L'erba alta e i fiori sono due MultiMesh: migliaia di dettagli con due draw
## call, densi vicino alla pista e radi in lontananza.

const WIDTH: float = 320.0
const NEAR_Z: float = 120.0
const FAR_Z: float = -1240.0
const GRASS_INSTANCES: int = 6200
const FLOWER_INSTANCES: int = 420
const SAND_INNER: float = 3.72
const SAND_OUTER: float = 4.85
const GRASS_START: float = 5.6

static var _tuft_mesh: Mesh = null
static var _flower_mesh: Mesh = null

var _built: bool = false


func _ready() -> void:
	build()


## Costruisce terreno e dettagli. Chiamabile più volte senza duplicare nulla.
func build() -> void:
	if _built:
		return
	_built = true
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = _build_terrain_mesh()
	terrain.material_override = MaterialFactory.terrain()
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	add_child(_build_grass())
	add_child(_build_flowers())


# --------------------------------------------------------------- Altezza ---

## Quota del terreno in un punto: piatta accanto alla pista, ondulata più
## lontano, con creste che diventano colline verso l'orizzonte.
static func height_at(x: float, z: float) -> float:
	var distance := absf(x)
	# Sponde basse vicino alla pista: niente "muri verdi" dietro l'auto.
	var near_flat := smoothstep(13.0, 46.0, distance)
	var rolling := (
		sin(z * 0.019 + x * 0.008) * 0.85
		+ sin(z * 0.0087 - 0.7) * 1.20
		+ sin(x * 0.028 + z * 0.0041 + 1.7) * 0.50
	)
	var ridge := smoothstep(70.0, 210.0, distance) * (4.2 + sin(z * 0.0055 + 1.2) * 2.8)
	return -0.12 + near_flat * rolling + ridge


## Colore del terreno: sabbia calda vicino all'asfalto, poi tre verdi a chiazze.
static func color_at(x: float, z: float) -> Color:
	var distance := absf(x)
	var sand := 1.0 - smoothstep(SAND_INNER, SAND_OUTER + 1.9, distance)
	var patch_a := sin(z * 0.031 + x * 0.017) * 0.5 + 0.5
	var patch_b := sin(z * 0.011 - x * 0.026 + 2.1) * 0.5 + 0.5
	var grass := SceneryPalette.GRASS_BASE
	var broad := sin(z * 0.0062 + x * 0.0091 + 0.6) * 0.5 + 0.5
	grass = grass.lerp(SceneryPalette.GRASS_DEEP, patch_a * 0.72)
	grass = grass.lerp(SceneryPalette.GRASS_LIGHT, patch_b * 0.60)
	grass = grass.lerp(SceneryPalette.GRASS_DEEP, broad * 0.34)
	# Chiazze più secche in quota: danno profondità alle colline.
	var height_factor := smoothstep(1.0, 9.0, height_at(x, z))
	grass = grass.lerp(SceneryPalette.GRASS_DRY, height_factor * 0.30)
	var sand_color := SceneryPalette.SAND.lerp(SceneryPalette.SAND_DARK, patch_a * 0.35)
	# Bordo sabbia mai pulito: l'erba lo invade a chiazze.
	var speck := sin(x * 2.7 + z * 1.9) * 0.5 + 0.5
	sand_color = sand_color.lerp(SceneryPalette.GRASS_DRY, speck * 0.16)
	return sand_color.lerp(grass, 1.0 - sand * 0.72)


# ----------------------------------------------------------------- Griglia ---

## Colonne fitte accanto alla pista (bordo sabbioso nitido) e larghe in
## lontananza: stessa qualità percepita con un terzo dei vertici.
static func _columns() -> Array[float]:
	var columns: Array[float] = [0.0]
	var near: Array[float] = [
		1.2, 2.4, 3.6, 4.36, 5.0, 5.7, 6.5, 7.3, 8.2, 9.2, 10.4, 11.8,
		13.4, 15.2, 17.4, 20.0, 23.0, 26.5, 30.5, 35.0, 40.5, 47.0,
		54.0, 62.0, 71.0, 81.0, 92.0, 104.0, 118.0, 134.0, 150.0, 160.0,
	]
	for value in near:
		columns.append(value)
		columns.append(-value)
	columns.sort()
	return columns


static func _rows() -> Array[float]:
	var rows: Array[float] = []
	var z := NEAR_Z
	while z >= FAR_Z:
		rows.append(z)
		z -= 11.0
	return rows


func _build_terrain_mesh() -> ArrayMesh:
	var columns := _columns()
	var rows := _rows()
	var cols := columns.size()
	var rows_n := rows.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(cols * rows_n)
	normals.resize(cols * rows_n)
	colors.resize(cols * rows_n)
	for row_index in rows_n:
		var z := rows[row_index]
		for col_index in cols:
			var x := columns[col_index]
			var index := row_index * cols + col_index
			verts[index] = Vector3(x, height_at(x, z), z)
			colors[index] = color_at(x, z)
	for row_index in rows_n:
		for col_index in cols:
			var index := row_index * cols + col_index
			var x := columns[col_index]
			var z := rows[row_index]
			var dx := height_at(x + 0.5, z) - height_at(x - 0.5, z)
			var dz := height_at(x, z + 0.5) - height_at(x, z - 0.5)
			normals[index] = Vector3(-dx, 1.0, -dz).normalized()
	for row_index in rows_n - 1:
		for col_index in cols - 1:
			var a := row_index * cols + col_index
			var b := a + 1
			var c := a + cols
			var d := c + 1
			# Verso orario visto dall'alto: le righe avanzano verso -Z e le
			# colonne verso +X, quindi l'ordine corretto è a, b, c.
			indices.append_array([a, b, c, b, d, c])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ------------------------------------------------------------- Dettagli -----

static func _tuft() -> Mesh:
	if _tuft_mesh != null:
		return _tuft_mesh
	# Ciuffo d'erba: tre lamine incrociate, 6 triangoli, doppia faccia.
	var acc := PropMeshes.new_accumulator()
	for i in 4:
		var yaw := TAU * float(i) / 4.0
		var blade := PropMeshes.frond(0.46, 0.13, 0.42, 0.06, 40 + i, 0.18, 3)
		PropMeshes.append(
			acc,
			blade["verts"] as Array[Vector3],
			blade["tris"] as Array[Vector3i],
			Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(82.0)), Vector3.ZERO),
		)
	# Colore per vertice bianco: serve solo a far esistere l'attributo COLOR,
	# che il MultiMesh moltiplica per il colore della singola istanza.
	_tuft_mesh = PropMeshes.merged_colored(
		[{"acc": acc, "color": Color.WHITE}], true
	)
	return _tuft_mesh


func _build_grass() -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _tuft()
	multimesh.instance_count = GRASS_INSTANCES
	var rng := RandomNumberGenerator.new()
	rng.seed = 31415
	for index in GRASS_INSTANCES:
		var side := -1.0 if index % 2 == 0 else 1.0
		# Distribuzione a densità decrescente: fitta entro 24 m, rada oltre.
		var spread := pow(rng.randf(), 2.3)
		var distance := GRASS_START + spread * 52.0
		var z := rng.randf_range(FAR_Z * 0.55, NEAR_Z)
		var x := side * distance
		var scale_value := rng.randf_range(0.40, 0.78) * lerpf(1.0, 0.5, spread)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(scale_value, scale_value * rng.randf_range(0.8, 1.3), scale_value)
		)
		var origin := Vector3(x, height_at(x, z) - 0.02, z)
		multimesh.set_instance_transform(index, Transform3D(basis, origin))
		multimesh.set_instance_color(
			index,
			SceneryPalette.grass(rng.randi_range(0, 2)).lerp(
				SceneryPalette.GRASS_DRY, rng.randf_range(0.0, 0.22)
			),
		)
	var holder := MultiMeshInstance3D.new()
	holder.name = "Grass"
	holder.multimesh = multimesh
	holder.material_override = MaterialFactory.vertex_colored("grass_blade", 0.9, true)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.visibility_range_end = 95.0
	return holder


func _build_flowers() -> MultiMeshInstance3D:
	if _flower_mesh == null:
		var acc := PropMeshes.new_accumulator()
		var petal := PropMeshes.blob(77, 0.085, 0, 0.18, 0.55, false)
		PropMeshes.append(
			acc,
			petal["verts"] as Array[Vector3],
			petal["tris"] as Array[Vector3i],
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.16, 0.0)),
		)
		_flower_mesh = PropMeshes.merged_colored(
			[{"acc": acc, "color": Color.WHITE}], false
		)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _flower_mesh
	multimesh.instance_count = FLOWER_INSTANCES
	var rng := RandomNumberGenerator.new()
	rng.seed = 27182
	var palette: Array[Color] = [
		SceneryPalette.FLOWER_A, SceneryPalette.FLOWER_B, SceneryPalette.FLOWER_C,
	]
	for index in FLOWER_INSTANCES:
		var side := -1.0 if index % 2 == 0 else 1.0
		var distance := GRASS_START + pow(rng.randf(), 1.6) * 14.0
		var z := rng.randf_range(FAR_Z * 0.45, NEAR_Z)
		var x := side * distance
		var scale_value := rng.randf_range(0.45, 0.72)
		var origin := Vector3(x, height_at(x, z) + 0.02, z)
		multimesh.set_instance_transform(
			index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_value), origin)
		)
		multimesh.set_instance_color(index, palette[rng.randi_range(0, palette.size() - 1)])
	var holder := MultiMeshInstance3D.new()
	holder.name = "Flowers"
	holder.multimesh = multimesh
	holder.material_override = MaterialFactory.vertex_colored("flower", 0.72, false)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.visibility_range_end = 70.0
	return holder
