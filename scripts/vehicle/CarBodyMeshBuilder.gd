class_name CarBodyMeshBuilder
extends RefCounted
## Generatore procedurale della sola carrozzeria (`Slot.BODY`) e dei suoi socket.
##
## A differenza del vecchio costruttore monolitico, costruisce esclusivamente la
## scocca portante (loft carrozzeria, abitacolo, passaruota, fari, specchietti,
## targa, spie evolutive e fondo piatto) e calcola in modo esatto i punti di
## montaggio 3D (`CarBodySockets`) su cui `VehicleRig` innesta paraurti, ruote,
## motore, scarico, spoiler ed elementi aerodinamici.

const PIP_SIZE := Vector3(0.13, 0.06, 0.24)
const PIP_SPACING: float = 0.22

const BUCKET_PAINT: String = "paint"
const BUCKET_TRIM: String = "trim"
const BUCKET_GLASS: String = "glass"

const BODY_SECTION: Array = [
	Vector2(0.00, 0.00), Vector2(0.58, 0.00), Vector2(0.86, 0.02),
	Vector2(0.985, 0.09), Vector2(1.00, 0.30), Vector2(1.00, 0.56),
	Vector2(0.985, 0.73), Vector2(0.93, 0.87), Vector2(0.78, 0.955),
	Vector2(0.50, 0.995), Vector2(0.00, 1.00),
]

const GLASS_SECTION: Array = [
	Vector2(0.00, 0.00), Vector2(0.60, 0.00), Vector2(0.92, 0.03),
	Vector2(1.00, 0.14), Vector2(0.99, 0.34), Vector2(0.94, 0.55),
	Vector2(0.85, 0.72), Vector2(0.68, 0.86), Vector2(0.40, 0.96),
	Vector2(0.00, 1.00),
]


static func build_body(
	part: CarPartDefinition,
	profile: CarEvolutionProfile,
) -> Dictionary:
	var sil := profile.silhouette
	if part != null:
		sil = part.resolved_visual_spec().body_silhouette
	var bp := blueprint_for(sil)
	var materials := make_materials(profile)
	var glow_meshes: Array = []
	var paint_meshes: Array = []
	var pips: Array = []

	var body_root := Node3D.new()
	body_root.name = "BodyChassis"

	var length := profile.body_length
	var hw := profile.body_width * 0.5
	var belt := profile.roof_height * float(bp["belt_f"])
	var sill := maxf(profile.ride_height - float(bp["sill_drop"]), 0.085)
	var crown := 2.0 * profile.wheel_radius + float(bp["arch_gap"])
	var ctx := {
		"profile": profile,
		"sil": sil,
		"bp": bp,
		"m": materials,
		"glow": glow_meshes,
		"paint": paint_meshes,
		"root": body_root,
		"length": length,
		"hw": hw,
		"belt": belt,
		"sill": sill,
		"crown": crown,
		"nose_z": -length * 0.5 - 0.02,
		"tail_z": length * 0.5 + 0.02,
		"nose_top": top_at(bp, length, belt, -length * 0.5 + 0.055 * length),
		"tail_top": top_at(bp, length, belt, -length * 0.5 + 0.955 * length),
	}

	_build_shell(ctx)
	_build_wheel_housings(ctx)
	_build_fixed_body_trim(ctx)
	_build_pips(ctx, pips)
	var sockets := compute_sockets(ctx)

	return {
		"instance": body_root,
		"paint_meshes": paint_meshes,
		"pips": pips,
		"glow_entries": collect_glow_entries(glow_meshes),
		"sockets": sockets,
	}


