class_name CarEvolutionDirector
extends Node3D
## Traduce `evolution_level` nell'aspetto dell'auto.
##
## È l'unico posto in cui il livello diventa geometria: possiede il nodo dello
## stadio corrente, lo sostituisce quando il livello cambia e cura una breve
## animazione di assestamento, senza rimbalzi o lampi invasivi.
##
## Proprietà importanti:
## - **Immediato**: il modello visibile cambia nello stesso frame del segnale.
## - **Non bloccante**: l'animazione gira in `_process` e non tocca né l'input
##   né il movimento: sterzo, velocità e posizione dell'auto non vengono mai
##   modificati da questa classe (che è un figlio del CarController).
## - **Senza stato duplicato**: `current_level` è solo lo specchio di ciò che è
##   stato applicato; richiedere lo stesso livello è una no-op.
## - **Sostituibile**: i modelli arrivano da `CarModelLibrary`, quindi i
##   modelli procedurali possono essere rimpiazzati senza toccare questo file.

signal stage_ready(level: int, profile: CarEvolutionProfile)
signal transformation_finished(level: int)

## Le risorse di luce e onda restano disattivate: il feedback è affidato a
## un assestamento discreto e a un riflesso leggero sulla carrozzeria.
const FLASH_LIGHT_RANGE: float = 4.0
const FLASH_LIGHT_HEIGHT: float = 0.9
const GLOW_FLASH_GAIN: float = 0.35
const SHOCKWAVE_HEIGHT: float = 0.04
const POP_SHRINK: float = 0.96
## Piccolo assestamento verticale del modello, appena percettibile.
const HOP_HEIGHT: float = 0.025

const NODE_FLASH: String = "TransformFlash"
const NODE_SHOCKWAVE: String = "TransformShockwave"

## Nome del nodo figlio del CarController che ospita questo direttore.
## Definito qui (fonte unica): in passato viveva in CarModel, che a sua volta
## dipendeva da questa classe, creando una dipendenza circolare tra script.
const DIRECTOR_NODE_NAME: String = "CarVisual"
## Raggio ruota di ripiego quando il profilo non ne fornisce uno valido.
const WHEEL_RADIUS: float = 0.33

## Chiavi dei metadati di servizio esposti sul nodo proprietario (l'auto).
const META_BODY_MESHES: StringName = &"evolution_body_meshes"
const META_PIPS: StringName = &"evolution_pips"
const META_LEVEL: StringName = &"evolution_level"
const META_STAGE_NAME: StringName = &"evolution_stage_name"

## Libreria dei modelli: se null viene caricata quella di default del progetto.
@export var library: CarModelLibrary = null
## Disattivabile per i test o per dispositivi molto lenti.
@export var animate: bool = true

## Livello attualmente mostrato (-1 = nessun modello ancora costruito).
var current_level: int = GameConfig.EVOLUTION_MIN_LEVEL - 1
var current_profile: CarEvolutionProfile = null
var wheel_radius: float = WHEEL_RADIUS

var _stage_root: Node3D = null
var _wheels: Array[Node3D] = []
var _pips: Array = []
var _glow: Array = []
var _flash: OmniLight3D = null
var _shockwave: MeshInstance3D = null
var _shockwave_material: StandardMaterial3D = null
var _anim_time: float = -1.0
var _anim_duration: float = GameConfig.EVOLUTION_TRANSFORM_DURATION


func _ready() -> void:
	set_process(false)
	_build_effects()
	if library == null:
		library = CarModelLibrary.default_library()


## Allinea subito l'aspetto al livello richiesto, senza animazione.
func setup(level: int) -> void:
	apply_level(level, false)


## Applica il livello indicato. Se è diverso da quello mostrato, il modello
## viene sostituito subito e (se richiesto) parte l'animazione. Se è lo stesso,
## non fa nulla: niente ricostruzioni inutili, nessuna doppia animazione.
func apply_level(level: int, animated: bool = true) -> void:
	var clamped := CarEvolutionCatalog.clamp_level(level)
	if clamped == current_level and _stage_root != null and is_instance_valid(_stage_root):
		return
	_swap_stage(clamped)
	if animated and animate and _stage_root != null:
		_start_animation()
	else:
		_reset_animation()


