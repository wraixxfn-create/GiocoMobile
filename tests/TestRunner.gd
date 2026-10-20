extends Node
## Test headless di integrazione dei controlli.
##
## Esecuzione:
##   godot --headless --path . res://tests/TestRunner.tscn
##
## Simula InputEventScreenTouch / InputEventScreenDrag / eventi mouse reali,
## avvia la partita e verifica movimento, tenuta della posizione, bordi,
## inquadratura della telecamera, riciclo della pista e indipendenza dagli FPS.

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const TOUCH_START := Vector2(270.0, 640.0)
const EPSILON := 0.0005

var _checks: int = 0
var _failures: Array[String] = []
var _finished: bool = false

var _main: Node
var _car: CarController
var _input_manager: InputManager
var _game_manager: GameManager
var _camera_rig: Node3D
var _camera: Camera3D
var _track: Node3D


func _ready() -> void:
	print("=== TEST CONTROLLI DI GUIDA ===")
	# Watchdog: evita che un test bloccato lasci il processo appeso in CI.
	get_tree().create_timer(30.0).timeout.connect(_on_watchdog_timeout)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().physics_frame

	_car = _main.get_node("Player") as CarController
	_input_manager = _main.get_node("InputManager") as InputManager
	_game_manager = _main.get_node("GameManager") as GameManager
	_camera_rig = _main.get_node("CameraRig") as Node3D
	_camera = _main.get_node("CameraRig/MainCamera") as Camera3D
	_track = _main.get_node("TrackManager") as Node3D

	_check(_car != null and _input_manager != null, "nodi principali presenti")
	_check(_car.lateral_limit > 0.0, "limite laterale calcolato")
	_check(_input_manager.is_in_group(&"input_manager"), "InputManager nel gruppo input_manager")
	_check(_game_manager.is_in_group(&"game_manager"), "GameManager nel gruppo game_manager")
	_check(_car.is_in_group(&"player"), "Player nel gruppo player")

	await _test_idle_then_auto_forward()
	await _test_touch_drag_and_hold()
	await _test_mouse_drag()
	await _test_touch_precedence_over_emulated_mouse()
	await _test_bounds_right_and_left()
	await _test_camera_keeps_car_centered()
	await _test_track_recycling()
	await _test_fps_independence()

	_finish()


# ------------------------------------------------------------------ Tests ---

func _test_idle_then_auto_forward() -> void:
	var start_z := _car.position.z
	await _physics_frames(5)
	_check(absf(_car.position.z - start_z) < EPSILON, "in IDLE l'auto non avanza")

	_send_touch(0, true)
	_check(_game_manager.state == GameManager.State.PLAYING, "il touch avvia la partita")

	await _physics_frames(30)
	var travelled := start_z - _car.position.z
	_check(travelled > 4.0, "l'auto avanza automaticamente (%.2f m)" % travelled)
	_check(absf(_car.position.x) < EPSILON, "senza drag resta al centro")
	_send_touch(0, false)
	await _physics_frames(2)


func _test_touch_drag_and_hold() -> void:
	_reset_lateral()
	await _physics_frames(2)

	var width := _viewport_width()
	_send_touch(1, true)
	_send_touch_drag(1, Vector2(width * 0.12, 0.0))
	await _physics_frames(24)

	var expected_target: float = 0.12 * _car.tuning.drag_sensitivity
	_check(
		absf(_car.lateral_target - expected_target) < 0.01,
		"il drag aggiorna il target (%.3f m)" % _car.lateral_target,
	)
	_check(
		_car.position.x > expected_target * 0.9,
		"l'auto segue il target con interpolazione (x=%.3f)" % _car.position.x,
	)
	_check(
		_car.position.x < expected_target + 0.01,
		"l'interpolazione non supera il target",
	)

	var x_at_release := _car.position.x
	var target_at_release := _car.lateral_target
	_send_touch(1, false)
	await _physics_frames(30)
	_check(
		absf(_car.lateral_target - target_at_release) < EPSILON,
		"al rilascio il target laterale resta invariato",
	)
	_check(
		absf(_car.position.x - x_at_release) < 0.02,
		"al rilascio l'auto mantiene la posizione (%.3f m)" % _car.position.x,
	)
	_check(_car.position.x > 0.4, "l'auto non torna al centro dopo il rilascio")


func _test_mouse_drag() -> void:
	_reset_lateral()
	await _physics_frames(2)

	var width := _viewport_width()
	_send_mouse_button(true)
	_send_mouse_motion(Vector2(-width * 0.10, 0.0), true)
	await _physics_frames(24)

	_check(_car.position.x < -0.4, "il drag con mouse sposta l'auto (x=%.3f)" % _car.position.x)
	var x_after_motion := _car.position.x
	_send_mouse_button(false)
	await _physics_frames(30)
	_check(
		absf(_car.position.x - x_after_motion) < 0.02,
		"al rilascio del mouse l'auto mantiene la posizione",
	)


