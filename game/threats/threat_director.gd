extends Node
## Turns what the necromancer does into Suspicion and Hunger (autoload `Threats`).
## Owned by the Suspicion and Patrols department.
##
## Suspicion (forces from above) rises with: the heart's presence, noise, light leaking out at night,
## smoke venting to the surface, the stench of death, missing residents, robbed graves, sightings that
## reach town, attacks on towns, and towns that shrink too fast. It slowly decays while you stay quiet.
## Hunger (forces from below) rises with: the heart's presence, collecting human souls, burning souls,
## and digging deep. Nothing comes up from below yet; the meter moves and the thresholds are exposed.
##
## Every number Zach may want to change is in the const blocks below. The F3 overlay (debug_overlay.gd)
## shows each change and why, from `ledger`.
##
## Noise contract for other departments: emit Events.noise_made(at, loudness, source) about once a second
## while something is loud, not every tick. Loudness: 1 = a ghoul digging, 3 = a machine working,
## 10 = an explosion. `source` is a short word shown in the overlay ("grinder", "ghoul digging").

signal ledger_changed ## a new line in the ledger (the overlay listens)
signal noise_heard(surface_point: Vector2, audible: float, source: String) ## noise that reached the surface
signal sighting_logged(at: Vector2, witness: Node2D) ## someone saw something; patrols nearby come to look
signal alarm_raised(at: Vector2, reason: String, by: Node2D)
signal report_filed(witness: Node2D, what: String, amount: float)
signal report_stopped(what: String) ## the witness died before getting home
signal depth_tier_reached(tier: int, tier_name: String)
signal hunger_level_crossed(level: float) ## 25, 50, 75 on the way up
signal suspicion_level_crossed(level: float)
signal raid_started(at: Vector2)

# ================================================================ tuning (Zach: change numbers here)

## Suspicion basics. Meters run 0-100.
const SUSPICION := {
	"heart_per_min": 0.25, # the heart hums; people feel uneasy
	"decay_per_min": 0.6, # how fast Suspicion fades while you stay quiet
	"quiet_after_s": 30.0, # seconds with nothing suspicious before it starts fading
	"decay_floor_no_heart": 0.0, # fading stops here...
	"decay_floor_with_heart": 8.0, # ...or here while a heart exists (it never fully goes away)
	"missing_resident": 2.0, # any human dying is a missing person
	"settlement_attack": 3.0, # extra when the human died in or near a town
	"town_margin_px": 160.0, # how close to a town counts as "in town"
	"grave_robbed": 1.5, # once the robbed grave is noticed
	"grave_discover_s": 90.0, # how long until someone notices a robbed grave
	"alarm_in_earshot": 1.0, # a patrol shouting close enough to a town to be heard
	"alarm_earshot_px": 320.0,
	"levels": [25.0, 50.0, 75.0], # Eyegor's warnings, patrols searching, etc.
}

## Noise travels up through the ground. Every `half_cells` cells of packed earth halve it.
## Other materials count as more or less than one cell of earth (see MUFFLE).
const NOISE := {
	"per_loudness": 0.05, # Suspicion per point of loudness heard at the surface with people near
	"half_cells": 12.0, # cells of packed earth that halve the noise
	"columns": 5, # how many columns we sample; the noise takes the easiest way up
	"column_spacing_cells": 4,
	"listen_px": 420.0, # people (or a town) this close to where it surfaces hear it fully
	"nobody_near": 0.35, # share that still spreads as rumour when nobody is close
	"min_amount": 0.0005, # ignore anything smaller
}

## How much one cell of each material muffles noise and stench, compared with packed earth (1.0).
## Keys are SandWorld material names (M_STONE -> "STONE"). Anything not listed: static 1.0, powder 0.7,
## liquid 0.4, gas/fire/empty 0.
const MUFFLE := {
	"STONE": 2.5, "BEDROCK": 4.0, "BRICK": 2.0, "CLAY": 1.3, "EARTH": 1.0, "RUBBLE": 1.1,
	"DIRT": 0.7, "MUD": 0.8, "SAND": 0.6, "SNOW": 0.4, "GRASS": 0.5, "BONE": 1.2, "BONEBIT": 0.6,
	"WOOD": 0.6, "PLANK": 0.5, "LEAVES": 0.05, "ASH": 0.3, "FLESH": 0.5, "GIBS": 0.5,
}

## Light leaking to the sky at night.
const LIGHT := {
	"every_s": 2.0,
	"per_light_per_min": 1.2, # a full-strength light seen from the surface all night
	"per_glow_cell_per_min": 0.02, # fire, embers, ichor cells seen from the sky
	"rays_deg": [-50.0, -25.0, 0.0, 25.0, 50.0], # directions we test for an open path to the sky
	"day_factor": 0.0, # light doesn't matter by day
	"underground_px": 6.0, # lights at least this far below the surface count (towns' lights don't)
}

## Smoke drifting up out of the ground or off the lair.
const SMOKE := {
	"every_s": 2.0,
	"band_cells": 40, # how high above the surface we look for smoke
	"tile_cells": 32,
	"per_cell_per_min": 0.015,
	"steam_share": 0.2, # steam is less alarming than smoke
	"night_factor": 0.5, # harder to see smoke at night
}

