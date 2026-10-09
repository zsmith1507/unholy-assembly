class_name NecroticHeart
extends LairStructure
## The necrotic heart: one per base. Its radius is where you can build and where tier 1-2 minions live on.
## Interacting refills the necromancer's mana by spending stored souls. Soul orbs (Bodies and Souls) drift here.

const HEART := {
	"radius_px": 260.0, # build range and the zone that sustains minions
	"glow_color": Color("2fd8c0"),
	"glow_radius_px": 120.0,
	"glow_energy": 1.1,
	"pulse_hz": 0.7, # heartbeats per second
}

var radius: float = HEART.radius_px
var _t := 0.0
var _light: Node = null


func _init() -> void:
	kind = &"heart"
	footprint = Vector2(40, 48)


func _ready() -> void:
	super()
	add_to_group(&"interactable")
	add_to_group(&"necrotic_heart")
	GameState.set_heart(self, radius)
	var lighting := Lair.lighting(get_tree())
	if lighting != null and lighting.has_method("add_light"):
		_light = lighting.add_light(self, HEART.glow_color, HEART.glow_radius_px, HEART.glow_energy)
		if _light is Node2D:
			(_light as Node2D).position = Vector2(0, -footprint.y * 0.5)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _light is PointLight2D:
		(_light as PointLight2D).energy = HEART.glow_energy * (0.85 + 0.15 * _beat())


func _beat() -> float:
	return pow(maxf(0.0, sin(_t * TAU * HEART.pulse_hz)), 6.0)


func _draw() -> void:
	# A soft teal glow and the range ring. The sprite itself comes from ArtLib.
	var c: Color = HEART.glow_color
	var mid := Vector2(0, -footprint.y * 0.5)
	if _light == null:
		var b := _beat()
		for i in 6:
			var rr: float = HEART.glow_radius_px * (0.25 + i * 0.13) * (1.0 + 0.05 * b)
			draw_circle(mid, rr, Color(c.r, c.g, c.b, 0.035 + 0.02 * b))
	draw_arc(mid, radius, 0.0, TAU, 96, Color(c.r, c.g, c.b, 0.12), 1.0)


func interact(_by: Node2D) -> void:
	if GameState.mana >= GameState.max_mana - 0.001:
		LairText.say("heart_refill_full", &"chipper")
		return
	if GameState.souls <= 0.0:
		LairText.say("heart_refill_empty", &"concerned")
		return
	var got := GameState.refill_mana_from_heart()
	LairText.say("heart_refill", &"chipper", {"souls": "%.2f" % got})


func interact_hint() -> String:
	return LairText.t("hint_heart", {"souls": "%.1f" % GameState.souls})


## Destroying the heart destroys everything linked to it: buildings, stockpiles, and the minions it sustains.
func destroy() -> void:
	for s in get_tree().get_nodes_in_group(&"lair_structures"):
		if s != self and is_instance_valid(s) and (s.get("heart") == self or s.get("heart") == null):
			s.destroy()
	for m in get_tree().get_nodes_in_group(&"minions"):
		if m.has_method("die") and m.get("tier") != null and int(m.tier) <= 2:
			m.die(self)
	var d := Lair.director(get_tree())
	if d != null and d.has_method("clear_stockpiles"):
		d.clear_stockpiles()
	for j in Jobs.all_jobs():
		Jobs.cancel(j.id)
	if GameState.heart == self:
		GameState.clear_heart()
	LairText.say("heart_destroyed", &"concerned")
	queue_free()