func _test_touch_precedence_over_emulated_mouse() -> void:
	_reset_lateral()
	var width := _viewport_width()

	_send_touch(2, true)
	_send_touch_drag(2, Vector2(width * 0.10, 0.0))
	# Su alcuni dispositivi Godot emula il mouse dal touch: non va contato due volte.
	_send_mouse_motion(Vector2(width * 0.10, 0.0), true)

	var accumulated := _input_manager.consume_lateral_drag()
	_check(
		absf(accumulated - 0.10) < 0.001,
		"il mouse emulato dal touch non raddoppia il drag (%.4f)" % accumulated,
	)

	# Un secondo dito non deve rubare il controllo al primo.
	_send_touch(3, true)
	_send_touch_drag(3, Vector2(width * 0.5, 0.0))
	_check(
		absf(_input_manager.consume_lateral_drag()) < EPSILON,
		"i tocchi secondari vengono ignorati",
	)
	_send_touch(3, false)
	_send_touch(2, false)
	await _physics_frames(2)


func _test_bounds_right_and_left() -> void:
	_reset_lateral()
	await _physics_frames(2)

	var half_track := GameConfig.TRACK_WIDTH * 0.5
	var worst_right: float = await _sweep_to_edge(4, 1.0)
	_check(
		_car.position.x <= _car.lateral_limit + EPSILON,
		"bordo destro: il centro auto resta entro il limite",
	)
	_check(
		_car.position.x > _car.lateral_limit - 0.02,
		"bordo destro raggiunto senza oltrepassarlo",
	)
	_check(
		worst_right <= half_track + EPSILON,
		"bordo destro: nessuna parte dell'auto esce dall'asfalto (%.3f <= %.3f)"
		% [worst_right, half_track],
	)

	var worst_left: float = await _sweep_to_edge(5, -1.0)
	_check(
		_car.position.x >= -_car.lateral_limit - EPSILON,
		"bordo sinistro: il centro auto resta entro il limite",
	)
	_check(
		_car.position.x < -_car.lateral_limit + 0.02,
		"bordo sinistro raggiunto senza oltrepassarlo",
	)
	_check(
		worst_left <= half_track + EPSILON,
		"bordo sinistro: nessuna parte dell'auto esce dall'asfalto (%.3f <= %.3f)"
		% [worst_left, half_track],
	)

	# Drag molto brusco e ripetuto: il clamp deve reggere anche qui.
	_send_touch(6, true)
	for step in 24:
		_send_touch_drag(6, Vector2(_viewport_width() * 3.0 * (1.0 if step % 2 == 0 else -1.0), 0.0))
		await get_tree().physics_frame
		_check_silent(_car.position.x <= _car.lateral_limit + EPSILON)
		_check_silent(_car.position.x >= -_car.lateral_limit - EPSILON)
	_check(true, "drag alternati violenti restano sempre dentro i bordi")
	_send_touch(6, false)
	await _physics_frames(2)

	var extent_at_max_yaw := (
		GameConfig.CAR_HALF_WIDTH * cos(GameConfig.CAR_MAX_STEER_YAW)
		+ GameConfig.CAR_HALF_LENGTH * sin(GameConfig.CAR_MAX_STEER_YAW)
	)
	_check(
		_car.lateral_limit + extent_at_max_yaw <= half_track + EPSILON,
		"limite geometrico coerente con ingombro e cordoli",
	)


func _test_camera_keeps_car_centered() -> void:
	# Attende tempo simulato reale: in headless i frame di processo possono
	# essere molto più rapidi della fisica.
	await _physics_frames(30)
	await _process_frames(2)
	_check(
		absf(_camera_rig.position.x - _car.position.x) < 0.05,
		"la telecamera segue l'auto lateralmente (%.3f vs %.3f)"
		% [_camera_rig.position.x, _car.position.x],
	)
	_check(
		absf(_camera_rig.position.z - (_car.position.z + GameConfig.CAMERA_DISTANCE)) < EPSILON,
		"la telecamera mantiene la distanza di avanzamento",
	)

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x > 1.0:
		var car_screen := _camera.unproject_position(_car.global_position + Vector3(0.0, 0.6, 0.0))
		var center_x := viewport_size.x * 0.5
		_check(
			absf(car_screen.x - center_x) < 25.0,
			"l'auto resta stabile al centro dell'inquadratura (x=%.1f px)" % car_screen.x,
		)
	else:
		# In headless puro il viewport può non avere dimensioni: la centratura
		# è comunque garantita dalla camera solidale.
		_check(
			absf(_camera.global_transform.basis.z.x) < 0.001,
			"telecamera senza imbardata laterale (viewport headless)",
		)


