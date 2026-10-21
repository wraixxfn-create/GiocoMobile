class_name HUD
extends CanvasLayer
## Interfaccia touch-first: menu, HUD, countdown, pausa e riepilogo.
## Tutti i pannelli sono ancorati al viewport verticale e i pulsanti hanno
## un'altezza ampia, adatta all'uso con un dito.

signal play_requested
signal replay_requested
signal menu_requested
signal pause_requested
signal resume_requested

const FEEDBACK_DURATION: float = 1.4
const FEEDBACK_FADE: float = 0.5
const STAGE_POP_DURATION: float = 0.6
const STAGE_POP_SCALE: float = 0.35
const COIN_POP_DURATION: float = 0.24
const COIN_POP_SCALE: float = 0.28
const COLLISION_FLASH_DURATION: float = 0.30
const COLLISION_FLASH_ALPHA: float = 0.30
const COLLISION_FLASH_COLOR := Color(0.95, 0.22, 0.14)
const COLOR_FEEDBACK_SPEED := Color(0.98, 0.55, 0.15)

var _ui_root: Control
var _status_panel: PanelContainer
var _distance_label: Label
var _coins_label: Label
var _permanent_coins_label: Label
var _evolution_label: Label
var _progress_bar: ProgressBar
var _pause_button: Button
var _stage_label: Label
var _stats_label: Label
var _hint_label: Label
var _feedback_label: Label
var _collision_flash: ColorRect
var _menu_overlay: Control
var _menu_balance_label: Label
var _countdown_overlay: Control
var _countdown_label: Label
var _pause_overlay: Control
var _results_overlay: Control
var _results_panel: PanelContainer
var _results_title: Label
var _results_label: Label
var _displayed_distance: int = 0
var _displayed_coins: int = 0
var _displayed_permanent_coins: int = 0
var _goal_distance: float = GameConfig.RUN_DISTANCE_METERS
var _feedback_time: float = 0.0
var _stage_pop_time: float = 0.0
var _coin_pop_time: float = 0.0
var _flash_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	set_distance(0)
	set_coins(0)
	set_permanent_coins(0)
	set_state(GameManager.State.IDLE)
	set_evolution(
		GameConfig.EVOLUTION_START_LEVEL,
		0,
		CarEvolutionCatalog.profile_for(GameConfig.EVOLUTION_START_LEVEL),
	)


func _build_interface() -> void:
	_ui_root = Control.new()
	_ui_root.name = "Interface"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_collision_flash = ColorRect.new()
	_collision_flash.name = "CollisionFlash"
	_collision_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collision_flash.color = Color(
		COLLISION_FLASH_COLOR.r,
		COLLISION_FLASH_COLOR.g,
		COLLISION_FLASH_COLOR.b,
		0.0,
	)
	_collision_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collision_flash.visible = false
	_ui_root.add_child(_collision_flash)

	_build_game_hud()
	_build_menu_overlay()
	_build_countdown_overlay()
	_build_pause_overlay()
	_build_results_overlay()


