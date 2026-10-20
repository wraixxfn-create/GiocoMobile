class_name InputManager
extends Node
## Unifica l'input laterale del giocatore:
## - trascinamento touch (e trascinamento mouse, utile in desktop)
## - frecce direzionali / A,D da tastiera
## Emette inoltre start_requested al primo tocco per far partire la partita.

signal start_requested

var _drag_accumulator: float = 0.0
var _game_started: bool = false


func _input(event: InputEvent) -> void:
	if not _game_started and _is_start_event(event):
		_game_started = true
		start_requested.emit()

	if event is InputEventScreenDrag:
		_drag_accumulator += event.relative.x
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag_accumulator += event.relative.x


## Restituisce lo spostamento orizzontale accumulato dall'ultimo frame
## (in pixel) e lo azzera. Da consumare una volta per frame.
func consume_lateral_delta() -> float:
	var value := _drag_accumulator
	_drag_accumulator = 0.0
	return value


## Asse tastiera -1 (sinistra) .. +1 (destra).
func get_keyboard_axis() -> float:
	return Input.get_axis(&"ui_left", &"ui_right")


func _is_start_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	return event.is_action_pressed(&"ui_accept")
