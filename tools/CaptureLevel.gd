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
		"height": 17.0, "distance": 17.0, "look": 58.0, "look_height": 0.0, "fov": 62.0},
	{"name": "07_hud_race", "z": -96.0, "x": 0.4, "mode": "game", "hud": true, "running": true},
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
	print("CAPTURE COMPLETE")
	get_tree().quit(0)


func _capture(shot: Dictionary, hud: CanvasLayer) -> void:
	_car.position = Vector3(float(shot["x"]), 0.0, float(shot["z"]))
	_car.lateral_target = float(shot["x"])
	# La pista si ricicla solo in avanti: dopo un teletrasporto (qui si salta
	# da una posizione all'altra) va riportata sotto l'auto, altrimenti si
	# fotografa il prato dove dovrebbe esserci l'asfalto.
	var track := _main.get_node("TrackManager") as TrackManager
	track.snap_to(_car.position.z)
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
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, shot["name"]])
	var error := image.save_png(path)
	print("SHOT %s err=%d %dx%d" % [path, error, image.get_width(), image.get_height()])
	if mode != "game":
		_main.set_process(true)
