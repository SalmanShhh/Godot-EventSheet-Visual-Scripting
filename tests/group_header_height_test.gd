# Godot EventSheets - a group head is ONE line, and everything it says fits inside it.
#
# Moved the description onto the head's own line (beside the name, still inline-editable) and put
# what the group holds at the right edge, so a group costs one row however much it says. This pins
# the relationship rather than the pixels: the head is a single-line row, a described group is no
# taller than an undescribed one, both clear the themed bar height, and every span - including the
# right-anchored counts and switch - draws inside the head instead of bleeding into the row below.
# Pixel values would just re-encode the theme.
@tool
class_name GroupHeaderHeightTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	var plain: EventGroup = EventGroup.new()
	plain.name = "Setup"
	plain.group_name = "Setup"
	var described: EventGroup = EventGroup.new()
	described.name = "Setup"
	described.group_name = "Setup"
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
	var described_row: EventRowData = viewport.get_flat_rows()[described_index].get("row")

	all_passed = _check("a described group head is a ONE-line row", described_row.line_count, 1) and all_passed
	all_passed = _check("the description rides the head's own line",
		_line_index_of(described_row, "group_description"), 0) and all_passed
	all_passed = _check("a description costs the head no height", described_height, plain_height) and all_passed
	all_passed = _check("a group head still clears the themed bar height",
		plain_height >= float(viewport._get_event_style().group_row_height), true) and all_passed
	all_passed = _check("the head reserves its font line",
		described_height >= line_height, true) and all_passed

	# The invariant that actually matters: everything the head says is DRAWN inside the head. The
	# counts and the switch are right-anchored, which is its own way to land outside the row.
	var described_top: float = viewport._get_row_top(described_index)
	# Laying the row out is what writes each span's rect, so this must run before they are read.
	viewport.get_row_layout_for_test(described_index)
	var lowest_span_bottom: float = described_top
	for span: SemanticSpan in described_row.spans:
		if span != null:
			lowest_span_bottom = maxf(lowest_span_bottom, span.rect.end.y)
	all_passed = _check("every part of the head is drawn inside the head",
		lowest_span_bottom <= described_top + described_height + 0.5, true) and all_passed

	editor.free()
	if all_passed:
		print("[PASS] group_header_height: a group head reads in one line and fits in it.")
	return all_passed


## The line_index of the head span carrying `edit_kind`, or -1 when the head has none.
static func _line_index_of(row_data: EventRowData, edit_kind: String) -> int:
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		if str((span.metadata as Dictionary).get("edit_kind", "")) == edit_kind:
			return int((span.metadata as Dictionary).get("line_index", 0))
	return -1


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
