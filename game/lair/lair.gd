class_name Lair
extends RefCounted
## Small shared helpers for the Lair department: where things get parented, and lookups by group.

## Kinds that must go through the grinder before they may be stockpiled (design rule).
const RAW_KINDS := [&"corpse", &"part"]

## Designation names the spell might use, mapped to the item kind they store.
const STOCKPILE_ALIASES := {
	&"ossuary": &"bones",
	&"flesh_pit": &"gibs",
	&"larder": &"meat",
	&"morgue": &"stitched_body",
}


## The run's director (logistics, stockpiles, morale), or null outside a run.
static func director(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"lair_director")


## The node new things of a layer go under: "buildings", "items", "actors" or "fx".
## Uses the director's layers when there is one, else `fallback`'s parent.
static func layer(tree: SceneTree, layer_name: String, fallback: Node) -> Node:
	var d := director(tree)
	if d != null and d.has_method("get_layer"):
		var l: Node = d.get_layer(layer_name)
		if l != null:
			return l
	if fallback != null and fallback.get_parent() != null:
		return fallback.get_parent()
	return fallback


## Spawn a lair item (gibs, bones, a stitched body...) at a pixel position.
static func spawn_item(tree: SceneTree, item_kind: StringName, at: Vector2, fallback: Node, vel := Vector2.ZERO) -> Node2D:
	var it := LairItem.make(item_kind)
	var parent := layer(tree, "items", fallback)
	parent.add_child(it)
	it.global_position = at
	it.velocity = vel
	return it


static func item_kind(item: Object) -> StringName:
	if item == null or not is_instance_valid(item):
		return &""
	var k = item.get("kind")
	return StringName(k) if k != null else &""


static func is_raw(kind: StringName) -> bool:
	return RAW_KINDS.has(kind)


## True if an item is lying free: not carried, not reserved, not being freed.
static func item_free(item: Object) -> bool:
	if item == null or not is_instance_valid(item) or (item as Node).is_queued_for_deletion():
		return false
	if item.get("carrier") != null:
		return false
	var r = item.get("reserved_by")
	return r == null or not is_instance_valid(r)


## The Bodies and Souls spawner, or null.
static func flesh_spawner(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(&"flesh_spawner") if tree != null else null


## The Art lighting service, or null.
static func lighting(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(&"lighting") if tree != null else null
