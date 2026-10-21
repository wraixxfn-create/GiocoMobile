class_name CarModel
extends RefCounted
## Strato di compatibilità con le chiamate storiche del modello dell'auto.
##
## La geometria non vive qui: ogni stadio è descritto da un
## `CarEvolutionProfile` (dati), costruito da `CarModelBuilder` (blockout
## procedurale oppure scena esterna via `CarModelLibrary`) e mostrato da
## `CarEvolutionDirector` (che è il nodo "CarVisual" figlio del CarController).
##
## Questo file resta come sottile strato di compatibilità: le chiamate a
## `apply_evolution_level()` continuano a funzionare e diventano semplicemente
## "allinea il modello al livello richiesto", senza duplicare stati.
##
## Dipendenza a senso unico: le costanti sono alias di quelle definite da
## `CarEvolutionDirector` (fonte unica). In passato le costanti vivevano qui e
## il direttore le referenziava, creando una dipendenza circolare tra i due
## script (fragile in fase di caricamento/export); ora CarModel dipende dal
## direttore e mai viceversa.

## Nome del nodo figlio che ospita il modello visibile.
const DIRECTOR_NODE_NAME: String = CarEvolutionDirector.DIRECTOR_NODE_NAME

## Raggio ruota della taratura di base (usato come fallback).
const WHEEL_RADIUS: float = CarEvolutionDirector.WHEEL_RADIUS

## Chiavi con cui il modello espone i nodi da aggiornare al cambio di livello.
const META_BODY_MESHES: StringName = CarEvolutionDirector.META_BODY_MESHES
const META_PIPS: StringName = CarEvolutionDirector.META_PIPS
const META_LEVEL: StringName = CarEvolutionDirector.META_LEVEL


## Allinea l'auto al livello indicato. È una scorciatoia di
## `CarEvolutionDirector.apply_level()`: se il livello è già mostrato non fa
## nulla, altrimenti sostituisce il modello (con animazione).
static func apply_evolution_level(car: Node, level: int, animated: bool = true) -> void:
	var director := find_director(car)
	if director == null:
		push_warning("CarEvolutionDirector non trovato su %s: modello non aggiornato." % car.name)
		return
	director.apply_level(level, animated)


## Direttore associato all'auto: delega a `CarEvolutionDirector.find_on()`
## (prima il figlio "CarVisual", poi il nodo stesso).
static func find_director(car: Node) -> CarEvolutionDirector:
	return CarEvolutionDirector.find_on(car)
