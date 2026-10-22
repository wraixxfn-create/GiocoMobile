class_name HUD
extends CanvasLayer
## Interfaccia touch-first: menu, HUD di corsa, countdown, pausa e riepilogo.
##
## HUD di corsa compatto: lascia la scena 3D libera, con stato e comandi
## confinati in una barra leggera nella fascia alta. I messaggi di feedback
## sono brevi e locali; le animazioni non usano rimbalzi né lampi a schermo.
## Menu, pausa e riepilogo mantengono controlli touch ampi.

signal play_requested
signal replay_requested
signal menu_requested
signal pause_requested
signal resume_requested
## Richiesta di attivare/disattivare l'audio (gestita da GameRoot/SfxDirector).
signal audio_toggle_requested

const FEEDBACK_DURATION: float = 1.15
const FEEDBACK_FADE: float = 0.32
const COIN_POP_DURATION: float = 0.20
const COIN_POP_SCALE: float = 0.045
const COLLISION_FEEDBACK_DURATION: float = 0.22
const COLOR_FEEDBACK_SPEED := Color(0.98, 0.58, 0.16)
const PILL_ALPHA: float = 0.16
const PIPS_COUNT: int = GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL + 1
const HINT_DURATION: float = 3.5

var _ui_root: Control
var _status_panel: PanelContainer
var _distance_label: Label
var _coins_label: Label
var _permanent_coins_label: Label
var _evolution_label: Label
var _progress_bar: ProgressBar
var _pause_button: Button
var _audio_button: Button
var _stage_label: Label
var _stats_label: Label
var _hint_label: Label
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _feedback_style: StyleBoxFlat
var _pip_nodes: Array[TextureRect] = []
var _menu_overlay: Control
var _menu_card: PanelContainer
var _menu_balance_label: Label
var _menu_audio_button: Button
var _countdown_overlay: Control
var _countdown_card: Control
var _countdown_label: Label
var _pause_overlay: Control
var _pause_card: PanelContainer
var _pause_audio_button: Button
var _results_overlay: Control
var _results_panel: PanelContainer
var _results_title: Label
var _results_score_label: Label
var _results_label: Label
var _displayed_distance: int = 0
var _displayed_coins: int = 0
var _displayed_permanent_coins: int = 0
var _goal_distance: float = GameConfig.RUN_DISTANCE_METERS
var _feedback_time: float = 0.0
var _coin_pop_time: float = 0.0
var _collision_feedback_time: float = 0.0
var _hint_time_left: float = 0.0
## Stato precedente: serve a capire quando animare la comparsa di un pannello.
var _last_state: GameManager.State = GameManager.State.FINISHED
var _last_countdown_text: String = ""
var _audio_muted: bool = false


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
	set_audio_muted(false)


# ------------------------------------------------------------------ Build ---

func _build_interface() -> void:
	_ui_root = Control.new()
	_ui_root.name = "Interface"
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_root)

	_build_game_hud()
	_build_menu_overlay()
	_build_countdown_overlay()
	_build_pause_overlay()
	_build_results_overlay()


