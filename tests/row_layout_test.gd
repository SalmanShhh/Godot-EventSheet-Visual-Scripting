# EventForge — Non-event row span layout (overlap regression guard)
#
# Variable (SECTION) and group rows lay their spans out on a single line. A layout bug had
# every span stacked at the same X (badge text overlapping the name). This guards that the
# spans of single-line rows are positioned left-to-right without horizontal overlap.
@tool
extends RefCounted
class_name RowLayoutTest

static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"hp": {"type": "int", "default": 100}}
	var group: EventGroup = EventGroup.new()
	group.group_name = "MyGroup"
	sheet.events.append(group)
	viewport.set_sheet(sheet)

	var font: Font = viewport._get_font()
	var font_size: int = viewport._get_font_size()
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	var saw_section: bool = false
	var saw_group: bool = false

	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data == null:
			continue
		if row_data.row_type != EventRowData.RowType.SECTION and row_data.row_type != EventRowData.RowType.GROUP:
			continue
		# Footer "Add event…" affordances are single-span by design.
		if viewport._row_is_add_event_footer(row_data):
			continue
		viewport._get_or_build_row_layout(i, 1200.0, font, font_size)
		var overlapped: bool = false
		var spans_with_width: int = 0
		for s in range(row_data.spans.size()):
			var span: SemanticSpan = row_data.spans[s]
			if span == null:
				continue
			if span.rect.size.x > 0.0:
				spans_with_width += 1
			if s > 0:
				var prev: SemanticSpan = row_data.spans[s - 1]
				if prev != null and span.rect.position.x < prev.rect.end.x - 0.5:
					overlapped = true
		var kind: String = "variable" if row_data.row_type == EventRowData.RowType.SECTION else "group"
		all_passed = _check("%s row has multiple laid-out spans" % kind, spans_with_width >= 2, true) and all_passed
		all_passed = _check("%s row spans do not overlap" % kind, overlapped, false) and all_passed
		if row_data.row_type == EventRowData.RowType.SECTION:
			saw_section = true
		else:
			saw_group = true

	all_passed = _check("a variable (section) row was laid out", saw_section, true) and all_passed
	all_passed = _check("a group row was laid out", saw_group, true) and all_passed
	viewport.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] row_layout_test: %s" % label)
		return true
	print("[FAIL] row_layout_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
