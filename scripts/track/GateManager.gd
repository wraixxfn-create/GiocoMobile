class_name GateManager
extends Node3D
## Gestisce le file di cancelli di evoluzione lungo la pista.
##
## Ogni fila è una coppia di cancelli affiancati che si dividono la carreggiata:
## uno positivo (verde per +1, blu per +2) e uno negativo (rosso, -1). Il punto
## di separazione cambia a ogni fila, quindi la scelta comoda si alterna tra
## sinistra e destra: il giocatore deve sterzare per prendere quello che vuole.
##
## Responsabilità:
## - generare le file davanti all'auto e riciclarle quando sono superate;
## - rilevare l'attraversamento in 3D (segmento auto / piano del cancello);
## - applicare l'effetto UNA sola volta tramite GameManager.apply_evolution().
##
## Le file non si sovrappongono mai: i due cancelli di una coppia sono
## adiacenti e le file distano GameConfig.GATE_ROW_SPACING metri.

## Emesso quando un cancello viene attraversato.
## `requested_value` è il valore del cancello, `applied_delta` la variazione
## realmente applicata (0 se il livello era già al limite), `level` il nuovo livello.
signal gate_crossed(requested_value: int, applied_delta: int, level: int)

## File attualmente in gioco (usata anche dai test).
var rows: Array[GateRow] = []
## Ultimo cancello attraversato e relativo esito (utile per HUD e test).
## Diventa null quando la fila viene riciclata e il nodo viene liberato.
var last_crossed_gate: EvolutionGate = null
var last_requested_value: int = 0
var last_applied_delta: int = 0

var _player: CarController = null
var _game_manager: GameManager = null
var _previous_car_position: Vector3 = Vector3.ZERO
var _pattern_index: int = 0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CarController
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	if _player != null:
		_previous_car_position = _player.global_position
	_spawn_initial_rows()


func _physics_process(delta: float) -> void:
	step(maxf(delta, 0.0))


## Un passo di simulazione: campiona la posizione dell'auto, rileva gli
## attraversamenti e ricicla le file superate. Separato da _physics_process
## per poter essere eseguito in modo deterministico dai test.
func step(_delta: float = 0.0) -> void:
	if _player == null:
		return

	var current_position := _player.global_position
	var previous_position := _previous_car_position
	_previous_car_position = current_position

	# I cancelli si attivano solo a partita iniziata (in IDLE l'auto è ferma).
	if _game_manager != null and _game_manager.state == GameManager.State.PLAYING:
		_detect_crossings(previous_position, current_position)

	_recycle_rows(current_position.z)


# --------------------------------------------------------------- Detection ---

## Rileva quali cancelli sono stati attraversati tra i due campioni 3D.
## Il calcolo è per-cancello: ogni varco ha il proprio piano e la propria
## apertura laterale, quindi non è possibile attivare il cancello sbagliato.
func _detect_crossings(previous_position: Vector3, current_position: Vector3) -> void:
	for gate_row in rows:
		if gate_row.passed:
			continue
		var gate_count: int = gate_row.gates.size()
		for index in gate_count:
			var gate := gate_row.gates[index] as EvolutionGate
			if gate == null or gate.consumed:
				continue
			var crossing_x := gate.crossing_x(previous_position, current_position)
			if is_nan(crossing_x):
				continue
			# L'estremo destro è incluso solo nell'ultimo cancello della fila:
			# ogni punto della pista appartiene così a un solo cancello.
			if gate.contains_x(crossing_x, index == gate_count - 1):
				_trigger_row(gate_row, gate)
				break


func _trigger_row(gate_row: GateRow, gate: EvolutionGate) -> void:
	# La fila è chiusa subito: nessuna seconda attivazione, né in questa
	# riga né in un frame successivo.
	gate_row.passed = true
	gate.trigger()
	for other in gate_row.gates:
		var other_gate := other as EvolutionGate
		if other_gate != null and other_gate != gate:
			other_gate.deactivate()

	var applied := 0
	if _game_manager != null:
		applied = _game_manager.apply_evolution(gate.value)

	last_crossed_gate = gate
	last_requested_value = gate.value
	last_applied_delta = applied
	var level := _game_manager.evolution_level if _game_manager != null else 0
	gate_crossed.emit(gate.value, applied, level)