func _build_game_hud() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.name = "RaceStatus"
	_set_anchors(_status_panel, 0.025, 0.014, 0.785, 0.145)
	_status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.075, 0.84)))
	_ui_root.add_child(_status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	_status_panel.add_child(margin)
	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 3)
	margin.add_child(status_stack)

	var first_row := HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 8)
	status_stack.add_child(first_row)
	_distance_label = _create_label("DISTANZA 0/800 m", 18, HORIZONTAL_ALIGNMENT_LEFT)
	_distance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first_row.add_child(_distance_label)
	_coins_label = _create_label("MONETE 0", 17, HORIZONTAL_ALIGNMENT_RIGHT)
	_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first_row.add_child(_coins_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "RaceProgress"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = _goal_distance
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 8.0)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_theme_stylebox_override("background", _progress_style(Color(0.10, 0.14, 0.20, 0.92)))
	_progress_bar.add_theme_stylebox_override("fill", _progress_style(Color(0.19, 0.86, 0.49, 1.0)))
	status_stack.add_child(_progress_bar)

	var second_row := HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 8)
	status_stack.add_child(second_row)
	_evolution_label = _create_label("EVOLUZIONE 1/5", 15, HORIZONTAL_ALIGNMENT_LEFT)
	_evolution_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_row.add_child(_evolution_label)
	_permanent_coins_label = _create_label("SALDO 0", 15, HORIZONTAL_ALIGNMENT_RIGHT)
	_permanent_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_row.add_child(_permanent_coins_label)

	_pause_button = _create_button("PAUSA", false)
	_pause_button.name = "PauseButton"
	_pause_button.add_theme_font_size_override("font_size", 17)
	_pause_button.custom_minimum_size = Vector2(88.0, 62.0)
	_set_anchors(_pause_button, 0.805, 0.020, 0.975, 0.092)
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_ui_root.add_child(_pause_button)

	_stage_label = _create_label("UTILITARIA", 32, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_stage_label, 0.035, 0.166, 0.965, 0.218)
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_label.resized.connect(_center_stage_pivot)
	_ui_root.add_child(_stage_label)

	_stats_label = _create_label("", 16, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_stats_label, 0.04, 0.218, 0.96, 0.254)
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_root.add_child(_stats_label)

	_feedback_label = _create_label("", 34, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_feedback_label, 0.03, 0.32, 0.97, 0.39)
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.visible = false
	_ui_root.add_child(_feedback_label)

	_hint_label = _create_label("TRASCINA PER STERZARE", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_hint_label, 0.04, 0.91, 0.96, 0.97)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	_ui_root.add_child(_hint_label)


func _build_menu_overlay() -> void:
	_menu_overlay = _make_overlay("MainMenu", Color(0.025, 0.06, 0.11, 0.43))
	var panel := PanelContainer.new()
	panel.name = "MenuCard"
	_set_anchors(panel, 0.07, 0.145, 0.93, 0.855)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.105, 0.97), true))
	_menu_overlay.add_child(panel)
	var stack := _panel_stack(panel, 26, 14, 26, 14, 10)

	var title := _create_label("CAR EVOLVE", 43, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size = Vector2(0.0, 70.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _create_label("CORSA 3D", 20, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0))
	stack.add_child(subtitle)
	var strapline := _create_label("EVOLVI L'AUTO. SCHIVA GLI OSTACOLI.\nRAGGIUNGI IL TRAGUARDO!", 16, HORIZONTAL_ALIGNMENT_CENTER)
	strapline.custom_minimum_size = Vector2(0.0, 54.0)
	strapline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(strapline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 12.0)
	stack.add_child(spacer)
	_menu_balance_label = _create_label("SALDO MONETE\n0", 27, HORIZONTAL_ALIGNMENT_CENTER)
	_menu_balance_label.custom_minimum_size = Vector2(0.0, 72.0)
	_menu_balance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_menu_balance_label.add_theme_color_override("font_color", Color(1.0, 0.79, 0.22))
	stack.add_child(_menu_balance_label)

	var play_button := _create_button("GIOCA", true)
	play_button.name = "PlayButton"
	play_button.custom_minimum_size = Vector2(0.0, 82.0)
	play_button.pressed.connect(func() -> void: play_requested.emit())
	stack.add_child(play_button)
	var instructions := _create_label("TOCCA GIOCA, POI TRASCINA IL DITO\nA DESTRA O SINISTRA PER STERZARE", 15, HORIZONTAL_ALIGNMENT_CENTER)
	instructions.custom_minimum_size = Vector2(0.0, 52.0)
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(instructions)


func _build_countdown_overlay() -> void:
	_countdown_overlay = _make_overlay("Countdown", Color(0.015, 0.035, 0.07, 0.28))
	var heading := _create_label("PREPARATI", 23, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(heading, 0.08, 0.35, 0.92, 0.42)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_overlay.add_child(heading)
	_countdown_label = _create_label("3", 96, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_countdown_label, 0.08, 0.40, 0.92, 0.57)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.24))
	_countdown_overlay.add_child(_countdown_label)


