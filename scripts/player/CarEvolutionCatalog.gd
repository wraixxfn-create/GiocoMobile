class_name CarEvolutionCatalog
extends RefCounted
## Registro degli stadi di evoluzione: traduce `evolution_level` in un
## `CarEvolutionProfile` (nome, colori, statistiche, proporzioni, silhouette).
##
## È l'unico punto in cui si definisce "che aspetto ha il livello N":
## - i valori di base arrivano da GameConfig (nomi, colori, statistiche);
## - le proporzioni e la silhouette sono qui sotto, una scheda per livello;
## - `set_profile()` permette di sovrascrivere uno stadio a runtime (utile per
##   provare nuovi modelli o per il bilanciamento) senza toccare altro codice.
##
## Nessuno stato viene duplicato: `profile_for()` è una funzione pura del
## livello, quindi l'aspetto non può mai disallinearsi da `evolution_level`.

const UNNAMED_STAGE: String = "STADIO"

static var _overrides: Dictionary = {}
static var _defaults: Dictionary = {}


static func clamp_level(level: int) -> int:
	return clampi(
		level,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)


static func count() -> int:
	return GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL + 1


## Profilo dello stadio richiesto, sempre limitato ai livelli validi.
static func profile_for(level: int) -> CarEvolutionProfile:
	var clamped := clamp_level(level)
	if _overrides.has(clamped):
		var overridden := _overrides[clamped] as CarEvolutionProfile
		if overridden != null:
			return overridden
	return _default_profile(clamped)


## Tutti i profili, ordinati dal livello minimo al massimo.
static func profiles() -> Array[CarEvolutionProfile]:
	var all: Array[CarEvolutionProfile] = []
	for level in range(GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL + 1):
		all.append(profile_for(level))
	return all


## Sovrascrive lo stadio di un livello (es. dall'inspector o dai test).
static func set_profile(profile: CarEvolutionProfile) -> void:
	if profile == null:
		return
	_overrides[clamp_level(profile.level)] = profile


static func clear_overrides() -> void:
	_overrides.clear()
	_defaults.clear()


# -------------------------------------------------------------- Defaults ---

static func _default_profile(level: int) -> CarEvolutionProfile:
	if _defaults.has(level):
		var cached := _defaults[level] as CarEvolutionProfile
		if cached != null:
			return cached
	var profile := _make_profile(level)
	_defaults[level] = profile
	return profile


static func _make_profile(level: int) -> CarEvolutionProfile:
	var profile := CarEvolutionProfile.new()
	profile.level = level
	profile.stage_name = _stage_name(level)
	profile.silhouette = _silhouette(level)
	profile.body_color = _evolution_color(level)
	profile.transform_duration = GameConfig.EVOLUTION_TRANSFORM_DURATION
	profile.speed_multiplier = _table_value(GameConfig.EVOLUTION_SPEED_MULTIPLIERS, level, 1.0)
	profile.handling_multiplier = _table_value(
		GameConfig.EVOLUTION_HANDLING_MULTIPLIERS,
		level,
		1.0,
	)
	_apply_shape(profile, level)
	_apply_palette(profile, level)
	if profile.silhouette == CarEvolutionProfile.Silhouette.HYPERCAR:
		# Sulla hypercar le spie stanno sul cofano motore, non sulla cupola.
		profile.pip_offset = Vector3(0.0, 0.52, 1.02)
	else:
		profile.pip_offset = Vector3(0.0, profile.roof_height + 0.06, 0.0)
	return profile


## Proporzioni di ogni stadio: è qui che si riconosce la silhouette.
## Le auto diventano progressivamente più lunghe, larghe e basse.
static func _apply_shape(profile: CarEvolutionProfile, level: int) -> void:
	match level:
		0:  # Rottame: microcar stretta, alta e corta, ruote piccole.
			profile.body_width = 1.30
			profile.body_length = 2.24
			profile.body_height = 0.42
			profile.roof_height = 1.26
			profile.ride_height = 0.36
			profile.wheel_radius = 0.27
			profile.wheel_width = 0.20
			profile.rear_wheel_width = 0.20
			profile.wheel_base_x = 0.62
			profile.wheel_base_z = 0.84
			profile.half_width = 0.76
			profile.half_length = 1.32
		1:  # Utilitaria: due volumi compatti, spigolosa e alta.
			profile.body_width = 1.50
			profile.body_length = 2.86
			profile.body_height = 0.36
			profile.roof_height = 1.04
			profile.ride_height = 0.30
			profile.wheel_radius = 0.30
			profile.wheel_width = 0.24
			profile.rear_wheel_width = 0.24
			profile.wheel_base_x = 0.72
			profile.wheel_base_z = 1.02
			profile.half_width = 0.82
			profile.half_length = 1.56
		2:  # Berlina: tre volumi, più lunga, abitacolo alto e vetrato.
			profile.body_width = 1.58
			profile.body_length = 3.20
			profile.body_height = 0.38
			profile.roof_height = 1.13
			profile.ride_height = 0.28
			profile.wheel_radius = 0.31
			profile.wheel_width = 0.25
			profile.rear_wheel_width = 0.26
			profile.wheel_base_x = 0.75
			profile.wheel_base_z = 1.14
			profile.half_width = 0.85
			profile.half_length = 1.74
		3:  # Sportiva: coupé bassa con cofano lungo e coda fastback.
			profile.body_width = 1.62
			profile.body_length = 3.04
			profile.body_height = 0.30
			profile.roof_height = 0.79
			profile.ride_height = 0.22
			profile.wheel_radius = 0.32
			profile.wheel_width = 0.28
			profile.rear_wheel_width = 0.32
			profile.wheel_base_x = 0.76
			profile.wheel_base_z = 1.10
			profile.half_width = 0.86
			profile.half_length = 1.70
		4:  # Supercar: larghissima, bassa, motore centrale e alettone alto.
			profile.body_width = 1.72
			profile.body_length = 3.22
			profile.body_height = 0.26
			profile.roof_height = 0.70
			profile.ride_height = 0.18
			profile.wheel_radius = 0.33
			profile.wheel_width = 0.30
			profile.rear_wheel_width = 0.36
			profile.wheel_base_x = 0.80
			profile.wheel_base_z = 1.16
			profile.half_width = 0.88
			profile.half_length = 1.78
		5:  # Hypercar: targa bassa, cupola in vetro, pinne e barre luminose.
			profile.body_width = 1.76
			profile.body_length = 3.30
			profile.body_height = 0.22
			profile.roof_height = 0.72
			profile.ride_height = 0.16
			profile.wheel_radius = 0.34
			profile.wheel_width = 0.30
			profile.rear_wheel_width = 0.38
			profile.wheel_base_x = 0.82
			profile.wheel_base_z = 1.20
			profile.half_width = 0.88
			profile.half_length = 1.80
		_:
			profile.body_width = 1.50
			profile.body_length = 2.86
			profile.body_height = 0.36
			profile.roof_height = 1.04
			profile.ride_height = 0.30