## The stench of death. Things start to smell after `grace_s` and reach full strength over `ramp_s`.
const STENCH := {
	"every_s": 2.0,
	"grace_s": 60.0,
	"ramp_s": 120.0,
	"items": {"corpse": 1.0, "part": 0.35, "gibs": 0.25}, # strength per item kind (gibs: per amount)
	"cells": {"FLESH": 0.01, "GIBS": 0.008, "MIASMA": 0.02, "BLOOD": 0.002}, # strength per loose cell
	"tile_cells": 16,
	"min_strength": 0.08, # weaker sources are ignored and not drawn
	"half_cells": 25.0, # cells of earth that halve the smell (it seeps up better than noise)
	"per_strength_per_min": 0.5, # Suspicion per minute for one corpse-worth of smell at the surface
	"night_factor": 0.7,
	"scan_margin": 1.3, # cell scan covers this many heart radii around the heart
}

## People who saw something and are running home to tell.
const WITNESS := {
	"sighting_day": 6.0,
	"sighting_night": 2.5,
	"necromancer_mult": 1.5, # seeing the master himself is worse than seeing a ghoul
	"tunnel_mult": 0.6, # a suspicious hole is less alarming than a walking corpse
	"home_margin_px": 16.0, # within a town rect (grown by this) counts as home
	"timeout_s": 45.0, # a witness who never gets home spreads the word anyway after this long
	"repeat_s": 20.0, # the same witness seeing the same thing again within this is ignored
}

## Culling towns: a few deaths at a time stay under the radar; a town shrinking fast spikes Suspicion.
const CULL := {
	"window_s": 300.0, # deaths are counted over this many seconds
	"safe_share": 0.15, # losing up to this share of a town in the window is just "bad luck"
	"spike_per_share": 40.0, # Suspicion per whole town lost beyond the safe share
	"default_population": 12, # if World hasn't told us how many people live there
}

## Hunger (forces from below).
const HUNGER := {
	"heart_per_min": 0.15,
	"per_human_soul": 1.5,
	"soul_weights": {"fragments": 0.0, "rabbit": 0.0, "crow": 0.0, "deer": 0.0, "critter": 0.0, "minion": 0.25},
	"burn_per_soul": 0.3, # spending souls from the heart (mana refills, raising)
	"depth_every_s": 1.0,
	"depth_tiers": [ # cells below the surface; crossing one wakes something (once) and keeps it humming
		{"cells": 80, "name": "the deep soil", "once": 3.0, "per_min": 0.1},
		{"cells": 180, "name": "the old stone", "once": 6.0, "per_min": 0.25},
		{"cells": 320, "name": "the black below", "once": 12.0, "per_min": 0.5},
	],
	"levels": [25.0, 50.0, 75.0],
}

## Patrol sizing and timing (patrols.gd reads these).
const PATROL := {
	"first_after_s": 60.0, # the first patrol leaves town this long into the run
	"interval_s": 240.0, # time between patrols from one town at 0 Suspicion
	"interval_min_s": 75.0, # ...and at 100 Suspicion
	"night_interval_mult": 2.5, # night patrols are rarer
	"size_base": 1,
	"size_per_suspicion": 20.0, # one more farmer per this much Suspicion
	"size_max": 6,
	"max_out": 4, # patrols out at once, all towns together
	"kind": &"farmer",
	"duration_s": 150.0, # then they head home
	"home_timeout_s": 90.0, # members still out this long after heading home are removed
	"wander_px": 700.0, # length of a made-up route when World gave us none
	"hear_px": 260.0, # a patrol member hears a noise of audible 1.0 this far away
	"investigate_min": 0.2, # quieter than this at the surface and patrols ignore it
	"investigate_s": 12.0,
	"sight_px": 150.0, # stand-in farmers and our own fallback sight check
	"sighting_call_px": 500.0, # patrols this close to a sighting come to look
	"tunnel_check_every_s": 1.0,
	"tunnel_look_px": 60.0, # how far around a farmer we look for a hole in the ground
	"tunnel_depth_cells": 10, # a hole this deep below the natural surface is a tunnel mouth
	"flee_fear": 0.6, # at or above this fear a farmer runs home instead of fighting
	"fear_on_ally_death": 0.25,
	"flee_then_home_s": 3.0,
	"search_at": 50.0, # from here patrols head for the heart's surface position
	"search_jitter_px": [500.0, 60.0], # how far off their guess is at search_at and at 100
	"raid_at": 85.0, # from here a patrol becomes a raid (stub)
	"raid_extra": 2,
	"use_stand_ins": true, # if Bodies and Souls has no flesh_spawner, use our own stand-in farmers
}

const LEDGER := {"keep": 60, "merge_s": 6.0}

# ================================================================ state

var info: Dictionary = {} ## the run's info (World's keys); set by begin_run
var ledger: Array = [] ## newest last: {key, meter, delta, text, t, count}
var pending_reports: Array = [] ## {witness, what, at, t, amount}
var depth_tier := -1 ## index into HUNGER.depth_tiers, -1 = none yet
var max_depth_cells := 0.0
var patrols: Node = null ## patrols.gd registers itself here
var time := 0.0 ## seconds since begin_run (game time)
var auto_tick := true ## tests turn this off and drive time with simulate()

