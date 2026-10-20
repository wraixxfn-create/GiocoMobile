class_name InputManager
extends Node
## Unifica l'input laterale del giocatore:
## - trascinamento touch (InputEventScreenTouch + InputEventScreenDrag)
## - trascinamento con il tasto sinistro del mouse (per il test su desktop)
## - frecce direzionali / tasti A,D da tastiera
##
## Lo spostamento viene accumulato in frazioni di larghezza dello schermo, così
## la stessa corsa del dito produce lo stesso movimento su qualsiasi risoluzione.
## Emette start_requested al primo input utile per avviare la partita.

signal start_requested
signal drag_started
signal drag_ended

const NO_TOUCH: int = -1

var _active_touch_index: int = NO_TOUCH
var _mouse_dragging: bool = false
var _drag_accumulator: float = 0.0
var _game_started: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return
	if _is_start_event(event):
		_request_start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()


## Spostamento orizzontale accumulato dall'ultimo frame, in frazioni di
## larghezza dello schermo (1.0 = un'intera larghezza). Da consumare una volta
## per step fisico: è indipendente dal frame rate perché deriva dagli eventi.
func consume_lateral_drag() -> float:
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


## True mentre il giocatore sta trascinando con dito o mouse.
func is_dragging() -> bool:
	return _active_touch_index != NO_TOUCH or _mouse_dragging


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Il touch ha priorità sul mouse: su alcuni dispositivi Godot emula
		# anche il mouse dal touch e non vogliamo contare due volte il drag.
		if _active_touch_index == NO_TOUCH:
			_active_touch_index = event.index
			_mouse_dragging = false
			_drag_accumulator = 0.0
			_request_start()
			drag_started.emit()
		return

	# Rilasciare un dito secondario non deve interrompere il trascinamento attivo.
	if event.index == _active_touch_index:
		_active_touch_index = NO_TOUCH
		drag_ended.emit()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _active_touch_index:
		return
	_accumulate_drag(event.relative.x)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		# Se un dito è già sullo schermo, ignora il mouse (anche quello emulato).
		if _active_touch_index == NO_TOUCH and not _mouse_dragging:
			_mouse_dragging = true
			_drag_accumulator = 0.0
			_request_start()
			drag_started.emit()
		return

	if _mouse_dragging:
		_mouse_dragging = false
		drag_ended.emit()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _active_touch_index != NO_TOUCH or not _mouse_dragging:
		return
	if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_mouse_dragging = false
		drag_ended.emit()
		return
	_accumulate_drag(event.relative.x)


func _accumulate_drag(pixel_delta: float) -> void:
	_drag_accumulator += pixel_delta / get_reference_width()


## Larghezza di riferimento per normalizzare il drag, in pixel del viewport.
## Usa la dimensione reale quando disponibile e ricade sulla larghezza di
## progetto (540) in headless o prima che la finestra sia pronta.
func get_reference_width() -> float:
	var viewport := get_viewport()
	if viewport != null:
		var width := viewport.get_visible_rect().size.x
		if width > 1.0:
			return width
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 540))


func _request_start() -> void:
	if _game_started:
		return
	_game_started = true
	start_requested.emit()


func _cancel_drag() -> void:
	var was_dragging := is_dragging()
	_active_touch_index = NO_TOUCH
	_mouse_dragging = false
	_drag_accumulator = 0.0
	if was_dragging:
		drag_ended.emit()


func _is_start_event(event: InputEvent) -> bool:
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
