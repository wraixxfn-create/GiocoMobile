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
## Moltiplicatori effettivi calcolati dal profilo e dai componenti equipaggiati.
var evolution_speed_multiplier: float = 1.0
var evolution_handling_multiplier: float = 1.0
var effective_half_width: float = GameConfig.CAR_HALF_WIDTH
var effective_half_length: float = GameConfig.CAR_HALF_LENGTH
## Se true la velocità non viene aggiornata al cambio di evoluzione
## (usato dai test e da eventuali pause: la marcia resta congelata).
var speed_locked: bool = false
## Penalità temporanea di velocità (collisione con un ostacolo): moltiplicatore
## applicato alla velocità base dello stadio. 1.0 = nessuna penalità attiva.
## Il recupero è graduale: la corsa non torna mai istantaneamente normale.
var speed_penalty_factor: float = 1.0

var _penalty_factor: float = 1.0
var _penalty_time_left: float = 0.0
var _penalty_duration: float = 0.0
var _shake_time_left: float = 0.0
var _shake_intensity: float = 0.0

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
		_director.part_changed.connect(_on_part_changed)
		var initial_level := (
			_game_manager.evolution_level if _game_manager != null
			else GameConfig.EVOLUTION_START_LEVEL
		)
		_director.setup(initial_level)
		_wheels = _director.get_wheels()
	_apply_evolution_stats(evolution_profile())


func _resolve_director() -> CarEvolutionDirector:
	var found := get_node_or_null(CarEvolutionDirector.DIRECTOR_NODE_NAME) as CarEvolutionDirector
	if found == null:
		# La scena può essere istanziata senza il nodo (es. test): lo creiamo.
		found = CarEvolutionDirector.new()
		found.name = CarEvolutionDirector.DIRECTOR_NODE_NAME
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
	if _director != null and _director.get_rig() != null:
		var stats := _director.effective_stats()
		evolution_speed_multiplier = float(stats.get("speed_multiplier", profile.speed_multiplier))
		evolution_handling_multiplier = float(
			stats.get("handling_multiplier", profile.handling_multiplier)
		)
		effective_half_width = float(stats.get("half_width", profile.half_width))
		effective_half_length = float(stats.get("half_length", profile.half_length))
	else:
		evolution_speed_multiplier = profile.speed_multiplier
		evolution_handling_multiplier = profile.handling_multiplier
		effective_half_width = profile.half_width
		effective_half_length = profile.half_length
	_recalculate_lateral_limit()
	_refresh_speed()


## Sostituisce un singolo componente modulare sul veicolo senza ricostruire la
## gerarchia e ricalcola immediatamente statistiche e ingombri fisici.
func equip_part(
	part: CarPartDefinition,
	enforce_level: bool = false,
	pin_across_stages: bool = false,
) -> Dictionary:
	if _director == null:
		return {"ok": false, "changed": false, "reason": -1, "message": "Direttore assente"}
	return _director.equip_part(part, enforce_level, pin_across_stages)


func equip_part_by_id(
	part_id: StringName,
	enforce_level: bool = false,
	pin_across_stages: bool = false,
) -> Dictionary:
	if _director == null:
		return {"ok": false, "changed": false, "reason": -1, "message": "Direttore assente"}
	return _director.equip_part_by_id(part_id, enforce_level, pin_across_stages)


func get_equipped_part(slot: int) -> CarPartDefinition:
	return _director.get_equipped_part(slot) if _director != null else null


func get_equipped_part_id(slot: int) -> StringName:
	return _director.get_equipped_part_id(slot) if _director != null else &""


## Semi-assi fisici XZ dell'auto ruotata di `yaw`, inclusivi delle parti montate.
func effective_half_extents(yaw: float) -> Vector2:
	var profile := evolution_profile()
	var hw := effective_half_width if effective_half_width > 0.0 else profile.half_width
	var hl := effective_half_length if effective_half_length > 0.0 else profile.half_length
	return Vector2(
		CarStatsAggregator.lateral_half_extent(hw, hl, yaw),
		CarStatsAggregator.longitudinal_half_extent(hw, hl, yaw),
	)


func _refresh_speed() -> void:
	if speed_locked or tuning == null:
		return
	var target := tuning.forward_speed * evolution_speed_multiplier * speed_penalty_factor
	if absf(current_speed - target) > 0.0001:
		current_speed = maxf(target, 0.0)
		speed_changed.emit(current_speed)


