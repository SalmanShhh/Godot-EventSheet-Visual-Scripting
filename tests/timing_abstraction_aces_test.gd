# Godot EventSheets - the timing abstraction ACEs (Has Changed + named cooldowns).
#
# Has Changed is stateful: a per-instance previous-value slot plus a helper function, so the emission
# is pinned AND the semantics are proven by compiling a sheet and ticking it for real. The cooldown
# trio is stateless (node metadata keyed by name), so it is proven the same way: start one, check that
# it reads as not-ready immediately and as ready once its deadline has passed.
@tool
class_name TimingAbstractionACEsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var passed: bool = true
	passed = _test_has_changed_emits_member_and_helper() and passed
	passed = _test_has_changed_runtime_edges() and passed
	passed = _test_cooldown_emits_meta_key() and passed
	passed = _test_cooldown_runtime() and passed
	passed = _test_cooldown_time_left_expression() and passed
	return passed


## The member and the helper both land in the emitted class with the row's baked uid, and the
## condition term calls the helper with the watched expression.
static func _test_has_changed_emits_member_and_helper() -> bool:
	var output: String = _compile(_build_has_changed_sheet(), "user://timing_has_changed_emit.gd")
	var ok: bool = _check("the previous-value member is emitted", output.contains("var __changed_prev_x: Variant = null"), true)
	ok = _check("the seen flag is emitted", output.contains("var __changed_seen_x: bool = false"), true) and ok
	ok = _check("the helper function is emitted", output.contains("func __has_changed_x(current: Variant) -> bool:"), true) and ok
	ok = _check("the condition term calls the helper with the watched value", output.contains("if __has_changed_x(watched):"), true) and ok
	return ok


## Real ticks: the seeding tick never fires, an unchanged tick never fires, and each change fires once.
static func _test_has_changed_runtime_edges() -> bool:
	var node: Node = _instantiate(_compile(_build_has_changed_sheet(), "user://timing_has_changed_run.gd"))
	if node == null:
		return _check("compiled Has Changed sheet instantiates", false, true)
	node.set("watched", 0)
	node.call("_process", 0.016)
	var ok: bool = _check("the seeding tick does not fire", int(node.get("counter")), 0)
	node.call("_process", 0.016)
	ok = _check("an unchanged tick does not fire", int(node.get("counter")), 0) and ok
	node.set("watched", 1)
	node.call("_process", 0.016)
	ok = _check("a changed tick fires once", int(node.get("counter")), 1) and ok
	node.call("_process", 0.016)
	ok = _check("holding the new value does not fire again", int(node.get("counter")), 1) and ok
	node.set("watched", 0)
	node.call("_process", 0.016)
	ok = _check("changing back fires again", int(node.get("counter")), 2) and ok
	node.free()
	return ok


## Start Cooldown and Cooldown Is Ready both address the same name-keyed metadata slot.
static func _test_cooldown_emits_meta_key() -> bool:
	var output: String = _compile(_build_cooldown_sheet(), "user://timing_cooldown_emit.gd")
	var ok: bool = _check("the action writes the name-keyed meta deadline", output.contains("set_meta(&\"__ef_cool_\" + str(\"dash\"), Time.get_ticks_msec() + int(maxf(0.05, 0.0) * 1000.0))"), true)
	ok = _check("the condition reads the same meta key", output.contains("Time.get_ticks_msec() >= int(get_meta(&\"__ef_cool_\" + str(\"dash\"), 0))"), true) and ok
	return ok


## A never-started cooldown reads as ready; starting one makes it not ready until its deadline passes.
static func _test_cooldown_runtime() -> bool:
	var node: Node = _instantiate(_compile(_build_cooldown_sheet(), "user://timing_cooldown_run.gd"))
	if node == null:
		return _check("compiled cooldown sheet instantiates", false, true)
	var ok: bool = _check("a never-started cooldown is ready", bool(node.call("check_ready")), true)
	node.call("begin")
	ok = _check("right after starting it is not ready", bool(node.call("check_ready")), false) and ok
	OS.delay_msec(80)
	ok = _check("once the deadline passes it is ready again", bool(node.call("check_ready")), true) and ok
	node.free()
	return ok


