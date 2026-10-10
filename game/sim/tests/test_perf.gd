extends RefCounted
## Pixel Physics: how long step() takes on the full 1536x768 world, settled, typical and busy.


func _ms(w: SandWorld, n: int, each := Callable()) -> float:
	var t0 := Time.get_ticks_usec()
	for i in n:
		if each.is_valid():
			each.call(i)
		w.step()
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


func run(t) -> void:
	var w := Sim.create(1536, 768, 99)
	var M := SandWorld
	# a world like the real one: surface ground with turf, caves, a lake, some timber, loose dirt pockets
	w.fill_rect(0, 740, 1536, 28, M.M_BEDROCK)
	w.fill_rect(0, 300, 1536, 440, M.M_EARTH)
	w.fill_rect(0, 298, 1536, 2, M.M_GRASS)
	for k in 10:
		w.fill_rect(80 + k * 145, 420 + (k % 3) * 80, 90, 30, M.M_EMPTY) # caves
		w.fill_rect(100 + k * 145, 360, 30, 20, M.M_DIRT) # pockets of loose dirt
	w.fill_rect(600, 250, 300, 50, M.M_EMPTY)
	w.fill_rect(600, 260, 300, 40, M.M_HOLY) # a lake
	for k in 6:
		w.fill_rect(100 + k * 220, 240, 8, 58, M.M_WOOD) # tree trunks
		w.fill_rect(84 + k * 220, 220, 40, 20, M.M_LEAVES)
	for i in 600:
		w.step()
	var settled := _ms(w, 120)
	var chunks := w.active_chunk_count()

	# typical: a few things going on (a ghoul digging, a trickle of blood, one fire)
	w.ignite(104, 239, 6)
	var typical := _ms(w, 240, func(i):
		w.dig(300 + i / 8, 450, 4, 2.0)
		if i % 3 == 0:
			w.spill(1200, 200, M.M_BLOOD, 3, 0.5, 0.0))
	var chunks_typ := w.active_chunk_count()

	# busy: a breached lake pouring into the caves, two fires, an explosion and a falling slab
	w.dig(905, 280, 10, 50.0)
	w.explode(400, 330, 24, 12.0)
	w.ignite(544, 239, 6)
	var busy := _ms(w, 240, func(i):
		w.fill_rect(200 + (i % 40) * 20, 100, 6, 3, [M.M_DIRT, M.M_BLOOD, M.M_ASH][i % 3])
		w.dig(905, 290 + i / 6, 6, 50.0))
	var chunks_busy := w.active_chunk_count()
	t.note("step() on 1536x768: settled %.2f ms (%d awake chunks), typical %.2f ms (%d), busy %.2f ms (%d)" % [
		settled, chunks, typical, chunks_typ, busy, chunks_busy])
	t.check(settled < 1.0, "a settled world costs almost nothing")
	t.check(typical < 4.0, "typical play stays under 4 ms a step")
	t.check(busy < 12.0, "even a very busy world stays under 12 ms a step")
