class_name GameRoot
extends Node
## Nodo radice della scena principale.
## Responsabilità: bootstrap dell'ambiente (luce, ambiente, camera)
## e collegamento dei sottosistemi (gameplay, input, pista, UI).

@onready var _game_manager: GameManager = $GameManager
@onready var _hud: HUD = $HUD
@onready var _car: CarController = $Player
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/MainCamera


func _ready() -> void:
	_setup_environment()
	_setup_sun()
	_setup_camera()

	_game_manager.setup(_car)
	_game_manager.score_updated.connect(_hud.set_distance)
	_game_manager.coins_updated.connect(_hud.set_coins)
	_game_manager.state_changed.connect(_hud.set_state)

	var input_manager := get_tree().get_first_node_in_group(&"input_manager") as InputManager
	if input_manager != null:
		input_manager.start_requested.connect(_game_manager.start_game)

	_hud.set_distance(0)
	_hud.set_coins(0)


func _process(_delta: float) -> void:
	if _car == null:
		return
	# La camera segue l'auto: avanza con lei e inseguimento morbido laterale.
	_camera_rig.position.x = lerp(_camera_rig.position.x, _car.position.x * 0.55, 0.08)
	_camera_rig.position.y = 5.2
	_camera_rig.position.z = _car.position.z + 8.8
	_camera.look_at(Vector3(_car.position.x * 0.85, 0.9, _car.position.z - 12.0), Vector3.UP)


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = GameConfig.COLOR_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = GameConfig.COLOR_AMBIENT
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = GameConfig.COLOR_SKY
	environment.fog_density = 0.012
	$WorldEnvironment.environment = environment


func _setup_sun() -> void:
	var sun := $Sun as DirectionalLight3D
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(20.0), 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = false


func _setup_camera() -> void:
	_camera.current = true
	_camera.fov = 62.0
	_camera.near = 0.1
	_camera.far = 200.0
