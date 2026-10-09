class_name NecroSpell
extends Node2D
## Base for the necromancer's spells. A spell is a tool: picked from the spell list, aimed with the mouse
## or the right stick, and paid for in mana (souls' worth). The necromancer owns one of each as a child.
##
## The necromancer calls tick() on the selected spell once per physics tick with the aim point and the
## cast button state. Spells draw themselves in world space (this node is top_level), with a second
## additive layer for glow so beams and wind shine in the dark.

const TEAL := Color(0.36, 0.95, 0.82) ## necromancy: the necromancer's signature glow
const TEAL_DIM := Color(0.18, 0.55, 0.5)

var necro: Node2D ## the Necromancer that owns this spell
var id: StringName = &"spell"
var title := "Spell" ## fallback name; Narrative key "spell.<id>" overrides it
var color := TEAL
var channelling := false ## true on ticks the spell is actually working (the necromancer shows his cast pose)

var _glow: Node2D
var _parts: Array = [] ## small FX particles: {p, v, life, max, col, glow, size}


func setup(owner_necro: Node2D) -> void:
	necro = owner_necro
	top_level = true
	z_as_relative = false
	z_index = 20
	global_position = Vector2.ZERO
	_glow = Node2D.new()
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## Called every physics tick while this spell is selected.
## held: cast button is down. pressed/released: it went down/up this tick.
func tick(_aim: Vector2, _held: bool, _pressed: bool, _released: bool) -> void:
	pass


## The alternate button (right mouse / left trigger). Tools with a sub-choice cycle it here.
func alt_pressed() -> void:
	pass


func on_select() -> void:
	pass


func on_deselect() -> void:
	channelling = false


## Shown in the spell list, e.g. "0.10 souls/s".
func cost_text() -> String:
	return ""


## Extra line for the HUD: the building or stockpile kind picked, or why the cast is refused.
func detail() -> String:
	return ""


func display_name() -> String:
	return NecroText.t("spell." + String(id), title)


# ---------------------------------------------------------------- FX particles

func emit_part(p: Vector2, v: Vector2, col: Color, life: int, glow := false, size := 2.0) -> void:
	if _parts.size() > 600:
		return
	_parts.append({"p": p, "v": v, "life": life, "max": life, "col": col, "glow": glow, "size": size})


func _physics_process(_delta: float) -> void:
	var keep := []
	for q in _parts:
		q.life -= 1
		if q.life <= 0:
			continue
		q.p += q.v
		q.v *= 0.94
		keep.append(q)
	_parts = keep


func _process(_delta: float) -> void:
	queue_redraw()
	if _glow:
		_glow.queue_redraw()


func _draw() -> void:
	for q in _parts:
		if q.glow:
			continue
		var c: Color = q.col
		c.a *= clampf(float(q.life) / float(q.max) * 1.5, 0.0, 1.0)
		draw_rect(Rect2(q.p - Vector2.ONE * q.size * 0.5, Vector2.ONE * q.size), c)


## Override to draw glowing things; call super to keep glowing particles.
func _draw_glow() -> void:
	for q in _parts:
		if not q.glow:
			continue
		var c: Color = q.col
		c.a *= clampf(float(q.life) / float(q.max) * 1.5, 0.0, 1.0)
		_glow.draw_rect(Rect2(q.p - Vector2.ONE * q.size * 0.5, Vector2.ONE * q.size), c)


func glow_line(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	_glow.draw_line(a, b, col, width)


func glow_circle(at: Vector2, r: float, col: Color) -> void:
	_glow.draw_circle(at, r, col)
