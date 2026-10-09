extends NecroRectTool
## Designate stockpile: paint a rectangle inside a dug-out hollow for one resource; ghouls fill and
## empty it (Jobs.designate_stockpile). The alternate button picks the resource: flesh pit (gibs),
## ossuary (bones), corpse pile.

const STOCKPILE := {
	"kinds": [&"gibs", &"bones", &"corpses"],
	"min_open": 0.8, # share of the rectangle that must already be dug out (air)
	"colors": {&"gibs": Color(0.75, 0.3, 0.3), &"bones": Color(0.85, 0.8, 0.65), &"corpses": Color(0.55, 0.6, 0.5)},
	"cost": 0.0,
}

var kind_index := 0
var zones: Array = [] ## [{rect: Rect2i, kind}]


func _init() -> void:
	id = &"stockpile"
	title = "Stockpile"
	color = STOCKPILE.colors[&"gibs"]


func current_kind() -> StringName:
	return STOCKPILE.kinds[posmod(kind_index, STOCKPILE.kinds.size())]


func cycle() -> void:
	kind_index += 1
	color = STOCKPILE.colors.get(current_kind(), color)
	Events.spell_selected.emit(id)


func cost_text() -> String:
	return NecroText.t("spell.command_cost", "order")


func detail() -> String:
	return NecroText.t("stockpile." + String(current_kind()), {&"gibs": "Flesh pit", &"bones": "Ossuary", &"corpses": "Corpse pile"}.get(current_kind(), String(current_kind())))


## Most of it must be open air: you dig the hollow first, then paint it.
func rect_ok(r: Rect2i) -> bool:
	if Sim.world == null or r.size.x * r.size.y <= 0:
		return false
	var counts := Sim.world.count_rect(r.position.x, r.position.y, r.size.x, r.size.y)
	var open := 0
	for m in counts:
		if SandWorld.mat_kind(m) == 0 or SandWorld.mat_kind(m) == 4:
			open += counts[m]
	return open >= r.size.x * r.size.y * STOCKPILE.min_open


func commit(r: Rect2i) -> void:
	if not rect_ok(r):
		Narrative.say(NecroText.t("necro.stockpile_needs_hollow", "Dig the hollow out first, boss. Then we paint it."), &"concerned")
		return
	var k := current_kind()
	zones.append({"rect": r, "kind": k})
	var jobs := get_node_or_null("/root/Jobs")
	if jobs != null and jobs.has_method("designate_stockpile"):
		jobs.designate_stockpile(r, k)
	else:
		Events.stockpile_designated.emit(r, k)
	Events.spell_cast.emit(id, Sim.cell_center(r.get_center()))


func _draw() -> void:
	if necro != null and necro.get_selected() == self:
		for z in zones:
			var r: Rect2i = z.rect
			var px := Rect2(Sim.to_pixel(r.position), Vector2(r.size) * Sim.CELL)
			var c: Color = STOCKPILE.colors.get(z.kind, color)
			draw_rect(px, Color(c, 0.08))
			draw_rect(px, Color(c, 0.35), false, 1.0)
	super._draw()
