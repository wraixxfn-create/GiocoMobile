class_name CarModelBuilder
extends RefCounted
## Costruisce il modello provvisorio ("blockout") di UNO stadio dell'auto con
## mesh primitive e materiali condivisi. Nessun asset esterno.
##
## Ogni livello ha la sua funzione `_build_*`, quindi la silhouette cambia
## davvero (proporzioni, volumi, dettagli) e non soltanto il colore:
##   0 rottame · 1 utilitaria · 2 berlina · 3 sportiva · 4 supercar · 5 hypercar
##
## Questo file è l'unico che va sostituito (o ignorato, impostando
## `CarEvolutionProfile.model_scene`) quando arriveranno i modelli definitivi:
## la logica di evoluzione non lo conosce direttamente, parla solo con
## CarModelLibrary e CarEvolutionDirector.

const WHEEL_SEGMENTS: int = 14
const RIM_SEGMENTS: int = 12
const PIP_SIZE := Vector3(0.13, 0.06, 0.24)
const PIP_SPACING: float = 0.22

## Chiavi del dizionario restituito da `build()`.
const KEY_ROOT: String = "root"
const KEY_WHEELS: String = "wheels"
const KEY_BODY_MESHES: String = "body_meshes"
const KEY_PIPS: String = "pips"
const KEY_GLOW_MATERIALS: String = "glow_materials"


## Costruisce lo stadio e restituisce i riferimenti che servono al direttore:
## radice del modello, perni delle ruote, mesh di carrozzeria, spie e
## materiali luminosi (istanze uniche, animate durante la trasformazione).
static func build(profile: CarEvolutionProfile) -> Dictionary:
	var root := Node3D.new()
	root.name = "Stage_%d" % profile.level

	var materials := _make_materials(profile)
	var glow_meshes: Array[MeshInstance3D] = []
	var pips: Array[MeshInstance3D] = []

	match profile.silhouette:
		CarEvolutionProfile.Silhouette.WRECK:
			_build_wreck(profile, root, materials, glow_meshes)
		CarEvolutionProfile.Silhouette.SEDAN:
			_build_sedan(profile, root, materials, glow_meshes)
		CarEvolutionProfile.Silhouette.COUPE:
			_build_coupe(profile, root, materials, glow_meshes)
		CarEvolutionProfile.Silhouette.SUPERCAR:
			_build_supercar(profile, root, materials, glow_meshes)
		CarEvolutionProfile.Silhouette.HYPERCAR:
			_build_hypercar(profile, root, materials, glow_meshes)
		_:
			_build_hatchback(profile, root, materials, glow_meshes)

	var wheels := _add_wheels(profile, root, materials)
	_add_pips(profile, root, materials, glow_meshes, pips)

	return {
		KEY_ROOT: root,
		KEY_WHEELS: wheels,
		KEY_BODY_MESHES: _collect_body_meshes(root, materials["body"] as Material),
		KEY_PIPS: pips,
		KEY_GLOW_MATERIALS: _collect_glow_materials(glow_meshes),
	}


# ------------------------------------------------------------- Silhouette ---
##
## Ogni stadio è costruito con volumi semplici ma con proporzioni e dettagli
## propri: paraurti, passaruota, specchietti, prese d'aria, alettoni e luci.
## Regola condivisa: nessun dettaglio supera in larghezza le ruote. Sono loro
## a definire l'ingombro laterale, che cresce stadio dopo stadio e rende le
## sei silhouette uniche anche a colpo d'occhio.

