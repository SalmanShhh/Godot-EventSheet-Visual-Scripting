# Godot EventSheets - the minimap column, and the History panel's log.
#
# Both are pictures of something the editor already holds, so both are pinned the same way: build
# the rows (or the edits) by hand, ask the pure part what it says about them, and compare VALUES.
# Nothing here needs an editor, a canvas or a theme.
@tool
class_name SheetMinimapTest
extends RefCounted


## Stands in for the dock's undo and redo: each restores the snapshot the funnel would, which is all
## the panel listens to.
class TravelDock:
	extends Control
	var panel: EventSheetHistoryPanel = null
	var _viewport: EventSheetViewport = null

	func _on_undo_requested() -> void:
		if panel.cursor > 0:
			panel.note_restored(panel.entries[panel.cursor - 1].get("before"))

	func _on_redo_requested() -> void:
		if panel.cursor < panel.entries.size():
			panel.note_restored(panel.entries[panel.cursor].get("after"))


static func run() -> bool:
	var passed: bool = true
	passed = _bar_kinds() and passed
	passed = _bars_of_a_fixture_sheet() and passed
	passed = _auto_show_rule() and passed
	passed = _history_labels() and passed
	passed = _history_touched_rows() and passed
	passed = _history_cursor_follows_the_snapshots() and passed
	passed = _history_travels_back_to_before_the_first_edit() and passed
	passed = _history_lights_rows_on_hover_not_on_click() and passed
	return passed


# ── One bar per row, tinted by what the row IS ────────────────────────────────────────────────


