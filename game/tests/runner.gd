extends Node
## Headless test runner. Each department keeps tests in res://<dept>/tests/test_*.gd.
## A test file extends RefCounted and has `func run(t) -> void` (it may await). Use t.check(...) to assert.
##
##   godot --headless --fixed-fps 60 --path game res://tests/runner.tscn -- --all
##   godot --headless --fixed-fps 60 --path game res://tests/runner.tscn -- --test=res://lair/tests/test_grinder.gd

class Ctx:
	var tree: SceneTree
	var root: Node ## a fresh node per test; add what you build under it
	var failures := 0
	var checks := 0
	var name := ""

	func check(cond: bool, what: String) -> void:
		checks += 1
		if not cond:
			failures += 1
			print("    FAIL  ", what)

	func note(what: String) -> void:
		print("    ", what)

	## A blank world: air above, packed earth from `ground` down, bedrock at the bottom.
	func flat_world(w: int = 256, h: int = 160, ground: int = 100) -> SandWorld:
		var world := Sim.create(w, h, 1234)
		world.fill_rect(0, ground, w, h - ground, SandWorld.M_EARTH)
		world.fill_rect(0, h - 3, w, 3, SandWorld.M_BEDROCK)
		return world

	## Let physics and the sim run for n ticks.
	func ticks(n: int) -> void:
		for i in n:
			await tree.physics_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var files: Array[String] = []
	for a in args:
		if a == "--all":
			_collect("res://", files)
		elif a.begins_with("--test="):
			files.append(a.substr(7))
	files.sort()
	var total_fail := 0
	var total_checks := 0
	for f in files:
		print("TEST ", f)
		var ctx := Ctx.new()
		ctx.tree = get_tree()
		ctx.name = f
		ctx.root = Node2D.new()
		add_child(ctx.root)
		GameState.reset()
		var script = load(f)
		if script == null:
			print("    FAIL  could not load")
			total_fail += 1
			continue
		var test = script.new()
		await test.run(ctx)
		ctx.root.queue_free()
		Sim.world = null
		await get_tree().process_frame
		print("    %d checks, %d failed" % [ctx.checks, ctx.failures])
		total_fail += ctx.failures
		total_checks += ctx.checks
	print("RESULT %d files, %d checks, %d failed" % [files.size(), total_checks, total_fail])
	get_tree().quit(1 if total_fail > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		_collect(dir.path_join(sub), out)
	if dir.get_file() == "tests" or dir.ends_with("/tests"):
		for f in d.get_files():
			if f.begins_with("test_") and f.ends_with(".gd"):
				out.append(dir.path_join(f))