## 0 — ROTTAME: microcar sgangherata, alta e corta, con ruota di scorta sul
## tetto, cofano storto, ruggine e paraurti rimediato.
static func _build_wreck(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
	glow: Array,
) -> void:
	var body := m["body"] as Material
	var trim := m["trim"] as Material
	var rust := m["trim_alt"] as Material
	var glass := m["glass"] as Material
	var plate := _plate_material()

	# Telaio arrugginito e scocca "a scatola": alta, corta, sgraziata.
	root.add_child(_box(Vector3(1.22, 0.18, 2.30), Vector3(0.0, 0.34, 0.02), rust))
	root.add_child(_box(Vector3(1.30, 0.44, 2.22), Vector3(0.0, 0.60, 0.02), body))
	root.add_child(_box(Vector3(1.17, 0.46, 1.10), Vector3(0.0, 1.00, 0.06), glass))
	root.add_child(_box(Vector3(1.22, 0.08, 1.08), Vector3(0.0, 1.26, 0.06), body))
	# Cofano storto e baule.
	root.add_child(_box(
		Vector3(1.26, 0.10, 0.64),
		Vector3(0.02, 0.84, -0.84),
		body,
		Vector3(deg_to_rad(-8.0), 0.0, deg_to_rad(1.4)),
	))
	root.add_child(_box(Vector3(1.20, 0.14, 0.44), Vector3(0.0, 0.84, 1.03), body))

	# Parafanghi squadrati, specchietti e maniglie.
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		root.add_child(_box(Vector3(0.16, 0.30, 0.92), Vector3(side * 0.65, 0.52, -0.10), trim))
		root.add_child(_box(Vector3(0.16, 0.26, 0.88), Vector3(side * 0.65, 0.52, 0.92), trim))
		root.add_child(_box(Vector3(0.13, 0.10, 0.10), Vector3(side * 0.66, 0.99, -0.36), trim))
		root.add_child(_box(Vector3(0.04, 0.05, 0.16), Vector3(side * 0.655, 0.80, 0.12), rust))

	# Toppe di ruggine e portiera diversa dal resto: auto "vissuta".
	root.add_child(_box(Vector3(0.42, 0.05, 0.34), Vector3(-0.40, 0.81, -0.34), rust))
	root.add_child(_box(Vector3(0.30, 0.05, 0.26), Vector3(0.46, 0.81, 0.56), rust))
	root.add_child(_box(Vector3(0.03, 0.32, 0.86), Vector3(0.655, 0.62, 0.20), rust))

	# Paraurti storti, griglia rotta e targa.
	root.add_child(_box(
		Vector3(1.24, 0.16, 0.14),
		Vector3(0.05, 0.44, -1.21),
		trim,
		Vector3(0.0, 0.0, deg_to_rad(-4.0)),
	))
	root.add_child(_box(Vector3(1.22, 0.14, 0.12), Vector3(-0.03, 0.42, 1.21), trim))
	root.add_child(_box(Vector3(0.62, 0.20, 0.06), Vector3(0.0, 0.66, -1.12), trim))
	for slat_index in 3:
		root.add_child(_box(
			Vector3(0.05, 0.20, 0.03),
			Vector3(-0.20 + 0.20 * slat_index, 0.66, -1.14),
			rust,
		))
	_add_plate(root, plate, 1.29, 0.52, 0.34)

	# Ruota di scorta sul tetto e barre portapacchi.
	root.add_child(_cylinder(
		0.27,
		0.27,
		0.15,
		Vector3(0.0, 1.39, 0.56),
		m["tire"] as Material,
		Vector3(deg_to_rad(90.0), 0.0, 0.0),
	))
	for side in sides:
		root.add_child(_box(
			Vector3(0.05, 0.05, 1.02),
			Vector3(side * 0.44, 1.33, 0.10),
			trim,
		))
	# Scarico storto e gancio di traino.
	root.add_child(_cylinder(
		0.05,
		0.05,
		0.28,
		Vector3(-0.34, 0.30, 1.26),
		trim,
		Vector3(deg_to_rad(90.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(0.10, 0.10, 0.18), Vector3(0.38, 0.30, -1.26), trim))

	_add_lights(profile, root, m, glow, -1.20, 1.22, 0.64, 0.24)


## 1 — UTILITARIA: due volumi compatti, spigolosi, con tetto alto, passaruota
## neri, barre sul tetto e striscia racing. È il modello di partenza.
static func _build_hatchback(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
	glow: Array,
) -> void:
	var body := m["body"] as Material
	var trim := m["trim"] as Material
	var glass := m["glass"] as Material
	var plate := _plate_material()

	root.add_child(_box(Vector3(1.46, 0.14, 2.90), Vector3(0.0, 0.30, 0.0), trim))
	root.add_child(_box(Vector3(1.50, 0.36, 2.86), Vector3(0.0, 0.50, 0.0), body))
	root.add_child(_box(
		Vector3(1.38, 0.10, 0.86),
		Vector3(0.0, 0.68, -0.88),
		body,
		Vector3(deg_to_rad(-4.5), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.42, 0.10, 0.70), Vector3(0.0, 0.70, 0.96), body))

	# Abitacolo alto con parabrezza e lunotto inclinati.
	root.add_child(_box(Vector3(1.20, 0.34, 1.10), Vector3(0.0, 0.85, 0.02), glass))
	root.add_child(_box(
		Vector3(1.18, 0.10, 0.44),
		Vector3(0.0, 0.84, -0.62),
		glass,
		Vector3(deg_to_rad(-42.0), 0.0, 0.0),
	))
	root.add_child(_box(
		Vector3(1.18, 0.10, 0.46),
		Vector3(0.0, 0.85, 0.72),
		glass,
		Vector3(deg_to_rad(36.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.20, 0.055, 1.16), Vector3(0.0, 1.045, 0.02), body))
	root.add_child(_box(Vector3(0.34, 0.03, 1.18), Vector3(0.0, 1.085, 0.02), trim))

	# Paraurti, passaruota e minigonne.
	root.add_child(_box(Vector3(1.40, 0.14, 0.12), Vector3(0.0, 0.42, -1.48), trim))
	root.add_child(_box(Vector3(1.40, 0.14, 0.12), Vector3(0.0, 0.42, 1.48), trim))
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.12, 0.17, 0.94), Vector3(side * 0.77, 0.31, -1.02), trim))
		root.add_child(_box(Vector3(0.12, 0.17, 0.90), Vector3(side * 0.77, 0.31, 1.02), trim))
		root.add_child(_box(Vector3(0.10, 0.10, 2.40), Vector3(side * 0.76, 0.32, 0.0), trim))
		root.add_child(_box(Vector3(0.14, 0.10, 0.10), Vector3(side * 0.76, 0.86, -0.44), trim))
		root.add_child(_box(Vector3(0.10, 0.05, 0.16), Vector3(side * 0.755, 0.78, 0.12), trim))
		# Barre sul tetto.
		root.add_child(_box(Vector3(0.05, 0.05, 1.30), Vector3(side * 0.48, 1.10, 0.02), trim))

	# Griglia anteriore e dettagli luminosi.
	root.add_child(_box(Vector3(0.90, 0.16, 0.06), Vector3(0.0, 0.56, -1.47), trim))
	for slat_index in 2:
		root.add_child(_box(
			Vector3(0.84, 0.03, 0.03),
			Vector3(0.0, 0.52 + 0.08 * slat_index, -1.49),
			body,
		))
	root.add_child(_box(Vector3(1.16, 0.05, 0.20), Vector3(0.0, 1.10, 1.40), trim))
	_add_plate(root, plate, -1.55, 0.46, 0.34)

	_add_lights(profile, root, m, glow, -1.50, 1.50, 0.58, 0.28)


