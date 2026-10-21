class_name Coin
extends Node3D
## Moneta 3D priva di collisioni fisiche: CoinManager usa un test continuo
## di prossimità, mentre questo nodo gestisce lo stato e l'animazione raccolta.

enum State { AVAILABLE, COLLECTING, COLLECTED }

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


func _ready() -> void:
	_build_visual()
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
	if _visual != null:
		_visual.scale = Vector3.ONE
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
		rotation.y = _base_yaw + _spin_elapsed * GameConfig.COIN_SPIN_SPEED
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
	var rise := GameConfig.COIN_ANIMATION_RISE * eased
	global_position = _collect_start_position + Vector3(0.0, rise, 0.0)
	var remaining_scale := 1.0 - progress
	scale = Vector3.ONE * remaining_scale
	if progress >= 1.0:
		state = State.COLLECTED
		visible = false
		set_process(false)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var coin_material := StandardMaterial3D.new()
	coin_material.albedo_color = GameConfig.COLOR_COIN
	coin_material.metallic = 0.72
	coin_material.roughness = 0.24
	coin_material.emission_enabled = true
	coin_material.emission = GameConfig.COLOR_COIN
	coin_material.emission_energy_multiplier = 0.18

	var highlight_material := StandardMaterial3D.new()
	highlight_material.albedo_color = GameConfig.COLOR_COIN_HIGHLIGHT
	highlight_material.metallic = 0.55
	highlight_material.roughness = 0.22
	highlight_material.emission_enabled = true
	highlight_material.emission = GameConfig.COLOR_COIN_HIGHLIGHT
	highlight_material.emission_energy_multiplier = 0.28

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = GameConfig.COIN_RADIUS
	disc_mesh.bottom_radius = GameConfig.COIN_RADIUS
	disc_mesh.height = GameConfig.COIN_THICKNESS
	disc_mesh.radial_segments = 24
	disc_mesh.rings = 1
	var disc := MeshInstance3D.new()
	disc.name = "CoinDisc"
	disc.mesh = disc_mesh
	disc.rotation.x = PI * 0.5
	disc.material_override = coin_material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(disc)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = GameConfig.COIN_RADIUS * 0.36
	ring_mesh.outer_radius = GameConfig.COIN_RADIUS * 0.57
	ring_mesh.rings = 6
	ring_mesh.ring_segments = 16
	for face_sign in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		ring.name = "CoinEmblem"
		ring.mesh = ring_mesh
		ring.rotation.x = PI * 0.5
		ring.position.z = face_sign * (GameConfig.COIN_THICKNESS * 0.5 + 0.006)
		ring.material_override = highlight_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(ring)
