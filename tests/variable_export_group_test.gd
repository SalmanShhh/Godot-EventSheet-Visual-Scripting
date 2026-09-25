# Godot EventSheets - grouping @export variables into Inspector @export_group sections.
#
# A variable's "Inspector group" (set in the variable dialog) lands it in an @export_group("Name") section
# in the generated script, so the Godot Inspector shows the exported vars grouped. The sheet draws the
# section ONCE, as a slim folder strip over the rows it holds. That the strip holds its grouped rows with
# no pill on them is variable_row_sentence_test's, and the @export_group / @export_subgroup emission is
# inspector_group_emit_test's; this pins the ungrouped row and the subsection's strip label.
@tool
class_name VariableExportGroupTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# Rendering: an ungrouped exported var sits beside a grouped one, in no folder.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"attack": {"type": "int", "default": 10, "exported": true, "attributes": {"group": "Combat"}},
		"speed": {"type": "float", "default": 5.0, "exported": true},
	}
	var rows: Array = viewport._build_global_variable_rows(sheet)
	all_passed = _check("an ungrouped variable sits in no folder",
		_folder_holding(rows, "speed"), "") and all_passed

	# A subgroup (@export_subgroup) reads as "Group › Subgroup" on the one strip.
	var sub_sheet: EventSheetResource = EventSheetResource.new()
	sub_sheet.variables = {"melee_dmg": {"type": "int", "default": 5, "exported": true, "attributes": {"group": "Combat", "subgroup": "Melee"}}}
	all_passed = _check("the strip names the subsection too",
		_folder_holding(viewport._build_global_variable_rows(sub_sheet), "melee_dmg"), "Combat › Melee") and all_passed
	viewport.free()

	return all_passed


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
