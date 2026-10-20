class_name CarController
extends Node3D
## Movimento dell'auto del giocatore:
## - avanzamento automatico lungo la pista (asse -Z)
## - spostamento laterale tramite trascinamento touch, mouse o tastiera
## TODO(fase 2): collisioni con ostacoli/cancelli, animazioni di evoluzione.

signal speed_changed(new_speed: float)

@export var base_speed: float = GameConfig.CAR_BASE_SPEED
@export var lateral_speed: float = GameConfig.CAR_LATERAL_SPEED
@export var drag_sensitivity: float = GameConfig.CAR_DRAG_SENSITIVITY

var current_speed: float = 0.0
var lateral_limit: float = GameConfig.TRACK_WIDTH / 2.0 - GameConfig.CAR_HALF_WIDTH_MARGIN

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

	# Avanzamento automatico lungo l'asse -Z verso l'orizzonte.
	position.z -= current_speed * delta

	# Controllo laterale unificato (touch/mouse drag + tastiera frecce / A,D).
	var drag_delta := 0.0
	var keyboard_axis := 0.0
	if _input_manager != null:
		drag_delta = _input_manager.consume_lateral_delta()
		keyboard_axis = _input_manager.get_keyboard_axis()
	else:
		keyboard_axis = Input.get_axis(&"ui_left", &"ui_right")

	var prev_x: float = position.x
	var delta_x := drag_delta * drag_sensitivity + keyboard_axis * lateral_speed * delta
	position.x = clampf(position.x + delta_x, -lateral_limit, lateral_limit)

	# Feedback visivo fluido: leggera sterzata sull'asse Y e rollio sull'asse Z.
	var lateral_velocity := (position.x - prev_x) / maxf(delta, 0.0001)
	var steer_blend := 1.0 - exp(-10.0 * delta)
	var target_yaw := clampf(-lateral_velocity * 0.02, -0.18, 0.18)
	var target_tilt := clampf(-lateral_velocity * 0.01, -0.10, 0.10)
	rotation.y = lerpf(rotation.y, target_yaw, steer_blend)
	rotation.z = lerpf(rotation.z, target_tilt, steer_blend)

	# Rotazione ruote e sterzata delle due ruote anteriori.
	var wheel_spin := current_speed * delta / CarModel.WHEEL_RADIUS
	var front_steer := clampf(-lateral_velocity * 0.035, -0.32, 0.32)
	for index in _wheels.size():
		var wheel: Node3D = _wheels[index]
		wheel.rotation.x -= wheel_spin
		if index < 2:
			wheel.rotation.y = lerpf(wheel.rotation.y, front_steer, steer_blend)


## Imposta la velocità di avanzamento (usato in futuro dalle evoluzioni).
func set_speed(value: float) -> void:
	current_speed = maxf(value, 0.0)
	speed_changed.emit(current_speed)
