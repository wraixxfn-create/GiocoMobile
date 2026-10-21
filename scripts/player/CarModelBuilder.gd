class_name CarModelBuilder
extends RefCounted
## Costruisce il modello visivo di UNO stadio dell'auto con mesh procedurali
## scolpite (`CarBodyFactory`), senza asset esterni.
##
## Il modello non è un assemblaggio di cubi: scocca e abitacolo sono loft di
## sezioni trasversali guidati da curve di progetto (linea del cofano, cintura,
## spalle dei parafanghi, passaruota veri), le ruote sono lathe con
## pneumatico, cerchio a razze e mozzo, e i dettagli (fari, paraurti,
## specchietti, maniglie, spoiler) sono parti distinte e nominate.
##
## Ogni silhouette ha il suo "blueprint" (curve e opzioni): a parità di
## costruzione cambiano proporzioni, volumi e carattere:
##   0 rottame · 1 utilitaria · 2 berlina · 3 sportiva · 4 supercar · 5 hypercar
##
## Gerarchia prodotta (pivot corretti per animare e sostituire le parti):
##   Stage_N
##   ├─ Body            (scocca, abitacolo, dettagli fissi, spie)
##   ├─ Wheel0..Wheel3  (perni ruota: rotazione x = rotolamento, y = sterzo)
##
## Questo file resta l'unico da sostituire/ignorare quando arriveranno
## modelli esterni (via `CarEvolutionProfile.model_scene` o
## `CarModelLibrary`): la logica di evoluzione non lo conosce direttamente.

const PIP_SIZE := Vector3(0.13, 0.06, 0.24)
const PIP_SPACING: float = 0.22

## Chiavi del dizionario restituito da `build()`.
const KEY_ROOT: String = "root"
const KEY_WHEELS: String = "wheels"
const KEY_BODY_MESHES: String = "body_meshes"
const KEY_PIPS: String = "pips"
const KEY_GLOW_MATERIALS: String = "glow_materials"

const BUCKET_PAINT: String = "paint"
const BUCKET_TRIM: String = "trim"
const BUCKET_GLASS: String = "glass"

## Mezza-sezione della scocca (xf, yf) da (0,0) a (0,1): fondo piatto,
## fianchi pieni, spalla alta e colmo arrotondato.
const BODY_SECTION: Array = [
	Vector2(0.00, 0.00), Vector2(0.55, 0.00), Vector2(0.84, 0.015),
	Vector2(0.98, 0.09), Vector2(1.00, 0.30), Vector2(1.00, 0.55),
	Vector2(0.985, 0.72), Vector2(0.93, 0.86), Vector2(0.78, 0.95),
	Vector2(0.50, 0.995), Vector2(0.00, 1.00),
]
## Mezza-sezione dell'abitacolo: tumblehome marcato verso il tetto.
const GLASS_SECTION: Array = [
	Vector2(0.00, 0.00), Vector2(0.60, 0.00), Vector2(0.92, 0.03),
	Vector2(1.00, 0.14), Vector2(0.99, 0.34), Vector2(0.94, 0.55),
	Vector2(0.85, 0.72), Vector2(0.68, 0.86), Vector2(0.40, 0.96),
	Vector2(0.00, 1.00),
]


## Costruisce lo stadio e restituisce i riferimenti che servono al direttore:
## radice del modello, perni delle ruote, mesh di carrozzeria, spie e
## materiali luminosi (istanze uniche, animate durante la trasformazione).
static func build(profile: CarEvolutionProfile) -> Dictionary:
	var bp := _blueprint_for(profile.silhouette)
	var materials := _make_materials(profile)
	var glow: Array = []
	var pips: Array = []

	var root := Node3D.new()
	root.name = "Stage_%d" % profile.level
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var length := profile.body_length
	var belt := profile.roof_height * float(bp["belt_f"])
	var ctx := {
		"profile": profile,
		"bp": bp,
		"m": materials,
		"glow": glow,
		"body": body,
		"length": length,
		"hw": profile.body_width * 0.5,
		"belt": belt,
		"sill": maxf(profile.ride_height - float(bp["sill_drop"]), 0.09),
		"crown": 2.0 * profile.wheel_radius + float(bp["arch_gap"]),
		"nose_z": -length * 0.5 - 0.03,
		"tail_z": length * 0.5 + 0.03,
		"nose_top": _top_at(bp, length, belt, -length * 0.5 + 0.055 * length),
		"tail_top": _top_at(bp, length, belt, -length * 0.5 + 0.96 * length),
	}

	_build_shell(ctx)
	var wheels := _add_wheels(ctx, root)
	_add_details(ctx)
	_add_pips(ctx, pips)

	return {
		KEY_ROOT: root,
		KEY_WHEELS: wheels,
		KEY_BODY_MESHES: _collect_body_meshes(root, materials["body"] as Material),
		KEY_PIPS: pips,
		KEY_GLOW_MATERIALS: _collect_glow_materials(glow),
	}


# ---------------------------------------------------------------- Blueprint --
##
## Curve in coordinate normalizzate: `zn` 0 = muso, 1 = coda; le altezze della
## scocca sono frazioni della linea di cintura, quelle dell'abitacolo del
## tetto; le larghezze sono frazioni della mezza larghezza carrozzeria.
## Le proporzioni assolute (lunghezza, ruote, ingombri) vengono dal profilo:
## il blueprint è il "carattere" della silhouette, il profilo la scala.

