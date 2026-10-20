class_name TrackManager
extends Node3D
## Genera e ricicla i segmenti di pista per creare una strada continua verso l'orizzonte.
## I cancelli di evoluzione e gli ostacoli NON vivono nei segmenti (che vengono
## riciclati): sono gestiti in coordinate mondo da GateManager e
## ObstacleManager, così non si spostano mai sotto l'auto.
## TODO: monete raccoglibili.

var _segments: Array[TrackSegment] = []
var _player: Node3D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	for index in GameConfig.SEGMENT_COUNT:
		var segment := TrackSegment.new()
		segment.name = "Segment_%d" % index
		segment.segment_index = index
		segment.position.z = -index * GameConfig.SEGMENT_LENGTH
		add_child(segment)
		_segments.append(segment)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var total_length := GameConfig.SEGMENT_COUNT * GameConfig.SEGMENT_LENGTH
	for segment in _segments:
		if segment.position.z - _player.position.z > GameConfig.SEGMENT_LENGTH:
			# Il segmento è ormai dietro la telecamera: spostalo in fondo all'orizzonte.
			segment.position.z -= total_length
			segment.rebuild(segment.segment_index + GameConfig.SEGMENT_COUNT)
