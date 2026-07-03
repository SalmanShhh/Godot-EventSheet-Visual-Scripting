# Godot EventSheets — event-sheet System coverage: time/engine, display, text, comparisons
@tool
class_name SystemAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("time group registered",
		by_id.has("SetTimeScale") and by_id.has("GetGameTime") and by_id.has("GetFps") and by_id.has("GetFrameCount"), true) and all_passed
	all_passed = _check("display group registered",
		by_id.has("SetFullscreen") and by_id.has("SetWindowSize") and by_id.has("GetWindowWidth"), true) and all_passed
	all_passed = _check("text expressions registered (10)",
		by_id.has("TextTokenAt") and by_id.has("TextZeroPad") and by_id.has("TextReplace") and by_id.has("TextTrim") and by_id.has("TextMid"), true) and all_passed
	all_passed = _check("generic comparisons registered",
		by_id.has("CompareValues") and by_id.has("IsBetween"), true) and all_passed
	all_passed = _check("fullscreen mode is a dropdown",
		((by_id["SetFullscreen"].params[0] as ACEParam).options as Array).size() >= 3, true) and all_passed

	# Compile a sheet exercising the trickier templates (zeropad's %, between's and).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"score": {"type": "int", "default": 0, "exported": false}, "label_text": {"type": "String", "default": "", "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var between: ACECondition = ACECondition.new()
	between.provider_id = "Core"
	between.ace_id = "IsBetween"
	between.codegen_template = str(by_id["IsBetween"].codegen_template)
	between.params = {"value": "score", "min": "0", "max": "100"}
	event.conditions.append(between)
	var pad: ACEAction = ACEAction.new()
	pad.provider_id = "Core"
	pad.ace_id = "SetVar"
	pad.codegen_template = "label_text = {value}"
	pad.params = {"value": str(by_id["TextZeroPad"].codegen_template).replace("{digits}", "5").replace("{value}", "score")}
	event.actions.append(pad)
	var slow: ACEAction = ACEAction.new()
	slow.provider_id = "Core"
	slow.ace_id = "SetTimeScale"
	slow.codegen_template = str(by_id["SetTimeScale"].codegen_template)
	slow.params = {"scale": "0.5"}
	event.actions.append(slow)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_system.gd").get("output", ""))
	all_passed = _check("is-between compiles", output.contains("if (0 <= score and score <= 100):"), true) and all_passed
	all_passed = _check("zeropad compiles", output.contains("label_text = (\"%0*d\" % [5, score])"), true) and all_passed
	all_passed = _check("time scale compiles", output.contains("Engine.time_scale = 0.5"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("system output parses", generated.reload(true) == OK, true) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] system_aces_test: %s" % label)
		return true
	print("[FAIL] system_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
