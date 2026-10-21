class_name CarPartCatalogResource
extends Resource
## Risorsa catalogo serializzata (`res://config/car_part_catalog.tres`).
##
## Raccoglie tutte le risorse `CarPartDefinition` disponibili e gli assetti
## canonici `CarLoadout` dei sei stadi evolutivi, ispezionabili dall'Editor.

@export var parts: Array[Resource] = []
@export var stage_loadouts: Array[Resource] = []
