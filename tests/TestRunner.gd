extends Node
## Test headless di integrazione dei controlli.
##
## Esecuzione:
##   godot --headless --path . res://tests/TestRunner.tscn
##
## Simula InputEventScreenTouch / InputEventScreenDrag / eventi mouse reali,
## avvia la partita e verifica movimento, tenuta della posizione, bordi,
## inquadratura della telecamera, riciclo della pista, indipendenza dagli FPS,
## layout dei cancelli di evoluzione, attraversamenti in 3D, applicazione
## singola degli effetti, limiti del livello e riciclo delle file di cancelli.

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
var _gate_manager: GateManager
var _initial_gate_distance: float = 0.0


func _ready() -> void:
	print("=== TEST CONTROLLI DI GUIDA ===")
	# Watchdog: evita che un test bloccato lasci il processo appeso in CI.
	get_tree().create_timer(60.0).timeout.connect(_on_watchdog_timeout)
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
	_gate_manager = _main.get_node("GateManager") as GateManager
	if _gate_manager != null and not _gate_manager.rows.is_empty():
		_initial_gate_distance = _car.position.z - float(_gate_manager.rows[0].z)

	_check(_car != null and _input_manager != null, "nodi principali presenti")
	_check(_car.lateral_limit > 0.0, "limite laterale calcolato")
	_check(_input_manager.is_in_group(&"input_manager"), "InputManager nel gruppo input_manager")
	_check(_game_manager.is_in_group(&"game_manager"), "GameManager nel gruppo game_manager")
	_check(_car.is_in_group(&"player"), "Player nel gruppo player")
	_check(_gate_manager != null, "GateManager presente nella scena")
	_check(
		_gate_manager != null and _gate_manager.is_in_group(&"gate_manager"),
		"GateManager nel gruppo gate_manager",
	)
	_check(_gate_manager != null and _gate_manager.rows.size() == GameConfig.GATE_ROW_COUNT,
		"file di cancelli generate all'avvio")

	await _test_idle_then_auto_forward()
	await _test_touch_drag_and_hold()
	await _test_mouse_drag()
	await _test_touch_precedence_over_emulated_mouse()
	await _test_bounds_right_and_left()
	await _test_camera_keeps_car_centered()
	await _test_track_recycling()
	await _test_fps_independence()
	_test_gate_layout()
	await _test_gate_crossing_positive()
	await _test_gate_crossing_negative()
	await _test_gate_evolution_limits()
	await _test_gate_single_activation()
	await _test_gate_recycling()
	_test_evolution_stage_catalog()
	_test_evolution_stage_models()
	await _test_evolution_transformation()
	await _test_evolution_keeps_driving()
	await _test_evolution_level_sync()
	await _test_car_evolution_visual()

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


# ------------------------------------------------------------- Cancelli ---

