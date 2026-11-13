@tool
extends RefCounted
# Godot EventSheets - the last round of the event alignment board
#
# In the Editor Native look:
#   1. values read in the normal text colour (no green on numbers and expressions);
#   2. a write to the behaviour's own variable reads with the behaviour's name as its object, the tests
#      beside it with System;
#   3. a function's parameters are "float value" - type, then bold name - and its "+ Add parameter"
#      is offered only while the head is pointed at or selected;
#   4. a line's object icon stands at the lane's padding (+8 into the block), a trigger's arrow ahead
#      of it (+25), and a local's mark at the block's edge + 10;
#   5. `$House3x3.z_index = 4` reads "House3x3 | Set z_index to 4";
#   6. an inert function body offers no add door of either kind, and a condition-less event has no strip.
# Classic Sheet keeps every one of its own geometries. It is a reading and a drawing and nothing else:
# the file saves back byte for byte.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_final_round_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SOURCE := """## @ace_category("Big Numbers")
extends Node2D

var total: float = 0.0


func calc(value: float, decimals: int) -> float:
	var magnitude: float = absf(value)
	var tier: int = 0
	tier += 1
	if value > 0.0:
		total = magnitude
	return total


func _ready() -> void:
	$House3x3.z_index = 4
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_values_read_plainly() and ok
	ok = _test_object_names() and ok
	ok = _test_property_reading() and ok
	ok = _test_function_head() and ok
	ok = _test_geometry() and ok
	ok = _test_typed_name_geometry() and ok
	ok = _test_inert_body_has_no_doors() and ok
	ok = _test_round_trip() and ok
	return ok


static func _view_of(theme_path: String, editable: bool = true, read_only: bool = false) -> EventSheetViewport:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	sheet.read_only = read_only
	# A sheet backed by a file keeps a function body inert until it is opted in.
	sheet.external_source_path = "user://native_final_round_view.gd"
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	if not editable:
		view.toggle_function_body_lock("calc")
	return view


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


static func _test_values_read_plainly() -> bool:
	var dark: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE).get_event_style()
	var classic: EventSheetEventStyle = (load(CLASSIC_THEME) as EventSheetEditorStyle).get_event_style()
	return SUPPORT.pins(TEST_NAME, [
		["dark: numbers and expressions in the lane's own text colour",
			[dark.word_number_color.to_html(false), dark.value_highlight_color.to_html(false)], ["d2d2d2", "d2d2d2"]],
		["light: numbers and expressions in the lane's own text colour",
			[light.word_number_color.to_html(false), light.value_highlight_color.to_html(false)], ["0f0f0f", "0f0f0f"]],
		["Classic Sheet keeps a tint of its own on a value", classic.value_highlight_color.to_html(false) != "d2d2d2", true],
	])


static func _test_object_names() -> bool:
	var rows: Array[String] = _rows_of(_view_of(NATIVE_THEME))
	var classic_rows: Array[String] = _rows_of(_view_of(CLASSIC_THEME))
	return SUPPORT.pins(TEST_NAME, [
		["a write to the behaviour's own local reads with the behaviour's name", _any_row(rows, "[Big Numbers]Set magnitude to"), true],
		["and so does an Add to it", _any_row(rows, "[Big Numbers]Add 1 to tier"), true],
		["and a write to its own variable", _any_row(rows, "[Big Numbers]Set total to"), true],
		["a test still reads with System", _any_row(rows, "[System]value > 0"), true],
		["Classic Sheet reads the same object", _any_row(classic_rows, "[Big Numbers]Set magnitude to"), true],
		["no write is left reading System", _any_row(rows, "[System]Set magnitude"), false],
	])


static func _test_property_reading() -> bool:
	var rows: Array[String] = _rows_of(_view_of(NATIVE_THEME))
	return SUPPORT.pins(TEST_NAME, [
		["a z_index write reads with the property as written", _any_row(rows, "[House3x3]Set z_index to 4"), true],
		["and not as the Z order of a class", _any_row(rows, "Z order"), false],
	])


static func _head_of(view: EventSheetViewport) -> EventRowData:
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_uid.begins_with("define_fn_calc"):
			view._row_builder._ensure_event_spans(row_data)
			return row_data
	return null


static func _test_function_head() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var head: EventRowData = _head_of(view)
	var style: EventSheetEventStyle = view.get_event_style()
	var typed: PackedStringArray = PackedStringArray()
	var door_seen: bool = false
	for span: EventSheetSemanticSpan in head.spans:
		var metadata: Dictionary = span.metadata as Dictionary
		if str(metadata.get("kind", "")) == "verb_param":
			typed.append("%s %s %s" % [str(metadata.get("typed_name", "")), span.text, str(metadata.get("object_label", ""))])
		if str(metadata.get("kind", "")) == "verb_param_add":
			door_seen = true
	var resting: PackedStringArray = EventSheetViewportRowMetrics.resting_add_line_kinds(head, style)
	head.hovered = true
	var pointed: PackedStringArray = EventSheetViewportRowMetrics.resting_add_line_kinds(head, style)
	head.hovered = false
	head.selected = true
	var chosen: PackedStringArray = EventSheetViewportRowMetrics.resting_add_line_kinds(head, style)
	head.selected = false
	var layout: Dictionary = view.get_row_layout_for_test(_flat_index(view, head), 1200.0)
	var classic_view: EventSheetViewport = _view_of(CLASSIC_THEME)
	var classic_head: EventRowData = _head_of(classic_view)
	return SUPPORT.pins(TEST_NAME, [
		["each parameter is a typed name: its type, then its own name", typed,
			PackedStringArray(["parameter float value", "parameter int decimals"])],
		["the head still holds its add-parameter door", door_seen, true],
		["at rest the door takes no room", resting.has("verb_param_add"), true],
		["pointed at it takes its line", pointed.has("verb_param_add"), false],
		["selected it takes its line", chosen.has("verb_param_add"), false],
		["the trigger and the two parameters are the cell's three strips - the door is not one",
			(layout.get("condition_line_bands", []) as Array).size(), 3],
		["Classic Sheet keeps its resting add-parameter line",
			EventSheetViewportRowMetrics.resting_add_line_kinds(classic_head, classic_view.get_event_style()).has("verb_param_add"), false],
	])


