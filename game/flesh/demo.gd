extends Node2D
## Bodies and Souls demo: a hamlet, a graveyard and a strip of forest on one screen.
## A stand-in necromancer arrives; townsfolk notice him and run (a brave farmer comes at him), one is cut
## down and falls apart in a spray of blood, its soul drifting down to the heart below; the grave-wind draws
## an old body up out of an opened grave; a rabbit dies for a soul fragment.
## Run it in Godot (F6 on this scene) or: shot.tscn --scene=res://flesh/demo.tscn --frames=240.

const DEMO := {
	"w": 320, "h": 180, "ground": 110, ## cells (the screen is 640×360 px)
	"necro_x": 236.0, ## where the stand-in necromancer stands, px
	"heart": Vector2(330, 320), "heart_radius": 150.0,
	"kill_frame": 70, ## a villager is cut down
	"rabbit_frame": 110,
	"harvest_from": 40, ## the grave-wind starts on the opened grave
	"pull": 0.6, "max_speed": 4.0, "steer": 0.12, ## as the Necromancer's Harvest (HARV)
	"hour": 12.0,
}

var sp: FleshSpawner
var necro: Node2D
var hand := Vector2.ZERO
var victim: Human
var rabbit: Critter
var grave_body: Corpse
var _frame := 0
var _pulled: Array = []


func _ready() -> void:
	GameState.reset()
	GameState.hour = DEMO.hour
	var w := Sim.create(DEMO.w, DEMO.h, 3)
	var g: int = DEMO.ground
	w.fill_rect(0, g, DEMO.w, DEMO.h - g, SandWorld.M_EARTH)
	w.fill_rect(0, g, DEMO.w, 2, SandWorld.M_GRASS)
	w.fill_rect(0, DEMO.h - 3, DEMO.w, 3, SandWorld.M_BEDROCK)
	# the heart's chamber below
	var hc := Sim.to_cell(DEMO.heart)
	w.fill_rect(hc.x - 24, hc.y - 14, 48, 15, SandWorld.M_EMPTY)
	# two homes: stone walls, wooden roofs (hollow inside)
	var homes := []
	for i in 2:
		var x0 := 214 + i * 34
		w.fill_rect(x0, g - 22, 26, 22, SandWorld.M_STONE)
		w.fill_rect(x0 + 2, g - 20, 22, 20, SandWorld.M_EMPTY)
		w.fill_rect(x0 - 2, g - 25, 30, 3, SandWorld.M_WOOD)
		homes.append({"id": i + 1, "rect": Rect2(Vector2(x0, g - 22) * Sim.CELL, Vector2(26, 22) * Sim.CELL), "residents": 2, "alive": 2})
	# a graveyard: two coffins, one already opened by Dig
	var graves: Array[Vector2] = []
	for i in 2:
		var gx := 40 + i * 30
		w.fill_rect(gx + 1, g - 6, 4, 6, SandWorld.M_STONE) # tombstone
		w.fill_rect(gx, g, 8, 14, SandWorld.M_DIRT)
		w.fill_rect(gx - 1, g + 14, 10, 6, SandWorld.M_WOOD)
		w.fill_rect(gx, g + 15, 8, 4, SandWorld.M_EMPTY)
		graves.append(Sim.cell_center(Vector2i(gx + 4, g + 17)))
	# the tunnel Dig bored from where he stands down to the second coffin
	var from_c := Sim.to_cell(Vector2(DEMO.necro_x - 14.0, g * Sim.CELL - 2.0))
	var to_c := Sim.to_cell(graves[1])
	for i in 41:
		var c := Vector2(from_c).lerp(Vector2(to_c), i / 40.0)
		w.paint_circle(int(c.x), int(c.y), 4, SandWorld.M_EMPTY, false)
	var view := SimView.new()
	add_child(view)
	var items := Node2D.new()
	items.z_index = 5
	add_child(items)
	var actors := Node2D.new()
	actors.z_index = 10
	add_child(actors)
	var heart := Node2D.new()
	heart.position = DEMO.heart
	heart.add_child(ArtLib.make_sprite("heart"))
	add_child(heart)
	GameState.set_heart(heart, DEMO.heart_radius)

	var surface := float(g * Sim.CELL)
	var info := {
		"towns": [{"name": "Ashby", "rect": Rect2(420, surface - 60, 140, 60), "side": 1, "homes": homes}],
		"graves": graves,
		"critter_zones": [Rect2(300, surface - 40, 120, 40)],
	}
	var inst = load("res://flesh/install.gd").new()
	sp = inst.install(_Layers.new(actors, items, self), info).flesh_spawner
	for b in items.get_children():
		if b is Corpse and b.global_position.x > 130.0:
			grave_body = b
	# out at work: put the townsfolk about their day
	for h in actors.get_children():
		if h is Human:
			h.global_position.x = randf_range(380.0, 600.0)
			h.set_mode(&"work")
	victim = sp.spawn_human(&"villager", Vector2(DEMO.necro_x + 46.0, surface - 4))
	rabbit = sp.spawn_critter(&"rabbit", Vector2(DEMO.necro_x - 60.0, surface - 4))

	necro = Node2D.new()
	necro.name = "StandInNecromancer"
	necro.add_to_group(&"necro")
	necro.position = Vector2(DEMO.necro_x, surface)
	necro.set("facing", -1)
	var spr := ArtLib.make_sprite("necromancer")
	spr.flip_h = true
	necro.add_child(spr)
	actors.add_child(necro)
	hand = necro.position + Vector2(-10, -40)

	var cam := Camera2D.new()
	cam.position = Vector2(DEMO.w, DEMO.h) * Sim.CELL * 0.5
	add_child(cam)
	cam.make_current()


