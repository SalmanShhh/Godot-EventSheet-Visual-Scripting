# Promote-to-Function: extract an event's inline GDScript actions into a reusable,
# ACE-exposed function, replacing them with a Call. Tests the pure static core headlessly.
@tool
extends RefCounted
class_name ExtractToFunctionTest

static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	# A GDScript block action (extracted) followed by a normal ACE action (preserved).
	var code_action: RawCodeRow = RawCodeRow.new()
	code_action.code = "var count := get_child_count()\nprint(count)"
	var ace_action: ACEAction = ACEAction.new()
	ace_action.provider_id = "Core"
	ace_action.ace_id = "QueueFree"
	ace_action.codegen_template = "queue_free()"
	event.actions.append(code_action)
	event.actions.append(ace_action)
	sheet.events.append(event)

	var created: EventFunction = EventSheetDock.extract_event_gdscript_to_function(sheet, event)
	all_passed = _check("a function was created", created != null, true) and all_passed
	if created == null:
		return false
	all_passed = _check("function exposed as an ACE", created.expose_as_ace, true) and all_passed
	all_passed = _check("function carries the extracted code",
		(created.events[0] as RawCodeRow).code.contains("get_child_count()"), true) and all_passed
	all_passed = _check("function added to the sheet", sheet.functions.has(created), true) and all_passed

	# The GDScript action is gone; a Call to the function replaced it; the ACE action survives.
	var has_call: bool = false
	var still_has_raw: bool = false
	for action in event.actions:
		if action is ACEAction and (action as ACEAction).ace_id == "CallFunction":
			has_call = str((action as ACEAction).params.get("function_name", "")) == created.function_name
		if action is RawCodeRow:
			still_has_raw = true
	all_passed = _check("GDScript action replaced by a Call to the function", has_call, true) and all_passed
	all_passed = _check("no inline GDScript action remains", still_has_raw, false) and all_passed
	all_passed = _check("the other ACE action survived (2 actions: call + queue_free)", event.actions.size(), 2) and all_passed

	# Extracting again (no GDScript actions left) is a no-op.
	all_passed = _check("re-extract with no code is a no-op",
		EventSheetDock.extract_event_gdscript_to_function(sheet, event) == null, true) and all_passed

	# The result compiles to valid GDScript: the function definition + a call to it.
	var output: String = str(SheetCompiler.compile(sheet, "user://extract_fn.gd").get("output", ""))
	all_passed = _check("function definition emitted", output.contains("func extracted_action("), true) and all_passed
	all_passed = _check("call to the function emitted in the handler", output.contains("extracted_action()"), true) and all_passed
	var script: GDScript = GDScript.new()
	script.source_code = output
	all_passed = _check("compiled output parses", script.reload() == OK, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] extract_to_function_test: %s" % label)
		return true
	print("[FAIL] extract_to_function_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
