@tool
extends RefCounted
# Godot EventSheets - the readings the margin look asks of a branch, a return, a local and a group
#
# In the Editor Native look:
#   1. a branch of a pair closes its action lane with the add line an event does, and leads with the
#      icon of its object;
#   2. a return reads "Function | Return ..." in an event and in a branch alike;
#   3. a local declared by a ternary reads as a Local row ahead of the pair, and each arm only sets it;
#   4. a condition-less event says nothing in its condition cell - no "Always", no resting add door;
#   5. a group takes a number in the margin, and Find / Doctor name events by the number the margin draws;
#   6. a plain click on a branch marks that row alone.
# Classic Sheet keeps every one of its own readings. It is a reading and nothing else: the file saves
# back byte for byte.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "margin_reading_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SOURCE := """extends Node


func calc(value: float) -> String:
	if not is_finite(value):
		return "Infinity" if value > 0.0 else "-Infinity"
	var sign_text: String = "-" if value < 0.0 else ""
	var magnitude: float = absf(value)
	if magnitude < 3.0:
		return sign_text
	return str(magnitude)
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_branch_doors_and_returns() and ok
	ok = _test_ternary_local() and ok
	ok = _test_empty_condition_cell() and ok
	ok = _test_branch_click() and ok
	ok = _test_margin_numbers_agree() and ok
	ok = _test_round_trip() and ok
	return ok


static func _view_of(theme_path: String, source: String = SOURCE) -> EventSheetViewport:
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	sheet.read_only = false
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


## Every flat row as one string: its spans' kinds and words in order, so a pin reads the whole row.
static func _rows_of(view: EventSheetViewport) -> Array[String]:
	var rows: Array[String] = []
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			rows.append("")
			continue
		view._row_builder._ensure_event_spans(row_data)
		var words: PackedStringArray = PackedStringArray()
		for span: EventSheetSemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			var label: String = str(metadata.get("object_label", ""))
			words.append("%s%s" % [("[%s]" % label) if not label.is_empty() else "", span.text])
		rows.append(" | ".join(words))
	return rows


static func _any_row(rows: Array[String], needle: String) -> bool:
	for row_words: String in rows:
		if row_words.contains(needle):
			return true
	return false


static func _test_branch_doors_and_returns() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var rows: Array[String] = _rows_of(view)
	var branch_row: EventRowData = null
	for index: int in range(view.get_flat_rows().size()):
		var candidate: EventRowData = view._row_at(index)
		if candidate != null and candidate.row_uid.contains("_branch_") and rows[index].contains("Infinity"):
			branch_row = candidate
			break
	var kinds: PackedStringArray = PackedStringArray()
	if branch_row != null:
		for span: EventSheetSemanticSpan in branch_row.spans:
			kinds.append(str((span.metadata as Dictionary).get("kind", "")))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a branch row was found", branch_row != null, true],
		["a branch closes its action lane with + Add action", kinds.has("add_action"), true],
		["and with the + Add... link beside it", kinds.has("add_menu"), true],
		["a branch's return reads under the object Function", _any_row(rows, "[Function]Return \"Infinity\""), true],
		["a return in an event reads under Function too", _any_row(rows, "[Function]Return magnitude"), true],
	])
	view.free()
	var classic: EventSheetViewport = _view_of(CLASSIC_THEME)

	ok = SUPPORT.pins(TEST_NAME, [
		["Classic Sheet draws no + Add... link on a branch", _count_branch_doors(classic, "add_menu"), 0],
	]) and ok
	classic.free()
	return ok


static func _count_branch_doors(view: EventSheetViewport, door_kind: String) -> int:
	var found: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or not row_data.row_uid.contains("_branch_"):
			continue
		for span: EventSheetSemanticSpan in row_data.spans:
			if str((span.metadata as Dictionary).get("kind", "")) == door_kind:
				found += 1
	return found


static func _test_ternary_local() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var rows: Array[String] = _rows_of(view)
	var local_at: int = -1
	var first_set_at: int = -1
	for index: int in range(rows.size()):
		if local_at < 0 and rows[index].contains("sign_text") and rows[index].contains("String"):
			local_at = index
		if first_set_at < 0 and rows[index].contains("[sign_text]Set to"):
			first_set_at = index
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the ternary's local reads as its own row", local_at >= 0, true],
		["and stands before the branches that set it", local_at >= 0 and local_at < first_set_at, true],
		["the first arm reads as Set to the value", _any_row(rows, "[sign_text]Set to \"-\""), true],
		["the last arm reads as Set to the default", _any_row(rows, "[sign_text]Set to \"\""), true],
	])
	view.free()
	return ok


static func _test_empty_condition_cell() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var placeholders: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		view._row_builder._ensure_event_spans(row_data)
		for span: EventSheetSemanticSpan in row_data.spans:
			if span.text == "Always" or span.text == "Every Tick":
				placeholders += 1
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["no cell says Always or Every Tick", placeholders, 0],
		["the add-condition door waits for the pointer on an empty cell",
			EventSheetRowRenderer.add_condition_door_revealed(false, false, false, view._get_event_style()), false],
		["and appears under it", EventSheetRowRenderer.add_condition_door_revealed(true, false, false, view._get_event_style()), true],
	])
	view.free()
	return ok


static func _test_branch_click() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var branch_index: int = -1
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_uid.contains("_branch_"):
			branch_index = index
			break
	view._select_from_click(branch_index, -1, false)
	var selected: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var flagged: EventRowData = view._row_at(index)
		if flagged != null and flagged.selected:
			selected += 1
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a branch was found", branch_index >= 0, true],
		["a click on a branch marks that row alone", selected, 1],
	])
	view.free()
	return ok


## The Doctor and Find name an event by the number the margin draws, branches and groups included.
static func _test_margin_numbers_agree() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var sheet: EventSheetResource = view._sheet
	var model: Dictionary = EventSheetResource.event_numbers(sheet.events, sheet.functions)
	var mismatches: int = 0
	var seen: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.event_number <= 0 or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var source: Resource = row_data.source_resource if row_data.source_resource != null else row_data.reading_resource
		if source == null or source is EventFunction or not model.has(source.get_instance_id()):
			continue
		seen += 1
		if view.display_event_number(int(model[source.get_instance_id()])) != row_data.event_number:
			mismatches += 1
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the gutter numbered some events", seen > 0, true],
		["display_event_number is the number the gutter draws", mismatches, 0],
		["a sheet with no look to nest by lines answers the sheet's own numbers",
			EventSheetResource.margin_numbers(null), {}],
	])
	view.free()
	return ok


static func _test_round_trip() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	view.free()
	var again: String = SUPPORT.reemit(SOURCE, "user://margin_reading_probe.gd")
	return SUPPORT.check(TEST_NAME, "the file saves back byte for byte", again, SOURCE)
