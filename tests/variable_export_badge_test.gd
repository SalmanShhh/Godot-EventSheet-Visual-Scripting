# Godot EventSheets - the "Inspector" badge on variable rows.
#
# A sheet variable exposed to the Godot Inspector (@export) gets a small sliders mark beside its name, so
# it's obvious at a glance - while scrolling a sheet - which variables show in the Inspector vs. stay
# internal. A mark, never a word: the hover says "Editable in the Inspector".
# The badge tracks the same default the compiler uses (exported unless explicitly false).
@tool
class_name VariableExportBadgeTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"health": {"type": "int", "default": 100, "exported": true},
		"internal_clock": {"type": "float", "default": 0.0, "exported": false},
	}
	var rows: Array = viewport._build_global_variable_rows(sheet)

	all_passed = _check("an exported variable shows the Inspector mark",
		_row_has_export_badge(rows, "health"), true) and all_passed
	all_passed = _check("a non-exported variable has no @export badge",
		_row_has_export_badge(rows, "internal_clock"), false) and all_passed
	viewport.free()

	return all_passed


## True when the variable row named `var_name` carries the sliders mark that says the value is
## editable in the Inspector. The mark is a BADGE, never the word - so it is matched by what it
## claims, not by the glyph it happens to draw.
static func _row_has_export_badge(rows: Array, var_name: String) -> bool:
	for row: Variant in rows:
		if not (row is EventRowData):
			continue
		var is_target: bool = false
		var has_badge: bool = false
		for span: Variant in (row as EventRowData).spans:
			var text: String = str((span as SemanticSpan).text)
			var meta: Dictionary = (span as SemanticSpan).metadata if (span as SemanticSpan).metadata is Dictionary else {}
			if text == var_name:
				is_target = true
			if bool(meta.get("inspector_badge", false)):
				has_badge = true
		if is_target:
			return has_badge
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("variable_export_badge_test", label, actual, expected)
