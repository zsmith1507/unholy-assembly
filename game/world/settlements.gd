class_name Settlements
extends Node
## The `settlements` hook: the towns' homes and who lives in them.
## When a home's last resident dies it runs down (holes in the roof and walls, the fire out), and after a
## while it is a ruin. Short-handed homes slowly take in newcomers, one at a time; when someone moves
## into a ruin it is rebuilt. Threats and Bodies and Souls call resident_died() and home_at();
## Bodies and Souls listens to resident_arrived to put a new human in the home.

signal home_emptied(home: Dictionary) ## the last resident died; the home starts to decay
signal resident_arrived(home: Dictionary) ## a newcomer moved in (home.alive already counts them)

const HOMES := {
	"ruin_hours": 12.0, ## game hours after emptying before a home is a ruin
	"newcomer_hours": 24.0, ## game hours between newcomers to a short-handed home (one game day = 12 real minutes)
}

var gen: WorldGen
var towns: Array = [] ## pixel-space copy handed out through info.towns
var _homes := {} ## id -> {id, rect(px), rect_cells, residents, alive, door_side, decay, emptied_at, short_since, town}
var _hours_elapsed := 0.0
var _last_hour := -1.0


func _init(world_gen: WorldGen = null) -> void:
	name = "Settlements"
	if world_gen != null:
		setup(world_gen)


func _ready() -> void:
	add_to_group("settlements")
	Events.time_of_day_changed.connect(_on_time)


func setup(world_gen: WorldGen) -> void:
	gen = world_gen
	towns.clear()
	_homes.clear()
	var c := float(Sim.CELL)
	for t in gen.towns:
		var homes_px: Array[Dictionary] = []
		for h in t.homes:
			var r: Rect2i = h.rect
			var rec := {"id": h.id, "rect": Rect2(Vector2(r.position) * c, Vector2(r.size) * c), "rect_cells": r,
				"residents": h.residents, "alive": h.alive, "door_side": h.door_side, "decay": 0,
				"emptied_at": -1.0, "short_since": -1.0, "town": t.name}
			_homes[h.id] = rec
			homes_px.append(_public(rec))
		var tr: Rect2i = t.rect
		var fr: Rect2i = t.get("fields", Rect2i())
		towns.append({"name": t.name, "side": t.side, "rect": Rect2(Vector2(tr.position) * c, Vector2(tr.size) * c),
			"homes": homes_px, "fields": Rect2(Vector2(fr.position) * c, Vector2(fr.size) * c)})


func _public(rec: Dictionary) -> Dictionary:
	return {"id": rec.id, "rect": rec.rect, "residents": rec.residents, "alive": rec.alive,
		"door": _door_px(rec), "town": rec.town}


## Where the door is, at floor level, in pixels (handy for walking residents home).
func _door_px(rec: Dictionary) -> Vector2:
	var r: Rect2 = rec.rect
	var x := r.end.x - Sim.CELL if rec.door_side > 0 else r.position.x + Sim.CELL
	return Vector2(x, r.end.y)


## Every home, with its current living count. Fresh dictionaries; changing them changes nothing.
func homes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _homes:
		out.append(_public(_homes[id]))
	return out


## A resident of this home died. When the last one dies the home starts to decay.
func resident_died(home_id: int) -> void:
	if not _homes.has(home_id):
		return
	var rec: Dictionary = _homes[home_id]
	if rec.alive <= 0:
		return
	rec.alive -= 1
	if rec.short_since < 0.0:
		rec.short_since = _hours_elapsed
	_sync_towns(rec)
	if rec.alive == 0:
		rec.emptied_at = _hours_elapsed
		_rebuild(rec, 1)
		home_emptied.emit(_public(rec))


## The home containing this pixel position, or {} if none.
func home_at(pos: Vector2) -> Dictionary:
	for id in _homes:
		var rec: Dictionary = _homes[id]
		if (rec.rect as Rect2).grow(2.0).has_point(pos):
			return _public(rec)
	return {}


## 0 lived in, 1 emptied and running down, 2 a ruin.
func decay_of(home_id: int) -> int:
	return _homes[home_id].decay if _homes.has(home_id) else 0


## Move the clock along without the Events signal (tests use this).
func advance_hours(h: float) -> void:
	_hours_elapsed += h
	_check()


func _on_time(hour: float, _night: bool) -> void:
	if _last_hour >= 0.0:
		var d := hour - _last_hour
		if d < 0.0:
			d += 24.0
		_hours_elapsed += d
	_last_hour = hour
	_check()


func _check() -> void:
	for id in _homes:
		var rec: Dictionary = _homes[id]
		if rec.alive == 0 and rec.decay == 1 and _hours_elapsed - rec.emptied_at >= HOMES.ruin_hours:
			_rebuild(rec, 2)
		while rec.short_since >= 0.0 and _hours_elapsed - rec.short_since >= HOMES.newcomer_hours:
			rec.short_since += HOMES.newcomer_hours
			rec.alive += 1
			if rec.decay > 0:
				_rebuild(rec, 0)
				rec.emptied_at = -1.0
			if rec.alive >= rec.residents:
				rec.alive = rec.residents
				rec.short_since = -1.0
			_sync_towns(rec)
			resident_arrived.emit(_public(rec))


func _rebuild(rec: Dictionary, decay: int) -> void:
	rec.decay = decay
	if Sim.world == null or gen == null:
		return
	gen.w = Sim.world
	gen.build_home(rec.rect_cells, decay, rec.door_side)
	if is_inside_tree():
		for s in get_tree().get_nodes_in_group("world_scenery"):
			s.refresh()


func _sync_towns(rec: Dictionary) -> void:
	for t in towns:
		for h in t.homes:
			if h.id == rec.id:
				h.alive = rec.alive
