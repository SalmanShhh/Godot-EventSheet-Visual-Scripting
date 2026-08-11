# Godot EventSheets - the third-wave ACEs (charge meters, progress readings, drip loops,
# coyote time, buffered presses, group population edges).
#
# Nine verbs that each replace a snippet people write wrong by hand: an unclamped charge meter, a
# forgotten inverse_lerp, a for loop with an await inside, a hand-rolled coyote timer, a jump buffer,
# and a "did the wave just end?" node count. Every one is pinned where it matters - the exact emitted
# line for the one-liners, the member + helper pair for the stateful conditions, and the shared
# metadata key for the buffer trio - and the three whose SEMANTICS are the point (the two progress
# readings, coyote time) are also run for real.
@tool
class_name ThirdWaveACEsTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _test_charge_toward_emits_clamped_fill() and passed
	passed = _test_progress_of_reads_zero_to_one() and passed
	passed = _test_percent_of_reads_zero_to_hundred() and passed
	passed = _test_repeat_with_delay_emits_loop_and_await() and passed
	passed = _test_repeat_with_delay_output_parses() and passed
	passed = _test_was_recently_true_emits_member_and_helper() and passed
	passed = _test_was_recently_true_survives_going_false() and passed
	passed = _test_group_edges_emit_members_and_helpers() and passed
	passed = _test_buffer_trio_shares_one_key() and passed
	return passed


## The action lands as the self-clamping fill, with the row's defaults baked in.
static func _test_charge_toward_emits_clamped_fill() -> bool:
	var output: String = _compile(_build_charge_sheet(), "user://third_wave_charge_emit.gd")
	return _check("Charge Toward emits the delta-scaled fill clamped at the maximum",
		output.contains("\tpower = minf(power + (maxf(100.0, 0.0) / maxf(1.5, 0.001)) * get_process_delta_time(), maxf(100.0, 0.0))"), true)


## The expression is the clamped inverse_lerp, and it really reads 0..1 across the range.
static func _test_progress_of_reads_zero_to_one() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "ProgressOf")
	if descriptor == null:
		return _check("Progress Of is registered", false, true)
	var ok: bool = _check("the template clamps an inverse_lerp",
		descriptor.codegen_template == "clampf(inverse_lerp({from}, {to}, {value}), 0.0, 1.0)", true)
	var node: Node = _reading_node(descriptor)
	if node == null:
		return _check("the Progress Of expression compiles standalone on a Node", false, true) and ok
	ok = _check("half way through the range reads 0.5", node.call("reading", 5.0, 0.0, 10.0), 0.5) and ok
	ok = _check("the bottom of the range reads 0", node.call("reading", 0.0, 0.0, 10.0), 0.0) and ok
	ok = _check("past the top of the range clamps to 1", node.call("reading", 40.0, 0.0, 10.0), 1.0) and ok
	ok = _check("below the bottom of the range clamps to 0", node.call("reading", -7.0, 0.0, 10.0), 0.0) and ok
	node.free()
	return ok


## The percent sibling is the same reading times a hundred.
static func _test_percent_of_reads_zero_to_hundred() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "PercentOf")
	if descriptor == null:
		return _check("Percent Of is registered", false, true)
	var node: Node = _reading_node(descriptor)
	if node == null:
		return _check("the Percent Of expression compiles standalone on a Node", false, true)
	var ok: bool = _check("three quarters of the range reads 75", node.call("reading", 75.0, 0.0, 100.0), 75.0)
	ok = _check("past the top of the range clamps to 100", node.call("reading", 500.0, 0.0, 100.0), 100.0) and ok
	ok = _check("below the bottom of the range clamps to 0", node.call("reading", -20.0, 0.0, 100.0), 0.0) and ok
	node.free()
	return ok


## The multi-line action lands as a counted loop whose body is the statement, then the wait.
static func _test_repeat_with_delay_emits_loop_and_await() -> bool:
	var output: String = _compile(_build_repeat_sheet(), "user://third_wave_repeat_emit.gd")
	var ok: bool = _check("the loop header clamps the repeat count",
		output.contains("\tfor __rep_r: int in maxi(3, 0):"), true)
	ok = _check("the chosen statement is the loop body", output.contains("\n\t\tbeats += 1\n"), true) and ok
	ok = _check("each repeat waits on a real timer",
		output.contains("\t\tawait get_tree().create_timer(maxf(0.05, 0.001)).timeout"), true) and ok
	return ok


