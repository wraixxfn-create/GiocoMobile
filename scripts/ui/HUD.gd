class_name HUD
extends CanvasLayer
## Interfaccia touch-first: menu, HUD di corsa, countdown, pausa e riepilogo.
##
## Gerarchia visiva pensata per il verticale:
## 1. barra di stato in alto (distanza, monete, progresso, evoluzione);
## 2. nome dello stadio al centro-alto, grande e colorato;
## 3. feedback temporanei (cancello, urto) come pillole animate;
## 4. suggerimento di sterzo in basso.
##
## Tutte le animazioni sono brevi, non bloccano i controlli e non lasciano
## stati intermedi: i pannelli compaiono in dissolvenza + scala, i testi con un
## piccolo "pop". I nodi e i metodi pubblici restano quelli usati dai test.

signal play_requested
signal replay_requested
signal menu_requested
signal pause_requested
signal resume_requested
## Richiesta di attivare/disattivare l'audio (gestita da GameRoot/SfxDirector).
signal audio_toggle_requested

const FEEDBACK_DURATION: float = 1.4
const FEEDBACK_FADE: float = 0.5
const STAGE_POP_DURATION: float = 0.6
const STAGE_POP_SCALE: float = 0.28
const COIN_POP_DURATION: float = 0.24
const COIN_POP_SCALE: float = 0.26
const COLLISION_FLASH_DURATION: float = 0.30
const COLLISION_FLASH_ALPHA: float = 0.28
const COLLISION_FLASH_COLOR := Color(0.95, 0.22, 0.14)
const COLOR_FEEDBACK_SPEED := Color(0.98, 0.58, 0.16)
const PILL_ALPHA: float = 0.22
const PIPS_COUNT: int = GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL + 1

var _ui_root: Control
var _status_panel: PanelContainer
var _distance_label: Label
var _coins_label: Label
var _permanent_coins_label: Label
var _evolution_label: Label
var _progress_bar: ProgressBar
var _pause_button: Button
var _audio_button: Button
var _stage_eyebrow: Label
var _stage_label: Label
var _stage_underline: ColorRect
var _stats_label: Label
var _hint_label: Label
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _feedback_style: StyleBoxFlat
var _collision_flash: ColorRect
var _gate_flash: ColorRect
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
var _stage_pop_time: float = 0.0
var _coin_pop_time: float = 0.0
var _flash_time: float = 0.0
var _gate_flash_time: float = 0.0
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

	_collision_flash = _make_full_rect_flash("CollisionFlash", COLLISION_FLASH_COLOR)
	_gate_flash = _make_full_rect_flash("GateFlash", COLOR_FEEDBACK_SPEED)

	_build_game_hud()
	_build_menu_overlay()
	_build_countdown_overlay()
	_build_pause_overlay()
	_build_results_overlay()


func _make_full_rect_flash(node_name: String, color: Color) -> ColorRect:
	var flash := ColorRect.new()
	flash.name = node_name
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.visible = false
	_ui_root.add_child(flash)
	return flash


