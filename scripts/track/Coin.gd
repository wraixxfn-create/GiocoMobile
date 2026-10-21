class_name Coin
extends Node3D
## Moneta 3D priva di collisioni fisiche: CoinManager usa un test continuo
## di prossimità, mentre questo nodo gestisce lo stato e l'animazione raccolta.
##
## Aspetto: disco dorato lucido con anello esterno e rilievo centrale, leggero
## moto di galleggiamento e rotazione. Alla raccolta la moneta "salta", ruota
## più velocemente e lascia un'anello luminoso che si espande e svanisce:
## un feedback breve, senza particelle pesanti né luci aggiuntive.

enum State { AVAILABLE, COLLECTING, COLLECTED }

const BURST_INNER: float = 0.26
const BURST_OUTER: float = 0.38
const BURST_SCALE_START: float = 0.55
const BURST_SCALE_END: float = 1.90
const BURST_ALPHA: float = 0.85
const COLLECT_SPIN_BOOST: float = 9.0
const COLLECT_POP_SCALE: float = 0.18

var state: State = State.AVAILABLE
## Rimane true anche durante l'animazione: una seconda collisione non può
## assegnare di nuovo la stessa moneta.
var collected: bool = false
var spawn_serial: int = 0

var _base_height: float = 0.0
var _base_yaw: float = 0.0
var _phase: float = 0.0
var _spin_elapsed: float = 0.0
var _collect_elapsed: float = 0.0
var _collect_start_position: Vector3 = Vector3.ZERO
var _visual: Node3D
var _body: Node3D
var _coin_material: StandardMaterial3D = null
var _highlight_material: StandardMaterial3D = null
var _burst: MeshInstance3D = null
var _burst_material: StandardMaterial3D = null


func _ready() -> void:
	_build_visual()
	_set_rest_state()
	if state == State.AVAILABLE or state == State.COLLECTING:
		set_process(true)
	else:
		set_process(false)


## Prepara o riutilizza l'oggetto a una nuova posizione lungo la pista.
func setup(world_position: Vector3, serial: int) -> void:
	spawn_serial = serial
	global_position = world_position
	_base_height = world_position.y
	_base_yaw = 0.0
	_phase = float(serial) * 0.71
	_spin_elapsed = 0.0
	_collect_elapsed = 0.0
	_collect_start_position = Vector3.ZERO
	state = State.AVAILABLE
	collected = false
	visible = true
	scale = Vector3.ONE
	rotation = Vector3.ZERO
	if _visual != null:
		_visual.scale = Vector3.ONE
	if _body != null:
		_body.scale = Vector3.ONE
		_body.rotation = Vector3.ZERO
	_set_rest_state()
	set_process(true)


func is_available() -> bool:
	return state == State.AVAILABLE and not collected


func is_collecting() -> bool:
	return state == State.COLLECTING


## Marca atomicamente la moneta come raccolta. False significa che è già stata
## raccolta o sta già animando: il chiamante non deve assegnare altre monete.
func collect() -> bool:
	if not is_available():
		return false
	collected = true
	state = State.COLLECTING
	_collect_elapsed = 0.0
	_collect_start_position = global_position
	set_process(true)
	return true


func _process(delta: float) -> void:
	if state == State.AVAILABLE:
		_spin_elapsed += delta
		if _body != null:
			# Ruota solo il corpo: l'onda di raccolta resta ferma e frontale.
			_body.rotation.y = _base_yaw + _spin_elapsed * GameConfig.COIN_SPIN_SPEED
		var bob := sin(_spin_elapsed * GameConfig.COIN_BOB_SPEED + _phase)
		global_position.y = _base_height + bob * GameConfig.COIN_BOB_AMPLITUDE
		return

	if state != State.COLLECTING:
		set_process(false)
		return

	_collect_elapsed += delta
	var duration := maxf(GameConfig.COIN_ANIMATION_DURATION, 0.001)
	var progress := clampf(_collect_elapsed / duration, 0.0, 1.0)
	var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
	# Salto verso l'alto con una leggera "frenata" finale.
	var rise := GameConfig.COIN_ANIMATION_RISE * (1.0 - pow(1.0 - progress, 3.0))
	global_position = _collect_start_position + Vector3(0.0, rise, 0.0)
	# Gira più velocemente e si restringe: lettura immediata del pickup.
	if _body != null:
		_body.rotation.y += COLLECT_SPIN_BOOST * delta * (1.0 - progress)
	var pop := sin(minf(progress * 2.2, 1.0) * PI * 0.5)
	var scale_value := maxf(1.0 + COLLECT_POP_SCALE * pop - progress * 1.35, 0.0)
	if _body != null:
		_body.scale = Vector3.ONE * scale_value
	_animate_burst(progress)

	if progress >= 1.0:
		state = State.COLLECTED
		visible = false
		set_process(false)


