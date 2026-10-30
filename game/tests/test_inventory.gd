extends RefCounted
## The shared satchel: add, count, take a whole recipe or nothing, cap.

func run(t) -> void:
	GameState.reset()
	t.check(GameState.item_count(&"flesh") == 0.0, "starts empty")
	t.check(is_equal_approx(GameState.add_item(&"flesh", 5.0), 5.0), "adds flesh")
	GameState.add_item(&"bones", 2.0)
	t.check(not GameState.take_items({&"flesh": 4.0, &"bones": 3.0}), "refuses a recipe it can't cover")
	t.check(is_equal_approx(GameState.item_count(&"flesh"), 5.0), "a refused recipe takes nothing")
	t.check(GameState.take_items({&"flesh": 4.0, &"bones": 2.0}), "takes a recipe it can cover")
	t.check(is_equal_approx(GameState.item_count(&"flesh"), 1.0) and GameState.item_count(&"bones") == 0.0, "counts drop by the recipe")
	var fit := GameState.add_item(&"blood", GameState.INVENTORY_CAP + 10.0)
	t.check(is_equal_approx(fit, GameState.INVENTORY_CAP), "stops at the cap")
	GameState.reset()
	t.check(GameState.inventory.is_empty(), "reset empties it")
