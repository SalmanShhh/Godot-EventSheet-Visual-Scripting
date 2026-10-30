@tool
class_name ViewportDragMotion
extends RefCounted
# A DRAG YOU CAN SEE: what the sheet looks like while a row, an event or a cell is carried.
#
#   - The thing pressed LIFTS: the ghost is the real row drawn by the sheet's own renderer, tilted a
#     little with a shadow under it, and several carried things stack with their count on the top one.
#   - Where it would land, the target lane opens a dashed GAP the height of what is carried, and the
#     rows round it slide apart (SLIDE_MSEC, eased). Moving on closes that gap and opens the next.
#   - Once the pointer leaves the place the thing came from, that place FOLDS away, so the sheet
#     already looks as it will after the drop.
#   - Esc closes every gap and unfolds the source: everything slides back home.
#   - Reduced Motion snaps every gap and fold to its end at once; the ghost and the gap stay.
#
# The motion is paint and hit-testing only. Nothing here touches the sheet: the drop itself is the
# same signal it always was. The rows keep their laid-out places; while a drag is in hand the canvas
# draws each row moved by `row_offset()`, a lane with a gap draws its later cells moved down by the
# gap, and the pointer is mapped back through the same numbers (`to_logical`) before the drop target
# is asked for - so the target is always read off the sheet as it is drawn, gap and fold included,
# and a gap that opens under the pointer never sends the target somewhere else.
#
# Owned by the viewport (one per view), driven from its input handler, its _process and its _draw.

## How long a gap takes to open or close, and a fold to fold.
const SLIDE_MSEC: float = 160.0
## The ghost's tilt, the faint copy left where the carried thing was, and the most a gap opens.
const GHOST_TILT_DEGREES: float = -1.0
const LIFTED_ALPHA: float = 0.35
const MAX_GAP: float = 240.0
## How far the pointer travels from the press before the thing lifts.
const LIFT_DISTANCE: float = 4.0
## The most rows of a carried event the ghost shows.
const GHOST_ROWS: int = 3
## The dash and the corner of the gap's outline.
const GAP_DASH: float = 5.0

var _viewport: Control = null

## True from the lift until the drop, or until an Esc has slid everything back.
var active: bool = false
## "rows" (a row, an event and everything under it, several selected rows) or "cells".
var kind: String = ""
## The carried rows as flat index ranges [[first, last], ...], each an event with its whole subtree.
var _source_blocks: Array = []
## The carried cell(s): {"row", "lane", "top", "bottom", "spans": [span indices]} - {} for rows.
var _source_cell: Dictionary = {}
## How tall the gap opens: the height of what is carried.
var carried_height: float = 0.0
## How many things are carried (the count on the stack).
var carried_count: int = 1
## The pointer's offset into the ghost at the lift, in logical pixels.
var _grab: Vector2 = Vector2.ZERO
var _press: Vector2 = Vector2.ZERO
## True once the pointer has left the place the carried thing came from.
var left_source: bool = false
## True while Esc's slide home plays.
var cancelling: bool = false
## Why the pointer's place cannot take the carried thing ("Conditions go on the left"), "" otherwise.
var refusal: String = ""

## Every gap that is open or closing: key -> {"kind": "row"|"lane", "slot", "row", "lane", "y", "indent"}.
var _gaps: Dictionary = {}
## The key of the gap the pointer asks for now, "" when none.
var _target_key: String = ""
## Animated values: key -> {"from", "to", "start"}. Gap keys, and "fold".
var _tweens: Dictionary = {}
## The last pointer read back onto the rows, for facts(): {"at", "position", "row", "in_gap"}.
var _last_mapped: Dictionary = {}

var _ghost: Control = null
var _ghost_content: Control = null


func init(viewport: Control) -> void:
	_viewport = viewport


## Notes where the press was, so the lift can wait until the pointer has really moved.
func press(at: Vector2) -> void:
	_press = at


## True once the pointer has travelled far enough from the press for a held press to be a drag.
func moved_enough(at: Vector2) -> bool:
	return at.distance_to(_press) >= LIFT_DISTANCE


