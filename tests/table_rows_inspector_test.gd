# EventForge - a data table in the Inspector, read as a table: the "Pick a row of a data table" look
# on an int (a dropdown of the table's rows by their name column, the number still what the file
# stores, a number past the rows shown amber rather than moved), and the table look on a long list
# (search, sort by a column, pages, quiet amber empty cells) - which only change what is DRAWN, never
# the order the list keeps.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "table_rows_inspector_test"
const TABLE_ROW_DRAWER_PATH := "res://addons/eventsheet/editor/inspector/table_row_drawer.gd"
const ROW_LINE := "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table_row:drops:name\") var drop_row: int = 1"
const DROP_NAMES: Array[String] = ["Coin", "Gem", "Heart", "Key", "Big coin", "Chest key", "Potion", "Bomb", "Arrow",
	"Feather", "Bone", "Ruby", "Map piece", "Silver coin", "Elixir", "Shield shard", "Old boot", "Torch", "Rope", "Mushroom",
	"Crystal", "Star", "Scroll"]
const DROP_KINDS: Array[String] = ["coin", "gem", "heal", "key"]
const DROP_COLUMNS: Array = [{"name": "name", "type": "String"}, {"name": "kind", "type": "String"},
	{"name": "amount", "type": "int"}, {"name": "weight", "type": "int"}, {"name": "icon", "type": "texture"}]


static func run() -> bool:
	var ok: bool = _test_row_look_code()
	ok = _test_row_choices() and ok
	ok = _test_table_view() and ok
	ok = _test_open_link() and ok
	return _test_table_widget() and ok


## The look writes one marker on an int, reopens on the same look, and saves back byte for byte; a
## marker it cannot read stays the line it was.
static func _test_row_look_code() -> bool:
	var row_var: LocalVariable = LocalVariable.new()
	row_var.name = "drop_row"
	row_var.type_name = "int"
	row_var.default_value = 1
	row_var.exported = true
	row_var.attributes = EventSheetInspectorLooks.fold("table_row", {"table": "drops", "name_column": "name"}, "int")
	var source: String = "extends Resource\n\n" + ROW_LINE + "\n"
	var lifted: LocalVariable = null
	for entry: Variant in SUPPORT.reopen(source).events:
		if entry is LocalVariable and (entry as LocalVariable).name == "drop_row":
			lifted = entry
	var odd_source: String = "extends Resource\n\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table_row:drops\") var drop_row: int = 1\n"
	var odd_attributes: Variant = null
	for entry: Variant in SUPPORT.reopen(odd_source).events:
		if entry is LocalVariable and (entry as LocalVariable).name == "drop_row":
			odd_attributes = (entry as LocalVariable).attributes
	var int_looks: Array = EventSheetInspectorLooks.for_type("int").map(func(look: Dictionary) -> String: return str(look.get("id")))
	var float_looks: Array = EventSheetInspectorLooks.for_type("float").map(func(look: Dictionary) -> String: return str(look.get("id")))
	return SUPPORT.pins(NAME, [
		["the look folds into the two names the marker carries", row_var.attributes,
			{"drawer": "table_row", "table_row_table": "drops", "table_row_column": "name"}],
		["it emits the marker on the int, the number as its value", SheetCompiler._emit_tree_variable_line(row_var), ROW_LINE],
		["a String cannot carry it", SheetCompiler._drawer_export_prefix(row_var.attributes, "String"), ""],
		["a table name that is not a name writes nothing",
			SheetCompiler._drawer_export_prefix({"drawer": "table_row", "table_row_table": "my drops", "table_row_column": "name"}, "int"), ""],
		["the file reopens on the same look", lifted.attributes if lifted != null else null,
			{"drawer": "table_row", "table_row_table": "drops", "table_row_column": "name"}],
		["and unfolds into the look's own fields", EventSheetInspectorLooks.unfold(lifted.attributes if lifted != null else {}),
			["table_row", {"table": "drops", "name_column": "name"}]],
		["it saves back byte for byte", SUPPORT.reemit(source, "user://table_row_probe.gd"), source],
		["a marker short of its column is not read as the look", (odd_attributes as Dictionary).get("drawer", "") if odd_attributes is Dictionary else "", ""],
		["and stays the line it was", SUPPORT.reemit(odd_source, "user://table_row_odd_probe.gd"), odd_source],
		["the Inspector reads the marker's two names",
			EventSheetAttributeDrawers.parse_drawer_hint("eventsheet:table_row:drops:name").get("args"), ["drops", "name"]],
		["an int offers the look", int_looks.has("table_row"), true],
		["a float does not", float_looks.has("table_row"), false],
		["the look's own words", EventSheetInspectorLooks.label(EventSheetInspectorLooks.by_id("table_row")), "Pick a row of a data table"],
	])


