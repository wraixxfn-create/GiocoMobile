@tool
class_name SceneryPalm
extends SceneryProp
## Palma tropicale stilizzata: tronco incurvato a sezioni, chioma a corona di
## fronde con nervatura, noci di cocco e svasatura alla base.
##
## Sei varianti di sagoma (altezza, curvatura, densità e lunghezza delle
## fronde) condivise in cache: le istanze cambiano scala, rotazione e tonalità,
## così un filare di palme non è mai la ripetizione dello stesso oggetto.

const REFERENCE_HEIGHT: float = 7.2
const VARIANTS: int = 6
const TREE_VIEW_DISTANCE: float = 235.0

static var _cache: Dictionary = {}

@export_range(0.45, 1.7, 0.01) var height_scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var lean_bias: float = 0.5


func _ready() -> void:
	# La scala è uniforme: una palma giovane è più piccola in ogni dimensione,
	# non una palma schiacciata.
	scale = Vector3.ONE * maxf(height_scale, 0.2)
	view_distance = TREE_VIEW_DISTANCE
	super._ready()


func build() -> void:
	var index := posmod(variant, VARIANTS)
	var data := _variant_data(index)
	var crown_position: Vector3 = data["crown"]
	var crown_xform := Transform3D(Basis.IDENTITY, crown_position)

	add_accumulated("Trunk", data["trunk"], MaterialFactory.tree_trunk(index % 3 == 1))
	add_accumulated("RootFlare", data["root"], MaterialFactory.tree_trunk(true))
	add_accumulated("CrownBoot", data["boot"], MaterialFactory.tree_trunk(true), crown_xform)
	add_accumulated(
		"Crown", data["crown_main"], MaterialFactory.leaf(index, true), crown_xform
	)
	var light_acc: Dictionary = data["crown_light"]
	if not (light_acc["tris"] as Array).is_empty():
		add_accumulated(
			"CrownLight",
			light_acc,
			MaterialFactory.leaf_light(index + 1, true),
			crown_xform,
		)
	add_accumulated(
		"Coconuts",
		data["nuts"],
		MaterialFactory.scenery("coconut", SceneryPalette.COCONUT, 0.88, 0.0),
		crown_xform,
		false,
		150.0,
	)


## Geometria della variante, costruita una sola volta e condivisa.
static func _variant_data(index: int) -> Dictionary:
	if _cache.has(index):
		return _cache[index]

	var specs: Array[Dictionary] = [
		{"height": 6.6, "curve": 0.55, "base": 0.26, "fronds": 10, "length": 2.9,
			"width": 0.62, "droop": 1.15, "crown": 0.30},
		{"height": 5.8, "curve": 1.35, "base": 0.24, "fronds": 9, "length": 2.7,
			"width": 0.58, "droop": 1.30, "crown": 0.34},
		{"height": 7.4, "curve": 0.25, "base": 0.28, "fronds": 11, "length": 3.0,
			"width": 0.60, "droop": 1.05, "crown": 0.26},
		{"height": 5.2, "curve": 1.85, "base": 0.23, "fronds": 8, "length": 2.5,
			"width": 0.64, "droop": 1.45, "crown": 0.38},
		{"height": 6.9, "curve": 0.85, "base": 0.27, "fronds": 13, "length": 2.45,
			"width": 0.52, "droop": 1.20, "crown": 0.30},
		{"height": 6.2, "curve": 0.05, "base": 0.25, "fronds": 9, "length": 3.15,
			"width": 0.66, "droop": 0.95, "crown": 0.28},
	]
	var spec: Dictionary = specs[posmod(index, specs.size())]
	var height: float = float(spec["height"])
	var curve: float = float(spec["curve"])
	var trunk := PropMeshes.curved_trunk(
		height,
		curve,
		float(spec["base"]),
		float(spec["base"]) * 0.52,
		index + 3,
		8,
	)
	var top: Vector3 = trunk["top"]

	var root_acc := PropMeshes.new_accumulator()
	PropMeshes.append(
		root_acc,
		PropMeshes.cylinder(-0.05, 0.62, float(spec["base"]) * 1.9, float(spec["base"]) * 1.02, 9)["verts"],
		PropMeshes.cylinder(-0.05, 0.62, float(spec["base"]) * 1.9, float(spec["base"]) * 1.02, 9)["tris"],
	)

	var boot_acc := PropMeshes.new_accumulator()
	PropMeshes.append(
		boot_acc,
		PropMeshes.cylinder(-0.35, 0.35, 0.30, 0.16, 8)["verts"],
		PropMeshes.cylinder(-0.35, 0.35, 0.30, 0.16, 8)["tris"],
	)

	var crown := PropMeshes.palm_crown(
		index + 11,
		int(spec["fronds"]),
		float(spec["length"]),
		float(spec["width"]),
		float(spec["droop"]),
	)

	# Noci di cocco raccolte sotto la corona.
	var nuts_acc := PropMeshes.new_accumulator()
	var nut_rng := RandomNumberGenerator.new()
	nut_rng.seed = 4400 + index
	for i in int(spec["fronds"]) / 3 + 1:
		var angle := TAU * float(i) / 3.0 + nut_rng.randf_range(-0.4, 0.4)
		var nut := PropMeshes.blob(900 + index * 7 + i, 0.17, 0, 0.16, 1.0, false)
		var nut_xform := Transform3D(
			Basis.IDENTITY,
			Vector3(cos(angle) * 0.30, -0.20 + nut_rng.randf_range(-0.06, 0.06), sin(angle) * 0.30),
		)
		PropMeshes.append(
			nuts_acc,
			nut["verts"] as Array[Vector3],
			nut["tris"] as Array[Vector3i],
			nut_xform,
		)

	var data := {
		"trunk": trunk,
		"root": root_acc,
		"boot": boot_acc,
		"crown": top,
		"crown_main": crown["main"],
		"crown_light": crown["light"],
		"nuts": nuts_acc,
	}
	_cache[index] = data
	return data
