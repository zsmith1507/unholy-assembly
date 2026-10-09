class_name Actor
extends GridBody
## Anything that lives, dies and can be killed: the necromancer, humans, critters, minions.
## Faction decides who fights whom. Groups are added automatically: "actors" and the faction name.

signal died(actor: Actor, killer: Node2D)
signal damaged(actor: Actor, amount: float, source: Node2D)

enum Faction { NECRO, UNDEAD, HUMAN, CRITTER, DEMON }

@export var faction: Faction = Faction.HUMAN
@export var max_hp := 100.0
@export var display_name := ""

var hp := 100.0
var dead := false
var facing := 1 ## 1 right, -1 left


func _ready() -> void:
	hp = max_hp
	add_to_group("actors")
	add_to_group(faction_group(faction))


static func faction_group(f: Faction) -> StringName:
	match f:
		Faction.NECRO: return &"necro"
		Faction.UNDEAD: return &"minions"
		Faction.HUMAN: return &"humans"
		Faction.CRITTER: return &"critters"
		Faction.DEMON: return &"demons"
	return &"actors"


func is_living() -> bool:
	return faction == Faction.HUMAN or faction == Faction.CRITTER


func take_damage(amount: float, source: Node2D = null) -> void:
	if dead:
		return
	hp -= amount
	damaged.emit(self, amount, source)
	if hp <= 0.0:
		die(source)


## Override _on_death to drop a body, spill blood, release a soul. Call super.die() if you override die().
func die(killer: Node2D = null) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	_on_death(killer)
	died.emit(self, killer)
	Events.actor_died.emit(self, killer, global_position)


func _on_death(_killer: Node2D) -> void:
	pass
