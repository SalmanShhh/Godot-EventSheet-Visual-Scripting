# Godot EventSheets — Group aggregate expressions (Sum / Average / Lowest / Highest in group).
#
# These roll a numeric member up across every node in a group without writing a loop (the "average
# health of all enemies" case). Verifies they register under "Groups", carry the exact reduce-based
# one-liners, compile to valid GDScript inside a real sheet, and — running the reduce lambda against a
# live array of objects — actually compute the right totals (catching any silent error in the lambda).
# The headless test runner does its work in _init(), before the SceneTree root viewport exists, so the
# reduce is exercised against a literal array (the novel part); get_nodes_in_group is stock Godot API.
# Min/Max are checked on an empty array so the no-members case yields the +/-INF sentinel, never a crash.
@tool
extends RefCounted
class_name GroupAggregatesTest

const GROUP_CALL := "get_tree().get_nodes_in_group({group})"

static func run() -> bool:
	var all_passed: bool = true
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor

	# Registration: the four roll-ups live alongside Count under the "Groups" category.
	for ace_id: String in ["SumInGroup", "AverageInGroup", "MinInGroup", "MaxInGroup"]:
		all_passed = _check("ACE registered: %s" % ace_id, by_id.has(ace_id), true) and all_passed
		all_passed = _check("%s groups under Groups" % ace_id, str(by_id[ace_id].category) if by_id.has(ace_id) else "", "Groups") and all_passed
		all_passed = _check("%s is an expression" % ace_id, by_id[ace_id].ace_type == ACEDescriptor.ACEType.EXPRESSION if by_id.has(ace_id) else false, true) and all_passed

	# Templates are reduce one-liners over get_nodes_in_group (no helper func, zero runtime).
	all_passed = _check("Sum reduces with a 0.0 seed", str(by_id["SumInGroup"].codegen_template).ends_with(", 0.0)"), true) and all_passed
	all_passed = _check("Lowest seeds at +INF", str(by_id["MinInGroup"].codegen_template).ends_with(", INF)"), true) and all_passed
	all_passed = _check("Highest seeds at -INF", str(by_id["MaxInGroup"].codegen_template).ends_with(", -INF)"), true) and all_passed

	# Compile a sheet that uses all four in _ready: proves each template is valid GDScript in context.
	all_passed = _check("Aggregator sheet compiles to valid GDScript", _compiles(by_id), true) and all_passed

	# Run the reduce lambdas against three live enemies (health 10/20/30): the math must be exact.
	var enemies: Array = [_make_enemy(10.0), _make_enemy(20.0), _make_enemy(30.0)]
	all_passed = _check("Sum In Group totals the member", _reduce_value(by_id, "SumInGroup", enemies), 60.0) and all_passed
	all_passed = _check("Average In Group divides by the count", _reduce_value(by_id, "AverageInGroup", enemies), 20.0) and all_passed
	all_passed = _check("Lowest In Group finds the minimum", _reduce_value(by_id, "MinInGroup", enemies), 10.0) and all_passed
	all_passed = _check("Highest In Group finds the maximum", _reduce_value(by_id, "MaxInGroup", enemies), 30.0) and all_passed

	# Empty group: Sum is 0, and Min/Max fall back to their sentinels rather than erroring.
	all_passed = _check("Sum of an empty group is 0", _reduce_value(by_id, "SumInGroup", []), 0.0) and all_passed
	all_passed = _check("Lowest of an empty group is +INF (no crash)", _reduce_value(by_id, "MinInGroup", []), INF) and all_passed
	all_passed = _check("Highest of an empty group is -INF (no crash)", _reduce_value(by_id, "MaxInGroup", []), -INF) and all_passed

	return all_passed

## A bare object whose script exposes a numeric `health`, so the reduce can read __n.health.
static func _make_enemy(health_value: float) -> Object:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nvar health: float = 0.0\n"
	script.reload()
	var enemy: Object = script.new()
	enemy.set("health", health_value)
	return enemy

## Runs ace_id's reduce body against a literal array by swapping the get_nodes_in_group call for the
## passed-in node list. Exercises the exact reduce lambda the template ships, without needing a tree.
static func _reduce_value(by_id: Dictionary, ace_id: String, nodes: Array) -> Variant:
	var body: String = str(by_id[ace_id].codegen_template).replace(GROUP_CALL, "__nodes").replace("{property}", "health")
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\nfunc compute(__nodes: Array) -> Variant:\n\treturn %s\n" % body
	if script.reload() != OK:
		return null
	return script.new().call("compute", nodes)

## Compiles a sheet that assigns each aggregate expression to a member var in _ready; true if the
## generated GDScript reloads cleanly (no run needed — this only proves the templates are valid).
static func _compiles(by_id: Dictionary) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {
		"agg_sum": {"type": "float", "default": 0.0, "exported": false},
		"agg_avg": {"type": "float", "default": 0.0, "exported": false},
		"agg_min": {"type": "float", "default": 0.0, "exported": false},
		"agg_max": {"type": "float", "default": 0.0, "exported": false},
	}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_set_var("agg_sum", _expr(by_id, "SumInGroup")))
	event.actions.append(_set_var("agg_avg", _expr(by_id, "AverageInGroup")))
	event.actions.append(_set_var("agg_min", _expr(by_id, "MinInGroup")))
	event.actions.append(_set_var("agg_max", _expr(by_id, "MaxInGroup")))
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://__group_aggregates_compiled.gd").get("output", ""))
	var script: GDScript = GDScript.new()
	script.source_code = output
	return script.reload() == OK

## The registered expression for ace_id with a group + a `health` property substituted in.
static func _expr(by_id: Dictionary, ace_id: String) -> String:
	return str(by_id[ace_id].codegen_template).replace("{group}", "\"enemies\"").replace("{property}", "health")

## A SetVar action assigning a raw expression to a member variable (as the dock would apply it).
static func _set_var(var_name: String, value_expr: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.codegen_template = "{var_name} = {value}"
	action.params = {"var_name": var_name, "value": value_expr}
	return action

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] group_aggregates_test: %s" % label)
		return true
	print("[FAIL] group_aggregates_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