static func compute_sockets(ctx: Dictionary) -> CarBodySockets:
	var profile: CarEvolutionProfile = ctx["profile"]
	var sil: int = int(ctx["sil"])
	var bp: Dictionary = ctx["bp"]
	var length: float = ctx["length"]
	var hw: float = ctx["hw"]
	var belt: float = ctx["belt"]
	var sill: float = ctx["sill"]
	var nose_z: float = ctx["nose_z"]
	var tail_z: float = ctx["tail_z"]
	var nose_top: float = ctx["nose_top"]
	var tail_top: float = ctx["tail_top"]

	var sockets := CarBodySockets.new()
	sockets.body_silhouette = sil
	sockets.body_length = length
	sockets.body_width = hw * 2.0
	sockets.roof_height = profile.roof_height
	sockets.belt_height = belt
	sockets.sill_height = sill

	var span: Vector2 = bp["glass_span"]
	var roof_range: Vector2 = bp["roof_range"]
	var roof_z0 := -length * 0.5 + (span.x + roof_range.x * (span.y - span.x)) * length
	var roof_z1 := -length * 0.5 + (span.x + roof_range.y * (span.y - span.x)) * length
	sockets.roof_span = Vector2(roof_z0, roof_z1)

	# 1. Paraurti anteriore: ancorato sul muso (-Z), orientato verso -Z.
	var front_w := 2.0 * half_width_at(bp, length, hw, -length * 0.44)
	sockets.set_socket(
		CarPartSlot.Type.BUMPER_FRONT,
		Transform3D(Basis.IDENTITY, Vector3(0.0, sill + 0.085, nose_z + 0.045)),
		front_w,
		maxf(nose_top - sill, 0.20),
		0.28,
		PackedStringArray(["front_fascia"]),
	)

	# 2. Paraurti posteriore: ancorato in coda (+Z), ben visibile dalla camera.
	var rear_w := 2.0 * half_width_at(bp, length, hw, length * 0.45)
	sockets.set_socket(
		CarPartSlot.Type.BUMPER_REAR,
		Transform3D(Basis.IDENTITY, Vector3(0.0, sill + 0.095, tail_z - 0.045)),
		rear_w,
		maxf(tail_top - sill, 0.22),
		0.28,
		PackedStringArray(["rear_fascia"]),
	)

	# 3. Ruote: slot logico + 4 mozzi metrici (FL, FR, RL, RR).
	sockets.set_socket(
		CarPartSlot.Type.WHEELS,
		Transform3D.IDENTITY,
		profile.wheel_width,
		profile.wheel_radius * 2.0,
		profile.wheel_radius * 2.0,
		PackedStringArray(["wheel_hub"]),
	)
	var hubs: Array[Dictionary] = [
		{
			"position": Vector3(-profile.wheel_base_x, profile.wheel_radius, -profile.wheel_base_z),
			"side": -1.0,
			"is_rear": false,
			"base_radius": profile.wheel_radius,
			"base_width": profile.wheel_width,
		},
		{
			"position": Vector3(profile.wheel_base_x, profile.wheel_radius, -profile.wheel_base_z),
			"side": 1.0,
			"is_rear": false,
			"base_radius": profile.wheel_radius,
			"base_width": profile.wheel_width,
		},
		{
			"position": Vector3(-profile.wheel_base_x, profile.wheel_radius, profile.wheel_base_z),
			"side": -1.0,
			"is_rear": true,
			"base_radius": profile.wheel_radius,
			"base_width": profile.rear_wheel_width,
		},
		{
			"position": Vector3(profile.wheel_base_x, profile.wheel_radius, profile.wheel_base_z),
			"side": 1.0,
			"is_rear": true,
			"base_radius": profile.wheel_radius,
			"base_width": profile.rear_wheel_width,
		},
	]
	sockets.set_wheel_hubs(hubs)

	# 4. Motore: vano anteriore (`hood_bay`) su auto a motore anteriore, oppure
	#    vano posteriore scoperto (`mid_bay`) su supercar e hypercar.
	var is_mid_engine := sil in [
		CarEvolutionProfile.Silhouette.SUPERCAR,
		CarEvolutionProfile.Silhouette.HYPERCAR,
	]
	if is_mid_engine:
		var mid_z := -length * 0.5 + 0.74 * length
		var mid_y := top_at(bp, length, belt, mid_z) - 0.012
		sockets.set_socket(
			CarPartSlot.Type.ENGINE,
			Transform3D(Basis.IDENTITY, Vector3(0.0, mid_y, mid_z)),
			hw * 1.12,
			0.28,
			length * 0.24,
			PackedStringArray(["mid_bay"]),
		)
	else:
		var hood_z := -length * 0.5 + 0.19 * length
		var hood_y := top_at(bp, length, belt, hood_z) - 0.012
		var z_ahead := hood_z - 0.12
		var z_behind := hood_z + 0.12
		var hood_slope := atan2(
			top_at(bp, length, belt, z_behind) - top_at(bp, length, belt, z_ahead),
			z_behind - z_ahead,
		)
		var engine_basis := Basis.from_euler(Vector3(-hood_slope * 0.65, 0.0, 0.0))
		sockets.set_socket(
			CarPartSlot.Type.ENGINE,
			Transform3D(engine_basis, Vector3(0.0, hood_y, hood_z)),
			hw * 1.06,
			0.26,
			length * 0.22,
			PackedStringArray(["hood_bay"]),
		)

	# 5. Scarico: posizionato sotto la traversa posteriore, sempre sopra y=0.
	sockets.set_socket(
		CarPartSlot.Type.EXHAUST,
		Transform3D(Basis.IDENTITY, Vector3(0.0, maxf(sill + 0.015, 0.11), tail_z - 0.035)),
		rear_w * 0.84,
		0.14,
		0.24,
		PackedStringArray(["rear_exhaust"]),
	)

	# 6. Spoiler: ancorato sul bordo reale del tetto (due volumi) o del baule.
	var is_roof_tail := sil in [
		CarEvolutionProfile.Silhouette.WRECK,
		CarEvolutionProfile.Silhouette.HATCHBACK,
	]
	var sp_z := length * 0.5 - 0.14
	var sp_y := top_at(bp, length, belt, sp_z) - 0.010
	if is_roof_tail:
		var sp_gt := 0.84
		sp_z = -length * 0.5 + (span.x + sp_gt * (span.y - span.x)) * length
		sp_y = profile.roof_height * CarBodyFactory.catmull_rom_1d(bp["glass_top"], sp_gt) - 0.012
	var sp_w := 2.0 * half_width_at(bp, length, hw, sp_z)
	sockets.set_socket(
		CarPartSlot.Type.SPOILER,
		Transform3D(Basis.IDENTITY, Vector3(0.0, sp_y, sp_z)),
		sp_w,
		0.45,
		0.36,
		PackedStringArray(["spoiler_mount"]),
	)

	# 7. Aerodinamica aggiuntiva: centro brancardi a y = sill, luce netta tra i
	#    passaruota per evitare qualsiasi intersezione con le ruote sterzanti.
	var clear_wheelbase := maxf(
		2.0 * profile.wheel_base_z - 2.0 * profile.wheel_radius * 1.18,
		0.52,
	)
	sockets.set_socket(
		CarPartSlot.Type.AERO,
		Transform3D(Basis.IDENTITY, Vector3(0.0, sill, 0.0)),
		2.0 * hw,
		maxf(profile.roof_height - sill, 0.35),
		clear_wheelbase,
		PackedStringArray(["aero_sill"]),
	)

	return sockets


