# A drag moves its drop target many times a second; the layout cache must not throw away every
# visible row's layout each time. Only the row the drop would land on (the row-drag target) and
# the row an ACE drop would land in read the drag state, so only those two carry it in their key:
#   1. A row that is neither target keeps one key across target changes (cache hit).
#   2. The target row's key changes with the target mode, so its drop preview is rebuilt.
#   3. Moving the target relays out the row it reached, and nothing else.
#   4. Whether a drag is live at all still reaches every row (the gap drawn between rows).
@tool
class_name LayoutDragKeyTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const PROBE: String = "probe_marker"


static func run() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.size = Vector2(900.0, 600.0)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = viewport._get_font_size()
	var rows: Array[Dictionary] = []
	for index: int in range(4):
		var row_data: EventRowData = EventRowData.new()
		row_data.row_type = EventRowData.RowType.EVENT
		var span: SemanticSpan = SemanticSpan.new()
		span.text = "Condition %d" % index
		span.metadata = {"kind": "condition", "line_index": 0, "chip": true}
		row_data.spans = [span]
		rows.append({"row": row_data})
	viewport._flat_rows = rows
	viewport._row_metrics_helper.rebuild()
	var width: float = viewport._get_logical_canvas_width()
	var builder: ViewportLayoutBuilder = viewport._layout_builder

	var ok: bool = true
	var idle_key: String = builder.drag_signature_for_row(0)
	viewport._drag_target_index = 2
	viewport._drag_target_mode = "before"
	ok = SUPPORT.check("layout_drag_key_test", "a non-target row keeps its key when the target moves", builder.drag_signature_for_row(0), idle_key) and ok
	ok = SUPPORT.check("layout_drag_key_test", "the target row's key differs from the idle one", builder.drag_signature_for_row(2) != idle_key, true) and ok
	var before_mode: String = builder.drag_signature_for_row(2)
	viewport._drag_target_mode = "after"
	ok = SUPPORT.check("layout_drag_key_test", "the target row's key follows the drop mode", builder.drag_signature_for_row(2) != before_mode, true) and ok

	# Layout reuse: mark each cached layout, move the target, and see which marks survive.
	viewport._drag_target_index = -1
	viewport._drag_target_mode = ""
	for index: int in range(4):
		var layout: Dictionary = builder.get_or_build_row_layout(index, width, font, font_size)
		layout[PROBE] = true
	viewport._drag_target_index = 2
	viewport._drag_target_mode = "before"
	var survived: Array = []
	for index: int in range(4):
		var layout: Dictionary = builder.get_or_build_row_layout(index, width, font, font_size)
		survived.append(layout.has(PROBE))
	ok = SUPPORT.check("layout_drag_key_test", "only the new target row relaid out", survived, [true, true, false, true]) and ok
	for index: int in range(4):
		builder.get_or_build_row_layout(index, width, font, font_size)[PROBE] = true
	viewport._drag_target_index = 1
	survived.clear()
	for index: int in range(4):
		survived.append(builder.get_or_build_row_layout(index, width, font, font_size).has(PROBE))
	ok = SUPPORT.check("layout_drag_key_test", "moving the target rebuilds the row it reached and the row it left goes back to its idle layout", survived, [true, false, true, true]) and ok

	# An ACE drop target is a row too.
	viewport._drag_target_index = -1
	viewport._drag_ace_target_row_index = 3
	ok = SUPPORT.check("layout_drag_key_test", "the ACE drop row carries the drag signature", builder.drag_signature_for_row(3) != builder.drag_signature_for_row(0), true) and ok

	# A live drag changes every row's key (the gap between rows).
	viewport._drag_ace_target_row_index = -1
	var idle: String = builder.drag_signature_for_row(0)
	viewport._drag_motion.active = true
	ok = SUPPORT.check("layout_drag_key_test", "a live drag reaches every row's key", builder.drag_signature_for_row(0) != idle, true) and ok

	viewport.free()
	return ok
