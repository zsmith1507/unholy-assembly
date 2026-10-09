extends Node
## Turns what the necromancer does into Suspicion and Hunger, and sends patrols (autoload `Threats`).
## Owned by the Suspicion and Patrols department.

func _ready() -> void:
	Events.noise_made.connect(_on_noise)


func _on_noise(_at: Vector2, loudness: float, source: String) -> void:
	GameState.add_suspicion(loudness * 0.01, source)
