class_name SceneryPlan
extends RefCounted
## Regia dello scenario: decide **cosa** compare in un segmento e **dove**,
## istanziando le scene riutilizzabili degli oggetti.
##
## Il livello è composto da tre fasce di profondità, ognuna con un compito:
## 1. **primo piano** (x 4.7-11 m): felci, sassi, delineatori, erba alta.
##    È la fascia che scorre veloce e dà il senso di velocità;
## 2. **piano intermedio** (x 11-30 m): palme inclinate, alberi a chioma larga,
##    cartelli, chioschi. Sono i volumi che incorniciano la pista;
## 3. **sfondo** (x 30-70 m + `Backdrop`): alberi e rocce progressivamente più
##    radi, poi creste e linee di palme lontane.
##
## La disposizione è deterministica (seme del segmento) ma non ripetitiva:
## si alternano dieci "ambienti" curati e, all'interno, cambiano variante,
## scala, rotazione e inclinazione. Nessun oggetto finisce sulla carreggiata.

const PALM_SCENE: PackedScene = preload("res://scenes/scenery/Palm.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/scenery/BroadleafTree.tscn")
const FERN_SCENE: PackedScene = preload("res://scenes/scenery/FernBush.tscn")
const ROCK_SCENE: PackedScene = preload("res://scenes/scenery/Rock.tscn")
const CLUSTER_SCENE: PackedScene = preload("res://scenes/scenery/RockCluster.tscn")
const HUT_SCENE: PackedScene = preload("res://scenes/scenery/BeachHut.tscn")
const SIGN_SCENE: PackedScene = preload("res://scenes/scenery/RoadSign.tscn")
const MARKER_SCENE: PackedScene = preload("res://scenes/scenery/MarkerPost.tscn")

## Dieci ambienti curati: densità e specie diverse, tutti con la stessa
## grammatica visiva. I conteggi sono per lato.
const ARRANGEMENTS: Array[Dictionary] = [
	{"name": "palmeto", "palm": 2, "tree": 0, "fern": 2, "rock": 1, "cluster": 0, "sign": 0, "hut": 0},
	{"name": "felceto", "palm": 1, "tree": 1, "fern": 3, "rock": 2, "cluster": 0, "sign": 0, "hut": 0},
	{"name": "radura", "palm": 0, "tree": 2, "fern": 1, "rock": 1, "cluster": 1, "sign": 0, "hut": 0},
	{"name": "costa", "palm": 3, "tree": 0, "fern": 1, "rock": 1, "cluster": 0, "sign": 1, "hut": 0},
	{"name": "foresta", "palm": 1, "tree": 3, "fern": 2, "rock": 0, "cluster": 0, "sign": 0, "hut": 0},
	{"name": "scogli", "palm": 1, "tree": 0, "fern": 2, "rock": 2, "cluster": 1, "sign": 0, "hut": 0},
	{"name": "chiosco", "palm": 2, "tree": 1, "fern": 1, "rock": 0, "cluster": 0, "sign": 0, "hut": 1},
	{"name": "sentiero", "palm": 0, "tree": 1, "fern": 3, "rock": 1, "cluster": 0, "sign": 1, "hut": 0},
	{"name": "giardino", "palm": 2, "tree": 2, "fern": 2, "rock": 0, "cluster": 0, "sign": 0, "hut": 0},
	{"name": "promontorio", "palm": 2, "tree": 0, "fern": 0, "rock": 2, "cluster": 1, "sign": 0, "hut": 0},
]

## Oltre questa distanza gli oggetti non vengono disegnati: la foschia copre
## il passaggio e il telefono risparmia centinaia di draw call.
const MAX_VIEW_DISTANCE: float = 235.0


## Decora un segmento. `segment_index` è monotono (cresce a ogni riciclo),
## quindi la sequenza di ambienti non torna mai identica.
static func decorate(segment: Node3D, segment_index: int) -> void:
	var half_length := GameConfig.SEGMENT_LENGTH * 0.5
	_place_markers(segment, segment_index, half_length)
	for side: float in [-1.0, 1.0]:
		var arrangement_index := posmod(segment_index * 3 + (0 if side < 0.0 else 4), ARRANGEMENTS.size())
		var arrangement := ARRANGEMENTS[arrangement_index]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("scenery_%d_%.0f" % [segment_index, side])
		_place_side(segment, side, arrangement, rng, half_length)


# ------------------------------------------------------------- Delineatori ---

static func _place_markers(parent: Node3D, segment_index: int, half_length: float) -> void:
	for side: float in [-1.0, 1.0]:
		for i in 2:
			var marker := MARKER_SCENE.instantiate() as SceneryProp
			marker.prop_seed = segment_index * 17 + i
			marker.shadow_casting = false
			var x: float = side * (GameConfig.TRACK_WIDTH * 0.5 + GameConfig.CURB_WIDTH + 0.42)
			var z: float = -half_length + 6.0 + i * 20.0
			marker.position = Vector3(x, 0.0, z)
			marker.rotation.y = 0.0
			parent.add_child(marker)


# ------------------------------------------------------------------ Fasce ---

