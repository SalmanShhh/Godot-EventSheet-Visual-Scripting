# Godot EventSheets — Input vocabulary + Wait/Await (Godot-familiarity batch 1)
# Input conditions/expressions with InputMap-driven action dropdowns, _input /
# _unhandled_input lifecycle triggers (compile + verify-lift), and C3's System: Wait as
# `await` actions (handlers are implicit coroutines, so await is safe anywhere).
@tool
extends RefCounted
class_name InputTimeAcesTest

static func run() -> bool:
	var all_passed: bool = true

	# Registry shapes.
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("input conditions registered",
		by_id.has("IsActionPressed") and by_id.has("IsActionJustPressed") and by_id.has("IsActionJustReleased"), true) and all_passed
	all_passed = _check("input triggers registered", by_id.has("OnInput") and by_id.has("OnUnhandledInput"), true) and all_passed
	all_passed = _check("input expressions registered", by_id.has("GetActionStrength") and by_id.has("GetInputAxis"), true) and all_passed
	all_passed = _check("time actions registered", by_id.has("Wait") and by_id.has("AwaitSignal"), true) and all_passed
	all_passed = _check("input group is its own picker category", str(by_id["IsActionPressed"].category), "Input") and all_passed

	# InputMap enumeration: options are quoted literals and include the ui_* defaults.
	var options: Array[String] = EventForgeBuiltinACEs._input_action_options()
	all_passed = _check("action options include ui defaults", options.has("\"ui_accept\"") and options.has("\"ui_left\""), true) and all_passed
	all_passed = _check("default action is a quoted literal", EventForgeBuiltinACEs._default_input_action().begins_with("\""), true) and all_passed

	# Compile: input condition + wait + axis expression in one event.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnPhysicsProcess"
	var pressed: ACECondition = ACECondition.new()
	pressed.provider_id = "Core"
	pressed.ace_id = "IsActionJustPressed"
	pressed.codegen_template = str(by_id["IsActionJustPressed"].codegen_template)
	pressed.params = {"action": "\"ui_accept\""}
	event.conditions.append(pressed)
	var wait: ACEAction = ACEAction.new()
	wait.provider_id = "Core"
	wait.ace_id = "Wait"
	wait.codegen_template = str(by_id["Wait"].codegen_template)
	wait.params = {"seconds": "0.5"}
	event.actions.append(wait)
	var set_velocity: ACEAction = ACEAction.new()
	set_velocity.provider_id = "Core"
	set_velocity.ace_id = "SetVelocity2D"
	set_velocity.codegen_template = "velocity.x = {value}"
	set_velocity.params = {"value": "Input.get_axis(\"ui_left\", \"ui_right\") * 200.0"}
	event.actions.append(set_velocity)
	sheet.events.append(event)
	var input_event: EventRow = EventRow.new()
	input_event.trigger_provider_id = "Core"
	input_event.trigger_id = "OnInput"
	var quit_action: ACEAction = ACEAction.new()
	quit_action.provider_id = "Core"
	quit_action.ace_id = "QueueFree"
	quit_action.codegen_template = "queue_free()"
	input_event.actions.append(quit_action)
	sheet.events.append(input_event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_input.gd").get("output", ""))
	all_passed = _check("input condition compiles with a StringName literal (hidden optimization)",
		output.contains("if Input.is_action_just_pressed(&\"ui_accept\"):"), true) and all_passed
	all_passed = _check("wait compiles to await", output.contains("await get_tree().create_timer(0.5).timeout"), true) and all_passed
	all_passed = _check("axis expression compiles", output.contains("Input.get_axis(\"ui_left\", \"ui_right\") * 200.0"), true) and all_passed
	all_passed = _check("OnInput compiles to the lifecycle handler", output.contains("func _input(event: InputEvent) -> void:"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("input/await output parses", generated.reload(true) == OK, true) and all_passed

	# Verify-lift: an _input trigger function round-trips back into an event.
	var external_source: String = "extends Node\n\nfunc _input(event: InputEvent) -> void:\n\tqueue_free()\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	var lifted: EventRow = null
	for row in imported.events:
		if row is EventRow:
			lifted = row
	all_passed = _check("_input lifts to an OnInput event", lifted != null and lifted.trigger_id == "OnInput", true) and all_passed
	imported.external_source_path = "user://eventsheets_input_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_input_rt.gd").get("output", ""))
	all_passed = _check("_input round-trips byte-identically", roundtrip == external_source, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] input_time_aces_test: %s" % label)
		return true
	print("[FAIL] input_time_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
