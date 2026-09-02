# Godot EventSheets - grouping @export variables into Inspector @export_group sections.
#
# A variable's "Inspector group" (set in the variable dialog) lands it in an @export_group("Name") section
# in the generated script, so the Godot Inspector shows the exported vars grouped. This pins both halves:
# the sheet draws the section ONCE, as a slim folder strip over the rows it holds (never a chip repeated
# on every row), and the group attribute compiles to @export_group(...).
@tool
class_name VariableExportGroupTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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
	all_passed = _check("a grouped variable sits under a folder strip named for its section",
		_folder_holding(rows, "attack"), "Combat") and all_passed
	all_passed = _check("an ungrouped variable sits in no folder",
		_folder_holding(rows, "speed"), "") and all_passed
	all_passed = _check("and no row wears a group pill",
		_row_has_chip(rows, "attack", "Combat"), false) and all_passed

	# A subgroup (@export_subgroup) reads as "Group › Subgroup" in the one chip.
	var sub_sheet: EventSheetResource = EventSheetResource.new()
	sub_sheet.variables = {"melee_dmg": {"type": "int", "default": 5, "exported": true, "attributes": {"group": "Combat", "subgroup": "Melee"}}}
	all_passed = _check("the strip names the subsection too",
		_folder_holding(viewport._build_global_variable_rows(sub_sheet), "melee_dmg"), "Combat › Melee") and all_passed
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
	return SUPPORT.check("variable_export_group_test", label, actual, expected)


## The label on the folder strip that holds the variable named `var_name`, "" when it sits in none.
static func _folder_holding(rows: Array, var_name: String) -> String:
	for row: Variant in rows:
		var strip: EventRowData = row as EventRowData
		if strip == null or strip.children.is_empty():
			continue
		for child: EventRowData in strip.children:
			var meta: Dictionary = child.spans[0].metadata if child.spans[0].metadata is Dictionary else {}
			if str(meta.get("variable_name", "")) == var_name:
				return str(strip.spans[0].text)
	return ""
