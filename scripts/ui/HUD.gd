class_name HUD
extends CanvasLayer
## Interfaccia minimale: distanza, monete e hint per il giocatore.
## TODO(fase 2): pannello evoluzioni, messaggi di gate, pause e game over.

var _distance_label: Label
var _coins_label: Label
var _hint_label: Label


func _ready() -> void:
	_distance_label = _create_label(Vector2(18.0, 18.0), 30)
	_coins_label = _create_label(Vector2(18.0, 58.0), 30)
	_hint_label = _create_label(Vector2(0.0, 900.0), 22)
	_hint_label.size = Vector2(540.0, 44.0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_state(GameManager.State.IDLE)


func set_distance(meters: int) -> void:
	_distance_label.text = "DISTANZA %d m" % meters


func set_coins(amount: int) -> void:
	_coins_label.text = "MONETE %d" % amount


func set_state(state: GameManager.State) -> void:
	match state:
		GameManager.State.IDLE:
			_hint_label.text = "TOCCA LO SCHERMO PER INIZIARE"
		GameManager.State.PLAYING:
			_hint_label.text = "TRASCINA PER STERZARE"
		GameManager.State.FINISHED:
			_hint_label.text = "TRAGUARDO!"


func _create_label(position: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override(&"shadow_offset_x", 2)
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	add_child(label)
	return label
