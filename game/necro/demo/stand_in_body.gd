extends Item
## A stand-in for a Bodies and Souls corpse with the Components hook (group "harvestable"), used by the
## necro tests and demo before the real ones land: components() says what it yields, consume() hands
## that over and frees it.

var yields := {&"flesh": 2.0, &"bones": 1.0, &"blood": 1.0}
var consumed := 0


func _ready() -> void:
	super._ready()
	add_to_group("harvestable")
	add_to_group("pullable")


func components() -> Dictionary:
	return yields.duplicate()


func consume() -> Dictionary:
	consumed += 1
	var y := yields.duplicate()
	yields = {}
	queue_free()
	return y
