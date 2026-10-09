extends RefCounted
## He falls, lands, walks, jumps, levitates, and swims up out of a pool.

const U := preload("res://necro/tests/necro_test_util.gd")


func run(t) -> void:
	var n: Necromancer = U.setup(t)
	n.position.y -= 40.0 # start in the air
	await t.ticks(60)
	t.check(n.on_floor, "lands on the ground")
	t.check(absf(n.position.y - 200.0) <= 2.0, "feet rest on the surface (y=%.1f)" % n.position.y)
	t.check(n.get_box().size == Vector2(14, 58), "uses a necromancer-sized box")

	var x0 := n.position.x
	n.script_input = {"move": Vector2(1, 0)}
	await t.ticks(40)
	t.check(n.position.x > x0 + 40.0, "walks right (moved %.1f px)" % (n.position.x - x0))
	t.check(n.anim_state == &"walk", "plays walk while walking (got %s)" % n.anim_state)
	t.check(n.facing == 1, "faces the way he walks")

	# a hop
	n.script_input = {"jump": true}
	await t.ticks(1)
	n.script_input = {}
	var peak := n.position.y
	for i in 40:
		await t.ticks(1)
		peak = minf(peak, n.position.y)
	var hop := 200.0 - peak
	t.check(hop > 12.0 and hop < 60.0, "jump is a short hop (%.1f px)" % hop)
	await t.ticks(30)
	t.check(n.on_floor, "lands after the jump")

	# hold jump: levitate well above the hop height, spending the meter
	n.script_input = {"jump": true}
	peak = n.position.y
	for i in 100:
		await t.ticks(1)
		peak = minf(peak, n.position.y)
	t.check(200.0 - peak > hop + 30.0, "levitation rises higher than a hop (%.1f px)" % (200.0 - peak))
	t.check(n.get_levitation() < 0.5, "levitation meter drains (%.2f)" % n.get_levitation())
	n.script_input = {}
	await t.ticks(160)
	t.check(n.on_floor, "comes back down")
	t.check(n.get_levitation() > 0.99, "meter refills on the ground (%.2f)" % n.get_levitation())

	# swimming: a deep pool of blood; holding jump swims him up and out
	Sim.world.fill_rect(20, 60, 60, 41, SandWorld.M_BLOOD)
	Sim.world.fill_rect(20, 101, 60, 30, SandWorld.M_EMPTY)
	Sim.world.fill_rect(20, 101, 60, 30, SandWorld.M_BLOOD)
	n.position = Vector2(100, 250)
	await t.ticks(10)
	t.check(n.submerged > 0.5, "is under the blood (%.2f)" % n.submerged)
	t.check(n.anim_state == &"swim", "plays swim in liquid")
	n.script_input = {"jump": true}
	var y0 := n.position.y
	await t.ticks(40)
	t.check(n.position.y < y0 - 20.0, "swims upward holding jump (%.1f px)" % (y0 - n.position.y))
	n.script_input = {"move": Vector2(0, 1)}
	y0 = n.position.y
	await t.ticks(30)
	t.check(n.position.y > y0 + 5.0, "dives holding down (%.1f px)" % (n.position.y - y0))