## Lifts carried rows: `indices` are the flat rows the drag carries (their subtrees come along).
func lift_rows(indices: Array, at: Vector2) -> void:
	_reset()
	kind = "rows"
	var blocks: Array = []
	var sorted: Array = indices.duplicate()
	sorted.sort()
	# Each carried row brings its subtree; a row already inside a carried subtree is not counted again,
	# so a selected event with its selected children is ONE thing on the stack.
	var roots: int = 0
	for index: Variant in sorted:
		var first: int = int(index)
		var last: int = subtree_last(first)
		if blocks.is_empty() or first > int(blocks[-1][1]):
			roots += 1
		if not blocks.is_empty() and first <= int(blocks[-1][1]) + 1:
			blocks[-1][1] = maxi(int(blocks[-1][1]), last)
			continue
		blocks.append([first, last])
	_source_blocks = blocks
	carried_count = maxi(roots, 1)
	var height: float = 0.0
	for block: Variant in blocks:
		height += _band_height(int(block[0]), int(block[1]))
	carried_height = minf(height, MAX_GAP)
	var lead: int = int(blocks[0][0]) if not blocks.is_empty() else 0
	_grab = at - Vector2(0.0, _metrics().row_top(lead))
	active = true
	_tweens["fold"] = {"from": 0.0, "to": 0.0, "start": 0}
	_show_ghost()


## Lifts carried cells: the spans `span_indices` of row `row_index`, in `lane`.
func lift_cells(row_index: int, lane: String, span_indices: Array, count: int, at: Vector2) -> void:
	_reset()
	kind = "cells"
	var row_data: EventRowData = _viewport._row_at(row_index)
	if row_data == null:
		return
	var top: float = INF
	var bottom: float = -INF
	var line_left: float = INF
	for span_index: Variant in span_indices:
		var span: SemanticSpan = row_data.spans[int(span_index)]
		top = minf(top, span.rect.position.y)
		bottom = maxf(bottom, span.rect.end.y)
		line_left = minf(line_left, span.rect.position.x)
	if top == INF:
		return
	_source_cell = {"row": row_index, "lane": lane, "top": top, "bottom": bottom, "spans": span_indices.duplicate()}
	carried_count = count
	carried_height = minf((bottom - top) + _line_gap(), MAX_GAP)
	_grab = at - Vector2(_lane_rect(row_index, lane).position.x, top)
	active = true
	_tweens["fold"] = {"from": 0.0, "to": 0.0, "start": 0}
	_show_ghost()


## The drop happened, or the drag ended without one: everything goes back to the sheet as laid out.
## Esc's slide home is left to play out; it ends the motion itself.
func finish() -> void:
	if cancelling:
		return
	_reset()


## Esc: every gap closes and the source unfolds, sliding; the ghost goes at once.
func cancel() -> void:
	if not active:
		return
	cancelling = true
	refusal = ""
	_target_key = ""
	for key: String in _gaps.keys():
		_retarget(key, 0.0)
	_retarget("fold", 0.0)
	_hide_ghost()
	if not is_animating():
		_reset()


func _reset() -> void:
	active = false
	cancelling = false
	kind = ""
	_source_blocks = []
	_source_cell = {}
	carried_height = 0.0
	carried_count = 1
	left_source = false
	refusal = ""
	_gaps.clear()
	_target_key = ""
	_tweens.clear()
	_hide_ghost()


## The pointer moved to `at` (logical): the ghost follows it, and leaving the source starts its fold.
func pointer_moved(at: Vector2) -> void:
	if not active or cancelling:
		return
	if not left_source and not _over_source(at):
		left_source = true
		_retarget("fold", _fold_size())
	_place_ghost(at)


## Opens the gap for a ROW drop: `slot` is the flat index the carried rows would be inserted before
## (the row count for the very end), drawn at `indent`. -1 closes every gap.
func target_row_slot(slot: int, indent: int) -> void:
	if not active or cancelling:
		return
	refusal = ""
	if slot < 0 or _slot_is_source(slot):
		_open("")
		return
	var key: String = "row:%d:%d" % [slot, indent]
	if not _gaps.has(key):
		_gaps[key] = {"kind": "row", "slot": slot, "indent": indent}
	_open(key)


