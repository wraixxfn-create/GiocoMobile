class_name CarBodyFactory
extends RefCounted
## Fabbrica di geometria procedurale per la carrozzeria dell'auto.
##
## Produce `ArrayMesh` "scolpite" a partire da curve di progetto, invece di
## assemblare primitive: è ciò che distingue il modello da un blockout.
##
## Strumenti offerti:
## - `build_loft()`: superficie che collega sezioni trasversali lungo l'asse
##   longitudinale (scocca e abitacolo). Ogni stazione ha larghezza, fondo e
##   colmo propri; due sollevamenti locali scolpiscono i passaruota (solo
##   verso i fianchi) e le spalle dei parafanghi, senza deformare pianale e
##   cofano al centro. I triangoli vengono smistati in "bucket" (uno per
##   materiale) da una `Callable`, così un unico loft continuo produce mesh
##   separate per vernice, rivestimenti e vetri, con normali morbide
##   calcolate sulla griglia intera (nessuna cucitura di luce ai confini).
## - `build_lathe_x()`: rivoluzione di un profilo attorno all'asse X
##   (pneumatici e barili dei cerchi), con specchiatura corretta per lato.
## - `build_torus_arc()`: arco di toro con tappi (profili dei passaruota).
## - `catmull_rom_1d()`: interpolazione morbida delle curve di progetto.
##
## Convenzioni: metri, fronte verso -Z, suolo a y=0. Le sezioni sono
## descritte da punti `Vector2(xf, yf)` della metà destra, da (0,0) in basso
## al centro a (0,1) in alto al centro; la metà sinistra è lo specchio.


