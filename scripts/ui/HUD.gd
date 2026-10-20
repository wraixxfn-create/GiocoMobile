class_name HUD
extends CanvasLayer
## Interfaccia minimale: distanza, monete, livello di evoluzione e feedback
## dei cancelli (messaggio temporaneo che sfuma).
## TODO(fase 3): pannello evoluzioni, pause e schermata di fine partita.

## Durata del messaggio mostrato dopo l'attraversamento di un cancello.
const FEEDBACK_DURATION: float = 1.4
const FEEDBACK_FADE: float = 0.5

var _distance_label: Label
var _coins_label: Label
var _evolution_label: Label
var _hint_label: Label
var _feedback_label: Label
var _feedback_time: float = 0.0


func _ready() -> void:
	_distance_label = _create_label(Vector2(18.0, 18.0), 30)
	_coins_label = _create_label(Vector2(18.0, 58.0), 30)
	_evolution_label = _create_label(Vector2(18.0, 98.0), 29)
	_hint_label = _create_label(Vector2(0.0, 900.0), 22)
	_hint_label.size = Vector2(540.0, 44.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_feedback_label = _create_label(Vector2(0.0, 250.0), 42)
	_feedback_label.size = Vector2(540.0, 60.0)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.visible = false

	set_state(GameManager.State.IDLE)
	set_evolution(GameConfig.EVOLUTION_START_LEVEL, 0)


func set_distance(meters: int) -> void:
	_distance_label.text = "DISTANZA %d m" % meters


func set_coins(amount: int) -> void:
	_coins_label.text = "MONETE %d" % amount


## Mostra il livello corrente; `delta` è la variazione appena applicata.
func set_evolution(level: int, _delta: int) -> void:
	_evolution_label.text = "EVOLUZIONE %d/%d" % [level, GameConfig.EVOLUTION_MAX_LEVEL]
	_evolution_label.modulate = Color.WHITE.lerp(_level_color(level), 0.55)


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


func _process(delta: float) -> void:
	if _feedback_time <= 0.0:
		return
	_feedback_time = maxf(_feedback_time - delta, 0.0)
	if _feedback_time <= FEEDBACK_FADE:
		_feedback_label.modulate.a = _feedback_time / FEEDBACK_FADE
	if _feedback_time <= 0.0:
		_feedback_label.visible = false


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
