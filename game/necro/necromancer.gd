class_name Necromancer
extends Actor
## The player. He never lifts a shovel: his spells are his tools, picked like tools in a builder game and
## paid for in mana (souls' worth, GameState.mana). Moves with Noita's feel on the sand world: walk, a small
## jump, a short levitation with a recharging meter, swimming up and diving in liquids.
##
## Hooks he provides (docs/ARCHITECTURE.md): get_spells(), get_selected_spell(), get_interact_hint(),
## get_levitation() for the HUD, and Events.spell_selected / Events.spell_cast.

const SpellDig := preload("res://necro/spells/dig.gd")
const SpellHarvest := preload("res://necro/spells/harvest.gd")
const SpellSiphon := preload("res://necro/spells/siphon.gd")
const SpellBuild := preload("res://necro/spells/build.gd")
const SpellCommandDig := preload("res://necro/spells/command_dig.gd")
const SpellStockpile := preload("res://necro/spells/stockpile.gd")

## Movement tuning. Pixels and ticks (60 a second). Ported from the proving ground, scaled to a 64 px body.
const MOVE := {
	"walk_speed": 1.75, # pixels per tick on the ground (about 105 px/s)
	"air_speed": 1.6, # steering while airborne
	"accel": 0.3, # share of the gap to target speed closed each tick on the ground
	"air_accel": 0.12,
	"gravity": 0.38, # pixels per tick per tick
	"max_fall": 8.0,
	"jump_speed": 4.6, # a short Noita hop; levitation does the rest
	"coyote_ticks": 5, # you can still jump this many ticks after walking off a ledge
	"jump_buffer_ticks": 6, # a jump pressed this many ticks before landing still counts
	"step_height": 8.0, # walks up ledges this high without jumping
	"box": Vector2(14, 58), # collision box; the sprite is 20 x 64
	"fast_fall": 0.2, # extra gravity while holding down in the air
}

## Levitation: hold jump in the air to rise while the meter lasts. Refills on the ground.
const LEVITATE := {
	"thrust": 0.62, # upward push per tick while levitating (gravity is 0.38)
	"max_rise": 2.6, # fastest upward speed while levitating, px per tick
	"duration": 1.4, # seconds of levitation in a full meter
	"recharge": 1.0, # seconds to refill an empty meter while standing on the ground
	"delay_ticks": 8, # after a ground jump, levitation starts this many ticks later (keeps the hop crisp)
}

## Swimming in blood, water, ichor and the rest.
const SWIM := {
	"wet": 0.35, # share of the body under liquid that counts as swimming
	"up": 0.55, # jump: swim upward
	"max_up": 2.4,
	"dive": 0.35, # down: dive
	"speed": 1.1, # horizontal speed while swimming
	"hop_out": 4.2, # jump at the surface to climb out onto a bank
}

## Aiming.
const AIM := {
	"stick_reach": 110.0, # right stick puts the aim this far from the hand
	"hand": Vector2(9, -40), # hand position relative to the feet, facing right
	"reticle": Color(0.36, 0.95, 0.82, 0.8),
}

## Interacting with the heart, the altar and other lair pieces.
const INTERACT := {
	"radius": 24.0, # pixels from his body to the thing's edge
}

const MANA_WARN_EVERY := 300 ## ticks between "out of mana" nags

## Order of the spell list (spell_1 .. spell_6).
var spells: Array = []
var selected := 0
var gamepad_aim := false ## true when the right stick was the last thing used to aim

## Tests and demo drivers fill this to play him without real input:
## {move: Vector2, jump: bool, cast: bool, cast_alt: bool, interact: bool, aim: Vector2 (world px)}
var scripted := false
var script_input := {}

var aim := Vector2.ZERO ## world position of the aim point
var levitation := 1.0 ## 0..1 meter
var casting := false
var anim_state: StringName = &"idle"

