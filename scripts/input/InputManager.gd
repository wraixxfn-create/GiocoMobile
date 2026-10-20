class_name InputManager
extends Node
## Unifica l'input laterale del giocatore:
## - trascinamento touch (e trascinamento mouse per il test su desktop)
## - frecce direzionali / tasti A,D da tastiera
## Emette inoltre start_requested al primo input utile per avviare la partita.

signal start_requested

var _drag_accumulator: float = 0.0
var _game_started: bool = false


func _input(event: InputEvent) -> void:
	if not _game_started and _is_start_event(event):
		_game_started = true
		start_requested.emit()

	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		_drag_accumulator += drag_event.relative.x
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_accumulator += motion_event.relative.x


## Restituisce lo spostamento orizzontale accumulato dall'ultimo frame
## (in pixel) e lo azzera. Da consumare una volta per frame.
func consume_lateral_delta() -> float:
	var value := _drag_accumulator
	_drag_accumulator = 0.0
	return value


## Asse tastiera -1 (sinistra) .. +1 (destra), supporta frecce e A/D.
func get_keyboard_axis() -> float:
	var axis := Input.get_axis(&"ui_left", &"ui_right")
	if Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		axis += 1.0
	return clampf(axis, -1.0, 1.0)


func _is_start_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var code := key_event.keycode
			if code == KEY_A or code == KEY_D or code == KEY_SPACE or code == KEY_ENTER:
				return true
	return (
		event.is_action_pressed(&"ui_accept")
		or event.is_action_pressed(&"ui_left")
		or event.is_action_pressed(&"ui_right")
	)
