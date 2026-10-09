extends RefCounted
## Pixel Physics: each material behaves the way the proving ground taught us.


func _count(w: SandWorld, m: int) -> int:
	return int(w.count_rect(0, 0, w.get_width(), w.get_height()).get(m, 0))


func _run(w: SandWorld, n: int) -> void:
	for i in n:
		w.step()


func run(t) -> void:
	# --- stone holds liquid: a pool on stone keeps all its water
	var w := Sim.create(128, 96, 7)
	w.fill_rect(0, 80, 128, 16, SandWorld.M_STONE)
	w.fill_rect(40, 40, 10, 10, SandWorld.M_HOLY)
	_run(w, 240)
	t.check(_count(w, SandWorld.M_HOLY) == 100, "stone holds holy water (have %d of 100)" % _count(w, SandWorld.M_HOLY))
	t.check(w.get_mat(45, 79) == SandWorld.M_HOLY, "the water settled onto the stone floor")

	# --- soil drinks liquid: blood poured on dirt soaks in
	w = Sim.create(128, 96, 7)
	w.fill_rect(0, 80, 128, 16, SandWorld.M_DIRT)
	w.fill_rect(40, 60, 10, 10, SandWorld.M_BLOOD)
	_run(w, 900)
	var left := _count(w, SandWorld.M_BLOOD)
	t.check(left < 60, "dirt soaks up blood (left %d of 100)" % left)

	# --- powders pile at their own angle: ash spreads flatter than flesh
	var widths := {}
	for m in [SandWorld.M_ASH, SandWorld.M_FLESH]:
		w = Sim.create(160, 120, 3)
		w.fill_rect(0, 110, 160, 10, SandWorld.M_STONE)
		for k in 30:
			w.fill_rect(78, 10, 4, 4, m)
			_run(w, 12)
		_run(w, 600)
		var x0 := 160
		var x1 := 0
		for x in 160:
			if w.get_mat(x, 109) == m:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
		widths[m] = x1 - x0
	t.note("pile width: ash %d, flesh %d" % [widths[SandWorld.M_ASH], widths[SandWorld.M_FLESH]])
	t.check(widths[SandWorld.M_ASH] > widths[SandWorld.M_FLESH], "ash spreads wider than flesh")

	# --- coffin wood burns slowly and leaves embers; it is not gone in a flash
	w = Sim.create(128, 96, 5)
	w.fill_rect(0, 80, 128, 16, SandWorld.M_STONE)
	w.fill_rect(50, 70, 20, 10, SandWorld.M_WOOD)
	w.ignite(60, 69, 3)
	_run(w, 120)
	var wood_2s := _count(w, SandWorld.M_WOOD)
	var fire_2s := _count(w, SandWorld.M_FIRE)
	t.note("after 2 s: wood %d, fire %d" % [wood_2s, fire_2s])
	t.check(fire_2s > 0, "the wood caught")
	t.check(wood_2s > 100, "wood burns slowly, not in a flash (%d of 200 left)" % wood_2s)
	_run(w, 1800)
	t.check(_count(w, SandWorld.M_WOOD) < wood_2s, "the fire ate into the wood over time")

	# --- holy water puts fire out
	w = Sim.create(64, 64, 9)
	w.fill_rect(0, 56, 64, 8, SandWorld.M_STONE)
	w.fill_rect(20, 50, 20, 6, SandWorld.M_FIRE)
	w.fill_rect(20, 30, 20, 6, SandWorld.M_HOLY)
	_run(w, 180)
	t.check(_count(w, SandWorld.M_FIRE) < 20, "holy water douses fire")

	# --- glow map lights ichor
	w = Sim.create(64, 64, 9)
	w.fill_rect(10, 10, 4, 4, SandWorld.M_ICHOR)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	w.render_glow(img, 0, 0)
	t.check(img.get_pixel(11, 11).a > 0.5, "ichor glows")
	t.check(img.get_pixel(40, 40).a == 0.0, "empty air is dark")

	# --- crush events API exists and is an array
	t.check(w.take_crush_events() is Array, "take_crush_events returns an array")

	# --- step speed on the full world
	w = Sim.create(1536, 768, 11)
	w.fill_rect(0, 400, 1536, 368, SandWorld.M_EARTH)
	_run(w, 30)
	var t0 := Time.get_ticks_usec()
	_run(w, 60)
	var idle_ms := (Time.get_ticks_usec() - t0) / 60000.0
	for k in 12:
		w.fill_rect(60 + k * 120, 200, 30, 30, [SandWorld.M_BLOOD, SandWorld.M_DIRT, SandWorld.M_HOLY][k % 3])
	t0 = Time.get_ticks_usec()
	_run(w, 60)
	var busy_ms := (Time.get_ticks_usec() - t0) / 60000.0
	t.note("step(): idle %.2f ms, busy %.2f ms (1536x768)" % [idle_ms, busy_ms])
	t.check(idle_ms < 4.0, "idle world steps under 4 ms")