func _test_track_recycling() -> void:
	var initial_indices := _segment_indices()
	var initial_car_z := _car.position.z
	await _physics_frames(210)

	var moved := initial_car_z - _car.position.z
	_check(moved > 40.0, "la pista scorre mentre l'auto avanza (%.1f m)" % moved)
	# Lascia aggiornare la telecamera con la posizione più recente dell'auto.
	await _process_frames(2)
	_check(
		absf(_camera_rig.position.z - (_car.position.z + GameConfig.CAMERA_DISTANCE)) < 0.05,
		"la telecamera avanza con l'auto",
	)

	var positions: Array[float] = []
	for segment in _track.get_children():
		if segment is TrackSegment:
			positions.append((segment as TrackSegment).position.z)
	positions.sort()
	var contiguous := true
	for index in range(1, positions.size()):
		if absf((positions[index] - positions[index - 1]) - GameConfig.SEGMENT_LENGTH) > 0.01:
			contiguous = false
	_check(contiguous, "i segmenti riciclati restano contigui (nessun buco)")
	_check(_segment_indices() != initial_indices, "i segmenti vengono riciclati in fondo")
	_check(_segment_indices().size() == GameConfig.SEGMENT_COUNT, "numero segmenti invariato")


func _test_fps_independence() -> void:
	var test_car := CarController.new()
	test_car.tuning = DrivingTuning.new()
	test_car.tuning.max_lateral_speed = 0.0
	add_child(test_car)
	test_car.set_physics_process(false)
	test_car._game_manager = null
	test_car._input_manager = null

	# 0.1 secondi simulati con tre frequenze diverse.
	var x_60 := _simulate_lateral(test_car, 6, 1.0 / 60.0)
	var x_120 := _simulate_lateral(test_car, 12, 1.0 / 120.0)
	var x_30 := _simulate_lateral(test_car, 3, 1.0 / 30.0)
	_check(absf(x_60 - x_120) < 0.005, "sterzo identico a 60 e 120 FPS")
	_check(absf(x_60 - x_30) < 0.01, "sterzo identico a 60 e 30 FPS")

	var z_60 := _simulate_forward(test_car, 60, 1.0 / 60.0)
	var z_120 := _simulate_forward(test_car, 120, 1.0 / 120.0)
	_check(absf(z_60 - z_120) < 0.005, "avanzamento identico a 60 e 120 FPS")


# ---------------------------------------------------------------- Helpers ---

func _simulate_lateral(test_car: CarController, steps: int, step: float) -> float:
	test_car.position = Vector3.ZERO
	test_car.rotation = Vector3.ZERO
	test_car.lateral_target = 2.0
	test_car.current_speed = 0.0
	for _i in steps:
		test_car._physics_process(step)
	return test_car.position.x


func _simulate_forward(test_car: CarController, steps: int, step: float) -> float:
	test_car.position = Vector3.ZERO
	test_car.current_speed = 14.0
	for _i in steps:
		test_car._physics_process(step)
	return test_car.position.z


## Trascina fino al bordo nel verso indicato e restituisce il massimo ingombro
## laterale (centro + metà larghezza effettiva) osservato durante il moto.
func _sweep_to_edge(touch_index: int, direction: float) -> float:
	_send_touch(touch_index, true)
	_send_touch_drag(touch_index, Vector2(_viewport_width() * 10.0 * direction, 0.0))
	var worst_extent := 0.0
	for _i in 60:
		await get_tree().physics_frame
		var yaw := absf(_car.rotation.y)
		var extent := (
			GameConfig.CAR_HALF_WIDTH * cos(yaw)
			+ GameConfig.CAR_HALF_LENGTH * sin(yaw)
		)
		worst_extent = maxf(worst_extent, absf(_car.position.x) + extent)
	# Il target resta dov'è: rilasciare il dito non fa tornare l'auto indietro.
	_send_touch(touch_index, false)
	return worst_extent


func _reset_lateral() -> void:
	_input_manager.consume_lateral_drag()
	_car.position.x = 0.0
	_car.lateral_target = 0.0
	_car.rotation.y = 0.0
	_car.rotation.z = 0.0
	_car._update_visual_feedback(0.0, 1.0)


func _send_touch(index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = TOUCH_START
	_input_manager._input(event)


func _send_touch_drag(index: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = TOUCH_START + relative
	event.relative = relative
	_input_manager._input(event)


func _send_mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = TOUCH_START
	_input_manager._input(event)


func _send_mouse_motion(relative: Vector2, with_left_button: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = TOUCH_START + relative
	event.relative = relative
	if with_left_button:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_input_manager._input(event)


func _segment_indices() -> Array[int]:
	var indices: Array[int] = []
	for segment in _track.get_children():
		if segment is TrackSegment:
			indices.append((segment as TrackSegment).segment_index)
	indices.sort()
	return indices


func _viewport_width() -> float:
	return _input_manager.get_reference_width() if _input_manager != null else 540.0


func _physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _process_frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  %s" % message)
	else:
		_failures.append(message)
		printerr("  FAIL  %s" % message)


func _check_silent(condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures.append("posizione fuori dai bordi durante un drag violento")


func _on_watchdog_timeout() -> void:
	if _finished:
		return
	printerr("TIMEOUT: il test non è terminato entro 30 secondi")
	get_tree().quit(2)


func _finish() -> void:
	_finished = true
	print("--------------------------------")
	if _failures.is_empty():
		print("TEST OK: %d verifiche superate" % _checks)
		get_tree().quit(0)
		return
	for failure in _failures:
		printerr("FALLITO: " + failure)
	print("TEST FALLITI: %d su %d" % [_failures.size(), _checks])
	get_tree().quit(1)
