class_name ObstacleManager
extends Node3D
## Gestisce le file di ostacoli lungo la pista (fase 3).
##
## Quattro tipologie, tutte generate a partire da parametri deterministici
## (serial + difficoltà), così il layout è riproducibile e testabile:
## - CONES: campo di coni stradali (non solidi, si abbattono);
## - BARRIER: barriera statica che occupa parte della carreggiata (solida);
## - NARROW: restringimento con due muri e un varco preciso da centrare (solidi);
## - MOVING: blocco mobile che attraversa la pista a pendolo (solido, predicibile).
##
## Fairness garantita per costruzione (vedi GameConfig, sezione Ostacoli):
## - ogni fila è ANCORATA a una fila di cancelli, a OBSTACLE_CORRIDOR_OFFSET
##   metri oltre di essa: ostacoli e cancelli non sono mai vicini, quindi le
##   due meccaniche non si disturbano e nessuna opzione dei cancelli diventa
##   irraggiungibile a causa di un muro;
## - ogni fila lascia un varco largo almeno OBSTACLE_GAP_MIN (> ingombro massimo
##   dell'auto ruotata + margine): il passaggio è sempre possibile;
## - le file distano GATE_ROW_SPACING tra loro: il tempo per passare da un
##   varco all'altro è sempre ampio rispetto alla velocità laterale massima;
## - gli ostacoli mobili occupano al più ~2 m di carreggiata: resta sempre
##   spazio libero, e dopo pochi contatti il blocco viene abbattuto (nessun
##   blocco permanente della corsa).
##
## Collisioni affidabili: il percorso dell'auto nel frame (segmento 3D) viene
## testato contro il rettangolo XZ di ogni pezzo dilatato dell'ingombro auto,
## con sottopassi per i mobili; i solidi risolvono la posizione sulla faccia di
## contatto, quindi l'auto NON attraversa mai un ostacolo solido. I salti di
## posizione oltre OBSTACLE_TELEPORT_LIMIT (test/reset) non generano collisioni.
##
## Una collisione applica ESATTAMENTE UNA penalità, mai entrambe:
## - velocità temporanea (coni, barriere, muri) via CarController.apply_speed_penalty;
## - un livello di evoluzione perso (blocchi mobili) via GameManager.apply_evolution.

## Emesso quando una collisione applica una penalità.
## `penalty_kind` è GameConfig.OBSTACLE_PENALTY_*, `evolution_delta` la
## variazione di livello realmente applicata (0 per le penalità di velocità).
signal obstacle_hit(penalty_kind: int, evolution_delta: int)

## File attualmente in gioco (usata anche dai test).
var rows: Array[ObstacleRow] = []
## Contatori per HUD, debug e test.
var hit_count: int = 0
var penalties_applied: int = 0
var rows_generated: int = 0
var formations_seen: Dictionary = {}
## Ultimo ostacolo colpito (null quando la sua fila viene rigenerata).
var last_hit_obstacle: Obstacle = null
var last_penalty_kind: int = GameConfig.OBSTACLE_PENALTY_SPEED
var last_evolution_delta: int = 0

var _player: CarController = null
var _game_manager: GameManager = null
var _gate_manager: GateManager = null
var _previous_car_position: Vector3 = Vector3.ZERO
var _row_serial: int = 0
var _sim_time: float = 0.0
var _travel_distance: float = 0.0
var _effects: Array = []


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as CarController
	_game_manager = get_tree().get_first_node_in_group(&"game_manager") as GameManager
	_gate_manager = get_tree().get_first_node_in_group(&"gate_manager") as GateManager
	if _player != null:
		_previous_car_position = _player.global_position
	_build_initial_rows()


func _physics_process(delta: float) -> void:
	step(maxf(delta, 0.0))


