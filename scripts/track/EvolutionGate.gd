class_name EvolutionGate
extends Node3D
## Un cancello di evoluzione: un'arcata colorata che l'auto può attraversare.
##
## Il cancello è puramente visivo + logico (nessun corpo fisico): la geometria
## serve al giocatore per scegliere, mentre l'attraversamento è rilevato in 3D
## da `crossing_x()`, che calcola l'intersezione tra il segmento percorso
## dall'auto e il piano verticale del cancello. Questo rende la rilevazione
## corretta anche con passi grandi o movimento diagonale in un solo frame.
##
## Regole del prototipo:
## - valore > 0 (verde/blu): evoluzione positiva;
## - valore < 0 (rosso): regressione;
## - un cancello si attiva UNA sola volta (`consumed`) e poi si spegne.

## Durata dell'animazione di spegnimento dopo l'attraversamento.
const CONSUME_DURATION: float = 0.45
const POST_WIDTH: float = 0.22
const POST_DEPTH: float = 0.32
const BEAM_HEIGHT: float = 0.30
const PANEL_ALPHA: float = 0.20
const PANEL_BOTTOM: float = 0.20
const PANEL_TOP_GAP: float = 0.55
const LABEL_FONT_SIZE: int = 128
const LABEL_PIXEL_SIZE: float = 0.012

## Variazione applicata al livello di evoluzione (+1, +2, -1, ...).
var value: int = 1
## Estremi laterali del varco, in coordinate mondo sull'asse X.
var span_start: float = 0.0
var span_end: float = 0.0
## True quando il cancello è già stato attraversato (nessuna seconda attivazione).
var consumed: bool = false

var _visual: Node3D
var _panel: MeshInstance3D
var _label: Label3D
var _frame_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _panel_material: StandardMaterial3D
var _base_color: Color = GameConfig.COLOR_GATE_POSITIVE
var _consuming: bool = false
var _consume_time: float = 0.0


func _ready() -> void:
	# L'animazione di spegnimento parte solo quando serve.
	set_process(false)


## Costruisce la geometria del cancello.
## `left_x`/`right_x` sono gli estremi del varco in coordinate mondo.
## La posizione Z (piano del cancello) va impostata dal chiamante prima
## dell'attraversamento, perché `crossing_x()` usa la trasformazione globale.
func setup(gate_value: int, left_x: float, right_x: float) -> void:
	value = gate_value
	span_start = minf(left_x, right_x)
	span_end = maxf(left_x, right_x)
	consumed = false
	_consuming = false
	_consume_time = 0.0
	position.x = (span_start + span_end) * 0.5
	_build(maxf(span_end - span_start, 0.2))


func is_positive() -> bool:
	return value > 0


## Testo mostrato sopra il cancello ("+1", "+2", "-1", ...).
func label_text() -> String:
	return _label.text if _label != null else ""


## True se la X indicata cade nel varco. Se `include_end` è true l'estremo
## destro è incluso: serve a far sì che, tra due cancelli affiancati, ogni
## punto della pista appartenga esattamente a un cancello.
func contains_x(x: float, include_end: bool = false) -> bool:
	if include_end:
		return x >= span_start and x <= span_end
	return x >= span_start and x < span_end


## Rilevazione 3D dell'attraversamento.
## Restituisce la X del punto in cui il segmento `previous_position` ->
## `current_position` interseca il piano del cancello, oppure NAN se il
## segmento non attraversa il piano nel verso di marcia (-Z).
## L'auto viaggia verso -Z: si attraversa quando la Z passa da >= a < del piano.
func crossing_x(previous_position: Vector3, current_position: Vector3) -> float:
	var plane_z := global_position.z
	var start_offset := previous_position.z - plane_z
	var end_offset := current_position.z - plane_z
	if start_offset < 0.0 or end_offset >= 0.0:
		return NAN
	var delta_z := current_position.z - previous_position.z
	if is_zero_approx(delta_z):
		return NAN
	var weight := (plane_z - previous_position.z) / delta_z
	return lerpf(previous_position.x, current_position.x, clampf(weight, 0.0, 1.0))


## Attiva l'effetto del cancello. Sicuro da chiamare più volte: l'effetto
## viene applicato una sola volta.
func trigger() -> void:
	if consumed:
		return
	consumed = true
	_consuming = true
	_consume_time = 0.0
	set_process(true)


