# Godot EventSheets — the "@export" badge on variable rows.
#
# A sheet variable exposed to the Godot Inspector (@export) gets a blue "@export" pill on its row, so it's
# obvious at a glance — while scrolling a sheet — which variables show in the Inspector vs. stay internal.
# The badge tracks the same default the compiler uses (exported unless explicitly false).
@tool
class_name VariableExportBadgeTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"health": {"type": "int", "default": 100, "exported": true},
		"internal_clock": {"type": "float", "default": 0.0, "exported": false},
	}
	var rows: Array = viewport._build_global_variable_rows(sheet)

	all_passed = _check("an exported variable shows the @export badge",
		_row_has_export_badge(rows, "health"), true) and all_passed
	all_passed = _check("a non-exported variable has no @export badge",
		_row_has_export_badge(rows, "internal_clock"), false) and all_passed
	viewport.free()

	return all_passed


## True when the variable row named `var_name` carries an "@export" badge span.
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
			if text == "@export" and bool(meta.get("badge", false)):
				has_badge = true
		if is_target:
			return has_badge
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_export_badge_test: %s" % label)
		return true
	print("[FAIL] variable_export_badge_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