## True se l'aspetto mostrato corrisponde già al livello indicato.
func matches_level(level: int) -> bool:
	return CarEvolutionCatalog.clamp_level(level) == current_level


func get_stage_root() -> Node3D:
	return _stage_root


func get_wheels() -> Array[Node3D]:
	return _wheels


func get_pips() -> Array:
	return _pips


## Materiali luminosi del modello corrente (lampeggiano nella trasformazione).
func get_glow_materials() -> Array:
	var materials: Array = []
	for entry in _glow:
		var glow_entry: Dictionary = entry
		var material := glow_entry.get("material", null) as StandardMaterial3D
		if material != null:
			materials.append(material)
	return materials


func stage_name() -> String:
	return current_profile.stage_name if current_profile != null else ""


func is_transforming() -> bool:
	return _anim_time >= 0.0


func transform_progress() -> float:
	if not is_transforming():
		return 0.0
	return clampf(_anim_time / _anim_duration, 0.0, 1.0)


## Avanza l'animazione di `delta` secondi. Separata da `_process` per poter
## essere pilotata in modo deterministico dai test.
func advance(delta: float) -> void:
	if not is_transforming():
		return
	_anim_time += maxf(delta, 0.0)
	var progress := clampf(_anim_time / _anim_duration, 0.0, 1.0)
	_apply_animation(progress)
	if progress >= 1.0:
		_finish_animation()


func _process(delta: float) -> void:
	advance(delta)


# ------------------------------------------------------------- Stadio -------

func _swap_stage(level: int) -> void:
	current_level = level
	current_profile = CarEvolutionCatalog.profile_for(level)

	if _stage_root != null and is_instance_valid(_stage_root):
		remove_child(_stage_root)
		_stage_root.queue_free()
	_stage_root = null
	_wheels = []
	_pips = []
	_glow = []

	if library == null:
		library = CarModelLibrary.default_library()

	var built: Dictionary = library.create_stage(current_profile)
	var root := built.get(CarModelBuilder.KEY_ROOT, null) as Node3D
	if root == null:
		push_warning("Nessun modello disponibile per il livello %d." % level)
		return

	_stage_root = root
	add_child(root)

	# Le ruote si risolvono dopo l'add_child: i gruppi esistono solo nell'albero.
	var resolved := library.resolve_wheels(root)
	if resolved.is_empty():
		resolved = _as_node_array(built.get(CarModelBuilder.KEY_WHEELS, []))
	_wheels = resolved

	_pips = _as_node_array(built.get(CarModelBuilder.KEY_PIPS, []))
	var glow_entries: Array = built.get(CarModelBuilder.KEY_GLOW_MATERIALS, [])
	if glow_entries.is_empty() and library != null:
		glow_entries = library.resolve_glow_materials(root)
	_glow = glow_entries

	wheel_radius = (
		current_profile.wheel_radius if current_profile != null else WHEEL_RADIUS
	)
	_apply_metas(built)
	stage_ready.emit(level, current_profile)


func _apply_metas(built: Dictionary) -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	# Metadati di servizio (riferimenti ai nodi + specchio del livello):
	# comodi per debug e test, ma nessuno li usa come fonte di verità.
	owner_node.set_meta(META_LEVEL, current_level)
	if current_profile != null:
		owner_node.set_meta(META_STAGE_NAME, current_profile.stage_name)
	owner_node.set_meta(META_BODY_MESHES, built.get(CarModelBuilder.KEY_BODY_MESHES, []))
	owner_node.set_meta(META_PIPS, _pips)


# ---------------------------------------------------------- Animazione ------