## Un passo di simulazione: sincronizza gli ancoraggi, fa avanzare mobili e
## animazioni, rileva le collisioni e ricicla le file. Separato da
## _physics_process per poter essere eseguito in modo deterministico dai test.
func step(delta: float = 0.0) -> void:
	if _player == null:
		return
	var current_position := _player.global_position
	var previous_position := _previous_car_position
	_previous_car_position = current_position

	# In menu, countdown, pausa e riepilogo il mondo è immobile: nessun urto,
	# animazione di ostacolo o riciclo può modificare una corsa già conclusa.
	if _game_manager != null and _game_manager.state != GameManager.State.PLAYING:
		return

	var dt := clampf(delta, 0.0, GameConfig.OBSTACLE_MAX_STEP_DT)
	_sim_time += dt
	_sync_rows()

	for row in rows:
		for piece in row.obstacles:
			var obstacle := piece as Obstacle
			if obstacle == null:
				continue
			obstacle.prev_frame_x = obstacle.position.x
			obstacle.advance(dt, true)

	var travel := Vector2(
		current_position.x - previous_position.x,
		current_position.z - previous_position.z,
	)
	var path_length := travel.length()
	# I teletrasporti (test/reset) non generano collisioni; il passo reale è limitato.
	if path_length > 0.000001 and path_length <= GameConfig.OBSTACLE_TELEPORT_LIMIT:
		_travel_distance += absf(current_position.z - previous_position.z)
		_detect_collisions(previous_position, current_position)

	# La risoluzione delle collisioni può avere spostato l'auto: il campione
	# "precedente" del prossimo passo è la posizione reale corrente.
	_previous_car_position = _player.global_position
	_advance_effects(dt)


## Elimina gli effetti e ricrea file/contatori per una nuova corsa.
func reset_run() -> void:
	for row in rows:
		_clear_row_pieces(row)
	rows.clear()
	for effect in _effects:
		var entry: Dictionary = effect
		var root := entry.get("root", null) as Node3D
		if root == null or not is_instance_valid(root):
			continue
		if root.get_parent() == self:
			remove_child(root)
		root.queue_free()
	_effects.clear()
	_row_serial = 0
	_sim_time = 0.0
	_travel_distance = 0.0
	hit_count = 0
	penalties_applied = 0
	rows_generated = 0
	formations_seen.clear()
	last_hit_obstacle = null
	last_penalty_kind = GameConfig.OBSTACLE_PENALTY_SPEED
	last_evolution_delta = 0
	_previous_car_position = _player.global_position if _player != null else Vector3.ZERO
	_build_initial_rows()


# ---------------------------------------------------------------- Query -----

## Distanza percorsa rilevante per la difficoltà (metri).
func travel_distance() -> float:
	if _game_manager != null:
		return maxf(_travel_distance, _game_manager.distance)
	return _travel_distance


## Difficoltà corrente [0..1] della generazione degli ostacoli.
func current_difficulty() -> float:
	return difficulty_for_distance(travel_distance())


## Rampa della difficoltà con la distanza percorsa: 0 fino a
## OBSTACLE_EASY_DISTANCE, cresce linearmente, satura a 1 da
## OBSTACLE_RAMP_DISTANCE. Monotòna e limitata: progressione controllata.
static func difficulty_for_distance(distance_meters: float) -> float:
	var easy := GameConfig.OBSTACLE_EASY_DISTANCE
	var ramp := GameConfig.OBSTACLE_RAMP_DISTANCE
	if ramp <= easy:
		return 1.0 if distance_meters >= ramp else 0.0
	return clampf((distance_meters - easy) / (ramp - easy), 0.0, 1.0)


## Formazione scelta per una fila: deterministica (serial) e progressiva.
## All'inizio solo coni e barriere; i restringimenti compaiono a
## OBSTACLE_TIER_NARROW, i mobili a OBSTACLE_TIER_MOVING.
static func pick_formation(serial: int, difficulty: float) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(serial * 7919 + 104729)
	var pool: Array[int] = [ObstacleRow.Formation.CONES, ObstacleRow.Formation.BARRIER]
	var d := clampf(difficulty, 0.0, 1.0)
	if d >= GameConfig.OBSTACLE_TIER_NARROW:
		pool.append(ObstacleRow.Formation.NARROW)
	if d >= GameConfig.OBSTACLE_TIER_MOVING:
		pool.append(ObstacleRow.Formation.MOVING)
	return pool[rng.randi_range(0, pool.size() - 1)]