func _test_gate_layout() -> void:
	# Da qui in poi i test controllano la posizione 3D dell'auto passo per
	# passo: l'avanzamento automatico viene congelato (lock=true, così il
	# cambio di evoluzione non lo riaccende) e ripristinato alla fine.
	_car.set_speed(0.0, true)
	var inner_half := GameConfig.TRACK_WIDTH * 0.5 - GameConfig.GATE_EDGE_MARGIN
	_check(
		_initial_gate_distance >= 60.0,
		"il primo cancello nasce lontano ma visibile (%.1f m)" % _initial_gate_distance,
	)
	_check(
		GameConfig.GATE_HEIGHT >= 2.0,
		"i cancelli sono alti abbastanza da essere visti da lontano (%.2f m)"
		% GameConfig.GATE_HEIGHT,
	)

	var pairs_ok := true
	var spans_ok := true
	var reachable_ok := true
	var signs_ok := true
	var labels_ok := true
	var visible_ok := true
	for row in _gate_manager.rows:
		if row.gates.size() != 2:
			pairs_ok = false
			continue
		var positives := 0
		var negatives := 0
		var previous_end := -INF
		for gate in row.gates:
			var width: float = gate.span_end - gate.span_start
			if width < GameConfig.GATE_MIN_WIDTH - 0.001:
				spans_ok = false
			if gate.span_start < -inner_half - 0.001 or gate.span_end > inner_half + 0.001:
				spans_ok = false
			# Nessuna sovrapposizione: ogni cancello comincia dove finisce il precedente.
			if gate.span_start < previous_end - 0.001:
				spans_ok = false
			previous_end = gate.span_end
			# Entrambe le opzioni devono essere raggiungibili sterzando.
			var overlap := (
				minf(gate.span_end, _car.lateral_limit)
				- maxf(gate.span_start, -_car.lateral_limit)
			)
			if overlap < 0.6:
				reachable_ok = false
			if gate.value > 0:
				positives += 1
			elif gate.value < 0:
				negatives += 1
			if gate.label_text() != _expected_gate_label(gate.value):
				labels_ok = false
			if not gate.is_visible_in_tree():
				visible_ok = false
		if positives != 1 or negatives != 1:
			signs_ok = false

	_check(pairs_ok, "ogni fila contiene esattamente due cancelli affiancati")
	_check(spans_ok, "i cancelli stanno nella carreggiata, larghi e senza sovrapposizioni")
	_check(reachable_ok, "entrambi i cancelli sono raggiungibili entro i limiti laterali")
	_check(signs_ok, "ogni fila propone un cancello positivo e uno negativo")
	_check(labels_ok, "ogni cancello mostra il proprio valore (+1/+2/-1)")
	_check(visible_ok, "tutti i cancelli sono visibili nella scena 3D")

	# Le file sono equidistanti e mai sovrapposte lungo la pista.
	var positions: Array[float] = []
	for row in _gate_manager.rows:
		positions.append(row.z)
	positions.sort()
	var spacing_ok := positions.size() == GameConfig.GATE_ROW_COUNT
	for index in range(1, positions.size()):
		if absf((positions[index] - positions[index - 1]) - GameConfig.GATE_ROW_SPACING) > 0.01:
			spacing_ok = false
	_check(spacing_ok, "le file di cancelli sono equidistanti e non sovrapposte")

	# I valori positivi sono leggibili e i più grandi sono i blu (+2).
	var values_ok := true
	for row in _gate_manager.rows:
		for gate in row.gates:
			if absi(gate.value) < 1 or absi(gate.value) > 2:
				values_ok = false
	_check(values_ok, "i valori dei cancelli restano tra 1 e 2 in valore assoluto")


func _test_gate_crossing_positive() -> void:
	_force_evolution(1)
	var director := _director()
	var stage_before := director.get_stage_root() if director != null else null
	var found := _find_row_with_gate(true)
	_check(not found.is_empty(), "esiste una fila con cancello positivo davanti all'auto")
	if found.is_empty():
		return
	var row = found[0]
	var gate = found[1]
	var expected := mini(1 + int(gate.value), GameConfig.EVOLUTION_MAX_LEVEL)

	# Avvicinamento senza attraversare il piano del cancello.
	_place_car_before_gate(row, gate, 2.0)
	await _physics_frames(2)
	_check(not row.passed, "avvicinarsi al cancello non lo attiva")
	_check(_game_manager.evolution_level == 1, "nessun effetto prima dell'attraversamento")

	# Attraversamento reale: l'auto supera il piano del cancello.
	_place_car_after_gate(row, gate, 2.0)
	await _physics_frames(1)
	_check(row.passed, "la fila viene marcata come attraversata")
	_check(gate.consumed, "il cancello attraversato viene disattivato")
	_check(
		_game_manager.evolution_level == expected,
		"il cancello %s porta evolution_level a %d" % [gate.label_text(), expected],
	)
	_check(_gate_manager.last_requested_value == gate.value, "viene riportato il valore del cancello")
	_check(
		_gate_manager.last_applied_delta == expected - 1,
		"viene riportata la variazione applicata (%d)" % _gate_manager.last_applied_delta,
	)

	# L'altro cancello della coppia si spegne: niente doppie letture.
	var other = row.gates[0] if row.gates[1] == gate else row.gates[1]
	_check(other.consumed, "anche l'altro cancello della coppia viene spento")

	await _physics_frames(3)
	_check(
		_game_manager.evolution_level == expected,
		"nessuna attivazione ripetuta dopo l'attraversamento",
	)

	# Il cancello positivo cambia davvero il modello visibile dell'auto.
	if director != null:
		_check(
			director.current_level == _game_manager.evolution_level,
			"dopo il cancello positivo il modello è allineato al livello (%d)"
			% director.current_level,
		)
		_check(
			director.get_stage_root() != stage_before and is_instance_valid(director.get_stage_root()),
			"il cancello positivo sostituisce il modello dell'auto",
		)
		_check(
			director.get_wheels().size() == 4,
			"il nuovo modello ha tutte e quattro le ruote collegate",
		)
	await _recycle_passed_row(row)


