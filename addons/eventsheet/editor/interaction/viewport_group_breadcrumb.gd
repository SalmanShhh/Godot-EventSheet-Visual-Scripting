# EventSheet - the PINNED GROUP HEAD: while you are scrolled inside a group, its own head stays at
# the top of the canvas, so the thing that pins is the thing you can act on. Same parts as the head
# itself - the parent trail, the title, the description, what the group holds and its switch - read
# straight off the head ROW, so the pinned copy can never drift from the row it stands for. The
# parent chain shortens to the last two names; the full chain is the hover.
#
# A DRAW PASS in the virtualized viewport, not a Control: it renders at the scroll offset each frame
# (the viewport already redraws on scroll), so appearing and disappearing can never reflow the
# scroll area or jitter at group boundaries.
#
# Four click zones: the fold arrow folds the group (and scrolls to its real head, so you never fall
# into the next group by surprise), each PARENT NAME in the trail scrolls to that head, the switch at
# the right turns the group on and off, and anything else opens Edit group. A crumb is a door because
# the name of the thing you are inside is exactly what a reader reaches for to get back out of it.
# The enclosure map is a single O(rows) pass cached until the viewport rebuilds its
# flat rows (the one _refresh_rows site invalidates it) - per-frame work is a map lookup, never a
# scan. The derivations are static + pure, so the path logic is headless-testable without a
# viewport.
@tool
class_name ViewportGroupBreadcrumb
extends RefCounted

const STRIP_HEIGHT := 24.0

## How wide the fold zone at the left of the strip is, and the switch zone at its right.
const FOLD_ZONE_WIDTH := 26.0
const SWITCH_ZONE_WIDTH := 26.0

var _viewport: Control = null
var _map: PackedInt32Array = PackedInt32Array()
var _map_dirty: bool = true
# The pinned head's flat index while the strip is visible (-1 = strip hidden, clicks pass through).
var _jump_index: int = -1
# The full parent chain of the pinned head, for the hover - the strip only shows the last two.
var _full_chain: String = ""
# G5 - one click zone per drawn parent name: [{"x", "width", "index"}] in canvas x, `index` the flat
# row of the head that name stands for. Rebuilt by every draw, so it can never point at a stale row.
var _crumb_zones: Array[Dictionary] = []


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


