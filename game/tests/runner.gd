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


## A test that has not finished after this many physics frames (game time) or this much
## wall-clock time counts as failed, and the runner moves on. Override with --timeout=<seconds>
## (game seconds), or per file with `const TEST_TIMEOUT_S := 300.0` in the test script.
const TIMEOUT := {
	"game_seconds": 120.0,
	"wall_seconds": 300.0,
}


## Counts engine and script errors while a test runs, so a test that errors part-way fails even when
## its coroutine returns early with no failed checks.
class ErrorCounter extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_ERROR or error_type == ERROR_TYPE_SCRIPT:
			count += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _errors := ErrorCounter.new()


func _ready() -> void:
	OS.add_logger(_errors)
	var args := OS.get_cmdline_user_args()
	var files: Array[String] = []
	var timeout_s: float = TIMEOUT.game_seconds
	for a in args:
		if a == "--all":
			_collect("res://", files)
		elif a.begins_with("--test="):
			files.append(a.substr(7))
		elif a.begins_with("--timeout="):
			timeout_s = a.substr(10).to_float()
	files.sort()
	var total_fail := 0
	var total_checks := 0
	var broken: Array[String] = []
	for f in files:
		print("TEST ", f)
		var errors0 := _errors.count
		var test = _instantiate(f)
		if test == null:
			total_fail += 1
			broken.append(f)
			continue
		var ctx := Ctx.new()
		ctx.tree = get_tree()
		ctx.name = f
		ctx.root = Node2D.new()
		add_child(ctx.root)
		GameState.reset()
		var limit := timeout_s
		var consts: Dictionary = test.get_script().get_script_constant_map()
		if consts.has("TEST_TIMEOUT_S"):
			limit = float(consts.TEST_TIMEOUT_S)
		var state := {"done": false}
		_run_one(test, ctx, state)
		var frames := 0
		var max_frames := int(limit * Engine.physics_ticks_per_second)
		var wall_end := Time.get_ticks_msec() + int(maxf(limit, TIMEOUT.wall_seconds) * 1000.0)
		while not state.done:
			if frames >= max_frames or Time.get_ticks_msec() > wall_end:
				break
			await get_tree().physics_frame
			frames += 1
		if not state.done:
			# Either it hung, or a script error stopped it part-way (a coroutine that errors never returns).
			print("    FAIL  did not finish within %.0f s of game time (hung, or stopped by a script error above)" % limit)
			ctx.failures += 1
			broken.append(f)
		if _errors.count > errors0:
			print("    FAIL  %d engine or script errors while it ran (see above)" % (_errors.count - errors0))
			ctx.failures += 1
			if not broken.has(f):
				broken.append(f)
		elif ctx.checks == 0:
			print("    FAIL  made no checks")
			ctx.failures += 1
		ctx.root.queue_free()
		Sim.world = null
		await get_tree().process_frame
		print("    %d checks, %d failed" % [ctx.checks, ctx.failures])
		total_fail += ctx.failures
		total_checks += ctx.checks
	for b in broken:
		print("BROKEN ", b)
	print("RESULT %d files, %d checks, %d failed" % [files.size(), total_checks, total_fail])
	get_tree().quit(1 if total_fail > 0 else 0)


## Loads a test file and makes an instance, or prints why it can't and returns null.
func _instantiate(f: String) -> Object:
	if not ResourceLoader.exists(f):
		print("    FAIL  file not found")
		return null
	var script = load(f)
	if script == null or not (script is Script):
		print("    FAIL  could not load (see the parse error above)")
		return null
	if not script.can_instantiate():
		print("    FAIL  does not compile (see the parse error above)")
		return null
	var test = script.new()
	if test == null:
		print("    FAIL  could not be created")
		return null
	if not test.has_method("run"):
		print("    FAIL  has no run(t) function")
		return null
	return test


func _run_one(test: Object, ctx: Ctx, state: Dictionary) -> void:
	await test.run(ctx)
	state.done = true


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
