# Godot EventSheets - the "Trigger Once" condition.
#
# Runs the event only on the FIRST tick of each stretch where the conditions above it hold, re-arming once
# they go false. Conditions compile to a short-circuiting `and` chain, so the term is reached only when every
# condition before it is true - "was I reached last tick?" therefore answers "were they already true then?".
# The emission is pinned below, and the SEMANTICS are proven by compiling a sheet and ticking it for real.
@tool
class_name TriggerOnceTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _test_emits_helper_and_prelude() and passed
	passed = _test_runtime_fires_once_and_rearms() and passed
	passed = _test_runtime_alone_fires_exactly_once() and passed
	passed = _test_negated_warns() and passed
	passed = _test_source_map_stays_aligned() and passed
	return passed


## The multi-line member inserts SEVERAL class-level lines; the source map indexes lines one-per-entry, so
## the event row below the helper must still map to its real `if` line (not drift by the helper's height).
static func _test_source_map_stays_aligned() -> bool:
	var sheet: EventSheetResource = _build_sheet(true)
	var event_uid: String = ""
	for entry: Variant in sheet.events:
		if entry is EventRow:
			event_uid = str((entry as EventRow).get_instance_id())
	var result: Dictionary = SheetCompiler.compile(sheet, "user://trigger_once_map.gd")
	var output_lines: PackedStringArray = str(result.get("output", "")).split("\n")
	var mapped_start: int = -1
	var mapped_end: int = -1
	for map_entry: Variant in result.get("source_map", []):
		if map_entry is Dictionary and str((map_entry as Dictionary).get("uid", "")) == event_uid:
			mapped_start = int((map_entry as Dictionary).get("start", -1))
			mapped_end = int((map_entry as Dictionary).get("end", -1))
	# The event's block spans its prelude..action inside _process. The multi-line helper must NOT shift that
	# window into the helper function above it (the bug this catches: start pointing at a helper line).
	var start_text: String = output_lines[mapped_start - 1].strip_edges() if mapped_start >= 1 and mapped_start <= output_lines.size() else "<oob>"
	var end_text: String = output_lines[mapped_end - 1].strip_edges() if mapped_end >= 1 and mapped_end <= output_lines.size() else "<oob>"
	var ok: bool = _check("the event row's block starts at its prelude line (not shifted into the helper)", start_text, "__once_x += 1")
	ok = _check("the event row's block ends at its action line", end_text, "counter += 1") and ok
	return ok


## Builds `<host> / var flag / var counter / _process: if flag and __trigger_once_x(): counter += 1`.
static func _build_sheet(with_flag_condition: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	for spec: Array in [["flag", "bool", false], ["counter", "int", 0]]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = str(spec[0])
		variable.type_name = str(spec[1])
		variable.default_value = spec[2]
		sheet.events.append(variable)
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	if with_flag_condition:
		var flag_condition: ACECondition = ACECondition.new()
		flag_condition.provider_id = "Core"
		flag_condition.ace_id = "ExpressionIsTrue"
		flag_condition.codegen_template = "flag"
		row.conditions.append(flag_condition)
	row.conditions.append(_trigger_once_condition())
	var bump: ACEAction = ACEAction.new()
	bump.provider_id = "Core"
	bump.ace_id = "AddVar"
	bump.codegen_template = "counter += 1"
	row.actions.append(bump)
	sheet.events.append(row)
	return sheet


## Bakes a uid into the REAL registered descriptor, exactly as the dock's apply step does.
static func _trigger_once_condition(uid: String = "x") -> ACECondition:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "TriggerOnce")
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "TriggerOnce"
	condition.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	condition.codegen_prelude = descriptor.codegen_prelude.replace("{uid}", uid)
	return condition


static func _test_emits_helper_and_prelude() -> bool:
	var output: String = str(SheetCompiler.compile(_build_sheet(true), "user://trigger_once_emit.gd").get("output", ""))
	var ok: bool = _check("state var is emitted", output.contains("var __once_x: int = 1"), true)
	ok = _check("helper function is emitted", output.contains("func __trigger_once_x() -> bool:"), true) and ok
	ok = _check("helper zeroes its counter and edge-tests", output.contains("__once_x = 0") and output.contains("return ticks_since_last > 1"), true) and ok
	ok = _check("prelude ages the counter every tick", output.contains("\t__once_x += 1"), true) and ok
	ok = _check("the condition is the LAST term of the and-chain", output.contains("if flag and __trigger_once_x():"), true) and ok
	return ok


## The real proof: compile, attach, and tick. 3 true ticks fire ONCE; after a false tick it re-arms.
static func _test_runtime_fires_once_and_rearms() -> bool:
	var node: Node = _instantiate(_build_sheet(true))
	if node == null:
		return _check("compiled Trigger Once sheet instantiates", false, true)
	var ok: bool = true
	node.set("flag", true)
	for _i in range(3):
		node.call("_process", 0.016)
	ok = _check("3 consecutive true ticks fire exactly once", int(node.get("counter")), 1) and ok
	node.set("flag", false)
	node.call("_process", 0.016)
	ok = _check("a false tick does not fire", int(node.get("counter")), 1) and ok
	node.set("flag", true)
	for _i in range(2):
		node.call("_process", 0.016)
	ok = _check("it re-arms: becoming true again fires once more", int(node.get("counter")), 2) and ok
	node.free()
	return ok


## With no other conditions the term is reached every tick, so it fires exactly once, ever.
static func _test_runtime_alone_fires_exactly_once() -> bool:
	var node: Node = _instantiate(_build_sheet(false))
	if node == null:
		return _check("compiled bare Trigger Once sheet instantiates", false, true)
	for _i in range(5):
		node.call("_process", 0.016)
	var ok: bool = _check("Trigger Once alone fires exactly once over 5 ticks", int(node.get("counter")), 1)
	node.free()
	return ok


## A stateful condition can not be inverted (its state would advance on the ticks it does not fire).
static func _test_negated_warns() -> bool:
	var sheet: EventSheetResource = _build_sheet(true)
	for row: Variant in sheet.events:
		if row is EventRow:
			for condition: Variant in (row as EventRow).conditions:
				if condition is ACECondition and (condition as ACECondition).ace_id == "TriggerOnce":
					(condition as ACECondition).negated = true
	var warnings: Array = SheetCompiler.compile(sheet, "user://trigger_once_negated.gd").get("warnings", [])
	var warned: bool = false
	for warning: Variant in warnings:
		if str(warning).contains("can not be inverted"):
			warned = true
	return _check("a negated Trigger Once warns (it has no on-true rebase to key on)", warned, true)


static func _instantiate(sheet: EventSheetResource) -> Node:
	var source: String = str(SheetCompiler.compile(sheet, "user://trigger_once_run.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  compiled source failed to reload:\n%s" % source)
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] trigger_once_test: %s" % label)
		return true
	print("[FAIL] trigger_once_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
