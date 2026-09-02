# Godot EventSheets - the beginner-pattern ACEs (Move Toward, Toggle, As Clock Time, Every X To Y Seconds).
#
# These four wrap patterns beginners routinely write wrong by hand: frame-rate dependent damping, a
# hand-typed `x = not x`, minutes:seconds formatting, and a varied spawner cadence. Each one is pinned
# where it matters - the exact emitted line for the three one-liners, and the member + helper + prelude
# trio for the stateful condition - and the two whose SEMANTICS are the point (damping, clock text) are
# also run for real.
@tool
class_name BeginnerPatternACEsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var passed: bool = true
	passed = _test_move_toward_emits_exp_form() and passed
	passed = _test_move_toward_is_frame_rate_independent() and passed
	passed = _test_toggle_emits_negation() and passed
	passed = _test_toggle_runtime_flips() and passed
	passed = _test_as_clock_time_reads_minutes_and_seconds() and passed
	passed = _test_every_random_seconds_emits_state_helper_and_prelude() and passed
	return passed


## The action lands as the exponential-damping assignment, with the row's defaults baked in.
static func _test_move_toward_emits_exp_form() -> bool:
	var output: String = _compile(_build_move_toward_sheet(), "user://beginner_move_toward_emit.gd")
	return _check("Move Toward emits the frame-rate independent exp form",
		output.contains("\tvalue = lerp(value, 1.0, 1.0 - exp(-maxf(8.0, 0.0) * get_process_delta_time()))"), true)


## The claim in the description, proven: 60 steps of 1/60s and 240 steps of 1/240s land on the same
## value. A test Node has no tree, so get_process_delta_time() cannot supply a real frame delta - it
## is the ONLY thing swapped out of the shipped template here, for a member the harness drives.
static func _test_move_toward_is_frame_rate_independent() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SmoothMoveToward")
	if descriptor == null:
		return _check("Move Toward is registered", false, true)
	var statement: String = descriptor.codegen_template \
		.replace("{var_name}", "value").replace("{target}", "1.0").replace("{speed}", "8.0") \
		.replace("get_process_delta_time()", "step_delta")
	var source: String = "extends Node\n\nvar value: float = 0.0\nvar step_delta: float = 0.0\n\n\nfunc step() -> void:\n\t%s\n" % statement
	var node: Node = _instantiate(source)
	if node == null:
		return _check("the Move Toward statement compiles", false, true)
	var coarse: float = _run_steps(node, 1.0 / 60.0, 60)
	var fine: float = _run_steps(node, 1.0 / 240.0, 240)
	var ok: bool = _check("one second of easing at 60 fps and at 240 fps agree",
		absf(coarse - fine) < 0.001, true)
	ok = _check("one second at speed 8 closes most of the gap toward 1.0", coarse > 0.9, true) and ok
	ok = _check("easing never overshoots the target", coarse <= 1.0, true) and ok
	node.free()
	return ok


## The action is the plain boolean flip, no `if` ladder.
static func _test_toggle_emits_negation() -> bool:
	var output: String = _compile(_build_toggle_sheet(), "user://beginner_toggle_emit.gd")
	return _check("Toggle emits the negation assignment",
		output.contains("\tenabled_flag = not enabled_flag"), true)


## Real ticks: each run of the event flips the variable and flips it back.
static func _test_toggle_runtime_flips() -> bool:
	var node: Node = _instantiate(_compile(_build_toggle_sheet(), "user://beginner_toggle_run.gd"))
	if node == null:
		return _check("compiled Toggle sheet instantiates", false, true)
	node.set("enabled_flag", false)
	node.call("_process", 0.016)
	var ok: bool = _check("one tick turns the flag on", bool(node.get("enabled_flag")), true)
	node.call("_process", 0.016)
	ok = _check("the next tick turns it back off", bool(node.get("enabled_flag")), false) and ok
	node.free()
	return ok