func _build_pause_overlay() -> void:
	_pause_overlay = _make_overlay("PauseScreen", Color(0.008, 0.02, 0.045, 0.70))
	var panel := PanelContainer.new()
	panel.name = "PauseCard"
	_set_anchors(panel, 0.09, 0.28, 0.91, 0.72)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.105, 0.99), true))
	_pause_overlay.add_child(panel)
	var stack := _panel_stack(panel, 25, 18, 25, 18, 16)
	var title := _create_label("PAUSA", 38, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size = Vector2(0.0, 72.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var resume_button := _create_button("RIPRENDI", true)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	stack.add_child(resume_button)
	var menu_button := _create_button("MENU", false)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	stack.add_child(menu_button)


func _build_results_overlay() -> void:
	_results_overlay = _make_overlay("RunResults", Color(0.008, 0.02, 0.045, 0.78))
	_results_panel = PanelContainer.new()
	_results_panel.name = "ResultsCard"
	_set_anchors(_results_panel, 0.075, 0.13, 0.925, 0.87)
	_results_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.105, 0.99), true))
	_results_overlay.add_child(_results_panel)
	var stack := _panel_stack(_results_panel, 25, 16, 25, 16, 10)

	_results_title = _create_label("TRAGUARDO!", 34, HORIZONTAL_ALIGNMENT_CENTER)
	_results_title.custom_minimum_size = Vector2(0.0, 68.0)
	_results_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_results_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.66))
	stack.add_child(_results_title)
	var divider := ColorRect.new()
	divider.color = Color(0.32, 0.53, 0.72, 0.8)
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(divider)
	_results_label = _create_label("", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_results_label.custom_minimum_size = Vector2(0.0, 275.0)
	_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(_results_label)
	var replay_button := _create_button("RIGIOCA", true)
	replay_button.name = "ReplayButton"
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	stack.add_child(replay_button)
	var menu_button := _create_button("MENU", false)
	menu_button.name = "ResultsMenuButton"
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	stack.add_child(menu_button)


func _make_overlay(node_name: String, scrim_color: Color) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	_ui_root.add_child(overlay)
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = scrim_color
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(scrim)
	return overlay


func _panel_stack(
	panel: PanelContainer,
	left: int,
	top: int,
	right: int,
	bottom: int,
	separation: int,
) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", separation)
	margin.add_child(stack)
	return stack


func _set_anchors(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func set_goal_distance(goal: float) -> void:
	_goal_distance = maxf(goal, 1.0)
	if _progress_bar != null:
		_progress_bar.max_value = _goal_distance
	set_distance(_displayed_distance)


func set_distance(meters: int) -> void:
	_displayed_distance = maxi(meters, 0)
	if _distance_label != null:
		_distance_label.text = "DISTANZA %d/%d m" % [_displayed_distance, roundi(_goal_distance)]
	if _progress_bar != null:
		_progress_bar.value = minf(float(_displayed_distance), _goal_distance)


## Totale raccolto nella corsa corrente, distinto dal saldo permanente.
func set_coins(amount: int) -> void:
	_displayed_coins = maxi(amount, 0)
	if _coins_label != null:
		_coins_label.text = "MONETE %d" % _displayed_coins


func set_permanent_coins(amount: int) -> void:
	_displayed_permanent_coins = maxi(amount, 0)
	if _permanent_coins_label != null:
		_permanent_coins_label.text = "SALDO %d" % _displayed_permanent_coins
	if _menu_balance_label != null:
		_menu_balance_label.text = "SALDO MONETE\n%d" % _displayed_permanent_coins


func set_countdown(seconds_left: int) -> void:
	if _countdown_label == null:
		return
	_countdown_label.text = "VIA!" if seconds_left <= 0 else str(seconds_left)


func play_coin_pickup_animation(_run_total: int) -> void:
	_coin_pop_time = COIN_POP_DURATION


func displayed_distance() -> int:
	return _displayed_distance


func displayed_coins() -> int:
	return _displayed_coins


func displayed_permanent_coins() -> int:
	return _displayed_permanent_coins


func results_visible() -> bool:
	return _results_overlay != null and _results_overlay.visible


func results_text() -> String:
	return _results_label.text if _results_label != null else ""


## Riepilogo congelato: esito, punti, distanza, monete e stadio raggiunto.
func show_run_results(
	final_score: int,
	distance_meters: int,
	max_level: int,
	coins: int,
	final_level: int,
	outcome: GameManager.Outcome,
) -> void:
	if outcome == GameManager.Outcome.VICTORY:
		_results_title.text = "VITTORIA!"
		_results_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.66))
	else:
		_results_title.text = "SCONFITTA"
		_results_title.add_theme_color_override("font_color", Color(1.0, 0.64, 0.42))
	_results_label.text = "\n".join(PackedStringArray([
		"PUNTEGGIO %d" % final_score,
		"DISTANZA %d m" % distance_meters,
		"MONETE RACCOLTE %d" % coins,
		"LIVELLO AUTO %d/%d" % [final_level, GameConfig.EVOLUTION_MAX_LEVEL],
		"PICCO EVOLUZIONE %d/%d" % [max_level, GameConfig.EVOLUTION_MAX_LEVEL],
		"SALDO PERMANENTE %d" % _displayed_permanent_coins,
	]))


