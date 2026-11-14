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
	ok = _columns_by_need() and ok
	ok = _widest_cell() and ok
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


## The columns share the width by need: the text columns take what is left, the number column and the
## share column ask only for what their widest value wants, and the bar joins the percent only in a
## table with room to spare.
static func _columns_by_need() -> bool:
	var table: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new([
		{"name": "item", "type": "String"}, {"name": "weight", "type": "float"}, {"name": "tags", "type": "String"}])
	table.call("set_weight_column", "weight")
	table.call("set_value", [{"item": "coin", "weight": 50.0, "tags": "common"}])
	var grid: GridContainer = table.get("_grid") as GridContainer
	var cell: Control = (table.get("_share_cells") as Array)[0][0] as Control
	var narrow: float = (cell.get("_bar") as Control).custom_minimum_size.x
	var bar_narrow: bool = bool(cell.call("bar_shown"))
	cell.call("set_roomy", true)
	var roomy: float = (cell.get("_bar") as Control).custom_minimum_size.x
	var bar_room: float = EventSheetLookStyle.px(28.0)
	var result: bool = SUPPORT.pins("weighted_table_share_test", [
		["a text cell grows into the room that is left", (grid.get_child(7) as Control).size_flags_horizontal, Control.SIZE_EXPAND_FILL],
		["the number cell does not grow", (grid.get_child(8) as Control).size_flags_horizontal, Control.SIZE_FILL],
		["the second text cell grows too", (grid.get_child(9) as Control).size_flags_horizontal, Control.SIZE_EXPAND_FILL],
		["the share cell does not grow", cell.size_flags_horizontal, Control.SIZE_FILL],
		["the bar asks for its own room only in a roomy table", roomy - narrow, bar_room],
		["a table just under the roomy width has no bar", EventSheetAttributeDrawers.widgets().DrawerTable.is_roomy(EventSheetLookStyle.px(439.0)), false],
		["a table at the roomy width has the bar", EventSheetAttributeDrawers.widgets().DrawerTable.is_roomy(EventSheetLookStyle.px(440.0)), true],
		["a narrow share cell shows no bar", bar_narrow, false],
		["a roomy share cell shows its bar", bool(cell.call("bar_shown")), true],
	])
	table.free()
	return result


## A number column is as wide as its widest value needs: nines as long as the longest number, one more
## for a sign, and never fewer than four.
static func _widest_cell() -> bool:
	var table: GDScript = EventSheetAttributeDrawers.widgets().DrawerTable
	return SUPPORT.pins("weighted_table_share_test", [
		["short numbers keep the least room", table.widest_cell([{"weight": 5.0}], "weight"), "9999"],
		["a wider number asks for one more", table.widest_cell([{"weight": 5.0}, {"weight": 25.0}], "weight"), "99999"],
		["a long number asks for its digits and a sign", table.widest_cell([{"weight": 12345.5}], "weight"), "99999999"],
		["a column nobody has filled keeps the least room", table.widest_cell([{"item": "coin"}], "weight"), "9999"],
	])
