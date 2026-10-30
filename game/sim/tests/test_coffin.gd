extends RefCounted
## Pixel Physics: coffin planks (M_COFFIN) dig and burn like coffin wood and are drawn with a plank grain.


func _count(w: SandWorld, m: int) -> int:
	return int(w.count_rect(0, 0, w.get_width(), w.get_height()).get(m, 0))


func _lum(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	return c.r + c.g + c.b


func run(t) -> void:
	var M := SandWorld
	t.check(M.M_COFFIN == 31, "M_COFFIN is a new id (31); the old ids are untouched (M_CLAY %d)" % M.M_CLAY)
	t.check(M.mat_kind(M.M_COFFIN) == M.K_STATIC, "coffin planks are static")
	t.check(is_equal_approx(M.mat_hardness(M.M_COFFIN), M.mat_hardness(M.M_WOOD)), "as hard to dig as coffin wood")
	t.check(M.mat_name(M.M_COFFIN) == "Coffin Plank", "named 'Coffin Plank'")

	# --- digs like wood: the same Dig removes the same number of cells
	var removed := {}
	for m in [M.M_WOOD, M.M_COFFIN]:
		var w := Sim.create(96, 96, 5)
		w.fill_rect(20, 20, 56, 56, m)
		var got := 0
		for i in 30:
			got += int(w.dig(48, 48, 6, 0.4).get(m, 0))
			w.step()
		removed[m] = got
	t.check(removed[M.M_COFFIN] > 20 and absi(removed[M.M_COFFIN] - removed[M.M_WOOD]) <= removed[M.M_WOOD] / 5,
		"Dig wears coffin planks like wood (%d vs %d cells)" % [removed[M.M_COFFIN], removed[M.M_WOOD]])

	# --- burns like wood: a lit coffin in the open burns away, leaving ash and embers
	var left := {}
	for m in [M.M_WOOD, M.M_COFFIN]:
		var w := Sim.create(128, 96, 5)
		w.fill_rect(0, 80, 128, 16, M.M_STONE)
		w.fill_rect(40, 70, 34, 8, m)
		w.fill_rect(41, 71, 32, 6, M.M_EMPTY)
		w.ignite(40, 74, 3)
		var burning := false
		for i in 1800:
			w.step()
			if i == 120:
				for x in range(40, 74):
					if w.is_burning(x, 70) or w.is_burning(x, 77):
						burning = true
		left[m] = _count(w, m)
		if m == M.M_COFFIN:
			t.check(burning, "a lit coffin catches")
			t.check(_count(w, M.M_ASH) + _count(w, M.M_EMBER) > 0, "it leaves ash and embers")
	t.note("after 30 s alight: wood %d cells left, coffin planks %d (of 76)" % [left[M.M_WOOD], left[M.M_COFFIN]])
	t.check(left[M.M_COFFIN] < 60, "the coffin burns away (%d of 76 cells left)" % left[M.M_COFFIN])
	t.check(absi(left[M.M_COFFIN] - left[M.M_WOOD]) < 30, "about as fast as wood")

	# --- grain: set by position (the same everywhere it is drawn), with seams and streaks, not per-cell noise
	var a := Sim.create(96, 64, 1)
	a.fill_rect(10, 10, 60, 30, M.M_COFFIN)
	var b := Sim.create(96, 64, 2)
	b.fill_rect(10, 10, 60, 30, M.M_COFFIN)
	var ia := Image.create_empty(96, 64, false, Image.FORMAT_RGBA8)
	var ib := Image.create_empty(96, 64, false, Image.FORMAT_RGBA8)
	a.render_region(ia, 0, 0)
	b.render_region(ib, 0, 0)
	var same := true
	for y in range(14, 38):
		for x in range(12, 68):
			if ia.get_pixel(x, y) != ib.get_pixel(x, y):
				same = false
	t.check(same, "the grain depends on where the plank is, not on the random seed")
	# seams: every third row (12, 15, 18 ...) is darker than the rows between
	var seam := 0.0
	var board := 0.0
	for x in range(12, 68):
		for y in [15, 18, 21, 24, 27]:
			seam += _lum(ia, x, y)
			board += (_lum(ia, x, y + 1) + _lum(ia, x, y + 2)) * 0.5
	# a one-cell lid is all board, never a black seam line
	var thin := Sim.create(64, 32, 1)
	thin.fill_rect(4, 9, 34, 1, M.M_COFFIN) # row 9 is a seam row in thick planking
	var it := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	thin.render_region(it, 0, 0)
	var dark := 0
	for x in range(4, 38):
		if _lum(it, x, 9) < 0.3:
			dark += 1
	t.check(dark < 6, "a one-cell lid on a seam row still shows as wood (%d dark cells of 34)" % dark)
	t.check(seam < board * 0.7, "plank seams are darker than the boards (%.0f vs %.0f)" % [seam, board])
	# streaks run along x: neighbours along a board are closer in colour than neighbours across boards
	var along := 0.0
	var steps := 0
	for y in [16, 19, 22, 25]:
		for x in range(12, 66):
			if _lum(ia, x, y) > 0.3 and _lum(ia, x + 1, y) > 0.3: # skip butt joints and knots
				along += absf(_lum(ia, x, y) - _lum(ia, x + 1, y))
				steps += 1
	var noise := 0.0
	var w2 := Sim.create(96, 64, 3)
	w2.fill_rect(10, 10, 60, 30, M.M_WOOD)
	var iw := Image.create_empty(96, 64, false, Image.FORMAT_RGBA8)
	w2.render_region(iw, 0, 0)
	for y in [16, 19, 22, 25]:
		for x in range(12, 66):
			noise += absf(_lum(iw, x, y) - _lum(iw, x + 1, y))
	along /= maxi(1, steps)
	noise /= 216.0
	t.note("colour change cell to cell along a board: coffin %.3f, plain wood %.3f" % [along, noise])
	t.check(along < noise, "the grain is smoother along a board than plain wood's speckle")

	# a coffin cut free falls as one piece (its grain is stored in the cells, so it travels with them)
	var f := Sim.create(96, 96, 4)
	f.fill_rect(0, 90, 96, 6, M.M_STONE)
	f.fill_rect(30, 20, 30, 6, M.M_COFFIN)
	f.fill_rect(29, 20, 1, 6, M.M_EARTH) # held up by a sliver of earth, cut free below
	f.fill_rect(29, 0, 1, 20, M.M_BEDROCK)
	f.dig(29, 23, 2, 50.0)
	for i in 240:
		f.step()
	var top := f.surface_y(45, 0)
	t.check(top > 60 and f.get_mat(45, top) == M.M_COFFIN, "the cut-free coffin fell (top now row %d)" % top)