## The expression is the mm:ss printf form, and it really reads "01:30" for 90 seconds.
static func _test_as_clock_time_reads_minutes_and_seconds() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "AsClockTime")
	if descriptor == null:
		return _check("As Clock Time is registered", false, true)
	var ok: bool = _check("the template formats two zero-padded fields",
		descriptor.codegen_template.contains("%02d:%02d"), true)
	var source: String = "extends Node\n\n\nfunc clock(seconds: float) -> String:\n\treturn %s\n" \
		% descriptor.codegen_template.replace("{seconds}", "seconds")
	var node: Node = _instantiate(source)
	if node == null:
		return _check("the As Clock Time expression compiles standalone on a Node", false, true) and ok
	ok = _check("90 seconds reads as one and a half minutes", str(node.call("clock", 90.0)), "01:30") and ok
	ok = _check("5 seconds pads both fields", str(node.call("clock", 5.0)), "00:05") and ok
	ok = _check("605 seconds rolls past ten minutes", str(node.call("clock", 605.0)), "10:05") and ok
	ok = _check("a negative duration clamps to zero", str(node.call("clock", -30.0)), "00:00") and ok
	node.free()
	return ok


## The stateful trio: both members and the helper land in the class, the prelude ages the accumulator
## inside the per-frame handler, and the condition term calls the helper with the clamped bounds.
static func _test_every_random_seconds_emits_state_helper_and_prelude() -> bool:
	var output: String = _compile(_build_every_random_sheet(), "user://beginner_every_random_emit.gd")
	var ok: bool = _check("the accumulator member is emitted", output.contains("var __everyr_time_r: float = 0.0"), true)
	ok = _check("the rolled-interval member starts at the not-yet-rolled sentinel",
		output.contains("var __everyr_next_r: float = -1.0"), true) and ok
	ok = _check("the helper function is emitted",
		output.contains("func __everyr_r(min_seconds: float, max_seconds: float) -> bool:"), true) and ok
	ok = _check("the helper re-rolls the next wait after firing",
		output.contains("\t__everyr_next_r = randf_range(min_seconds, maxf(max_seconds, min_seconds))\n\treturn true"), true) and ok
	ok = _check("the prelude ages the accumulator in the handler",
		output.contains("\t__everyr_time_r += get_process_delta_time()"), true) and ok
	ok = _check("the condition term calls the helper with both clamped bounds",
		output.contains("if __everyr_r(maxf(2.0, 0.001), maxf(5.0, 0.001)):"), true) and ok
	return ok


## `<Node> / var value / _process: <Move Toward value, defaults>`.
static func _build_move_toward_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("value", "float", 0.0))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.actions.append(_defaults_action("SmoothMoveToward"))
	sheet.events.append(row)
	return sheet


## `<Node> / var enabled_flag / _process: <Toggle enabled_flag>`.
static func _build_toggle_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("enabled_flag", "bool", false))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.actions.append(_defaults_action("ToggleVar"))
	sheet.events.append(row)
	return sheet


## `<Node> / var counter / _process: if <Every 2 to 5 seconds>: counter += 1`.
static func _build_every_random_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("counter", "int", 0))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_every_random_condition("r"))
	row.actions.append(_raw_action("counter += 1"))
	sheet.events.append(row)
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


## Bakes a uid into the REAL registered descriptor, exactly as the dock's apply step does.
static func _every_random_condition(uid: String) -> ACECondition:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "EveryRandomSeconds")
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "EveryRandomSeconds"
	condition.codegen_template = descriptor.codegen_template.replace("{uid}", uid) \
		.replace("{min_seconds}", "2.0").replace("{max_seconds}", "5.0")
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	condition.codegen_prelude = descriptor.codegen_prelude.replace("{uid}", uid)
	return condition


static func _raw_action(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = statement
	return action


## Drives the compiled easing statement for N steps of a fixed delta, from a zeroed start.
static func _run_steps(node: Node, step_delta: float, steps: int) -> float:
	node.set("value", 0.0)
	node.set("step_delta", step_delta)
	for i: int in range(steps):
		node.call("step")
	return float(node.get("value"))


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
	return SUPPORT.check("beginner_pattern_aces_test", label, actual, expected)
