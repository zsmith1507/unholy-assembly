extends Node2D
## Pixel Physics demo pit: every material in one screen, with a scripted opening so a screenshot shows them working.
## Play with it: left mouse digs, right mouse pours the chosen material, F lights a fire, E sets off a blast,
## 1-9 choose what to pour (blood, holy water, ichor, tallow, embalming fluid, grave dirt, ash, flesh, sand).

const SIZE := Vector2i(320, 180) ## cells: exactly one screen at CELL = 2
const POUR := [
	SandWorld.M_BLOOD, SandWorld.M_HOLY, SandWorld.M_ICHOR, SandWorld.M_TALLOW, SandWorld.M_EMBALM,
	SandWorld.M_DIRT, SandWorld.M_ASH, SandWorld.M_FLESH, SandWorld.M_SAND,
]

var w: SandWorld
var pour := SandWorld.M_BLOOD
var frame := 0
var label: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.08)
	bg.size = Vector2(SIZE * Sim.CELL)
	bg.z_index = -10
	add_child(bg)
	w = Sim.create(SIZE.x, SIZE.y, 1234)
	_build()
	var view := SimView.new()
	add_child(view)
	var cam := Camera2D.new()
	cam.position = Vector2(SIZE * Sim.CELL) * 0.5
	add_child(cam)
	cam.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 8)
	label.modulate = Color(0.8, 0.75, 0.7, 0.8)
	ui.add_child(label)


func _build() -> void:
	var M := SandWorld
	w.fill_rect(0, 160, 320, 20, M.M_BEDROCK)
	# packed earth banks with grass on top, a stone crypt basin in the middle
	w.fill_rect(0, 90, 110, 70, M.M_EARTH)
	w.fill_rect(0, 88, 110, 2, M.M_GRASS)
	w.fill_rect(220, 100, 100, 60, M.M_EARTH)
	w.fill_rect(220, 98, 100, 2, M.M_GRASS)
	w.fill_rect(110, 150, 110, 10, M.M_STONE)
	w.fill_rect(110, 120, 6, 30, M.M_STONE)
	w.fill_rect(214, 120, 6, 40, M.M_STONE)
	# a pool of holy water in the basin, tallow on the right bank, a coffin buried in the left bank
	w.fill_rect(116, 136, 98, 14, M.M_HOLY)
	w.fill_rect(240, 98, 50, 10, M.M_EMPTY)
	w.fill_rect(240, 100, 50, 8, M.M_TALLOW)
	w.fill_rect(30, 110, 40, 16, M.M_WOOD)
	w.fill_rect(34, 113, 32, 10, M.M_FLESH)
	# bones and a slab of earth overhanging the basin that the opening will cut loose
	w.fill_rect(80, 130, 20, 4, M.M_BONE)
	w.fill_rect(110, 90, 10, 5, M.M_EARTH)
	w.fill_rect(120, 90, 40, 14, M.M_EARTH)
	# a pocket of miasma under the right bank, sand and snow drifts
	w.fill_rect(250, 130, 30, 12, M.M_EMPTY)
	w.fill_rect(250, 130, 30, 12, M.M_MIASMA)
	w.fill_rect(160, 20, 8, 8, M.M_SAND)
	w.fill_rect(290, 60, 10, 10, M.M_SNOW)


## The scripted opening: blood pours, ash and flesh pile, the slab is cut free, the tallow is lit.
func _script() -> void:
	var M := SandWorld
	if frame < 150:
		w.fill_rect(170, 10, 3, 2, M.M_BLOOD)
	if frame < 120 and frame % 4 == 0:
		w.fill_rect(60, 10, 3, 2, M.M_ASH)
		w.fill_rect(80, 10, 3, 2, M.M_FLESH)
	if frame == 40:
		for y in range(88, 97):
			w.dig(115, y, 2, 10.0)
	if frame == 60:
		w.ignite(265, 99, 4)
	if frame == 90:
		w.spill(130, 80, M.M_ICHOR, 60, 1.5, -2.0)


func _physics_process(_delta: float) -> void:
	frame += 1
	_script()
	var c := Sim.to_cell(get_global_mouse_position())
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		w.dig(c.x, c.y, 5, 1.5)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		w.paint_circle(c.x, c.y, 2, pour, true)
	label.text = "pour: %s   chunks falling %d   droplets %d   awake chunks %d" % [
		SandWorld.mat_name(pour), w.falling_chunk_count(), w.particle_count(), w.active_chunk_count()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var c := Sim.to_cell(get_global_mouse_position())
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			pour = POUR[event.keycode - KEY_1]
		elif event.keycode == KEY_F:
			w.ignite(c.x, c.y, 4)
		elif event.keycode == KEY_E:
			w.explode(c.x, c.y, 10, 8.0)
