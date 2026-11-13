@tool
class_name TableWeightMarkerTest
extends RefCounted

## The `:weight=<column>` part of a table marker: written only when asked and only for a number
## column, read back into the attribute, byte-exact through the importer, and harmless to a reader
## that does not know it (the older reading bails, so the line stays as written).

const SUPPORT := preload("res://tests/support.gd")
const PLAIN: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float,tags=String\") var entries: Array = []"
const WEIGHTED: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float,tags=String:weight=weight\") var entries: Array = []"
const WITH_NOTES: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float:default=coin|1:about=What drops|How likely:weight=weight\") var entries: Array = []"
const BAD_COLUMN: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float:weight=nothing\") var entries: Array = []"
const TEXT_COLUMN: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,weight=float:weight=item\") var entries: Array = []"


static func run() -> bool:
	var ok: bool = true
	ok = _emit() and ok
	ok = _round_trip() and ok
	ok = _older_reading() and ok
	return ok


static func _variable(attributes: Dictionary) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "entries"
	variable.type_name = "Array"
	variable.default_value = []
	variable.exported = true
	variable.attributes = attributes
	return variable


static func _columns() -> Array:
	return [{"name": "item", "type": "String"}, {"name": "weight", "type": "float"}, {"name": "tags", "type": "String"}]


static func _emit() -> bool:
	var weighted: Dictionary = {"drawer": "table", "table_columns": _columns(), "table_weight_column": "weight"}
	var unweighted: Dictionary = {"drawer": "table", "table_columns": _columns()}
	var on_text: Dictionary = {"drawer": "table", "table_columns": _columns(), "table_weight_column": "item"}
	var missing: Dictionary = {"drawer": "table", "table_columns": _columns(), "table_weight_column": "nothing"}
	return SUPPORT.pins("table_weight_marker_test", [
		["a table with a weight column writes the part last", EventSheetCompiler._emit_tree_variable_line(_variable(weighted)), WEIGHTED],
		["a table without one writes today's line", EventSheetCompiler._emit_tree_variable_line(_variable(unweighted)), PLAIN],
		["a weight column that is a text column is not written", EventSheetCompiler._emit_tree_variable_line(_variable(on_text)), PLAIN],
		["a weight column the table does not have is not written", EventSheetCompiler._emit_tree_variable_line(_variable(missing)), PLAIN],
	])


static func _round_trip() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen("extends Node2D\n\n" + WEIGHTED + "\n")
	var lifted: LocalVariable = null
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "entries":
			lifted = entry as LocalVariable
	var rows: Array = [["the variable is read", lifted != null, true]]
	if lifted != null:
		rows.append(["the weight column is read into the attribute", lifted.attributes.get("table_weight_column", ""), "weight"])
		rows.append(["the columns are still read", (lifted.attributes.get("table_columns", []) as Array).size(), 3])
	for source: Array in [["a weighted table", WEIGHTED], ["a weighted table with column notes", WITH_NOTES], ["a plain table", PLAIN],
			["a weight naming a missing column", BAD_COLUMN], ["a weight naming a text column", TEXT_COLUMN]]:
		var text: String = "extends Node2D\n\n" + str(source[1]) + "\n"
		rows.append(["%s re-saves byte for byte" % str(source[0]), SUPPORT.reemit(text, "user://table_weight_marker_test.gd"), text])
	var noted: EventSheetResource = SUPPORT.reopen("extends Node2D\n\n" + WITH_NOTES + "\n")
	for entry: Variant in noted.events:
		if entry is LocalVariable and (entry as LocalVariable).name == "entries":
			var columns: Array = (entry as LocalVariable).attributes.get("table_columns", [])
			rows.append(["column notes survive beside a weight column", columns[1].get("about", ""), "How likely"])
	return SUPPORT.pins("table_weight_marker_test", rows)


static func _older_reading() -> bool:
	# What a build without the part does with it: its note reader refuses an unknown part, so the
	# importer leaves the whole line as written and the Inspector keeps the notes before it.
	var columns: Array = [{"name": "item", "type": "String"}, {"name": "weight", "type": "float"}]
	var older_accepts: bool = EventSheetCompiler.read_table_column_notes(columns, ["weight=weight"])
	var inspector_columns: Array = EventSheetAttributeDrawers.parse_table_columns("item=String,weight=float", ["default=coin|1", "weight=weight"])
	return SUPPORT.pins("table_weight_marker_test", [
		["an older note reader refuses the weight part", older_accepts, false],
		["the weight part is peeled off the end", EventSheetCompiler.peel_table_weight(["default=a|b", "weight=w"]), {"parts": ["default=a|b"], "weight": "w"}],
		["a part list with no weight is left whole", EventSheetCompiler.peel_table_weight(["default=a|b"]), {"parts": ["default=a|b"], "weight": ""}],
		["the Inspector reads the notes before the weight part", inspector_columns[0].get("default", ""), "coin"],
		["the Inspector finds the weight column", EventSheetAttributeDrawers.table_weight_column(inspector_columns, ["weight=weight"]), "weight"],
		["a weight naming no number column finds none", EventSheetAttributeDrawers.table_weight_column(inspector_columns, ["weight=item"]), ""],
	])