static func _place_side(
	parent: Node3D,
	side: float,
	arrangement: Dictionary,
	rng: RandomNumberGenerator,
	half_length: float,
) -> void:
	var forward_yaw := 0.0 if side > 0.0 else PI

	# Primo piano: felci e sassi sul bordo sabbioso.
	for i in int(arrangement["fern"]):
		_add(FERN_SCENE, parent, {
			"x": side * rng.randf_range(5.3, 10.5),
			"z": rng.randf_range(-half_length + 1.0, half_length - 1.0),
			"yaw": rng.randf_range(0.0, TAU),
			"scale_key": "size_scale",
			"scale": rng.randf_range(0.65, 1.35),
			"variant": rng.randi_range(0, SceneryFernBush.VARIANTS - 1),
			"seed": rng.randi(),
			"shadow": true,
		})
	for i in int(arrangement["rock"]):
		_add(ROCK_SCENE, parent, {
			"x": side * rng.randf_range(5.6, 13.0),
			"z": rng.randf_range(-half_length + 1.0, half_length - 1.0),
			"yaw": rng.randf_range(0.0, TAU),
			"scale_key": "size_scale",
			"scale": rng.randf_range(0.45, 1.05),
			"variant": rng.randi_range(0, SceneryRock.VARIANTS - 1),
			"seed": rng.randi(),
			"shadow": true,
		})

	# Piano intermedio: i volumi che incorniciano la strada.
	for i in int(arrangement["palm"]):
		var near_road := i % 2 == 0
		var distance := rng.randf_range(10.5, 18.0) if near_road else rng.randf_range(20.0, 34.0)
		_add(PALM_SCENE, parent, {
			"x": side * distance,
			"z": rng.randf_range(-half_length + 2.0, half_length - 2.0),
			# La chioma si inclina verso la pista: cornice naturale.
			"yaw": forward_yaw + rng.randf_range(-0.45, 0.45),
			"scale_key": "height_scale",
			"scale": rng.randf_range(0.78, 1.18) * (1.0 if near_road else 0.92),
			"variant": rng.randi_range(0, SceneryPalm.VARIANTS - 1),
			"seed": rng.randi(),
			"shadow": near_road,
		})
	for i in int(arrangement["tree"]):
		_add(TREE_SCENE, parent, {
			"x": side * rng.randf_range(16.0, 38.0),
			"z": rng.randf_range(-half_length + 2.0, half_length - 2.0),
			"yaw": rng.randf_range(0.0, TAU),
			"scale_key": "height_scale",
			"scale": rng.randf_range(0.85, 1.35),
			"variant": rng.randi_range(0, SceneryBroadleaf.VARIANTS - 1),
			"seed": rng.randi(),
			"shadow": rng.randf() > 0.35,
		})
	if int(arrangement["cluster"]) > 0:
		_add(CLUSTER_SCENE, parent, {
			"x": side * rng.randf_range(18.0, 36.0),
			"z": rng.randf_range(-half_length + 4.0, half_length - 4.0),
			"yaw": rng.randf_range(0.0, TAU),
			"scale_key": "size_scale",
			"scale": rng.randf_range(0.9, 1.5),
			"variant": 0,
			"seed": rng.randi(),
			"shadow": true,
		})
	if int(arrangement["hut"]) > 0:
		_add(HUT_SCENE, parent, {
			"x": side * rng.randf_range(15.0, 21.0),
			"z": rng.randf_range(-half_length + 6.0, half_length - 6.0),
			"yaw": forward_yaw + rng.randf_range(-0.25, 0.25),
			"scale_key": "size_scale",
			"scale": rng.randf_range(0.92, 1.12),
			"variant": 0,
			"seed": rng.randi(),
			"shadow": true,
		})
	if int(arrangement["sign"]) > 0:
		_add(SIGN_SCENE, parent, {
			"x": side * rng.randf_range(6.4, 8.6),
			"z": rng.randf_range(-half_length + 3.0, half_length - 3.0),
			# Il cartello guarda chi arriva (verso +Z), leggermente angolato.
			"yaw": rng.randf_range(-0.28, 0.28),
			"scale_key": "height_scale",
			"scale": rng.randf_range(0.9, 1.05),
			"variant": 0,
			"seed": rng.randi(),
			"shadow": true,
		})

	# Sfondo: alberi radi e rocce grandi, senza ombre proiettate.
	var far_trees := rng.randi_range(1, 3)
	for i in far_trees:
		_add(TREE_SCENE, parent, {
			"x": side * rng.randf_range(38.0, 72.0),
			"z": rng.randf_range(-half_length, half_length),
			"yaw": rng.randf_range(0.0, TAU),
			"scale_key": "height_scale",
			"scale": rng.randf_range(1.0, 1.6),
			"variant": rng.randi_range(0, SceneryBroadleaf.VARIANTS - 1),
			"seed": rng.randi(),
			"shadow": false,
		})
	var far_palms := rng.randi_range(0, 2)
	for i in far_palms:
		_add(PALM_SCENE, parent, {
			"x": side * rng.randf_range(40.0, 78.0),
			"z": rng.randf_range(-half_length, half_length),
			"yaw": rng.randf_range(0.0, TAU),
			"scale_key": "height_scale",
			"scale": rng.randf_range(1.0, 1.4),
			"variant": rng.randi_range(0, SceneryPalm.VARIANTS - 1),
			"seed": rng.randi(),
			"shadow": false,
		})


## Istanzia un oggetto e applica i parametri della scheda.
static func _add(scene: PackedScene, parent: Node3D, spec: Dictionary) -> void:
	var prop := scene.instantiate() as SceneryProp
	if prop == null:
		return
	prop.variant = int(spec.get("variant", 0))
	prop.prop_seed = int(spec.get("seed", 0))
	prop.shadow_casting = bool(spec.get("shadow", true))
	var scale_key: String = str(spec.get("scale_key", ""))
	if scale_key != "":
		prop.set(scale_key, float(spec.get("scale", 1.0)))
	prop.position = Vector3(float(spec["x"]), 0.0, float(spec["z"]))
	prop.rotation.y = float(spec.get("yaw", 0.0))
	parent.add_child(prop)
