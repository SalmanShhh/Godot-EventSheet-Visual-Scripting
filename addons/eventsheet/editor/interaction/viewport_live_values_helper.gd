@tool
class_name ViewportLiveValuesHelper
extends RefCounted
# The streamed-debug "= value" chips drawn next to variable / group rows during a debug run.
# Extracted from event_sheet_viewport.gd to keep that file maintainable. This subsystem is stateful
# (it holds the live frame), so unlike the stateless hit-test / selection helpers it keeps a
# back-reference to the viewport: queue_redraw, the canvas width, and the event style are read through
# it, and the per-frame draw is proxied via `_viewport.draw_string` because `CanvasItem.draw_*` only
# works inside the owning node's `_draw` (which is exactly where `draw_chip` is called from).

## The metadata key the row builder writes the timed row's own wait onto - the `seconds` its Is in X
## for over Ns cell was given, when that is a plain number. Named here because this file is the only
## reader of it, and an expression in that field writes nothing, so a row whose wait is computed
## simply shows no progress rather than a number the editor made up.
const STATE_PROGRESS_META: String = "state_for_over_seconds"

var _viewport: Control = null
## One frame per running copy of the game, keyed by the feature tag it was started with - "" for
## a lone run, which is every game not being tested as two players at once. Insertion order is the
## order the instances first streamed, so the chips stay in one order across frames.
var _live_values: Dictionary = {}


func init(viewport: Control) -> void:
	_viewport = viewport


## Streamed name->value frame (debug runs). Redraws value chips on variable rows. A lone run and a
## labelled one never mix: a frame with no label replaces every labelled one and the other way
## round, so a second run cannot leave a chip naming a window from the first.
func set_live_values(values: Dictionary, instance: String = "") -> void:
	var keys: Array = _live_values.keys()
	var was_labelled: bool = not keys.is_empty() and not str(keys[0]).is_empty()
	if was_labelled != (not instance.is_empty()):
		_live_values.clear()
	_live_values[instance] = values
	_viewport.queue_redraw()


## The run ended - the last frame stops counting as live.
func clear_live_values() -> void:
	_live_values.clear()
	if _viewport != null:
		_viewport.queue_redraw()


## The "now value" chip for a row, or "" (variable rows whose name has a live frame). "now",
## never "=": the declaration's own value never changes while the game runs, and a second "= 73" on
## the row read as though it had. With two copies of the game running there is one chip per
## instance, each headed by the tag that copy was started with.
func chip_for(row_data: EventRowData) -> String:
	# The states band is the one head band with a live half: while the game runs it carries what state
	# the object is in and how long it has held. Drawn as a chip for the same reason a variable's
	# "now" is - the band's own words are the LINE of the file it stands for, and a reading that
	# changes four times a second is not that line. Nothing is written: stop the game and the band is
	# the declaration again.
	if is_states_band(row_data):
		return EventSheetStateWatch.band_reading()
	var variable_name: String = ""
	if row_data.source_resource is LocalVariable:
		variable_name = (row_data.source_resource as LocalVariable).name
	elif row_data.row_type != EventRowData.RowType.GROUP and not row_data.spans.is_empty():
		# The name is a FACT on the row, carried in its metadata - never the first span's text, which
		# is a badge or a scope word depending on how the row reads.
		var metadata: Dictionary = row_data.spans[0].metadata if row_data.spans[0].metadata is Dictionary else {}
		variable_name = str(metadata.get("variable_name", "")).strip_edges()
	return chip_text(_live_values, variable_name)


## The chips one variable's row wears, side by side: "now 100" on its own for a lone run,
## "host · now 100   client · now 90" while two copies stream. Static + pure, so the words are
## pinned without a canvas.
static func chip_text(frames: Dictionary, variable_name: String) -> String:
	if variable_name.is_empty():
		return ""
	var chips: PackedStringArray = PackedStringArray()
	for instance: Variant in frames:
		var values: Dictionary = frames[instance] if frames[instance] is Dictionary else {}
		if not values.has(variable_name):
			continue
		var now: String = "now %s" % str(values[variable_name])
		chips.append(now if str(instance).is_empty() else "%s · %s" % [str(instance), now])
	return "   ".join(chips)


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


## True when this row IS the sheet head's states band. Asked of the band's own metadata rather than
## of its uid, because the metadata is the fact and the uid is a string somebody could reshape.
## Static + pure, so the rule is pinned headless.
static func is_states_band(row_data: EventRowData) -> bool:
	if row_data == null:
		return false
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		if str((span.metadata as Dictionary).get("head_band", "")) == EventSheetHeadBands.BAND_STATES:
			return true
	return false


## The timed condition's progress, drawn IN PLACE: "3.2 of 6" straight after the Is in X for over Ns
## cell, which is where the question it answers is asked. The row builder wrote the row's own target
## into the cell's metadata, so nothing is parsed in the draw loop; the held half is the number the
## running game last reported. A row with no running game gets nothing at all, which is the row
## exactly as it reads with the game closed.
func draw_state_progress(row_data: EventRowData, row_top: float, row_height: float, font: Font,
		font_size: int) -> void:
	if _live_values.is_empty() or row_data == null or not EventSheetStateWatch.is_live():
		return
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata
		if not metadata.has(STATE_PROGRESS_META):
			continue
		var progress: String = EventSheetStateWatch.progress_reading(float(metadata[STATE_PROGRESS_META]))
		if progress.is_empty():
			continue
		var style: Variant = _viewport.get_event_style()
		var chip_color: Color = style.value_highlight_color if style != null else EventSheetPalette.COLOR_VALUE
		# Clamped to the canvas, exactly as the "now" chip above is. There is no horizontal scroll
		# here, so a reading drawn past the right edge is not a reading a reader can go and find - it
		# is one that silently is not there, and a long cell in a narrow dock is enough to do it.
		var text_width: float = font.get_string_size(progress, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			font_size).x
		var progress_x: float = minf(span.rect.end.x + 8.0,
			_viewport._get_logical_canvas_width() - text_width - 24.0)
		_viewport.draw_string(font, Vector2(progress_x,
			row_top + row_height * 0.5 + font_size * 0.35), progress,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, chip_color)
		return


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