## 2 — BERLINA: tre volumi ben separati, più lunga, abitacolo vetrato, profili
## cromati, griglia a listelli e pinna sul tetto.
static func _build_sedan(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
	glow: Array,
) -> void:
	var body := m["body"] as Material
	var trim := m["trim"] as Material
	var chrome := m["trim_alt"] as Material
	var glass := m["glass"] as Material
	var plate := _plate_material()

	root.add_child(_box(Vector3(1.52, 0.14, 3.24), Vector3(0.0, 0.28, 0.0), trim))
	root.add_child(_box(Vector3(1.58, 0.38, 3.20), Vector3(0.0, 0.48, 0.0), body))
	root.add_child(_box(
		Vector3(1.46, 0.10, 1.10),
		Vector3(0.0, 0.66, -1.02),
		body,
		Vector3(deg_to_rad(-3.5), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.48, 0.14, 0.86), Vector3(0.0, 0.74, 1.10), body))

	root.add_child(_box(Vector3(1.30, 0.40, 1.30), Vector3(0.0, 0.90, -0.06), glass))
	root.add_child(_box(
		Vector3(1.28, 0.10, 0.46),
		Vector3(0.0, 0.89, -0.78),
		glass,
		Vector3(deg_to_rad(-40.0), 0.0, 0.0),
	))
	root.add_child(_box(
		Vector3(1.28, 0.10, 0.46),
		Vector3(0.0, 0.89, 0.74),
		glass,
		Vector3(deg_to_rad(38.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.32, 0.06, 1.26), Vector3(0.0, 1.13, -0.06), body))

	# Profili cromati, passaruota e pinna sul tetto.
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.05, 0.05, 2.80), Vector3(side * 0.80, 0.56, 0.0), chrome))
		root.add_child(_box(Vector3(0.05, 0.05, 1.30), Vector3(side * 0.79, 1.11, -0.06), chrome))
		root.add_child(_box(Vector3(0.10, 0.15, 0.98), Vector3(side * 0.82, 0.29, -1.10), trim))
		root.add_child(_box(Vector3(0.10, 0.15, 0.94), Vector3(side * 0.82, 0.29, 1.10), trim))
		root.add_child(_box(Vector3(0.13, 0.10, 0.10), Vector3(side * 0.81, 0.86, -0.52), body))
		root.add_child(_box(Vector3(0.04, 0.04, 0.16), Vector3(side * 0.805, 0.80, 0.10), chrome))
	root.add_child(_box(
		Vector3(0.05, 0.12, 0.30),
		Vector3(0.0, 1.20, 0.54),
		body,
		Vector3(deg_to_rad(-16.0), 0.0, 0.0),
	))

	# Griglia a listelli cromati e paraurti sdoppiati.
	root.add_child(_box(Vector3(1.10, 0.20, 0.08), Vector3(0.0, 0.54, -1.60), trim))
	for slat_index in 3:
		root.add_child(_box(
			Vector3(0.94, 0.025, 0.03),
			Vector3(0.0, 0.47 + 0.07 * slat_index, -1.63),
			chrome,
		))
	root.add_child(_box(Vector3(1.50, 0.14, 0.12), Vector3(0.0, 0.40, -1.62), trim))
	root.add_child(_box(Vector3(1.50, 0.14, 0.12), Vector3(0.0, 0.42, 1.62), trim))
	root.add_child(_box(Vector3(1.28, 0.05, 0.18), Vector3(0.0, 0.86, 1.52), chrome))
	_add_plate(root, plate, 1.69, 0.52, 0.36)

	_add_lights(profile, root, m, glow, -1.62, 1.62, 0.58, 0.30)


