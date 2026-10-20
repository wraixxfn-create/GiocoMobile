class_name HUD
extends CanvasLayer
## Interfaccia minimale: distanza, monete, livello di evoluzione (con nome e
## statistiche dello stadio) e feedback dei cancelli (messaggio che sfuma).
## Il cambio di stadio mostra anche un banner che "salta" al centro dello
## schermo: è solo grafico, non intercetta mai l'input del giocatore.
## TODO(fase 3): pannello evoluzioni, pause e schermata di fine partita.

## Durata del messaggio mostrato dopo l'attraversamento di un cancello.
const FEEDBACK_DURATION: float = 1.4
const FEEDBACK_FADE: float = 0.5
## Durata del nome dello stadio.
const STAGE_POP_DURATION: float = 0.6
const STAGE_POP_SCALE: float = 0.35
## Lampeggio rosso a schermo intero dopo una collisione con un ostacolo.
const COLLISION_FLASH_DURATION: float = 0.30
const COLLISION_FLASH_ALPHA: float = 0.30
const COLLISION_FLASH_COLOR := Color(0.95, 0.22, 0.14)
const COLOR_FEEDBACK_SPEED := Color(0.98, 0.55, 0.15)

var _distance_label: Label
var _coins_label: Label
var _evolution_label: Label
var _stage_label: Label
var _stats_label: Label
var _hint_label: Label
var _feedback_label: Label
var _collision_flash: ColorRect
var _feedback_time: float = 0.0
var _stage_pop_time: float = 0.0
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

	_distance_label = _create_label(Vector2(18.0, 18.0), 30)
	_coins_label = _create_label(Vector2(18.0, 58.0), 30)
	_evolution_label = _create_label(Vector2(18.0, 98.0), 29)

	_stage_label = _create_label(Vector2(0.0, 168.0), 34)
	_stage_label.size = Vector2(540.0, 46.0)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.pivot_offset = Vector2(270.0, 23.0)

	_stats_label = _create_label(Vector2(0.0, 214.0), 20)
	_stats_label.size = Vector2(540.0, 30.0)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hint_label = _create_label(Vector2(0.0, 900.0), 22)
	_hint_label.size = Vector2(540.0, 44.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_feedback_label = _create_label(Vector2(0.0, 290.0), 42)
	_feedback_label.size = Vector2(540.0, 60.0)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.visible = false

	set_state(GameManager.State.IDLE)
	set_evolution(
		GameConfig.EVOLUTION_START_LEVEL,
		0,
		CarEvolutionCatalog.profile_for(GameConfig.EVOLUTION_START_LEVEL),
	)


func set_distance(meters: int) -> void:
	_distance_label.text = "DISTANZA %d m" % meters


func set_coins(amount: int) -> void:
	_coins_label.text = "MONETE %d" % amount


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
		GameManager.State.FINISHED:
			_hint_label.text = "TRAGUARDO!"


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
