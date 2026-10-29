extends RefCounted
## Suspicion and Patrols installer: starts the Threats director, adds patrols, the stench haze and the F3 overlay.

func install(main: Node, info: Dictionary) -> Variant:
	Threats.begin_run(info)
	var patrols = load("res://threats/patrols.gd").new()
	patrols.name = "Patrols"
	var actors: Node = main.get("actors") if main.get("actors") != null else main
	actors.add_child(patrols)
	var haze = load("res://threats/stench_view.gd").new()
	haze.name = "StenchHaze"
	var fx: Node = main.get("fx") if main.get("fx") != null else main
	fx.add_child(haze)
	var overlay = load("res://threats/debug_overlay.gd").new()
	overlay.name = "ThreatsOverlay"
	var ui: Node = main.get("ui") if main.get("ui") != null else main
	ui.add_child(overlay)
	return {}
