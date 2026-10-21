class_name CarEvolutionDirector
extends Node3D
## Coordina l'evoluzione di stadio e la personalizzazione modulare dell'auto.
##
## Mantiene un unico `VehicleRig` persistente per tutta la vita del veicolo:
##   - `equip_part()` / `equip_part_by_id()` sostituiscono un singolo componente
##     (`CarPartDefinition`) senza ricostruire la gerarchia né azzerare i perni
##     delle ruote o il moto in corso;
##   - `apply_level()` aggiorna il rig all'assetto dello stadio richiesto
##     preservando eventuali componenti personalizzati compatibili fissati con
##     `pin_across_stages = true`, e avvia il feedback visivo non bloccante.

signal stage_ready(level: int, profile: CarEvolutionProfile)
signal part_changed(slot: int, part: CarPartDefinition)
signal transformation_finished(level: int)

const FLASH_LIGHT_ENERGY: float = 3.4
const FLASH_LIGHT_RANGE: float = 6.0
const FLASH_LIGHT_HEIGHT: float = 0.9
const GLOW_FLASH_GAIN: float = 2.2
const SHOCKWAVE_START: float = 0.55
const SHOCKWAVE_END: float = 2.45
const SHOCKWAVE_ALPHA: float = 0.50
const SHOCKWAVE_HEIGHT: float = 0.06
const POP_SHRINK: float = 0.58
const POP_OVERSHOOT: float = 1.14
const POP_SPLIT: float = 0.42
const SQUASH_AMOUNT: float = 0.16
const HOP_HEIGHT: float = 0.09

const NODE_FLASH: String = "TransformFlash"
const NODE_SHOCKWAVE: String = "TransformShockwave"
const DIRECTOR_NODE_NAME: String = "CarVisual"
const WHEEL_RADIUS: float = 0.33

const META_BODY_MESHES: StringName = &"evolution_body_meshes"
const META_PIPS: StringName = &"evolution_pips"
const META_LEVEL: StringName = &"evolution_level"
const META_STAGE_NAME: StringName = &"evolution_stage_name"
const META_EQUIPPED_PARTS: StringName = &"equipped_part_ids"

@export var library: CarModelLibrary = null
@export var animate: bool = true

var current_level: int = GameConfig.EVOLUTION_MIN_LEVEL - 1
var current_profile: CarEvolutionProfile = null
var wheel_radius: float = WHEEL_RADIUS

var _rig: VehicleRig = null
var _external_stage_root: Node3D = null
var _pinned_custom_parts: Dictionary = {}
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


func setup(level: int) -> void:
	apply_level(level, false)


func apply_level(level: int, animated: bool = true) -> void:
	var clamped := CarEvolutionCatalog.clamp_level(level)
	var active_visual := get_stage_root()
	if clamped == current_level and active_visual != null and is_instance_valid(active_visual):
		return
	_apply_stage(clamped)
	if animated and animate and get_stage_root() != null:
		_start_animation()
	else:
		_reset_animation()


## Monta un singolo componente `CarPartDefinition` sul rig persistente senza
## ricostruire il resto del veicolo. Restituisce `{ok, changed, reason, message}`.
func equip_part(
	part: CarPartDefinition,
	enforce_level: bool = false,
	pin_across_stages: bool = false,
) -> Dictionary:
	_ensure_rig_initialized()
	var effective_lvl := maxi(current_level, GameConfig.EVOLUTION_MIN_LEVEL)
	var result := _rig.equip_part(part, effective_lvl, enforce_level)
	if not bool(result["ok"]):
		return result
	if pin_across_stages and part != null:
		_pinned_custom_parts[part.slot] = part
	_sync_from_rig()
	if bool(result.get("changed", false)):
		part_changed.emit(part.slot, part)
	return result


## Variante basata su identificativo dati (`StringName`), es. `&"spoiler_gt_wing"`.
func equip_part_by_id(
	part_id: StringName,
	enforce_level: bool = false,
	pin_across_stages: bool = false,
) -> Dictionary:
	var part := CarPartRegistry.part_by_id(part_id)
	return equip_part(part, enforce_level, pin_across_stages)


func clear_custom_parts(reapply_stage: bool = true) -> void:
	_pinned_custom_parts.clear()
	if reapply_stage and current_level >= GameConfig.EVOLUTION_MIN_LEVEL:
		var lvl := current_level
		current_level = GameConfig.EVOLUTION_MIN_LEVEL - 1
		apply_level(lvl, false)


func get_rig() -> VehicleRig:
	return _rig


func get_equipped_part(slot: int) -> CarPartDefinition:
	return _rig.get_equipped_part(slot) if _rig != null else null


func get_equipped_part_id(slot: int) -> StringName:
	return _rig.get_equipped_part_id(slot) if _rig != null else &""


func get_slot_visual(slot: int) -> Node3D:
	return _rig.get_slot_visual(slot) if _rig != null else null


func effective_stats() -> Dictionary:
	if _rig != null:
		return _rig.effective_stats()
	return CarStatsAggregator.compute(current_profile, {})


func matches_level(level: int) -> bool:
	return CarEvolutionCatalog.clamp_level(level) == current_level


func get_stage_root() -> Node3D:
	if _external_stage_root != null and is_instance_valid(_external_stage_root):
		return _external_stage_root
	return _rig


func get_wheels() -> Array[Node3D]:
	return _wheels


func get_pips() -> Array:
	return _pips


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

