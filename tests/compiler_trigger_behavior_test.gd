# EventForge — Trigger compiler behavior tests
@tool
extends RefCounted
class_name CompilerTriggerBehaviorTest

## Verifies signal-backed trigger compilation and default every-frame behavior.
static func run() -> bool:
	var signal_sheet: EventSheetResource = EventSheetResource.new()
	signal_sheet.host_class = "Node"
	signal_sheet.events = [_make_signal_row()]

	var signal_result: Dictionary = SheetCompiler.compile(signal_sheet, "user://eventforge_signal_trigger_test.gd")
	assert(bool(signal_result.get("success", false)), "OnSignal compile failed: %s" % str(signal_result.get("errors", [])))
	var signal_output: String = str(signal_result.get("output", ""))
	assert(signal_output.contains("get_node(\"Button\").pressed.connect("), "OnSignal output missing signal connection")
	assert(signal_output.contains("func _ef_on_button_pressed() -> void:"), "OnSignal output missing generated callback")
	assert(signal_output.contains("print(\"ready\")"), "OnSignal output missing action body")

	var every_frame_sheet: EventSheetResource = EventSheetResource.new()
	every_frame_sheet.host_class = "Node"
	every_frame_sheet.events = [_make_every_frame_row()]

	var every_frame_result: Dictionary = SheetCompiler.compile(every_frame_sheet, "user://eventforge_every_frame_test.gd")
	assert(bool(every_frame_result.get("success", false)), "Every-frame compile failed: %s" % str(every_frame_result.get("errors", [])))
	var every_frame_output: String = str(every_frame_result.get("output", ""))
	assert(every_frame_output.contains("func _process(delta: float) -> void:"), "Default every-frame output missing _process")
	assert(every_frame_output.contains("print(\"tick\")"), "Default every-frame output missing action body")

	print("[PASS] compiler_trigger_behavior_test")
	return true

static func _make_signal_row() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnSignal"
	row.trigger_params = {
		"target_node": "Button",
		"signal_name": "pressed"
	}
	row.trigger = ACECondition.new()
	row.trigger.provider_id = "Core"
	row.trigger.ace_id = "OnSignal"
	row.trigger.params = row.trigger_params.duplicate(true)
	row.trigger.parameters = row.trigger_params.duplicate(true)
	row.actions = [_make_print_action("\"ready\"")]
	return row

static func _make_every_frame_row() -> EventRow:
	var row: EventRow = EventRow.new()
	row.actions = [_make_print_action("\"tick\"")]
	return row

static func _make_print_action(message: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PrintLog"
	action.params = {"message": message}
	action.parameters = action.params.duplicate(true)
	return action
