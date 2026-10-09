extends Node
## Renders a scene for a while and saves screenshots. Needs a display (use xvfb-run on a server).
##   xvfb-run -a godot --path game --rendering-driver opengl3 --fixed-fps 60 res://tests/shot.tscn -- \
##       --scene=res://main/main.tscn --frames=180 --out=/tmp/shot.png [--every=60] [--drive=res://tests/drive_demo.gd]
## --drive points at a script with `func drive(main: Node, frame: int) -> void`, called each frame, to press
## inputs or move the camera, so a screenshot can show the game mid-action.

var _scene: Node
var _frames := 180
var _every := 0
var _out := "/tmp/shot.png"
var _driver = null
var _frame := 0


func _ready() -> void:
	var scene_path := "res://main/main.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="): scene_path = a.substr(8)
		elif a.begins_with("--frames="): _frames = int(a.substr(9))
		elif a.begins_with("--every="): _every = int(a.substr(8))
		elif a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--drive="): _driver = load(a.substr(8)).new()
	_scene = load(scene_path).instantiate()
	add_child(_scene)


func _process(_delta: float) -> void:
	_frame += 1
	if _driver != null:
		_driver.drive(_scene, _frame)
	if _every > 0 and _frame % _every == 0:
		_save(_out.get_basename() + "_%04d.png" % _frame)
	if _frame >= _frames:
		_save(_out)
		get_tree().quit()


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