## 3 — SPORTIVA: coupé bassa, cofano lungo con sfoghi, coda fastback, minigonne,
## diffusore posteriore e doppio scarico.
static func _build_coupe(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
	glow: Array,
) -> void:
	var body := m["body"] as Material
	var trim := m["trim"] as Material
	var glass := m["glass"] as Material
	var plate := _plate_material()

	root.add_child(_box(Vector3(1.54, 0.12, 3.10), Vector3(0.0, 0.24, 0.0), trim))
	root.add_child(_box(Vector3(1.62, 0.30, 3.04), Vector3(0.0, 0.40, 0.0), body))
	root.add_child(_box(
		Vector3(1.46, 0.09, 1.28),
		Vector3(0.0, 0.52, -1.00),
		body,
		Vector3(deg_to_rad(-5.0), 0.0, 0.0),
	))
	root.add_child(_box(
		Vector3(1.50, 0.09, 1.00),
		Vector3(0.0, 0.56, 0.98),
		body,
		Vector3(deg_to_rad(10.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(0.46, 0.06, 0.50), Vector3(0.0, 0.585, -0.86), trim))

	root.add_child(_box(Vector3(1.22, 0.26, 0.96), Vector3(0.0, 0.62, 0.06), glass))
	root.add_child(_box(
		Vector3(1.20, 0.09, 0.56),
		Vector3(0.0, 0.60, -0.60),
		glass,
		Vector3(deg_to_rad(-52.0), 0.0, 0.0),
	))
	root.add_child(_box(
		Vector3(1.20, 0.09, 0.62),
		Vector3(0.0, 0.62, 0.76),
		glass,
		Vector3(deg_to_rad(28.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.18, 0.06, 0.84), Vector3(0.0, 0.76, 0.14), body))

	# Sfoghi sul cofano e minigonne, specchietti bassi e maniglie.
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.28, 0.03, 0.34), Vector3(side * 0.36, 0.545, -1.18), trim))
		root.add_child(_box(Vector3(0.10, 0.10, 2.20), Vector3(side * 0.81, 0.22, 0.0), trim))
		root.add_child(_box(Vector3(0.12, 0.08, 0.12), Vector3(side * 0.85, 0.66, -0.46), body))
		root.add_child(_box(Vector3(0.04, 0.04, 0.18), Vector3(side * 0.805, 0.52, 0.10), trim))
		# Presa d'aria laterale dietro la portiera.
		root.add_child(_box(Vector3(0.06, 0.12, 0.46), Vector3(side * 0.79, 0.42, 0.62), trim))

	# Codino fastback, splitter anteriore e diffusore con alette.
	root.add_child(_box(
		Vector3(1.30, 0.06, 0.26),
		Vector3(0.0, 0.62, 1.52),
		trim,
		Vector3(deg_to_rad(-8.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.40, 0.05, 0.28), Vector3(0.0, 0.19, -1.52), trim))
	for fin_index in 3:
		root.add_child(_box(
			Vector3(0.05, 0.12, 0.24),
			Vector3((float(fin_index) - 1.0) * 0.34, 0.20, 1.50),
			trim,
		))
	_add_plate(root, plate, 1.60, 0.30, 0.32)

	_add_lights(profile, root, m, glow, -1.56, 1.56, 0.50, 0.32)


## 4 — SUPERCAR: larghissima e bassa, motore centrale con prese d'aria,
## cupola piccola, alettone con paratie, diffusore e scarichi multipli.
static func _build_supercar(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
	glow: Array,
) -> void:
	var body := m["body"] as Material
	var trim := m["trim"] as Material
	var glass := m["glass"] as Material
	var plate := _plate_material()

	root.add_child(_box(Vector3(1.64, 0.10, 3.26), Vector3(0.0, 0.20, 0.0), trim))
	root.add_child(_box(Vector3(1.72, 0.26, 3.22), Vector3(0.0, 0.34, 0.0), body))
	root.add_child(_box(
		Vector3(1.56, 0.12, 0.94),
		Vector3(0.0, 0.28, -1.22),
		body,
		Vector3(deg_to_rad(-7.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.74, 0.05, 0.44), Vector3(0.0, 0.15, -1.58), trim))

	# Prese d'aria laterali, cofano motore e sfoghi.
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		root.add_child(_box(Vector3(0.16, 0.24, 0.80), Vector3(side * 0.90, 0.46, 0.32), trim))
		root.add_child(_box(Vector3(0.13, 0.09, 0.12), Vector3(side * 0.88, 0.62, -0.58), body))
		root.add_child(_box(Vector3(0.05, 0.04, 0.18), Vector3(side * 0.855, 0.44, 0.02), trim))
		# Canard anteriore.
		root.add_child(_box(
			Vector3(0.24, 0.03, 0.20),
			Vector3(side * 0.78, 0.24, -1.45),
			trim,
			Vector3(0.0, 0.0, deg_to_rad(-8.0) * side),
		))
	root.add_child(_box(Vector3(1.36, 0.05, 1.00), Vector3(0.0, 0.50, 0.66), trim))
	for louver_index in 3:
		root.add_child(_box(
			Vector3(1.20, 0.03, 0.08),
			Vector3(0.0, 0.54, 0.42 + 0.24 * louver_index),
			trim,
		))

	# Cupola e sportello motore.
	root.add_child(_box(Vector3(1.16, 0.22, 1.04), Vector3(0.0, 0.54, -0.10), glass))
	root.add_child(_box(
		Vector3(1.14, 0.08, 0.60),
		Vector3(0.0, 0.52, -0.68),
		glass,
		Vector3(deg_to_rad(-58.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.06, 0.06, 0.76), Vector3(0.0, 0.67, 0.06), body))

	# Alettone con paratie verticali, diffusore e scarichi.
	root.add_child(_box(Vector3(1.66, 0.05, 0.34), Vector3(0.0, 0.80, 1.44), trim))
	for side in sides:
		root.add_child(_box(Vector3(0.06, 0.22, 0.34), Vector3(side * 0.80, 0.78, 1.44), body))
		root.add_child(_box(Vector3(0.07, 0.24, 0.16), Vector3(side * 0.60, 0.68, 1.44), trim))
		root.add_child(_cylinder(
			0.055,
			0.055,
			0.22,
			Vector3(side * 0.36, 0.19, 1.62),
			trim,
			Vector3(deg_to_rad(90.0), 0.0, 0.0),
		))
	root.add_child(_box(Vector3(1.40, 0.18, 0.26), Vector3(0.0, 0.22, 1.58), trim))
	for fin_index in 4:
		root.add_child(_box(
			Vector3(0.04, 0.14, 0.24),
			Vector3((float(fin_index) - 1.5) * 0.26, 0.18, 1.56),
			body,
		))
	_add_plate(root, plate, 1.72, 0.28, 0.34)

	_add_lights(profile, root, m, glow, -1.62, 1.62, 0.40, 0.34)


## 5 — HYPERCAR: pancia bassissima, cupola in vetro, pinne, canali d'aria,
## alettone attivo, barre e pattini luminosi sotto la scocca.
static func _build_hypercar(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
	glow: Array,
) -> void:
	var body := m["body"] as Material
	var trim := m["trim"] as Material
	var dark := m["trim_alt"] as Material
	var glass := m["glass"] as Material
	var glow_material := m["glow"] as Material
	var plate := _plate_material()

	root.add_child(_box(Vector3(1.68, 0.09, 3.34), Vector3(0.0, 0.18, 0.0), trim))
	root.add_child(_box(Vector3(1.76, 0.22, 3.30), Vector3(0.0, 0.30, 0.0), body))
	root.add_child(_box(
		Vector3(1.50, 0.10, 1.04),
		Vector3(0.0, 0.24, -1.30),
		body,
		Vector3(deg_to_rad(-9.0), 0.0, 0.0),
	))
	root.add_child(_box(Vector3(1.50, 0.08, 1.00), Vector3(0.0, 0.44, 0.90), body))

	# Cupola in vetro: sfera schiacciata sopra la scocca.
	root.add_child(_box(Vector3(1.20, 0.10, 1.40), Vector3(0.0, 0.40, 0.02), glass))
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.5
	canopy_mesh.height = 1.0
	canopy_mesh.radial_segments = 14
	canopy_mesh.rings = 7
	var canopy := MeshInstance3D.new()
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 0.46, 0.02)
	canopy.scale = Vector3(1.10, 0.34, 1.52)
	canopy.material_override = glass
	root.add_child(canopy)

	# Pinne verticali, gallerie d'aria, alettone attivo e specchietti.
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		root.add_child(_box(Vector3(0.06, 0.30, 0.90), Vector3(side * 0.84, 0.60, 1.00), body))
		root.add_child(_box(Vector3(0.14, 0.20, 0.90), Vector3(side * 0.86, 0.34, 0.30), dark))
		root.add_child(_box(Vector3(0.07, 0.30, 0.12), Vector3(side * 0.66, 0.78, 1.44), trim))
		root.add_child(_box(Vector3(0.11, 0.07, 0.10), Vector3(side * 0.93, 0.48, -0.50), body))
		# Feritoie sopra i passaruota.
		root.add_child(_box(Vector3(0.16, 0.04, 0.30), Vector3(side * 0.72, 0.40, -1.10), dark))
		# Canard luminoso anteriore.
		root.add_child(_box(Vector3(0.26, 0.025, 0.06), Vector3(side * 0.72, 0.22, -1.62), glow_material))
	root.add_child(_box(Vector3(1.70, 0.05, 0.28), Vector3(0.0, 0.92, 1.44), trim))
	for side in sides:
		root.add_child(_box(Vector3(0.05, 0.26, 0.30), Vector3(side * 0.82, 0.80, 1.44), body))
	root.add_child(_box(Vector3(1.44, 0.16, 0.24), Vector3(0.0, 0.20, 1.62), trim))

	# Barre luminose continue e pattini luminosi: lampeggiano alle trasformazioni.
	_add_plate(root, plate, 1.70, 0.26, 0.34)
	_add_glow_bar(root, Vector3(1.44, 0.06, 0.05), Vector3(0.0, 0.50, 1.70), glow_material, glow)
	_add_glow_bar(root, Vector3(1.10, 0.05, 0.05), Vector3(0.0, 0.32, -1.66), glow_material, glow)
	_add_glow_bar(root, Vector3(0.70, 0.03, 1.60), Vector3(-0.52, 0.07, 0.10), glow_material, glow)
	_add_glow_bar(root, Vector3(0.70, 0.03, 1.60), Vector3(0.52, 0.07, 0.10), glow_material, glow)

	_add_lights(profile, root, m, glow, -1.60, 1.60, 0.36, 0.30)


# ----------------------------------------------------------------- Parti ---

## Ruote: quattro perni (prima le due anteriori, poi le due posteriori).
## Il perno è il nodo che `CarController` fa ruotare su X e, per le anteriori,
## sterza su Y.
static func _add_wheels(
	profile: CarEvolutionProfile,
	root: Node3D,
	m: Dictionary,
) -> Array[Node3D]:
	var wheels: Array[Node3D] = []
	var offsets: Array[Vector3] = [
		Vector3(-profile.wheel_base_x, profile.wheel_radius, -profile.wheel_base_z),
		Vector3(profile.wheel_base_x, profile.wheel_radius, -profile.wheel_base_z),
		Vector3(-profile.wheel_base_x, profile.wheel_radius, profile.wheel_base_z),
		Vector3(profile.wheel_base_x, profile.wheel_radius, profile.wheel_base_z),
	]
	for index in offsets.size():
		var width := profile.rear_wheel_width if index >= 2 else profile.wheel_width
		var pivot := Node3D.new()
		pivot.name = "Wheel%d" % index
		pivot.position = offsets[index]

		pivot.add_child(_cylinder(
			profile.wheel_radius,
			profile.wheel_radius,
			width,
			Vector3.ZERO,
			m["tire"] as Material,
			Vector3(0.0, 0.0, PI / 2.0),
			WHEEL_SEGMENTS,
		))
		pivot.add_child(_cylinder(
			profile.wheel_radius * 0.62,
			profile.wheel_radius * 0.62,
			width + 0.02,
			Vector3.ZERO,
			m["rim"] as Material,
			Vector3(0.0, 0.0, PI / 2.0),
			RIM_SEGMENTS,
		))
		# Mozzo scuro: stacca il cerchione e dà profondità alla ruota.
		pivot.add_child(_cylinder(
			profile.wheel_radius * 0.24,
			profile.wheel_radius * 0.24,
			width + 0.03,
			Vector3.ZERO,
			m["trim"] as Material,
			Vector3(0.0, 0.0, PI / 2.0),
			8,
		))

		root.add_child(pivot)
		wheels.append(pivot)
	return wheels


## Fari e fanali: materiali emissivi unici, così lampeggiano solo loro.
static func _add_lights(
	profile: CarEvolutionProfile,
	root: Node3D,
	_m: Dictionary,
	glow: Array,
	front_z: float,
	rear_z: float,
	light_y: float,
	light_width: float,
) -> void:
	var head_material := MaterialFactory.unique_emissive(profile.headlight_color, 1.4)
	var tail_material := MaterialFactory.unique_emissive(profile.taillight_color, 1.3)

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(light_width, light_width * 0.34, 0.08)
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(light_width * 1.10, light_width * 0.30, 0.08)
	# Firma luminosa sottile sotto il faro: modernizza tutte le silhouette.
	var drl_mesh := BoxMesh.new()
	drl_mesh.size = Vector3(light_width * 0.86, 0.028, 0.05)

	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var head := MeshInstance3D.new()
		head.mesh = head_mesh
		head.position = Vector3(side * light_width * 0.85, light_y, front_z)
		head.material_override = head_material
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(head)
		glow.append(head)

		var drl := MeshInstance3D.new()
		drl.mesh = drl_mesh
		drl.position = Vector3(side * light_width * 0.85, light_y - light_width * 0.26, front_z - 0.02)
		drl.material_override = head_material
		drl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(drl)
		glow.append(drl)

		var tail := MeshInstance3D.new()
		tail.mesh = tail_mesh
		tail.position = Vector3(side * light_width * 0.85, light_y + 0.02, rear_z)
		tail.material_override = tail_material
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(tail)
		glow.append(tail)


## Barra di spie dell'evoluzione: tante quanti i livelli, accese fino a quello
## corrente. Permette di leggere il livello anche senza l'HUD.
static func _add_pips(
	profile: CarEvolutionProfile,
	root: Node3D,
	_m: Dictionary,
	glow: Array,
	pips: Array,
) -> void:
	var holder := Node3D.new()
	holder.name = "EvolutionPips"
	holder.position = profile.pip_offset
	root.add_child(holder)

	var count: int = GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL
	var center_offset: float = (count - 1) * 0.5
	var lit_material := MaterialFactory.unique_emissive(profile.glow_color, 1.8)
	var off_material := MaterialFactory.pip_off()

	var pip_mesh := BoxMesh.new()
	pip_mesh.size = PIP_SIZE
	for index in count:
		var is_lit := index < profile.level
		var pip := MeshInstance3D.new()
		pip.mesh = pip_mesh
		pip.position = Vector3((index - center_offset) * PIP_SPACING, 0.0, 0.0)
		pip.material_override = lit_material if is_lit else off_material
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(pip)
		pips.append(pip)
		if is_lit:
			glow.append(pip)


## Targa: un piccolo dettaglio chiaro che chiude il muso/la coda.
static func _plate_material() -> StandardMaterial3D:
	return MaterialFactory.colored("license_plate", Color(0.93, 0.94, 0.90), 0.55, 0.0)


static func _add_plate(
	root: Node3D,
	material: Material,
	plate_z: float,
	plate_y: float,
	plate_width: float,
) -> void:
	var plate := _box(
		Vector3(plate_width, 0.13, 0.035),
		Vector3(0.0, plate_y, plate_z),
		material,
	)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plate)


static func _add_glow_bar(
	root: Node3D,
	size: Vector3,
	bar_position: Vector3,
	material: Material,
	glow: Array,
) -> void:
	var bar := _box(size, bar_position, material)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar)
	glow.append(bar)


# ------------------------------------------------------------- Materiali ---

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
		"glow": MaterialFactory.unique_emissive(profile.glow_color, 1.6),
	}


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


# ---------------------------------------------------------------- Helper ---

static func _box(
	size: Vector3,
	box_position: Vector3,
	material: Material,
	box_rotation: Vector3 = Vector3.ZERO,
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = box_position
	instance.rotation = box_rotation
	instance.material_override = material
	return instance


static func _cylinder(
	top_radius: float,
	bottom_radius: float,
	height: float,
	cylinder_position: Vector3,
	material: Material,
	cylinder_rotation: Vector3 = Vector3.ZERO,
	segments: int = 14,
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = cylinder_position
	instance.rotation = cylinder_rotation
	instance.material_override = material
	return instance
