@tool
extends RefCounted
# Godot EventSheets - the Editor Native event rows (the theme's add_lines_on_hover,
# trigger_icon_in_gutter, behaviour_in_object_column, lane_chips_yield and row_font_size)
#
# A theme that draws events at the design's size draws a one-condition, one-action event one line
# tall: 12 px text on 24 px lines, the "Add condition" / "Add action" lines only on the hovered or
# selected event, the number on the event's first line, the trigger's green arrow in a 16 px mark
# slot at the head of the conditions lane (as in every look), a behaviour's action led by its name and a
# colon after the node it is mounted on (the retired behaviour_in_object_column stays off), and the
# chips after a condition giving the condition's words their room. The pins hold:
#   1. the tokens are off by default, on in the Editor Native starter and its rule (bar the retired
#      one), and stated off in every other shipped theme;
#   2. the resting add-line rule, as a pure function;
#   3. the real sheet's events in Editor Native - heights at rest, on hover and on selection, no
#      trigger badge, the behaviour in the object column, the font size - and the same sheet in
#      Classic Sheet reading and measuring exactly as before;
#   4. the gutter geometry: the number and the icon on the first line, one margin column.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_event_rows_test"
const SHOOTER := "res://demo/showcase/platformer_shooter/platformer_shooter.gd"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const THEME_FOLDERS: PackedStringArray = ["res://addons/eventsheet/themes", "res://demo/themes"]
const NativeRowMarks := preload("res://addons/eventsheet/editor/interaction/native_row_marks.gd")
const TOKENS: PackedStringArray = [
	"add_lines_on_hover", "trigger_icon_in_gutter", "behaviour_in_object_column", "lane_chips_yield",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_tokens() and ok
	ok = _test_resting_add_lines() and ok
	ok = _test_shooter_events() and ok
	ok = _test_gutter_geometry() and ok
	return ok


static func _test_tokens() -> bool:
	var defaults := EventSheetEventStyle.new()
	var starter: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	var rule: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	var others: int = 0
	var all_off: bool = true
	for folder: String in THEME_FOLDERS:
		for file_name: String in DirAccess.get_files_at(folder):
			var path: String = folder.path_join(file_name)
			if not file_name.ends_with("_theme.tres") or path == NATIVE_THEME:
				continue
			var text: String = FileAccess.get_file_as_string(path)
			if not text.contains("inspector_variable_rows"):
				continue
			others += 1
			for token: String in TOKENS:
				all_off = all_off and text.contains("%s = false" % token)
			all_off = all_off and text.contains("row_font_size = 0")
	var off: Array = []
	var on_starter: Array = []
	var on_rule: Array = []
	for token: String in TOKENS:
		off.append(defaults.get(token))
		on_starter.append(starter.get(token))
		on_rule.append(rule.get_event_style().get(token))
	return SUPPORT.pins(TEST_NAME, [
		["off by default", [off, defaults.row_font_size], [[false, false, false, false], 0]],
		["the starter states them on (the retired one off), at the design's 12 px text",
			[on_starter, starter.row_font_size], [[true, true, false, true], 12]],
		["and so does the rule it is built by",
			[on_rule, rule.get_event_style().row_font_size], [[true, true, false, true], 12]],
		["the starter's geometry: a 16 px mark slot, a 92 px name after the icon, 1 px cell padding",
			[starter.condition_badge_column_width, starter.condition_object_column_width,
				starter.action_object_column_width,
				(load(NATIVE_THEME) as EventSheetEditorStyle).get_condition_style().vertical_padding,
				rule.get_condition_style().vertical_padding, rule.get_action_style().vertical_padding],
			[16, 114, 114, 1, 1, 1]],
		["the action lane is the card tinted green, never toward yellow",
			[starter.action_lane_color.to_html(false), rule.get_event_style().action_lane_color.to_html(false)],
			["354838", "354838"]],
		["every other shipped theme states them off", [others >= 11, all_off], [true, true]],
	])


static func _test_resting_add_lines() -> bool:
	var native := EventSheetEventStyle.new()
	native.add_lines_on_hover = true
	var full: EventRowData = _event_row(["condition", "action"])
	var no_action: EventRowData = _event_row(["trigger"])
	var placeholder: EventRowData = _event_row(["condition", "action"], true)
	var hovered: EventRowData = _event_row(["condition", "action"])
	hovered.hovered = true
	var selected: EventRowData = _event_row(["condition", "action"])
	selected.selected = true
	return SUPPORT.pins(TEST_NAME, [
		["a filled event at rest gives both add lines no room",
			ViewportRowMetrics.resting_add_line_kinds(full, native), PackedStringArray(["add_condition", "add_action"])],
		["an empty lane keeps its add line", ViewportRowMetrics.resting_add_line_kinds(no_action, native),
			PackedStringArray(["add_condition"])],
		["a placeholder is not a condition", ViewportRowMetrics.resting_add_line_kinds(placeholder, native),
			PackedStringArray(["add_action"])],
		["hovered or selected, both lines are there",
			[ViewportRowMetrics.resting_add_line_kinds(hovered, native),
				ViewportRowMetrics.resting_add_line_kinds(selected, native)],
			[PackedStringArray(), PackedStringArray()]],
		["any other theme reserves them always",
			ViewportRowMetrics.resting_add_line_kinds(full, EventSheetEventStyle.new()), PackedStringArray()],
	])


static func _test_shooter_events() -> bool:
	var native_view: EventSheetViewport = _view_of(SHOOTER, NATIVE_THEME)
	var events: Array[int] = _top_level_events(native_view)
	var jump: EventRowData = native_view._row_at(events[0])
	var line: float = native_view._get_event_line_height(native_view._get_font_size())
	var at_rest: Array = [native_view._row_metrics_helper.row_height(events[0]), native_view._row_metrics_helper.row_height(events[1])]
	var second_top: float = native_view._row_metrics_helper.row_top(events[1])
	native_view._set_hover_state(events[0], -1)
	var hovered: Array = [native_view._row_metrics_helper.row_height(events[0]), native_view._row_metrics_helper.row_top(events[1]) - second_top]
	native_view._set_hover_state(events[1], -1)
	var moved_on: Array = [native_view._row_metrics_helper.row_height(events[0]), native_view._row_metrics_helper.row_height(events[1])]
	native_view._select_row(events[0], -1)
	var selected: float = native_view._row_metrics_helper.row_height(events[0])
	var shoot: EventRowData = native_view._row_at(events[2])
	var shoot_trailing: float = native_view._row_metrics_helper.condition_trailing_width(
		shoot, 0, native_view._get_font(), native_view._get_font_size())
	var lane: float = native_view.lane_width_for("condition")
	var blank_tick: EventRowData = _event_with(native_view, events, "Keep ")
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the text is the design's 12 px, on 24 px lines", [native_view._get_font_size(), line], [12, 24.0]],
		["a one-condition, one-action event is one line at rest", at_rest, [24.0, 24.0]],
		["hovered it gains its add line, and the event below moves down by it", hovered, [48.0, 24.0]],
		["the pointer moving on gives the line to the next event", moved_on, [24.0, 48.0]],
		["selected it keeps the line", selected, 48.0],
		["the trigger keeps its badge in the lane, and the behaviour leads its words",
			_texts(jump), "⌨ | On \"ui_up\" pressed | + Add condition | Platformer: Jump | + Add action"],
		["the action keeps the node the behaviour is mounted on", _object_of(jump, "Jump"), "PlatformerShooter"],
		["the pattern chip yields to the trigger's words", shoot_trailing <= lane * 0.4 + 0.01, true],
		["a physics tick with no condition reads as its neighbours' trigger cell",
			[_object_of(blank_tick, "Every tick (physics)"), _texts(blank_tick).contains("every tick (physics)")],
			["System", false]],
	])
	native_view.free()
	var classic_view: EventSheetViewport = _view_of(SHOOTER, CLASSIC_THEME)
	var classic_events: Array[int] = _top_level_events(classic_view)
	var classic_jump: EventRowData = classic_view._row_at(classic_events[0])
	var classic_rest: float = classic_view._row_metrics_helper.row_height(classic_events[0])
	var classic_blank_tick: EventRowData = _event_with(classic_view, classic_events, "Keep ")
	classic_view._set_hover_state(classic_events[0], -1)
	result = SUPPORT.pins(TEST_NAME, [
		["Classic Sheet keeps its font, its trigger badge and the behaviour in the sentence",
			[classic_view._get_font_size(), _texts(classic_jump)],
			[16, "⌨ | On \"ui_up\" pressed | + Add condition | Platformer: Jump | + Add action"]],
		["and the script's object in the column", _object_of(classic_jump, "Platformer"), "PlatformerShooter"],
		["and the blank physics tick as the trigger line every look reads, System and all",
			[_object_of(classic_blank_tick, "Every tick (physics)"), _texts(classic_blank_tick).contains("every tick (physics)")],
			["System", false]],
		["and the add line reserved, hovered or not",
			[classic_rest, classic_view._row_metrics_helper.row_height(classic_events[0])], [64.0, 64.0]],
	]) and result
	classic_view.free()
	return result