func set_evolution(level: int, delta: int, profile: CarEvolutionProfile = null) -> void:
	if _evolution_label == null or _stage_label == null or _stats_label == null:
		return
	_evolution_label.text = "EVOLUZIONE %d/%d" % [level, GameConfig.EVOLUTION_MAX_LEVEL]
	_evolution_label.label_settings.font_color = _level_color(level).lightened(0.22)
	if profile == null:
		return
	_stage_label.text = profile.stage_name
	_stage_label.label_settings.font_color = profile.body_color.lightened(0.35)
	_stats_label.text = profile.stats_text()
	if delta != 0:
		_stage_pop_time = STAGE_POP_DURATION


func set_state(state: GameManager.State) -> void:
	if _ui_root == null:
		return
	_menu_overlay.visible = state == GameManager.State.IDLE
	_status_panel.visible = state != GameManager.State.IDLE
	_pause_button.visible = state == GameManager.State.PLAYING
	_countdown_overlay.visible = state == GameManager.State.COUNTDOWN
	_pause_overlay.visible = state == GameManager.State.PAUSED
	_results_overlay.visible = state == GameManager.State.FINISHED
	_hint_label.visible = state == GameManager.State.PLAYING

	match state:
		GameManager.State.IDLE:
			_hint_label.text = ""
			_feedback_label.visible = false
			_feedback_time = 0.0
			_flash_time = 0.0
			_collision_flash.visible = false
		GameManager.State.COUNTDOWN:
			_hint_label.text = ""
			_feedback_label.visible = false
		GameManager.State.PLAYING:
			_hint_label.text = "TRASCINA PER STERZARE"
		GameManager.State.PAUSED:
			_feedback_label.visible = false
		GameManager.State.FINISHED:
			_hint_label.visible = false
			_feedback_label.visible = false

	_stage_label.visible = state != GameManager.State.IDLE
	_stats_label.visible = state != GameManager.State.IDLE


func show_gate_feedback(requested_value: int, applied_delta: int, _level: int) -> void:
	var text := ""
	var color := Color.WHITE
	if applied_delta > 0:
		text = "+%d EVOLUZIONE" % applied_delta
		color = GameConfig.COLOR_GATE_POSITIVE
	elif applied_delta < 0:
		text = "%d REGRESSIONE" % applied_delta
		color = GameConfig.COLOR_GATE_NEGATIVE
	elif requested_value > 0:
		text = "LIVELLO MASSIMO"
		color = GameConfig.COLOR_GATE_POSITIVE_STRONG
	else:
		text = "LIVELLO MINIMO"
		color = GameConfig.COLOR_GATE_NEGATIVE
	_set_feedback(text, color)


