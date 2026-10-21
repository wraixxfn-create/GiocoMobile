@tool
class_name SceneryBackdrop
extends Node3D
## Sfondo del livello: tre creste di colline a profondità diverse e una linea
## di palme lontane. Non è decorazione "casuale": è la terza fascia di
## profondità, quella che dà all'orizzonte una forma riconoscibile e coerente.
##
## Il nodo segue l'auto solo in Z: le montagne restano sempre all'orizzonte
## (come una quinta teatrale), mentre la pista scorre. Le creste sono mesh
## statiche, un materiale ciascuna, nessuna ombra: costo trascurabile.

const RIDGE_NEAR_Z: float = -235.0
const RIDGE_MID_Z: float = -305.0
const RIDGE_FAR_Z: float = -395.0
const TREELINE_Z: float = -165.0
const FOLLOW_MARGIN: float = 0.0

var _player: Node3D = null
var _built: bool = false


func _ready() -> void:
	if not _built:
		_build()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _process(_delta: float) -> void:
	if _player == null:
		return
	position.z = _player.position.z - FOLLOW_MARGIN


func _build() -> void:
	_built = true
	_add_ridge("RidgeNear", RIDGE_NEAR_Z, 18.0, 8.0, SceneryPalette.HILL_NEAR, 34.0)
	_add_ridge("RidgeMid", RIDGE_MID_Z, 27.0, 12.0, SceneryPalette.HILL_MID, 52.0)
	_add_ridge("RidgeFar", RIDGE_FAR_Z, 40.0, 17.0, SceneryPalette.HILL_FAR, 74.0)
	_add_treeline("TreeLine", TREELINE_Z)


## Una catena di colline: due file di cupole schiacciate sovrapposte, non una
## quinta piatta. Ogni strato ha raggio, altezza e tinta propri; le cupole
## sono irregolari e sfalsate, così la silhouette non è mai una fila di gobbe
## uguali. La foschia le schiarisce con la distanza, in modo naturale.
func _add_ridge(
	node_name: String,
	z: float,
	radius: float,
	height: float,
	color: Color,
	step: float,
) -> void:
	var acc := PropMeshes.new_accumulator()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(z)) * 31 + 7
	for layer in 2:
		var layer_z := z - float(layer) * step * 1.15
		var layer_height := height * (1.0 if layer == 0 else 0.78)
		var layer_radius := radius * (1.0 if layer == 0 else 0.86)
		var cursor := -layer_radius * 5.2 + float(layer) * step * 0.55
		while cursor < layer_radius * 5.2:
			var dome_radius := layer_radius * rng.randf_range(0.62, 1.16)
			var dome_height := layer_height * rng.randf_range(0.48, 1.05)
			var dome := PropMeshes.blob(
				int(absf(cursor)) + int(absf(layer_z)) + layer * 97,
				dome_radius,
				2,
				0.20,
				dome_height / dome_radius,
				true,
			)
			var origin := Vector3(
				cursor + rng.randf_range(-0.3, 0.3) * step,
				-dome_radius * 0.62,
				layer_z + rng.randf_range(-0.3, 0.3) * step,
			)
			PropMeshes.append(
				acc,
				dome["verts"] as Array[Vector3],
				dome["tris"] as Array[Vector3i],
				Transform3D(Basis.IDENTITY, origin),
			)
			cursor += step * rng.randf_range(0.55, 0.95)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = PropMeshes.to_mesh(acc, false)
	instance.material_override = MaterialFactory.distant_hill(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 620.0
	add_child(instance)


## Linea di palme lontane: un'unica mesh di chiome e tronchi semplificati.
## La silhouette irregolare evita l'effetto "filare ripetuto".
func _add_treeline(node_name: String, z: float) -> void:
	var acc := PropMeshes.new_accumulator()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9182
	for side: float in [-1.0, 1.0]:
		var cursor := 12.0
		while cursor < 130.0:
			var x: float = side * cursor
			var distance := absf(x)
			var scale_value := rng.randf_range(0.7, 1.25) * lerpf(1.0, 0.65, distance / 130.0)
			var hue := rng.randi_range(0, 2)
			var base: Vector3 = Vector3(x, -2.0, z + rng.randf_range(-26.0, 6.0))
			var trunk: Dictionary = PropMeshes.cylinder(0.0, 7.5 * scale_value, 0.30, 0.16, 5)
			PropMeshes.append(
				acc,
				trunk["verts"] as Array[Vector3],
				trunk["tris"] as Array[Vector3i],
				Transform3D(Basis.IDENTITY, base),
			)
			for lobe in 3:
				var blob: Dictionary = PropMeshes.blob(
					1200 + hue * 17 + int(cursor) + lobe,
					2.1 * scale_value,
					1,
					0.24,
					0.72,
					false,
				)
				var offset: Vector3 = Vector3(
					rng.randf_range(-1.6, 1.6) * scale_value,
					7.0 * scale_value + rng.randf_range(-0.6, 1.4) * scale_value,
					rng.randf_range(-1.2, 1.2) * scale_value,
				)
				PropMeshes.append(
					acc,
					blob["verts"] as Array[Vector3],
					blob["tris"] as Array[Vector3i],
					Transform3D(Basis.IDENTITY, base + offset),
				)
			cursor += rng.randf_range(7.0, 13.0)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = PropMeshes.to_mesh(acc, false)
	instance.material_override = MaterialFactory.distant_hill(SceneryPalette.DISTANT_TREE)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 420.0
	add_child(instance)
