@tool
extends RefCounted
# Godot EventSheets - sub-events lined up (the Editor Native nesting)
#
# Nesting is drawn as ONE 1 px line per level in the margin (each level steps the block right by one
# 16 px step), no fill and no connector. The sheet keeps ONE condition/action divider for every
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
	ok = _test_strip_fill_and_cut_names() and ok
	return ok


## Nesting is one 1 px line per level at the fold arrow's column, a nested block begins past the lines
## of its ancestors, the condition cell keeps a quieter tone below its strips, an event keeps its
## add action line at rest, and a name the fixed column cut short is read whole by the hover.
static func _test_strip_fill_and_cut_names() -> bool:
	var style := EventSheetEventStyle.new()
	style.condition_lane_color = Color("#404040")
	style.sheet_background_color = Color("#202020")
	var step: int = 16
	var origin: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + float(EventSheetPalette.GUTTER_WIDTH)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["level 0 draws its line two px left of the first nested block's slot",
			EventRowRenderer.nesting_line_x(0, step), origin - 2.0],
		["each level moves its line one step right", EventRowRenderer.nesting_line_x(2, step) - EventRowRenderer.nesting_line_x(1, step), float(step)],
		["a nested block begins at its own slot, past every ancestor's line",
			EventRowRenderer.nested_block_left_for(2, step), origin + 2.0 * float(step)],
		["the line of a level is left of the block that level's arrow opens",
			EventRowRenderer.nesting_line_x(1, step) < EventRowRenderer.nested_block_left_for(1, step), true],
		["the cell below the last condition is the lane drawn halfway to the sheet",
			EventRowRenderer.condition_cell_rest(style).to_html(false), "303030"],
		["the add action line rests under every event in the Editor Native look and nowhere else",
			[EventRowRenderer.add_action_line_rests(null), EventRowRenderer.add_action_line_rests(style)], [false, false]],
	])
	style.sub_event_strips = true
	ok = SUPPORT.check(TEST_NAME, "the add action line rests with the strips look",
		EventRowRenderer.add_action_line_rests(style), true) and ok
	var kinds_at_rest: PackedStringArray = ViewportRowMetrics.resting_add_line_kinds(_filled_event_row(), _hover_style(true))
	ok = SUPPORT.check(TEST_NAME, "only the add condition line waits for the hover under that look",
		kinds_at_rest, PackedStringArray(["add_condition"])) and ok
	var local := EventRowData.new()
	local.row_type = EventRowData.RowType.SECTION
	local.variable_row = true
	var promoted := EventRowData.new()
	promoted.row_type = EventRowData.RowType.SECTION
	promoted.row_uid = "local_declaration_ev_3"
	var global_row := EventRowData.new()
	global_row.row_type = EventRowData.RowType.SECTION
	global_row.variable_row = true
	local.inside_event = true
	promoted.inside_event = true
	ok = SUPPORT.pins(TEST_NAME, [
		["a variable row inside an event is a local on the sheet", EventRowRenderer.is_local_variable_row(local), true],
		["so is a declaration promoted out of its actions", EventRowRenderer.is_local_variable_row(promoted), true],
		["a variable row at the sheet's level is not", EventRowRenderer.is_local_variable_row(global_row), false],
	]) and ok
	var sheet := EventSheetResource.new()
	var event := EventRow.new()
	var condition := ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "Compare"
	event.conditions.append(condition)
	sheet.events.append(event)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 600.0)
	view.set_sheet(sheet)
	var layout: Dictionary = view._layout_builder.get_or_build_row_layout(0, view._get_logical_canvas_width(), view._get_font(), view._get_font_size())
	var row_data: EventRowData = view._row_at(0)
	var bands: Array = layout.get("condition_line_bands", [])
	ok = SUPPORT.pins(TEST_NAME, [
		["an event with one condition has one condition strip, a line tall", bands.size(), 1],
		["and the strip is exactly one line high", (bands[0] as Vector2).y if not bands.is_empty() else -1.0,
			view._get_event_line_height(view._get_font_size())],
	]) and ok
	var span: SemanticSpan = null
	for candidate: SemanticSpan in row_data.spans:
		if candidate != null and candidate.metadata is Dictionary and (candidate.metadata as Dictionary).has("object_label") \
				and str((candidate.metadata as Dictionary).get("lane", "")) == "condition":
			span = candidate
			break
	if span == null:
		ok = SUPPORT.check(TEST_NAME, "the sample event has a condition span with an object name", false, true) and ok
	else:
		var metadata: Dictionary = span.metadata
		var short_name: String = str(metadata.get("object_label", ""))
		var inside: Vector2 = Vector2(span.rect.position.x + 2.0, span.rect.get_center().y)
		var whole: String = view.elided_object_name_at(0, row_data.spans.find(span), inside)
		metadata["object_label"] = "AVeryLongObjectNameThatNoColumnCouldHold_" + short_name
		var cut: String = view.elided_object_name_at(0, row_data.spans.find(span), inside)
		ok = SUPPORT.pins(TEST_NAME, [
			["a name that fits its column adds no hover", whole, ""],
			["a name wider than the column is read whole on hover", cut, str(metadata.get("object_label", ""))],
			["and a point past the column is not the name", view.elided_object_name_at(0, row_data.spans.find(span),
				Vector2(span.rect.end.x + 500.0, inside.y)), ""],
		]) and ok
		ok = _test_cut_name_agrees_with_the_drawn_ellipsis(view, row_data, span) and ok
	view.free()
	return ok