var _muffle := PackedFloat32Array()
var _stench_cell_mats := {} ## mat id -> strength per cell
var _glow_mats: Array[int] = []
var _m_smoke := 0
var _m_steam := 0
var _last_gain_t := -1000.0
var _timers := {}
var _item_seen := {} ## instance id -> time first seen
var _tile_seen := {} ## tile key -> time first smelly
var _stench: Array = [] ## last computed sources
var _graves: Array = [] ## {pos, base, robbed, found_at}
var _baseline := PackedInt32Array() ## natural surface per column, cells
var _deaths := {} ## town index -> Array of death times
var _report_seen := {} ## "witness:of" -> time
var _last_souls := 0.0


func _ready() -> void:
	_build_tables()
	Events.noise_made.connect(_on_noise)
	Events.sighting.connect(_on_sighting)
	Events.actor_died.connect(_on_actor_died)
	Events.soul_collected.connect(_on_soul_collected)
	Events.souls_changed.connect(_on_souls_changed)
	Events.dig_marked.connect(_on_dig_marked)
	Events.suspicion_changed.connect(_on_suspicion_changed)
	Events.hunger_changed.connect(_on_hunger_changed)


## Start (or restart) a run. install.gd calls this with World's info; tests call it with their own.
func begin_run(run_info: Dictionary = {}) -> void:
	reset()
	info = run_info
	_snapshot_baseline()


func reset() -> void:
	info = {}
	ledger.clear()
	pending_reports.clear()
	depth_tier = -1
	max_depth_cells = 0.0
	time = 0.0
	_last_gain_t = -1000.0
	_timers.clear()
	_item_seen.clear()
	_tile_seen.clear()
	_stench.clear()
	_graves.clear()
	_baseline = PackedInt32Array()
	_deaths.clear()
	_report_seen.clear()
	_last_souls = GameState.souls


func _physics_process(delta: float) -> void:
	if auto_tick:
		_tick(delta)


## Run the director for `seconds` of game time at once (tests use this instead of waiting).
func simulate(seconds: float, step: float = 0.25) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(step, left)
		_tick(dt)
		if patrols != null and is_instance_valid(patrols) and patrols.has_method("tick"):
			patrols.tick(dt)
		left -= dt


func _tick(dt: float) -> void:
	time += dt
	if _every("second", 1.0):
		_per_second()
	if _every("light", LIGHT.every_s):
		_scan_light()
	if _every("smoke", SMOKE.every_s):
		_scan_smoke()
	if _every("stench", STENCH.every_s):
		_scan_stench()
	if _every("graves", 5.0):
		_scan_graves()
	if _every("depth", HUNGER.depth_every_s):
		_scan_depth()
	if _every("reports", 0.5):
		_check_reports()


func _every(key: String, period: float) -> bool:
	var next: float = _timers.get(key, period)
	if time + 0.0001 >= next:
		_timers[key] = next + period
		return true
	_timers[key] = next
	return false


func _per_second() -> void:
	if GameState.has_heart:
		add_suspicion(SUSPICION.heart_per_min / 60.0, "heart", "the heart's presence", false)
		add_hunger(HUNGER.heart_per_min / 60.0, "heart", "the heart's presence")
	# fading while quiet
	var floor_v: float = SUSPICION.decay_floor_with_heart if GameState.has_heart else SUSPICION.decay_floor_no_heart
	if is_quiet() and GameState.suspicion > floor_v:
		var d := minf(SUSPICION.decay_per_min / 60.0, GameState.suspicion - floor_v)
		add_suspicion(-d, "decay", "fading: nothing suspicious for a while", false)
	# depth keeps Hunger humming
	if depth_tier >= 0:
		var tier: Dictionary = HUNGER.depth_tiers[depth_tier]
		add_hunger(float(tier.per_min) / 60.0, "depth", "the lair reaches %s" % tier.name)


# ================================================================ public API

## True when nothing suspicious has happened for SUSPICION.quiet_after_s.
func is_quiet() -> bool:
	return time - _last_gain_t >= SUSPICION.quiet_after_s


func seconds_until_quiet() -> float:
	return maxf(0.0, SUSPICION.quiet_after_s - (time - _last_gain_t))


## Raise (or lower) Suspicion and write why in the ledger. `counts_as_activity` false for trickles.
func add_suspicion(delta: float, key: String, why: String, counts_as_activity: bool = true) -> void:
	if absf(delta) < 0.000001:
		return
	GameState.add_suspicion(delta, key)
	if delta > 0.0 and counts_as_activity:
		_last_gain_t = time
	_log("suspicion", key, delta, why)


func add_hunger(delta: float, key: String, why: String) -> void:
	if absf(delta) < 0.000001:
		return
	GameState.add_hunger(delta, key)
	_log("hunger", key, delta, why)


## A note in the ledger with no change to either meter.
func note(key: String, why: String) -> void:
	_log("note", key, 0.0, why)


