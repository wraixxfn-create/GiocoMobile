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

## Asfalto: due toni alternati per segmento, così la pista "scorre" e non è
## una superficie unica e piatta.
static func road(alternate: bool = false) -> StandardMaterial3D:
	if alternate:
		return colored("road_alt", GameConfig.COLOR_ROAD_ALT, 0.86, 0.0)
	return colored("road", GameConfig.COLOR_ROAD, 0.86, 0.0)


## Fascia chiara (cordolo esterno + prato): aiuta a leggere il bordo pista.
static func verge() -> StandardMaterial3D:
	return colored("verge", GameConfig.COLOR_VERGE, 0.90, 0.0)


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


## Tono più chiaro del fogliame: dà volume alle chiome low-poly.
static func foliage_highlight(index: int) -> StandardMaterial3D:
	var palette_size := GameConfig.FOLIAGE_COLORS.size()
	var color_index := posmod(index, palette_size)
	var color := GameConfig.FOLIAGE_COLORS[color_index].lightened(0.20)
	return colored("foliage_light_%d" % color_index, color, 0.82, 0.0)


static func rock() -> StandardMaterial3D:
	return colored("rock", GameConfig.COLOR_ROCK, 0.90, 0.0)


static func post() -> StandardMaterial3D:
	return colored("post", GameConfig.COLOR_POST, 0.55, 0.05)


## Catarifrangente arancione del delineatore: leggibile anche controluce.
static func post_reflector() -> StandardMaterial3D:
	return emissive("post_reflector", GameConfig.COLOR_POST_REFLECTOR, 1.1)


# --------------------------------------------------------------------- Car ---

## Vernice dell'auto: lucida, con un leggero clearcoat per un look "giocattolo"
## premium senza shader personalizzati.
static func car_paint(color: Color) -> StandardMaterial3D:
	var key := "car_paint_" + color.to_html(false)
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.26
		material.metallic = 0.16
		material.clearcoat_enabled = true
		material.clearcoat = 0.65
		material.clearcoat_roughness = 0.18
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


static func car_black() -> StandardMaterial3D:
	return colored("car_black", GameConfig.COLOR_CAR_BLACK, 0.42, 0.16)


static func car_glass() -> StandardMaterial3D:
	return colored("car_glass", GameConfig.COLOR_CAR_CABIN, 0.08, 0.55)


static func car_accent() -> StandardMaterial3D:
	return car_black()


static func car_rim() -> StandardMaterial3D:
	return colored("car_rim", GameConfig.COLOR_CAR_RIM, 0.22, 0.80)


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


## Vernice di uno stadio: lucida e con clearcoat, condivisa tra le parti della
## stessa carrozzeria. La chiave include il livello, così due stadi con colori
## simili restano indipendenti.
static func stage_paint(level: int, color: Color) -> StandardMaterial3D:
	var key := "stage_paint_%d_%s" % [level, color.to_html(false)]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.30
		material.metallic = 0.08
		material.clearcoat_enabled = true
		material.clearcoat = 0.55
		material.clearcoat_roughness = 0.22
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


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


# ------------------------------------------------------- Decorazioni 3D -----

## Materiale per MultiMesh con colore per-istanza (ciuffi d'erba e fiori).
static func vertex_colored(
	key: String,
	roughness: float = 0.85,
	double_sided: bool = false,
) -> StandardMaterial3D:
	var material_key := "vertex_" + key + ("_ds" if double_sided else "")
	if not _cache.has(material_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 1.0, 1.0)
		material.vertex_color_use_as_albedo = true
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.roughness = roughness
		material.metallic = 0.0
		if double_sided:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[material_key] = material
	return _cache[material_key] as StandardMaterial3D


