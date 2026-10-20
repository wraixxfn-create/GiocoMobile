class_name MaterialFactory
extends RefCounted
## Crea e mette in cache i materiali del progetto (solo primitive 3D,
## nessun asset esterno). I materiali condivisi sono riutilizzati tra i segmenti.

static var _cache: Dictionary = {}


static func colored(key: String, color: Color, roughness: float = 0.9, metalness: float = 0.0) -> StandardMaterial3D:
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metalness = metalness
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


# ------------------------------------------------------------------- Track ---

static func road() -> StandardMaterial3D:
	return colored("road", GameConfig.COLOR_ROAD)


static func lane() -> StandardMaterial3D:
	return colored("lane", GameConfig.COLOR_LANE, 0.7)


static func edge() -> StandardMaterial3D:
	return colored("edge", GameConfig.COLOR_EDGE, 0.7)


static func grass(alternate: bool) -> StandardMaterial3D:
	if alternate:
		return colored("grass_alt", GameConfig.COLOR_GRASS_ALT)
	return colored("grass", GameConfig.COLOR_GRASS)


# ---------------------------------------------------------------- Props ---

static func trunk() -> StandardMaterial3D:
	return colored("trunk", GameConfig.COLOR_TRUNK)


static func foliage(index: int) -> StandardMaterial3D:
	var key := "foliage_%d" % index
	return colored(key, GameConfig.FOLIAGE_COLORS[index % GameConfig.FOLIAGE_COLORS.size()])


static func rock() -> StandardMaterial3D:
	return colored("rock", GameConfig.COLOR_ROCK)


# -------------------------------------------------------------------- Car ---

static func car_paint(color: Color) -> StandardMaterial3D:
	return colored("car_paint_" + color.to_html(false), color, 0.55, 0.15)


static func car_glass() -> StandardMaterial3D:
	return colored("car_glass", GameConfig.COLOR_CAR_CABIN, 0.15, 0.4)


static func car_accent() -> StandardMaterial3D:
	return colored("car_accent", GameConfig.COLOR_CAR_ACCENT, 0.6)


static func tire() -> StandardMaterial3D:
	return colored("tire", GameConfig.COLOR_TIRE, 0.95)


static func emissive(key: String, color: Color, energy: float = 1.2) -> StandardMaterial3D:
	var material_key := "emissive_" + key
	if not _cache.has(material_key):
		var material := colored(key, color, 0.5, 0.0)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		_cache[material_key] = material
	return _cache[material_key] as StandardMaterial3D


static func headlight() -> StandardMaterial3D:
	return emissive("headlight", GameConfig.COLOR_HEADLIGHT)


static func taillight() -> StandardMaterial3D:
	return emissive("taillight", GameConfig.COLOR_TAILLIGHT)
