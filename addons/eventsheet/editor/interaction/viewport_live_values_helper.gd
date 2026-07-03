@tool
class_name ViewportLiveValuesHelper
extends RefCounted
# The streamed-debug "= value" chips drawn next to variable / group rows during a debug run.
# Extracted from event_sheet_viewport.gd to keep that file maintainable. This subsystem is stateful
# (it holds the live frame), so unlike the stateless hit-test / selection helpers it keeps a
# back-reference to the viewport: queue_redraw, the canvas width, and the event style are read through
# it, and the per-frame draw is proxied via `_viewport.draw_string` because `CanvasItem.draw_*` only
# works inside the owning node's `_draw` (which is exactly where `draw_chip` is called from).

var _viewport: Control = null
var _live_values: Dictionary = {}


func init(viewport: Control) -> void:
	_viewport = viewport


## Streamed name->value frame (debug runs). Redraws value chips on variable rows.
func set_live_values(values: Dictionary) -> void:
	_live_values = values
	_viewport.queue_redraw()


## The "= value" chip for a row, or "" (variable rows whose name has a live frame).
func chip_for(row_data: EventRowData) -> String:
	var variable_name: String = ""
	if row_data.source_resource is LocalVariable:
		variable_name = (row_data.source_resource as LocalVariable).name
	elif row_data.row_type != EventRowData.RowType.GROUP and not row_data.spans.is_empty():
		# Group headers expose their name as spans[0] (the "Group" badge that used to shield it is
		# gone), but a group is organizational, not a variable - never read its name as a live value.
		var first_word: String = str(row_data.spans[0].text).get_slice(":", 0).strip_edges()
		if _live_values.has(first_word):
			variable_name = first_word
	if variable_name.is_empty() or not _live_values.has(variable_name):
		return ""
	return "= %s" % str(_live_values[variable_name])


## Draws "= value" after a variable row's text when a live frame carries its name. Called from the
## viewport's _draw, so draw_string is proxied through _viewport (the owning CanvasItem).
func draw_chip(row_data: EventRowData, row_top: float, row_height: float, font: Font, font_size: int) -> void:
	if _live_values.is_empty() or row_data == null:
		return
	var chip_text: String = chip_for(row_data)
	if chip_text.is_empty():
		return
	var text_width: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var chip_x: float = _viewport._get_logical_canvas_width() - text_width - 24.0
	var style: Variant = _viewport.get_event_style()
	var chip_color: Color = style.value_highlight_color if style != null else EventSheetPalette.COLOR_VALUE
	_viewport.draw_string(font, Vector2(chip_x, row_top + row_height * 0.5 + font_size * 0.35), chip_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, chip_color)
