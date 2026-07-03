# Godot EventSheets — the "Emit Signal On" helper emits the modern, parity-clean signal.emit() form.
#
# Godot 4's idiom is `signal.emit(args)`, and the project's parity guard (codegen_parity_test.gd) bans the
# legacy `emit_signal("name")` substring. This pulls the REAL EmitSignalOn descriptor from the registry,
# asserts its template is the modern form, compiles it, and runs the output through the SAME
# BANNED_PATTERNS scan the parity test uses — so the helper can never regress to the legacy form.
@tool
class_name EmitSignalModernTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Pull the live descriptor (not a hand-baked template) so this tests the real helper.
	var descriptor: ACEDescriptor = null
	for d: ACEDescriptor in EventForgeHelperACEs.get_descriptors():
		if d.ace_id == "EmitSignalOn":
			descriptor = d
			break
	all_passed = _check("EmitSignalOn helper is registered", descriptor != null, true) and all_passed
	if descriptor == null:
		return all_passed

	var template: String = str(descriptor.codegen_template)
	all_passed = _check("EmitSignalOn uses the modern .emit() template", template, "{target}.{signal}.emit({args})") and all_passed
	all_passed = _check("EmitSignalOn no longer uses legacy emit_signal", template.contains("emit_signal"), false) and all_passed

	# Compile two real actions through the live template: empty args, and with args.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_emit(template, "self", "exploded", ""))
	event.actions.append(_emit(template, "$Boss", "phase_changed", "2"))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_emit_modern.gd").get("output", ""))

	all_passed = _check("empty args compile to a clean .emit()", output.contains("self.exploded.emit()"), true) and all_passed
	all_passed = _check("args pass through .emit(args)", output.contains("$Boss.phase_changed.emit(2)"), true) and all_passed

	# Reuse the project's parity guard: the output must contain NONE of the banned patterns
	# (notably emit_signal(", the legacy form this helper used to emit).
	var body: String = output.substr(maxi(output.find("extends "), 0))
	for banned: String in CodegenParityTest.BANNED_PATTERNS:
		all_passed = _check("Emit Signal On output is parity-clean (no '%s')" % banned, body.contains(banned), false) and all_passed

	# The Core (host-scoped) "Emit Signal" ACE must stay modern + parity-clean too.
	var core: ACEDescriptor = null
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if d.ace_id == "EmitSignal":
			core = d
			break
	all_passed = _check("Core EmitSignal is registered", core != null, true) and all_passed
	if core != null:
		var core_template: String = str(core.codegen_template)
		all_passed = _check("Core EmitSignal uses the modern .emit() template", core_template, "{signal_name}.emit({args})") and all_passed
		all_passed = _check("Core EmitSignal no longer uses legacy emit_signal", core_template.contains("emit_signal"), false) and all_passed
		var core_action: ACEAction = ACEAction.new()
		core_action.provider_id = "Core"
		core_action.ace_id = "EmitSignal"
		core_action.params = {"signal_name": "damage_taken", "args": "10"}
		var core_sheet: EventSheetResource = EventSheetResource.new()
		core_sheet.host_class = "Node"
		var core_event: EventRow = EventRow.new()
		core_event.trigger_provider_id = "Core"
		core_event.trigger_id = "OnReady"
		core_event.actions.append(core_action)
		core_sheet.events.append(core_event)
		var core_out: String = str(SheetCompiler.compile(core_sheet, "user://eventsheets_emit_core.gd").get("output", ""))
		all_passed = _check("Core EmitSignal compiles to signal.emit(args)", core_out.contains("damage_taken.emit(10)"), true) and all_passed
		var core_body: String = core_out.substr(maxi(core_out.find("extends "), 0))
		for banned: String in CodegenParityTest.BANNED_PATTERNS:
			all_passed = _check("Core EmitSignal output is parity-clean (no '%s')" % banned, core_body.contains(banned), false) and all_passed

	return all_passed


static func _emit(template: String, target: String, signal_name: String, args: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "EmitSignalOn"
	action.codegen_template = template
	action.params = {"target": target, "signal": signal_name, "args": args}
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] emit_signal_modern_test: %s" % label)
		return true
	print("[FAIL] emit_signal_modern_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
