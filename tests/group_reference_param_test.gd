# EventForge - the "group_reference" rich param hint: node-group params get a live
# autocomplete listing the groups that actually exist (project global groups + groups used
# in the edited scene) as the quoted literals templates expect. Pins: choice enumeration
# (globals + scene groups, sorted, deduped, engine-internal _groups skipped, quoted) and the
# builtin group vocabulary carrying the hint on node-group params ONLY - a regex capture
# group index and the event-group activity toggles must stay plain expression fields.
@tool
class_name GroupReferenceParamTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- choice enumeration: globals + scene groups, quoted + sorted + deduped ----
	var setting_name: String = "global_group/zz_test_faction"
	ProjectSettings.set_setting(setting_name, "test-only group")
	var root: Node = Node.new()
	var child_a: Node = Node.new()
	child_a.add_to_group("enemies", true)
	child_a.add_to_group("_engine_internal", true)
	var child_b: Node = Node.new()
	child_b.add_to_group("enemies", true)
	child_b.add_to_group("pickups", true)
	root.add_child(child_a)
	root.add_child(child_b)
	var choices: Array = ACEParamsDialog.group_choices(root)
	ProjectSettings.set_setting(setting_name, null)
	root.free()
	all_passed = _check("scene groups enumerate as quoted literals", choices.has("\"enemies\""), true) and all_passed
	all_passed = _check("project global groups enumerate", choices.has("\"zz_test_faction\""), true) and all_passed
	all_passed = _check("groups on several nodes dedupe", choices.count("\"enemies\""), 1) and all_passed
	all_passed = _check("engine-internal _groups are skipped", choices.has("\"_engine_internal\""), false) and all_passed
	var sorted_copy: Array = choices.duplicate()
	sorted_copy.sort()
	all_passed = _check("choices come sorted", choices, sorted_copy) and all_passed
	all_passed = _check("a null scene root is safe (globals only)", ACEParamsDialog.group_choices(null).has("\"enemies\""), false) and all_passed

	# ---- the builtin vocabulary carries the hint on node-group params only ----
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	for hinted_id: String in ["AddToGroup", "RemoveFromGroup", "IsInGroup", "GetFirstNodeInGroup", "GetNodeCountInGroup", "SumInGroup", "AverageInGroup", "MinInGroup", "MaxInGroup", "CallGroup", "GetNodesInGroup", "GetRandomNodeInGroup", "NearestInGroup", "FurthestInGroup", "NodesInGroup", "AnyInGroup", "CallOnTagged", "HasGroupMember", "SpawnSceneFull"]:
		all_passed = _check("%s's group param carries the group_reference hint" % hinted_id, _param_hint(by_id, hinted_id, "group"), "group_reference") and all_passed
	all_passed = _check("a regex capture group index is NOT a node group", _param_hint(by_id, "RegexCaptureGroup", "group"), "expression") and all_passed
	all_passed = _check("event-group toggles are NOT node groups", _param_hint(by_id, "SetGroupActive", "group"), "expression") and all_passed
	all_passed = _check("Run On Tagged's tag is a node group too", _param_hint(by_id, "CallOnTagged", "tag"), "group_reference") and all_passed

	return all_passed


## The hint string of a named param on a builtin descriptor, or "<absent>" when missing.
static func _param_hint(by_id: Dictionary, ace_id: String, param_id: String) -> String:
	var descriptor: ACEDescriptor = by_id.get(ace_id)
	if descriptor == null:
		return "<absent: %s>" % ace_id
	for parameter: ACEParam in descriptor.params:
		if parameter.id == param_id:
			return parameter.hint
	return "<absent: %s.%s>" % [ace_id, param_id]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] group_reference_param_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
