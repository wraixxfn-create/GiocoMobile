class_name HUD
extends CanvasLayer
## HUD della corsa: distanza, monete della sessione, saldo permanente,
## livello di evoluzione, feedback e riepilogo del punteggio finale.
## Tutti gli elementi grafici ignorano l'input del giocatore.

## Durata del messaggio mostrato dopo l'attraversamento di un cancello.
const FEEDBACK_DURATION: float = 1.4
const FEEDBACK_FADE: float = 0.5
## Durata del nome dello stadio.
const STAGE_POP_DURATION: float = 0.6
const STAGE_POP_SCALE: float = 0.35
const COIN_POP_DURATION: float = 0.24
const COIN_POP_SCALE: float = 0.28
## Lampeggio rosso a schermo intero dopo una collisione con un ostacolo.
const COLLISION_FLASH_DURATION: float = 0.30
const COLLISION_FLASH_ALPHA: float = 0.30
const COLLISION_FLASH_COLOR := Color(0.95, 0.22, 0.14)
const COLOR_FEEDBACK_SPEED := Color(0.98, 0.55, 0.15)

var _distance_label: Label
var _coins_label: Label
var _permanent_coins_label: Label
var _evolution_label: Label
var _stage_label: Label
var _stats_label: Label
var _hint_label: Label
var _feedback_label: Label
var _collision_flash: ColorRect
var _results_panel: ColorRect
var _results_label: Label
var _displayed_distance: int = 0
var _displayed_coins: int = 0
var _displayed_permanent_coins: int = 0
var _feedback_time: float = 0.0
var _stage_pop_time: float = 0.0
var _coin_pop_time: float = 0.0
var _flash_time: float = 0.0


