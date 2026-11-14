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
	rows.append_array(_readable_amber())
	return SUPPORT.pins("inspector_mark_test", rows)


## The amber "?" of a missing look is held to a readable contrast on the colour it sits on, in either theme,
## and keeps its hue; a mark that does not know its ground is left alone.
static func _readable_amber() -> Array:
	var minis: GDScript = load("res://addons/eventsheet/editor/inspector/look_minis.gd")
	var pale_amber: Color = Color(0.95, 0.82, 0.5)
	var pale_tile: Color = Color("#c8d2e6")
	var dark_tile: Color = Color("#23384d")
	var on_pale: Color = minis.readable_ink(pale_amber, pale_tile)
	var on_dark: Color = minis.readable_ink(pale_amber, dark_tile)
	var unknown: Color = minis.readable_ink(pale_amber, Color(0.0, 0.0, 0.0, 0.0))
	return [
		["amber on a pale tile reads at the least contrast", EventSheetLookStyle.contrast_ratio(on_pale, pale_tile) >= minis.MARK_CONTRAST, true],
		["amber on a pale tile is darker than it was", on_pale.get_luminance() < pale_amber.get_luminance(), true],
		["amber on a pale tile keeps its hue", snappedf(on_pale.h, 0.02), snappedf(pale_amber.h, 0.02)],
		["amber on a dark tile already reads and is left as it was", on_dark, pale_amber],
		["an unknown ground leaves the amber as it was", unknown, pale_amber],
		["a pale amber on a white tile is darkened to read", EventSheetLookStyle.contrast_ratio(minis.readable_ink(pale_amber, Color.WHITE), Color.WHITE) >= minis.MARK_CONTRAST, true],
	]


static func _with(attributes: Dictionary) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "value"
	variable.exported = true
	variable.attributes = attributes
	return variable