static func blueprint_for(silhouette: int) -> Dictionary:
	var bp := {
		"belt_f": 0.78,
		"sill_drop": 0.095,
		"body_top": [
			Vector2(0.00, 0.66), Vector2(0.05, 0.77), Vector2(0.14, 0.91),
			Vector2(0.30, 1.00), Vector2(0.55, 1.00), Vector2(0.80, 0.99),
			Vector2(0.95, 0.97), Vector2(1.00, 0.94),
		],
		"body_w": [
			Vector2(0.00, 0.80), Vector2(0.06, 0.94), Vector2(0.16, 1.02),
			Vector2(0.34, 0.99), Vector2(0.56, 1.00), Vector2(0.82, 1.04),
			Vector2(0.94, 1.00), Vector2(1.00, 0.93),
		],
		"glass_span": Vector2(0.30, 0.76),
		"roof_range": Vector2(0.22, 0.74),
		"glass_top": [
			Vector2(0.00, 0.68), Vector2(0.16, 0.93), Vector2(0.30, 0.99),
			Vector2(0.55, 1.00), Vector2(0.76, 0.98), Vector2(0.90, 0.86),
			Vector2(1.00, 0.70),
		],
		"glass_w": [
			Vector2(0.00, 0.82), Vector2(0.20, 0.85), Vector2(0.55, 0.86),
			Vector2(0.85, 0.83), Vector2(1.00, 0.79),
		],
		"glass_bottom_f": 0.90,
		"pillars_b": Vector2(0.46, 0.53),
		"pillars_c": Vector2(0.64, 0.74),
		"roof_split": 0.64,
		"a_pillars": true,
		"clad_split": 0.10,
		"arch_gap": 0.045,
		"arch_flare": "trim",
		"light_style": "round",
		"mirrors_painted": false,
		"nose_intake": true,
		"roof_rails": false,
	}
	match silhouette:
		CarEvolutionProfile.Silhouette.WRECK:
			bp.merge({
				"belt_f": 0.66,
				"body_top": [
					Vector2(0.00, 0.78), Vector2(0.06, 0.88), Vector2(0.16, 0.96),
					Vector2(0.32, 1.00), Vector2(0.55, 1.00), Vector2(0.80, 1.00),
					Vector2(0.95, 0.98), Vector2(1.00, 0.92),
				],
				"glass_span": Vector2(0.26, 0.84),
				"roof_range": Vector2(0.22, 0.82),
				"glass_top": [
					Vector2(0.00, 0.66), Vector2(0.10, 0.93), Vector2(0.22, 0.99),
					Vector2(0.55, 1.00), Vector2(0.82, 0.99), Vector2(0.94, 0.88),
					Vector2(1.00, 0.66),
				],
				"glass_w": [
					Vector2(0.00, 0.88), Vector2(0.20, 0.90), Vector2(0.55, 0.90),
					Vector2(0.85, 0.88), Vector2(1.00, 0.84),
				],
				"pillars_c": Vector2(0.86, 0.96),
				"clad_split": 0.14,
				"arch_flare": "trim",
				"roof_rails": true,
			}, true)
		CarEvolutionProfile.Silhouette.SEDAN:
			bp.merge({
				"belt_f": 0.65,
				"body_top": [
					Vector2(0.00, 0.74), Vector2(0.05, 0.84), Vector2(0.14, 0.94),
					Vector2(0.30, 1.00), Vector2(0.55, 1.00), Vector2(0.78, 1.01),
					Vector2(0.92, 1.02), Vector2(1.00, 0.95),
				],
				"glass_span": Vector2(0.26, 0.68),
				"roof_range": Vector2(0.34, 0.76),
				"glass_top": [
					Vector2(0.00, 0.64), Vector2(0.18, 0.94), Vector2(0.34, 0.99),
					Vector2(0.58, 1.00), Vector2(0.76, 0.96), Vector2(0.90, 0.80),
					Vector2(1.00, 0.64),
				],
				"glass_bottom_f": 0.80,
				"pillars_c": Vector2(0.78, 0.92),
				"clad_split": 0.12,
				"arch_flare": "paint",
				"mirrors_painted": true,
			}, true)
		CarEvolutionProfile.Silhouette.COUPE:
			bp.merge({
				"belt_f": 0.70,
				"body_top": [
					Vector2(0.00, 0.66), Vector2(0.05, 0.78), Vector2(0.15, 0.90),
					Vector2(0.34, 0.98), Vector2(0.55, 1.00), Vector2(0.80, 1.02),
					Vector2(0.95, 0.99), Vector2(1.00, 0.94),
				],
				"body_w": [
					Vector2(0.00, 0.80), Vector2(0.05, 0.92), Vector2(0.15, 1.01),
					Vector2(0.32, 0.98), Vector2(0.55, 1.00), Vector2(0.80, 1.05),
					Vector2(0.94, 1.01), Vector2(1.00, 0.93),
				],
				"glass_span": Vector2(0.30, 0.84),
				"roof_range": Vector2(0.36, 0.56),
				"glass_top": [
					Vector2(0.00, 0.62), Vector2(0.20, 0.94), Vector2(0.36, 1.00),
					Vector2(0.52, 0.99), Vector2(0.72, 0.92), Vector2(0.90, 0.76),
					Vector2(1.00, 0.62),
				],
				"glass_w": [
					Vector2(0.00, 0.78), Vector2(0.20, 0.82), Vector2(0.55, 0.82),
					Vector2(0.85, 0.78), Vector2(1.00, 0.73),
				],
				"pillars_c": Vector2(0.70, 0.94),
				"clad_split": 0.13,
				"arch_flare": "paint",
				"light_style": "slim",
				"mirrors_painted": true,
			}, true)
		CarEvolutionProfile.Silhouette.SUPERCAR:
			bp.merge({
				"belt_f": 0.68,
				"body_top": [
					Vector2(0.00, 0.58), Vector2(0.05, 0.72), Vector2(0.15, 0.88),
					Vector2(0.34, 0.97), Vector2(0.55, 1.00), Vector2(0.80, 1.03),
					Vector2(0.95, 1.00), Vector2(1.00, 0.95),
				],
				"body_w": [
					Vector2(0.00, 0.80), Vector2(0.05, 0.92), Vector2(0.15, 1.00),
					Vector2(0.32, 0.97), Vector2(0.55, 1.00), Vector2(0.80, 1.05),
					Vector2(0.94, 1.02), Vector2(1.00, 0.94),
				],
				"glass_span": Vector2(0.25, 0.66),
				"roof_range": Vector2(0.44, 0.62),
				"glass_top": [
					Vector2(0.00, 0.60), Vector2(0.24, 0.95), Vector2(0.44, 1.00),
					Vector2(0.62, 0.97), Vector2(0.82, 0.84), Vector2(1.00, 0.60),
				],
				"glass_w": [
					Vector2(0.00, 0.76), Vector2(0.25, 0.80), Vector2(0.55, 0.80),
					Vector2(0.85, 0.76), Vector2(1.00, 0.70),
				],
				"pillars_b": Vector2(0.50, 0.56),
				"pillars_c": Vector2(0.74, 0.96),
				"clad_split": 0.15,
				"arch_flare": "paint",
				"light_style": "slim",
				"mirrors_painted": true,
			}, true)
		CarEvolutionProfile.Silhouette.HYPERCAR:
			bp.merge({
				"belt_f": 0.64,
				"body_top": [
					Vector2(0.00, 0.54), Vector2(0.05, 0.70), Vector2(0.15, 0.86),
					Vector2(0.34, 0.96), Vector2(0.55, 1.00), Vector2(0.80, 1.04),
					Vector2(0.95, 1.01), Vector2(1.00, 0.96),
				],
				"body_w": [
					Vector2(0.00, 0.80), Vector2(0.05, 0.92), Vector2(0.15, 1.00),
					Vector2(0.32, 0.96), Vector2(0.55, 0.99), Vector2(0.80, 1.05),
					Vector2(0.94, 1.02), Vector2(1.00, 0.94),
				],
				"glass_span": Vector2(0.23, 0.67),
				"roof_range": Vector2(0.48, 0.66),
				"glass_top": [
					Vector2(0.00, 0.58), Vector2(0.26, 0.96), Vector2(0.48, 1.00),
					Vector2(0.66, 0.96), Vector2(0.86, 0.82), Vector2(1.00, 0.58),
				],
				"glass_w": [
					Vector2(0.00, 0.74), Vector2(0.25, 0.78), Vector2(0.55, 0.78),
					Vector2(0.85, 0.74), Vector2(1.00, 0.66),
				],
				"pillars_b": Vector2(0.52, 0.58),
				"pillars_c": Vector2(0.76, 0.97),
				"roof_split": 0.86,
				"a_pillars": false,
				"clad_split": 0.18,
				"arch_flare": "paint",
				"light_style": "bar",
				"mirrors_painted": true,
			}, true)
	return bp


