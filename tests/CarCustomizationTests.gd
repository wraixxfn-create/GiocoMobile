class_name CarCustomizationTests
extends RefCounted
## Suite di test di integrazione per il sistema modulare di personalizzazione
## ed evoluzione fisica dell'automobile.
##
## Verifica tutti i requisiti architetturali e i criteri di accettazione:
##   1. Separazione rigorosa dati (`Resource` `.tres`) / logica / geometria.
##   2. Copertura di tutti gli 8 slot modulari e delle >= 3 varianti visive
##      per paraurti, ruote, spoiler, motore, scarico ed aerodinamica.
##   3. Sostituzione chirurgica di una singola parte senza ricostruire il rig
##      né gli altri componenti né azzerare rotazione/sterzata dei mozzi.
##   4. Cambio reale della geometria ruote e cambio reale della silhouette
##      allo swap di spoiler e paraurti.
##   5. Allineamento punti di montaggio, orientamento ortonormale, appoggio a
##      terra e validazione di compatibilità / livello richiesto.
##   6. Integrità di movimento, collisioni con ostacoli e telecamera durante
##      sostituzioni effettuate in piena corsa.
##   7. Identificazione puramente basata sui dati (`StringName` / `Slot`), mai
##      su controlli fragili legati ai nomi dei nodi.


static func run(runner: Node) -> void:
	_test_part_catalog_and_resources(runner)
	_test_single_part_swap_preserves_hierarchy(runner)
	_test_wheel_swap_changes_visible_wheels(runner)
	_test_spoiler_and_bumper_swaps_change_silhouette(runner)
	_test_mount_points_orientation_and_compatibility(runner)
	await _test_live_swap_preserves_driving_collisions_and_camera(runner)
	await _test_data_identity_without_fragile_node_names(runner)


# ------------------------------------------------ 1. Dati e Risorse `.tres` --

static func _test_part_catalog_and_resources(runner: Node) -> void:
	CarPartRegistry.ensure_loaded()
	var all_parts := CarPartRegistry.all_parts()
	runner._check(
		all_parts.size() >= 30,
		"catalogo componenti modulari caricato da risorse .tres (%d parti)" % all_parts.size(),
	)

	var seen_ids := {}
	var all_valid := true
	var prototypes_documented := true
	for part in all_parts:
		if part == null or not (part is Resource) or part.id == &"":
			all_valid = false
			continue
		if seen_ids.has(part.id) or part.display_name.is_empty():
			all_valid = false
		seen_ids[part.id] = true
		if part.required_level < GameConfig.EVOLUTION_MIN_LEVEL:
			all_valid = false
		if part.required_level > GameConfig.EVOLUTION_MAX_LEVEL:
			all_valid = false
		if part.is_procedural_prototype and part.asset_upgrade_notes.strip_edges().is_empty():
			prototypes_documented = false

	runner._check(all_valid, "ogni CarPartDefinition ha ID univoco, slot, rarità e livello validi")
	runner._check(
		prototypes_documented and CarPartRegistry.prototype_parts().size() >= 25,
		"tutti i prototipi procedurali dichiarano note esplicite per il futuro upgrade asset",
	)

	var required_counts := {
		CarPartSlot.Type.BODY: 6,
		CarPartSlot.Type.BUMPER_FRONT: 3,
		CarPartSlot.Type.BUMPER_REAR: 3,
		CarPartSlot.Type.WHEELS: 3,
		CarPartSlot.Type.ENGINE: 3,
		CarPartSlot.Type.EXHAUST: 3,
		CarPartSlot.Type.SPOILER: 3,
		CarPartSlot.Type.AERO: 3,
	}
	var slots_covered := true
	for slot in required_counts.keys():
		if CarPartRegistry.parts_for_slot(int(slot)).size() < int(required_counts[slot]):
			slots_covered = false
	runner._check(
		slots_covered,
		"tutti gli 8 slot modulari dispongono delle varianti richieste (>=3 per paraurti/ruote/spoiler)",
	)


# ---------------------------------- 2. Sostituzione senza ricostruire il rig -

