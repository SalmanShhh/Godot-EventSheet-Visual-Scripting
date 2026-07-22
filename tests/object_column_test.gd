# EventForge - the C3-style object column (a draggable sub-lane between object names and display
# text, per lane). Pins the ONE resolver (object_column_width_for) and that the two geometry
# twins - span width measurement and the text-origin used by hit-testing - advance by the fixed
# column width when set and by the label's own width in flow mode (0), so draw, measure, and
# hit-test can never disagree. Also pins the boundary hit used to start the drag.
@tool
class_name ObjectColumnTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- the resolver: per-lane token, 0 = flow, non-lanes never column ----
	var event_style: EventSheetEventStyle = EventSheetEventStyle.new()
	# The column is ALIGNED by default (the Construct look): every row's text starts at the same x, so
	# the sheet scans as a table instead of each row starting wherever its own object name happens to
	# end. Flow mode is still reachable by setting the token to 0.
	ok = _check(ok, EventRowRenderer.object_column_width_for(event_style, "condition") == 130.0, "condition lane is aligned by default")
	ok = _check(ok, EventRowRenderer.object_column_width_for(event_style, "action") == 130.0, "action lane is aligned by default")
	event_style.condition_object_column_width = 0
	ok = _check(ok, EventRowRenderer.object_column_width_for(event_style, "condition") == 0.0, "0 still means flow mode")
	event_style.condition_object_column_width = 120
	event_style.action_object_column_width = 90
	ok = _check(ok, EventRowRenderer.object_column_width_for(event_style, "condition") == 120.0, "condition column reads its token")
	ok = _check(ok, EventRowRenderer.object_column_width_for(event_style, "action") == 90.0, "action column reads its token")
	ok = _check(ok, EventRowRenderer.object_column_width_for(event_style, "keyword") == 0.0, "non-ACE lanes never column")
	ok = _check(ok, EventRowRenderer.object_column_width_for(null, "condition") == 0.0, "null style is flow (headless safety)")

	# ---- measure + text origin agree, fixed column vs flow ----
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var guard: ACECondition = ACECondition.new()
	guard.provider_id = "Core"
	guard.ace_id = "ExpressionIsTrue"
	guard.params = {"expr": "health > 0"}
	row.conditions.append(guard)
	sheet.events.append(row)
	viewport.set_sheet(sheet)

	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	viewport.apply_editor_style(style)
	var live_style: EventSheetEventStyle = viewport._get_event_style()

	var span: SemanticSpan = _condition_span(viewport)
	ok = _check(ok, span != null, "a condition span with an object label exists")
	if span == null:
		return false
	var font: Font = viewport._get_font()
	var font_size: int = viewport._get_font_size()
	var metadata: Dictionary = span.metadata as Dictionary
	var display_text: String = span.text

	live_style.condition_object_column_width = 0
	var flow_width: float = viewport._measure_span_width(span, display_text, font, font_size)
	var flow_origin: float = viewport._span_text_origin_x(span, font, font_size)
	live_style.condition_object_column_width = 150
	var fixed_width: float = viewport._measure_span_width(span, display_text, font, font_size)
	var fixed_origin: float = viewport._span_text_origin_x(span, font, font_size)
	# The EFFECTIVE column, not the raw token: a column is bounded by the room its lane actually has,
	# so a themed 150 on a narrow canvas resolves to less. Draw, measure and hit-test must all use this
	# same bounded number - that agreement is what this test exists to protect.
	var effective_column: float = EventRowRenderer.object_column_width_for(
		live_style, "condition", viewport.lane_width_for("condition"))
	ok = _check(ok, effective_column <= 150.0 and effective_column > 0.0,
		"the effective column is the token bounded by its lane (%.1f)" % effective_column)

	var label: String = str(metadata.get("object_label", ""))
	var label_advance: float = font.get_string_size(label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	ok = _check(ok, absf((fixed_width - flow_width) - (effective_column - label_advance)) < 0.5, "measure swaps label advance for the column width (delta %.1f vs %.1f)" % [fixed_width - flow_width, effective_column - label_advance])
	ok = _check(ok, absf((fixed_origin - flow_origin) - (effective_column - label_advance)) < 0.5, "text origin swaps identically (delta %.1f)" % (fixed_origin - flow_origin))
	# The bound must never let the column push the display text past the lane divider - the failure the
	# clamp exists to stop. Pinned as a VALUE relationship, not a count.
	ok = _check(ok, fixed_origin < viewport.get_lane_divider_x(viewport._get_logical_canvas_width()),
		"the column never pushes condition text past the lane divider")
	ok = _check(ok, absf((fixed_width - fixed_origin) - (flow_width - flow_origin)) < 0.5, "display text keeps its full width either way (stays fully visible)")

	# ---- the drag-start boundary: flow mode grabs after the label, fixed grabs the column edge ----
	viewport.get_row_layout_for_test(0, 900.0)  # position spans so rects are real
	var anchor_x: float = span.rect.position.x
	# Chip spans draw from rect.x + padding_x (review fix): the grab zone follows the DRAWN
	# boundary, so the expected anchor mirrors the renderer's padding too.
	if bool(metadata.get("chip", false)):
		anchor_x += float(metadata.get("padding_x", 0.0))
	if metadata.get("object_icon") is Texture2D:
		anchor_x += EventRowRenderer.OBJECT_ICON_ADVANCE
	var boundary: Dictionary = viewport.object_column_boundary_hit(Vector2(anchor_x + effective_column, span.rect.position.y + span.rect.size.y * 0.5))
	ok = _check(ok, str(boundary.get("lane", "")) == "condition", "the column edge is grabbable (got %s)" % str(boundary))
	ok = _check(ok, absf(float(boundary.get("anchor_x", -1.0)) - anchor_x) < 0.5, "the drag anchor is the column start")
	var miss: Dictionary = viewport.object_column_boundary_hit(Vector2(anchor_x + 320.0, span.rect.position.y + span.rect.size.y * 0.5))
	ok = _check(ok, miss.is_empty(), "far from the boundary is not grabbable")

	viewport.free()

	# ---- the View ▾ "Aligned Object Columns" toggle: flips BOTH lanes, and back ----
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	ok = _check(ok, dock._object_columns_aligned(), "a fresh sheet reports its columns aligned")
	dock._toggle_object_column_alignment(null)
	var flowed: EventSheetEventStyle = dock._active_view()._get_event_style()
	ok = _check(ok, not dock._object_columns_aligned(), "the toggle switches to flow")
	ok = _check(ok, flowed.condition_object_column_width == 0 and flowed.action_object_column_width == 0,
		"flow clears BOTH lanes (they move together)")
	dock._toggle_object_column_alignment(null)
	var realigned: EventSheetEventStyle = dock._active_view()._get_event_style()
	ok = _check(ok, dock._object_columns_aligned(), "toggling back re-aligns")
	ok = _check(ok, realigned.condition_object_column_width == EventSheetPalette.OBJECT_COLUMN_WIDTH
		and realigned.action_object_column_width == EventSheetPalette.OBJECT_COLUMN_WIDTH,
		"re-aligning restores the shared default width on both lanes")
	dock.free()
	return ok


## The first condition-lane span carrying an object label (the trigger chip qualifies).
static func _condition_span(viewport: EventSheetViewport) -> SemanticSpan:
	var row_data: EventRowData = viewport._row_at(0)
	if row_data == null:
		return null
	viewport.get_row_layout_for_test(0, 900.0)
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		if str(metadata.get("lane", "")) == "condition" and not str(metadata.get("object_label", "")).is_empty():
			return span
	return null


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
