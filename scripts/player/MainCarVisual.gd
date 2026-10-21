@tool
class_name MainCarVisual
extends Node3D
## Scena dedicata all'auto principale: contiene il solo `VehicleRig` modulare,
## senza logica di guida (`CarController`).
##
## Permette di cambiare stadio evolutivo (`level`), assegnare un `CarLoadout`
## personalizzato o sostituire singoli componenti (`equip_part()` /
## `equip_part_by_id()`) senza ricostruire l'intera gerarchia del veicolo.

@export_range(0, 5, 1) var level: int = 1:
	set(value):
		level = clampi(value, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
		if is_inside_tree():
			rebuild()

@export var custom_loadout: CarLoadout = null:
	set(value):
		custom_loadout = value
		if is_inside_tree():
			rebuild()

## Alias retrocompatibile che punta al `VehicleRig` persistente.
var stage_root: Node3D = null

var _rig: VehicleRig = null
var _wheels: Array = []


func _ready() -> void:
	rebuild()


func set_level(new_level: int) -> void:
	level = new_level


func profile() -> CarEvolutionProfile:
	return CarEvolutionCatalog.profile_for(level)


func get_rig() -> VehicleRig:
	return _rig


func get_wheels() -> Array:
	return _wheels


func equip_part(part: CarPartDefinition, enforce_level: bool = false) -> Dictionary:
	if _rig == null:
		rebuild()
	var res := _rig.equip_part(part, level, enforce_level)
	_wheels = _rig.get_wheel_hubs()
	return res


func equip_part_by_id(part_id: StringName, enforce_level: bool = false) -> Dictionary:
	return equip_part(CarPartRegistry.part_by_id(part_id), enforce_level)


func get_equipped_part(slot: int) -> CarPartDefinition:
	return _rig.get_equipped_part(slot) if _rig != null else null


func rebuild() -> void:
	if _rig == null or not is_instance_valid(_rig):
		_rig = VehicleRig.new()
		_rig.name = "VehicleRig"
		add_child(_rig)
	var active_loadout := (
		custom_loadout if custom_loadout != null else CarPartRegistry.loadout_for_stage(level)
	)
	_rig.apply_loadout(active_loadout, profile())
	stage_root = _rig
	_wheels = _rig.get_wheel_hubs()