## Interpola una curva 1D definita da punti `Vector2(x, y)` ordinati per x.
static func catmull_rom_1d(points: Array, x: float) -> float:
	if points.is_empty():
		return 0.0
	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	if x <= first.x:
		return first.y
	if x >= last.x:
		return last.y
	var i := 0
	while i + 1 < points.size() and (points[i + 1] as Vector2).x < x:
		i += 1
	var p1: Vector2 = points[i]
	var p2: Vector2 = points[i + 1]
	var p0: Vector2 = points[i - 1] if i > 0 else Vector2(2.0 * p1.x - p2.x, 2.0 * p1.y - p2.y)
	var p3: Vector2 = (
		points[i + 2] if i + 2 < points.size() else Vector2(2.0 * p2.x - p1.x, 2.0 * p2.y - p1.y)
	)
	var t := (x - p1.x) / maxf(p2.x - p1.x, 0.000001)
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1.y
		+ (-p0.y + p2.y) * t
		+ (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2
		+ (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3
	)


## Costruisce il loft e restituisce un dizionario {nome_bucket: ArrayMesh}.
##
## `stations`: array di dizionari con chiavi `z`, `hw` (mezza larghezza),
## `bottom`, `top` e opzionalmente `arch` (sollevamento passaruota) e
## `fender` (sollevamento spalla parafango). `section_keys`: punti chiave
## della mezza-sezione. `bucket`: Callable(station_i, ring_j, punto_a,
## punto_b, z_media) -> String che assegna ogni quad a un materiale.
static func build_loft(
	stations: Array,
	section_keys: Array,
	half_count: int,
	bucket: Callable,
) -> Dictionary:
	var half := _sample_section(section_keys, half_count)
	var ring: Array = []
	for point in half:
		ring.append(point)
	for k in range(half.size() - 2, 0, -1):
		var point: Vector2 = half[k]
		ring.append(Vector2(-point.x, point.y))
	var ring_n := ring.size()
	var station_n := stations.size()
	if station_n < 2 or ring_n < 3:
		return {}

	# Griglia dei vertici: stazione per stazione, anello completo.
	var grid := PackedVector3Array()
	grid.resize(station_n * ring_n)
	var min_z := INF
	var max_z := -INF
	for i in station_n:
		var station: Dictionary = stations[i]
		var z: float = station["z"]
		var hw: float = station["hw"]
		var bottom: float = station["bottom"]
		var top: float = station["top"]
		var arch: float = station.get("arch", 0.0)
		var fender: float = station.get("fender", 0.0)
		min_z = minf(min_z, z)
		max_z = maxf(max_z, z)
		for j in ring_n:
			var point: Vector2 = ring[j]
			var axf := absf(point.x)
			var b := bottom + arch * smoothstep(0.35, 0.75, axf)
			var t := top + fender * smoothstep(0.30, 0.80, axf)
			grid[i * ring_n + j] = Vector3(
				point.x * hw, b + point.y * maxf(t - b, 0.02), z
			)

	# Normali morbide sulla griglia intera (senza tappi: i loro vertici di
	# bordo ereditano queste, il centro riceve la direzione dell'asse).
	var grid_tris := PackedInt32Array()
	for i in station_n - 1:
		for j in ring_n:
			var j2 := (j + 1) % ring_n
			var a := i * ring_n + j
			var b := i * ring_n + j2
			var c := (i + 1) * ring_n + j2
			var d := (i + 1) * ring_n + j
			grid_tris.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var grid_normals := _accumulate_normals(grid, grid_tris)

	# Smistamento in bucket: vertici duplicati per bucket, normali copiate.
	var buckets: Dictionary = {}
	var z_span := maxf(max_z - min_z, 0.001)
	for i in station_n - 1:
		var z_a: float = stations[i]["z"]
		var z_b: float = stations[i + 1]["z"]
		var z_mid := 0.5 * (z_a + z_b)
		for j in ring_n:
			var j2 := (j + 1) % ring_n
			var name: String = bucket.call(i, j, ring[j], ring[j2], z_mid)
			var data := _bucket_data(buckets, name)
			var a := _bucket_vertex(data, grid, grid_normals, i * ring_n + j, min_z, z_span, ring_n)
			var b := _bucket_vertex(data, grid, grid_normals, i * ring_n + j2, min_z, z_span, ring_n)
			var c := _bucket_vertex(
				data, grid, grid_normals, (i + 1) * ring_n + j2, min_z, z_span, ring_n
			)
			var d := _bucket_vertex(data, grid, grid_normals, (i + 1) * ring_n + j, min_z, z_span, ring_n)
			(data["indices"] as PackedInt32Array).append_array(PackedInt32Array([a, b, c, a, c, d]))

	_add_loft_cap(buckets, bucket, grid, grid_normals, ring, stations, 0, -1.0, min_z, z_span)
	_add_loft_cap(
		buckets, bucket, grid, grid_normals, ring, stations, station_n - 1, 1.0, min_z, z_span
	)

	var meshes: Dictionary = {}
	for name in buckets.keys():
		var data: Dictionary = buckets[name]
		meshes[name] = _make_mesh(data["verts"], data["normals"], data["uvs"], data["indices"])
	return meshes


## Rivoluzione attorno all'asse X di un profilo `Vector2(x_assiale, raggio)`.
## `side_sign` < 0 specchia la geometria (ruota sinistra) correggendo
## l'avvolgimento: il perno della ruota resta con rotazione identità, come
## richiesto dal CarController che ne imposta rotazione.x/y in assoluto.
static func build_lathe_x(profile: Array, segments: int, side_sign: float = 1.0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var profile_n := profile.size()
	for i in profile_n:
		var point: Vector2 = profile[i]
		for s in segments:
			var angle := TAU * float(s) / float(segments)
			verts.append(Vector3(
				side_sign * point.x, point.y * cos(angle), point.y * sin(angle)
			))
			uvs.append(Vector2(float(s) / float(segments), float(i) / float(maxi(profile_n - 1, 1))))
	var indices := PackedInt32Array()
	for i in profile_n - 1:
		for s in segments:
			var s2 := (s + 1) % segments
			var a := i * segments + s
			var b := i * segments + s2
			var c := (i + 1) * segments + s2
			var d := (i + 1) * segments + s
			if side_sign >= 0.0:
				indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
			else:
				indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	var normals := _accumulate_normals(verts, indices)
	return _make_mesh(verts, normals, uvs, indices)


## Arco di toro nel piano XY, centrato verso l'alto (+Y), con tappi di
## chiusura alle estremità. Ruotandolo di 90° su Y diventa il profilo di un
## passaruota: niente geometria sotto il pianale, niente fori alle estremità.
static func build_torus_arc(
	ring_radius: float,
	tube_radius: float,
	segments: int,
	tube_segments: int,
	arc_degrees: float,
) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var a0 := deg_to_rad(90.0 - arc_degrees * 0.5)
	var a1 := deg_to_rad(90.0 + arc_degrees * 0.5)
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / float(segments))
		var center := Vector2(ring_radius * cos(a), ring_radius * sin(a))
		for j in tube_segments:
			var b := TAU * float(j) / float(tube_segments)
			verts.append(Vector3(
				center.x + tube_radius * cos(b) * cos(a),
				center.y + tube_radius * cos(b) * sin(a),
				tube_radius * sin(b),
			))
			uvs.append(Vector2(float(i) / float(segments), float(j) / float(tube_segments)))
	var indices := PackedInt32Array()
	for i in segments:
		for j in tube_segments:
			var j2 := (j + 1) % tube_segments
			var a := i * tube_segments + j
			var b := (i + 1) * tube_segments + j
			var c := (i + 1) * tube_segments + j2
			var d := i * tube_segments + j2
			indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	# Tappi alle estremità (ventaglio dal centro del tubo).
	for end_i: int in [0, segments]:
		var a: float = a0 if end_i == 0 else a1
		var ci := verts.size()
		verts.append(Vector3(ring_radius * cos(a), ring_radius * sin(a), 0.0))
		uvs.append(Vector2(0.5, 0.5))
		for j in tube_segments:
			var j2 := (j + 1) % tube_segments
			var p := end_i * tube_segments + j
			var q := end_i * tube_segments + j2
			if end_i == 0:
				indices.append_array(PackedInt32Array([ci, q, p]))
			else:
				indices.append_array(PackedInt32Array([ci, p, q]))
	var normals := _accumulate_normals(verts, indices)
	return _make_mesh(verts, normals, uvs, indices)


## Capsula con asse lungo Y (lunghezza totale = `cylinder_length` + 2*raggio),
## generata come lathe: stessa geometria e stesse trasformazioni in ogni
## punto del modello (paraurti, fanali, specchietti, maniglie...).
static func build_capsule(
	radius: float, cylinder_length: float, segments: int = 18, cap_steps: int = 5
) -> ArrayMesh:
	var profile: Array = []
	var half_cyl := cylinder_length * 0.5
	for k in cap_steps + 1:
		var phi := -PI * 0.5 + PI * 0.5 * float(k) / float(cap_steps)
		profile.append(Vector2(-half_cyl + radius * sin(phi), radius * cos(phi)))
	for k in range(1, cap_steps + 1):
		var phi := PI * 0.5 * float(k) / float(cap_steps)
		profile.append(Vector2(half_cyl + radius * sin(phi), radius * cos(phi)))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var profile_n := profile.size()
	for i in profile_n:
		var point: Vector2 = profile[i]
		for s in segments:
			var angle := TAU * float(s) / float(segments)
			# Lathe attorno a X ruotato su Y: (x, y, z) -> (y, x, z) con la
			# rotazione che porta l'asse X sull'asse Y (Rz di +90 gradi:
			# (x, y, z) -> (-y, x, z)); la capsula e' simmetrica, il segno
			# sull'asse trasversale non cambia la forma.
			verts.append(Vector3(
				-point.y * cos(angle), point.x, point.y * sin(angle)
			))
			uvs.append(Vector2(float(s) / float(segments), float(i) / float(maxi(profile_n - 1, 1))))
	var indices := PackedInt32Array()
	for i in profile_n - 1:
		for s in segments:
			var s2 := (s + 1) % segments
			var a := i * segments + s
			var b := i * segments + s2
			var c := (i + 1) * segments + s2
			var d := (i + 1) * segments + s
			indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var normals := _accumulate_normals(verts, indices)
	return _make_mesh(verts, normals, uvs, indices)


# ----------------------------------------------------------------- Interni ---

## Campiona la mezza-sezione dai punti chiave con Catmull-Rom 2D.
static func _sample_section(keys: Array, count: int) -> Array:
	var xs: Array = []
	var ys: Array = []
	for i in keys.size():
		var key: Vector2 = keys[i]
		xs.append(Vector2(float(i), key.x))
		ys.append(Vector2(float(i), key.y))
	var out: Array = []
	for j in count:
		var u := float(j) / float(count - 1) * float(keys.size() - 1)
		out.append(Vector2(catmull_rom_1d(xs, u), catmull_rom_1d(ys, u)))
	out[0] = keys[0]
	out[count - 1] = keys[keys.size() - 1]
	return out


## Normali per-vertice accumulate dalle facce: shading morbido e continuo.
static func _accumulate_normals(
	verts: PackedVector3Array, indices: PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var tri_n := indices.size() / 3
	for t in tri_n:
		var ia := indices[t * 3]
		var ib := indices[t * 3 + 1]
		var ic := indices[t * 3 + 2]
		var face := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
		normals[ia] = normals[ia] + face
		normals[ib] = normals[ib] + face
		normals[ic] = normals[ic] + face
	for i in normals.size():
		var n := normals[i]
		normals[i] = n.normalized() if n.length() > 0.000001 else Vector3.UP
	return normals


static func _make_mesh(
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


static func _bucket_data(buckets: Dictionary, name: String) -> Dictionary:
	if not buckets.has(name):
		buckets[name] = {
			"verts": PackedVector3Array(),
			"normals": PackedVector3Array(),
			"uvs": PackedVector2Array(),
			"indices": PackedInt32Array(),
			"map": {},
		}
	return buckets[name]


static func _bucket_vertex(
	data: Dictionary,
	grid: PackedVector3Array,
	grid_normals: PackedVector3Array,
	grid_index: int,
	min_z: float,
	z_span: float,
	ring_n: int,
) -> int:
	var map: Dictionary = data["map"]
	if map.has(grid_index):
		return map[grid_index]
	var local := (data["verts"] as PackedVector3Array).size()
	map[grid_index] = local
	var vertex := grid[grid_index]
	(data["verts"] as PackedVector3Array).append(vertex)
	(data["normals"] as PackedVector3Array).append(grid_normals[grid_index])
	(data["uvs"] as PackedVector2Array).append(Vector2(
		(vertex.z - min_z) / z_span, float(grid_index % ring_n) / float(ring_n)
	))
	return local


## Tappo di chiusura del loft: ventaglio verso un centro spinto in fuori,
## con bucket scelto triangolo per triangolo così le fasce dei materiali
## proseguono continue sul muso e sulla coda. L'avvolgimento è opposto tra
## fronte (-Z) e retro (+Z), come richiede il backface culling.
static func _add_loft_cap(
	buckets: Dictionary,
	bucket: Callable,
	grid: PackedVector3Array,
	grid_normals: PackedVector3Array,
	ring: Array,
	stations: Array,
	station_i: int,
	direction: float,
	min_z: float,
	z_span: float,
) -> void:
	var ring_n := ring.size()
	var station: Dictionary = stations[station_i]
	var z: float = station["z"]
	var center := Vector3.ZERO
	for j in ring_n:
		center += grid[station_i * ring_n + j]
	center = center / float(ring_n) + Vector3(0.0, 0.0, direction * 0.055)
	var centers: Dictionary = {}
	for j in ring_n:
		var j2 := (j + 1) % ring_n
		var name: String = bucket.call(station_i, j, ring[j], ring[j2], z)
		var data := _bucket_data(buckets, name)
		if not centers.has(name):
			var ci := (data["verts"] as PackedVector3Array).size()
			centers[name] = ci
			(data["verts"] as PackedVector3Array).append(center)
			(data["normals"] as PackedVector3Array).append(
				Vector3(0.0, 0.15, direction).normalized()
			)
			(data["uvs"] as PackedVector2Array).append(Vector2((z - min_z) / z_span, 0.5))
		var ci: int = centers[name]
		var a := _bucket_vertex(data, grid, grid_normals, station_i * ring_n + j, min_z, z_span, ring_n)
		var b := _bucket_vertex(
			data, grid, grid_normals, station_i * ring_n + j2, min_z, z_span, ring_n
		)
		if direction < 0.0:
			(data["indices"] as PackedInt32Array).append_array(PackedInt32Array([ci, b, a]))
		else:
			(data["indices"] as PackedInt32Array).append_array(PackedInt32Array([ci, a, b]))
