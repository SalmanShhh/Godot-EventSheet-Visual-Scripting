# Godot EventSheets - Construct-style interaction features:
#   - OR / AND condition blocks (right-click an event → "Convert to OR Block"): conditions join with
#     `or` instead of `and`.
#   - Condition inversion (right-click a condition → "Invert Condition"): compiles to `not (…)`.
#   - A TRIGGER can't be inverted (no "not On X"); the menu disables Invert for triggers - and the
#     compiler never read trigger.negated, so the old enabled-for-triggers item was a silent no-op.
@tool
class_name InteractionFeaturesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── OR / AND block: conditions AND-join by default, OR-join in OR mode ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions.append(_compare_condition("a"))
	event.conditions.append(_compare_condition("b"))
	sheet.events.append(event)

	var and_out: String = str(SheetCompiler.compile(sheet, "user://__if_and.gd").get("output", ""))
	all_passed = _check("AND block joins conditions with `and`", and_out.contains("a > 0 and b > 0"), true) and all_passed
	event.condition_mode = EventRow.ConditionMode.OR
	var or_out: String = str(SheetCompiler.compile(sheet, "user://__if_or.gd").get("output", ""))
	all_passed = _check("OR block joins conditions with `or`", or_out.contains("a > 0 or b > 0"), true) and all_passed

	# ── Condition inversion → `not (…)`, reversible ──
	event.condition_mode = EventRow.ConditionMode.AND
	event.conditions[0].negated = true
	var inv_out: String = str(SheetCompiler.compile(sheet, "user://__if_inv.gd").get("output", ""))
	all_passed = _check("inverted condition compiles to `not (`", inv_out.contains("not (a > 0)"), true) and all_passed
	event.conditions[0].negated = false
	var uninv_out: String = str(SheetCompiler.compile(sheet, "user://__if_uninv.gd").get("output", ""))
	all_passed = _check("un-inverting removes the `not`", uninv_out.contains("not ("), false) and all_passed

	# ── The condition menu disables Invert for a TRIGGER, enables it for a condition ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(null)
	var ctx_event: EventRow = EventRow.new()
	ctx_event.trigger = ACECondition.new()
	ctx_event.conditions.append(_compare_condition("x"))
	var row_data: EventRowData = EventRowData.new()
	row_data.source_resource = ctx_event
	row_data.row_type = EventRowData.RowType.EVENT
	dock._context_row = row_data
	var invert_index: int = dock._condition_context_menu.get_item_index(4)  # CONDITION_MENU_INVERT

	dock._context_hit = {"span_metadata": {"kind": "trigger", "ace_index": -1}}
	dock._configure_context_menu(dock._condition_context_menu)
	all_passed = _check("Invert is disabled when the clicked span is a trigger",
		invert_index >= 0 and dock._condition_context_menu.is_item_disabled(invert_index), true) and all_passed

	dock._context_hit = {"span_metadata": {"kind": "condition", "ace_index": 0}}
	dock._configure_context_menu(dock._condition_context_menu)
	all_passed = _check("Invert is enabled when the clicked span is a condition",
		not dock._condition_context_menu.is_item_disabled(invert_index), true) and all_passed

	# Right-clicking an event's bounds (the conditions-lane background - no specific condition/action span)
	# selects the whole event and opens the EVENT row menu, which offers the OR/AND block toggle.
	dock._on_viewport_context_menu_requested(row_data, {"span_metadata": {}}, Vector2.ZERO)
	all_passed = _check("right-clicking an event's bounds shows the event menu with the OR/AND block toggle",
		dock._row_context_menu.get_item_index(8) >= 0, true) and all_passed  # 8 = ROW_MENU_TOGGLE_CONDITION_BLOCK
	dock.free()

	return all_passed


## A trivial always-emittable condition: codegen_template carries the whole expression (no params).
static func _compare_condition(var_name: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareVar"
	condition.codegen_template = "%s > 0" % var_name
	return condition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] interaction_features_test: %s" % label)
		return true
	print("[FAIL] interaction_features_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
