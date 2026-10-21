extends Node3D
## Scena di presentazione TEMPORANEA dell'auto principale.
##
## Sfondo neutro da studio, podio, tre luci curate e telecamera orbitale
## (trascina per ruotare, rotella/pinch per zoomare; da fermo la vista
## ruota lentamente da sola). I pulsanti — o i tasti 1..6 — cambiano lo
## stadio di evoluzione mostrato, così si possono valutare tutte le
## silhouette senza avviare una partita.
##
## Non è collegata alla scena di guida e non condivide stato con il gioco:
## quando non servirà più si possono cancellare questa scena e il suo
## script senza toccare altro. Ambiente, luci e interfaccia sono costruiti
## da codice per tenere la scena ispezionabile in un unico file.

const PODIUM_TOP: float = 0.14
const TARGET := Vector3(0.0, 0.55, 0.0)
const MIN_DISTANCE: float = 3.0
const MAX_DISTANCE: float = 8.5
const MIN_PITCH: float = 0.05
const MAX_PITCH: float = 1.15
const IDLE_BEFORE_ROTATION: float = 2.5
const AUTO_ROTATION_SPEED: float = 0.35

var _yaw: float = 0.65
var _pitch: float = 0.32
var _distance: float = 5.4
var _dragging: bool = false
var _idle: float = 0.0
var _auto_rotate: bool = true
var _stage_label: Label = null

@onready var _camera: Camera3D = $Camera3D
@onready var _car: MainCarVisual = $MainCar


func _ready() -> void:
	_camera.fov = 40.0
	_car.position.y = PODIUM_TOP
	_build_environment()
	_build_lights()
	_build_floor()
	_build_ui()
	_refresh_stage_label()
	_update_camera(0.0)


func _process(delta: float) -> void:
	_idle += delta
	if _auto_rotate and _idle > IDLE_BEFORE_ROTATION:
		_yaw += AUTO_ROTATION_SPEED * delta
	_update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_distance = clampf(_distance * 0.9, MIN_DISTANCE, MAX_DISTANCE)
			_idle = 0.0
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_distance = clampf(_distance * 1.1, MIN_DISTANCE, MAX_DISTANCE)
			_idle = 0.0
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			_idle = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_orbit((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenDrag:
		_orbit((event as InputEventScreenDrag).relative)
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_distance = clampf(_distance / maxf(magnify.factor, 0.01), MIN_DISTANCE, MAX_DISTANCE)
		_idle = 0.0
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
					_set_level(GameConfig.EVOLUTION_MIN_LEVEL + (key.keycode - KEY_1))
				KEY_R:
					_auto_rotate = not _auto_rotate


func _orbit(delta_px: Vector2) -> void:
	_yaw -= delta_px.x * 0.008
	_pitch = clampf(_pitch + delta_px.y * 0.005, MIN_PITCH, MAX_PITCH)
	_idle = 0.0


func _update_camera(_delta: float) -> void:
	var offset := Vector3(
		sin(_yaw) * cos(_pitch),
		sin(_pitch),
		-cos(_yaw) * cos(_pitch),
	) * _distance
	_camera.position = TARGET + offset
	_camera.look_at(TARGET, Vector3.UP)


func _set_level(new_level: int) -> void:
	_car.set_level(clampi(
		new_level, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL
	))
	_refresh_stage_label()
	_idle = 0.0


func _refresh_stage_label() -> void:
	if _stage_label != null:
		var stage_profile := _car.profile()
		_stage_label.text = "%s · STADIO %d/%d" % [
			stage_profile.stage_name,
			_car.level - GameConfig.EVOLUTION_MIN_LEVEL + 1,
			GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL + 1,
		]


# -------------------------------------------------------------------- Scena --

## Ambiente da studio: fondo neutro chiaro, luce ambiente morbida, ACES per
## un contrasto fotografico e un accenno di bloom sulle parti emissive.
func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.bg_color = Color(0.84, 0.85, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.90, 0.92, 0.98)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_strength = 0.8
	environment.glow_bloom = 0.05
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)


## Tre luci: chiave calda con ombre morbide, riempimento freddo opposto e
## un punto luce posteriore che stacca la sagoma dal fondo.
func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	key.light_color = Color(1.0, 0.97, 0.90)
	key.light_energy = 1.15
	key.light_angular_distance = 0.6
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 30.0
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-25.0, 140.0, 0.0)
	fill.light_color = Color(0.75, 0.85, 1.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)

	var rim := OmniLight3D.new()
	rim.name = "RimLight"
	rim.position = Vector3(0.0, 3.0, 3.6)
	rim.light_color = Color(0.85, 0.92, 1.0)
	rim.light_energy = 0.5
	rim.omni_range = 10.0
	add_child(rim)


