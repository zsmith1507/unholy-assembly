class_name Settlements
extends Node
## The `settlements` hook: the towns' homes and who lives in them.
## A home whose residents have all died decays (walls knocked out); after a while a new family moves in
## and the home is rebuilt. Threats and Bodies and Souls call resident_died() and home_at().

const HOMES := {
	"refill_hours": 36.0, ## game hours an emptied home stays a ruin before a new family arrives
	"refill_check_seconds": 2.0,
}

var gen: WorldGen
var towns: Array = [] ## pixel-space copy handed out through info.towns
var _homes := {} ## id -> {id, rect(px), rect_cells, residents, alive, emptied_at(hours elapsed), town}
var _hours_elapsed := 0.0
var _last_hour := -1.0
var _accum := 0.0


func _init(world_gen: WorldGen = null) -> void:
	gen = world_gen
	name = "Settlements"


func _ready() -> void:
	add_to_group("settlements")
	if gen != null and towns.is_empty():
		setup(gen)
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
			var rp := Rect2(Vector2(r.position) * c, Vector2(r.size) * c)
			var rec := {"id": h.id, "rect": rp, "rect_cells": r, "residents": h.residents, "alive": h.alive,
				"emptied_at": -1.0, "town": t.name}
			_homes[h.id] = rec
			homes_px.append(_public(rec))
		var tr: Rect2i = t.rect
		towns.append({"name": t.name, "side": t.side, "rect": Rect2(Vector2(tr.position) * c, Vector2(tr.size) * c),
			"homes": homes_px})


func _public(rec: Dictionary) -> Dictionary:
	return {"id": rec.id, "rect": rec.rect, "residents": rec.residents, "alive": rec.alive}


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
	_sync_towns(rec)
	if rec.alive == 0:
		rec.emptied_at = _hours_elapsed
		if Sim.world != null:
			gen.w = Sim.world
			gen.build_home(rec.rect_cells, true)


## The home containing this pixel position, or {} if none.
func home_at(pos: Vector2) -> Dictionary:
	for id in _homes:
		var rec: Dictionary = _homes[id]
		if (rec.rect as Rect2).grow(2.0).has_point(pos):
			return _public(rec)
	return {}


## Move the clock along without the Events signal (tests use this).
func advance_hours(h: float) -> void:
	_hours_elapsed += h
	_check_refill()


func _on_time(hour: float, _night: bool) -> void:
	if _last_hour >= 0.0:
		var d := hour - _last_hour
		if d < 0.0:
			d += 24.0
		_hours_elapsed += d
	_last_hour = hour
	_check_refill()


func _check_refill() -> void:
	for id in _homes:
		var rec: Dictionary = _homes[id]
		if rec.alive == 0 and rec.emptied_at >= 0.0 and _hours_elapsed - rec.emptied_at >= HOMES.refill_hours:
			rec.alive = rec.residents
			rec.emptied_at = -1.0
			if Sim.world != null:
				gen.w = Sim.world
				gen.build_home(rec.rect_cells, false)
			_sync_towns(rec)


func _sync_towns(rec: Dictionary) -> void:
	for t in towns:
		for h in t.homes:
			if h.id == rec.id:
				h.alive = rec.alive
