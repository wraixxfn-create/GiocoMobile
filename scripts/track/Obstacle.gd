class_name Obstacle
extends Node3D
## Un singolo ostacolo sulla pista (fase 3).
##
## Come i cancelli, l'ostacolo è visivo + logico (nessun corpo fisico): la
## geometria serve al giocatore per leggere il varco, mentre la collisione è
## risolta analiticamente da `ObstacleManager` (segmento auto contro rettangolo
## XZ dilatato dell'ingombro auto). Questo rende gli urti affidabili a qualsiasi
## frame rate e con passi grandi, e garantisce che l'auto non attraversi mai un
## ostacolo solido: a ogni contatto la posizione viene riportata sulla faccia
## di contatto prima del frame successivo.
##
## Quattro tipologie (Kind):
## - CONE: cono stradale, NON solido; si abbatte e rallenta brevemente l'auto.
## - BARRIER: barriera statica solida; si sfonda con forte perdita di velocità.
## - NARROW_WALL: muro dei restringimenti, solido; si sfonda, perdita media.
## - MOVING_BLOCK: blocco mobile che attraversa la pista a velocità costante
##   (moto a pendolo predicibile); solido; fa perdere UN livello di evoluzione.
##
## Ogni collisione applica ESATTAMENTE UNA penalità (`penalty_applied`):
## velocità oppure evoluzione, mai entrambe.
##
## Il movimento dei blocchi mobili è derivato da una fase lineare
## (`ping_pong_x(move_phase)`): deterministico, predicibile dai test e
## leggibile dal giocatore (nessuna accelerazione o traiettoria casuale).

enum Kind { CONE, BARRIER, NARROW_WALL, MOVING_BLOCK }
enum State { ACTIVE, HIT, BROKEN }

const RECOIL_DURATION: float = 0.28
const BEACON_PULSE_SPEED: float = 2.8
const CONE_SLIDE_DISTANCE: float = 0.42
const BREAK_TILT: float = 1.35
const BREAK_SINK: float = 0.45
const MOVING_BREAK_SPIN: float = 3.2
const MOVING_BREAK_SLIDE: float = 1.6

var kind: int = Kind.BARRIER
var state: int = State.ACTIVE
## True se l'auto non può attraversarlo (la posizione viene risolta a contatto).
var solid: bool = true
## Semi-assi dell'ingombro (x, y, z) in metri; y è solo visivo (la collisione
## lavora sul piano XZ, l'auto è sempre a terra).
var half_extents: Vector3 = Vector3(0.5, 0.5, 0.3)
## Penalità associata (GameConfig.OBSTACLE_PENALTY_*): una sola per collisione.
var penalty_kind: int = GameConfig.OBSTACLE_PENALTY_SPEED
var speed_penalty_factor: float = 1.0
var speed_penalty_duration: float = 0.0
var evolution_penalty_step: int = 0
## La penalità è già stata applicata: mai due volte per lo stesso ostacolo.
var penalty_applied: bool = false
## Contatti contati (oltre la cooldown): i mobili si abbattono a
## GameConfig.OBSTACLE_MOVING_BREAK_HITS.
var hit_count: int = 0
## Istante di simulazione dell'ultimo contatto contato (cooldown).
var last_hit_time: float = -1000.0

## Moto a pendolo (solo MOVING_BLOCK): la posizione X è derivata dalla fase.
var move_min_x: float = 0.0
var move_max_x: float = 0.0
var move_speed: float = 0.0
var move_phase: float = 0.0
## X a inizio frame: usata per interpolare l'ostacolo nei sottopassi della
## rilevazione (nessun tunneling nemmeno con il blocco in movimento).
var prev_frame_x: float = 0.0

var _visual: Node3D = null
var _body_material: StandardMaterial3D = null
var _beacon_material: StandardMaterial3D = null
var _anim_time: float = 0.0
var _recoil_time: float = 0.0
var _beacon_time: float = 0.0
var _hit_dir: float = 1.0
var _break_slide: float = 0.0


func _ready() -> void:
	prev_frame_x = position.x


## Pezzo fermo (barriera, muro, cono) su un piano di fila.
func setup_static(piece_kind: int, x: float, z: float, halves: Vector3) -> void:
	kind = piece_kind
	solid = piece_kind != Kind.CONE
	half_extents = halves
	position = Vector3(x, 0.0, z)
	prev_frame_x = x
	move_speed = 0.0
	_configure_penalty()
	_build()