## Where the stench of death is coming from: [{pos, strength, surface_strength, kind}], pixels.
## `strength` is raw smell (one ripe corpse is about 1.0); `surface_strength` is what reaches the surface.
func stench_sources() -> Array:
	return _stench


## Patrol size for a Suspicion value.
func patrol_size(suspicion: float = -1.0) -> int:
	var s := GameState.suspicion if suspicion < 0.0 else suspicion
	return clampi(PATROL.size_base + floori(s / PATROL.size_per_suspicion), 1, PATROL.size_max)


## Seconds between patrols from one town for a Suspicion value, at the current time of day.
func patrol_interval(suspicion: float = -1.0) -> float:
	var s := GameState.suspicion if suspicion < 0.0 else suspicion
	var t := lerpf(PATROL.interval_s, PATROL.interval_min_s, clampf(s / 100.0, 0.0, 1.0))
	if GameState.is_night():
		t *= PATROL.night_interval_mult
	return t


## The surface right above the heart: where searching patrols are headed.
func heart_surface_pos() -> Vector2:
	if not GameState.has_heart:
		return Vector2.INF
	return Vector2(GameState.heart_pos.x, surface_at(GameState.heart_pos.x))


## The next depth threshold below the current one, or {} if all are passed.
func next_depth_tier() -> Dictionary:
	var tiers: Array = HUNGER.depth_tiers
	if depth_tier + 1 < tiers.size():
		return tiers[depth_tier + 1]
	return {}


## The natural surface height (pixels) at x: World's heightmap if given, else what the ground looked like
## when the run began.
func surface_at(x_px: float) -> float:
	var f = info.get("surface_at")
	if f is Callable and (f as Callable).is_valid():
		return float(f.call(x_px))
	var w := Sim.world
	if w == null:
		return float(info.get("surface_y_px", 0.0))
	if _baseline.size() != w.get_width():
		_snapshot_baseline()
	var cx := clampi(floori(x_px / Sim.CELL), 0, w.get_width() - 1)
	return float(_baseline[cx] * Sim.CELL)


## How much ground lies over a point, taking the easiest of a few nearby columns.
## Returns {weight (in cells of packed earth), cells (solid cells), what ("soil", "stone", "soil and stone")}.
func earth_above(at: Vector2) -> Dictionary:
	var w := Sim.world
	if w == null:
		return {"weight": 0.0, "cells": 0, "what": "air"}
	var c := Sim.to_cell(at)
	var best := {"weight": INF, "cells": 0, "stone": 0.0}
	var n: int = NOISE.columns
	var sp: int = NOISE.column_spacing_cells
	for i in n:
		var cx := c.x + (i - n / 2) * sp
		if cx < 0 or cx >= w.get_width():
			continue
		var cy := clampi(c.y, 0, w.get_height())
		var counts: Dictionary = w.count_rect(cx, 0, 1, cy)
		var weight := 0.0
		var cells := 0
		var stone := 0.0
		for m in counts:
			var k: float = _muffle[int(m)] * float(counts[m])
			weight += k
			if _muffle[int(m)] > 0.0:
				cells += int(counts[m])
			if _muffle[int(m)] >= 2.0:
				stone += k
		if weight < float(best.weight):
			best = {"weight": weight, "cells": cells, "stone": stone}
	if best.weight == INF:
		return {"weight": 0.0, "cells": 0, "what": "air"}
	var share: float = float(best.stone) / maxf(0.001, float(best.weight))
	var what := "soil"
	if best.cells == 0:
		what = "air"
	elif share > 0.6:
		what = "stone"
	elif share > 0.2:
		what = "soil and stone"
	return {"weight": best.weight, "cells": best.cells, "what": what}


## The share (0-1) of a sound that gets through `weight` cells of earth.
func noise_muffle(weight: float) -> float:
	return pow(0.5, weight / NOISE.half_cells)


## What a noise would cost, without applying it. {amount, audible, earth, near, surface_point}
func noise_cost(at: Vector2, loudness: float) -> Dictionary:
	var earth := earth_above(at)
	var muffle := noise_muffle(earth.weight)
	var surface_point := Vector2(at.x, minf(at.y, surface_at(at.x)))
	var near := _listener_near(surface_point)
	var amount := loudness * NOISE.per_loudness * muffle * (1.0 if near else NOISE.nobody_near)
	return {"amount": amount, "audible": loudness * muffle, "earth": earth, "near": near, "surface_point": surface_point}


## A patrol (or anyone) raises the alarm: other patrols react, and Suspicion jumps if a town can hear.
func raise_alarm(at: Vector2, reason: String, by: Node2D = null) -> void:
	alarm_raised.emit(at, reason, by)
	var t := town_near(at, SUSPICION.alarm_earshot_px)
	if t >= 0:
		add_suspicion(SUSPICION.alarm_in_earshot, "alarm", "alarm raised in earshot of %s: %s" % [_town_name(t), reason])
	else:
		note("alarm", "alarm raised out in the wilds: %s (no town heard it)" % reason)


