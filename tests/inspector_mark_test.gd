@tool
class_name InspectorMarkTest
extends RefCounted

## The picture an exported variable's Inspector mark is drawn with: the look it wears, a Color's own
## colour, an amber question mark for a look that is not installed, and today's plain mark for the rest.

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")


static func run() -> bool:
	var rows: Array = []
	for case: Array in [
		["a variable with no attributes", {}, "int", 5, "", ""],
		["a variable with only words", {"tooltip": "How tough.", "group": "Combat"}, "int", 5, "", ""],
		["a range is a slider", {"range": {"min": "0", "max": "100", "step": "1"}}, "int", 5, "slider", "slider"],
		["an angle", {"range": {"min": "0", "max": "360", "step": "0.1", "angle": "degrees"}}, "float", 0.0, "angle", "angle"],
		["a progress bar", {"drawer": "progress_bar", "range": {"min": "0", "max": "100", "step": "1"}}, "int", 5, "progress_bar", "progress_bar"],
		["a table", {"drawer": "table", "table_columns": [{"name": "item", "type": "String"}]}, "Array", [], "table", "table"],
		["a table with a weight column", {"drawer": "table", "table_columns": [{"name": "w", "type": "float"}], "table_weight_column": "w"}, "Array", [], "table", "table"],
		["a row picked from a table", {"drawer": "table_row", "table_row_table": "drops", "table_row_column": "name"}, "int", 0, "table_row", "table_row"],
		["a list of cards", {"drawer": "cards"}, "Array", [], "cards", "cards"],
		["a file picker", {"file": {"mode": "file", "global": false}}, "String", "", "file", "file"],
		["checkbox flags", {"flags": [{"label": "Fire"}]}, "int", 0, "flags", "flags"],
		["a dropdown from a function", {"choices_function": "attack_names"}, "String", "", "choices", "choices"],
		["a look that is a file and is installed", {"look": "seed", "look_args": []}, "int", 0, "seed", "seed"],
		["a look that is a file with no picture of its own", {"look": "star_rating_that_is_not_here"}, "int", 0, "missing", "star_rating_that_is_not_here"],
		["your own hint", {"custom_hint": {"hint": "PROPERTY_HINT_RANGE", "text": "0,10", "usage": ""}}, "int", 0, "", ""],
		["saved but hidden", {"storage": true}, "int", 0, "", ""],
	]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = "value"
		variable.type_name = str(case[2])
		variable.exported = true
		variable.attributes = case[1]
		var mark: Dictionary = NativeVariableMarks.inspector_mark(variable, str(case[2]), case[3])
		rows.append(["%s: the picture" % case[0], mark["picture"], case[4]])
		rows.append(["%s: the look" % case[0], mark["look_id"], case[5]])
	var coloured: LocalVariable = LocalVariable.new()
	coloured.name = "tint"
	coloured.exported = true
	var own: Dictionary = NativeVariableMarks.inspector_mark(coloured, "Color", "Color(1, 0.5, 0.25)")
	rows.append(["a plain Color wears its own colour", [own["picture"], own["colour"]], ["colour", Color(1, 0.5, 0.25)]])
	var unreadable: Dictionary = NativeVariableMarks.inspector_mark(coloured, "Color", "pick_colour()")
	rows.append(["a Color it cannot read keeps the plain mark", unreadable["picture"], ""])
	var by_hint: LocalVariable = LocalVariable.new()
	by_hint.name = "speed"
	by_hint.exported = true
	by_hint.export_hint = "@export_range(0, 100, 1)"
	rows.append(["an opened script's @export_range line is a slider", NativeVariableMarks.inspector_mark(by_hint, "int", 5)["picture"], "slider"])
	by_hint.export_hint = "@export_storage"
	var combo: LocalVariable = LocalVariable.new()
	combo.name = "difficulty"
	combo.exported = true
	combo.options = PackedStringArray(["easy", "hard"])
	rows.append(["a String with a list of words is a dropdown", NativeVariableMarks.inspector_mark(combo, "String", "easy")["picture"], "choices"])
	rows.append(["an opened script's @export_storage line is the plain mark", NativeVariableMarks.inspector_mark(by_hint, "int", 5)["picture"], ""])
	rows.append(["no variable is the plain mark", NativeVariableMarks.inspector_mark(null, "int", 5)["picture"], ""])
	rows.append(["a missing look is flagged missing", NativeVariableMarks.inspector_mark(_with({"look": "not_installed_anywhere"}), "int", 0)["missing"], true])
	return SUPPORT.pins("inspector_mark_test", rows)


static func _with(attributes: Dictionary) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "value"
	variable.exported = true
	variable.attributes = attributes
	return variable
