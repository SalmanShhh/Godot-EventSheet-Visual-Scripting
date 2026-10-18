# Godot EventSheets - what a region does when you reach for it: fold it, turn a group into one,
# surround rows with one, and mend a fence that lost its other half.
#
# What this pins, in the order a reader meets it:
#   1. FOLDING. Open / Close Region is the region's own menu item and it folds the region; folded,
#      the opener echoes both fences and says how much it holds.
#   2. GROUP INTO REGION. The item is always offered; a group carrying what a region cannot asks
#      first, in translated sentences, and Cancel leaves it as it is.
#   3. SURROUND. A selection that skips rows asks (take them in, one region per run, or nothing),
#      and rows inside a group get the region inside that group.
#   4. A FENCE WITHOUT ITS OTHER HALF. Only the quiet amber state on the fence row - no note row -
#      with the sentence and the door on the help strip.
#   5. THE MENUS speak the reader's language.
@tool
class_name RegionGesturesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SMALL_PROMPT := preload("res://addons/eventsheet/editor/small_prompt.gd")


static func run() -> bool:
	var passed: bool = true
	passed = _test_folding() and passed
	passed = _test_group_into_region() and passed
	passed = _test_surround() and passed
	passed = _test_lonely_fences() and passed
	passed = _test_menus_are_translated() and passed
	return passed


# ── 1. Folding ──


static func _test_folding() -> bool:
	var passed: bool = true
	var dock: EventSheetDock = _dock_with([_region("Spawning"), _event("a"), _event("b"), _closer(), _event("after")])
	var opener: EventRowData = _opener_row(dock)
	dock._context_row = opener
	dock._context_menus._build_row_context_menu(opener)
	dock._context_menus._configure_context_menu(dock._row_context_menu)
	var menu: PopupMenu = dock._row_context_menu
	var index: int = menu.get_item_index(EventSheetDock.ROW_MENU_TOGGLE_REGION_FOLD)
	passed = SUPPORT.pins("region_gestures_test", [
		["a region's menu folds by the region's own item", index >= 0, true],
		["the group's fold is not offered on a region", menu.get_item_index(EventSheetDock.ROW_MENU_TOGGLE_GROUP_FOLD), -1],
		["the item is live", menu.is_item_disabled(index) if index >= 0 else true, false],
		["and says which way it goes", menu.get_item_text(index) if index >= 0 else "", "Close Region"],
	]) and passed
	dock._input_dispatch.on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_REGION_FOLD)
	var folded: EventRowData = _opener_row(dock)
	passed = SUPPORT.pins("region_gestures_test", [
		["Open / Close Region folds the region", folded.folded, true],
		["the folded opener echoes both fences", _span_text(folded, "region_fence", "open"), "#region Spawning … #endregion"],
		["and says how much it holds", _span_text(folded, "region_note", true), "2 events"],
		["the rows inside are hidden", dock._active_view().get_flat_rows().size(), 3],
	]) and passed
	dock._context_row = folded
	dock._context_menus._configure_context_menu(dock._row_context_menu)
	passed = SUPPORT.check("region_gestures_test", "folded, the item offers to open it",
		menu.get_item_text(menu.get_item_index(EventSheetDock.ROW_MENU_TOGGLE_REGION_FOLD)), "Open Region") and passed
	dock._input_dispatch.on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_REGION_FOLD)
	passed = SUPPORT.check("region_gestures_test", "and pressing it again opens it",
		_opener_row(dock).folded, false) and passed
	dock.free()
	# A fence that never closes holds nothing to fold: the item stays, greyed.
	var unclosed: EventSheetDock = _dock_with([_region("Spawning"), _event("a")])
	unclosed._context_row = _opener_row(unclosed)
	unclosed._context_menus._build_row_context_menu(unclosed._context_row)
	unclosed._context_menus._configure_context_menu(unclosed._row_context_menu)
	var unclosed_index: int = unclosed._row_context_menu.get_item_index(EventSheetDock.ROW_MENU_TOGGLE_REGION_FOLD)
	passed = SUPPORT.check("region_gestures_test", "an unclosed fence's fold item is greyed",
		unclosed._row_context_menu.is_item_disabled(unclosed_index) if unclosed_index >= 0 else false, true) and passed
	unclosed.free()
	return passed


# ── 2. Group into region ──