## Parametri geometrici di una fila (deterministici per serial + difficoltà):
## larghezza del varco, lato occupato, numero di coni, velocità/fase dei mobili.
## Il varco non scende mai sotto OBSTACLE_GAP_MIN: il passaggio resta possibile.
static func formation_parameters(serial: int, difficulty: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(serial * 48611 + 4231)
	var d := clampf(difficulty, 0.0, 1.0)
	var gap := clampf(
		lerpf(GameConfig.OBSTACLE_GAP_WIDE, GameConfig.OBSTACLE_GAP_MIN, d)
		+ rng.randf_range(-0.15, 0.15),
		GameConfig.OBSTACLE_GAP_MIN,
		GameConfig.OBSTACLE_GAP_WIDE,
	)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var cone_count := 3
	if rng.randf() < 0.35 + 0.35 * d:
		cone_count += 1
	if d > 0.6 and rng.randf() < 0.5:
		cone_count += 1
	var usable_width := GameConfig.TRACK_WIDTH - GameConfig.OBSTACLE_EDGE_MARGIN * 2.0
	return {
		"gap": gap,
		"side": side,
		"cone_count": cone_count,
		"move_speed": lerpf(
			GameConfig.OBSTACLE_MOVING_SPEED_SLOW,
			GameConfig.OBSTACLE_MOVING_SPEED_FAST,
			d,
		),
		"move_phase": rng.randf_range(0.0, usable_width * 2.0),
	}


# ------------------------------------------------------------- Generazione --

func _build_initial_rows() -> void:
	var gate_rows := _gate_rows()
	if not gate_rows.is_empty():
		for anchor in gate_rows:
			var gate_row := anchor as GateRow
			if gate_row == null:
				continue
			var row := ObstacleRow.new()
			row.z = gate_row.z - GameConfig.OBSTACLE_CORRIDOR_OFFSET
			rows.append(row)
			_refill_row(row)
		return

	# Senza GateManager (uso isolato): file proprie, equidistanti davanti all'auto.
	var base_z := _player.global_position.z if _player != null else 0.0
	for index in GameConfig.GATE_ROW_COUNT:
		var row := ObstacleRow.new()
		row.z = base_z - (
			GameConfig.OBSTACLE_FIRST_ROW_DISTANCE + index * GameConfig.OBSTACLE_VIRTUAL_SPACING
		)
		rows.append(row)
		_refill_row(row)


## Le file seguono l'ancora (fila di cancelli): quando un cancello viene
## riciclato verso l'orizzonte, anche i suoi ostacoli viaggiano con esso e
## vengono rigenerati con la difficoltà corrente. Il "salto" avviene sempre
## quando l'auto ha già superato la fila (vedi OBSTACLE_CORRIDOR_OFFSET).
func _sync_rows() -> void:
	var gate_rows := _gate_rows()
	if gate_rows.is_empty():
		_recycle_virtual_rows()
		return

	while rows.size() < gate_rows.size():
		var row := ObstacleRow.new()
		var anchor := gate_rows[rows.size()] as GateRow
		row.z = anchor.z - GameConfig.OBSTACLE_CORRIDOR_OFFSET if anchor != null else 0.0
		rows.append(row)
		_refill_row(row)
	while rows.size() > gate_rows.size():
		var removed: ObstacleRow = rows.pop_back()
		_clear_row_pieces(removed)

	for index in rows.size():
		var row: ObstacleRow = rows[index]
		var anchor := gate_rows[index] as GateRow
		if anchor == null:
			continue
		var desired := anchor.z - GameConfig.OBSTACLE_CORRIDOR_OFFSET
		if absf(row.z - desired) > 0.001:
			row.z = desired
			_refill_row(row)


func _recycle_virtual_rows() -> void:
	if _player == null:
		return
	var car_z := _player.global_position.z
	for row in rows:
		if row.z <= car_z + GameConfig.OBSTACLE_PASSED_OFFSET:
			continue
		var farthest := INF
		for other in rows:
			if other == row:
				continue
			if other.z < farthest and other.z <= car_z:
				farthest = other.z
		if is_inf(farthest):
			farthest = (
				car_z - GameConfig.OBSTACLE_FIRST_ROW_DISTANCE + GameConfig.OBSTACLE_VIRTUAL_SPACING
			)
		row.z = farthest - GameConfig.OBSTACLE_VIRTUAL_SPACING
		_refill_row(row)


## Rigenera il contenuto di una fila con la difficoltà corrente.
func _refill_row(row: ObstacleRow) -> void:
	row.serial = _row_serial
	_row_serial += 1
	var difficulty := current_difficulty()
	var formation := pick_formation(row.serial, difficulty)
	apply_formation(row, formation, difficulty, row.serial)
	rows_generated += 1
	formations_seen[formation] = int(formations_seen.get(formation, 0)) + 1


## Costruisce i pezzi di una formazione nella fila (usato anche dai test per
## preparare scenari deterministici). I vecchi pezzi vengono liberati.
func apply_formation(row: ObstacleRow, formation: int, difficulty: float, serial: int = -1) -> void:
	_clear_row_pieces(row)
	row.formation = formation
	row.difficulty = clampf(difficulty, 0.0, 1.0)
	if serial >= 0:
		row.serial = serial

	var params := formation_parameters(row.serial, row.difficulty)
	var usable_half := GameConfig.TRACK_WIDTH * 0.5 - GameConfig.OBSTACLE_EDGE_MARGIN
	var usable_width := usable_half * 2.0
	var gap: float = clampf(float(params["gap"]), GameConfig.OBSTACLE_GAP_MIN, usable_width)
	var side: float = float(params["side"])

	match formation:
		ObstacleRow.Formation.CONES:
			var cone_count: int = int(params["cone_count"])
			var cover := maxf(usable_width - gap, 0.6)
			var cone_step := cover / float(cone_count)
			for index in cone_count:
				var offset := cone_step * (float(index) + 0.5)
				var x := -usable_half + offset if side < 0.0 else usable_half - offset
				row.obstacles.append(_make_static(
					Obstacle.Kind.CONE, x, row.z, GameConfig.OBSTACLE_CONE_HALF_EXTENTS
				))
		ObstacleRow.Formation.BARRIER:
			var block_width := maxf(usable_width - gap, 0.6)
			var center := -usable_half + block_width * 0.5
			if side > 0.0:
				center = usable_half - block_width * 0.5
			var halves := Vector3(
				block_width * 0.5,
				GameConfig.OBSTACLE_BARRIER_HALF_HEIGHT,
				GameConfig.OBSTACLE_BARRIER_HALF_DEPTH,
			)
			row.obstacles.append(_make_static(Obstacle.Kind.BARRIER, center, row.z, halves))
		ObstacleRow.Formation.NARROW:
			var wall_width := maxf((usable_width - gap) * 0.5, 0.4)
			var wall_halves := Vector3(
				wall_width * 0.5,
				GameConfig.OBSTACLE_WALL_HALF_HEIGHT,
				GameConfig.OBSTACLE_WALL_HALF_DEPTH,
			)
			row.obstacles.append(_make_static(
				Obstacle.Kind.NARROW_WALL, -usable_half + wall_width * 0.5, row.z, wall_halves
			))
			row.obstacles.append(_make_static(
				Obstacle.Kind.NARROW_WALL, usable_half - wall_width * 0.5, row.z, wall_halves
			))
		ObstacleRow.Formation.MOVING:
			var halves := GameConfig.OBSTACLE_MOVING_HALF_EXTENTS
			var obstacle := Obstacle.new()
			obstacle.name = "ObstacleMoving_%d" % row.serial
			add_child(obstacle)
			obstacle.setup_mover(
				row.z,
				halves,
				-usable_half + halves.x + 0.05,
				usable_half - halves.x - 0.05,
				float(params["move_speed"]),
				float(params["move_phase"]),
			)
			row.obstacles.append(obstacle)
		_:
			push_warning("Formazione ostacoli sconosciuta: %d" % formation)


func _make_static(kind: int, x: float, z: float, halves: Vector3) -> Obstacle:
	var obstacle := Obstacle.new()
	match kind:
		Obstacle.Kind.CONE:
			obstacle.name = "ObstacleCone"
		Obstacle.Kind.BARRIER:
			obstacle.name = "ObstacleBarrier"
		_:
			obstacle.name = "ObstacleWall"
	add_child(obstacle)
	# setup_static va chiamato DOPO add_child: la geometria vive nell'albero.
	obstacle.setup_static(kind, x, z, halves)
	return obstacle


func _clear_row_pieces(row: ObstacleRow) -> void:
	for piece in row.obstacles:
		var obstacle := piece as Obstacle
		if obstacle == null:
			continue
		if obstacle == last_hit_obstacle:
			last_hit_obstacle = null
		if obstacle.get_parent() == self:
			remove_child(obstacle)
		obstacle.queue_free()
	row.obstacles = []


func _gate_rows() -> Array:
	if _gate_manager != null:
		return _gate_manager.rows
	return []


# --------------------------------------------------------------- Collisioni --

## Rileva le collisioni tra il segmento percorso dall'auto (prev -> cur) e i
## pezzi attivi. Sottopassi limitati tengono conto anche del moto dei blocchi
## mobili: nessun tunneling né con passi grandi né a frame rate bassi.
func _detect_collisions(previous_position: Vector3, current_position: Vector3) -> void:
	var car_half := _car_half_extents()
	var path_length := Vector2(
		current_position.x - previous_position.x,
		current_position.z - previous_position.z,
	).length()
	var substeps := clampi(
		ceili(path_length / GameConfig.OBSTACLE_SUBSTEP_LENGTH),
		1,
		GameConfig.OBSTACLE_MAX_SUBSTEPS,
	)

	var hits: Array = []
	for row in rows:
		for piece in row.obstacles:
			var obstacle := piece as Obstacle
			if obstacle == null or not obstacle.is_collidable():
				continue
			for substep in substeps:
				var from := previous_position.lerp(current_position, float(substep) / float(substeps))
				var to := previous_position.lerp(current_position, float(substep + 1) / float(substeps))
				var override_x := NAN
				if obstacle.is_mover():
					override_x = lerpf(
						obstacle.prev_frame_x,
						obstacle.position.x,
						(float(substep) + 0.5) / float(substeps),
					)
				var t := Obstacle.segment_enter_t(
					Vector2(from.x, from.z),
					Vector2(to.x, to.z),
					obstacle.collision_rect(override_x),
					car_half,
				)
				if not is_nan(t):
					hits.append({
						"t": (float(substep) + t) / float(substeps),
						"obstacle": obstacle,
						"point": from.lerp(to, t),
					})
					break

	if hits.is_empty():
		return
	hits.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return float(first["t"]) < float(second["t"])
	)
	for hit in hits:
		var obstacle: Obstacle = hit["obstacle"]
		if obstacle == null or not obstacle.is_collidable():
			continue
		_resolve_hit(obstacle, hit["point"] as Vector3, previous_position)
		if obstacle.solid:
			# L'auto si ferma sulla faccia di contatto: i pezzi più in
			# profondità non sono fisicamente raggiungibili in questo frame.
			break