func _build_game_hud() -> void:
	# Una sola barra compatta: lo spazio centrale resta dedicato alla pista.
	_status_panel = PanelContainer.new()
	_status_panel.name = "RaceStatus"
	_set_anchors(_status_panel, 0.025, 0.012, 0.725, 0.102)
	_status_panel.add_theme_stylebox_override(
		"panel",
		UITheme.panel_style(Color(0.025, 0.045, 0.075, 0.78), false, 15),
	)
	_ui_root.add_child(_status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	_status_panel.add_child(margin)
	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 2)
	margin.add_child(status_stack)

	var first_row := HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 7)
	status_stack.add_child(first_row)
	_distance_label = UITheme.label("0 m / 800 m", 15, HORIZONTAL_ALIGNMENT_LEFT)
	_distance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_distance_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	first_row.add_child(_distance_label)

	var coin_chip := HBoxContainer.new()
	coin_chip.add_theme_constant_override("separation", 4)
	coin_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	first_row.add_child(coin_chip)
	var coin_icon := UITheme.icon(UITheme.coin_texture(), Vector2(16.0, 16.0))
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_chip.add_child(coin_icon)
	_coins_label = UITheme.label("0", 15, HORIZONTAL_ALIGNMENT_RIGHT)
	_coins_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_GOLD)
	_coins_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	coin_chip.add_child(_coins_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "RaceProgress"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = _goal_distance
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 4.0)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_theme_stylebox_override(
		"background",
		UITheme.progress_style(Color(0.09, 0.13, 0.19, 0.90)),
	)
	_progress_bar.add_theme_stylebox_override(
		"fill",
		UITheme.progress_style(GameConfig.COLOR_UI_ACCENT),
	)
	status_stack.add_child(_progress_bar)

	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 6)
	_stage_label = UITheme.label("UTILITARIA", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_row.add_child(_stage_label)
	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 3)
	pip_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	stage_row.add_child(pip_row)
	var pip_texture := UITheme.circle_texture()
	for _index in PIPS_COUNT:
		var pip := UITheme.icon(pip_texture, Vector2(7.0, 7.0))
		pip_row.add_child(pip)
		_pip_nodes.append(pip)
	_evolution_label = UITheme.label("1/5", 10, HORIZONTAL_ALIGNMENT_RIGHT)
	_evolution_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	_evolution_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	stage_row.add_child(_evolution_label)
	status_stack.add_child(stage_row)

	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 6)
	_stats_label = UITheme.label("VEL ×1.00 · STERZO ×1.00", 9, HORIZONTAL_ALIGNMENT_LEFT)
	_stats_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_child(_stats_label)
	_permanent_coins_label = UITheme.label("SALDO 0", 9, HORIZONTAL_ALIGNMENT_RIGHT)
	_permanent_coins_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	_permanent_coins_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	detail_row.add_child(_permanent_coins_label)
	status_stack.add_child(detail_row)

	# Controlli touch compatti e scuri, in alto a destra.
	_pause_button = _make_button("PAUSA", false)
	_pause_button.name = "PauseButton"
	_pause_button.custom_minimum_size = Vector2(0.0, 52.0)
	_pause_button.add_theme_font_size_override("font_size", 11)
	for color_override in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
	]:
		_pause_button.add_theme_color_override(color_override, GameConfig.COLOR_UI_TEXT)
	UITheme.apply_button_color(_pause_button, Color(0.035, 0.07, 0.105, 0.82))
	_pause_button.tooltip_text = "Metti in pausa"
	_set_anchors(_pause_button, 0.750, 0.025, 0.865, 0.082)
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_ui_root.add_child(_pause_button)

	_audio_button = _make_button("SFX", false)
	_audio_button.name = "AudioButton"
	_audio_button.custom_minimum_size = Vector2(0.0, 52.0)
	_audio_button.add_theme_font_size_override("font_size", 10)
	for color_override in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
	]:
		_audio_button.add_theme_color_override(color_override, GameConfig.COLOR_UI_TEXT)
	UITheme.apply_button_color(_audio_button, Color(0.035, 0.07, 0.105, 0.82))
	_audio_button.tooltip_text = "Attiva o disattiva i suoni"
	_set_anchors(_audio_button, 0.875, 0.025, 0.985, 0.082)
	_audio_button.pressed.connect(_request_audio_toggle)
	_ui_root.add_child(_audio_button)

	# Feedback piccolo e sopra la linea dell'orizzonte, non al centro dell'azione.
	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "FeedbackPill"
	_set_anchors(_feedback_panel, 0.17, 0.116, 0.83, 0.164)
	_feedback_style = UITheme.panel_style(Color(0.05, 0.08, 0.12, 0.82), false, 15)
	_feedback_panel.add_theme_stylebox_override("panel", _feedback_style)
	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_panel.visible = false
	_ui_root.add_child(_feedback_panel)
	var feedback_margin := MarginContainer.new()
	feedback_margin.add_theme_constant_override("margin_left", 8)
	feedback_margin.add_theme_constant_override("margin_right", 8)
	_feedback_panel.add_child(feedback_margin)
	_feedback_label = UITheme.label("", 17, HORIZONTAL_ALIGNMENT_CENTER)
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_margin.add_child(_feedback_label)

	_hint_label = UITheme.label("TRASCINA PER STERZARE", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.78))
	_set_anchors(_hint_label, 0.08, 0.955, 0.92, 0.988)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	_ui_root.add_child(_hint_label)


