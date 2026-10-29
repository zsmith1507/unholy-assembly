extends RefCounted
## Every Bodies and Souls script compiles (the runner can't count a test file that fails to load).

const SCRIPTS := ["body_rig", "body_part", "corpse", "human", "critter", "soul_orb", "flesh_spawner", "install"]


func run(t) -> void:
	for s in SCRIPTS:
		var sc: GDScript = load("res://flesh/%s.gd" % s)
		t.check(sc != null and sc.can_instantiate(), "flesh/%s.gd compiles" % s)
