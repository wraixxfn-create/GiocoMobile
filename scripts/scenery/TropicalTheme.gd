class_name TropicalTheme
extends RefCounted
## Direzione artistica del livello dimostrativo: cielo, luce e camera in un
## unico punto, coerenti con la palette (`SceneryPalette`).
##
## Scelte pensate per il mobile:
## - **una sola luce direzionale** con ombre morbide (2 split, 62 m): nessun
##   SSAO, nessun glow, nessuna luce dinamica aggiuntiva;
## - ambiente preso dal cielo con una quota di colore fisso, così le zone in
##   ombra restano leggibili e un po' fredde (contrasto con il sole caldo);
## - foschia per profondità che parte dopo i 90 m: separa primo piano, piano
##   intermedio e sfondo senza costare nulla;
## - camera più bassa e vicina: l'auto resta il soggetto, la strada si apre
##   davanti e i cancelli sono visibili molto prima di attraversarli.

## Direzione del sole: da sinistra, alto, leggermente dietro la camera.
## Le ombre cadono in avanti a destra, leggibili sulla carreggiata.
const SUN_ROTATION_DEG := Vector3(-46.0, 26.0, 0.0)
const SUN_ENERGY: float = 1.14
const AMBIENT_ENERGY: float = 0.30
const SHADOW_DISTANCE: float = 62.0
const SHADOW_OPACITY: float = 0.80
const SHADOW_BLUR: float = 1.5
const FOG_BEGIN: float = 130.0
const FOG_END: float = 430.0


## Cielo procedurale: azzurro pieno in alto, orizzonte chiaro e caldo.
static func build_sky() -> Sky:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = SceneryPalette.SKY_TOP
	material.sky_horizon_color = SceneryPalette.SKY_HORIZON
	material.sky_curve = 0.11
	material.sky_energy_multiplier = 1.06
	material.ground_horizon_color = SceneryPalette.FOG_COLOR
	material.ground_bottom_color = SceneryPalette.SKY_GROUND
	material.ground_curve = 0.04
	material.sun_angle_max = 12.0
	material.sun_curve = 0.09
	var sky := Sky.new()
	sky.sky_material = material
	# Riflessi a bassa risoluzione: bastano per le vernici metallizzate.
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky


## Applica l'ambiente completo (cielo, tonemapping, foschia) all'Environment.
static func apply_environment(environment: Environment) -> void:
	environment.background_mode = Environment.BG_SKY
	environment.sky = build_sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = SceneryPalette.AMBIENT_COLOR
	environment.ambient_light_sky_contribution = 0.18
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Nessun effetto pesante: solo tonemapping e correzioni colore.
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.97
	environment.tonemap_white = 1.18
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.01
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.20
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.volumetric_fog_enabled = false

	# Foschia di profondità: schiarisce lo sfondo verso il colore dell'orizzonte.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = SceneryPalette.FOG_COLOR
	environment.fog_light_energy = 1.0
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.9
	environment.fog_sky_affect = 0.10


## Configura l'unica luce direzionale della scena.
static func configure_sun(sun: DirectionalLight3D) -> void:
	sun.rotation = Vector3(
		deg_to_rad(SUN_ROTATION_DEG.x),
		deg_to_rad(SUN_ROTATION_DEG.y),
		deg_to_rad(SUN_ROTATION_DEG.z),
	)
	sun.light_color = SceneryPalette.SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.light_specular = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.directional_shadow_fade_start = 0.86
	sun.directional_shadow_split_1 = 0.28
	sun.shadow_opacity = SHADOW_OPACITY
	sun.shadow_blur = SHADOW_BLUR
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.1
	sun.light_angular_distance = 0.35


## Impostazioni della telecamera di gioco (inquadratura, non movimento).
static func configure_camera(camera: Camera3D) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = GameConfig.CAMERA_FOV
	camera.near = 0.12
	camera.far = 560.0