## Someone saw something and will tell the town if they get home alive.
func start_report(witness: Node2D, what: String, at: Vector2, weight: float = 1.0) -> void:
	if witness == null or not is_instance_valid(witness):
		return
	var amount: float = (WITNESS.sighting_night if GameState.is_night() else WITNESS.sighting_day) * weight
	for r in pending_reports:
		if r.witness == witness:
			r.amount = maxf(r.amount, amount)
			return
	pending_reports.append({"witness": witness, "what": what, "at": at, "t": time, "amount": amount})
	note("report", "%s saw %s and is heading home to tell (+%.1f if they make it)" % [_who(witness), what, amount])


## Index of the town whose rect (grown by margin) contains the point, or -1.
func town_near(at: Vector2, margin: float = 0.0) -> int:
	var towns: Array = info.get("towns", [])
	for i in towns.size():
		var r: Rect2 = towns[i].get("rect", Rect2())
		if r.grow(margin).has_point(at):
			return i
	return -1


func suspicion_per_min() -> float:
	var sum := 0.0
	for e in ledger:
		if e.meter == "suspicion" and time - e.t <= 60.0:
			sum += e.delta
	return sum


# ================================================================ noise

func _on_noise(at: Vector2, loudness: float, source: String) -> void:
	if loudness <= 0.0:
		return
	var c := noise_cost(at, loudness)
	var earth: Dictionary = c.earth
	if c.audible > 0.0:
		noise_heard.emit(c.surface_point, c.audible, source)
	if c.amount < NOISE.min_amount:
		return
	var how := "at the surface" if earth.cells == 0 else "muffled by %d cells of %s" % [earth.cells, earth.what]
	if not c.near:
		how += ", nobody near to hear"
	add_suspicion(c.amount, "noise:" + source, "%s noise, %s" % [source, how])


func _listener_near(p: Vector2) -> bool:
	var r: float = NOISE.listen_px
	if town_near(p, r) >= 0:
		return true
	for h in get_tree().get_nodes_in_group("humans"):
		if h is Node2D and is_instance_valid(h) and not _is_dead(h):
			if (h as Node2D).global_position.distance_to(p) <= r:
				return true
	return false


# ================================================================ light

func _scan_light() -> void:
	var w := Sim.world
	if w == null:
		return
	var night := GameState.is_night()
	var factor: float = 1.0 if night else LIGHT.day_factor
	if factor <= 0.0:
		return
	var lit := 0.0
	var count := 0
	# lights placed by Art's lighting hook, the lair, the player...
	var lights: Array = get_tree().root.find_children("*", "PointLight2D", true, false)
	lights.append_array(get_tree().get_nodes_in_group("light_sources"))
	for l in lights:
		if not (l is Node2D) or not l.is_visible_in_tree():
			continue
		if l is PointLight2D and not (l as PointLight2D).enabled:
			continue
		var p: Vector2 = (l as Node2D).global_position
		if not _counts_as_lair(p):
			continue
		var exposure := sky_exposure(p)
		if exposure <= 0.0:
			continue
		var energy := 1.0
		if l is PointLight2D:
			energy = clampf((l as PointLight2D).energy, 0.2, 2.0)
		elif l.get("light_energy") != null:
			energy = float(l.get("light_energy"))
		lit += exposure * energy * LIGHT.per_light_per_min
		count += 1
	# glowing cells (fire, embers, ichor) in and around the lair
	var glow := 0.0
	for tile in _lair_tiles(STENCH.tile_cells):
		var counts: Dictionary = tile.counts
		var n := 0
		for m in _glow_mats:
			n += int(counts.get(m, 0))
		if n == 0:
			continue
		var e := sky_exposure(tile.center)
		glow += n * e
	lit += glow * LIGHT.per_glow_cell_per_min
	if lit > 0.0:
		var dt: float = LIGHT.every_s / 60.0
		var parts: Array[String] = []
		if count > 0:
			parts.append("%d light%s" % [count, "" if count == 1 else "s"])
		if glow > 0.0:
			parts.append("%d glowing cells" % roundi(glow))
		add_suspicion(lit * dt * factor, "light", "light leaking to the night sky (%s)" % ", ".join(parts))


## Share (0-1) of test rays from this point that reach open sky.
func sky_exposure(p: Vector2) -> float:
	var w := Sim.world
	if w == null:
		return 0.0
	var c := Sim.to_cell(p)
	if not w.in_bounds(c.x, c.y):
		return 0.0
	if w.is_solid(c.x, c.y):
		c.y -= 1
	var rays: Array = LIGHT.rays_deg
	var clear := 0
	for a in rays:
		var dx := int(tan(deg_to_rad(float(a))) * c.y)
		var to := Vector2i(clampi(c.x + dx, 0, w.get_width() - 1), 0)
		var hit: Vector2i = w.raycast(c, to, false)
		if hit.x < 0:
			clear += 1
	return float(clear) / float(maxi(1, rays.size()))


## Underground (below the natural surface), or within the heart's range. Towns' own lights don't count.
func _counts_as_lair(p: Vector2) -> bool:
	if town_near(p, 0.0) >= 0:
		return false
	if GameState.in_heart_range(p):
		return true
	return p.y > surface_at(p.x) + LIGHT.underground_px


# ================================================================ smoke