# ------------------------------------------------- Penalità e feedback urti --

## Perdita di velocità temporanea (collisione con ostacolo). Non tocca mai il
## livello di evoluzione: è uno dei due possibili effetti di un urto, l'altro
## (gestito da ObstacleManager) è la regressione di un livello.
## Con `speed_locked` (test/pause) la penalità viene ignorata.
func apply_speed_penalty(factor: float, duration: float) -> void:
	if speed_locked or tuning == null:
		return
	var clamped_factor := clampf(factor, 0.05, 1.0)
	var clamped_duration := maxf(duration, 0.05)
	# Vince la penalità più severa; la durata si estende, mai si accorcia.
	if _penalty_time_left > 0.0:
		_penalty_factor = minf(_penalty_factor, clamped_factor)
		clamped_duration = maxf(clamped_duration, _penalty_time_left)
	else:
		_penalty_factor = clamped_factor
	_penalty_duration = clamped_duration
	_penalty_time_left = clamped_duration
	speed_penalty_factor = _penalty_factor
	_refresh_speed()


## True se è attiva una penalità di velocità.
func is_speed_penalized() -> bool:
	return speed_penalty_factor < 1.0 or _penalty_time_left > 0.0


## Breve scuotimento dell'auto dopo un urto: solo visivo, decade a zero da solo
## e non tocca posizione laterale, sterzo o avanzamento.
func add_impact_shake(intensity: float = 1.0) -> void:
	_shake_intensity = clampf(maxf(_shake_intensity, intensity), 0.0, 1.5)
	_shake_time_left = GameConfig.OBSTACLE_SHAKE_DURATION


func is_shaking() -> bool:
	return _shake_time_left > 0.0


## Aggiorna la penalità di velocità: tiene il fattore basso per una frazione
## della durata, poi recupera con una curva dolce fino a 1.0. Il timer avanza
## anche a velocità bloccata (test/pause), così lo sblocco non "eredita" una
## penalità già scaduta; la velocità bloccata invece non viene modificata.
func _update_speed_penalty(step: float) -> void:
	if _penalty_time_left <= 0.0:
		if speed_penalty_factor != 1.0:
			speed_penalty_factor = 1.0
			_penalty_factor = 1.0
			_refresh_speed()
		return
	_penalty_time_left = maxf(_penalty_time_left - step, 0.0)
	var progress := 1.0
	if _penalty_duration > 0.0:
		progress = clampf(1.0 - _penalty_time_left / _penalty_duration, 0.0, 1.0)
	var hold := clampf(GameConfig.OBSTACLE_PENALTY_HOLD_FRACTION, 0.0, 0.9)
	if progress <= hold:
		speed_penalty_factor = _penalty_factor
	else:
		var recovery := (progress - hold) / (1.0 - hold)
		recovery = recovery * recovery * (3.0 - 2.0 * recovery)
		speed_penalty_factor = lerpf(_penalty_factor, 1.0, recovery)
	if _penalty_time_left <= 0.0:
		speed_penalty_factor = 1.0
		_penalty_factor = 1.0
	_refresh_speed()


## Scuotimento da urto: oscillazione smorzata di imbardata/rollio e un piccolo
## sobbalzo verticale. A fine animazione tutto torna esattamente a riposo.
func _update_impact_shake(step: float) -> void:
	if _shake_time_left <= 0.0:
		return
	_shake_time_left = maxf(_shake_time_left - step, 0.0)
	var duration := GameConfig.OBSTACLE_SHAKE_DURATION
	var progress := clampf(1.0 - _shake_time_left / duration, 0.0, 1.0)
	if _shake_time_left <= 0.0:
		_shake_intensity = 0.0
		position.y = 0.0
		return
	var decay := (1.0 - progress) * _shake_intensity
	var wobble := sin(progress * GameConfig.OBSTACLE_SHAKE_FREQUENCY * TAU)
	wobble *= decay * GameConfig.OBSTACLE_SHAKE_AMPLITUDE
	rotation.y += wobble * 0.55
	rotation.z += wobble
	position.y = absf(wobble) * 1.2