## Spegne il cancello senza animazione di consumo (cancello "non scelto"
## della coppia, che deve comunque sparire per evitare doppie letture).
func deactivate() -> void:
	consumed = true
	_consuming = false
	_apply_consumed_state(1.0)
	set_process(false)


func _process(delta: float) -> void:
	if not _consuming:
		set_process(false)
		return
	_consume_time += delta
	var progress := clampf(_consume_time / CONSUME_DURATION, 0.0, 1.0)
	_apply_consumed_state(progress)
	if progress >= 1.0:
		_consuming = false
		set_process(false)


# ------------------------------------------------------------------ Build ---

func _build(width: float) -> void:
	_base_color = _color_for_value(value)
	_frame_material = _make_material(GameConfig.COLOR_GATE_FRAME, 0.45)
	_accent_material = _make_material(_base_color, 0.30, 1.35)
	_panel_material = _make_material(_base_color, 0.70, 0.55, PANEL_ALPHA)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var height := GameConfig.GATE_HEIGHT
	var post_offset := width * 0.5 - POST_WIDTH * 0.5
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		# Pilone colorato del varco.
		_visual.add_child(_mesh_box(
			Vector3(POST_WIDTH, height, POST_DEPTH),
			Vector3(side * post_offset, height * 0.5, 0.0),
			_accent_material,
		))
		# Basamento bianco: ancora il cancello all'asfalto e lo rende leggibile.
		_visual.add_child(_mesh_box(
			Vector3(POST_WIDTH + 0.18, 0.14, POST_DEPTH + 0.18),
			Vector3(side * post_offset, 0.07, 0.0),
			_frame_material,
		))

	# Trave superiore che chiude l'arcata.
	_visual.add_child(_mesh_box(
		Vector3(width, BEAM_HEIGHT, POST_DEPTH),
		Vector3(0.0, height - BEAM_HEIGHT * 0.5, 0.0),
		_accent_material,
	))

	# Pannello semitrasparente che riempie il varco: rende il cancello visibile
	# anche in lontananza senza nascondere la pista.
	var panel_width := maxf(width - POST_WIDTH * 2.0, 0.1)
	var panel_height := maxf(height - PANEL_BOTTOM - PANEL_TOP_GAP, 0.3)
	_panel = _mesh_box(
		Vector3(panel_width, panel_height, 0.05),
		Vector3(0.0, PANEL_BOTTOM + panel_height * 0.5, 0.0),
		_panel_material,
	)
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_panel)

	# Valore comprensibile (+1, +2, -1) sopra la trave, sempre rivolto alla camera.
	_label = Label3D.new()
	_label.name = "ValueLabel"
	_label.text = _format_value(value)
	_label.font_size = LABEL_FONT_SIZE
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.outline_size = 26
	_label.outline_modulate = Color(0.05, 0.06, 0.08, 0.92)
	_label.modulate = Color.WHITE
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, height + 0.62, 0.05)
	_visual.add_child(_label)


func _mesh_box(size: Vector3, box_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = box_position
	instance.material_override = material
	return instance


func _make_material(
	color: Color,
	roughness: float,
	emission_energy: float = 0.0,
	alpha: float = 1.0,
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Spegnimento progressivo: il pannello svanisce, la struttura vira al grigio.
func _apply_consumed_state(progress: float) -> void:
	var off := GameConfig.COLOR_GATE_OFF
	if _panel_material != null:
		_panel_material.albedo_color.a = PANEL_ALPHA * (1.0 - progress)
		_panel_material.emission_energy_multiplier = 0.55 * (1.0 - progress)
	if _accent_material != null:
		var faded := _base_color.lerp(off, progress).darkened(0.15 * progress)
		_accent_material.albedo_color = faded
		_accent_material.emission = faded
		_accent_material.emission_energy_multiplier = 1.35 * (1.0 - progress) + 0.05
	if _label != null:
		_label.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, 0.35, progress))


func _color_for_value(gate_value: int) -> Color:
	if gate_value < 0:
		return GameConfig.COLOR_GATE_NEGATIVE
	if gate_value >= 2:
		return GameConfig.COLOR_GATE_POSITIVE_STRONG
	return GameConfig.COLOR_GATE_POSITIVE


static func _format_value(gate_value: int) -> String:
	var prefix := "+" if gate_value > 0 else ""
	return "%s%d" % [prefix, gate_value]
