# EventForge - the doors that make and move a comment
#
# Q with an action selected puts the comment in that action list, under the action, instead of a new
# row under the event. Right-click on an action offers Add note (the words after it); a condition
# offers no note at all. Alt+Up / Alt+Down move a comment that sits among the actions. A comment row let
# go on an event's action column joins that action list. The Edit comment window shows the theme's
# named colours and the box that writes ##, and a picked colour stays on the sheet.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "comment_making_test"


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var ok: bool = _q_on_an_action_comments_between_actions()
	ok = _notes_are_for_actions_only() and ok
	ok = _the_menus_offer_a_note_only_where_it_does_something() and ok
	ok = _alt_arrows_move_a_comment_among_actions() and ok
	ok = _a_comment_dropped_on_the_actions_joins_them() and ok
	ok = _the_edit_window_names_its_colours() and ok
	ok = _a_comment_only_code_row_draws_its_markup() and ok
	return ok


## A code row that is nothing but comments reads as a comment, and a comment's [b] is drawn bold, not
## shown as the tag; its text stays what the file holds.
static func _a_comment_only_code_row_draws_its_markup() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "# [b]Movement[/b] - the player walks."
	sheet.events.append(block)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(sheet)
	var row_data: EventRowData = dock.get_viewport_control().get_flat_rows()[0].get("row")
	dock.get_viewport_control()._row_builder._ensure_event_spans(row_data)
	var segments: Array = row_data.spans[0].metadata.get("bbcode_segments", [])
	var drawn: Array = []
	for segment: Dictionary in segments:
		drawn.append([segment.get("text"), segment.get("bold")])
	var text: String = row_data.spans[0].text
	dock.free()
	return SUPPORT.pins(NAME, [
		["the bold words are drawn bold, without the tag", drawn, [["Movement", true], [" - the player walks.", false]]],
		["the row's text is still what the file holds", text, "[b]Movement[/b] - the player walks."],
	])


static func _say(said: String) -> ACEAction:
	var say: ACEAction = ACEAction.new()
	say.provider_id = "Core"
	say.ace_id = "Print"
	say.codegen_template = "print({value})"
	say.params = {"value": "\"%s\"" % said}
	return say


## A dock over one event with two actions (and a comment row above it), its undo history a no-op.
static func _dock_with_event() -> EventSheetDock:
	var sheet: EventSheetResource = EventSheetResource.new()
	var note: CommentRow = CommentRow.new()
	note.text = "Play the sound after the jump."
	sheet.events.append(note)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_say("jump"))
	event.actions.append(_say("sound"))
	sheet.events.append(event)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(sheet)
	dock.set_undo_redo_manager(NoopUndoManager.new())
	return dock


## Puts the selection on the action lane cell of `event` whose ace_index is `ace_index`.
static func _select_action(dock: EventSheetDock, event: EventRow, ace_index: int) -> void:
	var viewport: EventSheetViewport = dock.get_viewport_control()
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for row_index: int in range(flat.size()):
		var row_data: EventRowData = flat[row_index].get("row")
		if row_data == null or row_data.source_resource != event:
			continue
		viewport._row_builder._ensure_event_spans(row_data)
		for span_index: int in range(row_data.spans.size()):
			var metadata: Dictionary = row_data.spans[span_index].metadata
			if str(metadata.get("kind", "")) == "action" and int(metadata.get("ace_index", -1)) == ace_index:
				viewport._selected_row_index = row_index
				viewport._selected_span_index = span_index
				return


static func _event_of(dock: EventSheetDock) -> EventRow:
	for entry: Variant in dock._current_sheet.events:
		if entry is EventRow:
			return entry
	return null


## The event's actions as words: `say <what>` for an action, `# <text>` for a comment.
static func _actions(event: EventRow) -> Array:
	var out: Array = []
	for action: Variant in event.actions:
		if action is CommentRow:
			out.append("# " + (action as CommentRow).text)
		elif action is ACEAction:
			out.append("say " + str((action as ACEAction).params.get("value", "")).trim_prefix("\"").trim_suffix("\""))
	return out