static func top_at(bp: Dictionary, length: float, belt: float, z: float) -> float:
	var zn := clampf((z + length * 0.5) / length, 0.0, 1.0)
	return belt * CarBodyFactory.catmull_rom_1d(bp["body_top"], zn)


static func half_width_at(bp: Dictionary, length: float, hw: float, z: float) -> float:
	var zn := clampf((z + length * 0.5) / length, 0.0, 1.0)
	return hw * CarBodyFactory.catmull_rom_1d(bp["body_w"], zn)


static func fender_lift_at(
	bp: Dictionary,
	profile: CarEvolutionProfile,
	belt: float,
	crown: float,
	z: float,
) -> float:
	var need := maxf((crown + 0.05) - top_at(bp, profile.body_length, belt, z), 0.0)
	if need <= 0.0:
		return 0.0
	var half := profile.wheel_radius * 1.45
	var lift := 0.0
	for wz: float in [-profile.wheel_base_z, profile.wheel_base_z]:
		var dz := absf(z - wz)
		if dz < half:
			var shape := 0.5 + 0.5 * cos(PI * dz / half)
			lift = maxf(lift, need * shape)
	return lift


static func arch_circle_bottom(
	profile: CarEvolutionProfile,
	arch_gap: float,
	z: float,
	base_bottom: float,
) -> float:
	var crown := 2.0 * profile.wheel_radius + arch_gap
	var h := profile.wheel_radius * 1.48
	var rise := maxf(crown - base_bottom, 0.05)
	var radius := (h * h + rise * rise) / (2.0 * rise)
	var center_y := crown - radius
	var bottom := base_bottom
	for wz: float in [-profile.wheel_base_z, profile.wheel_base_z]:
		var dz := absf(z - wz)
		if dz < h:
			bottom = maxf(bottom, center_y + sqrt(maxf(radius * radius - dz * dz, 0.0)))
	return bottom