static func _test_gutter_geometry() -> bool:
	var row := Rect2(0.0, 100.0, 800.0, 72.0)
	var gutter := Rect2(0.0, 100.0, 20.0, 72.0)
	return SUPPORT.pins(TEST_NAME, [
		["centred on the event without a first line, as before",
			NativeRowMarks.trigger_icon_rect(row, 0, 18), Rect2(32.0, 129.0, 14.0, 14.0)],
		["on the first line beside the number with one",
			NativeRowMarks.trigger_icon_rect(row, 0, 18, 24.0), Rect2(32.0, 105.0, 14.0, 14.0)],
		["one margin column across the icon's slot", NativeRowMarks.gutter_band_rect(gutter, row, 0, 18),
			Rect2(0.0, 100.0, 48.0, 72.0)],
		["a nested event keeps the plain gutter", NativeRowMarks.gutter_band_rect(gutter, row, 1, 18), gutter],
	])


static func _event_row(kinds: Array, placeholder: bool = false) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	for kind: String in kinds:
		var span := SemanticSpan.new()
		span.text = kind
		span.metadata = {"kind": kind, "placeholder": placeholder and kind == "condition"}
		row_data.spans.append(span)
	return row_data


static func _view_of(path: String, theme_path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = false
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	# A canvas as wide as a docked sheet, so no cell wraps and a height is a count of lines.
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


static func _top_level_events(view: EventSheetViewport) -> Array[int]:
	var found: Array[int] = []
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT and row_data.indent == 0:
			view._row_builder._ensure_event_spans(row_data)
			found.append(index)
	return found


## The first top-level event whose words contain `text_part`.
static func _event_with(view: EventSheetViewport, events: Array[int], text_part: String) -> EventRowData:
	for index: int in events:
		var row_data: EventRowData = view._row_at(index)
		if _texts(row_data).contains(text_part):
			return row_data
	return null


static func _object_of(row_data: EventRowData, text_part: String) -> String:
	for span: SemanticSpan in row_data.spans if row_data != null else []:
		if span.text.contains(text_part):
			return str((span.metadata as Dictionary).get("object_label", ""))
	return ""


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	return " | ".join(parts)
