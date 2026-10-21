class_name PropMeshes
extends RefCounted
## Toolkit geometrico per la vegetazione e gli elementi dello scenario.
##
## Tutte le funzioni sono pure e deterministiche: costruiscono mesh scolpite
## (icosphere deformate, tubi lungo una curva, fronde a lamina con nervatura)
## a partire da parametri, senza asset esterni. Le mesh prodotte vengono
## condivise tra le istanze dagli script degli oggetti (`SceneryProp`), così
## cento palme costano cento nodi ma poche mesh.
##
## Convenzioni:
## - unità: metri; le mesh sono costruite con la base all'altezza y = 0;
## - l'asse +X è "avanti" per le fronde, +Y è l'alto;
## - `Accumulator` raccoglie più parti in un'unica mesh (pochi draw call).

## Contenitore mutabile per unire più parti in una sola mesh.
## Viene passato per riferimento (Dictionary) e chiuso con `to_mesh()`.
static func new_accumulator() -> Dictionary:
	return {"verts": [] as Array[Vector3], "tris": [] as Array[Vector3i]}


## Aggiunge una parte trasformata all'accumulatore.
## `tris` sono indici locali della parte, `xform` la porta in coordinate mesh.
static func append(
	acc: Dictionary,
	verts: Array[Vector3],
	tris: Array[Vector3i],
	xform: Transform3D = Transform3D.IDENTITY,
) -> void:
	var target: Array[Vector3] = acc["verts"]
	var offset := target.size()
	for vertex in verts:
		target.append(xform * vertex)
	var target_tris: Array[Vector3i] = acc["tris"]
	for tri in tris:
		target_tris.append(tri + Vector3i(offset, offset, offset))


## Mesh finale dell'accumulatore. `flat` = facce a spigolo vivo (rocce),
## altrimenti normali morbide (chiome, tronchi).
static func to_mesh(acc: Dictionary, flat: bool = false) -> ArrayMesh:
	var verts: Array[Vector3] = acc["verts"]
	var tris: Array[Vector3i] = acc["tris"]
	if verts.is_empty() or tris.is_empty():
		return ArrayMesh.new()
	if flat:
		return flat_mesh(verts, tris)
	return smooth_mesh(verts, tris)


## Mesh con normali per-faccia: ogni triangolo ha i propri vertici duplicati.
static func flat_mesh(verts: Array[Vector3], tris: Array[Vector3i]) -> ArrayMesh:
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for tri in tris:
		var a := verts[tri.x]
		var b := verts[tri.y]
		var c := verts[tri.z]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		var start := out_verts.size()
		out_verts.append_array([a, b, c])
		out_normals.append_array([normal, normal, normal])
		out_uvs.append_array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0)])
		indices.append_array([start, start + 1, start + 2])
	return _mesh(out_verts, out_normals, out_uvs, indices)


## Mesh con normali accumulate per vertice: superfici lisce e continue.
static func smooth_mesh(verts: Array[Vector3], tris: Array[Vector3i]) -> ArrayMesh:
	var out_verts := PackedVector3Array(verts)
	var normals := PackedVector3Array()
	normals.resize(out_verts.size())
	var indices := PackedInt32Array()
	for tri in tris:
		indices.append_array([tri.x, tri.y, tri.z])
		var a := out_verts[tri.x]
		var b := out_verts[tri.y]
		var c := out_verts[tri.z]
		var face := (b - a).cross(c - a)
		normals[tri.x] = normals[tri.x] + face
		normals[tri.y] = normals[tri.y] + face
		normals[tri.z] = normals[tri.z] + face
	for i in normals.size():
		var n := normals[i]
		normals[i] = n.normalized() if n.length_squared() > 0.000001 else Vector3.UP
	var uvs := PackedVector2Array()
	uvs.resize(out_verts.size())
	for i in out_verts.size():
		var v := out_verts[i]
		uvs[i] = Vector2(v.x * 0.25 + v.z * 0.25, v.y * 0.5)
	return _mesh(out_verts, normals, uvs, indices)


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


# -------------------------------------------------------------- Icosphere ---