# ------------------------------------------------------------------- Rows ---

func _spawn_initial_rows() -> void:
	for index in GameConfig.GATE_ROW_COUNT:
		var gate_row := GateRow.new()
		gate_row.z = -(GameConfig.GATE_FIRST_ROW_DISTANCE + index * GameConfig.GATE_ROW_SPACING)
		_fill_row(gate_row)
		rows.append(gate_row)


## Crea i due cancelli di una fila e li aggancia alla scena.
## `_pattern_index` avanza a ogni fila: la sequenza di posizioni e valori è
## deterministica, ma alternata (nessuna fila identica alla precedente).
func _fill_row(gate_row: GateRow) -> void:
	var inner_half := GameConfig.TRACK_WIDTH * 0.5 - GameConfig.GATE_EDGE_MARGIN
	var left_edge := -inner_half
	var right_edge := inner_half

	var split_pattern := GameConfig.GATE_SPLIT_PATTERN
	var requested_split: float = split_pattern[posmod(_pattern_index, split_pattern.size())]
	var min_width := GameConfig.GATE_MIN_WIDTH
	var split := clampf(
		requested_split,
		left_edge + min_width,
		right_edge - min_width,
	)

	var positive_pattern := GameConfig.GATE_POSITIVE_PATTERN
	var positive_value: int = positive_pattern[posmod(_pattern_index, positive_pattern.size())]
	var positive_on_left := _pattern_index % 2 == 0
	var negative_value := -GameConfig.GATE_NEGATIVE_STEP
	var left_value := positive_value if positive_on_left else negative_value
	var right_value := negative_value if positive_on_left else positive_value

	gate_row.passed = false
	gate_row.gates = [
		_create_gate(left_value, left_edge, split, gate_row.z),
		_create_gate(right_value, split, right_edge, gate_row.z),
	]
	_pattern_index += 1


func _create_gate(gate_value: int, left_x: float, right_x: float, z: float) -> EvolutionGate:
	var gate := EvolutionGate.new()
	gate.name = "GatePositive" if gate_value > 0 else "GateNegative"
	gate.position = Vector3(0.0, 0.0, z)
	add_child(gate)
	gate.setup(gate_value, left_x, right_x)
	return gate


## Ricicla verso l'orizzonte le file già superate dall'auto.
## Mantiene sempre tutte le file davanti al giocatore e distanziate tra loro.
func _recycle_rows(car_z: float) -> void:
	for gate_row in rows:
		if gate_row.z <= car_z + GameConfig.GATE_PASSED_OFFSET:
			continue
		_recycle_row(gate_row, car_z)


func _recycle_row(gate_row: GateRow, car_z: float) -> void:
	# La fila viene rimessa davanti alla più lontana delle altre file che sono
	# ancora davanti all'auto; se non ce ne sono, a distanza utile dall'auto.
	var farthest := INF
	for other in rows:
		if other == gate_row:
			continue
		if other.z < farthest and other.z <= car_z:
			farthest = other.z
	if is_inf(farthest):
		farthest = car_z - GameConfig.GATE_FIRST_ROW_DISTANCE + GameConfig.GATE_ROW_SPACING
	var new_z := farthest - GameConfig.GATE_ROW_SPACING

	for gate in gate_row.gates:
		var gate_node := gate as EvolutionGate
		if gate_node == null:
			continue
		if gate_node == last_crossed_gate:
			last_crossed_gate = null
		remove_child(gate_node)
		gate_node.queue_free()
	gate_row.gates = []

	gate_row.z = new_z
	_fill_row(gate_row)


# ------------------------------------------------------------------ Query ---

## Numero di cancelli ancora attivi (non attraversati) davanti all'auto.
func active_gate_count() -> int:
	var count := 0
	for gate_row in rows:
		for gate in gate_row.gates:
			var gate_node := gate as EvolutionGate
			if gate_node != null and not gate_node.consumed:
				count += 1
	return count