func _resolve_hit(obstacle: Obstacle, contact: Vector3, previous_position: Vector3) -> void:
	if _sim_time - obstacle.last_hit_time < GameConfig.OBSTACLE_HIT_COOLDOWN:
		# Contatto continuo (es. auto che spinge contro un blocco mobile):
		# nessuna penalità ripetuta, solo risoluzione della posizione.
		if obstacle.solid:
			_resolve_position(obstacle, previous_position)
		return

	obstacle.last_hit_time = _sim_time
	obstacle.hit_count += 1
	if obstacle.solid:
		_resolve_position(obstacle, previous_position)

	var hit_dir := signf(_player.global_position.x - obstacle.global_position.x)
	if is_zero_approx(hit_dir):
		hit_dir = 1.0
	obstacle.register_hit(hit_dir)

	_spawn_impact(Vector3(contact.x, 0.40, obstacle.position.z + obstacle.half_extents.z))
	_player.add_impact_shake(1.0 if obstacle.solid else 0.6)
	hit_count += 1
	last_hit_obstacle = obstacle
	last_penalty_kind = obstacle.penalty_kind

	if not obstacle.penalty_applied:
		obstacle.penalty_applied = true
		last_evolution_delta = _apply_penalty(obstacle)
		penalties_applied += 1
		if _game_manager != null:
			_game_manager.register_obstacle_hit()
		obstacle_hit.emit(obstacle.penalty_kind, last_evolution_delta)