## Blocco mobile: attraversa la pista tra due limiti a velocità costante.
func setup_mover(
	z: float,
	halves: Vector3,
	min_x: float,
	max_x: float,
	speed: float,
	phase: float,
) -> void:
	kind = Kind.MOVING_BLOCK
	solid = true
	half_extents = halves
	move_min_x = min_x
	move_max_x = max_x
	move_speed = maxf(speed, 0.0)
	move_phase = phase
	position = Vector3(ping_pong_x(phase), 0.0, z)
	prev_frame_x = position.x
	_configure_penalty()
	_build()


func is_mover() -> bool:
	return kind == Kind.MOVING_BLOCK


## Collidibile finché è attivo: coni abbattuti e pezzi sfondati non lo sono più.
func is_collidable() -> bool:
	return state == State.ACTIVE


## Rettangolo di collisione nel piano XZ (Rect2: x = mondo X, y = mondo Z).
## `override_x` interpola la posizione dei mobili nei sottopassi del frame.
func collision_rect(override_x: float = NAN) -> Rect2:
	var center_x := position.x if is_nan(override_x) else override_x
	return Rect2(
		Vector2(center_x - half_extents.x, position.z - half_extents.z),
		Vector2(half_extents.x * 2.0, half_extents.z * 2.0),
	)


## Posizione X del pendolo per una data fase (metri percorsi, ripiegati).
func ping_pong_x(phase: float) -> float:
	var span := move_max_x - move_min_x
	if span <= 0.0:
		return move_min_x
	var period := span * 2.0
	var folded := fposmod(phase, period)
	if folded <= span:
		return move_min_x + folded
	return move_max_x - (folded - span)


## X prevista tra `seconds` secondi: stessa formula del moto, usata dai test
## (e utile in futuro a qualsiasi logica che debba "guardare avanti").
func predicted_x(seconds: float) -> float:
	return ping_pong_x(move_phase + move_speed * seconds)


## Avanza moto e animazioni di `dt`. Il moto dei mobili avviene solo a partita
## iniziata (`simulate_movement`); le animazioni girano sempre.
func advance(dt: float, simulate_movement: bool) -> void:
	if is_mover() and state == State.ACTIVE and simulate_movement and move_speed > 0.0:
		move_phase += move_speed * dt
		position.x = ping_pong_x(move_phase)

	if is_mover() and state == State.ACTIVE:
		_beacon_time += dt
		if _beacon_material != null:
			var pulse := maxf(sin(_beacon_time * BEACON_PULSE_SPEED), 0.0)
			_beacon_material.emission_energy_multiplier = 1.0 + 0.55 * pulse

	if _recoil_time > 0.0:
		_recoil_time = maxf(_recoil_time - dt, 0.0)
		if _body_material != null:
			var flash := _recoil_time / RECOIL_DURATION
			_body_material.emission_energy_multiplier = 0.65 * flash * flash

	match state:
		State.HIT:
			_anim_time += dt
			_animate_cone_fall(clampf(_anim_time / GameConfig.OBSTACLE_CONE_FALL_DURATION, 0.0, 1.0))
		State.BROKEN:
			_anim_time += dt
			var progress := clampf(_anim_time / GameConfig.OBSTACLE_BREAK_DURATION, 0.0, 1.0)
			_animate_break(progress)
		_:
			pass


## Registra un contatto già contato dal manager: avvia l'animazione corretta.
## `hit_dir` è il lato da cui arriva l'auto (-1/+1), usato per coni e detriti.
func register_hit(hit_dir: float) -> void:
	_hit_dir = hit_dir if absf(hit_dir) > 0.001 else 1.0
	match kind:
		Kind.CONE:
			if state == State.ACTIVE:
				state = State.HIT
				_anim_time = 0.0
		Kind.MOVING_BLOCK:
			if hit_count >= GameConfig.OBSTACLE_MOVING_BREAK_HITS:
				state = State.BROKEN
				_anim_time = 0.0
				_break_slide = 0.0
			else:
				_recoil_time = RECOIL_DURATION
				if _body_material != null:
					_body_material.emission_enabled = true
					_body_material.emission = GameConfig.COLOR_OBSTACLE_IMPACT
		_:
			if state == State.ACTIVE:
				state = State.BROKEN
				_anim_time = 0.0


