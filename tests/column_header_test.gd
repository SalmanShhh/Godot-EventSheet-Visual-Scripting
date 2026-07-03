# EventForge — Column header lane-geometry
#
# The pinned Conditions/Actions header aligns to the same lane divider the rows use, so this
# guards EventSheetViewport.get_lane_divider_x() (the shared alignment contract) and that the
# header binds and reserves its band. The header's appearance is verified by opening the editor.
@tool
class_name ColumnHeaderTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var style: EventSheetEventStyle = viewport._get_event_style()
	var ratio: float = style.condition_lane_ratio
	var min_width: float = style.minimum_conditions_lane_width

	for width in [400.0, 1000.0, 2000.0]:
		var content_width: float = max(width - EventSheetPalette.GUTTER_WIDTH, 120.0)
		var expected: float = EventSheetPalette.GUTTER_WIDTH + max(min_width, floor(content_width * ratio))
		var actual: float = viewport.get_lane_divider_x(width)
		all_passed = _check("lane divider x at width %d" % int(width), actual, expected) and all_passed
		all_passed = _check("divider sits right of the gutter at %d" % int(width), actual > EventSheetPalette.GUTTER_WIDTH, true) and all_passed
		all_passed = _check("divider leaves an action lane at %d" % int(width), actual < width, true) and all_passed

	all_passed = _check("wider canvas pushes the divider right",
		viewport.get_lane_divider_x(2000.0) > viewport.get_lane_divider_x(1000.0), true) and all_passed

	# Header binds to the viewport and reserves its band height.
	var header: SheetColumnHeader = SheetColumnHeader.new()
	header.setup(viewport)
	all_passed = _check("header reserves its band height", header.custom_minimum_size.y, SheetColumnHeader.HEADER_HEIGHT) and all_passed
	all_passed = _check("header ignores mouse so rows stay clickable", header.mouse_filter, Control.MOUSE_FILTER_IGNORE) and all_passed
	header.free()
	viewport.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] column_header_test: %s" % label)
		return true
	print("[FAIL] column_header_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