func _test_gate_crossing_negative() -> void:
	_force_evolution(3)
	var director := _director()
	var stage_before := director.get_stage_root() if director != null else null
	var found := _find_row_with_gate(false)
	_check(not found.is_empty(), "esiste una fila con cancello negativo davanti all'auto")
	if found.is_empty():
		return
	var row = found[0]
	var gate = found[1]
	var expected := maxi(3 + int(gate.value), GameConfig.EVOLUTION_MIN_LEVEL)
	_cross_gate(row, gate)
	await _physics_frames(1)
	_check(gate.value < 0, "il cancello scelto è negativo (%s)" % gate.label_text())
	_check(
		_game_manager.evolution_level == expected,
		"il cancello %s riduce evolution_level a %d" % [gate.label_text(), expected],
	)
	await _physics_frames(3)
	_check(_game_manager.evolution_level == expected, "la regressione viene applicata una sola volta")

	# Il cancello negativo fa regredire anche il modello visibile.
	if director != null:
		_check(
			director.current_level == _game_manager.evolution_level,
			"dopo il cancello negativo il modello è allineato al livello (%d)"
			% director.current_level,
		)
		_check(
			director.get_stage_root() != stage_before and is_instance_valid(director.get_stage_root()),
			"il cancello negativo sostituisce il modello dell'auto",
		)
	await _recycle_passed_row(row)


func _test_gate_evolution_limits() -> void:
	# Massimo: il cancello positivo non deve superare il limite.
	_force_evolution(GameConfig.EVOLUTION_MAX_LEVEL)
	var found := _find_row_with_gate(true)
	_check(not found.is_empty(), "fila con cancello positivo per il test del massimo")
	if not found.is_empty():
		var row = found[0]
		var gate = found[1]
		await _cross_gate(row, gate)
		_check(
			_game_manager.evolution_level == GameConfig.EVOLUTION_MAX_LEVEL,
			"evolution_level non supera il massimo (%d)" % GameConfig.EVOLUTION_MAX_LEVEL,
		)
		_check(
			_gate_manager.last_applied_delta == 0,
			"al massimo l'effetto viene limitato a 0",
		)
		_check(gate.consumed, "il cancello viene comunque consumato al limite")
		await _recycle_passed_row(row)

	# Minimo: il cancello negativo non deve scendere sotto il limite.
	_force_evolution(GameConfig.EVOLUTION_MIN_LEVEL)
	found = _find_row_with_gate(false)
	_check(not found.is_empty(), "fila con cancello negativo per il test del minimo")
	if not found.is_empty():
		var row = found[0]
		var gate = found[1]
		await _cross_gate(row, gate)
		_check(
			_game_manager.evolution_level == GameConfig.EVOLUTION_MIN_LEVEL,
			"evolution_level non scende sotto il minimo (%d)" % GameConfig.EVOLUTION_MIN_LEVEL,
		)
		_check(
			_gate_manager.last_applied_delta == 0,
			"al minimo l'effetto viene limitato a 0",
		)
		await _recycle_passed_row(row)


