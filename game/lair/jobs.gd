extends Node
## The ghoul job board (autoload `Jobs`). Owned by the Lair and Factory department.
## Spells and machines post work here; ghouls claim it by priority.
## The method signatures below are the contract other departments use. Fill in the bodies freely.

## Job types the slice needs. A job is a Dictionary: {id, type, priority, cell or rect, item, target, claimed_by}
const DIG := &"dig"
const HAUL := &"haul" ## carry an item to a machine or stockpile
const OPERATE := &"operate" ## work a machine
const HARVEST := &"harvest" ## collect a body or part from the world

## Tuning for the board itself.
const BOARD := {
	"dig_chunk_cells": 14, # a big dig is split into columns this wide so several ghouls can share it
	"avoid_msec": 8000, # a ghoul that gave up on a job won't take it again for this long
	"distance_weight": 0.001, # among equal priorities, nearer jobs win (priority 1 beats 1000 px of walking)
}

var _next_id := 1
var _jobs := {} ## id -> job


func reset() -> void:
	_jobs.clear()
	_next_id = 1


func post(job: Dictionary) -> int:
	var id := _next_id
	_next_id += 1
	job["id"] = id
	job["claimed_by"] = null
	if not job.has("priority"):
		job["priority"] = 5
	_jobs[id] = job
	return id


## The best unclaimed job this worker may do, already claimed for it, or an empty Dictionary.
## Lower priority numbers win; among equals the job nearest the worker wins.
func claim_next(worker: Node, allowed_types: Array = []) -> Dictionary:
	_prune()
	var best: Dictionary = {}
	var best_score := INF
	var wpos := Vector2.ZERO
	var has_pos := worker is Node2D
	if has_pos:
		wpos = (worker as Node2D).global_position
	var now := Time.get_ticks_msec()
	for job in _jobs.values():
		if job.claimed_by != null:
			continue
		if not allowed_types.is_empty() and not allowed_types.has(job.type):
			continue
		var avoid: Dictionary = job.get("avoid", {})
		if avoid.has(worker.get_instance_id()) and int(avoid[worker.get_instance_id()]) > now:
			continue
		var score := float(job.priority)
		if has_pos:
			score += wpos.distance_to(job_pos(job)) * BOARD.distance_weight
		if score < best_score:
			best = job
			best_score = score
	if not best.is_empty():
		best.claimed_by = worker
	return best


func complete(id: int) -> void:
	_jobs.erase(id)


func release(id: int) -> void:
	if _jobs.has(id):
		_jobs[id].claimed_by = null


func cancel(id: int) -> void:
	_jobs.erase(id)


func all_jobs() -> Array:
	return _jobs.values()


func get_job(id: int) -> Dictionary:
	return _jobs.get(id, {})


func has_job(id: int) -> bool:
	return _jobs.has(id)


## A worker gave up on a job it couldn't reach: free it for others, and keep this worker off it a while.
func give_up(id: int, worker: Node) -> void:
	if not _jobs.has(id):
		return
	var job: Dictionary = _jobs[id]
	job.claimed_by = null
	var avoid: Dictionary = job.get("avoid", {})
	avoid[worker.get_instance_id()] = Time.get_ticks_msec() + int(BOARD.avoid_msec)
	job["avoid"] = avoid


## Where a job happens, in pixels (for picking the nearest).
func job_pos(job: Dictionary) -> Vector2:
	if job.has("pos"):
		return job.pos
	var item = job.get("item")
	if item is Node2D and is_instance_valid(item):
		return item.global_position
	if job.has("rect"):
		var r: Rect2i = job.rect
		return Sim.cell_center(r.position + r.size / 2)
	var target = job.get("target")
	if target is Node2D and is_instance_valid(target):
		return target.global_position
	return Vector2.ZERO


## The necromancer's Dig command: ghouls clear these cells.
func mark_dig(rect_cells: Rect2i) -> void:
	var w := int(BOARD.dig_chunk_cells)
	var x := rect_cells.position.x
	var end_x := rect_cells.end.x
	while x < end_x:
		var cw := mini(w, end_x - x)
		var chunk := Rect2i(x, rect_cells.position.y, cw, rect_cells.size.y)
		post({"type": DIG, "rect": chunk, "priority": 4})
		x += cw
	Events.dig_marked.emit(rect_cells)


## The designation spell paints a dug-out hollow as a stockpile for one kind of item.
func designate_stockpile(rect_cells: Rect2i, kind: StringName) -> void:
	Events.stockpile_designated.emit(rect_cells, kind)


## Drop jobs whose item or machine is gone, and free jobs held by workers that are gone.
func _prune() -> void:
	for id in _jobs.keys():
		var job: Dictionary = _jobs[id]
		if job.has("item") and job.item != null and not is_instance_valid(job.item):
			_jobs.erase(id)
			continue
		if job.has("target") and job.target != null and not is_instance_valid(job.target):
			_jobs.erase(id)
			continue
		if job.claimed_by != null and not is_instance_valid(job.claimed_by):
			job.claimed_by = null