static func make_materials(profile: CarEvolutionProfile) -> Dictionary:
	return {
		"body": MaterialFactory.stage_paint(profile.level, profile.body_color),
		"trim": MaterialFactory.stage_material(
			profile.level, "trim", profile.trim_color, 0.44, 0.18
		),
		"trim_alt": MaterialFactory.stage_material(
			profile.level, "trim_alt", profile.trim_alt_color, 0.36, 0.38
		),
		"chrome": MaterialFactory.colored("car_chrome", Color(0.86, 0.89, 0.94), 0.18, 0.88),
		"carbon": MaterialFactory.colored("car_carbon", Color(0.11, 0.12, 0.14), 0.32, 0.25),
		"glass": MaterialFactory.stage_glass(
			profile.level, profile.glass_color.darkened(0.15)
		),
		"rim": MaterialFactory.stage_material(
			profile.level, "rim", profile.rim_color, 0.20, 0.80
		),
		"tire": MaterialFactory.stage_material(
			profile.level, "tire", profile.tire_color, 0.94, 0.0
		),
		"well": MaterialFactory.colored("car_well", Color(0.05, 0.05, 0.06), 0.95, 0.0),
	}


static func collect_glow_entries(meshes: Array) -> Array:
	var entries: Array = []
	var seen: Array = []
	for item in meshes:
		var instance := item as MeshInstance3D
		if instance == null:
			continue
		var material := instance.material_override as StandardMaterial3D
		if material == null or seen.has(material):
			continue
		seen.append(material)
		entries.append({
			"material": material,
			"base": material.emission_energy_multiplier,
		})
	return entries


static func add_mesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	material: Material,
	paint_list: Array = [],
	paint_material: Material = null,
	pos: Vector3 = Vector3.ZERO,
	rot_deg: Vector3 = Vector3.ZERO,
	scl: Vector3 = Vector3.ONE,
) -> MeshInstance3D:
	if mesh == null:
		return null
	if mesh is ArrayMesh and mesh.get_surface_count() == 0:
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot_deg
	instance.scale = scl
	parent.add_child(instance)
	if paint_material != null and material == paint_material:
		paint_list.append(instance)
	return instance