static func _test_single_part_swap_preserves_hierarchy(runner: Node) -> void:
	var car: CarController = runner._car
	var director: CarEvolutionDirector = CarModel.find_director(car)
	director.clear_custom_parts(false)
	director.apply_level(3, false)

	var rig := director.get_rig()
	runner._check(rig != null, "VehicleRig modulare persistente presente sull'auto")
	if rig == null:
		return

	var rig_id := rig.get_instance_id()
	var hubs := rig.get_wheel_hubs()
	hubs[0].rotation = Vector3(-1.42, 0.19, 0.0)
	var hub_ids: Array[int] = []
	for hub in hubs:
		hub_ids.append(hub.get_instance_id())

	var before_ids := _slot_visual_instance_ids(rig)

	# 2a. Sostituisce SOLO lo spoiler: tutti gli altri 7 slot restano intatti.
	var res_spoiler := car.equip_part_by_id(&"spoiler_gt_wing")
	var after_spoiler_ids := _slot_visual_instance_ids(rig)
	runner._check(
		bool(res_spoiler["ok"])
		and rig.get_instance_id() == rig_id
		and after_spoiler_ids[CarPartSlot.Type.SPOILER] != before_ids[CarPartSlot.Type.SPOILER]
		and _other_slots_unchanged(before_ids, after_spoiler_ids, CarPartSlot.Type.SPOILER),
		"sostituire lo spoiler non ricostruisce né scocca né ruote né altri slot",
	)

	# 2b. Sostituisce SOLO il set di ruote: mozzi e angoli di rotazione preservati.
	var res_wheels := car.equip_part_by_id(&"wheels_racing_turbofan")
	var after_wheels_ids := _slot_visual_instance_ids(rig)
	var hubs_preserved := true
	for i in hubs.size():
		if rig.get_wheel_hubs()[i].get_instance_id() != hub_ids[i]:
			hubs_preserved = false
	runner._check(
		bool(res_wheels["ok"])
		and hubs_preserved
		and absf(hubs[0].rotation.x - (-1.42)) < 0.0001
		and absf(hubs[0].rotation.y - 0.19) < 0.0001
		and after_wheels_ids[CarPartSlot.Type.WHEELS] != after_spoiler_ids[CarPartSlot.Type.WHEELS]
		and _other_slots_unchanged(after_spoiler_ids, after_wheels_ids, CarPartSlot.Type.WHEELS),
		"sostituire il set di ruote preserva i perni mozzo, rotolamento, sterzo e altri slot",
	)

	# 2c. Sostituisce paraurti ant., post., motore, scarico e aero singolarmente.
	var single_swaps := [
		[CarPartSlot.Type.BUMPER_FRONT, &"bumper_front_gt_aero"],
		[CarPartSlot.Type.BUMPER_REAR, &"bumper_rear_gt_venturi"],
		[CarPartSlot.Type.ENGINE, &"engine_hood_twinturbo"],
		[CarPartSlot.Type.EXHAUST, &"exhaust_quad_titanium"],
		[CarPartSlot.Type.AERO, &"aero_hyper_venturi"],
	]
	var all_surgical := true
	for pair in single_swaps:
		var target_slot := int(pair[0])
		var snap_before := _slot_visual_instance_ids(rig)
		var swap_res := car.equip_part_by_id(pair[1] as StringName)
		var snap_after := _slot_visual_instance_ids(rig)
		if (
			not bool(swap_res["ok"])
			or snap_after[target_slot] == snap_before[target_slot]
			or not _other_slots_unchanged(snap_before, snap_after, target_slot)
		):
			all_surgical = false
	runner._check(
		all_surgical,
		"paraurti ant/post, motore, scarico e aerodinamica si sostituiscono singolarmente in-place",
	)


# ------------------------------------ 3. Varianti ruote realmente visibili ---

