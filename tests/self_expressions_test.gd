# EventSheet - the Self expression section census (SPEC-self-expressions Phase 1).
# Pins the derived model VALUES (never counts): the C3 alias table's fragments, the host gating,
# the variables census, the expression-only function filter, and the query scoping. All static +
# pure - no dialog, no editor.
@tool
class_name SelfExpressionsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── Properties: the alias table under host gating ────────────────────────────────────
	var body_2d: Array = EventSheetSelfExpressions.property_entries("CharacterBody2D")
	all_passed = _check("Node2D-family host: X inserts position.x", _fragment_for(body_2d, "X"), "position.x") and all_passed
	all_passed = _check("Node2D-family host: Angle inserts rotation", _fragment_for(body_2d, "Angle"), "rotation") and all_passed
	all_passed = _check("Node2D-family host: Opacity inserts modulate.a", _fragment_for(body_2d, "Opacity"), "modulate.a") and all_passed
	all_passed = _check("Node2D-family host has no Width (that is Control's)", _fragment_for(body_2d, "Width"), "") and all_passed

	var control: Array = EventSheetSelfExpressions.property_entries("Control")
	all_passed = _check("Control host: Width inserts size.x", _fragment_for(control, "Width"), "size.x") and all_passed
	all_passed = _check("Control host: X inserts position.x", _fragment_for(control, "X"), "position.x") and all_passed
	all_passed = _check("Control host: Opacity inserts modulate.a", _fragment_for(control, "Opacity"), "modulate.a") and all_passed

	var node_3d: Array = EventSheetSelfExpressions.property_entries("CharacterBody3D")
	all_passed = _check("Node3D-family host: Z inserts position.z", _fragment_for(node_3d, "Z"), "position.z") and all_passed
	all_passed = _check("Node3D-family host has NO Angle (rotation is a Vector3 there)", _fragment_for(node_3d, "Angle"), "") and all_passed

	var bare_node: Array = EventSheetSelfExpressions.property_entries("Node")
	all_passed = _check("bare Node host: no X", _fragment_for(bare_node, "X"), "") and all_passed
	all_passed = _check("bare Node host: UID survives (Object-level)", _fragment_for(bare_node, "UID"), "get_instance_id()") and all_passed

	# A custom class_name host resolves through the global class list to its engine base.
	var custom: Array = EventSheetSelfExpressions.property_entries("CanvasSurface")
	all_passed = _check("custom class host resolves to its engine base (UID present)", _fragment_for(custom, "UID"), "get_instance_id()") and all_passed
	# An unresolvable host degrades to Object: only the Object-level commons remain.
	var unresolvable: Array = EventSheetSelfExpressions.property_entries("NoSuchClassAnywhere")
	all_passed = _check("unresolvable host keeps only Object commons", _fragment_for(unresolvable, "X"), "") and all_passed
	all_passed = _check("unresolvable host still offers UID", _fragment_for(unresolvable, "UID"), "get_instance_id()") and all_passed

	# ── Variables: dict + tree census, bare-name fragments ───────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {"health": {"type": "int"}}
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "combo"
	tree_var.type_name = "int"
	sheet.events.append(tree_var)
	var variables: Array = EventSheetSelfExpressions.variable_entries(sheet)
	all_passed = _check("dict variable inserts its bare name", _fragment_for(variables, "health"), "health") and all_passed
	all_passed = _check("tree variable inserts its bare name", _fragment_for(variables, "combo"), "combo") and all_passed

	# ── Functions: expression role only, call fragment carries the param names ───────────
	var dps: EventFunction = EventFunction.new()
	dps.function_name = "dps"
	dps.return_type = TYPE_FLOAT
	sheet.functions.append(dps)
	var damage_after: EventFunction = EventFunction.new()
	damage_after.function_name = "damage_after"
	damage_after.return_type = TYPE_INT
	var armor_param: ACEParam = ACEParam.new()
	armor_param.id = "armor"
	armor_param.name = "armor"
	damage_after.params.append(armor_param)
	sheet.functions.append(damage_after)
	var is_ready_check: EventFunction = EventFunction.new()
	is_ready_check.function_name = "is_ready_check"
	is_ready_check.return_type = TYPE_BOOL
	sheet.functions.append(is_ready_check)
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.return_type = TYPE_NIL
	sheet.functions.append(heal)
	var functions: Array = EventSheetSelfExpressions.function_entries(sheet)
	all_passed = _check("float function is an expression entry", _fragment_for(functions, "dps"), "dps()") and all_passed
	all_passed = _check("params ride the call fragment", _fragment_for(functions, "damage_after"), "damage_after(armor)") and all_passed
	all_passed = _check("bool function is a CONDITION, not listed", _fragment_for(functions, "is_ready_check"), "") and all_passed
	all_passed = _check("void function is an ACTION, not listed", _fragment_for(functions, "heal"), "") and all_passed

	# ── Query scoping: the C3 "type Self. and browse" reflex ─────────────────────────────
	var scoped: Dictionary = EventSheetSelfExpressions.normalize_query("Self.X")
	all_passed = _check("Self.X is self-scoped", bool(scoped.get("self_scoped")), true) and all_passed
	all_passed = _check("Self.X remainder is x", str(scoped.get("remainder")), "x") and all_passed
	all_passed = _check("bare self is self-scoped, empty remainder",
		EventSheetSelfExpressions.normalize_query("sELF"), {"self_scoped": true, "remainder": ""}) and all_passed
	all_passed = _check("a plain query is not self-scoped",
		EventSheetSelfExpressions.normalize_query("position"), {"self_scoped": false, "remainder": "position"}) and all_passed

	# Matching covers BOTH spellings: the C3 label and the GDScript fragment.
	var x_entry: Dictionary = {"label": "X · position.x", "fragment": "position.x"}
	all_passed = _check("query x matches the C3 label", EventSheetSelfExpressions.entry_matches(x_entry, "x"), true) and all_passed
	all_passed = _check("query position matches the fragment", EventSheetSelfExpressions.entry_matches(x_entry, "position"), true) and all_passed
	all_passed = _check("query angle does not match X", EventSheetSelfExpressions.entry_matches(x_entry, "angle"), false) and all_passed

	# ── Resource-host sheet: variables work, no node commons ─────────────────────────────
	var resource_sheet: EventSheetResource = EventSheetResource.new()
	resource_sheet.host_class = "Resource"
	resource_sheet.variables = {"max_stack": {"type": "int"}}
	var resource_section: Dictionary = EventSheetSelfExpressions.section_for(resource_sheet, "Resource")
	all_passed = _check("resource host: variable census works", _fragment_for(resource_section.get("variables", []), "max_stack"), "max_stack") and all_passed
	all_passed = _check("resource host: no X", _fragment_for(resource_section.get("properties", []), "X"), "") and all_passed
	all_passed = _check("resource host: UID remains (Object-level)", _fragment_for(resource_section.get("properties", []), "UID"), "get_instance_id()") and all_passed

	return all_passed


## The fragment of the entry whose label STARTS with the given C3 name / variable name ("" when
## absent) - value-pinning helper. The separator is " · " for aliases, " : " for typed variables.
static func _fragment_for(entries: Array, label_head: String) -> String:
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var label: String = str((entry as Dictionary).get("label", ""))
		var head: String = label.split(" · ")[0].split(" : ")[0].replace("ƒ ", "").split("(")[0].strip_edges()
		if head == label_head:
			return str((entry as Dictionary).get("fragment", ""))
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] self_expressions_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
