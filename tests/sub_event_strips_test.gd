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
	ok = _test_strip_fill_and_cut_names() and ok
	return ok


## A strip is filled with the parent's condition lane (or its group's tint), and a name the fixed
## column cut short is read whole by the hover.
static func _test_strip_fill_and_cut_names() -> bool:
	var style := EventSheetEventStyle.new()
	style.condition_lane_color = Color("#112233")
	style.group_background_color = Color("#445566")
	style.row_background_color = Color("#778899")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["an event parent fills its strip with its condition lane, never the row background",
			EventRowRenderer.strip_fill(style, false).to_html(false), "112233"],
		["a group parent fills it with the group tint", EventRowRenderer.strip_fill(style, true).to_html(false), "445566"],
	])
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
	view._layout_builder.get_or_build_row_layout(0, view._get_logical_canvas_width(), view._get_font(), view._get_font_size())
	var row_data: EventRowData = view._row_at(0)
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