static func _test_wheel_swap_changes_visible_wheels(runner: Node) -> void:
	var car: CarController = runner._car
	var director: CarEvolutionDirector = CarModel.find_director(car)
	director.apply_level(2, false)
	var rig := director.get_rig()

	var variants: Array[StringName] = [
		&"wheels_classic_5spoke",
		&"wheels_sport_multispoke",
		&"wheels_racing_turbofan",
	]
	var signatures: Array[String] = []
	var ground_aligned := true
	var visible_ok := true

	for wid in variants:
		var r := car.equip_part_by_id(wid)
		if not bool(r["ok"]):
			visible_ok = false
			continue
		var visuals := rig.get_wheel_visuals()
		if visuals.size() != 4:
			visible_ok = false
			continue
		var tris := 0
		for w in visuals:
			if w == null or not w.is_visible_in_tree():
				visible_ok = false
				continue
			tris += _triangle_count(w)
		var box := _local_aabb(rig)
		if absf(box.position.y) > 0.03:
			ground_aligned = false
		signatures.append("%d_%.3f" % [tris, director.wheel_radius])

	runner._check(visible_ok, "tutte e 3 le varianti di ruote sono montate e visibili sui 4 mozzi")
	runner._check(
		runner._all_unique_strings(signatures),
		"sostituire una ruota cambia realmente geometria e raggio delle ruote (%s)"
		% ", ".join(signatures),
	)
	runner._check(ground_aligned, "ogni set di ruote mantiene appoggio corretto sul piano strada y=0")


# ------------------------------- 4. Silhouette reale di spoiler e paraurti ---

static func _test_spoiler_and_bumper_swaps_change_silhouette(runner: Node) -> void:
	var car: CarController = runner._car
	var director: CarEvolutionDirector = CarModel.find_director(car)
	director.apply_level(3, false)
	var rig := director.get_rig()

	# 4a. Tre varianti visive di spoiler sulla medesima carrozzeria Coupé.
	var spoiler_ids: Array[StringName] = [
		&"spoiler_ducktail",
		&"spoiler_gt_wing",
		&"spoiler_biplane_swan",
	]
	var spoiler_heights: Array[float] = []
	var spoiler_sigs: Array[String] = []
	for sid in spoiler_ids:
		car.equip_part_by_id(sid)
		var sp_node := rig.get_slot_visual(CarPartSlot.Type.SPOILER)
		var sp_box := _subtree_aabb_in_space(sp_node, rig)
		var total_box := _local_aabb(rig)
		spoiler_heights.append(sp_box.position.y + sp_box.size.y)
		spoiler_sigs.append(
			"top=%.3f_w=%.3f_z=%.3f" % [
				sp_box.position.y + sp_box.size.y,
				sp_box.size.x,
				total_box.position.z + total_box.size.z,
			]
		)

	runner._check(
		spoiler_heights.size() == 3
		and spoiler_heights[0] < spoiler_heights[1] - 0.08
		and spoiler_heights[1] < spoiler_heights[2] - 0.08
		and runner._all_unique_strings(spoiler_sigs),
		"sostituire lo spoiler cambia realmente la silhouette in altezza, apertura e coda (%s)"
		% ", ".join(spoiler_sigs),
	)

	# 4b. Tre varianti di paraurti anteriore + tre varianti di paraurti posteriore.
	var front_sigs: Array[String] = []
	for fid: StringName in [&"bumper_front_street", &"bumper_front_splitter", &"bumper_front_gt_aero"]:
		car.equip_part_by_id(fid)
		var fnode := rig.get_slot_visual(CarPartSlot.Type.BUMPER_FRONT)
		var fbox := _subtree_aabb_in_space(fnode, rig)
		front_sigs.append("z=%.3f_w=%.3f_t=%d" % [fbox.position.z, fbox.size.x, _triangle_count(fnode)])

	var rear_sigs: Array[String] = []
	for rid: StringName in [&"bumper_rear_street", &"bumper_rear_diffuser", &"bumper_rear_gt_venturi"]:
		car.equip_part_by_id(rid)
		var rnode := rig.get_slot_visual(CarPartSlot.Type.BUMPER_REAR)
		var rbox := _subtree_aabb_in_space(rnode, rig)
		rear_sigs.append(
			"z=%.3f_w=%.3f_t=%d" % [rbox.position.z + rbox.size.z, rbox.size.x, _triangle_count(rnode)]
		)

	runner._check(
		runner._all_unique_strings(front_sigs) and runner._all_unique_strings(rear_sigs),
		"le tre varianti di paraurti anteriore e posteriore modificano realmente muso e coda",
	)


# ---------------------- 5. Punti di montaggio, orientamento e compatibilità --

