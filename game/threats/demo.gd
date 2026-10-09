extends Node2D
## Threats demo: a little world with a town, a buried lair, a rotting pile and loud machines.
## Patrols leave town, the stench haze rises, and the F3 overlay (shown) explains every change.

const DEMO := {
	"w": 340, "h": 200, "ground": 90, # cells
	"heart_cell": Vector2i(220, 150),
	"noise_every_s": 1.0, "noise_loudness": 4.0,
	"time_scale_s": 1.0, # demo seconds per frame-second
}

var _noise_t := 0.0


func _ready() -> void:
	var world := Sim.create(DEMO.w, DEMO.h, 7)
	world.fill_rect(0, DEMO.ground, DEMO.w, DEMO.h - DEMO.ground, SandWorld.M_EARTH)
	world.fill_rect(0, DEMO.ground, DEMO.w, 2, SandWorld.M_GRASS)
	world.fill_rect(150, 110, 140, 14, SandWorld.M_STONE) # a stone shelf over part of the lair
	world.fill_rect(0, DEMO.h - 3, DEMO.w, 3, SandWorld.M_BEDROCK)
	var hc: Vector2i = DEMO.heart_cell
	world.fill_rect(hc.x - 40, hc.y - 18, 80, 20, SandWorld.M_EMPTY) # the lair chamber
	world.fill_rect(hc.x + 10, hc.y + 0, 20, 2, SandWorld.M_GIBS)
	world.fill_rect(120, DEMO.ground, 4, 40, SandWorld.M_EMPTY) # a tunnel mouth
	var view := SimView.new()
	add_child(view)
	var surface := float(DEMO.ground * Sim.CELL)
	var town := {"name": "Ashby", "rect": Rect2(10, surface - 60, 160, 60), "side": -1, "homes": []}
	var info := {"surface_y_px": surface, "towns": [town],
		"patrol_routes": [PackedVector2Array([Vector2(90, surface), Vector2(600, surface)])]}
	# the heart
	var heart := Node2D.new()
	heart.position = Sim.to_pixel(hc)
	add_child(heart)
	GameState.set_heart(heart, 120.0)
	GameState.suspicion = 30.0
	var layers := Node2D.new()
	add_child(layers)
	var ui := CanvasLayer.new()
	add_child(ui)
	Threats.begin_run(info)
	var patrols = load("res://threats/patrols.gd").new()
	layers.add_child(patrols)
	var haze = load("res://threats/stench_view.gd").new()
	layers.add_child(haze)
	var overlay = load("res://threats/debug_overlay.gd").new()
	ui.add_child(overlay)
	overlay.visible = true
	Threats.simulate(Threats.STENCH.grace_s + Threats.STENCH.ramp_s, 2.0)
	Events.noise_made.emit(heart.position, 3.0, "grinder")
	patrols.send(0)
	var cam := Camera2D.new()
	cam.position = Vector2(340, surface - 20)
	add_child(cam)
	cam.make_current()


func _process(dt: float) -> void:
	_noise_t -= dt
	if _noise_t <= 0.0:
		_noise_t = DEMO.noise_every_s
		Events.noise_made.emit(Sim.to_pixel(DEMO.heart_cell), DEMO.noise_loudness, "grinder")
