extends NecroSpell
## Dig: a channelled beam from his hand that wears the ground away, softest first. Ported from the
## proving ground: the beam runs out to its range, and where it meets the ground it grinds a circle big
## enough to walk through. Packed earth goes in a moment, stone takes a while, bedrock never goes.
## Grinding is loud: it reports noise for the Threats department to turn into Suspicion.

## Tuning. Cells are 2 px. Hardness per material lives in the sim (packed earth 1.2, stone 6, ...).
const DIG := {
	"cost": 0.1, # souls' worth of mana per second of channelling (about ten seconds on a full bar)
	"power": 0.17, # wear per tick at the beam's heart (packed earth goes in ~7 ticks, stone in ~35)
	"radius_px": 32.0, # carves a 64 px wide bore: a tunnel the necromancer can walk through
	"range_px": 116.0, # how far the beam reaches from his hand
	"noise_every": 20, # ticks between noise reports while grinding
	"noise_per_cell": 0.02, # loudness per cell removed in that window (stone counts 3x)
	"noise_max": 1.0,
	"loose_earth": 0.06, # share of removed earth thrown back as loose grave dirt
	"loose_stone": 0.35, # share of removed stone thrown back as rubble
	"hurt_per_tick": 0.6, # damage per tick to a living thing caught in the beam
	"dust_per_cell": 0.35, # FX: dust motes per removed cell
}

const DUST := {
	SandWorld.M_EARTH: Color("3a2a20"), SandWorld.M_DIRT: Color("4a3526"), SandWorld.M_STONE: Color("4a4852"),
	SandWorld.M_GRASS: Color("3d4a26"), SandWorld.M_WOOD: Color("4d3220"), SandWorld.M_BONE: Color("d8ccaa"),
	SandWorld.M_CLAY: Color("5e4436"), SandWorld.M_SAND: Color("8a7a55"), SandWorld.M_BRICK: Color("5b4a44"),
}

var beam_from := Vector2.ZERO
var beam_to := Vector2.ZERO
var beam_hit := false ## the beam is touching diggable ground
var beam_wall := false ## the beam is scraping bedrock
var removed_total := 0 ## cells removed since the game began (tests read this)
var _noise_cells := 0.0
var _noise_tick := 0
var _beam_on := false
var _t := 0


func _init() -> void:
	announce_channel = true
	id = &"dig"
	title = "Dig"
	color = TEAL


func cost_text() -> String:
	return NecroText.t("necro_cost_per_s", "{c} souls/s", {"c": "%.2f" % DIG.cost})


func on_deselect() -> void:
	super.on_deselect()
	_beam_on = false


func tick(aim: Vector2, held: bool, _pressed: bool, _released: bool) -> void:
	_t += 1
	channelling = false
	_beam_on = false
	if not held:
		return
	if not GameState.spend_mana(DIG.cost / 60.0):
		necro.warn_no_mana()
		return
	channelling = true
	_beam_on = true
	var hand: Vector2 = necro.get_hand_pos()
	var dir := (aim - hand)
	if dir.length() < 0.01:
		dir = Vector2(necro.facing, 0)
	dir = dir.normalized()
	beam_from = hand
	beam_to = hand + dir * DIG.range_px
	beam_hit = false
	beam_wall = false

	# a living thing in the way takes the beam instead of the ground
	var victim := _actor_on_beam(hand, beam_to)
	var ground = Sim.raycast_px(hand, beam_to)
	if ground != null:
		beam_to = ground
	if victim != null and hand.distance_to(victim.global_position) <= hand.distance_to(beam_to) + 8.0:
		beam_to = _closest_on_segment(hand, beam_to, victim.global_position - Vector2(0, victim.box_size.y * 0.5))
		victim.take_damage(DIG.hurt_per_tick, necro)
		_sparks(beam_to, dir, Color(0.55, 0.06, 0.08), 1)
		return
	if ground == null:
		return
	var mat := Sim.mat_at(beam_to)
	if SandWorld.mat_hardness(mat) <= 0.0:
		beam_wall = true
		if randf() < 0.6:
			_sparks(beam_to, dir, TEAL, 1, true)
		return
	beam_hit = true
	var removed := Sim.dig_px(beam_to, DIG.radius_px, DIG.power)
	_after_dig(removed, beam_to, dir)