func _ready() -> void:
	# Il lampeggio di collisione sta dietro a tutte le etichette e non
	# intercetta mai l'input: è solo grafico.
	_collision_flash = ColorRect.new()
	_collision_flash.name = "CollisionFlash"
	_collision_flash.color = Color(
		COLLISION_FLASH_COLOR.r, COLLISION_FLASH_COLOR.g, COLLISION_FLASH_COLOR.b, 0.0
	)
	_collision_flash.position = Vector2.ZERO
	_collision_flash.size = Vector2(540.0, 960.0)
	_collision_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collision_flash.visible = false
	add_child(_collision_flash)

	_distance_label = _create_label(Vector2(18.0, 16.0), 28)
	_coins_label = _create_label(Vector2(18.0, 52.0), 27)
	_permanent_coins_label = _create_label(Vector2(18.0, 86.0), 22)
	_evolution_label = _create_label(Vector2(18.0, 116.0), 26)

	_stage_label = _create_label(Vector2(0.0, 168.0), 34)
	_stage_label.size = Vector2(540.0, 46.0)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.pivot_offset = Vector2(270.0, 23.0)

	_stats_label = _create_label(Vector2(0.0, 212.0), 19)
	_stats_label.size = Vector2(540.0, 30.0)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hint_label = _create_label(Vector2(0.0, 900.0), 22)
	_hint_label.size = Vector2(540.0, 44.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_feedback_label = _create_label(Vector2(0.0, 290.0), 42)
	_feedback_label.size = Vector2(540.0, 60.0)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.visible = false

	_results_panel = ColorRect.new()
	_results_panel.name = "RunResultsPanel"
	_results_panel.color = Color(0.035, 0.055, 0.085, 0.91)
	_results_panel.position = Vector2(34.0, 282.0)
	_results_panel.size = Vector2(472.0, 402.0)
	_results_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_panel.visible = false
	add_child(_results_panel)

	_results_label = _create_label(Vector2(48.0, 294.0), 26)
	_results_label.size = Vector2(444.0, 376.0)
	_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_results_label.visible = false

	set_distance(0)
	set_coins(0)
	set_permanent_coins(0)
	set_state(GameManager.State.IDLE)
	set_evolution(
		GameConfig.EVOLUTION_START_LEVEL,
		0,
		CarEvolutionCatalog.profile_for(GameConfig.EVOLUTION_START_LEVEL),
	)


func set_distance(meters: int) -> void:
	_displayed_distance = maxi(meters, 0)
	_distance_label.text = "DISTANZA %d m" % _displayed_distance


## Totale raccolto nella corsa corrente (non il saldo persistente).
func set_coins(amount: int) -> void:
	_displayed_coins = maxi(amount, 0)
	_coins_label.text = "MONETE CORSA %d" % _displayed_coins


func set_permanent_coins(amount: int) -> void:
	_displayed_permanent_coins = maxi(amount, 0)
	_permanent_coins_label.text = "SALDO PERMANENTE %d" % _displayed_permanent_coins


## Piccolo "pop" del contatore quando una moneta viene accreditata.
func play_coin_pickup_animation(_run_total: int) -> void:
	_coin_pop_time = COIN_POP_DURATION


func displayed_distance() -> int:
	return _displayed_distance


func displayed_coins() -> int:
	return _displayed_coins


func displayed_permanent_coins() -> int:
	return _displayed_permanent_coins


func results_visible() -> bool:
	return _results_panel.visible


func results_text() -> String:
	return _results_label.text


## Mostra il riepilogo finale della corsa conclusa.
func show_run_results(final_score: int, distance_meters: int, max_level: int, coins: int) -> void:
	_results_label.text = "\n".join(PackedStringArray([
		"CORSA TERMINATA",
		"PUNTEGGIO %d" % final_score,
		"DISTANZA %d m" % distance_meters,
		"LIVELLO MASSIMO %d/%d" % [max_level, GameConfig.EVOLUTION_MAX_LEVEL],
		"MONETE RACCOLTE %d" % coins,
		"SALDO PERMANENTE %d" % _displayed_permanent_coins,
	]))
	_results_label.visible = true
	_results_panel.visible = true


## Mostra il livello corrente; `delta` è la variazione appena applicata e
## `profile` lo stadio (nome e statistiche). Con `delta != 0` il nome dello
## stadio fa un "pop" al centro dello schermo.
func set_evolution(level: int, delta: int, profile: CarEvolutionProfile = null) -> void:
	_evolution_label.text = "EVOLUZIONE %d/%d" % [level, GameConfig.EVOLUTION_MAX_LEVEL]
	_evolution_label.modulate = Color.WHITE.lerp(_level_color(level), 0.55)

	if profile == null:
		return
	_stage_label.text = profile.stage_name
	_stage_label.label_settings.font_color = profile.body_color.lightened(0.35)
	_stats_label.text = profile.stats_text()
	if delta != 0:
		_stage_pop_time = STAGE_POP_DURATION


func set_state(state: GameManager.State) -> void:
	match state:
		GameManager.State.IDLE:
			_hint_label.text = "TOCCA LO SCHERMO PER INIZIARE"
		GameManager.State.PLAYING:
			_hint_label.text = "TRASCINA PER STERZARE"
			_results_panel.visible = false
			_results_label.visible = false
		GameManager.State.FINISHED:
			_hint_label.text = "CORSA TERMINATA"


## Messaggio dopo l'attraversamento di un cancello.
## `requested_value` = valore del cancello, `applied_delta` = effetto reale
## (0 se il livello era già al minimo/massimo), `_level` = nuovo livello.
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

	_feedback_label.text = text
	_feedback_label.label_settings.font_color = color.lightened(0.2)
	_feedback_label.modulate = Color.WHITE
	_feedback_label.visible = true
	_feedback_time = FEEDBACK_DURATION


## Messaggio + lampeggio rosso dopo una collisione con un ostacolo.
## `penalty_kind` è GameConfig.OBSTACLE_PENALTY_*, `evolution_delta` la
## regressione realmente applicata (0 se il livello era già al minimo).
## Una collisione mostra UNA sola penalità: velocità oppure evoluzione.
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

	_feedback_label.text = text
	_feedback_label.label_settings.font_color = color.lightened(0.2)
	_feedback_label.modulate = Color.WHITE
	_feedback_label.visible = true
	_feedback_time = FEEDBACK_DURATION

	_collision_flash.visible = true
	_flash_time = COLLISION_FLASH_DURATION


## True mentre il lampeggio rosso di collisione è attivo (usato dai test).
func collision_flash_active() -> bool:
	return _flash_time > 0.0


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


func _level_color(level: int) -> Color:
	var index := clampi(level, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
	return GameConfig.EVOLUTION_COLORS[index]


func _create_label(label_pos: Vector2, font_size: int) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color.WHITE
	settings.outline_size = 6
	settings.outline_color = Color(0.08, 0.10, 0.14, 0.90)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	settings.shadow_offset = Vector2(2.0, 2.0)

	var label := Label.new()
	label.position = label_pos
	label.label_settings = settings
	add_child(label)
	return label