func _start_animation() -> void:
	var duration := GameConfig.EVOLUTION_TRANSFORM_DURATION
	if current_profile != null:
		duration = current_profile.transform_duration
	_anim_duration = maxf(duration, 0.05)
	_anim_time = 0.0
	_tint_effects()
	set_process(true)
	_apply_animation(0.0)


func _apply_animation(progress: float) -> void:
	if _stage_root == null:
		return

	# Assestamento uniforme: il modello non supera mai la sua scala normale.
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var scale_value := lerpf(POP_SHRINK, 1.0, eased)
	_stage_root.scale = Vector3.ONE * scale_value
	_stage_root.position.y = sin(progress * PI) * HOP_HEIGHT

	# Un leggero riflesso sulle parti luminose, senza lampi o onde a terra.
	var glow := pow(1.0 - progress, 2.0)
	for entry in _glow:
		var glow_entry: Dictionary = entry
		var material := glow_entry.get("material", null) as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = (
				float(glow_entry.get("base", 1.0)) * (1.0 + GLOW_FLASH_GAIN * glow)
			)

	if _flash != null:
		_flash.visible = false
		_flash.light_energy = 0.0

	if _shockwave != null and _shockwave_material != null:
		_shockwave.visible = false
		_shockwave_material.albedo_color.a = 0.0


func _finish_animation() -> void:
	_anim_time = -1.0
	_restore_model()
	set_process(false)
	transformation_finished.emit(current_level)


## Stato "a riposo": modello a scala piena, luci ed emissioni ai valori base.
func _reset_animation() -> void:
	_anim_time = -1.0
	_restore_model()
	set_process(false)


func _restore_model() -> void:
	if _stage_root != null:
		_stage_root.scale = Vector3.ONE
		_stage_root.position = Vector3.ZERO
	for entry in _glow:
		var glow_entry: Dictionary = entry
		var material := glow_entry.get("material", null) as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = float(glow_entry.get("base", 1.0))
	if _flash != null:
		_flash.visible = false
		_flash.light_energy = 0.0
	if _shockwave != null:
		_shockwave.visible = false
		_shockwave.scale = Vector3.ONE


func _tint_effects() -> void:
	var color := current_profile.glow_color if current_profile != null else Color(1.0, 1.0, 1.0)
	if _flash != null:
		_flash.light_color = color
	if _shockwave_material != null:
		_shockwave_material.albedo_color = Color(color.r, color.g, color.b, 0.0)
		_shockwave_material.emission = color


func _build_effects() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 26
	disc.rings = 1

	_shockwave_material = StandardMaterial3D.new()
	_shockwave_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	_shockwave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shockwave_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shockwave_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shockwave_material.emission_enabled = true
	_shockwave_material.emission = Color(1.0, 1.0, 1.0)
	_shockwave_material.emission_energy_multiplier = 2.0

	_shockwave = MeshInstance3D.new()
	_shockwave.name = NODE_SHOCKWAVE
	_shockwave.mesh = disc
	_shockwave.position = Vector3(0.0, SHOCKWAVE_HEIGHT, 0.0)
	_shockwave.material_override = _shockwave_material
	_shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shockwave.visible = false
	add_child(_shockwave)

	_flash = OmniLight3D.new()
	_flash.name = NODE_FLASH
	_flash.position = Vector3(0.0, FLASH_LIGHT_HEIGHT, 0.0)
	_flash.omni_range = FLASH_LIGHT_RANGE
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.visible = false
	add_child(_flash)


# -------------------------------------------------------------- Helper ------

static func _as_node_array(values: Variant) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if values == null or not (values is Array):
		return nodes
	for value in values as Array:
		var node := value as Node3D
		if node != null:
			nodes.append(node)
	return nodes


## Cerca il direttore a partire da un nodo dell'auto (o dal suo genitore).
static func find_on(car: Node) -> CarEvolutionDirector:
	if car == null:
		return null
	var found := car.get_node_or_null(DIRECTOR_NODE_NAME) as CarEvolutionDirector
	if found != null:
		return found
	return car as CarEvolutionDirector