## Ingresso del segmento `a -> b` (centro auto, piano XZ) nel rettangolo
## `rect` dilatato di `expand` (semi-assi dell'auto). Restituisce il parametro
## t in [0,1] del primo contatto, oppure NAN se il segmento non lo attraversa.
## Metodo degli slab: corretto anche con passi grandi e moto diagonale.
static func segment_enter_t(a: Vector2, b: Vector2, rect: Rect2, expand: Vector2) -> float:
	var lo := rect.position - expand
	var hi := rect.position + rect.size + expand
	var d := b - a
	var t_min := 0.0
	var t_max := 1.0
	for axis in 2:
		if absf(d[axis]) < 0.000001:
			if a[axis] < lo[axis] or a[axis] > hi[axis]:
				return NAN
		else:
			var inv := 1.0 / d[axis]
			var t1 := (lo[axis] - a[axis]) * inv
			var t2 := (hi[axis] - a[axis]) * inv
			if t1 > t2:
				var swap := t1
				t1 = t2
				t2 = swap
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return NAN
	return t_min


# ------------------------------------------------------------------ Setup ---

func _configure_penalty() -> void:
	match kind:
		Kind.CONE:
			penalty_kind = GameConfig.OBSTACLE_PENALTY_SPEED
			speed_penalty_factor = GameConfig.OBSTACLE_CONE_SPEED_FACTOR
			speed_penalty_duration = GameConfig.OBSTACLE_CONE_SPEED_DURATION
			evolution_penalty_step = 0
		Kind.BARRIER:
			penalty_kind = GameConfig.OBSTACLE_PENALTY_SPEED
			speed_penalty_factor = GameConfig.OBSTACLE_BARRIER_SPEED_FACTOR
			speed_penalty_duration = GameConfig.OBSTACLE_BARRIER_SPEED_DURATION
			evolution_penalty_step = 0
		Kind.NARROW_WALL:
			penalty_kind = GameConfig.OBSTACLE_PENALTY_SPEED
			speed_penalty_factor = GameConfig.OBSTACLE_WALL_SPEED_FACTOR
			speed_penalty_duration = GameConfig.OBSTACLE_WALL_SPEED_DURATION
			evolution_penalty_step = 0
		Kind.MOVING_BLOCK:
			penalty_kind = GameConfig.OBSTACLE_PENALTY_EVOLUTION
			speed_penalty_factor = 1.0
			speed_penalty_duration = 0.0
			evolution_penalty_step = GameConfig.OBSTACLE_MOVING_EVOLUTION_STEP


# ------------------------------------------------------------------ Build ---

func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	match kind:
		Kind.CONE:
			_build_cone()
		Kind.BARRIER:
			_build_barrier()
		Kind.NARROW_WALL:
			_build_wall()
		Kind.MOVING_BLOCK:
			_build_mover()


func _build_cone() -> void:
	_body_material = _animated_material(GameConfig.COLOR_OBSTACLE_CONE, 0.62)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.045
	cone.bottom_radius = half_extents.x
	cone.height = 0.62
	cone.radial_segments = 10
	cone.rings = 1
	_visual.add_child(_mesh(cone, Vector3(0.0, 0.31, 0.0), _body_material))

	var band := CylinderMesh.new()
	band.top_radius = 0.135
	band.bottom_radius = 0.175
	band.height = 0.13
	band.radial_segments = 10
	band.rings = 1
	_visual.add_child(_mesh(
		band,
		Vector3(0.0, 0.36, 0.0),
		MaterialFactory.colored("obstacle_cone_band", GameConfig.COLOR_OBSTACLE_STRIPE, 0.55),
	))

	# Seconda fascia bianca più in alto: il cono resta leggibile anche da lontano.
	var upper_band := CylinderMesh.new()
	upper_band.top_radius = 0.075
	upper_band.bottom_radius = 0.105
	upper_band.height = 0.10
	upper_band.radial_segments = 10
	upper_band.rings = 1
	_visual.add_child(_mesh(
		upper_band,
		Vector3(0.0, 0.49, 0.0),
		MaterialFactory.colored("obstacle_cone_band", GameConfig.COLOR_OBSTACLE_STRIPE, 0.55),
	))

	var base_size := Vector3(half_extents.x * 2.0 + 0.06, 0.06, half_extents.z * 2.0 + 0.06)
	_visual.add_child(_mesh(
		_box(base_size),
		Vector3(0.0, 0.03, 0.0),
		MaterialFactory.colored("obstacle_cone_base", GameConfig.COLOR_OBSTACLE_CONE_BASE, 0.8),
	))