## Colori derivati da quello della carrozzeria, con eccezioni per stadio.
static func _apply_palette(profile: CarEvolutionProfile, _level: int) -> void:
	profile.glow_color = profile.body_color.lightened(0.35)
	profile.rim_color = profile.body_color.lightened(0.15)
	profile.trim_color = Color(0.11, 0.12, 0.15)
	profile.trim_alt_color = Color(0.26, 0.27, 0.31)
	profile.glass_color = Color(0.12, 0.18, 0.25)
	profile.tire_color = GameConfig.COLOR_TIRE
	profile.headlight_color = Color(1.0, 0.96, 0.78)
	profile.taillight_color = Color(0.96, 0.18, 0.18)
	match profile.silhouette:
		CarEvolutionProfile.Silhouette.WRECK:
			# Ruggine e plastica sbiadita: niente cromature.
			profile.trim_color = Color(0.16, 0.15, 0.16)
			profile.trim_alt_color = Color(0.40, 0.27, 0.19)
			profile.glass_color = Color(0.20, 0.25, 0.27)
			profile.rim_color = Color(0.36, 0.36, 0.38)
			profile.glow_color = Color(0.68, 0.58, 0.30)
			profile.headlight_color = Color(1.0, 0.90, 0.62)
		CarEvolutionProfile.Silhouette.HATCHBACK:
			profile.glass_color = Color(0.10, 0.17, 0.25)
			profile.rim_color = Color(0.78, 0.80, 0.84)
			profile.trim_alt_color = Color(0.22, 0.23, 0.27)
		CarEvolutionProfile.Silhouette.SEDAN:
			profile.trim_color = Color(0.13, 0.14, 0.17)
			profile.trim_alt_color = Color(0.80, 0.82, 0.86)  # profili cromati
			profile.glass_color = Color(0.12, 0.21, 0.29)
			profile.rim_color = Color(0.86, 0.88, 0.92)
		CarEvolutionProfile.Silhouette.COUPE:
			profile.trim_color = Color(0.09, 0.10, 0.12)
			profile.trim_alt_color = Color(0.24, 0.25, 0.29)
			profile.glass_color = Color(0.09, 0.16, 0.23)
			profile.rim_color = Color(0.30, 0.32, 0.36)
		CarEvolutionProfile.Silhouette.SUPERCAR:
			profile.trim_color = Color(0.08, 0.09, 0.12)
			profile.trim_alt_color = Color(0.20, 0.21, 0.25)
			profile.glass_color = Color(0.07, 0.14, 0.21)
			profile.rim_color = Color(0.16, 0.17, 0.20)
		CarEvolutionProfile.Silhouette.HYPERCAR:
			profile.trim_color = Color(0.09, 0.09, 0.13)
			profile.trim_alt_color = Color(0.20, 0.20, 0.28)
			profile.glass_color = Color(0.30, 0.62, 0.86)
			profile.glow_color = Color(0.62, 0.92, 1.0)
			profile.headlight_color = Color(0.78, 0.96, 1.0)
			profile.taillight_color = Color(1.0, 0.35, 0.55)
			profile.rim_color = Color(0.92, 0.94, 1.0)


static func _silhouette(level: int) -> int:
	match level:
		0:
			return CarEvolutionProfile.Silhouette.WRECK
		1:
			return CarEvolutionProfile.Silhouette.HATCHBACK
		2:
			return CarEvolutionProfile.Silhouette.SEDAN
		3:
			return CarEvolutionProfile.Silhouette.COUPE
		4:
			return CarEvolutionProfile.Silhouette.SUPERCAR
		_:
			return CarEvolutionProfile.Silhouette.HYPERCAR


static func _stage_name(level: int) -> String:
	var names := GameConfig.EVOLUTION_STAGE_NAMES
	var index := clamp_level(level) - GameConfig.EVOLUTION_MIN_LEVEL
	if index < 0 or index >= names.size():
		return UNNAMED_STAGE
	return names[index]


static func _evolution_color(level: int) -> Color:
	var colors := GameConfig.EVOLUTION_COLORS
	var index := clamp_level(level) - GameConfig.EVOLUTION_MIN_LEVEL
	if index < 0 or index >= colors.size():
		return Color(0.8, 0.8, 0.8)
	return colors[index]


static func _table_value(table: Array, level: int, fallback: float) -> float:
	var index := clamp_level(level) - GameConfig.EVOLUTION_MIN_LEVEL
	if index < 0 or index >= table.size():
		return fallback
	return float(table[index])
