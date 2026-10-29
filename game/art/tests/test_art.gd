extends RefCounted
## Art and Lighting: every sprite any department asks for has real frames and the standard animations,
## machines fit the Lair footprints, body parts fit the Bodies and Souls rig, the lighting hook adds a light,
## and the glow bloom attaches to SimView.

const STANDARD := ["idle", "walk", "run", "jump", "fall", "cast", "work", "carry", "hurt", "die", "swim"]
## What the other departments request by name (grep ArtLib. in necro, flesh, lair, world, threats, eyegor).
const REQUESTED := ["necromancer", "ghoul", "rotling", "farmer", "villager", "rabbit", "crow", "deer", "pig",
	"chicken", "heart", "grinder", "stitching_table", "altar", "spike_trap", "soul_orb", "eyegor",
	"eyegor_portrait", "corpse", "stitched_body", "part", "gibs", "bones", "meat"]
## Lair footprints (game/lair/builder.gd footprint()).
const FOOTPRINT := {"heart": Vector2(40, 48), "grinder": Vector2(48, 48), "stitching_table": Vector2(56, 32),
	"altar": Vector2(48, 40), "spike_trap": Vector2(24, 10)}
## Bodies and Souls rig bones (game/flesh/body_rig.gd RIG).
const BONES := {"head": 10.0, "torso": 20.0, "arm": 18.0, "leg": 24.0}


func run(t) -> void:
	for n in REQUESTED:
		var path := "res://art/sprites/%s.tres" % n
		t.check(ResourceLoader.exists(path), "%s has real art" % n)
		var sf := ArtLib.frames(n)
		var missing := []
		for a in STANDARD:
			if not sf.has_animation(a) or sf.get_frame_count(a) < 1:
				missing.append(a)
		t.check(missing.is_empty(), "%s has the standard animations (missing %s)" % [n, missing])
		var tex := sf.get_frame_texture(&"idle", 0)
		t.check(tex is AtlasTexture and tex.get_width() > 0, "%s idle frame is a real texture" % n)
	for n in ArtLib.CHARACTERS:
		var h := ArtLib.frames(n).get_frame_texture(&"idle", 0).get_height()
		t.check(h >= 64 and h <= 96, "%s is a large sprite (%d px frame)" % [n, h])
	for k in FOOTPRINT:
		var tex := ArtLib.frames(k).get_frame_texture(&"idle", 0)
		t.check(Vector2(tex.get_size()) == FOOTPRINT[k], "%s sprite matches its footprint (%s vs %s)" % [k, tex.get_size(), FOOTPRINT[k]])
		t.check(ArtLib.frames(k).get_frame_count(&"work") > 0, "%s has a work animation" % k)
	t.check(ArtLib.frames("eyegor_portrait").get_frame_texture(&"idle", 0).get_size() == Vector2(96, 96), "Eyegor's portrait is 96 px")
	for a in ["talk", "concerned", "proud", "memo"]:
		t.check(ArtLib.frames("eyegor_portrait").has_animation(a), "Eyegor's portrait has %s" % a)
	# feet on the origin: the offset lifts the frame by half its height
	var off := ArtLib.feet_offset("necromancer")
	t.check(is_equal_approx(off.y, -ArtLib.frames("necromancer").get_frame_texture(&"idle", 0).get_height() * 0.5), "feet_offset puts feet on the origin")
	var spr := ArtLib.make_sprite("heart")
	t.check(spr.get_node_or_null("Glow") != null, "the heart carries a glow layer")
	spr.free()

	# body parts
	for look in ArtLib.BODY_LOOKS + ["necromancer", "nobody"]:
		var parts := ArtLib.body_parts(look)
		for p in BONES:
			var tex: Texture2D = parts.get(p)
			t.check(tex != null, "%s %s texture" % [look, p])
			if tex:
				var sc: float = BONES[p] / float(tex.get_height())
				t.check(sc > 0.75 and sc <= 1.1, "%s %s fits its %d px bone (scale %.2f)" % [look, p, BONES[p], sc])
				t.check(not (tex is ImageTexture), "%s %s is real art, not a placeholder" % [look, p])

	# lighting
	var lighting := ArtLighting.new()
	lighting.override_hour = 12.0
	lighting.override_depth = 0.0
	t.root.add_child(lighting)
	t.check(t.tree.get_first_node_in_group("lighting") == lighting, "lighting node is in group `lighting`")
	var holder := Node2D.new()
	t.root.add_child(holder)
	var l: PointLight2D = lighting.add_light(holder, Color("3fd6c0"), 48.0, 1.0)
	t.check(l != null and l.get_parent() == holder, "add_light puts a PointLight2D on the node")
	t.check(l.texture != null and is_equal_approx(l.texture_scale, 48.0 / 64.0), "light radius maps to texture scale")
	var day := lighting.ambient(12.0, 0.0)
	var night := lighting.ambient(23.0, 0.0)
	var deep := lighting.ambient(12.0, 600.0)
	t.check(day.get_luminance() > night.get_luminance(), "night is darker than day")
	t.check(day.get_luminance() > deep.get_luminance(), "underground is darker than the surface at noon")
	t.check(deep.b >= deep.r, "underground is cold")
	await t.ticks(2)
	t.check(lighting.modulate_node.color.is_equal_approx(day), "CanvasModulate follows the hour and depth")

	# glow bloom on SimView
	var sv := SimView.new()
	t.root.add_child(sv)
	var Inst = load("res://art/install.gd")
	t.check(Inst.style_glow(sv), "bloom shader attaches to SimView's glow layer")
	var g = sv.get("_glow_sprite")
	t.check(g.material is ShaderMaterial, "glow layer uses the bloom material")
