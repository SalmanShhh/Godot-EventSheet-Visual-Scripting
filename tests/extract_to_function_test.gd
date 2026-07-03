# Extract to Function — the "create abstraction" gesture: turn a pile of statement-level action rows into
# one NAMED, reusable function (exposed as an ACE), replacing them with a single Call. Unlike the old
# GDScript-only extractor, this works on STRUCTURED ACE actions too and preserves them as rows in the
# function body. Tests the pure static core headlessly.
@tool
class_name ExtractToFunctionTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	# A STRUCTURED ACE action + a GDScript block — both must be extracted + preserved (the upgrade).
	var ace_action: ACEAction = ACEAction.new()
	ace_action.provider_id = "Core"
	ace_action.ace_id = "QueueFree"
	ace_action.codegen_template = "queue_free()"
	var code_action: RawCodeRow = RawCodeRow.new()
	code_action.code = "var count := get_child_count()\nprint(count)"
	event.actions.append(ace_action)
	event.actions.append(code_action)
	sheet.events.append(event)

	# Extract BOTH actions under a human name ("Apply Physics" → method apply_physics).
	var created: EventFunction = EventSheetDock.extract_actions_to_function(sheet, event, event.actions.duplicate(), "Apply Physics")
	all_passed = _check("a function was created", created != null, true) and all_passed
	if created == null:
		return false
	all_passed = _check("the typed name is snake_cased to a valid identifier", created.function_name, "apply_physics") and all_passed
	all_passed = _check("the readable name is kept for the ACE label", created.ace_display_name, "Apply Physics") and all_passed
	all_passed = _check("function exposed as an ACE", created.expose_as_ace, true) and all_passed
	all_passed = _check("function added to the sheet", sheet.functions.has(created), true) and all_passed

	# The function body preserves BOTH actions as rows (structured + raw), wrapped in one event.
	var body_has_structured: bool = false
	var body_has_raw: bool = false
	if created.events.size() == 1 and created.events[0] is EventRow:
		for action: Variant in (created.events[0] as EventRow).actions:
			if action is ACEAction and (action as ACEAction).ace_id == "QueueFree":
				body_has_structured = true
			if action is RawCodeRow:
				body_has_raw = true
	all_passed = _check("function body preserves the STRUCTURED action", body_has_structured, true) and all_passed
	all_passed = _check("function body preserves the GDScript action", body_has_raw, true) and all_passed

	# The event's actions are gone; a single Call to the function replaced them.
	all_passed = _check("the event now holds exactly one action (the call)", event.actions.size(), 1) and all_passed
	var is_call: bool = event.actions[0] is ACEAction \
		and (event.actions[0] as ACEAction).ace_id == "CallFunction" \
		and str((event.actions[0] as ACEAction).params.get("function_name", "")) == "apply_physics"
	all_passed = _check("the actions were replaced by a Call to the function", is_call, true) and all_passed

	# Extracting nothing is a no-op.
	all_passed = _check("extracting an empty list is a no-op",
		EventSheetDock.extract_actions_to_function(sheet, event, [], "x") == null, true) and all_passed

	# The result compiles: the function definition (with both statements) + a call to it, and it parses.
	var output: String = str(SheetCompiler.compile(sheet, "user://extract_fn.gd").get("output", ""))
	all_passed = _check("function definition emitted", output.contains("func apply_physics("), true) and all_passed
	all_passed = _check("structured action emitted inside the function", output.contains("queue_free()"), true) and all_passed
	all_passed = _check("GDScript action emitted inside the function", output.contains("get_child_count()"), true) and all_passed
	all_passed = _check("call to the function emitted in the handler", output.contains("apply_physics()"), true) and all_passed
	var script: GDScript = GDScript.new()
	script.source_code = output
	all_passed = _check("compiled output parses", script.reload() == OK, true) and all_passed

	# ── Guard: a GDScript reserved keyword as a name must NOT yield `func func():` (unparseable) ──
	var kw_sheet: EventSheetResource = EventSheetResource.new()
	kw_sheet.host_class = "Node2D"
	var kw_event: EventRow = EventRow.new()
	kw_event.actions.append(_queue_free_action())
	kw_sheet.events.append(kw_event)
	var kw_fn: EventFunction = EventSheetDock.extract_actions_to_function(kw_sheet, kw_event, kw_event.actions.duplicate(), "func")
	all_passed = _check("a reserved keyword name is not used verbatim", kw_fn != null and kw_fn.function_name != "func", true) and all_passed
	var kw_script: GDScript = GDScript.new()
	kw_script.source_code = str(SheetCompiler.compile(kw_sheet, "user://extract_kw.gd").get("output", ""))
	all_passed = _check("a keyword-named extract still parses", kw_script.reload() == OK, true) and all_passed

	# ── Guard: a host/native method name (queue_free on a Node2D) must NOT be overridden ──
	var hm_sheet: EventSheetResource = EventSheetResource.new()
	hm_sheet.host_class = "Node2D"
	var hm_event: EventRow = EventRow.new()
	hm_event.actions.append(_queue_free_action())
	hm_sheet.events.append(hm_event)
	var hm_fn: EventFunction = EventSheetDock.extract_actions_to_function(hm_sheet, hm_event, hm_event.actions.duplicate(), "queue free")
	all_passed = _check("a host-method name is not overridden", hm_fn != null and hm_fn.function_name != "queue_free", true) and all_passed

	# ── Guard: extracting an action that captures an event-local var is REFUSED (would not parse) ──
	var sc_sheet: EventSheetResource = EventSheetResource.new()
	sc_sheet.host_class = "Node2D"
	var sc_event: EventRow = EventRow.new()
	var sc_local: LocalVariable = LocalVariable.new()
	sc_local.name = "speed"
	sc_local.type_name = "float"
	sc_event.local_variables.append(sc_local)
	var sc_action: RawCodeRow = RawCodeRow.new()
	sc_action.code = "print(speed)"
	sc_event.actions.append(sc_action)
	sc_sheet.events.append(sc_event)
	all_passed = _check("extract is refused when an action captures an event-local var",
		EventSheetDock.extract_actions_to_function(sc_sheet, sc_event, sc_event.actions.duplicate(), "use_speed") == null, true) and all_passed
	# A whole-word match only: "speedometer" must NOT be mistaken for the local "speed".
	sc_action.code = "print(speedometer)"
	all_passed = _check("scope check is whole-word (speedometer != speed)",
		EventSheetDock.extract_actions_to_function(sc_sheet, sc_event, sc_event.actions.duplicate(), "use_speed") != null, true) and all_passed

	return all_passed


static func _queue_free_action() -> ACEAction:
	var a: ACEAction = ACEAction.new()
	a.provider_id = "Core"
	a.ace_id = "QueueFree"
	a.codegen_template = "queue_free()"
	return a


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] extract_to_function_test: %s" % label)
		return true
	print("[FAIL] extract_to_function_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