static func _blueprint_for(silhouette: int) -> Dictionary:
	var bp := {
		"belt_f": 0.71,
		"sill_drop": 0.085,
		"body_top": [
			Vector2(0.00, 0.66), Vector2(0.05, 0.77), Vector2(0.14, 0.91),
			Vector2(0.30, 1.00), Vector2(0.55, 1.00), Vector2(0.80, 0.99),
			Vector2(0.95, 0.96), Vector2(1.00, 0.88),
		],
		"body_w": [
			Vector2(0.00, 0.74), Vector2(0.05, 0.90), Vector2(0.14, 1.00),
			Vector2(0.32, 0.98), Vector2(0.55, 0.99), Vector2(0.80, 1.03),
			Vector2(0.93, 0.98), Vector2(1.00, 0.82),
		],
		"glass_span": Vector2(0.25, 0.87),
		"roof_range": Vector2(0.30, 0.75),
		"glass_top": [
			Vector2(0.00, 0.68), Vector2(0.16, 0.93), Vector2(0.30, 0.99),
			Vector2(0.55, 1.00), Vector2(0.75, 0.98), Vector2(0.90, 0.85),
			Vector2(1.00, 0.68),
		],
		"glass_w": [
			Vector2(0.00, 0.80), Vector2(0.20, 0.84), Vector2(0.55, 0.85),
			Vector2(0.85, 0.82), Vector2(1.00, 0.77),
		],
		"glass_bottom_f": 0.84,
		"pillars_b": Vector2(0.46, 0.53),
		"pillars_c": Vector2(0.80, 0.95),
		"roof_split": 0.80,
		"a_pillars": true,
		"clad_split": 0.20,
		"arch_gap": 0.05,
		"arch_flare": "trim",
		"light_style": "round",
		"spoiler": "lip",
		"bumper": "paint",
		"exhausts": 1,
		"spare_roof": false,
		"mirrors_painted": false,
		"steel_wheels": false,
		"nose_intake": true,
		"roof_rails": false,
	}
	match silhouette:
		CarEvolutionProfile.Silhouette.WRECK:
			bp.merge({
				"belt_f": 0.66,
				"body_top": [
					Vector2(0.00, 0.78), Vector2(0.06, 0.88), Vector2(0.16, 0.96),
					Vector2(0.32, 1.00), Vector2(0.55, 1.00), Vector2(0.80, 1.00),
					Vector2(0.95, 0.98), Vector2(1.00, 0.92),
				],
				"glass_span": Vector2(0.26, 0.84),
				"roof_range": Vector2(0.22, 0.82),
				"glass_top": [
					Vector2(0.00, 0.66), Vector2(0.10, 0.93), Vector2(0.22, 0.99),
					Vector2(0.55, 1.00), Vector2(0.82, 0.99), Vector2(0.94, 0.88),
					Vector2(1.00, 0.66),
				],
				"glass_w": [
					Vector2(0.00, 0.88), Vector2(0.20, 0.90), Vector2(0.55, 0.90),
					Vector2(0.85, 0.88), Vector2(1.00, 0.84),
				],
				"pillars_c": Vector2(0.86, 0.96),
				"clad_split": 0.13,
				"spoiler": "none",
				"spare_roof": true,
				"steel_wheels": true,
				"arch_flare": "none",
				"roof_rails": true,
				"bumper": "trim",
			}, true)
		CarEvolutionProfile.Silhouette.SEDAN:
			bp.merge({
				"belt_f": 0.65,
				"body_top": [
					Vector2(0.00, 0.74), Vector2(0.05, 0.84), Vector2(0.14, 0.94),
					Vector2(0.30, 1.00), Vector2(0.55, 1.00), Vector2(0.78, 1.01),
					Vector2(0.92, 1.02), Vector2(1.00, 0.94),
				],
				"glass_span": Vector2(0.26, 0.68),
				"roof_range": Vector2(0.34, 0.76),
				"glass_top": [
					Vector2(0.00, 0.64), Vector2(0.18, 0.94), Vector2(0.34, 0.99),
					Vector2(0.58, 1.00), Vector2(0.76, 0.96), Vector2(0.90, 0.80),
					Vector2(1.00, 0.64),
				],
				"glass_bottom_f": 0.80,
				"pillars_c": Vector2(0.78, 0.92),
				"clad_split": 0.12,
				"arch_flare": "none",
				"spoiler": "none",
				"mirrors_painted": true,
				"exhausts": 2,
			}, true)
		CarEvolutionProfile.Silhouette.COUPE:
			bp.merge({
				"belt_f": 0.70,
				"body_top": [
					Vector2(0.00, 0.66), Vector2(0.05, 0.78), Vector2(0.15, 0.90),
					Vector2(0.34, 0.98), Vector2(0.55, 1.00), Vector2(0.80, 1.02),
					Vector2(0.95, 0.99), Vector2(1.00, 0.92),
				],
				"body_w": [
					Vector2(0.00, 0.76), Vector2(0.05, 0.90), Vector2(0.15, 0.99),
					Vector2(0.32, 0.97), Vector2(0.55, 0.99), Vector2(0.80, 1.04),
					Vector2(0.93, 1.00), Vector2(1.00, 0.86),
				],
				"glass_span": Vector2(0.30, 0.86),
				"roof_range": Vector2(0.36, 0.54),
				"glass_top": [
					Vector2(0.00, 0.62), Vector2(0.20, 0.94), Vector2(0.36, 1.00),
					Vector2(0.52, 0.99), Vector2(0.72, 0.92), Vector2(0.90, 0.76),
					Vector2(1.00, 0.62),
				],
				"glass_w": [
					Vector2(0.00, 0.78), Vector2(0.20, 0.82), Vector2(0.55, 0.82),
					Vector2(0.85, 0.78), Vector2(1.00, 0.72),
				],
				"pillars_c": Vector2(0.70, 0.94),
				"clad_split": 0.14,
				"arch_flare": "paint",
				"light_style": "slim",
				"spoiler": "lip",
				"mirrors_painted": true,
				"exhausts": 2,
				"bumper": "split",
			}, true)
		CarEvolutionProfile.Silhouette.SUPERCAR:
			bp.merge({
				"belt_f": 0.68,
				"body_top": [
					Vector2(0.00, 0.58), Vector2(0.05, 0.72), Vector2(0.15, 0.88),
					Vector2(0.34, 0.97), Vector2(0.55, 1.00), Vector2(0.80, 1.03),
					Vector2(0.95, 1.00), Vector2(1.00, 0.94),
				],
				"body_w": [
					Vector2(0.00, 0.78), Vector2(0.05, 0.90), Vector2(0.15, 0.99),
					Vector2(0.32, 0.96), Vector2(0.55, 0.99), Vector2(0.80, 1.05),
					Vector2(0.93, 1.01), Vector2(1.00, 0.88),
				],
				"glass_span": Vector2(0.26, 0.68),
				"roof_range": Vector2(0.44, 0.62),
				"glass_top": [
					Vector2(0.00, 0.60), Vector2(0.24, 0.95), Vector2(0.44, 1.00),
					Vector2(0.62, 0.97), Vector2(0.82, 0.84), Vector2(1.00, 0.60),
				],
				"glass_w": [
					Vector2(0.00, 0.76), Vector2(0.25, 0.80), Vector2(0.55, 0.80),
					Vector2(0.85, 0.76), Vector2(1.00, 0.70),
				],
				"pillars_b": Vector2(0.50, 0.56),
				"pillars_c": Vector2(0.74, 0.96),
				"clad_split": 0.16,
				"arch_flare": "paint",
				"light_style": "slim",
				"spoiler": "wing",
				"mirrors_painted": true,
				"exhausts": 2,
				"bumper": "split",
			}, true)
		CarEvolutionProfile.Silhouette.HYPERCAR:
			bp.merge({
				"belt_f": 0.64,
				"body_top": [
					Vector2(0.00, 0.54), Vector2(0.05, 0.70), Vector2(0.15, 0.86),
					Vector2(0.34, 0.96), Vector2(0.55, 1.00), Vector2(0.80, 1.04),
					Vector2(0.95, 1.01), Vector2(1.00, 0.95),
				],
				"body_w": [
					Vector2(0.00, 0.78), Vector2(0.05, 0.90), Vector2(0.15, 0.99),
					Vector2(0.32, 0.95), Vector2(0.55, 0.98), Vector2(0.80, 1.05),
					Vector2(0.93, 1.01), Vector2(1.00, 0.88),
				],
				"glass_span": Vector2(0.24, 0.70),
				"roof_range": Vector2(0.48, 0.66),
				"glass_top": [
					Vector2(0.00, 0.58), Vector2(0.26, 0.96), Vector2(0.48, 1.00),
					Vector2(0.66, 0.96), Vector2(0.86, 0.82), Vector2(1.00, 0.58),
				],
				"glass_w": [
					Vector2(0.00, 0.74), Vector2(0.25, 0.78), Vector2(0.55, 0.78),
					Vector2(0.85, 0.74), Vector2(1.00, 0.66),
				],
				"pillars_b": Vector2(0.52, 0.58),
				"pillars_c": Vector2(0.76, 0.97),
				"roof_split": 0.86,
				"a_pillars": false,
				"clad_split": 0.20,
				"arch_flare": "paint",
				"light_style": "bar",
				"spoiler": "wing",
				"mirrors_painted": true,
				"exhausts": 2,
				"bumper": "split",
			}, true)
	return bp


