@tool
class_name SceneryFernBush
extends SceneryProp
## Cespuglio di felci tropicali: ciuffo di fronde arcuate su due toni, più un
## piccolo nucleo scuro alla base che dà volume e nasconde i gambi.
##
## È il dettaglio di primo piano lungo il bordo pista: costa una manciata di
## triangoli e rompe la linearità del prato.

const VARIANTS: int = 5
const BUSH_VIEW_DISTANCE: float = 120.0

static var _cache: Dictionary = {}

@export_range(0.5, 1.8, 0.01) var size_scale: float = 1.0


func _ready() -> void:
	scale = Vector3.ONE * maxf(size_scale, 0.2)
	view_distance = BUSH_VIEW_DISTANCE
	super._ready()


func build() -> void:
	var index := posmod(variant, VARIANTS)
	var data := _variant_data(index)
	var tint := (prop_seed % 3) if prop_seed >= 0 else 0
	add_accumulated("Core", data["core"], MaterialFactory.leaf(index + 2 + tint, false))
	add_accumulated("FrondsLow", data["low"], MaterialFactory.fern(false))
	add_accumulated("FrondsHigh", data["high"], MaterialFactory.fern(true))


static func _variant_data(index: int) -> Dictionary:
	if _cache.has(index):
		return _cache[index]
	var specs: Array[Dictionary] = [
		{"count": 9, "length": 1.25, "width": 0.46, "rise": 0.55, "core": 0.42},
		{"count": 12, "length": 1.05, "width": 0.40, "rise": 0.40, "core": 0.34},
		{"count": 8, "length": 1.65, "width": 0.55, "rise": 0.75, "core": 0.50},
		{"count": 14, "length": 0.85, "width": 0.36, "rise": 0.32, "core": 0.30},
		{"count": 10, "length": 1.45, "width": 0.62, "rise": 0.62, "core": 0.46},
	]
	var spec: Dictionary = specs[posmod(index, specs.size())]
	var low := PropMeshes.leaf_fan(
		index + 41,
		int(spec["count"]),
		float(spec["length"]),
		float(spec["width"]),
		float(spec["rise"]),
	)
	var high := PropMeshes.leaf_fan(
		index + 97,
		mini(int(spec["count"]), 7),
		float(spec["length"]) * 0.82,
		float(spec["width"]) * 0.9,
		float(spec["rise"]) * 1.35,
	)
	var core_acc := PropMeshes.new_accumulator()
	var core := PropMeshes.blob(
		5200 + index,
		float(spec["core"]),
		1,
		0.22,
		0.55,
		true,
	)
	PropMeshes.append(
		core_acc,
		core["verts"] as Array[Vector3],
		core["tris"] as Array[Vector3i],
		Transform3D(Basis.IDENTITY, Vector3(0.0, float(spec["core"]) * 0.3, 0.0)),
	)
	var data := {"low": low, "high": high, "core": core_acc}
	_cache[index] = data
	return data
