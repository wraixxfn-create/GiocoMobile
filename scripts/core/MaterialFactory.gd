class_name MaterialFactory
extends RefCounted
## Crea e mette in cache i materiali del progetto (solo primitive 3D,
## nessun asset esterno). I materiali condivisi sono riutilizzati tra i segmenti.

static var _cache: Dictionary = {}


static func colored(key: String, color: Color, roughness: float = 0.9, metalness: float = 0.0) -> MeshStandardMaterial:
	if not _cache.has(key):
		var material := MeshStandardMaterial.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metalness = metalness
		_cache[key] = material
	return _cache[key] as MeshStandardMaterial


# ------------------------------------------------------------------- Track ---

static func road() -> MeshStandardMaterial:
	return colored("road", GameConfig.COLOR_ROAD)


static func lane() -> MeshStandardMaterial:
	return colored("lane", GameConfig.COLOR_LANE, 0.7)


static func edge() -> MeshStandardMaterial:
	return colored("edge", GameConfig.COLOR_EDGE, 0.7)


static func grass(alternate: bool) -> MeshStandardMaterial:
	if alternate:
		return colored("grass_alt", GameConfig.COLOR_GRASS_ALT)
	return colored("grass", GameConfig.COLOR_GRASS)


# ---------------------------------------------------------------- Props ---

static func trunk() -> MeshStandardMaterial:
	return colored("trunk", GameConfig.COLOR_TRUNK)


static func foliage(index: int) -> MeshStandardMaterial:
	var key := "foliage_%d" % index
	return colored(key, GameConfig.FOLIAGE_COLORS[index % GameConfig.FOLIAGE_COLORS.size()])


static func rock() -> MeshStandardMaterial:
	return colored("rock", GameConfig.COLOR_ROCK)


# -------------------------------------------------------------------- Car ---

static func car_paint(color: Color) -> MeshStandardMaterial:
	return colored("car_paint_" + color.to_html(false), color, 0.55, 0.15)


static func car_glass() -> MeshStandardMaterial:
	return colored("car_glass", GameConfig.COLOR_CAR_CABIN, 0.15, 0.4)


static func car_accent() -> MeshStandardMaterial:
	return colored("car_accent", GameConfig.COLOR_CAR_ACCENT, 0.6)


static func tire() -> MeshStandardMaterial:
	return colored("tire", GameConfig.COLOR_TIRE, 0.95)


static func emissive(key: String, color: Color, energy: float = 1.2) -> MeshStandardMaterial:
	var material_key := "emissive_" + key
	if not _cache.has(material_key):
		var material := colored(key, color, 0.5, 0.0)
		material.emissive = color
		material.emissive_energy = energy
		_cache[material_key] = material
	return _cache[material_key] as MeshStandardMaterial


static func headlight() -> MeshStandardMaterial:
	return emissive("headlight", GameConfig.COLOR_HEADLIGHT)


static func taillight() -> MeshStandardMaterial:
	return emissive("taillight", GameConfig.COLOR_TAILLIGHT)