static func _flat_index(view: EventSheetViewport, target: EventRowData) -> int:
	for index: int in range(view.get_flat_rows().size()):
		if view._row_at(index) == target:
			return index
	return -1


## The x of a line's object icon, its trigger arrow and a local's mark, measured from where they land.
static func _test_geometry() -> bool:
	var sheet := EventSheetResource.new()
	sheet.editor_style = (load(NATIVE_THEME) as EventSheetEditorStyle).duplicate(true)
	var armed := EventRow.new()
	armed.trigger_id = "OnReady"
	var plain := EventRow.new()
	plain.trigger_id = "OnProcess"
	sheet.events.append(armed)
	sheet.events.append(plain)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var out: Dictionary = {}
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var layout: Dictionary = view.get_row_layout_for_test(index, 1300.0)
		var block: float = (layout.get("condition_lane_rect", Rect2()) as Rect2).position.x
		for span: EventSheetSemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata as Dictionary
			if bool(metadata.get("badge", false)):
				out["arrow_%s" % row_data.row_uid] = span.rect.position.x - block
			elif str(metadata.get("kind", "")) == "trigger":
				out["trigger_%s" % row_data.row_uid] = span.rect.position.x - block
			elif str(metadata.get("kind", "")) == "add_condition":
				out["door_%s" % row_data.row_uid] = span.rect.position.x - block
	var arrows: Array = []
	var triggers: Array = []
	var doors: Array = []
	for key: String in out:
		if key.begins_with("arrow_"):
			arrows.append(out[key])
		elif key.begins_with("trigger_"):
			triggers.append(out[key])
		else:
			doors.append(out[key])
	view.free()
	var native_style: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	return SUPPORT.pins(TEST_NAME, [
		["a trigger's arrow stands at the lane's padding (8 px into the block)", arrows, [8.0]],
		["the arrow's line starts its object 17 px on", triggers, [25.0]],
		["a line with no mark starts at the padding, a mark-less event's door included", doors[0], 8.0],
		["no mark slot is reserved on the look's own tokens",
			[native_style.condition_badge_column_width, (load(NATIVE_THEME) as EventSheetEditorStyle).get_condition_style().horizontal_padding], [0, 0]],
		["the arrow's advance is 17 and an inverted mark advances nothing",
			[EventSheetViewportRowMetrics.STRIP_MARK_ADVANCE], [17.0]],
	])


static func _test_typed_name_geometry() -> bool:
	var local: Dictionary = EventSheetRowRenderer.typed_name_geometry(null, 12, "local", "float", "x")
	var parameter: Dictionary = EventSheetRowRenderer.typed_name_geometry(null, 12, "parameter", "float", "x")
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var local_marks: Array = []
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or not EventSheetRowRenderer.is_local_variable_row(row_data):
			continue
		var layout: Dictionary = view.get_row_layout_for_test(index, 1200.0)
		view._row_builder._ensure_event_spans(row_data)
		if row_data.spans.is_empty():
			continue
		local_marks.append(row_data.spans[0].rect.position.x - EventSheetRowRenderer.nested_block_left_for(row_data.indent, 18))
		if layout.is_empty():
			local_marks.append(-1.0)
	return SUPPORT.pins(TEST_NAME, [
		["a local's type stands past its 16 px tile and a 7 px gap", [local["mark_x"], local["type_x"], local["name_x"]], [0.0, 23.0, 30.0]],
		["a parameter's mark stands in 18 px, its type past 11 px and a 6 px gap", [parameter["mark_x"], parameter["type_x"], parameter["name_x"]], [18.0, 35.0, 41.0]],
		["a local's mark stands 10 px in from its block, as the board sets it", local_marks.slice(0, 2), [10.0, 10.0]],
	])


static func _body_rows_with(rows: Array[String], door: String) -> bool:
	for row_words: String in rows:
		if row_words.contains("Set magnitude") and row_words.contains(door):
			return true
	return false


static func _test_inert_body_has_no_doors() -> bool:
	var inert: Array[String] = _rows_of(_view_of(NATIVE_THEME, false))
	var read_only: Array[String] = _rows_of(_view_of(NATIVE_THEME, false, true))
	var editable: Array[String] = _rows_of(_view_of(NATIVE_THEME))
	return SUPPORT.pins(TEST_NAME, [
		["a function body nobody opted into draws no add action", _body_rows_with(inert, "+ Add action"), false],
		["nor the add menu beside it", _body_rows_with(inert, "+ Add…"), false],
		["a read-only sheet draws neither", _body_rows_with(read_only, "+ Add action") or _body_rows_with(read_only, "+ Add…"), false],
		["a body opted in draws its add lines", _body_rows_with(editable, "+ Add action"), true],
	])


static func _test_round_trip() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["the file saves back byte for byte", SUPPORT.reemit(SOURCE, "user://native_final_round_reemit.gd"), SOURCE]])