## Opens the gap for a CELL drop: in row `row_index`'s `lane`, at logical height `y` (the top edge of
## the cell it goes before, or the bottom edge of the one it goes after). An empty lane closes every gap.
func target_lane(row_index: int, lane: String, y: float) -> void:
	if not active or cancelling:
		return
	refusal = ""
	if row_index < 0 or lane.is_empty():
		_open("")
		return
	# Back where it came from is no move at all.
	if not left_source and row_index == int(_source_cell.get("row", -1)) and lane == str(_source_cell.get("lane", "")):
		_open("")
		return
	var key: String = "lane:%d:%s:%d" % [row_index, lane, int(round(y))]
	if not _gaps.has(key):
		_gaps[key] = {"kind": "lane", "row": row_index, "lane": lane, "y": y}
	_open(key)


## The pointer is over a place that cannot take what is carried: no gap, and the ghost says why.
func refuse(why: String) -> void:
	if not active or cancelling:
		return
	_open("")
	refusal = why
	_redraw_ghost()


func _open(key: String) -> void:
	if key == _target_key:
		return
	if not _target_key.is_empty():
		_retarget(_target_key, 0.0)
	_target_key = key
	if not key.is_empty():
		_retarget(key, carried_height)
	_redraw_ghost()


## Moves every value toward its end; true while anything is still moving. Gaps that have closed are
## dropped, and an Esc slide that has finished ends the drag's motion.
func advance() -> bool:
	if _tweens.is_empty():
		return false
	var moving: bool = is_animating()
	for key: String in _gaps.keys():
		if key != _target_key and _value(key) <= 0.01 and not _tween_running(key):
			_gaps.erase(key)
			_tweens.erase(key)
	if cancelling and not moving:
		_reset()
	return moving


func is_animating() -> bool:
	for key: String in _tweens.keys():
		if _tween_running(key):
			return true
	return false


func _tween_running(key: String) -> bool:
	var tween: Dictionary = _tweens.get(key, {})
	if tween.is_empty():
		return false
	return float(Time.get_ticks_msec() - int(tween["start"])) < SLIDE_MSEC \
		and absf(float(tween["to"]) - float(tween["from"])) > 0.01


func _retarget(key: String, to: float) -> void:
	var now: float = _value(key)
	if EventSheetAccessibility.reduced_motion():
		_tweens[key] = {"from": to, "to": to, "start": 0}
		return
	_tweens[key] = {"from": now, "to": to, "start": Time.get_ticks_msec()}


## The value of an animated key right now: eased out of its start toward its end.
func _value(key: String) -> float:
	var tween: Dictionary = _tweens.get(key, {})
	if tween.is_empty():
		return 0.0
	var from: float = float(tween["from"])
	var to: float = float(tween["to"])
	var t: float = clampf(float(Time.get_ticks_msec() - int(tween["start"])) / SLIDE_MSEC, 0.0, 1.0)
	return from + (to - from) * ease_out(t)


## The slide's curve: fast away, gentle at the end.
static func ease_out(t: float) -> float:
	var u: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


## How far row `index` is drawn below its laid-out place: every row gap opened at or above it, the
## growth of every row above it whose lane opened a gap, less the fold of everything carried away above it.
func row_offset(index: int) -> float:
	if not active:
		return 0.0
	var offset: float = 0.0
	for key: String in _gaps.keys():
		var gap: Dictionary = _gaps[key]
		var height: float = _value(key)
		if height <= 0.0:
			continue
		if str(gap["kind"]) == "row" and int(gap["slot"]) <= index:
			offset += height
		elif str(gap["kind"]) == "lane" and int(gap["row"]) < index:
			offset += lane_growth(int(gap["row"]))
	var fold: float = _value("fold")
	if fold > 0.0:
		if kind == "rows":
			for block: Variant in _source_blocks:
				var first: int = int(block[0])
				var last: int = int(block[1])
				var share: float = fold * (_band_height(first, last) / maxf(_carried_full_height(), 1.0))
				if index > last:
					offset -= share
				elif index >= first:
					# Inside the folding block: the rows close up toward its top.
					var into: float = _metrics().row_top(index) - _metrics().row_top(first)
					offset -= share * (into / maxf(_band_height(first, last), 1.0))
	return offset


