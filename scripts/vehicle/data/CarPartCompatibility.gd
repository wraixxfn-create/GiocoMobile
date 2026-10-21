class_name CarPartCompatibility
extends Resource
## Regole dichiarative di compatibilità e adattamento metrico di un componente.
##
## Consente di verificare se una parte può essere montata su una data carrozzeria
## (architettura silhouette, punti di attacco richiesti, esclusioni reciproche)
## e come adattarne le dimensioni di riferimento ai punti di montaggio.

## Silhouette `CarEvolutionProfile.Silhouette` ammesse. Vuoto = universale.
@export var compatible_silhouettes: PackedInt32Array = PackedInt32Array()

## Tag di ancoraggio richiesti sullo slot della carrozzeria ospite
## (es. `"hood_bay"` per motori anteriori, `"mid_bay"` per motori centrali).
@export var required_mount_tags: PackedStringArray = PackedStringArray()

## Identificativi (`CarPartDefinition.id`) incompatibili con questa parte.
@export var incompatible_part_ids: PackedStringArray = PackedStringArray()

## Larghezza e lunghezza naturali di progetto (metri) per scalatura adattiva
## controllata dei modelli 3D esterni (`PackedScene`). 0 = nessun riscalamento.
@export_range(0.0, 4.0, 0.01) var reference_width: float = 0.0
@export_range(0.0, 4.0, 0.01) var reference_length: float = 0.0
@export_range(0.5, 1.0, 0.01) var min_fit_scale: float = 0.82
@export_range(1.0, 1.6, 0.01) var max_fit_scale: float = 1.22
