@tool
class_name EventSheetDensityStyle
extends Resource

## How much room a sheet gives its rows, as a resource a project owns.
##
## The six numbers below are the whole of a sheet's breathing room: how tall a row is, how much air
## a cell keeps above and below its text, how big a gap opens between two events, how far a
## sub-event steps in (and whether a rail line is drawn down that step), how wide the object-name
## column is, and how thick the border round a whole event is. They live on the theme resource the
## project owns - a density is data in the project, never a plugin constant.
##
## A density starter is one of these saved as a `.tres`. Three ship (Compact, Comfortable,
## Spacious); a user copies one, edits the numbers and drops it beside them, and it appears in the
## menu with no code and no restart. Nothing here is a fixed house style: the starters are the
## beginning of an answer, not the answer.
##
## Applying one COPIES its numbers onto a theme's own sub-styles and touches nothing else - every
## colour, chip and corner radius the theme states survives a density change untouched, which is
## what lets density and look be two independent choices instead of one bundled decision.

## Height an event row reserves before its text asks for more.
@export_range(20, 200, 1) var row_height: int = EventSheetPalette.ROW_HEIGHT
## Horizontal air inside a condition/action cell, left and right of its text.
@export_range(0, 24, 1) var cell_padding_horizontal: int = 8
## Vertical air inside a condition/action cell, above and below its text.
@export_range(0, 16, 1) var cell_padding_vertical: int = EventSheetPalette.CELL_PADDING_V
## Gap opened before an event or group that starts a new sibling block.
@export_range(0, 48, 1) var event_block_gap: int = EventSheetPalette.EVENT_BLOCK_GAP
## How far one nesting level indents a sub-event.
@export_range(4, 96, 1) var sub_event_indent: int = EventSheetPalette.INDENT_WIDTH
## Draw the rail line a sub-event hangs from, down its parent's indent step.
@export var sub_event_rail_line: bool = true
## Fixed width of the object-name column in both lanes. 0 = flow, where each row's text starts
## wherever its own object name ended.
@export_range(0, 480, 1) var object_column_width: int = EventSheetPalette.OBJECT_COLUMN_WIDTH
## Thickness of the border drawn round a whole event. 0 = no card.
@export_range(0, 4, 1) var event_card_border_width: int = EventSheetPalette.EVENT_CARD_BORDER_WIDTH
## Gap between the number gutter and the card's left edge.
@export_range(0, 16, 1) var event_card_gutter_gap: int = EventSheetPalette.EVENT_CARD_GUTTER_GAP


## Writes these numbers onto a theme's sub-styles. Colours, chips and radii are untouched: a
## density is a spacing choice, and swapping one must never repaint a theme somebody tuned.
func apply_to(editor_style: EventSheetEditorStyle) -> void:
	if editor_style == null:
		return
	editor_style.ensure_defaults()
	var event_style: EventSheetEventStyle = editor_style.get_event_style()
	event_style.minimum_row_height = row_height
	event_style.event_block_gap = event_block_gap
	event_style.sub_event_indent = sub_event_indent
	event_style.sub_event_rail_line = sub_event_rail_line
	event_style.condition_object_column_width = object_column_width
	event_style.action_object_column_width = object_column_width
	event_style.event_card_border_width = event_card_border_width
	event_style.event_card_gutter_gap = event_card_gutter_gap
	for element_style: EventSheetElementStyle in [editor_style.get_condition_style(), editor_style.get_action_style()]:
		element_style.horizontal_padding = cell_padding_horizontal
		element_style.vertical_padding = cell_padding_vertical


## The density a theme is currently wearing, read back off its sub-styles. The menu ticks a starter
## by comparing this against each shipped one, so a theme that states its own numbers ticks nothing
## rather than pretending to be a starter it is not.
static func read_from(editor_style: EventSheetEditorStyle) -> EventSheetDensityStyle:
	var density := EventSheetDensityStyle.new()
	if editor_style == null:
		return density
	editor_style.ensure_defaults()
	var event_style: EventSheetEventStyle = editor_style.get_event_style()
	density.row_height = event_style.minimum_row_height
	density.event_block_gap = event_style.event_block_gap
	density.sub_event_indent = event_style.sub_event_indent
	density.sub_event_rail_line = event_style.sub_event_rail_line
	density.object_column_width = event_style.condition_object_column_width
	density.event_card_border_width = event_style.event_card_border_width
	density.event_card_gutter_gap = event_style.event_card_gutter_gap
	var condition_style: EventSheetElementStyle = editor_style.get_condition_style()
	density.cell_padding_horizontal = condition_style.horizontal_padding
	density.cell_padding_vertical = condition_style.vertical_padding
	return density


## True when two densities state the same six numbers. Value equality, not resource identity: a
## starter loaded from disk and a theme's own spacing are different objects that may say the
## same thing, and the menu tick is about what they say.
func matches(other: EventSheetDensityStyle) -> bool:
	if other == null:
		return false
	return (
		row_height == other.row_height
		and cell_padding_horizontal == other.cell_padding_horizontal
		and cell_padding_vertical == other.cell_padding_vertical
		and event_block_gap == other.event_block_gap
		and sub_event_indent == other.sub_event_indent
		and sub_event_rail_line == other.sub_event_rail_line
		and object_column_width == other.object_column_width
		and event_card_border_width == other.event_card_border_width
		and event_card_gutter_gap == other.event_card_gutter_gap
	)
