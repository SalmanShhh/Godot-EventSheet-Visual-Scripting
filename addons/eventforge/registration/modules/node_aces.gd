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
	descriptors.append(F.make_descriptor("Core", "FindChildrenByPattern", "Find Children (by name)", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children({pattern})", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("pattern", "String", "\"Enemy*\"", "Pattern", "Name pattern (wildcards allowed).", "expression")], "Nodes: Picking", "find {pattern} in {target}"))
	descriptors.append(F.make_descriptor("Core", "GetNodesInGroup", "Nodes In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Nodes: Picking", "nodes in group {group}"))
	descriptors.append(F.make_descriptor("Core", "GetRandomNodeInGroup", "Random Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).pick_random()", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick a random member from.", "expression")], "Nodes: Picking", "random node in group {group}"))
	# Nearest / Furthest by distance from THIS node — the auto-attack / targeting primitives. reduce()
	# (Godot 4 Array has no min_by/max_by) over the group, comparing global_position.distance_to: one
	# template serves Node2D AND Node3D (distance_to is identical for Vector2/Vector3). Empty group → null.
	descriptors.append(F.make_descriptor("Core", "NearestInGroup", "Nearest Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) < global_position.distance_to(__acc.global_position) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick the closest member of (by distance to this node). Returns null if the group is empty.", "expression")], "Nodes: Picking", "nearest node in group {group}"))
	descriptors.append(F.make_descriptor("Core", "FurthestInGroup", "Furthest Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) > global_position.distance_to(__acc.global_position) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick the farthest member of (by distance to this node). Returns null if the group is empty.", "expression")], "Nodes: Picking", "furthest node in group {group}"))

	return descriptors
