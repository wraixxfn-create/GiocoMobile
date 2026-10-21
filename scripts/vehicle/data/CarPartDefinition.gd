class_name CarPartDefinition
extends Resource
## Definizione dati completa di UN componente sostituibile dell'automobile.
##
## Ogni istanza (salvata come risorsa `.tres` in `res://config/parts/`) descrive
## identificativo univoco, slot funzionale, livello richiesto di evoluzione,
## eventuale rarità statica, modello 3D esterno opzionale (`PackedScene`),
## offset di montaggio, compatibilità, modificatori di gameplay e metadati di
## stato prototipale per la futura sostituzione artistica in Blender.

@export_group("Identità")
@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: int = CarPartSlot.Type.BODY
@export_range(0, 5, 1) var required_level: int = 0
@export var rarity: int = CarPartRarity.Tier.COMMON

@export_group("Modello 3D e montaggio")
## Modello 3D dedicato opzionale (es. wrapper `.tscn` di un `.glb` Blender).
## Se `null`, il sistema genera il prototipo modulare da `visual_spec`.
@export var model_scene: PackedScene = null
@export var mount_offset: Vector3 = Vector3.ZERO
@export var mount_rotation_degrees: Vector3 = Vector3.ZERO

@export_group("Regole e gameplay")
@export var modifiers: CarGameplayModifiers = null
@export var compatibility: CarPartCompatibility = null
@export var visual_spec: CarPartVisualSpec = null

@export_group("Stato asset")
@export var is_procedural_prototype: bool = true
@export_multiline var asset_upgrade_notes: String = ""


func resolved_modifiers() -> CarGameplayModifiers:
	return modifiers if modifiers != null else CarGameplayModifiers.new()


func resolved_compatibility() -> CarPartCompatibility:
	return compatibility if compatibility != null else CarPartCompatibility.new()


func resolved_visual_spec() -> CarPartVisualSpec:
	return visual_spec if visual_spec != null else CarPartVisualSpec.new()
