@tool
class_name SceneryProp
extends Node3D
## Base comune degli oggetti dello scenario (vegetazione, rocce, arredi).
##
## Ogni oggetto è una **scena riutilizzabile**: la geometria viene generata una
## volta sola e condivisa da tutte le istanze della stessa variante (cache
## statica nello script), mentre scala, rotazione e colore cambiano da
## istanza a istanza. Il livello dimostrativo è quindi composto da questi
## oggetti, non da un unico script che costruisce la mappa.
##
## Parametri esposti (comuni):
## - `variant`: quale "sagoma" della specie usare (0..n-1);
## - `prop_seed`: variazione deterministica di dettagli e colori;
## - `shadow_casting`: ombra proiettata (spenta sugli oggetti lontani);
## - `view_distance`: distanza oltre la quale l'oggetto non viene disegnato
##   (LOD di visibilità a costo zero, utile su mobile).

@export var variant: int = 0
@export var prop_seed: int = 0
@export var shadow_casting: bool = true
@export var view_distance: float = 210.0
## Solo gli oggetti entro questa distanza dalla pista proiettano ombre:
## il sole è posizionato in modo che quelle dei filari lontani non arrivino
## mai in carreggiata, quindi il budget ombre resta minimo su mobile.
@export var shadow_range: float = 26.0

## Meta con cui il piano di scenografia segnala la quota del terreno.
const META_GROUND_Y: StringName = &"scenery_ground_y"


func _ready() -> void:
	if get_child_count() == 0:
		rebuild()


## Libera i figli generati e ricostruisce l'oggetto.
func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build()


## Da implementare nelle sottoclassi: crea i figli dell'oggetto.
func build() -> void:
	pass


## Generatore deterministico legato a variante e seme dell'istanza.
func seeded_rng(salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d_%d_%d" % [variant, prop_seed, salt])
	return rng


## Aggiunge una MeshInstance3D con materiale e trasformazione.
func add_mesh(
	node_name: String,
	mesh: Mesh,
	material: Material,
	xform: Transform3D = Transform3D.IDENTITY,
	view_range: float = -1.0,
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.transform = xform
	var casts := shadow_casting and absf(global_position.x) <= shadow_range
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if casts
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	var distance := view_distance if view_range < 0.0 else view_range
	if distance > 0.0:
		instance.visibility_range_end = distance
	add_child(instance)
	return instance


## Aggiunge una mesh da un accumulatore `PropMeshes`.
func add_accumulated(
	node_name: String,
	acc: Dictionary,
	material: Material,
	xform: Transform3D = Transform3D.IDENTITY,
	flat: bool = false,
	view_range: float = -1.0,
) -> MeshInstance3D:
	return add_mesh(node_name, PropMeshes.to_mesh(acc, flat), material, xform, view_range)
