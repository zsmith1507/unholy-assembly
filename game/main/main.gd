class_name Main
extends Node2D
## Builds a run. Each department plugs in through its own res://<dept>/install.gd, which adds its nodes
## to the layers below. A department whose installer is missing is simply skipped, so the game boots at
## every stage of the build. Owned by the lead (Claude); departments don't edit this file.

## Installers, in the order they run. World runs first and returns `info` (see docs/ARCHITECTURE.md).
const INSTALLERS := [
	"res://world/install.gd",
	"res://art/install.gd",
	"res://lair/install.gd",
	"res://flesh/install.gd",
	"res://necro/install.gd",
	"res://threats/install.gd",
	"res://eyegor/install.gd",
]

const DEFAULT_WORLD := Vector2i(1536, 768) ## cells; 3072 x 1536 pixels

@export var world_seed := 0

var info := {} ## filled by world/install.gd: spawn points, graveyard, towns
var player: Node2D = null ## set by necro/install.gd

# Layers, back to front. Departments add children to these.
var background: Node2D
var terrain: Node2D
var items: Node2D
var buildings: Node2D
var actors: Node2D
var fx: Node2D
var ui: CanvasLayer
var camera: Camera2D
var sim_view: SimView


func _ready() -> void:
	_make_layers()
	if Sim.world == null:
		Sim.create(DEFAULT_WORLD.x, DEFAULT_WORLD.y, world_seed)
	for path in INSTALLERS:
		if not ResourceLoader.exists(path):
			continue
		var inst = load(path).new()
		var result = inst.install(self, info)
		if result is Dictionary:
			info.merge(result, true)
	if info.is_empty():
		_fallback_world()
	if player == null:
		camera.position = info.get("necro_spawn", Sim.world_size_px() * 0.5)


func _make_layers() -> void:
	background = _layer("Background", -100)
	terrain = _layer("Terrain", 0)
	sim_view = SimView.new()
	sim_view.name = "SimView"
	terrain.add_child(sim_view)
	buildings = _layer("Buildings", 4)
	items = _layer("Items", 5)
	actors = _layer("Actors", 10)
	fx = _layer("FX", 20)
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	add_child(l)
	return l


func _process(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		camera.position = player.global_position + Vector2(0, -40)
	_clamp_camera()


func _clamp_camera() -> void:
	var half := get_viewport().get_visible_rect().size * 0.5
	var size := Sim.world_size_px()
	camera.position.x = clampf(camera.position.x, half.x, maxf(half.x, size.x - half.x))
	camera.position.y = clampf(camera.position.y, half.y, maxf(half.y, size.y - half.y))


## Until the World department lands: flat ground with a stone layer, so everything else has a floor.
func _fallback_world() -> void:
	var w := Sim.world
	var ground := int(w.get_height() * 0.4)
	w.fill_rect(0, ground, w.get_width(), w.get_height() - ground, SandWorld.M_EARTH)
	w.fill_rect(0, ground + 60, w.get_width(), w.get_height() - ground - 60, SandWorld.M_STONE)
	w.fill_rect(0, w.get_height() - 4, w.get_width(), 4, SandWorld.M_BEDROCK)
	info["necro_spawn"] = Vector2(w.get_width() * Sim.CELL * 0.5, ground * Sim.CELL)
	info["surface_y_px"] = ground * Sim.CELL
