# Godot EventSheets — JSON ACEs (serialize / parse / validate / file).
#
# The JSON module is its own thing (consolidated out of Collections). Verifies the JSON vocabulary
# registers under the dedicated "JSON" category, the codegen templates are the exact native JSON /
# FileAccess calls, and — for the save/load + parse-into-variable actions — that a compiled sheet
# round-trips a value through JSON text and a file on disk (catching any silent runtime error a
# string-only check would miss). The 5 moved ACEs keep their ace_ids + templates (the covenant).
@tool
extends RefCounted
class_name JsonAcesTest

const TEST_FILE := "user://__json_aces_test.json"

static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	# Registration: the full JSON vocabulary lives in its own "JSON" category.
	for ace_id: String in ["JsonStringify", "JsonStringifyPretty", "JsonParse", "JsonParseToVar", "JsonIsValid", "JsonSaveFile", "JsonLoadFile"]:
		all_passed = _check("ACE registered: %s" % ace_id, by_id.has(ace_id), true) and all_passed
		all_passed = _check("%s groups under JSON" % ace_id, str(by_id[ace_id].category) if by_id.has(ace_id) else "", "JSON") and all_passed

	# Templates are the exact native calls (the moved ones keep their templates verbatim).
	all_passed = _check("stringify wraps JSON.stringify", str(by_id["JsonStringify"].codegen_template), "JSON.stringify({value})") and all_passed
	all_passed = _check("pretty stringify passes an indent arg", str(by_id["JsonStringifyPretty"].codegen_template).begins_with("JSON.stringify({value}, "), true) and all_passed
	all_passed = _check("parse wraps JSON.parse_string", str(by_id["JsonParse"].codegen_template), "JSON.parse_string({text})") and all_passed
	all_passed = _check("parse-into-variable assigns the parsed value", str(by_id["JsonParseToVar"].codegen_template), "{var_name} = JSON.parse_string({text})") and all_passed
	all_passed = _check("is-valid tests for non-null parse", str(by_id["JsonIsValid"].codegen_template), "JSON.parse_string({text}) != null") and all_passed

	# Runtime round-trip: save a value as JSON to a file, load it back into a variable, and parse JSON
	# text into another variable; confirm the generated script parses and the values survive.
	DirAccess.remove_absolute(TEST_FILE)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {
		"loaded": {"type": "Variant", "default": null, "exported": false},
		"parsed": {"type": "Variant", "default": null, "exported": false},
	}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("JsonSaveFile", by_id, {"path": "\"%s\"" % TEST_FILE, "value": "{\"hp\": 7}"}))
	event.actions.append(_action("JsonLoadFile", by_id, {"var_name": "loaded", "path": "\"%s\"" % TEST_FILE}))
	event.actions.append(_action("JsonParseToVar", by_id, {"var_name": "parsed", "text": "\"[1, 2, 3]\""}))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://__json_aces_compiled.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = output
	var reload_ok: bool = script.reload() == OK
	all_passed = _check("JSON sheet compiles to valid GDScript", reload_ok, true) and all_passed
	if reload_ok:
		var node: Node = script.new()
		node._ready()
		all_passed = _check("Save + Load round-trips the value through a JSON file",
			node.loaded is Dictionary and int((node.loaded as Dictionary).get("hp", 0)) == 7, true) and all_passed
		all_passed = _check("Parse Into Variable parses JSON text",
			node.parsed is Array and (node.parsed as Array).size() == 3 and int((node.parsed as Array)[0]) == 1, true) and all_passed
		node.free()
	DirAccess.remove_absolute(TEST_FILE)
	return all_passed

## ACEAction built from the registered template (JSON templates carry no {uid}), as the dock applies it.
static func _action(ace_id: String, by_id: Dictionary, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = str(by_id[ace_id].codegen_template)
	action.params = params
	return action

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] json_aces_test: %s" % label)
		return true
	print("[FAIL] json_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
