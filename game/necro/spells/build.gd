extends NecroSpell
## Build: raise a lair structure where he points. A ghost of the structure follows the aim, green where
## the Lair department says it fits and red where it doesn't. Cast places it and pays its cost; the
## alternate button cycles what to build. With a gamepad the ghost snaps to a grid.
##
## Uses the Lair builder hook: the node in group "lair_builder" with kinds(), can_place(kind, at),
## place(kind, at) -> Node2D, cost(kind) -> {"mana": x, "souls": y}. `at` is the structure's feet:
## the middle of its bottom edge, like every other thing in the game.
## The necrotic heart comes first and there is only one; until it stands, it's all he can build.

const BUILD := {
	"grid_px": 16.0, # gamepad snap grid
	"floor_search_px": 72.0, # the ghost drops onto ground up to this far below the aim
	"range_px": 220.0, # can't build farther than this from him
	"order": [&"heart", &"grinder", &"stitching_table", &"altar", &"spike_trap"],
	"ghost_ok": Color(0.35, 1.0, 0.55, 0.45),
	"ghost_bad": Color(1.0, 0.25, 0.25, 0.45),
	"fallback_size": Vector2(32, 32),
}

var kind_index := 0
var ghost_at := Vector2.ZERO
var ghost_ok := false
var ghost_reason := ""
var last_placed: Node2D = null
var _show := false


func _init() -> void:
	id = &"build"
	title = "Build"
	color = Color(0.55, 0.85, 1.0)


func builder() -> Node:
	return get_tree().get_first_node_in_group("lair_builder") if is_inside_tree() else null


## What can be built right now, in list order. Only the heart until it stands; never a second heart.
func available_kinds() -> Array:
	var b := builder()
	var kinds: Array = []
	if b != null and b.has_method("kinds"):
		kinds = b.kinds()
	else:
		kinds = BUILD.order.duplicate()
	var out: Array = []
	for k in BUILD.order:
		if kinds.has(k):
			out.append(k)
	for k in kinds:
		if not out.has(k):
			out.append(k)
	if not GameState.has_heart:
		return [&"heart"] if out.has(&"heart") else out
	out.erase(&"heart")
	return out


func current_kind() -> StringName:
	var ks := available_kinds()
	if ks.is_empty():
		return &""
	return ks[posmod(kind_index, ks.size())]


func alt_pressed() -> void:
	kind_index += 1
	Events.spell_selected.emit(id) # HUD refreshes the detail line


func cost_text() -> String:
	return _cost_string(current_kind())


func detail() -> String:
	var k := current_kind()
	if k == &"":
		return NecroText.t("necro_build_nothing", "Nothing to build")
	var s := NecroText.t("build_" + String(k), String(k).capitalize())
	if _show and not ghost_ok and ghost_reason != "":
		s += " - " + ghost_reason
	return s


func _cost(k: StringName) -> Dictionary:
	var b := builder()
	if b != null and b.has_method("cost"):
		return b.cost(k)
	return {}


func _cost_string(k: StringName) -> String:
	var c := _cost(k)
	var parts := []
	if c.get("mana", 0.0) > 0.0:
		parts.append(NecroText.t("necro_cost_mana", "{c} mana", {"c": "%.2f" % c.mana}))
	if c.get("souls", 0.0) > 0.0:
		parts.append(NecroText.t("necro_cost_souls", "{c} souls", {"c": "%.2g" % c.souls}))
	return ", ".join(parts) if not parts.is_empty() else NecroText.t("necro_free", "free")


func footprint(k: StringName) -> Vector2:
	var b := builder()
	if b != null and b.has_method("footprint"):
		return b.footprint(k)
	var s: Array = ArtLib.SIZES.get(String(k), [])
	return Vector2(s[0], s[1]) if s.size() >= 2 else BUILD.fallback_size


func on_select() -> void:
	_show = true


func on_deselect() -> void:
	super.on_deselect()
	_show = false


func tick(aim: Vector2, _held: bool, pressed: bool, _released: bool) -> void:
	channelling = false
	_show = true
	var k := current_kind()
	ghost_at = _ghost_position(aim, k)
	ghost_ok = _check(k, ghost_at)
	if pressed:
		try_place(k, ghost_at)


## Snap to the grid on a gamepad, then settle the feet onto the ground below.
func _ghost_position(aim: Vector2, k: StringName) -> Vector2:
	var p := aim
	if necro.gamepad_aim:
		p = (p / BUILD.grid_px).round() * BUILD.grid_px
	var fp := footprint(k)
	var hit = Sim.raycast_px(p, p + Vector2(0, BUILD.floor_search_px))
	if hit != null:
		p.y = floorf((hit as Vector2).y / Sim.CELL) * Sim.CELL
	else:
		p.y += fp.y * 0.5
	return p


func _check(k: StringName, at: Vector2) -> bool:
	ghost_reason = ""
	if k == &"":
		return false
	if at.distance_to(necro.global_position) > BUILD.range_px:
		ghost_reason = NecroText.t("necro_build_too_far", "too far")
		return false
	var b := builder()
	if b == null:
		ghost_reason = NecroText.t("necro_build_no_builder", "no lair yet")
		return false
	if b.has_method("can_place") and not b.can_place(k, at):
		ghost_reason = NecroText.t("necro_build_blocked", "won't fit here")
		return false
	var c := _cost(k)
	if GameState.mana + 0.0001 < float(c.get("mana", 0.0)):
		ghost_reason = NecroText.t("necro_build_need_mana", "not enough mana")
		return false
	if GameState.souls + 0.0001 < float(c.get("souls", 0.0)):
		ghost_reason = NecroText.t("necro_build_need_souls", "not enough souls")
		return false
	return true


## Place a structure through the builder and pay for it. Returns the new node or null.
func try_place(k: StringName, at: Vector2) -> Node2D:
	if not _check(k, at):
		if ghost_reason == NecroText.t("necro_build_need_mana", "not enough mana"):
			necro.warn_no_mana()
		return null
	var b := builder()
	var node: Node2D = b.place(k, at)
	if node == null:
		return null
	var c := _cost(k)
	if float(c.get("mana", 0.0)) > 0.0:
		GameState.spend_mana(float(c.mana))
	if float(c.get("souls", 0.0)) > 0.0:
		GameState.spend_souls(float(c.souls))
	last_placed = node
	Events.spell_cast.emit(id, at)
	for i in 14:
		emit_part(at + Vector2(randf_range(-16, 16), randf_range(-24, 0)), Vector2(randf_range(-0.6, 0.6), randf_range(-1.4, -0.3)), TEAL, randi_range(16, 30), true, 1.5)
	if k == &"heart":
		kind_index = 0
	return node


func _draw() -> void:
	super._draw()
	if not _show or necro == null or necro.get_selected_spell() != id:
		return
	var k := current_kind()
	if k == &"":
		return
	var fp := footprint(k)
	var col: Color = BUILD.ghost_ok if ghost_ok else BUILD.ghost_bad
	var rect := Rect2(ghost_at - Vector2(fp.x * 0.5, fp.y), fp)
	var tex: Texture2D = null
	var sf := ArtLib.frames(String(k))
	if sf != null and sf.has_animation(&"idle") and sf.get_frame_count(&"idle") > 0:
		tex = sf.get_frame_texture(&"idle", 0)
	if tex != null:
		draw_texture_rect(tex, rect, false, col)
	else:
		draw_rect(rect, col)
	draw_rect(rect, Color(col, 0.9), false, 1.0)
