class_name CarStatsAggregator
extends RefCounted
## Aggregatore puro delle statistiche di gameplay e degli ingombri fisici.
##
## Combina il profilo base della carrozzeria con i `CarGameplayModifiers` di
## tutti i componenti attualmente montati, mantenendo sempre l'invariante di
## percorribilità dei varchi minimi della pista (`OBSTACLE_GAP_MIN`).

## Margine minimo garantito rispetto al varco più stretto degli ostacoli (m).
const FAIRNESS_GAP_CLEARANCE: float = 0.26


static func compute(
	profile: CarEvolutionProfile,
	equipped_parts: Dictionary,
) -> Dictionary:
	var fallback := profile if profile != null else CarEvolutionCatalog.profile_for(1)
	if equipped_parts.is_empty():
		return {
			"speed_multiplier": fallback.speed_multiplier,
			"handling_multiplier": fallback.handling_multiplier,
			"wheel_radius": fallback.wheel_radius,
			"wheel_width_scale": 1.0,
			"half_width": fallback.half_width,
			"half_length": fallback.half_length,
		}

	var speed_sum := 1.0
	var handling_sum := 1.0
	var width_delta := 0.0
	var front_overhang := 0.0
	var rear_overhang := 0.0
	var radius_scale := 1.0
	var tire_width_scale := 1.0

	for slot in equipped_parts.keys():
		var part := equipped_parts[slot] as CarPartDefinition
		if part == null:
			continue
		var mod := part.resolved_modifiers()
		speed_sum += mod.speed_bonus
		handling_sum += mod.handling_bonus
		width_delta += mod.half_width_delta
		front_overhang = maxf(front_overhang, mod.front_overhang_delta)
		rear_overhang = maxf(rear_overhang, mod.rear_overhang_delta)
		if int(slot) == CarPartSlot.Type.WHEELS:
			radius_scale = mod.wheel_radius_scale
			tire_width_scale = mod.wheel_width_scale

	var raw_half_w := maxf(fallback.half_width + width_delta, 0.55)
	var raw_half_l := maxf(
		fallback.half_length + 0.5 * (front_overhang + rear_overhang),
		0.95,
	)

	# Garantisce che anche un assetto ultra-largo resti fisicamente passabile
	# nei varchi minimi della carreggiata senza alterare la fairness del gioco.
	var max_half_span := (GameConfig.OBSTACLE_GAP_MIN - FAIRNESS_GAP_CLEARANCE) * 0.5
	var cos_yaw := cos(GameConfig.CAR_MAX_STEER_YAW)
	var sin_yaw := sin(GameConfig.CAR_MAX_STEER_YAW)
	var current_span := raw_half_w * cos_yaw + raw_half_l * sin_yaw
	if current_span > max_half_span and current_span > 0.0001:
		var ratio := max_half_span / current_span
		raw_half_w *= ratio
		raw_half_l *= ratio

	return {
		"speed_multiplier": clampf(speed_sum, 0.25, 3.0),
		"handling_multiplier": clampf(handling_sum, 0.25, 3.0),
		"wheel_radius": maxf(fallback.wheel_radius * radius_scale, 0.12),
		"wheel_width_scale": clampf(tire_width_scale, 0.75, 1.40),
		"half_width": raw_half_w,
		"half_length": raw_half_l,
	}


static func lateral_half_extent(half_width: float, half_length: float, yaw: float) -> float:
	return half_width * cos(absf(yaw)) + half_length * sin(absf(yaw))


static func longitudinal_half_extent(half_width: float, half_length: float, yaw: float) -> float:
	return half_width * sin(absf(yaw)) + half_length * cos(absf(yaw))