func _test_gate_single_activation() -> void:
	_force_evolution(2)
	var found := _find_row_with_gate(true)
	_check(not found.is_empty(), "fila disponibile per il test di attivazione singola")
	if found.is_empty():
		return
	var row = found[0]
	var gate = found[1]
	var level_before: int = _game_manager.evolution_level

	# Passo lungo e diagonale: l'auto entra da sinistra ed esce a destra del
	# varco in un solo frame. La X va interpolata sul piano del cancello.
	var crossing_x: float = gate.crossing_x(
		Vector3(gate.span_start - 3.0, 0.0, row.z + 12.0),
		Vector3(gate.span_end + 3.0, 0.0, row.z - 12.0),
	)
	_check(
		not is_nan(crossing_x) and absf(crossing_x - (gate.span_start + gate.span_end) * 0.5) < 0.001,
		"l'attraversamento calcola la X esatta sul piano del cancello",
	)
	# Un segmento che si allontana dal cancello non è un attraversamento.
	_check(
		is_nan(gate.crossing_x(
			Vector3(gate.span_start, 0.0, row.z - 12.0),
			Vector3(gate.span_start, 0.0, row.z + 12.0),
		)),
		"il verso di marcia conta: nessun attraversamento all'indietro",
	)

	# Passo grande che supera il piano (12 m in un colpo solo).
	var previous := Vector3((gate.span_start + gate.span_end) * 0.5, 0.0, row.z + 12.0)
	var current := Vector3((gate.span_start + gate.span_end) * 0.5, 0.0, row.z - 12.0)
	_gate_manager._detect_crossings(previous, current)
	_check(row.passed, "un passo grande supera il cancello e viene rilevato")
	_check(
		_game_manager.evolution_level == level_before + int(gate.value),
		"l'effetto del passo grande viene applicato una volta",
	)

	# Lo stesso attraversamento ripetuto non deve produrre altri effetti.
	_gate_manager._detect_crossings(previous, current)
	_gate_manager._detect_crossings(previous, current)
	_check(
		_game_manager.evolution_level == level_before + int(gate.value),
		"ripetere lo stesso attraversamento non riapplica l'effetto",
	)
	_check(
		_gate_manager.last_applied_delta == int(gate.value),
		"l'ultima variazione registrata è quella del cancello",
	)
	await _recycle_passed_row(row)


func _test_gate_recycling() -> void:
	var gate_nodes_before := _gate_node_count()
	var car_z: float = _car.position.z - 400.0
	_car.position.z = car_z
	_gate_manager.step()
	await _physics_frames(2)

	_check(
		_gate_manager.rows.size() == GameConfig.GATE_ROW_COUNT,
		"il numero di file resta costante dopo il riciclo",
	)
	_check(
		_gate_node_count() == gate_nodes_before,
		"nessun cancello orfano nella scena dopo il riciclo",
	)

	var positions: Array[float] = []
	var ahead_ok := true
	var fresh_ok := true
	for row in _gate_manager.rows:
		positions.append(row.z)
		if row.z > car_z - GameConfig.GATE_FIRST_ROW_DISTANCE + 0.01:
			ahead_ok = false
		if row.passed or not row.has_active_gate():
			fresh_ok = false
	positions.sort()
	var spacing_ok := true
	for index in range(1, positions.size()):
		if absf((positions[index] - positions[index - 1]) - GameConfig.GATE_ROW_SPACING) > 0.01:
			spacing_ok = false
	_check(ahead_ok, "le file riciclate compaiono davanti all'auto")
	_check(spacing_ok, "le file riciclate restano equidistanti")
	_check(fresh_ok, "le file riciclate ripartono con cancelli attivi")


# ------------------------------------------------ Evoluzione (modelli 3D) ---

## Il direttore del modello (nodo "CarVisual" figlio dell'auto).
func _director() -> CarEvolutionDirector:
	return CarModel.find_director(_car)


func _test_evolution_stage_catalog() -> void:
	var names: Array[String] = []
	var silhouettes: Array[int] = []
	var previous_speed := -1.0
	var valid := true
	var monotonic := true
	var stage_count := 0
	for level in range(GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL + 1):
		var profile := CarEvolutionCatalog.profile_for(level)
		if profile == null or profile.level != level or profile.stage_name.is_empty():
			valid = false
			continue
		stage_count += 1
		names.append(profile.stage_name)
		silhouettes.append(profile.silhouette)
		if profile.speed_multiplier < previous_speed - 0.0001:
			monotonic = false
		previous_speed = profile.speed_multiplier

	_check(valid, "ogni livello ha un profilo valido e completo")
	_check(stage_count >= 5, "almeno cinque stadi di evoluzione definiti (%d)" % stage_count)
	_check(monotonic, "salendo di livello le statistiche non peggiorano mai")
	_check(_all_unique_strings(names), "ogni stadio ha un nome distinto")
	_check(_all_unique_ints(silhouettes), "ogni stadio ha una silhouette distinta")
	_check(
		CarEvolutionCatalog.clamp_level(-99) == GameConfig.EVOLUTION_MIN_LEVEL
		and CarEvolutionCatalog.clamp_level(99) == GameConfig.EVOLUTION_MAX_LEVEL,
		"i livelli fuori range vengono riportati dentro i limiti",
	)
	_check(
		CarEvolutionCatalog.profile_for(999).level == GameConfig.EVOLUTION_MAX_LEVEL,
		"anche una richiesta fuori range produce uno stadio valido",
	)


