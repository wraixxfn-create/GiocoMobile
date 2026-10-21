@tool
class_name SceneryBeachHut
extends SceneryProp
## Chiosco tropicale: piattaforma in legno, pali, bancone, tetto di paglia a
## strati e tenda a righe. È il landmark della fascia intermedia: compare
## raramente e dà al livello un punto riconoscibile.
##
## Costruito con blocchi smussati e cilindri condivisi: pochi materiali, ombre
## nette e proporzioni da giocattolo.

const HUT_VIEW_DISTANCE: float = 270.0
const _BEVEL: float = 0.05

static var _cache: Dictionary = {}


func _ready() -> void:
	view_distance = HUT_VIEW_DISTANCE
	super._ready()


func _box(
	name: String,
	size: Vector3,
	material: Material,
	position: Vector3,
	yaw: float = 0.0,
	bevel: float = _BEVEL,
) -> void:
	var data := PropMeshes.beveled_box(size, bevel)
	add_accumulated(
		name,
		{"verts": data["verts"], "tris": data["tris"]},
		material,
		Transform3D(Basis(Vector3.UP, yaw), position),
	)


func build() -> void:
	var wood := MaterialFactory.wood()
	var wood_light := MaterialFactory.wood(true)
	var thatch := MaterialFactory.thatch()
	var thatch_dark := MaterialFactory.thatch(true)

	# Piattaforma e zoccolo.
	_box("Deck", Vector3(4.4, 0.28, 3.0), wood, Vector3(0.0, 0.28, 0.0))
	_box("DeckTrim", Vector3(4.6, 0.10, 3.2), wood_light, Vector3(0.0, 0.10, 0.0))

	# Pali angolari e trave di colmo.
	for x: float in [-1.9, 1.9]:
		for z: float in [-1.25, 1.25]:
			var post := PropMeshes.cylinder(0.10, 2.75, 0.13, 0.11, 7)
			add_accumulated(
				"Post",
				{"verts": post["verts"], "tris": post["tris"]},
				wood_light,
				Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z)),
			)
	_box("Beam", Vector3(4.2, 0.16, 0.16), wood_light, Vector3(0.0, 2.65, -1.25))

	# Bancone anteriore e schienale.
	_box("Counter", Vector3(4.0, 0.62, 0.20), wood_light, Vector3(0.0, 1.05, 1.18))
	_box("CounterTop", Vector3(4.15, 0.10, 0.42), thatch_dark, Vector3(0.0, 1.40, 1.18))
	_box("BackWall", Vector3(3.7, 1.55, 0.12), wood, Vector3(0.0, 1.35, -1.18))

	# Tetto di paglia a tre strati sfalsati: volumi leggibili e ombra morbida.
	_box("RoofLower", Vector3(5.1, 0.26, 3.7), thatch, Vector3(0.0, 2.62, 0.0), 0.02, 0.09)
	_box("RoofMid", Vector3(4.5, 0.24, 3.2), thatch, Vector3(0.0, 2.84, 0.0), -0.03, 0.09)
	_box("RoofTop", Vector3(3.5, 0.22, 2.5), thatch_dark, Vector3(0.0, 3.04, 0.0), 0.04, 0.09)
	_box("Ridge", Vector3(3.6, 0.20, 0.34), thatch_dark, Vector3(0.0, 3.18, 0.0))

	# Tenda a righe sul davanti: due falde inclinate.
	for sign: float in [-1.0, 1.0]:
		var panel := PropMeshes.beveled_box(Vector3(1.55, 0.07, 1.25), 0.02)
		var basis := Basis(Vector3.UP, 0.0) * Basis(Vector3.RIGHT, deg_to_rad(-18.0))
		add_accumulated(
			"Awning",
			{"verts": panel["verts"], "tris": panel["tris"]},
			MaterialFactory.fabric(0 if sign < 0.0 else 1),
			Transform3D(basis, Vector3(sign * 1.15, 2.30, 1.75)),
		)

	# Cassette di legno e insegna.
	_box("CrateA", Vector3(0.62, 0.52, 0.62), wood_light, Vector3(-2.35, 0.65, 0.9))
	_box("CrateB", Vector3(0.52, 0.44, 0.52), wood, Vector3(-2.30, 0.44, 1.35), 0.35)
	_box("Sign", Vector3(2.3, 0.72, 0.10), MaterialFactory.sign_green(), Vector3(0.0, 2.16, 1.30))
	_box("SignBand", Vector3(1.9, 0.16, 0.06), MaterialFactory.sign_yellow(), Vector3(0.0, 2.16, 1.36))
