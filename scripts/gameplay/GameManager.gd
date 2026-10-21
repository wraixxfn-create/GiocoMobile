class_name GameManager
extends Node
## Stato autoritativo del ciclo di gioco: menu, conto alla rovescia, corsa,
## pausa e riepilogo. Le ricompense sono accreditate solo da collect_coin();
## il saldo permanente è salvato localmente da CoinWalletStore.

signal score_updated(score: int)
signal distance_updated(distance_meters: int)
## `coins_updated` comunica solo le monete raccolte nella corsa corrente.
signal coins_updated(coins: int)
signal permanent_coins_updated(balance: int)
signal state_changed(new_state: State)
signal countdown_updated(seconds_left: int)
## Richiesta sincrona al GameRoot di ripristinare auto, pista e pool prima
## dell'avvio di ogni corsa o del ritorno al menu.
signal run_reset_requested
## Emesso una sola volta per corsa, dopo aver congelato tutti i valori finali.
signal run_finished(
	final_score: int,
	distance_meters: int,
	max_level: int,
	coins: int,
	final_level: int,
	outcome: Outcome,
)
## Emesso a ogni variazione effettiva del livello (delta già limitato).
signal evolution_changed(level: int, delta: int, profile: CarEvolutionProfile)

enum State { IDLE, COUNTDOWN, PLAYING, PAUSED, FINISHED }
enum Outcome { NONE, VICTORY, DEFEAT }

## Percorso ConfigFile locale. Modificabile dall'Inspector o nei test.
@export var wallet_save_path: String = GameConfig.COIN_SAVE_PATH
@export_range(100.0, 10000.0, 50.0) var race_distance_meters: float = GameConfig.RUN_DISTANCE_METERS
@export_range(0.0, 5.0, 0.1) var countdown_duration: float = GameConfig.COUNTDOWN_DURATION

var state: State = State.IDLE
var outcome: Outcome = Outcome.NONE
## Distanza longitudinale effettivamente percorsa nella corsa corrente.
var distance: float = 0.0
## Punteggio finale (calcolato una sola volta quando la corsa termina).
var score: int = 0
var final_score: int = 0
var final_evolution_level: int = GameConfig.EVOLUTION_START_LEVEL
## Quantità raccolta nella singola corsa; non è il saldo persistente.
var session_coins: int = 0
## Saldo conservato tra le corse e i riavvii.
var permanent_coins: int = 0
## Livello evolutivo corrente: fonte di verità per modello e statistiche.
var evolution_level: int = GameConfig.EVOLUTION_START_LEVEL
## Valore massimo di evoluzione raggiunto nella corsa corrente.
var max_evolution_level: int = GameConfig.EVOLUTION_START_LEVEL
## Collisioni con ostacoli che hanno applicato una penalità (statistica).
var obstacle_hits: int = 0

var _car: CarController = null
var _wallet_store: CoinWalletStore = null
var _last_reported_distance: int = 0
var _race_start_z: float = 0.0
var _last_car_z: float = 0.0
var _countdown_remaining: float = 0.0
var _last_countdown_number: int = -1


func _ready() -> void:
	# Il gestore deve ricevere i comandi di ripresa/menu anche con lo SceneTree
	# in pausa; _process è comunque inerte negli stati PAUSED e FINISHED.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wallet_store = CoinWalletStore.new(wallet_save_path)
	permanent_coins = _wallet_store.load_balance()


func setup(car: CarController) -> void:
	_car = car
	_race_start_z = car.global_position.z
	_last_car_z = _race_start_z
	_last_reported_distance = floori(distance)


## Registra una collisione con ostacolo penalizzante solo durante la corsa.
func register_obstacle_hit() -> void:
	if state == State.PLAYING:
		obstacle_hits += 1


## Avvia una nuova corsa dal menu o dal riepilogo. Il conto alla rovescia
## dura pochi secondi; il movimento comincia solo quando raggiunge zero.
func start_game() -> bool:
	if state != State.IDLE and state != State.FINISHED:
		return false

	_set_tree_paused(false)
	_reset_run_data()
	run_reset_requested.emit()
	if _car != null:
		_race_start_z = _car.global_position.z
		_last_car_z = _race_start_z

	_countdown_remaining = maxf(countdown_duration, 0.0)
	_last_countdown_number = -1
	_transition_to(State.COUNTDOWN)
	_emit_countdown_number()
	if _countdown_remaining <= 0.0:
		_enter_playing()
	return true


## Pausa touch-friendly (la UI resta attiva, tutto il mondo di gioco si ferma).
func pause_game() -> bool:
	if state != State.PLAYING:
		return false
	_transition_to(State.PAUSED)
	_set_tree_paused(true)
	return true


func resume_game() -> bool:
	if state != State.PAUSED:
		return false
	_set_tree_paused(false)
	if _car != null:
		_last_car_z = _car.global_position.z
	_transition_to(State.PLAYING)
	return true


## Ritorna al menu dal riepilogo o dalla schermata di pausa. Il portafoglio
## non viene azzerato; auto, pista e dati della corsa vengono riportati all'inizio.
func return_to_menu() -> bool:
	if state != State.FINISHED and state != State.PAUSED:
		return false
	_set_tree_paused(false)
	_reset_run_data()
	run_reset_requested.emit()
	if _car != null:
		_race_start_z = _car.global_position.z
		_last_car_z = _race_start_z
	_transition_to(State.IDLE)
	return true


