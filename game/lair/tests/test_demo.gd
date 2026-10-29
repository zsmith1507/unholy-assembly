extends RefCounted
## The demo chamber runs the whole chain on its own: corpses ground, a body stitched, a ghoul raised.


func run(t) -> void:
	var demo: Node = load("res://lair/demo.tscn").instantiate()
	t.root.add_child(demo)
	var secs := 0
	while secs < 45 and int(GameState.stats.get("minions_raised", 0)) < 1:
		await t.ticks(60)
		secs += 1
	t.note("after %ds: %s" % [secs, str(GameState.stats)])
	t.check(int(GameState.stats.get("bodies_ground", 0)) >= 1, "demo ground a corpse")
	t.check(int(GameState.stats.get("made_stitched_body", 0)) >= 1, "demo stitched a body")
	t.check(int(GameState.stats.get("minions_raised", 0)) >= 1, "demo raised a ghoul from corpses")
	demo.queue_free()
	await t.ticks(2)
