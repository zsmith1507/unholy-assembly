class_name LairSpikeTrap
extends LairStructure
## A plank of spikes. Anything living that steps on it is skewered; it re-arms after a while.

const TRAP := {
	"footprint": Vector2(24, 10),
	"damage": 120.0,
	"rearm_s": 6.0,
	"noise": 0.3,
	"blood": 30,
}

var armed := true
var _rearm := 0.0


func _init() -> void:
	kind = &"spike_trap"
	footprint = TRAP.footprint


func _physics_process(delta: float) -> void:
	if not armed:
		_rearm -= delta
		if _rearm <= 0.0:
			armed = true
			queue_redraw()
		return
	var r := get_rect()
	for a in get_tree().get_nodes_in_group(&"actors"):
		if not (a is Actor) or a.dead or not a.is_living():
			continue
		if r.has_point(a.global_position - Vector2(0, 1)):
			a.take_damage(float(TRAP.damage), self)
			armed = false
			_rearm = float(TRAP.rearm_s)
			Events.noise_made.emit(global_position, float(TRAP.noise), "spike_trap")
			Sim.spill_px(global_position + Vector2(0, -6), SandWorld.M_BLOOD, int(TRAP.blood), Vector2(0, -2))
			GameState.count("trap_kills")
			queue_redraw()
			break


func _draw() -> void:
	if sprite != null:
		return
	var w := footprint.x
	draw_rect(Rect2(-w * 0.5, -2, w, 2), Color("4d3220"))
	var h := 8.0 if armed else 3.0
	var x := -w * 0.5 + 1
	while x < w * 0.5 - 2:
		draw_colored_polygon(PackedVector2Array([Vector2(x, -2), Vector2(x + 3, -2), Vector2(x + 1.5, -2 - h)]), Color("8a8a90"))
		x += 4
