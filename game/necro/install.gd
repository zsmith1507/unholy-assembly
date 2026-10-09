extends RefCounted
## Puts the necromancer into a run (see "How a run is assembled" in docs/ARCHITECTURE.md).
## Runs after World, Art, Lair and Flesh; sets main.player so the camera follows him.

const NecromancerScript := preload("res://necro/necromancer.gd")


func install(main: Main, info: Dictionary) -> Variant:
	var necro: Necromancer = NecromancerScript.new()
	var spawn: Vector2 = info.get("necro_spawn", Sim.world_size_px() * 0.5)
	necro.position = _safe_spawn(spawn)
	main.actors.add_child(necro)
	main.player = necro
	return {"necromancer": necro}


## World's spawn point is his feet; nudge up out of the ground if it is buried, or down onto it if floating.
func _safe_spawn(at: Vector2) -> Vector2:
	if Sim.world == null:
		return at
	var p := at
	for i in 200:
		if not Sim.solid_at(p - Vector2(0, 1)) and not Sim.solid_at(p - Vector2(0, 40)):
			break
		p.y -= Sim.CELL
	return p
