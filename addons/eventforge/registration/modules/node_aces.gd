# EventForge module — Node manipulation + picking (build, rearrange, and select scene-tree nodes).
#
# The everyday scene-tree operations: parent/reorder/free/rename nodes, and PICK nodes (children,
# by name pattern, or by group) so common tree work never forces a drop to GDScript. Complements
# the Nodes navigation set in dev_aces (Get Parent / Child / Find Child …) and the Groups set.
# Each compiles to the exact native call. Grouped under Nodes / Nodes: Picking.
@tool
extends RefCounted
class_name EventForgeNodeACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Nodes: manipulation (build + rearrange the tree at runtime; act on self or a {target}) ──
	descriptors.append(F.make_descriptor("Core", "AddChild", "Add Child", ACEDescriptor.ACEType.ACTION, "add_child({node})", "", [F.make_param("node", "String", "Node.new()", "Node", "Node to add as a child of this node.", "expression")], "Nodes", "add child {node}"))
	descriptors.append(F.make_descriptor("Core", "RemoveChild", "Remove Child", ACEDescriptor.ACEType.ACTION, "remove_child({node})", "", [F.make_param("node", "String", "get_node(\"Child\")", "Node", "Child node to detach (not freed).", "expression")], "Nodes", "remove child {node}"))
	descriptors.append(F.make_descriptor("Core", "MoveChild", "Move Child To Index", ACEDescriptor.ACEType.ACTION, "move_child({node}, {index})", "", [F.make_param("node", "String", "get_node(\"Child\")", "Node", "Child to reorder.", "expression"), F.make_param("index", "String", "0", "Index", "New sibling index (draw / process order).", "expression")], "Nodes", "move {node} to index {index}"))
	descriptors.append(F.make_descriptor("Core", "QueueFreeNode", "Free Node", ACEDescriptor.ACEType.ACTION, "{target}.queue_free()", "", [F.make_param("target", "String", "self", "Target", "Node to free at the end of the frame.", "expression")], "Nodes", "free {target}"))
	descriptors.append(F.make_descriptor("Core", "SetNodeName", "Set Node Name", ACEDescriptor.ACEType.ACTION, "{target}.name = {name}", "", [F.make_param("target", "String", "self", "Target", "Node to rename.", "expression"), F.make_param("name", "String", "\"Renamed\"", "Name", "New node name.", "expression")], "Nodes", "rename {target} to {name}"))
	descriptors.append(F.make_descriptor("Core", "DuplicateNode", "Duplicate Node", ACEDescriptor.ACEType.EXPRESSION, "{target}.duplicate()", "", [F.make_param("target", "String", "self", "Target", "Node to clone (add the clone with Add Child).", "expression")], "Nodes", "duplicate {target}"))
	descriptors.append(F.make_descriptor("Core", "GetNodeName", "Node Name", ACEDescriptor.ACEType.EXPRESSION, "{target}.name", "", [F.make_param("target", "String", "self", "Target", "Node to read the name of.", "expression")], "Nodes", "{target} name"))
	descriptors.append(F.make_descriptor("Core", "GetNodePath", "Node Path", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_path()", "", [F.make_param("target", "String", "self", "Target", "Node to read its scene-tree path.", "expression")], "Nodes", "{target} path"))
	descriptors.append(F.make_descriptor("Core", "GetIndexInParent", "Index In Parent", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_index()", "", [F.make_param("target", "String", "self", "Target", "Node to read its sibling index.", "expression")], "Nodes", "{target} index"))
	descriptors.append(F.make_descriptor("Core", "IsInsideTree", "Is Inside Tree", ACEDescriptor.ACEType.CONDITION, "{target}.is_inside_tree()", "", [F.make_param("target", "String", "self", "Target", "Node to test for scene-tree membership.", "expression")], "Nodes", "{target} is inside tree"))
	descriptors.append(F.make_descriptor("Core", "GetSceneRoot", "Current Scene Root", ACEDescriptor.ACEType.EXPRESSION, "get_tree().current_scene", "", [], "Nodes", "current scene root"))

	# ── Nodes: Picking — find / select nodes (children, by name pattern, by group) ──
	descriptors.append(F.make_descriptor("Core", "GetChildren", "Get Children", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_children()", "", [F.make_param("target", "String", "self", "Target", "Node whose direct children to list.", "expression")], "Nodes: Picking", "{target} children"))
	descriptors.append(F.make_descriptor("Core", "FindChildrenByPattern", "Find Children (by name)", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children({pattern}, \"\", true, false)", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("pattern", "String", "\"Enemy*\"", "Pattern", "Name pattern (wildcards allowed).", "expression")], "Nodes: Picking", "find {pattern} in {target}"))
	# By TYPE — the answer to Godot's node-heavy objects: reach "the AnimationPlayer / Area2D / Sprite2D of
	# this object" WITHOUT a brittle deep path ($A/B/C/D) or a GDScript block. find_children("*", Type,
	# recursive=true, owned=false) walks the whole subtree by class. Pairs with For Each (Find Children Of
	# Type), With-node / expressions (First Child Of Type), and gating (Has Child Of Type).
	descriptors.append(F.make_descriptor("Core", "FindChildrenOfType", "Find Children Of Type", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children(\"*\", {type}, true, false)", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("type", "String", "\"AnimationPlayer\"", "Type", "Node class name to find — AnimationPlayer, Area2D, Sprite2D, … (every descendant of that type).", "expression")], "Nodes: Picking", "{type} nodes in {target}"))
	descriptors.append(F.make_descriptor("Core", "FirstChildOfType", "First Child Of Type", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children(\"*\", {type}, true, false).pop_front()", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("type", "String", "\"AnimationPlayer\"", "Type", "Node class name to find — the first match in the subtree (null if none; pop_front is null-safe on empty).", "expression")], "Nodes: Picking", "first {type} in {target}"))
	descriptors.append(F.make_descriptor("Core", "HasChildOfType", "Has Child Of Type", ACEDescriptor.ACEType.CONDITION, "not {target}.find_children(\"*\", {type}, true, false).is_empty()", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("type", "String", "\"Area2D\"", "Type", "Node class name to test for anywhere in the subtree.", "expression")], "Nodes: Picking", "{target} has a {type}"))

	# ── Object-level component verbs (the Construct mental model: act on the OBJECT, not its deep node) ──
	# The animation ACEs above this file's peers are host-scoped to the AnimationPlayer/AnimatedSprite2D, so
	# they force you to TARGET that deep child by path. These take the object and AUTO-RESOLVE its player by
	# type, so "Play Animation walk on Player" needs no path and no GDScript block. Null-safe (guarded) and
	# collision-safe (the {uid}-baked temp var is unique per row, exactly like the audio Play Sound ACEs).
	descriptors.append(F.make_descriptor("Core", "PlayAnimationInObject", "Play Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __ap_{uid} := {target}.find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer\nif __ap_{uid}:\n\t__ap_{uid}.play(&{anim})", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimationPlayer is found automatically anywhere beneath it).", "expression"), F.make_param("anim", "String", "\"idle\"", "Animation", "Name of the animation to play.")], "Animation", "play animation {anim} in {target}"))
	descriptors.append(F.make_descriptor("Core", "StopAnimationInObject", "Stop Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __ap_{uid} := {target}.find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer\nif __ap_{uid}:\n\t__ap_{uid}.stop()", "", [F.make_param("target", "String", "self", "Target", "The OBJECT whose AnimationPlayer to stop (found automatically).", "expression")], "Animation", "stop animation in {target}"))
	descriptors.append(F.make_descriptor("Core", "PlaySpriteAnimationInObject", "Play Sprite Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __as_{uid} := {target}.find_children(\"*\", \"AnimatedSprite2D\", true, false).pop_front() as AnimatedSprite2D\nif __as_{uid}:\n\t__as_{uid}.play(&{anim})", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimatedSprite2D is found automatically).", "expression"), F.make_param("anim", "String", "\"default\"", "Animation", "Animation name.")], "Animation", "play sprite animation {anim} in {target}"))
	descriptors.append(F.make_descriptor("Core", "IsObjectAnimating", "Is Animating (in object)", ACEDescriptor.ACEType.CONDITION, "{target}.find_children(\"*\", \"AnimationPlayer\", true, false).any(func(__p): return __p.is_playing())", "", [F.make_param("target", "String", "self", "Target", "The OBJECT to test — true if any AnimationPlayer beneath it is playing.", "expression")], "Animation", "{target} is animating"))
	descriptors.append(F.make_descriptor("Core", "GetNodesInGroup", "Nodes In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Nodes: Picking", "nodes in group {group}"))
	descriptors.append(F.make_descriptor("Core", "GetRandomNodeInGroup", "Random Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).pick_random()", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick a random member from.", "expression")], "Nodes: Picking", "random node in group {group}"))
	# Nearest / Furthest by distance from THIS node — the auto-attack / targeting primitives. reduce()
	# (Godot 4 Array has no min_by/max_by) over the group, comparing global_position.distance_to: one
	# template needs global_position, so these register for Node2D hosts (a 3D game can paste the same
	# reduce() into a GDScript block). Empty group → null.
	descriptors.append(F.make_descriptor("Core", "NearestInGroup", "Nearest Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) < global_position.distance_to(__acc.global_position) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick the closest member of (by distance to this node). Returns null if the group is empty.", "expression")], "Nodes: Picking", "nearest node in group {group}", "Node2D"))
	descriptors.append(F.make_descriptor("Core", "FurthestInGroup", "Furthest Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) > global_position.distance_to(__acc.global_position) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick the farthest member of (by distance to this node). Returns null if the group is empty.", "expression")], "Nodes: Picking", "furthest node in group {group}", "Node2D"))

	return descriptors