static func _q_on_an_action_comments_between_actions() -> bool:
	var dock: EventSheetDock = _dock_with_event()
	_select_action(dock, _event_of(dock), 0)
	dock._add_rows.on_add_comment_requested()
	var rows_after: int = dock._current_sheet.events.size()
	var actions: Array = _actions(_event_of(dock))
	dock.free()
	return SUPPORT.pins(NAME, [
		["Q with an action selected puts the comment under it, in the action list", actions, ["say jump", "# Comment", "say sound"]],
		["and adds no row to the sheet", rows_after, 2],
	])


static func _notes_are_for_actions_only() -> bool:
	var dock: EventSheetDock = _dock_with_event()
	dock._context_menus.build_all()
	var action_items: Array = []
	for index: int in range(dock._action_context_menu.item_count):
		action_items.append(dock._action_context_menu.get_item_text(index))
	var condition_items: Array = []
	for index: int in range(dock._condition_context_menu.item_count):
		condition_items.append(dock._condition_context_menu.get_item_text(index))
	var condition: ACECondition = ACECondition.new()
	var questions_before: int = dock.find_children("*", "ConfirmationDialog", true, false).size()
	dock._open_ace_comment_dialog(condition)
	var asked_a_condition: int = dock.find_children("*", "ConfirmationDialog", true, false).size() - questions_before
	dock._open_ace_comment_dialog(_event_of(dock).actions[0])
	var questions: Array = dock.find_children("*", "ConfirmationDialog", true, false)
	var asked_title: String = (questions.back() as ConfirmationDialog).title if not questions.is_empty() else ""
	dock.free()
	return SUPPORT.pins(NAME, [
		["right-click on an action offers Add note", action_items.has("Add note"), true],
		["right-click on a condition offers no note", condition_items.filter(func(item: String) -> bool:
			return item.contains("Note") or item.contains("note")), []],
		["a condition is never asked for a note", asked_a_condition, 0],
		["an action is, under Add note", asked_title, "Add note"],
	])


## The note items follow what was right-clicked. A comment sitting among the actions is words already,
## so it is offered no Add note (choosing it only ever said "Right-click an action"). A condition is
## offered no note - unless an older sheet gave it one, which Remove note clears.
static func _the_menus_offer_a_note_only_where_it_does_something() -> bool:
	var dock: EventSheetDock = _dock_with_event()
	var event: EventRow = _event_of(dock)
	var between: CommentRow = CommentRow.new()
	between.text = "between"
	event.actions.insert(1, between)
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "Compare"
	condition.comment = "from an older sheet"
	event.conditions.append(condition)
	dock._refresh_after_edit()
	dock._context_menus.build_all()
	dock._context_row = _row_of(dock, _event_of(dock))
	var on_action: Array = _items_for(dock, dock._action_context_menu, {"kind": "action", "ace_index": 0})
	var on_comment: Array = _items_for(dock, dock._action_context_menu, {"kind": "action", "ace_index": 1})
	var on_noted_condition: Array = _items_for(dock, dock._condition_context_menu, {"kind": "condition", "ace_index": 0})
	dock._on_condition_context_menu_id_pressed(dock.CONDITION_MENU_EDIT_ACE_COMMENT)
	var left: String = (_event_of(dock).conditions[0] as ACECondition).comment
	dock._context_row = _row_of(dock, _event_of(dock))
	var on_plain_condition: Array = _items_for(dock, dock._condition_context_menu, {"kind": "condition", "ace_index": 0})
	dock.free()
	var notes: Callable = func(items: Array) -> Array:
		return items.filter(func(item: String) -> bool: return item.contains("note"))
	return SUPPORT.pins(NAME, [
		["an action is offered Add note, right after Disable", on_action.slice(on_action.find("Disable Action"),
			on_action.find("Disable Action") + 2), ["Disable Action", "Add note"]],
		["a comment among the actions is offered no note", notes.call(on_comment), []],
		["a condition carrying an older note is offered Remove note", notes.call(on_noted_condition), ["Remove note"]],
		["which clears it", left, ""],
		["a condition with no note is offered none", notes.call(on_plain_condition), []],
	])