## Chiusura della corsa. Le chiamate successive sono ignorate: punteggio,
## risultato e saldo non possono essere registrati due volte.
func finish_run(result: Outcome) -> bool:
	if state != State.PLAYING:
		return false
	if result == Outcome.NONE:
		result = Outcome.DEFEAT
	if result == Outcome.VICTORY:
		distance = maxf(distance, race_distance_meters)
		if _car != null:
			var car_position := _car.global_position
			car_position.z = _race_start_z - race_distance_meters
			_car.global_position = car_position

	outcome = result
	final_evolution_level = evolution_level
	final_score = calculate_final_score()
	score = final_score
	_last_reported_distance = floori(distance)
	distance_updated.emit(_last_reported_distance)
	score_updated.emit(final_score)
	_transition_to(State.FINISHED)
	run_finished.emit(
		final_score,
		floori(distance),
		max_evolution_level,
		session_coins,
		final_evolution_level,
		outcome,
	)
	# Congela anche animazioni e riciclo: il riepilogo è ormai definitivo.
	_set_tree_paused(true)
	return true


## Compatibilità e punto d'ingresso per eventuali collisioni fatali future.
func end_game() -> void:
	finish_run(Outcome.DEFEAT)


func fail_run() -> void:
	finish_run(Outcome.DEFEAT)


## Punteggio: distanza, picco di evoluzione e monete raccolte.
func calculate_final_score() -> int:
	var distance_points := floori(maxf(distance, 0.0) * GameConfig.SCORE_POINTS_PER_METER)
	var capped_level := clampi(
		max_evolution_level,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)
	var level_points := capped_level * GameConfig.SCORE_POINTS_PER_EVOLUTION_LEVEL
	var coin_points := maxi(session_coins, 0) * GameConfig.SCORE_POINTS_PER_COIN
	return maxi(distance_points + level_points + coin_points, 0)


## Profilo dello stadio corrente (nome, colori, statistiche, proporzioni).
func evolution_profile() -> CarEvolutionProfile:
	return CarEvolutionCatalog.profile_for(evolution_level)


## Accredita la moneta alla corsa e al saldo persistente. La guardia di stato
## blocca qualsiasi pickup elaborato dopo pausa o fine corsa.
func collect_coin(amount: int = GameConfig.COIN_VALUE) -> bool:
	if state != State.PLAYING or amount <= 0:
		return false
	if _wallet_store == null:
		_wallet_store = CoinWalletStore.new(wallet_save_path)

	session_coins += amount
	coins_updated.emit(session_coins)
	permanent_coins += amount
	permanent_coins_updated.emit(permanent_coins)
	_wallet_store.save_balance(permanent_coins)
	return true


## Applica una variazione al livello rispettando i limiti. In pausa, countdown
## o dopo la fine non è possibile alterare il riepilogo.
func apply_evolution(amount: int) -> int:
	if state != State.PLAYING and state != State.IDLE:
		return 0
	var previous := evolution_level
	evolution_level = clampi(
		evolution_level + amount,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)
	var applied := evolution_level - previous
	max_evolution_level = maxi(max_evolution_level, evolution_level)
	if applied != 0:
		evolution_changed.emit(evolution_level, applied, evolution_profile())
	return applied


## Riporta il livello allo stadio iniziale per una nuova corsa o il menu.
func reset_evolution() -> void:
	var previous := evolution_level
	evolution_level = GameConfig.EVOLUTION_START_LEVEL
	max_evolution_level = evolution_level
	if evolution_level != previous:
		evolution_changed.emit(evolution_level, evolution_level - previous, evolution_profile())


func _process(delta: float) -> void:
	if state == State.COUNTDOWN:
		_countdown_remaining = maxf(_countdown_remaining - maxf(delta, 0.0), 0.0)
		_emit_countdown_number()
		if _countdown_remaining <= 0.0:
			_enter_playing()
		return

	if state != State.PLAYING or _car == null:
		return

	# Misura lo spostamento reale dell'auto: gli urti contro un ostacolo non
	# fanno avanzare artificialmente il traguardo.
	var current_car_z := _car.global_position.z
	var forward_travel := maxf(_last_car_z - current_car_z, 0.0)
	_last_car_z = current_car_z
	distance += forward_travel

	if distance >= race_distance_meters:
		distance = race_distance_meters
		if _car != null:
			var car_position := _car.global_position
			car_position.z = _race_start_z - race_distance_meters
			_car.global_position = car_position
		finish_run(Outcome.VICTORY)
	else:
		_report_distance_if_changed()


func _reset_run_data() -> void:
	distance = 0.0
	score = 0
	final_score = 0
	outcome = Outcome.NONE
	session_coins = 0
	obstacle_hits = 0
	max_evolution_level = GameConfig.EVOLUTION_START_LEVEL
	final_evolution_level = GameConfig.EVOLUTION_START_LEVEL
	_last_reported_distance = 0
	_countdown_remaining = 0.0
	_last_countdown_number = -1
	reset_evolution()
	distance_updated.emit(0)
	coins_updated.emit(session_coins)


func _enter_playing() -> void:
	_countdown_remaining = 0.0
	if _car != null:
		_last_car_z = _car.global_position.z
	_transition_to(State.PLAYING)


func _emit_countdown_number() -> void:
	var interval := maxf(countdown_duration / 3.0, 0.001)
	var number := ceili(_countdown_remaining / interval)
	number = clampi(number, 0, 3)
	if number == _last_countdown_number:
		return
	_last_countdown_number = number
	countdown_updated.emit(number)


func _report_distance_if_changed() -> void:
	var distance_meters := floori(maxf(distance, 0.0))
	if distance_meters != _last_reported_distance:
		_last_reported_distance = distance_meters
		distance_updated.emit(distance_meters)


func _transition_to(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)


func _set_tree_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = paused


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _wallet_store != null:
			_wallet_store.save_balance(permanent_coins)