# ------------------------------------------------------------- Curve pure ----

## Altezza del colmo della scocca (centrale) alla coordinata z.
static func _top_at(bp: Dictionary, length: float, belt: float, z: float) -> float:
	var zn := clampf((z + length * 0.5) / length, 0.0, 1.0)
	return belt * CarBodyFactory.catmull_rom_1d(bp["body_top"], zn)


## Mezza larghezza della scocca alla coordinata z.
static func _half_width_at(bp: Dictionary, length: float, hw: float, z: float) -> float:
	var zn := clampf((z + length * 0.5) / length, 0.0, 1.0)
	return hw * CarBodyFactory.catmull_rom_1d(bp["body_w"], zn)


## Sollevamento della spalla del parafango: quanto serve a coprire il
## passaruota se la curva del colmo è più bassa (auto sportive), zero altrove.
static func _fender_lift_at(
	bp: Dictionary, profile: CarEvolutionProfile, belt: float, crown: float, z: float
) -> float:
	var need := maxf((crown + 0.05) - _top_at(bp, profile.body_length, belt, z), 0.0)
	if need <= 0.0:
		return 0.0
	var half := profile.wheel_radius * 1.45
	var lift := 0.0
	for wz: float in [-profile.wheel_base_z, profile.wheel_base_z]:
		var dz := absf(z - wz)
		if dz < half:
			var shape := 0.5 + 0.5 * cos(PI * dz / half)
			lift = maxf(lift, need * shape)
	return lift


## Fondo del passaruota alla coordinata z: arco di cerchio che nasce dal
## pianale e culmina a `crown` sopra il centro ruota.
static func _arch_circle_bottom(
	profile: CarEvolutionProfile, arch_gap: float, z: float, base_bottom: float
) -> float:
	var crown := 2.0 * profile.wheel_radius + arch_gap
	var h := profile.wheel_radius * 1.5
	var rise := maxf(crown - base_bottom, 0.05)
	var radius := (h * h + rise * rise) / (2.0 * rise)
	var center_y := crown - radius
	var bottom := base_bottom
	for wz: float in [-profile.wheel_base_z, profile.wheel_base_z]:
		var dz := absf(z - wz)
		if dz < h:
			bottom = maxf(bottom, center_y + sqrt(maxf(radius * radius - dz * dz, 0.0)))
	return bottom


# ------------------------------------------------------------------- Scocca --