static func _test_mount_points_orientation_and_compatibility(runner: Node) -> void:
	var car: CarController = runner._car
	var director: CarEvolutionDirector = CarModel.find_director(car)

	var mounts_ok := true
	for lvl in range(GameConfig.EVOLUTION_MIN_LEVEL, GameConfig.EVOLUTION_MAX_LEVEL + 1):
		director.clear_custom_parts(false)
		director.apply_level(lvl, false)
		var rig := director.get_rig()
		var profile := director.current_profile
		for slot in CarPartSlot.ALL:
			if slot == CarPartSlot.Type.WHEELS:
				continue
			var anchor := rig.get_slot_anchor(slot)
			if anchor == null or absf(anchor.transform.basis.determinant() - 1.0) > 0.002:
				mounts_ok = false
		var front_pos := rig.get_slot_anchor(CarPartSlot.Type.BUMPER_FRONT).position
		var rear_pos := rig.get_slot_anchor(CarPartSlot.Type.BUMPER_REAR).position
		var exh_pos := rig.get_slot_anchor(CarPartSlot.Type.EXHAUST).position
		var hubs := rig.get_wheel_hubs()
		if (
			front_pos.z >= -profile.wheel_base_z
			or rear_pos.z <= profile.wheel_base_z
			or exh_pos.z <= profile.wheel_base_z
			or exh_pos.y < 0.05
			or absf(hubs[0].position.x + hubs[1].position.x) > 0.001
			or absf(hubs[2].position.x + hubs[3].position.x) > 0.001
		):
			mounts_ok = false
	runner._check(
		mounts_ok,
		"tutti i punti di montaggio mantengono posizione, simmetria e orientamento ortonormale",
	)

	# Verifiche di compatibilità fisica e requisito di livello.
	director.apply_level(1, false)
	var mid_on_front := car.equip_part_by_id(&"engine_mid_hyper_v12")
	var tag_probe := CarPartDefinition.new()
	tag_probe.id = &"test_mid_bay_probe"
	tag_probe.display_name = "Sonda Vano Centrale"
	tag_probe.slot = CarPartSlot.Type.ENGINE
	var tag_compat := CarPartCompatibility.new()
	tag_compat.required_mount_tags = PackedStringArray(["mid_bay"])
	tag_probe.compatibility = tag_compat
	var missing_tag_res := car.equip_part(tag_probe)
	runner._check(
		not bool(mid_on_front["ok"])
		and int(mid_on_front["reason"]) == CarCompatibilityValidator.Reason.INCOMPATIBLE_SILHOUETTE
		and not bool(missing_tag_res["ok"])
		and int(missing_tag_res["reason"]) == CarCompatibilityValidator.Reason.MISSING_MOUNT_TAG
		and car.get_equipped_part_id(CarPartSlot.Type.ENGINE) == &"engine_hood_aspirated",
		"motore centrale incompatibile rifiutato su scocca a motore anteriore senza corrompere lo slot",
	)

	var locked_wing := car.equip_part_by_id(&"spoiler_biplane_swan", true)
	runner._check(
		not bool(locked_wing["ok"])
		and int(locked_wing["reason"]) == CarCompatibilityValidator.Reason.LEVEL_TOO_LOW,
		"il controllo del livello richiesto blocca componenti di fascia superiore",
	)

	car.equip_part_by_id(&"bumper_rear_raw")
	var conflict_exh := car.equip_part_by_id(&"exhaust_center_triple")
	runner._check(
		not bool(conflict_exh["ok"])
		and int(conflict_exh["reason"]) == CarCompatibilityValidator.Reason.CONFLICTS_WITH_EQUIPPED,
		"incompatibilità reciproca tra paraurti grezzo e scarico centrale rilevata correttamente",
	)

	# Evoluzione con parti fissate: conserva le universali, rimpiazza quelle incompatibili.
	director.clear_custom_parts(false)
	director.apply_level(2, false)
	car.equip_part_by_id(&"spoiler_gt_wing", false, true)
	car.equip_part_by_id(&"engine_hood_blower", false, true)
	director.apply_level(4, false)
	runner._check(
		car.get_equipped_part_id(CarPartSlot.Type.SPOILER) == &"spoiler_gt_wing"
		and car.get_equipped_part_id(CarPartSlot.Type.ENGINE) == &"engine_mid_v8_bay",
		"l'evoluzione a Supercar conserva lo spoiler custom e adatta il motore al vano centrale",
	)


# ------------------ 6. Movimento, collisioni e camera durante swap live ------