static func _test_group_into_region() -> bool:
	var passed: bool = true
	var group: EventGroup = _group("Combat", [_event("hit")])
	group.runs_on = EventGroup.RUNS_ON_HOST
	group.runs_in = "Playing"
	group.enabled = false
	group.runtime_toggleable = true
	var hp := LocalVariable.new()
	hp.name = "hp"
	group.local_variables.append(hp)
	passed = SUPPORT.check("region_gestures_test", "each thing a region cannot carry is said, in order",
		EventSheetGroupFacts.region_losses(group), PackedStringArray([
			"Combat is off at start, so its events never run. As a region they run from the start.",
			"Events can switch Combat off and on. A region cannot be switched, so the rows that switch it stop working.",
			"Its local variable hp goes with it, so the rows that use it stop working.",
			"Combat runs only on the host. As a region its events run everywhere.",
			"Combat runs only in Playing. As a region its events run in every mode.",
		])) and passed
	passed = SUPPORT.check("region_gestures_test", "a plain group loses nothing",
		EventSheetGroupFacts.region_losses(_group("Plain", [])), PackedStringArray()) and passed

	# The item is offered whatever the group carries, with no refusal glued to its words.
	var hosted: EventGroup = _group("Combat", [_event("hit")])
	hosted.runs_on = EventGroup.RUNS_ON_HOST
	hosted.runtime_toggleable = true
	var dock: EventSheetDock = _dock_with([hosted])
	dock._context_row = dock._active_view().get_flat_rows()[0].get("row")
	dock._context_menus._build_row_context_menu(dock._context_row)
	var menu: PopupMenu = dock._row_context_menu
	var item: int = menu.get_item_index(EventSheetDock.ROW_MENU_GROUP_TO_REGION)
	passed = SUPPORT.pins("region_gestures_test", [
		["Turn Into Region is offered on a switchable group", item >= 0, true],
		["and is live", menu.is_item_disabled(item) if item >= 0 else true, false],
		["in its own words", menu.get_item_text(item) if item >= 0 else "", "Turn Into Region"],
	]) and passed
	dock._input_dispatch.on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_GROUP_TO_REGION)
	var prompt: ConfirmationDialog = _prompt_of(dock)
	passed = SUPPORT.pins("region_gestures_test", [
		["it asks before anything changes", prompt != null, true],
		["the sheet is untouched while it asks", dock.get_current_sheet().events[0] is EventGroup, true],
		["the question names the group", prompt.title if prompt != null else "", "Turn Combat into a region?"],
		["the safe answer is the verb", prompt.ok_button_text if prompt != null else "", "Turn Into Region"],
		["and Cancel is there", prompt.cancel_button_text if prompt != null else "", "Cancel"],
		["the losses are listed in the window", _notes_in(prompt), PackedStringArray([
			"Events can switch Combat off and on. A region cannot be switched, so the rows that switch it stop working.",
			"Combat runs only on the host. As a region its events run everywhere.",
		])],
	]) and passed
	if prompt != null:
		prompt.canceled.emit()
	passed = SUPPORT.check("region_gestures_test", "Cancel keeps the group",
		dock.get_current_sheet().events[0] is EventGroup, true) and passed
	dock._context_row = dock._active_view().get_flat_rows()[0].get("row")
	dock._input_dispatch.on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_GROUP_TO_REGION)
	prompt = _prompt_of(dock)
	if prompt != null:
		prompt.confirmed.emit()
	var events: Array = dock.get_current_sheet().events
	passed = SUPPORT.pins("region_gestures_test", [
		["Turn Into Region writes the pair", events.size(), 3],
		["the opener carries the name", EventSheetRegionFacts.label(events[0]), "Combat"],
		["the rows stay between the fences", events[1] is EventRow, true],
		["and the closer ends it", EventSheetRegionFacts.is_closing_fence(events[2]), true],
	]) and passed
	dock.free()

	# A plain group turns at once: nothing would be lost, and Ctrl+Z is the way back.
	var plain: EventSheetDock = _dock_with([_group("Plain", [_event("x")])])
	plain._context_row = plain._active_view().get_flat_rows()[0].get("row")
	plain._input_dispatch.on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_GROUP_TO_REGION)
	passed = SUPPORT.pins("region_gestures_test", [
		["a plain group asks nothing", _prompt_of(plain), null],
		["and is a region straight away", EventSheetRegionFacts.label(plain.get_current_sheet().events[0]), "Plain"],
	]) and passed
	plain.free()
	return passed


# ── 3. Surround ──


