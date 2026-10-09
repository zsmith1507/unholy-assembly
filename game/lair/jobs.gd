extends Node
## The ghoul job board (autoload `Jobs`). Owned by the Lair and Factory department.
## Spells and machines post work here; ghouls claim it by priority.
## The method signatures below are the contract other departments use. Fill in the bodies freely.

## Job types the slice needs. A job is a Dictionary: {id, type, priority, cell or rect, item, target, claimed_by}
const DIG := &"dig"
const HAUL := &"haul" ## carry an item to a machine or stockpile
const OPERATE := &"operate" ## work a machine
const HARVEST := &"harvest" ## collect a body or part from the world

var _next_id := 1
var _jobs := {} ## id -> job


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
func claim_next(worker: Node, allowed_types: Array = []) -> Dictionary:
	var best: Dictionary = {}
	for job in _jobs.values():
		if job.claimed_by != null:
			continue
		if not allowed_types.is_empty() and not allowed_types.has(job.type):
			continue
		if best.is_empty() or job.priority < best.priority:
			best = job
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


## The necromancer's Dig command: ghouls clear these cells.
func mark_dig(rect_cells: Rect2i) -> void:
	post({"type": DIG, "rect": rect_cells, "priority": 4})
	Events.dig_marked.emit(rect_cells)


## The designation spell paints a dug-out hollow as a stockpile for one kind of item.
func designate_stockpile(rect_cells: Rect2i, kind: StringName) -> void:
	Events.stockpile_designated.emit(rect_cells, kind)