func _test_evolution_stage_models() -> void:
	var director := _director()
	_check(director != null, "l'auto ha il direttore delle evoluzioni (CarVisual)")
	if director == null:
		return

	var sizes: Array[String] = []
	var proportions_ok := true
	var wheels_ok := true
	var colors_ok := true
	var pips_ok := true
	var levels_ok := true
	var previous_color := Color(0.0, 0.0, 0.0, 0.0)
	for level in range(GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL + 1):
		director.apply_level(level, false)
		if director.current_level != level or director.current_profile == null:
			levels_ok = false
			continue
		var profile := director.current_profile
		var size := _stage_size(director.get_stage_root())
		if size.x < 1.2 or size.z < 1.8 or size.y < 0.6:
			proportions_ok = false
		if director.get_wheels().size() != 4:
			wheels_ok = false
		if profile.body_color.is_equal_approx(previous_color):
			colors_ok = false
		previous_color = profile.body_color
		if _lit_pips(director) != level:
			pips_ok = false
		sizes.append("%.2fx%.2fx%.2f" % [size.x, size.y, size.z])

	_check(levels_ok, "ogni stadio viene applicato al modello")
	_check(proportions_ok, "ogni stadio ha proporzioni da automobile plausibili")
	_check(wheels_ok, "ogni stadio monta quattro ruote collegate al movimento")
	_check(colors_ok, "ogni stadio ha un colore di carrozzeria diverso")
	_check(pips_ok, "le spie accese sul modello corrispondono al livello mostrato")
	_check(
		_all_unique_strings(sizes),
		"le %d silhouette sono tutte diverse: non cambia solo il colore" % sizes.size(),
	)


func _test_evolution_transformation() -> void:
	var director := _director()
	if director == null:
		return

	_force_evolution(GameConfig.EVOLUTION_MIN_LEVEL)
	await _physics_frames(1)
	var level_before := director.current_level
	var stage_before := director.get_stage_root()

	_game_manager.apply_evolution(1)
	# Campionato subito: se la macchina è lenta, l'animazione potrebbe essere
	# già finita quando si arriva al ciclo sotto.
	var scale_at_start := director.get_stage_root().scale
	# Aggiornamento immediato: nello stesso frame il modello è già quello nuovo.
	_check(
		director.current_level == level_before + 1,
		"il livello sale e il modello cambia subito (%d -> %d)" % [level_before, director.current_level],
	)
	_check(
		not scale_at_start.is_equal_approx(Vector3.ONE),
		"la trasformazione parte con il modello compresso (%.2f)" % scale_at_start.x,
	)
	_check(
		director.get_stage_root() != stage_before and is_instance_valid(director.get_stage_root()),
		"il nodo del modello viene sostituito senza distruggere l'auto",
	)
	_check(director.is_transforming(), "parte l'animazione di trasformazione")

	# Durante l'animazione i comandi continuano a funzionare.
	# Partenza al centro, così il drag non può essere fermato dai bordi.
	_car.position.x = 0.0
	_car.lateral_target = 0.0
	var target_before := _car.lateral_target
	_send_touch(20, true)
	_send_touch_drag(20, Vector2(_viewport_width() * 0.05, 0.0))
	await _physics_frames(3)
	_check(
		_car.lateral_target > target_before + 0.05,
		"lo sterzo risponde mentre l'auto si trasforma",
	)
	_send_touch(20, false)

	# Avanzamento deterministico: la scala passa da compressa a piena.
	# `scale_at_start` è già una prova valida se l'animazione è finita prima.
	var saw_scaled := not scale_at_start.is_equal_approx(Vector3.ONE)
	var guard := 0
	while director.is_transforming() and guard < 240:
		director.advance(1.0 / 60.0)
		if not director.get_stage_root().scale.is_equal_approx(Vector3.ONE):
			saw_scaled = true
		guard += 1
	_check(saw_scaled, "la trasformazione scala il modello")
	_check(not director.is_transforming(), "l'animazione termina da sola")
	_check(
		director.get_stage_root().scale.is_equal_approx(Vector3.ONE),
		"a fine animazione il modello torna a scala piena",
	)

	var glow_ok := true
	for material in director.get_glow_materials():
		var emissive := material as StandardMaterial3D
		if emissive == null or emissive.emission_energy_multiplier <= 0.0:
			glow_ok = false
	_check(glow_ok, "le luci dello stadio tornano ai valori base")

	var flash := director.get_node_or_null(CarEvolutionDirector.NODE_FLASH) as OmniLight3D
	_check(flash != null and not flash.visible, "il lampo di trasformazione si spegne")
	var shockwave := director.get_node_or_null(CarEvolutionDirector.NODE_SHOCKWAVE) as MeshInstance3D
	_check(shockwave != null and not shockwave.visible, "l'onda d'urto sparisce a fine animazione")