## Dopo un cambio di modello le ruote sono nuove: vanno ricollegate.
func _on_stage_ready(_level: int, _profile: CarEvolutionProfile) -> void:
	if _director == null:
		return
	_wheels = _director.get_wheels()
	_apply_evolution_stats(_profile)
	lateral_target = clampf(lateral_target, -lateral_limit, lateral_limit)
	position.x = clampf(position.x, -lateral_limit, lateral_limit)


func _on_part_changed(_slot: int, _part: CarPartDefinition) -> void:
	if _director == null:
		return
	_wheels = _director.get_wheels()
	_apply_evolution_stats(evolution_profile())
	lateral_target = clampf(lateral_target, -lateral_limit, lateral_limit)
	position.x = clampf(position.x, -lateral_limit, lateral_limit)


# ---------------------------------------------------------------- Movimento --

func _physics_process(delta: float) -> void:
	if _game_manager != null and _game_manager.state != GameManager.State.PLAYING:
		return

	# Il passo è limitato: con un frame molto lungo l'auto percorrerebbe troppi
	# metri in un colpo solo e la rilevazione degli ostacoli perderebbe colpi.
	var step := clampf(delta, 0.0, GameConfig.OBSTACLE_MAX_STEP_DT)

	# Penalità di velocità da urto: recupera gradualmente verso la marcia normale.
	_update_speed_penalty(step)

	# Avanzamento automatico lungo l'asse -Z verso l'orizzonte.
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
	var wheel_radius := CarEvolutionDirector.WHEEL_RADIUS
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

	# Scuotimento da collisione (solo visivo): si somma al feedback di sterzo
	# e torna esattamente a zero al termine dell'animazione.
	_update_impact_shake(step)


## Limite laterale derivato dall'ingombro reale dell'auto ruotata al massimo.
## In questo modo nemmeno gli angoli della carrozzeria possono superare il bordo.
## L'ingombro è quello dello stadio corrente: le auto evolute sono più lunghe.
## Limite laterale prudente: usa l'ingombro più largo tra quello dello stadio
## corrente e la costante di progetto. Così nessuno stadio (anche il più largo)
## può sporgere oltre il cordolo, qualunque sia il modello in uso.
func _recalculate_lateral_limit() -> void:
	var profile := evolution_profile()
	var base_hw := effective_half_width if effective_half_width > 0.0 else profile.half_width
	var base_hl := effective_half_length if effective_half_length > 0.0 else profile.half_length
	var half_width := maxf(base_hw, GameConfig.CAR_HALF_WIDTH)
	var half_length := maxf(base_hl, GameConfig.CAR_HALF_LENGTH)
	var half_extent := half_width * cos(GameConfig.CAR_MAX_STEER_YAW) \
		+ half_length * sin(GameConfig.CAR_MAX_STEER_YAW)
	lateral_limit = maxf(
		GameConfig.TRACK_WIDTH * 0.5 - half_extent - GameConfig.CAR_EDGE_MARGIN,
		0.0,
	)


func _on_game_state_changed(new_state: GameManager.State) -> void:
	# Riallinea il target ai cambi di fase: niente drag accumulato nel menu o
	# durante il countdown. In FINISHED la velocità effettiva viene azzerata.
	if (
		new_state == GameManager.State.PLAYING
		or new_state == GameManager.State.COUNTDOWN
		or new_state == GameManager.State.IDLE
	):
		lateral_target = clampf(position.x, -lateral_limit, lateral_limit)
	elif new_state == GameManager.State.FINISHED:
		current_speed = 0.0
		speed_changed.emit(current_speed)


## Ripristina i dati di guida tra due corse, senza toccare il saldo permanente.
func reset_for_new_run() -> void:
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	speed_locked = false
	_penalty_factor = 1.0
	_penalty_time_left = 0.0
	_penalty_duration = 0.0
	speed_penalty_factor = 1.0
	_shake_time_left = 0.0
	_shake_intensity = 0.0
	lateral_target = 0.0
	current_speed = 0.0
	_refresh_speed()
	for wheel in _wheels:
		if is_instance_valid(wheel):
			wheel.rotation = Vector3.ZERO


## Imposta la velocità di avanzamento. Con `lock = true` la velocità resta
## fissata anche quando cambia l'evoluzione (serve ai test).
func set_speed(value: float, lock: bool = false) -> void:
	current_speed = maxf(value, 0.0)
	if lock:
		speed_locked = true
	speed_changed.emit(current_speed)