## The handler tolerates the await: the whole emitted sheet is valid GDScript, coroutine and all.
static func _test_repeat_with_delay_output_parses() -> bool:
	var output: String = _compile(_build_repeat_sheet(), "user://third_wave_repeat_parse.gd")
	var node: Node = _instantiate(output)
	var ok: bool = _check("a sheet containing Repeat With Delay parses as GDScript", node != null, true)
	if node != null:
		node.free()
	return ok


## The stateful pair: the timestamp member and its helper both land in the class, and the condition
## term calls the helper with the watched value wrapped in bool() and the clamped window.
static func _test_was_recently_true_emits_member_and_helper() -> bool:
	var output: String = _compile(_build_recent_sheet(), "user://third_wave_recent_emit.gd")
	var ok: bool = _check("the last-true timestamp member starts far in the past",
		output.contains("var __recent_at_r: int = -1000000"), true)
	ok = _check("the helper function is emitted",
		output.contains("func __recent_r(current: bool, window: float) -> bool:"), true) and ok
	ok = _check("the helper stamps the moment the value is true",
		output.contains("\t\t__recent_at_r = Time.get_ticks_msec()"), true) and ok
	ok = _check("the condition term calls the helper with the value and the clamped window",
		output.contains("if __recent_r(bool(watched), maxf(0.1, 0.0)):"), true) and ok
	return ok


## The coyote-time claim, proven: the tick after the watched value goes false still counts, because
## the window has not run out yet.
static func _test_was_recently_true_survives_going_false() -> bool:
	var node: Node = _instantiate(_compile(_build_recent_sheet(), "user://third_wave_recent_run.gd"))
	if node == null:
		return _check("compiled Was Recently True sheet instantiates", false, true)
	node.set("watched", true)
	node.call("_process", 0.016)
	var ok: bool = _check("a true value fires the event", int(node.get("hits")), 1)
	node.set("watched", false)
	node.call("_process", 0.016)
	ok = _check("the tick straight after it goes false still fires, inside the window",
		int(node.get("hits")), 2) and ok
	node.free()
	return ok


## Both group-edge conditions carry their own previous-count member and helper.
static func _test_group_edges_emit_members_and_helpers() -> bool:
	var output: String = _compile(_build_group_sheet(), "user://third_wave_group_emit.gd")
	var ok: bool = _check("the emptied watcher's count member starts at the unseeded sentinel",
		output.contains("var __gcount_e: int = -1"), true)
	ok = _check("the emptied helper counts the group's nodes",
		output.contains("\tvar count: int = get_tree().get_nodes_in_group(group_name).size()"), true) and ok
	ok = _check("the emptied helper fires only on the fall to zero",
		output.contains("\treturn previous > 0 and count == 0"), true) and ok
	ok = _check("the first-member watcher carries its own member",
		output.contains("var __gfirst_f: int = -1"), true) and ok
	ok = _check("the first-member helper fires only on the rise from zero",
		output.contains("\treturn previous == 0 and count > 0"), true) and ok
	ok = _check("each condition term passes its own group name",
		output.contains("__group_emptied_e(\"enemies\")"), true) and ok
	return ok


## Buffer Press, Press Is Buffered and Clear Buffer all address the SAME name-keyed metadata slot,
## which is what lets them sit in three different events and still agree.
static func _test_buffer_trio_shares_one_key() -> bool:
	var output: String = _compile(_build_buffer_sheet(), "user://third_wave_buffer_emit.gd")
	var ok: bool = _check("the action writes a future deadline under the buffer key",
		output.contains("\tset_meta(&\"__ef_buffer_\" + str(\"jump\"), Time.get_ticks_msec() + int(maxf(0.12, 0.0) * 1000.0))"), true)
	ok = _check("the condition reads the same key back",
		output.contains("if Time.get_ticks_msec() <= int(get_meta(&\"__ef_buffer_\" + str(\"jump\"), 0)):"), true) and ok
	ok = _check("clearing zeroes the same key",
		output.contains("\tset_meta(&\"__ef_buffer_\" + str(\"jump\"), 0)"), true) and ok
	return ok


## `<Node> / var power / _process: <Charge Toward power, defaults>`.
static func _build_charge_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("power", "float", 0.0))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.actions.append(_defaults_action("ChargeToward"))
	sheet.events.append(row)
	return sheet


