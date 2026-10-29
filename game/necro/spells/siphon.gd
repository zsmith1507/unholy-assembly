extends NecroSpell
## Siphon: drink mana straight out of the dead. Aim at a corpse, a part or a pool of blood and hold.
## Blood is the richest source; flesh gives less; whatever is drained crumbles to ash. A field refill
## that costs the factory its materials (design doc, Mana).
##
## Bodies and parts use the Siphonable hook: group "siphonable", siphon(amount) -> mana gained.
## Blood, flesh and gibs lying on the ground are drained straight from the sim, cell by cell.

const SIPHON := {
	"range_px": 110.0, # how far from his hand he can drain
	"radius_px": 22.0, # size of the draining spot around the aim point
	"node_rate": 0.25, # souls' worth asked of a siphonable body per second
	"cells_per_tick": 6, # sim cells drained per tick at most
	"mana_per_cell": { # souls' worth per cell drained
		SandWorld.M_BLOOD: 0.0025, # 400 cells of blood fill a fresh bar
		SandWorld.M_FLESH: 0.0008,
		SandWorld.M_GIBS: 0.0006,
		SandWorld.M_TALLOW: 0.0004,
		SandWorld.M_ICHOR: 0.0015,
	},
	"ash_chance": 0.35, # a drained cell of flesh or gibs leaves ash; drained blood mostly vanishes
	"blood_ash_chance": 0.08,
	"motes_per_cell": 1, # FX: glowing motes that fly to his hand
}

var drained_total := 0.0 ## mana gained since start (tests read this)
var _on := false
var _hand := Vector2.ZERO
var _spot := Vector2.ZERO
var _t := 0


func _init() -> void:
	announce_channel = true
	id = &"siphon"
	title = "Siphon"
	color = Color(0.75, 0.25, 0.35)


func cost_text() -> String:
	return NecroText.t("necro_siphon_cost", "gains mana")


func on_deselect() -> void:
	super.on_deselect()
	_on = false


func tick(aim: Vector2, held: bool, _pressed: bool, _released: bool) -> void:
	_t += 1
	channelling = false
	_on = false
	if not held:
		return
	channelling = true
	_on = true
	_hand = necro.get_hand_pos()
	var to := aim - _hand
	if to.length() > SIPHON.range_px:
		to = to.normalized() * SIPHON.range_px
	_spot = _hand + to
	if GameState.mana >= GameState.max_mana - 0.0001:
		return # full: nothing to drink into
	var gained := 0.0
	gained += _siphon_nodes()
	gained += _siphon_cells()
	if gained > 0.0:
		drained_total += gained
		GameState.add_mana(gained)


func _siphon_nodes() -> float:
	var got := 0.0
	var want: float = SIPHON.node_rate / 60.0
	for n in get_tree().get_nodes_in_group("siphonable"):
		if not (n is Node2D) or not n.has_method("siphon"):
			continue
		var p: Vector2 = n.get_box().get_center() if n.has_method("get_box") else n.global_position
		if p.distance_to(_spot) > SIPHON.radius_px + 8.0:
			continue
		var g: float = n.siphon(want)
		if g > 0.0:
			got += g
			for k in 2:
				_mote(p + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Color(0.85, 0.2, 0.3))
	return got


func _siphon_cells() -> float:
	var w := Sim.world
	if w == null:
		return 0.0
	var got := 0.0
	var c := Sim.to_cell(_spot)
	var r := int(SIPHON.radius_px / Sim.CELL)
	var table: Dictionary = SIPHON.mana_per_cell
	# gather candidate cells, richest first (blood before flesh)
	var found := []
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) > r * r:
				continue
			var m := w.get_mat(x, y)
			if table.has(m):
				found.append([table[m], x, y, m])
	if found.is_empty():
		return 0.0
	found.shuffle()
	found.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(SIPHON.cells_per_tick, found.size()):
		var f: Array = found[i]
		var m: int = f[3]
		var ash: float = SIPHON.blood_ash_chance if m == SandWorld.M_BLOOD or m == SandWorld.M_ICHOR else SIPHON.ash_chance
		w.set_mat(f[1], f[2], SandWorld.M_ASH if randf() < ash else SandWorld.M_EMPTY)
		got += f[0]
		for k in SIPHON.motes_per_cell:
			_mote(Sim.cell_center(Vector2i(f[1], f[2])), Color(0.85, 0.15, 0.22) if m == SandWorld.M_BLOOD else Color(0.6, 0.35, 0.35))
	w.wake_rect(c.x - r - 1, c.y - r - 1, r * 2 + 3, r * 2 + 3)
	return got


func _mote(p: Vector2, col: Color) -> void:
	emit_part(p, (_hand - p) / randf_range(14.0, 22.0), col, 20, true, 1.5)


func _physics_process(delta: float) -> void:
	for q in _parts:
		if q.glow and _on:
			q.v = q.v.lerp((_hand - q.p) * 0.1, 0.2)
			q.col = q.col.lerp(TEAL, 0.06)
	super._physics_process(delta)


func _draw_glow() -> void:
	super._draw_glow()
	if not _on:
		return
	var pulse := 0.6 + 0.4 * sin(_t * 0.25)
	_glow.draw_arc(_spot, SIPHON.radius_px, 0, TAU, 28, Color(color, 0.35 * pulse), 1.0)
	glow_circle(_spot, 3.0, Color(color, 0.5))
	glow_line(_hand, _spot, Color(color, 0.12), 1.0)
	glow_circle(_hand, 3.5 * pulse, Color(TEAL, 0.5))
