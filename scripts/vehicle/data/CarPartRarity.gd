class_name CarPartRarity
extends RefCounted
## Classificazione statica di fascia tecnica/rarità di un componente (puro dato).
##
## Descrive il grado tecnologico della parte nelle risorse dati senza alcuna
## logica di estrazione casuale, negozio o monetizzazione.

enum Tier {
	COMMON = 0,     ## Dotazione base / stradale standard.
	UNCOMMON = 1,   ## Dotazione stradale evoluta.
	RARE = 2,       ## Componente sportivo stradale/pista.
	EPIC = 3,       ## Componente da competizione GT.
	PROTOTYPE = 4,  ## Componente estremo di fascia Hypercar.
}


static func label_it(tier: int) -> String:
	match tier:
		Tier.COMMON:
			return "COMUNE"
		Tier.UNCOMMON:
			return "NON COMUNE"
		Tier.RARE:
			return "RARA"
		Tier.EPIC:
			return "EPICA"
		Tier.PROTOTYPE:
			return "PROTOTIPO"
		_:
			return "COMUNE"
