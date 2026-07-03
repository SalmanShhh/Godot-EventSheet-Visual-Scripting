# EventForge — Helper ACEs test.
# The Helper module is the "structured escape hatch": generic ACEs (set/get any property,
# call any method, run a line, ternary, is-valid, connect-signal, math/string idioms) for
# GDScript that doesn't map to a specific ACE. This guards that they register, compile to the
# exact one-line GDScript they advertise, and stay registered LAST (so the reverse-lifter
# prefers specific ACEs).
@tool
class_name HelperACEsTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true

	var by_id: Dictionary = {}
	var all_descriptors: Array = EventForgeBuiltinACEs.get_descriptors()
	for descriptor in all_descriptors:
		by_id[descriptor.ace_id] = descriptor

	# The generic node-access helpers (the biggest gap they fill).
	passed = _check("generic node access registered",
		by_id.has("SetProperty") and by_id.has("GetProperty") and by_id.has("CallMethod")
		and by_id.has("CallMethodValue") and by_id.has("GetNode"), true) and passed
	# The universal escape, pickable.
	passed = _check("run/evaluate helpers registered",
		by_id.has("RunGDScript") and by_id.has("EvaluateGDScript") and by_id.has("EvaluateExpression"), true) and passed
	# Control / validity / signals / math / string.
	passed = _check("control + validity helpers registered",
		by_id.has("InlineIf") and by_id.has("ToggleBool") and by_id.has("SetLocalVar")
		and by_id.has("IsValid") and by_id.has("IsNull"), true) and passed
	passed = _check("signal + math + string helpers registered",
		by_id.has("ConnectSignal") and by_id.has("DisconnectSignal") and by_id.has("MoveTowardValue")
		and by_id.has("RemapValue") and by_id.has("FormatString"), true) and passed

	# Templates are single-line, direct GDScript (parity contract) — spot-check a few.
	passed = _check("Set Property template is a direct assignment",
		str(by_id["SetProperty"].codegen_template), "{target}.{property} = {value}") and passed
	passed = _check("Call Method template is a direct call",
		str(by_id["CallMethod"].codegen_template), "{target}.{method}({args})") and passed
	passed = _check("Is Valid uses is_instance_valid",
		str(by_id["IsValid"].codegen_template), "is_instance_valid({target})") and passed
	passed = _check("helpers are grouped under one category",
		str(by_id["RunGDScript"].category) == "Helpers" and str(by_id["FormatString"].category) == "Helpers", true) and passed

	# Helpers must come AFTER the specific modules so reverse-lift prefers specific templates.
	var helper_first: int = -1
	var collection_last: int = -1
	for index in range(all_descriptors.size()):
		var ace_id: String = all_descriptors[index].ace_id
		if helper_first < 0 and ace_id == "SetProperty":
			helper_first = index
		if ace_id == "ArrayAppend":
			collection_last = index
	passed = _check("helper module is registered after the specific modules",
		helper_first > collection_last and collection_last >= 0, true) and passed

	# Compile a few helpers end to end through a real event so the templates are exercised.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	# Condition: Is Valid(self)
	var valid_cond: ACECondition = ACECondition.new()
	valid_cond.provider_id = "Core"
	valid_cond.ace_id = "IsValid"
	valid_cond.codegen_template = "is_instance_valid({target})"
	valid_cond.params = {"target": "self"}
	event.conditions.append(valid_cond)
	# Action: Set Property self.modulate = Color.WHITE
	var set_prop: ACEAction = ACEAction.new()
	set_prop.provider_id = "Core"
	set_prop.ace_id = "SetProperty"
	set_prop.codegen_template = "{target}.{property} = {value}"
	set_prop.params = {"target": "self", "property": "modulate", "value": "Color.WHITE"}
	event.actions.append(set_prop)
	sheet.events.append(event)
	var result: Dictionary = SheetCompiler.compile(sheet, "user://helper_aces_test.gd")
	passed = _check("helper event compiles", bool(result.get("success", false)), true) and passed
	var output: String = str(result.get("output", ""))
	passed = _check("compiled output uses the direct property assignment",
		output.contains("self.modulate = Color.WHITE") and output.contains("is_instance_valid(self)"), true) and passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	passed = _check("helper output parses as GDScript", generated.reload(true) == OK, true) and passed

	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] helper_aces_test: %s" % label)
		return true
	print("[FAIL] helper_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
