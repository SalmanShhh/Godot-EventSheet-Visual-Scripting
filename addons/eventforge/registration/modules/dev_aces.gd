# EventForge module — Developer helper vocabulary (the everyday dev tools).
#
# The small native operations a Godot dev reaches for constantly while building + debugging:
# console output, assertions, scene-tree groups, and node metadata. They compile to the exact
# one-liners you'd hand-write (print(...), add_to_group(...), set_meta(...)), so picking one
# keeps logic as an editable row instead of a raw block — and means common dev chores never
# force a drop to GDScript. Grouped under Debug / Groups / Metadata for discoverability.
@tool
extends RefCounted
class_name EventForgeDevACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Debug: console output + assertions (the #1 thing you do while building) ──
	descriptors.append(F.make_descriptor("Core", "Print", "Print", ACEDescriptor.ACEType.ACTION, "print({value})", "", [F.make_param("value", "String", "\"hello\"", "Value", "Value/expression to print to the Output console.", "expression")], "Debug", "print {value}"))
	descriptors.append(F.make_descriptor("Core", "PrintLabeled", "Print Labeled", ACEDescriptor.ACEType.ACTION, "print({label}, {value})", "", [F.make_param("label", "String", "\"value:\"", "Label", "Leading label string.", "expression"), F.make_param("value", "String", "0", "Value", "Value/expression to print after the label.", "expression")], "Debug", "print {label} {value}"))
	descriptors.append(F.make_descriptor("Core", "PrintRich", "Print Rich (BBCode)", ACEDescriptor.ACEType.ACTION, "print_rich({value})", "", [F.make_param("value", "String", "\"[b]done[/b]\"", "Value", "BBCode string (colors/bold) for the Output console.", "expression")], "Debug", "print rich {value}"))
	descriptors.append(F.make_descriptor("Core", "PushWarning", "Push Warning", ACEDescriptor.ACEType.ACTION, "push_warning({message})", "", [F.make_param("message", "String", "\"check this\"", "Message", "Warning text (shows in the debugger).", "expression")], "Debug", "warn {message}"))
	descriptors.append(F.make_descriptor("Core", "PushError", "Push Error", ACEDescriptor.ACEType.ACTION, "push_error({message})", "", [F.make_param("message", "String", "\"bad state\"", "Message", "Error text (shows in the debugger).", "expression")], "Debug", "error {message}"))
	descriptors.append(F.make_descriptor("Core", "Assert", "Assert", ACEDescriptor.ACEType.ACTION, "assert({condition}, {message})", "", [F.make_param("condition", "String", "true", "Condition", "Boolean that must hold (stripped from release builds).", "expression"), F.make_param("message", "String", "\"assertion failed\"", "Message", "Message if it fails.", "expression")], "Debug", "assert {condition}"))
	descriptors.append(F.make_descriptor("Core", "PrintTree", "Print Scene Tree", ACEDescriptor.ACEType.ACTION, "print_tree_pretty()", "", [], "Debug", "print scene tree"))
	descriptors.append(F.make_descriptor("Core", "GetFrameCount", "Frame Count", ACEDescriptor.ACEType.EXPRESSION, "Engine.get_process_frames()", "", [], "Debug", "frame count"))
	# A manual debugger pause as a pickable row (complements the F9 gutter breakpoints).
	descriptors.append(F.make_descriptor("Core", "Breakpoint", "Breakpoint (pause debugger)", ACEDescriptor.ACEType.ACTION, "breakpoint", "", [], "Debug", "breakpoint"))

	# ── Groups: the scene-tree group vocabulary (tag + query + broadcast) ──
	descriptors.append(F.make_descriptor("Core", "AddToGroup", "Add To Group", ACEDescriptor.ACEType.ACTION, "{target}.add_to_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to tag.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "add {target} to {group}"))
	descriptors.append(F.make_descriptor("Core", "RemoveFromGroup", "Remove From Group", ACEDescriptor.ACEType.ACTION, "{target}.remove_from_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to untag.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "remove {target} from {group}"))
	descriptors.append(F.make_descriptor("Core", "IsInGroup", "Is In Group", ACEDescriptor.ACEType.CONDITION, "{target}.is_in_group({group})", "", [F.make_param("target", "String", "self", "Target", "Node to test.", "expression"), F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "{target} in {group}"))
	descriptors.append(F.make_descriptor("Core", "GetFirstNodeInGroup", "Get First Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_first_node_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "first in {group}"))
	descriptors.append(F.make_descriptor("Core", "GetNodeCountInGroup", "Count Nodes In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_node_count_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression")], "Groups", "count in {group}"))
	descriptors.append(F.make_descriptor("Core", "CallGroup", "Call Method On Group", ACEDescriptor.ACEType.ACTION, "get_tree().call_group({group}, {method})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "expression"), F.make_param("method", "String", "\"reset\"", "Method", "Method name to call on every member.", "expression")], "Groups", "call {method} on {group}"))

	# ── Metadata: arbitrary key/value on any node (Godot's set_meta/get_meta) ──
	descriptors.append(F.make_descriptor("Core", "SetMeta", "Set Metadata", ACEDescriptor.ACEType.ACTION, "{target}.set_meta({name}, {value})", "", [F.make_param("target", "String", "self", "Target", "Object to tag.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression"), F.make_param("value", "String", "0", "Value", "Value to store.", "expression")], "Metadata", "set meta {name} = {value}"))
	descriptors.append(F.make_descriptor("Core", "GetMeta", "Get Metadata", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to read.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "meta {name}"))
	descriptors.append(F.make_descriptor("Core", "HasMeta", "Has Metadata", ACEDescriptor.ACEType.CONDITION, "{target}.has_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to test.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "has meta {name}"))
	descriptors.append(F.make_descriptor("Core", "RemoveMeta", "Remove Metadata", ACEDescriptor.ACEType.ACTION, "{target}.remove_meta({name})", "", [F.make_param("target", "String", "self", "Target", "Object to edit.", "expression"), F.make_param("name", "String", "\"key\"", "Name", "Metadata key.", "expression")], "Metadata", "remove meta {name}"))

	return descriptors
