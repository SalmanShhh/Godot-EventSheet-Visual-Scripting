# EventSheet - row density (Comfortable / Compact). Pins the two contracts:
#   1. Comfortable (density 1.0, the default) is BYTE-IDENTICAL to the pre-toggle formulas.
#   2. Compact shrinks only the breathing room - the text-height portion of a line never scales.
@tool
class_name RowDensityTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var style: EventSheetElementStyle = EventSheetElementStyle.new()
	# Defaults at the time of writing: font_size_delta 0, vertical_padding 2. Pin through the API.
	style.font_size_delta = 0
	style.vertical_padding = 2

	# Comfortable = the exact legacy value: 13 + 0 + 4 + MIN_LINE_HEIGHT_EXTRA, floored by 28.
	EventSheetPalette.set_row_density(1.0)
	var comfortable: float = style.resolve_line_height(13, 28)
	var legacy: float = max(28.0, float(13 + 0 + 4 + EventSheetElementStyle.MIN_LINE_HEIGHT_EXTRA))
	all_passed = _check("comfortable is byte-identical to the legacy formula", comfortable, legacy) and all_passed

	# Compact: floors and padding scale, the font portion does not.
	EventSheetPalette.set_row_density(EventSheetPalette.COMPACT_ROW_DENSITY)
	var compact: float = style.resolve_line_height(13, 28)
	all_passed = _check("compact is tighter than comfortable", compact < comfortable, true) and all_passed
	var expected_compact: float = max(28.0 * EventSheetPalette.COMPACT_ROW_DENSITY,
		13.0 + float(4 + EventSheetElementStyle.MIN_LINE_HEIGHT_EXTRA) * EventSheetPalette.COMPACT_ROW_DENSITY)
	all_passed = _check("compact value matches the padding-only scaling", compact, expected_compact) and all_passed
	# A BIG font is never shrunk: the text term stays whole, so the line always fits the glyphs.
	var compact_big_font: float = style.resolve_line_height(28, 28)
	all_passed = _check("compact never squeezes below the font height", compact_big_font >= 28.0, true) and all_passed

	# The factor clamps to a sane band (a stray 0.0 would collapse the sheet).
	EventSheetPalette.set_row_density(0.0)
	all_passed = _check("density clamps at 0.5", EventSheetPalette.row_density(), 0.5) and all_passed
	EventSheetPalette.set_row_density(3.0)
	all_passed = _check("density clamps at 1.0", EventSheetPalette.row_density(), 1.0) and all_passed

	EventSheetPalette.set_row_density(1.0)
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] row_density_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
