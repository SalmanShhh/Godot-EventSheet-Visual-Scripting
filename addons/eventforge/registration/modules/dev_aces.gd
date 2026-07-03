# EventForge module — Developer helper vocabulary (the everyday dev tools).
#
# The small native operations a Godot dev reaches for constantly while building + debugging:
# console output, assertions, scene-tree groups, node metadata, and tree navigation. They compile
# to the exact one-liners you'd hand-write (print(...), add_to_group(...), set_meta(...),
# get_parent()), so picking one keeps logic as an editable row instead of a raw block — and means
# common dev chores never force a drop to GDScript. Grouped under Debug / Groups / Metadata / Nodes.
@tool
class_name EventForgeDevACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Debug: console output + assertions (the #1 thing you do while building) ──
	descriptors.append(F.make_descriptor("Core", "Print", "Print", ACEDescriptor.ACEType.ACTION, "print({value})", "", [F.make_param("value", "String", "\"hello\"", "Value", "Value/expression to print to the Output console.", "expression")], "Debug", "print {value}")
		.described("Prints a value to the Output console, useful for debugging what's happening."))
	descriptors.append(F.make_descriptor("Core", "PrintLabeled", "Print Labeled", ACEDescriptor.ACEType.ACTION, "print({label}, {value})", "", [F.make_param("label", "String", "\"value:\"", "Label", "Leading label string.", "expression"), F.make_param("value", "String", "0", "Value", "Value/expression to print after the label.", "expression")], "Debug", "print {label} {value}")
		.described("Prints a value preceded by a label so you can tell debug messages apart."))
	descriptors.append(F.make_descriptor("Core", "PrintRich", "Print Rich (BBCode)", ACEDescriptor.ACEType.ACTION, "print_rich({value})", "", [F.make_param("value", "String", "\"[b]done[/b]\"", "Value", "BBCode string (colors/bold) for the Output console.", "expression")], "Debug", "print rich {value}")
		.described("Prints colored or bold text to the Output console using BBCode formatting."))
	descriptors.append(F.make_descriptor("Core", "PushWarning", "Push Warning", ACEDescriptor.ACEType.ACTION, "push_warning({message})", "", [F.make_param("message", "String", "\"check this\"", "Message", "Warning text (shows in the debugger).", "expression")], "Debug", "warn {message}")
		.described("Logs a warning message that appears in Godot's debugger panel."))
	descriptors.append(F.make_descriptor("Core", "PushError", "Push Error", ACEDescriptor.ACEType.ACTION, "push_error({message})", "", [F.make_param("message", "String", "\"bad state\"", "Message", "Error text (shows in the debugger).", "expression")], "Debug", "error {message}")
		.described("Logs an error message that appears in Godot's debugger panel."))
	descriptors.append(F.make_descriptor("Core", "Assert", "Assert", ACEDescriptor.ACEType.ACTION, "assert({condition}, {message})", "", [F.make_param("condition", "String", "true", "Condition", "Boolean that must hold (stripped from release builds).", "expression"), F.make_param("message", "String", "\"assertion failed\"", "Message", "Message if it fails.", "expression")], "Debug", "assert {condition}")
		.described("Crashes during testing if a condition isn't true, catching bugs early; removed from release."))
	descriptors.append(F.make_descriptor("Core", "PrintTree", "Print Scene Tree", ACEDescriptor.ACEType.ACTION, "print_tree_pretty()", "", [], "Debug", "print scene tree")
		.described("Prints the whole scene's node hierarchy to the output log for debugging."))
	# (Frame Count lives in system_aces.gd under "Time" — no duplicate "Core::GetFrameCount" here.)
	# A manual debugger pause as a pickable row (complements the F9 gutter breakpoints).
	descriptors.append(F.make_descriptor("Core", "Breakpoint", "Breakpoint (pause debugger)", ACEDescriptor.ACEType.ACTION, "breakpoint", "", [], "Debug", "breakpoint")
		.described("Pauses the game in the debugger right here so you can inspect things."))

	# ── Groups: the scene-tree group vocabulary (tag + query + broadcast) ──
	descriptors.append(F.make_descriptor("Core", "AddToGroup", "Add To Group", ACEDescriptor.ACEType.ACTION, "{target}.add_to_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to tag.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "add {target} to {group}")
		.described("Tags a node into a named group so you can find or affect it later."))
	descriptors.append(F.make_descriptor("Core", "RemoveFromGroup", "Remove From Group", ACEDescriptor.ACEType.ACTION, "{target}.remove_from_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to untag.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "remove {target} from {group}")
		.described("Untags a node from a named group when it should no longer belong."))
	descriptors.append(F.make_descriptor("Core", "IsInGroup", "Is In Group", ACEDescriptor.ACEType.CONDITION, "{target}.is_in_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to test.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "{target} in {group}")
		.described("True when the given node currently belongs to the named group."))
	descriptors.append(F.make_descriptor("Core", "GetFirstNodeInGroup", "Get First Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_first_node_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "first in {group}")
		.described("Returns the first node found in a named group, or nothing if empty."))
	descriptors.append(F.make_descriptor("Core", "GetNodeCountInGroup", "Count Nodes In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_node_count_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "count in {group}")
		.described("Returns how many nodes are currently in the named group."))
	# Numeric roll-ups across a group with no loop (the "average health of all enemies" case): each
	# reduces over get_nodes_in_group in one line. Sum/Average start at 0; Min/Max start at +/-INF so
	# an empty group yields that sentinel instead of erroring. {property} is a bare numeric member.
	descriptors.append(F.make_descriptor("Core", "SumInGroup", "Sum In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __acc + __n.{property}, 0.0)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression"), F.make_param("property", "String", "health", "Property", "Numeric member to total up across the group, e.g. health.", "expression")], "Groups", "sum of {property} in {group}")
		.described("Returns the total of a numeric property added up across every group member."))
	descriptors.append(F.make_descriptor("Core", "AverageInGroup", "Average In Group", ACEDescriptor.ACEType.EXPRESSION, "(get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __acc + __n.{property}, 0.0) / maxf(float(get_tree().get_nodes_in_group({group}).size()), 1.0))", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression"), F.make_param("property", "String", "health", "Property", "Numeric member to average across the group, e.g. health.", "expression")], "Groups", "average {property} in {group}")
		.described("Returns the average of a numeric property across all members of a group."))
	descriptors.append(F.make_descriptor("Core", "MinInGroup", "Lowest In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return min(__acc, __n.{property}), INF)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression"), F.make_param("property", "String", "health", "Property", "Numeric member to take the minimum of, e.g. health.", "expression")], "Groups", "lowest {property} in {group}")
		.described("Returns the smallest value of a property among all group members."))
	descriptors.append(F.make_descriptor("Core", "MaxInGroup", "Highest In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return max(__acc, __n.{property}), -INF)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression"), F.make_param("property", "String", "health", "Property", "Numeric member to take the maximum of, e.g. health.", "expression")], "Groups", "highest {property} in {group}")
		.described("Returns the largest value of a property among all group members."))
	descriptors.append(F.make_descriptor("Core", "CallGroup", "Call Method On Group", ACEDescriptor.ACEType.ACTION, "get_tree().call_group({group}, {method})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression"), F.make_param("method", "String", "\"reset\"", "Method", "Method name to call on every member.", "expression")], "Groups", "call {method} on {group}")
		.described("Calls the named method on every node in a group at once."))

	# ── Metadata: arbitrary key/value on any node (Godot's set_meta/get_meta) ──
	descriptors.append(F.make_descriptor("Core", "SetMeta", "Set Metadata", ACEDescriptor.ACEType.ACTION, "{target}.set_meta({name}, {value})", "", [F.make_param("target", "String", "self", "Target", "Object to tag.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression"), F.make_param("value", "String", "0", "Value", "Value to store.", "expression")], "Metadata", "set meta {name} = {value}")
		.described("Stores a custom named value on an object as hidden metadata."))
	descriptors.append(F.make_descriptor("Core", "GetMeta", "Get Metadata", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to read.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "meta {name}")
		.described("Returns a custom metadata value previously stored on an object."))
	descriptors.append(F.make_descriptor("Core", "HasMeta", "Has Metadata", ACEDescriptor.ACEType.CONDITION, "{target}.has_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to test.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "has meta {name}")
		.described("True when the object has metadata stored under the given key."))
	descriptors.append(F.make_descriptor("Core", "RemoveMeta", "Remove Metadata", ACEDescriptor.ACEType.ACTION, "{target}.remove_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to edit.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "remove meta {name}")
		.described("Deletes a stored metadata value from an object by its key."))

	# ── Nodes: scene-tree navigation (parent / child / find / owner), the everyday tree queries ──
	descriptors.append(F.make_descriptor("Core", "GetParent", "Get Parent", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_parent()", "", [F.make_param("target", "String", "self", "Target", "Node whose parent to get.", "expression")], "Nodes", "{target} parent")
		.described("Returns the node directly above this one in the scene tree."))
	descriptors.append(F.make_descriptor("Core", "GetChildCount", "Get Child Count", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_child_count()", "", [F.make_param("target", "String", "self", "Target", "Node whose children to count.", "expression")], "Nodes", "{target} child count")
		.described("Returns how many direct children a node currently has."))
	descriptors.append(F.make_descriptor("Core", "GetChild", "Get Child (by index)", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_child({index})", "", [F.make_param("target", "String", "self", "Target", "Parent node.", "expression"), F.make_param("index", "String", "0", "Index", "Child index (0-based).", "expression")], "Nodes", "{target} child {index}")
		.described("Returns a node's child at the given position number, starting from zero."))
	descriptors.append(F.make_descriptor("Core", "FindChild", "Find Child (by name)", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_child({pattern})", "", [F.make_param("target", "String", "self", "Target", "Node to search under.", "expression"), F.make_param("pattern", "String", "\"Enemy*\"", "Pattern", "Name pattern (wildcards allowed).", "expression")], "Nodes", "find {pattern} in {target}")
		.described("Returns a child node matching a name pattern, useful when paths vary."))
	descriptors.append(F.make_descriptor("Core", "GetNodeOrNull", "Get Node Or Null", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_node_or_null({path})", "", [F.make_param("target", "String", "self", "Target", "Base node.", "expression"), F.make_param("path", "String", "\"Sprite2D\"", "Path", "Node path (returns null if missing).", "expression")], "Nodes", "{target}.{path} or null")
		.described("Returns the node at a path, or nothing instead of erroring if missing."))
	descriptors.append(F.make_descriptor("Core", "HasNode", "Has Node", ACEDescriptor.ACEType.CONDITION, "{target}.has_node({path})", "", [F.make_param("target", "String", "self", "Target", "Base node.", "expression"), F.make_param("path", "String", "\"Sprite2D\"", "Path", "Node path to test.", "expression")], "Nodes", "{target} has {path}")
		.described("True when a node exists at the given path under this one."))
	descriptors.append(F.make_descriptor("Core", "GetOwner", "Get Scene Owner", ACEDescriptor.ACEType.EXPRESSION, "{target}.owner", "", [F.make_param("target", "String", "self", "Target", "Node whose scene owner to get.", "expression")], "Nodes", "{target} owner")
		.described("Returns the scene that this node was saved as part of."))
	descriptors.append(F.make_descriptor("Core", "IsAncestorOf", "Is Ancestor Of", ACEDescriptor.ACEType.CONDITION, "{target}.is_ancestor_of({node})", "", [F.make_param("target", "String", "self", "Target", "Potential ancestor node.", "expression"), F.make_param("node", "String", "get_node(\"Child\")", "Node", "Node to test for descendancy.", "expression")], "Nodes", "{target} is ancestor of {node}")
		.described("True when this node is somewhere above the other node in the tree."))

	return descriptors
