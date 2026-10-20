class_name CarModelLibrary
extends Resource
## Punto unico di sostituzione dei modelli provvisori.
##
## `create_stage()` chiede il modello di un livello e decide così:
##   1. se `model_scenes[livello]` contiene una scena (es. un .glb importato)
##      la istanzia e la usa al posto del blockout;
##   2. altrimenti costruisce il modello provvisorio con `CarModelBuilder`.
##
## In questo modo, quando arriveranno i modelli definitivi, basterà compilare
## questa risorsa (`config/car_model_library.tres`) o impostare
## `CarEvolutionProfile.model_scene`: la logica di evoluzione, i cancelli,
## l'HUD e i test continuano a funzionare senza modifiche.

const DEFAULT_LIBRARY_PATH: String = "res://config/car_model_library.tres"
## Gruppo con cui un modello definitivo può segnalare le proprie ruote.
const WHEEL_GROUP: StringName = &"car_wheel"
## Prefisso dei nodi ruota cercati in alternativa al gruppo.
const WHEEL_NAME_PREFIX: String = "Wheel"

## Una scena per livello (indice = livello - GameConfig.EVOLUTION_MIN_LEVEL).
## Lasciare vuoto uno slot significa "usa il blockout procedurale".
@export var model_scenes: Array[PackedScene] = []


static func default_library() -> CarModelLibrary:
	var library := load(DEFAULT_LIBRARY_PATH) as CarModelLibrary
	if library == null:
		library = CarModelLibrary.new()
	return library


func scene_for_level(level: int) -> PackedScene:
	var index: int = level - GameConfig.EVOLUTION_MIN_LEVEL
	if index < 0 or index >= model_scenes.size():
		return null
	return model_scenes[index] as PackedScene


## Crea il modello dello stadio richiesto.
## Restituisce sempre lo stesso formato (vedi CarModelBuilder.build()), che il
## modello arrivi da una scena esterna o dal blockout procedurale.
func create_stage(profile: CarEvolutionProfile) -> Dictionary:
	if profile == null:
		return {}

	var scene := scene_for_level(profile.level)
	if scene != null and scene.can_instantiate():
		var instance := scene.instantiate() as Node3D
		if instance != null:
			instance.name = "Stage_%d" % profile.level
			return {
				CarModelBuilder.KEY_ROOT: instance,
				CarModelBuilder.KEY_WHEELS: [],
				CarModelBuilder.KEY_BODY_MESHES: [],
				CarModelBuilder.KEY_PIPS: [],
				CarModelBuilder.KEY_GLOW_MATERIALS: [],
			}
		push_warning(
			"Modello del livello %d non istanziabile: uso il blockout." % profile.level
		)

	return CarModelBuilder.build(profile)


## Individua le ruote di un modello, da chiamare DOPO che la radice è stata
## aggiunta alla scena (i gruppi di Godot esistono solo dentro l'albero).
## Cerca prima il gruppo `car_wheel`, poi i nodi che iniziano per "Wheel".
func resolve_wheels(root: Node3D) -> Array[Node3D]:
	var wheels: Array[Node3D] = []
	if root == null:
		return wheels

	if root.is_inside_tree():
		var tree := root.get_tree()
		if tree != null:
			for node in tree.get_nodes_in_group(WHEEL_GROUP):
				if node == root or root.is_ancestor_of(node):
					var wheel := node as Node3D
					if wheel != null:
						wheels.append(wheel)
	if not wheels.is_empty():
		return wheels

	_collect_wheels_by_name(root, wheels)
	return wheels


## Materiali emissivi di un modello esterno, da chiamare dopo l'aggiunta
## all'albero: il direttore li fa lampeggiare durante la trasformazione.
func resolve_glow_materials(root: Node3D) -> Array:
	if root == null:
		return []
	return _collect_glow_materials(root)


# ---------------------------------------------------------------- Helper ---

static func _collect_wheels_by_name(node: Node, wheels: Array) -> void:
	for child in node.get_children():
		if child is Node3D and String(child.name).begins_with(WHEEL_NAME_PREFIX):
			wheels.append(child as Node3D)
		else:
			_collect_wheels_by_name(child, wheels)


static func _collect_glow_materials(node: Node) -> Array:
	var entries: Array = []
	var seen: Array = []
	for child in node.get_children():
		var instance := child as MeshInstance3D
		if instance != null:
			var material := instance.material_override as StandardMaterial3D
			if material != null and material.emission_enabled and not seen.has(material):
				seen.append(material)
				entries.append({
					"material": material,
					"base": material.emission_energy_multiplier,
				})
			continue
		for entry in _collect_glow_materials(child):
			var glow_entry: Dictionary = entry
			var glow_material := glow_entry.get("material", null)
			if glow_material != null and not seen.has(glow_material):
				seen.append(glow_material)
				entries.append(glow_entry)
	return entries
