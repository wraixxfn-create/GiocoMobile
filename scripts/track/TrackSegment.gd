class_name TrackSegment
extends Node3D
## Un tratto di pista del livello dimostrativo.
##
## Il segmento non costruisce "tutto da solo": compone due sottosistemi
## riutilizzabili e indipendenti.
## 1. `TrackRoadBuilder` → superficie, cordoli, segnaletica, rappezzi;
## 2. `SceneryPlan` → vegetazione, rocce, arredi, nelle tre fasce di profondità.
##
## Restano fuori dal segmento (in coordinate mondo, perché i segmenti vengono
## riciclati): cancelli, ostacoli e monete. La geometria di gioco non cambia:
## la superficie di guida è a y = 0 e la larghezza utile è `TRACK_WIDTH`.
##
## `segment_index` è monotono: cresce a ogni riciclo, così lo scenario non si
## ripete mai uguale a se stesso.

## Indice monotono del segmento (usato da test e riciclo).
var segment_index: int = 0


func _ready() -> void:
	_build()


## Ricostruisce il segmento con un nuovo indice (usato al riciclo).
func rebuild(new_index: int) -> void:
	segment_index = new_index
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()


func _build() -> void:
	TrackRoadBuilder.build(self, segment_index)
	SceneryPlan.decorate(self, segment_index)