func _test_evolution_keeps_driving() -> void:
	var director := _director()
	if director == null:
		return

	# La marcia riprende con la velocità dello stadio corrente.
	_car.speed_locked = false
	_car.set_speed(_car.tuning.forward_speed * _car.evolution_speed_multiplier)
	if _game_manager.state != GameManager.State.PLAYING:
		_game_manager.start_game()
	_force_evolution(2)
	# Parte da una situazione pulita: niente sterzo residuo dai test precedenti.
	_reset_lateral()
	await _physics_frames(4)
	_car.lateral_target = _car.position.x

	var x_before: float = _car.position.x
	var z_before: float = _car.position.z
	var target_before: float = _car.lateral_target
	var yaw_before: float = _car.rotation.y
	var level_before: int = director.current_level
	var wheels_before := director.get_wheels()
	var wheel_before: float = 0.0
	if wheels_before.size() > 0:
		wheel_before = (wheels_before[0] as Node3D).rotation.x

	_game_manager.apply_evolution(1)
	await _physics_frames(12)

	var expected_speed := _car.tuning.forward_speed * _car.evolution_speed_multiplier
	_check(director.current_level == level_before + 1, "il livello sale cambiando il modello in corsa")
	_check(
		absf(_car.position.x - x_before) < 0.05,
		"la posizione laterale non salta al cambio modello (%.3f -> %.3f)" % [x_before, _car.position.x],
	)
	_check(absf(_car.lateral_target - target_before) < EPSILON, "lo sterzo resta quello di prima")
	_check(absf(_car.rotation.y - yaw_before) < 0.02, "l'inclinazione dell'auto non viene azzerata")
	_check(
		absf(_car.current_speed - expected_speed) < 0.001,
		"la velocità segue le statistiche dello stadio (%.2f m/s)" % _car.current_speed,
	)
	_check(_car.position.z < z_before - 0.5, "l'auto continua ad avanzare durante la trasformazione")
	var wheels_after := director.get_wheels()
	_check(wheels_after.size() == 4, "il nuovo modello ha tutte e quattro le ruote")
	_check(
		wheels_after.size() > 0 and (wheels_after[0] as Node3D).rotation.x != wheel_before,
		"le ruote del nuovo modello continuano a girare",
	)
	_check(
		absf(_car.lateral_limit - (GameConfig.TRACK_WIDTH * 0.5
			- _car.evolution_profile().lateral_half_extent(GameConfig.CAR_MAX_STEER_YAW)
			- GameConfig.CAR_EDGE_MARGIN)) < EPSILON,
		"i limiti laterali seguono l'ingombro dello stadio",
	)


