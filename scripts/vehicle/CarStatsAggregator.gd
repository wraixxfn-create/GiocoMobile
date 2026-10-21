class_name CarStatsAggregator
extends RefCounted
## Aggregatore puro dei modificatori di gameplay e degli ingombri fisici.
##
## Combina i valori base dello stadio (`CarEvolutionProfile`) con i delta dei
## componenti equipaggiati (`Slot -> CarPartDefinition`). Per gli ingombri
## fisici (`half_width`, `half_length`), il profilo dello stadio descrive già
## l'ingombro del suo assetto predefinito: eventuali parti custom applicano il
## delta differenziale rispetto al componente base dello stadio, rispettando
## sempre il vincolo di giocabilità nei corridoi minimi (`OBSTACLE_GAP_MIN`).

const FAIRNESS_GAP_CLEARANCE: float = 0.25


static func compute(
	profile: CarEvolutionProfile,
	equipped_parts: Dictionary,
) -> Dictionary:
	var base_width := profile.half_width if profile != null else GameConfig.CAR_HALF_WIDTH
	var base_length := profile.half_length if profile != null else GameConfig.CAR_HALF_LENGTH
	var base_wheel_r := profile.wheel_radius if profile != null else 0.30
	var stage_defaults := (
		CarPartRegistry.loadout_for_stage(profile.level) if profile != null else null
	)

	var speed_sum := 0.0
	var handling_sum := 0.0
	var width_delta := 0.0
	var length_delta := 0.0
	var wheel_r_scale := 1.0

	for slot in equipped_parts.keys():
		var part := equipped_parts[slot] as CarPartDefinition
		if part == null:
			continue
		var mod := part.resolved_modifiers()
		speed_sum += mod.speed_bonus
		handling_sum += mod.handling_bonus
		if int(slot) == CarPartSlot.Type.WHEELS:
			wheel_r_scale *= mod.wheel_radius_scale
		var base_hw_mod := 0.0
		var base_hl_mod := 0.0
		if stage_defaults != null:
			var def_part := stage_defaults.get_part(int(slot))
			if def_part != null:
				var dmod := def_part.resolved_modifiers()
				base_hw_mod = dmod.half_width_delta
				base_hl_mod = 0.5 * (dmod.front_overhang_delta + dmod.rear_overhang_delta)
		var part_hl_mod := 0.5 * (mod.front_overhang_delta + mod.rear_overhang_delta)
		width_delta += mod.half_width_delta - base_hw_mod
		length_delta += part_hl_mod - base_hl_mod

	var speed_mult := maxf(1.0 + speed_sum, 0.45)
	var handling_mult := maxf(1.0 + handling_sum, 0.45)
	var raw_length := clampf(base_length + length_delta, 1.05, 2.34)
	var yaw := GameConfig.CAR_MAX_STEER_YAW
	var max_safe_lat := (GameConfig.OBSTACLE_GAP_MIN - FAIRNESS_GAP_CLEARANCE) * 0.5
	var max_fair_half_w := (max_safe_lat - raw_length * sin(yaw)) / maxf(cos(yaw), 0.2)
	var eff_half_w := clampf(base_width + width_delta, 0.65, max_fair_half_w)
	var eff_wheel_r := clampf(base_wheel_r * wheel_r_scale, 0.20, 0.48)

	return {
		"speed_multiplier": speed_mult,
		"handling_multiplier": handling_mult,
		"half_width": eff_half_w,
		"half_length": raw_length,
		"wheel_radius": eff_wheel_r,
	}


static func lateral_half_extent(half_width: float, half_length: float, yaw: float) -> float:
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	return half_width * c + half_length * s


static func longitudinal_half_extent(half_width: float, half_length: float, yaw: float) -> float:
	var c := absf(cos(yaw))
	var s := absf(sin(yaw))
	return half_width * s + half_length * c