var _sprite: AnimatedSprite2D
var _hand_light: Node = null
var _coyote := 0
var _jump_buffer := 0
var _since_jump := 99
var _was_cast := false
var _was_alt := false
var _was_interact := false
var _was_jump := false
var _aim_dir := Vector2.RIGHT
var _mana_warned := -MANA_WARN_EVERY
var _ticks := 0
var _last_mouse := Vector2.INF


func _init() -> void:
	faction = Faction.NECRO
	display_name = "The Necromancer"
	max_hp = 100.0


func _ready() -> void:
	super._ready()
	name = "Necromancer"
	box_size = MOVE.box
	gravity = MOVE.gravity
	max_fall = MOVE.max_fall
	step_height = MOVE.step_height
	add_to_group("player")
	_sprite = ArtLib.make_sprite("necromancer")
	_sprite.name = "Sprite"
	add_child(_sprite)
	for script in [SpellDig, SpellHarvest, SpellSiphon, SpellBuild, SpellCommandDig, SpellStockpile]:
		var s: NecroSpell = script.new()
		add_child(s)
		s.setup(self)
		spells.append(s)
	aim = global_position + Vector2(60, -30)
	_attach_light.call_deferred()
	spells[selected].on_select()


func _attach_light() -> void:
	var lighting := get_tree().get_first_node_in_group("lighting")
	if lighting != null and lighting.has_method("add_light"):
		_hand_light = lighting.add_light(self, NecroSpell.TEAL, 70.0, 0.6)
		if _hand_light is Node2D:
			_hand_light.position = AIM.hand


# ---------------------------------------------------------------- hooks for the HUD

## The spell list: [{id, name, cost_text, color}], in hotkey order.
func get_spells() -> Array:
	var out := []
	for s in spells:
		out.append({"id": s.id, "name": s.display_name(), "cost_text": s.cost_text(), "color": s.color, "detail": s.detail()})
	return out


func get_selected_spell() -> StringName:
	return spells[selected].id


func get_selected() -> NecroSpell:
	return spells[selected]


func get_spell(spell_id: StringName) -> NecroSpell:
	for s in spells:
		if s.id == spell_id:
			return s
	return null


## Levitation meter 0..1, for a HUD bar.
func get_levitation() -> float:
	return levitation


func select_spell(index: int) -> void:
	index = posmod(index, spells.size())
	if index == selected:
		return
	spells[selected].on_deselect()
	selected = index
	spells[selected].on_select()
	Events.spell_selected.emit(spells[selected].id)


func select_spell_id(spell_id: StringName) -> void:
	for i in spells.size():
		if spells[i].id == spell_id:
			select_spell(i)
			return


## What pressing interact would do right now, or "" when nothing is in reach.
func get_interact_hint() -> String:
	var n := nearest_interactable()
	if n == null:
		return ""
	return n.interact_hint() if n.has_method("interact_hint") else ""


func nearest_interactable() -> Node2D:
	var best: Node2D = null
	var best_d := INTERACT.radius
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node2D) or not n.has_method("interact"):
			continue
		var d := _distance_to_thing(n)
		if d <= best_d:
			best_d = d
			best = n
	return best


func interact() -> bool:
	var n := nearest_interactable()
	if n == null:
		return false
	n.interact(self)
	return true


# ---------------------------------------------------------------- positions

func get_hand_pos() -> Vector2:
	return global_position + Vector2(AIM.hand.x * facing, AIM.hand.y)


func get_center() -> Vector2:
	return global_position - Vector2(0, box_size.y * 0.5)


## Distance from his body box to a node: to its box if it has one, else to its position.
func _distance_to_thing(n: Node2D) -> float:
	var me := get_box()
	var r := Rect2(n.global_position, Vector2.ZERO)
	if n.has_method("get_box"):
		r = n.get_box()
	elif n.has_method("get_rect_px"):
		r = n.get_rect_px()
	# gap between two rectangles (0 when they overlap)
	var dx := maxf(0.0, maxf(r.position.x - me.end.x, me.position.x - r.end.x))
	var dy := maxf(0.0, maxf(r.position.y - me.end.y, me.position.y - r.end.y))
	return Vector2(dx, dy).length()


