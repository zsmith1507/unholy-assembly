extends Node
## Eyegor's voice and every bit of flavour text (autoload `Narrative`). Owned by the Eyegor and HUD department.
## Other departments call these; they never hard-code player-facing strings of their own.

## Ask Eyegor to say something. mood: &"chipper", &"concerned", &"proud", &"memo".
func say(text: String, mood: StringName = &"chipper") -> void:
	Events.advisor_line.emit(text, mood)


## A line by key, e.g. line("heart_placed"). Unknown keys return the key itself so gaps are visible.
func line(key: String, args: Dictionary = {}) -> String:
	return key.format(args)


## Deadpan description of an item ("Left Arm, Slightly Used. Previous owner no longer requires it.").
func describe_item(kind: StringName, _data: Dictionary = {}) -> String:
	return String(kind).capitalize()


## Display name of a material id from the sim.
func material_name(mat: int) -> String:
	return SandWorld.mat_name(mat)