func _build_game_hud() -> void:
	# ---------------------------------------------------------- barra alto ---
	_status_panel = PanelContainer.new()
	_status_panel.name = "RaceStatus"
	_set_anchors(_status_panel, 0.025, 0.012, 0.785, 0.152)
	_status_panel.add_theme_stylebox_override(
		"panel",
		UITheme.panel_style(Color(0.025, 0.045, 0.075, 0.86), false, 18),
	)
	_ui_root.add_child(_status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 8)
	_status_panel.add_child(margin)
	var status_stack := VBoxContainer.new()
	status_stack.add_theme_constant_override("separation", 5)
	margin.add_child(status_stack)

	var first_row := HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 8)
	status_stack.add_child(first_row)
	_distance_label = UITheme.label("DISTANZA 0/800 m", 19, HORIZONTAL_ALIGNMENT_LEFT)
	_distance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_distance_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	first_row.add_child(_distance_label)

	var coin_chip := HBoxContainer.new()
	coin_chip.add_theme_constant_override("separation", 5)
	coin_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	first_row.add_child(coin_chip)
	var coin_icon := UITheme.icon(UITheme.coin_texture(), Vector2(20.0, 20.0))
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_chip.add_child(coin_icon)
	_coins_label = UITheme.label("0", 19, HORIZONTAL_ALIGNMENT_RIGHT)
	_coins_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_GOLD)
	_coins_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	coin_chip.add_child(_coins_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "RaceProgress"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = _goal_distance
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_theme_stylebox_override(
		"background",
		UITheme.progress_style(Color(0.09, 0.13, 0.19, 0.95)),
	)
	_progress_bar.add_theme_stylebox_override(
		"fill",
		UITheme.progress_style(GameConfig.COLOR_UI_ACCENT),
	)
	status_stack.add_child(_progress_bar)

	var second_row := HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 8)
	status_stack.add_child(second_row)
	_evolution_label = UITheme.label("EVOLUZIONE 1/5", 14, HORIZONTAL_ALIGNMENT_LEFT)
	_evolution_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_row.add_child(_evolution_label)
	_permanent_coins_label = UITheme.label("SALDO 0", 14, HORIZONTAL_ALIGNMENT_RIGHT)
	_permanent_coins_label.add_theme_color_override(
		"font_color",
		GameConfig.COLOR_UI_TEXT_MUTED,
	)
	_permanent_coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_row.add_child(_permanent_coins_label)

	# Spie dell'evoluzione: leggibili a colpo d'occhio anche senza testo.
	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 5)
	pip_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status_stack.add_child(pip_row)
	var pip_texture := UITheme.circle_texture()
	for index in PIPS_COUNT:
		var pip := UITheme.icon(pip_texture, Vector2(12.0, 12.0))
		pip_row.add_child(pip)
		_pip_nodes.append(pip)

	# ---------------------------------------------------- pulsanti laterali --
	_pause_button = _make_button("PAUSA", false)
	_pause_button.name = "PauseButton"
	_pause_button.add_theme_font_size_override("font_size", 16)
	_set_anchors(_pause_button, 0.805, 0.012, 0.975, 0.078)
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_ui_root.add_child(_pause_button)

	_audio_button = _make_button("AUDIO ON", false)
	_audio_button.name = "AudioButton"
	_audio_button.add_theme_font_size_override("font_size", 13)
	_audio_button.tooltip_text = "Attiva o disattiva i suoni"
	_set_anchors(_audio_button, 0.805, 0.084, 0.975, 0.150)
	_audio_button.pressed.connect(_request_audio_toggle)
	_ui_root.add_child(_audio_button)

	# ------------------------------------------------------- nome stadio ----
	_stage_eyebrow = UITheme.label("STADIO ATTUALE", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_stage_eyebrow.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	_set_anchors(_stage_eyebrow, 0.10, 0.157, 0.90, 0.180)
	_stage_eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_root.add_child(_stage_eyebrow)

	_stage_label = UITheme.label("UTILITARIA", 35, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchors(_stage_label, 0.035, 0.178, 0.965, 0.236)
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_label.resized.connect(_center_stage_pivot)
	_ui_root.add_child(_stage_label)

	_stage_underline = ColorRect.new()
	_stage_underline.name = "StageUnderline"
	_stage_underline.color = GameConfig.COLOR_UI_ACCENT
	_stage_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_anchors(_stage_underline, 0.42, 0.239, 0.58, 0.242)
	_ui_root.add_child(_stage_underline)

	_stats_label = UITheme.label("VEL ×1.00   STERZO ×1.00", 15, HORIZONTAL_ALIGNMENT_CENTER)
	_stats_label.add_theme_color_override("font_color", GameConfig.COLOR_UI_TEXT_MUTED)
	_set_anchors(_stats_label, 0.04, 0.244, 0.96, 0.272)
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui_root.add_child(_stats_label)

	# ------------------------------------------------------- feedback -------
	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "FeedbackPill"
	_set_anchors(_feedback_panel, 0.10, 0.300, 0.90, 0.372)
	_feedback_style = UITheme.panel_style(Color(0.05, 0.08, 0.12, 0.88), false, 26)
	_feedback_panel.add_theme_stylebox_override("panel", _feedback_style)
	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_panel.visible = false
	_ui_root.add_child(_feedback_panel)
	var feedback_margin := MarginContainer.new()
	feedback_margin.add_theme_constant_override("margin_left", 12)
	feedback_margin.add_theme_constant_override("margin_right", 12)
	_feedback_panel.add_child(feedback_margin)
	_feedback_label = UITheme.label("", 29, HORIZONTAL_ALIGNMENT_CENTER)
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_margin.add_child(_feedback_label)

	_hint_label = UITheme.label("TRASCINA PER STERZARE", 17, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_set_anchors(_hint_label, 0.04, 0.905, 0.96, 0.955)
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

## Dissolvenza + scala morbida per i pannelli dei menu.
func _animate_panel_in(panel: Control) -> void:
	if panel == null:
		return
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var duration := GameConfig.UI_APPEAR_DURATION
	if panel.size.x <= 1.0 or panel.size.y <= 1.0:
		var fade := create_tween()
		fade.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade.tween_property(panel, "modulate:a", 1.0, duration)
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, duration)
	tween.tween_property(panel, "scale", Vector2.ONE, duration)


func _pop(control: Control, from_scale: float = 0.82, duration: float = 0.26) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * from_scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration)


func _center_stage_pivot() -> void:
	if _stage_label != null:
		_stage_label.pivot_offset = _stage_label.size * 0.5


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
		_distance_label.text = "DISTANZA %d/%d m" % [
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
	_pop(_countdown_label, 1.35, 0.30)


## Aggiorna le etichette audio (menu, pausa, HUD) e il colore del pulsante.
func set_audio_muted(muted: bool) -> void:
	_audio_muted = muted
	var text := "AUDIO OFF" if muted else "AUDIO ON"
	var color := Color(0.78, 0.86, 0.94) if not muted else Color(0.55, 0.60, 0.68)
	for button in [_audio_button, _menu_audio_button, _pause_audio_button]:
		var target := button as Button
		if target == null:
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
	_pop(_results_score_label, 0.72, 0.34)
	_pop(_results_title, 0.88, 0.30)


func set_evolution(level: int, delta: int, profile: CarEvolutionProfile = null) -> void:
	if _evolution_label == null or _stage_label == null or _stats_label == null:
		return
	var clamped := clampi(level, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
	_evolution_label.text = "EVOLUZIONE %d/%d" % [clamped, GameConfig.EVOLUTION_MAX_LEVEL]
	_evolution_label.label_settings.font_color = _level_color(clamped).lightened(0.25)
	_update_pips(clamped)
	if profile == null:
		return
	_stage_label.text = profile.stage_name
	_stage_label.label_settings.font_color = profile.body_color.lightened(0.35)
	_stage_underline.color = profile.body_color.lightened(0.12)
	_stats_label.text = profile.stats_text()
	if delta != 0:
		_stage_pop_time = STAGE_POP_DURATION
		_pop(_stage_label, 0.82, 0.34)


func _update_pips(level: int) -> void:
	for index in _pip_nodes.size():
		var pip := _pip_nodes[index]
		if pip == null:
			continue
		var reached := index <= level
		var color := _level_color(index)
		pip.modulate = color if reached else Color(0.30, 0.36, 0.44, 0.55)
		pip.custom_minimum_size = Vector2(12.0, 12.0) if index != level else Vector2(14.0, 14.0)


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

	match state:
		GameManager.State.IDLE:
			_hint_label.text = ""
			_hide_feedback()
			_flash_time = 0.0
			_gate_flash_time = 0.0
			_collision_flash.visible = false
			_gate_flash.visible = false
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

	_stage_eyebrow.visible = state != GameManager.State.IDLE
	_stage_label.visible = state != GameManager.State.IDLE
	_stage_underline.visible = state != GameManager.State.IDLE
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
	# Lampo a tutto schermo molto tenue: conferma l'attraversamento senza
	# coprire la pista né bloccare i comandi.
	_start_gate_flash(color)


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
	_feedback_label.label_settings.font_color = color.lightened(0.25)
	_feedback_style.bg_color = Color(color.r, color.g, color.b, PILL_ALPHA)
	_feedback_style.border_color = Color(color.r, color.g, color.b, 0.85)
	_feedback_panel.modulate = Color.WHITE
	_feedback_panel.visible = true
	_feedback_time = FEEDBACK_DURATION
	_pop(_feedback_panel, 0.86, GameConfig.UI_POP_DURATION)


func _hide_feedback() -> void:
	_feedback_time = 0.0
	if _feedback_panel != null:
		_feedback_panel.visible = false
	if _feedback_label != null:
		_feedback_label.visible = true


func _start_gate_flash(color: Color) -> void:
	_gate_flash.color = Color(color.r, color.g, color.b, GameConfig.GATE_FLASH_ALPHA)
	_gate_flash.visible = true
	_gate_flash_time = GameConfig.GATE_FLASH_DURATION


func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)

	if _feedback_time > 0.0:
		_feedback_time = maxf(_feedback_time - step, 0.0)
		if _feedback_time <= FEEDBACK_FADE and _feedback_panel != null:
			_feedback_panel.modulate.a = _feedback_time / FEEDBACK_FADE
		if _feedback_time <= 0.0 and _feedback_panel != null:
			_feedback_panel.visible = false

	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time - step, 0.0)
		var fade := _flash_time / COLLISION_FLASH_DURATION
		_collision_flash.color.a = COLLISION_FLASH_ALPHA * fade * fade
		if _flash_time <= 0.0:
			_collision_flash.visible = false
			_collision_flash.color.a = 0.0

	if _gate_flash_time > 0.0:
		_gate_flash_time = maxf(_gate_flash_time - step, 0.0)
		var gate_fade := _gate_flash_time / GameConfig.GATE_FLASH_DURATION
		_gate_flash.color.a = GameConfig.GATE_FLASH_ALPHA * gate_fade * gate_fade
		if _gate_flash_time <= 0.0:
			_gate_flash.visible = false
			_gate_flash.color.a = 0.0

	if _stage_pop_time > 0.0:
		_stage_pop_time = maxf(_stage_pop_time - step, 0.0)
		var progress := 1.0 - (_stage_pop_time / STAGE_POP_DURATION)
		if _stage_underline != null:
			var width := 0.16 + 0.14 * sin(progress * PI)
			_stage_underline.anchor_left = 0.5 - width * 0.5
			_stage_underline.anchor_right = 0.5 + width * 0.5
		if _stage_pop_time <= 0.0 and _stage_underline != null:
			_stage_underline.anchor_left = 0.42
			_stage_underline.anchor_right = 0.58
	elif _stage_underline != null and not is_equal_approx(_stage_underline.anchor_left, 0.42):
		_stage_underline.anchor_left = 0.42
		_stage_underline.anchor_right = 0.58

	if _coin_pop_time > 0.0:
		_coin_pop_time = maxf(_coin_pop_time - step, 0.0)
		var coin_progress := 1.0 - (_coin_pop_time / COIN_POP_DURATION)
		var coin_scale := 1.0 + COIN_POP_SCALE * sin(coin_progress * PI)
		_coins_label.scale = Vector2(coin_scale, coin_scale)
		_coins_label.pivot_offset = _coins_label.size * 0.5
		_coins_label.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(
			GameConfig.COLOR_COIN_HIGHLIGHT,
			sin(coin_progress * PI) * 0.6,
		)
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