func _test_evolution_level_sync() -> void:
	var director := _director()
	if director == null:
		return

	director.apply_level(-100, false)
	_check(
		director.current_level == GameConfig.EVOLUTION_MIN_LEVEL,
		"un livello troppo basso viene riportato al minimo",
	)
	director.apply_level(100, false)
	_check(
		director.current_level == GameConfig.EVOLUTION_MAX_LEVEL,
		"un livello troppo alto viene riportato al massimo",
	)

	# Richiedere lo stesso livello non ricostruisce nulla.
	var stage := director.get_stage_root()
	director.apply_level(GameConfig.EVOLUTION_MAX_LEVEL, true)
	_check(director.get_stage_root() == stage, "richiedere lo stesso livello non ricostruisce il modello")
	_check(not director.is_transforming(), "senza cambio di livello non parte alcuna animazione")

	# Limiti di gioco: il modello resta dentro min/max.
	_force_evolution(GameConfig.EVOLUTION_MIN_LEVEL)
	_game_manager.apply_evolution(-5)
	await _physics_frames(1)
	_check(
		_game_manager.evolution_level == GameConfig.EVOLUTION_MIN_LEVEL
		and director.current_level == GameConfig.EVOLUTION_MIN_LEVEL,
		"al minimo né il livello né il modello scendono oltre",
	)
	_game_manager.apply_evolution(99)
	await _physics_frames(1)
	_check(
		_game_manager.evolution_level == GameConfig.EVOLUTION_MAX_LEVEL
		and director.current_level == GameConfig.EVOLUTION_MAX_LEVEL,
		"al massimo né il livello né il modello salgono oltre",
	)

	# Dopo ogni passaggio: GameManager, direttore e metadati coincidono.
	var synced := true
	for level in range(GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL + 1):
		_force_evolution(level)
		_game_manager.apply_evolution(1 if level < GameConfig.EVOLUTION_MAX_LEVEL else 0)
		await _physics_frames(1)
		if director.current_level != _game_manager.evolution_level:
			synced = false
		if int(_car.get_meta(&"evolution_level", -99)) != _game_manager.evolution_level:
			synced = false
	_check(synced, "dopo ogni cambio il modello è allineato al vero evolution_level")

	# La chiamata storica continua a funzionare e resta coerente.
	CarModel.apply_evolution_level(_car, 2)
	await _physics_frames(1)
	_check(director.current_level == 2, "CarModel.apply_evolution_level allinea il modello")


func _test_car_evolution_visual() -> void:
	var pips: Array = _car.get_meta(&"evolution_pips", [])
	_check(
		pips.size() == GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL,
		"l'auto espone una barra di %d spie di evoluzione"
		% (GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL),
	)

	CarModel.apply_evolution_level(_car, GameConfig.EVOLUTION_MIN_LEVEL)
	var body: Array = _car.get_meta(&"evolution_body_meshes", [])
	_check(not body.is_empty(), "le parti di carrozzeria da ricolorare sono state trovate")
	var low_material = (body[0] as MeshInstance3D).material_override

	CarModel.apply_evolution_level(_car, GameConfig.EVOLUTION_MAX_LEVEL)
	var high_body: Array = _car.get_meta(&"evolution_body_meshes", [])
	var high_material = (high_body[0] as MeshInstance3D).material_override
	_check(low_material != high_material, "la carrozzeria cambia aspetto con il livello")
	_check(
		int(_car.get_meta(&"evolution_level", -1)) == GameConfig.EVOLUTION_MAX_LEVEL,
		"il livello applicato al modello è quello richiesto",
	)
	_check(
		str(_car.get_meta(&"evolution_stage_name", "")) == _director().stage_name(),
		"il nome dello stadio mostrato è quello del livello",
	)

	# Il livello arriva all'auto tramite il segnale di GameManager.
	_force_evolution(2)
	_game_manager.apply_evolution(1)
	await _physics_frames(1)
	_check(
		int(_car.get_meta(&"evolution_level", -1)) == 3,
		"il cambio di evolution_level aggiorna subito l'auto",
	)
	_check(
		_game_manager.evolution_level == 3,
		"apply_evolution mantiene il livello centralizzato coerente",
	)
	# Rimette l'auto in marcia con la velocità dello stadio raggiunto.
	_car.speed_locked = false
	_car.set_speed(_car.tuning.forward_speed * _car.evolution_speed_multiplier)


# --------------------------------------------------------------- Helpers ---

## Ingrandimento (larghezza, altezza, lunghezza) del modello mostrato.
## Calcolato trasformando a mano i bounding box delle mesh: nessuna ipotesi
## sull'orientamento dei singoli pezzi.
func _stage_size(root: Node3D) -> Vector3:
	if root == null:
		return Vector3.ZERO
	var bounds := {
		"min": Vector3(INF, INF, INF),
		"max": Vector3(-INF, -INF, -INF),
	}
	_collect_bounds(root, Transform3D.IDENTITY, bounds)
	var minimum: Vector3 = bounds["min"]
	if minimum.x == INF:
		return Vector3.ZERO
	var maximum: Vector3 = bounds["max"]
	return maximum - minimum


