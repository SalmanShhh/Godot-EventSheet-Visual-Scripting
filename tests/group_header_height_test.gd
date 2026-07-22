# Godot EventSheets - a group header reserves height for its DESCRIPTION line.
#
# A group with a description is a two-line header: the builder sets line_count = 2 and draws the
# description as a muted second line. The metrics pass, though, returned the themed group_row_height
# flat and never looked at line_count - so the second line had no height reserved, and the row below
# was drawn over it. The themed default (56) is already under two lines of the default font, and the
# gap widens with the editor font, which is the same bleed single-line rows had on a Retina Mac.
#
# This pins the relationship rather than the pixels: a described group is at least two font-lines
# tall, is taller than an undescribed one, and still clears the themed minimum. Pixel values would
# just re-encode the theme.
@tool
class_name GroupHeaderHeightTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	var plain: EventGroup = EventGroup.new()
	plain.name = "Setup"
	var described: EventGroup = EventGroup.new()
	described.name = "Setup"
	described.description = "one-time wiring"
	sheet.events.append(plain)
	sheet.events.append(described)

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport._rebuild_row_metrics()
	var line_height: float = viewport._get_event_line_height(viewport._get_font_size())
	# Locate each header by its RESOURCE: a group also emits a trailing "+ Add event to ..." row, so
	# flat-row indices do not line up with the sheet's own order.
	var plain_index: int = _index_of(viewport, plain)
	var described_index: int = _index_of(viewport, described)
	all_passed = _check("both group headers are on the canvas", plain_index >= 0 and described_index >= 0, true) and all_passed
	if plain_index < 0 or described_index < 0:
		editor.free()
		return false
	var plain_height: float = viewport._get_row_height(plain_index)
	var described_height: float = viewport._get_row_height(described_index)

	all_passed = _check("a described group header is a two-line row",
		viewport.get_flat_rows()[described_index].get("row").line_count, 2) and all_passed
	all_passed = _check("it reserves both font lines",
		described_height >= line_height * 2.0, true) and all_passed
	all_passed = _check("it is taller than a group with no description",
		described_height > plain_height, true) and all_passed
	all_passed = _check("an undescribed group still clears the themed bar height",
		plain_height >= float(viewport._get_event_style().group_row_height), true) and all_passed

	# The invariant that actually matters: the description is DRAWN inside its own row. Reserving the
	# height was only half the fix - the layout centred the text block as though it were a single line,
	# which pushed the second line past the bar's bottom edge and under the row that follows.
	var described_top: float = viewport._get_row_top(described_index)
	# Laying the row out is what writes each span's rect, so this must run before they are read.
	viewport.get_row_layout_for_test(described_index)
	var described_row: EventRowData = viewport.get_flat_rows()[described_index].get("row")
	var lowest_span_bottom: float = described_top
	for span: SemanticSpan in described_row.spans:
		if span != null:
			lowest_span_bottom = maxf(lowest_span_bottom, span.rect.end.y)
	all_passed = _check("every line of the header is drawn inside the header",
		lowest_span_bottom <= described_top + described_height + 0.5, true) and all_passed
	all_passed = _check("the second line is genuinely below the first",
		lowest_span_bottom > described_top + line_height, true) and all_passed

	# The Retina case that made this visible: at a large editor font two lines far exceed the themed
	# 56, so a flat themed height would bleed tens of pixels into the row below.
	var big_font: int = 28
	var big_line: float = viewport._get_event_line_height(big_font)
	all_passed = _check("two lines of a Retina-sized font exceed the themed bar",
		big_line * 2.0 > float(viewport._get_event_style().group_row_height), true) and all_passed

	editor.free()
	if all_passed:
		print("[PASS] group_header_height: a described group header reserves its second line.")
	return all_passed


## The flat-row index whose row is backed by `resource`, or -1.
static func _index_of(viewport: EventSheetViewport, resource: Resource) -> int:
	var rows: Array[Dictionary] = viewport.get_flat_rows()
	for index in range(rows.size()):
		var row: EventRowData = rows[index].get("row")
		if row != null and row.source_resource == resource:
			return index
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] group_header_height: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
