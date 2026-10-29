class_name NecroText
extends RefCounted
## Player-facing words go through Narrative (the Eyegor department writes them). Until a key has words,
## Narrative.line() hands the key back, so we show a plain fallback instead of "spell_dig".


static func t(key: String, fallback: String, args: Dictionary = {}) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var narrative: Node = tree.root.get_node_or_null("Narrative") if tree != null else null
	if narrative == null:
		return fallback.format(args)
	var s: String = narrative.line(key, args)
	if s == key or s.is_empty():
		return fallback.format(args)
	return s
