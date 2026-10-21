@tool
class_name SceneryRoadSign
extends SceneryProp
## Cartello stradale tropicale: due montanti, pannello verde con cornice
## gialla e freccia bianca. Aggiunge un elemento "disegnato" alla fascia
## intermedia, coerente con la palette degli oggetti di gameplay.

const SIGN_VIEW_DISTANCE: float = 225.0


func _ready() -> void:
	view_distance = SIGN_VIEW_DISTANCE
	super._ready()


func _panel(
	name: String,
	size: Vector3,
	material: Material,
	position: Vector3,
	yaw: float = 0.0,
) -> void:
	var data := PropMeshes.beveled_box(size, 0.03)
	add_accumulated(
		name,
		{"verts": data["verts"], "tris": data["tris"]},
		material,
		Transform3D(Basis(Vector3.UP, yaw), position),
	)


func build() -> void:
	var metal := MaterialFactory.metal()
	for x in [-0.85, 0.85]:
		var post := PropMeshes.cylinder(0.0, 2.15, 0.075, 0.065, 6)
		add_accumulated(
			"Post",
			{"verts": post["verts"], "tris": post["tris"]},
			metal,
			Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0)),
		)
	_panel("Frame", Vector3(2.35, 1.0, 0.09), MaterialFactory.sign_yellow(), Vector3(0.0, 2.05, 0.0))
	_panel("Board", Vector3(2.15, 0.82, 0.10), MaterialFactory.sign_green(), Vector3(0.0, 2.05, 0.02))
	# Freccia: asta + punta, costruita con due blocchi smussati.
	_panel("ArrowShaft", Vector3(0.85, 0.14, 0.05), MaterialFactory.scenery(
		"arrow_paint", SceneryPalette.FABRIC_CREAM, 0.5, 0.0
	), Vector3(-0.18, 2.05, 0.08))
	for sign in [-1.0, 1.0]:
		_panel(
			"ArrowTip",
			Vector3(0.46, 0.13, 0.05),
			MaterialFactory.scenery("arrow_paint", SceneryPalette.FABRIC_CREAM, 0.5, 0.0),
			Vector3(0.42, 2.05 + sign * 0.14, 0.08),
			sign * 0.72,
		)
