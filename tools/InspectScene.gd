extends Node
## Diagnostica di sviluppo: stampa lo stato della scena, gli ingombri dell'auto,
## la composizione dell'ambiente e l'inquadratura (proiezione schermo).
## Uso: godot --headless --path . res://tools/InspectScene.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var gm := main.get_node("GameManager") as GameManager
	var car := main.get_node("Player") as CarController
	var cam := main.get_node("CameraRig/MainCamera") as Camera3D
	var gm_profile := gm.evolution_profile()
	print("STATE=", gm.state, " LEVEL=", gm.evolution_level)
	print("PROFILE level=%d half_w=%.3f half_l=%.3f body_w=%.3f body_l=%.3f" % [
		gm_profile.level, gm_profile.half_width, gm_profile.half_length,
		gm_profile.body_width, gm_profile.body_length])
	print("CAR lateral_limit=%.3f extent_yaw=%.3f half_track=%.3f" % [
		car.lateral_limit,
		gm_profile.lateral_half_extent(GameConfig.CAR_MAX_STEER_YAW),
		GameConfig.TRACK_WIDTH * 0.5])
	print("CAMERA rig=", main.get_node("CameraRig").position, " fov=", cam.fov)
	var viewport := get_viewport().get_visible_rect().size
	print("VIEWPORT=", viewport)
	if viewport.x > 1.0:
		var car_pt := cam.unproject_position(car.global_position + Vector3(0, 0.6, 0))
		print("CAR_SCREEN=", car_pt, " y_frac=%.3f" % (car_pt.y / viewport.y))
		var gates := main.get_node("GateManager") as GateManager
		for index in gates.rows.size():
			var row: GateRow = gates.rows[index]
			var p := cam.unproject_position(Vector3(0, GameConfig.GATE_HEIGHT * 0.5, row.z))
			var top := cam.unproject_position(Vector3(0, GameConfig.GATE_HEIGHT + 0.9, row.z))
			print("GATE row=%d z=%.1f dist=%.1f screen=(%.0f,%.0f) h=%.1fpx" % [
				index, row.z, car.global_position.z - row.z, p.x, p.y, absf(p.y - top.y)])
	var lights := main.find_children("*", "DirectionalLight3D", true, false)
	print("DIRECTIONAL_LIGHTS=", lights.size())
	for light in lights:
		var dl := light as DirectionalLight3D
		print("  LIGHT ", dl.name, " energy=%.2f shadow=%s dist=%.1f splits=%d" % [
			dl.light_energy, dl.shadow_enabled, dl.directional_shadow_max_distance,
			dl.directional_shadow_mode])
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("ENV sky=%s ambient_src=%d amb_energy=%.2f fog=%s ssao=%s glow=%s tonemap=%d" % [
		env.sky != null, env.ambient_light_source, env.ambient_light_energy,
		env.fog_enabled, env.ssao_enabled, env.glow_enabled, env.tonemap_mode])
	var track := main.get_node("TrackManager") as Node3D
	print("TRACK segments=", track.get_child_count())
	var director := car.get_node_or_null("CarVisual") as CarEvolutionDirector
	if director != null:
		var stage := director.get_stage_root()
		print("STAGE root=", stage, " children=", stage.get_child_count() if stage != null else -1)
		var meshes := 0
		var empty := 0
		var tris := 0
		for node in stage.find_children("*", "MeshInstance3D", true, false):
			meshes += 1
			var mi := node as MeshInstance3D
			if mi.mesh == null or mi.mesh.get_surface_count() == 0:
				empty += 1
			else:
				for s in mi.mesh.get_surface_count():
					var arrays := mi.mesh.surface_get_arrays(s)
					tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else 0
		print("CAR_MESHES=%d empty=%d tris=%d" % [meshes, empty, tris])
	print("--- CAR TREE ---")
	for node in car.find_children("*", "Node3D", true, false):
		var n3 := node as Node3D
		var extra := ""
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var aabb := mi.get_aabb()
			var global_aabb := mi.global_transform * aabb
			extra = " mesh=%s aabb_pos=%s aabb_size=%s" % [
				mi.mesh.get_class() if mi.mesh != null else "null",
				global_aabb.position, global_aabb.size]
		print("  ", car.get_path_to(n3), " pos=", n3.global_position, extra)
	var scenery := main.get_node_or_null("Scenery")
	print("SCENERY=", scenery)
	get_tree().quit(0)