## The dropdown names each row by its name column; a number past the rows is shown as it is.
static func _test_row_choices() -> bool:
	var drawer: GDScript = load(TABLE_ROW_DRAWER_PATH)
	var rows: Array = [{"name": "Coin"}, {"name": "Gem"}, {"name": ""}]
	var held: Dictionary = drawer.choices(rows, "drops", "name", 1)
	var gone: Dictionary = drawer.choices(rows, "drops", "name", 5)
	var texts: Callable = func(offered: Dictionary) -> Array:
		return (offered.get("items", []) as Array).map(func(item: Dictionary) -> String: return str(item.get("text")))
	var dropdown: OptionButton = OptionButton.new()
	drawer.fill(dropdown, gone)
	var shown_gone: Array = [dropdown.get_item_text(dropdown.selected), dropdown.get_item_metadata(dropdown.selected),
		dropdown.has_theme_stylebox_override("normal")]
	drawer.fill(dropdown, held)
	var shown_held: Array = [dropdown.get_item_text(dropdown.selected), dropdown.tooltip_text, dropdown.has_theme_stylebox_override("normal")]
	dropdown.free()
	return SUPPORT.pins(NAME, [
		["each row by its name, a nameless one by its number", texts.call(held), ["Coin", "Gem", "row 2"]],
		["the stored number picks its row", [held.get("selected"), held.get("missing")], [1, false]],
		["each row says where it is", (held.get("items") as Array)[1].get("description"), "row 1 of drops"],
		["a number past the rows keeps its own item", texts.call(gone), ["Coin", "Gem", "row 2", "row 5"]],
		["chosen and marked missing, never moved", [gone.get("selected"), gone.get("missing"), (gone.get("items") as Array)[3].get("value")], [3, true, 5]],
		["and says the row is gone", (gone.get("items") as Array)[3].get("description"),
			"drops has no row 5: pick a row, or the number stays as it is."],
		["the field shows the number it holds, amber", shown_gone, ["row 5", 5, true]],
		["a held row shows its name and place, plain", shown_held, ["Gem", "row 1 of drops", false]],
		["a Resource row is named the same way", drawer.row_name_of(_named_resource("Torch"), "resource_name"), "Torch"],
	])


## What the grid draws for a search, a sort and a page - stored indices, in drawn order.
static func _test_table_view() -> bool:
	var table: GDScript = EventSheetAttributeDrawers.widgets().DrawerTable
	var rows: Array = _drops()
	var view: Callable = func(query: String, column: String, descending: bool, page: int) -> Dictionary:
		return table.view_of(rows, DROP_COLUMNS, query, column, descending, page, 8)
	var numbers: Array = [{"n": -5}, {"n": 3}, {"n": -12}]
	return SUPPORT.pins(NAME, [
		["the first page in the file's order", view.call("", "", false, 0).get("rows"), [0, 1, 2, 3, 4, 5, 6, 7]],
		["and what it says", table.page_text(view.call("", "", false, 0), 8), "Rows 1-8 of 23"],
		["the last page holds the rest", view.call("", "", false, 2).get("rows"), [16, 17, 18, 19, 20, 21, 22]],
		["and says so", table.page_text(view.call("", "", false, 2), 8), "Rows 17-23 of 23"],
		["a page past the end is the last page", view.call("", "", false, 9).get("page"), 2],
		["a search keeps the rows with it in any cell", view.call("coin", "", false, 0).get("rows"), [0, 4, 8, 12, 13, 16, 20]],
		["on one page, counted", table.page_text(view.call("coin", "", false, 0), 8), "Rows 1-7 of 7"],
		["a search that keeps nothing says so", table.page_text(view.call("dragon", "", false, 0), 8), "No row matches"],
		["sorted by weight, the heaviest first", view.call("", "weight", true, 0).get("rows"), [0, 14, 5, 19, 10, 1, 15, 6]],
		["its second page", view.call("", "weight", true, 1).get("rows"), [20, 11, 2, 16, 7, 21, 12, 3]],
		["sorted by name from A", view.call("", "name", false, 0).get("rows"), [8, 4, 7, 10, 5, 0, 20, 14]],
		["a search and a sort together", view.call("coin", "weight", true, 0).get("rows"), [0, 20, 16, 12, 8, 13, 4]],
		["a number column sorts as numbers", table.view_of(numbers, [{"name": "n", "type": "int"}], "", "n", false, 0, 8).get("rows"), [2, 0, 1]],
		["one empty cell", table.is_empty_cell(rows[6], DROP_COLUMNS[4]), true],
		["a number is never empty", table.is_empty_cell({"amount": 0}, DROP_COLUMNS[2]), false],
		["rows with an empty cell", table.rows_with_empty_cells(rows, DROP_COLUMNS), 1],
		["an empty cell's hover says what is missing", table.empty_cell_hint(DROP_COLUMNS[4], 6), "icon is empty in row 6."],
		["and what the column is for", table.empty_cell_hint({"name": "icon", "about": "The picture shown."}, 6),
			"icon is empty in row 6.\nThe picture shown."],
	])


