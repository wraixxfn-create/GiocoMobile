class_name GameManager
extends Node
## Stato globale della partita e punteggio.
## TODO(fase 2): cancelli bonus/penalità, ostacoli, monete,
## evoluzioni dell'auto e traguardo.

enum State { IDLE, PLAYING, FINISHED }

signal score_updated(score: int)
signal coins_updated(coins: int)
signal state_changed(new_state: State)

var state: State = State.IDLE
var distance: float = 0.0
var score: int = 0
var coins: int = 0

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


func add_coins(amount: int) -> void:
	coins += amount
	coins_updated.emit(coins)


func _process(delta: float) -> void:
	if state != State.PLAYING or _car == null:
		return
	# Il punteggio iniziale è la distanza percorsa (metri).
	distance += _car.current_speed * delta
	var new_score := int(distance)
	if new_score != score:
		score = new_score
		score_updated.emit(score)
