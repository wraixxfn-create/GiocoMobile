class_name CarController
extends Node3D
## Movimento dell'auto del giocatore:
## - avanzamento automatico lungo la pista (asse -Z)
## - spostamento laterale tramite trascinamento touch o tastiera
## TODO(fase 2): collisioni con ostacoli/cancelli, animazioni di evoluzione.

signal speed_changed(new_speed: float)

@export var base_speed: float = GameConfig.CAR_BASE_SPEED
@export var lateral_speed: float = GameConfig.CAR_LATERAL_SPEED
@export var drag_sensitivity: float = GameConfig.CAR_DRAG_SENSITIVITY

var current_speed: float = 0.0
var lateral_limit: float = GameConfig.TRACK_WIDTH / 2.0 - 0.9

var _input_manager: InputManager = null
var _game_manager: GameManager = null
var _wheels: Array[Node3D] = []


func _ready() -> void:
	_input_manager = get_tree().get_first_node_in_group(&"input_manager") as InputManager
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	current_speed = base_speed
	_wheels = CarModel.build(self)


func _physics_process(delta: float) -> void:
	if _game_manager != null and _game_manager.state != GameManager.State.PLAYING:
		return

	# Avanzamento automatico.
	position.z -= current_speed * delta

	# Controllo laterale: trascinamento (pixel -> unità mondo) + tastiera.
	var drag_delta := 0.0
	if _input_manager != null:
		drag_delta = _input_manager.consume_lateral_delta()
	var keyboard_axis := Input.get_axis(&"ui_left", &"ui_right")
	var delta_x := drag_delta * drag_sensitivity + keyboard_axis * lateral_speed * delta
	position.x = clampf(position.x + delta_x, -lateral_limit, lateral_limit)

	# Inclinazione di guida per feedback visivo.
	var target_tilt := clampf(-delta_x * 0.06, -0.22, 0.22)
	rotation.z = lerpf(rotation.z, target_tilt, 0.15)

	# Rotazione delle ruote.
	for wheel in _wheels:
		wheel.rotation.x -= current_speed * delta / CarModel.WHEEL_RADIUS


## Imposta la velocità di avanzamento (usato in futuro dalle evoluzioni).
func set_speed(value: float) -> void:
	current_speed = maxf(value, 0.0)
	speed_changed.emit(current_speed)