## Applica ESATTAMENTE UNA penalità: velocità temporanea OPPURE un livello di
## evoluzione perso, in base alla tipologia. Mai entrambe per la stessa
## collisione (il canale è determinato da `obstacle.penalty_kind`).
func _apply_penalty(obstacle: Obstacle) -> int:
	if obstacle.penalty_kind == GameConfig.OBSTACLE_PENALTY_EVOLUTION:
		if _game_manager != null:
			return _game_manager.apply_evolution(-obstacle.evolution_penalty_step)
		return 0
	if _player != null:
		_player.apply_speed_penalty(
			obstacle.speed_penalty_factor,
			obstacle.speed_penalty_duration,
		)
	return 0


## Risolve la posizione dell'auto contro un solido: la riporta sulla faccia di
## contatto così non lo attraversa mai. I blocchi mobili che "scivolano" sopra
## l'auto quasi ferma la spingono di lato, se c'è spazio entro i cordoli.
func _resolve_position(obstacle: Obstacle, previous_position: Vector3) -> void:
	var car_half := _car_half_extents()
	var rect := obstacle.collision_rect()
	var front_face := rect.position.y + rect.size.y
	var car_position := _player.global_position
	var eps := 0.02
	var entered_from_front := previous_position.z >= front_face + car_half.y - eps
	var resolved := car_position
	if entered_from_front or not obstacle.is_mover():
		resolved.z = front_face + car_half.y + eps
	else:
		var left_x := rect.position.x - car_half.x - eps
		var right_x := rect.position.x + rect.size.x + car_half.x + eps
		var limit := _player.lateral_limit
		if absf(car_position.x - left_x) <= absf(car_position.x - right_x) and left_x >= -limit:
			resolved.x = left_x
		elif right_x <= limit:
			resolved.x = right_x
		else:
			resolved.z = front_face + car_half.y + eps
	_player.global_position = resolved
	if absf(resolved.x - car_position.x) > 0.0001:
		_player.lateral_target = clampf(resolved.x, -_player.lateral_limit, _player.lateral_limit)