func _build_barrier() -> void:
	var width := half_extents.x * 2.0
	var height := half_extents.y * 2.0
	var depth := half_extents.z * 2.0
	_body_material = _animated_material(GameConfig.COLOR_OBSTACLE_BARRIER, 0.55)

	# Corpo principale: barriera rossa ben visibile.
	_visual.add_child(_mesh(
		_box(Vector3(width, height, depth)),
		Vector3(0.0, height * 0.5 + 0.12, 0.0),
		_body_material,
	))
	# Strisce bianche sulla faccia rivolta all'auto (+Z): leggibilità immediata.
	var stripe_mat := MaterialFactory.colored("obstacle_stripe", GameConfig.COLOR_OBSTACLE_STRIPE, 0.5)
	for index in 4:
		var stripe_x := (float(index) - 1.5) * width * 0.24
		_visual.add_child(_mesh(
			_box(Vector3(width * 0.16, height * 0.62, 0.04)),
			Vector3(stripe_x, height * 0.5 + 0.12, depth * 0.5 + 0.01),
			stripe_mat,
		))
	# Rail superiore bianco e piedi scuri.
	_visual.add_child(_mesh(
		_box(Vector3(width + 0.04, 0.12, depth + 0.06)),
		Vector3(0.0, height + 0.16, 0.0),
		stripe_mat,
	))
	var foot_mat := MaterialFactory.colored(
		"obstacle_dark", GameConfig.COLOR_OBSTACLE_MOVING_DARK, 0.8
	)
	for side in [-1.0, 1.0]:
		_visual.add_child(_mesh(
			_box(Vector3(0.18, 0.16, depth + 0.26)),
			Vector3(side * (width * 0.5 - 0.24), 0.06, 0.0),
			foot_mat,
		))
	# Catarifrangenti agli angoli: la barriera si vede anche in controluce.
	var reflector_mat := MaterialFactory.emissive(
		"obstacle_reflector", GameConfig.COLOR_OBSTACLE_STRIPE, 0.9
	)
	for side in [-1.0, 1.0]:
		_visual.add_child(_mesh(
			_box(Vector3(0.14, 0.14, 0.05)),
			Vector3(side * (width * 0.5 - 0.12), height + 0.06, depth * 0.5 + 0.02),
			reflector_mat,
		))


func _build_wall() -> void:
	var width := half_extents.x * 2.0
	var height := half_extents.y * 2.0
	var depth := half_extents.z * 2.0
	_body_material = _animated_material(GameConfig.COLOR_OBSTACLE_WALL, 0.75)

	# Blocco di calcestruzzo tipo "new jersey".
	_visual.add_child(_mesh(
		_box(Vector3(width, height, depth)),
		Vector3(0.0, height * 0.5, 0.0),
		_body_material,
	))
	# Strisce diagonali frontali + cappello bianco: il varco resta leggibile.
	var chevron_mat := MaterialFactory.colored(
		"obstacle_chevron", GameConfig.COLOR_OBSTACLE_WALL_CHEVRON, 0.6
	)
	for index in 3:
		var stripe := _mesh(
			_box(Vector3(width * 0.17, height * 0.62, 0.04)),
			Vector3((float(index) - 1.0) * width * 0.30, height * 0.52, depth * 0.5 + 0.01),
			chevron_mat,
		)
		stripe.rotation.z = deg_to_rad(24.0)
		_visual.add_child(stripe)
	_visual.add_child(_mesh(
		_box(Vector3(width + 0.06, 0.09, depth + 0.08)),
		Vector3(0.0, height + 0.03, 0.0),
		MaterialFactory.colored("obstacle_stripe", GameConfig.COLOR_OBSTACLE_STRIPE, 0.5),
	))
	_visual.add_child(_mesh(
		_box(Vector3(width + 0.02, 0.08, depth + 0.10)),
		Vector3(0.0, 0.04, 0.0),
		MaterialFactory.colored("obstacle_dark", GameConfig.COLOR_OBSTACLE_MOVING_DARK, 0.8),
	))