static func _row_of(dock: EventSheetDock, event: EventRow) -> EventRowData:
	for entry: Dictionary in dock.get_viewport_control().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == event:
			return row_data
	return null


## The menu's items as the click on `metadata` shows them.
static func _items_for(dock: EventSheetDock, menu: PopupMenu, metadata: Dictionary) -> Array:
	dock._context_hit = {"span_metadata": metadata, "ace_index": int(metadata.get("ace_index", -1))}
	dock._context_menus._configure_context_menu(menu)
	var items: Array = []
	for index: int in range(menu.item_count):
		if not menu.is_item_separator(index):
			items.append(menu.get_item_text(index))
	return items


static func _alt_arrows_move_a_comment_among_actions() -> bool:
	var dock: EventSheetDock = _dock_with_event()
	var event: EventRow = _event_of(dock)
	var between: CommentRow = CommentRow.new()
	between.text = "between"
	event.actions.insert(0, between)
	dock._refresh_after_edit()
	_select_action(dock, event, 0)
	dock._move_selected_row(1)
	var once: Array = _actions(_event_of(dock))
	_select_action(dock, _event_of(dock), 1)
	dock._move_selected_row(-1)
	var back: Array = _actions(_event_of(dock))
	dock.free()
	return SUPPORT.pins(NAME, [
		["Alt+Down moves the comment one action down", once, ["say jump", "# between", "say sound"]],
		["Alt+Up moves it back up", back, ["# between", "say jump", "say sound"]],
	])


static func _a_comment_dropped_on_the_actions_joins_them() -> bool:
	var dock: EventSheetDock = _dock_with_event()
	var viewport: EventSheetViewport = dock.get_viewport_control()
	var comment_row: EventRowData = null
	var event_row: EventRowData = null
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is CommentRow:
			comment_row = row_data
		elif row_data != null and row_data.source_resource is EventRow:
			event_row = row_data
	dock._ace_apply._on_row_drop_requested(comment_row, event_row, EventSheetViewport.ACTION_LIST_DROP_PREFIX + "1", false)
	var actions: Array = _actions(_event_of(dock))
	var rows_left: int = dock._current_sheet.events.size()
	dock.free()
	return SUPPORT.pins(NAME, [
		["a comment row dropped between two actions joins that action list there", actions,
			["say jump", "# Play the sound after the jump.", "say sound"]],
		["and leaves the sheet's rows", rows_left, 1],
	])


static func _the_edit_window_names_its_colours() -> bool:
	var dock: EventSheetDock = _dock_with_event()
	var comment: CommentRow = dock._current_sheet.events[0] as CommentRow
	dock._comments.open_comment_dialog(comment)
	var window: Variant = dock._comments
	var names: Array = []
	for swatch: Button in window._comment_swatches:
		names.append(swatch.tooltip_text)
	var manual_box: String = window._comment_manual_check.text
	window._on_swatch_picked("orange")
	window._on_comment_dialog_confirmed()
	var picked: String = (dock._current_sheet.events[0] as CommentRow).color_tag
	dock.free()
	return SUPPORT.pins(NAME, [
		["the window shows the theme's named colours", names, ["Default", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Grey"]],
		["and the box that writes ##", manual_box, "Shows in the manual (writes ##)"],
		["a picked colour is the comment's, by name", picked, "orange"],
		["every colour's name is translated in all eight languages", _untranslated(names), []],
	])


## The swatch names some language's file leaves untranslated, as "<language>: <name>". A name read
## through a variable is invisible to the harvest, so its translation was never asked for.
static func _untranslated(names: Array) -> Array:
	var missing: Array = []
	var folder: String = "res://addons/eventsheet/translations"
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() != "csv" or file_name == "TEMPLATE.csv":
			continue
		var translated: Dictionary = {}
		var file: FileAccess = FileAccess.open(folder.path_join(file_name), FileAccess.READ)
		while not file.eof_reached():
			var line: PackedStringArray = file.get_csv_line()
			if line.size() >= 2 and not line[1].is_empty():
				translated[line[0]] = true
		for swatch_name: String in names:
			if not translated.has(swatch_name):
				missing.append("%s: %s" % [file_name.get_basename(), swatch_name])
	return missing