## Icosaedro geodetico. `subdivisions` 0 = 20 facce, 1 = 80, 2 = 320.
## Restituisce {"verts": Array[Vector3], "tris": Array[Vector3i]}.
static func icosphere(subdivisions: int, radius: float = 1.0) -> Dictionary:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var corners: Array[Vector3] = [
		Vector3(-1.0, phi, 0.0), Vector3(1.0, phi, 0.0),
		Vector3(-1.0, -phi, 0.0), Vector3(1.0, -phi, 0.0),
		Vector3(0.0, -1.0, phi), Vector3(0.0, 1.0, phi),
		Vector3(0.0, -1.0, -phi), Vector3(0.0, 1.0, -phi),
		Vector3(phi, 0.0, -1.0), Vector3(phi, 0.0, 1.0),
		Vector3(-phi, 0.0, -1.0), Vector3(-phi, 0.0, 1.0),
	]
	var verts: Array[Vector3] = []
	for corner in corners:
		verts.append(corner.normalized() * radius)
	var tris: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7),
		Vector3i(0, 7, 10), Vector3i(0, 10, 11), Vector3i(1, 5, 9),
		Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6),
		Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2),
		Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10),
		Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]
	for _level in maxi(subdivisions, 0):
		var cache: Dictionary = {}
		var next: Array[Vector3i] = []
		for tri in tris:
			var a := tri.x
			var b := tri.y
			var c := tri.z
			var ab := _midpoint(verts, cache, a, b, radius)
			var bc := _midpoint(verts, cache, b, c, radius)
			var ca := _midpoint(verts, cache, c, a, radius)
			next.append(Vector3i(a, ab, ca))
			next.append(Vector3i(b, bc, ab))
			next.append(Vector3i(c, ca, bc))
			next.append(Vector3i(ab, bc, ca))
		tris = next
	return {"verts": verts, "tris": tris}


static func _midpoint(
	verts: Array[Vector3],
	cache: Dictionary,
	a: int,
	b: int,
	radius: float,
) -> int:
	var key := mini(a, b) * 100000 + maxi(a, b)
	if cache.has(key):
		return int(cache[key])
	var middle: Vector3 = (verts[a] + verts[b]) * 0.5
	verts.append(middle.normalized() * radius)
	var index := verts.size() - 1
	cache[key] = index
	return index