func _build_mover() -> void:
	var width := half_extents.x * 2.0
	var height := half_extents.y * 2.0
	var depth := half_extents.z * 2.0
	_body_material = _animated_material(GameConfig.COLOR_OBSTACLE_MOVING, 0.45, 0.1)
	var dark_mat := MaterialFactory.colored(
		"obstacle_dark", GameConfig.COLOR_OBSTACLE_MOVING_DARK, 0.8
	)

	# Corpo del veicolo/blocco che attraversa la pista.
	_visual.add_child(_mesh(
		_box(Vector3(width, height * 0.72, depth)),
		Vector3(0.0, 0.24 + height * 0.36, 0.0),
		_body_material,
	))
	# Cabina scura.
	_visual.add_child(_mesh(
		_box(Vector3(width * 0.56, height * 0.42, depth * 0.78)),
		Vector3(0.0, 0.24 + height * 0.72 + height * 0.21, 0.0),
		dark_mat,
	))
	# Pannello posteriore a strisce (l'auto lo vede avvicinarsi di fronte).
	var stripe_mat := MaterialFactory.colored("obstacle_stripe", GameConfig.COLOR_OBSTACLE_STRIPE, 0.5)
	var chevron_mat := MaterialFactory.colored(
		"obstacle_chevron", GameConfig.COLOR_OBSTACLE_WALL_CHEVRON, 0.6
	)
	for index in 4:
		var mat := stripe_mat if index % 2 == 0 else chevron_mat
		_visual.add_child(_mesh(
			_box(Vector3(width * 0.2, height * 0.4, 0.04)),
			Vector3(
				(float(index) - 1.5) * width * 0.22,
				0.24 + height * 0.36,
				depth * 0.5 + 0.015,
			),
			mat,
		))
	# Ruote.
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.22
	wheel.bottom_radius = 0.22
	wheel.height = 0.16
	wheel.radial_segments = 10
	wheel.rings = 1
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			var wheel_node := _mesh(
				wheel,
				Vector3(side_x * (width * 0.5 - 0.12), 0.22, side_z * (depth * 0.5 - 0.14)),
				MaterialFactory.tire(),
			)
			wheel_node.rotation.z = PI * 0.5
			_visual.add_child(wheel_node)
	# Lampeggiante ambra: segnala "ostacolo in movimento" da lontano.
	var warning_mat := MaterialFactory.emissive(
		"obstacle_mover_strip", GameConfig.COLOR_OBSTACLE_BEACON, 1.35
	)
	for face_sign in [-1.0, 1.0]:
		_visual.add_child(_mesh(
			_box(Vector3(width * 0.80, 0.07, 0.04)),
			Vector3(0.0, 0.24 + height * 0.36, face_sign * (depth * 0.5 + 0.02)),
			warning_mat,
		))

	_beacon_material = MaterialFactory.unique_emissive(GameConfig.COLOR_OBSTACLE_BEACON, 2.2)
	var beacon := CylinderMesh.new()
	beacon.top_radius = 0.07
	beacon.bottom_radius = 0.09
	beacon.height = 0.14
	beacon.radial_segments = 8
	beacon.rings = 1
	_visual.add_child(_mesh(
		beacon,
		Vector3(0.0, 0.24 + height * 0.72 + height * 0.42 + 0.07, 0.0),
		_beacon_material,
	))


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _mesh(mesh: Mesh, mesh_position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = mesh_position
	instance.material_override = material
	return instance


## Materiale del corpo, unico per pezzo e predisposto per la dissolvenza:
## le animazioni di sfondamento non possono propagarsi ad altri ostacoli.
func _animated_material(
	color: Color,
	roughness: float,
	metallic: float = 0.0,
) -> StandardMaterial3D:
	var material := MaterialFactory.unique_material(color, roughness, metallic)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# ------------------------------------------------------------- Animazioni ---

## Cono abbattuto: cade in avanti (allontanandosi dall'auto) e scivola un poco.
func _animate_cone_fall(progress: float) -> void:
	if _visual == null:
		return
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	_visual.rotation.x = -PI * 0.5 * eased
	_visual.rotation.z = _hit_dir * 0.28 * eased
	_visual.position.z = -CONE_SLIDE_DISTANCE * eased
	_visual.position.x = _hit_dir * CONE_SLIDE_DISTANCE * 0.5 * eased


## Pezzo sfondato: si ribalta all'indietro, affonda e si dissolve.
func _animate_break(progress: float) -> void:
	if _visual == null:
		return
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	_visual.rotation.x = -BREAK_TILT * eased
	_visual.position.y = -BREAK_SINK * eased
	if is_mover():
		_break_slide += MOVING_BREAK_SLIDE * eased * 0.02
		_visual.position.x = _hit_dir * _break_slide
		_visual.rotation.y = _hit_dir * MOVING_BREAK_SPIN * eased
	if _body_material != null:
		_body_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		_visual.visible = false
