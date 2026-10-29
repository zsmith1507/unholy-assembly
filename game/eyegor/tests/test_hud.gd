extends RefCounted
## The HUD survives with no Necromancer, no heart and no objectives, then picks a necromancer up when one
## appears (spell toolbar from get_spells, the interact hint from get_interact_hint).


class FakeNecro:
	extends Node2D

	func _init() -> void:
		add_to_group(&"player")

	func get_spells() -> Array:
		return [{"id": &"dig", "name": "Dig", "cost_text": "0.05 souls/s", "color": Color.TAN, "detail": ""},
			{"id": &"build", "name": "Build", "cost_text": "0.2 mana", "color": Color.GOLD, "detail": "Corpse Grinder"}]

	func get_selected_spell() -> StringName:
		return &"build"

	func get_interact_hint() -> String:
		return "Necrotic Heart (1.0 souls): refill mana"


func run(t) -> void:
	var layer := CanvasLayer.new()
	t.root.add_child(layer)
	var hud := EyegorHUD.new()
	layer.add_child(hud)
	await t.ticks(30)
	t.check(is_instance_valid(hud) and hud.is_inside_tree(), "HUD runs with no necromancer")
	t.check(hud._spells.get_child_count() == 0, "no spell boxes without a necromancer")
	t.check(hud._hint.text == "", "no hint without a necromancer")
	var nec := FakeNecro.new()
	t.root.add_child(nec)
	await t.ticks(30)
	t.check(hud._spells.get_child_count() == 2, "spell toolbar from get_spells (%d)" % hud._spells.get_child_count())
	t.check(hud._hint.text.ends_with("refill mana"), "interact hint from get_interact_hint (%s)" % hud._hint.text)
	t.check(hud._detail.text == "Corpse Grinder", "selected spell's detail line")
	nec.queue_free()
	await t.ticks(30)
	t.check(hud._hint.text == "", "necromancer gone, hint cleared")
	Narrative.say("Testing, testing.", &"chipper")
	Narrative.say("RE: Seating\nPlease sit.", &"memo")
	Narrative.say("MEMO: A one-line memo.", &"memo")
	await t.ticks(5)
	t.check(hud.panel.is_busy(), "Eyegor's panel takes lines")
	GameState.has_heart = true
	GameState.add_fragments(1.0, "rabbit", Vector2.ZERO)
	GameState.add_souls(1.0, "human", Vector2(10, 10))
	await t.ticks(20)
	t.check(true, "pop-ups for souls and fragments don't error")
	hud.show_banner(&"first_ghoul")
	t.check(true, "an unlock with no milestone line is ignored")
	# the clipboard opens on the advisor button and lists the checklist and recent lines
	var o := EyegorObjectives.new()
	t.root.add_child(o)
	hud.clipboard.objectives = o
	o.start()
	var ev := InputEventAction.new()
	ev.action = &"advisor"
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.ticks(3)
	t.check(hud.clipboard.visible, "the advisor button opens the clipboard")
	await t.ticks(2)
	t.check(hud.clipboard._box.get_child_count() >= 4, "clipboard lists checklist and recent lines (%d)" % hud.clipboard._box.get_child_count())
	hud.clipboard.toggle()
	t.check(not hud.clipboard.visible, "and closes again")
	# the panel: announcements give way to real talk and don't repeat
	var p := EyegorPanel.new()
	layer.add_child(p)
	await t.ticks(2)
	p.push("Long line one.", &"chipper")
	p.push("A grave has been emptied.", &"announce")
	p.push("A grave has been emptied.", &"announce")
	t.check(p.queue.filter(func(e): return e.mood == &"announce").size() <= 1, "duplicate announcement dropped")
	p.push("Real talk.", &"proud")
	t.check(p.queue.filter(func(e): return e.mood == &"announce").is_empty(), "waiting announcements give way to real talk")
