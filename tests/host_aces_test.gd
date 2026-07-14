# EventForge - the behaviour-only Host vocabulary (Host expression + Host Is Valid condition) and its
# picker gate. Both ACEs read the literal `host` var, which only a behaviour sheet's synthesized prelude
# declares, so they MUST be hidden off a non-behaviour sheet (else they emit an undefined `host`). Pins:
# registration + type/template (frozen API), the static gate predicate the picker filters `definitions`
# on, and - covenant-critical - a behaviour using Host Is Valid round-trips byte-identically.
@tool
class_name HostACEsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[str(d.ace_id)] = d
	ok = _check("Host expression registers", by_id.has("BehaviorHost"), true) and ok
	ok = _check("Host Is Valid condition registers", by_id.has("BehaviorHostValid"), true) and ok
	if by_id.has("BehaviorHost"):
		var host_def: ACEDescriptor = by_id["BehaviorHost"]
		ok = _check("Host is an expression", host_def.ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
		ok = _check("Host emits the literal host var", str(host_def.codegen_template), "host") and ok
		ok = _check("Host takes no params", host_def.params.size(), 0) and ok
	if by_id.has("BehaviorHostValid"):
		var valid_def: ACEDescriptor = by_id["BehaviorHostValid"]
		ok = _check("Host Is Valid is a condition", valid_def.ace_type, ACEDescriptor.ACEType.CONDITION) and ok
		ok = _check("Host Is Valid guards with is_instance_valid", str(valid_def.codegen_template), "is_instance_valid(host)") and ok

	# The behaviour-only gate: hidden off a non-behaviour sheet, shown on a behaviour one, never touches
	# other vocabulary. This is exactly the predicate the picker filters `definitions` on.
	ok = _check("Host is hidden on a non-behaviour sheet", ACEPickerDialog.host_ace_hidden("Core", "BehaviorHost", false), true) and ok
	ok = _check("Host Is Valid is hidden on a non-behaviour sheet", ACEPickerDialog.host_ace_hidden("Core", "BehaviorHostValid", false), true) and ok
	ok = _check("Host is shown on a behaviour sheet", ACEPickerDialog.host_ace_hidden("Core", "BehaviorHost", true), false) and ok
	ok = _check("a normal ACE is never gated", ACEPickerDialog.host_ace_hidden("Core", "SetVar", false), false) and ok

	# The condition compiles to its guard on a behaviour sheet (the byte-exact round-trip of a real .gd
	# using is_instance_valid(host) is gated by the drift audit - the 4 packs that carry it re-lift with
	# drifted=0 once this ACE joins the reverse index).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "HostProbeBehavior"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var cond: ACECondition = ACECondition.new()
	cond.provider_id = "Core"
	cond.ace_id = "BehaviorHostValid"
	event.conditions.append(cond)
	var act: RawCodeRow = RawCodeRow.new()
	act.code = "host.set_process(false)"
	event.actions.append(act)
	sheet.events.append(event)
	var source: String = str(SheetCompiler.compile(sheet, "user://host_probe.gd").get("output", ""))
	ok = _check("Host Is Valid emits is_instance_valid(host)", source.contains("if is_instance_valid(host):"), true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] host_aces_test: %s" % label)
		return true
	print("[FAIL] host_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
