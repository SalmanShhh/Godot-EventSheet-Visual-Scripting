# EventSheet - the sticky group breadcrumb: "Gameplay ▸ Combat" pinned under the column header
# while you are scrolled INSIDE those groups, so a 1,000-row sheet never loses you. A DRAW PASS in
# the virtualized viewport, not a Control: it renders at the scroll offset each frame (the
# viewport already redraws on scroll), so appearing and disappearing can never reflow the scroll
# area or jitter at group boundaries. Clicking the strip jumps to the innermost group's bar.
#
# The enclosure map is a single O(rows) pass cached until the viewport rebuilds its flat rows
# (the one _refresh_rows site invalidates it) - per-frame work is a map lookup, never a scan.
# The derivation is static + pure, so the path logic is headless-testable without a viewport.
@tool
class_name ViewportGroupBreadcrumb
extends RefCounted

const STRIP_HEIGHT := 20.0

var _viewport: Control = null
var _map: PackedInt32Array = PackedInt32Array()
var _map_dirty: bool = true
# The click target while the strip is visible (-1 = strip hidden, clicks pass through).
var _jump_index: int = -1


func init(viewport: Control) -> void:
	_viewport = viewport


## The flat rows changed shape (rebuild, fold, filter) - the enclosure map is stale.
func invalidate() -> void:
	_map_dirty = true


## The enclosure map: map[i] = flat index of row i's INNERMOST enclosing group row, -1 at the
## top level. A group row maps to its PARENT group (it does not enclose itself), so the strip
## shows only what has scrolled out of sight when a group bar is the first visible row.
## `rows` is [{group: bool, indent: int}] - static + pure for the tests.
static func enclosing_map(rows: Array) -> PackedInt32Array:
	var map: PackedInt32Array = PackedInt32Array()
	map.resize(rows.size())
	var stack: Array[int] = []
	for i: int in range(rows.size()):
		var entry: Dictionary = rows[i]
		var indent: int = int(entry.get("indent", 0))
		while not stack.is_empty() and int((rows[stack.back()] as Dictionary).get("indent", 0)) >= indent:
			stack.pop_back()
		map[i] = stack.back() if not stack.is_empty() else -1
		if bool(entry.get("group", false)):
			stack.append(i)
	return map


## The breadcrumb chain for a row, OUTERMOST first ([Gameplay, Combat] for a row inside both).
static func chain_for(map: PackedInt32Array, index: int) -> PackedInt32Array:
	var chain: PackedInt32Array = PackedInt32Array()
	if index < 0 or index >= map.size():
		return chain
	var cursor: int = map[index]
	while cursor >= 0:
		chain.insert(0, cursor)
		cursor = map[cursor]
	return chain


## Draws the strip (canvas coordinates - the zoom transform is already active) and arms the
## click target. Called from the viewport's _draw after the rows.
func draw(width: float, font: Font, font_size: int) -> void:
	_jump_index = -1
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var scroll_offset: float = float(_viewport._get_scroll_offset()) / zoom
	if scroll_offset <= 0.0:
		return
	_ensure_map()
	var first_visible: int = _viewport._find_row_index_at_y(scroll_offset + 1.0)
	var chain: PackedInt32Array = chain_for(_map, first_visible)
	if chain.is_empty():
		return
	var titles: PackedStringArray = PackedStringArray()
	for group_index: int in chain:
		var row_data: EventRowData = (_viewport._flat_rows[group_index] as Dictionary).get("row")
		if row_data == null:
			continue
		if row_data.source_resource is EventGroup:
			titles.append(_viewport._group_name(row_data.source_resource as EventGroup))
			continue
		# V12: an Arrange-by header is a group as far as reading goes - it holds events and the
		# reader is inside it - so the breadcrumb names it too, from its own drawn title.
		var header_title: String = header_title_of(row_data)
		if not header_title.is_empty():
			titles.append(header_title)
	if titles.is_empty():
		return
	_jump_index = chain[chain.size() - 1]
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var background: Color = event_style.column_header_background_color
	background.a = 0.97
	_viewport.draw_rect(Rect2(0.0, scroll_offset, width, STRIP_HEIGHT), background, true)
	_viewport.draw_rect(Rect2(0.0, scroll_offset + STRIP_HEIGHT - 1.0, width, 1.0), event_style.lane_divider_color, true)
	var text_size: int = EventSheetPalette.resolve_font_size(font_size, -1)
	var baseline: float = scroll_offset + STRIP_HEIGHT * 0.5 + float(text_size) * 0.32
	_viewport.draw_string(font, Vector2(EventSheetPalette.GUTTER_WIDTH + 8.0, baseline),
		" ▸ ".join(titles), HORIZONTAL_ALIGNMENT_LEFT, width - EventSheetPalette.GUTTER_WIDTH - 16.0,
		text_size, event_style.group_title_color)


## Left-click routing: true (and jumps) when the click lands on the visible strip. `local_position`
## is the event position in the control's own coordinates (zoomed canvas pixels).
func handle_click(local_position: Vector2) -> bool:
	if _jump_index < 0:
		return false
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var scroll_offset: float = float(_viewport._get_scroll_offset())
	if local_position.y < scroll_offset or local_position.y > scroll_offset + STRIP_HEIGHT * zoom:
		return false
	var scroll: ScrollContainer = _viewport._get_scroll_container()
	if scroll == null:
		return false
	scroll.scroll_vertical = maxi(0, int(round(_viewport._row_metrics_helper.row_top(_jump_index) * zoom)))
	return true


func _ensure_map() -> void:
	if not _map_dirty:
		return
	_map_dirty = false
	var shape: Array = []
	for row_info: Dictionary in _viewport._flat_rows:
		var row_data: EventRowData = row_info.get("row")
		shape.append({
			"group": row_data != null and row_data.row_type == EventRowData.RowType.GROUP,
			"indent": row_data.indent if row_data != null else 0,
		})
	_map = enclosing_map(shape)


## The title a synthetic header row (an Arrange-by bucket) reads with: its first drawn span, and
## only when the row genuinely stands for no resource - a real group answers through EventGroup.
static func header_title_of(row_data: EventRowData) -> String:
	if row_data.source_resource != null or row_data.row_type != EventRowData.RowType.GROUP:
		return ""
	if not row_data.row_uid.begins_with("arrange_"):
		return ""
	for span: Variant in row_data.spans:
		var typed: SemanticSpan = span as SemanticSpan
		if typed != null and not str(typed.text).strip_edges().is_empty():
			return str(typed.text).strip_edges()
	return ""