static func _build_shell(ctx: Dictionary) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var root: Node3D = ctx["root"]
	var paint: Array = ctx["paint"]
	var length: float = ctx["length"]
	var hw: float = ctx["hw"]
	var belt: float = ctx["belt"]
	var sill: float = ctx["sill"]
	var crown: float = ctx["crown"]
	var arch_gap := float(bp["arch_gap"])
	var body_mat: Material = m["body"]

	var zn_set := {}
	for i in 29:
		zn_set[float(i) / 28.0] = true
	for wz: float in [-profile.wheel_base_z, profile.wheel_base_z]:
		var wzn: float = (wz + length * 0.5) / length
		for k in range(-4, 5):
			zn_set[clampf(wzn + float(k) * 0.02, 0.0, 1.0)] = true
	zn_set[0.012] = true
	zn_set[0.988] = true
	var zn_list := zn_set.keys()
	zn_list.sort()

	var bottom_base := [
		Vector2(0.0, sill + 0.085), Vector2(0.08, sill + 0.025), Vector2(0.20, sill),
		Vector2(0.80, sill), Vector2(0.93, sill + 0.025), Vector2(1.0, sill + 0.095),
	]
	var stations: Array = []
	for zn in zn_list:
		var z := -length * 0.5 + float(zn) * length
		var base := CarBodyFactory.catmull_rom_1d(bottom_base, float(zn))
		stations.append({
			"z": z,
			"hw": half_width_at(bp, length, hw, z),
			"bottom": base,
			"top": top_at(bp, length, belt, z),
			"arch": arch_circle_bottom(profile, arch_gap, z, base) - base,
			"fender": fender_lift_at(bp, profile, belt, crown, z),
		})

	var clad_split := float(bp["clad_split"])
	var body_bucket := func(_i: int, _j: int, pa: Vector2, pb: Vector2, _z: float) -> String:
		return BUCKET_TRIM if 0.5 * (pa.y + pb.y) < clad_split else BUCKET_PAINT
	var shell := CarBodyFactory.build_loft(stations, BODY_SECTION, 12, body_bucket)
	add_mesh(root, "BodyPaint", shell.get(BUCKET_PAINT, null) as Mesh, body_mat, paint, body_mat)
	add_mesh(root, "BodyTrim", shell.get(BUCKET_TRIM, null) as Mesh, m["trim"])

	# Fondo piatto scuro tra gli assi: chiude completamente il sottoscocca.
	var pan_mesh := BoxMesh.new()
	pan_mesh.size = Vector3(hw * 1.56, 0.055, length * 0.86)
	add_mesh(root, "ChassisPan", pan_mesh, m["well"], [], null, Vector3(0.0, sill + 0.02, 0.0))

	var span: Vector2 = bp["glass_span"]
	var g0 := span.x
	var g1 := span.y
	var roof_range: Vector2 = bp["roof_range"]
	var pillars_b: Vector2 = bp["pillars_b"]
	var pillars_c: Vector2 = bp["pillars_c"]
	var gt_set := {}
	for i in 21:
		gt_set[float(i) / 20.0] = true
	for edge: float in [
		pillars_b.x, pillars_b.y, pillars_c.x, pillars_c.y, roof_range.x, roof_range.y,
	]:
		gt_set[edge] = true
	var gt_list := gt_set.keys()
	gt_list.sort()

	var glass_bottom := belt * float(bp["glass_bottom_f"])
	var gstations: Array = []
	for gt in gt_list:
		var zn := g0 + float(gt) * (g1 - g0)
		gstations.append({
			"z": -length * 0.5 + zn * length,
			"hw": hw * CarBodyFactory.catmull_rom_1d(bp["glass_w"], float(gt)),
			"bottom": glass_bottom,
			"top": profile.roof_height * CarBodyFactory.catmull_rom_1d(bp["glass_top"], float(gt)),
		})

	var roof_split := float(bp["roof_split"])
	var a_pillars := bool(bp["a_pillars"])
	var glass_bucket := func(_i: int, _j: int, pa: Vector2, pb: Vector2, z_mid: float) -> String:
		var yf := 0.5 * (pa.y + pb.y)
		var gt := ((z_mid + length * 0.5) / length - g0) / maxf(g1 - g0, 0.000001)
		if yf >= roof_split:
			return BUCKET_PAINT
		if gt <= 0.10 or gt >= 0.90:
			return BUCKET_PAINT
		if a_pillars and gt < roof_range.x and yf >= 0.50:
			return BUCKET_PAINT
		if gt >= pillars_b.x and gt <= pillars_b.y and yf > 0.06:
			return BUCKET_PAINT
		return BUCKET_GLASS
	var cabin := CarBodyFactory.build_loft(gstations, GLASS_SECTION, 11, glass_bucket)
	add_mesh(root, "CabinGlass", cabin.get(BUCKET_GLASS, null) as Mesh, m["glass"])
	add_mesh(root, "CabinPaint", cabin.get(BUCKET_PAINT, null) as Mesh, body_mat, paint, body_mat)


