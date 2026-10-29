extends NecroRectTool
## Command: Dig here. Drag a rectangle over ground and the ghouls assigned to digging clear it
## (Jobs.mark_dig). He commands; they shovel. Marks stay visible until the job board drops them.

const COMMAND := {
	"cost": 0.0, # souls' worth per order (commands are free for now)
	"min_solid": 0.05, # a rectangle with less ground than this in it is refused (nothing to dig)
	"max_cells": 40000, # largest single order, in cells (200 x 200 cells = 400 x 400 px)
	"mark_color": Color(0.85, 0.7, 0.35),
}

var marks: Array = [] ## Rect2i orders given (drawn faintly until done)
var last_rect := Rect2i()


func _init() -> void:
	id = &"command_dig"
	title = "Dig Here"
	color = COMMAND.mark_color


func cost_text() -> String:
	return NecroText.t("necro_command_cost", "order") if COMMAND.cost <= 0.0 else "%.2f" % COMMAND.cost


func rect_ok(r: Rect2i) -> bool:
	if r.size.x * r.size.y > COMMAND.max_cells or Sim.world == null:
		return false
	var counts := Sim.world.count_rect(r.position.x, r.position.y, r.size.x, r.size.y)
	var solid := 0
	for m in counts:
		var k := SandWorld.mat_kind(m)
		if (k == 1 or k == 2) and SandWorld.mat_hardness(m) > 0.0:
			solid += counts[m]
	return solid >= r.size.x * r.size.y * COMMAND.min_solid


func commit(r: Rect2i) -> void:
	if not rect_ok(r):
		return
	if COMMAND.cost > 0.0 and not GameState.spend_mana(COMMAND.cost):
		necro.warn_no_mana()
		return
	last_rect = r
	marks.append(r)
	if marks.size() > 24:
		marks.pop_front()
	var jobs := get_node_or_null("/root/Jobs")
	if jobs != null and jobs.has_method("mark_dig"):
		jobs.mark_dig(r)
	else:
		Events.dig_marked.emit(r)
	Events.spell_cast.emit(id, Sim.cell_center(r.get_center()))


func _draw() -> void:
	# standing orders, drawn faintly while this tool is in hand
	if necro != null and necro.get_selected() == self:
		for r in marks:
			var px := Rect2(Sim.to_pixel(r.position), Vector2(r.size) * Sim.CELL)
			draw_rect(px, Color(color, 0.07))
			draw_rect(px, Color(color, 0.3), false, 1.0)
	super._draw()
