@tool
extends RefCounted
# Godot EventSheets - the "+ Add..." doors and the note over an event's actions (Editor Native)
#
# The look that closes every event with its add line puts "+ Add..." at the far right of that line,
# and closes every group with its foot: "+ Add event to 'name'..." at the left and "+ Add to 'name'..."
# at the right. A note written about an event's actions heads its action lane. Every other look keeps
# the lane as it was. The pins hold:
#   1. the doors exist only in the look that nests by lines, on the add line, at the right;
#   2. the note about an event's actions is the lane's first line there and its last line elsewhere;
#   3. a group's foot carries both doors, whether or not the group holds events;
#   4. pressing a door selects what it belongs to and asks for the menu, once, with the block it closes.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_add_doors_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_event_door_and_note() and ok
	ok = _test_group_foot() and ok
	ok = _test_door_press() and ok
	return ok


static func _sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.read_only = false
	var event := EventRow.new()
	event.event_uid = "door_event"
	event.comment = "Why these run."
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.params = {"text": "\"hello\""}
	event.actions.append(action)
	sheet.events.append(event)
	var group := EventGroup.new()
	group.group_name = "Setup"
	var inner := EventRow.new()
	inner.event_uid = "door_group_event"
	group.events.append(inner)
	sheet.events.append(group)
	var empty_group := EventGroup.new()
	empty_group.group_name = "Later"
	sheet.events.append(empty_group)
	return sheet


static func _view(theme_path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = _sheet()
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


static func _row_with_uid(view: EventSheetViewport, uid: String) -> int:
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_uid == uid:
			return index
	return -1


## The metadata of the first span of `kind` on a row, {} when there is none.
static func _span_of(row_data: EventRowData, kind: String) -> Dictionary:
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) == kind:
			return span.metadata as Dictionary
	return {}


static func _comment_line(row_data: EventRowData) -> int:
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("edit_kind", "")) == "event_comment":
			return int((span.metadata as Dictionary).get("line_index", -1))
	return -1


static func _test_event_door_and_note() -> bool:
	var native_view: EventSheetViewport = _view(NATIVE_THEME)
	var native_row: EventRowData = native_view._row_at(_row_with_uid(native_view, "door_event"))
	native_view._row_builder._ensure_event_spans(native_row)
	var native_door: Dictionary = _span_of(native_row, "add_menu")
	var native_add: Dictionary = _span_of(native_row, "add_action")
	var native_action: Dictionary = _span_of(native_row, "action")
	var native_note_line: int = _comment_line(native_row)
	native_view.free()
	var classic_view: EventSheetViewport = _view(CLASSIC_THEME)
	var classic_row: EventRowData = classic_view._row_at(_row_with_uid(classic_view, "door_event"))
	classic_view._row_builder._ensure_event_spans(classic_row)
	var classic_door: Dictionary = _span_of(classic_row, "add_menu")
	var classic_note_line: int = _comment_line(classic_row)
	var classic_action: Dictionary = _span_of(classic_row, "action")
	classic_view.free()
	return SUPPORT.pins(TEST_NAME, [
		["Editor Native puts a door on the add line, at the right",
			[not native_door.is_empty(), bool(native_door.get("align_right", false)),
				int(native_door.get("line_index", -1)) == int(native_add.get("line_index", -2))], [true, true, true]],
		["the note about the actions is the first line of the lane and the action steps down",
			[native_note_line, int(native_action.get("line_index", -1)), int(native_add.get("line_index", -1))], [0, 1, 2]],
		["any other look has no door", classic_door.is_empty(), true],
		["and keeps the note under the actions",
			[classic_note_line, int(classic_action.get("line_index", -1))], [1, 0]],
	])


static func _test_group_foot() -> bool:
	var native_view: EventSheetViewport = _view(NATIVE_THEME)
	var texts: Array = []
	for index: int in range(native_view.get_flat_rows().size()):
		var row_data: EventRowData = native_view._row_at(index)
		if row_data != null and native_view._row_is_add_event_footer(row_data):
			var words := PackedStringArray()
			for span: SemanticSpan in row_data.spans:
				words.append(span.text)
			texts.append(" | ".join(words))
	native_view.free()
	var classic_view: EventSheetViewport = _view(CLASSIC_THEME)
	var classic_feet: int = 0
	var classic_doors: int = 0
	for index: int in range(classic_view.get_flat_rows().size()):
		var row_data: EventRowData = classic_view._row_at(index)
		if row_data != null and classic_view._row_is_add_event_footer(row_data):
			classic_feet += 1
			classic_doors += 1 if not _span_of(row_data, "add_block_menu").is_empty() else 0
	classic_view.free()
	return SUPPORT.pins(TEST_NAME, [
		["every group of Editor Native ends with both doors, the one holding events and the empty one",
			texts, ["+ Add event to 'Setup'… | + Add to 'Setup'…", "+ Add event to 'Later'… | + Add to 'Later'…"]],
		["another look draws its feet as it always did, with no second door", [classic_doors], [0]],
	])


static func _test_door_press() -> bool:
	var view: EventSheetViewport = _view(NATIVE_THEME)
	var seen: Array = []
	view.add_menu_requested.connect(func(row_data: EventRowData, owner_resource: Resource, _at: Vector2) -> void:
		seen.append([row_data.row_uid, owner_resource.get("group_name") if owner_resource != null else null])
	)
	var event_index: int = _row_with_uid(view, "door_event")
	view.open_add_menu_for(event_index)
	var footer_index: int = -1
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and view._row_is_add_event_footer(row_data) and not _span_of(row_data, "add_event").is_empty():
			var owner_group: Variant = (_span_of(row_data, "add_event").get("add_event_owner"))
			if owner_group is EventGroup and (owner_group as EventGroup).group_name == "Setup":
				footer_index = index
	view.open_add_menu_for(footer_index)
	var group_uid: String = view._row_at(view.get_flat_rows().size() - 1).row_uid
	view.free()
	return SUPPORT.pins(TEST_NAME, [
		["pressing the event's door asks for the menu of that event, with no block",
			seen[0] if seen.size() > 0 else null, ["door_event", null]],
		["pressing a foot's door asks for the menu of the block it closes, with that block",
			[seen.size(), (seen[1] as Array)[1] if seen.size() > 1 else null], [2, "Setup"]],
		["the last row of the sheet is still the empty group's foot", group_uid.begins_with("add_event_footer_"), true],
	])
