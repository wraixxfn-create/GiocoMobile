class_name CarPartRegistry
extends RefCounted
## Registro centrale in sola lettura delle risorse `CarPartDefinition` e `CarLoadout`.
##
## Carica il database serializzato `res://config/car_part_catalog.tres`, indicizza
## le parti per `id` (`StringName`) e per `CarPartSlot.Type`, e fornisce report
## espliciti sugli asset ancora in stato di prototipo procedurale.

const DEFAULT_CATALOG_PATH: String = "res://config/car_part_catalog.tres"

static var _by_id: Dictionary = {}
static var _by_slot: Dictionary = {}
static var _stage_loadouts: Dictionary = {}
static var _loaded: bool = false


static func ensure_loaded() -> void:
	if _loaded:
		return
	reload()


static func reload() -> void:
	_by_id.clear()
	_by_slot.clear()
	_stage_loadouts.clear()
	for slot in CarPartSlot.ALL:
		_by_slot[slot] = [] as Array[CarPartDefinition]

	var catalog := load(DEFAULT_CATALOG_PATH) as CarPartCatalogResource
	if catalog != null:
		for item in catalog.parts:
			register_part(item as CarPartDefinition)
		for loadout_res in catalog.stage_loadouts:
			var loadout := loadout_res as CarLoadout
			if loadout != null:
				_stage_loadouts[loadout.stage_level] = loadout
				# Registra anche eventuali parti referenziate solo dall'assetto.
				for slot in CarPartSlot.ALL:
					register_part(loadout.get_part(slot))
	_loaded = true


static func register_part(part: CarPartDefinition) -> void:
	if part == null or part.id == &"":
		return
	if not _by_slot.has(part.slot):
		_by_slot[part.slot] = [] as Array[CarPartDefinition]
	_by_id[part.id] = part
	var bucket: Array[CarPartDefinition] = _by_slot[part.slot]
	for i in bucket.size():
		if bucket[i].id == part.id:
			bucket[i] = part
			return
	bucket.append(part)


static func part_by_id(part_id: StringName) -> CarPartDefinition:
	ensure_loaded()
	return _by_id.get(part_id, null) as CarPartDefinition


static func has_part(part_id: StringName) -> bool:
	ensure_loaded()
	return _by_id.has(part_id)


static func parts_for_slot(slot: int) -> Array[CarPartDefinition]:
	ensure_loaded()
	var result: Array[CarPartDefinition] = []
	if _by_slot.has(slot):
		result.assign(_by_slot[slot])
	return result


static func all_parts() -> Array[CarPartDefinition]:
	ensure_loaded()
	var result: Array[CarPartDefinition] = []
	for slot in CarPartSlot.ALL:
		for part in parts_for_slot(slot):
			result.append(part)
	return result


static func loadout_for_stage(level: int) -> CarLoadout:
	ensure_loaded()
	var clamped := CarEvolutionCatalog.clamp_level(level)
	var found := _stage_loadouts.get(clamped, null) as CarLoadout
	if found != null:
		return found.duplicate_loadout()
	return CarLoadout.new()


static func compatible_parts_for_slot(
	slot: int,
	body_part: CarPartDefinition,
	sockets: CarBodySockets,
	equipped_parts: Dictionary,
	current_level: int = 99,
	enforce_level: bool = false,
) -> Array[CarPartDefinition]:
	var valid: Array[CarPartDefinition] = []
	for candidate in parts_for_slot(slot):
		var check := CarCompatibilityValidator.validate(
			candidate,
			body_part,
			sockets,
			equipped_parts,
			current_level,
			enforce_level,
		)
		if bool(check["ok"]):
			valid.append(candidate)
	return valid


## Elenco dei componenti attualmente generati come prototipi procedurali
## (`model_scene == null` e `is_procedural_prototype == true`), pronti per essere
## rimpiazzati in seguito da asset `.glb`/`.tscn` modellati a mano.
static func prototype_parts() -> Array[CarPartDefinition]:
	var out: Array[CarPartDefinition] = []
	for part in all_parts():
		if part.model_scene == null and part.is_procedural_prototype:
			out.append(part)
	return out
