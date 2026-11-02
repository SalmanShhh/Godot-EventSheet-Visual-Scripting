@tool
class_name EventSheetRetainedPaintItem
extends Node2D
# One retained piece of the sheet's paint: the canvas item the engine keeps the drawing commands of
# between frames. The sheet is still ONE virtualized custom-drawn canvas - these are not widgets (no
# layout, no input, no theme, no focus), only the places the viewport parks paint that has not
# changed, so a hover or a keystroke re-records the one row it touched and not every visible row.
#
# Two kinds, both drawn BEHIND the viewport's own paint (show_behind_parent), which keeps the old
# stacking exactly: the base layer (background and fills) first, then the rows by index, then
# everything the viewport itself draws over them (cards, selection frames, brackets, the ghost).
#
#   KIND_BASE   the sheet background and the fills that sit under the rows.
#   KIND_ROW    one visible row, drawn by the very renderer call the viewport used to make inline.
#
# A row is re-recorded only when its paint signature changes. The signature is every value the row's
# paint reads that can change without the row being rebuilt: the row's own plain fields, the live
# state the layout refreshes on every read (hover, selection, the edit in progress), the layout's
# identity (a relayout makes a new one) and the frame-wide values (zoom, size, look, font).

const KIND_BASE: int = 0
const KIND_ROW: int = 1

## The row fields that never reach the paint: heavy references and the child lists. Everything else
## on the row that is plain data is part of its signature.
const SKIPPED_FIELDS: Array[String] = ["spans", "children"]

static var _signature_fields: PackedStringArray = PackedStringArray()
## The plain fields of each part of a look, by its script.
static var _look_field_names: Dictionary = {}

var kind: int = KIND_ROW
var viewport: Control = null
## What this item was last recorded from.
var paint_layout: Dictionary = {}
var paint_row: EventRowData = null
var paint_signature_value: int = 0
var font: Font = null
var font_size: int = 16
var zoom: float = 1.0
## The viewport's size, for the paint that reads it (a note's right edge).
var size: Vector2 = Vector2.ZERO
## This frame's row is one a drag in hand changes (a veil, a gap in its lane, a cell lifted): it is
## drawn through the viewport's motion path, on this item, so it keeps its place in the row order.
var in_motion: bool = false
var row_index: int = -1
## How many times this item has been drawn, and how many times it was asked to be recorded, for the
## tests and the bench.
var records: int = 0
var requests: int = 0


func _init() -> void:
	show_behind_parent = true


func _draw() -> void:
	records += 1
	if viewport == null:
		return
	if kind == KIND_BASE:
		viewport.draw_retained_base(self)
		return
	if paint_row == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
	if in_motion:
		viewport.paint_retained_row_in_motion(self, row_index, paint_layout, paint_row, font, font_size, zoom)
		return
	viewport.paint_retained_row(self, paint_layout, paint_row, font, font_size)


## The services the renderer asks of whatever it draws on, answered by the viewport.
func lane_width_for(lane: String, indent: int) -> float:
	return viewport.lane_width_for(lane, indent)


func get_zoom_factor() -> float:
	return viewport.get_zoom_factor()


func collapsed_row_summary(row_data: EventRowData) -> String:
	return viewport.collapsed_row_summary(row_data)


## Whether this item must be recorded again to show `row_data` laid out as `layout` with `signature`.
func needs_record(layout: Dictionary, row_data: EventRowData, signature: int) -> bool:
	return paint_row != row_data or paint_signature_value != signature or not is_same(paint_layout, layout)


## Remembers what the next record is made from, and asks for it.
func record(layout: Dictionary, row_data: EventRowData, signature: int) -> void:
	paint_layout = layout
	paint_row = row_data
	paint_signature_value = signature
	requests += 1
	queue_redraw()


## Forgets the recording, so a recycled item is never mistaken for the row it last showed.
func forget() -> void:
	paint_layout = {}
	paint_row = null
	paint_signature_value = 0
	in_motion = false
	row_index = -1
	visible = false


## The signature of one row's paint. `frame_signature` is the viewport's frame-wide part.
static func paint_signature(row_data: EventRowData, layout: Dictionary, frame_signature: int) -> int:
	var fields: PackedStringArray = _fields()
	var values: Array = [frame_signature]
	for field: String in fields:
		values.append(row_data.get(field))
	# What the layout refreshes on every read, because it is not part of the geometry's cache key.
	values.append(layout.get("selected_span_indices", []))
	values.append(layout.get("hovered_span_index", -1))
	values.append(layout.get("match_span_indices", PackedInt32Array()))
	values.append(layout.get("editing_span_index", -1))
	values.append(layout.get("editing_buffer", ""))
	values.append(layout.get("editing_caret", -1))
	values.append(layout.get("editing_select_anchor", -1))
	values.append(layout.get("editing_note", ""))
	values.append(layout.get("total_selected_spans", 0))
	# A state row's live token: the renderer asks the running game's state at draw time, and the seconds
	# change inside the room the row already holds, with no rebuild and no new layout.
	if EventSheetStateWatch.is_live():
		values.append(_live_state_reading(row_data))
	return hash(values)


## What the row's state tokens say right now: "" for a member no running game is in.
static func _live_state_reading(row_data: EventRowData) -> PackedStringArray:
	var reading: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary and (span.metadata as Dictionary).has("state_name"):
			reading.append(EventSheetStateWatch.token_text(str((span.metadata as Dictionary)["state_name"])))
	return reading


## A hash of every plain value a look holds. A look is a resource a reader can change in place (the
## Inspector edits a sheet's own one) and nothing announces that: the row items must not keep the old
## colours. The look's parts are looked at once per drawn frame, never per row.
static func look_signature(style: EventSheetEditorStyle) -> int:
	if style == null:
		return 0
	var values: Array = []
	for part: Resource in [style.event_style, style.condition_style, style.action_style, style.reading_style, style.chrome_style]:
		if part == null:
			values.append(0)
			continue
		for field: String in _look_fields(part):
			values.append(part.get(field))
	return hash(values)


static func _look_fields(part: Resource) -> PackedStringArray:
	var script: Script = part.get_script()
	if _look_field_names.has(script):
		return _look_field_names[script]
	var names: PackedStringArray = PackedStringArray()
	for property: Dictionary in part.get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and int(property["type"]) != TYPE_OBJECT:
			names.append(str(property["name"]))
	_look_field_names[script] = names
	return names


static func _fields() -> PackedStringArray:
	if _signature_fields.is_empty():
		for property: Dictionary in EventRowData.new().get_property_list():
			if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var field: String = str(property["name"])
			if SKIPPED_FIELDS.has(field) or int(property["type"]) == TYPE_OBJECT:
				continue
			_signature_fields.append(field)
	return _signature_fields
