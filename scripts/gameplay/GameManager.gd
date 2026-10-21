class_name GameManager
extends Node
## Stato globale della corsa: distanza, monete di sessione, saldo permanente,
## punteggio finale e livello di evoluzione dell'auto.
## Il saldo permanente viene caricato/salvato con CoinWalletStore; le monete
## della corsa vengono azzerate all'avvio e non sostituiscono mai il saldo.

signal score_updated(score: int)
signal distance_updated(distance_meters: int)
## `coins_updated` comunica solo le monete raccolte nella corsa corrente.
signal coins_updated(coins: int)
signal permanent_coins_updated(balance: int)
signal state_changed(new_state: State)
## Emesso a ogni variazione effettiva del livello (delta già limitato).
signal evolution_changed(level: int, delta: int, profile: CarEvolutionProfile)
## Riepilogo calcolato una sola volta quando termina la corsa.
signal run_finished(final_score: int, distance_meters: int, max_level: int, coins: int)

enum State { IDLE, PLAYING, FINISHED }

## Percorso ConfigFile locale. Può essere cambiato dall'Inspector o prima
## dell'ingresso nell'albero (utile anche per test isolati).
@export var wallet_save_path: String = GameConfig.COIN_SAVE_PATH

var state: State = State.IDLE
## Distanza longitudinale percorsa nella corsa corrente, in metri.
var distance: float = 0.0
## Punteggio finale (calcolato in end_game, non confuso con i metri a schermo).
var score: int = 0
var final_score: int = 0
## Quantità raccolta nella singola corsa; non è il saldo persistente.
var session_coins: int = 0
## Alias di sola lettura mantenuto per il vecchio nome del contatore di corsa.
var coins: int:
	get:
		return session_coins
## Saldo conservato tra le corse e i riavvii.
var permanent_coins: int = 0
## Valore massimo di evoluzione raggiunto nella corsa corrente.
var max_evolution_level: int = GameConfig.EVOLUTION_START_LEVEL
## Collisioni con ostacoli che hanno applicato una penalità (statistica).
var obstacle_hits: int = 0

var _car: CarController = null
var _wallet_store: CoinWalletStore = null
var _last_reported_distance: int = 0


func _ready() -> void:
	_wallet_store = CoinWalletStore.new(wallet_save_path)
	permanent_coins = _wallet_store.load_balance()


func setup(car: CarController) -> void:
	_car = car
	_last_reported_distance = floori(distance)


## Registra una collisione con ostacolo penalizzante.
func register_obstacle_hit() -> void:
	obstacle_hits += 1


func start_game() -> void:
	if state == State.PLAYING:
		return
	# Un nuovo avvio azzera solo i dati della corsa; il portafoglio locale
	# resta intatto anche quando si riparte dopo un riepilogo.
	distance = 0.0
	score = 0
	final_score = 0
	session_coins = 0
	max_evolution_level = evolution_level
	_last_reported_distance = 0
	distance_updated.emit(0)
	coins_updated.emit(session_coins)
	state = State.PLAYING
	state_changed.emit(state)


## Termina la corsa e congela il riepilogo. Chiamate ripetute sono innocue.
func end_game() -> void:
	if state == State.FINISHED:
		return
	final_score = calculate_final_score()
	score = final_score
	state = State.FINISHED
	score_updated.emit(final_score)
	state_changed.emit(state)
	run_finished.emit(final_score, floori(distance), max_evolution_level, session_coins)


## Punteggio configurabile: distanza, picco di evoluzione e monete di corsa.
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
## È calcolato dal livello, non memorizzato: non può disallinearsi.
func evolution_profile() -> CarEvolutionProfile:
	return CarEvolutionCatalog.profile_for(evolution_level)


## Accredita subito le monete alla corsa e al saldo permanente. La scrittura
## locale avviene nello stesso frame del pickup, senza attendere la fine corsa.
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


## Compatibilità con chiamanti che usavano il vecchio nome del metodo.
func add_coins(amount: int) -> void:
	collect_coin(amount)


## Applica una variazione al livello rispettando i limiti. Restituisce la
## variazione realmente applicata (0 se il livello è già al limite).
func apply_evolution(amount: int) -> int:
	var previous := evolution_level
	evolution_level = clampi(
		evolution_level + amount,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)
	var applied := evolution_level - previous
	if state == State.PLAYING:
		max_evolution_level = maxi(max_evolution_level, evolution_level)
	elif state == State.IDLE:
		max_evolution_level = maxi(max_evolution_level, evolution_level)
	if applied != 0:
		evolution_changed.emit(evolution_level, applied, evolution_profile())
	return applied


## Riporta il livello allo stato iniziale (usato da un eventuale restart).
func reset_evolution() -> void:
	var previous := evolution_level
	evolution_level = GameConfig.EVOLUTION_START_LEVEL
	if state != State.PLAYING:
		max_evolution_level = evolution_level
	if evolution_level != previous:
		evolution_changed.emit(evolution_level, evolution_level - previous, evolution_profile())


func _process(delta: float) -> void:
	if state != State.PLAYING or _car == null:
		return
	distance += maxf(_car.current_speed, 0.0) * maxf(delta, 0.0)
	var distance_meters := floori(distance)
	if distance_meters != _last_reported_distance:
		_last_reported_distance = distance_meters
		distance_updated.emit(distance_meters)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _wallet_store != null:
			_wallet_store.save_balance(permanent_coins)
