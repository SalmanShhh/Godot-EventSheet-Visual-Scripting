# EventForge — Cached layout reflects live selection/hover
#
# The row layout is cached by geometry, but selection/hover are NOT part of the cache key.
# They must be refreshed on every read, otherwise a click reads stale state and the whole
# event highlights instead of the clicked cell, and hover never shows. Guards that fix.
@tool
class_name LayoutStateTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsOnFloor"
	event.conditions.append(condition)
	sheet.events.append(event)
	viewport.set_sheet(sheet)

	var index: int = _flat_index(viewport, event)
	var width: float = viewport.get_canvas_logical_width()
	var font: Font = viewport._get_font()
	var font_size: int = viewport._get_font_size()

	# Build + cache the layout (nothing selected/hovered yet).
	var layout_initial: Dictionary = viewport._get_or_build_row_layout(index, width, font, font_size)
	all_passed = _check("initially no span selected", (layout_initial.get("selected_span_indices", []) as Array).is_empty(), true) and all_passed

	var row_data: EventRowData = viewport._row_at(index)
	var span_index: int = -1
	for s in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[s]
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) in ["condition", "trigger"]:
			span_index = s
			break
	all_passed = _check("found a condition/trigger span", span_index >= 0, true) and all_passed

	# Select that span — the cached layout (same key) must reflect it, not stale [].
	viewport._select_row(index, span_index)
	var layout_after_select: Dictionary = viewport._get_or_build_row_layout(index, width, font, font_size)
	all_passed = _check("cached layout reflects the new selection",
		(layout_after_select.get("selected_span_indices", []) as Array).has(span_index), true) and all_passed

	# Hover the span — the cached layout must reflect it, not stale -1.
	viewport._set_hover_state(index, span_index)
	var layout_after_hover: Dictionary = viewport._get_or_build_row_layout(index, width, font, font_size)
	all_passed = _check("cached layout reflects the new hover",
		int(layout_after_hover.get("hovered_span_index", -1)), span_index) and all_passed

	# Selecting the whole event (span -1) clears the span selection so the row fills as a block.
	viewport._select_row(index, -1)
	var layout_whole: Dictionary = viewport._get_or_build_row_layout(index, width, font, font_size)
	all_passed = _check("whole-event select clears span selection in layout",
		(layout_whole.get("selected_span_indices", []) as Array).is_empty(), true) and all_passed

	viewport.free()
	return all_passed


static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] layout_state_test: %s" % label)
		return true
	print("[FAIL] layout_state_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
