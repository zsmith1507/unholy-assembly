extends RefCounted
## A scripted playthrough of the hidden start (design doc, "Hidden start"), on the real generated world
## with every department's real nodes: spawn, dig down, Build the heart, refill mana at the heart, rob a
## grave, Build the grinder, stitching table and altar, feed the corpse through, raise a ghoul, order a
## dig and watch the ghoul dig it, and kill a critter for soul fragments.
##
## The necromancer is played through his scripted input (move, jump, aim, cast, interact), the same path
## a keyboard takes. Where a step needs help to keep going (an item carried by hand, mana topped up), the
## playthrough says so with an "ASSIST" note, so the report shows what a player could not do on their own.
##
## Used by tests/test_hidden_start.gd (headless, counts checks) and tests/drive_hidden_start.gd (renders
## screenshots at the main moments).

const PLAY := {
	"lair_x": 1400.0, # where he goes to ground: the forest's edge, just east of the graveyard
	"depth_px": 190.0, # how far below the surface the lair hall is dug (well below the coffins)
	"hall_px": 420.0, # length of the hall dug west from the shaft
	"walk_ticks": 1200, # give up a walk after this long
	"harvest_ticks": 400,
}

var t ## the test context: check(cond, what), note(what), ticks(n), tree
var main: Node
var n: Node2D ## the necromancer
var moments: Callable = func(_name: String) -> void: pass ## called at screenshot moments
var results := {} ## step -> true / false
var assists: Array[String] = []

var _heart: Node2D
var _grinder: Node2D
var _table: Node2D
var _altar: Node2D
var _corpse: Node2D
var _floor_y := 0.0
var _surface_y := 0.0 ## ground level at the top of the shaft
var _hall: Rect2 ## the dug hall, pixels


func _init(ctx, main_node: Node) -> void:
	t = ctx
	main = main_node


func play() -> void:
	await _step("spawn", _spawn)
	await _step("dig_down", _dig_down)
	await _step("build_heart", _build_heart)
	await _step("refill_mana", _refill)
	await _step("rob_grave", _rob_grave)
	await _step("build_chain", _build_chain)
	await _step("feed_corpse", _feed_corpse)
	await _step("raise_ghoul", _raise_ghoul)
	await _step("ghoul_digs", _ghoul_digs)
	await _step("kill_critter", _kill_critter)
	var line := []
	for k in results:
		line.append("%s=%s" % [k, "pass" if results[k] else "FAIL"])
	t.note("HIDDEN START: " + ", ".join(line))
	for a in assists:
		t.note("ASSIST " + a)


func _step(step_name: String, f: Callable) -> void:
	t.note("-- " + step_name)
	var ok = await f.call()
	results[step_name] = bool(ok)
	t.check(bool(ok), "hidden start: " + step_name)
	moments.call(step_name)


## Puts a thing somewhere by hand (an assist). Ragdolls and items move through drop(), not position.
func _carry(thing: Node2D, at: Vector2) -> void:
	if not is_instance_valid(thing):
		return
	if thing.has_method("drop"):
		thing.drop(at, Vector2.ZERO)
	else:
		thing.global_position = at


func _assist(what: String) -> void:
	assists.append(what)
	t.note("ASSIST " + what)


# ---------------------------------------------------------------- steps

func _spawn() -> bool:
	n = main.get("player")
	if n == null:
		t.note("no player")
		return false
	n.set("scripted", true)
	await t.ticks(90)
	var spawn: Vector2 = main.info.get("necro_spawn", Vector2.ZERO)
	t.note("spawned at %s (spawn %s), on floor %s" % [n.global_position, spawn, n.on_floor])
	return n.on_floor and n.global_position.distance_to(spawn) < 64.0