## How much taller row `index` is drawn because a gap opened in one of its lanes.
func lane_growth(index: int) -> float:
	var grown: float = 0.0
	for key: String in _gaps.keys():
		var gap: Dictionary = _gaps[key]
		if str(gap["kind"]) != "lane" or int(gap["row"]) != index:
			continue
		var height: float = _value(key)
		if height <= 0.0:
			continue
		var lane_bottom: float = _lane_bottom(index, str(gap["lane"]))
		var other_bottom: float = _lane_bottom(index, "action" if str(gap["lane"]) == "condition" else "condition")
		var row_bottom: float = _metrics().row_top(index) + _metrics().row_height(index)
		grown += maxf(lane_bottom + height - maxf(maxf(lane_bottom, other_bottom), row_bottom - _line_gap()), 0.0)
	return grown


## The drawing plan for one row: how far it moves, and how its spans move inside it. A row a carried
## cell left keeps its height: the cells after it in its lane close up inside the row.
##   {"offset": y, "growth": extra height, "span_shift": {span index: dy},
##    "hidden": [span indices not drawn], "faded": alpha of a lifted source (1 = drawn as it is)}
func row_plan(index: int) -> Dictionary:
	var plan: Dictionary = {"offset": row_offset(index), "growth": lane_growth(index),
		"span_shift": {}, "hidden": [], "faded": 1.0}
	if not active:
		return plan
	var row_data: EventRowData = _viewport._row_at(index)
	if row_data == null:
		return plan
	for key: String in _gaps.keys():
		var gap: Dictionary = _gaps[key]
		if str(gap["kind"]) != "lane" or int(gap["row"]) != index:
			continue
		var height: float = _value(key)
		for span_index: int in range(row_data.spans.size()):
			var span: SemanticSpan = row_data.spans[span_index]
			if span != null and _span_lane(span) == str(gap["lane"]) and span.rect.position.y >= float(gap["y"]) - 0.5:
				(plan["span_shift"] as Dictionary)[span_index] = float((plan["span_shift"] as Dictionary).get(span_index, 0.0)) + height
	if kind == "cells" and int(_source_cell.get("row", -1)) == index:
		var fold: float = _value("fold")
		var carried_spans: Array = _source_cell["spans"]
		if left_source:
			plan["hidden"] = carried_spans.duplicate()
			for span_index: int in range(row_data.spans.size()):
				var span: SemanticSpan = row_data.spans[span_index]
				if span != null and not carried_spans.has(span_index) and _span_lane(span) == str(_source_cell["lane"]) \
						and span.rect.position.y >= source_cell_bottom() - 0.5:
					(plan["span_shift"] as Dictionary)[span_index] = float((plan["span_shift"] as Dictionary).get(span_index, 0.0)) - fold
	if kind == "rows":
		for block: Variant in _source_blocks:
			if index >= int(block[0]) and index <= int(block[1]):
				var fold_share: float = _value("fold") / maxf(_fold_size(), 1.0)
				plan["faded"] = LIFTED_ALPHA * (1.0 - clampf(fold_share, 0.0, 1.0)) if left_source else LIFTED_ALPHA
	return plan


