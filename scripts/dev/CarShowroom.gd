extends Node3D
## Scena di sviluppo per l'ispezione del sistema modulare dell'auto.
##
## Consente di ruotare/zoomare attorno al veicolo, cambiare stadio evolutivo
## (pulsanti `< STADIO / STADIO >` o tasti 1..6) e sostituire in tempo reale
## i singoli componenti compatibili di ogni slot senza ricostruire l'auto.
## Non contiene alcun negozio, valuta, rarità casuale o monetizzazione.

const PODIUM_TOP: float = 0.14
const TARGET := Vector3(0.0, 0.55, 0.0)
const MIN_DISTANCE: float = 2.8
const MAX_DISTANCE: float = 8.5
const MIN_PITCH: float = 0.05
const MAX_PITCH: float = 1.15
const IDLE_BEFORE_ROTATION: float = 2.5
const AUTO_ROTATION_SPEED: float = 0.35

var _yaw: float = 0.65
var _pitch: float = 0.30
var _distance: float = 5.2
var _dragging: bool = false
var _idle: float = 0.0
var _auto_rotate: bool = true
var _stage_label: Label = null
var _stats_label: Label = null
var _slot_buttons: Dictionary = {}

@onready var _camera: Camera3D = $Camera3D
@onready var _car: MainCarVisual = $MainCar


func _ready() -> void:
	_camera.fov = 40.0
	_car.position.y = PODIUM_TOP
	_build_environment()
	_build_lights()
	_build_floor()
	_build_ui()
	_refresh_labels()
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
	_refresh_labels()
	_idle = 0.0


func _cycle_slot(slot: int) -> void:
	var rig := _car.get_rig()
	if rig == null:
		return
	var candidates := CarPartRegistry.compatible_parts_for_slot(
		slot,
		rig.get_equipped_part(CarPartSlot.Type.BODY),
		rig.get_sockets(),
		rig.equipped_parts(),
	)
	if candidates.is_empty():
		return
	var current_id := rig.get_equipped_part_id(slot)
	var next_idx := 0
	for i in candidates.size():
		if candidates[i].id == current_id:
			next_idx = (i + 1) % candidates.size()
			break
	_car.equip_part(candidates[next_idx], false)
	_refresh_labels()
	_idle = 0.0


func _refresh_labels() -> void:
	if _stage_label != null:
		var stage_profile := _car.profile()
		_stage_label.text = "%s · STADIO %d/%d" % [
			stage_profile.stage_name,
			_car.level - GameConfig.EVOLUTION_MIN_LEVEL + 1,
			GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL + 1,
		]
	var rig := _car.get_rig()
	if rig != null and _stats_label != null:
		var stats := rig.effective_stats()
		_stats_label.text = "VEL ×%.2f   STERZO ×%.2f   INGOMBRO %.2f×%.2f m" % [
			float(stats["speed_multiplier"]),
			float(stats["handling_multiplier"]),
			float(stats["half_width"]) * 2.0,
			float(stats["half_length"]) * 2.0,
		]
	for slot in _slot_buttons.keys():
		var btn := _slot_buttons[slot] as Button
		var part := rig.get_equipped_part(int(slot)) if rig != null else null
		if btn != null:
			btn.text = "%s: %s" % [
				CarPartSlot.label_it(int(slot)),
				part.display_name if part != null else "-",
			]


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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var title := Label.new()
	title.text = "SHOWROOM TECNICO · TEST COMPONENTI MODULARI"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 10.0
	title.add_theme_font_size_override("font_size", 16)
	layer.add_child(title)

	_stage_label = Label.new()
	_stage_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.offset_top = 34.0
	_stage_label.add_theme_font_size_override("font_size", 26)
	layer.add_child(_stage_label)

	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.offset_top = 68.0
	_stats_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(_stats_label)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12.0
	bottom.offset_right = -12.0
	bottom.offset_top = -270.0
	bottom.offset_bottom = -12.0
	bottom.add_theme_constant_override("separation", 6)
	layer.add_child(bottom)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	bottom.add_child(grid)

	for slot in CarPartSlot.ATTACHED:
		var slot_btn := Button.new()
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.custom_minimum_size = Vector2(0.0, 34.0)
		slot_btn.add_theme_font_size_override("font_size", 12)
		var captured_slot := slot
		slot_btn.pressed.connect(func() -> void: _cycle_slot(captured_slot))
		grid.add_child(slot_btn)
		_slot_buttons[slot] = slot_btn

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	bottom.add_child(row)

	var prev := Button.new()
	prev.text = "< STADIO"
	prev.custom_minimum_size = Vector2(124.0, 42.0)
	prev.pressed.connect(func() -> void: _set_level(_car.level - 1))
	row.add_child(prev)

	var next := Button.new()
	next.text = "STADIO >"
	next.custom_minimum_size = Vector2(124.0, 42.0)
	next.pressed.connect(func() -> void: _set_level(_car.level + 1))
	row.add_child(next)

	var toggle := CheckButton.new()
	toggle.text = "Rotazione"
	toggle.button_pressed = _auto_rotate
	toggle.toggled.connect(func(on: bool) -> void: _auto_rotate = on)
	row.add_child(toggle)
