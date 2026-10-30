class_name LairBuilder
extends Node
## The lair builder hook (group `lair_builder`), used by the necromancer's build spell.
## A structure needs its whole pixel footprint dug out (air) with solid floor under it, and must sit inside
## the heart's range; only the heart itself may go anywhere (and only one at a time).

const BUILD := {
	"costs": {
		&"heart": {"mana": 0.5},
		&"grinder": {"mana": 0.2},
		&"stitching_table": {"mana": 0.2},
		&"altar": {"mana": 0.3},
		&"spike_trap": {"mana": 0.1},
	},
	"floor_fraction": 0.7, # share of the footprint's bottom row that must stand on solid ground
	"floor_give_px": 8.0, # dug floors are bumpy: bumps this high inside the footprint are levelled when it is
		# built, and a column counts as standing if ground is within this far below the footprint
	"overlap_margin_px": 2.0,
	"first_heart_free": true, # the first heart of each run costs nothing (playtest note 7)
	# Kinds the build menu offers from the start; anything else waits for GameState.unlock("build_<kind>").
	"unlocked_at_start": [&"heart", &"grinder", &"stitching_table", &"altar", &"spike_trap"],
}

var parent_layer: Node = null ## where placed structures go; defaults to this node's parent
var _free_heart_frame := -1


func _ready() -> void:
	add_to_group(&"lair_builder")


func kinds() -> Array[StringName]:
	return [&"heart", &"grinder", &"stitching_table", &"altar", &"spike_trap"]


## What building `kind` costs now, e.g. {"mana": 0.2}. The first heart of a run is free: `{}` until one has
## been built this run (GameState.stats.built_heart, which resets with the run). Also free on the very frame
## the first heart is placed, so a caller that reads the cost just after `place()` doesn't charge for it.
func cost(kind: StringName) -> Dictionary:
	if kind == &"heart" and BUILD.first_heart_free:
		var built := int(GameState.stats.get("built_heart", 0))
		if built == 0 or (built == 1 and _free_heart_frame == Engine.get_physics_frames()):
			return {}
	return BUILD.costs.get(kind, {})


## For Eyegor's build menu: {name, cost, footprint, unlocked, blurb}. Names and blurbs are Eyegor's lines
## `build_<kind>` and `desc_<kind>` (plain fallbacks in LairText).
func describe(kind: StringName) -> Dictionary:
	var k := String(kind)
	return {
		"name": LairText.t("build_" + k),
		"cost": cost(kind),
		"footprint": footprint(kind),
		"unlocked": kinds().has(kind) and (BUILD.unlocked_at_start.has(kind) or GameState.is_unlocked(StringName("build_" + k))),
		"blurb": LairText.t("desc_" + k),
	}


func footprint(kind: StringName) -> Vector2:
	match kind:
		&"heart":
			return Vector2(40, 48)
		&"spike_trap":
			return LairSpikeTrap.TRAP.footprint
	if LairMachine.MACHINES.has(kind):
		return LairMachine.MACHINES[kind].footprint
	return Vector2.ZERO


## `at` is the middle of the footprint's bottom edge (feet), in pixels.
func can_place(kind: StringName, at: Vector2) -> bool:
	return why_not(kind, at) == ""


## Empty string if placeable, else a short reason key (for hints and tests).
func why_not(kind: StringName, at: Vector2) -> String:
	if not kinds().has(kind):
		return "unknown"
	if kind == &"heart":
		if GameState.has_heart and is_instance_valid(GameState.heart):
			return "one_heart"
	elif not GameState.has_heart or not GameState.in_heart_range(at):
		return "out_of_range"
	var fp := footprint(kind)
	var w := Sim.world
	if w == null:
		return "no_world"
	var rect := Rect2(at.x - fp.x * 0.5, at.y - fp.y, fp.x, fp.y)
	var c := Sim.CELL
	var x0 := floori(rect.position.x / c)
	var x1 := floori((rect.end.x - 0.01) / c)
	var y0 := floori(rect.position.y / c)
	var y1 := floori((rect.end.y - 0.01) / c)
	var give := int(float(BUILD.floor_give_px) / c)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not w.in_bounds(x, y):
				return "not_dug"
			# Air, gas and liquid (blood the grinder splashes) never block. Ground does, except low bumps
			# in the bottom few rows, which the build levels.
			if not (w.is_empty(x, y) or w.is_liquid(x, y)):
				if y <= y1 - give or SandWorld.mat_hardness(w.get_mat(x, y)) <= 0.0:
					return "not_dug"
	var floor_y := y1 + 1
	var solid := 0
	for x in range(x0, x1 + 1):
		for y in range(y1 - give + 1, floor_y + give + 1):
			if w.is_solid(x, y):
				solid += 1
				break
	if float(solid) < float(x1 - x0 + 1) * float(BUILD.floor_fraction):
		return "no_floor"
	for s in get_tree().get_nodes_in_group(&"lair_structures"):
		if s is LairStructure and is_instance_valid(s) and not s.is_queued_for_deletion():
			if s.get_rect().grow(-float(BUILD.overlap_margin_px)).intersects(rect):
				return "overlap"
	return ""


## Builds it (the caller pays the cost). Null if refused.
func place(kind: StringName, at: Vector2) -> Node2D:
	if not can_place(kind, at):
		return null
	var s: LairStructure
	match kind:
		&"heart":
			s = NecroticHeart.new()
		&"spike_trap":
			s = LairSpikeTrap.new()
		_:
			s = LairMachine.make(kind)
	s.heart = GameState.heart if kind != &"heart" else null
	_level(kind, at)
	var parent := parent_layer if parent_layer != null else Lair.layer(get_tree(), "buildings", self)
	s.position = at
	parent.add_child(s)
	s.global_position = at
	if kind != &"heart":
		Events.machine_built.emit(s)
	if kind == &"heart" and int(GameState.stats.get("built_heart", 0)) == 0:
		_free_heart_frame = Engine.get_physics_frames()
	GameState.count("built_" + String(kind))
	return s


## Clears the low bumps of ground inside a footprint, so the structure stands on a level plot.
func _level(kind: StringName, at: Vector2) -> void:
	var fp := footprint(kind)
	var w := Sim.world
	if w == null:
		return
	var c := Sim.CELL
	var x0 := floori((at.x - fp.x * 0.5) / c)
	var x1 := floori((at.x + fp.x * 0.5 - 0.01) / c)
	var y0 := floori((at.y - fp.y) / c)
	var y1 := floori((at.y - 0.01) / c)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if w.is_solid(x, y):
				w.set_mat(x, y, SandWorld.M_EMPTY)
	w.wake_rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
