class_name CarPartVisualSpec
extends Resource
## Specifica parametrica puramente dichiarativa del prototipo 3D modulare.
##
## Usata da `CarPartMeshBuilder` solo quando `CarPartDefinition.model_scene` è
## `null`. Non contiene riferimenti a nodi o logica di gioco.

## Archetipo geometrico del prototipo (es. `&"ducktail"`, `&"gt_wing"`,
## `&"biplane"`, `&"five_spoke"`, `&"multispoke"`, `&"turbofan"`, ecc.).
@export var archetype: StringName = &"stock"

## Silhouette della carrozzeria quando il componente appartiene allo slot `BODY`.
@export var body_silhouette: int = CarEvolutionProfile.Silhouette.HATCHBACK

## Fattori di proporzione e molteplicità geometrica specifici della variante.
@export var primary_scale: Vector3 = Vector3.ONE
@export var secondary_scale: Vector3 = Vector3.ONE
@export var element_count: int = 1
@export var has_accent_stripe: bool = false
@export var accent_color: Color = Color(0.92, 0.20, 0.16)
