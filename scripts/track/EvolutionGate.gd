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
##
## Aspetto: piloni colorati con striscia luminosa, trave superiore, soglia
## sull'asfalto, pannello traslucido e un cartello compatto con il valore.
## All'attraversamento il cancello si attenua con un'onda discreta a terra,
## senza lampi o rimbalzi invasivi.

## Durata dell'animazione di attraversamento dopo l'attivazione.
const CONSUME_DURATION: float = 0.30
const POST_WIDTH: float = 0.105
const POST_DEPTH: float = 0.16
const BEAM_HEIGHT: float = 0.20
const PANEL_ALPHA: float = 0.055
const PANEL_BOTTOM: float = 0.18
const PANEL_TOP_GAP: float = 0.52
const LABEL_FONT_SIZE: int = 72
const LABEL_PIXEL_SIZE: float = 0.0042
const BADGE_SIZE := Vector2(0.98, 0.38)
const BADGE_HEIGHT: float = 0.34
const BADGE_COLOR := Color(0.05, 0.07, 0.11, 0.90)
const POP_AMOUNT: float = 0.012
const GLOW_STRIP_WIDTH: float = 0.035
const RING_START: float = 0.45
const RING_END: float = 1.55
const RING_ALPHA: float = 0.24

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
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _frame_material: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _panel_material: StandardMaterial3D
var _base_color: Color = GameConfig.COLOR_GATE_POSITIVE
var _consuming: bool = false
var _consume_time: float = 0.0


func _ready() -> void:
	# L'animazione di attraversamento parte solo quando serve.
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
	_frame_material = MaterialFactory.colored(
		"gate_frame", GameConfig.COLOR_GATE_FRAME, 0.40, 0.10
	)
	_accent_material = MaterialFactory.unique_emissive(_base_color, 1.30)
	_glow_material = MaterialFactory.unique_emissive(_base_color.lightened(0.35), 2.10)
	_panel_material = MaterialFactory.translucent(
		Color(_base_color.r, _base_color.g, _base_color.b, PANEL_ALPHA),
		0.55,
	)

	if _visual != null and is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()

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
		# Striscia luminosa interna: rende il varco leggibile già da lontano.
		_visual.add_child(_mesh_box(
			Vector3(GLOW_STRIP_WIDTH, height * 0.82, 0.045),
			Vector3(side * (post_offset - POST_WIDTH * 0.5 - 0.005), height * 0.5, 0.0),
			_glow_material,
		))
		_visual.add_child(_mesh_box(
			Vector3(POST_WIDTH + 0.09, 0.10, POST_DEPTH + 0.09),
			Vector3(side * post_offset, 0.05, 0.0),
			_frame_material,
		))

	# Trave superiore bianca con anima colorata: struttura + colore del cancello.
	_visual.add_child(_mesh_box(
		Vector3(width, BEAM_HEIGHT, POST_DEPTH),
		Vector3(0.0, height - BEAM_HEIGHT * 0.5, 0.0),
		_accent_material,
	))
	_visual.add_child(_mesh_box(
		Vector3(width, 0.04, POST_DEPTH + 0.02),
		Vector3(0.0, height - 0.02, 0.0),
		_frame_material,
	))

	# Soglia colorata sull'asfalto: segna esattamente il piano di attraversamento.
	var threshold := _mesh_box(
		Vector3(maxf(width - POST_WIDTH * 2.0, 0.2), 0.022, 0.16),
		Vector3(0.0, 0.021, 0.0),
		_glow_material,
	)
	threshold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(threshold)

	# Pannello semitrasparente che riempie il varco (non nasconde la pista).
	var panel_width := maxf(width - POST_WIDTH * 2.0, 0.1)
	var panel_height := maxf(height - PANEL_BOTTOM - PANEL_TOP_GAP, 0.3)
	_panel = _mesh_box(
		Vector3(panel_width, panel_height, 0.04),
		Vector3(0.0, PANEL_BOTTOM + panel_height * 0.5, 0.0),
		_panel_material,
	)
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_panel)

	# Frecce a chevron sulla trave: indicano la direzione di marcia.
	for side in sides:
		var arrow := _mesh_box(
			Vector3(0.19, 0.05, 0.03),
			Vector3(side * 0.10, height - BEAM_HEIGHT * 0.5, POST_DEPTH * 0.5 + 0.02),
			_frame_material,
		)
		arrow.rotation.z = deg_to_rad(-34.0) * side
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(arrow)

	_build_badge(height)
	_build_ring()