# ---------------------------------------------------------------- input

func _input_state() -> Dictionary:
	if scripted:
		return {
			"move": script_input.get("move", Vector2.ZERO),
			"jump": script_input.get("jump", false),
			"cast": script_input.get("cast", false),
			"cast_alt": script_input.get("cast_alt", false),
			"interact": script_input.get("interact", false),
		}
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"jump": Input.is_action_pressed("jump"),
		"cast": Input.is_action_pressed("cast"),
		"cast_alt": Input.is_action_pressed("cast_alt"),
		"interact": Input.is_action_pressed("interact"),
	}


func _update_aim() -> void:
	if scripted:
		aim = script_input.get("aim", aim)
		_aim_dir = (aim - get_hand_pos()).normalized() if aim != get_hand_pos() else _aim_dir
		return
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var mouse := get_global_mouse_position()
	var screen_mouse := get_viewport().get_mouse_position()
	if stick.length() > 0.2:
		gamepad_aim = true
		_aim_dir = stick.normalized()
	elif screen_mouse != _last_mouse and _last_mouse != Vector2.INF:
		gamepad_aim = false
	_last_mouse = screen_mouse
	if gamepad_aim:
		var reach: float = AIM.stick_reach * clampf(stick.length(), 0.35, 1.0) if stick.length() > 0.2 else AIM.stick_reach * 0.6
		aim = get_hand_pos() + _aim_dir * reach
	else:
		aim = mouse
		_aim_dir = (aim - get_hand_pos()).normalized()


func _unhandled_input(event: InputEvent) -> void:
	if scripted:
		return
	if event.is_action_pressed("spell_next"):
		select_spell(selected + 1)
	elif event.is_action_pressed("spell_prev"):
		select_spell(selected - 1)
	else:
		for i in mini(8, spells.size()):
			if event.is_action_pressed("spell_%d" % (i + 1)):
				select_spell(i)
				break


# ---------------------------------------------------------------- the tick

func _physics_process(_delta: float) -> void:
	if dead:
		return
	_ticks += 1
	var inp := _input_state()
	_update_aim()
	_move(inp)
	_unbury()

	# spells
	var cast: bool = inp.cast
	var alt: bool = inp.cast_alt
	var spell: NecroSpell = spells[selected]
	if alt and not _was_alt:
		spell.alt_pressed()
	spell.tick(aim, cast, cast and not _was_cast, (not cast) and _was_cast)
	casting = spell.channelling
	_was_cast = cast
	_was_alt = alt

	# interact
	var inter: bool = inp.interact
	if inter and not _was_interact:
		interact()
	_was_interact = inter

	_update_facing(inp)
	_update_anim()
	queue_redraw()


func _move(inp: Dictionary) -> void:
	var move: Vector2 = inp.move
	var jump: bool = inp.jump
	var jump_pressed := jump and not _was_jump
	_was_jump = jump
	var swimming := submerged >= SWIM.wet
	_since_jump += 1

	# horizontal
	var target := move.x * (SWIM.speed if swimming else (MOVE.walk_speed if on_floor else MOVE.air_speed))
	var accel: float = MOVE.accel if on_floor or swimming else MOVE.air_accel
	velocity.x += (target - velocity.x) * accel

	# jumping, with a little forgiveness either side of the ledge
	_coyote = MOVE.coyote_ticks if on_floor else _coyote - 1
	_jump_buffer = MOVE.jump_buffer_ticks if jump_pressed else _jump_buffer - 1
	if swimming:
		if jump:
			velocity.y = maxf(velocity.y - SWIM.up, -SWIM.max_up)
		if move.y > 0.5:
			velocity.y += SWIM.dive
		# at the surface with ground ahead: hop out onto the bank
		if jump_pressed and submerged < 0.75:
			velocity.y = -SWIM.hop_out
	elif _jump_buffer > 0 and _coyote > 0:
		velocity.y = -MOVE.jump_speed
		_coyote = 0
		_jump_buffer = 0
		_since_jump = 0
	elif jump and not on_floor and levitation > 0.0 and _since_jump >= LEVITATE.delay_ticks:
		# Noita's levitation: hold jump in the air
		velocity.y = maxf(velocity.y - LEVITATE.thrust, -LEVITATE.max_rise)
		levitation = maxf(0.0, levitation - 1.0 / (LEVITATE.duration * 60.0))
	if not jump and not on_floor and not swimming and move.y > 0.5:
		velocity.y += MOVE.fast_fall

	if on_floor or swimming:
		levitation = minf(1.0, levitation + 1.0 / (LEVITATE.recharge * 60.0))
	move_tick()


