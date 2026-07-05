# EventForge - Performance-parity guard for generated GDScript
#
# Hard project constraint (SPEC-gdscript-pairing, Principles #5): generated code must run
# exactly as fast as hand-written GDScript. This test compiles a representative sheet that
# exercises every emitting feature and asserts the output contains no runtime indirection
# (call()/Callable/plugin classes) and keeps static typing where the compiler knows types.
# If a future feature trips this test, fix the codegen - do not relax the assertions.
@tool
class_name CodegenParityTest
extends RefCounted

## Substrings that must never appear in generated output: each one would mean runtime
## indirection or a plugin dependency, breaking parity with hand-written GDScript.
const BANNED_PATTERNS: Array[String] = [
	".call(",
	"Callable(",
	"call_deferred(\"",
	"get_meta(",
	"set_meta(",
	"EventForge",
	"EventSheet",
	"ACERegistry",
	"ACEDefinition",
	"emit_signal(\""
]


static func run() -> bool:
	var all_passed: bool = true

	# Representative sheet: typed globals, tree variable, class-level + in-flow GDScript,
	# trigger + condition + builtin action + baked addon-template action, sheet function.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "ammo"
	tree_var.type_name = "int"
	tree_var.default_value = 3
	sheet.events.append(tree_var)
	var helper_block: RawCodeRow = RawCodeRow.new()
	helper_block.code = "func heal(amount: int) -> void:\n\thealth += amount"
	sheet.events.append(helper_block)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsOnFloor"
	event.conditions.append(condition)
	var builtin_action: ACEAction = ACEAction.new()
	builtin_action.provider_id = "Core"
	builtin_action.ace_id = "QueueFree"
	event.actions.append(builtin_action)
	var addon_action: ACEAction = ACEAction.new()
	addon_action.provider_id = "DemoHealthAddon"
	addon_action.ace_id = "method:heal"
	addon_action.params = {"amount": 5}
	addon_action.codegen_template = "health += {amount}"
	event.actions.append(addon_action)
	var inline_block: RawCodeRow = RawCodeRow.new()
	inline_block.code = "velocity.x = 0.0"
	event.actions.append(inline_block)
	sheet.events.append(event)
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "reload"
	sheet.functions.append(event_function)

	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_parity.gd").get("output", ""))
	all_passed = _check("representative sheet compiled", not output.strip_edges().is_empty(), true) and all_passed

	# No runtime indirection or plugin references anywhere in the output. The header comment
	# mentions the generator by name, so only the code body (after the header) is scanned.
	var body_start: int = output.find("extends ")
	var code_body: String = output.substr(maxi(body_start, 0))
	for banned in BANNED_PATTERNS:
		all_passed = _check("generated code avoids '%s'" % banned, code_body.contains(banned), false) and all_passed

	# Direct, typed output is present.
	all_passed = _check("globals emit with static types", code_body.contains("@export var health: int = 100"), true) and all_passed
	all_passed = _check("tree variables emit with static types", code_body.contains("var ammo: int = 3"), true) and all_passed
	all_passed = _check("conditions compile to direct if-expressions", code_body.contains("if is_on_floor():"), true) and all_passed
	all_passed = _check("builtin actions compile to direct calls", code_body.contains("queue_free()"), true) and all_passed
	all_passed = _check("addon actions compile to direct statements", code_body.contains("health += 5"), true) and all_passed
	all_passed = _check("functions emit typed signatures", code_body.contains("func reload() -> void:"), true) and all_passed
	all_passed = _check("no stray await (only flagged actions await)", code_body.contains("await "), false) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] codegen_parity_test: %s" % label)
		return true
	print("[FAIL] codegen_parity_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
