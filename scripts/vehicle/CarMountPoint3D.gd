class_name CarMountPoint3D
extends Marker3D
## Nodo marker tipizzato per definire punti di montaggio nei modelli 3D esterni.
##
## Permette a una scena `.tscn` derivata da Blender (`.glb`) di dichiarare i
## propri ancoraggi tramite proprietà esportate (`slot`, `hub_index`, `mount_tags`),
## senza mai dipendere dal nome testuale del nodo nella gerarchia.

@export var slot: int = CarPartSlot.Type.SPOILER
## Solo per `slot == CarPartSlot.Type.WHEELS`: 0 = FL, 1 = FR, 2 = RL, 3 = RR.
@export_range(-1, 3, 1) var hub_index: int = -1
@export var mount_tags: PackedStringArray = PackedStringArray()
@export_range(0.0, 4.0, 0.01) var available_width: float = 0.0
@export_range(0.0, 4.0, 0.01) var available_height: float = 0.0
@export_range(0.0, 4.0, 0.01) var available_length: float = 0.0