static func _build_wheel_housings(ctx: Dictionary) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var root: Node3D = ctx["root"]
	var paint: Array = ctx["paint"]
	var body_mat: Material = m["body"]
	var radius := profile.wheel_radius
	var corners: Array = [
		[Vector3(-profile.wheel_base_x, radius, -profile.wheel_base_z), -1.0, profile.wheel_width],
		[Vector3(profile.wheel_base_x, radius, -profile.wheel_base_z), 1.0, profile.wheel_width],
		[Vector3(-profile.wheel_base_x, radius, profile.wheel_base_z), -1.0, profile.rear_wheel_width],
		[Vector3(profile.wheel_base_x, radius, profile.wheel_base_z), 1.0, profile.rear_wheel_width],
	]
	var tags := ["FL", "FR", "RL", "RR"]
	for i in corners.size():
		var c: Array = corners[i]
		var pos: Vector3 = c[0]
		var side: float = c[1]
		var width: float = c[2]
		var well_r := radius + float(bp["arch_gap"]) * 0.65
		var well_cyl := CylinderMesh.new()
		well_cyl.top_radius = well_r
		well_cyl.bottom_radius = well_r
		well_cyl.height = 0.16
		well_cyl.radial_segments = 20
		well_cyl.rings = 1
		add_mesh(
			root,
			"Well" + tags[i],
			well_cyl,
			m["well"],
			[],
			null,
			Vector3(pos.x - side * (width * 0.5 + 0.055), radius, pos.z),
			Vector3(0.0, 0.0, 90.0),
		)
		var flare_mat: Material = (
			m["trim"] if String(bp["arch_flare"]) == "trim" else body_mat
		)
		var hw_at := half_width_at(bp, profile.body_length, ctx["hw"], pos.z)
		add_mesh(
			root,
			"Arch" + tags[i],
			CarBodyFactory.build_torus_arc(radius + 0.068, 0.040, 24, 9, 206.0),
			flare_mat,
			paint,
			body_mat,
			Vector3(side * (hw_at - 0.016), radius, pos.z),
			Vector3(0.0, 90.0, 0.0),
		)


static func _build_fixed_body_trim(ctx: Dictionary) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var bp: Dictionary = ctx["bp"]
	var m: Dictionary = ctx["m"]
	var glow: Array = ctx["glow"]
	var paint: Array = ctx["paint"]
	var root: Node3D = ctx["root"]
	var length: float = ctx["length"]
	var hw: float = ctx["hw"]
	var belt: float = ctx["belt"]
	var nose_z: float = ctx["nose_z"]
	var tail_z: float = ctx["tail_z"]
	var nose_top: float = ctx["nose_top"]
	var tail_top: float = ctx["tail_top"]
	var body_mat: Material = m["body"]
	var sides: Array[float] = [-1.0, 1.0]

	var head_mat := MaterialFactory.unique_emissive(profile.headlight_color, 1.4)
	var tail_mat := MaterialFactory.unique_emissive(profile.taillight_color.darkened(0.10), 0.65)
	if String(bp["light_style"]) == "bar":
		var bar := add_mesh(
			root, "HeadBar", CarBodyFactory.build_capsule(0.042, hw * 1.26), head_mat,
			[], null, Vector3(0.0, nose_top - 0.010, nose_z - 0.004),
			Vector3(0.0, 0.0, 90.0), Vector3(1.0, 1.0, 0.7),
		)
		if bar != null:
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.append(bar)
		var tbar := add_mesh(
			root, "TailBar", CarBodyFactory.build_capsule(0.038, hw * 1.34), tail_mat,
			[], null, Vector3(0.0, tail_top * 0.94, tail_z + 0.012),
			Vector3(0.0, 0.0, 90.0), Vector3(1.0, 1.0, 0.7),
		)
		if tbar != null:
			tbar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.append(tbar)
	else:
		var slim := String(bp["light_style"]) == "slim"
		var housing_sphere := SphereMesh.new()
		housing_sphere.radius = 0.112
		housing_sphere.height = 0.224
		var lens_sphere := SphereMesh.new()
		lens_sphere.radius = 0.098
		lens_sphere.height = 0.196
		var tail_cap := CarBodyFactory.build_capsule(0.058, 0.22)
		for side in sides:
			var sfx := "L" if side < 0.0 else "R"
			var tilt := side * (10.0 if slim else 0.0)
			add_mesh(
				root, "HeadHousing" + sfx, housing_sphere, m["trim"], [], null,
				Vector3(side * hw * 0.62, nose_top - 0.015, nose_z + 0.068),
				Vector3(-10.0, side * -14.0, tilt),
				Vector3(1.30, 0.50 if slim else 0.72, 0.55),
			)
			var lens := add_mesh(
				root, "HeadLens" + sfx, lens_sphere, head_mat, [], null,
				Vector3(side * hw * 0.62, nose_top - 0.015, nose_z + 0.042),
				Vector3(-10.0, side * -14.0, tilt),
				Vector3(1.26, 0.42 if slim else 0.62, 0.50),
			)
			if lens != null:
				lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				glow.append(lens)
			var tail := add_mesh(
				root, "TailLight" + sfx, tail_cap, tail_mat, [], null,
				Vector3(side * hw * 0.60, tail_top * 0.92, tail_z - 0.048),
				Vector3(0.0, side * 12.0, 90.0), Vector3(1.0, 1.0, 0.62),
			)
			if tail != null:
				tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				glow.append(tail)
		add_mesh(
			root, "TailTrimBar", CarBodyFactory.build_capsule(0.050, hw * 1.12), m["trim"],
			[], null, Vector3(0.0, tail_top * 0.81, tail_z + 0.002),
			Vector3(0.0, 0.0, 90.0), Vector3(1.0, 0.9, 0.55),
		)

	if bool(bp["nose_intake"]):
		add_mesh(
			root, "NoseGrille", CarBodyFactory.build_capsule(0.072, hw * 0.90), m["trim"],
			[], null, Vector3(0.0, belt * 0.61, nose_z + 0.026),
			Vector3(-8.0, 0.0, 90.0), Vector3(1.0, 0.80, 0.5),
		)
		var badge := CylinderMesh.new()
		badge.top_radius = 0.044
		badge.bottom_radius = 0.044
		badge.height = 0.024
		add_mesh(
			root, "NoseBadge", badge, m["rim"], [], null,
			Vector3(0.0, belt * 0.61, nose_z - 0.004), Vector3(90.0, 0.0, 0.0),
		)

	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.36, 0.13, 0.026)
	var plate := add_mesh(
		root, "LicensePlate", plate_mesh,
		MaterialFactory.colored("license_plate", Color(0.93, 0.94, 0.90), 0.55, 0.0),
		[], null, Vector3(0.0, belt * 0.67, tail_z + 0.018), Vector3(6.0, 0.0, 0.0),
	)
	if plate != null:
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var span: Vector2 = bp["glass_span"]
	var mirror_z := -length * 0.5 + (span.x + 0.10 * (span.y - span.x)) * length
	var mirror_mat: Material = body_mat if bool(bp["mirrors_painted"]) else m["trim"]
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.016
	stalk.bottom_radius = 0.020
	stalk.height = 0.16
	var glass_disc := CylinderMesh.new()
	glass_disc.top_radius = 0.042
	glass_disc.bottom_radius = 0.042
	glass_disc.height = 0.012
	var handle_mesh := CarBodyFactory.build_capsule(0.017, 0.085)
	for side in sides:
		var sfx := "L" if side < 0.0 else "R"
		add_mesh(
			root, "MirrorStalk" + sfx, stalk, m["trim"], [], null,
			Vector3(side * hw * 0.92, belt + 0.055, mirror_z),
			Vector3(0.0, 0.0, side * 62.0),
		)
		add_mesh(
			root, "MirrorCap" + sfx, CarBodyFactory.build_capsule(0.055, 0.080),
			mirror_mat, paint, body_mat,
			Vector3(side * (hw * 0.99 + 0.020), belt + 0.105, mirror_z),
			Vector3(0.0, 0.0, 90.0), Vector3(1.0, 0.98, 0.66),
		)
		add_mesh(
			root, "MirrorLens" + sfx, glass_disc, m["glass"], [], null,
			Vector3(side * (hw * 0.99 + 0.020), belt + 0.105, mirror_z + 0.030),
			Vector3(90.0, 0.0, 0.0),
		)
		var door_idx := 0
		for hz_f: float in [0.44, 0.62]:
			var hx := hw * CarBodyFactory.catmull_rom_1d(bp["body_w"], hz_f) * 0.965
			add_mesh(
				root, "DoorHandle%s%d" % [sfx, door_idx], handle_mesh, m["trim"], [], null,
				Vector3(side * hx, belt * 0.90, -length * 0.5 + hz_f * length),
				Vector3(90.0, 0.0, 0.0), Vector3(0.8, 1.0, 1.0),
			)
			door_idx += 1

	if bool(bp["roof_rails"]):
		var rail_mesh := CarBodyFactory.build_capsule(0.022, length * 0.30)
		for side in sides:
			var sfx := "L" if side < 0.0 else "R"
			add_mesh(
				root, "RoofRail" + sfx, rail_mesh, m["trim"], [], null,
				Vector3(side * hw * 0.52, profile.roof_height + 0.015, -length * 0.5 + 0.52 * length),
				Vector3(90.0, 0.0, 0.0),
			)


