extends RefCounted
## Eyegor and HUD installer: the HUD (with Eyegor's panel), the hidden-start objectives, the commentary
## listener, and the title/pause menus on main's UI layer. Runs last.

const INSTALL := {
	"show_title": true, ## false skips the title overlay (tests, quick iteration)
}


func install(main: Node, _info: Dictionary) -> Variant:
	var ui: Node = main.get("ui") if main != null else null
	if ui == null:
		ui = CanvasLayer.new()
		ui.name = "UI"
		main.add_child(ui)
	var objectives := EyegorObjectives.new()
	objectives.name = "Objectives"
	main.add_child(objectives)
	var commentary := EyegorCommentary.new()
	commentary.name = "Commentary"
	main.add_child(commentary)
	var hud := EyegorHUD.new()
	hud.name = "HUD"
	hud.objectives = objectives
	ui.add_child(hud)
	var menus := EyegorMenus.new()
	menus.name = "Menus"
	ui.add_child(menus)
	menus.begun.connect(objectives.start)
	if INSTALL.show_title and DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-title"):
		menus.show_title()
	else:
		objectives.start()
	return {"hud": hud, "objectives": objectives}
