@tool
class_name EventSheetTextListing
extends RefCounted
# The sheet as a PLAIN-TEXT LISTING - the shape every event-sheet community pastes into a forum
# post, an issue or a chat message: "+ " in front of a condition, "-> " in front of an action, one
# extra indent per sub-event.
#
#   + Player: On hit (damage)
#       -> Player: Subtract damage from hp
#       + Player: hp <= 0
#           -> Player: Destroy
#
# The words are the CANVAS's words, not a second grammar: every line is assembled from the spans the
# viewport already built for that row, so whatever the reading lenses are showing (Humanized names,
# Familiar words, Reading mode) is what the listing says. Read-only output - the round trip already
# lives in the .gd, so nothing pastes back in from here.
#
# Pure functions over EventRowData, so the whole listing is testable without a dock.

## Four spaces per nesting level - the indent the listing is read with everywhere.
const INDENT_UNIT := "    "
## Width of the event-number gutter used when numbers are printed (Save as text).
const NUMBER_GUTTER_WIDTH := 6
## The canvas's add affordances are offers, not content: a listing must not say "+ Add condition".
const SKIPPED_SPAN_KINDS: PackedStringArray = ["add_condition", "add_action", "add_event"]


## The listing for a tree of built rows (each row's `children` are walked, folded or not - a
## listing of half a sheet would be a listing of nothing). `include_numbers` prints each event's
## margin number in a fixed-width gutter so the text and the sheet agree on what "event 12" is.
## `indent_base` is subtracted from every row's indent, so copying a nested selection starts flush
## left instead of carrying the indentation of where it happened to sit.
static func text_for_rows(rows: Array, include_numbers: bool = false, indent_base: int = 0) -> String:
	return "\n".join(lines_for_rows(rows, include_numbers, indent_base))


## The listing as its individual lines (see text_for_rows).
static func lines_for_rows(rows: Array, include_numbers: bool = false, indent_base: int = 0) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		if row is EventRowData:
			_append_row(row as EventRowData, lines, include_numbers, indent_base)
	return lines


## The whole sheet as a Markdown document: a heading naming the sheet, then the listing in a
## fenced block so pasting it anywhere keeps the indentation. Event numbers are on.
static func markdown_for_rows(rows: Array, sheet_title: String) -> String:
	var body: String = text_for_rows(rows, true)
	var heading: String = sheet_title.strip_edges()
	if heading.is_empty():
		heading = "Event sheet"
	return "# %s\n\n```text\n%s\n```\n" % [heading, body]


static func _append_row(row: EventRowData, lines: PackedStringArray, include_numbers: bool, indent_base: int) -> void:
	var indent: String = INDENT_UNIT.repeat(maxi(row.indent - indent_base, 0))
	var number_gutter: String = ""
	if include_numbers:
		number_gutter = " ".repeat(NUMBER_GUTTER_WIDTH)
		if row.event_number > 0:
			var stamp: String = str(row.event_number)
			number_gutter = stamp + " ".repeat(maxi(NUMBER_GUTTER_WIDTH - stamp.length(), 1))
	var blank_gutter: String = " ".repeat(number_gutter.length())
	match row.row_type:
		EventRowData.RowType.COMMENT:
			for comment_line: String in _lane_lines(row, ""):
				lines.append("%s%s# %s" % [number_gutter, indent, comment_line])
				number_gutter = blank_gutter
		EventRowData.RowType.GROUP, EventRowData.RowType.SECTION:
			for title_line: String in _lane_lines(row, ""):
				lines.append("%s%s%s" % [number_gutter, indent, title_line])
				number_gutter = blank_gutter
		_:
			for condition_line: String in _lane_lines(row, "condition"):
				lines.append("%s%s+ %s" % [number_gutter, indent, condition_line])
				number_gutter = blank_gutter
			var action_indent: String = indent + INDENT_UNIT
			for action_line: String in _lane_lines(row, "action"):
				lines.append("%s%s-> %s" % [number_gutter, action_indent, action_line])
				number_gutter = blank_gutter
	for child: Variant in row.children:
		if child is EventRowData:
			_append_row(child as EventRowData, lines, include_numbers, indent_base)


## The row's text for one lane, one string per drawn line. `lane` "" takes every span (the rows
## that have no lanes - comments, group titles). An inverted condition reads "not ..." the way the
## sheet says it, because the canvas says it with a red mark the text cannot draw.
static func _lane_lines(row: EventRowData, lane: String) -> PackedStringArray:
	var by_line: Dictionary = {}
	var order: Array[int] = []
	for span: Variant in row.spans:
		if not (span is SemanticSpan):
			continue
		var metadata: Dictionary = (span as SemanticSpan).metadata if (span as SemanticSpan).metadata is Dictionary else {}
		if not lane.is_empty() and str(metadata.get("lane", "")) != lane:
			continue
		if SKIPPED_SPAN_KINDS.has(str(metadata.get("kind", ""))):
			continue
		var line_index: int = int(metadata.get("line_index", 0))
		if not by_line.has(line_index):
			by_line[line_index] = []
			order.append(line_index)
		(by_line[line_index] as Array).append(span)
	order.sort()
	var lines: PackedStringArray = PackedStringArray()
	for line_index: int in order:
		var text: String = _join_spans(by_line[line_index] as Array)
		if not text.is_empty():
			lines.append(text)
	return lines


static func _join_spans(spans: Array) -> String:
	var negated: bool = false
	var pieces: PackedStringArray = PackedStringArray()
	var object_label: String = ""
	for span: Variant in spans:
		var typed: SemanticSpan = span as SemanticSpan
		var metadata: Dictionary = typed.metadata if typed.metadata is Dictionary else {}
		var text: String = str(typed.text).strip_edges()
		if bool(metadata.get("badge", false)):
			if str(metadata.get("badge_style", "")) == "negated":
				negated = true
			continue
		if text.is_empty():
			continue
		if pieces.is_empty() and object_label.is_empty() and typed.type == SemanticSpan.SpanType.OBJECT:
			object_label = text
			continue
		pieces.append(text)
	var body: String = " ".join(pieces)
	if negated and not body.is_empty():
		body = "not " + body
	if object_label.is_empty():
		return body
	return object_label if body.is_empty() else "%s: %s" % [object_label, body]