## Cartello "pillola" scuro + valore: contrasto alto a qualsiasi distanza.
func _build_badge(height: float) -> void:
	var badge_material := MaterialFactory.badge_material(BADGE_COLOR)
	var badge := MeshInstance3D.new()
	badge.name = "ValueBadge"
	var quad := QuadMesh.new()
	quad.size = BADGE_SIZE
	badge.mesh = quad
	badge.material_override = badge_material
	badge.position = Vector3(0.0, height + BADGE_HEIGHT, 0.06)
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(badge)

	_label = Label3D.new()
	_label.name = "ValueLabel"
	_label.text = _format_value(value)
	_label.font_size = LABEL_FONT_SIZE
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.outline_size = 0
	_label.modulate = _base_color.lightened(0.30)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, height + BADGE_HEIGHT, 0.09)
	_visual.add_child(_label)


## Onda a terra mostrata solo durante l'attraversamento.
func _build_ring() -> void:
	_ring_material = MaterialFactory.translucent(
		Color(_base_color.r, _base_color.g, _base_color.b, 0.0),
		2.0,
	)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.03
	disc.radial_segments = 20
	disc.rings = 1
	_ring = MeshInstance3D.new()
	_ring.name = "CrossRing"
	_ring.mesh = disc
	_ring.material_override = _ring_material
	_ring.position = Vector3(0.0, 0.06, 0.0)
	_ring.scale = Vector3(RING_START, 1.0, RING_START)
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(_ring)


func _mesh_box(size: Vector3, box_position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = box_position
	instance.material_override = material
	return instance


## Spegnimento progressivo: l'arcata "pulsa", il pannello svanisce, la
## struttura vira al grigio e un'onda si espande a terra.
func _apply_consumed_state(progress: float) -> void:
	if _visual == null:
		return
	var eased := sin(progress * PI)
	var pop := 1.0 + POP_AMOUNT * eased
	_visual.scale = Vector3(pop, 1.0 + POP_AMOUNT * 0.45 * eased, pop)

	var off := GameConfig.COLOR_GATE_OFF
	if _panel_material != null:
		_panel_material.albedo_color.a = PANEL_ALPHA * (1.0 - progress)
		_panel_material.emission_energy_multiplier = 2.2 * (1.0 - progress)
	if _accent_material != null:
		var faded := _base_color.lerp(off, progress).darkened(0.12 * progress)
		_accent_material.albedo_color = faded
		_accent_material.emission = faded
		_accent_material.emission_energy_multiplier = 1.30 * (1.0 - progress) + 0.05
	if _glow_material != null:
		var glow := _base_color.lightened(0.35).lerp(off, progress)
		_glow_material.albedo_color = glow
		_glow_material.emission = glow
		_glow_material.emission_energy_multiplier = 2.10 * (1.0 - progress)
	if _label != null:
		_label.modulate.a = lerpf(1.0, 0.25, progress)
		_label.scale = Vector3.ONE * (1.0 + 0.04 * eased)
	if _ring != null and _ring_material != null:
		_ring.visible = progress > 0.0 and progress < 1.0
		var radius := lerpf(RING_START, RING_END, progress)
		_ring.scale = Vector3(radius, 1.0, radius)
		_ring_material.albedo_color.a = RING_ALPHA * pow(1.0 - progress, 1.4)
		_ring_material.emission_energy_multiplier = 2.0 * (1.0 - progress)


func _color_for_value(gate_value: int) -> Color:
	if gate_value < 0:
		return GameConfig.COLOR_GATE_NEGATIVE
	if gate_value >= 2:
		return GameConfig.COLOR_GATE_POSITIVE_STRONG
	return GameConfig.COLOR_GATE_POSITIVE


static func _format_value(gate_value: int) -> String:
	var prefix := "+" if gate_value > 0 else ""
	return "%s%d" % [prefix, gate_value]
