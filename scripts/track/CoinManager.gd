class_name CoinManager
extends Node3D
## Genera un flusso di monete davanti all'auto e ne rileva la raccolta con
## un test continuo di prossimità in XZ (senza collisioni fisiche o tunneling).
## Gli oggetti vengono riciclati in coordinate mondo come cancelli e ostacoli.

signal coin_collected(run_total: int)

## Pool di monete attive lungo la pista (esposto per debug e test).
var coins: Array[Coin] = []
var last_collected_coin: Coin = null
var collected_count: int = 0

var _player: CarController = null
var _game_manager: GameManager = null
var _previous_car_position: Vector3 = Vector3.ZERO
var _next_spawn_serial: int = 0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CarController
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	if _player != null:
		_previous_car_position = _player.global_position
	_spawn_initial_coins()


func _physics_process(delta: float) -> void:
	step(maxf(delta, 0.0))


## Passo separato per test deterministici. Il segmento precedente/corrente
## intercetta anche una moneta attraversata tra due frame, purché il movimento
## non sia un teletrasporto di test.
func step(_delta: float = 0.0) -> void:
	if _player == null:
		return

	var current_position := _player.global_position
	var previous_position := _previous_car_position
	_previous_car_position = current_position

	var can_collect := _game_manager == null or _game_manager.state == GameManager.State.PLAYING
	var travel_length := Vector2(
		current_position.x - previous_position.x,
		current_position.z - previous_position.z,
	).length()
	if can_collect and travel_length <= GameConfig.COIN_TELEPORT_LIMIT:
		_detect_collections(previous_position, current_position)

	_recycle_passed_coins(current_position.z)


func _spawn_initial_coins() -> void:
	var start_z := _player.global_position.z if _player != null else 0.0
	for index in GameConfig.COIN_ACTIVE_COUNT:
		var coin := Coin.new()
		coin.name = "Coin_%d" % index
		add_child(coin)
		var coin_z := start_z - GameConfig.COIN_FIRST_DISTANCE - index * GameConfig.COIN_SPAWN_SPACING
		_spawn_coin(coin, index, coin_z)
		coins.append(coin)
	_next_spawn_serial = GameConfig.COIN_ACTIVE_COUNT


func _spawn_coin(coin: Coin, serial: int, coin_z: float) -> void:
	if coin == null:
		return
	var lane_pattern := GameConfig.COIN_LANE_PATTERN
	var lane_x := 0.0
	if not lane_pattern.is_empty():
		lane_x = lane_pattern[posmod(serial, lane_pattern.size())]
	coin.setup(Vector3(lane_x, GameConfig.COIN_HEIGHT, coin_z), serial)


func _detect_collections(previous_position: Vector3, current_position: Vector3) -> void:
	var radius_squared := GameConfig.COIN_PICKUP_RADIUS * GameConfig.COIN_PICKUP_RADIUS
	for coin in coins:
		if coin == null or not coin.is_available():
			continue
		var coin_position := coin.global_position
		var point := Vector2(coin_position.x, coin_position.z)
		if _distance_squared_to_segment_xz(point, previous_position, current_position) > radius_squared:
			continue
		if not coin.collect():
			continue

		var accepted := true
		if _game_manager != null:
			accepted = _game_manager.collect_coin(GameConfig.COIN_VALUE)
		if not accepted:
			# Lo stato può cambiare solo in questo frame; nel caso anomalo la
			# moneta viene comunque consumata, ma non accredita un premio.
			continue

		collected_count += 1
		last_collected_coin = coin
		var total := collected_count
		if _game_manager != null:
			total = _game_manager.session_coins
		coin_collected.emit(total)


func _distance_squared_to_segment_xz(point: Vector2, start_3d: Vector3, end_3d: Vector3) -> float:
	var start := Vector2(start_3d.x, start_3d.z)
	var end := Vector2(end_3d.x, end_3d.z)
	var segment := end - start
	var length_squared := segment.length_squared()
	var weight := 0.0
	if length_squared > 0.000001:
		weight = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest := start + segment * weight
	return point.distance_squared_to(closest)


func _recycle_passed_coins(car_z: float) -> void:
	for coin in coins:
		if coin == null or coin.is_collecting():
			continue
		if coin.global_position.z <= car_z + GameConfig.COIN_RECYCLING_OFFSET:
			continue
		var next_z := car_z - GameConfig.COIN_FIRST_DISTANCE
		for other in coins:
			if other == null or other == coin:
				continue
			if other.global_position.z < next_z:
				next_z = other.global_position.z
		_spawn_coin(coin, _next_spawn_serial, next_z - GameConfig.COIN_SPAWN_SPACING)
		_next_spawn_serial += 1