func _ensure_rig_initialized() -> void:
	if _rig == null or not is_instance_valid(_rig):
		_rig = VehicleRig.new()
		_rig.name = "VehicleRig"
		add_child(_rig)
		_rig.ensure_structure()
	if current_profile == null:
		var start_lvl := maxi(current_level, GameConfig.EVOLUTION_START_LEVEL)
		current_level = start_lvl
		current_profile = CarEvolutionCatalog.profile_for(start_lvl)
		_rig.apply_loadout(
			CarPartRegistry.loadout_for_stage(start_lvl),
			current_profile,
			_pinned_custom_parts,
			start_lvl,
			false,
		)
		_sync_from_rig()


func _apply_stage(level: int) -> void:
	current_level = level
	current_profile = CarEvolutionCatalog.profile_for(level)

	if library == null:
		library = CarModelLibrary.default_library()

	# Supporto opzionale a una scena monolitica esterna registrata in libreria.
	var ext_scene := library.scene_for_level(level)
	if ext_scene == null and current_profile != null:
		ext_scene = current_profile.model_scene

	if ext_scene != null and ext_scene.can_instantiate():
		if _rig != null and is_instance_valid(_rig):
			_rig.visible = false
		if _external_stage_root != null and is_instance_valid(_external_stage_root):
			remove_child(_external_stage_root)
			_external_stage_root.free()
		_external_stage_root = ext_scene.instantiate() as Node3D
		if _external_stage_root != null:
			_external_stage_root.name = "ExternalStage_%d" % level
			add_child(_external_stage_root)
			_wheels = library.resolve_wheels(_external_stage_root)
			_pips = []
			_glow = library.resolve_glow_materials(_external_stage_root)
			wheel_radius = current_profile.wheel_radius
			_apply_metas([])
			stage_ready.emit(level, current_profile)
			return

	if _external_stage_root != null and is_instance_valid(_external_stage_root):
		remove_child(_external_stage_root)
		_external_stage_root.free()
	_external_stage_root = null

	if _rig == null or not is_instance_valid(_rig):
		_rig = VehicleRig.new()
		_rig.name = "VehicleRig"
		add_child(_rig)
	_rig.visible = true
	_rig.apply_loadout(
		CarPartRegistry.loadout_for_stage(level),
		current_profile,
		_pinned_custom_parts,
		level,
		true,
	)
	_sync_from_rig()
	stage_ready.emit(level, current_profile)


func _sync_from_rig() -> void:
	if _rig == null:
		return
	_wheels = _rig.get_wheel_hubs()
	_pips = _rig.get_pips()
	_glow = _rig.get_glow_entries()
	var stats := _rig.effective_stats()
	wheel_radius = float(stats.get("wheel_radius", WHEEL_RADIUS))
	_apply_metas(_rig.get_paint_meshes())


func _apply_metas(paint_meshes: Array) -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	owner_node.set_meta(META_LEVEL, current_level)
	if current_profile != null:
		owner_node.set_meta(META_STAGE_NAME, current_profile.stage_name)
	owner_node.set_meta(META_BODY_MESHES, paint_meshes)
	owner_node.set_meta(META_PIPS, _pips)
	if _rig != null:
		var ids: Dictionary = {}
		var eq := _rig.equipped_parts()
		for slot in eq.keys():
			var p := eq[slot] as CarPartDefinition
			if p != null:
				ids[CarPartSlot.slug(int(slot))] = p.id
		owner_node.set_meta(META_EQUIPPED_PARTS, ids)


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
	var target := get_stage_root()
	if target == null:
		return

	var pop := POP_OVERSHOOT
	if progress < POP_SPLIT:
		var k := progress / POP_SPLIT
		pop = lerpf(POP_SHRINK, POP_OVERSHOOT, 1.0 - pow(1.0 - k, 3.0))
	else:
		var k := (progress - POP_SPLIT) / (1.0 - POP_SPLIT)
		pop = lerpf(POP_OVERSHOOT, 1.0, 1.0 - pow(1.0 - k, 3.0))
	var squash := sin(progress * PI) * SQUASH_AMOUNT
	target.scale = Vector3(
		pop * (1.0 + squash * 0.5),
		pop * (1.0 - squash),
		pop * (1.0 + squash * 0.5),
	)
	target.position.y = sin(progress * PI) * HOP_HEIGHT

	var flash := pow(1.0 - progress, 2.0)
	for entry in _glow:
		var glow_entry: Dictionary = entry
		var material := glow_entry.get("material", null) as StandardMaterial3D
		if material != null:
			material.emission_energy_multiplier = (
				float(glow_entry.get("base", 1.0)) * (1.0 + GLOW_FLASH_GAIN * flash)
			)

	if _flash != null:
		_flash.visible = true
		_flash.light_energy = FLASH_LIGHT_ENERGY * flash

	if _shockwave != null and _shockwave_material != null:
		_shockwave.visible = true
		var radius := lerpf(SHOCKWAVE_START, SHOCKWAVE_END, progress)
		_shockwave.scale = Vector3(radius, 1.0, radius)
		_shockwave_material.albedo_color.a = SHOCKWAVE_ALPHA * pow(1.0 - progress, 1.5)


func _finish_animation() -> void:
	_anim_time = -1.0
	_restore_model()
	set_process(false)
	transformation_finished.emit(current_level)


func _reset_animation() -> void:
	_anim_time = -1.0
	_restore_model()
	set_process(false)


func _restore_model() -> void:
	var target := get_stage_root()
	if target != null:
		target.scale = Vector3.ONE
		target.position = Vector3.ZERO
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
	var color := (
		current_profile.glow_color if current_profile != null else Color(1.0, 1.0, 1.0)
	)
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


static func find_on(car: Node) -> CarEvolutionDirector:
	if car == null:
		return null
	var found := car.get_node_or_null(DIRECTOR_NODE_NAME) as CarEvolutionDirector
	if found != null:
		return found
	return car as CarEvolutionDirector
