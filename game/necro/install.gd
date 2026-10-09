extends RefCounted
## Puts the necromancer into a run (see "How a run is assembled" in docs/ARCHITECTURE.md).
## Runs after World, Art, Lair and Flesh; sets main.player so the camera follows him.
## Returns nothing: adding keys to `info` would hide an empty world from main's fallback ground.

const NecromancerScript := preload("res://necro/necromancer.gd")


func install(main: Main, info: Dictionary) -> Variant:
	var necro: Necromancer = NecromancerScript.new()
	necro.position = info.get("necro_spawn", Sim.world_size_px() * 0.5)
	main.actors.add_child(necro)
	main.player = necro
	# Wait until every installer (and main's fallback world) has run, then settle him on the ground.
	# (main.info is the same Dictionary the fallback world writes into.)
	necro.settle_at_spawn.call_deferred(main.info)
	return null
