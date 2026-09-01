# Godot EventSheets - authoring parity for the shapes the sheet already READS: the three
# event-shape commands (Make 'Or' block / Make 'And' block, Add blank sub-event, Add 'Else') live on
# the right-click menu AND the Add menu, in the words the reading uses, and they are greyed while the
# sheet is a read-only preview. On an opened .gd, Make 'Or' block rewrites the event's joined
# condition (`a and b` <-> `a or b`) and leaves the rest of the file byte-identical.
# Pins: the menu labels, the live Or/And relabel, the preview greying, and the byte-exact rewrite.
@tool
class_name OrBlockAuthoringTest
extends RefCounted

const SOURCE := """extends Node


func _process(delta: float) -> void:
	if health > 0 and shield > 0:
		queue_free()
"""


static func run() -> bool:
	var ok: bool = true

	# ── The rewrite: an opened .gd whose `and` becomes `or`, and nothing else moves ──
	var opened: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	opened.external_source_path = "user://or_block_authoring.gd"
	var before: String = str(SheetCompiler.compile(opened, "user://or_block_authoring.gd").get("output", ""))
	ok = _check("the source round-trips before the rewrite", before, SOURCE) and ok
	var joined: EventRow = _first_event_with_two_conditions(opened.events)
	ok = _check("the opened file has one event joining two conditions", joined != null, true) and ok
	if joined != null:
		ok = _check("`and` reads as an AND block", joined.condition_mode, EventRow.ConditionMode.AND) and ok
		joined.condition_mode = EventRow.ConditionMode.OR
		var after: String = str(SheetCompiler.compile(opened, "user://or_block_authoring.gd").get("output", ""))
		ok = _check("Make 'Or' block rewrites just the joiner", after, SOURCE.replace(" and ", " or ")) and ok
		joined.condition_mode = EventRow.ConditionMode.AND
		ok = _check("Make 'And' block puts the file back byte-for-byte",
			str(SheetCompiler.compile(opened, "user://or_block_authoring.gd").get("output", "")), SOURCE) and ok

	# ── The menu: the sheet's own words, and the live Or/And relabel ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	sheet.events.append(event_row)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var row_data: EventRowData = null
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var candidate: EventRowData = entry.get("row")
		if candidate != null and candidate.source_resource == event_row:
			row_data = candidate
	dock._context_row = row_data
	dock._build_row_context_menu(row_data)
	ok = _check("the blank sub-event says the key that makes one",
		_item_text(dock, dock.ROW_MENU_ADD_SUB_EVENT), "Add blank sub-event (B)") and ok
	dock._active_view()._selected_row_uids[row_data.row_uid] = true
	row_data.selected = true
	dock._configure_context_menu(dock._row_context_menu)
	ok = _check("an AND event offers Make 'Or' block",
		_item_text(dock, dock.ROW_MENU_TOGGLE_CONDITION_BLOCK), "Make 'Or' block") and ok
	ok = _check("Else is offered by the word the sheet reads",
		_item_text(dock, dock.ROW_MENU_MAKE_ELSE), "Add 'Else'") and ok
	event_row.condition_mode = EventRow.ConditionMode.OR
	dock._configure_context_menu(dock._row_context_menu)
	ok = _check("an OR event offers the way back",
		_item_text(dock, dock.ROW_MENU_TOGGLE_CONDITION_BLOCK), "Make 'And' block") and ok

	# ── A read-only preview greys all three: a preview never rewrites the file ──
	sheet.read_only = true
	dock._configure_context_menu(dock._row_context_menu)
	ok = _check("Make 'Or' block is greyed on a preview",
		_item_disabled(dock, dock.ROW_MENU_TOGGLE_CONDITION_BLOCK), true) and ok
	ok = _check("Add blank sub-event is greyed on a preview",
		_item_disabled(dock, dock.ROW_MENU_ADD_SUB_EVENT), true) and ok
	ok = _check("Add 'Else' is greyed on a preview",
		_item_disabled(dock, dock.ROW_MENU_MAKE_ELSE), true) and ok
	sheet.read_only = false
	dock._configure_context_menu(dock._row_context_menu)
	ok = _check("an editable sheet offers them again",
		_item_disabled(dock, dock.ROW_MENU_ADD_SUB_EVENT), false) and ok

	# ── The Add menu carries the same three commands, in the same words ──
	var add_labels: PackedStringArray = PackedStringArray()
	for index: int in range(dock._add_menu_popup.item_count):
		add_labels.append(dock._add_menu_popup.get_item_text(index))
	# The Add menu says the same command WITHOUT the key typed into its words: the cascade prints
	# every key it has from the one shortcut table instead, so this item carries B as a Shortcut on
	# the item rather than as four characters of its label (pinned in resting_toolbar_test). The
	# right-click menu still spells it out, and that reading is pinned above.
	ok = _check("the Add menu offers a blank sub-event",
		add_labels.has("Add blank sub-event"), true) and ok
	ok = _check("the Add menu offers an Or block", add_labels.has("Make 'Or' block"), true) and ok
	ok = _check("the Add menu offers Else", add_labels.has("Add 'Else'"), true) and ok

	dock.free()
	return ok


static func _first_event_with_two_conditions(rows: Array) -> EventRow:
	for row: Variant in rows:
		if row is EventRow:
			var event_row: EventRow = row
			if event_row.conditions.size() >= 2:
				return event_row
			var nested: EventRow = _first_event_with_two_conditions(event_row.sub_events)
			if nested != null:
				return nested
		elif row is EventGroup:
			var group: EventGroup = row
			var in_group: EventRow = _first_event_with_two_conditions(
				group.events if not group.events.is_empty() else group.rows)
			if in_group != null:
				return in_group
	return null


static func _item_text(dock: EventSheetDock, id: int) -> String:
	var index: int = dock._row_context_menu.get_item_index(id)
	return dock._row_context_menu.get_item_text(index) if index >= 0 else ""


static func _item_disabled(dock: EventSheetDock, id: int) -> bool:
	var index: int = dock._row_context_menu.get_item_index(id)
	return dock._row_context_menu.is_item_disabled(index) if index >= 0 else false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] or_block_authoring_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
