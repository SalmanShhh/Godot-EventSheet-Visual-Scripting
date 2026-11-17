# EventForge - which behaviours the Scene dock's "Preview its behaviours" plays.
#
# The entry belongs to the node you right-clicked, so it plays the behaviours that ACT ON that node or on a
# node under it, wherever they sit below it: a behaviour two levels down inside a plain holder node counts,
# one that acts on something outside the node does not, and neither does one that lives in the inside of an
# instanced scene you have not opened up (its internals are not part of the scene you are editing).
#
# The walk runs on every right-click, so it is bounded: it goes level by level, nearest first, and stops after
# a fixed number of nodes. In a scene that is wider than that the farthest behaviours are left out rather than
# the menu waiting on them.
#
# Loaded by path from the context menu plugin, never named as a class, so the editor's boot does not read it.
@tool
extends RefCounted

## The most nodes one right-click looks at below the selected node.
const MAX_VISITED: int = 600


## The behaviours below `node` with a Preview button (a pack's `_preview_start` and `_preview_stop`) that act on
## `node` or on a node under it, nearest first. `edited_root` is the root of the scene being edited, used to
## leave out the inside of instanced scenes that are not opened up; null takes every node as part of the scene.
static func find(node: Node, edited_root: Node = null) -> Array[Node]:
	return walk(node, edited_root, MAX_VISITED)["found"]


## `find` with its cost: {found: Array[Node], visited: int, cut: bool}, where `cut` is true when the walk
## stopped at `limit` nodes with more still to look at.
static func walk(node: Node, edited_root: Node, limit: int) -> Dictionary:
	var found: Array[Node] = []
	var result: Dictionary = {"found": found, "visited": 0, "cut": false}
	if node == null:
		return result
	var queue: Array[Node] = [node]
	var next: int = 0
	var visited: int = 0
	while next < queue.size():
		var parent: Node = queue[next]
		next += 1
		for child: Node in parent.get_children():
			if visited >= limit:
				result["cut"] = true
				result["visited"] = visited
				return result
			visited += 1
			if not _in_edited_scene(child, edited_root):
				continue
			if child.has_method("_preview_start") and child.has_method("_preview_stop") and _acts_inside(child, node):
				found.append(child)
			queue.append(child)
	result["visited"] = visited
	return result


## Whether `node` is part of the scene being edited: owned by its root, or inside an instanced scene that has
## its children opened up. With no scene root given, every node is.
static func _in_edited_scene(node: Node, edited_root: Node) -> bool:
	if edited_root == null or node.owner == null or node.owner == edited_root:
		return true
	return edited_root.is_editable_instance(node.owner)


## Whether the node a behaviour acts on (its `acts_on` when it names one, else its parent) is `inside` or below it.
static func _acts_inside(behaviour: Node, inside: Node) -> bool:
	var target: Node = behaviour.get_parent()
	if "acts_on" in behaviour:
		var named: Variant = behaviour.get("acts_on")
		if named is Node and is_instance_valid(named):
			target = named as Node
		elif named is NodePath and not (named as NodePath).is_empty():
			var resolved: Node = behaviour.get_node_or_null(named as NodePath)
			if resolved != null:
				target = resolved
	return target != null and (target == inside or inside.is_ancestor_of(target))