## Loft di scocca e abitacolo, con le fasce materiali ricavate dagli stessi
## loft: rivestimento scuro in basso, vernice sopra; tetto e montanti in
## vernice, resto in vetro.
static func _build_shell(ctx: Dictionary) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var body: Node3D = ctx["body"]
	var length: float = ctx["length"]
	var hw: float = ctx["hw"]
	var belt: float = ctx["belt"]
	var sill: float = ctx["sill"]
	var crown: float = ctx["crown"]
	var arch_gap := float(bp["arch_gap"])

	# Stazioni della scocca: maglia fitta intorno ai passaruota.
	var zn_set := {}
	for i in 29:
		zn_set[float(i) / 28.0] = true
	for wz: float in [-profile.wheel_base_z, profile.wheel_base_z]:
		var wzn: float = (wz + length * 0.5) / length
		for k in range(-4, 5):
			zn_set[clampf(wzn + float(k) * 0.02, 0.0, 1.0)] = true
	zn_set[0.012] = true
	zn_set[0.988] = true
	var zn_list := zn_set.keys()
	zn_list.sort()

	var bottom_base := [
		Vector2(0.0, sill + 0.10), Vector2(0.08, sill + 0.03), Vector2(0.20, sill),
		Vector2(0.80, sill), Vector2(0.93, sill + 0.03), Vector2(1.0, sill + 0.11),
	]
	var stations: Array = []
	for zn in zn_list:
		var z := -length * 0.5 + float(zn) * length
		var base := CarBodyFactory.catmull_rom_1d(bottom_base, float(zn))
		stations.append({
			"z": z,
			"hw": _half_width_at(bp, length, hw, z),
			"bottom": base,
			"top": _top_at(bp, length, belt, z),
			"arch": _arch_circle_bottom(profile, arch_gap, z, base) - base,
			"fender": _fender_lift_at(bp, profile, belt, crown, z),
		})

	var clad_split := float(bp["clad_split"])
	var body_bucket := func(_i: int, _j: int, pa: Vector2, pb: Vector2, _z: float) -> String:
		return BUCKET_TRIM if 0.5 * (pa.y + pb.y) < clad_split else BUCKET_PAINT
	var shell := CarBodyFactory.build_loft(stations, BODY_SECTION, 12, body_bucket)
	body.add_child(_instance("BodyPaint", _bucket_mesh(shell, BUCKET_PAINT), m["body"]))
	body.add_child(_instance("BodyTrim", _bucket_mesh(shell, BUCKET_TRIM), m["trim"]))

	# Abitacolo: loft vetrato con tetto e montanti verniciati. La base è
	# affondata nella scocca, così la giunzione non si vede mai.
	var span: Vector2 = bp["glass_span"]
	var g0 := span.x
	var g1 := span.y
	var roof_range: Vector2 = bp["roof_range"]
	var pillars_b: Vector2 = bp["pillars_b"]
	var pillars_c: Vector2 = bp["pillars_c"]
	var gt_set := {}
	for i in 21:
		gt_set[float(i) / 20.0] = true
	for edge: float in [pillars_b.x, pillars_b.y, pillars_c.x, pillars_c.y, roof_range.x, roof_range.y]:
		gt_set[edge] = true
	var gt_list := gt_set.keys()
	gt_list.sort()

	var glass_bottom := belt * float(bp["glass_bottom_f"])
	var gstations: Array = []
	for gt in gt_list:
		var zn := g0 + float(gt) * (g1 - g0)
		gstations.append({
			"z": -length * 0.5 + zn * length,
			"hw": hw * CarBodyFactory.catmull_rom_1d(bp["glass_w"], float(gt)),
			"bottom": glass_bottom,
			"top": profile.roof_height * CarBodyFactory.catmull_rom_1d(bp["glass_top"], float(gt)),
		})

	var roof_split := float(bp["roof_split"])
	var a_pillars := bool(bp["a_pillars"])
	var glass_bucket := func(_i: int, _j: int, pa: Vector2, pb: Vector2, z_mid: float) -> String:
		var yf := 0.5 * (pa.y + pb.y)
		var gt := ((z_mid + length * 0.5) / length - g0) / maxf(g1 - g0, 0.000001)
		# Vernice sul colmo solo nel tratto piano: parabrezza e lunotto
		# restano vetro pieno (effetto "a bolla" moderno).
		if yf >= roof_split and gt >= roof_range.x and gt <= roof_range.y:
			return BUCKET_PAINT
		# Montanti A ai bordi del parabrezza.
		if a_pillars and gt < roof_range.x and yf >= 0.54 and yf <= 0.66:
			return BUCKET_PAINT
		if gt >= pillars_b.x and gt <= pillars_b.y and yf > 0.06:
			return BUCKET_PAINT
		if gt >= pillars_c.x and gt <= pillars_c.y and yf > 0.06:
			return BUCKET_PAINT
		return BUCKET_GLASS
	var cabin := CarBodyFactory.build_loft(gstations, GLASS_SECTION, 11, glass_bucket)
	body.add_child(_instance("CabinGlass", _bucket_mesh(cabin, BUCKET_GLASS), m["glass"]))
	if cabin.has(BUCKET_PAINT):
		body.add_child(_instance("CabinPaint", _bucket_mesh(cabin, BUCKET_PAINT), m["body"]))


# -------------------------------------------------------------------- Ruote --

