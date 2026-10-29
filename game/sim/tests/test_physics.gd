extends RefCounted
## Pixel Physics: splashes, stains, burning, gases and falling ground behave the way the proving ground does.


func _count(w: SandWorld, m: int, r := Rect2i()) -> int:
	if r.size == Vector2i.ZERO:
		r = Rect2i(0, 0, w.get_width(), w.get_height())
	return int(w.count_rect(r.position.x, r.position.y, r.size.x, r.size.y).get(m, 0))


func _run(w: SandWorld, n: int) -> void:
	for i in n:
		w.step()


func _basin(wd: int, ht: int, seed: int) -> SandWorld:
	var w := Sim.create(wd, ht, seed)
	w.fill_rect(0, ht - 8, wd, 8, SandWorld.M_STONE)
	w.fill_rect(0, 0, 4, ht, SandWorld.M_STONE)
	w.fill_rect(wd - 4, 0, 4, ht, SandWorld.M_STONE)
	return w


func run(t) -> void:
	# --- a stream of blood falling into a pool throws droplets up
	var w := _basin(128, 128, 21)
	w.fill_rect(4, 100, 120, 20, SandWorld.M_HOLY)
	_run(w, 120)
	var most := 0
	for k in 90:
		w.fill_rect(60, 4, 4, 2, SandWorld.M_BLOOD)
		w.step()
		most = maxi(most, w.particle_count())
	t.note("most droplets in the air at once: %d" % most)
	t.check(most > 2, "a fast stream splashes droplets out of the pool")
	_run(w, 900)
	t.check(_count(w, SandWorld.M_BLOOD) + _count(w, SandWorld.M_HOLY) > 2000, "splashing keeps the liquid (nothing vanishes into thin air)")

	# --- water levels out in a stone basin
	w = _basin(128, 96, 4)
	w.fill_rect(10, 20, 20, 40, SandWorld.M_HOLY)
	_run(w, 900)
	var top := 999
	var low := 0
	for x in range(6, 122):
		var y := w.surface_y(x, 0)
		var s := 0
		for yy in range(0, 88):
			if w.is_liquid(x, yy):
				s = yy
				break
		if s > 0:
			top = mini(top, s)
			low = maxi(low, s)
	t.note("pool surface rows %d..%d" % [top, low])
	t.check(low - top <= 2, "a pool settles level (surface spans %d rows)" % (low - top + 1))

	# --- blood stains what it touches, and the stain outlives the blood
	w = _basin(96, 64, 8)
	w.fill_rect(30, 40, 20, 8, SandWorld.M_BLOOD)
	_run(w, 300)
	w.fill_rect(4, 0, 88, 56, SandWorld.M_EMPTY)
	var stained := 0
	for x in range(4, 92):
		if w.get_stain(x, 56) == SandWorld.M_BLOOD:
			stained += 1
	t.note("stone cells stained by blood: %d" % stained)
	t.check(stained > 10, "blood leaves a stain on the stone floor")
	var img := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	w.render_region(img, 0, 0)
	var fresh := img.get_pixel(40, 56)
	_run(w, 7200) # two minutes
	w.render_region(img, 0, 0)
	var aged := img.get_pixel(40, 56)
	t.note("stain colour fresh %s, after 2 min %s" % [fresh.to_html(false), aged.to_html(false)])
	t.check(w.get_stain(40, 56) == SandWorld.M_BLOOD, "the stain is still there after two minutes")
	t.check(aged.r - aged.g < fresh.r - fresh.g, "the stain browns as it ages")

	# --- holy water scrubs stains away
	w.fill_rect(20, 46, 56, 10, SandWorld.M_HOLY)
	_run(w, 600)
	var left := 0
	for x in range(4, 92):
		if w.get_stain(x, 56) == SandWorld.M_BLOOD:
			left += 1
	t.note("blood-stained cells after a holy wash: %d (was %d)" % [left, stained])
	t.check(left < stained / 2, "holy water scrubs blood stains")

	# --- tallow burns from the surface down, not all at once
	w = _basin(96, 64, 3)
	w.fill_rect(20, 40, 56, 16, SandWorld.M_TALLOW)
	_run(w, 120)
	var surf := 0
	while surf < 56 and w.get_mat(48, surf) != SandWorld.M_TALLOW:
		surf += 1
	w.ignite(48, surf - 1, 6)
	_run(w, 60)
	var burning_top := 0
	var burning_deep := 0
	for x in range(20, 76):
		var s := 0
		for y in range(30, 56):
			if w.get_mat(x, y) == SandWorld.M_TALLOW:
				if s == 0:
					s = y
				if w.is_burning(x, y):
					if y - s < 3:
						burning_top += 1
					elif y - s > 4:
						burning_deep += 1
	t.note("burning tallow cells: near the surface %d, deep in the pool %d" % [burning_top, burning_deep])
	t.check(burning_top > 5 and burning_deep == 0, "a tallow pool burns from its surface")

	# --- miasma goes up in a flash near fire
	w = _basin(64, 64, 2)
	w.fill_rect(20, 20, 20, 20, SandWorld.M_MIASMA)
	w.add_heat(30, 30, 3, 10.0)
	_run(w, 2)
	var fire := _count(w, SandWorld.M_FIRE)
	t.note("miasma: %d flames two ticks after heating" % fire)
	t.check(fire > 20, "heated miasma flashes")

	# --- smoke rises
	w = _basin(64, 96, 2)
	w.fill_rect(20, 70, 20, 10, SandWorld.M_SMOKE)
	_run(w, 40)
	t.check(_count(w, SandWorld.M_SMOKE, Rect2i(0, 0, 64, 60)) > 50, "smoke rises")

	# --- burning coffin wood throws embers
	w = _basin(96, 64, 6)
	w.fill_rect(30, 36, 30, 20, SandWorld.M_WOOD)
	w.ignite(45, 35, 4)
	var embers := 0
	for k in 20:
		_run(w, 60)
		embers = maxi(embers, _count(w, SandWorld.M_EMBER))
	t.note("most embers at once in a 20 s wood fire: %d" % embers)
	t.check(embers > 0, "burning wood sheds embers")

	# --- ground never caves in by itself; a piece cut free falls as one chunk and reports crush events
	w = Sim.create(160, 120, 5)
	w.fill_rect(0, 100, 160, 20, SandWorld.M_BEDROCK)
	w.fill_rect(0, 30, 160, 20, SandWorld.M_EARTH) # a bridge of earth, held up by the sides of the world
	_run(w, 120)
	for y in range(28, 52):
		w.dig(80, y, 2, 10.0) # cut the bridge in the middle: each half still hangs from its side
	_run(w, 120)
	t.check(w.falling_chunk_count() == 0 and _count(w, SandWorld.M_EARTH, Rect2i(0, 30, 160, 20)) > 2800, "ground that is still held up stays put")
	w.take_crush_events()
	for y in range(28, 52):
		w.dig(50, y, 2, 10.0) # a second cut frees the piece between the two cuts
	_run(w, 6)
	t.check(w.falling_chunk_count() == 1, "the piece cut free falls as one chunk")
	var events := []
	for k in 120:
		w.step()
		events.append_array(w.take_crush_events())
	var landed := events.filter(func(e): return e.landed)
	t.note("crush events: %d while falling, %d landed" % [events.size() - landed.size(), landed.size()])
	t.check(events.size() > 5 and landed.size() == 1, "a falling chunk reports crush events and one landing")
	if landed.size() == 1:
		var e: Dictionary = landed[0]
		t.note("landing: rect %s, force %.1f, speed %.1f, %d cells" % [e.rect, e.force, e.speed, e.cells])
		t.check(e.rect is Rect2i and e.force > 0.0, "crush events carry a rect and a force")
	var on_floor := _count(w, SandWorld.M_EARTH, Rect2i(0, 70, 160, 30)) + _count(w, SandWorld.M_DIRT, Rect2i(0, 70, 160, 30))
	t.check(on_floor > 400, "the piece landed on the floor (%d cells there)" % on_floor)
	t.check(_count(w, SandWorld.M_DIRT) > 0, "a hard landing shatters the leading edge into dirt")

	# --- digging a cave inside the ground leaves its ceiling up
	w = Sim.create(160, 120, 5)
	w.fill_rect(0, 20, 160, 100, SandWorld.M_EARTH)
	_run(w, 30)
	for x in range(40, 120, 2):
		w.dig(x, 60, 6, 10.0)
	_run(w, 120)
	t.check(w.falling_chunk_count() == 0 and w.get_mat(80, 50) == SandWorld.M_EARTH, "a dug cave's ceiling holds")