## `<Node> / var beats / _ready: <Repeat With Delay 3 x 0.05s: beats += 1>`.
static func _build_repeat_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("beats", "int", 0))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_baked_action("RepeatWithDelay", "r", {
		"{times}": "3", "{delay}": "0.05", "{do}": "beats += 1",
	}))
	sheet.events.append(row)
	return sheet


## `<Node> / var watched, var hits / _process: if <watched was true within 0.1s>: hits += 1`.
static func _build_recent_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("watched", "bool", false))
	sheet.events.append(_variable("hits", "int", 0))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_baked_condition("WasRecentlyTrue", "r", {
		"{value}": "watched", "{window}": "0.1",
	}))
	row.actions.append(_raw_action("hits += 1"))
	sheet.events.append(row)
	return sheet


## One row per group edge, each with its own baked uid, so both members land side by side.
static func _build_group_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("waves", "int", 0))
	var emptied: EventRow = EventRow.new()
	emptied.trigger_provider_id = "Core"
	emptied.trigger_id = "OnProcess"
	emptied.conditions.append(_baked_condition("OnGroupEmptied", "e", {"{group}": "\"enemies\""}))
	emptied.actions.append(_raw_action("waves += 1"))
	sheet.events.append(emptied)
	var first: EventRow = EventRow.new()
	first.trigger_provider_id = "Core"
	first.trigger_id = "OnProcess"
	first.conditions.append(_baked_condition("OnGroupFirstMember", "f", {"{group}": "\"enemies\""}))
	first.actions.append(_raw_action("waves -= 1"))
	sheet.events.append(first)
	return sheet


## `_process: if <press "jump" is buffered>: <Clear Buffer "jump">` plus a Buffer Press row, so all
## three shipped templates land in one file.
static func _build_buffer_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var press: EventRow = EventRow.new()
	press.trigger_provider_id = "Core"
	press.trigger_id = "OnReady"
	press.actions.append(_defaults_action("BufferPress"))
	sheet.events.append(press)
	var consume: EventRow = EventRow.new()
	consume.trigger_provider_id = "Core"
	consume.trigger_id = "OnProcess"
	consume.conditions.append(_defaults_condition("PressIsBuffered"))
	consume.actions.append(_defaults_action("ClearBuffer"))
	sheet.events.append(consume)
	return sheet


static func _variable(variable_name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = default_value
	return variable


## An action row carrying the REAL descriptor's template with every param at its shipped default -
## exactly what the dock applies the moment the ACE is dropped onto a sheet.
static func _defaults_action(ace_id: String) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	var template: String = descriptor.codegen_template
	for parameter: ACEParam in descriptor.params:
		template = template.replace("{%s}" % parameter.id, str(parameter.default_value))
	action.codegen_template = template
	return action


static func _defaults_condition(ace_id: String) -> ACECondition:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	var template: String = descriptor.codegen_template
	for parameter: ACEParam in descriptor.params:
		template = template.replace("{%s}" % parameter.id, str(parameter.default_value))
	condition.codegen_template = template
	return condition


## Bakes a uid and chosen param values into the REAL registered descriptor, as the dock's apply does.
static func _baked_action(ace_id: String, uid: String, values: Dictionary) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = _bake(descriptor.codegen_template, uid, values)
	return action


static func _baked_condition(ace_id: String, uid: String, values: Dictionary) -> ACECondition:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.codegen_template = _bake(descriptor.codegen_template, uid, values)
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	condition.codegen_prelude = descriptor.codegen_prelude.replace("{uid}", uid)
	return condition


static func _bake(template: String, uid: String, values: Dictionary) -> String:
	var baked: String = template.replace("{uid}", uid)
	for placeholder: String in values:
		baked = baked.replace(placeholder, str(values[placeholder]))
	return baked


static func _raw_action(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = statement
	return action


## A Node exposing the reading expression as `reading(value, from, to)`, straight from the descriptor.
static func _reading_node(descriptor: ACEDescriptor) -> Node:
	var expression: String = descriptor.codegen_template \
		.replace("{value}", "value").replace("{from}", "from_value").replace("{to}", "to_value")
	var source: String = "extends Node\n\n\nfunc reading(value: float, from_value: float, to_value: float) -> float:\n\treturn %s\n" % expression
	return _instantiate(source)


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _instantiate(source: String) -> Node:
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
		print("[PASS] third_wave_aces_test: %s" % label)
		return true
	print("[FAIL] third_wave_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
