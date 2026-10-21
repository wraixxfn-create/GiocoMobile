@tool
class_name SceneryMarkerPost
extends SceneryProp
## Delineatore di bordo pista: paletto bianco smussato, fascia scura e
## catarifrangente arancione. Segna il limite dell'asfalto nel primo piano
## senza competere con i cancelli.

const MARKER_VIEW_DISTANCE: float = 130.0


func _ready() -> void:
	view_distance = MARKER_VIEW_DISTANCE
	super._ready()


func build() -> void:
	var body := PropMeshes.beveled_box(Vector3(0.15, 0.95, 0.15), 0.03)
	add_accumulated(
		"Post",
		{"verts": body["verts"], "tris": body["tris"]},
		MaterialFactory.scenery("marker", SceneryPalette.CURB_LIGHT, 0.55, 0.05),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.47, 0.0)),
	)
	var band := PropMeshes.beveled_box(Vector3(0.17, 0.17, 0.17), 0.02)
	add_accumulated(
		"Band",
		{"verts": band["verts"], "tris": band["tris"]},
		MaterialFactory.scenery("marker_band", Color(0.24, 0.26, 0.30), 0.55, 0.10),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.62, 0.0)),
	)
	var lens := PropMeshes.beveled_box(Vector3(0.18, 0.11, 0.18), 0.02)
	add_accumulated(
		"Reflector",
		{"verts": lens["verts"], "tris": lens["tris"]},
		MaterialFactory.emissive(
			"marker_reflector", SceneryPalette.CURB_RED.lightened(0.18), 0.9
		),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.80, 0.0)),
		false,
		90.0,
	)