# EventForge - the "group_reference" rich param hint: node-group params get a live
# autocomplete listing the groups that actually exist (project global groups + groups used
# in the edited scene) as the quoted literals templates expect. Pins: choice enumeration
# (globals + scene groups, sorted, deduped, engine-internal _groups skipped, quoted) and the
# builtin group vocabulary carrying the hint on node-group params ONLY - a regex capture
# group index stays a plain expression field, while the two event-group toggles take the same hint
# pointed at the SHEET's own groups - which list the dialog offers is derived from the template.
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
	all_passed = _check("Run On Tagged's tag is a node group too", _param_hint(by_id, "CallOnTagged", "tag"), "group_reference") and all_passed

	# ---- The SAME hint, pointed at the sheet's own groups for the two group toggles ----
	# Which list the dialog offers is derived from what the template does with the value: Set/Is
	# Group Active build the very "__group_<name>_active" member the compiler emits for a
	# runtime-toggleable group, and nothing that means a NODE group ever does.
	for sheet_group_id: String in ["SetGroupActive", "IsGroupActive"]:
		all_passed = _check("%s's group param carries the group_reference hint" % sheet_group_id,
			_param_hint(by_id, sheet_group_id, "group"), "group_reference") and all_passed
		all_passed = _check("%s reads the SHEET's groups" % sheet_group_id,
			EventSheetGroupFacts.reads_sheet_groups(_template(by_id, sheet_group_id), "group"), true) and all_passed
	for node_group_id: String in ["AddToGroup", "IsInGroup", "CallGroup", "OnGroupEmptied", "OnGroupFirstMember"]:
		all_passed = _check("%s still means a NODE group" % node_group_id,
			EventSheetGroupFacts.reads_sheet_groups(_template(by_id, node_group_id), "group"), false) and all_passed

	# ---- the sheet's own groups as the picker's choices ----
	var sheet: EventSheetResource = EventSheetResource.new()
	var combat: EventGroup = EventGroup.new()
	combat.group_name = "Combat"
	combat.name = combat.group_name
	var tutorial: EventGroup = EventGroup.new()
	tutorial.group_name = "Tutorial hints"
	tutorial.name = tutorial.group_name
	tutorial.runtime_toggleable = true
	combat.events.append(tutorial)
	sheet.events.append(combat)
	var offered: Array[Dictionary] = EventSheetGroupFacts.choices(sheet)
	all_passed = _check("both groups are offered, nested included", offered.size(), 2) and all_passed
	all_passed = _check("a switchable group leads the list", str(offered[0].get("name", "")), "Tutorial hints") and all_passed
	all_passed = _check("the value is the token the compiler emits",
		str(offered[0].get("value", "")), "\"tutorial_hints\"") and all_passed
	all_passed = _check("picking a group that cannot be switched yet is offered the fix",
		EventSheetGroupFacts.needs_switch(offered, "\"combat\""), true) and all_passed
	all_passed = _check("a switchable group needs no fix",
		EventSheetGroupFacts.needs_switch(offered, "\"tutorial_hints\""), false) and all_passed
	all_passed = _check("free text names no group of this sheet",
		EventSheetGroupFacts.needs_switch(offered, "some_expression"), false) and all_passed
	all_passed = _check("the value resolves back to its group",
		EventSheetGroupFacts.group_for_value(sheet, "\"combat\"") == combat, true) and all_passed

	# ---- the sentence the two rows read with ----
	all_passed = _check("Set Group Active reads as a sentence",
		_descriptor(by_id, "SetGroupActive").get_display_text(), "Set group {group} {active}") and all_passed
	all_passed = _check("its on/off value shows as a word",
		_param_of(by_id, "SetGroupActive", "active").display_value("false"), "inactive") and all_passed
	all_passed = _check("Is Group Active reads as a sentence",
		_descriptor(by_id, "IsGroupActive").get_display_text(), "Group {group} is active") and all_passed

	return all_passed


## The codegen template of a builtin descriptor, or "" when it is missing.
static func _template(by_id: Dictionary, ace_id: String) -> String:
	var descriptor: ACEDescriptor = by_id.get(ace_id)
	return descriptor.codegen_template if descriptor != null else ""


static func _descriptor(by_id: Dictionary, ace_id: String) -> ACEDescriptor:
	return by_id.get(ace_id)


static func _param_of(by_id: Dictionary, ace_id: String, param_id: String) -> ACEParam:
	var descriptor: ACEDescriptor = by_id.get(ace_id)
	if descriptor == null:
		return ACEParam.new()
	for parameter: ACEParam in descriptor.params:
		if parameter.id == param_id:
			return parameter
	return ACEParam.new()


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
