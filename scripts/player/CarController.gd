class_name CarController
extends Node3D
## Movimento dell'auto del giocatore:
## - avanzamento automatico e costante lungo l'asse -Z della pista
## - spostamento laterale tramite trascinamento touch/mouse o tastiera
##
## Lo sterzo usa un punto target che il giocatore sposta con il trascinamento.
## La posizione reale lo insegue con un'interpolazione esponenziale, quindi il
## movimento è fluido, senza scatti e indipendente dal frame rate. Il target e
## la posizione sono sempre limitati ai bordi dell'asfalto.
## TODO(fase 2): collisioni con ostacoli/cancelli, animazioni di evoluzione.

signal speed_changed(new_speed: float)

const DEFAULT_TUNING_PATH: String = "res://config/driving_tuning.tres"
const STEER_VISUAL_RESPONSE: float = 12.0
const STEER_YAW_PER_METER: float = 0.02
const STEER_TILT_PER_METER: float = 0.01
const FRONT_WHEEL_STEER_PER_METER: float = 0.035
const MIN_STEP: float = 0.0001

## Parametri centralizzati di velocità e sensibilità (config/driving_tuning.tres).
@export var tuning: DrivingTuning

var current_speed: float = 0.0
## Distanza massima del centro auto dal centro pista, calcolata sull'ingombro.
var lateral_limit: float = 0.0
## Posizione laterale desiderata: resta ferma quando il dito viene sollevato.
var lateral_target: float = 0.0

var _input_manager: InputManager = null
var _game_manager: GameManager = null
var _wheels: Array[Node3D] = []


func _ready() -> void:
	if tuning == null:
		tuning = load(DEFAULT_TUNING_PATH) as DrivingTuning
	if tuning == null:
		tuning = DrivingTuning.new()
		push_warning("DrivingTuning non trovato: uso i valori predefiniti.")
	current_speed = tuning.forward_speed
	_recalculate_lateral_limit()
	lateral_target = clampf(position.x, -lateral_limit, lateral_limit)

	_input_manager = get_tree().get_first_node_in_group(&"input_manager") as InputManager
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	if _game_manager != null:
		_game_manager.state_changed.connect(_on_game_state_changed)
	_wheels = CarModel.build(self)


func _physics_process(delta: float) -> void:
	if _game_manager != null and _game_manager.state != GameManager.State.PLAYING:
		return

	var step := maxf(delta, 0.0)

	# Avanzamento automatico lungo l'asse -Z verso l'orizzonte, a velocità costante.
	position.z -= current_speed * step

	_update_lateral_target(step)
	_apply_lateral_motion(step)


func _update_lateral_target(step: float) -> void:
	var drag_fraction := 0.0
	var keyboard_axis := 0.0
	if _input_manager != null:
		drag_fraction = _input_manager.consume_lateral_drag()
		keyboard_axis = _input_manager.get_keyboard_axis()
	else:
		keyboard_axis = Input.get_axis(&"ui_left", &"ui_right")

	# Il drag è relativo: sposta il target di una frazione di larghezza schermo.
	if not is_zero_approx(drag_fraction):
		lateral_target += drag_fraction * tuning.drag_sensitivity

	# La tastiera aggiorna il target in modo continuo, sempre con il tempo reale.
	if not is_zero_approx(keyboard_axis):
		lateral_target += keyboard_axis * tuning.keyboard_lateral_speed * step

	# I bordi valgono sia per il target sia per la posizione reale.
	lateral_target = clampf(lateral_target, -lateral_limit, lateral_limit)


func _apply_lateral_motion(step: float) -> void:
	var previous_x := position.x

	# Interpolazione esponenziale: stessa curva a 30, 60 o 120 FPS.
	var blend := 1.0 - exp(-tuning.lateral_response * step)
	var next_x := lerpf(position.x, lateral_target, blend)

	# Ulteriore limite di sicurezza contro trascinamenti molto bruschi.
	if tuning.max_lateral_speed > 0.0:
		next_x = move_toward(position.x, next_x, tuning.max_lateral_speed * step)

	position.x = clampf(next_x, -lateral_limit, lateral_limit)
	_update_visual_feedback((position.x - previous_x) / maxf(step, MIN_STEP), step)


func _update_visual_feedback(lateral_velocity: float, step: float) -> void:
	# Feedback visivo fluido: leggera sterzata sull'asse Y e rollio sull'asse Z.
	var steer_blend := 1.0 - exp(-STEER_VISUAL_RESPONSE * step)
	var target_yaw := clampf(
		-lateral_velocity * STEER_YAW_PER_METER,
		-GameConfig.CAR_MAX_STEER_YAW,
		GameConfig.CAR_MAX_STEER_YAW,
	)
	var target_tilt := clampf(-lateral_velocity * STEER_TILT_PER_METER, -0.10, 0.10)
	rotation.y = lerpf(rotation.y, target_yaw, steer_blend)
	rotation.z = lerpf(rotation.z, target_tilt, steer_blend)

	# Rotazione ruote e sterzata delle due ruote anteriori.
	var wheel_spin := current_speed * step / CarModel.WHEEL_RADIUS
	var front_steer := clampf(-lateral_velocity * FRONT_WHEEL_STEER_PER_METER, -0.32, 0.32)
	for index in _wheels.size():
		var wheel: Node3D = _wheels[index]
		wheel.rotation.x -= wheel_spin
		if index < 2:
			wheel.rotation.y = lerpf(wheel.rotation.y, front_steer, steer_blend)


## Limite laterale derivato dall'ingombro reale dell'auto ruotata al massimo.
## In questo modo nemmeno gli angoli della carrozzeria possono superare il bordo.
func _recalculate_lateral_limit() -> void:
	var yaw := GameConfig.CAR_MAX_STEER_YAW
	var half_extent := (
		GameConfig.CAR_HALF_WIDTH * cos(yaw)
		+ GameConfig.CAR_HALF_LENGTH * sin(yaw)
	)
	lateral_limit = maxf(
		GameConfig.TRACK_WIDTH * 0.5 - half_extent - GameConfig.CAR_EDGE_MARGIN,
		0.0,
	)


func _on_game_state_changed(new_state: GameManager.State) -> void:
	# All'avvio (e in un eventuale reset) riallinea il target alla posizione
	# reale, senza trascinare input accumulato prima della partita.
	if new_state == GameManager.State.PLAYING or new_state == GameManager.State.IDLE:
		lateral_target = clampf(position.x, -lateral_limit, lateral_limit)


## Imposta la velocità di avanzamento (usato in futuro dalle evoluzioni).
func set_speed(value: float) -> void:
	current_speed = maxf(value, 0.0)
	speed_changed.emit(current_speed)
