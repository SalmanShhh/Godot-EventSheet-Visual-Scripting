@tool
class_name OddsBarTest
extends RefCounted

## The odds of a weighted table as one bar and one line: what it says for a table with weights, for
## one with none, and for none at all, and that a look hands back no extra rows unless it asks to.

const SUPPORT := preload("res://tests/support.gd")
const BAR_PATH: String = "res://addons/eventsheet/editor/inspector/odds_bar.gd"
const ROWS: Array = [{"item": "coin", "weight": 50.0}, {"item": "gem", "weight": 25.0}, {"item": "sword", "weight": 5.0}, {"item": "map", "weight": 4.0}, {"item": "", "weight": 1.0}]


static func run() -> bool:
	var ok: bool = true
	ok = _with_weights() and ok
	ok = _without_weights() and ok
	ok = _hooks() and ok
	return ok


static func _with_weights() -> bool:
	var bar: Control = load(BAR_PATH).new()
	bar.call("set_rows", ROWS, "weight", "item")
	var shares: PackedFloat64Array = bar.call("shares_drawn")
	var result: bool = SUPPORT.pins("odds_bar_test", [
		["the control shows for a table with rows", bar.visible, true],
		["one piece per row, in row order", shares.size(), 5],
		["the first piece is the biggest share", snappedf(shares[0], 0.001), 0.588],
		["the line names the biggest three and counts the rest", bar.call("line_text"), "coin 58.8%, gem 29.4%, sword 5.9% and 2 more"],
		["no empty-table sentence while there are odds", bar.call("empty_text"), ""],
	])
	bar.free()
	return result


static func _without_weights() -> bool:
	var bar: Control = load(BAR_PATH).new()
	bar.call("set_rows", [{"item": "coin", "weight": 0.0}], "weight", "item")
	var result: bool = SUPPORT.pins("odds_bar_test", [
		["a table where nothing has a weight says nothing can be picked", bar.call("empty_text"), "No row has a weight above 0, so nothing can be picked."],
		["it draws no bar and says no odds", [bar.call("shares_drawn").size(), bar.call("line_text")], [0, ""]],
	])
	bar.call("set_rows", [], "weight", "item")
	result = SUPPORT.pins("odds_bar_test", [["a table with no rows hides the control", bar.visible, false]]) and result
	bar.free()
	return result


static func _hooks() -> bool:
	# An editor row cannot be built outside the editor, so the base is read by its method list.
	var names: PackedStringArray = PackedStringArray()
	for method: Dictionary in load("res://addons/eventsheet/editor/inspector/inspector_look.gd").get_script_method_list():
		names.append(str(method["name"]))
	return SUPPORT.pins("odds_bar_test", [
		["a look can hand back rows above its field", names.has("_rows_above_field"), true],
		["a look can hand back rows under its field", names.has("_rows_under_field"), true],
	])
