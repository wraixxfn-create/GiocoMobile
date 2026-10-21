extends Node
## Strumento di sviluppo: apre il livello, posiziona l'auto in punti
## significativi e salva screenshot reali del renderer (telecamera di gioco e
## inquadrature di presentazione). Pensato per la CI (Xvfb + Mesa Vulkan).
##
## Uso:
##   godot --path . --resolution 900x1600 res://tools/CaptureLevel.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_DIR: String = "res://docs/screenshots"

var _main: Node
var _car: CarController
var _camera: Camera3D
var _rig: Node3D

## Inquadrature: `game` usa la camera di gioco; `orbit` gira attorno all'auto
## per mostrare il modello; `overview` è una panoramica dall'alto del livello.
var _shots: Array[Dictionary] = [
	{"name": "01_start_hero", "z": -6.0, "x": 0.0, "mode": "game"},
	{"name": "02_approach_gates", "z": -52.0, "x": -0.9, "mode": "game"},
	{"name": "03_palms_mid", "z": -138.0, "x": 1.3, "mode": "game"},
	{"name": "04_road_detail", "z": -212.0, "x": 0.0, "mode": "game",
		"height": 2.55, "distance": 5.6, "look": 8.4, "look_height": 0.85, "fov": 54.0},
	{"name": "05_car_study", "z": -286.0, "x": 0.7, "mode": "orbit",
		"orbit_angle": 2.45, "orbit_distance": 6.6, "orbit_height": 2.2, "fov": 38.0},
	{"name": "06_overview", "z": -150.0, "x": 0.0, "mode": "overview",
		"height": 22.0, "distance": 30.0, "look": 46.0, "look_height": 0.0, "fov": 58.0},
	{"name": "07_hud_race", "z": -96.0, "x": 0.4, "mode": "game", "hud": true, "running": true},
]

## Inquadrature diagnostiche (solo con GIOCO_DEBUG=1): mostrano l'albedo
## puro e il fondo sostituito da un colore pieno, per distinguere un difetto
## di luce da un buco nella geometria.
var _debug_shots: Array[Dictionary] = [
	{"name": "_tmp/dx_albedo", "z": -96.0, "x": 0.4, "mode": "game", "debug_draw": Viewport.DEBUG_DRAW_UNSHADED},
	{"name": "_tmp/dx_flat_bg", "z": -96.0, "x": 0.4, "mode": "game", "flat_background": true},
	{"name": "_tmp/dx_nofog", "z": -212.0, "x": 0.0, "mode": "game", "probe": "no_fog",
		"height": 2.55, "distance": 5.6, "look": 8.4, "look_height": 0.85, "fov": 54.0},
	{"name": "_tmp/dx_redterrain", "z": -212.0, "x": 0.0, "mode": "game", "probe": "red",
		"height": 2.55, "distance": 5.6, "look": 8.4, "look_height": 0.85, "fov": 54.0},
	{"name": "_tmp/dx_noterrain", "z": -212.0, "x": 0.0, "mode": "game", "probe": "no_terrain",
		"height": 2.55, "distance": 5.6, "look": 8.4, "look_height": 0.85, "fov": 54.0},
	{"name": "_tmp/dx_clones", "z": -212.0, "x": 0.0, "mode": "game", "probe": "clones",
		"height": 2.55, "distance": 5.6, "look": 8.4, "look_height": 0.85, "fov": 54.0},
	{"name": "_tmp/dx_copy", "z": -212.0, "x": 0.0, "mode": "game", "probe": "copy",
		"height": 2.55, "distance": 5.6, "look": 8.4, "look_height": 0.85, "fov": 54.0},
	{"name": "_tmp/dx_car_mats", "z": -96.0, "x": 0.4, "mode": "game", "probe": "car_mats"},
	{"name": "_tmp/dx_car_side", "z": -96.0, "x": 0.4, "mode": "orbit", "probe": "car_mats",
		"orbit_angle": 2.45, "orbit_distance": 6.6, "orbit_height": 2.2, "fov": 38.0},
	{"name": "_tmp/dx_ov_noterrain", "z": -150.0, "x": 0.0, "mode": "overview",
		"height": 22.0, "distance": 30.0, "look": 46.0, "fov": 58.0, "probe": "no_terrain"},
	{"name": "_tmp/dx_ov_red", "z": -150.0, "x": 0.0, "mode": "overview",
		"height": 22.0, "distance": 30.0, "look": 46.0, "fov": 58.0, "probe": "red"},
	{"name": "_tmp/dx_top", "z": -150.0, "x": 0.0, "mode": "overview",
		"height": 8.0, "distance": 0.0, "look": 0.01, "fov": 60.0, "probe": "top"},
]