func _scan_smoke() -> void:
	var w := Sim.world
	if w == null:
		return
	var tile: int = SMOKE.tile_cells
	var band: int = SMOKE.band_cells
	var total := 0.0
	var x := 0
	while x < w.get_width():
		var mid_px := (x + tile * 0.5) * Sim.CELL
		var top := floori(surface_at(mid_px) / Sim.CELL) - band
		if town_near(Vector2(mid_px, (top + band) * Sim.CELL), 32.0) < 0:
			var counts: Dictionary = w.count_rect(x, maxi(0, top), tile, band)
			total += float(counts.get(_m_smoke, 0)) + float(counts.get(_m_steam, 0)) * SMOKE.steam_share
		x += tile
	if total <= 0.0:
		return
	var f: float = SMOKE.night_factor if GameState.is_night() else 1.0
	var amount: float = total * SMOKE.per_cell_per_min * SMOKE.every_s / 60.0 * f
	add_suspicion(amount, "smoke", "smoke rising over the surface (%d puffs)" % roundi(total))


# ================================================================ stench

func _scan_stench() -> void:
	var out: Array = []
	var grace: float = STENCH.grace_s
	var ramp: float = STENCH.ramp_s
	var alive := {}
	# loose items: corpses, parts, gibs
	var kinds: Dictionary = STENCH.items
	for kind in kinds:
		for it in get_tree().get_nodes_in_group("item_" + String(kind)):
			if not (it is Node2D) or not is_instance_valid(it) or it.is_queued_for_deletion():
				continue
			var id: int = it.get_instance_id()
			alive[id] = true
			if not _item_seen.has(id):
				_item_seen[id] = time
			var age: float = time - float(_item_seen[id])
			if age < grace:
				continue
			var ripe := clampf((age - grace) / ramp, 0.0, 1.0)
			var amt := 1
			if it.get("amount") != null:
				amt = maxi(1, int(it.get("amount")))
			var s: float = float(kinds[kind]) * ripe * (amt if kind == "gibs" else 1)
			out.append({"pos": (it as Node2D).global_position + Vector2(0, -6), "strength": s, "kind": String(kind)})
	for id in _item_seen.keys():
		if not alive.has(id):
			_item_seen.erase(id)
	# loose flesh, gibs, miasma and blood in and around the lair
	var seen_tiles := {}
	for tile in _lair_tiles(STENCH.tile_cells):
		var s := 0.0
		for m in _stench_cell_mats:
			s += float(tile.counts.get(m, 0)) * float(_stench_cell_mats[m])
		if s <= 0.0:
			continue
		var key: String = tile.key
		seen_tiles[key] = true
		if not _tile_seen.has(key):
			_tile_seen[key] = time
		var age: float = time - float(_tile_seen[key])
		if age < grace:
			continue
		s *= clampf((age - grace) / ramp, 0.0, 1.0)
		out.append({"pos": tile.center, "strength": s, "kind": "remains"})
	for key in _tile_seen.keys():
		if not seen_tiles.has(key):
			_tile_seen.erase(key)
	# how much reaches the surface
	var total := 0.0
	var kept: Array = []
	for src in out:
		if src.strength < STENCH.min_strength:
			continue
		var earth := earth_above(src.pos)
		src["surface_strength"] = src.strength * pow(0.5, float(earth.weight) / STENCH.half_cells)
		src["earth_cells"] = earth.cells
		total += src.surface_strength
		kept.append(src)
	_stench = kept
	if total <= 0.0:
		return
	var f: float = STENCH.night_factor if GameState.is_night() else 1.0
	var amount: float = total * STENCH.per_strength_per_min * STENCH.every_s / 60.0 * f
	add_suspicion(amount, "stench", "the stench of death (%d source%s, %.2f corpse-worth reaching the surface)" % [kept.size(), "" if kept.size() == 1 else "s", total])


## Tiles of the sand world in and around the heart's range, with their material counts.
func _lair_tiles(size: int) -> Array:
	var w := Sim.world
	if w == null or not GameState.has_heart:
		return []
	var r: float = GameState.heart_radius * STENCH.scan_margin
	var c0 := Sim.to_cell(GameState.heart_pos - Vector2(r, r))
	var c1 := Sim.to_cell(GameState.heart_pos + Vector2(r, r))
	var x0 := maxi(0, c0.x - posmod(c0.x, size))
	var y0 := maxi(0, c0.y - posmod(c0.y, size))
	var out: Array = []
	var y := y0
	while y <= mini(c1.y, w.get_height() - 1):
		var x := x0
		while x <= mini(c1.x, w.get_width() - 1):
			var counts: Dictionary = w.count_rect(x, y, size, size)
			if counts.size() > 1 or not counts.has(0):
				out.append({"key": "%d:%d" % [x, y], "counts": counts,
					"center": Sim.to_pixel(Vector2i(x, y)) + Vector2(size, size) * Sim.CELL * 0.5})
			x += size
		y += size
	return out


# ================================================================ bodies, graves, towns