## Throw back a little loose dirt and rubble, kick up dust, and report the noise.
func _after_dig(removed: Dictionary, at: Vector2, dir: Vector2) -> void:
	var n := 0
	for m in removed:
		var c: int = removed[m]
		n += c
		removed_total += c
		var loose := 0
		var loose_mat := 0
		if m == SandWorld.M_EARTH or m == SandWorld.M_GRASS or m == SandWorld.M_CLAY:
			loose = int(round(c * DIG.loose_earth + randf() * 0.5))
			loose_mat = SandWorld.M_DIRT
		elif m == SandWorld.M_STONE or m == SandWorld.M_BRICK:
			loose = int(round(c * DIG.loose_stone + randf() * 0.5))
			loose_mat = SandWorld.M_RUBBLE
		if loose > 0:
			Sim.spill_px(at - dir * 6.0, loose_mat, loose, -dir * 2.5 + Vector2(0, -1.0))
		_noise_cells += c * (3.0 if m == SandWorld.M_STONE else 1.0)
		var dust: Color = DUST.get(m, Color("4a3a30"))
		for k in mini(12, int(c * DIG.dust_per_cell) + (1 if randf() < 0.5 else 0)):
			var off := Vector2(randf_range(-6, 6), randf_range(-6, 6))
			emit_part(at + off, -dir * randf_range(0.6, 2.0) + Vector2(randf_range(-0.7, 0.7), randf_range(-1.0, 0.2)), dust, randi_range(14, 32))
	if n > 0 and randf() < 0.5:
		_sparks(at, dir, TEAL, 1, true)
	if _t - _noise_tick >= DIG.noise_every and _noise_cells > 0.0:
		var loud: float = minf(DIG.noise_max, _noise_cells * DIG.noise_per_cell)
		Events.noise_made.emit(at, loud, "dig")
		_noise_cells = 0.0
		_noise_tick = _t


func _actor_on_beam(a: Vector2, b: Vector2) -> Actor:
	var best: Actor = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Actor) or n == necro or n.dead:
			continue
		if not (n.is_living()):
			continue
		var box: Rect2 = n.get_box()
		var p := _closest_on_segment(a, b, box.get_center())
		if box.grow(2.0).has_point(p):
			var d := a.distance_to(p)
			if d < best_d:
				best_d = d
				best = n
	return best


static func _closest_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return a + ab * t


func _sparks(at: Vector2, dir: Vector2, col: Color, n: int, glow := false) -> void:
	for k in n:
		emit_part(at, -dir * randf_range(0.5, 1.5) + Vector2(randf_range(-1, 1), randf_range(-1.2, 0.4)), col, randi_range(10, 20), glow, 1.5)


func _draw_glow() -> void:
	super._draw_glow()
	if not _beam_on:
		return
	var flick := 0.75 + 0.25 * sin(_t * 0.9)
	glow_line(beam_from, beam_to, Color(TEAL_DIM, 0.35 * flick), 6.0)
	glow_line(beam_from, beam_to, Color(TEAL, 0.8 * flick), 2.0)
	glow_line(beam_from, beam_to, Color(0.85, 1.0, 0.95, 0.9), 1.0)
	glow_circle(beam_from, 3.0, Color(TEAL, 0.7))
	if beam_hit or beam_wall:
		glow_circle(beam_to, 5.0 + 2.0 * flick, Color(TEAL, 0.35))
		glow_circle(beam_to, 2.5, Color(0.85, 1.0, 0.95, 0.8))
