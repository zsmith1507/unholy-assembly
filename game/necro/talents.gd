class_name NecroTalents
extends Node
## The necromancer's talent tree (passive upgrades) and skill tree (abilities). One per run: a child of
## the necromancer, in group "talents". Eyegor draws the screen; every department reads upgrades with
## get_tree().get_first_node_in_group("talents").rank(&"id").
##
## Points come from real progress (POINTS below). Learning a rank applies at once: the spells read their
## multipliers from effect() every tick, and max mana, spirit vision and corpse sense are pushed out here.

## Where skill points come from. Change these to make upgrades come faster or slower.
const POINTS := {
	"start": 1, # one point to spend straight away, so the screen is never empty at the start
	"souls_per_point": 3.0, # every 3 souls that reach the heart
	"first_heart": 1, # raising the first necrotic heart
	"first_minion": 1, # raising the first ghoul
	"minions_per_point": 4, # and one more for every 4 raised after that
	"humans_per_point": 2, # every 2 humans killed
	"first_grave": 1, # the first body drawn up out of a grave
}

## What each rank does. "per_rank" values are added per rank; the spells and the shroud read them.
const FX := {
	"dig_speed": {"power": 0.5}, # +50% wear per rank
	"dig_efficiency": {"cost": -0.2}, # -20% mana per second per rank
	"dig_radius": {"radius_px": 4.0}, # +4 px to the bore's radius per rank
	"mana_well": {"max_mana": 0.5}, # +half a soul of mana bar per rank
	"mana_flow": {"regen": 0.5}, # +50% mana regeneration per rank
	"grave_wind": {"range": 0.2, "pull": 0.15}, # Harvest reaches 20% farther and pulls 15% harder per rank
	"knife_edge": {"damage": 0.5}, # +50% knife damage per rank
	"spirit_vision": {"reveal_cells": 10.0}, # the shroud lifts 10 cells farther around him per rank
	"corpse_sense": {"sense_px": 320.0}, # buried bodies glow as red spirit gas this far away per rank
}

## The two trees. pos is the node's place on Eyegor's grid (column, row); requires lists ids that need a rank first.
const TREES := [
	{"id": &"talents", "name": "Talents", "kind": "talent", "nodes": [
		{"id": &"dig_speed", "name": "Hungry Earth", "desc": "Dig wears ground away 50% faster per rank.", "cost": 1, "max_rank": 3, "requires": [], "pos": Vector2i(0, 0)},
		{"id": &"dig_efficiency", "name": "Thrifty Grave-Wind", "desc": "Dig costs 20% less mana per rank.", "cost": 1, "max_rank": 3, "requires": [], "pos": Vector2i(1, 0)},
		{"id": &"dig_radius", "name": "Wide Bore", "desc": "Dig carves a wider tunnel (+4 px radius per rank).", "cost": 1, "max_rank": 3, "requires": [&"dig_speed"], "pos": Vector2i(0, 1)},
		{"id": &"mana_well", "name": "Deeper Well", "desc": "The mana bar holds half a soul more per rank.", "cost": 1, "max_rank": 3, "requires": [], "pos": Vector2i(2, 0)},
		{"id": &"mana_flow", "name": "Seeping Power", "desc": "Mana comes back 50% faster per rank.", "cost": 1, "max_rank": 3, "requires": [&"mana_well"], "pos": Vector2i(2, 1)},
		{"id": &"grave_wind", "name": "Long Reach", "desc": "Harvest reaches 20% farther and pulls harder per rank.", "cost": 1, "max_rank": 3, "requires": [], "pos": Vector2i(3, 0)},
		{"id": &"knife_edge", "name": "Wicked Edge", "desc": "The knife cuts 50% deeper per rank.", "cost": 1, "max_rank": 3, "requires": [], "pos": Vector2i(4, 0)},
	]},
	{"id": &"skills", "name": "Skills", "kind": "skill", "nodes": [
		{"id": &"spirit_vision", "name": "Spirit Vision", "desc": "See farther through the dark earth around you.", "cost": 1, "max_rank": 3, "requires": [], "pos": Vector2i(0, 0)},
		{"id": &"corpse_sense", "name": "Corpse Sense", "desc": "Buried bodies glow as red spirit gas through the earth.", "cost": 2, "max_rank": 2, "requires": [&"spirit_vision"], "pos": Vector2i(0, 1)},
		{"id": &"soul_pull", "name": "Soul Pull", "desc": "Coming later: draw loose souls to you from afar.", "cost": 2, "max_rank": 1, "requires": [&"corpse_sense"], "pos": Vector2i(0, 2), "locked": true},
	]},
]

var _ranks := {} ## id -> rank
var _points := 0
var _souls_seen := 0.0
var _minions := 0
var _humans := 0
var _got := {} ## one-off point sources already paid
var _mana_added := 0.0 ## max mana this node has added to GameState (so a reset doesn't double it)
var _base_reveal := -1 ## the shroud's own reveal radius, read the first time we touch it
var _shroud_set := false


func _ready() -> void:
	name = "Talents"
	add_to_group("talents")
	Events.soul_collected.connect(_on_soul)
	Events.heart_placed.connect(_on_heart)
	Events.minion_raised.connect(_on_minion)
	Events.human_killed.connect(_on_human)
	Events.body_harvested.connect(_on_harvested)
	reset()