## Walk to the forest edge by the graveyard, bore a shaft down, then dig a hall west. He digs the way a
## player does: holding the Dig beam on the nearest ground he wants gone, sweeping it about.
func _dig_down() -> bool:
	await walk_to(PLAY.lair_x)
	var top: float = n.global_position.y
	_surface_y = top
	_floor_y = floorf((top + PLAY.depth_px) / Sim.CELL) * Sim.CELL
	t.note("at x %.0f, surface y %.0f, digging to y %.0f" % [n.global_position.x, top, _floor_y])
	var shaft := Rect2(PLAY.lair_x - 26.0, top - 24.0, 52.0, _floor_y - top + 24.0)
	var left := await excavate(shaft, 2400)
	t.note("shaft: %d solid cells left, he is at %s" % [left, n.global_position])
	if n.global_position.y < _floor_y - 12.0:
		return false
	_hall = Rect2(PLAY.lair_x - PLAY.hall_px, _floor_y - 64.0, PLAY.hall_px + 26.0, 64.0)
	left = await excavate(_hall, 6000)
	t.note("hall %s: %d solid cells left, he is at %s" % [_hall, left, n.global_position])
	return left < 200


## Holds the Dig beam on the nearest solid cell inside `rect` (pixels) until it is clear, walking along
## to keep it in reach. Returns how many solid cells are left.
func excavate(rect: Rect2, max_ticks: int) -> int:
	n.select_spell_id(&"dig")
	var target = null
	var left := 0
	for i in max_ticks:
		_top_up_mana(0.15, "digging")
		if i % 3 == 0:
			var r := _nearest_solid(rect, n.get_hand_pos())
			target = r[0]
			left = r[1]
			if target == null:
				break
		var hand: Vector2 = n.get_hand_pos()
		var reach := hand.distance_to(target) < 100.0
		var mv := Vector2.ZERO
		if not reach:
			mv.x = signf(target.x - n.global_position.x)
		n.script_input = {"cast": reach, "aim": target, "move": mv, "jump": mv.x != 0.0 and n.hit_wall}
		await t.ticks(1)
	n.script_input = {}
	await t.ticks(30)
	return _nearest_solid(rect, n.get_hand_pos())[1]


## [nearest solid diggable cell centre in rect (or null), count of such cells]
func _nearest_solid(rect: Rect2, from: Vector2) -> Array:
	var w := Sim.world
	var c0 := Sim.to_cell(rect.position)
	var c1 := Sim.to_cell(rect.end)
	var best = null
	var bd := INF
	var count := 0
	for y in range(c0.y, c1.y):
		for x in range(c0.x, c1.x):
			if w.is_solid(x, y) and SandWorld.mat_hardness(w.get_mat(x, y)) > 0.0:
				count += 1
				var p := Sim.cell_center(Vector2i(x, y))
				var d := p.distance_squared_to(from)
				if d < bd:
					bd = d
					best = p
	return [best, count]


## Build the heart with the Build spell, in the middle of the hall.
func _build_heart() -> bool:
	n.select_spell_id(&"build")
	var spot := _hall.get_center().x
	await walk_to(spot)
	_heart = await build_near(&"heart", n.global_position.x)
	return _heart != null and GameState.has_heart


func _refill() -> bool:
	if _heart == null:
		return false
	GameState.mana = 0.3
	await walk_to(_heart.global_position.x - 34.0)
	var hint: String = n.get_interact_hint()
	t.note("hint by the heart: '%s'; souls %.2f" % [hint, GameState.souls])
	var before := GameState.mana
	n.script_input = {"interact": true}
	await t.ticks(2)
	n.script_input = {}
	await t.ticks(2)
	t.note("mana %.2f -> %.2f, souls left %.2f" % [before, GameState.mana, GameState.souls])
	return GameState.mana > before + 0.05


## Climb out, walk to the nearest grave, bore down to the coffin, draw the corpse up with Harvest.
func _rob_grave() -> bool:
	var graves: Array = main.info.get("graves", [])
	var best = null
	for c in t.tree.get_nodes_in_group(&"grave_corpses"):
		if best == null or absf(c.global_position.x - PLAY.lair_x) < absf(best.global_position.x - PLAY.lair_x):
			best = c
	if best == null:
		t.note("no buried corpses (%d graves)" % graves.size())
		return false
	_corpse = best
	t.note("nearest buried corpse at %s" % _corpse.global_position)
	await climb_out(-1.0)
	var gx: float = _corpse.global_position.x
	await walk_to(gx + 40.0)
	t.note("standing at %s above the grave" % n.global_position)
	n.select_spell_id(&"dig")
	for i in 300:
		_top_up_mana(0.3, "grave dig")
		n.script_input = {"cast": true, "aim": _box_center(_corpse)}
		await t.ticks(1)
		if Sim.raycast_px(n.get_hand_pos(), _box_center(_corpse), false) == null:
			break
	n.script_input = {}
	await t.ticks(10)
	var got := await harvest(_corpse)
	t.note("harvested: %s, corpse at %s, he is at %s" % [got, _corpse.global_position, n.global_position])
	return got and _corpse.global_position.y < n.global_position.y + 20.0


