extends Node
## Strumento di sviluppo: apre il livello, attende che la scena sia stabile e
## salva una serie di screenshot reali del renderer. Pensato per la CI
## (Xvfb + Mesa) e per il lavoro di direzione artistica locale.
##
## Uso:
##   godot --path . --resolution 540x960 res://tools/CaptureLevel.tscn

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_DIR: String = "res://docs/screenshots"

var _main: Node
var _car: CarController

## Punti di ripresa: nome, Z dell'auto, X, HUD visibile.
var _shots: Array = [
	{"name": "01_start_hero", "z": -4.0, "x": 0.0, "hud": false},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_car = _main.get_node("Player") as CarController
	var hud := _main.get_node("HUD") as CanvasLayer
	for shot in _shots:
		await _capture(shot, hud)
	get_tree().quit(0)


func _capture(shot: Dictionary, hud: CanvasLayer) -> void:
	_car.position = Vector3(float(shot["x"]), 0.0, float(shot["z"]))
	_car.lateral_target = float(shot["x"])
	hud.visible = bool(shot["hud"])
	# Lascia al GameRoot / TrackManager il tempo di aggiornare camera e segmenti.
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, shot["name"]])
	var error := image.save_png(path)
	print("SHOT %s -> %s (err %d) %dx%d" % [path, shot["name"], error, image.get_width(), image.get_height()])
