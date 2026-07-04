# Godot EventSheets - Budgeted For Each (frame-spreading Solution 2) codegen.
#
# A pick filter with frame_spread_count / frame_spread_budget_ms compiles to an in-place loop that
# processes a slice per frame over a persistent class-member snapshot, then resumes next frame. This
# asserts the emitted shape (cursor + snapshot members, top-of-loop budget break, pass-restart, validity
# guard, body inside the loop), that it PARSES, the order-by/while/first-N fallback, and that a plain
# loop is untouched (regression).
@tool
class_name BudgetedForEachTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# --- Case 1: count budget (process 2 per frame) -----------------------------------------------
	var out_count: String = _compile_loop("loopA", 2, 0.0, "")
	all_passed = _check("count: declares a persistent cursor member", out_count.contains("var __loop_cursor_loopA_0: int = 0"), true) and all_passed
	all_passed = _check("count: declares a persistent snapshot member", out_count.contains("var __loop_items_loopA_0: Array = []"), true) and all_passed
	all_passed = _check("count: snapshots the collection once per pass", out_count.contains("__loop_items_loopA_0 = Array([10, 20, 30, 40, 50])"), true) and all_passed
	all_passed = _check("count: restarts the pass at the end", out_count.contains("if __loop_cursor_loopA_0 >= __loop_items_loopA_0.size():"), true) and all_passed
	all_passed = _check("count: loops over the cursor", out_count.contains("while __loop_cursor_loopA_0 < __loop_items_loopA_0.size():"), true) and all_passed
	all_passed = _check("count: breaks at the per-frame count", out_count.contains("__done_loopA_0 >= 2"), true) and all_passed
	all_passed = _check("count: guards the break so each frame consumes at least one item", out_count.contains("if __done_loopA_0 > 0 and ("), true) and all_passed
	all_passed = _check("count: advances the cursor", out_count.contains("__loop_cursor_loopA_0 += 1"), true) and all_passed
	all_passed = _check("count: skips freed instances", out_count.contains("if num is Object and not is_instance_valid(num):"), true) and all_passed
	all_passed = _check("count: body runs inside the loop", out_count.contains("print(num)"), true) and all_passed
	all_passed = _check("count: output parses", _parses(out_count), true) and all_passed

	# --- Case 2: millisecond budget --------------------------------------------------------------
	var out_ms: String = _compile_loop("loopB", 0, 5.0, "")
	all_passed = _check("ms: arms a wall-clock fence", out_ms.contains("var __loop_end_loopB_0: int = Time.get_ticks_usec() + int(5.0 * 1000.0)"), true) and all_passed
	all_passed = _check("ms: breaks when over budget", out_ms.contains("Time.get_ticks_usec() >= __loop_end_loopB_0"), true) and all_passed
	all_passed = _check("ms: never stalls - at least one item per frame", out_ms.contains("if __done_loopB_0 > 0 and ("), true) and all_passed
	all_passed = _check("ms: output parses", _parses(out_ms), true) and all_passed

	# --- Case 3: fallback - frame-spread + order-by emits a NORMAL ordered loop, not a budgeted one --
	var out_fallback: String = _compile_loop("loopC", 2, 0.0, "num")
	all_passed = _check("fallback: no budgeted cursor member emitted", out_fallback.contains("__loop_cursor"), false) and all_passed
	all_passed = _check("fallback: emits the ordered sort", out_fallback.contains("sort_custom"), true) and all_passed
	all_passed = _check("fallback: emits a plain for-loop", out_fallback.contains("for num in"), true) and all_passed
	all_passed = _check("fallback: output parses", _parses(out_fallback), true) and all_passed

	# --- Case 4: regression - a plain loop (no frame-spread) is untouched -------------------------
	var out_plain: String = _compile_loop("loopD", 0, 0.0, "")
	all_passed = _check("plain: emits a plain for-loop", out_plain.contains("for num in [10, 20, 30, 40, 50]:"), true) and all_passed
	all_passed = _check("plain: emits NO budgeted machinery", out_plain.contains("__loop_cursor"), false) and all_passed
	all_passed = _check("plain: output parses", _parses(out_plain), true) and all_passed

	# --- Case 5: footgun warning - a budgeted loop only resumes under a per-frame trigger -----------
	all_passed = _check("warns when budgeted under a one-shot trigger", _warns_one_shot("OnReady"), true) and all_passed
	all_passed = _check("stays quiet when budgeted under On Process", _warns_one_shot("OnProcess"), false) and all_passed

	return all_passed


# Builds an On Process event with one EXPRESSION pick over [10,20,30,40,50] + a print(num) body, then
# compiles it. count/budget_ms drive frame-spreading; order_by exercises the fallback.
static func _compile_loop(uid: String, count: int, budget_ms: float, order_by: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.event_uid = uid
	var pick: PickFilter = PickFilter.new()
	pick.enabled = true
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "[10, 20, 30, 40, 50]"
	pick.iterator_name = "num"
	pick.frame_spread_count = count
	pick.frame_spread_budget_ms = budget_ms
	pick.order_by_expression = order_by
	event.pick_filters.append(pick)
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "Print"
	act.codegen_template = "print({val})"
	act.params = {"val": "num"}
	event.actions.append(act)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://es_budgeted_%s.gd" % uid).get("output", ""))


# True if compiling a budgeted loop under `trigger` produces the one-shot-trigger footgun warning.
static func _warns_one_shot(trigger: String) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger
	event.event_uid = "warnloop"
	var pick: PickFilter = PickFilter.new()
	pick.enabled = true
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "[1, 2, 3]"
	pick.iterator_name = "n"
	pick.frame_spread_count = 1
	event.pick_filters.append(pick)
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "Print"
	act.codegen_template = "print({v})"
	act.params = {"v": "n"}
	event.actions.append(act)
	sheet.events.append(event)
	var warnings: Array = SheetCompiler.compile(sheet, "user://es_warn_%s.gd" % trigger).get("warnings", []) as Array
	for w: Variant in warnings:
		if str(w).contains("one-shot trigger"):
			return true
	return false


static func _parses(source: String) -> bool:
	var generated: GDScript = GDScript.new()
	generated.source_code = source
	return generated.reload(true) == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] budgeted_for_each_test: %s" % label)
		return true
	print("[FAIL] budgeted_for_each_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