func _build_chain() -> bool:
	if _heart == null:
		return false
	await go_down_shaft()
	await walk_to(_heart.global_position.x)
	n.select_spell_id(&"build")
	# machines go in slots along the hall, west to east, skipping the heart's spot
	var slots := []
	var x := _hall.position.x + 70.0 # not hard against the end wall: machines spit their outputs to both sides
	while x < _hall.end.x - 30.0:
		if absf(x - _heart.global_position.x) > 60.0:
			slots.append(x)
		x += 64.0
	t.note("machine slots %s (heart at %.0f)" % [slots, _heart.global_position.x])
	_grinder = await build_near(&"grinder", slots[0])
	_table = await build_near(&"stitching_table", slots[1])
	_altar = await build_near(&"altar", slots[2])
	t.note("grinder %s table %s altar %s" % [_grinder != null, _table != null, _altar != null])
	return _grinder != null and _table != null and _altar != null


## Bring the corpse down to the grinder with Harvest, then carry the gibs and bones to the table and
## the stitched body to the altar the same way (stand beside the machine and draw the thing to his feet).
func _feed_corpse() -> bool:
	if _grinder == null or _table == null:
		return false
	if not is_instance_valid(_corpse):
		return false
	# the corpse is up on the surface by the grave: drag it to the lip of the shaft in Harvest hops,
	# go down, and draw it down the shaft from the bottom
	if _corpse.global_position.y < _surface_y + 40.0:
		await climb_out(-1.0)
		await drag_to(_corpse, PLAY.lair_x - 40.0)
		t.note("corpse at the shaft's lip: %s" % _corpse.global_position)
		await walk_to(PLAY.lair_x)
		await t.ticks(120)
		if not await harvest(_corpse):
			_assist("corpse carried down the shaft by hand (Harvest can't draw it over the lip from below)")
			_carry(_corpse, n.global_position + Vector2(-20, -4))
			await t.ticks(30)
	var fed := await deliver(_corpse, _grinder)
	if not fed:
		_assist("corpse carried into the grinder by hand")
		_carry(_corpse, _grinder.global_position + Vector2(0, -20))
	var ok := await _wait(func(): return int(GameState.stats.get("bodies_ground", 0)) >= 1, 400)
	t.note("grinder ground the corpse: %s" % ok)
	if not ok:
		return false
	await t.ticks(30)
	for k in [&"item_gibs", &"item_gibs", &"item_bones"]:
		var it = _nearest_in_group(k, _grinder.global_position, 200.0)
		if it == null:
			continue
		if not await deliver(it, _table):
			_assist("%s carried to the table by hand" % k)
			if is_instance_valid(it):
				_carry(it, _table.global_position + Vector2(0, -10))
	ok = await _wait(func(): return int(GameState.stats.get("made_stitched_body", 0)) >= 1, 600)
	t.note("table stitched a body: %s" % ok)
	return ok


func _raise_ghoul() -> bool:
	var body = await _wait_node(&"item_stitched_body", 120)
	if body == null or _altar == null:
		return false
	if not await deliver(body, _altar):
		_assist("stitched body carried to the altar by hand")
		if is_instance_valid(body):
			_carry(body, _altar.global_position + Vector2(0, -10))
	await t.ticks(10)
	if GameState.souls < 1.0:
		_assist("souls set to 1 for the altar (had %.2f; the first soul has to come from somewhere)" % GameState.souls)
		GameState.souls = 1.0
	_top_up_mana(0.3, "altar touch")
	await walk_to(_altar.global_position.x - 30.0)
	t.note("altar hint: '%s'; he is at %s, altar box %s, nearest interactable %s" % [n.get_interact_hint(), n.global_position, _altar.get_box(), n.nearest_interactable()])
	n.script_input = {"interact": true}
	await t.ticks(2)
	n.script_input = {}
	var ok := await _wait(func(): return t.tree.get_nodes_in_group(&"lair_ghoul").size() >= 1, 400)
	t.note("ghouls: %d (altar hopper %s, touched %s, working %s, souls %.2f, mana %.2f)" % [t.tree.get_nodes_in_group(&"lair_ghoul").size(), _altar.hopper, _altar.touched, _altar.working, GameState.souls, GameState.mana])
	return ok


