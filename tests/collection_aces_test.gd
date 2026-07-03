# Godot EventSheets — Curated collection ACE set (rich-variables phase 3)
# ~27 Dictionary/Array/JSON ops as builtin Core descriptors: always present in the picker
# under "Variables: …" groups, direct one-liner codegen (parity-safe), and type-aware
# variable dropdowns ("variable_reference:Array" offers only Array-typed variables).
@tool
class_name CollectionAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Registry: the curated set is present with the right shapes.
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("dictionary ops registered",
		by_id.has("DictSetKey") and by_id.has("DictHasKey") and by_id.has("DictGet") and by_id.has("DictKeys"), true) and all_passed
	all_passed = _check("array ops registered",
		by_id.has("ArrayAppend") and by_id.has("ArrayContains") and by_id.has("ArrayAt") and by_id.has("ArrayPickRandom"), true) and all_passed
	all_passed = _check("collection ops group under Variables pickers",
		str(by_id["DictSetKey"].category) == "Variables: Dictionary" and str(by_id["ArrayAppend"].category) == "Variables: Array", true) and all_passed
	all_passed = _check("codegen is a direct one-liner",
		str(by_id["DictSetKey"].codegen_template), "{var_name}[{key}] = {value}") and all_passed
	all_passed = _check("variable params carry the typed hint",
		str((by_id["ArrayAppend"].params[0] as ACEParam).hint), "variable_reference:Array") and all_passed

	# Compile: the templates produce working GDScript.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"inventory": {"type": "Dictionary", "default": {}, "exported": false},
		"scores": {"type": "Array[int]", "default": [], "exported": false},
		"save_data": {"type": "Variant", "default": null, "exported": false}
	}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var has_key: ACECondition = ACECondition.new()
	has_key.provider_id = "Core"
	has_key.ace_id = "DictHasKey"
	has_key.codegen_template = str(by_id["DictHasKey"].codegen_template)
	has_key.params = {"var_name": "inventory", "key": "\"sword\""}
	event.conditions.append(has_key)
	var set_key: ACEAction = ACEAction.new()
	set_key.provider_id = "Core"
	set_key.ace_id = "DictSetKey"
	set_key.codegen_template = str(by_id["DictSetKey"].codegen_template)
	set_key.params = {"var_name": "inventory", "key": "\"sword\"", "value": "1"}
	event.actions.append(set_key)
	var append_score: ACEAction = ACEAction.new()
	append_score.provider_id = "Core"
	append_score.ace_id = "ArrayAppend"
	append_score.codegen_template = str(by_id["ArrayAppend"].codegen_template)
	append_score.params = {"var_name": "scores", "value": "10"}
	event.actions.append(append_score)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_coll_aces.gd").get("output", ""))
	all_passed = _check("dictionary condition compiles", output.contains("if inventory.has(\"sword\"):"), true) and all_passed
	all_passed = _check("dictionary action compiles", output.contains("inventory[\"sword\"] = 1"), true) and all_passed
	all_passed = _check("array action compiles", output.contains("scores.append(10)"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("collection ACE output parses", generated.reload(true) == OK, true) and all_passed

	# Type-aware dropdown filtering.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	all_passed = _check("array-typed variable matches Array",
		dialog._variable_matches_type("scores", "Array"), true) and all_passed
	all_passed = _check("dictionary variable rejected for Array",
		dialog._variable_matches_type("inventory", "Array"), false) and all_passed
	all_passed = _check("Variant variables always qualify",
		dialog._variable_matches_type("save_data", "Array"), true) and all_passed
	all_passed = _check("typed containers match their base",
		dialog._variable_matches_type("scores", "Array") and dialog._variable_matches_type("inventory", "Dictionary"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] collection_aces_test: %s" % label)
		return true
	print("[FAIL] collection_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