func _build_menu_overlay() -> void:
	_menu_overlay = _make_overlay("MainMenu", Color(0.02, 0.05, 0.10, 0.50))
	_menu_card = PanelContainer.new()
	_menu_card.name = "MenuCard"
	_set_anchors(_menu_card, 0.065, 0.115, 0.935, 0.885)
	_menu_card.add_theme_stylebox_override(
		"panel",
		UITheme.panel_style(Color(0.035, 0.065, 0.105, 0.97), true, 28),
	)
	_menu_overlay.add_child(_menu_card)
	var stack := _panel_stack(_menu_card, 26, 20, 26, 20, 10)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := UITheme.label("CAR EVOLVE", 44, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size = Vector2(0.0, 62.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(title)

	# Striscia a scacchiera: firma visiva del gioco, nessun asset esterno.
	var checkers := TextureRect.new()
	checkers.name = "TitleCheckers"
	checkers.texture = MaterialFactory.checker_texture(14, 4)
	checkers.custom_minimum_size = Vector2(0.0, 12.0)
	checkers.stretch_mode = TextureRect.STRETCH_TILE
	checkers.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	checkers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(checkers)

	var subtitle := UITheme.label("CORSA 3D", 19, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.add_theme_color_override("font_color", Color(0.52, 0.84, 1.0))
	stack.add_child(subtitle)
	var strapline := UITheme.label(
		"EVOLVI L'AUTO. SCHIVA GLI OSTACOLI.\nRAGGIUNGI IL TRAGUARDO!",
		15,
		HORIZONTAL_ALIGNMENT_CENTER,
	)
	strapline.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	strapline.custom_minimum_size = Vector2(0.0, 48.0)
	strapline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(strapline)

	stack.add_child(UITheme.spacer(6.0))
	var balance_pill := PanelContainer.new()
	balance_pill.name = "BalancePill"
	balance_pill.add_theme_stylebox_override(
		"panel",
		UITheme.panel_style(Color(0.10, 0.09, 0.04, 0.92), false, 20),
	)
	balance_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(balance_pill)
	var balance_margin := MarginContainer.new()
	balance_margin.add_theme_constant_override("margin_left", 16)
	balance_margin.add_theme_constant_override("margin_right", 16)
	balance_margin.add_theme_constant_override("margin_top", 8)
	balance_margin.add_theme_constant_override("margin_bottom", 8)
	balance_pill.add_child(balance_margin)
	var balance_row := HBoxContainer.new()
	balance_row.add_theme_constant_override("separation", 8)
	balance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_margin.add_child(balance_row)
	var balance_icon := UITheme.icon(UITheme.coin_texture(), Vector2(24.0, 24.0))
	balance_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_row.add_child(balance_icon)
	_menu_balance_label = UITheme.label("SALDO 0", 22, HORIZONTAL_ALIGNMENT_CENTER)
	_menu_balance_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_GOLD)
	_menu_balance_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	balance_row.add_child(_menu_balance_label)

	stack.add_child(UITheme.spacer(6.0))
	var play_button := _make_button("GIOCA", true)
	play_button.name = "PlayButton"
	play_button.custom_minimum_size = Vector2(0.0, 84.0)
	play_button.pressed.connect(func() -> void: play_requested.emit())
	stack.add_child(play_button)

	var instructions := UITheme.label(
		"TOCCA GIOCA, POI TRASCINA IL DITO\nA DESTRA O SINISTRA PER STERZARE",
		14,
		HORIZONTAL_ALIGNMENT_CENTER,
	)
	instructions.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	instructions.custom_minimum_size = Vector2(0.0, 46.0)
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(instructions)

	_menu_audio_button = _make_button("AUDIO ON", false)
	_menu_audio_button.name = "MenuAudioButton"
	_menu_audio_button.add_theme_font_size_override("font_size", 15)
	_menu_audio_button.custom_minimum_size = Vector2(0.0, 52.0)
	_menu_audio_button.pressed.connect(_request_audio_toggle)
	stack.add_child(_menu_audio_button)


func _build_countdown_overlay() -> void:
	_countdown_overlay = _make_overlay("Countdown", Color(0.015, 0.035, 0.07, 0.26))
	_countdown_card = Control.new()
	_countdown_card.name = "CountdownCard"
	_set_anchors(_countdown_card, 0.08, 0.32, 0.92, 0.58)
	_countdown_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_overlay.add_child(_countdown_card)

	var heading := UITheme.label("PREPARATI", 22, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(heading, 0.0, 0.0, 1.0, 0.24)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_card.add_child(heading)
	_countdown_label = UITheme.label("3", 104, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_countdown_label, 0.0, 0.22, 1.0, 1.0)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	_countdown_label.resized.connect(_center_countdown_pivot)
	_countdown_card.add_child(_countdown_label)


func _build_pause_overlay() -> void:
	_pause_overlay = _make_overlay("PauseScreen", Color(0.008, 0.02, 0.045, 0.68))
	_pause_card = PanelContainer.new()
	_pause_card.name = "PauseCard"
	_set_anchors(_pause_card, 0.09, 0.255, 0.91, 0.745)
	_pause_card.add_theme_stylebox_override(
		"panel",
		UITheme.panel_style(Color(0.035, 0.065, 0.105, 0.99), true, 28),
	)
	_pause_overlay.add_child(_pause_card)
	var stack := _panel_stack(_pause_card, 26, 22, 26, 22, 14)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UITheme.label("PAUSA", 38, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size = Vector2(0.0, 66.0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var resume_button := _make_button("RIPRENDI", true)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	stack.add_child(resume_button)
	_pause_audio_button = _make_button("AUDIO ON", false)
	_pause_audio_button.custom_minimum_size = Vector2(0.0, 58.0)
	_pause_audio_button.add_theme_font_size_override("font_size", 18)
	_pause_audio_button.pressed.connect(_request_audio_toggle)
	stack.add_child(_pause_audio_button)
	var menu_button := _make_button("MENU", false)
	menu_button.custom_minimum_size = Vector2(0.0, 58.0)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	stack.add_child(menu_button)


func _build_results_overlay() -> void:
	_results_overlay = _make_overlay("RunResults", Color(0.008, 0.02, 0.045, 0.76))
	_results_panel = PanelContainer.new()
	_results_panel.name = "ResultsCard"
	_set_anchors(_results_panel, 0.07, 0.10, 0.93, 0.90)
	_results_panel.add_theme_stylebox_override(
		"panel",
		UITheme.panel_style(Color(0.035, 0.065, 0.105, 0.99), true, 28),
	)
	_results_overlay.add_child(_results_panel)
	var stack := _panel_stack(_results_panel, 24, 18, 24, 18, 8)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER

	_results_title = UITheme.label("TRAGUARDO!", 36, HORIZONTAL_ALIGNMENT_CENTER)
	_results_title.custom_minimum_size = Vector2(0.0, 62.0)
	_results_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_results_title.add_theme_color_override("font_color", Color(0.45, 1.0, 0.66))
	stack.add_child(_results_title)

	var divider := ColorRect.new()
	divider.color = Color(0.32, 0.53, 0.72, 0.75)
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(divider)

	var score_eyebrow := UITheme.label("PUNTI", 12, HORIZONTAL_ALIGNMENT_CENTER)
	score_eyebrow.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	stack.add_child(score_eyebrow)
	_results_score_label = UITheme.label("0", 52, HORIZONTAL_ALIGNMENT_CENTER)
	_results_score_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_GOLD)
	_results_score_label.custom_minimum_size = Vector2(0.0, 66.0)
	_results_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_results_score_label.resized.connect(_center_results_score_pivot)
	stack.add_child(_results_score_label)

	_results_label = UITheme.label("", 17, HORIZONTAL_ALIGNMENT_CENTER)
	_results_label.custom_minimum_size = Vector2(0.0, 208.0)
	_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_results_label.add_theme_constant_override("line_spacing", 7)
	stack.add_child(_results_label)

	stack.add_child(UITheme.spacer(4.0))
	var replay_button := _make_button("RIGIOCA", true)
	replay_button.name = "ReplayButton"
	replay_button.custom_minimum_size = Vector2(0.0, 76.0)
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	stack.add_child(replay_button)
	var menu_button := _make_button("MENU", false)
	menu_button.name = "ResultsMenuButton"
	menu_button.custom_minimum_size = Vector2(0.0, 60.0)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	stack.add_child(menu_button)


# ---------------------------------------------------------------- Helpers ---

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


# ------------------------------------------------------------- Animazioni ---

## Dissolvenza breve: niente zoom o rimbalzi sui pannelli.
func _animate_panel_in(panel: Control) -> void:
	if panel == null:
		return
	panel.scale = Vector2.ONE
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		panel,
		"modulate:a",
		1.0,
		minf(GameConfig.UI_APPEAR_DURATION, 0.22),
	)


func _pop(
	control: Control,
	from_scale: float = 0.98,
	duration: float = GameConfig.UI_POP_DURATION,
) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * clampf(from_scale, 0.94, 1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, minf(duration, 0.22))


func _center_countdown_pivot() -> void:
	if _countdown_label != null:
		_countdown_label.pivot_offset = _countdown_label.size * 0.5


func _center_results_score_pivot() -> void:
	if _results_score_label != null:
		_results_score_label.pivot_offset = _results_score_label.size * 0.5


# ---------------------------------------------------------------- Public ----

func set_goal_distance(goal: float) -> void:
	_goal_distance = maxf(goal, 1.0)
	if _progress_bar != null:
		_progress_bar.max_value = _goal_distance
	set_distance(_displayed_distance)


func set_distance(meters: int) -> void:
	_displayed_distance = maxi(meters, 0)
	if _distance_label != null:
		_distance_label.text = "%d m / %d m" % [
			_displayed_distance,
			roundi(_goal_distance),
		]
	if _progress_bar != null:
		_progress_bar.value = minf(float(_displayed_distance), _goal_distance)


## Totale raccolto nella corsa corrente, distinto dal saldo permanente.
func set_coins(amount: int) -> void:
	_displayed_coins = maxi(amount, 0)
	if _coins_label != null:
		_coins_label.text = "%d" % _displayed_coins


func set_permanent_coins(amount: int) -> void:
	_displayed_permanent_coins = maxi(amount, 0)
	if _permanent_coins_label != null:
		_permanent_coins_label.text = "SALDO %d" % _displayed_permanent_coins
	if _menu_balance_label != null:
		_menu_balance_label.text = "SALDO %d" % _displayed_permanent_coins


func set_countdown(seconds_left: int) -> void:
	if _countdown_label == null:
		return
	var text := "VIA!" if seconds_left <= 0 else str(seconds_left)
	if text == _last_countdown_text:
		return
	_last_countdown_text = text
	_countdown_label.text = text
	_pop(_countdown_label, 0.96, 0.20)


## Aggiorna le etichette audio (menu, pausa, HUD) e il colore del pulsante.
func set_audio_muted(muted: bool) -> void:
	_audio_muted = muted
	var text := "AUDIO OFF" if muted else "AUDIO ON"
	var color := Color(0.78, 0.86, 0.94) if not muted else Color(0.55, 0.60, 0.68)
	for button in [_audio_button, _menu_audio_button, _pause_audio_button]:
		var target := button as Button
		if target == null:
			continue
		if target == _audio_button:
			var race_color := Color(0.10, 0.20, 0.15, 0.90)
			if muted:
				race_color = Color(0.12, 0.13, 0.16, 0.90)
			target.text = "MUTO" if muted else "AUDIO"
			target.tooltip_text = "Audio disattivato" if muted else "Audio attivo"
			var text_color := Color(0.68, 0.73, 0.80) if muted else Color(0.76, 1.0, 0.84)
			for color_override in [
				"font_color",
				"font_hover_color",
				"font_pressed_color",
				"font_focus_color",
			]:
				target.add_theme_color_override(color_override, text_color)
			UITheme.apply_button_color(target, race_color)
			continue
		target.text = text
		target.add_theme_color_override("font_color", Color(0.035, 0.07, 0.105))
		target.add_theme_stylebox_override("normal", UITheme.button_style(color))
		target.add_theme_stylebox_override("hover", UITheme.button_style(color.lightened(0.10)))
		target.add_theme_stylebox_override("pressed", UITheme.button_style(color.darkened(0.12)))


func _request_audio_toggle() -> void:
	audio_toggle_requested.emit()


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
	if _results_score_label != null:
		_results_score_label.text = str(final_score)
	_pop(_results_score_label, 0.96, 0.20)
	_pop(_results_title, 0.97, 0.18)


func set_evolution(level: int, _delta: int, profile: CarEvolutionProfile = null) -> void:
	if _evolution_label == null or _stage_label == null or _stats_label == null:
		return
	var clamped := clampi(level, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
	_evolution_label.text = "%d/%d" % [clamped, GameConfig.EVOLUTION_MAX_LEVEL]
	_evolution_label.label_settings.font_color = _level_color(clamped).lightened(0.25)
	_update_pips(clamped)
	if profile == null:
		return
	_stage_label.text = profile.stage_name
	_stage_label.label_settings.font_color = profile.body_color.lightened(0.35)
	_stats_label.text = profile.stats_text()


func _update_pips(level: int) -> void:
	for index in _pip_nodes.size():
		var pip := _pip_nodes[index]
		if pip == null:
			continue
		var reached := index <= level
		var color := _level_color(index)
		pip.modulate = color if reached else Color(0.30, 0.36, 0.44, 0.55)
		pip.custom_minimum_size = Vector2(7.0, 7.0) if index != level else Vector2(8.0, 8.0)


func set_state(state: GameManager.State) -> void:
	if _ui_root == null:
		return
	var previous := _last_state
	_last_state = state
	_menu_overlay.visible = state == GameManager.State.IDLE
	_status_panel.visible = state != GameManager.State.IDLE
	_pause_button.visible = state == GameManager.State.PLAYING
	_audio_button.visible = state != GameManager.State.IDLE
	_countdown_overlay.visible = state == GameManager.State.COUNTDOWN
	_pause_overlay.visible = state == GameManager.State.PAUSED
	_results_overlay.visible = state == GameManager.State.FINISHED
	_hint_label.visible = state == GameManager.State.PLAYING

	if state != previous:
		_last_countdown_text = ""
		if state == GameManager.State.IDLE:
			_animate_panel_in(_menu_card)
		elif state == GameManager.State.PAUSED:
			_animate_panel_in(_pause_card)
		elif state == GameManager.State.FINISHED:
			_animate_panel_in(_results_panel)
		elif state == GameManager.State.COUNTDOWN:
			_last_countdown_text = ""
		elif state == GameManager.State.PLAYING:
			_hint_time_left = HINT_DURATION
			_hint_label.modulate = Color.WHITE
		else:
			_hint_time_left = 0.0

	match state:
		GameManager.State.IDLE:
			_hint_label.text = ""
			_hide_feedback()
			_collision_feedback_time = 0.0
		GameManager.State.COUNTDOWN:
			_hint_label.text = ""
			_hide_feedback()
		GameManager.State.PLAYING:
			_hint_label.text = "TRASCINA PER STERZARE"
		GameManager.State.PAUSED:
			_hide_feedback()
		GameManager.State.FINISHED:
			_hint_label.visible = false
			_hide_feedback()


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
	# Il timer resta disponibile al test/feedback logico; niente lampi invasivi.
	_collision_feedback_time = COLLISION_FEEDBACK_DURATION


func collision_feedback_active() -> bool:
	return _collision_feedback_time > 0.0


## Alias mantenuto per compatibilità con le scene/test precedenti.
func collision_flash_active() -> bool:
	return collision_feedback_active()


func _set_feedback(text: String, color: Color) -> void:
	_feedback_label.text = text
	_feedback_label.label_settings.font_color = color.lightened(0.25)
	_feedback_style.bg_color = Color(color.r, color.g, color.b, PILL_ALPHA)
	_feedback_style.border_color = Color(color.r, color.g, color.b, 0.85)
	_feedback_panel.modulate = Color.WHITE
	_feedback_panel.visible = true
	_feedback_time = FEEDBACK_DURATION


func _hide_feedback() -> void:
	_feedback_time = 0.0
	if _feedback_panel != null:
		_feedback_panel.visible = false
	if _feedback_label != null:
		_feedback_label.visible = true


func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)

	if _feedback_time > 0.0:
		_feedback_time = maxf(_feedback_time - step, 0.0)
		if _feedback_time <= FEEDBACK_FADE and _feedback_panel != null:
			_feedback_panel.modulate.a = _feedback_time / FEEDBACK_FADE
		if _feedback_time <= 0.0 and _feedback_panel != null:
			_feedback_panel.visible = false
			_feedback_panel.modulate = Color.WHITE

	# Mantiene la finestra temporale del feedback urto senza colorare l'intero schermo.
	_collision_feedback_time = maxf(_collision_feedback_time - step, 0.0)

	if _hint_time_left > 0.0:
		_hint_time_left = maxf(_hint_time_left - step, 0.0)
		if _hint_time_left <= 0.0 and _hint_label != null:
			_hint_label.visible = false

	if _coin_pop_time > 0.0 and _coins_label != null:
		_coin_pop_time = maxf(_coin_pop_time - step, 0.0)
		var coin_progress := 1.0 - (_coin_pop_time / COIN_POP_DURATION)
		var pulse := sin(coin_progress * PI)
		var coin_scale := 1.0 + COIN_POP_SCALE * pulse
		_coins_label.scale = Vector2(coin_scale, coin_scale)
		_coins_label.pivot_offset = _coins_label.size * 0.5
		_coins_label.modulate = Color.WHITE.lerp(GameConfig.COLOR_COIN_HIGHLIGHT, pulse * 0.22)
		if _coin_pop_time <= 0.0:
			_coins_label.scale = Vector2.ONE
			_coins_label.modulate = Color.WHITE
	elif _coins_label != null and _coins_label.scale != Vector2.ONE:
		_coins_label.scale = Vector2.ONE
		_coins_label.modulate = Color.WHITE


# -------------------------------------------------------------- Styling ----

func _level_color(level: int) -> Color:
	var index := clampi(level, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
	return GameConfig.EVOLUTION_COLORS[index]


func _make_button(text: String, accent: bool) -> Button:
	var control := UITheme.button(text, accent)
	control.pressed.connect(_on_any_button_pressed)
	return control


## Suono di conferma per ogni pulsante dell'interfaccia.
func _on_any_button_pressed() -> void:
	var sfx := get_tree().get_first_node_in_group(&"sfx") as SfxDirector
	if sfx != null:
		sfx.play_button()
