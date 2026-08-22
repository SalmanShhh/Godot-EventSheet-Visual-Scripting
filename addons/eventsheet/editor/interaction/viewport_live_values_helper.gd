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


## The "now value" chip for a row, or "" (variable rows whose name has a live frame). V12 - "now",
## never "=": the declaration's own value never changes while the game runs, and a second "= 73" on
## the row read as though it had.
func chip_for(row_data: EventRowData) -> String:
	var variable_name: String = ""
	if row_data.source_resource is LocalVariable:
		variable_name = (row_data.source_resource as LocalVariable).name
	elif row_data.row_type != EventRowData.RowType.GROUP and not row_data.spans.is_empty():
		# The name is a FACT on the row, carried in its metadata - never the first span's text, which
		# is a badge or a scope word depending on how the row reads.
		var metadata: Dictionary = row_data.spans[0].metadata if row_data.spans[0].metadata is Dictionary else {}
		variable_name = str(metadata.get("variable_name", "")).strip_edges()
	if variable_name.is_empty() or not _live_values.has(variable_name):
		return ""
	return "now %s" % str(_live_values[variable_name])


## Draws "now value" after a variable row's sentence when a live frame carries its name. Called from
## the viewport's _draw, so draw_string is proxied through _viewport (the owning CanvasItem).
func draw_chip(row_data: EventRowData, row_top: float, row_height: float, font: Font, font_size: int) -> void:
	if _live_values.is_empty() or row_data == null:
		return
	var chip_text: String = chip_for(row_data)
	if chip_text.is_empty():
		return
	var text_width: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	# Straight after the sentence, which is where "now" belongs - the row's right edge is the code
	# echo's, and a live value parked there read as part of the declaration.
	var chip_x: float = minf(
		_sentence_right_edge(row_data) + 10.0,
		_viewport._get_logical_canvas_width() - text_width - 24.0
	)
	var style: Variant = _viewport.get_event_style()
	var chip_color: Color = style.value_highlight_color if style != null else EventSheetPalette.COLOR_VALUE
	_viewport.draw_string(font, Vector2(chip_x, row_top + row_height * 0.5 + font_size * 0.35), chip_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, chip_color)


## Where the row's own words end - the rightmost edge of every span that is not the code echo.
func _sentence_right_edge(row_data: EventRowData) -> float:
	var edge: float = 0.0
	for span: SemanticSpan in row_data.spans:
		if span == null:
			continue
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		if bool(metadata.get("code_echo", false)):
			continue
		edge = maxf(edge, span.rect.end.x)
	return edge