## Where every open gap is drawn, as {"rect": logical Rect2, "open": 0..1} - for the canvas to dash.
func gap_rects() -> Array:
	var out: Array = []
	if not active:
		return out
	var width: float = _viewport._get_logical_canvas_width()
	for key: String in _gaps.keys():
		var gap: Dictionary = _gaps[key]
		var height: float = _value(key)
		if height <= 1.0:
			continue
		if str(gap["kind"]) == "row":
			var slot: int = int(gap["slot"])
			var top: float = _slot_top(slot)
			var indent_x: float = float(EventSheetPalette.GUTTER_WIDTH) + float(int(gap["indent"])) * _indent_width()
			out.append({"rect": Rect2(indent_x, top, maxf(width - indent_x - 2.0, 1.0), height),
				"open": height / maxf(carried_height, 1.0)})
		else:
			var row_index: int = int(gap["row"])
			var lane_rect: Rect2 = _lane_rect(row_index, str(gap["lane"]))
			var y: float = float(gap["y"]) + row_offset(row_index)
			out.append({"rect": Rect2(lane_rect.position.x + 2.0, y, maxf(lane_rect.size.x - 4.0, 1.0), height),
				"open": height / maxf(carried_height, 1.0)})
	return out


## The top of a row gap opened before flat row `slot` (the row count for the very end), as drawn.
func _slot_top(slot: int) -> float:
	var count: int = _viewport._flat_rows.size()
	if slot >= count:
		var last: int = count - 1
		return _metrics().row_top(last) + _metrics().row_height(last) + row_offset(last) + lane_growth(last)
	# The gap sits where the slot's row was, moved by everything above the gap but not the gap itself.
	var own: float = 0.0
	for key: String in _gaps.keys():
		var gap: Dictionary = _gaps[key]
		if str(gap["kind"]) == "row" and int(gap["slot"]) == slot:
			own += _value(key)
	return _metrics().row_top(slot) + row_offset(slot) - own


## The pointer at drawn position `at` (logical) read back onto the rows as laid out:
## {"position": Vector2 to hit-test, "in_gap": true when it is inside an open gap (keep the target)}.
func to_logical(at: Vector2) -> Dictionary:
	if not active:
		return {"position": at, "in_gap": false}
	for entry: Variant in gap_rects():
		var rect: Rect2 = (entry as Dictionary)["rect"]
		if at.y >= rect.position.y and at.y < rect.end.y and (rect.has_point(at) or _row_gap_contains(at.y, rect)):
			_last_mapped = {"at": at, "row": -1, "in_gap": true}
			return {"position": at, "in_gap": true}
	var range_: Vector2i = _viewport.get_visible_row_range()
	var first: int = maxi(range_.x - 2, 0)
	var last: int = mini(range_.y + 12, _viewport._flat_rows.size() - 1)
	for index: int in range(first, last + 1):
		if _hidden_row(index):
			continue
		var top: float = _metrics().row_top(index) + row_offset(index)
		var height: float = _metrics().row_height(index) + lane_growth(index)
		if at.y < top or at.y >= top + height:
			continue
		var logical_y: float = at.y - row_offset(index)
		for key: String in _gaps.keys():
			var gap: Dictionary = _gaps[key]
			if str(gap["kind"]) == "lane" and int(gap["row"]) == index and logical_y >= float(gap["y"]):
				logical_y -= _value(key)
		if kind == "cells" and int(_source_cell.get("row", -1)) == index and left_source \
				and logical_y >= source_cell_top():
			logical_y += _value("fold")
		var row_bottom: float = _metrics().row_top(index) + _metrics().row_height(index) - 0.5
		var mapped: Vector2 = Vector2(at.x, clampf(logical_y, _metrics().row_top(index), row_bottom))
		_last_mapped = {"at": at, "position": mapped, "row": index, "in_gap": false}
		return {"position": mapped, "in_gap": false}
	return {"position": at, "in_gap": false}


func _row_gap_contains(y: float, rect: Rect2) -> bool:
	return y >= rect.position.y and y < rect.end.y


## True for a carried row that has folded all the way out of the sheet.
func _hidden_row(index: int) -> bool:
	if kind != "rows" or not left_source:
		return false
	for block: Variant in _source_blocks:
		if index >= int(block[0]) and index <= int(block[1]):
			return _value("fold") >= _fold_size() - 0.5
	return false


