class_name GateRow
extends RefCounted
## Una fila di cancelli: due cancelli affiancati sullo stesso piano Z.
## È una struttura dati pura (nessun nodo): i cancelli veri e propri sono
## nodi EvolutionGate figli del GateManager.

## Piano della fila (coordinata Z mondo): i due cancelli lo condividono.
var z: float = 0.0
## True quando uno dei due cancelli è stato attraversato: la fila è chiusa.
var passed: bool = false
## I due cancelli affiancati (prima il sinistro, poi il destro).
var gates: Array = []


func has_active_gate() -> bool:
	for gate in gates:
		var evolution_gate := gate as EvolutionGate
		if evolution_gate != null and not evolution_gate.consumed:
			return true
	return false
