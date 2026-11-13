@tool
extends RefCounted
# Godot EventSheets - Editor Native draws the event alignment board
#
# The board's measured values, pinned: the lanes' neutral greys (derived from the editor's base, so a
# darker editor moves them together), the 1 px divider, the object blue, the 34 px number column,
# blocks at 52 / 70 / 88 px, the fold slot of each level, exactly 1 px between a parent and its child, the group
# bar's colour, and that Classic Sheet keeps its own geometry.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_board_drawing_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_palette_at_the_default_editors() and ok
	ok = _test_palette_follows_the_editor() and ok
	ok = _test_geometry() and ok
	ok = _test_classic_keeps_its_geometry() and ok
	return ok


static func _test_palette_at_the_default_editors() -> bool:
	var dark: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE).get_event_style()
	var rows: Array = []
	for pair: Array in [["dark", dark, ["3a3a3a", "323232", "363636", "2a2a2a", "262626", "8ec3f2", "4a4a4a"]],
			["light", light, ["ffffff", "f0f0f0", "f7f7f7", "cfcfcf", "e0e0e0", "124175", "c9c9c9"]]]:
		var style: EventSheetEventStyle = pair[1]
		rows.append(["%s: condition line, rest, action lane, divider, canvas, object name, group bar" % pair[0],
			[style.condition_lane_color.to_html(false), EventSheetRowRenderer.condition_cell_rest(style).to_html(false),
				style.action_lane_color.to_html(false), style.lane_divider_color.to_html(false),
				style.sheet_background_color.to_html(false), style.object_label_color.to_html(false),
				style.group_background_color.to_html(false)], pair[2]])
		rows.append(["%s: a 1 px divider, an 18 px step, no card border" % pair[0],
			[style.lane_divider_width, style.sub_event_indent, style.event_card_border_width], [1, 18, 0]])
	return SUPPORT.pins(TEST_NAME, rows)


## A darker editor moves the lanes with it: the lane is the design grey shifted by how far the
## editor's canvas moved, and the steps between the greys survive.
static func _test_palette_follows_the_editor() -> bool:
	var reference: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var darker: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(Color("#1e1e1e")).get_event_style()
	var step_ref: float = reference.condition_lane_color.r - reference.sheet_background_color.r
	var step_dark: float = darker.condition_lane_color.r - darker.sheet_background_color.r
	return SUPPORT.pins(TEST_NAME, [
		["a darker editor gets a darker condition lane", darker.condition_lane_color.r < reference.condition_lane_color.r, true],
		["and the step from the canvas to the lane survives", is_equal_approx(step_ref, step_dark), true],
		["the lane stays a neutral grey (no blue or green tint)",
			[is_equal_approx(darker.condition_lane_color.r, darker.condition_lane_color.b),
				is_equal_approx(darker.action_lane_color.r, darker.action_lane_color.g)], [true, true]],
	])


static func _layout_of(theme_path: String) -> Dictionary:
	var sheet := EventSheetResource.new()
	sheet.editor_style = load(theme_path) as EventSheetEditorStyle
	var top := EventRow.new()
	top.trigger_id = "OnProcess"
	var mid := EventRow.new()
	mid.trigger_id = "OnProcess"
	var deep := EventRow.new()
	deep.trigger_id = "OnProcess"
	mid.sub_events.append(deep)
	top.sub_events.append(mid)
	sheet.events.append(top)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var out: Dictionary = {"blocks": [], "numbers": [], "folds": [], "gaps": [], "dividers": []}
	var previous_end: float = -1.0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var layout: Dictionary = view.get_row_layout_for_test(index, 1300.0)
		(out["blocks"] as Array).append((layout.get("condition_lane_rect", Rect2()) as Rect2).position.x)
		(out["numbers"] as Array).append((layout.get("gutter_rect", Rect2()) as Rect2).size.x)
		(out["folds"] as Array).append(layout.get("fold_rect", Rect2()))
		(out["dividers"] as Array).append((layout.get("lane_divider_rect", Rect2()) as Rect2).size.x)
		var top_y: float = view.get_row_top(index)
		if previous_end >= 0.0:
			(out["gaps"] as Array).append(top_y - previous_end)
		previous_end = top_y + view.get_row_height(index)
	view.free()
	return out


static func _test_geometry() -> bool:
	var native: Dictionary = _layout_of(NATIVE_THEME)
	var folds: Array = native["folds"]
	var rows: Array = [
		["blocks of depth 0, 1 and 2 begin at 52, 70 and 88 px from the canvas", native["blocks"], [52.0, 70.0, 88.0]],
		["the number column is 34 px wide on every event", native["numbers"], [34.0, 34.0, 34.0]],
		["a parent's fold arrow fills the slot just left of its block (34..52, 52..70)",
			[(folds[0] as Rect2).position.x, (folds[0] as Rect2).end.x, (folds[1] as Rect2).position.x, (folds[1] as Rect2).end.x],
			[34.0, 52.0, 52.0, 70.0]],
		["a childless event has no fold slot", (folds[2] as Rect2).size, Vector2.ZERO],
		["exactly 1 px between a parent and its child, whatever the gap between two events is", native["gaps"], [1.0, 1.0]],
		["a 1 px lane divider", native["dividers"], [1.0, 1.0, 1.0]],
		["nesting lines stand 8 px into their slot",
			[EventSheetRowRenderer.nesting_line_x(0, 18), EventSheetRowRenderer.nesting_line_x(1, 18)], [42.0, 60.0]],
	]
	return SUPPORT.pins(TEST_NAME, rows)


static func _test_classic_keeps_its_geometry() -> bool:
	var classic: Dictionary = _layout_of(CLASSIC_THEME)
	var origin: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + float(EventSheetPalette.GUTTER_WIDTH) + 18.0
	var blocks: Array = classic["blocks"]
	var classic_step: float = float((load(CLASSIC_THEME) as EventSheetEditorStyle).get_event_style().sub_event_indent)
	return SUPPORT.pins(TEST_NAME, [
		["Classic Sheet: the number gutter is still the 20 px column on every event",
			classic["numbers"], [20.0, 20.0, 20.0]],
		["Classic Sheet: the lane starts at the old origin and steps by its own indent",
			[blocks[0], blocks[1] - blocks[0], blocks[2] - blocks[1]], [origin, classic_step, classic_step]],
		["Classic Sheet: no extra gap below a parent", classic["gaps"], [0.0, 0.0]],
	])
