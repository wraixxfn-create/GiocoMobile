@tool
class_name SceneryRock
extends SceneryProp
## Roccia stilizzata: sfera irregolare con facce piatte (normali per-faccia),
## base affondata nel terreno e, in alcune varianti, una cuffia di muschio.
##
## Le facce piatte danno il look "low-poly premium": i volumi si leggono con
## poche sfumature nette, senza texture.

const VARIANTS: int = 5
const ROCK_VIEW_DISTANCE: float = 190.0

static var _cache: Dictionary = {}

@export_range(0.4, 2.0, 0.01) var size_scale: float = 1.0


func _ready() -> void:
	scale = Vector3.ONE * maxf(size_scale, 0.2)
	view_distance = ROCK_VIEW_DISTANCE
	super._ready()


func build() -> void:
	var index := posmod(variant, VARIANTS)
	var data := _variant_data(index)
	add_accumulated(
		"Rock", data["rock"], MaterialFactory.boulder(index % 3 == 2), Transform3D.IDENTITY, true
	)
	var moss_acc: Dictionary = data["moss"]
	if not (moss_acc["tris"] as Array).is_empty():
		add_accumulated("Moss", moss_acc, MaterialFactory.moss(), Transform3D.IDENTITY, true)


static func _variant_data(index: int) -> Dictionary:
	if _cache.has(index):
		return _cache[index]
	var specs: Array[Dictionary] = [
		{"radius": 0.95, "squash": 0.72, "rough": 0.26, "moss": true},
		{"radius": 1.35, "squash": 0.42, "rough": 0.30, "moss": false},
		{"radius": 0.72, "squash": 1.35, "rough": 0.22, "moss": true},
		{"radius": 1.10, "squash": 0.58, "rough": 0.34, "moss": true},
		{"radius": 1.70, "squash": 0.50, "rough": 0.28, "moss": false},
	]
	var spec: Dictionary = specs[posmod(index, specs.size())]
	var rock := PropMeshes.blob(
		8100 + index * 17,
		float(spec["radius"]),
		2 if float(spec["radius"]) > 1.2 else 1,
		float(spec["rough"]),
		float(spec["squash"]),
		true,
	)
	var moss_acc := PropMeshes.new_accumulator()
	if bool(spec["moss"]):
		var moss := PropMeshes.blob(
			9300 + index * 23,
			float(spec["radius"]) * 0.78,
			1,
			0.30,
			0.16,
			true,
		)
		var height := float(spec["radius"]) * float(spec["squash"])
		PropMeshes.append(
			moss_acc,
			moss["verts"] as Array[Vector3],
			moss["tris"] as Array[Vector3i],
			Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.78, 0.0)),
		)
	var data := {"rock": rock, "moss": moss_acc}
	_cache[index] = data
	return data
