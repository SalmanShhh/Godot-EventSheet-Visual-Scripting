@tool
class_name RollPanelTest
extends RefCounted

## The roll button of a weighted table: nothing shown before a roll, a thousand picks after it, the
## counts cleared when the rows change, and no button to press when no row has a weight.

const SUPPORT := preload("res://tests/support.gd")
const PANEL_PATH: String = "res://addons/eventsheet/editor/inspector/roll_panel.gd"
const ROWS: Array = [{"item": "coin", "weight": 3.0}, {"item": "gem", "weight": 1.0}, {"item": "dud", "weight": 0.0}]


static func run() -> bool:
	var panel: Control = load(PANEL_PATH).new()
	panel.call("set_rows", ROWS, "weight", "item")
	var before: bool = panel.call("rolled")
	panel.get("_rng").seed = 7
	panel.call("roll")
	var lines: PackedStringArray = panel.call("count_lines")
	var coin: int = int(lines[0].get_slice(" ", 1))
	var gem: int = int(lines[1].get_slice(" ", 1))
	var dud: int = int(lines[2].get_slice(" ", 1))
	var result: bool = SUPPORT.pins("roll_panel_test", [
		["nothing is shown before the first roll", before, false],
		["a roll gives one line per row", lines.size(), 3],
		["a roll makes a thousand picks", coin + gem + dud, 1000],
		["a row with no weight never comes up", dud, 0],
		["the heavier row comes up more", coin > gem, true],
		["the lines name the rows by their text", lines[0].begins_with("coin "), true],
	])
	var changed: Array = ROWS.duplicate(true)
	(changed[0] as Dictionary)["weight"] = 5.0
	panel.call("set_rows", changed, "weight", "item")
	result = SUPPORT.pins("roll_panel_test", [
		["a change in the rows clears the counts", panel.call("rolled"), false],
		["the same rows again keep nothing either", panel.call("count_lines").size(), 0],
	]) and result
	panel.call("set_rows", [{"item": "coin", "weight": 0.0}], "weight", "item")
	result = SUPPORT.pins("roll_panel_test", [["the button is off when no row has a weight", panel.call("button_disabled"), true]]) and result
	panel.free()
	return result
