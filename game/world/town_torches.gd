class_name TownTorches
extends Node2D
## The towns' torches. Lights come from Art's `lighting` hook, installed after World, so they are
## attached one frame after the run starts. A torch's position is the top of its post; the post
## reaches down to the ground.

const TORCH := {
	"color": Color(1.0, 0.62, 0.3),
	"radius_px": 70.0,
	"energy": 0.9,
	"post_color": Color(0.25, 0.17, 0.1),
	"post_h_px": 24.0, ## must match the 12-cell torch height World places them at
	"flame_color": Color(1.0, 0.7, 0.35),
}


func _init() -> void:
	name = "TownTorches"
	add_to_group("town_torches")


func add_torch(at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = at
	n.add_to_group("torch")
	var post := ColorRect.new()
	post.color = TORCH.post_color
	post.size = Vector2(2, TORCH.post_h_px)
	post.position = Vector2(-1, 0)
	n.add_child(post)
	var cup := ColorRect.new()
	cup.color = TORCH.post_color.darkened(0.3)
	cup.size = Vector2(6, 2)
	cup.position = Vector2(-3, 0)
	n.add_child(cup)
	var flame := ColorRect.new()
	flame.color = TORCH.flame_color
	flame.size = Vector2(4, 5)
	flame.position = Vector2(-2, -5)
	n.add_child(flame)
	add_child(n)
	return n


func _ready() -> void:
	await get_tree().process_frame
	var lighting := get_tree().get_first_node_in_group("lighting")
	if lighting != null and lighting.has_method("add_light"):
		for n in get_children():
			lighting.add_light(n, TORCH.color, TORCH.radius_px, TORCH.energy)