## Anello che si espande a partire dalla moneta, con dissolvenza rapida.
func _animate_burst(progress: float) -> void:
	if _burst == null or _burst_material == null:
		return
	_burst.visible = true
	var burst_scale := lerpf(BURST_SCALE_START, BURST_SCALE_END, progress)
	_burst.scale = Vector3(burst_scale, 1.0, burst_scale)
	_burst_material.albedo_color.a = BURST_ALPHA * pow(1.0 - progress, 1.5)
	_burst_material.emission_energy_multiplier = 2.2 * (1.0 - progress)
	if _coin_material != null:
		_coin_material.emission_energy_multiplier = 0.22 + 1.4 * (1.0 - progress)
	if _highlight_material != null:
		_highlight_material.emission_energy_multiplier = 0.30 + 1.6 * (1.0 - progress)


func _set_rest_state() -> void:
	if _burst != null:
		_burst.visible = false
		_burst.scale = Vector3.ONE * BURST_SCALE_START
	if _burst_material != null:
		_burst_material.albedo_color.a = 0.0
	if _coin_material != null:
		_coin_material.emission_energy_multiplier = 0.22
	if _highlight_material != null:
		_highlight_material.emission_energy_multiplier = 0.30


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	# Il corpo della moneta si scala durante la raccolta; l'onda di luce resta
	# indipendente così non "collassa" insieme al disco.
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)

	_coin_material = MaterialFactory.unique_material(GameConfig.COLOR_COIN, 0.22, 0.85)
	_coin_material.emission_enabled = true
	_coin_material.emission = GameConfig.COLOR_COIN
	_coin_material.emission_energy_multiplier = 0.22

	_highlight_material = MaterialFactory.unique_material(
		GameConfig.COLOR_COIN_HIGHLIGHT, 0.18, 0.55
	)
	_highlight_material.emission_enabled = true
	_highlight_material.emission = GameConfig.COLOR_COIN_HIGHLIGHT
	_highlight_material.emission_energy_multiplier = 0.30

	# Disco principale: leggibile anche a 20 m, sempre rivolto verso la camera
	# grazie alla rotazione su Y del nodo.
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = GameConfig.COIN_RADIUS
	disc_mesh.bottom_radius = GameConfig.COIN_RADIUS
	disc_mesh.height = GameConfig.COIN_THICKNESS
	disc_mesh.radial_segments = 20
	disc_mesh.rings = 1
	var disc := MeshInstance3D.new()
	disc.name = "CoinDisc"
	disc.mesh = disc_mesh
	disc.rotation.x = PI * 0.5
	disc.material_override = _coin_material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(disc)

	# Anello esterno luminoso su entrambe le facce.
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = GameConfig.COIN_RADIUS * 0.70
	ring_mesh.outer_radius = GameConfig.COIN_RADIUS * 0.86
	ring_mesh.rings = 6
	ring_mesh.ring_segments = 18
	for face_sign in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		ring.name = "CoinRim"
		ring.mesh = ring_mesh
		ring.rotation.x = PI * 0.5
		ring.position.z = face_sign * (GameConfig.COIN_THICKNESS * 0.5 + 0.002)
		ring.material_override = _highlight_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(ring)

	# Rilievo centrale su entrambe le facce: dà spessore alla moneta.
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = GameConfig.COIN_RADIUS * 0.30
	hub_mesh.bottom_radius = GameConfig.COIN_RADIUS * 0.36
	hub_mesh.height = GameConfig.COIN_THICKNESS * 0.45
	hub_mesh.radial_segments = 8
	hub_mesh.rings = 1
	for face_sign in [-1.0, 1.0]:
		var hub := MeshInstance3D.new()
		hub.name = "CoinHub"
		hub.mesh = hub_mesh
		hub.rotation.x = PI * 0.5
		hub.position.z = face_sign * (GameConfig.COIN_THICKNESS * 0.5 + 0.012)
		hub.material_override = _highlight_material
		hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(hub)

	_build_burst()


func _build_burst() -> void:
	_burst_material = MaterialFactory.translucent(
		Color(
			GameConfig.COLOR_COIN_HIGHLIGHT.r,
			GameConfig.COLOR_COIN_HIGHLIGHT.g,
			GameConfig.COLOR_COIN_HIGHLIGHT.b,
			0.0,
		),
		2.2,
	)
	var burst_mesh := TorusMesh.new()
	burst_mesh.inner_radius = BURST_INNER
	burst_mesh.outer_radius = BURST_OUTER
	burst_mesh.rings = 6
	burst_mesh.ring_segments = 20
	_burst = MeshInstance3D.new()
	_burst.name = "PickupBurst"
	_burst.mesh = burst_mesh
	_burst.material_override = _burst_material
	_burst.rotation.x = PI * 0.5
	_burst.scale = Vector3.ONE * BURST_SCALE_START
	_burst.visible = false
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_burst)