## Facts for the harnesses and tests: what is carried, where the gaps are, how far the rows moved.
func facts() -> Dictionary:
	var gaps: Array = []
	for entry: Variant in gap_rects():
		gaps.append((entry as Dictionary)["rect"])
	return {"active": active, "kind": kind, "count": carried_count, "carried_height": carried_height,
		"left_source": left_source, "fold": _value("fold"), "target": _target_key, "gaps": gaps, "refusal": refusal,
		"cancelling": cancelling, "animating": is_animating(), "ghost": _ghost != null and _ghost.visible,
		"ghost_rect": _ghost.get_global_rect() if _ghost != null and _ghost.visible else Rect2(),
		"ghost_rotation": _ghost.rotation_degrees if _ghost != null else 0.0,
		"pointer": _viewport._drag_pointer_position, "grab": _grab, "mapped": _last_mapped}


func _show_ghost() -> void:
	if _ghost == null:
		_ghost = Control.new()
		_ghost.name = "DragGhost"
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.z_index = 90
		_ghost.draw.connect(_draw_ghost_frame)
		_ghost_content = Control.new()
		_ghost_content.name = "DragGhostContent"
		_ghost_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost_content.clip_contents = true
		_ghost_content.draw.connect(_draw_ghost_content)
		_ghost.add_child(_ghost_content)
		_viewport.add_child(_ghost)
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var size: Vector2 = _ghost_size() * zoom
	_ghost.size = size
	_ghost_content.size = size
	_ghost.pivot_offset = _grab * zoom
	_ghost.rotation_degrees = GHOST_TILT_DEGREES
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.94)
	_ghost.visible = true
	_place_ghost(_press if _press != Vector2.ZERO else _grab)
	_ghost.queue_redraw()
	_ghost_content.queue_redraw()


func _redraw_ghost() -> void:
	if _ghost != null:
		_ghost.queue_redraw()
		_ghost_content.queue_redraw()


## True for a row the drag carries that has started folding away: what is drawn round its rows (the
## event's card, the selection's frame) is not drawn while it folds, since the ghost carries them.
func row_carried_away(index: int) -> bool:
	if not active or kind != "rows" or not left_source:
		return false
	for block: Variant in _source_blocks:
		if index >= int(block[0]) and index <= int(block[1]):
			return true
	return false


func _hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


func _place_ghost(at: Vector2) -> void:
	if _ghost == null or not _ghost.visible:
		return
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	_ghost.position = (at - _grab) * zoom
	var size: Vector2 = _ghost_size() * zoom
	if not _ghost.size.is_equal_approx(size):
		_ghost.size = size
		_ghost_content.size = size
		_redraw_ghost()


## The ghost's size, logical: a carried event as wide as the sheet and as tall as its first rows; a
## carried cell as wide as its lane and as tall as its line.
func _ghost_size() -> Vector2:
	if kind == "cells":
		var lane_rect: Rect2 = _lane_rect(int(_source_cell["row"]), str(_source_cell["lane"]))
		return Vector2(lane_rect.size.x, source_cell_bottom() - source_cell_top() + 4.0)
	var block: Array = _source_blocks[0] if not _source_blocks.is_empty() else [0, 0]
	var last: int = mini(int(block[1]), int(block[0]) + GHOST_ROWS - 1)
	return Vector2(_viewport._get_logical_canvas_width(), _band_height(int(block[0]), last))