## The expression reads seconds remaining, and clamps to 0 for a cooldown that never started.
static func _test_cooldown_time_left_expression() -> bool:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "CooldownTimeLeft")
	if descriptor == null:
		return _check("Cooldown Time Left is registered", false, true)
	var ok: bool = _check("the expression template is the clamped seconds form", descriptor.codegen_template,
		"(maxf(0.0, float(int(get_meta(&\"__ef_cool_\" + str({name}), 0)) - Time.get_ticks_msec()) / 1000.0))")
	var source: String = "extends Node\n\n\nfunc time_left() -> float:\n\treturn %s\n" % descriptor.codegen_template.replace("{name}", "\"dash\"")
	var node: Node = _instantiate(source)
	if node == null:
		return _check("the expression compiles standalone on a Node", false, true) and ok
	ok = _check("a never-started cooldown has no time left", float(node.call("time_left")), 0.0) and ok
	node.set_meta(&"__ef_cool_dash", Time.get_ticks_msec() + 2000)
	ok = _check("a live cooldown reports time left above one second", float(node.call("time_left")) > 1.0, true) and ok
	node.free()
	return ok


## `<Node> / var watched / var counter / _process: if <Has Changed watched>: counter += 1`.
static func _build_has_changed_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	for spec: Array in [["watched", "int", 0], ["counter", "int", 0]]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = str(spec[0])
		variable.type_name = str(spec[1])
		variable.default_value = spec[2]
		sheet.events.append(variable)
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_has_changed_condition("watched"))
	row.actions.append(_raw_action("counter += 1"))
	sheet.events.append(row)
	return sheet


## Two functions on one Node: `begin()` starts the "dash" cooldown, `check_ready()` reports its state.
static func _build_cooldown_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var begin: EventFunction = EventFunction.new()
	begin.function_name = "begin"
	begin.return_type = TYPE_NIL
	var start_row: EventRow = EventRow.new()
	start_row.actions.append(_start_cooldown_action("\"dash\"", "0.05"))
	begin.events.append(start_row)
	sheet.functions.append(begin)
	var ready: EventFunction = EventFunction.new()
	ready.function_name = "check_ready"
	ready.return_type = TYPE_BOOL
	var ready_row: EventRow = EventRow.new()
	ready_row.conditions.append(_cooldown_ready_condition("\"dash\""))
	ready_row.actions.append(_raw_action("return true"))
	ready.events.append(ready_row)
	ready.events.append(_raw_row("return false"))
	sheet.functions.append(ready)
	return sheet


static func _raw_row(code: String) -> RawCodeRow:
	var row: RawCodeRow = RawCodeRow.new()
	row.code = code
	return row


## Bakes a uid into the REAL registered descriptor, exactly as the dock's apply step does.
static func _has_changed_condition(watched: String, uid: String = "x") -> ACECondition:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "HasChanged")
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "HasChanged"
	condition.codegen_template = descriptor.codegen_template.replace("{uid}", uid).replace("{value}", watched)
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	condition.codegen_prelude = descriptor.codegen_prelude.replace("{uid}", uid)
	return condition


static func _start_cooldown_action(cooldown_name: String, seconds: String) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "StartCooldown")
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "StartCooldown"
	action.codegen_template = descriptor.codegen_template.replace("{name}", cooldown_name).replace("{seconds}", seconds)
	return action


static func _cooldown_ready_condition(cooldown_name: String) -> ACECondition:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "CooldownReady")
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CooldownReady"
	condition.codegen_template = descriptor.codegen_template.replace("{name}", cooldown_name)
	return condition


static func _raw_action(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = statement
	return action


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
	return SUPPORT.check("timing_abstraction_aces_test", label, actual, expected)
