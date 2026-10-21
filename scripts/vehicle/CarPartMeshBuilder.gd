class_name CarPartMeshBuilder
extends RefCounted
## Generatore modulare di geometria 3D per i singoli componenti dell'auto.
##
## Per ciascuno slot (`BODY`, `BUMPER_FRONT`, `BUMPER_REAR`, `WHEELS`, `ENGINE`,
## `EXHAUST`, `SPOILER`, `AERO`):
##   1. Se `part.model_scene` è valorizzato, istanzia il modello esterno `.tscn`
##      (es. asset Blender `.glb` incapsulato) adattandolo ai punti di attacco.
##   2. Altrimenti costruisce il prototipo procedurale modulare parametrizzato
##      da `part.visual_spec` e dalle misure reali di `CarBodySockets`.

const KEY_INSTANCE: String = "instance"
const KEY_WHEEL_NODES: String = "wheel_nodes"
const KEY_PAINT_MESHES: String = "paint_meshes"
const KEY_PIPS: String = "pips"
const KEY_GLOW_ENTRIES: String = "glow_entries"
const KEY_SOCKETS: String = "sockets"


static func build_part(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	if part == null:
		return _empty_result()

	if part.model_scene != null and part.model_scene.can_instantiate():
		return _instantiate_external_part(part, profile, sockets)

	match part.slot:
		CarPartSlot.Type.BODY:
			return CarBodyMeshBuilder.build_body(part, profile)
		CarPartSlot.Type.WHEELS:
			return _build_wheel_set(part, profile, sockets)
		CarPartSlot.Type.BUMPER_FRONT:
			return _build_front_bumper(part, profile, sockets)
		CarPartSlot.Type.BUMPER_REAR:
			return _build_rear_bumper(part, profile, sockets)
		CarPartSlot.Type.ENGINE:
			return _build_engine(part, profile, sockets)
		CarPartSlot.Type.EXHAUST:
			return _build_exhaust(part, profile, sockets)
		CarPartSlot.Type.SPOILER:
			return _build_spoiler(part, profile, sockets)
		CarPartSlot.Type.AERO:
			return _build_aero(part, profile, sockets)
		_:
			return _empty_result()


# --------------------------------------------------- Modelli 3D esterni -----

static func _instantiate_external_part(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	if part.slot == CarPartSlot.Type.WHEELS:
		var wheel_nodes: Array[Node3D] = []
		var glow_list: Array = []
		for hub_i in 4:
			var inst := part.model_scene.instantiate() as Node3D
			if inst == null:
				inst = Node3D.new()
			var hub := sockets.wheel_hub(hub_i) if sockets != null else {"side": 1.0}
			var side := float(hub.get("side", 1.0))
			if side < 0.0:
				inst.rotation_degrees.y += 180.0
			inst.position += part.mount_offset
			wheel_nodes.append(inst)
			glow_list.append_array(_find_emissive_entries(inst))
		return {
			KEY_INSTANCE: null,
			KEY_WHEEL_NODES: wheel_nodes,
			KEY_PAINT_MESHES: [],
			KEY_PIPS: [],
			KEY_GLOW_ENTRIES: glow_list,
			KEY_SOCKETS: null,
		}

	var instance := part.model_scene.instantiate() as Node3D
	if instance == null:
		return _empty_result()
	instance.position += part.mount_offset
	instance.rotation_degrees += part.mount_rotation_degrees
	if part.slot != CarPartSlot.Type.BODY and sockets != null:
		instance.scale = instance.scale * sockets.compute_external_fit_scale(part)

	var body_sockets: CarBodySockets = null
	if part.slot == CarPartSlot.Type.BODY:
		var fallback := CarBodyMeshBuilder.build_body(null, profile)
		var fallback_root := fallback.get("instance", null) as Node3D
		if fallback_root != null:
			fallback_root.free()
		body_sockets = CarBodySockets.extract_from_scene(
			instance,
			fallback.get("sockets", null) as CarBodySockets,
		)

	return {
		KEY_INSTANCE: instance,
		KEY_WHEEL_NODES: [],
		KEY_PAINT_MESHES: _find_meshes(instance),
		KEY_PIPS: [],
		KEY_GLOW_ENTRIES: _find_emissive_entries(instance),
		KEY_SOCKETS: body_sockets,
	}


# -------------------------------------------------------- Paraurti ant. -----

static func _build_front_bumper(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var root := Node3D.new()
	var m := CarBodyMeshBuilder.make_materials(profile)
	var paint: Array = []
	var glow: Array = []
	var body_mat: Material = m["body"]
	var spec := part.resolved_visual_spec()
	var span_w := sockets.socket_width(CarPartSlot.Type.BUMPER_FRONT) * spec.primary_scale.x
	var hw := span_w * 0.5
	var arch := spec.archetype
	var accent_mat := MaterialFactory.colored(
		"part_accent_" + String(part.id), spec.accent_color, 0.35, 0.15
	)

	if arch == &"front_bullbar":
		var tube_main := CarBodyFactory.build_capsule(0.036, hw * 1.56)
		var tube_up := CarBodyFactory.build_capsule(0.026, hw * 0.96)
		CarBodyMeshBuilder.add_mesh(
			root, "BarLower", tube_main, m["trim_alt"], [], null,
			Vector3(0.0, -0.02, -0.05), Vector3(0.0, 0.0, 90.0),
		)
		CarBodyMeshBuilder.add_mesh(
			root, "BarUpper", tube_up, m["trim_alt"], [], null,
			Vector3(0.0, 0.11, -0.06), Vector3(0.0, 0.0, 90.0),
		)
		var guard := CylinderMesh.new()
		guard.top_radius = 0.026
		guard.bottom_radius = 0.028
		guard.height = 0.24
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "PushPost", guard, m["trim"], [], null,
				Vector3(side * hw * 0.44, 0.05, -0.055), Vector3(8.0, 0.0, 0.0),
			)
		var skid := BoxMesh.new()
		skid.size = Vector3(hw * 0.92, 0.10, 0.05)
		CarBodyMeshBuilder.add_mesh(
			root, "SkidPlate", skid, m["trim"], [], null,
			Vector3(0.0, -0.055, -0.025), Vector3(-22.0, 0.0, 0.0),
		)
		return _pack_part(root, paint, glow, part)

	# Fascia verniciata raccordata alla carrozzeria.
	CarBodyMeshBuilder.add_mesh(
		root, "FasciaMain",
		CarBodyFactory.build_wing_span(hw * 0.95, 0.17, 0.13, 0.015, 0.05, 0.0, 0.88),
		body_mat, paint, body_mat, Vector3(0.0, 0.03, -0.01),
	)
	var grille := BoxMesh.new()
	grille.size = Vector3(hw * 0.96, 0.09, 0.06)
	CarBodyMeshBuilder.add_mesh(
		root, "LowerAirDam", grille, m["well"], [], null, Vector3(0.0, -0.01, -0.055),
	)

	if arch == &"front_street":
		var lip := CarBodyFactory.build_wing_span(hw * 0.92, 0.11, 0.035, 0.0, 0.04, 0.0, 0.90)
		CarBodyMeshBuilder.add_mesh(
			root, "StreetChin", lip, m["trim"], [], null, Vector3(0.0, -0.055, -0.045),
		)
		var fog_mat := MaterialFactory.unique_emissive(spec.accent_color, 1.1)
		var fog_sphere := SphereMesh.new()
		fog_sphere.radius = 0.034
		fog_sphere.height = 0.068
		for side: float in [-1.0, 1.0]:
			var fog := CarBodyMeshBuilder.add_mesh(
				root, "FogLamp", fog_sphere, fog_mat, [], null,
				Vector3(side * hw * 0.72, 0.005, -0.075),
			)
			if fog != null:
				fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				glow.append(fog)
	elif arch == &"front_splitter":
		var splitter := CarBodyFactory.build_wing_span(
			hw * 1.01, 0.24, 0.032, -0.006, 0.05, 0.0, 0.94
		)
		CarBodyMeshBuilder.add_mesh(
			root, "SportSplitter", splitter, m["carbon"], [], null,
			Vector3(0.0, -0.065, -0.095),
		)
		var trim_edge := CarBodyFactory.build_wing_span(
			hw * 1.02, 0.045, 0.018, 0.0, 0.05, 0.0, 0.95
		)
		CarBodyMeshBuilder.add_mesh(
			root, "SplitterAccent", trim_edge, accent_mat, [], null,
			Vector3(0.0, -0.065, -0.195),
		)
		var rod := CylinderMesh.new()
		rod.top_radius = 0.008
		rod.bottom_radius = 0.008
		rod.height = 0.13
		var duct := BoxMesh.new()
		duct.size = Vector3(hw * 0.30, 0.085, 0.10)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "SupportRod", rod, m["chrome"], [], null,
				Vector3(side * hw * 0.36, -0.015, -0.135), Vector3(-28.0, 0.0, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "BrakeDuct", duct, m["trim"], [], null,
				Vector3(side * hw * 0.73, 0.005, -0.055), Vector3(0.0, side * -10.0, 0.0),
			)
	else:
		# `front_gt_aero`: splitter endurance profondo + endplate verticali + doppi canard.
		var main_plane := CarBodyFactory.build_wing_span(
			hw * 1.05, 0.30, 0.036, -0.010, 0.06, 0.0, 0.96
		)
		CarBodyMeshBuilder.add_mesh(
			root, "GtMainSplitter", main_plane, m["carbon"], [], null,
			Vector3(0.0, -0.072, -0.125),
		)
		CarBodyMeshBuilder.add_mesh(
			root, "GtLeadStripe",
			CarBodyFactory.build_wing_span(hw * 1.055, 0.045, 0.020, 0.0, 0.06, 0.0, 0.96),
			accent_mat, [], null, Vector3(0.0, -0.072, -0.255),
		)
		var plate := BoxMesh.new()
		plate.size = Vector3(0.026, 0.16, 0.24)
		var canard := BoxMesh.new()
		canard.size = Vector3(0.16, 0.016, 0.17)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "GtFrontEndplate", plate, body_mat, paint, body_mat,
				Vector3(side * hw * 1.04, -0.01, -0.115),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "CanardLower", canard, m["carbon"], [], null,
				Vector3(side * hw * 0.96, 0.045, -0.075),
				Vector3(16.0, side * -18.0, side * -14.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "CanardUpper", canard, accent_mat, [], null,
				Vector3(side * hw * 0.93, 0.105, -0.045),
				Vector3(20.0, side * -18.0, side * -16.0), Vector3(0.84, 1.0, 0.85),
			)
	return _pack_part(root, paint, glow, part)


# ------------------------------------------------------- Paraurti post. -----

static func _build_rear_bumper(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var root := Node3D.new()
	var m := CarBodyMeshBuilder.make_materials(profile)
	var paint: Array = []
	var glow: Array = []
	var body_mat: Material = m["body"]
	var spec := part.resolved_visual_spec()
	var span_w := sockets.socket_width(CarPartSlot.Type.BUMPER_REAR) * spec.primary_scale.x
	var hw := span_w * 0.5
	var arch := spec.archetype
	var accent_mat := MaterialFactory.colored(
		"part_accent_" + String(part.id), spec.accent_color, 0.35, 0.15
	)

	if arch == &"rear_raw":
		CarBodyMeshBuilder.add_mesh(
			root, "RawBeam", CarBodyFactory.build_capsule(0.048, hw * 1.56), m["trim_alt"],
			[], null, Vector3(0.0, 0.01, 0.045), Vector3(0.0, 0.0, 90.0),
		)
		var bracket := BoxMesh.new()
		bracket.size = Vector3(0.06, 0.09, 0.10)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "RawBracket", bracket, m["trim"], [], null,
				Vector3(side * hw * 0.50, 0.01, 0.01),
			)
		return _pack_part(root, paint, glow, part)

	# Grembialatura superiore in tinta carrozzeria.
	CarBodyMeshBuilder.add_mesh(
		root, "RearValence",
		CarBodyFactory.build_wing_span(hw * 0.96, 0.16, 0.13, 0.012, -0.04, 0.0, 0.90),
		body_mat, paint, body_mat, Vector3(0.0, 0.035, 0.015),
	)

	if arch == &"rear_street":
		CarBodyMeshBuilder.add_mesh(
			root, "Lower Apron",
			CarBodyFactory.build_wing_span(hw * 0.90, 0.11, 0.055, 0.0, -0.03, 0.0, 0.90),
			m["trim"], [], null, Vector3(0.0, -0.045, 0.035),
		)
		var refl := BoxMesh.new()
		refl.size = Vector3(0.16, 0.026, 0.025)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "RearReflector", refl, accent_mat, [], null,
				Vector3(side * hw * 0.68, -0.015, 0.088),
			)
	elif arch == &"rear_diffuser":
		CarBodyMeshBuilder.add_mesh(
			root, "DiffuserTray",
			CarBodyFactory.build_wing_span(hw * 0.94, 0.22, 0.045, 0.0, -0.03, 0.0, 0.94),
			m["carbon"], [], null, Vector3(0.0, -0.052, 0.068), Vector3(-9.0, 0.0, 0.0),
		)
		var strake := BoxMesh.new()
		strake.size = Vector3(0.022, 0.105, 0.22)
		for fin_x: float in [-0.52, -0.18, 0.18, 0.52]:
			CarBodyMeshBuilder.add_mesh(
				root, "DiffuserFin", strake, m["carbon"], [], null,
				Vector3(fin_x * hw, -0.068, 0.082), Vector3(-8.0, 0.0, 0.0),
			)
		var spat := BoxMesh.new()
		spat.size = Vector3(0.045, 0.12, 0.18)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "CornerSpat", spat, body_mat, paint, body_mat,
				Vector3(side * hw * 0.95, -0.015, 0.048),
			)
	else:
		# `rear_gt_venturi`: tunnel Venturi estesi + endplate + faro pioggia FIA.
		CarBodyMeshBuilder.add_mesh(
			root, "VenturiDeck",
			CarBodyFactory.build_wing_span(hw * 1.02, 0.28, 0.042, 0.008, -0.04, 0.02, 0.96),
			m["carbon"], [], null, Vector3(0.0, -0.048, 0.105), Vector3(-12.0, 0.0, 0.0),
		)
		CarBodyMeshBuilder.add_mesh(
			root, "VenturiTrim",
			CarBodyFactory.build_wing_span(hw * 1.02, 0.042, 0.020, 0.0, -0.04, 0.02, 0.96),
			accent_mat, [], null, Vector3(0.0, -0.022, 0.225),
		)
		var tall_fin := BoxMesh.new()
		tall_fin.size = Vector3(0.024, 0.135, 0.28)
		for fin_x: float in [-0.74, -0.46, -0.20, 0.20, 0.46, 0.74]:
			CarBodyMeshBuilder.add_mesh(
				root, "VenturiBlade", tall_fin, m["carbon"], [], null,
				Vector3(fin_x * hw, -0.062, 0.112), Vector3(-10.0, 0.0, 0.0),
			)
		var side_wing := BoxMesh.new()
		side_wing.size = Vector3(0.028, 0.18, 0.24)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "RearEndplate", side_wing, body_mat, paint, body_mat,
				Vector3(side * hw * 1.02, 0.005, 0.088),
			)
		var rain_mat := MaterialFactory.unique_emissive(Color(1.0, 0.14, 0.12), 2.1)
		var rain_box := BoxMesh.new()
		rain_box.size = Vector3(0.085, 0.055, 0.035)
		var rain := CarBodyMeshBuilder.add_mesh(
			root, "FiaRainLight", rain_box, rain_mat, [], null, Vector3(0.0, -0.052, 0.215),
		)
		if rain != null:
			rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.append(rain)
	return _pack_part(root, paint, glow, part)


