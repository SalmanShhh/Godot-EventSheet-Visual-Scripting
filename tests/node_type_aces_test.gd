# Godot EventSheets — "by node type" picking ACEs (the node-heavy-object answer).
#
# Godot objects are deep node trees (a player can be dozens of nodes). Reaching "the AnimationPlayer of
# this object" used to need a brittle path ($A/B/C/D) or a GDScript block. These ACEs resolve a child by
# CLASS anywhere in the subtree, so you target it by type instead — no path, no code. This pins their
# registration + that they compile to the right find_children() call (incl. param substitution).
@tool
extends RefCounted
class_name NodeTypeAcesTest

static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor: Variant in EventForgeNodeACEs.get_descriptors():
		if descriptor is ACEDescriptor:
			by_id[(descriptor as ACEDescriptor).ace_id] = descriptor

	# All three register under Nodes: Picking, with the expected ACE type.
	all_passed = _check("Find Children Of Type is an EXPRESSION under Nodes: Picking",
		_is(by_id, "FindChildrenOfType", ACEDescriptor.ACEType.EXPRESSION), true) and all_passed
	all_passed = _check("First Child Of Type is an EXPRESSION under Nodes: Picking",
		_is(by_id, "FirstChildOfType", ACEDescriptor.ACEType.EXPRESSION), true) and all_passed
	all_passed = _check("Has Child Of Type is a CONDITION under Nodes: Picking",
		_is(by_id, "HasChildOfType", ACEDescriptor.ACEType.CONDITION), true) and all_passed

	# First Child Of Type uses pop_front() so an empty subtree is null-safe (no runtime error).
	if by_id.has("FirstChildOfType"):
		all_passed = _check("First Child Of Type is null-safe on empty (pop_front)",
			(by_id["FirstChildOfType"] as ACEDescriptor).codegen_template.contains(".pop_front()"), true) and all_passed

	# End-to-end: an action built from the descriptor template + params compiles to the resolved call,
	# proving {target}/{type} substitution works (the whole point — target "the Area2D of $Player").
	if by_id.has("FindChildrenOfType"):
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Node2D"
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnReady"
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "FindChildrenOfType"
		action.codegen_template = (by_id["FindChildrenOfType"] as ACEDescriptor).codegen_template
		action.params = {"target": "$Player", "type": "\"Area2D\""}
		event.actions.append(action)
		sheet.events.append(event)
		var output: String = str(SheetCompiler.compile(sheet, "user://node_type_aces.gd").get("output", ""))
		all_passed = _check("resolves to a typed find_children call (target + type substituted)",
			output.contains("$Player.find_children(\"*\", \"Area2D\", true, false)"), true) and all_passed

	return all_passed

static func _is(by_id: Dictionary, ace_id: String, ace_type: int) -> bool:
	if not by_id.has(ace_id):
		return false
	var descriptor: ACEDescriptor = by_id[ace_id] as ACEDescriptor
	return descriptor.ace_type == ace_type and descriptor.category == "Nodes: Picking" \
		and descriptor.codegen_template.contains("find_children(\"*\", {type}, true, false)")

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_type_aces_test: %s" % label)
		return true
	print("[FAIL] node_type_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