func _on_actor_died(actor: Node2D, killer: Node2D, at: Vector2) -> void:
	# a witness silenced before getting home
	for r in pending_reports.duplicate():
		if r.witness == actor:
			pending_reports.erase(r)
			note("report", "%s was silenced before telling anyone about %s (report stopped)" % [_who(actor), r.what])
			report_stopped.emit(r.what)
	if not _is_human(actor):
		return
	var t := town_near(at, SUSPICION.town_margin_px)
	add_suspicion(SUSPICION.missing_resident, "missing", "%s went missing" % _who(actor))
	if t >= 0:
		if killer != null and is_instance_valid(killer) and not _is_human(killer):
			add_suspicion(SUSPICION.settlement_attack, "attack", "an attack on %s" % _town_name(t))
		_town_death(t)


## A town lost someone. Slow culling is fine; a town shrinking fast spikes Suspicion.
## Only the deaths beyond CULL.safe_share of the town (within CULL.window_s) cost extra.
func _town_death(t: int) -> void:
	var list: Array = _deaths.get(t, [])
	var pop := float(maxi(1, town_population(t)))
	var before := maxf(0.0, _recent(list) / pop - CULL.safe_share)
	list.append(time)
	_deaths[t] = list
	var after := maxf(0.0, _recent(list) / pop - CULL.safe_share)
	var spike: float = (after - before) * CULL.spike_per_share
	if spike > 0.0:
		add_suspicion(spike, "cull", "%s is shrinking fast (%d of %d gone in %d min)" % [
			_town_name(t), _recent(list), int(pop), roundi(CULL.window_s / 60.0)])


func _recent(list: Array) -> int:
	var n := 0
	for d in list:
		if time - float(d) <= CULL.window_s:
			n += 1
	return n


## How many people a town holds when full (World's homes' residents), for the culling rule.
func town_population(t: int) -> int:
	var towns: Array = info.get("towns", [])
	if t < 0 or t >= towns.size():
		return CULL.default_population
	var rect: Rect2 = towns[t].get("rect", Rect2())
	var homes: Array = towns[t].get("homes", [])
	var s := get_tree().get_first_node_in_group("settlements")
	if s != null and s.has_method("homes"):
		homes = []
		for h in s.homes():
			var hr: Rect2 = h.get("rect", Rect2())
			if rect.grow(8.0).intersects(hr):
				homes.append(h)
	var n := 0
	for h in homes:
		n += int(h.get("residents", 0))
	return n if n > 0 else CULL.default_population


func _scan_graves() -> void:
	var w := Sim.world
	if w == null:
		return
	var graves: Array = info.get("graves", [])
	if _graves.size() != graves.size():
		_graves.clear()
		for g in graves:
			_graves.append({"pos": g, "base": _grave_count(g), "robbed": false, "found_at": -1.0})
	for g in _graves:
		if g.robbed:
			if g.found_at >= 0.0 and time >= g.found_at:
				g.found_at = -1.0
				add_suspicion(SUSPICION.grave_robbed, "grave", "someone found a robbed grave")
			continue
		if g.base <= 0:
			g.base = _grave_count(g.pos)
			continue
		if _grave_count(g.pos) < g.base * 0.4:
			g.robbed = true
			g.found_at = time + SUSPICION.grave_discover_s
			note("grave", "a grave was robbed; someone will notice in about %d s" % roundi(SUSPICION.grave_discover_s))


func _grave_count(p: Vector2) -> int:
	var c := Sim.to_cell(p)
	var counts: Dictionary = Sim.world.count_rect(c.x - 8, c.y - 5, 16, 10)
	return int(counts.get(SandWorld.M_WOOD, 0)) + int(counts.get(SandWorld.M_BONE, 0)) + int(counts.get(SandWorld.M_FLESH, 0))


# ================================================================ sightings and reports

func _on_sighting(witness: Node2D, of: Node2D) -> void:
	if witness == null or not is_instance_valid(witness) or _is_dead(witness):
		return
	var key := "%d:%d" % [witness.get_instance_id(), of.get_instance_id() if of != null else 0]
	if _report_seen.has(key) and time - float(_report_seen[key]) < WITNESS.repeat_s:
		return
	_report_seen[key] = time
	var weight := 1.0
	var what := "something undead"
	if of != null and is_instance_valid(of):
		if of.is_in_group("necro"):
			weight = WITNESS.necromancer_mult
			what = "the necromancer"
		elif of.get("display_name") != null and String(of.get("display_name")) != "":
			what = "a " + String(of.get("display_name")).to_lower()
		elif of.is_in_group("minions"):
			what = "a walking corpse"
	var at := of.global_position if of != null and is_instance_valid(of) else witness.global_position
	start_report(witness, what, at, weight)
	sighting_logged.emit(at, witness)


func _check_reports() -> void:
	for r in pending_reports.duplicate():
		var wv = r.witness
		if wv == null or not is_instance_valid(wv) or _is_dead(wv):
			pending_reports.erase(r)
			note("report", "a witness to %s never made it home (report stopped)" % r.what)
			report_stopped.emit(r.what)
			continue
		var home := town_near((wv as Node2D).global_position, WITNESS.home_margin_px) >= 0
		var timed_out: bool = time - float(r.t) >= WITNESS.timeout_s
		if home or timed_out:
			pending_reports.erase(r)
			var how := "got home and told everyone about %s" % r.what if home else "spread word of %s" % r.what
			add_suspicion(r.amount, "report", "%s %s" % [_who(wv), how])
			report_filed.emit(wv, r.what, r.amount)