static func _bar_kinds() -> bool:
	var passed: bool = true
	passed = _check("a signal-backed event is a trigger bar",
		EventSheetMinimap.row_kind(_event_row("on_body_entered", 1)), "trigger") and passed
	passed = _check("an event with no conditions runs every tick",
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


# ── The History list, in the words the edits gave themselves ──────────────────────────────────


static func _history_labels() -> bool:
	var passed: bool = true
	passed = _check("an edit reads by its own name and the event it landed on",
		EventSheetHistoryPanel.entry_label("Add Group", 12, false), "Add Group   event 12") and passed
	passed = _check("an undone edit says so",
		EventSheetHistoryPanel.entry_label("Extract to Function", 4, true),
		"Extract to Function   event 4   (undone)") and passed
	passed = _check("an edit with no event beside it says only its name",
		EventSheetHistoryPanel.entry_label("Group Variables", 0, false), "Group Variables") and passed
	return passed


static func _history_touched_rows() -> bool:
	var before: EventSheetResource = _sheet(["a", "b"])
	var after: EventSheetResource = _sheet(["a", "b", "c"])
	return _check("the rows an edit touched are the ones one side has and the other does not",
		" ".join(EventSheetHistoryPanel.touched_uids(before, after)), "c")


static func _history_cursor_follows_the_snapshots() -> bool:
	var passed: bool = true
	var panel: EventSheetHistoryPanel = EventSheetHistoryPanel.new(null)
	var first_before: EventSheetResource = _sheet(["a"])
	var first_after: EventSheetResource = _sheet(["a", "b"])
	var second_after: EventSheetResource = _sheet(["a", "b", "c"])
	panel.record("Add Blank Event", first_before, first_after, 1)
	panel.record("Add Group", first_after, second_after, 2)
	passed = _check("two edits, both applied", panel.cursor, 2) and passed
	passed = _check("restoring the first step's own before undoes back past it",
		[panel.note_restored(first_before), panel.cursor], [true, 0]) and passed
	passed = _check("restoring the second step's after redoes forward to it",
		[panel.note_restored(second_after), panel.cursor], [true, 2]) and passed
	passed = _check("a snapshot from somewhere else moves nothing",
		panel.note_restored(_sheet(["z"])), false) and passed
	panel.cursor = 1
	panel.record("Paste", first_after, second_after, 3)
	passed = _check("an edit made after an undo drops what was waiting to be redone",
		[panel.entries.size(), str(panel.entries[1].get("label", ""))], [2, "Paste"]) and passed
	return passed


## The list's first line is the sheet before any of its edits, so a click can undo ALL of them -
## without it the furthest back a click reached was just after the first edit.
static func _history_travels_back_to_before_the_first_edit() -> bool:
	var passed: bool = true
	var dock: TravelDock = TravelDock.new()
	var panel: EventSheetHistoryPanel = EventSheetHistoryPanel.new(dock)
	dock.panel = panel
	panel.build()
	var first_after: EventSheetResource = _sheet(["a", "b"])
	panel.record("Add Blank Event", _sheet(["a"]), first_after, 1)
	panel.record("Add Group", first_after, _sheet(["a", "b", "c"]), 2)
	var first_line: TreeItem = panel.tree.get_root().get_first_child()
	passed = _check("the list opens with the sheet as it was opened",
		first_line.get_text(0), "• Opened this sheet") and passed
	# What a click on the line does (the selection handler, without a Tree selection that the
	# rebuild would free mid-signal in a headless run).
	panel.travel_to(int(first_line.get_metadata(0)) + 1)
	passed = _check("clicking it undoes every listed edit", panel.cursor, 0) and passed
	dock.free()
	return passed


## The touched rows light while the pointer is OVER an entry and go dark when it leaves - a click
## travels, it does not light anything.
static func _history_lights_rows_on_hover_not_on_click() -> bool:
	var passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	var panel: EventSheetHistoryPanel = editor._ensure_history_panel()
	panel.build()
	panel.record("Add Group", _sheet(["a"]), _sheet(["a", "c"]), 1)
	editor._current_sheet_path = "res://levels/player.gd"
	panel.refresh()
	passed = _check("the first line names the file the sheet was opened from",
		panel.tree.get_root().get_first_child().get_text(0), "• Opened player.gd") and passed
	var entry_line: TreeItem = panel.tree.get_root().get_first_child().get_next()
	panel.cursor = 0
	panel.refresh()
	passed = _check("the steps read in the theme's own text, an undone one in its muted text",
		[panel.tree.get_root().get_first_child().get_custom_color(0), panel.tree.get_root().get_child(1).get_custom_color(0)],
		[EventSheetPopupUI.text_color(), EventSheetPopupUI.muted_text_color()]) and passed
	panel.cursor = 1
	panel.refresh()
	entry_line = panel.tree.get_root().get_first_child().get_next()
	# Selected without travelling, so the click below is the only thing that could light rows.
	panel.tree.item_selected.disconnect(panel._on_entry_selected)
	entry_line.select(0)
	panel.tree.item_selected.connect(panel._on_entry_selected)
	panel.tree.item_mouse_selected.emit(Vector2.ZERO, MOUSE_BUTTON_LEFT)
	passed = _check("a click lights nothing", editor._viewport._row_highlight.keys(), []) and passed
	panel.highlight_entry(0)
	passed = _check("hovering the edit lights the row it added", editor._viewport._row_highlight.keys(), ["c"]) and passed
	panel.highlight_entry(-1)
	passed = _check("leaving the list clears the light", editor._viewport._row_highlight.keys(), []) and passed
	# In split view the light lands in the pane the reader is working in, like the Outline's jumps.
	editor._multi_view._toggle_split_view()
	var split: EventSheetViewport = editor._multi_view._split_viewport
	# The split is the pane the reader last worked in (a selection there makes it so).
	editor._active_viewport_ref = split
	panel.highlight_entry(0)
	passed = _check("in split view the hover lights the active pane, not the left one",
		[split._row_highlight.keys(), editor._viewport._row_highlight.keys()], [["c"], []]) and passed
	panel.highlight_entry(-1)
	editor._multi_view._toggle_split_view()
	editor.free()
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
