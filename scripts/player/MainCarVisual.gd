@tool
class_name MainCarVisual
extends Node3D
## Scena dedicata all'auto principale: contiene solo il modello visivo,
## nessuna logica di guida (che resta in `CarController`/`Car.tscn`).
##
## Il modello è generato da `CarModelBuilder` a partire dal profilo del
## livello scelto: stessa fonte di verità del gioco, nessuna geometria
## duplicata. In editor il modello è visibile e cambia muovendo `level`
## nell'inspector; i nodi generati non hanno owner, quindi non vengono
## mai salvati dentro la scena.
##
## Uso tipico: ispezione dell'asset, scena di presentazione
## (`scenes/CarShowroom.tscn`), futuri garage/negozi.

## Livello di evoluzione mostrato. L'intervallo segue GameConfig
## (EVOLUTION_MIN_LEVEL..EVOLUTION_MAX_LEVEL, oggi 0..5).
@export_range(0, 5, 1) var level: int = 1:
	set(value):
		level = clampi(value, GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL)
		if is_inside_tree():
			rebuild()

## Radice del modello generato (Stage_N), per chi deve animarlo dall'esterno.
var stage_root: Node3D = null

var _wheels: Array = []


func _ready() -> void:
	rebuild()


## Cambia il livello mostrato e ricostruisce il modello.
func set_level(new_level: int) -> void:
	level = new_level


## Profilo (dati) dello stadio attualmente mostrato.
func profile() -> CarEvolutionProfile:
	return CarEvolutionCatalog.profile_for(level)


## Perni delle ruote del modello corrente (stesso ordine del gioco:
## anteriori prima, poi posteriori). Vuoto finché non è stato costruito.
func get_wheels() -> Array:
	return _wheels


## (Ri)costruisce il modello del livello corrente, liberando il precedente.
func rebuild() -> void:
	if stage_root != null and is_instance_valid(stage_root):
		remove_child(stage_root)
		stage_root.queue_free()
	stage_root = null
	_wheels = []
	var built := CarModelBuilder.build(profile())
	stage_root = built.get(CarModelBuilder.KEY_ROOT, null) as Node3D
	if stage_root == null:
		return
	_wheels = built.get(CarModelBuilder.KEY_WHEELS, [])
	add_child(stage_root)