## Materiale piatto e trasparente per pannelli e onde d'urto a terra.
static func translucent(color: Color, energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = energy
	return material


# ---------------------------------------------------------- Traguardo -------

## Scacchiera generata a runtime (nessun asset esterno) per il traguardo.
## L'immagine è piccola e con filtro NEAREST: costa pochissimo anche su mobile.
static func checker_texture(cells: int = 8, pixel_size: int = 8) -> ImageTexture:
	var key := "checker_%d_%d" % [cells, pixel_size]
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var size := maxi(cells, 2) * maxi(pixel_size, 1)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dark := GameConfig.COLOR_FINISH_DARK
	var light := GameConfig.COLOR_FINISH_LIGHT
	for y in size:
		for x in size:
			var cell := (x / pixel_size) + (y / pixel_size)
			image.set_pixel(x, y, dark if cell % 2 == 0 else light)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Materiale con la scacchiera del traguardo (filtro nearest, nessun blur).
static func checker_material(cells: int = 8) -> StandardMaterial3D:
	var key := "checker_material_%d" % cells
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = checker_texture(cells)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 0.55
		material.metallic = 0.0
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


static func finish_gold() -> StandardMaterial3D:
	var material_key := "finish_gold"
	if not _cache.has(material_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = GameConfig.COLOR_FINISH_GOLD
		material.metallic = 0.75
		material.roughness = 0.26
		material.emission_enabled = true
		material.emission = GameConfig.COLOR_FINISH_GOLD
		material.emission_energy_multiplier = 0.35
		_cache[material_key] = material
	return _cache[material_key] as StandardMaterial3D


# ------------------------------------------------------- Cartelli 3D -------

## Texture "pillola" arrotondata generata a runtime per i cartelli dei cancelli.
## Bianca con alpha: il colore arriva dall'albedo del materiale.
static func badge_texture() -> ImageTexture:
	var key := "badge_texture"
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var width := 96
	var height := 48
	var radius := 16.0
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			var dx := maxf(maxf(radius - px, px - (float(width) - radius)), 0.0)
			var dy := maxf(maxf(radius - py, py - (float(height) - radius)), 0.0)
			var distance := sqrt(dx * dx + dy * dy)
			var alpha := clampf(radius - distance + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Cartello scuro semitrasparente, sempre rivolto alla telecamera: fa da
## sfondo leggibile al valore del cancello.
static func badge_material(color: Color) -> StandardMaterial3D:
	var key := "badge_" + color.to_html(true)
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = badge_texture()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


# ---------------------------------------------------------------- Scenario ---
## Materiali dello scenario tropicale. Tutti condivisi e in cache: il livello
## dimostrativo usa poche decine di materiali, non uno per oggetto.

## Materiale opaco generico dello scenario (legno, metallo, tessuto...).
static func scenery(
	key: String,
	color: Color,
	roughness: float = 0.90,
	metallic: float = 0.0,
) -> StandardMaterial3D:
	return colored("scenery_" + key, color, roughness, metallic)


## Fogliame: opaco, leggermente più lucido ai bordi grazie al tono, senza
## shader personalizzati. `cull_disabled` perché le fronde sono lamine.
static func leaf(index: int, double_sided: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.foliage(index)
	var key := "scenery_foliage_%d_%s" % [index, "ds" if double_sided else "ss"]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.84
		material.metallic = 0.0
		if double_sided:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


## Chioma chiara: stesso verde, un gradino più luminoso (volume leggibile).
static func leaf_light(index: int, double_sided: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.foliage_highlight(index)
	var key := "scenery_foliage_light_%d_%s" % [index, "ds" if double_sided else "ss"]
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.82
		material.metallic = 0.0
		if double_sided:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


static func fern(light: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.FERN_LIGHT if light else SceneryPalette.FERN_GREEN
	var key := "scenery_fern_%s" % ("light" if light else "dark")
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.86
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


static func tree_trunk(light: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.TRUNK_LIGHT if light else SceneryPalette.TRUNK
	return scenery("trunk_%s" % ("light" if light else "dark"), color, 0.92, 0.0)


static func boulder(light: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.ROCK_LIGHT if light else SceneryPalette.ROCK
	return scenery("rock_%s" % ("light" if light else "dark"), color, 0.93, 0.0)


static func moss() -> StandardMaterial3D:
	return scenery("moss", SceneryPalette.MOSS, 0.95, 0.0)


static func sand() -> StandardMaterial3D:
	return scenery("sand", SceneryPalette.SAND, 0.95, 0.0)


static func wood(light: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.WOOD_LIGHT if light else SceneryPalette.WOOD
	return scenery("wood_%s" % ("light" if light else "dark"), color, 0.88, 0.0)


static func thatch(dark: bool = false) -> StandardMaterial3D:
	var color := SceneryPalette.THATCH_DARK if dark else SceneryPalette.THATCH
	return scenery("thatch_%s" % ("dark" if dark else "light"), color, 0.94, 0.0)


static func fabric(index: int) -> StandardMaterial3D:
	var color := SceneryPalette.FABRIC_RED
	if index == 1:
		color = SceneryPalette.FABRIC_CREAM
	elif index == 2:
		color = SceneryPalette.FABRIC_TEAL
	return scenery("fabric_%d" % posmod(index, 3), color, 0.80, 0.0)


static func metal() -> StandardMaterial3D:
	return scenery("metal", SceneryPalette.METAL, 0.42, 0.55)


static func sign_yellow() -> StandardMaterial3D:
	return scenery("sign_yellow", SceneryPalette.SIGN_YELLOW, 0.52, 0.0)


static func sign_green() -> StandardMaterial3D:
	return scenery("sign_green", SceneryPalette.SIGN_GREEN, 0.56, 0.0)


static func sand_ground() -> StandardMaterial3D:
	return scenery("sand_ground", SceneryPalette.SAND_DARK, 0.96, 0.0)


## Terreno con colore per vertice: un solo materiale per tutta la prateria.
static func terrain() -> StandardMaterial3D:
	var key := "scenery_terrain"
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.96
		material.metallic = 0.0
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


## Colline e sfondo: materiale opaco con una punta di emissione, così la
## foschia le schiarisce senza shader dedicati né nebbia volumetrica.
static func distant_hill(color: Color) -> StandardMaterial3D:
	var key := "scenery_hill_" + color.to_html(false)
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		material.metallic = 0.0
		material.emission_enabled = true
		material.emission = color.lightened(0.25)
		material.emission_energy_multiplier = 0.10
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


## Asfalto: texture generata a runtime (grana + piste di usura dei pneumatici
## + bordo più sporco). Una sola texture per tutti i segmenti.
static func asphalt() -> StandardMaterial3D:
	var key := "scenery_asphalt"
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = asphalt_texture()
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.92
		material.metallic = 0.0
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		_cache[key] = material
	return _cache[key] as StandardMaterial3D


## Texture dell'asfalto: 128x128, generata in pochi millisecondi.
## U attraversa la carreggiata (0 = bordo sinistro), V si ripete lungo la pista.
static func asphalt_texture() -> ImageTexture:
	var key := "scenery_asphalt_texture"
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := SceneryPalette.ROAD_BASE
	var edge := SceneryPalette.ROAD_EDGE
	var wear := SceneryPalette.ROAD_WEAR
	# Piste di usura: due per corsia, come lasciate dai pneumatici.
	var tracks: Array[float] = [0.070, 0.263, 0.404, 0.596, 0.737, 0.930]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260317
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size)
			var color := base
			# Bordo carreggiata più scuro (grasso e polvere).
			var edge_weight := smoothstep(0.085, 0.0, minf(u, 1.0 - u))
			color = color.lerp(edge, edge_weight * 0.55)
			for track in tracks:
				var distance := absf(u - track)
				color = color.lerp(wear, smoothstep(0.030, 0.010, distance) * 0.6)
			# Grana fine e macchie larghe: due frequenze, deterministiche.
			var grain := rng.randf_range(-0.022, 0.022)
			var blotch := sin(u * 21.0 + float(y) * 0.09) * 0.008
			color = Color(
				clampf(color.r + grain + blotch, 0.0, 1.0),
				clampf(color.g + grain + blotch, 0.0, 1.0),
				clampf(color.b + grain + blotch, 0.0, 1.0),
			)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
