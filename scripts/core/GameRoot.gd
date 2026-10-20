class_name GameRoot
extends Node
## Nodo radice della scena principale.
## Responsabilità: bootstrap dell'ambiente 3D (cielo, luce, ombre, camera)
## e collegamento dei sottosistemi (gameplay, input, pista, UI).

@onready var _game_manager: GameManager = $GameManager
@onready var _hud: HUD = $HUD
@onready var _car: CarController = $Player
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/MainCamera
@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_setup_environment()
	_setup_sun()
	_setup_camera()
	_update_camera(1.0, false)

	_game_manager.setup(_car)
	_game_manager.score_updated.connect(_hud.set_distance)
	_game_manager.coins_updated.connect(_hud.set_coins)
	_game_manager.state_changed.connect(_hud.set_state)

	var input_manager := get_tree().get_first_node_in_group(&"input_manager") as InputManager
	if input_manager != null:
		input_manager.start_requested.connect(_game_manager.start_game)

	_hud.set_distance(0)
	_hud.set_coins(0)


func _process(delta: float) -> void:
	_update_camera(delta, true)


func _update_camera(delta: float, smooth: bool) -> void:
	if _car == null:
		return
	var target_rig_x := _car.position.x * 0.58
	if smooth:
		var weight := 1.0 - exp(-GameConfig.CAMERA_FOLLOW_SPEED * delta)
		_camera_rig.position.x = lerpf(_camera_rig.position.x, target_rig_x, weight)
	else:
		_camera_rig.position.x = target_rig_x

	_camera_rig.position.y = GameConfig.CAMERA_HEIGHT
	_camera_rig.position.z = _car.position.z + GameConfig.CAMERA_DISTANCE

	var look_target := Vector3(
		_car.position.x * 0.82,
		GameConfig.CAMERA_LOOK_HEIGHT,
		_car.position.z - GameConfig.CAMERA_LOOK_AHEAD,
	)
	_camera.look_at_from_position(_camera_rig.position, look_target, Vector3.UP)


func _setup_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = GameConfig.COLOR_SKY_TOP
	sky_material.sky_horizon_color = GameConfig.COLOR_SKY_HORIZON
	sky_material.sky_curve = 0.14
	sky_material.ground_horizon_color = GameConfig.COLOR_GROUND_HORIZON
	sky_material.ground_bottom_color = GameConfig.COLOR_GRASS_ALT
	sky_material.ground_curve = 0.04
	sky_material.sun_angle_max = 22.0
	sky_material.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = GameConfig.COLOR_AMBIENT
	environment.ambient_light_sky_contribution = 0.55
	environment.ambient_light_energy = 0.85

	# Nebbia di profondità sul fondo: fonde senza stacchi pista e terreno nell'orizzonte.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = GameConfig.COLOR_SKY_HORIZON
	environment.fog_light_energy = 1.0
	environment.fog_depth_begin = 95.0
	environment.fog_depth_end = 275.0
	environment.fog_depth_curve = 1.15
	environment.fog_sky_affect = 0.2

	_world_environment.environment = environment


func _setup_sun() -> void:
	_sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(28.0), 0.0)
	_sun.light_color = GameConfig.COLOR_SUN
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 75.0
	_sun.directional_shadow_fade_start = 0.8
	_sun.shadow_opacity = 0.72
	_sun.shadow_blur = 1.0
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.5


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	_camera.fov = GameConfig.CAMERA_FOV
	_camera.near = 0.15
	_camera.far = 380.0
