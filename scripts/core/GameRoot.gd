class_name GameRoot
extends Node
## Radice della scena principale: ambiente 3D, camera e collegamento dei
## sottosistemi al ciclo di gioco/menu della UI.

@onready var _game_manager: GameManager = $GameManager
@onready var _input_manager: InputManager = $InputManager
@onready var _track_manager: TrackManager = $TrackManager
@onready var _gate_manager: GateManager = $GateManager
@onready var _obstacle_manager: ObstacleManager = $ObstacleManager
@onready var _coin_manager: CoinManager = $CoinManager
@onready var _hud: HUD = $HUD
@onready var _car: CarController = $Player
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/MainCamera
@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	# Il gameplay resta effettivamente pausable anche quando la scena è ospitata
	# da un nodo/processo che continua a girare durante la pausa.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_environment()
	_setup_sun()
	_setup_camera()
	_update_camera()

	_game_manager.setup(_car)
	_game_manager.distance_updated.connect(_hud.set_distance)
	_game_manager.coins_updated.connect(_hud.set_coins)
	_game_manager.permanent_coins_updated.connect(_hud.set_permanent_coins)
	_game_manager.state_changed.connect(_hud.set_state)
	_game_manager.state_changed.connect(_on_game_state_changed)
	_game_manager.countdown_updated.connect(_hud.set_countdown)
	_game_manager.evolution_changed.connect(_hud.set_evolution)
	_game_manager.run_finished.connect(_hud.show_run_results)
	_game_manager.run_reset_requested.connect(_reset_world_for_run)
	_coin_manager.coin_collected.connect(_hud.play_coin_pickup_animation)
	_gate_manager.gate_crossed.connect(_hud.show_gate_feedback)
	_obstacle_manager.obstacle_hit.connect(_hud.show_obstacle_feedback)

	_hud.set_goal_distance(_game_manager.race_distance_meters)
	_hud.play_requested.connect(_game_manager.start_game)
	_hud.replay_requested.connect(_game_manager.start_game)
	_hud.pause_requested.connect(_game_manager.pause_game)
	_hud.resume_requested.connect(_game_manager.resume_game)
	_hud.menu_requested.connect(_game_manager.return_to_menu)
	_input_manager.pause_requested.connect(_game_manager.pause_game)
	_input_manager.resume_requested.connect(_game_manager.resume_game)

	_hud.set_distance(floori(_game_manager.distance))
	_hud.set_coins(_game_manager.session_coins)
	_hud.set_permanent_coins(_game_manager.permanent_coins)
	_hud.set_evolution(
		_game_manager.evolution_level,
		0,
		_game_manager.evolution_profile(),
	)


func _process(_delta: float) -> void:
	_update_camera()


func _on_game_state_changed(_new_state: GameManager.State) -> void:
	# Aggiorna subito la camera anche se una vittoria sposta l'auto esattamente
	# sulla linea del traguardo e mette in pausa la scena nello stesso frame.
	_update_camera()


## Ripristino coerente di una nuova corsa: prima l'auto e la pista, poi le
## ancore dei cancelli, gli ostacoli dipendenti da esse e infine le monete.
func _reset_world_for_run() -> void:
	_input_manager.reset_controls()
	_car.reset_for_new_run()
	_track_manager.reset_run()
	_gate_manager.reset_run()
	_obstacle_manager.reset_run()
	_coin_manager.reset_run()
	_update_camera()


func _update_camera() -> void:
	if _car == null:
		return

	# La telecamera segue l'auto lateralmente senza ritardo: l'auto resta
	# stabile al centro dell'inquadratura ed è la pista a scorrere.
	_camera_rig.position.x = _car.position.x * GameConfig.CAMERA_LATERAL_FOLLOW
	_camera_rig.position.y = GameConfig.CAMERA_HEIGHT
	_camera_rig.position.z = _car.position.z + GameConfig.CAMERA_DISTANCE

	var look_target := Vector3(
		_camera_rig.position.x,
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
