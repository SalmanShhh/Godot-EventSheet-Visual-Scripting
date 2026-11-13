# Godot EventSheets - the minimap column.
#
# It is a picture of something the editor already holds, so it is pinned by building the rows by
# hand, asking the pure part what it says about them, and comparing VALUES.
# Nothing here needs an editor, a canvas or a theme.
@tool
class_name SheetMinimapTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _bar_kinds() and passed
	passed = _bars_of_a_fixture_sheet() and passed
	passed = _auto_show_rule() and passed
	return passed


# ── One bar per row, tinted by what the row IS ────────────────────────────────────────────────


static func _bar_kinds() -> bool:
	var passed: bool = true
	passed = _check("a signal-backed event is a trigger bar",
		EventSheetMinimap.row_kind(_event_row("on_body_entered", 1)), "trigger") and passed
	passed = _check("an event with no conditions runs every frame",
		EventSheetMinimap.row_kind(_event_row("", 0)), "tick") and passed
	passed = _check("an event with conditions is a plain event",
		EventSheetMinimap.row_kind(_event_row("", 2)), "event") and passed
	passed = _check("a group is a group bar",
		EventSheetMinimap.row_kind(_group_row("Enemies")), "group") and passed
	passed = _check("a comment is a comment bar",
		EventSheetMinimap.row_kind(_comment_row()), "comment") and passed
	passed = _check("a Script block is a Script block bar",
		EventSheetMinimap.row_kind(_script_row()), "script") and passed
	passed = _check("a function is a function bar",
		EventSheetMinimap.row_kind(_function_row()), "function") and passed
	var disabled: EventRowData = _event_row("on_body_entered", 1)
	disabled.disabled = true
	passed = _check("a disabled event keeps its place and stops asking to be read",
		EventSheetMinimap.row_kind(disabled), "disabled") and passed
	return passed


static func _bars_of_a_fixture_sheet() -> bool:
	var passed: bool = true
	var group: EventRowData = _group_row("Enemies")
	var bookmarked: EventRowData = _event_row("", 0)
	bookmarked.bookmark_enabled = true
	var flagged: EventRowData = _event_row("", 3)
	flagged.error_message = "This object has no such property."
	var rows: Array = [
		{"row": _comment_row()},
		{"row": group},
		{"row": _event_row("on_body_entered", 1)},
		{"row": bookmarked},
		{"row": flagged},
		{"row": _script_row()}
	]
	var bars: Array[Dictionary] = EventSheetMinimap.bars_of(rows)
	passed = _check("the column reads the sheet in order",
		_kinds_of(bars), "comment · group · trigger · tick · event · script") and passed
	passed = _check("the group is the one bar that can answer a hover",
		_labels_of(bars), "Enemies") and passed
	passed = _check("a bookmark is a mark in the margin",
		_marked(bars, "bookmarked"), "3") and passed
	passed = _check("a flagged row is a mark in the margin",
		_marked(bars, "flagged"), "4") and passed
	return passed


static func _auto_show_rule() -> bool:
	var passed: bool = true
	passed = _check("a short sheet leaves the column off on its own",
		EventSheetDock.minimap_shown_for(EventSheetDock.MINIMAP_AUTO, 12), false) and passed
	passed = _check("a sheet past 200 events shows the column on its own",
		EventSheetDock.minimap_shown_for(EventSheetDock.MINIMAP_AUTO, 201), true) and passed
	passed = _check("an explicit off holds on a long sheet",
		EventSheetDock.minimap_shown_for(0, 900), false) and passed
	passed = _check("an explicit on holds on a short sheet",
		EventSheetDock.minimap_shown_for(1, 3), true) and passed
	return passed


# ── Fixture rows and sheets ───────────────────────────────────────────────────────────────────


static func _event_row(trigger_id: String, condition_count: int) -> EventRowData:
	var event: EventRow = EventRow.new()
	event.trigger_id = trigger_id
	for index: int in condition_count:
		event.conditions.append(ACECondition.new())
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = event
	return row_data


static func _group_row(group_name: String) -> EventRowData:
	var group: EventGroup = EventGroup.new()
	group.group_name = group_name
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.GROUP
	row_data.source_resource = group
	return row_data


static func _comment_row() -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.COMMENT
	row_data.source_resource = CommentRow.new()
	return row_data


static func _script_row() -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = RawCodeRow.new()
	return row_data


static func _function_row() -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = EventFunction.new()
	return row_data


static func _sheet(uids: PackedStringArray) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	for uid: String in uids:
		var event: EventRow = EventRow.new()
		event.event_uid = uid
		sheet.events.append(event)
	return sheet


static func _kinds_of(bars: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for bar: Dictionary in bars:
		parts.append(str(bar.get("kind", "")))
	return " · ".join(parts)


static func _labels_of(bars: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for bar: Dictionary in bars:
		var label: String = str(bar.get("label", ""))
		if not label.is_empty():
			parts.append(label)
	return " · ".join(parts)


static func _marked(bars: Array[Dictionary], key: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for index: int in bars.size():
		if bool(bars[index].get(key, false)):
			parts.append(str(index))
	return " · ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] minimap/history: %s" % label)
		return true
	print("[FAIL] minimap/history: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
