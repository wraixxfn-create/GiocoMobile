class_name CarModelBuilder
extends RefCounted
## Facciata di costruzione del veicolo modulare a partire da un profilo dati.
##
## Non assembla più un monoblocco indivisibile: istanzia un `VehicleRig`
## modulare e vi monta i componenti dati `CarPartDefinition` previsti per lo
## stadio (o per un `CarLoadout` personalizzato). Mantiene intatto il contratto
## del dizionario restituito (`root`, `wheels`, `body_meshes`, `pips`,
## `glow_materials`) per la piena retrocompatibilità con il resto del progetto.

const KEY_ROOT: String = "root"
const KEY_WHEELS: String = "wheels"
const KEY_BODY_MESHES: String = "body_meshes"
const KEY_PIPS: String = "pips"
const KEY_GLOW_MATERIALS: String = "glow_materials"
const KEY_RIG: String = "rig"


static func build(
	profile: CarEvolutionProfile,
	custom_loadout: CarLoadout = null,
) -> Dictionary:
	var resolved_profile := (
		profile if profile != null else CarEvolutionCatalog.profile_for(1)
	)
	var loadout := (
		custom_loadout if custom_loadout != null
		else CarPartRegistry.loadout_for_stage(resolved_profile.level)
	)

	var rig := VehicleRig.new()
	rig.name = "Stage_%d" % resolved_profile.level
	rig.apply_loadout(loadout, resolved_profile)

	return {
		KEY_ROOT: rig,
		KEY_RIG: rig,
		KEY_WHEELS: rig.get_wheel_hubs(),
		KEY_BODY_MESHES: rig.get_paint_meshes(),
		KEY_PIPS: rig.get_pips(),
		KEY_GLOW_MATERIALS: rig.get_glow_entries(),
	}
