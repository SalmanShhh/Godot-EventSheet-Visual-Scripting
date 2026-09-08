# EventForge - the density tokens, the three shipped starters, and the card the tokens draw.
#
# How much room a sheet gives its rows is a theme question, not a plugin constant: six numbers on
# the theme resource decide it, and three starters state them. This pins all three halves of that
# claim by VALUE:
#
#   • the tokens read from a theme - the layout seams (row height floor, indent step, block gap)
#     answer what the sheet's own theme says, not what the palette holds;
#   • the three starters' own numbers, and that Comfortable is what a fresh theme already wears
#     (a default nobody has to choose is the one most projects will keep);
#   • the geometry the card and gutter tokens produce for a real two-event sheet - the card's
#     painted rectangle starts PAST the number gutter, and an OR stack is framed once over the
#     union of its rows rather than once per row.
@tool
class_name SheetDensityTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "sheet_density_test"
const COMPACT_PATH := "res://addons/eventsheet/themes/density/compact_density.tres"
const COMFORTABLE_PATH := "res://addons/eventsheet/themes/density/comfortable_density.tres"
const SPACIOUS_PATH := "res://addons/eventsheet/themes/density/spacious_density.tres"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_starters() and all_passed
	all_passed = _pin_tokens_reach_the_layout() and all_passed
	all_passed = _pin_card_geometry() and all_passed
	return all_passed


## The three shipped starters, each number as the file states it, and the order the menu offers
## them in. Pinned as values because these ARE the product: a starter is a file a user reads.
static func _pin_starters() -> bool:
	var compact: EventSheetDensityStyle = load(COMPACT_PATH)
	var comfortable: EventSheetDensityStyle = load(COMFORTABLE_PATH)
	var spacious: EventSheetDensityStyle = load(SPACIOUS_PATH)
	var names: Array[String] = []
	for preset: Dictionary in EventSheetDensityPresets.list_presets():
		names.append(str(preset.get("name", "")))
	var fresh := EventSheetEditorStyle.new()
	return SUPPORT.pins(PREFIX, [
		["Compact keeps the row height the editor shipped with", compact.row_height, 28],
		["Compact keeps the old cell padding", [compact.cell_padding_horizontal, compact.cell_padding_vertical], [8, 2]],
		["Compact keeps the old gap between events", compact.event_block_gap, 7],
		["Compact keeps the old indent and draws no rail", [compact.sub_event_indent, compact.sub_event_rail_line], [18, false]],
		["Compact keeps the old object column", compact.object_column_width, 130],
		["Compact draws no card", compact.event_card_border_width, 0],

		["Comfortable raises the row height", comfortable.row_height, 32],
		["Comfortable gives a cell more air above and below", [comfortable.cell_padding_horizontal, comfortable.cell_padding_vertical], [8, 3]],
		["Comfortable opens the gap between events", comfortable.event_block_gap, 10],
		["Comfortable indents further and hangs a rail", [comfortable.sub_event_indent, comfortable.sub_event_rail_line], [28, true]],
		["Comfortable narrows the object column", comfortable.object_column_width, 96],
		["Comfortable draws a one pixel card", [comfortable.event_card_border_width, comfortable.event_card_gutter_gap], [1, 0]],

		["Spacious is the tallest row", spacious.row_height, 36],
		["Spacious gives a cell the most air", [spacious.cell_padding_horizontal, spacious.cell_padding_vertical], [10, 5]],
		["Spacious opens the widest gap", spacious.event_block_gap, 14],
		["Spacious indents furthest and hangs a rail", [spacious.sub_event_indent, spacious.sub_event_rail_line], [32, true]],
		["Spacious widens the object column", spacious.object_column_width, 120],
		["Spacious holds its card off the gutter", [spacious.event_card_border_width, spacious.event_card_gutter_gap], [1, 2]],

		["the menu offers them tightest first", names, ["Compact", "Comfortable", "Spacious"]],
		["a fresh theme already wears Comfortable",
			EventSheetDensityStyle.read_from(fresh).matches(comfortable), true],
		["and is not wearing Compact", EventSheetDensityStyle.read_from(fresh).matches(compact), false],
	])