## Pavimento chiaro senza giunte e podio scuro con anello luminoso.
func _build_floor() -> void:
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.86, 0.87, 0.90)
	ground_material.roughness = 0.96
	var ground_mesh := CylinderMesh.new()
	ground_mesh.top_radius = 14.0
	ground_mesh.bottom_radius = 14.0
	ground_mesh.height = 0.1
	ground_mesh.radial_segments = 48
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ground_mesh
	ground.material_override = ground_material
	ground.position = Vector3(0.0, -0.05, 0.0)
	add_child(ground)

	var podium_material := StandardMaterial3D.new()
	podium_material.albedo_color = Color(0.15, 0.16, 0.19)
	podium_material.roughness = 0.6
	podium_material.metallic = 0.1
	var podium_mesh := CylinderMesh.new()
	podium_mesh.top_radius = 2.35
	podium_mesh.bottom_radius = 2.45
	podium_mesh.height = PODIUM_TOP
	podium_mesh.radial_segments = 48
	var podium := MeshInstance3D.new()
	podium.name = "Podium"
	podium.mesh = podium_mesh
	podium.material_override = podium_material
	podium.position = Vector3(0.0, PODIUM_TOP * 0.5, 0.0)
	add_child(podium)

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.75, 0.85, 1.0)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.75, 0.85, 1.0)
	ring_material.emission_energy_multiplier = 0.7
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.24
	ring_mesh.outer_radius = 2.30
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.name = "PodiumRing"
	ring.mesh = ring_mesh
	ring.material_override = ring_material
	ring.position = Vector3(0.0, PODIUM_TOP + 0.002, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


## Interfaccia minima da scena di sviluppo: titolo, nome dello stadio,
## pulsanti precedente/successivo e interruttore della rotazione lenta.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var title := Label.new()
	title.text = "SHOWROOM · SCENA DI PRESENTAZIONE (temporanea)"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 12.0
	title.add_theme_font_size_override("font_size", 18)
	layer.add_child(title)

	_stage_label = Label.new()
	_stage_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.offset_top = 40.0
	_stage_label.add_theme_font_size_override("font_size", 30)
	layer.add_child(_stage_label)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16.0
	bottom.offset_right = -16.0
	bottom.offset_top = -118.0
	bottom.offset_bottom = -14.0
	bottom.add_theme_constant_override("separation", 8)
	layer.add_child(bottom)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)

	var prev := Button.new()
	prev.text = "<  STADIO"
	prev.custom_minimum_size = Vector2(130.0, 46.0)
	prev.pressed.connect(func() -> void: _set_level(_car.level - 1))
	row.add_child(prev)

	var next := Button.new()
	next.text = "STADIO  >"
	next.custom_minimum_size = Vector2(130.0, 46.0)
	next.pressed.connect(func() -> void: _set_level(_car.level + 1))
	row.add_child(next)

	var toggle := CheckButton.new()
	toggle.text = "Rotazione lenta"
	toggle.button_pressed = _auto_rotate
	toggle.toggled.connect(func(on: bool) -> void: _auto_rotate = on)
	row.add_child(toggle)

	var hint := Label.new()
	hint.text = (
		"Trascina per ruotare · rotella o pinch per zoom · "
		+ "tasti 1-6 per lo stadio · R rotazione"
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	bottom.add_child(hint)
