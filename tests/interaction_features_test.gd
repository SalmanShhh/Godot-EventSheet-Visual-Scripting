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

	# ── Review fixes: viewport uid / caret / hit-test desyncs ──
	var vp_sheet: EventSheetResource = EventSheetResource.new()
	vp_sheet.host_class = "Node"
	var stats_a: RawCodeRow = RawCodeRow.new()
	stats_a.code = "class Stats:\n\tvar hp: int = 1"
	var stats_b: RawCodeRow = RawCodeRow.new()
	stats_b.code = "class Stats:\n\tvar mp: int = 2"
	vp_sheet.events.append(stats_a)
	vp_sheet.events.append(stats_b)
	var vp_editor: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	vp_editor.setup(vp_sheet)
	var vp: EventSheetViewport = vp_editor.get_viewport_control()
	# Two class blocks sharing one NAME used to share one row uid, so selecting or
	# disabling one silently mirrored onto the other.
	var header_uids: Dictionary = {}
	var second_stats_index: int = -1
	for flat_index in range(vp.get_flat_rows().size()):
		var flat_row: EventRowData = vp.get_flat_rows()[flat_index].get("row")
		if flat_row != null and flat_row.row_uid.begins_with("data_class_Stats"):
			header_uids[flat_row.row_uid] = true
			second_stats_index = flat_index
	all_passed = _check("same-named class blocks get DISTINCT row uids", header_uids.size(), 2) and all_passed
	# Caret re-derivation: select the second class by uid, corrupt the numeric index, refresh -
	# the caret must snap back to the SELECTED row (arrow keys acted on the wrong row before).
	vp._select_row(second_stats_index, -1)
	var selected_uid: String = (vp.get_flat_rows()[second_stats_index].get("row") as EventRowData).row_uid
	vp._selected_row_index = 0
	vp._refresh_rows()
	var caret_uid: String = ""
	if vp._selected_row_index >= 0 and vp._selected_row_index < vp.get_flat_rows().size():
		caret_uid = (vp.get_flat_rows()[vp._selected_row_index].get("row") as EventRowData).row_uid
	all_passed = _check("the caret re-derives from the selected uid after a rebuild", caret_uid, selected_uid) and all_passed
	# Chip spans draw their text at rect.x + padding_x - the hit-test must mirror that.
	var chip_span: SemanticSpan = SemanticSpan.new()
	chip_span.text = "42"
	chip_span.rect = Rect2(100.0, 0.0, 60.0, 20.0)
	chip_span.metadata = {"chip": true, "padding_x": 8.0}
	all_passed = _check("chip hit-tests start at rect.x + padding_x",
		vp._span_text_origin_x(chip_span, vp._get_font(), vp._get_font_size()), 108.0) and all_passed
	vp_editor.free()

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