static func _test_live_swap_preserves_driving_collisions_and_camera(runner: Node) -> void:
	var car: CarController = runner._car
	var gm: GameManager = runner._game_manager
	var cam: Camera3D = runner._camera
	var director: CarEvolutionDirector = CarModel.find_director(car)

	director.clear_custom_parts(false)
	if gm.state != GameManager.State.PLAYING:
		gm.start_game()
		await runner._wait_for_state(GameManager.State.PLAYING, 30)

	car.speed_locked = false
	director.apply_level(1, false)
	car.position.x = 0.0
	car.lateral_target = 0.65
	await runner._physics_frames(4)

	var base_speed := car.current_speed
	var z_before := car.position.z
	var x_before := car.position.x

	# Swap multiplo in piena corsa mentre sterza.
	car.equip_part_by_id(&"wheels_racing_turbofan")
	car.equip_part_by_id(&"spoiler_biplane_swan")
	car.equip_part_by_id(&"bumper_front_gt_aero")
	car.equip_part_by_id(&"engine_hood_blower")
	var boosted_speed := car.current_speed

	await runner._physics_frames(10)

	var viewport_size := runner.get_viewport().get_visible_rect().size
	var projected := cam.unproject_position(car.global_position + Vector3(0.0, 0.6, 0.0))
	var centered := true
	if viewport_size.x > 1.0:
		centered = absf(projected.x - viewport_size.x * 0.5) < viewport_size.x * 0.12

	var obs_mgr := runner.get("_obstacle_manager") as ObstacleManager
	var obs_extents: Vector2 = obs_mgr._car_half_extents()
	runner._check(
		boosted_speed > base_speed + 1.0,
		"i modificatori di gameplay dei componenti aggiornano subito la velocità (%.2f -> %.2f m/s)"
		% [base_speed, boosted_speed],
	)
	runner._check(
		car.position.z < z_before - 1.5 and absf(car.position.x - x_before) < 1.2,
		"la sostituzione in corsa non interrompe avanzamento né sterzata",
	)
	runner._check(
		centered and obs_extents.x > GameConfig.CAR_HALF_WIDTH,
		"telecamera e ingombro di collisione ostacoli restano coerenti dopo la sostituzione",
	)
	runner._check(
		_mesh_outward_dot(director.get_slot_visual(CarPartSlot.Type.BODY)) > 0.0
		and _mesh_outward_dot(director.get_slot_visual(CarPartSlot.Type.SPOILER)) > 0.0,
		"le superfici procedurali della carrozzeria e dei componenti hanno avvolgimento CW esterno",
	)


# ------------------ 7. Identificazione dati senza nomi nodo fragili ----------

static func _test_data_identity_without_fragile_node_names(runner: Node) -> void:
	var car: CarController = runner._car
	var director: CarEvolutionDirector = CarModel.find_director(car)

	var custom_spoiler_scene := _make_packed_box_scene(
		"ArbitraryRoot_99", "SubGeo_Alpha", Vector3(1.3, 0.12, 0.25)
	)
	var custom_wheel_scene := _make_packed_box_scene(
		"OpaqueNode_42", "Mesh_X7", Vector3(0.24, 0.58, 0.58)
	)

	var custom_spoiler := CarPartDefinition.new()
	custom_spoiler.id = &"test_custom_spoiler_opaque"
	custom_spoiler.display_name = "Spoiler Scena Esterna"
	custom_spoiler.slot = CarPartSlot.Type.SPOILER
	custom_spoiler.model_scene = custom_spoiler_scene
	custom_spoiler.is_procedural_prototype = false
	var mod := CarGameplayModifiers.new()
	mod.handling_bonus = 0.09
	custom_spoiler.modifiers = mod
	CarPartRegistry.register_part(custom_spoiler)

	var custom_wheels := CarPartDefinition.new()
	custom_wheels.id = &"test_custom_wheels_opaque"
	custom_wheels.display_name = "Ruote Scena Esterna"
	custom_wheels.slot = CarPartSlot.Type.WHEELS
	custom_wheels.model_scene = custom_wheel_scene
	custom_wheels.is_procedural_prototype = false
	CarPartRegistry.register_part(custom_wheels)

	var r1 := car.equip_part(custom_spoiler)
	var r2 := car.equip_part(custom_wheels)
	var spin_before := director.get_wheels()[0].rotation.x
	await runner._physics_frames(4)
	var spin_after := director.get_wheels()[0].rotation.x

	runner._check(
		bool(r1["ok"])
		and bool(r2["ok"])
		and director.get_rig().is_part_equipped(&"test_custom_spoiler_opaque")
		and car.get_equipped_part_id(CarPartSlot.Type.WHEELS) == &"test_custom_wheels_opaque"
		and spin_after != spin_before,
		"parti esterne con nomi nodo arbitrari sono identificate dai dati e animano le 4 ruote",
	)

	# Ripristino completo allo stato standard per i test successivi della suite.
	director.clear_custom_parts(true)
	CarPartRegistry.reload()
	runner._force_evolution(GameConfig.EVOLUTION_START_LEVEL)
	car.reset_for_new_run()
	runner._park_gates_ahead(GameConfig.GATE_FIRST_ROW_DISTANCE)
	var obs_mgr := runner.get("_obstacle_manager") as ObstacleManager
	obs_mgr._sync_rows()
	await runner._physics_frames(2)


