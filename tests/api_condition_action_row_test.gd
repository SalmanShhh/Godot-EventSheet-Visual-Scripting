# EventForge - the public API helper EventSheets.build_condition_action_row makes it easy to map a construct
# onto the sheet's event model: the discriminating text goes in a CONDITION cell, each action line in an
# ACTION cell. This is the primitive the switch/case dogfoods and custom blocks can reuse, so a feature
# reads as events rather than a text blob. Pins: it returns an EVENT row with the pattern in the condition
# lane and each body line in the action lane.
@tool
class_name ApiConditionActionRowTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())

	var row: EventRowData = EventSheets.build_condition_action_row(
		"State.IDLE", PackedStringArray(["velocity = Vector2.ZERO", "jump()"]), 1, null)
	ok = _check("the API builds a row when the dock is open", row != null, true) and ok
	if row != null:
		ok = _check("it is an EVENT row (so it gets the condition | action lanes)",
			row.row_type == EventRowData.RowType.EVENT, true) and ok
		ok = _check("the discriminating text is in the CONDITION cell", _lane_text(row, "condition"), "State.IDLE") and ok
		ok = _check("the first body line is in the ACTION cell", _lane_text(row, "action"), "velocity = Vector2.ZERO") and ok
		var action_count: int = 0
		for span: SemanticSpan in row.spans:
			if span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane")) == "action":
				action_count += 1
		ok = _check("both action lines render as action cells", action_count, 2) and ok

	dock.free()
	return ok


static func _lane_text(row: EventRowData, lane: String) -> String:
	for span: SemanticSpan in row.spans:
		if span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane")) == lane:
			return str(span.text)
	return "<none>"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] api_condition_action_row_test: %s" % label)
		return true
	print("[FAIL] api_condition_action_row_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
