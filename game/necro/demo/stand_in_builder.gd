extends Node2D
## A stand-in for the Lair department's builder, used only by the necro demo and tests so the Build
## spell has something to talk to before the real one lands. Same hook shape as docs/ARCHITECTURE.md.
## In a real run the Lair installer adds the real builder and this file is never loaded.

const StandInHeart := preload("res://necro/demo/stand_in_heart.gd")

const COST := {
	&"heart": {"mana": 0.25},
	&"grinder": {"mana": 0.2, "souls": 0.0},
	&"stitching_table": {"mana": 0.2},
	&"altar": {"mana": 0.3},
	&"spike_trap": {"mana": 0.1},
}

var placed: Array = [] ## [{kind, at, node}]
var calls := {"can_place": 0, "place": 0} ## tests read this


func _ready() -> void:
	add_to_group("lair_builder")


func kinds() -> Array[StringName]:
	return [&"heart", &"grinder", &"stitching_table", &"altar", &"spike_trap"]


func cost(kind: StringName) -> Dictionary:
	return COST.get(kind, {})


func footprint(kind: StringName) -> Vector2:
	var s: Array = ArtLib.SIZES.get(String(kind), [32, 32])
	return Vector2(s[0], s[1])


## Fits when the footprint is open air and there is ground under its feet.
func can_place(kind: StringName, at: Vector2) -> bool:
	calls.can_place += 1
	if kind == &"heart" and GameState.has_heart:
		return false
	var fp := footprint(kind)
	var x0 := at.x - fp.x * 0.5
	for y in range(int(at.y - fp.y) + 2, int(at.y) - 1, 4):
		for x in range(int(x0) + 2, int(x0 + fp.x) - 1, 4):
			if Sim.solid_at(Vector2(x, y)):
				return false
	var ground := 0
	for x in range(int(x0) + 2, int(x0 + fp.x) - 1, 4):
		if Sim.solid_at(Vector2(x, at.y + 1)):
			ground += 1
	return ground >= 2


func place(kind: StringName, at: Vector2) -> Node2D:
	calls.place += 1
	if not can_place(kind, at):
		return null
	var n := Node2D.new()
	if kind == &"heart":
		n.set_script(StandInHeart)
	n.name = String(kind).capitalize().replace(" ", "")
	n.position = at
	n.add_child(ArtLib.make_sprite(String(kind)))
	add_child(n)
	placed.append({"kind": kind, "at": at, "node": n})
	if kind == &"heart":
		GameState.set_heart(n, 160.0)
	Events.machine_built.emit(n)
	return n