## Applying a starter writes its six numbers onto a theme's own sub-styles, and the viewport's
## layout seams read them back. This is the whole contract of "the constants became defaults read
## through the active theme": change the theme, and the distances change with it.
static func _pin_tokens_reach_the_layout() -> bool:
	var style := EventSheetEditorStyle.new()
	(load(SPACIOUS_PATH) as EventSheetDensityStyle).apply_to(style)
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.editor_style = style
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var event_style: EventSheetEventStyle = viewport._get_event_style()
	var passed: bool = SUPPORT.pins(PREFIX, [
		["the row height floor is the theme's", viewport.row_height_floor(), 36.0],
		["the indent step is the theme's", viewport.indent_width(), 32],
		["the block gap is the theme's", viewport.event_block_gap(), 14.0],
		["the card border is the theme's", event_style.event_card_border_width, 1],
		["applying a density leaves the colours alone",
			event_style.selection_fill_color, EventSheetEventStyle.new().selection_fill_color],
		["both lanes take the one object column",
			[event_style.condition_object_column_width, event_style.action_object_column_width], [120, 120]],
		["and both cell styles take the one padding",
			[style.get_condition_style().vertical_padding, style.get_action_style().vertical_padding], [5, 5]],
	])
	editor.free()
	return passed


## The card the tokens draw, over a two-event sheet whose first event is an OR stack. The card's
## PAINTED rectangle is the event's own rectangle with the number gutter taken off the front - the
## number is a margin mark, and a card that swallowed it would say otherwise.
static func _pin_card_geometry() -> bool:
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_or_event())
	sheet.events.append(_plain_event())
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var width: float = viewport._get_logical_canvas_width()
	viewport.get_row_layout_for_test(0, width)
	viewport.get_row_layout_for_test(1, width)
	var card: Rect2 = viewport.event_card_rect(0)
	var painted: Rect2 = viewport.event_card_border_rect(0)
	var gutter: float = float(EventSheetPalette.GUTTER_WIDTH)
	var passed: bool = SUPPORT.pins(PREFIX, [
		["the painted card starts past the number gutter", painted.position.x, gutter],
		["the painted card keeps the event's own top", painted.position.y, card.position.y],
		["the painted card keeps the event's own height", painted.size.y, card.size.y],
		["the painted card stops one pixel inside the canvas", painted.end.x, width - 1.0],
		["the OR stack is one card, not one per condition",
			viewport.event_card_rect(0), viewport.event_card_rect(viewport.statement_last_index(0))],
		["the second event has a card of its own",
			viewport.event_card_border_rect(1).position.y > painted.end.y, true],
	])
	# A theme that draws no card still answers a rectangle: the geometry is the event's either way,
	# and the border width alone decides whether anything is painted in it.
	var compact_style := EventSheetEditorStyle.new()
	(load(COMPACT_PATH) as EventSheetDensityStyle).apply_to(compact_style)
	sheet.editor_style = compact_style
	viewport.set_sheet(sheet)
	viewport.get_row_layout_for_test(0, width)
	passed = SUPPORT.pins(PREFIX, [
		["Compact still measures the card", viewport.event_card_border_rect(0).position.x, gutter],
		["Compact simply paints no border", viewport._get_event_style().event_card_border_width, 0],
	]) and passed
	editor.free()
	return passed


## An event whose conditions are OR'd, so it is drawn on several rows and framed once.
static func _or_event() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.condition_mode = EventRow.ConditionMode.OR
	row.conditions.append(_condition("health > 0"))
	row.conditions.append(_condition("shield > 0"))
	return row


## A one-condition event: the card below the stack.
static func _plain_event() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_condition("armour > 0"))
	return row


static func _condition(expression: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.params = {"expr": expression}
	return condition