## Sfera irregolare e schiacciata: la base delle rocce e dei cespugli.
## `seed` rende la deformazione deterministica; `squash` < 1 abbassa la forma.
static func blob(
	seed: int,
	radius: float,
	subdivisions: int = 1,
	roughness: float = 0.18,
	squash: float = 1.0,
	flat_bottom: bool = false,
) -> Dictionary:
	var sphere := icosphere(subdivisions, radius)
	var verts: Array[Vector3] = sphere["verts"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var phases: Array[float] = []
	for i in 6:
		phases.append(rng.randf_range(0.0, TAU))
	for i in verts.size():
		var vertex := verts[i]
		var direction := vertex.normalized()
		var wave := (
			sin(direction.x * 3.1 + phases[0]) * 0.45
			+ sin(direction.y * 2.7 + phases[1]) * 0.35
			+ sin(direction.z * 3.6 + phases[2]) * 0.40
			+ sin((direction.x + direction.z) * 5.3 + phases[3]) * 0.22
		)
		var factor := 1.0 + wave * roughness
		var displaced := direction * radius * factor
		displaced.y *= squash
		verts[i] = displaced
	if flat_bottom:
		for i in verts.size():
			var vertex := verts[i]
			vertex.y = maxf(vertex.y, -radius * squash * 0.35)
			verts[i] = vertex
	return {"verts": verts, "tris": sphere["tris"]}


# ------------------------------------------------------------------- Tubo ---

## Tubo lungo una spezzata con raggio variabile: tronchi, rami, pali.
## `path` ha almeno due punti; `radii` un raggio per punto.
static func tube(
	path: Array[Vector3],
	radii: Array[float],
	sides: int = 8,
	cap_ends: bool = true,
	rings: int = 1,
) -> Dictionary:
	var verts: Array[Vector3] = []
	var tris: Array[Vector3i] = []
	var count := path.size()
	if count < 2:
		return {"verts": verts, "tris": tris}
	var safe_sides := maxi(sides, 3)
	# Segmenti di lunghezza uniforme: più anelli = tronco più regolare.
	for index in count:
		var previous := path[maxi(index - 1, 0)]
		var next := path[mini(index + 1, count - 1)]
		var tangent := (next - previous).normalized()
		if tangent.length_squared() < 0.5:
			tangent = Vector3.UP
		var reference := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
		var side := tangent.cross(reference).normalized()
		var up := side.cross(tangent).normalized()
		var radius := radii[mini(index, radii.size() - 1)]
		for ring in rings + 1:
			var amount := float(ring) / float(rings + 1)
			var wobble := 1.0 + 0.06 * sin(amount * TAU + float(index))
			var ring_radius := radius * wobble
			for s in safe_sides:
				var angle := TAU * float(s) / float(safe_sides)
				var offset := side * cos(angle) + up * sin(angle)
				verts.append(path[index] + offset * ring_radius)
	for index in count - 1:
		for ring in rings + 1:
			var ring_base := index * (rings + 1) + ring
			var next_base := (index + 1) * (rings + 1) + ring
			for s in safe_sides:
				var s2 := (s + 1) % safe_sides
				var a := ring_base * safe_sides + s
				var b := ring_base * safe_sides + s2
				var c := next_base * safe_sides + s2
				var d := next_base * safe_sides + s
				tris.append(Vector3i(a, c, b))
				tris.append(Vector3i(a, d, c))
	# Anello di chiusura alle due estremità.
	if cap_ends:
		for end_index: int in [0, count - 1]:
			var base: int = end_index * (rings + 1) * safe_sides
			var center: Vector3 = path[end_index]
			verts.append(center)
			var center_index := verts.size() - 1
			for s in safe_sides:
				var s2 := (s + 1) % safe_sides
				if end_index == 0:
					tris.append(Vector3i(center_index, base + s, base + s2))
				else:
					tris.append(Vector3i(center_index, base + s2, base + s))
	return {"verts": verts, "tris": tris}


## Tronco che si incurva: la curva è un arco semplice, il raggio si assottiglia.
static func curved_trunk(
	height: float,
	curve: float,
	base_radius: float,
	top_radius: float,
	seed: int,
	sides: int = 7,
) -> Dictionary:
	var path: Array[Vector3] = []
	var radii: Array[float] = []
	var steps := 7
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 131 + 7
	var wobble := rng.randf_range(-0.25, 0.25)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var bend := pow(t, 1.8) * curve
		path.append(Vector3(
			bend + sin(t * 2.4 + wobble) * base_radius * 1.4 * t,
			height * t,
			sin(t * 3.1 + wobble * 2.0) * base_radius * 1.1 * t,
		))
		radii.append(lerpf(base_radius, top_radius, pow(t, 0.85)))
	var data := tube(path, radii, sides, true, 0)
	# Punto sommità del tronco: serve ad appoggiare la chioma esattamente in cima.
	data["top"] = path[steps]
	return data


# ------------------------------------------------------------------ Fronde ---

## Fronda di palma: lamina a tre punti (bordo, nervatura rialzata, bordo) con
## profilo a punta e leggera dentellatura. Restituisce vertici e triangoli in
## cui +X è la direzione di crescita e +Y l'alto.
static func frond(
	length: float,
	width: float,
	rise: float,
	droop: float,
	seed: int,
	serration: float = 0.10,
	segments: int = 9,
) -> Dictionary:
	var verts: Array[Vector3] = []
	var tris: Array[Vector3i] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 3571 + 29
	var twist := rng.randf_range(-0.18, 0.18)
	var phase := rng.randf_range(0.0, TAU)
	for i in segments + 1:
		var t := float(i) / float(segments)
		var along := length * t
		var lift := sin(t * PI * 0.62) * rise - droop * pow(t, 1.7)
		var spine := Vector3(along, lift, sin(t * 2.2 + phase) * width * 0.10)
		var taper := pow(sin(PI * minf(t * 1.08, 1.0)), 0.62)
		var half := width * 0.5 * taper
		var teeth := 1.0 + (serration if i % 2 == 0 else -serration)
		var lateral := Vector3(0.0, sin(t * PI * 0.35) * 0.10, 1.0)
		verts.append(spine + lateral * (half * teeth) + Vector3(0.0, -half * 0.10, 0.0))
		verts.append(spine + Vector3(0.0, half * 0.24 + 0.02, 0.0))
		verts.append(spine - lateral * (half * teeth) + Vector3(0.0, -half * 0.10, 0.0))
	for i in segments:
		var base := i * 3
		var next := base + 3
		tris.append(Vector3i(base, next, base + 1))
		tris.append(Vector3i(base + 1, next, next + 1))
		tris.append(Vector3i(base + 1, next + 1, base + 2))
		tris.append(Vector3i(base + 2, next + 1, next + 2))
	var shear := Basis(Vector3.UP, twist)
	for i in verts.size():
		verts[i] = shear * verts[i]
	return {"verts": verts, "tris": tris}


## Chioma di palma: fronde distribuite a corona, alcune più basse e arcuate.
## Restituisce due accumulatori (fronde principali e fronde chiare).
static func palm_crown(
	seed: int,
	count: int,
	length: float,
	width: float,
	droop: float,
) -> Dictionary:
	var main_acc := new_accumulator()
	var light_acc := new_accumulator()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 977 + 41
	for i in count:
		var yaw := TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
		var lower := i % 3 == 2
		var pitch := deg_to_rad(rng.randf_range(10.0, 26.0))
		if lower:
			pitch = deg_to_rad(rng.randf_range(34.0, 46.0))
		var part := frond(
			length * rng.randf_range(0.88, 1.08),
			width * rng.randf_range(0.92, 1.10),
			length * 0.20,
			droop * (1.35 if lower else 1.0),
			seed * 31 + i,
		)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)
		var part_verts: Array[Vector3] = part["verts"]
		var part_tris: Array[Vector3i] = part["tris"]
		if lower:
			append(light_acc, part_verts, part_tris, Transform3D(basis, Vector3.ZERO))
		else:
			append(main_acc, part_verts, part_tris, Transform3D(basis, Vector3.ZERO))
	return {"main": main_acc, "light": light_acc}