## Draws the pinned head (canvas coordinates - the zoom transform is already active) and arms the
## click zones. Called from the viewport's _draw after the rows.
func draw(width: float, font: Font, font_size: int) -> void:
	_jump_index = -1
	_full_chain = ""
	_crumb_zones.clear()
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
	# The flat row each title stands for, kept beside it: a chain row that names nothing is skipped,
	# so titles[i] and chain[i] part company the moment one is - and a crumb whose zone points at the
	# wrong head is worse than no crumb at all.
	var title_rows: PackedInt32Array = PackedInt32Array()
	for group_index: int in chain:
		var chain_row: EventRowData = (_viewport._flat_rows[group_index] as Dictionary).get("row")
		if chain_row == null:
			continue
		if chain_row.source_resource is EventGroup:
			titles.append(EventSheetGroupFacts.display_name(chain_row.source_resource as EventGroup))
			title_rows.append(group_index)
			continue
		# V12: an Arrange-by header is a group as far as reading goes - it holds events and the
		# reader is inside it - so the pinned head names it too, from its own drawn title.
		var header_title: String = header_title_of(chain_row)
		if not header_title.is_empty():
			titles.append(header_title)
			title_rows.append(group_index)
	if titles.is_empty():
		return
	_jump_index = chain[chain.size() - 1]
	var head_row: EventRowData = (_viewport._flat_rows[_jump_index] as Dictionary).get("row")
	var trail: Dictionary = EventSheetGroupFacts.pinned_trail(titles)
	_full_chain = str(trail.get("full", ""))
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	var background: Color = event_style.column_header_background_color
	background.a = 0.97
	_viewport.draw_rect(Rect2(0.0, scroll_offset, width, STRIP_HEIGHT), background, true)
	_viewport.draw_rect(Rect2(0.0, scroll_offset + STRIP_HEIGHT - 1.0, width, 1.0), event_style.lane_divider_color, true)
	var text_size: int = EventSheetPalette.resolve_font_size(font_size, -1)
	var baseline: float = scroll_offset + STRIP_HEIGHT * 0.5 + float(text_size) * 0.32
	var cursor: float = FOLD_ZONE_WIDTH
	_viewport.draw_string(font, Vector2(cursor - 14.0, baseline),
		"▸" if head_row != null and head_row.folded else "▾",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, reading_style.muted_text_color)
	# G5 - the parent names are drawn one at a time rather than as one joined string, so each can
	# arm its own click zone. The separators are drawn between them, and belong to neither.
	var crumbs: Array = trail.get("crumbs", []) as Array
	var crumb_widths: PackedFloat32Array = PackedFloat32Array()
	for crumb: Dictionary in crumbs:
		crumb_widths.append(font.get_string_size(
			str(crumb.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size).x)
	var separator_width: float = font.get_string_size(
		EventSheetGroupFacts.CRUMB_SEPARATOR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size).x
	_crumb_zones = crumb_zones(crumbs, title_rows, cursor, crumb_widths, separator_width)
	for index: int in range(crumbs.size()):
		_viewport.draw_string(font, Vector2(cursor, baseline), str((crumbs[index] as Dictionary).get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, reading_style.muted_text_color)
		cursor += crumb_widths[index]
		_viewport.draw_string(font, Vector2(cursor, baseline), EventSheetGroupFacts.CRUMB_SEPARATOR,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, reading_style.muted_text_color)
		cursor += separator_width
	if not crumbs.is_empty():
		cursor += 2.0
	var title: String = str(trail.get("title", ""))
	_viewport.draw_string(font, Vector2(cursor, baseline), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, event_style.group_title_color)
	cursor += font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size).x + 8.0
	# The rest of the head, taken from the head ROW itself so the pinned copy is the same reading:
	# the description beside the name, then what the group holds and its switch at the right edge.
	var parts: Dictionary = head_parts(head_row)
	var description: String = str(parts.get("description", ""))
	var right_edge: float = width - EventSheetPalette.ROW_HORIZONTAL_PADDING
	var switch_glyph: String = str(parts.get("switch", ""))
	if not switch_glyph.is_empty():
		right_edge -= SWITCH_ZONE_WIDTH
		_viewport.draw_string(font, Vector2(right_edge + 6.0, baseline), switch_glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size,
			reading_style.primary_text_color if bool(parts.get("enabled", true)) else reading_style.muted_text_color)
	var counts: String = str(parts.get("counts", ""))
	if not counts.is_empty():
		var counts_width: float = font.get_string_size(counts, HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size).x
		right_edge -= counts_width + 8.0
		_viewport.draw_string(font, Vector2(right_edge, baseline), counts,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, reading_style.muted_text_color)
	if not description.is_empty() and right_edge - cursor > 40.0:
		_viewport.draw_string(font, Vector2(cursor, baseline), description,
			HORIZONTAL_ALIGNMENT_LEFT, right_edge - cursor - 8.0, text_size, event_style.comment_text_color)


## The parts of a group head the pinned copy re-draws, read off the head row's own spans by their
## METADATA, never by position: whatever the row builder puts there is what pins. Static + pure.
static func head_parts(head_row: EventRowData) -> Dictionary:
	var parts := {"description": "", "counts": "", "switch": "", "enabled": true}
	if head_row == null:
		return parts
	for span: SemanticSpan in head_row.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		if str(metadata.get("edit_kind", "")) == "group_description":
			parts["description"] = span.text
		elif bool(metadata.get("group_counts", false)):
			parts["counts"] = span.text
		elif str(metadata.get("group_action", "")) == "enabled":
			parts["switch"] = span.text
			parts["enabled"] = not head_row.disabled
	return parts


## The pinned head's group, or null when the strip is hidden (or pins an Arrange-by header, which is
## a reading rather than a resource).
func pinned_group() -> EventGroup:
	if _jump_index < 0 or _jump_index >= _viewport._flat_rows.size():
		return null
	var head_row: EventRowData = (_viewport._flat_rows[_jump_index] as Dictionary).get("row")
	return head_row.source_resource as EventGroup if head_row != null else null


## The full parent chain, for the strip's hover ("" while the strip is hidden).
func full_chain() -> String:
	return _full_chain


## True when `local_position` (control coordinates) is inside the visible strip.
func covers(local_position: Vector2) -> bool:
	if _jump_index < 0:
		return false
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var scroll_offset: float = float(_viewport._get_scroll_offset())
	return local_position.y >= scroll_offset and local_position.y <= scroll_offset + STRIP_HEIGHT * zoom


## Left-click routing: true (and acts) when the click lands on the visible strip. `local_position`
## is the event position in the control's own coordinates (zoomed canvas pixels). The fold arrow
## folds, the switch at the right turns the group on and off, and anything between opens Edit group.
func handle_click(local_position: Vector2) -> bool:
	if not covers(local_position):
		return false
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var group: EventGroup = pinned_group()
	var canvas_x: float = local_position.x / zoom
	var width: float = _viewport._get_logical_canvas_width()
	if canvas_x <= FOLD_ZONE_WIDTH:
		_viewport._toggle_row_fold(_jump_index)
		_scroll_to_row(_jump_index, zoom)
		return true
	# G5 - a parent name is a door back out to that group: clicking it scrolls to its own head,
	# which is the row the reader wanted when they read the name.
	var crumb_row: int = crumb_at(_crumb_zones, canvas_x)
	if crumb_row >= 0:
		_scroll_to_row(crumb_row, zoom)
		return true
	if group != null and canvas_x >= width - EventSheetPalette.ROW_HORIZONTAL_PADDING - SWITCH_ZONE_WIDTH:
		_viewport.group_action_requested.emit("enabled", group)
		return true
	if group != null:
		_viewport.group_edit_requested.emit(group)
		return true
	_scroll_to_row(_jump_index, zoom)
	return true


## G5. Where each parent name lands on the strip, given the widths the font measured for them:
## [{"x", "width", "index"}] in canvas x, one per crumb that stands for a row. The elision names no
## group, so it arms nothing. Pure + static, so the geometry is pinned without a canvas.
static func crumb_zones(crumbs: Array, title_rows: PackedInt32Array, start_x: float,
		widths: PackedFloat32Array, separator_width: float) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	var cursor: float = start_x
	for index: int in range(crumbs.size()):
		var crumb_width: float = widths[index] if index < widths.size() else 0.0
		var title_index: int = int((crumbs[index] as Dictionary).get("index", -1))
		if title_index >= 0 and title_index < title_rows.size():
			zones.append({"x": cursor, "width": crumb_width, "index": title_rows[title_index]})
		cursor += crumb_width + separator_width
	return zones


## The flat row the parent name under `canvas_x` stands for, or -1 where no crumb is drawn there.
static func crumb_at(zones: Array[Dictionary], canvas_x: float) -> int:
	for zone: Dictionary in zones:
		var left: float = float(zone.get("x", 0.0))
		if canvas_x >= left and canvas_x <= left + float(zone.get("width", 0.0)):
			return int(zone.get("index", -1))
	return -1


func _scroll_to_row(row_index: int, zoom: float) -> void:
	var scroll: ScrollContainer = _viewport._get_scroll_container()
	if scroll == null:
		return
	scroll.scroll_vertical = maxi(0, int(round(_viewport._row_metrics_helper.row_top(row_index) * zoom)))


func _ensure_map() -> void:
	if not _map_dirty:
		return
	_map_dirty = false
	var shape: Array = []
	for row_info: Dictionary in _viewport._flat_rows:
		var row_data: EventRowData = row_info.get("row")
		shape.append({
			"group": row_data != null and row_data.row_type in [
				EventRowData.RowType.GROUP, EventRowData.RowType.REGION
			],
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