## Quattro perni (prima le due anteriori, poi le posteriori) con pozzi e
## profili passaruota. Il perno è il nodo che il CarController fa ruotare su
## X (rotolamento) e, per le anteriori, sterza su Y: deve restare con
## rotazione identità a riposo, la specchiatura è nella geometria.
static func _add_wheels(ctx: Dictionary, root: Node3D) -> Array[Node3D]:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var body: Node3D = ctx["body"]
	var wheels: Array[Node3D] = []
	var radius := profile.wheel_radius
	var positions: Array = [
		[Vector3(-profile.wheel_base_x, radius, -profile.wheel_base_z), -1.0, profile.wheel_width],
		[Vector3(profile.wheel_base_x, radius, -profile.wheel_base_z), 1.0, profile.wheel_width],
		[Vector3(-profile.wheel_base_x, radius, profile.wheel_base_z), -1.0, profile.rear_wheel_width],
		[Vector3(profile.wheel_base_x, radius, profile.wheel_base_z), 1.0, profile.rear_wheel_width],
	]
	var names := ["FL", "FR", "RL", "RR"]
	for index in positions.size():
		var entry: Array = positions[index]
		var pos: Vector3 = entry[0]
		var side: float = entry[1]
		var width: float = entry[2]
		var pivot := _build_wheel(ctx, width, side)
		pivot.name = "Wheel%d" % index
		pivot.position = pos
		root.add_child(pivot)
		wheels.append(pivot)

		# Pozzo ruota scuro: chiude la vista attraverso il passaruota.
		var well_radius := radius + float(bp["arch_gap"]) * 0.55
		body.add_child(_instance(
			"Well" + names[index],
			_cylinder_mesh(well_radius, well_radius, 0.03, 20),
			m["well"],
			Vector3(pos.x - side * (width * 0.5 + 0.045), radius, pos.z),
			Vector3(0.0, 0.0, 90.0),
		))
		# Profilo del passaruota: arco sagomato sul labbro della scocca.
		if String(bp["arch_flare"]) != "none":
			var flare_material: Material = (
				m["trim"] if String(bp["arch_flare"]) == "trim" else m["body"]
			)
			var hw_at := _half_width_at(bp, profile.body_length, ctx["hw"], pos.z)
			body.add_child(_instance(
				"Arch" + names[index],
				CarBodyFactory.build_torus_arc(radius + 0.075, 0.035, 24, 9, 212.0),
				flare_material,
				Vector3(side * (hw_at - 0.006), radius, pos.z),
				Vector3(0.0, 90.0, 0.0),
			))
	return wheels