static func _test_surround() -> bool:
	var passed: bool = true
	# Rows 1 and 3 selected, row 2 skipped: the gesture asks instead of swallowing it.
	var dock: EventSheetDock = _dock_with([_event("one"), _event("two"), _event("three")])
	_select(dock, [0, 2])
	dock._input_dispatch.surround_selection_with_region()
	var prompt: ConfirmationDialog = _prompt_of(dock)
	passed = SUPPORT.pins("region_gestures_test", [
		["a selection that skips a row asks", prompt != null, true],
		["and changes nothing while it asks", dock.get_current_sheet().events.size(), 3],
		["it names the row it skips", _said_in(prompt), "The selection skips row 2. A region is one run of rows."],
		["the first answer takes it in", prompt.ok_button_text if prompt != null else "", "Include row 2"],
		["the second makes one region per run", _also_text(prompt), "Two regions"],
	]) and passed
	if prompt != null:
		prompt.custom_action.emit(SMALL_PROMPT.ALSO_ACTION)
	passed = SUPPORT.check("region_gestures_test", "Two regions wraps each run alone",
		_shape(dock.get_current_sheet().events), ["(", "one", ")", "two", "(", "three", ")"]) and passed
	dock.free()

	var include: EventSheetDock = _dock_with([_event("one"), _event("two"), _event("three")])
	_select(include, [0, 2])
	include._input_dispatch.surround_selection_with_region()
	prompt = _prompt_of(include)
	if prompt != null:
		prompt.confirmed.emit()
	passed = SUPPORT.check("region_gestures_test", "Include row 2 wraps the whole run",
		_shape(include.get_current_sheet().events), ["(", "one", "two", "three", ")"]) and passed
	include.free()

	# Rows inside a group get the region inside that group.
	var grouped: EventSheetDock = _dock_with([_group("Combat", [_event("hit"), _event("heal")]), _event("outside")])
	_select(grouped, [1, 2])
	grouped._input_dispatch.surround_selection_with_region()
	var live_group: EventGroup = grouped.get_current_sheet().events[0] as EventGroup
	passed = SUPPORT.pins("region_gestures_test", [
		["rows inside a group get the region inside the group", _shape(live_group.child_rows()), ["(", "hit", "heal", ")"]],
		["and the sheet around the group is untouched", grouped.get_current_sheet().events.size(), 2],
	]) and passed
	grouped.free()
	return passed


# ── 4. A fence without its other half ──


static func _test_lonely_fences() -> bool:
	var passed: bool = true
	var dock: EventSheetDock = _dock_with([_region("Spawning"), _event("a"), _event("b")])
	var opener: EventRowData = _opener_row(dock)
	# A sheet with no fence at all draws the same rows that stand for nothing (its footer), so any
	# extra one here would be a note grown under the fence.
	var clean: EventSheetDock = _dock_with([_event("a"), _event("b")])
	var note_rows: int = _resourceless_rows(dock) - _resourceless_rows(clean)
	clean.free()
	var sentence: String = "Spawning never closes, so it cannot fold. Add #endregion after the last row you want inside."
	passed = SUPPORT.pins("region_gestures_test", [
		["the sheet grows no note row", note_rows, 0],
		["the fence row wears the quiet amber state", opener.attention_note, sentence],
		["tagged as a region fence", str(opener.attention_findings[0].get("family", "")) if not opener.attention_findings.is_empty() else "",
			EventSheetRegionFacts.FINDING_FAMILY],
	]) and passed
	dock._update_row_help_strip(opener)
	passed = SUPPORT.pins("region_gestures_test", [
		["selecting it puts the sentence on the strip", dock._row_help_label.text, sentence],
		["with the fix on the button", dock._row_help_button.text, "Add #endregion"],
		["shown", dock._row_help_button.visible, true],
	]) and passed
	dock.apply_selected_row_fix()
	passed = SUPPORT.check("region_gestures_test", "the strip's door writes the #endregion after the last row",
		_shape(dock.get_current_sheet().events), ["(", "a", "b", ")"]) and passed
	dock.free()

	var lone: EventSheetDock = _dock_with([_event("a"), _closer(), _event("b")])
	var closer: EventRowData = null
	for entry: Dictionary in lone._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and EventSheetRegionFacts.is_closing_fence(row_data.source_resource):
			closer = row_data
	lone._update_row_help_strip(closer)
	passed = SUPPORT.pins("region_gestures_test", [
		["a lone closer says so on the strip", lone._row_help_label.text,
			"#endregion closes nothing - there is no #region above it. Remove it, or open a region first."],
		["and offers to remove it", lone._row_help_button.text, "Remove #endregion"],
	]) and passed
	lone.apply_selected_row_fix()
	passed = SUPPORT.check("region_gestures_test", "the door removes the lone closer",
		_shape(lone.get_current_sheet().events), ["a", "b"]) and passed
	lone.free()
	return passed


# ── 5. The menus speak the reader's language ──


