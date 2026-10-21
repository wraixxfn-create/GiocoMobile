class_name FinishLine
extends Node3D
## Traguardo 3D della corsa: striscia a scacchiera sull'asfalto, due piloni e
## un arco con la scritta "TRAGUARDO".
##
## È puramente decorativo: la vittoria resta decisa da `GameManager` in base
## alla distanza percorsa. `GameRoot` lo posiziona all'inizio di ogni corsa,
## quindi non interferisce con il riciclo della pista.
##
## Tutto è costruito con primitive e una piccola texture a scacchiera generata
## a runtime: nessun asset esterno e costo trascurabile su mobile.

const STRIP_DEPTH: float = 1.5
const POST_WIDTH: float = 0.32
const POST_HEIGHT: float = 5.0
const BANNER_HEIGHT: float = 0.92
const BANNER_DEPTH: float = 0.24
const ACCENT_HEIGHT: float = 0.10
const LABEL_FONT_SIZE: int = 96
const LABEL_PIXEL_SIZE: float = 0.0125
const PULSE_SPEED: float = 2.2
const GOLD_ENERGY_BASE: float = 0.40
const GOLD_ENERGY_PULSE: float = 0.22

var _visual: Node3D = null
var _gold_material: StandardMaterial3D = null
var _pulse_time: float = 0.0


func _ready() -> void:
	_build()


## Posiziona il traguardo sul piano Z della corsa (misure mondo).
func setup(finish_z: float) -> void:
	position.z = finish_z
	visible = true


func _process(delta: float) -> void:
	if _gold_material == null:
		set_process(false)
		return
	_pulse_time += maxf(delta, 0.0)
	var pulse := 0.5 + 0.5 * sin(_pulse_time * PULSE_SPEED)
	_gold_material.emission_energy_multiplier = GOLD_ENERGY_BASE + GOLD_ENERGY_PULSE * pulse


func _build() -> void:
	if _visual != null and is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()

	_gold_material = MaterialFactory.finish_gold().duplicate() as StandardMaterial3D
	_gold_material.emission_energy_multiplier = GOLD_ENERGY_BASE

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var half_track := GameConfig.TRACK_WIDTH * 0.5

	# 1) Striscia a scacchiera sull'asfalto.
	_visual.add_child(_box(
		Vector3(GameConfig.TRACK_WIDTH, 0.025, STRIP_DEPTH),
		Vector3(0.0, 0.02, 0.0),
		MaterialFactory.checker_material(8),
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
	))
	# 2) Due linee dorate ai lati della scacchiera: il traguardo "brilla" appena.
	for side in [-1.0, 1.0]:
		_visual.add_child(_box(
			Vector3(GameConfig.TRACK_WIDTH, 0.02, 0.10),
			Vector3(0.0, 0.028, side * (STRIP_DEPTH * 0.5 + 0.06)),
			_gold_material,
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		))

	var post_x := half_track + GameConfig.CURB_WIDTH + 0.55
	for side in [-1.0, 1.0]:
		# Pilone bianco con anima scura: contrasto netto con il verde.
		_visual.add_child(_box(
			Vector3(POST_WIDTH, POST_HEIGHT, POST_WIDTH),
			Vector3(side * post_x, POST_HEIGHT * 0.5, 0.0),
			MaterialFactory.colored("finish_post", GameConfig.COLOR_FINISH_LIGHT, 0.45, 0.10),
		))
		_visual.add_child(_box(
			Vector3(POST_WIDTH + 0.10, 0.55, POST_WIDTH + 0.10),
			Vector3(side * post_x, 0.28, 0.0),
			MaterialFactory.finish_gold(),
		))
		# Fascia a scacchiera sul pilone.
		_visual.add_child(_box(
			Vector3(POST_WIDTH + 0.05, 0.9, POST_WIDTH + 0.05),
			Vector3(side * post_x, POST_HEIGHT - 1.35, 0.0),
			MaterialFactory.checker_material(4),
		))

	# 3) Arco superiore con la scacchiera.
	var banner_width := post_x * 2.0 + POST_WIDTH
	_visual.add_child(_box(
		Vector3(banner_width, BANNER_HEIGHT, BANNER_DEPTH),
		Vector3(0.0, POST_HEIGHT - BANNER_HEIGHT * 0.5, 0.0),
		MaterialFactory.checker_material(16),
	))
	# Cornice dorata sotto e sopra il banner.
	for offset in [-1.0, 1.0]:
		_visual.add_child(_box(
			Vector3(banner_width + 0.08, ACCENT_HEIGHT, BANNER_DEPTH + 0.06),
			Vector3(
				0.0,
				POST_HEIGHT - BANNER_HEIGHT * 0.5 + offset * (BANNER_HEIGHT * 0.5 + 0.05),
				0.0,
			),
			_gold_material,
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		))

	# 4) Scritta sopra l'arco, sempre rivolta alla telecamera.
	var label := Label3D.new()
	label.name = "FinishLabel"
	label.text = "TRAGUARDO"
	label.font_size = LABEL_FONT_SIZE
	label.pixel_size = LABEL_PIXEL_SIZE
	label.outline_size = 34
	label.outline_modulate = Color(0.04, 0.06, 0.10, 0.95)
	label.modulate = GameConfig.COLOR_FINISH_GOLD.lightened(0.25)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, POST_HEIGHT + 0.55, 0.0)
	_visual.add_child(label)

	set_process(true)


func _box(
	size: Vector3,
	box_position: Vector3,
	material: Material,
	shadow: int = 1,  # GeometryInstance3D.SHADOW_CASTING_SETTING_ON
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = box_position
	instance.material_override = material
	instance.cast_shadow = shadow
	return instance