## Semi-assi XZ dell'auto ruotata (stesso criterio dei bordi pista): nemmeno
## gli angoli della carrozzeria possono entrare in un ostacolo.
func _car_half_extents() -> Vector2:
	var profile := _player.evolution_profile()
	if profile == null:
		profile = CarEvolutionCatalog.profile_for(GameConfig.EVOLUTION_START_LEVEL)
	var yaw := absf(_player.rotation.y)
	var margin := GameConfig.OBSTACLE_CAR_MARGIN
	var half_x := profile.lateral_half_extent(yaw) + margin
	var half_z := profile.half_width * sin(yaw) + profile.half_length * cos(yaw) + margin
	return Vector2(half_x, half_z)


# ------------------------------------------------------------------ Effetti --

## Effetto d'impatto: anello che si espande, lampo di luce breve e poche
## scintille. Volutamente contenuto (niente schermate bianche o pioggia di
## particelle): dà il "colpo" senza coprire la pista.
## Autogestito e limitato a OBSTACLE_MAX_EFFECTS istanze simultanee.
func _spawn_impact(at: Vector3) -> void:
	if _effects.size() >= GameConfig.OBSTACLE_MAX_EFFECTS:
		return
	var root := Node3D.new()
	root.name = "Impact"
	root.position = at
	add_child(root)

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(
		GameConfig.COLOR_OBSTACLE_IMPACT.r,
		GameConfig.COLOR_OBSTACLE_IMPACT.g,
		GameConfig.COLOR_OBSTACLE_IMPACT.b,
		0.85,
	)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.emission_enabled = true
	ring_material.emission = GameConfig.COLOR_OBSTACLE_IMPACT
	ring_material.emission_energy_multiplier = 1.8

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.0
	ring_mesh.bottom_radius = 1.0
	ring_mesh.height = 0.03
	ring_mesh.radial_segments = 18
	ring_mesh.rings = 1
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(0.35, 1.0, 0.35)
	root.add_child(ring)

	var light := OmniLight3D.new()
	light.light_color = GameConfig.COLOR_OBSTACLE_IMPACT
	light.omni_range = 4.2
	light.light_energy = 2.6
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.40, 0.0)
	root.add_child(light)

	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.075, 0.075, 0.075)
	var spark_material := MaterialFactory.emissive(
		"obstacle_spark", GameConfig.COLOR_OBSTACLE_IMPACT, 1.6
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(int(_sim_time * 1000.0) + hit_count * 31 + 7)
	var sparks: Array = []
	for _index in 4:
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		spark.material_override = spark_material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(spark)
		var angle := rng.randf() * TAU
		sparks.append({
			"node": spark,
			"velocity": Vector3(
				cos(angle) * rng.randf_range(1.5, 3.5),
				rng.randf_range(2.5, 4.5),
				sin(angle) * rng.randf_range(1.5, 3.5) - 1.2,
			),
		})

	_effects.append({
		"root": root,
		"ring": ring,
		"ring_material": ring_material,
		"light": light,
		"sparks": sparks,
		"time": 0.0,
	})


func _advance_effects(dt: float) -> void:
	var index := _effects.size() - 1
	while index >= 0:
		var effect: Dictionary = _effects[index]
		effect["time"] = float(effect["time"]) + dt
		var progress := clampf(
			float(effect["time"]) / GameConfig.OBSTACLE_IMPACT_DURATION, 0.0, 1.0
		)

		var ring: MeshInstance3D = effect["ring"]
		var ring_scale := lerpf(0.32, 1.75, progress)
		ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material: StandardMaterial3D = effect["ring_material"]
		ring_material.albedo_color.a = 0.85 * (1.0 - progress)

		var light: OmniLight3D = effect["light"]
		light.light_energy = 2.6 * pow(1.0 - progress, 2.0)
		light.visible = progress < 1.0

		for spark_entry in effect["sparks"]:
			var spark: Dictionary = spark_entry
			var node: MeshInstance3D = spark["node"]
			var velocity: Vector3 = spark["velocity"]
			velocity.y -= 9.8 * dt
			node.position += velocity * dt
			spark["velocity"] = velocity
			var shrink := maxf(1.0 - progress, 0.0)
			node.scale = Vector3(shrink, shrink, shrink)

		if progress >= 1.0:
			var root: Node3D = effect["root"]
			if root.get_parent() == self:
				remove_child(root)
			root.queue_free()
			_effects.remove_at(index)
		index -= 1