func _collect_bounds(node: Node, parent_transform: Transform3D, bounds: Dictionary) -> void:
	var transform := parent_transform
	var spatial := node as Node3D
	if spatial != null:
		transform = parent_transform * spatial.transform
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		for corner in _aabb_corners(instance.mesh.get_aabb()):
			var point: Vector3 = transform * corner
			var minimum: Vector3 = bounds["min"]
			var maximum: Vector3 = bounds["max"]
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			minimum.z = minf(minimum.z, point.z)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
			maximum.z = maxf(maximum.z, point.z)
			bounds["min"] = minimum
			bounds["max"] = maximum
	for child in node.get_children():
		_collect_bounds(child, transform, bounds)


static func _aabb_corners(box: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	var xs: Array[float] = [box.position.x, box.position.x + box.size.x]
	var ys: Array[float] = [box.position.y, box.position.y + box.size.y]
	var zs: Array[float] = [box.position.z, box.position.z + box.size.z]
	for x in xs:
		for y in ys:
			for z in zs:
				corners.append(Vector3(x, y, z))
	return corners


## Numero di spie accese sul modello: deve combaciare con il livello.
func _lit_pips(director: CarEvolutionDirector) -> int:
	var count := 0
	for pip in director.get_pips():
		var instance := pip as MeshInstance3D
		if instance == null:
			continue
		var material := instance.material_override as StandardMaterial3D
		if material != null and material.emission_enabled:
			count += 1
	return count


static func _all_unique_strings(values: Array[String]) -> bool:
	for index in values.size():
		for other in range(index + 1, values.size()):
			if values[index] == values[other]:
				return false
	return values.size() > 0


static func _all_unique_ints(values: Array[int]) -> bool:
	for index in values.size():
		for other in range(index + 1, values.size()):
			if values[index] == values[other]:
				return false
	return values.size() > 0


func _expected_gate_label(gate_value: int) -> String:
	var prefix := "+" if gate_value > 0 else ""
	return "%s%d" % [prefix, gate_value]


## Imposta il livello "a mano" come fanno i test, ma continua a notificarlo:
## così anche l'aspetto dell'auto resta allineato al valore reale.
func _force_evolution(level: int) -> void:
	_game_manager.evolution_level = clampi(
		level,
		GameConfig.EVOLUTION_MIN_LEVEL,
		GameConfig.EVOLUTION_MAX_LEVEL,
	)
	_game_manager.evolution_changed.emit(
		_game_manager.evolution_level,
		0,
		_game_manager.evolution_profile(),
	)


## Cerca una fila non ancora superata con un cancello del segno richiesto.
func _find_row_with_gate(positive: bool) -> Array:
	for row in _gate_manager.rows:
		if row.passed:
			continue
		for gate in row.gates:
			if positive and gate.value > 0:
				return [row, gate]
			if not positive and gate.value < 0:
				return [row, gate]
	return []


func _gate_center(gate) -> float:
	return (gate.span_start + gate.span_end) * 0.5


func _place_car_before_gate(row, gate, distance: float) -> void:
	_car.position.x = _gate_center(gate)
	_car.lateral_target = _gate_center(gate)
	_car.position.z = row.z + distance
	_gate_manager.step()


func _place_car_after_gate(row, gate, distance: float) -> void:
	_car.position.x = _gate_center(gate)
	_car.lateral_target = _gate_center(gate)
	_car.position.z = row.z - distance
	_gate_manager.step()


## Attraversa davvero il cancello indicato con due campioni consecutivi.
func _cross_gate(row, gate) -> void:
	_place_car_before_gate(row, gate, 1.5)
	_place_car_after_gate(row, gate, 1.5)
	await _physics_frames(1)


## Dopo un attraversamento la fila viene portata dietro l'auto oltre il margine
## di riciclo: torna così davanti con cancelli nuovi per i test successivi.
func _recycle_passed_row(row) -> void:
	if row.passed:
		_car.position.z = row.z - GameConfig.GATE_PASSED_OFFSET - 4.0
		_gate_manager.step()
		await _physics_frames(1)


func _gate_node_count() -> int:
	var count := 0
	for child in _gate_manager.get_children():
		if child is EvolutionGate:
			count += 1
	return count


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
		# Ingombro reale dello stadio mostrato, con l'imbardata del momento.
		var extent := _car.evolution_profile().lateral_half_extent(absf(_car.rotation.y))
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
