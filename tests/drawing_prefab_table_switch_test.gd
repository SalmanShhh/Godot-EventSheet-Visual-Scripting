# Godot EventSheets - "Open as a table" and "Show as cards": one Inspector, one list, two ways to look at
# it. Switching writes nothing and keeps nothing in the file; an edit made in the table and an edit made
# in a card each keep the keys the other view does not show (a line's ends and dashes).
@tool
class_name DrawingPrefabTableSwitchTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_table_switch_test"
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")


static func _look_line() -> Dictionary:
	return {"kind": "line", "x": -60.0, "y": 0.0, "p1": 60.0, "p2": 0.0, "p3": 3.0, "color": "#ffd24d", "texture": "",
		"scale_mode": "fixed", "caps": "round", "dashed": true, "dash_size": 5.0, "dash_spacing": 3.0, "dash_offset": 0.25, "dash_style": "angled"}


static func _ranges(node: Node, found: Array) -> Array:
	if node is Range:
		found.append(node)
	for child: Node in node.get_children():
		_ranges(child, found)
	return found


static func _link_words(node: Node, found: PackedStringArray) -> PackedStringArray:
	if node is LinkButton and (node as LinkButton).visible:
		found.append((node as LinkButton).text)
	for child: Node in node.get_children():
		_link_words(child, found)
	return found


static func run() -> bool:
	var view: Control = PREFAB_STEPS.ShapeStepsView.new()
	var steps: Array = [_look_line(), {"kind": "circle", "x": 0.0, "y": 0.0, "p1": 8.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""}]
	view.call("set_steps", steps)
	var changes: Array = []
	view.connect("value_changed", func(value: Array) -> void: changes.append(value))
	var rows: Array = [
		["a list opens as cards", view.call("table_shown"), false],
		["the cards side offers the table", ",".join(_link_words(view.call("cards"), PackedStringArray())), "Open as a table"],
	]
	view.call("show_table", true)
	rows.append(["asking for the table shows it", view.call("table_shown"), true])
	rows.append(["the table side offers the cards back", ",".join(_link_words(view.call("table"), PackedStringArray())), "Show as cards"])
	rows.append(["switching changes nothing in the list", view.call("get_steps"), steps])
	rows.append(["and writes nothing", changes.size(), 0])
	# A table edit: the first number cell of the first row is the line's x.
	var cells: Array = _ranges(view.call("table"), [])
	(cells[0] as Range).set_value_no_signal(-50.0)
	(cells[0] as Range).value_changed.emit(-50.0)
	var after_table: Array = view.call("get_steps")
	rows.append(["a table edit reaches the line", float((after_table[0] as Dictionary).get("x")), -50.0])
	rows.append(["and keeps the look the table has no column for", [
		(after_table[0] as Dictionary).get("caps"), (after_table[0] as Dictionary).get("dashed"),
		(after_table[0] as Dictionary).get("dash_size"), (after_table[0] as Dictionary).get("scale_mode"),
		(after_table[0] as Dictionary).get("dash_style")], ["round", true, 5.0, "fixed", "angled"]])
	rows.append(["the table edit was announced once", changes.size(), 1])
	view.call("show_table", false)
	rows.append(["back on the cards the edit is there", float((view.call("get_steps")[0] as Dictionary).get("x")), -50.0])
	view.call("cards").write_card_key(0, "p1", 80.0)
	var after_card: Array = view.call("get_steps")
	rows.append(["a card edit reaches the line", float((after_card[0] as Dictionary).get("p1")), 80.0])
	rows.append(["and keeps what the table wrote", float((after_card[0] as Dictionary).get("x")), -50.0])
	rows.append(["and its dashes", (after_card[0] as Dictionary).get("dash_style"), "angled"])
	view.call("show_table", true)
	rows.append(["the table shows the card's edit", view.call("get_steps"), after_card])
	# The choice is per object and lives for the session only: nothing is written into the data.
	PREFAB_STEPS.ShapeStepsView.remember(4242, true)
	rows.append(["the view an object was left in is remembered", PREFAB_STEPS.ShapeStepsView.remembered(4242), true])
	rows.append(["another object starts on the cards", PREFAB_STEPS.ShapeStepsView.remembered(4243), false])
	PREFAB_STEPS.ShapeStepsView.remember(4242, false)
	view.free()
	return SUPPORT.pins(PREFIX, rows)
