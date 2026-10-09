extends Node2D
## Eyegor and HUD demo: the HUD over a dark backdrop, a stand-in necromancer for the spell toolbar,
## and Eyegor working through a few lines. Run: res://eyegor/demo.tscn


class FakeNecro:
	extends Node2D

	func _init() -> void:
		add_to_group(&"necro")

	func get_spells() -> Array:
		return [
			{"id": &"dig", "name": "Dig", "cost_text": "0.05", "color": Color("c8a070")},
			{"id": &"harvest", "name": "Harvest", "cost_text": "0.1", "color": Color("5fe0cc")},
			{"id": &"siphon", "name": "Siphon", "cost_text": "+", "color": Color("9a2a2a")},
			{"id": &"build", "name": "Build", "cost_text": "0.2", "color": Color("e0b860")},
			{"id": &"command_dig", "name": "Dig Order", "cost_text": "", "color": Color("a462e8")},
		]

	func get_selected_spell() -> StringName:
		return &"harvest"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1a1216")
	bg.size = Vector2(640, 360)
	add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color("2e2218")
	ground.position = Vector2(0, 230)
	ground.size = Vector2(640, 130)
	add_child(ground)
	add_child(FakeNecro.new())
	var ui := CanvasLayer.new()
	add_child(ui)
	var objectives := EyegorObjectives.new()
	add_child(objectives)
	add_child(EyegorCommentary.new())
	var hud := EyegorHUD.new()
	hud.objectives = objectives
	ui.add_child(hud)
	GameState.mana = 0.6
	GameState.souls = 3.0
	GameState.has_heart = true
	GameState.fragments = 2.0
	GameState.suspicion = 34.0
	GameState.hunger = 12.0
	objectives.start()
	hud.show_banner(&"place_heart")
	Narrative.announce("grave_robbed")
	Narrative.say_line("memo_seating", {}, &"memo")
	await get_tree().create_timer(0.3).timeout
	GameState.add_souls(1.0, "human", Vector2(320, 200))