## Under the ghost: its shadow, the plates of a stack, the count, and the red edge and the reason when
## the place under the pointer refuses it.
func _draw_ghost_frame() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, _ghost.size)
	var reading: EventSheetReadingStyle = _viewport._get_reading_style()
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var plate: Color = event_style.row_background_color if event_style != null else Color(0.2, 0.2, 0.2)
	plate.a = 1.0
	var shadow: StyleBoxFlat = StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	shadow.shadow_size = 14
	shadow.shadow_offset = Vector2(0.0, 8.0)
	shadow.set_corner_radius_all(4)
	shadow.draw(_ghost.get_canvas_item(), rect)
	if carried_count > 1:
		for step: int in [2, 1]:
			var behind: Rect2 = rect.grow(0.0)
			behind.position += Vector2(5.0, 5.0) * float(step)
			_ghost.draw_rect(behind, plate.darkened(0.08 * float(step)), true)
			_ghost.draw_rect(behind, reading.drag_line_color, false, 1.0)
	_ghost.draw_rect(rect, plate, true)
	var font: Font = _viewport._get_font()
	var font_size: int = _viewport._get_font_size()
	if carried_count > 1 and font != null:
		var badge_text: String = str(carried_count)
		var badge_size: float = font.get_height(font_size) + 4.0
		# By the pointer, where the eye is: a full-width event's far edge can sit past the window's.
		var badge_center: Vector2 = Vector2(clampf(_grab.x * maxf(_viewport._zoom_factor, 0.001) + badge_size, badge_size * 0.5 + 2.0,
			rect.end.x - badge_size * 0.5 - 2.0), rect.position.y - badge_size * 0.5 + 2.0)
		_ghost.draw_circle(badge_center, badge_size * 0.5, reading.drag_line_color)
		var text_width: float = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		_ghost.draw_string(font, badge_center + Vector2(-text_width * 0.5, font.get_ascent(font_size) * 0.5 - 1.0),
			badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, reading.drag_bubble_text_color)


