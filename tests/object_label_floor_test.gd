# Godot EventSheets - the sheet's object column holds the widest object name whole.
#
# The column is a fixed width shared by every row of a lane (96 px by default), so a long class name was
# cut to "ScriptRowsAnnotatedT..." however much room the lane had. The viewport measures the widest object
# name of each lane and the column grows to hold it, up to the share of the lane it may take; a lane that is
# truly short still elides. Drawing only: no reading text moves.
@tool
class_name ObjectLabelFloorTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var style: EventSheetEventStyle = EventSheetEventStyle.new()
	style.condition_object_column_width = 96
	style.action_object_column_width = 146
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport._flat_rows = [
		{"row": _row_with("action", "ScriptRowsAnnotatedTwin")},
		{"row": _row_with("action", "Rat")},
		{"row": _row_with("condition", "Rat")},
	]
	viewport._row_builds += 1
	var font: Font = viewport._get_font()
	var long_width: float = font.get_string_size("ScriptRowsAnnotatedTwin", HORIZONTAL_ALIGNMENT_LEFT, -1.0, viewport._get_font_size()).x
	var rat_width: float = font.get_string_size("Rat", HORIZONTAL_ALIGNMENT_LEFT, -1.0, viewport._get_font_size()).x
	var floors: Array = [viewport.object_label_floor("action"), viewport.object_label_floor("condition"),
		viewport.object_label_floor("keyword")]
	viewport.free()
	var pad: float = EventSheetRowRenderer.OBJECT_LABEL_PAD
	return SUPPORT.pins("object label floor", [
		["each lane measures its own widest name", floors, [long_width, rat_width, 0.0]],
		["a name wider than the column widens it, with the gap after it",
			EventSheetRowRenderer.object_column_width_for(style, "action", 1000.0, long_width), long_width + pad],
		["a short name leaves the column as it was",
			EventSheetRowRenderer.object_column_width_for(style, "condition", 1000.0, rat_width), 96.0],
		["no name measured leaves the column as it was", EventSheetRowRenderer.object_column_width_for(style, "action", 1000.0), 146.0],
		["a lane that is truly short still takes no more than its share",
			EventSheetRowRenderer.object_column_width_for(style, "action", 200.0, long_width), 200.0 * EventSheetRowRenderer.OBJECT_COLUMN_LANE_SHARE],
		["flow mode (no column) is still flow mode", EventSheetRowRenderer.object_column_width_for(_flow(style), "action", 1000.0, long_width), 0.0],
	])


static func _flow(style: EventSheetEventStyle) -> EventSheetEventStyle:
	var flowing: EventSheetEventStyle = style.duplicate() as EventSheetEventStyle
	flowing.action_object_column_width = 0
	return flowing


## A built row holding one span that carries an object name in `lane`.
static func _row_with(lane: String, label: String) -> EventRowData:
	var row: EventRowData = EventRowData.new()
	var span: EventSheetSemanticSpan = EventSheetSemanticSpan.new()
	span.text = "words"
	span.metadata = {"lane": lane, "object_label": label}
	row.spans = [span]
	return row
