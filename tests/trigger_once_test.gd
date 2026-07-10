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
	passed = _test_position_independent_emission() and passed
	passed = _test_runtime_fires_once_and_rearms() and passed
	passed = _test_runtime_trigger_once_in_first_cell() and passed
	passed = _test_runtime_alone_fires_exactly_once() and passed
	passed = _test_negated_warns() and passed
	passed = _test_source_map_stays_aligned() and passed
	passed = _test_custom_edge_gate_via_fluent_api() and passed
	return passed


## API dogfood proof: a THIRD-PARTY stateful edge gate declared with the fluent descriptor API
## (.stateful() + .evaluated_last()) gets the same position-independent hoisting as the built-in.
## The provider is NOT in the registry, so the flag BAKED at apply time - not any Core special
## case - must carry the hoist, exactly the path an addon pack rides.
static func _test_custom_edge_gate_via_fluent_api() -> bool:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.codegen_template = "__once_gate_{uid}()"
	descriptor.stateful("var __gate_{uid}: int = 1\n\nfunc __once_gate_{uid}() -> bool:\n\tvar gap: int = __gate_{uid}\n\t__gate_{uid} = 0\n\treturn gap > 1", "__gate_{uid} += 1").evaluated_last()
	var ok: bool = _check("the fluent chain sets all stateful fields",
		[descriptor.member_template.is_empty(), descriptor.codegen_prelude, descriptor.evaluate_last],
		[false, "__gate_{uid} += 1", true])
	# Bake a uid the way the dock's apply step does, onto a condition from a provider the registry
	# has never heard of.
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "MyPack"
	gate.ace_id = "OnceGate"
	gate.codegen_template = descriptor.codegen_template.replace("{uid}", "g")
	gate.member_declaration = descriptor.member_template.replace("{uid}", "g")
	gate.codegen_prelude = descriptor.codegen_prelude.replace("{uid}", "g")
	gate.evaluate_last = descriptor.evaluate_last
	# FIRST cell, the flag condition second - only the baked flag can hoist it.
	var sheet: EventSheetResource = _build_sheet(true)
	for entry: Variant in sheet.events:
		if entry is EventRow:
			(entry as EventRow).conditions.clear()
			(entry as EventRow).conditions.append(gate)
			(entry as EventRow).conditions.append(_expression_condition("flag"))
	var output: String = str(SheetCompiler.compile(sheet, "user://custom_gate.gd").get("output", ""))
	ok = _check("a custom pack edge gate in the first cell is hoisted last",
		output.contains("if flag and __once_gate_g():"), true) and ok
	# And it behaves at runtime: fires once on the rising edge, re-arms after a false tick.
	var node: Node = _instantiate_source(output)
	if node == null:
		return _check("custom gate sheet instantiates", false, true)
	node.set("flag", true)
	for _i in range(3):
		node.call("_process", 0.016)
	ok = _check("custom gate fires exactly once over 3 true ticks", int(node.get("counter")), 1) and ok
	node.set("flag", false)
	node.call("_process", 0.016)
	node.set("flag", true)
	node.call("_process", 0.016)
	ok = _check("custom gate re-arms", int(node.get("counter")), 2) and ok
	node.free()
	return ok


## The compiler hoists the term to the end of the chain, so ANY condition cell works: first, middle,
## or last all emit the same `if <others> and __trigger_once_x():` - and an OR row parenthesizes the
## OR list so the edge test gates the whole result instead of leaking in by precedence.
static func _test_position_independent_emission() -> bool:
	var ok: bool = true
	# Trigger Once in the FIRST cell of an AND row.
	var first_sheet: EventSheetResource = _build_sheet(true, 0)
	var first_output: String = str(SheetCompiler.compile(first_sheet, "user://trigger_once_first.gd").get("output", ""))
	ok = _check("first-cell Trigger Once still emits LAST in the and-chain",
		first_output.contains("if flag and __trigger_once_x():"), true) and ok
	# Trigger Once in the MIDDLE of an OR row: [flag, TO, other] with OR mode.
	var or_sheet: EventSheetResource = _build_sheet(true, 1, true)
	var or_output: String = str(SheetCompiler.compile(or_sheet, "user://trigger_once_or.gd").get("output", ""))
	ok = _check("mid-cell Trigger Once in an OR row gates the parenthesized OR result",
		or_output.contains("if (flag or other) and __trigger_once_x():"), true) and ok
	return ok


## Same runtime semantics with Trigger Once in the FIRST condition cell: fires once, re-arms.
static func _test_runtime_trigger_once_in_first_cell() -> bool:
	var node: Node = _instantiate(_build_sheet(true, 0))
	if node == null:
		return _check("first-cell Trigger Once sheet instantiates", false, true)
	var ok: bool = true
	node.set("flag", true)
	for _i in range(3):
		node.call("_process", 0.016)
	ok = _check("first-cell: 3 true ticks fire exactly once", int(node.get("counter")), 1) and ok
	node.set("flag", false)
	node.call("_process", 0.016)
	node.set("flag", true)
	node.call("_process", 0.016)
	ok = _check("first-cell: re-arms after a false tick", int(node.get("counter")), 2) and ok
	node.free()
	return ok


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
## once_position places the Trigger Once cell: -1 = last (the default), 0 = first, else that index.
## or_mode adds a second `other` condition and joins the row's conditions with OR.
static func _build_sheet(with_flag_condition: bool, once_position: int = -1, or_mode: bool = false) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	for spec: Array in [["flag", "bool", false], ["other", "bool", false], ["counter", "int", 0]]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = str(spec[0])
		variable.type_name = str(spec[1])
		variable.default_value = spec[2]
		sheet.events.append(variable)
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	if or_mode:
		row.condition_mode = EventRow.ConditionMode.OR
	if with_flag_condition:
		row.conditions.append(_expression_condition("flag"))
	if or_mode:
		row.conditions.append(_expression_condition("other"))
	var once_index: int = clampi(once_position, 0, row.conditions.size()) if once_position >= 0 else row.conditions.size()
	row.conditions.insert(once_index, _trigger_once_condition())
	var bump: ACEAction = ACEAction.new()
	bump.provider_id = "Core"
	bump.ace_id = "AddVar"
	bump.codegen_template = "counter += 1"
	row.actions.append(bump)
	sheet.events.append(row)
	return sheet


static func _expression_condition(expression: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.codegen_template = expression
	return condition


## Bakes a uid into the REAL registered descriptor, exactly as the dock's apply step does - EXCEPT
## evaluate_last, deliberately left unbaked: the compiler's registry fallback must hoist it anyway
## (the path an importer-rebuilt condition rides, where apply-time baking never ran).
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
	return _instantiate_source(str(SheetCompiler.compile(sheet, "user://trigger_once_run.gd").get("output", "")))


static func _instantiate_source(source: String) -> Node:
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