## The grid itself: sorting, searching and paging draw other rows and keep the list's order.
static func _test_table_widget() -> bool:
	var table: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new(DROP_COLUMNS)
	var rows: Array = _drops()
	table.call("set_value", rows)
	var short: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new(DROP_COLUMNS)
	short.call("set_value", rows.slice(0, 3))
	var short_search: bool = (short.get("_search") as Control).visible
	short.free()
	var long_search: bool = (table.get("_search") as Control).visible
	table.call("sort_by", "weight")
	var by_weight: Array = table.call("shown_rows")
	var weight_head: String = ((table.get("_grid") as GridContainer).get_child(4) as Button).text
	var second_up: Button = (table.get("_grid") as GridContainer).get_child(22) as Button
	var up_while_sorted: bool = second_up.disabled
	table.call("sort_by", "weight")
	var by_weight_light: Array = table.call("shown_rows")
	table.call("turn_page", 1)
	var page_two: String = (table.get("_page_label") as Label).text
	table.call("search", "key")
	var keys: Array = table.call("shown_rows")
	var order_kept: bool = table.call("get_value") == rows
	table.call("search", "")
	table.call("sort_by", "#")
	var back: Array = table.call("shown_rows")
	var missing: String = (table.get("_missing_label") as Label).text
	table.call("search", "gem")
	var up_while_searched: bool = ((table.get("_grid") as GridContainer).get_child(22) as Button).disabled
	table.free()
	return SUPPORT.pins(NAME, [
		["a short grid has no search box", short_search, false],
		["a long one has", long_search, true],
		["a click on a number column sorts the heaviest first", by_weight, [0, 14, 5, 19, 10, 1, 15, 6]],
		["the sorted column carries its arrow", weight_head, "weight ▼"],
		["moving a row waits for the file's order", up_while_sorted, true],
		["and for the whole list", up_while_searched, true],
		["a second click flips it", by_weight_light, [9, 18, 4, 13, 22, 8, 17, 3]],
		["the page turns", page_two, "Rows 9-16 of 23"],
		["a search keeps the matching rows, still sorted", keys, [3, 7, 11, 15, 19, 5]],
		["and the list keeps its order", order_kept, true],
		["the # column is the file's order again", back, [0, 1, 2, 3, 4, 5, 6, 7]],
		["the count of rows with an empty cell", missing, "1 row has an empty cell"],
	])


## "Open as a table" under the grid: shown for a list kept in a file of its own, and it opens that
## file; a list with no file, or with no door handed in, draws no link.
static func _test_open_link() -> bool:
	var opened: Array = []
	var filed: Resource = Resource.new()
	filed.resource_path = "res://goblin_probe.tres"
	var inner: Resource = Resource.new()
	inner.resource_path = "res://goblin_probe.tscn::Resource_1"
	var file_of: Callable = EventSheetAttributeDrawers.TableProperty.file_of
	var table: Control = EventSheetAttributeDrawers.widgets().DrawerTable.new(DROP_COLUMNS)
	var link: LinkButton = table.get("_open_link")
	var doorless: Array = [link.visible, (table.get("_pager") as Control).visible]
	table.set("open_table", func() -> void: opened.append("goblin"))
	table.call("_rebuild")
	var with_door: Array = [link.visible, link.text, (table.get("_pager") as Control).visible]
	link.pressed.emit()
	table.free()
	return SUPPORT.pins(NAME, [
		["a list in a .tres can be opened as a table", file_of.call(filed), "res://goblin_probe.tres"],
		["a list with no file of its own cannot", file_of.call(Resource.new()), ""],
		["nor one inside a scene", file_of.call(inner), ""],
		["no door: no link, and a short grid has no bar under it", doorless, [false, false]],
		["a door: the link, in the bar under the grid", with_door, [true, "Open as a table", true]],
		["and the link opens the file", opened, ["goblin"]],
	])


## The board's 23 drops, one icon left empty.
static func _drops() -> Array:
	var rows: Array = []
	for index: int in range(DROP_NAMES.size()):
		rows.append({"name": DROP_NAMES[index], "kind": DROP_KINDS[index % 4], "amount": 1 + ((index * 7) % 25),
			"weight": maxi(1, 60 - ((index * 13) % 59)),
			"icon": "" if index == 6 else "res://%s.png" % DROP_NAMES[index].to_lower().replace(" ", "_")})
	return rows


static func _named_resource(text: String) -> Resource:
	var resource: Resource = Resource.new()
	resource.resource_name = text
	return resource
