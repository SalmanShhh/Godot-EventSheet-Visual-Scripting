# EventForge - silent-bug regression suite
#
# Pins the silent defects an adversarial sweep reproduced (each shipped invalid/wrong behaviour
# WITHOUT crashing at compile time): an awaited multi-statement action template, an unresolvable
# condition silently OPENING the gate, a negated stateful Every-X-Seconds, and charge abilities that
# only spent one stack per regen cycle.
@tool
class_name SilentBugRegressionTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# An AWAITED multi-statement action template used to put `await` on the `var … =` line (parse err).
	var await_sheet: EventSheetResource = EventSheetResource.new()
	await_sheet.host_class = "Node2D"
	var await_event: EventRow = EventRow.new()
	await_event.trigger_provider_id = "Core"
	await_event.trigger_id = "OnReady"
	var await_action: ACEAction = ACEAction.new()
	await_action.provider_id = "Core"
	await_action.ace_id = "SpawnSceneAt"
	await_action.codegen_template = "var __spawn_t = load({path}).instantiate()\n__spawn_t.position = {position}\nadd_child(__spawn_t)"
	await_action.params = {"path": "\"res://e.tscn\"", "position": "Vector2(0, 0)"}
	await_action.is_awaited = true
	await_event.actions.append(await_action)
	await_sheet.events.append(await_event)
	var await_out: String = str(SheetCompiler.compile(await_sheet, "user://eventsheets_await.gd").get("output", ""))
	all_passed = _check("awaited multi-line: await goes on the trailing call, not the var line",
		await_out.contains("await add_child(__spawn_t)") and not await_out.contains("await var "), true) and all_passed
	var await_script: GDScript = GDScript.new()
	await_script.source_code = await_out
	all_passed = _check("awaited multi-line output parses", await_script.reload() == OK, true) and all_passed

	# An unresolvable condition (addon missing / stale id) used to be silently dropped, OPENING the gate.
	var ghost_sheet: EventSheetResource = EventSheetResource.new()
	ghost_sheet.host_class = "Node"
	var ghost_event: EventRow = EventRow.new()
	ghost_event.trigger_provider_id = "Core"
	ghost_event.trigger_id = "OnProcess"
	var ghost_cond: ACECondition = ACECondition.new()
	ghost_cond.provider_id = "GhostAddon"
	ghost_cond.ace_id = "SomeGoneCondition"
	ghost_event.conditions.append(ghost_cond)
	var ghost_action: ACEAction = ACEAction.new()
	ghost_action.provider_id = "Core"
	ghost_action.ace_id = "X"
	ghost_action.codegen_template = "fire_missile()"
	ghost_event.actions.append(ghost_action)
	ghost_sheet.events.append(ghost_event)
	var ghost_result: Dictionary = SheetCompiler.compile(ghost_sheet, "user://eventsheets_ghost.gd")
	var ghost_out: String = str(ghost_result.get("output", ""))
	all_passed = _check("unresolvable condition fails CLOSED (if false), not open",
		ghost_out.contains("if false:") and ghost_out.contains("fire_missile()"), true) and all_passed
	all_passed = _check("unresolvable condition warns",
		str(ghost_result.get("warnings")).to_lower().contains("could not be resolved"), true) and all_passed

	# Negating a stateful Every-X-Seconds used to put the timer reset inside the inverted `if`.
	var neg_sheet: EventSheetResource = EventSheetResource.new()
	neg_sheet.host_class = "Node"
	var neg_event: EventRow = EventRow.new()
	neg_event.trigger_provider_id = "Core"
	neg_event.trigger_id = "OnProcess"
	var neg_cond: ACECondition = ACECondition.new()
	neg_cond.provider_id = "Core"
	neg_cond.ace_id = "EveryXSeconds"
	neg_cond.member_declaration = "var __every_t: float = 0.0"
	neg_cond.codegen_prelude = "__every_t += delta"
	neg_cond.codegen_on_true = "__every_t = fmod(__every_t, maxf(1.0, 0.001))"
	neg_cond.codegen_template = "__every_t >= maxf(1.0, 0.001)"
	neg_cond.negated = true
	neg_event.conditions.append(neg_cond)
	var neg_action: ACEAction = ACEAction.new()
	neg_action.provider_id = "Core"
	neg_action.ace_id = "X"
	neg_action.codegen_template = "spawn()"
	neg_event.actions.append(neg_action)
	neg_sheet.events.append(neg_event)
	var neg_result: Dictionary = SheetCompiler.compile(neg_sheet, "user://eventsheets_neg.gd")
	var neg_out: String = str(neg_result.get("output", ""))
	all_passed = _check("negated stateful is NOT inverted (no `if not (`)",
		neg_out.contains("if __every_t >= maxf(1.0, 0.001):") and not neg_out.contains("if not ("), true) and all_passed
	all_passed = _check("negated stateful warns it can not be inverted",
		str(neg_result.get("warnings")).to_lower().contains("can not be inverted"), true) and all_passed

	# Abilities pack: a 3-charge ability used to spend only 1 stack (activate was gated by the
	# per-stack regen cooldown). The fix gates activation on stacks alone.
	var ability_script: GDScript = load("res://eventsheet_addons/abilities/abilities_behavior.gd")
	if ability_script != null:
		var ab: Node = ability_script.new()
		ab.create_ability_with_stacks("dash", 2.0, 3, true)
		var spent: int = 0
		for i in range(3):
			var before: int = int(ab.get_stacks("dash"))
			ab.activate_ability("dash")
			if int(ab.get_stacks("dash")) < before:
				spent += 1
		all_passed = _check("3-charge ability spends all 3 charges (regen cooldown does not lock remaining stacks)", spent, 3) and all_passed
		all_passed = _check("after spending all charges the ability is not ready", bool(ab.is_ready("dash")), false) and all_passed
		ab.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] silent_bug_regression_test: %s" % label)
		return true
	print("[FAIL] silent_bug_regression_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
