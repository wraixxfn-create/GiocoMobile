@tool
class_name SceneryBroadleaf
extends SceneryProp
## Albero tropicale a chioma larga: tronco con biforcazioni, ciuffi di foglie
## tondeggianti su due toni di verde e grandi foglie pendenti sul bordo.
##
## È il "pieno" della fascia intermedia: le chiome tonde creano volumi leggibili
## contro il cielo e la silhouette non ripete mai la stessa forma (sei varianti).

const REFERENCE_HEIGHT: float = 5.4
const VARIANTS: int = 6
const TREE_VIEW_DISTANCE: float = 245.0

static var _cache: Dictionary = {}

@export_range(0.55, 1.6, 0.01) var height_scale: float = 1.0


func _ready() -> void:
	scale = Vector3.ONE * maxf(height_scale, 0.2)
	view_distance = TREE_VIEW_DISTANCE
	super._ready()


func build() -> void:
	var index := posmod(variant, VARIANTS)
	var data := _variant_data(index)
	add_accumulated("Trunk", data["trunk"], MaterialFactory.tree_trunk(index % 2 == 0))
	add_accumulated("Branches", data["branches"], MaterialFactory.tree_trunk(true))
	add_accumulated(
		"CanopyLow", data["canopy_low"], MaterialFactory.leaf(index, false)
	)
	add_accumulated(
		"CanopyHigh",
		data["canopy_high"],
		MaterialFactory.leaf_light(index + 1, false),
	)
	add_accumulated(
		"CanopyLeaves",
		data["leaves"],
		MaterialFactory.fern(true),
		Transform3D.IDENTITY,
		false,
		160.0,
	)


static func _variant_data(index: int) -> Dictionary:
	if _cache.has(index):
		return _cache[index]

	var specs: Array[Dictionary] = [
		{"trunk": 2.8, "curve": 0.35, "radius": 0.30, "lobes": 5, "spread": 1.55, "round": 0.86},
		{"trunk": 3.4, "curve": 0.55, "radius": 0.26, "lobes": 4, "spread": 1.35, "round": 0.92},
		{"trunk": 2.2, "curve": 0.20, "radius": 0.32, "lobes": 6, "spread": 1.85, "round": 0.72},
		{"trunk": 3.9, "curve": 0.85, "radius": 0.24, "lobes": 4, "spread": 1.20, "round": 0.95},
		{"trunk": 2.5, "curve": 0.65, "radius": 0.28, "lobes": 5, "spread": 1.70, "round": 0.80},
		{"trunk": 3.1, "curve": 0.10, "radius": 0.30, "lobes": 6, "spread": 1.45, "round": 0.88},
	]
	var spec: Dictionary = specs[posmod(index, specs.size())]
	var trunk_height: float = float(spec["trunk"])
	var trunk := PropMeshes.curved_trunk(
		trunk_height,
		float(spec["curve"]),
		float(spec["radius"]),
		float(spec["radius"]) * 0.62,
		index + 21,
		8,
	)
	var top: Vector3 = trunk["top"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 7600 + index * 13
	var lobe_count: int = int(spec["lobes"])
	var spread: float = float(spec["spread"])
	var round: float = float(spec["round"])

	var branches := PropMeshes.new_accumulator()
	var canopy_low := PropMeshes.new_accumulator()
	var canopy_high := PropMeshes.new_accumulator()
	var leaves := PropMeshes.new_accumulator()

	var centers: Array[Vector3] = []
	for i in lobe_count:
		var angle := TAU * float(i) / float(lobe_count) + rng.randf_range(-0.35, 0.35)
		var distance := spread * rng.randf_range(0.55, 1.05)
		var center := top + Vector3(
			cos(angle) * distance,
			rng.randf_range(0.25, 0.95) * spread * 0.55,
			sin(angle) * distance,
		)
		centers.append(center)
		# Ramo dal tronco alla chioma: tubo sottile, si assottiglia.
		var branch := PropMeshes.tube(
			[top + Vector3(0.0, -0.25, 0.0), (top + center) * 0.5 + Vector3(0.0, 0.15, 0.0), center],
			[float(spec["radius"]) * 0.55, float(spec["radius"]) * 0.36, float(spec["radius"]) * 0.20],
			6,
			false,
			0,
		)
		PropMeshes.append(
			branches, branch["verts"] as Array[Vector3], branch["tris"] as Array[Vector3i]
		)
		var radius := spread * rng.randf_range(0.48, 0.74)
		var lobe := PropMeshes.blob(
			3000 + index * 31 + i,
			radius,
			1,
			0.20,
			round,
			false,
		)
		var target := canopy_high if center.y > top.y + spread * 0.42 else canopy_low
		PropMeshes.append(
			target,
			lobe["verts"] as Array[Vector3],
			lobe["tris"] as Array[Vector3i],
			Transform3D(Basis.IDENTITY, center),
		)
		# Foglie pendenti sul bordo della chioma: silhouette tropicale.
		for k in 2:
			var leaf := PropMeshes.frond(
				spread * rng.randf_range(0.55, 0.85),
				spread * rng.randf_range(0.30, 0.42),
				0.25,
				0.55,
				5000 + index * 53 + i * 7 + k,
				0.16,
				6,
			)
			var yaw := angle + rng.randf_range(-0.7, 0.7)
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(18.0, 42.0)))
			PropMeshes.append(
				leaves,
				leaf["verts"] as Array[Vector3],
				leaf["tris"] as Array[Vector3i],
				Transform3D(basis, center + Vector3(0.0, -0.2, 0.0)),
			)

	var data := {
		"trunk": trunk,
		"branches": branches,
		"canopy_low": canopy_low,
		"canopy_high": canopy_high,
		"leaves": leaves,
	}
	_cache[index] = data
	return data