## Una ruota completa centrata sull'origine: pneumatico tornito con spalle
## arrotondate, barile scuro, cerchio con anello, cinque razze e mozzo
## (oppure cerchio in acciaio pieno per il rottame). Faccia esterna +X*side.
static func _build_wheel(ctx: Dictionary, width: float, side: float) -> Node3D:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var radius := profile.wheel_radius
	var pivot := Node3D.new()

	var tire_profile := [
		Vector2(-0.42 * width, 0.58 * radius), Vector2(-0.50 * width, 0.74 * radius),
		Vector2(-0.50 * width, 0.87 * radius), Vector2(-0.44 * width, 0.955 * radius),
		Vector2(-0.28 * width, 0.995 * radius), Vector2(0.0, 1.00 * radius),
		Vector2(0.28 * width, 0.995 * radius), Vector2(0.44 * width, 0.955 * radius),
		Vector2(0.50 * width, 0.87 * radius), Vector2(0.50 * width, 0.74 * radius),
		Vector2(0.42 * width, 0.58 * radius),
	]
	pivot.add_child(_instance(
		"Tire", CarBodyFactory.build_lathe_x(tire_profile, 24, side), m["tire"]
	))
	var barrel_profile := [
		Vector2(-0.44 * width, 0.60 * radius), Vector2(0.40 * width, 0.60 * radius),
	]
	pivot.add_child(_instance(
		"RimBarrel", CarBodyFactory.build_lathe_x(barrel_profile, 20, side), m["trim"]
	))

	if bool(bp["steel_wheels"]):
		pivot.add_child(_instance(
			"RimFace", _cylinder_mesh(0.56 * radius, 0.56 * radius, 0.03, 20), m["rim"],
			Vector3(side * (width * 0.5 - 0.028), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		))
		pivot.add_child(_instance(
			"Hub", _cylinder_mesh(0.17 * radius, 0.17 * radius, 0.05, 12), m["trim"],
			Vector3(side * (width * 0.5 - 0.02), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		))
	else:
		var lip := TorusMesh.new()
		lip.inner_radius = 0.505 * radius
		lip.outer_radius = 0.605 * radius
		lip.rings = 24
		lip.ring_segments = 10
		pivot.add_child(_instance(
			"RimLip", lip, m["rim"],
			Vector3(side * (width * 0.5 - 0.022), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		))
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(0.045, 0.50 * radius, 0.21 * radius)
		for k in 5:
			var angle := deg_to_rad(float(k) * 72.0)
			var off := 0.30 * radius
			pivot.add_child(_instance(
				"Spoke%d" % k, spoke_mesh, m["rim"],
				Vector3(side * (width * 0.5 - 0.030), off * cos(angle), off * sin(angle)),
				Vector3(rad_to_deg(angle), 0.0, 0.0),
			))
		pivot.add_child(_instance(
			"Hub", _cylinder_mesh(0.17 * radius, 0.19 * radius, 0.055, 14), m["rim"],
			Vector3(side * (width * 0.5 - 0.030), 0.0, 0.0),
			Vector3(0.0, 0.0, 90.0 * side),
		))
		pivot.add_child(_instance(
			"HubCap", _cylinder_mesh(0.085 * radius, 0.085 * radius, 0.02, 12), m["trim_alt"],
			Vector3(side * (width * 0.5 + 0.002), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		))
	return pivot


# ----------------------------------------------------------------- Dettagli --

## Fari, fanali, paraurti, presa d'aria, specchietti, maniglie, scarichi,
## pinna, spoiler/alettone, ruota di scorta e barre sul tetto: tutto ciò che
## rende l'auto "progettata" invece che un semplice volume.
static func _add_details(ctx: Dictionary) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var glow: Array = ctx["glow"]
	var body: Node3D = ctx["body"]
	var length: float = ctx["length"]
	var hw: float = ctx["hw"]
	var belt: float = ctx["belt"]
	var sill: float = ctx["sill"]
	var nose_z: float = ctx["nose_z"]
	var tail_z: float = ctx["tail_z"]
	var nose_top: float = ctx["nose_top"]
	var tail_top: float = ctx["tail_top"]
	var sides: Array[float] = [-1.0, 1.0]

	# Fari anteriori: guscio scuro + lente emissiva, ancorati alla spalla
	# del muso. La hypercar usa una barra luminosa continua.
	var head_material := MaterialFactory.unique_emissive(profile.headlight_color, 1.4)
	var tail_material := MaterialFactory.unique_emissive(profile.taillight_color, 1.3)
	if String(bp["light_style"]) == "bar":
		var bar := _instance(
			"HeadBar", CarBodyFactory.build_capsule(0.045, hw * 1.24), head_material,
			Vector3(0.0, nose_top - 0.010, nose_z - 0.005), Vector3(0.0, 0.0, 90.0),
			Vector3(1.0, 1.0, 0.7),
		)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(bar)
		glow.append(bar)
	else:
		var slim := String(bp["light_style"]) == "slim"
		var housing_mesh := _sphere_mesh(0.115)
		var lens_mesh := _sphere_mesh(0.100)
		for side in sides:
			var suffix := "L" if side < 0.0 else "R"
			var tilt := side * (10.0 if slim else 0.0)
			body.add_child(_instance(
				"HeadlightHousing" + suffix, housing_mesh, m["trim"],
				Vector3(side * hw * 0.62, nose_top - 0.015, nose_z + 0.070),
				Vector3(-10.0, side * -14.0, tilt),
				Vector3(1.30, 0.50 if slim else 0.72, 0.55),
			))
			var lens := _instance(
				"Headlight" + suffix, lens_mesh, head_material,
				Vector3(side * hw * 0.62, nose_top - 0.015, nose_z + 0.042),
				Vector3(-10.0, side * -14.0, tilt),
				Vector3(1.26, 0.42 if slim else 0.62, 0.5),
			)
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(lens)
			glow.append(lens)

	# Fanali posteriori ancorati alla spalla della coda.
	if String(bp["light_style"]) == "bar":
		var tail_bar := _instance(
			"TailBar", CarBodyFactory.build_capsule(0.04, hw * 1.30), tail_material,
			Vector3(0.0, tail_top * 0.94, tail_z + 0.012), Vector3(0.0, 0.0, 90.0),
			Vector3(1.0, 1.0, 0.7),
		)
		tail_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(tail_bar)
		glow.append(tail_bar)
	else:
		var tail_mesh := CarBodyFactory.build_capsule(0.062, 0.20)
		for side in sides:
			var suffix := "L" if side < 0.0 else "R"
			var tail := _instance(
				"Taillight" + suffix, tail_mesh, tail_material,
				Vector3(side * hw * 0.58, tail_top * 0.92, tail_z - 0.055),
				Vector3(0.0, side * 14.0, 90.0), Vector3(1.0, 1.0, 0.62),
			)
			tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(tail)
			glow.append(tail)

	# Paraurti: barre tondeggianti incassate nel rivestimento inferiore;
	# in tinta sulle auto "civili", splitter scuri e sottili sulle sportive.
	var bumper_style := String(bp["bumper"])
	var bumper_material: Material = m["body"] if bumper_style == "paint" else m["trim"]
	var bumper_radius := 0.062 if bumper_style == "split" else 0.088
	var bumper_mesh := CarBodyFactory.build_capsule(bumper_radius, hw * 1.52)
	body.add_child(_instance(
		"BumperFront", bumper_mesh, bumper_material,
		Vector3(0.0, sill + 0.115, nose_z + 0.055), Vector3(0.0, 0.0, 90.0),
		Vector3(1.0, 0.80, 0.62),
	))
	body.add_child(_instance(
		"BumperRear", bumper_mesh, bumper_material,
		Vector3(0.0, sill + 0.125, tail_z - 0.055), Vector3(0.0, 0.0, 90.0),
		Vector3(1.0, 0.80, 0.62),
	))

	# Presa d'aria anteriore con distintivo centrale.
	if bool(bp["nose_intake"]):
		body.add_child(_instance(
			"Intake", CarBodyFactory.build_capsule(0.080, hw * 0.92), m["trim"],
			Vector3(0.0, belt * 0.60, nose_z + 0.028), Vector3(-8.0, 0.0, 90.0),
			Vector3(1.0, 0.82, 0.5),
		))
		body.add_child(_instance(
			"Badge", _cylinder_mesh(0.046, 0.046, 0.026, 16), m["rim"],
			Vector3(0.0, belt * 0.60, nose_z - 0.006), Vector3(90.0, 0.0, 0.0),
		))

	# Pannello scuro di coda tra i fanali e targa posteriore.
	if String(bp["light_style"]) != "bar":
		body.add_child(_instance(
			"TailPanel", CarBodyFactory.build_capsule(0.055, hw * 1.10), m["trim"],
			Vector3(0.0, tail_top * 0.80, tail_z + 0.004), Vector3(0.0, 0.0, 90.0),
			Vector3(1.0, 0.9, 0.55),
		))
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.36, 0.13, 0.03)
	var plate := _instance(
		"PlateRear", plate_mesh, _plate_material(),
		Vector3(0.0, belt * 0.68, tail_z + 0.020), Vector3(6.0, 0.0, 0.0),
	)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(plate)

	# Specchietti: braccio, calotta e vetro.
	var span: Vector2 = bp["glass_span"]
	var mirror_z := -length * 0.5 + (span.x + 0.10 * (span.y - span.x)) * length
	var mirror_material: Material = m["body"] if bool(bp["mirrors_painted"]) else m["trim"]
	var stalk_mesh := _cylinder_mesh(0.016, 0.020, 0.16, 8)
	var mirror_mesh := CarBodyFactory.build_capsule(0.056, 0.080)
	var mirror_glass_mesh := _cylinder_mesh(0.042, 0.042, 0.012, 12)
	for side in sides:
		var suffix := "L" if side < 0.0 else "R"
		body.add_child(_instance(
			"MirrorStalk" + suffix, stalk_mesh, m["trim"],
			Vector3(side * hw * 0.92, belt + 0.055, mirror_z), Vector3(0.0, 0.0, side * 62.0),
		))
		body.add_child(_instance(
			"Mirror" + suffix, mirror_mesh, mirror_material,
			Vector3(side * (hw * 0.99 + 0.020), belt + 0.105, mirror_z),
			Vector3(0.0, 0.0, 90.0), Vector3(1.0, 0.98, 0.66),
		))
		body.add_child(_instance(
			"MirrorGlass" + suffix, mirror_glass_mesh, m["glass"],
			Vector3(side * (hw * 0.99 + 0.020), belt + 0.105, mirror_z + 0.030),
			Vector3(90.0, 0.0, 0.0),
		))

	# Maniglie delle portiere, appoggiate alla fiancata.
	var handle_mesh := CarBodyFactory.build_capsule(0.017, 0.085)
	for side in sides:
		var suffix := "L" if side < 0.0 else "R"
		var door := 0
		for hz_f: float in [0.44, 0.62]:
			var hx := hw * CarBodyFactory.catmull_rom_1d(bp["body_w"], hz_f) * 0.965
			body.add_child(_instance(
				"Handle%s%d" % [suffix, door], handle_mesh, m["trim"],
				Vector3(side * hx, belt * 0.90, -length * 0.5 + hz_f * length),
				Vector3(90.0, 0.0, 0.0), Vector3(0.8, 1.0, 1.0),
			))
			door += 1

	# Scarichi.
	var exhaust_mesh := _cylinder_mesh(0.042, 0.034, 0.14, 12)
	var exhaust_xs: Array = [-0.42] if int(bp["exhausts"]) == 1 else [-0.44, 0.44]
	var exhaust_index := 0
	for ex in exhaust_xs:
		body.add_child(_instance(
			"Exhaust%d" % exhaust_index, exhaust_mesh, m["trim_alt"],
			Vector3(float(ex) * (hw / 0.75), sill - 0.015, tail_z - 0.02),
			Vector3(90.0, 0.0, 0.0),
		))
		exhaust_index += 1

	# Pinna antenna sulle silhouette "civili".
	if profile.silhouette in [
		CarEvolutionProfile.Silhouette.HATCHBACK,
		CarEvolutionProfile.Silhouette.SEDAN,
		CarEvolutionProfile.Silhouette.COUPE,
	]:
		var fin_gt := 0.72
		var fin_z := -length * 0.5 + (span.x + fin_gt * (span.y - span.x)) * length
		var fin_top := profile.roof_height * CarBodyFactory.catmull_rom_1d(bp["glass_top"], fin_gt)
		body.add_child(_instance(
			"SharkFin", _cylinder_mesh(0.004, 0.030, 0.085, 10), m["body"],
			Vector3(0.0, fin_top + 0.028, fin_z), Vector3.ZERO, Vector3(0.45, 1.0, 2.4),
		))

	# Spoiler: labbro sul bordo del tetto oppure alettone su piloni.
	var spoiler := String(bp["spoiler"])
	if spoiler == "lip":
		var roof_range: Vector2 = bp["roof_range"]
		var lip_gt: float = roof_range.y + 0.04
		var lip_z := -length * 0.5 + (span.x + lip_gt * (span.y - span.x)) * length
		var lip_y := (
			profile.roof_height * CarBodyFactory.catmull_rom_1d(bp["glass_top"], lip_gt) + 0.015
		)
		body.add_child(_instance(
			"SpoilerLip", CarBodyFactory.build_capsule(0.042, hw * 1.12), m["trim"],
			Vector3(0.0, lip_y, lip_z + 0.045), Vector3(22.0, 0.0, 90.0),
			Vector3(1.0, 0.58, 1.0),
		))
	elif spoiler == "wing":
		var crown: float = ctx["crown"]
		var wing_z := length * 0.5 - 0.16
		var wing_y := belt + 0.30
		body.add_child(_instance(
			"Wing", CarBodyFactory.build_capsule(0.05, hw * 1.55), m["trim"],
			Vector3(0.0, wing_y, wing_z + 0.06), Vector3(-10.0, 0.0, 90.0),
			Vector3(0.5, 1.0, 2.2),
		))
		var deck := (
			_top_at(bp, length, belt, wing_z + 0.04)
			+ _fender_lift_at(bp, profile, belt, crown, wing_z + 0.04) * 0.55
		)
		var pylon_h := maxf(wing_y - deck + 0.05, 0.08)
		var pylon_mesh := BoxMesh.new()
		pylon_mesh.size = Vector3(0.05, pylon_h, 0.16)
		var endplate_mesh := BoxMesh.new()
		endplate_mesh.size = Vector3(0.03, 0.15, 0.34)
		for side in sides:
			var suffix := "L" if side < 0.0 else "R"
			body.add_child(_instance(
				"WingPylon" + suffix, pylon_mesh, m["trim"],
				Vector3(side * hw * 0.55, deck + pylon_h * 0.5 - 0.03, wing_z + 0.04),
			))
			body.add_child(_instance(
				"WingEndplate" + suffix, endplate_mesh, m["body"],
				Vector3(side * (hw * 0.80 + 0.02), wing_y, wing_z + 0.06),
			))

	# Ruota di scorta sul tetto e barre portapacchi (rottame).
	if bool(bp["spare_roof"]):
		var spare_z := -length * 0.5 + 0.60 * length
		var spare := TorusMesh.new()
		spare.inner_radius = 0.125
		spare.outer_radius = 0.275
		spare.rings = 20
		spare.ring_segments = 10
		body.add_child(_instance(
			"SpareTire", spare, m["tire"],
			Vector3(0.0, profile.roof_height + 0.065, spare_z),
		))
		body.add_child(_instance(
			"SpareHub", _cylinder_mesh(0.10, 0.10, 0.16, 12), m["rim"],
			Vector3(0.0, profile.roof_height + 0.065, spare_z),
		))
	if bool(bp["roof_rails"]):
		var rail_mesh := CarBodyFactory.build_capsule(0.022, length * 0.30)
		for side in sides:
			var suffix := "L" if side < 0.0 else "R"
			body.add_child(_instance(
				"RoofRail" + suffix, rail_mesh, m["trim"],
				Vector3(side * hw * 0.52, profile.roof_height + 0.015, -length * 0.5 + 0.52 * length),
				Vector3(90.0, 0.0, 0.0),
			))


# ----------------------------------------------------------------------- Spie --

## Barra di spie dell'evoluzione: tante quanti i livelli, accese fino a quello
## corrente. Geometria e materiali invariati rispetto al modello precedente
## (è un elemento di lettura del gioco), ora appoggiati a una slitta scura
## che li ancora visivamente alla carrozzeria.
static func _add_pips(ctx: Dictionary, pips: Array) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var m: Dictionary = ctx["m"]
	var glow: Array = ctx["glow"]
	var body: Node3D = ctx["body"]

	var holder := Node3D.new()
	holder.name = "EvolutionPips"
	holder.position = profile.pip_offset
	body.add_child(holder)

	var base := _instance(
		"PipBase", CarBodyFactory.build_capsule(0.020, 0.98), m["trim"],
		Vector3(0.0, -0.048, 0.0), Vector3(0.0, 0.0, 90.0), Vector3(1.0, 1.0, 3.2),
	)
	holder.add_child(base)

	var count: int = GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL
	var center_offset: float = (count - 1) * 0.5
	var lit_material := MaterialFactory.unique_emissive(profile.glow_color, 1.8)
	var off_material := MaterialFactory.pip_off()

	var pip_mesh := BoxMesh.new()
	pip_mesh.size = PIP_SIZE
	for index in count:
		var is_lit := index < profile.level
		var pip := _instance(
			"Pip%d" % index, pip_mesh, lit_material if is_lit else off_material,
			Vector3((index - center_offset) * PIP_SPACING, 0.0, 0.0),
		)
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(pip)
		pips.append(pip)
		if is_lit:
			glow.append(pip)


# ---------------------------------------------------------------- Materiali --

static func _make_materials(profile: CarEvolutionProfile) -> Dictionary:
	return {
		"body": MaterialFactory.stage_paint(profile.level, profile.body_color),
		"trim": MaterialFactory.stage_material(
			profile.level, "trim", profile.trim_color, 0.45, 0.18
		),
		"trim_alt": MaterialFactory.stage_material(
			profile.level, "trim_alt", profile.trim_alt_color, 0.40, 0.30
		),
		"glass": MaterialFactory.stage_material(
			profile.level, "glass", profile.glass_color, 0.06, 0.55
		),
		"rim": MaterialFactory.stage_material(
			profile.level, "rim", profile.rim_color, 0.20, 0.80
		),
		"tire": MaterialFactory.stage_material(
			profile.level, "tire", profile.tire_color, 0.94, 0.0
		),
		"well": MaterialFactory.colored("car_well", Color(0.05, 0.05, 0.06), 0.95, 0.0),
	}


## Targa: un piccolo dettaglio chiaro che chiude la coda.
static func _plate_material() -> StandardMaterial3D:
	return MaterialFactory.colored("license_plate", Color(0.93, 0.94, 0.90), 0.55, 0.0)


## Mesh di carrozzeria: quelle che portano il colore dello stadio.
static func _collect_body_meshes(root: Node3D, body_material: Material) -> Array:
	var found: Array = []
	_collect_meshes_with_material(root, body_material, found)
	return found


static func _collect_meshes_with_material(
	node: Node,
	material: Material,
	found: Array,
) -> void:
	for child in node.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.material_override == material:
			found.append(mesh_instance)
		_collect_meshes_with_material(child, material, found)


## Materiali emissivi unici del modello: sono quelli che il direttore fa
## lampeggiare. Ogni materiale compare una volta sola, con la sua energia base.
static func _collect_glow_materials(meshes: Array) -> Array:
	var entries: Array = []
	var seen: Array = []
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		if instance == null:
			continue
		var material := instance.material_override as StandardMaterial3D
		if material == null or seen.has(material):
			continue
		seen.append(material)
		entries.append({
			"material": material,
			"base": material.emission_energy_multiplier,
		})
	return entries


# ------------------------------------------------------------------ Helper ---

## Mesh di un bucket, oppure null se quel materiale non ha facce.
## Un MeshInstance3D senza mesh resta un nodo vuoto innocuo (niente errori).
static func _bucket_mesh(buckets: Dictionary, name: String) -> Mesh:
	return buckets.get(name, null) as Mesh


static func _instance(
	node_name: String,
	mesh: Mesh,
	material: Material,
	node_position: Vector3 = Vector3.ZERO,
	rotation_degrees: Vector3 = Vector3.ZERO,
	node_scale: Vector3 = Vector3.ONE,
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = node_position
	instance.rotation_degrees = rotation_degrees
	instance.scale = node_scale
	return instance


static func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 12
	return mesh


static func _cylinder_mesh(
	top_radius: float, bottom_radius: float, height: float, segments: int = 16
) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh
