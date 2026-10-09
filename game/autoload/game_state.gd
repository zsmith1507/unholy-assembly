extends Node
## The run's shared numbers: souls, mana, the two meters, the heart, the clock.
## Everyone reads these; change them only through the methods so Events fire.

const InputSetup := preload("res://autoload/input_setup.gd")

## Tuning. Change feel here, not in callers.
const ECON := {
	"fragments_per_soul": 5.0, # critters give fragments; this many make one soul orb
	"start_souls": 1.0, # one soul in the heart at the start: enough for the first refill
	"start_max_mana": 1.0, # the mana bar holds one soul's worth at first
	"start_mana": 1.0,
}

var souls: float = 0.0 ## souls stored in the necrotic heart
var fragments: float = 0.0 ## soul fragments waiting to combine
var mana: float = 1.0 ## in souls' worth
var max_mana: float = 1.0
var suspicion: float = 0.0 ## 0-100, forces from above
var hunger: float = 0.0 ## 0-100, forces from below

var has_heart := false
var heart: Node2D = null
var heart_pos := Vector2.ZERO
var heart_radius := 0.0 ## in game pixels

var day := 1
var hour := 20.0 ## 0-24; the run opens at dusk
var unlocks := {} ## id -> true
var stats := {} ## counters for milestones: "humans_killed", "minions_raised", ...


func _ready() -> void:
	InputSetup.setup()
	reset()


func reset() -> void:
	souls = 0.0
	fragments = 0.0
	mana = ECON.start_mana
	max_mana = ECON.start_max_mana
	suspicion = 0.0
	hunger = 0.0
	has_heart = false
	heart = null
	heart_pos = Vector2.ZERO
	heart_radius = 0.0
	day = 1
	hour = 20.0
	unlocks = {}
	stats = {}


# ---------------------------------------------------------------- souls

## A full soul (or part of one) reaches the heart.
func add_souls(amount: float, source: String = "", at: Vector2 = Vector2.ZERO) -> void:
	souls += amount
	Events.soul_collected.emit(amount, source, at)
	Events.souls_changed.emit(souls)


## Critter and farm-animal fragments. Enough of them combine into a soul.
func add_fragments(amount: float, source: String = "", at: Vector2 = Vector2.ZERO) -> void:
	fragments += amount
	while fragments >= ECON.fragments_per_soul:
		fragments -= ECON.fragments_per_soul
		add_souls(1.0, "fragments", at)
	Events.souls_changed.emit(souls)


func spend_souls(amount: float) -> bool:
	if souls + 0.0001 < amount:
		return false
	souls -= amount
	Events.souls_changed.emit(souls)
	return true


# ---------------------------------------------------------------- mana (in souls' worth)

func spend_mana(amount: float) -> bool:
	if mana + 0.0001 < amount:
		return false
	mana = maxf(0.0, mana - amount)
	Events.mana_changed.emit(mana, max_mana)
	return true


func add_mana(amount: float) -> void:
	mana = clampf(mana + amount, 0.0, max_mana)
	Events.mana_changed.emit(mana, max_mana)


## Top the bar up from the heart. Spends souls for the missing mana. Returns how much was added.
func refill_mana_from_heart() -> float:
	var missing := max_mana - mana
	if missing <= 0.001 or souls <= 0.0:
		return 0.0
	var take := minf(missing, souls)
	souls -= take
	mana += take
	Events.souls_changed.emit(souls)
	Events.mana_changed.emit(mana, max_mana)
	return take


# ---------------------------------------------------------------- meters

func add_suspicion(delta: float, reason: String = "") -> void:
	var before := suspicion
	suspicion = clampf(suspicion + delta, 0.0, 100.0)
	if not is_equal_approx(before, suspicion):
		Events.suspicion_changed.emit(suspicion, suspicion - before, reason)


func add_hunger(delta: float, reason: String = "") -> void:
	var before := hunger
	hunger = clampf(hunger + delta, 0.0, 100.0)
	if not is_equal_approx(before, hunger):
		Events.hunger_changed.emit(hunger, hunger - before, reason)


# ---------------------------------------------------------------- the heart

func set_heart(node: Node2D, radius: float) -> void:
	heart = node
	heart_pos = node.global_position
	heart_radius = radius
	has_heart = true
	Events.heart_placed.emit(heart_pos, radius)


func clear_heart() -> void:
	var at := heart_pos
	heart = null
	has_heart = false
	Events.heart_destroyed.emit(at)


func in_heart_range(pos: Vector2) -> bool:
	return has_heart and pos.distance_to(heart_pos) <= heart_radius


# ---------------------------------------------------------------- clock

func is_night() -> bool:
	return hour >= 20.0 or hour < 6.0


# ---------------------------------------------------------------- unlocks and stats

func unlock(id: StringName) -> void:
	if unlocks.has(id):
		return
	unlocks[id] = true
	Events.milestone_reached.emit(id)


func is_unlocked(id: StringName) -> bool:
	return unlocks.has(id)


func count(stat: String, by: int = 1) -> int:
	stats[stat] = int(stats.get(stat, 0)) + by
	return stats[stat]