# --------------------------------------------------------- Set di ruote -----

static func _build_wheel_set(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var m := CarBodyMeshBuilder.make_materials(profile)
	var mod := part.resolved_modifiers()
	var spec := part.resolved_visual_spec()
	var wheels: Array[Node3D] = []
	for i in 4:
		var hub := sockets.wheel_hub(i) if sockets != null else {
			"side": -1.0 if i % 2 == 0 else 1.0,
			"base_radius": profile.wheel_radius,
			"base_width": profile.wheel_width,
		}
		var side := float(hub["side"])
		var radius := float(hub["base_radius"]) * mod.wheel_radius_scale
		var width := float(hub["base_width"]) * mod.wheel_width_scale
		wheels.append(_build_single_wheel(part, spec, m, radius, width, side))
	return {
		KEY_INSTANCE: null,
		KEY_WHEEL_NODES: wheels,
		KEY_PAINT_MESHES: [],
		KEY_PIPS: [],
		KEY_GLOW_ENTRIES: [],
		KEY_SOCKETS: null,
	}


static func _build_single_wheel(
	part: CarPartDefinition,
	spec: CarPartVisualSpec,
	m: Dictionary,
	radius: float,
	width: float,
	side: float,
) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = "WheelAssembly"
	var arch := spec.archetype
	var rim_r := 0.58 * radius
	if arch == &"wheel_multispoke":
		rim_r = 0.66 * radius
	elif arch == &"wheel_turbofan":
		rim_r = 0.63 * radius
	elif arch == &"wheel_steel":
		rim_r = 0.52 * radius

	var shoulder := 0.45 if arch == &"wheel_turbofan" else 0.43
	var tire_profile := [
		Vector2(-0.44 * width, rim_r * 0.96), Vector2(-0.50 * width, lerpf(rim_r, radius, 0.42)),
		Vector2(-0.50 * width, radius * 0.89), Vector2(-shoulder * width, radius * 0.965),
		Vector2(-0.28 * width, radius * 0.996), Vector2(0.0, radius),
		Vector2(0.28 * width, radius * 0.996), Vector2(shoulder * width, radius * 0.965),
		Vector2(0.50 * width, radius * 0.89), Vector2(0.50 * width, lerpf(rim_r, radius, 0.42)),
		Vector2(0.44 * width, rim_r * 0.96),
	]
	CarBodyMeshBuilder.add_mesh(
		assembly, "Tire", CarBodyFactory.build_lathe_x(tire_profile, 24, side), m["tire"]
	)
	var barrel_profile := [Vector2(-0.45 * width, rim_r), Vector2(0.43 * width, rim_r)]
	CarBodyMeshBuilder.add_mesh(
		assembly, "Barrel", CarBodyFactory.build_lathe_x(barrel_profile, 20, side), m["well"]
	)

	var accent_mat := MaterialFactory.colored(
		"wheel_accent_" + String(part.id), spec.accent_color, 0.26, 0.45
	)

	if arch == &"wheel_steel":
		var disc := CylinderMesh.new()
		disc.top_radius = rim_r * 0.98
		disc.bottom_radius = rim_r * 0.98
		disc.height = 0.032
		CarBodyMeshBuilder.add_mesh(
			assembly, "SteelDisc", disc, accent_mat, [], null,
			Vector3(side * (width * 0.44), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
		var hole_mesh := CylinderMesh.new()
		hole_mesh.top_radius = 0.065 * radius
		hole_mesh.bottom_radius = 0.065 * radius
		hole_mesh.height = 0.038
		for k in 8:
			var ang := TAU * float(k) / 8.0
			CarBodyMeshBuilder.add_mesh(
				assembly, "VentHole%d" % k, hole_mesh, m["well"], [], null,
				Vector3(
					side * (width * 0.45),
					0.34 * radius * cos(ang),
					0.34 * radius * sin(ang),
				),
				Vector3(0.0, 0.0, 90.0),
			)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.19 * radius
		cap.bottom_radius = 0.21 * radius
		cap.height = 0.055
		CarBodyMeshBuilder.add_mesh(
			assembly, "SteelCap", cap, m["trim"], [], null,
			Vector3(side * (width * 0.47), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
	elif arch == &"wheel_multispoke":
		# Disco freno in acciaio + pinza rossa + 10 razze sottili brunite.
		var rotor := CylinderMesh.new()
		rotor.top_radius = 0.48 * radius
		rotor.bottom_radius = 0.48 * radius
		rotor.height = 0.026
		CarBodyMeshBuilder.add_mesh(
			assembly, "BrakeRotor", rotor, m["chrome"], [], null,
			Vector3(side * (width * 0.16), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
		var caliper := BoxMesh.new()
		caliper.size = Vector3(0.065, 0.22 * radius, 0.14 * radius)
		CarBodyMeshBuilder.add_mesh(
			assembly, "BrakeCaliper", caliper, accent_mat, [], null,
			Vector3(side * (width * 0.20), 0.31 * radius, 0.14 * radius),
		)
		var gunmetal := MaterialFactory.colored("rim_gunmetal", Color(0.24, 0.26, 0.30), 0.22, 0.85)
		var lip := TorusMesh.new()
		lip.inner_radius = rim_r * 0.88
		lip.outer_radius = rim_r * 1.02
		lip.rings = 24
		lip.ring_segments = 10
		CarBodyMeshBuilder.add_mesh(
			assembly, "SportRimLip", lip, m["chrome"], [], null,
			Vector3(side * (width * 0.46), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.032, rim_r * 0.86, 0.095 * radius)
		for k in 10:
			var ang := TAU * float(k) / 10.0
			var off := rim_r * 0.46
			CarBodyMeshBuilder.add_mesh(
				assembly, "SportSpoke%d" % k, spoke, gunmetal, [], null,
				Vector3(side * (width * 0.42), off * cos(ang), off * sin(ang)),
				Vector3(rad_to_deg(ang), 0.0, side * 6.0),
			)
		var hub := CylinderMesh.new()
		hub.top_radius = 0.16 * radius
		hub.bottom_radius = 0.18 * radius
		hub.height = 0.05
		CarBodyMeshBuilder.add_mesh(
			assembly, "CenterHub", hub, accent_mat, [], null,
			Vector3(side * (width * 0.46), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
	elif arch == &"wheel_turbofan":
		# Anello racing giallo sulla spalla + disco aerodinamico dorato a 12 alette + center-lock.
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.72
		ring.outer_radius = radius * 0.80
		ring.rings = 24
		ring.ring_segments = 8
		CarBodyMeshBuilder.add_mesh(
			assembly, "TireSidewallStripe", ring, accent_mat, [], null,
			Vector3(side * (width * 0.495), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
		var fan_cone := CylinderMesh.new()
		fan_cone.top_radius = rim_r * 0.24
		fan_cone.bottom_radius = rim_r * 0.98
		fan_cone.height = 0.045
		CarBodyMeshBuilder.add_mesh(
			assembly, "AeroFanCover", fan_cone, accent_mat, [], null,
			Vector3(side * (width * 0.45), 0.0, 0.0), Vector3(0.0, 0.0, -90.0 * side),
		)
		var fin := BoxMesh.new()
		fin.size = Vector3(0.022, rim_r * 0.62, 0.045 * radius)
		for k in 12:
			var ang := TAU * float(k) / 12.0
			var off := rim_r * 0.56
			CarBodyMeshBuilder.add_mesh(
				assembly, "FanVane%d" % k, fin, m["carbon"], [], null,
				Vector3(side * (width * 0.48), off * cos(ang), off * sin(ang)),
				Vector3(rad_to_deg(ang) + 18.0, 0.0, 0.0),
			)
		var lock_nut := CylinderMesh.new()
		lock_nut.top_radius = 0.075 * radius
		lock_nut.bottom_radius = 0.145 * radius
		lock_nut.height = 0.065
		var nut_red := MaterialFactory.colored("center_lock_red", Color(0.92, 0.14, 0.14), 0.25, 0.7)
		CarBodyMeshBuilder.add_mesh(
			assembly, "CenterLockNut", lock_nut, nut_red, [], null,
			Vector3(side * (width * 0.50), 0.0, 0.0), Vector3(0.0, 0.0, -90.0 * side),
		)
	else:
		# `wheel_5spoke`: cerchio lega classico a 5 razze spesse lucide.
		var lip := TorusMesh.new()
		lip.inner_radius = 0.49 * radius
		lip.outer_radius = 0.60 * radius
		lip.rings = 24
		lip.ring_segments = 10
		CarBodyMeshBuilder.add_mesh(
			assembly, "ClassicLip", lip, m["chrome"], [], null,
			Vector3(side * (width * 0.45), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.046, 0.50 * radius, 0.20 * radius)
		for k in 5:
			var ang := deg_to_rad(float(k) * 72.0)
			var off := 0.29 * radius
			CarBodyMeshBuilder.add_mesh(
				assembly, "ClassicSpoke%d" % k, spoke, m["chrome"], [], null,
				Vector3(side * (width * 0.42), off * cos(ang), off * sin(ang)),
				Vector3(rad_to_deg(ang), 0.0, 0.0),
			)
		var hub := CylinderMesh.new()
		hub.top_radius = 0.17 * radius
		hub.bottom_radius = 0.19 * radius
		hub.height = 0.055
		CarBodyMeshBuilder.add_mesh(
			assembly, "ClassicHub", hub, m["chrome"], [], null,
			Vector3(side * (width * 0.43), 0.0, 0.0), Vector3(0.0, 0.0, 90.0),
		)
	return assembly


# ----------------------------------------------------------- Motore 3D ------

static func _build_engine(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var root := Node3D.new()
	var m := CarBodyMeshBuilder.make_materials(profile)
	var paint: Array = []
	var glow: Array = []
	var body_mat: Material = m["body"]
	var spec := part.resolved_visual_spec()
	var bay_w := sockets.socket_width(CarPartSlot.Type.ENGINE) * spec.primary_scale.x
	var bay_l := sockets.socket_length(CarPartSlot.Type.ENGINE) * spec.primary_scale.z
	var arch := spec.archetype
	var accent_mat := MaterialFactory.colored(
		"eng_accent_" + String(part.id), spec.accent_color, 0.28, 0.55
	)

	if arch == &"engine_hood_dome":
		CarBodyMeshBuilder.add_mesh(
			root, "PowerDome",
			CarBodyFactory.build_tapered_block(
				Vector2(bay_w * 0.52, 0.055), Vector2(bay_w * 0.68, 0.085), bay_l * 0.92,
				0.022, 0.036, 0.28,
			),
			body_mat, paint, body_mat,
		)
		var slot_box := BoxMesh.new()
		slot_box.size = Vector3(bay_w * 0.44, 0.032, 0.045)
		CarBodyMeshBuilder.add_mesh(
			root, "ScoopSlot", slot_box, m["well"], [], null,
			Vector3(0.0, 0.032, -bay_l * 0.44),
		)
	elif arch == &"engine_hood_turbo":
		CarBodyMeshBuilder.add_mesh(
			root, "CowlFrame",
			CarBodyFactory.build_tapered_block(
				Vector2(bay_w * 0.66, 0.065), Vector2(bay_w * 0.80, 0.095), bay_l * 0.98,
				0.025, 0.042, 0.22,
			),
			m["carbon"],
		)
		var cooler := BoxMesh.new()
		cooler.size = Vector3(bay_w * 0.44, 0.035, bay_l * 0.44)
		CarBodyMeshBuilder.add_mesh(
			root, "IntercoolerCore", cooler, m["chrome"], [], null, Vector3(0.0, 0.072, 0.02),
		)
		var louver := BoxMesh.new()
		louver.size = Vector3(bay_w * 0.18, 0.018, 0.075)
		for side: float in [-1.0, 1.0]:
			for idx in 3:
				CarBodyMeshBuilder.add_mesh(
					root, "HeatVent", louver, m["well"], [], null,
					Vector3(side * bay_w * 0.28, 0.068, -bay_l * 0.24 + float(idx) * 0.13),
					Vector3(16.0, 0.0, 0.0),
				)
		CarBodyMeshBuilder.add_mesh(
			root, "StrutBrace", CarBodyFactory.build_capsule(0.014, bay_w * 0.62),
			accent_mat, [], null, Vector3(0.0, 0.088, 0.06), Vector3(0.0, 0.0, 90.0),
		)
	elif arch == &"engine_hood_blower":
		var collar := BoxMesh.new()
		collar.size = Vector3(bay_w * 0.62, 0.045, bay_l * 0.86)
		CarBodyMeshBuilder.add_mesh(
			root, "HoodCutoutCollar", collar, m["carbon"], [], null, Vector3(0.0, 0.02, 0.0),
		)
		var case_box := CarBodyFactory.build_tapered_block(
			Vector2(bay_w * 0.40, 0.115), Vector2(bay_w * 0.42, 0.115), bay_l * 0.68,
			0.085, 0.085, 0.22,
		)
		CarBodyMeshBuilder.add_mesh(root, "BlowerCase", case_box, m["chrome"])
		var scoop := CarBodyFactory.build_tapered_block(
			Vector2(bay_w * 0.46, 0.095), Vector2(bay_w * 0.36, 0.075), bay_l * 0.56,
			0.175, 0.165, 0.20,
		)
		CarBodyMeshBuilder.add_mesh(root, "BugCatcherScoop", scoop, m["chrome"])
		var valve := CylinderMesh.new()
		valve.top_radius = 0.030
		valve.bottom_radius = 0.030
		valve.height = 0.018
		for idx in [-1, 0, 1]:
			CarBodyMeshBuilder.add_mesh(
				root, "ButterflyValve", valve, accent_mat, [], null,
				Vector3(float(idx) * 0.075, 0.175, -bay_l * 0.285), Vector3(90.0, 0.0, 0.0),
			)
		var belt_pulley := BoxMesh.new()
		belt_pulley.size = Vector3(bay_w * 0.22, 0.12, 0.035)
		CarBodyMeshBuilder.add_mesh(
			root, "DriveBelt", belt_pulley, m["well"], [], null,
			Vector3(0.0, 0.085, -bay_l * 0.36),
		)
	elif arch == &"engine_mid_v8":
		var recess := BoxMesh.new()
		recess.size = Vector3(bay_w * 0.78, 0.04, bay_l * 0.90)
		CarBodyMeshBuilder.add_mesh(
			root, "EngineBayRecess", recess, m["well"], [], null, Vector3(0.0, 0.018, 0.0),
		)
		var bank := BoxMesh.new()
		bank.size = Vector3(0.11, 0.085, bay_l * 0.68)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "CylinderBank", bank, accent_mat, [], null,
				Vector3(side * bay_w * 0.20, 0.062, 0.0), Vector3(0.0, 0.0, side * -24.0),
			)
		var plenum := CarBodyFactory.build_tapered_block(
			Vector2(bay_w * 0.28, 0.075), Vector2(bay_w * 0.24, 0.065), bay_l * 0.62,
			0.095, 0.088, 0.25,
		)
		CarBodyMeshBuilder.add_mesh(root, "IntakePlenum", plenum, m["chrome"])
		var brace := CarBodyFactory.build_capsule(0.011, bay_l * 0.76)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "XBrace", brace, m["chrome"], [], null,
				Vector3(0.0, 0.128, 0.0), Vector3(90.0, side * 28.0, 0.0),
			)
	else:
		# `engine_mid_hyper`: propulsore V12 + 6 trombette aspirazione dorate + barre energia.
		CarBodyMeshBuilder.add_mesh(
			root, "CarbonShroud",
			CarBodyFactory.build_tapered_block(
				Vector2(bay_w * 0.80, 0.055), Vector2(bay_w * 0.68, 0.050), bay_l * 0.94,
				0.025, 0.022, 0.20,
			),
			m["carbon"],
		)
		var gold_mat := MaterialFactory.colored("velocity_gold", Color(0.95, 0.76, 0.22), 0.20, 0.90)
		var stack := CylinderMesh.new()
		stack.top_radius = 0.036
		stack.bottom_radius = 0.024
		stack.height = 0.095
		for side: float in [-1.0, 1.0]:
			for idx in 3:
				CarBodyMeshBuilder.add_mesh(
					root, "VelocityStack", stack, gold_mat, [], null,
					Vector3(side * 0.085, 0.095, -bay_l * 0.24 + float(idx) * (bay_l * 0.24)),
					Vector3(0.0, 0.0, side * -8.0),
				)
		var hv_mat := MaterialFactory.unique_emissive(spec.accent_color, 1.9)
		var hv_bar := CarBodyFactory.build_capsule(0.014, bay_l * 0.72)
		for side: float in [-1.0, 1.0]:
			var rail := CarBodyMeshBuilder.add_mesh(
				root, "HybridBusbar", hv_bar, hv_mat, [], null,
				Vector3(side * bay_w * 0.28, 0.062, 0.0), Vector3(90.0, 0.0, 0.0),
			)
			if rail != null:
				rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				glow.append(rail)
	return _pack_part(root, paint, glow, part)


# ----------------------------------------------------------- Scarico --------

static func _build_exhaust(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var root := Node3D.new()
	var m := CarBodyMeshBuilder.make_materials(profile)
	var glow: Array = []
	var spec := part.resolved_visual_spec()
	var span_w := sockets.socket_width(CarPartSlot.Type.EXHAUST)
	var hw := span_w * 0.5
	var arch := spec.archetype
	var accent_mat := MaterialFactory.colored(
		"exh_accent_" + String(part.id), spec.accent_color, 0.22, 0.85
	)

	var pipe_xs: Array[float] = []
	var outer_r := 0.044
	var pipe_len := 0.18
	var y_off := 0.0
	if arch == &"exhaust_single":
		pipe_xs = [-0.52 * hw]
		outer_r = 0.042
	elif arch == &"exhaust_dual":
		pipe_xs = [-0.58 * hw, 0.58 * hw]
		outer_r = 0.050
		pipe_len = 0.20
	elif arch == &"exhaust_quad":
		pipe_xs = [-0.66 * hw, -0.49 * hw, 0.49 * hw, 0.66 * hw]
		outer_r = 0.042
		pipe_len = 0.21
	else:
		pipe_xs = [-0.115, 0.0, 0.115]
		outer_r = 0.046
		pipe_len = 0.22
		y_off = 0.055
		var bezel := BoxMesh.new()
		bezel.size = Vector3(0.42, 0.135, 0.08)
		CarBodyMeshBuilder.add_mesh(
			root, "CenterExhaustBezel", bezel, m["carbon"], [], null, Vector3(0.0, y_off, 0.03),
		)

	var muffler := BoxMesh.new()
	muffler.size = Vector3(hw * 1.10, 0.075, 0.16)
	CarBodyMeshBuilder.add_mesh(
		root, "SilencerBox", muffler, m["trim"], [], null, Vector3(0.0, y_off + 0.01, -0.09),
	)

	var tip_mat: Material = accent_mat if arch in [&"exhaust_quad", &"exhaust_center"] else m["chrome"]
	var outer := CylinderMesh.new()
	outer.top_radius = outer_r
	outer.bottom_radius = outer_r * 0.92
	outer.height = pipe_len
	var inner := CylinderMesh.new()
	inner.top_radius = outer_r * 0.74
	inner.bottom_radius = outer_r * 0.74
	inner.height = 0.03
	var ember_mat := MaterialFactory.unique_emissive(Color(1.0, 0.42, 0.10), 1.5)

	for i in pipe_xs.size():
		var px := pipe_xs[i]
		var stagger := -0.025 if (arch == &"exhaust_quad" and (i == 0 or i == 3)) else 0.0
		CarBodyMeshBuilder.add_mesh(
			root, "TailPipe%d" % i, outer, tip_mat, [], null,
			Vector3(px, y_off, pipe_len * 0.35 + stagger), Vector3(90.0, 0.0, 0.0),
		)
		var core_mat: Material = ember_mat if arch == &"exhaust_center" else m["well"]
		var core := CarBodyMeshBuilder.add_mesh(
			root, "PipeBore%d" % i, inner, core_mat, [], null,
			Vector3(px, y_off, pipe_len * 0.82 + stagger), Vector3(90.0, 0.0, 0.0),
		)
		if arch == &"exhaust_center" and core != null:
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.append(core)
	return _pack_part(root, [], glow, part)


# ----------------------------------------------------------- Spoiler --------

static func _build_spoiler(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var root := Node3D.new()
	var m := CarBodyMeshBuilder.make_materials(profile)
	var paint: Array = []
	var body_mat: Material = m["body"]
	var spec := part.resolved_visual_spec()
	var deck_w := sockets.socket_width(CarPartSlot.Type.SPOILER)
	var hw := deck_w * 0.5
	var arch := spec.archetype
	var accent_mat := MaterialFactory.colored(
		"sp_accent_" + String(part.id), spec.accent_color, 0.30, 0.35
	)

	if arch == &"spoiler_none":
		var trim_strip := CarBodyFactory.build_wing_span(hw * 0.72, 0.055, 0.020, 0.0, 0.02, 0.0, 0.90)
		CarBodyMeshBuilder.add_mesh(
			root, "CleanDeckStrip", trim_strip, m["trim_alt"], [], null, Vector3(0.0, 0.008, 0.04),
		)
	elif arch == &"spoiler_wreck_rack":
		var spare_torus := TorusMesh.new()
		spare_torus.inner_radius = 0.125
		spare_torus.outer_radius = 0.275
		spare_torus.rings = 20
		spare_torus.ring_segments = 10
		CarBodyMeshBuilder.add_mesh(
			root, "SpareTire", spare_torus, m["tire"], [], null, Vector3(0.0, 0.085, -0.34),
		)
		var hub_cyl := CylinderMesh.new()
		hub_cyl.top_radius = 0.105
		hub_cyl.bottom_radius = 0.105
		hub_cyl.height = 0.15
		CarBodyMeshBuilder.add_mesh(
			root, "SpareWheelHub", hub_cyl, m["trim_alt"], [], null, Vector3(0.0, 0.085, -0.34),
		)
		var bar := CarBodyFactory.build_capsule(0.018, hw * 1.15)
		for z_bar: float in [-0.64, -0.06]:
			CarBodyMeshBuilder.add_mesh(
				root, "RackCrossbar", bar, m["trim"], [], null,
				Vector3(0.0, 0.025, z_bar), Vector3(0.0, 0.0, 90.0),
			)
	elif arch == &"spoiler_ducktail":
		# Variante 1: coda d'anatra inclinata e raccordata senza fessure.
		CarBodyMeshBuilder.add_mesh(
			root, "DucktailBlade",
			CarBodyFactory.build_wing_span(hw * 0.90, 0.22, 0.052, 0.018, 0.035, 0.012, 0.86),
			body_mat, paint, body_mat, Vector3(0.0, 0.052, 0.075), Vector3(26.0, 0.0, 0.0),
		)
		CarBodyMeshBuilder.add_mesh(
			root, "GurneyFlap",
			CarBodyFactory.build_wing_span(hw * 0.89, 0.050, 0.026, 0.0, 0.035, 0.012, 0.86),
			m["carbon"], [], null, Vector3(0.0, 0.102, 0.165), Vector3(34.0, 0.0, 0.0),
		)
	elif arch == &"spoiler_gt_wing":
		# Variante 2: grande alettone GT singolo rialzato su piloni con paratie laterali.
		var span_gt := hw * 1.06
		var wing_y := 0.255
		var wing_z := 0.10
		CarBodyMeshBuilder.add_mesh(
			root, "GtMainWing",
			CarBodyFactory.build_wing_span(span_gt, 0.27, 0.046, -0.020, 0.03, 0.015, 0.92),
			m["carbon"], [], null, Vector3(0.0, wing_y, wing_z), Vector3(-11.0, 0.0, 0.0),
		)
		var pylon := CarBodyFactory.build_tapered_block(
			Vector2(0.042, wing_y + 0.04), Vector2(0.036, wing_y + 0.04), 0.17,
			wing_y * 0.46, wing_y * 0.48, 0.18,
		)
		var endplate := BoxMesh.new()
		endplate.size = Vector3(0.028, 0.19, 0.34)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "GtPylon", pylon, m["trim"], [], null,
				Vector3(side * hw * 0.52, 0.0, wing_z - 0.02), Vector3(-8.0, 0.0, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "GtEndplate", endplate, body_mat, paint, body_mat,
				Vector3(side * (span_gt + 0.012), wing_y - 0.01, wing_z + 0.01),
			)
	else:
		# Variante 3: biplano racing con attacchi superiori swan-neck e deriva centrale.
		var span_bi := hw * 1.12
		var lower_y := 0.215
		var upper_y := 0.355
		CarBodyMeshBuilder.add_mesh(
			root, "BiplaneLower",
			CarBodyFactory.build_wing_span(span_bi * 0.96, 0.24, 0.038, -0.015, 0.04, 0.01, 0.92),
			m["carbon"], [], null, Vector3(0.0, lower_y, 0.09), Vector3(-9.0, 0.0, 0.0),
		)
		CarBodyMeshBuilder.add_mesh(
			root, "BiplaneUpper",
			CarBodyFactory.build_wing_span(span_bi, 0.29, 0.044, -0.024, 0.055, 0.022, 0.94),
			body_mat, paint, body_mat, Vector3(0.0, upper_y, 0.155), Vector3(-15.0, 0.0, 0.0),
		)
		CarBodyMeshBuilder.add_mesh(
			root, "BiplaneAccent",
			CarBodyFactory.build_wing_span(span_bi, 0.048, 0.022, 0.0, 0.055, 0.022, 0.94),
			accent_mat, [], null, Vector3(0.0, upper_y + 0.036, 0.285),
		)
		var neck_up := BoxMesh.new()
		neck_up.size = Vector3(0.034, upper_y + 0.085, 0.14)
		var swan_hook := BoxMesh.new()
		swan_hook.size = Vector3(0.036, 0.055, 0.18)
		var arrow_plate := BoxMesh.new()
		arrow_plate.size = Vector3(0.028, 0.31, 0.42)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "SwanNeckStrut", neck_up, m["carbon"], [], null,
				Vector3(side * hw * 0.44, (upper_y + 0.06) * 0.5 - 0.02, 0.05),
				Vector3(-12.0, 0.0, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "SwanNeckOverhang", swan_hook, accent_mat, [], null,
				Vector3(side * hw * 0.44, upper_y + 0.055, 0.115), Vector3(14.0, 0.0, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "BiplaneEndplate", arrow_plate, m["carbon"], [], null,
				Vector3(side * (span_bi + 0.014), lower_y + 0.065, 0.145), Vector3(-8.0, 0.0, 0.0),
			)
		var center_fin := BoxMesh.new()
		center_fin.size = Vector3(0.022, upper_y - 0.02, 0.30)
		CarBodyMeshBuilder.add_mesh(
			root, "CentralSpineFin", center_fin, body_mat, paint, body_mat,
			Vector3(0.0, upper_y * 0.5, 0.06), Vector3(-6.0, 0.0, 0.0),
		)
	return _pack_part(root, paint, [], part)


# --------------------------------------------------------- Aerodinamica -----

static func _build_aero(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
	sockets: CarBodySockets,
) -> Dictionary:
	var root := Node3D.new()
	var m := CarBodyMeshBuilder.make_materials(profile)
	var paint: Array = []
	var body_mat: Material = m["body"]
	var spec := part.resolved_visual_spec()
	var arch := spec.archetype
	if arch == &"aero_none":
		return _pack_part(root, paint, [], part)

	var hw := sockets.socket_width(CarPartSlot.Type.AERO) * 0.5
	var roof_rel_y := sockets.socket_height(CarPartSlot.Type.AERO)
	var clear_len := sockets.socket_length(CarPartSlot.Type.AERO)
	var accent_mat := MaterialFactory.colored(
		"aero_accent_" + String(part.id), spec.accent_color, 0.30, 0.35
	)

	if arch == &"aero_street":
		var skirt := BoxMesh.new()
		skirt.size = Vector3(0.055, 0.055, clear_len)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "StreetSkirt", skirt, m["trim"], [], null,
				Vector3(side * (hw * 0.985), 0.015, 0.0),
			)
		var shark := CylinderMesh.new()
		shark.top_radius = 0.005
		shark.bottom_radius = 0.032
		shark.height = 0.09
		CarBodyMeshBuilder.add_mesh(
			root, "RoofSharkFin", shark, body_mat, paint, body_mat,
			Vector3(0.0, roof_rel_y + 0.03, sockets.roof_span.y - 0.12),
			Vector3.ZERO, Vector3(0.45, 1.0, 2.4),
		)
	elif arch == &"aero_track":
		var blade := BoxMesh.new()
		blade.size = Vector3(0.095, 0.026, clear_len)
		var flick := BoxMesh.new()
		flick.size = Vector3(0.024, 0.135, 0.16)
		var louver := BoxMesh.new()
		louver.size = Vector3(0.075, 0.016, 0.055)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "TrackSkirtBlade", blade, m["carbon"], [], null,
				Vector3(side * (hw * 1.02), -0.012, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "SkirtPinStripe",
				BoxMesh.new(), accent_mat, [], null,
				Vector3(side * (hw * 1.065), -0.012, 0.0),
				Vector3.ZERO, Vector3(0.014, 0.018, clear_len),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "RearFlick", flick, m["carbon"], [], null,
				Vector3(side * (hw * 1.055), 0.045, clear_len * 0.44),
			)
			for k in 3:
				CarBodyMeshBuilder.add_mesh(
					root, "FenderLouver", louver, m["well"], [], null,
					Vector3(
						side * (hw * 0.86),
						sockets.belt_height - sockets.sill_height + 0.03,
						-profile.wheel_base_z + float(k - 1) * 0.085,
					),
					Vector3(18.0, 0.0, side * -12.0),
				)
		var vg := BoxMesh.new()
		vg.size = Vector3(0.014, 0.038, 0.075)
		for idx in range(-2, 3):
			CarBodyMeshBuilder.add_mesh(
				root, "VortexGenerator", vg, m["carbon"], [], null,
				Vector3(float(idx) * 0.095, roof_rel_y + 0.012, sockets.roof_span.y - 0.08),
				Vector3(0.0, float(idx) * 5.0, 0.0),
			)
	else:
		# `aero_hyper`: fondo Venturi laterale + bargeboard + pinna dorsale LMP1.
		var floor_blade := BoxMesh.new()
		floor_blade.size = Vector3(0.115, 0.030, clear_len)
		var barge := BoxMesh.new()
		barge.size = Vector3(0.026, 0.19, 0.24)
		for side: float in [-1.0, 1.0]:
			CarBodyMeshBuilder.add_mesh(
				root, "HyperFloorEdge", floor_blade, m["carbon"], [], null,
				Vector3(side * (hw * 1.035), -0.018, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "HyperEdgeGlow", BoxMesh.new(), accent_mat, [], null,
				Vector3(side * (hw * 1.09), -0.018, 0.0),
				Vector3.ZERO, Vector3(0.016, 0.020, clear_len),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "FrontBargeboard", barge, body_mat, paint, body_mat,
				Vector3(side * (hw * 1.05), 0.075, -clear_len * 0.38),
				Vector3(0.0, side * 8.0, 0.0),
			)
			CarBodyMeshBuilder.add_mesh(
				root, "RearPodWing", barge, m["carbon"], [], null,
				Vector3(side * (hw * 1.06), 0.070, clear_len * 0.42),
				Vector3(0.0, side * -6.0, 0.0),
			)
		var dorsal_len := maxf(profile.body_length * 0.28, 0.65)
		var dorsal := CarBodyFactory.build_tapered_block(
			Vector2(0.024, 0.175), Vector2(0.020, 0.115), dorsal_len,
			0.075, 0.055, 0.12,
		)
		CarBodyMeshBuilder.add_mesh(
			root, "LmpDorsalFin", dorsal, m["carbon"], [], null,
			Vector3(
				0.0,
				sockets.belt_height - sockets.sill_height + 0.035,
				profile.body_length * 0.24,
			),
		)
	return _pack_part(root, paint, [], part)


# ---------------------------------------------------------------- Helper ----

static func _pack_part(
	root: Node3D,
	paint_meshes: Array,
	glow_meshes: Array,
	part: CarPartDefinition,
) -> Dictionary:
	root.position += part.mount_offset
	root.rotation_degrees += part.mount_rotation_degrees
	return {
		KEY_INSTANCE: root,
		KEY_WHEEL_NODES: [],
		KEY_PAINT_MESHES: paint_meshes,
		KEY_PIPS: [],
		KEY_GLOW_ENTRIES: CarBodyMeshBuilder.collect_glow_entries(glow_meshes),
		KEY_SOCKETS: null,
	}


static func _empty_result() -> Dictionary:
	return {
		KEY_INSTANCE: null,
		KEY_WHEEL_NODES: [],
		KEY_PAINT_MESHES: [],
		KEY_PIPS: [],
		KEY_GLOW_ENTRIES: [],
		KEY_SOCKETS: null,
	}


static func _find_meshes(node: Node) -> Array:
	var list: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			list.append(child)
		list.append_array(_find_meshes(child))
	return list


static func _find_emissive_entries(node: Node) -> Array:
	var meshes: Array = []
	for item in _find_meshes(node):
		var mi := item as MeshInstance3D
		if mi != null and mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			if mat.emission_enabled:
				meshes.append(mi)
	return CarBodyMeshBuilder.collect_glow_entries(meshes)
