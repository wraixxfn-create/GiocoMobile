class_name InputManager
extends Node
## Unifica il controllo laterale tramite trascinamento touch/mouse e tastiera.
## Gli eventi di UI vengono lasciati ai Button: la guida riceve solo input
## non gestito e solo nello stato PLAYING.

signal drag_started
signal drag_ended
signal pause_requested
signal resume_requested

const NO_TOUCH: int = -1

var _active_touch_index: int = NO_TOUCH
var _mouse_dragging: bool = false
var _drag_accumulator: float = 0.0
var _game_manager: GameManager = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	if _game_manager != null:
		_game_manager.state_changed.connect(_on_game_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	if _game_manager == null:
		return

	if _game_manager.state == GameManager.State.PAUSED:
		if event is InputEventKey:
			var paused_key := event as InputEventKey
			if paused_key.pressed and not paused_key.echo and paused_key.keycode == KEY_ESCAPE:
				resume_requested.emit()
		return

	if _game_manager.state != GameManager.State.PLAYING:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			pause_requested.emit()
			reset_controls()
			return

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_controls()


## Spostamento orizzontale accumulato dall'ultimo step fisico, normalizzato
## rispetto alla larghezza del viewport.
func consume_lateral_drag() -> float:
	var value := _drag_accumulator
	_drag_accumulator = 0.0
	return value


## Asse tastiera -1 (sinistra) .. +1 (destra), supporta frecce e A/D.
func get_keyboard_axis() -> float:
	if _game_manager != null and _game_manager.state != GameManager.State.PLAYING:
		return 0.0
	var axis := Input.get_axis(&"ui_left", &"ui_right")
	if Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		axis += 1.0
	return clampf(axis, -1.0, 1.0)


## True mentre il giocatore sta trascinando con dito o mouse.
func is_dragging() -> bool:
	return _active_touch_index != NO_TOUCH or _mouse_dragging


## Annulla ogni gesto pendente (nuova corsa, pausa, cambio stato o focus perso).
func reset_controls() -> void:
	var was_dragging := is_dragging()
	_active_touch_index = NO_TOUCH
	_mouse_dragging = false
	_drag_accumulator = 0.0
	if was_dragging:
		drag_ended.emit()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Il touch ha priorità sul mouse: alcuni dispositivi emulano entrambi.
		if _active_touch_index == NO_TOUCH:
			_active_touch_index = event.index
			_mouse_dragging = false
			_drag_accumulator = 0.0
			drag_started.emit()
		return

	# Rilasciare un dito secondario non interrompe il controllo attivo.
	if event.index == _active_touch_index:
		_active_touch_index = NO_TOUCH
		drag_ended.emit()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _active_touch_index:
		_accumulate_drag(event.relative.x)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if _active_touch_index == NO_TOUCH and not _mouse_dragging:
			_mouse_dragging = true
			_drag_accumulator = 0.0
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


## Larghezza di riferimento in pixel del viewport; 540 come fallback headless.
func get_reference_width() -> float:
	var viewport := get_viewport()
	if viewport != null:
		var width := viewport.get_visible_rect().size.x
		if width > 1.0:
			return width
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 540))


func _on_game_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		reset_controls()
