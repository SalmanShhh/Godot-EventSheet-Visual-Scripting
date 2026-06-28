# Godot EventSheets — grouping @export variables into Inspector @export_group sections.
#
# A variable's "Inspector group" (set in the variable dialog) lands it in an @export_group("Name") section
# in the generated script, so the Godot Inspector shows the exported vars grouped. This pins both halves:
# the row shows the group name as a chip (so grouping is legible in the sheet), and the group attribute
# compiles to @export_group(...).
@tool
extends RefCounted
class_name VariableExportGroupTest

static func run() -> bool:
	var all_passed: bool = true

	# Rendering: a grouped exported var shows its Inspector-group chip on the row.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"attack": {"type": "int", "default": 10, "exported": true, "attributes": {"group": "Combat"}},
		"speed": {"type": "float", "default": 5.0, "exported": true},
	}
	var rows: Array = viewport._build_global_variable_rows(sheet)
	all_passed = _check("a grouped variable shows its Inspector-group chip",
		_row_has_chip(rows, "attack", "Combat"), true) and all_passed
	all_passed = _check("an ungrouped variable has no group chip",
		_row_has_chip(rows, "speed", "Combat"), false) and all_passed

	# A subgroup (@export_subgroup) reads as "Group › Subgroup" in the one chip.
	var sub_sheet: EventSheetResource = EventSheetResource.new()
	sub_sheet.variables = {"melee_dmg": {"type": "int", "default": 5, "exported": true, "attributes": {"group": "Combat", "subgroup": "Melee"}}}
	all_passed = _check("the row chip combines group and subgroup",
		_row_has_chip(viewport._build_global_variable_rows(sub_sheet), "melee_dmg", "Combat › Melee"), true) and all_passed
	viewport.free()

	# Emission: the group + subgroup attributes compile to @export_group / @export_subgroup.
	var lines: PackedStringArray = SheetCompiler._emit_variables(
		{"attack": {"type": "int", "default": 10, "exported": true, "attributes": {"group": "Combat"}}})
	all_passed = _check("the group compiles to @export_group",
		"\n".join(lines).contains("@export_group(\"Combat\")"), true) and all_passed
	var sub_lines: PackedStringArray = SheetCompiler._emit_variables(
		{"melee_dmg": {"type": "int", "default": 5, "exported": true, "attributes": {"group": "Combat", "subgroup": "Melee"}}})
	all_passed = _check("a subgroup compiles to @export_subgroup under the group",
		"\n".join(sub_lines).contains("@export_group(\"Combat\")") and "\n".join(sub_lines).contains("@export_subgroup(\"Melee\")"), true) and all_passed

	return all_passed

## True when the variable row named `var_name` carries a badge span with text `chip_text`.
static func _row_has_chip(rows: Array, var_name: String, chip_text: String) -> bool:
	for row: Variant in rows:
		if not (row is EventRowData):
			continue
		var is_target: bool = false
		var has_chip: bool = false
		for span: Variant in (row as EventRowData).spans:
			var text: String = str((span as SemanticSpan).text)
			var meta: Dictionary = (span as SemanticSpan).metadata if (span as SemanticSpan).metadata is Dictionary else {}
			if text == var_name:
				is_target = true
			if text == chip_text and bool(meta.get("badge", false)):
				has_chip = true
		if is_target:
			return has_chip
	return false

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_export_group_test: %s" % label)
		return true
	print("[FAIL] variable_export_group_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