func _ready() -> void:
	# Watchdog: la cattura non deve mai blocare la CI.
	get_tree().create_timer(600.0).timeout.connect(func() -> void:
		print("CAPTURE TIMEOUT")
		get_tree().quit(3)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR + "/_tmp"))
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	print("CAPTURE ready")
	await get_tree().process_frame
	await get_tree().process_frame
	_car = _main.get_node("Player") as CarController
	_camera = _main.get_node("CameraRig/MainCamera") as Camera3D
	_rig = _main.get_node("CameraRig") as Node3D
	var hud := _main.get_node("HUD") as CanvasLayer
	for shot in _shots:
		print("CAPTURE shot ", shot["name"])
		await _capture(shot, hud)
	if OS.get_environment("GIOCO_DEBUG") == "1":
		for shot in _debug_shots:
			print("CAPTURE debug ", shot["name"])
			await _capture(shot, hud)
	print("CAPTURE COMPLETE")
	get_tree().quit(0)


func _probe_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _capture(shot: Dictionary, hud: CanvasLayer) -> void:
	var is_debug := shot.has("probe") or shot.has("debug_draw") or shot.has("flat_background")
	if is_debug:
		# Congela la corsa: le inquadrature diagnostiche devono stare ferme.
		_car.set_physics_process(false)
		_car.set_process(false)
		(_main.get_node("GameManager") as Node).set_process(false)
	_car.position = Vector3(float(shot["x"]), 0.0, float(shot["z"]))
	_car.lateral_target = float(shot["x"])
	hud.visible = bool(shot.get("hud", false))
	var mode: String = str(shot.get("mode", "game"))
	if bool(shot.get("running", false)):
		var manager := _main.get_node("GameManager") as GameManager
		if manager.state != GameManager.State.PLAYING:
			manager.start_game()
		# Aspetta il countdown e un attimo di corsa reale.
		await get_tree().create_timer(3.2).timeout
	# Lascia aggiornare pista, scenario e camera di gioco.
	for i in 3:
		await get_tree().process_frame
	if mode == "game":
		var height := float(shot.get("height", GameConfig.CAMERA_HEIGHT))
		var distance := float(shot.get("distance", GameConfig.CAMERA_DISTANCE))
		var look := float(shot.get("look", GameConfig.CAMERA_LOOK_AHEAD))
		var look_height := float(shot.get("look_height", GameConfig.CAMERA_LOOK_HEIGHT))
		_camera.fov = float(shot.get("fov", GameConfig.CAMERA_FOV))
		_rig.position = Vector3(_car.position.x, height, _car.position.z + distance)
		_camera.look_at_from_position(
			_rig.position,
			Vector3(_rig.position.x, look_height, _car.position.z - look),
			Vector3.UP,
		)
	else:
		_main.set_process(false)
		if mode == "orbit":
			var angle := float(shot.get("orbit_angle", 2.3))
			var distance := float(shot.get("orbit_distance", 4.6))
			var height := float(shot.get("orbit_height", 1.7))
			_camera.fov = float(shot.get("fov", 42.0))
			var target := _car.position + Vector3(0.0, 0.62, 0.0)
			var position := _car.position + Vector3(
				cos(angle) * distance, height, sin(angle) * distance
			)
			_camera.look_at_from_position(position, target, Vector3.UP)
		else:
			var height := float(shot.get("height", 22.0))
			var distance := float(shot.get("distance", 30.0))
			var look := float(shot.get("look", 46.0))
			_camera.fov = float(shot.get("fov", 58.0))
			var position := Vector3(_car.position.x, height, _car.position.z + distance)
			_camera.look_at_from_position(
				position,
				Vector3(_car.position.x, float(shot.get("look_height", 0.0)), _car.position.z - look),
				Vector3.UP,
			)
	match str(shot.get("probe", "")):
		"no_fog":
			var env_node := _main.get_node("WorldEnvironment") as WorldEnvironment
			env_node.environment.fog_enabled = false
		"no_terrain":
			var ground := _main.get_node("World/GroundField/Terrain") as MeshInstance3D
			ground.visible = false
		"clones":
			var z_probe := float(shot["z"]) - 16.0
			var box := BoxMesh.new()
			box.size = Vector3(7.0, 0.2, 18.0)
			var box_node := MeshInstance3D.new()
			box_node.name = "ProbeBox"
			box_node.mesh = box
			box_node.material_override = _probe_material(Color(0.1, 1.0, 0.2))
			box_node.position = Vector3(0.0, 0.4, z_probe)
			_main.add_child(box_node)
			var asphalt_node := _main.get_node("TrackManager/Segment_0/Asphalt") as MeshInstance3D
			asphalt_node.material_override = _probe_material(Color(1.0, 0.55, 0.0))
			asphalt_node.position.y += 0.7
			var paint_node := _main.get_node("TrackManager/Segment_0/Paint") as MeshInstance3D
			paint_node.position.y += 1.4
		"copy":
			var asphalt_src := _main.get_node("TrackManager/Segment_5/Asphalt") as MeshInstance3D
			var z_probe := float(shot["z"]) - 18.0
			var same_mesh := MeshInstance3D.new()
			same_mesh.name = "ProbeSameMesh"
			same_mesh.mesh = asphalt_src.mesh
			same_mesh.material_override = _probe_material(Color(1.0, 0.45, 0.0))
			same_mesh.position = Vector3(0.0, 1.0, z_probe)
			_main.add_child(same_mesh)
			var dup_mesh := MeshInstance3D.new()
			dup_mesh.name = "ProbeDupMesh"
			dup_mesh.mesh = asphalt_src.mesh.duplicate() as Mesh
			dup_mesh.material_override = _probe_material(Color(0.1, 0.4, 1.0))
			dup_mesh.position = Vector3(0.0, 2.0, z_probe)
			_main.add_child(dup_mesh)
			var plane := PlaneMesh.new()
			plane.size = Vector2(8.0, 22.0)
			var plane_node := MeshInstance3D.new()
			plane_node.name = "ProbePlane"
			plane_node.mesh = plane
			plane_node.material_override = _probe_material(Color(0.1, 1.0, 0.3))
			plane_node.position = Vector3(0.0, 3.0, z_probe)
			_main.add_child(plane_node)
			print("CAPTURE asphalt_mesh_surfaces=", asphalt_src.mesh.get_surface_count())
		"car_mats":
			var flat_paint := _probe_material(Color(1.0, 1.0, 0.0))
			var flat_glass := _probe_material(Color(1.0, 0.0, 1.0))
			var flat_trim := _probe_material(Color(0.25, 0.25, 0.25))
			for node in _car.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				var mat := mi.material_override as StandardMaterial3D
				if mat == null:
					continue
				var name := String(mi.name)
				if name.contains("Glass"):
					mi.material_override = flat_glass
				elif name.contains("Trim") or name.contains("Arch") or name.contains("Well"):
					mi.material_override = flat_trim
				elif name.contains("Paint") or name.contains("Bumper"):
					mi.material_override = flat_paint
		"top":
			var target := _main.get_node("TrackManager/Segment_4/Asphalt") as MeshInstance3D
			if target == null:
				print("PROBE segment_4 asphalt MISSING")
			else:
				var box := target.get_aabb()
				print("PROBE asphalt visible=%s layers=%d aabb=%s pos=%s scale=%s" % [
					target.visible, target.layers, str(box),
					str(target.global_position), str(target.global_transform.basis.get_scale())])
			var plane_top := PlaneMesh.new()
			plane_top.size = Vector2(9.0, 40.0)
			var flat := _probe_material(Color(1.0, 0.2, 0.9))
			flat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var node_top := MeshInstance3D.new()
			node_top.name = "ProbePlaneTop"
			node_top.mesh = plane_top
			node_top.material_override = flat
			node_top.position = Vector3(0.0, 0.02, -150.0)
			_main.add_child(node_top)
			print("PROBE plane added at ", node_top.global_position)
		"red":
			var flat_red := StandardMaterial3D.new()
			flat_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flat_red.albedo_color = Color(1.0, 0.05, 0.05)
			var flat_cyan := StandardMaterial3D.new()
			flat_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flat_cyan.albedo_color = Color(0.05, 0.6, 1.0)
			var ground_fix := _main.get_node("World/GroundField/Terrain") as MeshInstance3D
			ground_fix.material_override = flat_red
			for node in (_main.get_node("TrackManager") as Node3D).get_children():
				var asphalt := node.get_node_or_null("Asphalt") as MeshInstance3D
				if asphalt != null:
					asphalt.material_override = flat_cyan
	if shot.has("debug_draw"):
		get_viewport().debug_draw = int(shot["debug_draw"]) as Viewport.DebugDraw
	if bool(shot.get("flat_background", false)):
		var world_env := _main.get_node("WorldEnvironment") as WorldEnvironment
		world_env.environment.background_mode = Environment.BG_COLOR
		world_env.environment.background_color = Color(1.0, 0.0, 1.0)
		world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, shot["name"]])
	var error := image.save_png(path)
	print("SHOT %s err=%d %dx%d" % [path, error, image.get_width(), image.get_height()])
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	if mode != "game":
		_main.set_process(true)
