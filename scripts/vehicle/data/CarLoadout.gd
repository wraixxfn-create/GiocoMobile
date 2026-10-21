class_name CarLoadout
extends Resource
## Configurazione modulare completa dell'auto (uno slot per ogni componente).
##
## Può rappresentare sia la dotazione canonica di uno stadio evolutivo (salvata
## in `res://config/loadouts/stage_*.tres`), sia un assetto personalizzato a
## runtime senza duplicare né ricostruire la gerarchia del veicolo.

@export var id: StringName = &"default"
@export var display_name: String = "Assetto Base"
@export_range(0, 5, 1) var stage_level: int = 1

@export_group("Componenti per slot")
@export var body: CarPartDefinition = null
@export var bumper_front: CarPartDefinition = null
@export var bumper_rear: CarPartDefinition = null
@export var wheels: CarPartDefinition = null
@export var engine: CarPartDefinition = null
@export var exhaust: CarPartDefinition = null
@export var spoiler: CarPartDefinition = null
@export var aero: CarPartDefinition = null


func get_part(slot: int) -> CarPartDefinition:
	match slot:
		CarPartSlot.Type.BODY:
			return body
		CarPartSlot.Type.BUMPER_FRONT:
			return bumper_front
		CarPartSlot.Type.BUMPER_REAR:
			return bumper_rear
		CarPartSlot.Type.WHEELS:
			return wheels
		CarPartSlot.Type.ENGINE:
			return engine
		CarPartSlot.Type.EXHAUST:
			return exhaust
		CarPartSlot.Type.SPOILER:
			return spoiler
		CarPartSlot.Type.AERO:
			return aero
		_:
			return null


func set_part(slot: int, part: CarPartDefinition) -> void:
	match slot:
		CarPartSlot.Type.BODY:
			body = part
		CarPartSlot.Type.BUMPER_FRONT:
			bumper_front = part
		CarPartSlot.Type.BUMPER_REAR:
			bumper_rear = part
		CarPartSlot.Type.WHEELS:
			wheels = part
		CarPartSlot.Type.ENGINE:
			engine = part
		CarPartSlot.Type.EXHAUST:
			exhaust = part
		CarPartSlot.Type.SPOILER:
			spoiler = part
		CarPartSlot.Type.AERO:
			aero = part


func equipped_map() -> Dictionary:
	var result: Dictionary = {}
	for slot in CarPartSlot.ALL:
		var part := get_part(slot)
		if part != null:
			result[slot] = part
	return result


func duplicate_loadout() -> CarLoadout:
	var copy := CarLoadout.new()
	copy.id = id
	copy.display_name = display_name
	copy.stage_level = stage_level
	for slot in CarPartSlot.ALL:
		copy.set_part(slot, get_part(slot))
	return copy
