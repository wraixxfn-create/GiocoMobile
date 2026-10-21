@tool
class_name SceneryRockCluster
extends SceneryProp
## Gruppo di rocce con felci: una composizione riutilizzabile (istanzia le
## scene `Rock` e `FernBush`) che dà un punto di interesse riconoscibile
## lungo il percorso senza creare un nuovo script di mappa.

const ROCK_SCENE: PackedScene = preload("res://scenes/scenery/Rock.tscn")
const FERN_SCENE: PackedScene = preload("res://scenes/scenery/FernBush.tscn")
const CLUSTER_VIEW_DISTANCE: float = 185.0

@export_range(0.6, 1.8, 0.01) var size_scale: float = 1.0


func _ready() -> void:
	scale = Vector3.ONE * maxf(size_scale, 0.2)
	view_distance = CLUSTER_VIEW_DISTANCE
	super._ready()


func build() -> void:
	var rng := seeded_rng(7)
	var count := rng.randi_range(2, 4)
	for index in count:
		var rock := ROCK_SCENE.instantiate() as SceneryRock
		rock.variant = rng.randi_range(0, SceneryRock.VARIANTS - 1)
		rock.prop_seed = prop_seed * 13 + index
		var distance := rng.randf_range(0.35, 1.25)
		var angle := rng.randf_range(0.0, TAU)
		rock.position = Vector3(cos(angle) * distance, -0.12, sin(angle) * distance)
		rock.rotation.y = rng.randf_range(0.0, TAU)
		rock.size_scale = rng.randf_range(0.55, 1.15)
		rock.shadow_casting = shadow_casting
		add_child(rock)
	var ferns := rng.randi_range(1, 2)
	for index in ferns:
		var fern := FERN_SCENE.instantiate() as SceneryFernBush
		fern.variant = rng.randi_range(0, SceneryFernBush.VARIANTS - 1)
		fern.prop_seed = prop_seed * 29 + index
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(0.9, 1.9)
		fern.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		fern.rotation.y = rng.randf_range(0.0, TAU)
		fern.size_scale = rng.randf_range(0.8, 1.25)
		fern.shadow_casting = false
		add_child(fern)