static func _build_pips(ctx: Dictionary, pips: Array) -> void:
	var profile: CarEvolutionProfile = ctx["profile"]
	var m: Dictionary = ctx["m"]
	var glow: Array = ctx["glow"]
	var root: Node3D = ctx["root"]

	var holder := Node3D.new()
	holder.name = "EvolutionPips"
	holder.position = profile.pip_offset
	root.add_child(holder)

	add_mesh(
		holder, "PipBase", CarBodyFactory.build_capsule(0.020, 0.98), m["trim"],
		[], null, Vector3(0.0, -0.048, 0.0), Vector3(0.0, 0.0, 90.0), Vector3(1.0, 1.0, 3.2),
	)

	var count: int = GameConfig.EVOLUTION_MAX_LEVEL - GameConfig.EVOLUTION_MIN_LEVEL
	var center_offset: float = (count - 1) * 0.5
	var lit_mat := MaterialFactory.unique_emissive(profile.glow_color, 1.8)
	var off_mat := MaterialFactory.pip_off()

	var pip_mesh := BoxMesh.new()
	pip_mesh.size = PIP_SIZE
	for index in count:
		var is_lit := index < profile.level
		var pip := add_mesh(
			holder, "Pip%d" % index, pip_mesh, lit_mat if is_lit else off_mat,
			[], null, Vector3((index - center_offset) * PIP_SPACING, 0.0, 0.0),
		)
		if pip != null:
			pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pips.append(pip)
			if is_lit:
				glow.append(pip)
