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
##
## L'auto non rileva i cancelli: l'attraversamento è calcolato in 3D da
## GateManager. Qui si reagisce al livello di evoluzione, aggiornando:
## - l'aspetto dell'auto (delegato a `CarEvolutionDirector`);
## - le statistiche dello stadio (velocità e reattività dello sterzo).
## Nulla di tutto questo tocca posizione, sterzo o velocità in corso: il
## cambio di modello riguarda solo un nodo figlio.

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
## Moltiplicatori dello stadio corrente (letti dal profilo di evoluzione).
var evolution_speed_multiplier: float = 1.0
var evolution_handling_multiplier: float = 1.0
## Se true la velocità non viene aggiornata al cambio di evoluzione
## (usato dai test e da eventuali pause: la marcia resta congelata).
var speed_locked: bool = false

var _input_manager: InputManager = null
var _game_manager: GameManager = null
var _wheels: Array[Node3D] = []
## Nodo "CarVisual": possiede il modello dello stadio e la sua animazione.
var _director: CarEvolutionDirector = null


func _ready() -> void:
	if tuning == null:
		tuning = load(DEFAULT_TUNING_PATH) as DrivingTuning
	if tuning == null:
		tuning = DrivingTuning.new()
		push_warning("DrivingTuning non trovato: uso i valori predefiniti.")
	current_speed = tuning.forward_speed

	_input_manager = get_tree().get_first_node_in_group(&"input_manager") as InputManager
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	if _game_manager != null:
		_game_manager.state_changed.connect(_on_game_state_changed)
		_game_manager.evolution_changed.connect(_on_evolution_changed)

	_setup_evolution_visual()
	_recalculate_lateral_limit()
	lateral_target = clampf(position.x, -lateral_limit, lateral_limit)


# ------------------------------------------------------------- Evoluzione ---

## Crea (o recupera) il direttore del modello e lo allinea al livello attuale.
func _setup_evolution_visual() -> void:
	_director = _resolve_director()
	if _director != null:
		_director.stage_ready.connect(_on_stage_ready)
		var initial_level := (
			_game_manager.evolution_level if _game_manager != null
			else GameConfig.EVOLUTION_START_LEVEL
		)
		_director.setup(initial_level)
		_wheels = _director.get_wheels()
	_apply_evolution_stats(evolution_profile())


func _resolve_director() -> CarEvolutionDirector:
	var found := get_node_or_null(CarModel.DIRECTOR_NODE_NAME) as CarEvolutionDirector
	if found == null:
		# La scena può essere istanziata senza il nodo (es. test): lo creiamo.
		found = CarEvolutionDirector.new()
		found.name = CarModel.DIRECTOR_NODE_NAME
		add_child(found)
	return found


## Profilo dello stadio corrente: fonte unica delle statistiche di gioco.
func evolution_profile() -> CarEvolutionProfile:
	if _director != null and _director.current_profile != null:
		return _director.current_profile
	if _game_manager != null:
		return CarEvolutionCatalog.profile_for(_game_manager.evolution_level)
	return CarEvolutionCatalog.profile_for(GameConfig.EVOLUTION_START_LEVEL)


## Il livello di evoluzione è gestito da GameManager: qui si aggiornano
## l'aspetto dell'auto e le statistiche dello stadio.
func _on_evolution_changed(level: int, _delta: int, profile: CarEvolutionProfile = null) -> void:
	_apply_evolution_stats(profile)
	if _director != null:
		_director.apply_level(level, true)


## Applica le statistiche dello stadio. La velocità viene ricalcolata dalla
## taratura di base, quindi resta sempre coerente con il livello mostrato.
func _apply_evolution_stats(profile: CarEvolutionProfile) -> void:
	if profile == null:
		profile = evolution_profile()
	if profile == null:
		return
	evolution_speed_multiplier = profile.speed_multiplier
	evolution_handling_multiplier = profile.handling_multiplier
	_recalculate_lateral_limit()
	_refresh_speed()


func _refresh_speed() -> void:
	if speed_locked or tuning == null:
		return
	var target := tuning.forward_speed * evolution_speed_multiplier
	if absf(current_speed - target) > 0.0001:
		current_speed = maxf(target, 0.0)
		speed_changed.emit(current_speed)


## Dopo un cambio di modello le ruote sono nuove: vanno ricollegate.
func _on_stage_ready(_level: int, _profile: CarEvolutionProfile) -> void:
	if _director == null:
		return
	_wheels = _director.get_wheels()
	_recalculate_lateral_limit()
	lateral_target = clampf(lateral_target, -lateral_limit, lateral_limit)
	position.x = clampf(position.x, -lateral_limit, lateral_limit)
	_refresh_speed()


# ---------------------------------------------------------------- Movimento --

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
	# La reattività tiene conto dello stadio di evoluzione (auto più pronte).
	var response := tuning.lateral_response * evolution_handling_multiplier
	var blend := 1.0 - exp(-response * step)
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
	var wheel_radius := CarModel.WHEEL_RADIUS
	if _director != null:
		wheel_radius = maxf(_director.wheel_radius, 0.05)
	var wheel_spin := current_speed * step / wheel_radius
	var front_steer := clampf(-lateral_velocity * FRONT_WHEEL_STEER_PER_METER, -0.32, 0.32)
	for index in _wheels.size():
		var wheel: Node3D = _wheels[index]
		if not is_instance_valid(wheel):
			continue
		wheel.rotation.x -= wheel_spin
		if index < 2:
			wheel.rotation.y = lerpf(wheel.rotation.y, front_steer, steer_blend)


## Limite laterale derivato dall'ingombro reale dell'auto ruotata al massimo.
## In questo modo nemmeno gli angoli della carrozzeria possono superare il bordo.
## L'ingombro è quello dello stadio corrente: le auto evolute sono più lunghe.
func _recalculate_lateral_limit() -> void:
	var profile := evolution_profile()
	var half_extent := profile.lateral_half_extent(GameConfig.CAR_MAX_STEER_YAW)
	lateral_limit = maxf(
		GameConfig.TRACK_WIDTH * 0.5 - half_extent - GameConfig.CAR_EDGE_MARGIN,
		0.0,
	)


func _on_game_state_changed(new_state: GameManager.State) -> void:
	# All'avvio (e in un eventuale reset) riallinea il target alla posizione
	# reale, senza trascinare input accumulato prima della partita.
	if new_state == GameManager.State.PLAYING or new_state == GameManager.State.IDLE:
		lateral_target = clampf(position.x, -lateral_limit, lateral_limit)


## Imposta la velocità di avanzamento. Con `lock = true` la velocità resta
## fissata anche quando cambia l'evoluzione (serve ai test e alle pause).
func set_speed(value: float, lock: bool = false) -> void:
	current_speed = maxf(value, 0.0)
	if lock:
		speed_locked = true
	speed_changed.emit(current_speed)
