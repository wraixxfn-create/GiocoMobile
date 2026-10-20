class_name GameManager
extends Node
## Stato globale della partita, punteggio e livello di evoluzione dell'auto.
##
## Il livello di evoluzione è centralizzato qui: `evolution_level` è l'unico
## valore di gioco e può essere modificato solo tramite `apply_evolution()`,
## che applica i limiti min/max di GameConfig e notifica l'interfaccia.
## I cancelli (GateManager) non toccano mai la variabile direttamente.
## L'aspetto dell'auto e le statistiche dipendono solo da qui: vengono ricavate
## dal livello tramite CarEvolutionCatalog, così non esiste uno stato visivo
## separato che possa restare indietro rispetto al valore reale.
## TODO(fase 3): ostacoli, monete raccoglibili, traguardo e fine partita.

signal score_updated(score: int)
signal coins_updated(coins: int)
signal state_changed(new_state: State)
## Emesso a ogni variazione effettiva del livello (delta già limitato).
## `profile` è lo stadio visivo/di gioco corrispondente al nuovo livello.
signal evolution_changed(level: int, delta: int, profile: CarEvolutionProfile)

enum State { IDLE, PLAYING, FINISHED }

var state: State = State.IDLE
var distance: float = 0.0
var score: int = 0
var coins: int = 0
## Livello di evoluzione corrente, sempre compreso tra
## GameConfig.EVOLUTION_MIN_LEVEL e GameConfig.EVOLUTION_MAX_LEVEL.
var evolution_level: int = GameConfig.EVOLUTION_START_LEVEL

var _car: CarController = null


func setup(car: CarController) -> void:
	_car = car


func start_game() -> void:
	if state == State.PLAYING:
		return
	state = State.PLAYING
	state_changed.emit(state)


func end_game() -> void:
	state = State.FINISHED
	state_changed.emit(state)


## Profilo dello stadio corrente (nome, colori, statistiche, proporzioni).
## È calcolato dal livello, non memorizzato: non può disallinearsi.
func evolution_profile() -> CarEvolutionProfile:
	return CarEvolutionCatalog.profile_for(evolution_level)


func add_coins(amount: int) -> void:
	coins += amount
	coins_updated.emit(coins)


## Applica una variazione al livello di evoluzione rispettando i limiti.
## Restituisce la variazione realmente applicata (0 se il livello è già al
## limite): positivo = evoluzione, negativo = regressione.
## NON emette evolution_changed se il livello non cambia.
func apply_evolution(amount: int) -> int:
	var previous := evolution_level
	evolution_level = clampi(
		evolution_level + amount,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)
	var applied := evolution_level - previous
	if applied != 0:
		evolution_changed.emit(evolution_level, applied, evolution_profile())
	return applied


## Riporta il livello allo stato iniziale (usato da un eventuale restart).
func reset_evolution() -> void:
	var previous := evolution_level
	evolution_level = GameConfig.EVOLUTION_START_LEVEL
	if evolution_level != previous:
		evolution_changed.emit(evolution_level, evolution_level - previous, evolution_profile())


func _process(delta: float) -> void:
	if state != State.PLAYING or _car == null:
		return
	# Il punteggio iniziale è la distanza percorsa (metri).
	distance += _car.current_speed * delta
	var new_score := int(distance)
	if new_score != score:
		score = new_score
		score_updated.emit(score)