## Falling dirt landed on him: shoulder up out of it rather than getting stuck.
func _unbury() -> void:
	if Sim.world == null or not _box_blocked(position):
		return
	for up in range(1, 9):
		if not _box_blocked(position - Vector2(0, up)):
			position.y -= up
			return


func _update_facing(inp: Dictionary) -> void:
	var move: Vector2 = inp.move
	if casting or (not gamepad_aim and not scripted):
		var dx := aim.x - global_position.x
		if absf(dx) > 2.0:
			facing = 1 if dx > 0 else -1
	elif absf(move.x) > 0.2:
		facing = 1 if move.x > 0 else -1
	elif scripted and absf(aim.x - global_position.x) > 2.0:
		facing = 1 if aim.x > global_position.x else -1


func _update_anim() -> void:
	var a: StringName
	if submerged >= SWIM.wet:
		a = &"swim"
	elif casting:
		a = &"cast"
	elif not on_floor:
		a = &"jump" if velocity.y < 0 else &"fall"
	elif absf(velocity.x) > 0.25:
		a = &"walk"
	else:
		a = &"idle"
	anim_state = a
	if _sprite == null:
		return
	_sprite.flip_h = facing < 0
	if _sprite.sprite_frames.has_animation(a) and _sprite.animation != a:
		_sprite.play(a)
	# placeholder art has one frame per animation; a little bob keeps him readable until real frames land
	var bob := 0.0
	if a == &"walk":
		bob = -absf(sin(_ticks * 0.25)) * 2.0
	elif a == &"swim":
		bob = sin(_ticks * 0.12) * 1.5
	_sprite.position = Vector2(0, bob)


## Called by spells when the bar is empty. Eyegor nags, but not every tick.
func warn_no_mana() -> void:
	if _ticks - _mana_warned < MANA_WARN_EVERY:
		return
	_mana_warned = _ticks
	Narrative.say(NecroText.t("necro.no_mana", "Mana's run dry, boss. A visit to the heart will top you up."), &"concerned")


# ---------------------------------------------------------------- drawing: aim reticle and hand glow

func _draw() -> void:
	var a := aim - global_position
	var c: Color = AIM.reticle
	if spells.size() > 0 and spells[selected].color != NecroSpell.TEAL:
		c = spells[selected].color
		c.a = 0.8
	draw_line(a + Vector2(-5, 0), a + Vector2(-2, 0), c, 1.0)
	draw_line(a + Vector2(2, 0), a + Vector2(5, 0), c, 1.0)
	draw_line(a + Vector2(0, -5), a + Vector2(0, -2), c, 1.0)
	draw_line(a + Vector2(0, 2), a + Vector2(0, 5), c, 1.0)
	var hand := Vector2(AIM.hand.x * facing, AIM.hand.y)
	var pulse := 0.6 + 0.4 * sin(_ticks * 0.15)
	draw_circle(hand, 2.5 if casting else 1.5, Color(0.6, 1.0, 0.9, 0.9 * pulse))
	# levitation meter: a thin bar under his feet, only while it is not full
	if levitation < 0.999:
		draw_rect(Rect2(-8, 3, 16, 2), Color(0.1, 0.1, 0.12, 0.7))
		draw_rect(Rect2(-8, 3, 16 * levitation, 2), Color(0.6, 0.85, 1.0, 0.85))