func show_obstacle_feedback(penalty_kind: int, evolution_delta: int) -> void:
	var text := ""
	var color := COLOR_FEEDBACK_SPEED
	if penalty_kind == GameConfig.OBSTACLE_PENALTY_EVOLUTION:
		color = GameConfig.COLOR_GATE_NEGATIVE
		if evolution_delta < 0:
			text = "URTO! %d EVOLUZIONE" % evolution_delta
		else:
			text = "URTO! LIVELLO GIÀ MINIMO"
	else:
		text = "URTO! VELOCITÀ RIDOTTA"
	_set_feedback(text, color)
	_collision_flash.visible = true
	_flash_time = COLLISION_FLASH_DURATION


func collision_flash_active() -> bool:
	return _flash_time > 0.0


func _set_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.label_settings.font_color = color.lightened(0.2)
	_feedback_label.modulate = Color.WHITE
	_feedback_label.visible = true
	_feedback_time = FEEDBACK_DURATION


func _process(delta: float) -> void:
	if _feedback_time > 0.0:
		_feedback_time = maxf(_feedback_time - delta, 0.0)
		if _feedback_time <= FEEDBACK_FADE:
			_feedback_label.modulate.a = _feedback_time / FEEDBACK_FADE
		if _feedback_time <= 0.0:
			_feedback_label.visible = false

	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time - delta, 0.0)
		var fade := _flash_time / COLLISION_FLASH_DURATION
		_collision_flash.color.a = COLLISION_FLASH_ALPHA * fade * fade
		if _flash_time <= 0.0:
			_collision_flash.visible = false
			_collision_flash.color.a = 0.0

	if _stage_pop_time > 0.0:
		_stage_pop_time = maxf(_stage_pop_time - delta, 0.0)
		var progress := 1.0 - (_stage_pop_time / STAGE_POP_DURATION)
		var scale_value := 1.0 + STAGE_POP_SCALE * (1.0 - progress)
		_stage_label.scale = Vector2(scale_value, scale_value)
		if _stage_pop_time <= 0.0:
			_stage_label.scale = Vector2.ONE
	elif _stage_label.scale != Vector2.ONE:
		_stage_label.scale = Vector2.ONE

	if _coin_pop_time > 0.0:
		_coin_pop_time = maxf(_coin_pop_time - delta, 0.0)
		var coin_progress := 1.0 - (_coin_pop_time / COIN_POP_DURATION)
		var coin_scale := 1.0 + COIN_POP_SCALE * sin(coin_progress * PI)
		_coins_label.scale = Vector2(coin_scale, coin_scale)
		if _coin_pop_time <= 0.0:
			_coins_label.scale = Vector2.ONE
	elif _coins_label.scale != Vector2.ONE:
		_coins_label.scale = Vector2.ONE


func _center_stage_pivot() -> void:
	if _stage_label != null:
		_stage_label.pivot_offset = _stage_label.size * 0.5


func _level_color(level: int) -> Color:
	var index := clampi(level, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
	return GameConfig.EVOLUTION_COLORS[index]


func _create_label(text: String, font_size: int, alignment: int) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color.WHITE
	settings.outline_size = 5
	settings.outline_color = Color(0.04, 0.07, 0.11, 0.95)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	settings.shadow_offset = Vector2(1.0, 2.0)

	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _create_button(text: String, accent: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color(0.035, 0.07, 0.105))
	button.add_theme_color_override("font_hover_color", Color(0.02, 0.05, 0.08))
	button.add_theme_color_override("font_pressed_color", Color(0.02, 0.05, 0.08))
	var base := Color(0.27, 0.90, 0.53) if accent else Color(0.78, 0.86, 0.94)
	button.add_theme_stylebox_override("normal", _button_style(base))
	button.add_theme_stylebox_override("hover", _button_style(base.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.12)))
	button.add_theme_stylebox_override("focus", _button_style(base.lightened(0.05), true))
	return button


func _button_style(color: Color, focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	if focused:
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color.WHITE
	return style


func _panel_style(color: Color, accent_border: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.32, 0.63, 0.82, 0.8) if accent_border else Color(0.6, 0.77, 0.9, 0.58)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