# ================================================================ hunger

func _on_soul_collected(amount: float, source: String, _at: Vector2) -> void:
	var weights: Dictionary = HUNGER.soul_weights
	var wgt: float = float(weights.get(source, 1.0))
	if wgt <= 0.0:
		return
	var label := "a %s's soul" % source if source != "" else "a soul"
	if source == "minion":
		label = "a minion's soul coming home"
	add_hunger(amount * HUNGER.per_human_soul * wgt, "soul", "collected %s" % label)


func _on_souls_changed(souls: float) -> void:
	var d := souls - _last_souls
	_last_souls = souls
	if d < -0.0001:
		add_hunger(-d * HUNGER.burn_per_soul, "burn", "burned %.2f soul%s" % [-d, "" if is_equal_approx(-d, 1.0) else "s"])


func _on_dig_marked(cells: Rect2i) -> void:
	_note_depth(Sim.to_pixel(Vector2i(cells.position.x + cells.size.x / 2, cells.end.y)))


func _scan_depth() -> void:
	for g in [&"necro", &"minions"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node2D and is_instance_valid(n):
				_note_depth((n as Node2D).global_position)


func _note_depth(p: Vector2) -> void:
	var d := (p.y - surface_at(p.x)) / Sim.CELL
	if d <= max_depth_cells:
		return
	max_depth_cells = d
	var tiers: Array = HUNGER.depth_tiers
	while depth_tier + 1 < tiers.size() and d >= float(tiers[depth_tier + 1].cells):
		depth_tier += 1
		var tier: Dictionary = tiers[depth_tier]
		add_hunger(float(tier.once), "depth", "dug down into %s (%d cells deep)" % [tier.name, int(tier.cells)])
		depth_tier_reached.emit(depth_tier, String(tier.name))


func _on_suspicion_changed(value: float, delta: float, _reason: String) -> void:
	for lv in SUSPICION.levels:
		if value >= lv and value - delta < lv:
			suspicion_level_crossed.emit(lv)


func _on_hunger_changed(value: float, delta: float, _reason: String) -> void:
	for lv in HUNGER.levels:
		if value >= lv and value - delta < lv:
			hunger_level_crossed.emit(lv)


# ================================================================ helpers

func _log(meter: String, key: String, delta: float, text: String) -> void:
	for i in range(ledger.size() - 1, maxi(-1, ledger.size() - 9), -1):
		var e: Dictionary = ledger[i]
		if e.key == key and e.meter == meter and time - e.t <= LEDGER.merge_s and signf(e.delta) == signf(delta):
			e.delta += delta
			e.text = text
			e.t = time
			e.count += 1
			ledger.remove_at(i)
			ledger.append(e)
			ledger_changed.emit()
			return
	ledger.append({"key": key, "meter": meter, "delta": delta, "text": text, "t": time, "count": 1})
	while ledger.size() > LEDGER.keep:
		ledger.pop_front()
	ledger_changed.emit()


func _is_human(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is Actor:
		return (n as Actor).faction == Actor.Faction.HUMAN
	return n.is_in_group("humans")


func _who(n: Node) -> String:
	if n != null and is_instance_valid(n):
		var dn = n.get("display_name")
		if dn != null and String(dn) != "":
			return "a " + String(dn).to_lower()
		if n.get("kind") != null:
			return "a " + String(n.get("kind"))
	return "someone"


func _town_name(t: int) -> String:
	var towns: Array = info.get("towns", [])
	if t >= 0 and t < towns.size():
		return String(towns[t].get("name", "town %d" % (t + 1)))
	return "a town"


func _snapshot_baseline() -> void:
	var w := Sim.world
	if w == null:
		_baseline = PackedInt32Array()
		return
	_baseline.resize(w.get_width())
	for x in w.get_width():
		_baseline[x] = w.surface_y(x, 0)


func _build_tables() -> void:
	_muffle.resize(64)
	for m in 64:
		var k := SandWorld.mat_kind(m)
		var v := 0.0
		match k:
			SandWorld.K_STATIC: v = 1.0
			SandWorld.K_POWDER: v = 0.7
			SandWorld.K_LIQUID: v = 0.4
		_muffle[m] = v
	for name in MUFFLE:
		var id := _mat(name)
		if id >= 0:
			_muffle[id] = float(MUFFLE[name])
	_stench_cell_mats.clear()
	for name in STENCH.cells:
		var id := _mat(name)
		if id >= 0:
			_stench_cell_mats[id] = float(STENCH.cells[name])
	_glow_mats = [SandWorld.M_FIRE, SandWorld.M_EMBER, SandWorld.M_ICHOR]
	_m_smoke = SandWorld.M_SMOKE
	_m_steam = SandWorld.M_STEAM


func _mat(name: String) -> int:
	if ClassDB.class_has_integer_constant("SandWorld", "M_" + name):
		return ClassDB.class_get_integer_constant("SandWorld", "M_" + name)
	return -1


func _is_dead(n: Object) -> bool:
	if n == null or not is_instance_valid(n):
		return true
	var d = n.get("dead")
	if d == null and n.has_method("is_dead"):
		d = n.call("is_dead")
	return d == true