## Ciuffo di foglie larghe (felci, piante tropicali a terra) attorno alla base.
static func leaf_fan(
	seed: int,
	count: int,
	length: float,
	width: float,
	rise: float,
) -> Dictionary:
	var acc := new_accumulator()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 613 + 5
	for i in count:
		var yaw := TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var pitch := deg_to_rad(rng.randf_range(18.0, 52.0))
		var part := frond(
			length * rng.randf_range(0.75, 1.15),
			width * rng.randf_range(0.85, 1.2),
			rise,
			length * 0.42,
			seed * 17 + i,
			0.14,
			6,
		)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)
		var part_verts: Array[Vector3] = part["verts"]
		var part_tris: Array[Vector3i] = part["tris"]
		append(acc, part_verts, part_tris, Transform3D(basis, Vector3.ZERO))
	return acc


# ------------------------------------------------------------------ Blocchi ---

## Scatola smussata: spigoli vivi ma con un piccolo smusso, per una lettura
## "giocattolo" anche negli oggetti costruiti (pali, cartelli, casotti).
static func beveled_box(size: Vector3, bevel: float = 0.04) -> Dictionary:
	var half := size * 0.5
	var b := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.9)
	var verts: Array[Vector3] = []
	var tris: Array[Vector3i] = []
	# Sei facce, ognuna con quattro vertici interni smussati.
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for axis: Vector3 in axes:
		var normal := axis
		var u := Vector3(0.0, 1.0, 0.0) if absf(normal.y) < 0.9 else Vector3(1.0, 0.0, 0.0)
		var v := normal.cross(u).normalized()
		u = v.cross(normal).normalized()
		var center := normal * (half * Vector3(absf(normal.x), absf(normal.y), absf(normal.z)))
		var inner := Vector3(size.x - b * 2.0, size.y - b * 2.0, size.z - b * 2.0) * 0.5
		var base := verts.size()
		var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		for corner in corners:
			var offset := u * corner.x * (inner.dot(Vector3(absf(u.x), absf(u.y), absf(u.z))))
			offset += v * corner.y * (inner.dot(Vector3(absf(v.x), absf(v.y), absf(v.z))))
			verts.append(center + offset)
		tris.append(Vector3i(base, base + 1, base + 2))
		tris.append(Vector3i(base, base + 2, base + 3))
	# Fasce di raccordo sugli spigoli: chiudono la scatola senza buchi.
	for axis in 3:
		for sign: float in [-1.0, 1.0]:
			for other in 3:
				if other == axis:
					continue
				for other_sign: float in [-1.0, 1.0]:
					var a := Vector3.ZERO
					var c := Vector3.ZERO
					var normal_a := Vector3.ZERO
					var normal_c := Vector3.ZERO
					a[axis] = half[axis] * sign
					c[axis] = half[axis] * sign
					a[other] = half[other] * other_sign
					c[other] = half[other] * other_sign
					normal_a[axis] = sign
					normal_c[other] = other_sign
					var third := 3 - axis - other
					var p1 := a
					var p2 := a
					p1[third] = -half[third] + b
					p2[third] = half[third] - b
					var q1 := c
					var q2 := c
					q1[third] = -half[third] + b
					q2[third] = half[third] - b
					q1[axis] -= b * sign
					q2[axis] -= b * sign
					var base := verts.size()
					verts.append_array([p1, p2, q2, q1])
					tris.append(Vector3i(base, base + 1, base + 2))
					tris.append(Vector3i(base, base + 2, base + 3))
	return {"verts": verts, "tris": tris}