## The carried thing itself, drawn by the sheet's own renderer: the event's first rows, or the cell's line.
func _draw_ghost_content() -> void:
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var font: Font = _viewport._get_font()
	var font_size: int = _viewport._get_font_size()
	var width: float = _viewport._get_logical_canvas_width()
	var renderer: EventRowRenderer = _viewport._renderer
	if kind == "cells":
		var row_index: int = int(_source_cell["row"])
		var row_data: EventRowData = _viewport._row_at(row_index)
		if row_data == null:
			return
		var lane_rect: Rect2 = _lane_rect(row_index, str(_source_cell["lane"]))
		_ghost_content.draw_set_transform(-Vector2(lane_rect.position.x, source_cell_top() - 2.0) * zoom, 0.0, Vector2(zoom, zoom))
		renderer.draw_cell_line(_ghost_content, row_data, str(_source_cell["lane"]),
			Rect2(lane_rect.position.x, source_cell_top() - 2.0, lane_rect.size.x, source_cell_bottom() - source_cell_top() + 4.0),
			font, font_size, _viewport._editor_style)
	elif not _source_blocks.is_empty():
		var first: int = int(_source_blocks[0][0])
		var last: int = mini(int(_source_blocks[0][1]), first + GHOST_ROWS - 1)
		_ghost_content.draw_set_transform(Vector2(0.0, -_metrics().row_top(first)) * zoom, 0.0, Vector2(zoom, zoom))
		for index: int in range(first, last + 1):
			var row_data: EventRowData = _viewport._row_at(index)
			if row_data == null:
				continue
			var layout: Dictionary = _viewport._layout_builder.get_or_build_row_layout(index, width, font, font_size)
			renderer.draw_row(_ghost_content, layout, row_data, font, font_size, _viewport._editor_style)
	_ghost_content.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not refusal.is_empty() and font != null:
		var reading: EventSheetReadingStyle = _viewport._get_reading_style()
		var edge: Rect2 = Rect2(Vector2.ZERO, _ghost_content.size)
		_ghost_content.draw_rect(edge.grow(-1.0), reading.drag_refusal_color, false, 2.0)
		var said: float = font.get_string_size(refusal, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + 12.0
		var tag: Rect2 = Rect2(edge.end.x - said - 4.0, 2.0, said, font.get_height(font_size) + 4.0)
		_ghost_content.draw_rect(tag, reading.drag_bubble_refused_background_color, true)
		_ghost_content.draw_string(font, tag.position + Vector2(6.0, 2.0 + font.get_ascent(font_size)), refusal,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, reading.drag_bubble_text_color)


## The flat index of the last row of `index`'s subtree (itself when it has none): every following
## row drawn deeper than it, and the rest of its own statement.
func subtree_last(index: int) -> int:
	var row_data: EventRowData = _viewport._row_at(index)
	if row_data == null:
		return index
	var last: int = _viewport.statement_last_index(index)
	var count: int = _viewport._flat_rows.size()
	while last + 1 < count:
		var next: EventRowData = _viewport._row_at(last + 1)
		if next == null or next.indent <= row_data.indent or _viewport._row_is_add_event_footer(next):
			break
		last += 1
	return last


## The top and bottom of the carried cell as the row lays it out NOW. Read live rather than kept from
## the lift: the press selects the event, and a theme that shows the add lines on the selected event
## lays its cells out again a frame later.
func source_cell_top() -> float:
	return _source_cell_band().x


func source_cell_bottom() -> float:
	return _source_cell_band().y


func _source_cell_band() -> Vector2:
	var row_data: EventRowData = _viewport._row_at(int(_source_cell.get("row", -1)))
	if row_data == null:
		return Vector2(float(_source_cell.get("top", 0.0)), float(_source_cell.get("bottom", 0.0)))
	var top: float = INF
	var bottom: float = -INF
	for span_index: Variant in _source_cell.get("spans", []):
		if int(span_index) < row_data.spans.size() and row_data.spans[int(span_index)] != null:
			top = minf(top, row_data.spans[int(span_index)].rect.position.y)
			bottom = maxf(bottom, row_data.spans[int(span_index)].rect.end.y)
	if top == INF:
		return Vector2(float(_source_cell.get("top", 0.0)), float(_source_cell.get("bottom", 0.0)))
	return Vector2(top, bottom)


func _slot_is_source(slot: int) -> bool:
	for block: Variant in _source_blocks:
		if slot >= int(block[0]) and slot <= int(block[1]) + 1:
			return true
	return false


func _over_source(at: Vector2) -> bool:
	if kind == "rows":
		for block: Variant in _source_blocks:
			var top: float = _metrics().row_top(int(block[0]))
			if at.y >= top and at.y < top + _band_height(int(block[0]), int(block[1])):
				return true
		return false
	var row_index: int = int(_source_cell.get("row", -1))
	if row_index < 0:
		return false
	var lane_rect: Rect2 = _lane_rect(row_index, str(_source_cell["lane"]))
	return at.x >= lane_rect.position.x and at.x < lane_rect.end.x \
		and at.y >= source_cell_top() - 2.0 and at.y < source_cell_bottom() + 2.0


func _fold_size() -> float:
	if kind == "rows":
		return _carried_full_height()
	return source_cell_bottom() - source_cell_top() + _line_gap()


func _carried_full_height() -> float:
	var height: float = 0.0
	for block: Variant in _source_blocks:
		height += _band_height(int(block[0]), int(block[1]))
	return height


func _band_height(first: int, last: int) -> float:
	if first < 0 or last < first:
		return 0.0
	return _metrics().row_top(last) + _metrics().row_height(last) - _metrics().row_top(first)


func _lane_rect(row_index: int, lane: String) -> Rect2:
	var layout: Dictionary = _viewport._layout_builder.get_or_build_row_layout(row_index,
		_viewport._get_logical_canvas_width(), _viewport._get_font(), _viewport._get_font_size())
	return layout.get("action_lane_rect" if lane == "action" else "condition_lane_rect", Rect2())


## The bottom of the last cell in a lane of a row, or the lane's top when it holds none.
func _lane_bottom(row_index: int, lane: String) -> float:
	var row_data: EventRowData = _viewport._row_at(row_index)
	var bottom: float = _lane_rect(row_index, lane).position.y
	if row_data == null:
		return bottom
	for span: SemanticSpan in row_data.spans:
		if span != null and _span_lane(span) == lane:
			bottom = maxf(bottom, span.rect.end.y)
	return bottom


func _span_lane(span: SemanticSpan) -> String:
	if not (span.metadata is Dictionary):
		return ""
	var lane: String = str((span.metadata as Dictionary).get("lane", ""))
	return "action" if lane == "action" else ("condition" if lane in ["condition", "trigger"] else lane)


func _line_gap() -> float:
	return 2.0


func _indent_width() -> float:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	return float(event_style.sub_event_indent) if event_style != null else 24.0


func _metrics() -> ViewportRowMetrics:
	return _viewport._row_metrics_helper