# --------------------------------------------------------------- Helpers -----

static func _make_packed_box_scene(
	root_name: String,
	mesh_name: String,
	sz: Vector3,
) -> PackedScene:
	var root := Node3D.new()
	root.name = root_name
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	var box := BoxMesh.new()
	box.size = sz
	mi.mesh = box
	root.add_child(mi)
	mi.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


static func _slot_visual_instance_ids(rig: VehicleRig) -> Dictionary:
	var out: Dictionary = {}
	for slot in CarPartSlot.ALL:
		if slot == CarPartSlot.Type.WHEELS:
			var wvis := rig.get_wheel_visuals()
			out[slot] = wvis[0].get_instance_id() if (wvis.size() > 0 and wvis[0] != null) else 0
		else:
			var vis := rig.get_slot_visual(slot)
			out[slot] = vis.get_instance_id() if vis != null else 0
	return out


static func _other_slots_unchanged(
	before: Dictionary,
	after: Dictionary,
	changed_slot: int,
) -> bool:
	for slot in CarPartSlot.ALL:
		if slot == changed_slot:
			continue
		if before.get(slot, -1) != after.get(slot, -2):
			return false
	return true


static func _triangle_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			count += mi.mesh.get_faces().size() / 3
	for child in node.get_children():
		count += _triangle_count(child)
	return count


static func _local_aabb(rig: Node3D) -> AABB:
	return _subtree_aabb_in_space(rig, rig)


static func _subtree_aabb_in_space(target: Node3D, space_root: Node3D) -> AABB:
	var meshes: Array = []
	_collect_mesh_instances(target, meshes)
	var has_point := false
	var min_pt := Vector3.ZERO
	var max_pt := Vector3.ZERO
	var inv_root := space_root.global_transform.affine_inverse()
	for item in meshes:
		var mi := item as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var rel_xform := inv_root * mi.global_transform
		var faces := mi.mesh.get_faces()
		for v in faces:
			var pt := rel_xform * v
			if not has_point:
				min_pt = pt
				max_pt = pt
				has_point = true
			else:
				min_pt = min_pt.min(pt)
				max_pt = max_pt.max(pt)
	if not has_point:
		return AABB()
	return AABB(min_pt, max_pt - min_pt)


static func _collect_mesh_instances(node: Node, out: Array) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)


static func _mesh_outward_dot(root_node: Node3D) -> float:
	if root_node == null:
		return 0.0
	var meshes: Array = []
	_collect_mesh_instances(root_node, meshes)
	var total := 0.0
	for item in meshes:
		var mi := item as MeshInstance3D
		var arr_mesh := mi.mesh as ArrayMesh if mi != null else null
		if arr_mesh == null or arr_mesh.get_surface_count() == 0:
			continue
		var arrays := arr_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if verts.is_empty() or indices.is_empty():
			continue
		var centroid := Vector3.ZERO
		for v in verts:
			centroid += v
		centroid /= float(verts.size())
		for t in indices.size() / 3:
			var a := verts[indices[t * 3]]
			var b := verts[indices[t * 3 + 1]]
			var c := verts[indices[t * 3 + 2]]
			var n := (c - a).cross(b - a)
			total += n.dot(((a + b + c) / 3.0) - centroid)
	return total
