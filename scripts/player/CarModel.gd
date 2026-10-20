class_name CarModel
extends RefCounted
## Compatibilità con le chiamate storiche del modello dell'auto.
##
## La geometria non vive più qui: ogni stadio è descritto da un
## `CarEvolutionProfile` (dati), costruito da `CarModelBuilder` (blockout
## procedurale oppure scena esterna via `CarModelLibrary`) e mostrato da
## `CarEvolutionDirector` (che è il nodo "CarVisual" figlio del CarController).
##
## Questo file resta come sottile strato di compatibilità: le chiamate a
## `apply_evolution_level()` continuano a funzionare e diventano semplicemente
## "allinea il modello al livello richiesto", senza duplicare stati.

## Nome del nodo figlio che ospita il modello visibile.
const DIRECTOR_NODE_NAME: String = "CarVisual"

## Costanti di ingombro della taratura di base (usate come fallback).
const WHEEL_RADIUS: float = 0.33
const WHEEL_WIDTH: float = 0.26
const WHEEL_BASE_X: float = 0.73
const WHEEL_BASE_Z: float = 1.04

## Chiavi con cui il modello espone i nodi da aggiornare al cambio di livello.
const META_BODY_MESHES: StringName = &"evolution_body_meshes"
const META_PIPS: StringName = &"evolution_pips"
const META_LEVEL: StringName = &"evolution_level"


## Allinea l'auto al livello indicato. È una scorciatoia di
## `CarEvolutionDirector.apply_level()`: se il livello è già mostrato non fa
## nulla, altrimenti sostituisce il modello (con animazione).
static func apply_evolution_level(car: Node, level: int, animated: bool = true) -> void:
	var director := find_director(car)
	if director == null:
		push_warning("CarEvolutionDirector non trovato su %s: modello non aggiornato." % car.name)
		return
	director.apply_level(level, animated)


## Direttore associato all'auto: prima il figlio "CarVisual", poi il nodo stesso.
static func find_director(car: Node) -> CarEvolutionDirector:
	if car == null:
		return null
	var child := car.get_node_or_null(DIRECTOR_NODE_NAME) as CarEvolutionDirector
	if child != null:
		return child
	return car as CarEvolutionDirector
