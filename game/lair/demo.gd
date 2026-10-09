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
	builder.place(&"grinder", Vector2(160, fy))
	builder.place(&"stitching_table", Vector2(470, fy))
	altar = builder.place(&"altar", Vector2(580, fy))
	builder.place(&"spike_trap", Vector2(250, fy))
	for i in 2:
		var g := LairMinion.make(&"ghoul")
		add_child(g)
		g.global_position = Vector2(300 + i * 40, fy)
	Jobs.mark_dig(Rect2i(DEMO.w - 40, DEMO.floor - 20, 16, 20))
	Events.stockpile_designated.emit(Rect2i(26, DEMO.floor - 12, 30, 12), &"ossuary")
	var cam := Camera2D.new()
	cam.position = Vector2(DEMO.w * Sim.CELL * 0.5, (DEMO.ground + 55) * Sim.CELL)
	add_child(cam)
	cam.make_current()


func _physics_process(delta: float) -> void:
	_t += delta
	if _drops < 2 and _t > 0.3 + _drops * 2.0:
		_drops += 1
		Lair.spawn_item(get_tree(), &"corpse", Vector2(100 + _drops * 60, (DEMO.ground + 25) * Sim.CELL), self)
	if altar != null and int(altar.hopper.get(&"stitched_body", 0)) > 0 and not altar.touched and not altar.working:
		altar.interact(null)
	if GameState.mana < 0.5:
		GameState.add_mana(0.5)
