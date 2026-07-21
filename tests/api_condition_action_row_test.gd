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

	# ── add_field_cell: named slots read as condition-style CELLS, one per line. This is the primitive a
	# published verb's parameters are built from, so an extension's slots and a built-in verb's inputs
	# are literally the same code path.
	var slot_row: EventRowData = EventSheets.build_condition_action_row("Loot Table", PackedStringArray(), 0, null)
	if slot_row != null:
		var before: int = slot_row.spans.size()
		EventSheets.add_field_cell(slot_row, "rarity", "one of (common, rare)", {"kind": "my_slot", "slot_index": 0})
		EventSheets.add_field_cell(slot_row, "weight", "number", {"kind": "my_slot", "slot_index": 1})
		ok = _check("add_field_cell appends one cell per slot", slot_row.spans.size() - before, 2) and ok
		var first_cell: Dictionary = _meta_of_kind(slot_row, "my_slot", 0)
		var second_cell: Dictionary = _meta_of_kind(slot_row, "my_slot", 1)
		ok = _check("the slot NAME leads the cell as its object label", str(first_cell.get("object_label", "")), "rarity") and ok
		ok = _check("a field cell is a filled chip in the condition lane",
			bool(first_cell.get("chip", false)) and str(first_cell.get("lane", "")) == "condition", true) and ok
		ok = _check("caller metadata survives the merge (so a click can route back)",
			int(first_cell.get("slot_index", -1)), 0) and ok
		ok = _check("cells stack one per line", int(second_cell.get("line_index", -1)) - int(first_cell.get("line_index", -1)), 1) and ok

	# ── build_caption_row: a line of prose welded above the row it describes.
	var caption: EventRowData = EventSheets.build_caption_row("Rolls a drop for the given table.", 0, "caption_test")
	if caption != null:
		ok = _check("a caption is a COMMENT row (so it word-wraps)", caption.row_type == EventRowData.RowType.COMMENT, true) and ok
		ok = _check("a caption is inert (no resource to edit / drag / delete)", caption.source_resource == null, true) and ok
		ok = _check("a caption welds to the row below it", caption.attached_below, true) and ok

	dock.free()
	return ok


## Metadata of the Nth span carrying `kind` - field cells are inspected through metadata, since their
## identity (the slot name, the caller's index) lives there rather than in the drawn text.
static func _meta_of_kind(row: EventRowData, kind: String, nth: int) -> Dictionary:
	var seen: int = 0
	for span: SemanticSpan in row.spans:
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		if str(metadata.get("kind", "")) == kind:
			if seen == nth:
				return metadata
			seen += 1
	return {}


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
