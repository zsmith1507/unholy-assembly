extends Node2D
## The necromancer's proving ground in Godot: a small world with earth to dig, a stone shelf, a pool of
## blood to siphon, a buried coffin with a corpse to rob by magic, and a few loose things to pull.
## Open res://necro/demo.tscn and press F6. WASD / left stick move, Space / A jump (hold in the air to
## levitate), mouse / right stick aim, left click / RT cast, right click / LT alternate, 1-6 or
## Tab / bumpers pick a spell, E / X interact.

const StandInBuilder := preload("res://necro/demo/stand_in_builder.gd")
const NecromancerScript := preload("res://necro/necromancer.gd")

const DEMO := {
	"size": Vector2i(480, 240), # cells: 960 x 480 px
	"ground": 130, # cells down to the surface
	"stone_depth": 60, # stone starts this far below the surface
	"pool": Rect2i(250, 132, 40, 12), # blood pool hollow just under the grass (cells)
	"coffin_x": 150, # buried coffin (cells)
	"coffin_depth": 26,
}

var necro: Necromancer
var camera: Camera2D
var items_layer: Node2D
var hud: Label


func _ready() -> void:
	_build_world()
	var view := SimView.new()
	add_child(view)
	var builder := StandInBuilder.new()
	builder.name = "StandInBuilder"
	if get_tree().get_first_node_in_group("lair_builder") == null:
		add_child(builder)
	items_layer = Node2D.new()
	items_layer.z_index = 5
	add_child(items_layer)
	_spawn_items()
	necro = NecromancerScript.new()
	necro.position = Vector2(DEMO.size.x * Sim.CELL * 0.3, DEMO.ground * Sim.CELL)
	necro.z_index = 10
	add_child(necro)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(6, 4)
	hud.add_theme_font_size_override("font_size", 8)
	hud.add_theme_color_override("font_color", Color(0.7, 0.95, 0.9))
	ui.add_child(hud)
	GameState.souls = 3.0


func _build_world() -> void:
	var w := Sim.create(DEMO.size.x, DEMO.size.y, 777)
	var g: int = DEMO.ground
	w.fill_rect(0, g, DEMO.size.x, DEMO.size.y - g, SandWorld.M_EARTH)
	w.fill_rect(0, g, DEMO.size.x, 3, SandWorld.M_GRASS)
	# rolling surface
	for x in DEMO.size.x:
		var bump := int(4.0 * sin(x * 0.03) + 3.0 * sin(x * 0.071))
		if bump > 0:
			w.fill_rect(x, g - bump, 1, bump, SandWorld.M_EARTH)
			w.set_mat(x, g - bump, SandWorld.M_GRASS)
	w.fill_rect(0, g + DEMO.stone_depth, DEMO.size.x, DEMO.size.y - g - DEMO.stone_depth, SandWorld.M_STONE)
	w.fill_rect(0, DEMO.size.y - 4, DEMO.size.x, 4, SandWorld.M_BEDROCK)
	w.fill_rect(0, 0, 3, DEMO.size.y, SandWorld.M_BEDROCK)
	w.fill_rect(DEMO.size.x - 3, 0, 3, DEMO.size.y, SandWorld.M_BEDROCK)
	# a stone outcrop to show hardness
	w.paint_circle(330, g - 2, 14, SandWorld.M_STONE, false)
	# a hollow full of blood
	var pool: Rect2i = DEMO.pool
	w.fill_rect(pool.position.x, pool.position.y - 8, pool.size.x, pool.size.y + 8, SandWorld.M_EMPTY)
	w.fill_rect(pool.position.x, pool.position.y + 4, pool.size.x, pool.size.y - 4, SandWorld.M_BLOOD)
	# a coffin under the grass: wood box with a hollow
	var cx: int = DEMO.coffin_x
	var cy: int = g + DEMO.coffin_depth
	w.fill_rect(cx - 16, cy - 7, 32, 14, SandWorld.M_WOOD)
	w.fill_rect(cx - 14, cy - 5, 28, 10, SandWorld.M_EMPTY)


func _spawn_items() -> void:
	var g: float = DEMO.ground * Sim.CELL
	var specs := [
		[&"part", Vector2(400, g - 30), Vector2(10, 6), {"part": "arm"}],
		[&"part", Vector2(430, g - 30), Vector2(8, 10), {"part": "head"}],
		[&"bones", Vector2(700, g - 30), Vector2(10, 6), {}],
		[&"corpse", Vector2(DEMO.coffin_x * Sim.CELL, (DEMO.ground + DEMO.coffin_depth + 5) * Sim.CELL), Vector2(24, 8), {"source": "villager"}],
	]
	for s in specs:
		var it := make_item(s[0], s[1], s[2], s[3])
		items_layer.add_child(it)


## A simple stand-in Item that the Harvest spell can pull. Bodies and Souls makes the real ones.
static func make_item(kind: StringName, at: Vector2, size: Vector2, data := {}) -> Item:
	var it := Item.new()
	it.kind = kind
	it.data = data
	it.box_size = size
	it.position = at
	it.add_to_group("pullable")
	var r := ColorRect.new()
	r.color = {&"corpse": Color("6a5a55"), &"part": Color("8f5b5a"), &"bones": Color("d8ccaa")}.get(kind, Color.GRAY)
	r.size = size
	r.position = Vector2(-size.x * 0.5, -size.y)
	it.add_child(r)
	return it


func _process(_delta: float) -> void:
	if necro == null:
		return
	camera.position = necro.global_position + Vector2(0, -40)
	var half := get_viewport().get_visible_rect().size * 0.5
	var size := Sim.world_size_px()
	camera.position = camera.position.clamp(half, size - half)
	var s := necro.get_selected()
	var line := "MANA %.2f / %.2f souls   SOULS %.1f   [%d] %s  %s  %s" % [
		GameState.mana, GameState.max_mana, GameState.souls, necro.selected + 1, s.display_name(), s.cost_text(), s.detail()]
	var hint := necro.get_interact_hint()
	if hint != "":
		line += "\nE: " + hint
	hud.text = line