## main.<layer> lookups for the installer without the whole main scene.
class _Layers extends Node:
	var actors: Node
	var items: Node

	func _init(a: Node, i: Node, host: Node) -> void:
		actors = a
		items = i
		host.add_child(self)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == DEMO.kill_frame and is_instance_valid(victim):
		victim.take_damage(999.0, necro)
		var c: Corpse = null
		for n in get_tree().get_nodes_in_group(&"corpses"):
			if n is Corpse and n.fresh:
				c = n
		if c != null:
			c.tear("armF")
	if _frame == DEMO.rabbit_frame and is_instance_valid(rabbit):
		rabbit.take_damage(999.0, necro)
	if _frame >= DEMO.harvest_from:
		_grave_wind()
	queue_redraw()


## The Necromancer's Harvest, in miniature: pull the opened grave's body toward his hand.
func _grave_wind() -> void:
	# everything of the old body (and whatever tears off it) near the opened grave
	_pulled = []
	for n in get_tree().get_nodes_in_group(&"pullable"):
		if (n is Corpse or n is BodyPart) and not n.data.get("fresh", true) and n.carrier == null \
				and n.global_position.x < hand.x + 10.0 and not n.has_meta("harvested"):
			if n is Corpse and n.interred and n != grave_body:
				continue
			_pulled.append(n)
	for n in _pulled.duplicate():
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			_pulled.erase(n)
			continue
		var to: Vector2 = hand - n.global_position
		if to.length() < 14.0:
			n.drop(necro.position + Vector2(-12, -1), Vector2(-0.5, 0))
			n.set_meta("harvested", true)
			_pulled.erase(n)
			continue
		var dir := to.normalized()
		var v: Vector2 = n.velocity
		var along := v.dot(dir)
		n.apply_pull(dir * DEMO.pull * clampf(DEMO.max_speed - along, 0.0, 1.0) - (v - dir * along) * DEMO.steer)


func _draw() -> void:
	for n in _pulled:
		if is_instance_valid(n):
			draw_line(n.global_position, hand, Color(0.5, 0.95, 0.85, 0.35), 1.0)