## Cilindro verticale (pali, tronchi dritti, piedini).
static func cylinder(
	bottom: float,
	top: float,
	radius_bottom: float,
	radius_top: float,
	sides: int = 8,
) -> Dictionary:
	return tube(
		[Vector3(0.0, bottom, 0.0), Vector3(0.0, top, 0.0)],
		[radius_bottom, radius_top],
		sides,
		true,
		0,
	)


# ------------------------------------------------- Colore per vertice -------

## Unisce più parti colorate in un'unica mesh con colore per vertice: cordoli,
## strisce e dettagli dipinti costano così un solo draw call per segmento.
## `parts` è un array di dizionari {"acc": accumulatore, "color": Color,
## "xform": Transform3D (opzionale)}.
static func merged_colored(parts: Array, smooth: bool = true) -> ArrayMesh:
	var verts: Array[Vector3] = []
	var colors: Array[Color] = []
	var tris: Array[Vector3i] = []
	for entry in parts:
		var part: Dictionary = entry
		var acc: Dictionary = part["acc"]
		var color: Color = part["color"]
		var xform := Transform3D.IDENTITY
		if part.has("xform"):
			xform = part["xform"] as Transform3D
		var part_verts: Array[Vector3] = acc["verts"]
		var part_tris: Array[Vector3i] = acc["tris"]
		var offset := verts.size()
		for vertex in part_verts:
			verts.append(xform * vertex)
			colors.append(color)
		for tri in part_tris:
			tris.append(tri + Vector3i(offset, offset, offset))
	if verts.is_empty() or tris.is_empty():
		return ArrayMesh.new()
	if not smooth:
		return _flat_colored(verts, colors, tris)
	var normals := _smooth_normals(verts, tris)
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	var index_array := PackedInt32Array()
	for tri in tris:
		index_array.append_array([tri.x, tri.y, tri.z])
	var color_array := PackedColorArray(colors)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = color_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _flat_colored(
	verts: Array[Vector3], colors: Array[Color], tris: Array[Vector3i]
) -> ArrayMesh:
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_colors := PackedColorArray()
	var indices := PackedInt32Array()
	for tri in tris:
		var a := verts[tri.x]
		var b := verts[tri.y]
		var c := verts[tri.z]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		var start := out_verts.size()
		out_verts.append_array([a, b, c])
		out_normals.append_array([normal, normal, normal])
		out_colors.append_array([colors[tri.x], colors[tri.y], colors[tri.z]])
		indices.append_array([start, start + 1, start + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_verts
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_COLOR] = out_colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _smooth_normals(verts: Array[Vector3], tris: Array[Vector3i]) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for tri in tris:
		var a := verts[tri.x]
		var b := verts[tri.y]
		var c := verts[tri.z]
		var face := (b - a).cross(c - a)
		normals[tri.x] = normals[tri.x] + face
		normals[tri.y] = normals[tri.y] + face
		normals[tri.z] = normals[tri.z] + face
	for i in normals.size():
		var n := normals[i]
		normals[i] = n.normalized() if n.length_squared() > 0.000001 else Vector3.UP
	return normals
