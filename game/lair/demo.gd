extends Node2D
## A little dug-out chamber running the whole first chain: corpses fall in, ghouls haul them to the grinder,
## gibs and bones go to the stitching table, the stitched body to the altar, and the necromancer's touch
## (here, automatic) raises a ghoul. A dig rect and a bones stockpile give the ghouls other work.

const DEMO := {"w": 360, "h": 200, "ground": 60, "floor": 150}

var builder: LairBuilder
var director: LairDirector
var altar: LairMachine
var _t := 0.0
var _drops := 0


func _ready() -> void:
	GameState.reset()
	Jobs.reset()
	var w := Sim.create(DEMO.w, DEMO.h, 7)
	w.fill_rect(0, DEMO.ground, DEMO.w, DEMO.h - DEMO.ground, SandWorld.M_EARTH)
	w.fill_rect(0, DEMO.h - 3, DEMO.w, 3, SandWorld.M_BEDROCK)
	w.fill_rect(20, DEMO.ground + 20, DEMO.w - 40, DEMO.floor - DEMO.ground - 20, SandWorld.M_EMPTY)
	var view := SimView.new()
	add_child(view)
	director = LairDirector.new()
	add_child(director)
	for l in ["buildings", "items", "actors", "fx"]:
		director.layers[l] = self
	builder = LairBuilder.new()
	builder.parent_layer = self
	add_child(builder)
	var fy := float(DEMO.floor * Sim.CELL)
	GameState.souls = 3.0
	builder.place(&"heart", Vector2(360, fy))
	builder.place(&"grinder", Vector2(240, fy))
	builder.place(&"stitching_table", Vector2(470, fy))
	altar = builder.place(&"altar", Vector2(560, fy))
	builder.place(&"spike_trap", Vector2(140, fy))
	for s in get_tree().get_nodes_in_group(&"lair_structures"):
		_label(s)
	for i in 2:
		var g := LairMinion.make(&"ghoul")
		add_child(g)
		g.global_position = Vector2(300 + i * 40, fy)
	Jobs.mark_dig(Rect2i(DEMO.w - 20, DEMO.floor - 30, 12, 30)) # into the right-hand wall
	Events.stockpile_designated.emit(Rect2i(60, DEMO.floor - 12, 24, 12), &"ossuary")
	var cam := Camera2D.new()
	cam.position = Vector2(DEMO.w * Sim.CELL * 0.5, (DEMO.ground + 55) * Sim.CELL)
	add_child(cam)
	cam.make_current()


func _physics_process(delta: float) -> void:
	_t += delta
	if _drops < 2 and _t > 0.3 + _drops * 2.0:
		_drops += 1
		Lair.spawn_item(get_tree(), &"corpse", Vector2(150 + _drops * 50, (DEMO.ground + 25) * Sim.CELL), self)
	if altar != null and int(altar.hopper.get(&"stitched_body", 0)) > 0 and not altar.touched and not altar.working:
		altar.interact(null)
	if GameState.mana < 0.5:
		GameState.add_mana(0.5)


## Name tags over the buildings while the art is still placeholder blocks (demo only).
func _label(s: Node2D) -> void:
	var names := {&"heart": "Necrotic Heart", &"spike_trap": "Spike Trap"}
	var text: String = names.get(s.kind, s.get("spec").get("name", String(s.kind)) if s.get("spec") is Dictionary else String(s.kind))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.modulate = Color(0.8, 0.85, 0.8, 0.8)
	l.position = Vector2(-40, -s.footprint.y - 14)
	l.size = Vector2(80, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(l)