## Mark a block of the hall's end wall with Dig Here and watch the ghoul clear it.
func _ghoul_digs() -> bool:
	if _heart == null or t.tree.get_nodes_in_group(&"lair_ghoul").is_empty():
		return false
	var wall_x := _hall.position.x - 4.0
	await walk_to(wall_x + 60.0)
	n.select_spell_id(&"command_dig")
	var a := Vector2(wall_x - 70.0, _floor_y - 50.0)
	var z := Vector2(wall_x - 6.0, _floor_y - 2.0)
	var ra := Rect2i(Sim.to_cell(a), Sim.to_cell(z) - Sim.to_cell(a))
	var solid0 := _solid_cells(ra)
	n.script_input = {"aim": a, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": z, "cast": true}
	await t.ticks(3)
	n.script_input = {"aim": z}
	await t.ticks(1)
	n.script_input = {}
	var jobs: Array = Jobs.all_jobs().filter(func(j): return j.type == Jobs.DIG)
	t.note("dig jobs on the board: %d, solid cells in the mark %d" % [jobs.size(), solid0])
	n.select_spell_id(&"dig")
	await walk_to(_heart.global_position.x)
	var ok := await _wait(func(): return _solid_cells(ra) < solid0 * 0.75, 7200)
	t.note("solid cells left in the mark: %d of %d" % [_solid_cells(ra), solid0])
	return ok


## Walk into the forest, find a critter, draw it close with Harvest and burn it with the Dig beam.
func _kill_critter() -> bool:
	await climb_out()
	var f0 := GameState.fragments + GameState.souls * 5.0
	var killed := 0
	for attempt in 4:
		# hunt in the forest east of the shaft (west is the graveyard, full of holes now), ground critters first
		var c = null
		var bd := 1e9
		for x in t.tree.get_nodes_in_group(&"critters"):
			if not is_instance_valid(x) or x.is_queued_for_deletion() or x.global_position.x < PLAY.lair_x + 40.0:
				continue
			var d: float = x.global_position.distance_to(n.global_position) + (400.0 if x.get("kind") == &"crow" else 0.0)
			if d < bd:
				bd = d
				c = x
		if c == null:
			c = _nearest_in_group(&"critters", n.global_position, 2000.0)
		if c == null:
			t.note("no critters left")
			break
		t.note("hunting a %s at %s" % [c.get("kind"), c.global_position])
		await walk_to(c.global_position.x + (60.0 if c.global_position.x < n.global_position.x else -60.0))
		for i in 400:
			if not is_instance_valid(c) or c.dead or c.is_queued_for_deletion():
				break
			_top_up_mana(0.3, "hunt")
			var close: bool = n.get_hand_pos().distance_to(_box_center(c)) < 90.0
			n.select_spell_id(&"dig" if close else &"harvest")
			n.script_input = {"cast": true, "aim": _box_center(c)}
			await t.ticks(1)
		n.script_input = {}
		if not is_instance_valid(c) or c.dead or c.is_queued_for_deletion():
			killed += 1
			break
	await t.ticks(30)
	var orbs: int = t.tree.get_nodes_in_group(&"soul_orbs").size()
	t.note("soul orbs about: %d; carrying them home to the heart" % orbs)
	await walk_to(PLAY.lair_x)
	await _wait(func(): return GameState.fragments + GameState.souls * 5.0 > f0 + 0.01, 900)
	var f1 := GameState.fragments + GameState.souls * 5.0
	t.note("critters killed %d, fragments %.1f -> %.1f (souls %.2f)" % [killed, f0, f1, GameState.souls])
	return killed > 0 and f1 > f0


# ---------------------------------------------------------------- moves

func walk_to(x: float, max_ticks: int = PLAY.walk_ticks) -> bool:
	var last_x: float = n.global_position.x
	var jump_t := 0
	for i in max_ticks:
		var dx: float = x - n.global_position.x
		if absf(dx) < 6.0:
			break
		# stuck for half a second: hop (hold jump to levitate), then let go so the next hop is a fresh press
		if i % 30 == 29:
			if absf(n.global_position.x - last_x) < 4.0 and jump_t <= -6:
				jump_t = 24
			last_x = n.global_position.x
		var jump: bool = jump_t > 0 or (n.hit_wall and jump_t <= -6)
		jump_t -= 1
		n.script_input = {"move": Vector2(signf(dx), 0), "jump": jump, "aim": n.global_position + Vector2(signf(dx) * 60.0, -30.0)}
		await t.ticks(1)
	n.script_input = {}
	await t.ticks(10)
	var ok := absf(x - n.global_position.x) < 12.0
	if not ok:
		t.note("walk to x %.0f stopped at %s (wall %s, floor %s)" % [x, n.global_position, n.hit_wall, n.on_floor])
		var c := Sim.to_cell(n.global_position)
		for yy in range(c.y - 34, c.y + 4, 3):
			var row := ""
			for xx in range(c.x - 24, c.x + 24):
				row += "#" if Sim.world.is_solid(xx, yy) else ("@" if xx == c.x else ".")
			t.note("   " + row)
	return ok


## Back up the shaft to the surface: walk to it and levitate.
func climb_out(side: float = 1.0) -> void:
	if n.global_position.y < _surface_y + 24.0:
		t.note("already on the surface at %s" % n.global_position)
		return
	await walk_to(PLAY.lair_x)
	for attempt in 3:
		# levitate up the shaft, and once above the lip, drift over it
		for i in 240:
			var above: bool = n.global_position.y < _surface_y - 2.0
			n.script_input = {"jump": true, "move": Vector2(side if above else 0.0, 0)}
			await t.ticks(1)
			if n.on_floor and n.global_position.y < _surface_y + 12.0 and i > 10:
				break
		n.script_input = {}
		await t.ticks(70) # levitation recharges on the ground
		if n.global_position.y < _surface_y + 12.0:
			break
	await walk_to(PLAY.lair_x + 50.0 * side)
	t.note("climbed out to %s" % n.global_position)


func go_down_shaft() -> void:
	if n.global_position.y > _surface_y + 24.0:
		return
	await walk_to(PLAY.lair_x)
	await t.ticks(90)
	if _heart != null:
		await walk_to(_heart.global_position.x - 34.0)


## Cast Harvest on a thing until it reaches his hand and drops at his feet.
func harvest(thing, max_ticks: int = PLAY.harvest_ticks) -> bool:
	n.select_spell_id(&"harvest")
	var got := [false]
	var on_h := func(it): if it == thing: got[0] = true
	Events.body_harvested.connect(on_h)
	for i in max_ticks:
		if not is_instance_valid(thing):
			break
		_top_up_mana(0.2, "harvest")
		n.script_input = {"cast": true, "aim": _box_center(thing)}
		await t.ticks(1)
		if got[0]:
			break
	n.script_input = {}
	Events.body_harvested.disconnect(on_h)
	await t.ticks(20)
	if not got[0] and is_instance_valid(thing):
		t.note("harvest: %s at %s didn't come (he is at %s); pulled last tick: %s" % [thing.name, thing.global_position, n.global_position, n.get_spell(&"harvest").pulling.has(thing)])
	return got[0]


## Haul a thing along the surface in Harvest hops: walk ahead, draw it to his feet, repeat.
func drag_to(thing, x: float) -> void:
	for hop in 10:
		if not is_instance_valid(thing) or absf(thing.global_position.x - x) < 30.0:
			return
		var dir := signf(x - thing.global_position.x)
		var step: float = thing.global_position.x + dir * minf(120.0, absf(x - thing.global_position.x))
		await walk_to(step)
		if not await harvest(thing):
			await walk_to(thing.global_position.x + dir * 50.0)
			await harvest(thing)


## Stand beside a machine and draw a thing to his feet so it drops into the hopper.
func deliver(thing, machine) -> bool:
	if thing == null or machine == null or not is_instance_valid(thing):
		return false
	# stand just past the machine's middle, on the far side from the thing: he faces it while pulling,
	# and Harvest drops things 10 px in front of his feet, which is over the hopper
	var mx: float = machine.global_position.x
	if absf(thing.global_position.x - mx) > 140.0:
		await drag_to(thing, mx + signf(thing.global_position.x - mx) * 100.0)
	var side := -1.0 if thing.global_position.x < mx else 1.0
	await walk_to(mx - side * 12.0)
	var got := await harvest(thing)
	await t.ticks(20)
	var taken: bool = not is_instance_valid(thing) or thing.is_queued_for_deletion()
	if not taken:
		t.note("deliver: harvested %s; thing at %s, machine rect %s, he is at %s facing %d" % [got, thing.global_position, machine.get_rect(), n.global_position, n.facing])
	return taken


## Scan for a spot the Build spell's ghost shows green near x, aim there and cast.
func build_near(kind: StringName, x: float) -> Node2D:
	var build = n.get_spell(&"build")
	if build == null:
		return null
	if absf(n.global_position.x - x) > 120.0:
		await walk_to(x)
	n.select_spell_id(&"build")
	while build.current_kind() != kind and build.available_kinds().has(kind):
		build.alt_pressed()
	if build.current_kind() != kind:
		t.note("build: %s not on offer (%s)" % [kind, build.available_kinds()])
		return null
	_top_up_mana(1.0, "build " + String(kind))
	# sweep the ghost along the floor, nearest first, the way a player hovers until it turns green
	var offsets := [0]
	for k in range(8, 168, 8):
		offsets.append(-k)
		offsets.append(k)
	for dx in offsets:
		for up in [30.0, 56.0, 12.0]:
			var aim := Vector2(x + dx, _floor_y - up)
			n.script_input = {"aim": aim}
			await t.ticks(1)
			if not build.ghost_ok:
				continue
			n.script_input = {"aim": aim, "cast": true}
			await t.ticks(1)
			n.script_input = {"aim": aim}
			await t.ticks(2)
			n.script_input = {}
			var placed = build.last_placed
			if placed != null and placed.get("kind") == kind:
				t.note("built %s at %s" % [kind, placed.global_position])
				return placed
	var why: String = build.ghost_reason
	if main.info.has("lair_builder"):
		why += " / builder: " + main.info.lair_builder.why_not(kind, Vector2(x, _floor_y))
	t.note("build %s: no green spot near x %.0f (%s)" % [kind, x, why])
	n.script_input = {}
	return null


# ---------------------------------------------------------------- helpers

func _top_up_mana(at_least: float, why: String) -> void:
	if GameState.mana < at_least:
		if GameState.has_heart and GameState.souls > 0.0:
			GameState.refill_mana_from_heart()
		if GameState.mana < at_least:
			GameState.mana = GameState.max_mana
			if not assists.has("mana topped up (" + why + ")"):
				_assist("mana topped up (" + why + ")")


func _box_center(x: Node2D) -> Vector2:
	return x.get_box().get_center() if x.has_method("get_box") else x.global_position


func _nearest_in_group(g: StringName, at: Vector2, within: float) -> Node2D:
	var best: Node2D = null
	var bd := within
	for x in t.tree.get_nodes_in_group(g):
		if x is Node2D and is_instance_valid(x) and not x.is_queued_for_deletion():
			var d: float = (x as Node2D).global_position.distance_to(at)
			if d < bd:
				bd = d
				best = x
	return best


func _wait(cond: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		await t.ticks(1)
	return cond.call()


func _wait_node(g: StringName, max_ticks: int) -> Node2D:
	for i in max_ticks:
		var x := _nearest_in_group(g, _heart.global_position if _heart else n.global_position, 4000.0)
		if x != null:
			return x
		await t.ticks(1)
	return null


func _solid_cells(r: Rect2i) -> int:
	var counts := Sim.world.count_rect(r.position.x, r.position.y, r.size.x, r.size.y)
	var s := 0
	for m in counts:
		var k := SandWorld.mat_kind(m)
		if (k == 1 or k == 2) and SandWorld.mat_hardness(m) > 0.0:
			s += counts[m]
	return s
