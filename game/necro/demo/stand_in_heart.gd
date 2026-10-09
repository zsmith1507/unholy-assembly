extends Node2D
## Stand-in necrotic heart for the necro demo only: an interactable that refills mana from souls.
## The Lair department's real heart replaces it in a run.


func _ready() -> void:
	add_to_group("interactable")


func get_box() -> Rect2:
	return Rect2(global_position - Vector2(20, 48), Vector2(40, 48))


func interact_hint() -> String:
	return NecroText.t("heart.refill_hint", "Refill mana ({s} souls stored)", {"s": "%.1f" % GameState.souls})


func interact(_by: Node2D) -> void:
	GameState.refill_mana_from_heart()
