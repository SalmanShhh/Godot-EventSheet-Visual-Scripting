@tool
class_name WeightedTableShareTest
extends RefCounted

## The share column of a weighted table: one extra grid column, the percent of every row worked out
## from the weights as they stand, the total beside Add row, and nothing at all on a table with no
## weight column.

const SUPPORT := preload("res://tests/support.gd")
const COLUMNS: Array = [{"name": "item", "type": "String"}, {"name": "weight", "type": "float"}]
const ROWS: Array = [{"item": "coin", "weight": 50.0}, {"item": "gem", "weight": 25.0}, {"item": "sword", "weight": 25.0}]


static func run() -> bool:
	var ok: bool = true
	ok = _share_column() and ok
	ok = _plain_table() and ok
	ok = _weight_choice() and ok
	return ok


static func _share_column() -> bool:
	var table: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new(COLUMNS)
	table.call("set_weight_column", "weight")
	table.call("set_value", ROWS)
	var grid: GridContainer = table.get("_grid") as GridContainer
	var cells: Array = table.get("_share_cells")
	var shown: PackedStringArray = PackedStringArray()
	for entry: Variant in cells:
		shown.append(((entry as Array)[0] as Control).call("percent_text"))
	var total: Label = table.get("_total_label") as Label
	var result: bool = SUPPORT.pins("weighted_table_share_test", [
		["a weighted grid has a grip, two cells, a share and a remove button", grid.columns, 5],
		["every row shows its share", shown, PackedStringArray(["50%", "25%", "25%"])],
		["the total is said beside Add row", total.text, "Total weight 100"],
		["the total is visible", total.visible, true],
	])
	# Editing a weight moves every share and the total, without a rebuild of the grid.
	var rows: Array = table.get("_value")
	(rows[0] as Dictionary)["weight"] = 100.0
	table.call("_refresh_shares")
	var after: PackedStringArray = PackedStringArray()
	for entry: Variant in table.get("_share_cells"):
		after.append(((entry as Array)[0] as Control).call("percent_text"))
	result = SUPPORT.pins("weighted_table_share_test", [
		["a heavier first row takes more of the shares", after, PackedStringArray(["66.7%", "16.7%", "16.7%"])],
		["the total follows", total.text, "Total weight 150"],
	]) and result
	table.free()
	return result


static func _plain_table() -> bool:
	var table: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new(COLUMNS)
	table.call("set_value", ROWS)
	var grid: GridContainer = table.get("_grid") as GridContainer
	var result: bool = SUPPORT.pins("weighted_table_share_test", [
		["a table with no weight column keeps the grip, the cells and the remove button", grid.columns, 4],
		["it draws no share cell", (table.get("_share_cells") as Array).size(), 0],
		["it says no total", (table.get("_total_label") as Label).visible, false],
	])
	table.free()
	return result


static func _weight_choice() -> bool:
	var table: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new(COLUMNS)
	table.call("set_weight_column", "item")
	var text_column: String = str(table.get("weight_column"))
	table.call("set_weight_column", "nothing")
	var missing_column: String = str(table.get("weight_column"))
	table.free()
	return SUPPORT.pins("weighted_table_share_test", [
		["a text column cannot be the weight", text_column, ""],
		["a column the table does not have cannot be the weight", missing_column, ""],
	])
