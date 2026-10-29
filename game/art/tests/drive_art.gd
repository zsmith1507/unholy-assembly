extends RefCounted
## Screenshot driver: dresses any scene in Art's lighting and glow bloom, to compare a department's demo with
## and without the art pass.
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/shot.tscn -- --scene=res://sim/demo.tscn \
##       --frames=200 --out=/tmp/x.png --drive=res://art/tests/drive_art.gd

const HOUR := 22.0

var _done := false


func drive(main: Node, _frame: int) -> void:
	if _done:
		return
	_done = true
	for sv in main.find_children("*", "SimView", true, false):
		load("res://art/install.gd").style_glow(sv)
	if main.get_tree().get_first_node_in_group("lighting") == null:
		var l := ArtLighting.new()
		l.override_hour = HOUR
		l.override_depth = 0.0
		main.add_child(l)