static func _test_menus_are_translated() -> bool:
	var passed: bool = true
	EventSheetL10n.ensure_loaded()
	var before_locale: String = EventSheetL10n.get_locale()
	EventSheetL10n.set_locale("de")
	var dock: EventSheetDock = _dock_with([_group("Combat", [_event("x")]), _region("Spawning"), _event("a"), _closer()])
	var rows: Array[Dictionary] = dock._active_view().get_flat_rows()
	dock._context_row = rows[0].get("row")
	dock._context_menus._build_row_context_menu(dock._context_row)
	var menu: PopupMenu = dock._row_context_menu
	passed = SUPPORT.pins("region_gestures_test", [
		["the group menu is translated", menu.get_item_text(menu.get_item_index(EventSheetDock.ROW_MENU_EDIT_GROUP)), "Gruppe bearbeiten…"],
		["Turn Into Region too", menu.get_item_text(menu.get_item_index(EventSheetDock.ROW_MENU_GROUP_TO_REGION)), "In Region umwandeln"],
	]) and passed
	dock._context_row = _opener_row(dock)
	dock._context_menus._build_row_context_menu(dock._context_row)
	passed = SUPPORT.check("region_gestures_test", "the region menu is translated",
		menu.get_item_text(menu.get_item_index(EventSheetDock.ROW_MENU_REGION_RENAME)), "Region umbenennen…") and passed
	EventSheetL10n.set_locale(before_locale)
	dock.free()
	return passed


# ── Fixtures ──


static func _dock_with(entries: Array) -> EventSheetDock:
	var sheet := EventSheetResource.new()
	for entry: Variant in entries:
		sheet.events.append(entry as Resource)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	return dock


static func _region(label: String) -> CustomBlockRow:
	return EventSheetRegionFacts.make_fence(label)


static func _closer() -> CustomBlockRow:
	return EventSheetRegionFacts.make_fence("", true)


static func _event(comment: String) -> EventRow:
	var event_row := EventRow.new()
	event_row.comment = comment
	return event_row


static func _group(name: String, rows: Array) -> EventGroup:
	var group := EventGroup.new()
	group.name = name
	group.group_name = name
	for row: Variant in rows:
		group.events.append(row as Resource)
	return group


## Selects the rows at these flat indices, the way the click path does.
static func _select(dock: EventSheetDock, flat_indices: Array) -> void:
	var view: EventSheetViewport = dock._active_view()
	var rows: Array[Dictionary] = view.get_flat_rows()
	for index: Variant in flat_indices:
		var row_data: EventRowData = rows[int(index)].get("row")
		view._selected_row_uids[row_data.row_uid] = true
		row_data.selected = true
	dock._context_row = rows[int(flat_indices[0])].get("row")


static func _resourceless_rows(dock: EventSheetDock) -> int:
	var counted: int = 0
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == null:
			counted += 1
	return counted


static func _opener_row(dock: EventSheetDock) -> EventRowData:
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and EventSheetRegionFacts.is_opening_fence(row_data.source_resource):
			return row_data
	return null


## The rows of a container as a reader scans them: "(" an opener, ")" a closer, else the comment.
static func _shape(entries: Array) -> Array:
	var shape: Array = []
	for entry: Variant in entries:
		if EventSheetRegionFacts.is_opening_fence(entry):
			shape.append("(")
		elif EventSheetRegionFacts.is_closing_fence(entry):
			shape.append(")")
		elif entry is EventRow:
			shape.append((entry as EventRow).comment)
		else:
			shape.append(str(entry))
	return shape


static func _prompt_of(dock: EventSheetDock) -> ConfirmationDialog:
	var found: ConfirmationDialog = null
	for child: Node in dock.get_children():
		if child is ConfirmationDialog and not child.is_queued_for_deletion() and child.find_child("Say", true, false) != null:
			found = child as ConfirmationDialog
	return found


static func _said_in(prompt: ConfirmationDialog) -> String:
	var say: Label = prompt.find_child("Say", true, false) as Label if prompt != null else null
	return say.text if say != null else ""


static func _also_text(prompt: ConfirmationDialog) -> String:
	var also: Button = prompt.find_child("Also", true, false) as Button if prompt != null else null
	return also.text if also != null else ""


static func _notes_in(prompt: ConfirmationDialog) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	if prompt == null:
		return said
	for note: Node in prompt.find_children("*", "PanelContainer", true, false):
		if note is EventSheetPopupUI.StateNote and note.visible:
			said.append((note as EventSheetPopupUI.StateNote).text)
	return said


static func _span_text(row_data: EventRowData, key: String, value: Variant) -> String:
	for span: SemanticSpan in row_data.spans if row_data != null else []:
		if span != null and span.metadata is Dictionary and (span.metadata as Dictionary).get(key) == value:
			return span.text
	return "<no span %s=%s>" % [key, str(value)]
