# Godot EventSheets - Replace Object References (the Construct gesture, param-aware)
# Select rows, pick a reference they use, give the new one - every matching token across
# params, With-Node scopes, pick filters, and raw code rewrites, token-safe. Pins: the
# reference enumeration (every shape found, sorted, self only as a whole value), the
# guarded rewrite ($Enemy NEVER touches $EnemySpawner), quoted-path literals, %unique
# swaps, the conservative self rule, and the replacement count.
@tool
class_name ReplaceObjectTest
extends RefCounted


static func _action(params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.codegen_template = "{target}.{property} = {value}"
	action.params = params
	return action


static func run() -> bool:
	var all_passed: bool = true

	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.with_node_target = "$Enemy"
	row.actions.append(_action({"target": "$Enemy", "property": "visible", "value": "false"}))
	row.actions.append(_action({"target": "$EnemySpawner", "property": "active", "value": "$Enemy.visible"}))
	row.actions.append(_action({"target": "%HealthBar", "property": "value", "value": "self"}))
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "$Enemy.get_children()"
	pick.iterator_name = "child"
	row.pick_filters.append(pick)
	var quoted_row: EventRow = EventRow.new()
	quoted_row.trigger_provider_id = "Core"
	quoted_row.trigger_id = "OnReady"
	quoted_row.actions.append(_action({"target": "$\"UI/Score Label\"", "property": "text", "value": "\"0\""}))
	var rows: Array = [row, quoted_row]

	# ---- enumeration: every reference shape, sorted, self included as whole-value only ----
	var references: Array[String] = EventSheetRefactor.collect_node_references(rows)
	all_passed = _check("every reference shape enumerates",
		references, ["$\"UI/Score Label\"", "$Enemy", "$EnemySpawner", "%HealthBar", "self"]) and all_passed

	# ---- the guarded rewrite: $Enemy swaps, $EnemySpawner survives ----
	var replaced: int = EventSheetRefactor.replace_node_reference(rows, "$Enemy", "$EliteEnemy")
	all_passed = _check("every $Enemy token rewrote (target, expression, scope, pick)", replaced, 4) and all_passed
	all_passed = _check("the plain target swapped", (row.actions[0] as ACEAction).params.get("target"), "$EliteEnemy") and all_passed
	all_passed = _check("$EnemySpawner is untouched", (row.actions[1] as ACEAction).params.get("target"), "$EnemySpawner") and all_passed
	all_passed = _check("the reference inside an expression swapped", (row.actions[1] as ACEAction).params.get("value"), "$EliteEnemy.visible") and all_passed
	all_passed = _check("the With-Node scope swapped", row.with_node_target, "$EliteEnemy") and all_passed
	all_passed = _check("the pick collection swapped", pick.collection_value, "$EliteEnemy.get_children()") and all_passed

	# ---- quoted paths replace literally ----
	var quoted_replaced: int = EventSheetRefactor.replace_node_reference(rows, "$\"UI/Score Label\"", "%ScoreLabel")
	all_passed = _check("a quoted path swaps literally", quoted_replaced, 1) and all_passed
	all_passed = _check("the quoted target now reads as the unique name", (quoted_row.actions[0] as ACEAction).params.get("target"), "%ScoreLabel") and all_passed

	# ---- self swaps ONLY whole values ----
	(row.actions[1] as ACEAction).params["value"] = "self.visible and true"
	var self_replaced: int = EventSheetRefactor.replace_node_reference(rows, "self", "$Player")
	all_passed = _check("whole-value self swapped", (row.actions[2] as ACEAction).params.get("value"), "$Player") and all_passed
	all_passed = _check("self inside an expression is NEVER touched", (row.actions[1] as ACEAction).params.get("value"), "self.visible and true") and all_passed
	all_passed = _check("the self pass counted only the whole value", self_replaced, 1) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] replace_object_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
