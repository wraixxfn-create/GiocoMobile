class_name CarPartSlot
extends RefCounted
## Tipologia dei componenti modulari dell'automobile (puro strato dati).
##
## Ogni componente sostituibile dichiara il proprio slot tramite questo enum
## tipizzato: il sistema di montaggio non usa mai controlli basati sui nomi dei
## nodi della scena per identificare o sostituire i pezzi.

enum Type {
	BODY = 0,          ## Carrozzeria principale, abitacolo e punti di ancoraggio.
	BUMPER_FRONT = 1,  ## Paraurti anteriore (fascia, splitter, lama, bull-bar).
	BUMPER_REAR = 2,   ## Paraurti posteriore (fascia, estrattore, tunnel Venturi).
	WHEELS = 3,        ## Set completo di 4 ruote sui mozzi anteriori e posteriori.
	ENGINE = 4,        ## Motore o gruppo meccanico visibile (cofano / vano centrale).
	EXHAUST = 5,       ## Impianto di scarico posteriore.
	SPOILER = 6,       ## Spoiler / alettone posteriore.
	AERO = 7,          ## Elementi aerodinamici aggiuntivi (minigonne, canard, pinna).
}

const ALL: Array[int] = [
	Type.BODY,
	Type.BUMPER_FRONT,
	Type.BUMPER_REAR,
	Type.WHEELS,
	Type.ENGINE,
	Type.EXHAUST,
	Type.SPOILER,
	Type.AERO,
]

## Tutti i componenti periferici montati sui punti di attacco della carrozzeria.
const ATTACHED: Array[int] = [
	Type.BUMPER_FRONT,
	Type.BUMPER_REAR,
	Type.WHEELS,
	Type.ENGINE,
	Type.EXHAUST,
	Type.SPOILER,
	Type.AERO,
]


static func is_valid(slot: int) -> bool:
	return slot >= Type.BODY and slot <= Type.AERO


static func slug(slot: int) -> StringName:
	match slot:
		Type.BODY:
			return &"body"
		Type.BUMPER_FRONT:
			return &"bumper_front"
		Type.BUMPER_REAR:
			return &"bumper_rear"
		Type.WHEELS:
			return &"wheels"
		Type.ENGINE:
			return &"engine"
		Type.EXHAUST:
			return &"exhaust"
		Type.SPOILER:
			return &"spoiler"
		Type.AERO:
			return &"aero"
		_:
			return &"unknown"


static func label_it(slot: int) -> String:
	match slot:
		Type.BODY:
			return "CARROZZERIA"
		Type.BUMPER_FRONT:
			return "PARAURTI ANT."
		Type.BUMPER_REAR:
			return "PARAURTI POST."
		Type.WHEELS:
			return "RUOTE"
		Type.ENGINE:
			return "MOTORE"
		Type.EXHAUST:
			return "SCARICO"
		Type.SPOILER:
			return "SPOILER"
		Type.AERO:
			return "AERODINAMICA"
		_:
			return "COMPONENTE"
