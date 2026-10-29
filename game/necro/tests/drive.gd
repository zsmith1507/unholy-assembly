extends RefCounted
## Screenshot driver for res://necro/demo.tscn: walks right, digs a tunnel down toward the coffin,
## then pulls the loose parts with Harvest. Used with tests/shot.tscn --drive=res://necro/tests/drive.gd.
## Pass a frame count of about 240 for the dig, 420 for the harvest.


func drive(demo: Node, frame: int) -> void:
	var n: Necromancer = demo.get("necro")
	if n == null:
		return
	n.scripted = true
	var feet := n.global_position
	if frame < 30:
		n.script_input = {"aim": feet + Vector2(60, -20)}
	elif frame < 70:
		n.script_input = {"move": Vector2(-1, 0), "aim": feet + Vector2(-60, 20)}
	elif frame < 250:
		n.select_spell_id(&"dig")
		n.script_input = {"cast": true, "aim": feet + Vector2(-40, 70), "move": Vector2(-0.4, 0) if frame > 150 else Vector2.ZERO}
	elif frame < 370:
		n.script_input = {"move": Vector2(1, 0), "jump": frame > 262 and frame < 285, "aim": feet + Vector2(80, -10)}
	else:
		n.select_spell_id(&"harvest")
		n.script_input = {"cast": true, "aim": Vector2(420, 250)}
