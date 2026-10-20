class_name MaterialFactory
extends RefCounted
## Crea e mette in cache i materiali low-poly del progetto (nessun asset esterno).
## I materiali condivisi vengono riutilizzati tra auto e segmenti di pista.

static var _cache: Dictionary = {}


static func colored(
	key: String,
	color: Color,
	roughness: float = 0.88,
	metallic: float = 0.0,
) -> StandardMaterial3D:
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = metallic
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


# ------------------------------------------------------------------- Track ---

static func road() -> StandardMaterial3D:
	return colored("road", GameConfig.COLOR_ROAD, 0.92, 0.0)


static func lane() -> StandardMaterial3D:
	return colored("lane", GameConfig.COLOR_LANE, 0.72, 0.0)


static func edge() -> StandardMaterial3D:
	return colored("edge_primary", GameConfig.COLOR_CURB_PRIMARY, 0.68, 0.0)


static func curb_accent() -> StandardMaterial3D:
	return colored("edge_accent", GameConfig.COLOR_CURB_ACCENT, 0.68, 0.0)


static func grass(alternate: bool) -> StandardMaterial3D:
	if alternate:
		return colored("grass_alt", GameConfig.COLOR_GRASS_ALT, 0.95, 0.0)
	return colored("grass", GameConfig.COLOR_GRASS, 0.95, 0.0)


static func hill() -> StandardMaterial3D:
	return colored("hill", GameConfig.COLOR_HILL, 0.96, 0.0)


# ------------------------------------------------------------------- Props ---

static func trunk() -> StandardMaterial3D:
	return colored("trunk", GameConfig.COLOR_TRUNK, 0.92, 0.0)


static func foliage(index: int) -> StandardMaterial3D:
	var palette_size := GameConfig.FOLIAGE_COLORS.size()
	var color_index := posmod(index, palette_size)
	var key := "foliage_%d" % color_index
	return colored(key, GameConfig.FOLIAGE_COLORS[color_index], 0.86, 0.0)


static func rock() -> StandardMaterial3D:
	return colored("rock", GameConfig.COLOR_ROCK, 0.90, 0.0)


static func post() -> StandardMaterial3D:
	return colored("post", GameConfig.COLOR_POST, 0.65, 0.0)


# --------------------------------------------------------------------- Car ---

static func car_paint(color: Color) -> StandardMaterial3D:
	return colored("car_paint_" + color.to_html(false), color, 0.34, 0.12)


static func car_black() -> StandardMaterial3D:
	return colored("car_black", GameConfig.COLOR_CAR_BLACK, 0.42, 0.16)


static func car_glass() -> StandardMaterial3D:
	return colored("car_glass", GameConfig.COLOR_CAR_CABIN, 0.14, 0.35)


static func car_accent() -> StandardMaterial3D:
	return car_black()


static func car_rim() -> StandardMaterial3D:
	return colored("car_rim", GameConfig.COLOR_CAR_RIM, 0.32, 0.25)


static func tire() -> StandardMaterial3D:
	return colored("tire", GameConfig.COLOR_TIRE, 0.94, 0.0)


static func emissive(
	key: String,
	color: Color,
	energy: float = 1.25,
) -> StandardMaterial3D:
	var material_key := "emissive_" + key
	if not _cache.has(material_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.35
		material.metallic = 0.0
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		_cache[material_key] = material
	return _cache[material_key] as StandardMaterial3D


## Spia di evoluzione spenta (livello non ancora raggiunto).
static func pip_off() -> StandardMaterial3D:
	return colored("pip_off", Color(0.24, 0.26, 0.30), 0.55, 0.15)


# --------------------------------------------------- Stadi di evoluzione ----

## Materiale di uno stadio, condiviso tra tutti i modelli provvisori che usano
## lo stesso colore. La chiave include il livello: due stadi con lo stesso
## colore restano comunque indipendenti.
static func stage_material(
	level: int,
	key: String,
	color: Color,
	roughness: float,
	metallic: float,
) -> StandardMaterial3D:
	return colored("stage_%d_%s" % [level, key], color, roughness, metallic)


## Materiale emissivo NON condiviso: serve alle parti che lampeggiano durante
## la trasformazione (fari, spie, barre luminose). Essendo unico per modello,
## l'animazione non può mai propagarsi ad altri oggetti della scena.
static func unique_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## Materiale opaco NON condiviso, per dettagli che l'animazione può animare.
static func unique_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


static func headlight() -> StandardMaterial3D:
	return emissive("headlight", GameConfig.COLOR_HEADLIGHT, 1.4)


static func taillight() -> StandardMaterial3D:
	return emissive("taillight", GameConfig.COLOR_TAILLIGHT, 1.3)
