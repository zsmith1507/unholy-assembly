extends RefCounted
## The hidden start played through on the real generated world with every department's real nodes
## (see tests/hidden_start.gd for the steps). Each step is one check.

const TEST_TIMEOUT_S := 900.0
const HiddenStart := preload("res://tests/hidden_start.gd")
const PLAY_SEED := 1507


func run(t) -> void:
	Jobs.reset()
	seed(PLAY_SEED)
	var main = load("res://main/main.tscn").instantiate()
	t.root.add_child(main)
	var play = HiddenStart.new(t, main)
	await play.play()
