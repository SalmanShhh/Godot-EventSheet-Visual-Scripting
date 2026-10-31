@tool
extends RefCounted
# Godot EventSheets - sub-events lined up (the Editor Native nesting)
#
# Nesting is drawn as STRIPS: each level steps the whole block right by one 16 px step, filled with
# the parent's colour, no connector line. The sheet keeps ONE condition/action divider for every
# depth; a nested event's condition lane is the divider minus its steps, never narrower than 150 px,
# and only an event nested past that floor starts its own actions later. The pins hold:
#   1. the token is off by default, on in the Editor Native starter and its rule, with a 16 px
#      step and no rail;
#   2. one divider x for every depth until the floor, then the row's own;
#   3. the strips' ancestor kinds are stamped by the flatten (group vs event);
#   4. the object-name column gives way at half of a narrowed lane.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "sub_event_strips_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_token() and ok
	ok = _test_divider() and ok
	ok = _test_strip_kinds() and ok
	ok = _test_name_column_cap() and ok
	return ok


static func _test_token() -> bool:
	var defaults := EventSheetEventStyle.new()
	var starter: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	var rule: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	return SUPPORT.pins(TEST_NAME, [
		["strips are off by default", defaults.sub_event_strips, false],
		["the starter draws strips at a 16 px step with no rail",
			[starter.sub_event_strips, starter.sub_event_indent, starter.sub_event_rail_line], [true, 16, false]],
		["and so does the rule it is built by",
			[rule.sub_event_strips, rule.sub_event_indent, rule.sub_event_rail_line], [true, 16, false]],
	])


static func _test_divider() -> bool:
	var viewport := EventSheetViewport.new()
	var width: float = 1300.0
	var shared: float = viewport.get_lane_divider_x(width)
	var step: float = float(viewport.indent_width())
	var lane_start_at_zero: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + 18.0
	var depth_past_floor: int = int(ceil((shared - lane_start_at_zero) / step)) + 2
	var past: float = viewport.row_lane_divider_x(width, depth_past_floor)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["depths 0 to 3 share the sheet's one divider",
			[viewport.row_lane_divider_x(width, 0), viewport.row_lane_divider_x(width, 1),
				viewport.row_lane_divider_x(width, 2), viewport.row_lane_divider_x(width, 3)],
			[shared, shared, shared, shared]],
		["an event nested past the floor keeps a 150 px conditions lane and moves its actions right",
			[past > shared, past - (lane_start_at_zero + float(depth_past_floor) * step)],
			[true, EventSheetViewport.NESTED_LANE_FLOOR]],
	])
	viewport.free()
	return ok


static func _test_strip_kinds() -> bool:
	var viewport := EventSheetViewport.new()
	var group := EventRowData.new()
	group.row_type = EventRowData.RowType.GROUP
	group.indent = 0
	var event := EventRowData.new()
	event.row_type = EventRowData.RowType.EVENT
	event.indent = 1
	var sub := EventRowData.new()
	sub.row_type = EventRowData.RowType.EVENT
	sub.indent = 2
	event.children = [sub]
	group.children = [event]
	viewport._flatten_row(group, null)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a row under a group and an event: level 0 is the group's, level 1 the event's",
			[group.strip_groups, event.strip_groups, sub.strip_groups], [0, 1, 1]],
	])
	viewport.free()
	return ok


static func _test_name_column_cap() -> bool:
	var style := EventSheetEventStyle.new()
	style.condition_object_column_width = 114
	return SUPPORT.pins(TEST_NAME, [
		["the name column keeps its width in a wide lane", EventRowRenderer.object_column_width_for(style, "condition", 600.0), 114.0],
		["and gives way to under half of a narrowed lane", EventRowRenderer.object_column_width_for(style, "condition", 150.0), 67.5],
	])