## A chip cell starts its column after its padding, so a name only a few pixels too wide for the
## column is drawn "CharacterBo…" - and the hover must read it whole too. Every length from short to
## long: the hover answers exactly when the renderer's own elide (column less 6 px) cuts the name.
static func _test_cut_name_agrees_with_the_drawn_ellipsis(view: EventSheetViewport, row_data: EventRowData, span: SemanticSpan) -> bool:
	var metadata: Dictionary = span.metadata
	metadata["chip"] = true
	metadata["padding_x"] = 8.0
	var column: float = float(metadata.get("object_column_px", 0.0))
	var font: Font = view._get_font()
	var draw_size: int = view._span_draw_font_size(span, view._get_font_size())
	var inside: Vector2 = Vector2(span.rect.position.x + 12.0, span.rect.get_center().y)
	var disagreements: PackedStringArray = PackedStringArray()
	var cut_seen: int = 0
	var name: String = ""
	for letter: String in "CharacterBody2DWithAVeryLongTailIndeed".split(""):
		name += letter
		metadata["object_label"] = name
		var drawn_cut: bool = EventRowRenderer._elide(name, column - 6.0, font, draw_size) != name
		var hover: String = view.elided_object_name_at(0, row_data.spans.find(span), inside)
		if drawn_cut:
			cut_seen += 1
		if (hover == name) != drawn_cut:
			disagreements.append(name)
	return SUPPORT.pins(TEST_NAME, [
		["the column is stamped by the layout", column > 0.0, true],
		["some of the names are cut by the column", cut_seen > 0, true],
		["the hover reads a name whole exactly when the drawn name ends in an ellipsis", ", ".join(disagreements), ""],
	])


static func _filled_event_row() -> EventRowData:
	var row_data := EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	for kind: String in ["condition", "action"]:
		var span := SemanticSpan.new()
		span.metadata = {"kind": kind}
		row_data.spans.append(span)
	return row_data


static func _hover_style(strips: bool) -> EventSheetEventStyle:
	var style := EventSheetEventStyle.new()
	style.add_lines_on_hover = true
	style.sub_event_strips = strips
	return style


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
		["a row is inside an event only when its parent is one: [group, event under the group, sub-event]",
			[group.inside_event, event.inside_event, sub.inside_event], [false, false, true]],
	])
	viewport.free()
	return ok


static func _test_name_column_cap() -> bool:
	var style := EventSheetEventStyle.new()
	style.condition_object_column_width = 114
	return SUPPORT.pins(TEST_NAME, [
		["the name column keeps its width in a wide lane", EventRowRenderer.object_column_width_for(style, "condition", 600.0), 114.0],
		["and gives way at half of a narrowed lane", EventRowRenderer.object_column_width_for(style, "condition", 150.0), 75.0],
	]) and _test_row_lanes()


## Each depth bounds its name column by the lane it actually has: a nested event's conditions lane is
## one step narrower per level (same divider, later start), and an event nested past the floor keeps a
## 150 px conditions lane and an actions lane that starts at its own, later divider.
static func _test_row_lanes() -> bool:
	var viewport := EventSheetViewport.new()
	var width: float = viewport._get_logical_canvas_width()
	var step: float = float(viewport.indent_width())
	var top_condition: float = viewport.lane_width_for("condition", 0)
	var lane_start_at_zero: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + 18.0
	var deep: int = int(ceil((viewport.get_lane_divider_x(width) - lane_start_at_zero) / step)) + 2
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["two levels down, the conditions lane is two steps narrower",
			top_condition - viewport.lane_width_for("condition", 2), 2.0 * step],
		["past the floor, the actions lane starts at the row's own divider",
			viewport.lane_width_for("action", 0) - viewport.lane_width_for("action", deep),
			viewport.row_lane_divider_x(width, deep) - viewport.get_lane_divider_x(width)],
	])
	viewport.free()
	return ok
