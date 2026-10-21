class_name CarCompatibilityValidator
extends RefCounted
## Validatore puro e senza stato della compatibilità tra componenti modulari.
##
## Controlla livello richiesto, architettura della carrozzeria (`Silhouette`),
## tag dei punti di montaggio (`mount_tags`) ed esclusioni reciproche tra ID dati.

enum Reason {
	OK = 0,
	NULL_PART = 1,
	INVALID_SLOT = 2,
	LEVEL_TOO_LOW = 3,
	INCOMPATIBLE_SILHOUETTE = 4,
	MISSING_MOUNT_TAG = 5,
	CONFLICTS_WITH_EQUIPPED = 6,
}


static func validate(
	part: CarPartDefinition,
	body_part: CarPartDefinition,
	sockets: CarBodySockets,
	equipped_parts: Dictionary,
	current_level: int = 99,
	enforce_level: bool = false,
) -> Dictionary:
	if part == null or part.id == &"":
		return _fail(Reason.NULL_PART, "Componente nullo o privo di identificativo.")
	if not CarPartSlot.is_valid(part.slot):
		return _fail(Reason.INVALID_SLOT, "Slot componente non valido: %d." % part.slot)
	if enforce_level and current_level < part.required_level:
		return _fail(
			Reason.LEVEL_TOO_LOW,
			"Livello richiesto %d superiore al livello attuale %d."
			% [part.required_level, current_level],
		)
	if part.slot == CarPartSlot.Type.BODY:
		return _ok()

	var compat := part.resolved_compatibility()
	var active_sil := _resolve_silhouette(body_part, sockets)
	if not compat.compatible_silhouettes.is_empty():
		if not compat.compatible_silhouettes.has(active_sil):
			return _fail(
				Reason.INCOMPATIBLE_SILHOUETTE,
				"Componente %s non compatibile con la silhouette %d." % [part.id, active_sil],
			)

	if sockets != null and not compat.required_mount_tags.is_empty():
		for tag in compat.required_mount_tags:
			if not sockets.has_tag(part.slot, tag):
				return _fail(
					Reason.MISSING_MOUNT_TAG,
					"Punto di montaggio '%s' assente sulla carrozzeria." % tag,
				)

	for other_slot in equipped_parts.keys():
		if int(other_slot) == part.slot:
			continue
		var other := equipped_parts[other_slot] as CarPartDefinition
		if other == null:
			continue
		if compat.incompatible_part_ids.has(String(other.id)):
			return _fail(
				Reason.CONFLICTS_WITH_EQUIPPED,
				"Incompatibile con il componente equipaggiato '%s'." % other.id,
			)
		var other_compat := other.resolved_compatibility()
		if other_compat.incompatible_part_ids.has(String(part.id)):
			return _fail(
				Reason.CONFLICTS_WITH_EQUIPPED,
				"Il componente '%s' esclude '%s'." % [other.id, part.id],
			)

	return _ok()


static func _resolve_silhouette(body_part: CarPartDefinition, sockets: CarBodySockets) -> int:
	if body_part != null:
		return body_part.resolved_visual_spec().body_silhouette
	if sockets != null:
		return sockets.body_silhouette
	return CarEvolutionProfile.Silhouette.HATCHBACK


static func _ok() -> Dictionary:
	return {"ok": true, "reason": Reason.OK, "message": ""}


static func _fail(reason: int, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
