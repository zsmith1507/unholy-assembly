extends RefCounted
## Plays the hidden start (tests/hidden_start.gd) inside tests/shot.tscn and saves a screenshot after
## each step, so you can see the playthrough:
##   xvfb-run -a godot --path game --rendering-driver opengl3 --fixed-fps 60 res://tests/shot.tscn -- \
##       --scene=res://main/main.tscn --frames=60000 --drive=res://tests/drive_hidden_start.gd
## Screenshots go to OUT.dir as <prefix>_<nn>_<step>.png. The run quits when the playthrough ends.

const HiddenStart := preload("res://tests/hidden_start.gd")
const OUT := {"dir": "/tmp/unholy-shots", "prefix": "integration"}


class Ctx:
	var tree: SceneTree
	var checks := 0
	var failures := 0

	func check(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			print("    FAIL  ", what)

	func note(what: String) -> void:
		print("    ", what)

	func ticks(n: int) -> void:
		for i in n:
			await tree.physics_frame


var _started := false
var _shots := 0


func drive(main: Node, _frame: int) -> void:
	if _started:
		return
	_started = true
	_play(main)


func _play(main: Node) -> void:
	DirAccess.make_dir_recursive_absolute(OUT.dir)
	var ctx := Ctx.new()
	ctx.tree = main.get_tree()
	await ctx.ticks(2)
	var play = HiddenStart.new(ctx, main)
	play.moments = func(step: String) -> void: _shot(main, step)
	await play.play()
	print("hidden start: %d checks, %d failed" % [ctx.checks, ctx.failures])
	main.get_tree().quit()


func _shot(main: Node, step: String) -> void:
	_shots += 1
	var img := main.get_viewport().get_texture().get_image()
	var path := "%s/%s_%02d_%s.png" % [OUT.dir, OUT.prefix, _shots, step]
	img.save_png(path)
	print("saved ", path)
