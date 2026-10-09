class_name ArtLib
extends RefCounted
## Where every department gets its sprites. Owned by the Art and Lighting department.
## Until real art lands, each lookup returns a labelled placeholder of the right size, so other departments
## can wire sprites now and pick up the real art without changing their code.
##
## Characters face right; flip_h for left. Feet sit on the bottom edge, centred (offset is set for you).
## Standard animation names: idle, walk, run, jump, fall, cast, work, carry, hurt, die, swim.

## name -> [width, height, colour] for placeholders. Heights follow the design doc (~64 px characters).
const SIZES := {
	"necromancer": [20, 64, Color("4b3a5c")],
	"ghoul": [18, 52, Color("5a6b4a")],
	"rotling": [18, 56, Color("6b5a4a")],
	"farmer": [18, 60, Color("8a6a44")],
	"villager": [18, 60, Color("7a6450")],
	"rabbit": [12, 10, Color("8a7a66")],
	"crow": [12, 10, Color("2a2630")],
	"deer": [30, 34, Color("7a5a3a")],
	"pig": [22, 16, Color("b08070")],
	"chicken": [10, 12, Color("c8c0a8")],
	"eyegor": [40, 40, Color("d8d0b8")],
	"heart": [40, 48, Color("2f8a7e")],
	"grinder": [48, 48, Color("5a5048")],
	"stitching_table": [56, 32, Color("6a4a3a")],
	"altar": [48, 40, Color("3a3444")],
	"spike_trap": [24, 10, Color("8a8a90")],
	"soul_orb": [8, 8, Color("7fe8d8")],
}

static var _cache := {}


## SpriteFrames for a character or machine. Always valid: a placeholder when no art exists yet.
static func frames(sprite_name: String) -> SpriteFrames:
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var path := "res://art/sprites/%s.tres" % sprite_name
	var sf: SpriteFrames
	if ResourceLoader.exists(path):
		sf = load(path)
	else:
		sf = _placeholder_frames(sprite_name)
	_cache[sprite_name] = sf
	return sf


## Offset that puts a sprite's feet on its node's origin. Real art has the feet on the frame's bottom row.
static func feet_offset(sprite_name: String) -> Vector2:
	var sf := frames(sprite_name)
	if sf.has_animation(&"idle") and sf.get_frame_count(&"idle") > 0:
		var t := sf.get_frame_texture(&"idle", 0)
		if t:
			return Vector2(0, -t.get_height() * 0.5)
	var s: Array = SIZES.get(sprite_name, [16, 32, Color.MAGENTA])
	return Vector2(0, -s[1] * 0.5)


## The emissive layer (necrotic glow) for a sprite, or null. Same layout as frames(); draw it unshaded.
static func glow_frames(sprite_name: String) -> SpriteFrames:
	var key := sprite_name + "#glow"
	if _cache.has(key):
		return _cache[key]
	var path := "res://art/sprites/%s_glow.tres" % sprite_name
	var sf: SpriteFrames = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = sf
	return sf


## A ready-to-use AnimatedSprite2D with feet at the origin, playing "idle".
static func make_sprite(sprite_name: String) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames(sprite_name)
	a.offset = feet_offset(sprite_name)
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var gf := glow_frames(sprite_name)
	if gf:
		# Glow rides along as an unshaded, additive child that mirrors the parent's animation and flip,
		# so hands and eyes stay bright in the dark.
		var g := AnimatedSprite2D.new()
		g.name = "Glow"
		g.sprite_frames = gf
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = mat
		a.add_child(g)
		var sync := func() -> void:
			g.offset = a.offset
			g.flip_h = a.flip_h
			g.flip_v = a.flip_v
			if gf.has_animation(a.animation):
				g.animation = a.animation
				g.frame = a.frame
			g.visible = a.visible
		a.frame_changed.connect(sync)
		a.animation_changed.connect(sync)
		a.draw.connect(sync)
	if a.sprite_frames.has_animation(&"idle"):
		a.play(&"idle")
	return a


## Body-part textures for dismemberment: {"head", "torso", "arm", "leg"} -> Texture2D.
static func body_parts(sprite_name: String) -> Dictionary:
	var out := {}
	for part in ["head", "torso", "arm", "leg"]:
		var path := "res://art/sprites/%s_%s.png" % [sprite_name, part]
		if ResourceLoader.exists(path):
			out[part] = load(path)
		else:
			out[part] = _placeholder_part(sprite_name, part)
	return out


static func _placeholder_frames(sprite_name: String) -> SpriteFrames:
	var s: Array = SIZES.get(sprite_name, [16, 32, Color.MAGENTA])
	var tex := _box_texture(s[0], s[1], s[2])
	var sf := SpriteFrames.new()
	for anim in ["idle", "walk", "run", "jump", "fall", "cast", "work", "carry", "hurt", "die", "swim"]:
		if not sf.has_animation(anim):
			sf.add_animation(anim)
		sf.add_frame(anim, tex)
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	return sf


static func _placeholder_part(sprite_name: String, part: String) -> Texture2D:
	var s: Array = SIZES.get(sprite_name, [16, 32, Color.MAGENTA])
	var w: int = s[0]
	var h: int = s[1]
	match part:
		"head": return _box_texture(maxi(6, w / 2), maxi(6, h / 6), s[2].lightened(0.15))
		"torso": return _box_texture(maxi(6, w * 2 / 3), maxi(8, h / 3), s[2])
		"arm": return _box_texture(4, maxi(6, h / 3), s[2].darkened(0.1))
		_: return _box_texture(5, maxi(8, h * 2 / 5), s[2].darkened(0.2))


static func _box_texture(w: int, h: int, c: Color) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	var outline := Color(0.03, 0.02, 0.04)
	for x in w:
		img.set_pixel(x, 0, outline)
		img.set_pixel(x, h - 1, outline)
	for y in h:
		img.set_pixel(0, y, outline)
		img.set_pixel(w - 1, y, outline)
	return ImageTexture.create_from_image(img)