## Back to a fresh run: no ranks, the starting points.
func reset() -> void:
	# take back the bar we added, unless GameState.reset() already put it back to the start
	if _mana_added != 0.0 and GameState.max_mana - _mana_added >= float(GameState.ECON.start_max_mana) - 0.001:
		GameState.max_mana = maxf(0.1, GameState.max_mana - _mana_added)
		GameState.mana = minf(GameState.mana, GameState.max_mana)
	_mana_added = 0.0
	_ranks = {}
	_souls_seen = 0.0
	_minions = 0
	_humans = 0
	_got = {}
	_set_points(POINTS.start)
	_apply_shroud()


# ---------------------------------------------------------------- the contract

func trees() -> Array:
	var out := []
	for tr in TREES:
		var nodes := []
		for nd in tr.nodes:
			var d: Dictionary = nd.duplicate()
			d["name"] = NecroText.t("talent_" + String(nd.id), nd.name)
			d["desc"] = NecroText.t("talent_" + String(nd.id) + "_desc", nd.desc)
			d["rank"] = rank(nd.id)
			d["can_learn"] = can_learn(nd.id)
			nodes.append(d)
		out.append({"id": tr.id, "name": NecroText.t("talents_tree_" + String(tr.id), tr.name), "kind": tr.kind, "nodes": nodes})
	return out


func points() -> int:
	return _points


func rank(id: StringName) -> int:
	return int(_ranks.get(id, 0))


func can_learn(id: StringName) -> bool:
	var nd := _node(id)
	if nd.is_empty() or nd.get("locked", false):
		return false
	if rank(id) >= int(nd.max_rank) or _points < int(nd.cost):
		return false
	for req in nd.requires:
		if rank(req) <= 0:
			return false
	return true


func learn(id: StringName) -> bool:
	if not can_learn(id):
		return false
	var nd := _node(id)
	_ranks[id] = rank(id) + 1
	_set_points(_points - int(nd.cost))
	_apply(id)
	Events.talent_learned.emit(id, rank(id))
	return true


## rank x the per-rank value of one effect: effect(&"dig_speed", "power") is 1.0 at rank 2.
func effect(id: StringName, key: String) -> float:
	var fx: Dictionary = FX.get(String(id), {})
	return float(fx.get(key, 0.0)) * rank(id)


## Points from outside (tests, debug console, a future quest reward).
func grant_points(n: int) -> void:
	_set_points(_points + n)


# ---------------------------------------------------------------- applying ranks

func _apply(id: StringName) -> void:
	match id:
		&"mana_well":
			var add: float = FX.mana_well.max_mana
			_mana_added += add
			GameState.max_mana += add
			GameState.add_mana(add) # the new room comes full
		&"spirit_vision", &"corpse_sense":
			_apply_shroud()


func _apply_shroud() -> void:
	if not is_inside_tree():
		return
	var shroud := get_tree().get_first_node_in_group("shroud")
	if shroud == null:
		return
	if "reveal_radius_cells" in shroud:
		if _base_reveal < 0:
			_base_reveal = int(shroud.reveal_radius_cells)
		var want := _base_reveal + int(effect(&"spirit_vision", "reveal_cells"))
		if int(shroud.reveal_radius_cells) != want:
			shroud.reveal_radius_cells = want
	if "corpse_sense_radius_px" in shroud:
		var sense := effect(&"corpse_sense", "sense_px")
		if absf(float(shroud.corpse_sense_radius_px) - sense) > 0.5 and (sense > 0.0 or _shroud_set):
			shroud.corpse_sense_radius_px = sense
	_shroud_set = true


var _tick := 0


func _physics_process(delta: float) -> void:
	_tick += 1
	# the shroud may arrive after us (or be rebuilt); keep it in step once a second
	if _tick % 60 == 0 and (rank(&"spirit_vision") > 0 or rank(&"corpse_sense") > 0):
		_apply_shroud()
	# Seeping Power: extra regeneration on top of GameState's, under the same rule (waits after a spell)
	var flow := effect(&"mana_flow", "regen")
	if flow > 0.0 and GameState.mana < GameState.max_mana:
		var since = GameState.get("_since_spend")
		if since == null or float(since) >= float(GameState.ECON.mana_regen_delay):
			GameState.add_mana(float(GameState.ECON.mana_regen_per_sec) * flow * delta)


# ---------------------------------------------------------------- point sources

func _on_soul(amount: float, _source: String, _at: Vector2) -> void:
	_souls_seen += amount
	var per: float = POINTS.souls_per_point
	while _souls_seen >= per:
		_souls_seen -= per
		grant_points(1)


func _on_heart(_at: Vector2, _radius: float) -> void:
	_once(&"first_heart")


func _on_minion(_m: Node2D) -> void:
	_minions += 1
	if _minions == 1:
		_once(&"first_minion")
	elif (_minions - 1) % int(POINTS.minions_per_point) == 0:
		grant_points(1)


func _on_human(_a: Node2D, _seen: bool) -> void:
	_humans += 1
	if _humans % int(POINTS.humans_per_point) == 0:
		grant_points(1)


func _on_harvested(item: Node2D) -> void:
	if item == null or not is_instance_valid(item) or _got.has(&"first_grave"):
		return
	var fresh = item.get("fresh")
	if fresh == null and item.get("data") is Dictionary:
		fresh = item.data.get("fresh")
	if fresh == false:
		_once(&"first_grave")


func _once(key: StringName) -> void:
	if _got.has(key):
		return
	_got[key] = true
	grant_points(int(POINTS.get(String(key), 0)))


func _set_points(p: int) -> void:
	if p == _points:
		return
	_points = p
	Events.skill_points_changed.emit(_points)


func _node(id: StringName) -> Dictionary:
	for tr in TREES:
		for nd in tr.nodes:
			if nd.id == id:
				return nd
	return {}
